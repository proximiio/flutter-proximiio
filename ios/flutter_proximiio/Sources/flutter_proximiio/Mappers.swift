import Foundation
import Proximiio

/// Converts between SDK types and the Pigeon transport types (`Msg*`).
///
/// Units on the bridge: times are milliseconds since the epoch, durations are seconds,
/// metadata is a JSON string. Outlines are latitude/longitude pairs.
enum Mappers {

  // MARK: Configuration

  static func configuration(_ msg: MsgConfiguration) throws -> ProximiioConfiguration {
    var config: ProximiioConfiguration
    switch msg.preset {
    case .standard: config = .default(token: msg.token)
    case .highAccuracy: config = .highAccuracy(token: msg.token)
    case .lowPower: config = .lowPower(token: msg.token)
    case .relayOnly: config = .relayOnly(token: msg.token, runsInBackground: msg.relayRunsInBackground ?? false)
    }
    if let value = msg.apiBaseUrl { config.apiBaseURL = try url(value) }
    if !msg.fallbackApiBaseUrls.isEmpty { config.fallbackAPIBaseURLs = try msg.fallbackApiBaseUrls.map(url) }
    if let value = msg.syncIntervalSeconds { config.syncInterval = value }
    if let value = msg.desiredAccuracy { config.desiredAccuracy = desiredAccuracy(value) }
    if let value = msg.allowsBackgroundLocationUpdates { config.allowsBackgroundLocationUpdates = value }
    if let value = msg.visitorReportingEnabled { config.visitorReportingEnabled = value }
    if let value = msg.geofenceExitDelaySeconds { config.geofenceExitDelay = value }
    if let value = msg.withholdsPositionsInPrivacyZones { config.withholdsPositionsInPrivacyZones = value }
    if !msg.customIBeaconUuids.isEmpty {
      config.customIBeaconUUIDs = try msg.customIBeaconUuids.map { value in
        guard let uuid = UUID(uuidString: value) else { throw invalidArgument("Not a UUID: \(value)") }
        return uuid
      }
    }
    if let value = msg.pdrFusionEnabled { config.pdrFusionEnabled = value }
    if let value = msg.barometerEnabled { config.barometerEnabled = value }
    return config
  }

  private static func url(_ value: String) throws -> URL {
    guard let url = URL(string: value), url.scheme != nil, url.host != nil else {
      throw invalidArgument("Not an absolute URL: \(value)")
    }
    return url
  }

  static func desiredAccuracy(_ value: MsgDesiredAccuracy) -> CoreLocationAccuracy {
    switch value {
    case .bestForNavigation: return .bestForNavigation
    case .best: return .best
    case .nearestTenMeters: return .nearestTenMeters
    case .hundredMeters: return .hundredMeters
    case .kilometer: return .kilometer
    case .threeKilometers: return .threeKilometers
    }
  }

  static func logLevel(_ value: MsgLogLevel) -> ProximiioLogLevel {
    switch value {
    case .debug: return .debug
    case .info: return .info
    case .notice: return .notice
    case .warning: return .warning
    case .error: return .error
    }
  }

  // MARK: Models

  static func coordinate(_ value: ProximiioCoordinate) -> MsgCoordinate {
    MsgCoordinate(latitude: value.latitude, longitude: value.longitude)
  }

  /// The SDK keeps outlines in GeoJSON order, `[longitude, latitude]`.
  static func outline(_ polygon: [[Double]]?) -> [MsgCoordinate]? {
    polygon?.compactMap { point in
      point.count >= 2 ? MsgCoordinate(latitude: point[1], longitude: point[0]) : nil
    }
  }

  static func json(_ value: JSONValue?) -> String? {
    guard let value, value != .null, let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func millis(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
  }

  static func application(_ value: ProximiioApplication) -> MsgApplication {
    MsgApplication(id: value.id, name: value.name)
  }

  static func place(_ value: ProximiioPlace) -> MsgPlace {
    MsgPlace(
      id: value.id,
      name: value.name,
      address: value.address,
      tags: value.tags,
      location: value.location.map(coordinate),
      metadataJson: json(value.metadata)
    )
  }

  static func floor(_ value: ProximiioFloor) -> MsgFloor {
    MsgFloor(
      id: value.id,
      name: value.name,
      placeId: value.placeId,
      floorId: value.floorId,
      level: value.level,
      anchors: value.anchors.map(coordinate),
      floorPlanImageUrl: value.floorPlanImageURL,
      metadataJson: json(value.metadata)
    )
  }

  static func geofence(_ value: ProximiioGeofence) -> MsgZone {
    MsgZone(
      id: value.id,
      name: value.name,
      type: value.type,
      area: value.area.map(coordinate),
      radius: value.radius,
      polygon: outline(value.polygon),
      address: value.address,
      placeId: value.placeId,
      departmentId: value.departmentId,
      floorId: value.floorId,
      remoteId: value.remoteId,
      metadataJson: json(value.metadata),
      geometryIssue: value.geometryIssue?.rawValue
    )
  }

  static func privacyZone(_ value: ProximiioPrivacyZone) -> MsgZone {
    MsgZone(
      id: value.id,
      name: value.name,
      type: value.type,
      area: value.area.map(coordinate),
      radius: value.radius,
      polygon: outline(value.polygon),
      address: value.address,
      placeId: value.placeId,
      departmentId: value.departmentId,
      floorId: value.floorId,
      remoteId: nil,
      metadataJson: json(value.metadata),
      geometryIssue: value.geometryIssue?.rawValue
    )
  }

  static func permissionStatus(_ value: PermissionStatus) -> MsgPermissionStatus {
    let location: MsgLocationAuthorization
    switch value.location {
    case .notDetermined: location = .notDetermined
    case .whenInUse: location = .whenInUse
    case .always: location = .always
    case .denied: location = .denied
    case .restricted: location = .restricted
    @unknown default: location = .notDetermined
    }
    let accuracy: MsgLocationAccuracy
    switch value.accuracy {
    case .full: accuracy = .full
    case .reduced: accuracy = .reduced
    @unknown default: accuracy = .full
    }
    let bluetooth: MsgBluetoothAuthorization
    switch value.bluetooth {
    case .notDetermined: bluetooth = .notDetermined
    case .allowed: bluetooth = .allowed
    case .denied: bluetooth = .denied
    case .restricted: bluetooth = .restricted
    @unknown default: bluetooth = .notDetermined
    }
    let motion: MsgMotionAuthorization
    switch value.motion {
    case .notDetermined: motion = .notDetermined
    case .authorized: motion = .authorized
    case .denied: motion = .denied
    case .restricted: motion = .restricted
    case .unavailable: motion = .unavailable
    @unknown default: motion = .unavailable
    }
    return MsgPermissionStatus(location: location, accuracy: accuracy, bluetooth: bluetooth, motion: motion)
  }

  static func state(_ value: Proximiio.State) -> MsgSdkState {
    switch value {
    case .idle: return .idle
    case .authenticated: return .authenticated
    case .starting: return .starting
    case .running: return .running
    case .stopping: return .stopping
    @unknown default: return .idle
    }
  }

  // MARK: Events

  static func positionSource(_ value: PositionSource) -> MsgPositionSource {
    switch value {
    case .bleTrilateration: return .bleTrilateration
    case .native: return .native
    case .custom: return .custom
    case .pdrFusion: return .pdrFusion
    case .uwb: return .uwb
    @unknown default: return .unknown
    }
  }

  static func position(_ value: PositionUpdate) -> MsgPositionUpdate {
    MsgPositionUpdate(
      coordinate: coordinate(value.coordinate),
      horizontalAccuracy: value.horizontalAccuracy,
      floor: value.floor.map(floor),
      source: positionSource(value.source),
      timestampMs: millis(value.timestamp),
      background: value.background
    )
  }

  static func floorChange(_ value: FloorChangeEvent) -> MsgFloorChange {
    let direction: MsgFloorChangeDirection
    switch value.direction {
    case .up: direction = .up
    case .down: direction = .down
    case .unknown: direction = .unknown
    @unknown default: direction = .unknown
    }
    let source: MsgFloorChangeSource
    switch value.source {
    case .barometer: source = .barometer
    case .beacon: source = .beacon
    case .manual: source = .manual
    @unknown default: source = .unknown
    }
    return MsgFloorChange(
      previousFloor: value.previousFloor.map(floor),
      floor: value.floor.map(floor),
      direction: direction,
      confidence: value.confidence,
      source: source,
      timestampMs: millis(value.timestamp)
    )
  }

  /// `nil` for an event kind added to the SDK after this plugin release.
  static func geofenceEvent(_ value: GeofenceEvent) -> MsgGeofenceEvent? {
    switch value {
    case .entered(let geofence):
      return MsgGeofenceEntered(geofence: self.geofence(geofence))
    case .exited(let geofence, let dwellTime):
      return MsgGeofenceExited(geofence: self.geofence(geofence), dwellTimeSeconds: dwellTime)
    case .privacyZoneEntered(let zone):
      return MsgPrivacyZoneEntered(zone: privacyZone(zone))
    case .privacyZoneExited(let zone):
      return MsgPrivacyZoneExited(zone: privacyZone(zone))
    @unknown default:
      return nil
    }
  }

  static func privacyZoneState(_ value: PrivacyZoneState) -> MsgPrivacyZoneState {
    MsgPrivacyZoneState(
      isInPrivacyZone: value.isInPrivacyZone,
      positioningSourcePrivateSinceMs: value.positioningSourcePrivateSince.map(millis),
      isPrivate: value.isPrivate
    )
  }

  // MARK: Errors

  static func invalidArgument(_ message: String) -> ProximiioFlutterError {
    ProximiioFlutterError(code: "invalidArgument", message: message, details: nil)
  }

  static let notConfigured = ProximiioFlutterError(
    code: "notConfigured",
    message: "Call Proximiio.create(...) before using the SDK.",
    details: nil
  )

  /// Error codes are the SDK's `ProximiioError` case names, `api` for `ProximiioAPIError`
  /// (with `kind` in the details), `noRoute`, `offlinePackage`, `journey`, and `underlying` for
  /// anything else. `underlying` in the details names the system error behind a failure, for support.
  static func flutterError(_ error: Error) -> ProximiioFlutterError {
    if let error = error as? ProximiioFlutterError { return error }
    var details: [String: String] = [:]
    var message = error.localizedDescription
    if let failure = error as? ProximiioFailure {
      // CustomNSError carries the failure's static domain and its code.
      let bridged = failure as NSError
      details["domain"] = bridged.domain
      details["failureCode"] = String(bridged.code)
      details["retryable"] = failure.isRetryable ? "true" : "false"
      message = failure.errorDescription ?? message
      if let cause = failure.underlyingError {
        details["underlying"] = "\(type(of: cause)): \(cause.localizedDescription)"
      }
    }
    let code: String
    if let error = error as? ProximiioError {
      switch error {
      case .invalidToken: code = "invalidToken"
      case .notAuthenticated: code = "notAuthenticated"
      case .locationPermissionDenied(let authorization):
        code = "locationPermissionDenied"
        details["authorization"] = authorization.rawValue
      case .bluetoothPermissionDenied(let authorization):
        code = "bluetoothPermissionDenied"
        details["authorization"] = authorization.rawValue
      case .motionPermissionDenied(let authorization):
        code = "motionPermissionDenied"
        details["authorization"] = authorization.rawValue
      case .reducedLocationAccuracy: code = "reducedLocationAccuracy"
      case .storage: code = "storage"
      case .underlying: code = "underlying"
      @unknown default: code = "underlying"
      }
    } else if let error = error as? ProximiioAPIError {
      code = "api"
      details["kind"] = caseName(error)
      if case .server(let statusCode) = error { details["statusCode"] = String(statusCode) }
    } else if let error = error as? WayfindingRoutingError {
      code = "noRoute"
      if case .noRoute(let reason) = error { RouteMappers.noRouteDetails(reason, into: &details) }
    } else if let error = error as? OfflinePackageError {
      code = "offlinePackage"
      details["kind"] = caseName(error)
    } else if let error = error as? ProximiioJourneyError {
      code = "journey"
      details["kind"] = caseName(error)
    } else {
      code = "underlying"
    }
    return ProximiioFlutterError(code: code, message: message, details: details)
  }

  /// The case name of an enum value, without its associated values (`server(statusCode: 500)` → `server`).
  static func caseName(_ value: Any) -> String {
    if let label = Mirror(reflecting: value).children.first?.label { return label }
    return String(describing: value)
  }
}
