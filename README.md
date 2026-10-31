# flutter_proximiio

Proximi.io indoor positioning for Flutter: a typed bridge over the native **Proximi.io SDK v6** for
iOS and Android. Positions, floors, geofences, privacy zones and venue data, with the same names and
behaviour as the native SDKs.

For the map, see [`flutter_proximiio_map`](https://github.com/proximiio/flutter-proximiio-map).

## Native versions

Each release pins exact native SDK versions; they are built and tested together.

| flutter_proximiio | iOS SDK (`Proximiio`) | Android SDK (`io.proximi.sdk:proximiio`) |
|---|---|---|
| 6.0.0-beta.7 | 6.0.0-beta.68 | 6.0.0-beta.36 |
| 6.0.0-beta.6 | 6.0.0-beta.68 | 6.0.0-beta.36 |
| 6.0.0-beta.5 | 6.0.0-beta.67 | 6.0.0-beta.35 |
| 6.0.0-beta.4 | 6.0.0-beta.66 | 6.0.0-beta.31 |
| 6.0.0-beta.3 | 6.0.0-beta.66 | 6.0.0-beta.31 |
| 6.0.0-beta.2 | 6.0.0-beta.64 | 6.0.0-beta.31 |
| 6.0.0-beta.1 | 6.0.0-beta.64 | 6.0.0-beta.31 |

## Requirements

| | Minimum |
|---|---|
| Flutter / Dart | 3.44 / 3.12 |
| iOS | 15.0, Xcode 16 |
| Android | minSdk 26, compileSdk 37, Android Gradle Plugin 8.13, JDK 17 |

## Installation

```yaml
dependencies:
  flutter_proximiio:
    git:
      url: https://github.com/proximiio/flutter-proximiio
      ref: 6.0.0-beta.7
```

### iOS

The SDK pod is not on CocoaPods trunk. Add it to `ios/Podfile` inside the `Runner` target, at the
version from the table above, and set the platform to iOS 15:

```ruby
platform :ios, '15.0'

target 'Runner' do
  use_frameworks!
  pod 'Proximiio', :podspec => 'https://raw.githubusercontent.com/proximiio/proximiio-sdk-ios-binary/6.0.0-beta.68/Proximiio.podspec'
  # …
end
```

With Flutter's Swift Package Manager support turned on, nothing is needed in the Podfile: the plugin's
`Package.swift` pulls `proximiio/proximiio-sdk-ios-binary` itself.

`Info.plist` usage descriptions: add all six, also for features the app does not use. App Store
validation checks them against the APIs the SDK links and rejects the upload without them (ITMS-90683).

| Key | Shown when |
|---|---|
| `NSLocationWhenInUseUsageDescription` | positioning is asked |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | background positioning is asked |
| `NSBluetoothAlwaysUsageDescription` | beacon positioning is asked |
| `NSMotionUsageDescription` | PDR is asked; floor changes from the barometer |
| `NSNearbyInteractionUsageDescription` | UWB anchors are ranged |
| `NSCameraUsageDescription` | camera-assisted UWB direction |

A missing key turns its input off: the SDK logs an error naming the key and reports that permission as
denied. Without `NSBluetoothAlwaysUsageDescription` no beacons are scanned.

For background positioning also add `location` to `UIBackgroundModes` and set
`allowsBackgroundLocationUpdates: true`.

An app built with Xcode 27 ends at launch on iOS 27 unless it uses the UIScene lifecycle. Flutter 3.41 and
newer migrate an unmodified `AppDelegate` on the next build; see Flutter's
[UIScene adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate) guide. The plugin works
with either lifecycle.

### Android

The SDK comes from `https://maven.eu.proximi.fi/releases/` (public, no credentials). The plugin adds the
repository to every project. If your `settings.gradle(.kts)` uses
`RepositoriesMode.FAIL_ON_PROJECT_REPOS`, add it there:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.eu.proximi.fi/releases/")
    }
}
```

In `android/app/build.gradle.kts` set `minSdk = 26` and `compileSdk = 37`. A project created with Flutter
3.44 or newer needs nothing else: its Android Gradle Plugin 9 and Gradle 9 run on the JDK that Android
Studio bundles, with or without built-in Kotlin. An older project needs the Android Gradle Plugin 8.13 or
newer; Gradle before 9.1 does not run on JDK 25.

The SDK's manifest brings the location, Bluetooth, foreground-service, activity-recognition and
notification permissions and its foreground service. Google Play asks for a declaration for background
location, for each foreground-service type and for activity recognition (Health). An app that positions
only while it is open can remove them in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <!-- Positioning only while the app is open. -->
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" tools:node="remove" />
    <!-- No foreground service: leave ProximiioConfiguration.android unset. -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" tools:node="remove" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" tools:node="remove" />
    <!-- No PDR: never call requestMotionPermission() or enablePdr(). -->
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" tools:node="remove" />

    <application>
        <service android:name="io.proximi.sdk.service.ProximiioForegroundService" tools:node="remove" />
    </application>
</manifest>
```

- **The foreground service** starts only when the configuration has `android:` (`AndroidServiceOptions`).
  Without it the service never runs, so its permissions and the `<service>` element can go. The Usage
  snippet below passes `android:` for background positioning; leave it out in a foreground-only app.
- **Activity recognition** feeds PDR only. Without it positions still come from GPS and beacons, a little
  less smoothly between beacon fixes, and `pdrObservations` stays silent. `compassHeadings` needs no
  permission and keeps working.
- **Keep** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`,
  `INTERNET` and `ACCESS_NETWORK_STATE`. Never add `neverForLocation` to `BLUETOOTH_SCAN`: beacon positioning
  derives the location from the scan.

## Usage

```dart
import 'package:flutter_proximiio/flutter_proximiio.dart';

final sdk = await Proximiio.create(
  ProximiioConfiguration(
    token: token,                                   // never commit it; see the example app
    apiBaseUrl: Uri.parse('https://api.proximi.fi'), // the host of your residency group or installation
    // Only for positioning in the background: runs the Android foreground service. Leave it out in an
    // app that positions only while it is open.
    android: const AndroidServiceOptions(notificationTitle: 'Indoor positioning'),
  ),
);

final status = await sdk.requestPermissions();      // location, Bluetooth (+ notifications on Android 13+)
await sdk.authenticate();
await sdk.start();

sdk.positions.listen((position) {
  print('${position.coordinate} ±${position.horizontalAccuracy} m on ${position.floor?.name}');
});

sdk.geofenceEvents.listen((event) {
  switch (event) {
    case GeofenceEntered(:final geofence):
      print('entered ${geofence.name}');
    case GeofenceExited(:final geofence, :final dwellTime):
      print('left ${geofence.name} after $dwellTime');
    case PrivacyZoneEntered() || PrivacyZoneExited():
      break;
  }
});

// Which way the phone points, to turn the position marker. No permission, no start() needed.
sdk.compassHeadings.listen((heading) => print('${heading.degrees}° ±${heading.accuracyDegrees}°'));

final floors = await sdk.floors();
await sdk.stop();
```

- **One instance per process.** `Proximiio.create` makes it; calling it again stops and replaces it.
  `Proximiio.shared()` returns the running instance without touching it (a second engine, another
  screen). `flutter_proximiio_map` uses the same instance.
- **Privacy zones**: positions inside them are withheld by default, as in 1.x
  (`withholdsPositionsInPrivacyZones: false` to receive them; the native v6 default is `false`).
- **Streams** can be listened to at any time and stay open across `stop()` / `start()`.
- **Heading**: `compassHeadings` is the phone's compass (it turns with the phone, also standing still,
  about 10 Hz, smoothed on Android). `pdrObservations` is the direction of walking, once per step and only
  while PDR runs. For a marker that turns with the phone, use the compass.
- **Errors** are `ProximiioException`s; switch on `code` (`invalidToken`, `locationPermissionDenied`,
  `api`, …). `isRetryable` is true for network and server failures.
- **Visitor analytics** are on by default in SDK v6. Turn them off with
  `visitorReportingEnabled: false`, or record the visitor's choice with `setVisitorReportingConsent`.
- Android-only calls live under `sdk.android` and throw `unsupported` on iOS.

## Example app

```sh
cd example
cp env.example.json env.json   # put your application token in env.json (gitignored)
flutter run --dart-define-from-file=env.json
```

The example uses Swift Package Manager and the UIScene lifecycle on iOS and built-in Kotlin on Android
(Flutter 3.47 or newer). Clone the
repository into a directory named `flutter_proximiio`:

```sh
git clone https://github.com/proximiio/flutter-proximiio flutter_proximiio
```

Flutter adds the plugin's Swift package to the example's Xcode project under the checkout's directory
name. When that name differs from the package name, Xcode stops resolving packages with
`unable to override package 'flutter_proximiio'` (seen with Flutter 3.47 and Xcode 27).

## Development

The bridge is generated with [Pigeon](https://pub.dev/packages/pigeon) from `pigeons/messages.dart`:

```sh
dart run pigeon --input pigeons/messages.dart
flutter analyze && flutter test
cd example/android && ./gradlew :flutter_proximiio:testDebugUnitTest
```

Generated files (`*.g.dart`, `Messages.g.kt`, `Messages.g.swift`) are committed; regenerate them in the
same change as the schema.

Documentation: `docs/site` (built with `node docs/site/build.mjs`, published to Partner Zone), including the
migration guide from 1.x. Changes: [CHANGELOG.md](CHANGELOG.md).
