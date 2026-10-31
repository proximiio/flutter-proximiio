// The plugin's compass, behind `Proximiio.compassHeadings` in Dart.
//
// Neither SDK has a compass stream; the maps have their own (proximiio-ios-map-v6
// `Sources/ProximiioMapLive/MapCompass.swift`). This uses the same source and the same rules:
// `CLLocationManager.startUpdatingHeading()`, a negative accuracy dropped, the true heading preferred to
// the magnetic one, stopped in the background.
//
// Why Core Location and not CoreMotion: `startUpdatingHeading()` needs no permission and no Info.plist
// key, where CoreMotion brings the Motion & Fitness prompt. Core Location's heading is already the
// system's smoothed fusion of magnetometer and gyroscope, so there is no filter here, only the rate
// limit Android has too (about 10 Hz).
//
// True north: Core Location reports `trueHeading` only while the same manager also updates the
// location. With the location permission granted, the feed runs coarse location updates (a kilometre,
// no GPS of its own) next to the heading; without it, the magnetic heading stands in.

import CoreLocation
import Flutter
import UIKit

/// One compass reading, as `CLHeading` reports it.
struct CompassReading: Equatable {
  /// Degrees from true north, or negative when the location is unknown.
  var trueHeading: Double
  /// Degrees from magnetic north.
  var magneticHeading: Double
  /// The ± error in degrees. Negative means the reading is invalid.
  var headingAccuracy: Double
  var timestamp: Date

  /// The message for this reading, or `nil` when it is invalid.
  var message: MsgCompassHeading? {
    guard headingAccuracy >= 0, headingAccuracy.isFinite else { return nil }
    let isTrueNorth = trueHeading >= 0 && trueHeading.isFinite
    let degrees = isTrueNorth ? trueHeading : magneticHeading
    guard degrees >= 0, degrees.isFinite else { return nil }
    return MsgCompassHeading(
      degrees: degrees.truncatingRemainder(dividingBy: 360),
      accuracyDegrees: headingAccuracy,
      isTrueNorth: isTrueNorth,
      timestampMs: Int64((timestamp.timeIntervalSince1970 * 1000).rounded())
    )
  }
}

/// Runs the compass while Dart listens and the app is in the foreground, and passes readings on at
/// most every ``minimumInterval``, the latest one last.
@MainActor
final class CompassFeed: NSObject, CLLocationManagerDelegate {
  /// About 10 Hz, as on Android.
  static let minimumInterval: TimeInterval = 0.1

  /// Told each reading.
  var onHeading: ((MsgCompassHeading) -> Void)?

  /// Whether Dart listens.
  var isEnabled = false {
    didSet { if isEnabled != oldValue { update() } }
  }

  private(set) var isRunning = false

  private let manager = CLLocationManager()
  private var isInForeground: Bool
  private var updatesLocation = false
  private var lastSentUptime: TimeInterval = -.infinity
  private var pending: MsgCompassHeading?
  private var flushScheduled = false

  override init() {
    isInForeground = UIApplication.shared.applicationState != .background
    super.init()
    // Created on the main actor, so Core Location calls the delegate on the main thread.
    manager.delegate = self
    // 1°: below what a marker shows, above the sensor's jitter.
    manager.headingFilter = 1
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.distanceFilter = 1000
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(applicationDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil
    )
    center.addObserver(
      self, selector: #selector(applicationWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil
    )
  }

  /// The `CLDeviceOrientation` that puts 0° at the top of an interface in `orientation`. The landscape
  /// cases cross over: an interface in `.landscapeLeft` has the device turned to the right.
  static func deviceOrientation(for orientation: UIInterfaceOrientation?) -> CLDeviceOrientation {
    switch orientation {
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight
    case .landscapeRight: return .landscapeLeft
    default: return .portrait
    }
  }

  // MARK: - CLLocationManagerDelegate

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    let reading = CompassReading(
      trueHeading: heading.trueHeading,
      magneticHeading: heading.magneticHeading,
      headingAccuracy: heading.headingAccuracy,
      timestamp: heading.timestamp
    )
    Task { @MainActor [weak self] in self?.receive(reading) }
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor [weak self] in self?.updateLocation() }
  }

  /// The locations only make `trueHeading` valid; nothing reads them.
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

  nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }

  // MARK: - Private

  @objc private func applicationDidEnterBackground() {
    isInForeground = false
    update()
  }

  @objc private func applicationWillEnterForeground() {
    isInForeground = true
    update()
  }

  private func update() {
    let wanted = isEnabled && isInForeground && CLLocationManager.headingAvailable()
    guard wanted != isRunning else { return }
    isRunning = wanted
    if wanted {
      refreshOrientation()
      manager.startUpdatingHeading()
    } else {
      manager.stopUpdatingHeading()
      pending = nil
    }
    updateLocation()
  }

  /// Coarse location updates while the compass runs and the app may read the location.
  private func updateLocation() {
    let status = manager.authorizationStatus
    let wanted = isRunning && (status == .authorizedWhenInUse || status == .authorizedAlways)
    guard wanted != updatesLocation else { return }
    updatesLocation = wanted
    if wanted { manager.startUpdatingLocation() } else { manager.stopUpdatingLocation() }
  }

  private func receive(_ reading: CompassReading) {
    // A reading delivered after a stop is from the run that ended.
    guard isRunning, let message = reading.message else { return }
    refreshOrientation()
    let wait = Self.minimumInterval - (ProcessInfo.processInfo.systemUptime - lastSentUptime)
    guard wait > 0 else {
      send(message)
      return
    }
    pending = message
    guard !flushScheduled else { return }
    flushScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
      MainActor.assumeIsolated { self?.flush() }
    }
  }

  private func flush() {
    flushScheduled = false
    guard isRunning, let message = pending else { return }
    pending = nil
    send(message)
  }

  private func send(_ message: MsgCompassHeading) {
    lastSentUptime = ProcessInfo.processInfo.systemUptime
    onHeading?(message)
  }

  /// Puts 0° at the top of the screen in the interface orientation now; read on start and on every
  /// reading, so a rotation is picked up by the next reading after it.
  private func refreshOrientation() {
    let orientation = Self.deviceOrientation(for: Self.interfaceOrientation())
    if manager.headingOrientation != orientation { manager.headingOrientation = orientation }
  }

  private static func interfaceOrientation() -> UIInterfaceOrientation? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
      return nil
    }
    if #available(iOS 16.0, *) { return scene.effectiveGeometry.interfaceOrientation }
    return scene.interfaceOrientation
  }
}
