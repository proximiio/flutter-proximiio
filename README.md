# Flutter Proximiio

Flutter plugin for Proximiio indoor positioning with support for beacons, geofencing, and floor detection.

## Features

- **Indoor Positioning**: Track user location indoors using Proximiio SDK
- **Geofencing**: Detect when users enter or exit geofenced areas
- **Floor Detection**: Automatic floor level detection in multi-story buildings
- **Beacon Support**: iBeacon and Eddystone beacon detection
- **Privacy Zones**: Support for privacy zones where tracking is restricted
- **Cross-Platform**: Works on both iOS and Android

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_proximiio:
    git:
      url: https://github.com/proximiio/flutter-proximiio
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### iOS Configuration

1. Set minimum iOS version to 13.0 in `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

2. Add required permissions to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access to provide indoor positioning</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect beacons for indoor positioning</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to detect beacons for indoor positioning</string>
```

3. Run pod install:

```bash
cd ios && pod install
```

### Android Configuration

1. Set minimum SDK version to 21 in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

2. Add required permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

## Usage

### Basic Setup

```dart
import 'package:flutter_proximiio/flutter_proximiio.dart';

const String token = 'your-proximiio-token';

// Authorize with Proximiio
final state = await FlutterProximiio.authorize(token);

if (state.ready) {
  print('Visitor ID: ${state.visitorId}');

  // Request location permissions
  await FlutterProximiio.requestPermissions();

  // Set GPS accuracy
  await FlutterProximiio.setNativeAccuracy(NativeAccuracy.gps);
}
```

### Position Updates

Subscribe to position updates:

```dart
FlutterProximiio.subscribe(
  ProximiioEvents.positionUpdated,
  (ProximiioLocation location) {
    print('Latitude: ${location.lat}');
    print('Longitude: ${location.lng}');
    print('Accuracy: ${location.accuracy}');
    print('Source: ${location.sourceType}');
  },
);
```

### Floor Detection

Subscribe to floor changes:

```dart
FlutterProximiio.subscribe(
  ProximiioEvents.floorChanged,
  (ProximiioFloor floor) {
    print('Floor: ${floor.name}');
    print('Level: ${floor.level}');
  },
);
```

### Geofence Events

Subscribe to geofence enter/exit events:

```dart
FlutterProximiio.subscribe(
  ProximiioEvents.enteredGeofence,
  (ProximiioGeofence geofence) {
    print('Entered: ${geofence.name}');
  },
);

FlutterProximiio.subscribe(
  ProximiioEvents.exitedGeofence,
  (ProximiioGeofence geofence) {
    print('Exited: ${geofence.name}');
  },
);
```

### Beacon Detection

Subscribe to beacon events:

```dart
// iBeacon events
FlutterProximiio.subscribe(
  ProximiioEvents.foundIBeacon,
  (Map<String, dynamic> beacon) {
    print('Found iBeacon: ${beacon['uuid']}');
  },
);

// Eddystone beacon events
FlutterProximiio.subscribe(
  ProximiioEvents.foundEddystoneBeacon,
  (Map<String, dynamic> beacon) {
    print('Found Eddystone: ${beacon['namespace']}');
  },
);
```

## API Reference

### FlutterProximiio

Main plugin class with static methods:

- `authorize(String token)` - Authorize with Proximiio using your API token
- `requestPermissions({bool useAlways = true})` - Request location permissions
- `enable()` - Enable positioning
- `disable()` - Disable positioning
- `setNativeAccuracy(NativeAccuracy accuracy)` - Set GPS accuracy
- `setBufferSize(BufferSize size)` - Set location buffer size
- `subscribe(String event, Function callback)` - Subscribe to events
- `unsubscribe(String event, String id)` - Unsubscribe from events
- `unsubscribeAll(String event)` - Unsubscribe all listeners for an event
- `currentFloor()` - Get current floor
- `floors()` - Get all floors
- `currentGeofences()` - Get currently active geofences
- `geofences()` - Get all geofences

### ProximiioEvents

Available event types:

- `positionUpdated` - User position updated
- `floorChanged` - Floor changed
- `enteredGeofence` - Entered a geofence
- `exitedGeofence` - Exited a geofence
- `enteredPrivacyZone` - Entered a privacy zone
- `exitedPrivacyZone` - Exited a privacy zone
- `foundIBeacon` - Found an iBeacon
- `lostIBeacon` - Lost an iBeacon
- `foundEddystoneBeacon` - Found an Eddystone beacon
- `lostEddystoneBeacon` - Lost an Eddystone beacon

### NativeAccuracy

GPS accuracy levels:

- `cellular` - ~3km accuracy
- `low` - ~1km accuracy
- `balanced` - ~100m accuracy
- `gps` - Best accuracy

### BufferSize

Location buffer sizes:

- `mini` - Minimal buffer
- `small` - Small buffer
- `medium` - Medium buffer
- `large` - Large buffer
- `extraLarge` - Extra large buffer

## Example

See the [example](example/) folder for a complete Flutter application demonstrating all features.

## Requirements

- Flutter 3.0.0 or higher
- Dart 3.0.0 or higher
- iOS 13.0 or higher
- Android API 21 or higher

## Dependencies

### iOS
- Proximiio iOS SDK 5.3.0

### Android
- Proximiio Android SDK 5.1.16

## Troubleshooting

### iOS Build Issues

If you encounter build issues on iOS:

1. Clean the build folder:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
```

2. Make sure your `Podfile` has the correct platform version:
```ruby
platform :ios, '13.0'
```

### Android Build Issues

If you encounter build issues on Android:

1. Clean the build:
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
```

2. Check your `minSdkVersion` is at least 21.

### Location Not Updating

If location updates are not working:

1. Make sure you've called `requestPermissions()`
2. Check that location permissions are granted in device settings
3. Verify your Proximiio token is valid
4. Call `setNativeAccuracy()` after authorization

## License

MIT

## Support

For issues and questions:
- GitHub: https://github.com/proximiio/flutter-proximiio
- Proximiio Documentation: https://docs.proximi.fi
