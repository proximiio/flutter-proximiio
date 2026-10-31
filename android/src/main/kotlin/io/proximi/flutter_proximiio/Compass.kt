// The plugin's compass, behind `Proximiio.compassHeadings` in Dart.
//
// Neither SDK has a compass stream; the maps have their own (`proximiio-map-live/.../MapCompass.kt`).
// This is the same sensor and the same rules, plus a low-pass filter, because the reading goes to a
// marker that is redrawn as it arrives (a web map in a WebView, a Flutter widget) and not through the
// map's own animation.
//
// ## Why the rotation vector
//
// `TYPE_ROTATION_VECTOR` is the platform's fusion of magnetometer, accelerometer and gyroscope,
// referenced to magnetic north: steadier than the raw magnetometer and tilt-compensated.
// `TYPE_GEOMAGNETIC_ROTATION_VECTOR` (no gyroscope) stands in where it is missing. No sensor needs a
// permission, and none of this uses PDR, so it works without ACTIVITY_RECOGNITION.
//
// ## Pieces
//
// * `CompassSmoother`: the filter and the rate limit. Pure, tested on the JVM.
// * `CompassProvider`: the seam over `SensorManager`; `SensorCompass` is the real one.
// * `CompassFeed`: the lifecycle. On while Dart listens and the app is in the foreground.
package io.proximi.flutter_proximiio

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Display
import android.view.Surface
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.roundToLong
import kotlin.math.sin

/** Degrees in `[0, 360)`. */
internal fun normalizedDegrees(degrees: Double): Double {
  val value = degrees % 360.0
  return if (value < 0) value + 360.0 else value
}

/** The smaller angle between [a] and [b], in `[0, 180]`. */
internal fun angleBetween(a: Double, b: Double): Double = abs(normalizedDegrees(a - b + 180.0) - 180.0)

/**
 * Smooths compass readings and limits how often they are passed on.
 *
 * - **Filter:** an exponential low-pass on the unit vector of the heading (so 359° and 1° average to
 *   0°, not 180°), with time constant [timeConstantNanos]. It follows the time between readings, not
 *   their count, so the result is the same at any sensor rate.
 * - **Rate:** a reading is passed on at most every [minIntervalNanos] (about 10 Hz), and only when
 *   the smoothed heading moved [minChangeDegrees] or more, the accuracy changed by a degree or more,
 *   or the north it is measured from changed. A phone lying still sends nothing new.
 */
internal class CompassSmoother(
  private val timeConstantNanos: Long = TIME_CONSTANT_NANOS,
  private val minIntervalNanos: Long = MIN_INTERVAL_NANOS,
  private val minChangeDegrees: Double = MIN_CHANGE_DEGREES,
) {
  /** A smoothed reading. */
  data class Output(val degrees: Double, val accuracyDegrees: Double, val isTrueNorth: Boolean)

  private var east = 0.0
  private var north = 0.0
  private var lastSampleNanos: Long? = null
  private var lastEmitNanos = 0L
  private var lastEmitted: Output? = null

  /** Forgets the past readings: the next one is passed on as it is. */
  fun reset() {
    lastSampleNanos = null
    lastEmitted = null
  }

  /** Adds a reading taken at [timestampNanos]; returns the smoothed one to pass on, or `null`. */
  fun add(degrees: Double, accuracyDegrees: Double, isTrueNorth: Boolean, timestampNanos: Long): Output? {
    val radians = Math.toRadians(degrees)
    val last = lastSampleNanos
    if (last == null) {
      east = sin(radians)
      north = cos(radians)
    } else {
      val elapsed = (timestampNanos - last).coerceIn(0L, MAX_GAP_NANOS)
      val alpha = 1.0 - exp(-elapsed.toDouble() / timeConstantNanos)
      east += alpha * (sin(radians) - east)
      north += alpha * (cos(radians) - north)
    }
    lastSampleNanos = timestampNanos
    val smoothed = Output(normalizedDegrees(Math.toDegrees(atan2(east, north))), accuracyDegrees, isTrueNorth)
    val previous = lastEmitted
    if (previous != null) {
      if (timestampNanos - lastEmitNanos < minIntervalNanos) return null
      val changed = angleBetween(smoothed.degrees, previous.degrees) >= minChangeDegrees ||
        abs(smoothed.accuracyDegrees - previous.accuracyDegrees) >= 1.0 ||
        smoothed.isTrueNorth != previous.isTrueNorth
      if (!changed) return null
    }
    lastEmitted = smoothed
    lastEmitNanos = timestampNanos
    return smoothed
  }

  internal companion object {
    /** 0.15 s: the marker settles within about half a second of a turn, and sensor jitter is gone. */
    const val TIME_CONSTANT_NANOS = 150_000_000L

    /** About 10 Hz, with room for the sensor's timing jitter at 50 Hz. */
    const val MIN_INTERVAL_NANOS = 95_000_000L

    const val MIN_CHANGE_DEGREES = 0.5

    /** After a pause longer than this the next reading replaces the filter's state. */
    private const val MAX_GAP_NANOS = 1_000_000_000L
  }
}

/** One raw reading, before smoothing. [accuracyDegrees] is negative when the reading is unreliable. */
internal data class CompassReading(
  val degrees: Double,
  val accuracyDegrees: Double,
  val isTrueNorth: Boolean,
  val timestampNanos: Long,
)

/** The compass hardware, behind a seam so [CompassFeed] is tested with a fake. Main thread only. */
internal interface CompassProvider {
  /** Whether this device has a compass at all. */
  val isAvailable: Boolean

  /** Where the visitor is, for true north; `null` gives magnetic north. */
  var location: MsgCoordinate?

  /** Told each reading, on the main thread. */
  var onReading: ((CompassReading) -> Unit)?

  fun start()

  fun stop()
}

/** Whether the app is in the foreground, and when that changes. A seam so a test drives it. */
internal interface AppForeground {
  val isInForeground: Boolean

  /** Calls [onChange] on every change, on the main thread. */
  fun observe(onChange: (Boolean) -> Unit)
}

/** [AppForeground] on `ProcessLifecycleOwner`: in the foreground while the process is STARTED. */
internal class ProcessAppForeground : AppForeground {
  private val lifecycle: Lifecycle get() = ProcessLifecycleOwner.get().lifecycle

  override val isInForeground: Boolean get() = lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)

  override fun observe(onChange: (Boolean) -> Unit) {
    lifecycle.addObserver(
      object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) = onChange(true)

        override fun onStop(owner: LifecycleOwner) = onChange(false)
      },
    )
  }
}

/**
 * [CompassProvider] on `SensorManager`.
 *
 * - **Sensor:** `TYPE_ROTATION_VECTOR`, else `TYPE_GEOMAGNETIC_ROTATION_VECTOR`, at
 *   `SENSOR_DELAY_GAME` (about 50 Hz) so the filter has enough readings for 10 Hz output.
 * - **Azimuth:** rotation matrix, remapped for the display rotation so 0° is the top of the screen,
 *   then `getOrientation`.
 * - **True north:** the magnetic azimuth plus `GeomagneticField.declination` at [location].
 * - **Accuracy:** the rotation vector's own estimate when it gives one, else the event's status
 *   ([accuracyDegrees]).
 *
 * @see proximiio-android-map-v6/proximiio-map-live/src/main/kotlin/io/proximi/map/live/MapCompass.kt
 */
internal class SensorCompass(context: Context) : CompassProvider, SensorEventListener, DisplayManager.DisplayListener {
  private val context = context.applicationContext
  private val manager: SensorManager? = this.context.getSystemService(SensorManager::class.java)
  private val displays: DisplayManager? = this.context.getSystemService(DisplayManager::class.java)
  private val sensor: Sensor? =
    manager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
      ?: manager?.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
  private val handler = Handler(Looper.getMainLooper())
  private val rotation = FloatArray(9)
  private val remapped = FloatArray(9)
  private val angles = FloatArray(3)
  private var isRunning = false
  private var displayRotation = Surface.ROTATION_0
  private var declinationKey: Pair<Long, Long>? = null
  private var declination = 0.0

  override var location: MsgCoordinate? = null
  override var onReading: ((CompassReading) -> Unit)? = null
  override val isAvailable: Boolean get() = sensor != null

  override fun start() {
    val target = sensor ?: return
    if (isRunning) return
    isRunning = true
    readDisplayRotation()
    displays?.registerDisplayListener(this, handler)
    manager?.registerListener(this, target, SensorManager.SENSOR_DELAY_GAME, handler)
  }

  override fun stop() {
    if (!isRunning) return
    isRunning = false
    manager?.unregisterListener(this)
    displays?.unregisterDisplayListener(this)
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

  override fun onSensorChanged(event: SensorEvent) {
    if (!isRunning) return
    SensorManager.getRotationMatrixFromVector(rotation, event.values)
    val (axisX, axisY) = remapAxes(displayRotation)
    SensorManager.remapCoordinateSystem(rotation, axisX, axisY, remapped)
    SensorManager.getOrientation(remapped, angles)
    val magnetic = normalizedDegrees(Math.toDegrees(angles[0].toDouble()))
    val coordinate = location
    val degrees = if (coordinate != null) normalizedDegrees(magnetic + declinationAt(coordinate)) else magnetic
    onReading?.invoke(
      CompassReading(
        degrees = degrees,
        accuracyDegrees = accuracyDegrees(event.values, event.accuracy),
        isTrueNorth = coordinate != null,
        timestampNanos = event.timestamp,
      ),
    )
  }

  override fun onDisplayAdded(displayId: Int) = Unit

  override fun onDisplayRemoved(displayId: Int) = Unit

  override fun onDisplayChanged(displayId: Int) {
    if (displayId == Display.DEFAULT_DISPLAY) readDisplayRotation()
  }

  private fun readDisplayRotation() {
    displayRotation = displays?.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: Surface.ROTATION_0
  }

  /** The declination at [coordinate], recomputed only when the visitor moved about a kilometre. */
  private fun declinationAt(coordinate: MsgCoordinate): Double {
    val key = (coordinate.latitude * 100).roundToLong() to (coordinate.longitude * 100).roundToLong()
    if (key != declinationKey) {
      declinationKey = key
      declination = GeomagneticField(
        coordinate.latitude.toFloat(),
        coordinate.longitude.toFloat(),
        0f,
        System.currentTimeMillis(),
      ).declination.toDouble()
    }
    return declination
  }

  internal companion object {
    private const val ACCURACY_INDEX = 4
    const val HIGH_ACCURACY_DEGREES = 10.0
    const val MEDIUM_ACCURACY_DEGREES = 20.0
    const val LOW_ACCURACY_DEGREES = 40.0

    /**
     * The ± error of a rotation-vector event in degrees, or `-1` when the sensor says it is
     * unreliable. The sensor's own estimate wins over its status when it gives one.
     */
    fun accuracyDegrees(values: FloatArray, status: Int): Double {
      if (status <= SensorManager.SENSOR_STATUS_UNRELIABLE) return -1.0
      val estimate = values.getOrNull(ACCURACY_INDEX)?.toDouble()
      if (estimate != null && estimate.isFinite() && estimate > 0) return Math.toDegrees(estimate)
      return when (status) {
        SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> HIGH_ACCURACY_DEGREES
        SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> MEDIUM_ACCURACY_DEGREES
        else -> LOW_ACCURACY_DEGREES
      }
    }

    /** The `remapCoordinateSystem` axes that put 0° at the top of a display rotated by [rotation]. */
    fun remapAxes(rotation: Int): Pair<Int, Int> = when (rotation) {
      Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
      Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
      Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
      else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
    }
  }
}

/**
 * Runs the compass while it is wanted and passes smoothed readings on.
 *
 * On while [isEnabled] (Dart listens), the app is in the foreground and the device has a compass.
 * Unreliable readings (negative accuracy) are dropped, as iOS drops a negative `headingAccuracy`.
 * Every start begins a fresh filter. Main thread only.
 */
internal class CompassFeed(
  private val provider: CompassProvider,
  foreground: AppForeground,
  private val clock: () -> Long = System::currentTimeMillis,
  private val elapsedNanos: () -> Long = SystemClock::elapsedRealtimeNanos,
) {
  private val smoother = CompassSmoother()

  /** Told each smoothed reading. */
  var onHeading: ((MsgCompassHeading) -> Unit)? = null

  /** Whether Dart listens. */
  var isEnabled: Boolean = false
    set(value) {
      if (field == value) return
      field = value
      update()
    }

  /** Where the visitor last was, for true north. */
  var location: MsgCoordinate?
    get() = provider.location
    set(value) {
      provider.location = value
    }

  var isInForeground: Boolean = foreground.isInForeground
    private set

  var isRunning: Boolean = false
    private set

  init {
    provider.onReading = { reading -> receive(reading) }
    foreground.observe { inForeground ->
      isInForeground = inForeground
      update()
    }
  }

  private fun update() {
    val wanted = isEnabled && isInForeground && provider.isAvailable
    if (wanted == isRunning) return
    isRunning = wanted
    if (wanted) {
      smoother.reset()
      provider.start()
    } else {
      provider.stop()
    }
  }

  private fun receive(reading: CompassReading) {
    // A reading delivered after a stop is from the run that ended.
    if (!isRunning) return
    if (reading.accuracyDegrees < 0 || !reading.accuracyDegrees.isFinite() || !reading.degrees.isFinite()) return
    val output = smoother.add(reading.degrees, reading.accuracyDegrees, reading.isTrueNorth, reading.timestampNanos)
      ?: return
    // The sensor's clock is the boot clock; Dart gets wall time.
    val ageMs = ((elapsedNanos() - reading.timestampNanos) / 1_000_000L).coerceAtLeast(0L)
    onHeading?.invoke(
      MsgCompassHeading(
        degrees = output.degrees,
        accuracyDegrees = output.accuracyDegrees,
        isTrueNorth = output.isTrueNorth,
        timestampMs = clock() - ageMs,
      ),
    )
  }
}
