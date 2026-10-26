# flutter_proximiio

Proximi.io indoor positioning for Flutter: a typed bridge over the native **Proximi.io SDK v6** for
iOS and Android. Positions, floors, geofences, privacy zones and venue data, with the same names and
behaviour as the native SDKs.

For the map, see [`flutter_proximiio_map`](https://github.com/proximiio/flutter-proximiio-map).

## Native versions

Each release pins exact native SDK versions; they are built and tested together.

| flutter_proximiio | iOS SDK (`Proximiio`) | Android SDK (`io.proximi.sdk:proximiio`) |
|---|---|---|
| 6.0.0-beta.1 | 6.0.0-beta.64 | 6.0.0-beta.31 |

## Requirements

| | Minimum |
|---|---|
| Flutter / Dart | 3.29 / 3.7 |
| iOS | 15.0, Xcode 16 |
| Android | minSdk 26, compileSdk 37, Android Gradle Plugin 8.13, Gradle 8.13, Kotlin 2.2, JDK 17 |

## Installation

```yaml
dependencies:
  flutter_proximiio:
    git:
      url: https://github.com/proximiio/flutter-proximiio
      ref: 6.0.0-beta.1
```

### iOS

The SDK pod is not on CocoaPods trunk. Add it to `ios/Podfile` inside the `Runner` target, at the
version from the table above, and set the platform to iOS 15:

```ruby
platform :ios, '15.0'

target 'Runner' do
  use_frameworks!
  pod 'Proximiio', :podspec => 'https://raw.githubusercontent.com/proximiio/proximiio-sdk-ios-binary/6.0.0-beta.64/Proximiio.podspec'
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

Without `NSBluetoothAlwaysUsageDescription` iOS ends the app when the SDK scans for beacons, so
`Proximiio.create` throws `invalidArgument` for every preset except `relayOnly`.

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

In `android/app/build.gradle.kts` set `minSdk = 26` and `compileSdk = 37`; in `settings.gradle.kts` use
the Android Gradle Plugin 8.13 or newer and Kotlin 2.2 or newer.

The SDK's manifest brings the location, Bluetooth, foreground-service and notification permissions and
its foreground service. To keep an app foreground-only, remove background location:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" tools:node="remove" />
</manifest>
```

## Usage

```dart
import 'package:flutter_proximiio/flutter_proximiio.dart';

final sdk = await Proximiio.create(
  ProximiioConfiguration(
    token: token,                                   // never commit it; see the example app
    apiBaseUrl: Uri.parse('https://api.proximi.fi'), // the host of your residency group or installation
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

final floors = await sdk.floors();
await sdk.stop();
```

- **One instance per process.** `Proximiio.create` makes it; calling it again stops and replaces it.
  `Proximiio.shared()` returns the running instance without touching it (a second engine, another
  screen). `flutter_proximiio_map` uses the same instance.
- **Privacy zones**: positions inside them are withheld by default, as in 1.x
  (`withholdsPositionsInPrivacyZones: false` to receive them; the native v6 default is `false`).
- **Streams** can be listened to at any time and stay open across `stop()` / `start()`.
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

The example uses Swift Package Manager and the UIScene lifecycle on iOS (Flutter 3.38 or newer). Clone the
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
