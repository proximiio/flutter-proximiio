# Changelog

All notable changes to `flutter_proximiio` are documented here.
The format follows [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/), versions follow
[SemVer](https://semver.org/). Each release pins exact native SDK versions (see README).

## [Unreleased]

### Added
- `Proximiio.create(ProximiioConfiguration)`: one process-wide SDK instance, shared with
  `flutter_proximiio_map`. Configuration presets (`standard`, `highAccuracy`, `lowPower`, `relayOnly`) with
  overrides for API host, fallback hosts, sync interval, accuracy, background updates, visitor reporting,
  geofence exit delay, privacy-zone withholding, custom iBeacon UUIDs, PDR fusion, barometer (iOS) and the
  Android foreground-service notification.
- Lifecycle `requestPermissions`, `requestMotionPermission`, `authenticate`, `start`, `stop`, `signOut`, `sync`,
  `state`.
- Typed streams `stateChanges`, `permissionUpdates`, `positions`, `floorChanges`, `geofenceEvents`
  (sealed `GeofenceEntered` / `GeofenceExited` with `dwellTime` / `PrivacyZoneEntered` / `PrivacyZoneExited`),
  `privacyZoneStateChanges`. They stay open across `stop()` / `start()`.
- Venue data `application`, `places`, `floors`, `geofences`, `privacyZones`, `place(id)`, `floor(id)`,
  `currentFloor`, `lastPosition`, `enteredGeofenceIds`, `isInPrivacyZone`.
- Visitor analytics `visitorId`, `resetVisitorId`, `visitorReportingConsent`, `setVisitorReportingConsent`;
  `Proximiio.setLogLevel`.
- Android: `sdk.android.updateServiceNotification` / `resetServiceNotification`. Bluetooth and (with the
  service notification on) notification permissions are asked by `requestPermissions`, as iOS does.
- `ProximiioException` with a `code` per SDK error case, `isRetryable`, and API failure details.
- Swift Package Manager support on iOS next to CocoaPods.

### Changed
- BREAKING: the plugin is rebuilt on the Proximi.io SDK v6 (iOS `Proximiio` 6.0.0-beta.64, Android
  `io.proximi.sdk:proximiio` 6.0.0-beta.31). The 1.x API (`FlutterProximiio.authorize`, `subscribe`,
  `ProximiioEvents`) is removed; see the migration guide in `docs/MIGRATION.md`.
- BREAKING: minimum platforms are iOS 15 and Android API 26.

## [1.0.0]

### Added
- First release on the legacy Proximi.io SDK 5.x (iOS 5.3.0, Android 5.1.16).
