import Foundation
import Proximiio

/// Venue data, sync, beacon, offline, simulation and diagnostics types ↔ transport types.
enum VenueMappers {

  // MARK: Venue data

  static func amenity(_ value: ProximiioAmenity) -> MsgAmenity {
    MsgAmenity(id: value.id, title: value.title, category: value.category, icon: value.icon, details: value.details)
  }

  private static func encoded<Value: Encodable>(_ value: Value?) -> String? {
    guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func feature(_ value: ProximiioFeature) -> MsgFeature {
    MsgFeature(
      id: value.id,
      type: value.type,
      geometryJson: encoded(value.geometry),
      propertiesJson: Mappers.json(value.properties),
      level: value.level,
      featureClass: value.featureClass,
      propertyType: value.propertyType,
      isLevelChanger: value.isLevelChanger,
      titleTranslations: value.titleTranslations
    )
  }

  static func department(_ value: ProximiioDepartment) -> MsgDepartment {
    MsgDepartment(
      id: value.id,
      name: value.name,
      placeId: value.placeId,
      floorId: value.floorId,
      tags: value.tags,
      metadataJson: Mappers.json(value.metadata)
    )
  }

  static func journey(_ value: ProximiioJourney) -> MsgJourney {
    MsgJourney(
      id: value.id,
      organizationId: value.organizationID,
      name: value.name,
      placeId: value.placeID,
      speed: value.speed,
      waypoints: value.waypoints.map { waypoint in
        MsgJourneyWaypoint(
          latitude: waypoint.latitude,
          longitude: waypoint.longitude,
          level: waypoint.level,
          floorId: waypoint.floorID,
          label: waypoint.label,
          dwellSeconds: waypoint.dwell,
          speed: waypoint.speed,
          transitionSeconds: waypoint.transition
        )
      },
      displayName: value.displayName
    )
  }

  static func venueDataChange(_ value: VenueDataChange) -> MsgVenueDataChange {
    MsgVenueDataChange(kinds: value.kinds.map(\.rawValue).sorted())
  }

  static func syncEvent(_ value: SyncEvent) -> MsgSyncEvent? {
    switch value {
    case .updated(let entity, let id): return MsgSyncUpdated(entity: entity, id: id)
    case .deleted(let entity, let id): return MsgSyncDeleted(entity: entity, id: id)
    case .syncCompleted(let applied): return MsgSyncCompleted(applied: Int64(applied))
    case .syncFailed(let reason): return MsgSyncFailed(reason: reason)
    case .storeRecreated(let reason): return MsgStoreRecreated(reason: reason)
    @unknown default: return nil
    }
  }

  // MARK: Beacons

  static func beaconEvent(_ value: BeaconEvent) -> MsgBeaconEvent? {
    switch value {
    case .found(let observation): return MsgBeaconFound(observation: self.observation(observation))
    case .updated(let observation): return MsgBeaconUpdated(observation: self.observation(observation))
    case .lost(let identifier): return MsgBeaconLost(identifier: self.identifier(identifier))
    case .telemetry(let identifier, let telemetry):
      return MsgBeaconTelemetryReceived(identifier: self.identifier(identifier), telemetry: self.telemetry(telemetry))
    @unknown default: return nil
    }
  }

  private static func observation(_ value: BLEBeaconObservation) -> MsgBeaconObservation {
    MsgBeaconObservation(
      identifier: identifier(value.identifier),
      rssi: Int64(value.rssi),
      txPower: value.txPower.map(Int64.init),
      timestampMs: Mappers.millis(value.timestamp),
      calibratedDistance: value.calibratedDistance
    )
  }

  static func identifier(_ value: BeaconIdentifier) -> MsgBeaconIdentifier {
    switch value {
    case .iBeacon(let beacon):
      return MsgBeaconIdentifier(
        kind: .iBeacon,
        uuid: beacon.uuid.uuidString,
        major: Int64(beacon.major),
        minor: Int64(beacon.minor)
      )
    case .eddystone(let beacon):
      return MsgBeaconIdentifier(kind: .eddystone, namespace: beacon.namespace, instance: beacon.instance)
    case .uwbAccessory(let name):
      return MsgBeaconIdentifier(kind: .uwbAccessory, name: name)
    @unknown default:
      return MsgBeaconIdentifier(kind: .uwbAccessory, name: String(describing: value))
    }
  }

  private static func telemetry(_ value: BeaconTelemetry) -> MsgBeaconTelemetry {
    MsgBeaconTelemetry(
      batteryMillivolts: Int64(value.batteryMillivolts),
      temperatureCelsius: value.temperatureCelsius,
      advertisementCount: Int64(value.advertisementCount),
      uptimeSeconds: value.uptimeSeconds,
      receivedAtMs: Mappers.millis(value.receivedAt)
    )
  }

  // MARK: Offline, simulation, diagnostics

  static func packageState(_ value: PackageState) -> MsgPackageState {
    switch value {
    case .missing: return MsgPackageState(kind: .missing)
    case .downloading(let progress): return MsgPackageState(kind: .downloading, progress: progress)
    case .ready(let version): return MsgPackageState(kind: .ready, version: Int64(version))
    case .stale: return MsgPackageState(kind: .stale)
    case .verifying: return MsgPackageState(kind: .verifying)
    case .failed: return MsgPackageState(kind: .failed)
    @unknown default: return MsgPackageState(kind: .failed)
    }
  }

  static func simulatedRoute(_ value: MsgSimulatedRoute) -> ProximiioSimulatedRoute {
    ProximiioSimulatedRoute(
      waypoints: value.waypoints.map {
        ProximiioSimulatedWaypoint(coordinate: RouteMappers.sdkCoordinate($0.coordinate), level: Int($0.level))
      },
      speed: value.speed,
      updateInterval: value.updateIntervalSeconds,
      loops: value.loops,
      accuracy: value.accuracy
    )
  }

  static func simulationState(_ value: ProximiioSimulationState) -> MsgSimulationState {
    switch value {
    case .idle: return .idle
    case .running: return .running
    case .paused: return .paused
    @unknown default: return .idle
    }
  }

  static func diagnostics(_ value: ProximiioDiagnostics) -> MsgDiagnostics {
    MsgDiagnostics(
      state: Mappers.state(value.state),
      isStarted: value.isStarted,
      isAuthenticated: value.isAuthenticated,
      permissions: value.permissions.map(Mappers.permissionStatus),
      visibleBeaconCount: Int64(value.visibleBeaconCount),
      registeredBeaconCount: Int64(value.registeredBeaconCount),
      lastPositionAgeSeconds: value.lastPositionAge,
      lastPositionSource: value.lastPositionSource.map(Mappers.positionSource),
      pdrEnabled: value.pdrEnabled,
      pdrRunning: value.pdrRunning,
      visitorReportingEnabled: value.visitorReporting.rawValue == "enabled",
      noPositionReason: value.noPositionReason?.rawValue,
      summary: value.summary,
      generatedAtMs: Mappers.millis(value.generatedAt)
    )
  }
}
