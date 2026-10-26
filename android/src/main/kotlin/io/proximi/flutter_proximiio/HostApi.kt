package io.proximi.flutter_proximiio

import android.Manifest
import android.app.Notification
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.proximi.sdk.Proximiio
import io.proximi.sdk.amenities
import io.proximi.sdk.core.platform.PermissionStatus
import io.proximi.sdk.application
import io.proximi.sdk.computeRoute
import io.proximi.sdk.currentFloor
import io.proximi.sdk.departments
import io.proximi.sdk.diagnostics
import io.proximi.sdk.disablePdr
import io.proximi.sdk.disableRouteSnapping
import io.proximi.sdk.enablePdr
import io.proximi.sdk.enableRouteSnapping
import io.proximi.sdk.enteredGeofenceIds
import io.proximi.sdk.features
import io.proximi.sdk.fetchJourney
import io.proximi.sdk.floor
import io.proximi.sdk.floors
import io.proximi.sdk.geofences
import io.proximi.sdk.installOfflineSeed
import io.proximi.sdk.isInPrivacyZone
import io.proximi.sdk.journeys
import io.proximi.sdk.jumpToWaypoint
import io.proximi.sdk.lastPosition
import io.proximi.sdk.loadCachedRouteNetwork
import io.proximi.sdk.loadRouteNetwork
import io.proximi.sdk.mapStyle
import io.proximi.sdk.offline.PackagePolicy
import io.proximi.sdk.offlinePackageDiskUsage
import io.proximi.sdk.offlinePackageState
import io.proximi.sdk.pauseSimulation
import io.proximi.sdk.place
import io.proximi.sdk.places
import io.proximi.sdk.prepareDiagnosticsReport
import io.proximi.sdk.privacyZones
import io.proximi.sdk.refreshPermissions
import io.proximi.sdk.removeOfflinePackage
import io.proximi.sdk.requestMotionPermission
import io.proximi.sdk.requestPermissions
import io.proximi.sdk.resetServiceNotification
import io.proximi.sdk.resumeSimulation
import io.proximi.sdk.routeDurations
import io.proximi.sdk.service.ProximiioServiceOptions
import io.proximi.sdk.setPositioningSourcePrivate
import io.proximi.sdk.simulatePosition
import io.proximi.sdk.startDiagnosticsRecording
import io.proximi.sdk.startSimulation
import io.proximi.sdk.stopDiagnosticsRecording
import io.proximi.sdk.stopSimulation
import io.proximi.sdk.syncOfflinePackage
import io.proximi.sdk.updateServiceNotification
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Handles the Dart → native calls. Every call starts on the main thread and suspends on the SDK;
 * synchronous file, database and route-graph work runs on a background dispatcher.
 */
internal class HostApi(private val context: Context) : ProximiioHostApi {

  private fun <T> run(callback: (Result<T>) -> Unit, body: suspend (Proximiio) -> T) {
    ProximiioHub.scope.launch {
      callback(result { body(ProximiioHub.sdk ?: throw Mappers.notConfigured()) })
    }
  }

  /**
   * A lifecycle call: one at a time across all engines, on the instance current when its turn comes
   * (a `start()` queued behind `configure()` starts the new instance).
   */
  private fun <T> runLifecycle(callback: (Result<T>) -> Unit, body: suspend (Proximiio) -> T) {
    ProximiioHub.scope.launch {
      callback(ProximiioHub.lifecycle.withLock { result { body(ProximiioHub.sdk ?: throw Mappers.notConfigured()) } })
    }
  }

  private suspend fun <T> result(body: suspend () -> T): Result<T> =
    try {
      Result.success(body())
    } catch (error: CancellationException) {
      throw error
    } catch (error: Throwable) {
      Result.failure(Mappers.flutterError(error))
    }

  override fun configure(configuration: MsgConfiguration, callback: (Result<Unit>) -> Unit) {
    ProximiioHub.scope.launch {
      callback(
        ProximiioHub.lifecycle.withLock {
          result { ProximiioHub.configure(context, Mappers.configuration(configuration, context)) }
        },
      )
    }
  }

  override fun isConfigured(): Boolean = ProximiioHub.sdk != null

  override fun state(callback: (Result<MsgSdkState>) -> Unit) =
    run(callback) { Mappers.state(it.state()) }

  /**
   * Location (and background location with [always]) through the SDK, then what the SDK leaves to
   * the host on Android: Nearby devices (API 31+) when the configuration scans beacons and, while the
   * service shows its notification, POST_NOTIFICATIONS (API 33+). Like the SDK, the plugin asks each
   * permission once; iOS decides the same way. Without an activity nothing is asked, because the SDK
   * would record the unanswered prompt as a denial.
   */
  override fun requestPermissions(always: Boolean, callback: (Result<MsgPermissionStatus>) -> Unit) =
    run(callback) { sdk ->
      if (!ProximiioHub.permissionLauncher.canPrompt) return@run ProximiioHub.permissionStatus(sdk.refreshPermissions())
      sdk.requestPermissions(always)
      val missing = buildList {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && ProximiioHub.usesBluetooth) {
          add(Manifest.permission.BLUETOOTH_SCAN)
          add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && ProximiioHub.wantsNotifications) {
          add(Manifest.permission.POST_NOTIFICATIONS)
        }
      }.filter {
        ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED && !ProximiioHub.wasAsked(it)
      }
      if (missing.isNotEmpty() && ProximiioHub.permissionLauncher.canPrompt) {
        ProximiioHub.markAsked(missing)
        ProximiioHub.permissionLauncher.request(missing)
      }
      ProximiioHub.permissionStatus(sdk.refreshPermissions())
    }

  override fun requestMotionPermission(callback: (Result<Boolean>) -> Unit) =
    run(callback) { sdk ->
      if (ProximiioHub.permissionLauncher.canPrompt) {
        sdk.requestMotionPermission()
      } else {
        sdk.refreshPermissions().motion == PermissionStatus.MotionAuthorization.AUTHORIZED
      }
    }

  override fun authenticate(callback: (Result<MsgApplication?>) -> Unit) =
    runLifecycle(callback) { sdk ->
      try {
        sdk.authenticate()?.let(Mappers::application)
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun start(callback: (Result<Unit>) -> Unit) =
    runLifecycle(callback) { sdk ->
      try {
        ProximiioHub.ensureRunStreams()
        sdk.start()
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun stop(callback: (Result<Unit>) -> Unit) =
    runLifecycle(callback) { sdk ->
      ProximiioHub.stopAndDrain(sdk)
      ProximiioHub.publishState()
    }

  override fun signOut(callback: (Result<Unit>) -> Unit) =
    runLifecycle(callback) { sdk ->
      try {
        ProximiioHub.stopAndDrain(sdk)
        sdk.signOut()
      } finally {
        ProximiioHub.publishState()
      }
    }

  override fun sync(callback: (Result<Long>) -> Unit) =
    run(callback) { it.sync().toLong() }

  override fun application(callback: (Result<MsgApplication?>) -> Unit) =
    run(callback) { sdk -> sdk.application()?.let(Mappers::application) }

  override fun places(callback: (Result<List<MsgPlace>>) -> Unit) =
    run(callback) { sdk -> sdk.places().map(Mappers::place) }

  override fun floors(callback: (Result<List<MsgFloor>>) -> Unit) =
    run(callback) { sdk -> sdk.floors().map(Mappers::floor) }

  override fun geofences(callback: (Result<List<MsgZone>>) -> Unit) =
    run(callback) { sdk -> sdk.geofences().map(Mappers::geofence) }

  override fun privacyZones(callback: (Result<List<MsgZone>>) -> Unit) =
    run(callback) { sdk -> sdk.privacyZones().map(Mappers::privacyZone) }

  override fun place(id: String, callback: (Result<MsgPlace?>) -> Unit) =
    run(callback) { sdk -> sdk.place(id)?.let(Mappers::place) }

  override fun floor(id: String, callback: (Result<MsgFloor?>) -> Unit) =
    run(callback) { sdk -> sdk.floor(id)?.let(Mappers::floor) }

  override fun currentFloor(callback: (Result<MsgFloor?>) -> Unit) =
    run(callback) { sdk -> sdk.currentFloor()?.let(Mappers::floor) }

  override fun lastPosition(callback: (Result<MsgPositionUpdate?>) -> Unit) =
    run(callback) { sdk -> sdk.lastPosition()?.let(Mappers::position) }

  override fun enteredGeofenceIds(callback: (Result<List<String>>) -> Unit) =
    run(callback) { sdk -> sdk.enteredGeofenceIds().sorted() }

  override fun isInPrivacyZone(callback: (Result<Boolean>) -> Unit) =
    run(callback) { it.isInPrivacyZone() }

  override fun visitorId(callback: (Result<String>) -> Unit) =
    run(callback) { it.visitorId() }

  override fun resetVisitorId(callback: (Result<String>) -> Unit) =
    run(callback) { it.resetVisitorId() }

  override fun visitorReportingConsent(callback: (Result<Boolean>) -> Unit) =
    run(callback) { it.visitorReportingConsent() }

  override fun setVisitorReportingConsent(granted: Boolean, callback: (Result<Unit>) -> Unit) =
    run(callback) { it.setVisitorReportingConsent(granted) }

  override fun setLogLevel(level: MsgLogLevel) {
    ProximiioHub.setLogLevel(Mappers.logLevel(level))
  }

  override fun updateServiceNotification(options: MsgAndroidServiceOptions, callback: (Result<Boolean>) -> Unit) =
    run(callback) { sdk -> notification(options)?.let(sdk::updateServiceNotification) ?: false }

  override fun resetServiceNotification(callback: (Result<Unit>) -> Unit) =
    run(callback) { it.resetServiceNotification() }

  // region Wayfinding

  /** The Android router is synchronous; it runs off the main thread. */
  override fun computeRoute(
    from: MsgCoordinate,
    fromLevel: Double,
    to: MsgCoordinate,
    toLevel: Double,
    options: MsgRouteOptions,
    callback: (Result<MsgComputedRoute>) -> Unit,
  ) = run(callback) { sdk ->
    withContext(Dispatchers.Default) {
      RouteMappers.route(
        sdk.computeRoute(
          from = RouteMappers.sdkCoordinate(from),
          fromLevel = fromLevel,
          to = RouteMappers.sdkCoordinate(to),
          toLevel = toLevel,
          options = RouteMappers.options(options),
        ),
      )
    }
  }

  override fun routeDurations(
    points: List<MsgRoutePoint>,
    options: MsgRouteOptions,
    callback: (Result<List<MsgDurationRow>>) -> Unit,
  ) = run(callback) { sdk ->
    withContext(Dispatchers.Default) {
      sdk.routeDurations(points.map(RouteMappers::point), RouteMappers.options(options)).map { MsgDurationRow(seconds = it) }
    }
  }

  /** Decoding, storing and building the route graph are synchronous; they run off the main thread. */
  override fun loadRouteNetwork(callback: (Result<Long>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.loadRouteNetwork().toLong() } }

  override fun loadCachedRouteNetwork(callback: (Result<Long>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.loadCachedRouteNetwork().toLong() } }

  // endregion

  // region Venue data

  override fun amenities(callback: (Result<List<MsgAmenity>>) -> Unit) =
    run(callback) { sdk -> sdk.amenities().map(VenueMappers::amenity) }

  override fun features(callback: (Result<List<MsgFeature>>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.Default) { sdk.features().map(VenueMappers::feature) } }

  override fun departments(callback: (Result<List<MsgDepartment>>) -> Unit) =
    run(callback) { sdk -> sdk.departments().map(VenueMappers::department) }

  override fun mapStyle(callback: (Result<String>) -> Unit) =
    run(callback) { it.mapStyle().decodeToString() }

  override fun journeys(callback: (Result<List<MsgJourney>>) -> Unit) =
    run(callback) { sdk -> sdk.journeys().map(VenueMappers::journey) }

  override fun journey(id: String, callback: (Result<MsgJourney>) -> Unit) =
    run(callback) { sdk -> VenueMappers.journey(sdk.fetchJourney(id)) }

  // endregion

  // region Offline packages

  override fun syncOfflinePackage(
    packageId: String,
    place: String?,
    allowsCellular: Boolean,
    callback: (Result<MsgPackageState>) -> Unit,
  ) = run(callback) { sdk ->
    withContext(Dispatchers.IO) {
      VenueMappers.packageState(sdk.syncOfflinePackage(packageId, place, PackagePolicy(allowsCellular = allowsCellular)))
    }
  }

  // Package state, installs and removals read and write the package files synchronously.

  override fun offlinePackageState(packageId: String, callback: (Result<MsgPackageState>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { VenueMappers.packageState(sdk.offlinePackageState(packageId)) } }

  override fun installOfflineSeed(packageId: String, directory: String, callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.installOfflineSeed(packageId, File(directory)) } }

  override fun removeOfflinePackage(packageId: String, callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.removeOfflinePackage(packageId) } }

  override fun offlinePackageDiskUsage(packageId: String, callback: (Result<Long>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.offlinePackageDiskUsage(packageId) } }

  // endregion

  // region Simulation

  override fun simulatePosition(
    coordinate: MsgCoordinate,
    level: Long,
    accuracy: Double,
    callback: (Result<MsgPositionUpdate?>) -> Unit,
  ) = run(callback) { sdk ->
    sdk.simulatePosition(RouteMappers.sdkCoordinate(coordinate), level.toInt(), accuracy)?.let(Mappers::position)
  }

  override fun startSimulation(route: MsgSimulatedRoute, callback: (Result<Unit>) -> Unit) =
    run(callback) { it.startSimulation(VenueMappers.simulatedRoute(route)) }

  override fun pauseSimulation(callback: (Result<Unit>) -> Unit) = run(callback) { it.pauseSimulation() }

  override fun resumeSimulation(callback: (Result<Unit>) -> Unit) = run(callback) { it.resumeSimulation() }

  override fun stopSimulation(callback: (Result<Unit>) -> Unit) = run(callback) { it.stopSimulation() }

  override fun jumpToWaypoint(index: Long, callback: (Result<Unit>) -> Unit) =
    run(callback) { it.jumpToWaypoint(index.toInt()) }

  override fun simulationState(callback: (Result<MsgSimulationState>) -> Unit) =
    run(callback) { VenueMappers.simulationState(it.simulationState()) }

  // endregion

  // region Positioning inputs

  override fun setCustomPosition(
    coordinate: MsgCoordinate,
    accuracy: Double,
    floorId: String?,
    callback: (Result<MsgPositionUpdate?>) -> Unit,
  ) = run(callback) { sdk ->
    val floor = floorId?.let { knownFloor(sdk, it) }
    sdk.setCustomPosition(RouteMappers.sdkCoordinate(coordinate), accuracy, floor)?.let(Mappers::position)
  }

  override fun setFloor(floorId: String?, callback: (Result<MsgFloorChange?>) -> Unit) =
    run(callback) { sdk -> sdk.setFloor(floorId?.let { knownFloor(sdk, it) })?.let(Mappers::floorChange) }

  /** The SDK reads a `null` floor as "keep the current one" or "clear it", so an unknown id fails instead. */
  private suspend fun knownFloor(sdk: Proximiio, id: String) =
    sdk.floor(id) ?: throw Mappers.invalidArgument("No floor with id $id in the venue data.")

  override fun enableRouteSnapping(thresholdMeters: Double?, callback: (Result<Unit>) -> Unit) =
    run(callback) { sdk -> if (thresholdMeters == null) sdk.enableRouteSnapping() else sdk.enableRouteSnapping(thresholdMeters) }

  override fun disableRouteSnapping(callback: (Result<Unit>) -> Unit) = run(callback) { it.disableRouteSnapping() }

  override fun enablePdr(callback: (Result<Unit>) -> Unit) = run(callback) { it.enablePdr() }

  override fun disablePdr(callback: (Result<Unit>) -> Unit) = run(callback) { it.disablePdr() }

  override fun setPositioningSourcePrivate(sinceMs: Long?, callback: (Result<Unit>) -> Unit) =
    run(callback) { it.setPositioningSourcePrivate(sinceMs) }

  // endregion

  // region Diagnostics

  override fun diagnostics(callback: (Result<MsgDiagnostics>) -> Unit) =
    run(callback) { VenueMappers.diagnostics(it.diagnostics()) }

  override fun startDiagnosticsRecording(callback: (Result<Unit>) -> Unit) =
    run(callback) { it.startDiagnosticsRecording() }

  override fun stopDiagnosticsRecording(callback: (Result<Unit>) -> Unit) =
    run(callback) { it.stopDiagnosticsRecording() }

  override fun prepareDiagnosticsReport(callback: (Result<String>) -> Unit) =
    run(callback) { sdk -> withContext(Dispatchers.IO) { sdk.prepareDiagnosticsReport().archiveURL.absolutePath } }

  // endregion

  /**
   * A notification on the SDK's service channel; unset fields keep the configured ones. `null` when
   * the SDK runs no foreground service.
   */
  private fun notification(options: MsgAndroidServiceOptions): Notification? {
    val configured = ProximiioHub.serviceOptions ?: return null
    val service = Mappers.serviceOptions(options, context, configured)
    val icon = if (service.notificationIcon != 0) service.notificationIcon else context.applicationInfo.icon
    return Notification.Builder(context, ProximiioServiceOptions.CHANNEL_ID)
      .setContentTitle(service.notificationTitle)
      .setContentText(service.notificationText)
      .setSmallIcon(icon)
      .setOngoing(true)
      .apply { service.contentIntent?.let(::setContentIntent) }
      .build()
  }
}
