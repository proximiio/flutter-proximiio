# Changelog

All notable changes to `flutter_proximiio` are documented here.
The format follows [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/), versions follow
[SemVer](https://semver.org/). Each release pins exact native SDK versions (see README).

## [Unreleased]

## [6.0.0-beta.5] - 2026-10-29

### Added
- `ProximiioAmenity.metadata`: what the venue's editors attached to the amenity, decoded from JSON, such as
  whether it is listed in search. `ProximiioAmenity.titleTranslations` and `localizedTitle([language])`: the
  title in one language.
- Android: `tokenStatus()` works; it threw `unsupported` before. `allowsOfflineStart` applies on Android too.

### Changed
- The plugin builds on the iOS SDK 6.0.0-beta.67 (was 6.0.0-beta.66) and the Android SDK 6.0.0-beta.35 (was
  6.0.0-beta.31).
- Behaviour change, Android: **phones see BLE beacons.** Before, the Android SDK reported no iBeacon or Eddystone
  beacon: `beaconEvents` stayed silent, `diagnostics()` counted 0 visible beacons, and positions came only from the
  platform location and PDR. Now Android positions from beacons, with the floor, as iOS does. Android reports every
  iBeacon in range; iOS reports only the UUIDs it ranges.
- Behaviour change, Android: the beacon scan starts when Bluetooth access is granted, or Bluetooth is switched on,
  after `start()`. Before, it stayed off until the next `start()`.
- Behaviour change, Android: `authenticate()` succeeds without a connection when the API accepted this token on
  this phone before (`allowsOfflineStart`, default `true`); `tokenStatus()` is then `unverified`. It used to throw
  `api`. A token the API keeps refusing for at least two hours stops the SDK and deletes its local data, as on iOS.
- Behaviour change, both platforms: places, floors, departments, geofences, privacy zones and inputs deleted on the
  server leave the phone within about 15 minutes, even when the change log missed the deletion. Each arrives as
  `SyncDeleted` and in `venueDataChanges`.

### Fixed
- `ProximiioFeature.title(language)` falls back to the base language (`en` for `en-US`) and skips blank
  translations, as the SDKs do.

## [6.0.0-beta.4] - 2026-10-28

### Added
- `Proximiio.pdrObservations`: each PDR step as a `PdrUpdate`, with the step length, the direction of walking
  (`headingDegrees`), `isMoving` and the device placement (`DevicePlacement`). It mirrors `pdrObservations()` of
  the iOS and Android SDKs and delivers steps while PDR runs (`enablePdr()`) with PDR fusion on.

### Fixed
- Docs: `pdrFusionEnabled` and the `highAccuracy` preset only turn on PDR fusion. PDR runs after `enablePdr()`
  (tuning guide, configuration reference, dartdoc).

## [6.0.0-beta.3] - 2026-10-27

### Added
- `ProximiioConfiguration.bleEvaluationInterval`: how often the SDK computes a position from the
  beacons (preset default 2.5 s; 1 s with `highAccuracy`, 5 s with `lowPower`).
- `ProximiioConfiguration.distanceFilter` (`DistanceFilter`): how far a position must move before the
  SDK publishes it (`minimumDisplacement`, default 1.33 m; `accuracyDisplacementFactor`, default 0.5).
- `Proximiio.create` throws `invalidArgument` when `bleEvaluationInterval` is not positive, or a
  `DistanceFilter` value is negative or not finite.
- iOS: `ProximiioConfiguration.allowsOfflineStart` (default `true`) and `Proximiio.tokenStatus()`
  (`TokenStatus.verified`, `unverified`, `rejected`). `tokenStatus()` throws `unsupported` on Android.

### Changed
- iOS: the plugin builds on the Proximi.io iOS SDK 6.0.0-beta.66 (was 6.0.0-beta.64).
- iOS: `authenticate` succeeds without a connection when the API accepted the token on this phone
  before; `tokenStatus()` is then `unverified` until the SDK checks the token online. It gives up
  after 30 s on a network that does not answer.
- iOS: a token the API keeps refusing for at least two hours (three checks) stops the SDK and deletes
  its local data, offline packages included; `tokenStatus()` is then `rejected`.
- iOS: `Proximiio.create` no longer throws `invalidArgument` without
  `NSBluetoothAlwaysUsageDescription`. The SDK leaves beacon scanning off, logs an error naming the key
  and reports Bluetooth as denied.
- iOS: `requestPermissions(always: true)` waits for the SDK's answer; the plugin no longer gives up on
  it after the app has been active for 1.5 s.

## [6.0.0-beta.2] - 2026-10-26

### Changed
- BREAKING: the minimum is Flutter 3.44 / Dart 3.12.
- The Android plugin migrates to the Android Gradle Plugin's built-in Kotlin, as Flutter requires of
  plugins. Apps build with and without built-in Kotlin, on the Android Gradle Plugin 8.13 or newer;
  a project created with Flutter 3.44 or newer only sets `minSdk = 26` and `compileSdk = 37`.
- The Android build files use the Kotlin DSL.
- The example app uses the Android toolchain of the current Flutter template (Gradle 9.3, Android
  Gradle Plugin 9.1, Kotlin 2.4) with built-in Kotlin, and builds on the JDK Android Studio bundles.

## [6.0.0-beta.1] - 2026-10-26

### Added
- `Proximiio.create(ProximiioConfiguration)`: one process-wide SDK instance, shared with
  `flutter_proximiio_map`. `Proximiio.shared()` returns it to another engine or screen without
  reconfiguring it. Lifecycle calls from all engines run one at a time. Configuration presets
  (`standard`, `highAccuracy`, `lowPower`, `relayOnly`) with overrides for API host, fallback hosts, sync
  interval, accuracy, background updates, visitor reporting, geofence exit delay, privacy-zone
  withholding, custom iBeacon UUIDs, PDR fusion, barometer (iOS) and the Android foreground-service
  notification.
- Lifecycle `requestPermissions`, `requestMotionPermission`, `authenticate`, `start`, `stop`, `signOut`, `sync`,
  `state`.
- Typed streams `stateChanges`, `permissionUpdates`, `positions`, `floorChanges`, `geofenceEvents`
  (sealed `GeofenceEntered` / `GeofenceExited` with `dwellTime` / `PrivacyZoneEntered` / `PrivacyZoneExited`),
  `privacyZoneStateChanges`. They stay open across `stop()` / `start()`.
- Venue data `application`, `places`, `floors`, `geofences`, `privacyZones`, `place(id)`, `floor(id)`,
  `currentFloor`, `lastPosition`, `enteredGeofenceIds`, `isInPrivacyZone`.
- Visitor analytics `visitorId`, `resetVisitorId`, `visitorReportingConsent`, `setVisitorReportingConsent`;
  `Proximiio.setLogLevel`.
- Streams `venueDataChanges`, `syncEvents` and `beaconEvents` (sealed `BeaconFound` / `BeaconUpdated` /
  `BeaconLost` / `BeaconTelemetryReceived`).
- Wayfinding: `loadRouteNetwork`, `loadCachedRouteNetwork`, `computeRoute` with `RouteOptions` (profiles
  `pedestrian`, `wheelchair`, `stroller`, `staff` and avoidances), `routeDurations`. `ComputedRoute` carries
  segments, level changes and turn-by-turn instructions.
- Venue data `features` (GeoJSON, with titles by language), `amenities`, `departments`, `mapStyle`, `journeys`,
  `journey(id)`.
- Offline packages: `syncOfflinePackage`, `offlinePackageState`, `installOfflineSeed`, `removeOfflinePackage`,
  `offlinePackageDiskUsage`.
- Simulation: `simulatePosition`, `startSimulation`, `pauseSimulation`, `resumeSimulation`, `stopSimulation`,
  `jumpToWaypoint`, `simulationState`.
- Positioning inputs: `setCustomPosition`, `setFloor`, `enableRouteSnapping` / `disableRouteSnapping`,
  `enablePdr` / `disablePdr`, `setPositioningSourcePrivate`.
- Diagnostics: `diagnostics`, `startDiagnosticsRecording`, `stopDiagnosticsRecording`, `prepareDiagnosticsReport`.
- Android: `sdk.android.updateServiceNotification` / `resetServiceNotification`; unset fields keep the
  configured ones, and a tap on the notification opens the app. `requestPermissions` asks Bluetooth
  (both platforms, unless `relayOnly`) and, with `android:` options whose mode is not `disabled`,
  notifications; each once.
  Settings changes reach `permissionUpdates` when the app returns to the foreground.
- `Proximiio.setLogLevel` writes the SDK log to Logcat (tag `Proximiio`) on Android.
- `ProximiioException` with a `code` per SDK error case (`noRoute` with `noRouteReason`, `api` with `kind`, …),
  `isRetryable`, and `underlying` naming the system error behind a failure.
- Swift Package Manager support on iOS next to CocoaPods.
- Documentation site (`docs/site`) in the style of the iOS and Android SDK docs, for Partner Zone.

### Changed
- BREAKING: the plugin is rebuilt on the Proximi.io SDK v6 (iOS `Proximiio` 6.0.0-beta.64, Android
  `io.proximi.sdk:proximiio` 6.0.0-beta.31). The 1.x API (`FlutterProximiio.authorize`, `subscribe`,
  `ProximiioEvents`) is removed; see the migration guide (`docs/site/content/reference/migration.html`).
- BREAKING: minimum platforms are iOS 15 and Android API 26.
- BREAKING: iOS apps need all six usage descriptions (see README); without
  `NSBluetoothAlwaysUsageDescription`, `Proximiio.create` throws `invalidArgument` unless the preset is
  `relayOnly`.
- `withholdsPositionsInPrivacyZones` defaults to `true`, as in 1.x (the native v6 default is `false`).
- On Android the SDK keeps running after the last engine is destroyed only when the foreground service
  runs (`android:` options, mode not `disabled`); 1.x always stopped it.
- The example app uses Swift Package Manager and the UIScene lifecycle on iOS (Flutter 3.38 or newer).

## [1.0.0]

### Added
- First release on the legacy Proximi.io SDK 5.x (iOS 5.3.0, Android 5.1.16).
