// Bridge schema between Dart and the native Proximi.io SDK v6.
//
// Regenerate after any change:
//   dart run pigeon --input pigeons/messages.dart
//
// The classes here are transport types (prefix `Msg`), not the public Dart API:
// lib/src/ maps them to the public models. The prefix also keeps the generated
// Swift/Kotlin types from clashing with the SDK's own `ProximiioFloor` etc.
//
// Times cross the bridge as milliseconds since the epoch, durations as seconds
// (the SDK's unit), JSON metadata as an encoded string.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_proximiio',
    kotlinOut: 'android/src/main/kotlin/io/proximi/flutter_proximiio/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.proximi.flutter_proximiio', errorClassName: 'ProximiioFlutterError'),
    swiftOut: 'ios/flutter_proximiio/Sources/flutter_proximiio/Messages.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'ProximiioFlutterError'),
  ),
)
// ── Enums ────────────────────────────────────────────────────────────────────
enum MsgSdkState { idle, authenticated, starting, running, stopping }

enum MsgConfigurationPreset { standard, highAccuracy, lowPower, relayOnly }

enum MsgDesiredAccuracy { bestForNavigation, best, nearestTenMeters, hundredMeters, kilometer, threeKilometers }

enum MsgServiceNotificationMode { enabled, disabled, required }

enum MsgLogLevel { debug, info, notice, warning, error }

enum MsgLocationAuthorization { notDetermined, whenInUse, always, denied, restricted }

enum MsgLocationAccuracy { full, reduced }

enum MsgBluetoothAuthorization { notDetermined, allowed, denied, restricted }

enum MsgMotionAuthorization { notDetermined, authorized, denied, restricted, unavailable }

enum MsgPositionSource { bleTrilateration, native, custom, pdrFusion, uwb, unknown }

enum MsgFloorChangeDirection { up, down, unknown }

enum MsgFloorChangeSource { barometer, beacon, manual, unknown }

// ── Configuration ────────────────────────────────────────────────────────────

/// Android foreground-service notification. Ignored on iOS.
class MsgAndroidServiceOptions {
  String? notificationTitle;
  String? notificationText;

  /// Drawable resource name in the host app, e.g. `ic_stat_positioning`.
  String? notificationIcon;
  String? channelName;
  String? channelDescription;
  MsgServiceNotificationMode? mode;
  bool? holdsWakeLock;
}

/// Starts from [preset]; every non-null field overrides the preset's value.
class MsgConfiguration {
  MsgConfiguration({
    required this.token,
    required this.preset,
    required this.fallbackApiBaseUrls,
    required this.customIBeaconUuids,
  });

  String token;
  MsgConfigurationPreset preset;
  bool? relayRunsInBackground;
  String? apiBaseUrl;
  List<String> fallbackApiBaseUrls;
  double? syncIntervalSeconds;
  MsgDesiredAccuracy? desiredAccuracy;
  bool? allowsBackgroundLocationUpdates;
  bool? visitorReportingEnabled;
  double? geofenceExitDelaySeconds;
  bool? withholdsPositionsInPrivacyZones;
  List<String> customIBeaconUuids;
  bool? pdrFusionEnabled;
  bool? barometerEnabled;
  MsgAndroidServiceOptions? android;
}

// ── Models ───────────────────────────────────────────────────────────────────

class MsgCoordinate {
  MsgCoordinate({required this.latitude, required this.longitude});

  double latitude;
  double longitude;
}

class MsgApplication {
  MsgApplication({required this.id});

  String id;
  String? name;
}

class MsgPlace {
  MsgPlace({required this.id});

  String id;
  String? name;
  String? address;
  List<String>? tags;
  MsgCoordinate? location;
  String? metadataJson;
}

class MsgFloor {
  MsgFloor({required this.id, required this.level, required this.anchors});

  String id;
  String? name;
  String? placeId;
  String? floorId;
  double level;
  List<MsgCoordinate> anchors;
  String? floorPlanImageUrl;
  String? metadataJson;
}

/// A geofence or a privacy zone (same shape; privacy zones have no `remoteId`).
class MsgZone {
  MsgZone({required this.id, required this.radius});

  String id;
  String? name;
  String? type;
  MsgCoordinate? area;
  double radius;

  /// Outline in latitude/longitude, already converted from the SDK's GeoJSON order.
  List<MsgCoordinate>? polygon;
  String? address;
  String? placeId;
  String? departmentId;
  String? floorId;
  String? remoteId;
  String? metadataJson;

  /// `unreadableArea` or `degenerateOutline`, when the SDK could not read the geometry.
  String? geometryIssue;
}

class MsgPermissionStatus {
  MsgPermissionStatus({required this.location, required this.accuracy, required this.bluetooth, required this.motion});

  MsgLocationAuthorization location;
  MsgLocationAccuracy accuracy;
  MsgBluetoothAuthorization bluetooth;
  MsgMotionAuthorization motion;
}

// ── Events ───────────────────────────────────────────────────────────────────

class MsgStateChange {
  MsgStateChange({required this.state});

  MsgSdkState state;
}

class MsgPositionUpdate {
  MsgPositionUpdate({
    required this.coordinate,
    required this.horizontalAccuracy,
    required this.source,
    required this.timestampMs,
    required this.background,
  });

  MsgCoordinate coordinate;
  double horizontalAccuracy;
  MsgFloor? floor;
  MsgPositionSource source;
  int timestampMs;
  bool background;
}

class MsgFloorChange {
  MsgFloorChange({required this.direction, required this.confidence, required this.source, required this.timestampMs});

  MsgFloor? previousFloor;
  MsgFloor? floor;
  MsgFloorChangeDirection direction;
  double confidence;
  MsgFloorChangeSource source;
  int timestampMs;
}

sealed class MsgGeofenceEvent {}

class MsgGeofenceEntered extends MsgGeofenceEvent {
  MsgGeofenceEntered({required this.geofence});

  MsgZone geofence;
}

class MsgGeofenceExited extends MsgGeofenceEvent {
  MsgGeofenceExited({required this.geofence, required this.dwellTimeSeconds});

  MsgZone geofence;
  double dwellTimeSeconds;
}

class MsgPrivacyZoneEntered extends MsgGeofenceEvent {
  MsgPrivacyZoneEntered({required this.zone});

  MsgZone zone;
}

class MsgPrivacyZoneExited extends MsgGeofenceEvent {
  MsgPrivacyZoneExited({required this.zone});

  MsgZone zone;
}

class MsgPrivacyZoneState {
  MsgPrivacyZoneState({required this.isInPrivacyZone, required this.isPrivate});

  bool isInPrivacyZone;
  int? positioningSourcePrivateSinceMs;
  bool isPrivate;
}

// ── APIs ─────────────────────────────────────────────────────────────────────

/// Calls from Dart into the process-wide SDK instance.
///
/// Errors arrive as `ProximiioFlutterError` with `code` = the SDK's `ProximiioError`
/// case name (`invalidToken`, `locationPermissionDenied`, …) or a bridge code
/// (`notConfigured`, `noActivity`, `invalidArgument`, `unsupported`).
@HostApi()
abstract class ProximiioHostApi {
  /// Creates the SDK instance (stopping and replacing an existing one) and
  /// stores it in `Proximiio.shared` for the map plugin.
  @async
  void configure(MsgConfiguration configuration);

  @async
  MsgSdkState state();

  @async
  MsgPermissionStatus requestPermissions(bool always);

  @async
  bool requestMotionPermission();

  @async
  MsgApplication? authenticate();

  @async
  void start();

  @async
  void stop();

  @async
  void signOut();

  @async
  int sync();

  @async
  MsgApplication? application();

  @async
  List<MsgPlace> places();

  @async
  List<MsgFloor> floors();

  @async
  List<MsgZone> geofences();

  @async
  List<MsgZone> privacyZones();

  @async
  MsgPlace? place(String id);

  @async
  MsgFloor? floor(String id);

  @async
  MsgFloor? currentFloor();

  @async
  MsgPositionUpdate? lastPosition();

  @async
  List<String> enteredGeofenceIds();

  @async
  bool isInPrivacyZone();

  @async
  String visitorId();

  @async
  String resetVisitorId();

  @async
  bool visitorReportingConsent();

  @async
  void setVisitorReportingConsent(bool granted);

  void setLogLevel(MsgLogLevel level);

  /// Android only; `unsupported` on iOS. `false` when the foreground service is not running.
  @async
  bool updateServiceNotification(MsgAndroidServiceOptions options);

  /// Android only; `unsupported` on iOS.
  @async
  void resetServiceNotification();
}

/// Streams from the SDK. They stay open across `stop()`/`start()`: the native side
/// re-subscribes to the SDK's run-scoped streams after every successful `start()`.
@EventChannelApi()
abstract class ProximiioEventApi {
  MsgStateChange stateChanges();

  MsgPermissionStatus permissionUpdates();

  MsgPositionUpdate positions();

  MsgFloorChange floorChanges();

  MsgGeofenceEvent geofenceEvents();

  MsgPrivacyZoneState privacyZoneStateChanges();
}
