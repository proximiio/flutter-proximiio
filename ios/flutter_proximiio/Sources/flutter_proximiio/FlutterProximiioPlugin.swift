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

  func configure(configuration: MsgConfiguration, completion: @escaping (Result<Void, Error>) -> Void) {
    Task { @MainActor in
      do {
        try await ProximiioHub.shared.configure(Mappers.configuration(configuration))
        completion(.success(()))
      } catch {
        completion(.failure(Mappers.flutterError(error)))
      }
    }
  }

  func state(completion: @escaping (Result<MsgSdkState, Error>) -> Void) {
    run(completion) { sdk in Mappers.state(await sdk.state) }
  }

  func requestPermissions(always: Bool, completion: @escaping (Result<MsgPermissionStatus, Error>) -> Void) {
    run(completion) { sdk in Mappers.permissionStatus(await sdk.requestPermissions(always: always)) }
  }

  func requestMotionPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
    run(completion) { sdk in await sdk.requestMotionPermission() }
  }

  func authenticate(completion: @escaping (Result<MsgApplication?, Error>) -> Void) {
    run(completion) { sdk in
      defer { Task { await ProximiioHub.shared.publishState() } }
      return try await sdk.authenticate().map(Mappers.application)
    }
  }

  func start(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      defer { Task { await ProximiioHub.shared.publishState() } }
      try await sdk.start()
      await ProximiioHub.shared.subscribeRunStreams()
    }
  }

  func stop(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      await sdk.stop()
      ProximiioHub.shared.cancelRunStreams()
      await ProximiioHub.shared.publishState()
    }
  }

  func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
    run(completion) { sdk in
      defer { Task { await ProximiioHub.shared.publishState() } }
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

  func setLogLevel(level: MsgLogLevel) throws {
    Proximiio.logLevel = Mappers.logLevel(level)
  }

  func updateServiceNotification(options: MsgAndroidServiceOptions, completion: @escaping (Result<Bool, Error>) -> Void) {
    completion(.failure(Self.androidOnly))
  }

  func resetServiceNotification(completion: @escaping (Result<Void, Error>) -> Void) {
    completion(.failure(Self.androidOnly))
  }

  private static let androidOnly = ProximiioFlutterError(
    code: "unsupported",
    message: "The foreground-service notification exists only on Android.",
    details: nil
  )
}
