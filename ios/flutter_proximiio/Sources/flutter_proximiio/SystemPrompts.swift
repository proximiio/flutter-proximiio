import CoreBluetooth
import UIKit

/// Waits for the answer to a system permission prompt, without waiting for one that never shows.
///
/// A system prompt makes the app inactive, so a request is given up once the app has been active,
/// with nothing in front of it, for a moment; the status is read again then.
@MainActor
enum SystemPrompt {
  /// How long the app stays active before no prompt is assumed.
  private static let quietNanoseconds: UInt64 = 1_500_000_000
  private static let pollNanoseconds: UInt64 = 250_000_000

  static func answer<Value>(
    to request: @escaping @MainActor () async -> Value,
    orRead read: @escaping @MainActor () async -> Value
  ) async -> Value {
    await withCheckedContinuation { continuation in
      let once = Once(continuation)
      let watchdog = Task { @MainActor in
        await waitUntilNoPrompt()
        guard !Task.isCancelled else { return }
        once.resume(await read())
      }
      Task { @MainActor in
        let value = await request()
        watchdog.cancel()
        once.resume(value)
      }
    }
  }

  /// Returns once the app has been active for ``quietNanoseconds`` in a row, or when cancelled.
  private static func waitUntilNoPrompt() async {
    var active: UInt64 = 0
    while !Task.isCancelled, active < quietNanoseconds {
      try? await Task.sleep(nanoseconds: pollNanoseconds)
      active = UIApplication.shared.applicationState == .active ? active + pollNanoseconds : 0
    }
  }

  /// Resumes a continuation with the first value only.
  private final class Once<Value> {
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
      self.continuation = continuation
    }

    func resume(_ value: Value) {
      continuation?.resume(returning: value)
      continuation = nil
    }
  }
}

/// Shows the Bluetooth prompt the way the SDK's scanner would at `start()`: by creating a central
/// manager while the authorization is undecided.
@MainActor
final class BluetoothPrompt: NSObject, CBCentralManagerDelegate {
  /// Whether the user has not decided yet and the app has the usage description iOS requires;
  /// without it creating a central manager ends the app.
  static var isNeeded: Bool {
    CBManager.authorization == .notDetermined
      && Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil
  }

  /// The prompt on screen; the central manager holds its delegate weakly.
  private static var current: BluetoothPrompt?

  private var manager: CBCentralManager?
  private var continuation: CheckedContinuation<Void, Never>?

  /// Shows the prompt and returns once it is answered.
  static func show() async {
    let prompt = BluetoothPrompt()
    current = prompt
    await withCheckedContinuation { continuation in
      prompt.continuation = continuation
      prompt.manager = CBCentralManager(
        delegate: prompt,
        queue: .main,
        options: [CBCentralManagerOptionShowPowerAlertKey: false]
      )
    }
  }

  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    MainActor.assumeIsolated {
      guard CBManager.authorization != .notDetermined else { return }
      continuation?.resume()
      continuation = nil
      manager = nil
      if Self.current === self { Self.current = nil }
    }
  }
}
