package io.proximi.flutter_proximiio

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.proximi.sdk.Proximiio
import io.proximi.sdk.ProximiioConfiguration
import io.proximi.sdk.beaconEvents
import io.proximi.sdk.floorChanges
import io.proximi.sdk.syncEvents
import io.proximi.sdk.venueDataChanges
import io.proximi.sdk.geofenceEvents
import io.proximi.sdk.permissionUpdates
import io.proximi.sdk.positions
import io.proximi.sdk.privacyZoneStateChanges
import io.proximi.sdk.setPermissionLauncher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch

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

  val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  val permissionLauncher = FlutterPermissionLauncher()

  var sdk: Proximiio? = null
    private set

  /**
   * Whether the foreground service runs with its notification, so the plugin asks for POST_NOTIFICATIONS.
   * The SDK runs no service at all without `serviceOptions`.
   */
  var wantsNotifications: Boolean = false
    private set

  private val engines = mutableListOf<EngineStreams>()
  private var permissionJob: Job? = null
  private var runJobs: List<Job> = emptyList()

  fun attach(engine: EngineStreams) {
    engines += engine
  }

  fun detach(engine: EngineStreams) {
    engines -= engine
  }

  /** Creates the SDK instance, stopping and replacing the previous one. */
  suspend fun configure(context: Context, configuration: ProximiioConfiguration) {
    sdk?.let { previous ->
      cancelRunStreams()
      permissionJob?.cancel()
      previous.stop()
    }
    val sdk = Proximiio(context.applicationContext, configuration)
    this.sdk = sdk
    Proximiio.shared = sdk
    val serviceOptions = configuration.serviceOptions
    wantsNotifications = serviceOptions != null &&
      serviceOptions.notificationMode != io.proximi.sdk.service.NotificationMode.DISABLED
    sdk.setPermissionLauncher(permissionLauncher)
    permissionJob = forward(sdk.permissionUpdates(), Mappers::permissionStatus) { it.permissionUpdates.box }
    publishState()
  }

  /** The SDK has no state stream, so the bridge publishes the state after each lifecycle call it makes. */
  suspend fun publishState() {
    val sdk = sdk ?: return
    val change = MsgStateChange(state = Mappers.state(sdk.state()))
    engines.forEach { it.stateChanges.box.send(change) }
  }

  /** The SDK's streams are run-scoped (they finish at `stop()`), so they are taken again after each `start()`. */
  fun subscribeRunStreams() {
    val sdk = sdk ?: return
    cancelRunStreams()
    runJobs = listOf(
      forward(sdk.positions(), Mappers::position) { it.positions.box },
      forward(sdk.floorChanges(), Mappers::floorChange) { it.floorChanges.box },
      forward(sdk.geofenceEvents(), Mappers::geofenceEvent) { it.geofenceEvents.box },
      forward(sdk.privacyZoneStateChanges(), Mappers::privacyZoneState) { it.privacyZoneStateChanges.box },
      forward(sdk.venueDataChanges(), VenueMappers::venueDataChange) { it.venueDataChanges.box },
      forward(sdk.syncEvents(), VenueMappers::syncEvent) { it.syncEvents.box },
      forward(sdk.beaconEvents(), VenueMappers::beaconEvent) { it.beaconEvents.box },
    )
  }

  fun cancelRunStreams() {
    runJobs.forEach { it.cancel() }
    runJobs = emptyList()
  }

  private fun <T, M> forward(flow: Flow<T>, map: (T) -> M, box: (EngineStreams) -> EventBox<M>): Job =
    scope.launch {
      flow
        .catch { error -> Log.w(TAG, "SDK stream failed", error) }
        .collect { value ->
          val message = map(value)
          engines.forEach { box(it).send(message) }
        }
    }
}
