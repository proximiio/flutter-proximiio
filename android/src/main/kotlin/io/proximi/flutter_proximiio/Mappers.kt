package io.proximi.flutter_proximiio

import android.content.Context
import io.proximi.sdk.PrivacyZoneState
import io.proximi.sdk.Proximiio
import io.proximi.sdk.ProximiioConfiguration
import io.proximi.sdk.ProximiioError
import io.proximi.sdk.core.errors.ProximiioFailure
import io.proximi.sdk.core.logging.ProximiioLogLevel
import io.proximi.sdk.core.model.JsonValue
import io.proximi.sdk.core.model.ProximiioApplication
import io.proximi.sdk.core.model.ProximiioCoordinate
import io.proximi.sdk.core.model.ProximiioFloor
import io.proximi.sdk.core.model.ProximiioGeofence
import io.proximi.sdk.core.model.ProximiioGeometryIssue
import io.proximi.sdk.core.model.ProximiioPlace
import io.proximi.sdk.core.model.ProximiioPrivacyZone
import io.proximi.sdk.core.net.ProximiioAPIError
import io.proximi.sdk.core.platform.PermissionStatus
import io.proximi.sdk.geofencing.GeofenceEvent
import io.proximi.sdk.journey.ProximiioJourneyError
import io.proximi.sdk.offline.OfflinePackageError
import io.proximi.sdk.wayfinding.WayfindingRoutingError
import io.proximi.sdk.positioning.engine.PositionSource
import io.proximi.sdk.positioning.engine.PositionUpdate
import io.proximi.sdk.positioning.floor.FloorChangeDirection
import io.proximi.sdk.positioning.floor.FloorChangeEvent
import io.proximi.sdk.positioning.floor.FloorChangeSource
import io.proximi.sdk.positioning.native.CoreLocationAccuracy
import io.proximi.sdk.service.NotificationMode
import io.proximi.sdk.service.ProximiioServiceOptions
import java.net.URI
import java.util.UUID
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Converts between SDK types and the Pigeon transport types (`Msg*`).
 *
 * Units on the bridge: times are milliseconds since the epoch, durations are seconds,
 * metadata is a JSON string. Outlines are latitude/longitude pairs.
 */
internal object Mappers {

  // region Configuration

  fun configuration(msg: MsgConfiguration, context: Context): ProximiioConfiguration {
    val service = msg.android?.let { serviceOptions(it, context) }
    val preset = when (msg.preset) {
      MsgConfigurationPreset.STANDARD -> ProximiioConfiguration.default(msg.token)
      MsgConfigurationPreset.HIGH_ACCURACY -> ProximiioConfiguration.highAccuracy(msg.token)
      MsgConfigurationPreset.LOW_POWER -> ProximiioConfiguration.lowPower(msg.token)
      MsgConfigurationPreset.RELAY_ONLY -> ProximiioConfiguration.relayOnly(msg.token, serviceOptions = service)
    }
    // barometerEnabled has no Android counterpart; the Android SDK always uses the barometer when present.
    return preset.copy(
      apiBaseURL = msg.apiBaseUrl?.let(::uri) ?: preset.apiBaseURL,
      fallbackAPIBaseURLs = msg.fallbackApiBaseUrls.takeIf { it.isNotEmpty() }?.map(::uri) ?: preset.fallbackAPIBaseURLs,
      syncInterval = msg.syncIntervalSeconds ?: preset.syncInterval,
      customIBeaconUUIDs = msg.customIBeaconUuids.takeIf { it.isNotEmpty() }?.map(::uuid) ?: preset.customIBeaconUUIDs,
      desiredAccuracy = msg.desiredAccuracy?.let(::desiredAccuracy) ?: preset.desiredAccuracy,
      allowsBackgroundLocationUpdates = msg.allowsBackgroundLocationUpdates ?: preset.allowsBackgroundLocationUpdates,
      visitorReportingEnabled = msg.visitorReportingEnabled ?: preset.visitorReportingEnabled,
      positioning = msg.pdrFusionEnabled?.let { preset.positioning.copy(pdrFusionEnabled = it) } ?: preset.positioning,
      serviceOptions = service ?: preset.serviceOptions,
      geofenceExitDelay = msg.geofenceExitDelaySeconds ?: preset.geofenceExitDelay,
      withholdsPositionsInPrivacyZones = msg.withholdsPositionsInPrivacyZones ?: preset.withholdsPositionsInPrivacyZones,
    )
  }

  fun serviceOptions(msg: MsgAndroidServiceOptions, context: Context): ProximiioServiceOptions {
    val defaults = ProximiioServiceOptions()
    return defaults.copy(
      notificationMode = msg.mode?.let(::notificationMode) ?: defaults.notificationMode,
      notificationChannelName = msg.channelName ?: defaults.notificationChannelName,
      notificationChannelDescription = msg.channelDescription ?: defaults.notificationChannelDescription,
      notificationTitle = msg.notificationTitle ?: defaults.notificationTitle,
      notificationText = msg.notificationText ?: defaults.notificationText,
      notificationIcon = msg.notificationIcon?.let { drawable(context, it) } ?: defaults.notificationIcon,
      holdsWakeLock = msg.holdsWakeLock ?: defaults.holdsWakeLock,
    )
  }

  /** A drawable of the host app by name, or the app icon when there is none by that name. */
  fun drawable(context: Context, name: String): Int {
    val id = context.resources.getIdentifier(name, "drawable", context.packageName)
    return if (id != 0) id else context.applicationInfo.icon
  }

  private fun notificationMode(value: MsgServiceNotificationMode): NotificationMode = when (value) {
    MsgServiceNotificationMode.ENABLED -> NotificationMode.ENABLED
    MsgServiceNotificationMode.DISABLED -> NotificationMode.DISABLED
    MsgServiceNotificationMode.REQUIRED -> NotificationMode.REQUIRED
  }

  /** Android has no three-kilometre level; it maps to the coarsest one it has. */
  fun desiredAccuracy(value: MsgDesiredAccuracy): CoreLocationAccuracy = when (value) {
    MsgDesiredAccuracy.BEST_FOR_NAVIGATION -> CoreLocationAccuracy.BEST_FOR_NAVIGATION
    MsgDesiredAccuracy.BEST -> CoreLocationAccuracy.BEST
    MsgDesiredAccuracy.NEAREST_TEN_METERS -> CoreLocationAccuracy.NEAREST_TEN_METERS
    MsgDesiredAccuracy.HUNDRED_METERS -> CoreLocationAccuracy.HUNDRED_METERS
    MsgDesiredAccuracy.KILOMETER, MsgDesiredAccuracy.THREE_KILOMETERS -> CoreLocationAccuracy.KILOMETER
  }

  fun logLevel(value: MsgLogLevel): ProximiioLogLevel = when (value) {
    MsgLogLevel.DEBUG -> ProximiioLogLevel.DEBUG
    MsgLogLevel.INFO -> ProximiioLogLevel.INFO
    MsgLogLevel.NOTICE -> ProximiioLogLevel.NOTICE
    MsgLogLevel.WARNING -> ProximiioLogLevel.WARNING
    MsgLogLevel.ERROR -> ProximiioLogLevel.ERROR
  }

  private fun uri(value: String): URI {
    val uri = runCatching { URI(value) }.getOrNull()
    if (uri == null || uri.scheme == null || uri.host == null) throw invalidArgument("Not an absolute URL: $value")
    return uri
  }

  private fun uuid(value: String): UUID =
    runCatching { UUID.fromString(value) }.getOrElse { throw invalidArgument("Not a UUID: $value") }

  // endregion

  // region Models

  fun coordinate(value: ProximiioCoordinate) = MsgCoordinate(latitude = value.latitude, longitude = value.longitude)

  /** The SDK keeps outlines in GeoJSON order, `[longitude, latitude]`. */
  fun outline(polygon: List<List<Double>>?): List<MsgCoordinate>? =
    polygon?.mapNotNull { point -> if (point.size >= 2) MsgCoordinate(latitude = point[1], longitude = point[0]) else null }

  fun json(value: JsonValue?): String? =
    if (value == null || value == JsonValue.Null) null else jsonElement(value).toString()

  fun jsonElement(value: JsonValue): JsonElement = when (value) {
    JsonValue.Null -> JsonNull
    is JsonValue.Bool -> JsonPrimitive(value.value)
    is JsonValue.Number -> JsonPrimitive(value.value)
    is JsonValue.String -> JsonPrimitive(value.value)
    is JsonValue.Array -> JsonArray(value.value.map(::jsonElement))
    is JsonValue.Object -> JsonObject(value.value.mapValues { jsonElement(it.value) })
  }

  fun application(value: ProximiioApplication) = MsgApplication(id = value.id, name = value.name)

  fun place(value: ProximiioPlace) = MsgPlace(
    id = value.id,
    name = value.name,
    address = value.address,
    tags = value.tags,
    location = value.location?.let(::coordinate),
    metadataJson = json(value.metadata),
  )

  fun floor(value: ProximiioFloor) = MsgFloor(
    id = value.id,
    name = value.name,
    placeId = value.placeId,
    floorId = value.floorId,
    level = value.level,
    anchors = value.anchors.map(::coordinate),
    floorPlanImageUrl = value.floorPlanImageURL,
    metadataJson = json(value.metadata),
  )

  fun geofence(value: ProximiioGeofence) = MsgZone(
    id = value.id,
    name = value.name,
    type = value.type,
    area = value.area?.let(::coordinate),
    radius = value.radius,
    polygon = outline(value.polygon),
    address = value.address,
    placeId = value.placeId,
    departmentId = value.departmentId,
    floorId = value.floorId,
    remoteId = value.remoteId,
    metadataJson = json(value.metadata),
    geometryIssue = value.geometryIssue?.let(::geometryIssue),
  )

  fun privacyZone(value: ProximiioPrivacyZone) = MsgZone(
    id = value.id,
    name = value.name,
    type = value.type,
    area = value.area?.let(::coordinate),
    radius = value.radius,
    polygon = outline(value.polygon),
    address = value.address,
    placeId = value.placeId,
    departmentId = value.departmentId,
    floorId = value.floorId,
    remoteId = null,
    metadataJson = json(value.metadata),
    geometryIssue = value.geometryIssue?.let(::geometryIssue),
  )

  /** Same strings as the iOS raw values. */
  private fun geometryIssue(value: ProximiioGeometryIssue): String = when (value) {
    ProximiioGeometryIssue.UNREADABLE_AREA -> "unreadableArea"
    ProximiioGeometryIssue.DEGENERATE_OUTLINE -> "degenerateOutline"
  }

  fun permissionStatus(value: PermissionStatus) = MsgPermissionStatus(
    location = when (value.location) {
      PermissionStatus.LocationAuthorization.NOT_DETERMINED -> MsgLocationAuthorization.NOT_DETERMINED
      PermissionStatus.LocationAuthorization.WHEN_IN_USE -> MsgLocationAuthorization.WHEN_IN_USE
      PermissionStatus.LocationAuthorization.ALWAYS -> MsgLocationAuthorization.ALWAYS
      PermissionStatus.LocationAuthorization.DENIED -> MsgLocationAuthorization.DENIED
      PermissionStatus.LocationAuthorization.RESTRICTED -> MsgLocationAuthorization.RESTRICTED
    },
    accuracy = when (value.accuracy) {
      PermissionStatus.LocationAccuracy.FULL -> MsgLocationAccuracy.FULL
      PermissionStatus.LocationAccuracy.REDUCED -> MsgLocationAccuracy.REDUCED
    },
    bluetooth = when (value.bluetooth) {
      PermissionStatus.BluetoothAuthorization.NOT_DETERMINED -> MsgBluetoothAuthorization.NOT_DETERMINED
      PermissionStatus.BluetoothAuthorization.ALLOWED -> MsgBluetoothAuthorization.ALLOWED
      PermissionStatus.BluetoothAuthorization.DENIED -> MsgBluetoothAuthorization.DENIED
      PermissionStatus.BluetoothAuthorization.RESTRICTED -> MsgBluetoothAuthorization.RESTRICTED
    },
    motion = when (value.motion) {
      PermissionStatus.MotionAuthorization.NOT_DETERMINED -> MsgMotionAuthorization.NOT_DETERMINED
      PermissionStatus.MotionAuthorization.AUTHORIZED -> MsgMotionAuthorization.AUTHORIZED
      PermissionStatus.MotionAuthorization.DENIED -> MsgMotionAuthorization.DENIED
      PermissionStatus.MotionAuthorization.RESTRICTED -> MsgMotionAuthorization.RESTRICTED
      PermissionStatus.MotionAuthorization.UNAVAILABLE -> MsgMotionAuthorization.UNAVAILABLE
    },
  )

  fun state(value: Proximiio.State): MsgSdkState = when (value) {
    Proximiio.State.IDLE -> MsgSdkState.IDLE
    Proximiio.State.AUTHENTICATED -> MsgSdkState.AUTHENTICATED
    Proximiio.State.STARTING -> MsgSdkState.STARTING
    Proximiio.State.RUNNING -> MsgSdkState.RUNNING
    Proximiio.State.STOPPING -> MsgSdkState.STOPPING
  }

  // endregion

  // region Events

  fun position(value: PositionUpdate) = MsgPositionUpdate(
    coordinate = coordinate(value.coordinate),
    horizontalAccuracy = value.horizontalAccuracy,
    floor = value.floor?.let(::floor),
    source = positionSource(value.source),
    timestampMs = value.timestamp,
    background = value.background,
  )

  fun positionSource(value: PositionSource): MsgPositionSource = when (value) {
    PositionSource.BLE_TRILATERATION -> MsgPositionSource.BLE_TRILATERATION
    PositionSource.NATIVE -> MsgPositionSource.NATIVE
    PositionSource.CUSTOM -> MsgPositionSource.CUSTOM
    PositionSource.PDR_FUSION -> MsgPositionSource.PDR_FUSION
    PositionSource.UWB -> MsgPositionSource.UWB
  }

  fun floorChange(value: FloorChangeEvent) = MsgFloorChange(
    previousFloor = value.previousFloor?.let(::floor),
    floor = value.floor?.let(::floor),
    direction = when (value.direction) {
      FloorChangeDirection.UP -> MsgFloorChangeDirection.UP
      FloorChangeDirection.DOWN -> MsgFloorChangeDirection.DOWN
      FloorChangeDirection.UNKNOWN -> MsgFloorChangeDirection.UNKNOWN
    },
    confidence = value.confidence,
    source = when (value.source) {
      FloorChangeSource.BAROMETER -> MsgFloorChangeSource.BAROMETER
      FloorChangeSource.BEACON -> MsgFloorChangeSource.BEACON
      FloorChangeSource.MANUAL -> MsgFloorChangeSource.MANUAL
    },
    timestampMs = value.timestamp,
  )

  fun geofenceEvent(value: GeofenceEvent): MsgGeofenceEvent = when (value) {
    is GeofenceEvent.Entered -> MsgGeofenceEntered(geofence = geofence(value.geofence))
    is GeofenceEvent.Exited -> MsgGeofenceExited(geofence = geofence(value.geofence), dwellTimeSeconds = value.dwellTime)
    is GeofenceEvent.PrivacyZoneEntered -> MsgPrivacyZoneEntered(zone = privacyZone(value.zone))
    is GeofenceEvent.PrivacyZoneExited -> MsgPrivacyZoneExited(zone = privacyZone(value.zone))
  }

  fun privacyZoneState(value: PrivacyZoneState) = MsgPrivacyZoneState(
    isInPrivacyZone = value.isInPrivacyZone,
    positioningSourcePrivateSinceMs = value.positioningSourcePrivateSince,
    isPrivate = value.isPrivate,
  )

  // endregion

  // region Errors

  fun invalidArgument(message: String) = ProximiioFlutterError("invalidArgument", message)

  fun notConfigured() =
    ProximiioFlutterError("notConfigured", "Call Proximiio.create(...) before using the SDK.")

  /**
   * Error codes are the SDK's `ProximiioError` case names (as on iOS), `api` for `ProximiioAPIError`
   * (with `kind` in the details), `noRoute`, `offlinePackage`, `journey`, and `underlying` for anything
   * else. `underlying` in the details names the system error behind a failure, for support.
   */
  fun flutterError(error: Throwable): ProximiioFlutterError {
    if (error is ProximiioFlutterError) return error
    val details = mutableMapOf<String, String>()
    var message = error.message
    if (error is ProximiioFailure) {
      details["domain"] = error.failureDomain
      details["failureCode"] = error.failureCode.toString()
      details["retryable"] = error.isRetryable.toString()
      message = error.errorDescription ?: message
    }
    (if (error is ProximiioFailure) error.underlyingError else error.cause)?.let { cause ->
      details["underlying"] = "${cause::class.java.simpleName}: ${cause.message}"
    }
    val code = when (error) {
      is ProximiioError.InvalidToken -> "invalidToken"
      is ProximiioError.NotAuthenticated -> "notAuthenticated"
      is ProximiioError.LocationPermissionDenied -> {
        details["authorization"] = error.authorization.camelName()
        "locationPermissionDenied"
      }
      is ProximiioError.BluetoothPermissionDenied -> {
        details["authorization"] = error.authorization.camelName()
        "bluetoothPermissionDenied"
      }
      is ProximiioError.MotionPermissionDenied -> {
        details["authorization"] = error.authorization.camelName()
        "motionPermissionDenied"
      }
      is ProximiioError.ReducedLocationAccuracy -> "reducedLocationAccuracy"
      is ProximiioError.Storage -> "storage"
      is ProximiioError.Underlying -> "underlying"
      is ProximiioAPIError -> {
        details["kind"] = kindName(error)
        if (error is ProximiioAPIError.Server) details["statusCode"] = error.statusCode.toString()
        "api"
      }
      is WayfindingRoutingError -> {
        RouteMappers.noRouteDetails(error.reason, details)
        "noRoute"
      }
      is OfflinePackageError -> {
        details["kind"] = kindName(error)
        "offlinePackage"
      }
      is ProximiioJourneyError -> {
        details["kind"] = kindName(error)
        "journey"
      }
      else -> "underlying"
    }
    return ProximiioFlutterError(code, message, details)
  }

  /** The subclass name of a sealed error, as the iOS case name (`ChecksumMismatch` → `checksumMismatch`). */
  private fun kindName(error: Throwable): String =
    error::class.simpleName?.replaceFirstChar { it.lowercaseChar() } ?: "unknown"

  /** `NOT_DETERMINED` → `notDetermined`, the iOS raw value. */
  internal fun Enum<*>.camelName(): String =
    name.lowercase().split('_').mapIndexed { index, part ->
      if (index == 0) part else part.replaceFirstChar { it.uppercaseChar() }
    }.joinToString("")

  // endregion
}
