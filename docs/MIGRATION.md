# Migrating from flutter_proximiio 1.x to 6.0

6.0 moves the plugin from the Proximi.io SDK 5.x to SDK v6 and replaces the Dart API. Nothing of the
1.x API remains; the steps below map each use.

## 1. Platform setup

- iOS 15 and the `Proximiio` pod line in the Podfile (see README). Remove any `pod 'Proximiio', '5.x'`.
- Android: minSdk 26, compileSdk 37, AGP 8.13+, Kotlin 2.2+. Remove the old repositories
  `maven.proximi.io/repository/android-releases`, the IndoorAtlas and Mapbox repositories, unless
  something else in the app needs them.

## 2. Setup and lifecycle

| 1.x | 6.0 |
|---|---|
| `FlutterProximiio.authorize(token)` (also started positioning on iOS, not on Android) | `final sdk = await Proximiio.create(ProximiioConfiguration(token: token));` then `await sdk.authenticate();` and `await sdk.start();` |
| `ProximiioInitState.visitorId` | `await sdk.visitorId()` |
| `FlutterProximiio.requestPermissions(useAlways: true)` | `await sdk.requestPermissions(always: true)`: returns a `PermissionStatus` on both platforms |
| `FlutterProximiio.enable()` / `disable()` | `sdk.start()` / `sdk.stop()` |
| `setNativeAccuracy(NativeAccuracy.x)` | `ProximiioConfiguration(desiredAccuracy: DesiredAccuracy.x)` |
| `setBufferSize(...)` | removed; v6 has no position buffer setting |
| `setNotificationMode/Title/Text/Icon` + `updateOptions()` | `ProximiioConfiguration(android: AndroidServiceOptions(...))`, at runtime `sdk.android.updateServiceNotification(...)` |

## 3. Events

`subscribe(ProximiioEvents.x, callback)` becomes a typed stream; cancel the `StreamSubscription` instead
of `unsubscribe`.

| 1.x event | 6.0 stream |
|---|---|
| `positionUpdated` (`ProximiioLocation`) | `sdk.positions` (`PositionUpdate`: `coordinate`, `horizontalAccuracy`, `floor`, `source`, `timestamp`) |
| `floorChanged` (`ProximiioFloor`) | `sdk.floorChanges` (`FloorChangeEvent`: `previousFloor`, `floor`, `direction`, `source`) |
| `enteredGeofence` / `exitedGeofence` | `sdk.geofenceEvents`: `GeofenceEntered`, `GeofenceExited` (with `dwellTime` as a `Duration`) |
| `enteredPrivacyZone` / `exitedPrivacyZone` | `sdk.geofenceEvents`: `PrivacyZoneEntered`, `PrivacyZoneExited`; and `sdk.privacyZoneStateChanges` |
| `foundIBeacon`, `lostIBeacon`, `foundEddystoneBeacon`, … | not in 6.0-beta.1 yet (planned: `beaconEvents`) |

## 4. Data

| 1.x | 6.0 |
|---|---|
| `currentFloor()` | `sdk.currentFloor()` |
| `floors()`, `floorById(id)` | `sdk.floors()`, `sdk.floor(id)` |
| `geofences()`, `geofenceById(id)` | `sdk.geofences()`, then filter by id |
| `currentGeofences()` | `sdk.enteredGeofenceIds()` (ids) |

Model changes: `ProximiioFloor.level` is a `double` (venues can have levels like 0.5);
`ProximiioGeofence.polygon` is a list of `Coordinate`s; metadata is decoded JSON.

## 5. Errors

1.x threw `Exception('Failed to …')`. 6.0 throws `ProximiioException` with a `code`:

```dart
try {
  await sdk.start();
} on ProximiioException catch (e) {
  switch (e.code) {
    case ProximiioErrorCode.locationPermissionDenied:
      // ask again or explain
    case ProximiioErrorCode.notAuthenticated:
      await sdk.authenticate();
    default:
      rethrow;
  }
}
```

## 6. Behaviour that changes without an API rename

- Visitor analytics (positions, geofence events) are reported by default in SDK v6. Set
  `visitorReportingEnabled: false` or call `setVisitorReportingConsent(false)` if the app has no consent.
- A geofence exit is reported `geofenceExitDelay` (default 3 s) after the device leaves.
- `stop()` reports an exit for every geofence the device is in.
