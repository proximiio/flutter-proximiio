package io.proximi.flutter_proximiio

import io.proximi.sdk.ProximiioDiagnostics
import io.proximi.sdk.VenueDataChange
import io.proximi.sdk.core.model.ProximiioAmenity
import io.proximi.sdk.core.model.ProximiioDepartment
import io.proximi.sdk.core.model.ProximiioFeature
import io.proximi.sdk.core.sync.SyncEvent
import io.proximi.sdk.journey.ProximiioJourney
import io.proximi.sdk.offline.PackageState
import io.proximi.sdk.positioning.ble.BLEBeaconObservation
import io.proximi.sdk.positioning.ble.BeaconEvent
import io.proximi.sdk.positioning.ble.BeaconIdentifier
import io.proximi.sdk.positioning.ble.BeaconTelemetry
import io.proximi.sdk.simulation.ProximiioSimulatedRoute
import io.proximi.sdk.simulation.ProximiioSimulatedWaypoint
import io.proximi.sdk.simulation.ProximiioSimulationState
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** Venue data, sync, beacon, offline, simulation and diagnostics types ↔ transport types. */
internal object VenueMappers {

  // region Venue data

  fun amenity(value: ProximiioAmenity) = MsgAmenity(
    id = value.id,
    title = value.title,
    category = value.category,
    icon = value.icon,
    details = value.details,
  )

  fun feature(value: ProximiioFeature) = MsgFeature(
    id = value.id,
    type = value.type,
    geometryJson = value.geometry?.let { geometry(it).toString() },
    propertiesJson = Mappers.json(value.properties),
    level = value.level,
    featureClass = value.featureClass,
    propertyType = value.propertyType,
    isLevelChanger = value.isLevelChanger,
    titleTranslations = value.titleTranslations,
  )

  private fun geometry(value: ProximiioFeature.Geometry): JsonElement {
    val fields = mutableMapOf<String, JsonElement>("type" to JsonPrimitive(value.type))
    val geometries = value.geometries
    if (geometries != null) {
      fields["geometries"] = JsonArray(geometries.map(::geometry))
    } else {
      fields["coordinates"] = Mappers.jsonElement(value.coordinates)
    }
    return JsonObject(fields)
  }

  fun department(value: ProximiioDepartment) = MsgDepartment(
    id = value.id,
    name = value.name,
    placeId = value.placeId,
    floorId = value.floorId,
    tags = value.tags,
    metadataJson = Mappers.json(value.metadata),
  )

  fun journey(value: ProximiioJourney) = MsgJourney(
    id = value.id,
    organizationId = value.organizationId,
    name = value.name,
    placeId = value.placeId,
    speed = value.speed,
    waypoints = value.waypoints.map { waypoint ->
      MsgJourneyWaypoint(
        latitude = waypoint.latitude,
        longitude = waypoint.longitude,
        level = waypoint.level,
        floorId = waypoint.floorId,
        label = waypoint.label,
        dwellSeconds = waypoint.dwell,
        speed = waypoint.speed,
        transitionSeconds = waypoint.transition,
      )
    },
    displayName = value.displayName,
  )

  fun venueDataChange(value: VenueDataChange) = MsgVenueDataChange(kinds = value.kinds.map { it.rawValue }.sorted())

  fun syncEvent(value: SyncEvent): MsgSyncEvent = when (value) {
    is SyncEvent.Updated -> MsgSyncUpdated(entity = value.entity, id = value.id)
    is SyncEvent.Deleted -> MsgSyncDeleted(entity = value.entity, id = value.id)
    is SyncEvent.SyncCompleted -> MsgSyncCompleted(applied = value.applied.toLong())
    is SyncEvent.SyncFailed -> MsgSyncFailed(reason = value.reason)
    is SyncEvent.StoreRecreated -> MsgStoreRecreated(reason = value.reason)
  }

  // endregion

  // region Beacons

  fun beaconEvent(value: BeaconEvent): MsgBeaconEvent = when (value) {
    is BeaconEvent.Found -> MsgBeaconFound(observation = observation(value.observation))
    is BeaconEvent.Updated -> MsgBeaconUpdated(observation = observation(value.observation))
    is BeaconEvent.Lost -> MsgBeaconLost(identifier = identifier(value.identifier))
    is BeaconEvent.Telemetry -> MsgBeaconTelemetryReceived(
      identifier = identifier(value.identifier),
      telemetry = telemetry(value.telemetry),
    )
  }

  private fun observation(value: BLEBeaconObservation) = MsgBeaconObservation(
    identifier = identifier(value.identifier),
    rssi = value.rssi.toLong(),
    txPower = value.txPower?.toLong(),
    timestampMs = value.timestamp,
    calibratedDistance = value.calibratedDistance,
  )

  /** UUIDs in upper case, as iOS prints them. */
  fun identifier(value: BeaconIdentifier): MsgBeaconIdentifier = when (value) {
    is BeaconIdentifier.IBeacon -> MsgBeaconIdentifier(
      kind = MsgBeaconKind.I_BEACON,
      uuid = value.identifier.uuid.toString().uppercase(),
      major = value.identifier.major.toLong(),
      minor = value.identifier.minor.toLong(),
    )
    is BeaconIdentifier.Eddystone -> MsgBeaconIdentifier(
      kind = MsgBeaconKind.EDDYSTONE,
      namespace = value.identifier.namespace,
      instance = value.identifier.instance,
    )
    is BeaconIdentifier.UWBAccessory -> MsgBeaconIdentifier(kind = MsgBeaconKind.UWB_ACCESSORY, name = value.name)
  }

  private fun telemetry(value: BeaconTelemetry) = MsgBeaconTelemetry(
    batteryMillivolts = value.batteryMillivolts.toLong(),
    temperatureCelsius = value.temperatureCelsius,
    advertisementCount = value.advertisementCount,
    uptimeSeconds = value.uptimeSeconds,
    receivedAtMs = value.receivedAt,
  )

  // endregion

  // region Offline, simulation, diagnostics

  fun packageState(value: PackageState): MsgPackageState = when (value) {
    PackageState.Missing -> MsgPackageState(kind = MsgPackageStateKind.MISSING)
    is PackageState.Downloading -> MsgPackageState(kind = MsgPackageStateKind.DOWNLOADING, progress = value.progress)
    is PackageState.Ready -> MsgPackageState(kind = MsgPackageStateKind.READY, version = value.version.toLong())
    PackageState.Stale -> MsgPackageState(kind = MsgPackageStateKind.STALE)
    PackageState.Verifying -> MsgPackageState(kind = MsgPackageStateKind.VERIFYING)
    PackageState.Failed -> MsgPackageState(kind = MsgPackageStateKind.FAILED)
  }

  fun simulatedRoute(value: MsgSimulatedRoute) = ProximiioSimulatedRoute(
    waypoints = value.waypoints.map {
      ProximiioSimulatedWaypoint(coordinate = RouteMappers.sdkCoordinate(it.coordinate), level = it.level.toInt())
    },
    speed = value.speed,
    updateInterval = value.updateIntervalSeconds,
    loops = value.loops,
    accuracy = value.accuracy,
  )

  fun simulationState(value: ProximiioSimulationState): MsgSimulationState = when (value) {
    ProximiioSimulationState.IDLE -> MsgSimulationState.IDLE
    ProximiioSimulationState.RUNNING -> MsgSimulationState.RUNNING
    ProximiioSimulationState.PAUSED -> MsgSimulationState.PAUSED
  }

  fun diagnostics(value: ProximiioDiagnostics) = MsgDiagnostics(
    state = Mappers.state(value.state),
    isStarted = value.isStarted,
    isAuthenticated = value.isAuthenticated,
    permissions = value.permissions?.let(Mappers::permissionStatus),
    visibleBeaconCount = value.visibleBeaconCount.toLong(),
    registeredBeaconCount = value.registeredBeaconCount.toLong(),
    lastPositionAgeSeconds = value.lastPositionAge,
    lastPositionSource = value.lastPositionSource?.let { Mappers.positionSource(it) },
    pdrEnabled = value.pdrEnabled,
    pdrRunning = value.pdrRunning,
    visitorReportingEnabled = value.visitorReporting.rawValue == "enabled",
    noPositionReason = value.noPositionReason?.rawValue,
    summary = value.summary,
    generatedAtMs = value.generatedAt,
  )

  // endregion
}
