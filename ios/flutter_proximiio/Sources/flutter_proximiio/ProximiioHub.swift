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

final class VenueDataChangesRelay: VenueDataChangesStreamHandler {
  let box = EventBox<MsgVenueDataChange>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgVenueDataChange>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class SyncEventsRelay: SyncEventsStreamHandler {
  let box = EventBox<MsgSyncEvent>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgSyncEvent>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class BeaconEventsRelay: BeaconEventsStreamHandler {
  let box = EventBox<MsgBeaconEvent>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgBeaconEvent>) { box.sink = sink }
  override func onCancel(withArguments arguments: Any?) { box.sink = nil }
}

final class PdrObservationsRelay: PdrObservationsStreamHandler {
  let box = EventBox<MsgPdrUpdate>()
  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<MsgPdrUpdate>) { box.sink = sink }
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
  let venueDataChanges = VenueDataChangesRelay()
  let syncEvents = SyncEventsRelay()
  let beaconEvents = BeaconEventsRelay()
  let pdrObservations = PdrObservationsRelay()

  init(messenger: FlutterBinaryMessenger) {
    VenueDataChangesStreamHandler.register(with: messenger, streamHandler: venueDataChanges)
    SyncEventsStreamHandler.register(with: messenger, streamHandler: syncEvents)
    BeaconEventsStreamHandler.register(with: messenger, streamHandler: beaconEvents)
    PdrObservationsStreamHandler.register(with: messenger, streamHandler: pdrObservations)
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

  /// How long the forwarders get to deliver the exits `stop()` reports before they are cancelled.
  private static let streamDrainNanoseconds: UInt64 = 1_000_000_000
  private static let drainPollNanoseconds: UInt64 = 20_000_000

  private(set) var sdk: Proximiio?

  /// Whether the configuration scans BLE beacons or UWB anchors, so the plugin asks for Bluetooth.
  private(set) var usesBluetooth = false

  private var engines: [EngineStreams] = []
  private var permissionTask: Task<Void, Never>?
  private var runTasks: [Task<Void, Never>] = []
  /// Forwarders in `runTasks` whose stream has not finished.
  private var openRunStreams = 0
  private var lifecycleTail: Task<Void, Never>?

  func attach(_ engine: EngineStreams) {
    engines.append(engine)
  }

  func detach(_ engine: EngineStreams) {
    engines.removeAll { $0 === engine }
  }

  /// Runs configure, authenticate, start, stop and sign-out one at a time across all engines, so
  /// each runs on the instance current when its turn comes.
  func lifecycle<Value>(_ body: @escaping @MainActor () async throws -> Value) async throws -> Value {
    let previous = lifecycleTail
    let task = Task { @MainActor () async throws -> Value in
      await previous?.value
      return try await body()
    }
    lifecycleTail = Task { @MainActor in _ = try? await task.value }
    return try await task.value
  }

  /// Creates the SDK instance and replaces the previous one. The previous instance is stopped first,
  /// with its streams still forwarded so the exits `stop()` reports reach Dart. When the new instance
  /// cannot be created, the previous one stays (stopped). Call it inside ``lifecycle(_:)``.
  func configure(_ configuration: ProximiioConfiguration) async throws {
    let usesBluetooth = configuration.positioning.iBeaconScanningEnabled
      || configuration.positioning.eddystoneScanningEnabled
      || configuration.positioning.trilateration.uwbEnabled
    if let previous = sdk { await stopAndDrain(previous) }
    let sdk = try Proximiio(configuration: configuration)
    cancelRunStreams()
    permissionTask?.cancel()
    self.sdk = sdk
    self.usesBluetooth = usesBluetooth
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

  /// Takes the SDK's run-scoped streams unless they are still open. They are taken before `start()`,
  /// so the events `start()` itself emits are not missed, and they finish at `stop()`; a `start()` of a
  /// running SDK keeps the ones it has.
  func ensureRunStreams() async {
    guard let sdk, runTasks.isEmpty || openRunStreams < runTasks.count else { return }
    cancelRunStreams()
    let positions = await sdk.positions()
    let floorChanges = await sdk.floorChanges()
    let geofenceEvents = await sdk.geofenceEvents()
    let privacyZoneStates = await sdk.privacyZoneStateChanges()
    let venueDataChanges = await sdk.venueDataChanges()
    let syncEvents = await sdk.syncEvents()
    let beaconEvents = await sdk.beaconEvents()
    let pdrObservations = await sdk.pdrObservations()
    let finished = { @MainActor [weak self] () -> Void in self?.openRunStreams -= 1 }
    runTasks = [
      forward(positions, map: Mappers.position, onFinish: finished) { $0.positions.box },
      forward(floorChanges, map: Mappers.floorChange, onFinish: finished) { $0.floorChanges.box },
      forward(geofenceEvents, map: Mappers.geofenceEvent, onFinish: finished) { $0.geofenceEvents.box },
      forward(privacyZoneStates, map: Mappers.privacyZoneState, onFinish: finished) { $0.privacyZoneStateChanges.box },
      forward(venueDataChanges, map: VenueMappers.venueDataChange, onFinish: finished) { $0.venueDataChanges.box },
      forward(syncEvents, map: VenueMappers.syncEvent, onFinish: finished) { $0.syncEvents.box },
      forward(beaconEvents, map: VenueMappers.beaconEvent, onFinish: finished) { $0.beaconEvents.box },
      forward(pdrObservations, map: Mappers.pdrUpdate, onFinish: finished) { $0.pdrObservations.box },
    ]
    openRunStreams = runTasks.count
  }

  /// Stops `sdk`. When it was running, `stop()` finishes its streams after the exits it reports, and
  /// the forwarders are given time to deliver them; the streams of an SDK that was not running stay
  /// open for its next start.
  func stopAndDrain(_ sdk: Proximiio) async {
    let state = await sdk.state
    let wasRunning = state == .running || state == .starting
    await sdk.stop()
    guard wasRunning else { return }
    var waited: UInt64 = 0
    while openRunStreams > 0, waited < Self.streamDrainNanoseconds {
      try? await Task.sleep(nanoseconds: Self.drainPollNanoseconds)
      waited += Self.drainPollNanoseconds
    }
    cancelRunStreams()
  }

  func cancelRunStreams() {
    runTasks.forEach { $0.cancel() }
    runTasks = []
    openRunStreams = 0
  }

  private func forward<Value, Message>(
    _ stream: AsyncStream<Value>,
    map: @escaping (Value) -> Message?,
    onFinish: (@MainActor () -> Void)? = nil,
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
      if !Task.isCancelled { onFinish?() }
    }
  }
}
