import Flutter
import Proximiio
import UIKit

public final class FlutterProximiioPlugin: NSObject, FlutterPlugin {
  private let streams: EngineStreams

  private init(messenger: FlutterBinaryMessenger) {
    streams = EngineStreams(messenger: messenger)
    super.init()
    ProximiioHostApiSetup.setUp(binaryMessenger: messenger, api: HostApi())
    let streams = streams
    Task { @MainActor in ProximiioHub.shared.attach(streams) }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = FlutterProximiioPlugin(messenger: registrar.messenger())
    // Publishing keeps the plugin alive and makes the engine call detachFromEngine(for:).
    registrar.publish(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    ProximiioHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    let streams = streams
    Task { @MainActor in ProximiioHub.shared.detach(streams) }
  }
}

/// Handles the Dart → native calls. Every call runs on the main actor and awaits the SDK actor.
private final class HostApi: ProximiioHostApi {

  private func run<Value>(
    _ completion: @escaping (Result<Value, Error>) -> Void,
    _ body: @escaping @MainActor (Proximiio) async throws -> Value
  ) {
    Task { @MainActor in
      guard let sdk = ProximiioHub.shared.sdk else {
        completion(.failure(Mappers.notConfigured))
        return
      }
      do {
        completion(.success(try await body(sdk)))
      } catch {
        completion(.failure(Mappers.flutterError(error)))
      }
    }
  }

  /// A lifecycle call: one at a time across all engines, on the instance current when its turn
  /// comes. The new state is published before the call completes, as on Android.
  private func runLifecycle<Value>(
    _ completion: @escaping (Result<Value, Error>) -> Void,
    _ body: @escaping @MainActor (Proximiio) async throws -> Value
  ) {
    Task { @MainActor in
      do {
        let value = try await ProximiioHub.shared.lifecycle {
          guard let sdk = ProximiioHub.shared.sdk else { throw Mappers.notConfigured }
          do {
            let value = try await body(sdk)
            await ProximiioHub.shared.publishState()
            return value
          } catch {
            await ProximiioHub.shared.publishState()
            throw error
          }
        }
        completion(.success(value))
      } catch {
        completion(.failure(Mappers.flutterError(error)))
      }
    }
  }

  func configure(configuration: MsgConfiguration, completion: @escaping (Result<Void, Error>) -> Void) {
    Task { @MainActor in
      do {
        try await ProximiioHub.shared.lifecycle {
          try await ProximiioHub.shared.configure(Mappers.configuration(configuration))
        }
        completion(.success(()))
      } catch {
        completion(.failure(Mappers.flutterError(error)))
      }
    }
  }

  func isConfigured() throws -> Bool {
    MainActor.assumeIsolated { ProximiioHub.shared.sdk != nil }
  }

  func state(completion: @escaping (Result<MsgSdkState, Error>) -> Void) {
    run(completion) { sdk in Mappers.state(await sdk.state) }
  }

  func tokenStatus(completion: @escaping (Result<MsgTokenStatus, Error>) -> Void) {
    run(completion) { sdk in Mappers.tokenStatus(await sdk.tokenStatus) }
  }

  /// Location through the SDK, then Bluetooth, which iOS would otherwise ask at the first `start()`.
  /// The Bluetooth request gives up once no system prompt is on screen (see ``SystemPrompt``), and
  /// the status is read again at the end.
  func requestPermissions(always: Bool, completion: @escaping (Result<MsgPermissionStatus, Error>) -> Void) {
    run(completion) { sdk in
      var status = await sdk.requestPermissions(always: always)
      if ProximiioHub.shared.usesBluetooth, BluetoothPrompt.isNeeded {
        await SystemPrompt.answer(to: { await BluetoothPrompt.show() }, orRead: {})
        status = await sdk.requestPermissions(always: false)
      }
      return Mappers.permissionStatus(status)
    }
  }

  func requestMotionPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
    run(completion) { sdk in await sdk.requestMotionPermission() }
  }

  func authenticate(completion: @escaping (Result<MsgApplication?, Error>) -> Void) {
    runLifecycle(completion) { sdk in try await sdk.authenticate().map(Mappers.application) }
  }

  func start(completion: @escaping (Result<Void, Error>) -> Void) {
    runLifecycle(completion) { sdk in
      await ProximiioHub.shared.ensureRunStreams()
      try await sdk.start()
    }
  }

  func stop(completion: @escaping (Result<Void, Error>) -> Void) {
    runLifecycle(completion) { sdk in await ProximiioHub.shared.stopAndDrain(sdk) }
  }

  func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
    runLifecycle(completion) { sdk in
      await ProximiioHub.shared.stopAndDrain(sdk)
      try await sdk.signOut()
    }
  }

  func sync(completion: @escaping (Result<Int64, Error>) -> Void) {
    run(completion) { sdk in Int64(try await sdk.sync()) }
  }

  func application(completion: @escaping (Result<MsgApplication?, Error>) -> Void) {
    run(completion) { sdk in await sdk.application().map(Mappers.application) }
  }

  func places(completion: @escaping (Result<[MsgPlace], Error>) -> Void) {
    run(completion) { sdk in await sdk.places().map(Mappers.place) }
  }

  func floors(completion: @escaping (Result<[MsgFloor], Error>) -> Void) {
    run(completion) { sdk in await sdk.floors().map(Mappers.floor) }
  }

  func geofences(completion: @escaping (Result<[MsgZone], Error>) -> Void) {
    run(completion) { sdk in await sdk.geofences().map(Mappers.geofence) }
  }

  func privacyZones(completion: @escaping (Result<[MsgZone], Error>) -> Void) {
    run(completion) { sdk in await sdk.privacyZones().map(Mappers.privacyZone) }
  }

  func place(id: String, completion: @escaping (Result<MsgPlace?, Error>) -> Void) {
    run(completion) { sdk in await sdk.place(id: id).map(Mappers.place) }
  }

  func floor(id: String, completion: @escaping (Result<MsgFloor?, Error>) -> Void) {
    run(completion) { sdk in await sdk.floor(id: id).map(Mappers.floor) }
  }

  func currentFloor(completion: @escaping (Result<MsgFloor?, Error>) -> Void) {
    run(completion) { sdk in await sdk.currentFloor.map(Mappers.floor) }
  }

  func lastPosition(completion: @escaping (Result<MsgPositionUpdate?, Error>) -> Void) {
    run(completion) { sdk in await sdk.lastPosition.map(Mappers.position) }
  }

  func enteredGeofenceIds(completion: @escaping (Result<[String], Error>) -> Void) {
    run(completion) { sdk in Array(await sdk.enteredGeofenceIds).sorted() }
  }

  func isInPrivacyZone(completion: @escaping (Result<Bool, Error>) -> Void) {
    run(completion) { sdk in await sdk.isInPrivacyZone }
  }

  func visitorId(completion: @escaping (Result<String, Error>) -> Void) {
    run(completion) { sdk in await sdk.visitorId }
  }

  func resetVisitorId(completion: @escaping (Result<String, Error>) -> Void) {
    run(completion) { sdk in await sdk.resetVisitorId() }
  }

  func visitorReportingConsent(completion: @escaping (Result<Bool, Error>) -> Void) {
    run(completion) { sdk in await sdk.visitorReportingConsent }
  }

  func setVisitorReportingConsent(granted: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.setVisitorReportingConsent(granted) }
  }

  /// The level gates the SDK's log sink; its unified-log output is the same at every level.
  func setLogLevel(level: MsgLogLevel) throws {
    Proximiio.logLevel = Mappers.logLevel(level)
  }

  func updateServiceNotification(options: MsgAndroidServiceOptions, completion: @escaping (Result<Bool, Error>) -> Void) {
    completion(.failure(Self.androidOnly))
  }

  func resetServiceNotification(completion: @escaping (Result<Void, Error>) -> Void) {
    completion(.failure(Self.androidOnly))
  }

  // MARK: Wayfinding

  func computeRoute(
    from: MsgCoordinate,
    fromLevel: Double,
    to: MsgCoordinate,
    toLevel: Double,
    options: MsgRouteOptions,
    completion: @escaping (Result<MsgComputedRoute, Error>) -> Void
  ) {
    run(completion) { sdk in
      RouteMappers.route(
        try await sdk.computeRoute(
          from: RouteMappers.sdkCoordinate(from),
          fromLevel: fromLevel,
          to: RouteMappers.sdkCoordinate(to),
          toLevel: toLevel,
          options: RouteMappers.options(options)
        )
      )
    }
  }

  func routeDurations(
    points: [MsgRoutePoint],
    options: MsgRouteOptions,
    completion: @escaping (Result<[MsgDurationRow], Error>) -> Void
  ) {
    run(completion) { sdk in
      try await sdk.routeDurations(between: points.map(RouteMappers.point), options: RouteMappers.options(options))
        .map { MsgDurationRow(seconds: $0) }
    }
  }

  func loadRouteNetwork(completion: @escaping (Result<Int64, Error>) -> Void) {
    run(completion) { sdk in Int64(try await sdk.loadRouteNetwork()) }
  }

  func loadCachedRouteNetwork(completion: @escaping (Result<Int64, Error>) -> Void) {
    run(completion) { sdk in Int64(await sdk.loadCachedRouteNetwork()) }
  }

  // MARK: Venue data

  func amenities(completion: @escaping (Result<[MsgAmenity], Error>) -> Void) {
    run(completion) { sdk in try await sdk.amenities().map(VenueMappers.amenity) }
  }

  func features(completion: @escaping (Result<[MsgFeature], Error>) -> Void) {
    run(completion) { sdk in await sdk.features().map(VenueMappers.feature) }
  }

  func departments(completion: @escaping (Result<[MsgDepartment], Error>) -> Void) {
    run(completion) { sdk in await sdk.departments().map(VenueMappers.department) }
  }

  func mapStyle(completion: @escaping (Result<String, Error>) -> Void) {
    run(completion) { sdk in String(decoding: try await sdk.mapStyle(), as: UTF8.self) }
  }

  func journeys(completion: @escaping (Result<[MsgJourney], Error>) -> Void) {
    run(completion) { sdk in try await sdk.journeys().map(VenueMappers.journey) }
  }

  func journey(id: String, completion: @escaping (Result<MsgJourney, Error>) -> Void) {
    run(completion) { sdk in VenueMappers.journey(try await sdk.fetchJourney(id: id)) }
  }

  // MARK: Offline packages

  func syncOfflinePackage(
    packageId: String,
    place: String?,
    allowsCellular: Bool,
    completion: @escaping (Result<MsgPackageState, Error>) -> Void
  ) {
    run(completion) { sdk in
      VenueMappers.packageState(
        try await sdk.syncOfflinePackage(
          packageId: packageId,
          place: place,
          policy: PackagePolicy(allowsCellular: allowsCellular)
        )
      )
    }
  }

  func offlinePackageState(packageId: String, completion: @escaping (Result<MsgPackageState, Error>) -> Void) {
    run(completion) { sdk in VenueMappers.packageState(await sdk.offlinePackageState(packageId: packageId)) }
  }

  func installOfflineSeed(packageId: String, directory: String, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      try await sdk.installOfflineSeed(packageId: packageId, at: URL(fileURLWithPath: directory, isDirectory: true))
    }
  }

  func removeOfflinePackage(packageId: String, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in try await sdk.removeOfflinePackage(packageId: packageId) }
  }

  func offlinePackageDiskUsage(packageId: String, completion: @escaping (Result<Int64, Error>) -> Void) {
    run(completion) { sdk in await sdk.offlinePackageDiskUsage(packageId: packageId) }
  }

  // MARK: Simulation

  func simulatePosition(
    coordinate: MsgCoordinate,
    level: Int64,
    accuracy: Double,
    completion: @escaping (Result<MsgPositionUpdate?, Error>) -> Void
  ) {
    run(completion) { sdk in
      await sdk.simulatePosition(RouteMappers.sdkCoordinate(coordinate), level: Int(level), accuracy: accuracy)
        .map(Mappers.position)
    }
  }

  func startSimulation(route: MsgSimulatedRoute, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.startSimulation(VenueMappers.simulatedRoute(route)) }
  }

  func pauseSimulation(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.pauseSimulation() }
  }

  func resumeSimulation(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.resumeSimulation() }
  }

  func stopSimulation(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.stopSimulation() }
  }

  func jumpToWaypoint(index: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.jumpToWaypoint(Int(index)) }
  }

  func simulationState(completion: @escaping (Result<MsgSimulationState, Error>) -> Void) {
    run(completion) { sdk in VenueMappers.simulationState(await sdk.simulationState) }
  }

  // MARK: Positioning inputs

  func setCustomPosition(
    coordinate: MsgCoordinate,
    accuracy: Double,
    floorId: String?,
    completion: @escaping (Result<MsgPositionUpdate?, Error>) -> Void
  ) {
    run(completion) { sdk in
      let floor = try await Self.knownFloor(floorId, in: sdk)
      return await sdk.setCustomPosition(RouteMappers.sdkCoordinate(coordinate), accuracy: accuracy, floor: floor)
        .map(Mappers.position)
    }
  }

  func setFloor(floorId: String?, completion: @escaping (Result<MsgFloorChange?, Error>) -> Void) {
    run(completion) { sdk in
      let floor = try await Self.knownFloor(floorId, in: sdk)
      return await sdk.setFloor(floor).map(Mappers.floorChange)
    }
  }

  /// The SDK reads a `nil` floor as "keep the current one" or "clear it", so an unknown id fails instead.
  private static func knownFloor(_ id: String?, in sdk: Proximiio) async throws -> ProximiioFloor? {
    guard let id else { return nil }
    guard let floor = await sdk.floor(id: id) else {
      throw Mappers.invalidArgument("No floor with id \(id) in the venue data.")
    }
    return floor
  }

  func enableRouteSnapping(thresholdMeters: Double?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      if let thresholdMeters {
        await sdk.enableRouteSnapping(threshold: thresholdMeters)
      } else {
        await sdk.enableRouteSnapping()
      }
    }
  }

  func disableRouteSnapping(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.disableRouteSnapping() }
  }

  func enablePdr(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in _ = await sdk.enablePdr() }
  }

  func disablePdr(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.disablePdr() }
  }

  func setPositioningSourcePrivate(sinceMs: Int64?, completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      await sdk.setPositioningSourcePrivate(since: sinceMs.map { Date(timeIntervalSince1970: Double($0) / 1000) })
    }
  }

  // MARK: Diagnostics

  func diagnostics(completion: @escaping (Result<MsgDiagnostics, Error>) -> Void) {
    run(completion) { sdk in VenueMappers.diagnostics(await sdk.diagnostics()) }
  }

  func startDiagnosticsRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in try await sdk.startDiagnosticsRecording() }
  }

  func stopDiagnosticsRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in await sdk.stopDiagnosticsRecording() }
  }

  func prepareDiagnosticsReport(completion: @escaping (Result<String, Error>) -> Void) {
    run(completion) { sdk in try await sdk.prepareDiagnosticsReport().archiveURL.path }
  }

  private static let androidOnly = ProximiioFlutterError(
    code: "unsupported",
    message: "The foreground-service notification exists only on Android.",
    details: nil
  )
}
