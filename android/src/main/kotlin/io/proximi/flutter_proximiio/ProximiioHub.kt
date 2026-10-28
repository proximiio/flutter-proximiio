package io.proximi.flutter_proximiio

import android.Manifest
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.proximi.sdk.Proximiio
import io.proximi.sdk.ProximiioConfiguration
import io.proximi.sdk.beaconEvents
import io.proximi.sdk.core.logging.ProximiioLogEntry
import io.proximi.sdk.core.logging.ProximiioLogLevel
import io.proximi.sdk.core.platform.PermissionStatus
import io.proximi.sdk.floorChanges
import io.proximi.sdk.syncEvents
import io.proximi.sdk.venueDataChanges
import io.proximi.sdk.geofenceEvents
import io.proximi.sdk.pdrObservations
import io.proximi.sdk.permissionUpdates
import io.proximi.sdk.positions
import io.proximi.sdk.privacyZoneStateChanges
import io.proximi.sdk.refreshPermissions
import io.proximi.sdk.service.NotificationMode
import io.proximi.sdk.service.ProximiioServiceOptions
import io.proximi.sdk.setPermissionLauncher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withTimeoutOrNull

/** The current sink of one event channel; `null` while Dart is not listening. */
internal class EventBox<T> {
  var sink: PigeonEventSink<T>? = null

  fun send(value: T) {
    sink?.success(value)
  }
}

internal class StateChangesRelay : StateChangesStreamHandler() {
  val box = EventBox<MsgStateChange>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgStateChange>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class PermissionUpdatesRelay : PermissionUpdatesStreamHandler() {
  val box = EventBox<MsgPermissionStatus>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgPermissionStatus>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class PositionsRelay : PositionsStreamHandler() {
  val box = EventBox<MsgPositionUpdate>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgPositionUpdate>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class FloorChangesRelay : FloorChangesStreamHandler() {
  val box = EventBox<MsgFloorChange>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgFloorChange>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class GeofenceEventsRelay : GeofenceEventsStreamHandler() {
  val box = EventBox<MsgGeofenceEvent>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgGeofenceEvent>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class PrivacyZoneStateChangesRelay : PrivacyZoneStateChangesStreamHandler() {
  val box = EventBox<MsgPrivacyZoneState>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgPrivacyZoneState>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class VenueDataChangesRelay : VenueDataChangesStreamHandler() {
  val box = EventBox<MsgVenueDataChange>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgVenueDataChange>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class SyncEventsRelay : SyncEventsStreamHandler() {
  val box = EventBox<MsgSyncEvent>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgSyncEvent>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class BeaconEventsRelay : BeaconEventsStreamHandler() {
  val box = EventBox<MsgBeaconEvent>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgBeaconEvent>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

internal class PdrObservationsRelay : PdrObservationsStreamHandler() {
  val box = EventBox<MsgPdrUpdate>()
  override fun onListen(p0: Any?, sink: PigeonEventSink<MsgPdrUpdate>) { box.sink = sink }
  override fun onCancel(p0: Any?) { box.sink = null }
}

/** The event channels of one Flutter engine. */
internal class EngineStreams(messenger: BinaryMessenger) {
  val stateChanges = StateChangesRelay()
  val permissionUpdates = PermissionUpdatesRelay()
  val positions = PositionsRelay()
  val floorChanges = FloorChangesRelay()
  val geofenceEvents = GeofenceEventsRelay()
  val privacyZoneStateChanges = PrivacyZoneStateChangesRelay()
  val venueDataChanges = VenueDataChangesRelay()
  val syncEvents = SyncEventsRelay()
  val beaconEvents = BeaconEventsRelay()
  val pdrObservations = PdrObservationsRelay()

  init {
    StateChangesStreamHandler.register(messenger, stateChanges)
    PermissionUpdatesStreamHandler.register(messenger, permissionUpdates)
    PositionsStreamHandler.register(messenger, positions)
    FloorChangesStreamHandler.register(messenger, floorChanges)
    GeofenceEventsStreamHandler.register(messenger, geofenceEvents)
    PrivacyZoneStateChangesStreamHandler.register(messenger, privacyZoneStateChanges)
    VenueDataChangesStreamHandler.register(messenger, venueDataChanges)
    SyncEventsStreamHandler.register(messenger, syncEvents)
    BeaconEventsStreamHandler.register(messenger, beaconEvents)
    PdrObservationsStreamHandler.register(messenger, pdrObservations)
  }
}

/**
 * Owns the process-wide SDK instance and fans its streams out to every attached engine.
 *
 * One instance per process: it is also stored in `Proximiio.shared`, where the
 * flutter_proximiio_map plugin picks it up. Everything here runs on the main thread.
 */
internal object ProximiioHub {
  private const val TAG = "FlutterProximiio"

  /** How long the forwarders get to deliver the exits `stop()` reports before they are cancelled. */
  private const val STREAM_DRAIN_MS = 1_000L

  val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  val permissionLauncher = FlutterPermissionLauncher()

  /** Serialises configure, authenticate, start, stop and sign-out, which each engine may call. */
  val lifecycle = Mutex()

  var sdk: Proximiio? = null
    private set

  /** The configured foreground-service options; `null` when the SDK runs no service. */
  var serviceOptions: ProximiioServiceOptions? = null
    private set

  /**
   * Whether the SDK runs its foreground service (and shows its notification, so the plugin asks for
   * POST_NOTIFICATIONS); `mode: disabled` runs none.
   */
  val runsService: Boolean
    get() = serviceOptions.let { it != null && it.notificationMode != NotificationMode.DISABLED }

  /** Whether the configuration scans BLE beacons or UWB anchors, so the plugin asks for Nearby devices. */
  var usesBluetooth: Boolean = false
    private set

  private val engines = mutableListOf<EngineStreams>()
  private var permissionJob: Job? = null
  private var runJobs: List<Job> = emptyList()
  private var prompts: PluginPrompts? = null

  fun attach(engine: EngineStreams) {
    engines += engine
  }

  /** Removes [engine]; `true` when no engine is left. */
  fun detach(engine: EngineStreams): Boolean {
    engines -= engine
    return engines.isEmpty()
  }

  /**
   * Creates the SDK instance and replaces the previous one. The previous instance is stopped first,
   * with its streams still forwarded so the exits `stop()` reports reach Dart. When the new instance
   * cannot be created, the previous one stays (stopped). Call it holding [lifecycle].
   */
  suspend fun configure(context: Context, configuration: ProximiioConfiguration) {
    sdk?.let { previous -> stopAndDrain(previous) }
    val sdk = Proximiio(context.applicationContext, configuration)
    cancelRunStreams()
    permissionJob?.cancel()
    this.sdk = sdk
    Proximiio.shared = sdk
    serviceOptions = configuration.serviceOptions
    usesBluetooth = configuration.positioning.let {
      it.iBeaconScanningEnabled || it.eddystoneScanningEnabled || it.trilateration.uwbEnabled
    }
    prompts = PluginPrompts(context)
    sdk.setPermissionLauncher(permissionLauncher)
    permissionJob = forward(sdk.permissionUpdates().map(::permissionStatus)) { it.permissionUpdates.box }
    publishState()
  }

  /** The SDK has no state stream, so the bridge publishes the state after each lifecycle call it makes. */
  suspend fun publishState() {
    val sdk = sdk ?: return
    val change = MsgStateChange(state = Mappers.state(sdk.state()))
    engines.forEach { it.stateChanges.box.send(change) }
  }

  /**
   * Takes the SDK's run-scoped streams unless they are still open. They are taken before `start()`,
   * so the events `start()` itself emits are not missed, and they finish at `stop()`; a `start()` of a
   * running SDK keeps the ones it has.
   */
  fun ensureRunStreams() {
    val sdk = sdk ?: return
    if (runJobs.isNotEmpty() && runJobs.all { it.isActive }) return
    cancelRunStreams()
    runJobs = listOf(
      forward(sdk.positions().map(Mappers::position)) { it.positions.box },
      forward(sdk.floorChanges().map(Mappers::floorChange)) { it.floorChanges.box },
      forward(sdk.geofenceEvents().map(Mappers::geofenceEvent)) { it.geofenceEvents.box },
      forward(sdk.privacyZoneStateChanges().map(Mappers::privacyZoneState)) { it.privacyZoneStateChanges.box },
      forward(sdk.venueDataChanges().map(VenueMappers::venueDataChange)) { it.venueDataChanges.box },
      forward(sdk.syncEvents().map(VenueMappers::syncEvent)) { it.syncEvents.box },
      forward(sdk.beaconEvents().map(VenueMappers::beaconEvent)) { it.beaconEvents.box },
      forward(sdk.pdrObservations().map(Mappers::pdrUpdate)) { it.pdrObservations.box },
    )
  }

  /**
   * Stops [sdk]. When it was running, `stop()` completes its streams after the exits it reports, and
   * the forwarders are given time to deliver them; the streams of an SDK that was not running stay
   * open for its next start.
   */
  suspend fun stopAndDrain(sdk: Proximiio) {
    val wasRunning = sdk.state().let { it == Proximiio.State.RUNNING || it == Proximiio.State.STARTING }
    sdk.stop()
    if (!wasRunning) return
    withTimeoutOrNull(STREAM_DRAIN_MS) { runJobs.joinAll() }
    cancelRunStreams()
  }

  fun cancelRunStreams() {
    runJobs.forEach { it.cancel() }
    runJobs = emptyList()
  }

  /** The SDK's status, with Bluetooth read as denied once the plugin asked for it and got no grant. */
  fun permissionStatus(status: PermissionStatus): MsgPermissionStatus {
    val message = Mappers.permissionStatus(status)
    val askedBluetooth = prompts?.wasAsked(Manifest.permission.BLUETOOTH_SCAN) == true
    return if (message.bluetooth == MsgBluetoothAuthorization.NOT_DETERMINED && askedBluetooth) {
      message.copy(bluetooth = MsgBluetoothAuthorization.DENIED)
    } else {
      message
    }
  }

  /** Records that the plugin asked for [permissions] (the SDK keeps its own record for the ones it asks). */
  fun markAsked(permissions: List<String>) {
    prompts?.markAsked(permissions)
  }

  fun wasAsked(permission: String): Boolean = prompts?.wasAsked(permission) == true

  /** Re-reads the permissions; Android reports no change made in the system settings by itself. */
  fun refreshPermissions() {
    val sdk = sdk ?: return
    scope.launch { runCatching { sdk.refreshPermissions() } }
  }

  /** Writes SDK log entries to Logcat at [level] and above; the Android SDK writes none there itself. */
  fun setLogLevel(level: ProximiioLogLevel) {
    Proximiio.logLevel = level
    if (Proximiio.logSink == null) Proximiio.logSink = logcat
  }

  private val logcat: (ProximiioLogEntry) -> Unit = { entry ->
    val priority = when (entry.level) {
      ProximiioLogLevel.DEBUG -> Log.DEBUG
      ProximiioLogLevel.INFO, ProximiioLogLevel.NOTICE -> Log.INFO
      ProximiioLogLevel.WARNING -> Log.WARN
      ProximiioLogLevel.ERROR -> Log.ERROR
    }
    Log.println(priority, "Proximiio", "[${entry.category}] ${entry.message}")
  }

  private fun <M> forward(flow: Flow<M>, box: (EngineStreams) -> EventBox<M>): Job =
    scope.launch {
      flow
        .catch { error -> Log.w(TAG, "SDK stream failed", error) }
        .collect { message -> engines.forEach { box(it).send(message) } }
    }
}

/**
 * The permissions the plugin asked for itself (Nearby devices, notifications). Android reports a
 * permission that was never asked the same way as a denied one; the SDK keeps this record for the
 * permissions it asks, and the plugin keeps it for the rest.
 */
internal class PluginPrompts(context: Context) {
  private val preferences = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

  fun wasAsked(permission: String): Boolean = preferences.getBoolean(permission, false)

  fun markAsked(permissions: List<String>) {
    val editor = preferences.edit()
    permissions.forEach { editor.putBoolean(it, true) }
    editor.apply()
  }

  private companion object {
    const val FILE = "io.proximi.flutter_proximiio.permissions"
  }
}
