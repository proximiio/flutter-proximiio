import Flutter
import Proximiio

/// The current sink of one event channel; `nil` while Dart is not listening.
final class EventBox<Value> {
  var sink: PigeonEventSink<Value>?

  func send(_ value: Value) {
    sink?.success(value)
  }
}

final class StateChangesRelay: StateChangesStreamHandler {
  let box = EventBox<MsgStateChange>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgStateChange>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class PermissionUpdatesRelay: PermissionUpdatesStreamHandler {
  let box = EventBox<MsgPermissionStatus>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgPermissionStatus>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class PositionsRelay: PositionsStreamHandler {
  let box = EventBox<MsgPositionUpdate>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgPositionUpdate>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class FloorChangesRelay: FloorChangesStreamHandler {
  let box = EventBox<MsgFloorChange>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgFloorChange>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class GeofenceEventsRelay: GeofenceEventsStreamHandler {
  let box = EventBox<MsgGeofenceEvent>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgGeofenceEvent>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class PrivacyZoneStateChangesRelay: PrivacyZoneStateChangesStreamHandler {
  let box = EventBox<MsgPrivacyZoneState>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgPrivacyZoneState>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

/// The event channels of one Flutter engine.
final class EngineStreams {
  let stateChanges = StateChangesRelay()
  let permissionUpdates = PermissionUpdatesRelay()
  let positions = PositionsRelay()
  let floorChanges = FloorChangesRelay()
  let geofenceEvents = GeofenceEventsRelay()
  let privacyZoneStateChanges = PrivacyZoneStateChangesRelay()

  init(messenger: FlutterBinaryMessenger) {
    StateChangesStreamHandler.register(with: messenger, streamHandler: stateChanges)
    PermissionUpdatesStreamHandler.register(with: messenger, streamHandler: permissionUpdates)
    PositionsStreamHandler.register(with: messenger, streamHandler: positions)
    FloorChangesStreamHandler.register(with: messenger, streamHandler: floorChanges)
    GeofenceEventsStreamHandler.register(with: messenger, streamHandler: geofenceEvents)
    PrivacyZoneStateChangesStreamHandler.register(with: messenger, streamHandler: privacyZoneStateChanges)
  }
}

/// Owns the process-wide SDK instance and fans its streams out to every attached engine.
///
/// One instance per process: it is also stored in `Proximiio.shared`, where the
/// flutter_proximiio_map plugin picks it up.
@MainActor
final class ProximiioHub {
  static let shared = ProximiioHub()

  private(set) var sdk: Proximiio?
  private var engines: [EngineStreams] = []
  private var permissionTask: Task<Void, Never>?
  private var runTasks: [Task<Void, Never>] = []

  func attach(_ engine: EngineStreams) {
    engines.append(engine)
  }

  func detach(_ engine: EngineStreams) {
    engines.removeAll { $0 === engine }
  }

  /// Creates the SDK instance, stopping and replacing the previous one.
  func configure(_ configuration: ProximiioConfiguration) async throws {
    if let previous = sdk {
      cancelRunStreams()
      permissionTask?.cancel()
      await previous.stop()
    }
    let sdk = try Proximiio(configuration: configuration)
    self.sdk = sdk
    Proximiio.shared = sdk
    let updates = await sdk.permissionUpdates()
    permissionTask = forward(updates, map: Mappers.permissionStatus) { $0.permissionUpdates.box }
    await publishState()
  }

  /// The SDK has no state stream, so the bridge publishes the state after each lifecycle call it makes.
  func publishState() async {
    guard let sdk else { return }
    let state = Mappers.state(await sdk.state)
    for engine in engines {
      engine.stateChanges.box.send(MsgStateChange(state: state))
    }
  }

  /// The SDK's streams are run-scoped (they finish at `stop()`), so they are taken again after each `start()`.
  func subscribeRunStreams() async {
    guard let sdk else { return }
    cancelRunStreams()
    let positions = await sdk.positions()
    let floorChanges = await sdk.floorChanges()
    let geofenceEvents = await sdk.geofenceEvents()
    let privacyZoneStates = await sdk.privacyZoneStateChanges()
    runTasks = [
      forward(positions, map: Mappers.position) { $0.positions.box },
      forward(floorChanges, map: Mappers.floorChange) { $0.floorChanges.box },
      forward(geofenceEvents, map: Mappers.geofenceEvent) { $0.geofenceEvents.box },
      forward(privacyZoneStates, map: Mappers.privacyZoneState) { $0.privacyZoneStateChanges.box },
    ]
  }

  func cancelRunStreams() {
    runTasks.forEach { $0.cancel() }
    runTasks = []
  }

  private func forward<Value, Message>(
    _ stream: AsyncStream<Value>,
    map: @escaping (Value) -> Message?,
    to box: @escaping (EngineStreams) -> EventBox<Message>
  ) -> Task<Void, Never> {
    Task { [weak self] in
      for await value in stream {
        guard let self else { return }
        guard let message = map(value) else { continue }
        for engine in self.engines {
          box(engine).send(message)
        }
      }
    }
  }
}
