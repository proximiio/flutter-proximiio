package io.proximi.flutter_proximiio

import android.hardware.SensorManager
import android.view.Surface
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private const val MS = 1_000_000L

class CompassSmootherTest {
  @Test
  fun `the first reading is passed on as it is`() {
    val output = CompassSmoother().add(42.0, 10.0, isTrueNorth = false, timestampNanos = 0)
    assertNotNull(output)
    assertEquals(42.0, output.degrees, 1e-9)
    assertEquals(10.0, output.accuracyDegrees)
    assertFalse(output.isTrueNorth)
  }

  @Test
  fun `readings closer than the interval are held back`() {
    val smoother = CompassSmoother()
    smoother.add(0.0, 10.0, false, 0)
    assertNull(smoother.add(90.0, 10.0, false, 20 * MS))
    assertNull(smoother.add(90.0, 10.0, false, 80 * MS))
    assertNotNull(smoother.add(90.0, 10.0, false, 100 * MS))
  }

  @Test
  fun `a turn is followed smoothly and settles on the new heading`() {
    val smoother = CompassSmoother()
    smoother.add(0.0, 10.0, false, 0)
    val outputs = (1..50).mapNotNull { step -> smoother.add(90.0, 10.0, false, step * 20 * MS) }
    // At most 10 Hz from 50 Hz input over one second, fewer once the turn settles.
    assertTrue(outputs.size in 5..10, "outputs: ${outputs.size}")
    // Monotonic towards 90°, no overshoot, and close to it after a second.
    outputs.zipWithNext().forEach { (a, b) -> assertTrue(b.degrees >= a.degrees) }
    assertTrue(outputs.first().degrees < 80.0)
    assertEquals(90.0, outputs.last().degrees, 1.0)
  }

  @Test
  fun `the filter averages across north`() {
    val smoother = CompassSmoother()
    smoother.add(350.0, 10.0, false, 0)
    val outputs = (1..100).mapNotNull { step -> smoother.add(10.0, 10.0, false, step * 20 * MS) }
    // Through 0°, not back through 180°: every value stays within 10° of north.
    outputs.forEach { assertTrue(angleBetween(it.degrees, 0.0) <= 10.0 + 1e-9, "${it.degrees}") }
    assertEquals(10.0, outputs.last().degrees, 0.6)
  }

  @Test
  fun `a phone lying still sends nothing new`() {
    val smoother = CompassSmoother()
    smoother.add(120.0, 10.0, false, 0)
    val outputs = (1..50).mapNotNull { step -> smoother.add(120.0 + (step % 2) * 0.1, 10.0, false, step * 20 * MS) }
    assertTrue(outputs.isEmpty())
  }

  @Test
  fun `a change of accuracy or of north is passed on`() {
    val smoother = CompassSmoother()
    smoother.add(120.0, 10.0, false, 0)
    assertEquals(20.0, smoother.add(120.0, 20.0, false, 100 * MS)?.accuracyDegrees)
    assertEquals(true, smoother.add(120.0, 20.0, true, 200 * MS)?.isTrueNorth)
  }

  @Test
  fun `reset starts over`() {
    val smoother = CompassSmoother()
    smoother.add(0.0, 10.0, false, 0)
    smoother.reset()
    assertEquals(200.0, smoother.add(200.0, 10.0, false, 1 * MS)?.degrees ?: -1.0, 1e-9)
  }

  @Test
  fun `angles wrap`() {
    assertEquals(350.0, normalizedDegrees(-10.0), 1e-9)
    assertEquals(0.0, normalizedDegrees(360.0), 1e-9)
    assertEquals(20.0, angleBetween(350.0, 10.0), 1e-9)
    assertEquals(180.0, angleBetween(0.0, 180.0), 1e-9)
  }
}

class SensorCompassTest {
  @Test
  fun `accuracy from the estimate, else from the status, negative when unreliable`() {
    val estimate = floatArrayOf(0f, 0f, 0f, 1f, Math.toRadians(15.0).toFloat())
    assertEquals(15.0, SensorCompass.accuracyDegrees(estimate, SensorManager.SENSOR_STATUS_ACCURACY_LOW), 1e-4)
    val noEstimate = floatArrayOf(0f, 0f, 0f, 1f)
    assertEquals(10.0, SensorCompass.accuracyDegrees(noEstimate, SensorManager.SENSOR_STATUS_ACCURACY_HIGH))
    assertEquals(20.0, SensorCompass.accuracyDegrees(noEstimate, SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM))
    assertEquals(40.0, SensorCompass.accuracyDegrees(noEstimate, SensorManager.SENSOR_STATUS_ACCURACY_LOW))
    assertEquals(-1.0, SensorCompass.accuracyDegrees(estimate, SensorManager.SENSOR_STATUS_UNRELIABLE))
  }

  @Test
  fun `the axes follow the display rotation`() {
    assertEquals(SensorManager.AXIS_X to SensorManager.AXIS_Y, SensorCompass.remapAxes(Surface.ROTATION_0))
    assertEquals(SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X, SensorCompass.remapAxes(Surface.ROTATION_90))
    assertEquals(
      SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y,
      SensorCompass.remapAxes(Surface.ROTATION_180),
    )
    assertEquals(SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X, SensorCompass.remapAxes(Surface.ROTATION_270))
  }
}

private class FakeProvider(override val isAvailable: Boolean = true) : CompassProvider {
  override var location: MsgCoordinate? = null
  override var onReading: ((CompassReading) -> Unit)? = null
  var running = false
  var starts = 0

  override fun start() {
    running = true
    starts++
  }

  override fun stop() {
    running = false
  }

  fun deliver(degrees: Double, accuracy: Double = 10.0, atMs: Long = 0) =
    onReading?.invoke(CompassReading(degrees, accuracy, location != null, atMs * MS))
}

private class FakeForeground(override var isInForeground: Boolean = true) : AppForeground {
  var onChange: ((Boolean) -> Unit)? = null

  override fun observe(onChange: (Boolean) -> Unit) {
    this.onChange = onChange
  }

  fun post(inForeground: Boolean) {
    isInForeground = inForeground
    onChange?.invoke(inForeground)
  }
}

class CompassFeedTest {
  private val provider = FakeProvider()
  private val foreground = FakeForeground()
  private val headings = mutableListOf<MsgCompassHeading>()

  private fun feed(provider: CompassProvider = this.provider) =
    CompassFeed(provider, foreground, clock = { 10_000L }, elapsedNanos = { 500 * MS }).also { made ->
      made.onHeading = { headings += it }
    }

  @Test
  fun `runs only while enabled and in the foreground`() {
    val feed = feed()
    assertFalse(provider.running)
    feed.isEnabled = true
    assertTrue(provider.running)
    foreground.post(false)
    assertFalse(provider.running)
    foreground.post(true)
    assertTrue(provider.running)
    feed.isEnabled = false
    assertFalse(provider.running)
    assertEquals(2, provider.starts)
  }

  @Test
  fun `a device without a compass never starts`() {
    val missing = FakeProvider(isAvailable = false)
    val feed = feed(missing)
    feed.isEnabled = true
    assertFalse(missing.running)
    assertFalse(feed.isRunning)
  }

  @Test
  fun `readings become messages with wall time, and unreliable and late ones are dropped`() {
    val feed = feed()
    feed.isEnabled = true
    provider.deliver(30.0, accuracy = -1.0, atMs = 0)
    assertTrue(headings.isEmpty())
    provider.deliver(30.0, atMs = 400)
    val heading = headings.single()
    assertEquals(30.0, heading.degrees, 1e-9)
    assertEquals(10.0, heading.accuracyDegrees)
    assertFalse(heading.isTrueNorth)
    // Taken 100 ms before "now" (500 ms boot time, 10 000 ms wall time).
    assertEquals(9_900L, heading.timestampMs)

    feed.isEnabled = false
    provider.deliver(60.0, atMs = 600)
    assertEquals(1, headings.size)
  }

  @Test
  fun `a location gives true north, and every start begins a fresh filter`() {
    val feed = feed()
    feed.location = MsgCoordinate(latitude = 60.17, longitude = 24.94)
    feed.isEnabled = true
    provider.deliver(100.0, atMs = 0)
    assertTrue(headings.last().isTrueNorth)
    feed.isEnabled = false
    feed.isEnabled = true
    provider.deliver(250.0, atMs = 10)
    assertEquals(250.0, headings.last().degrees, 1e-9)
  }
}
