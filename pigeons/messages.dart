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

enum MsgTokenStatus { verified, unverified, rejected }

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

enum MsgDevicePlacement { handTexting, handSwinging, pocket, bag, table, unknown }

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

/// The SDK's emission gate (`positioning.distanceFilter`); unset fields keep the SDK's values.
class MsgDistanceFilter {
  /// Metres.
  double? minimumDisplacement;
  double? accuracyDisplacementFactor;
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
  double? bleEvaluationIntervalSeconds;
  MsgDistanceFilter? distanceFilter;
  bool? allowsOfflineStart;
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

/// One PDR step. `timestampSeconds` is on the SDK's monotonic PDR clock, not wall time.
class MsgPdrUpdate {
  MsgPdrUpdate({
    required this.northMeters,
    required this.eastMeters,
    required this.distanceMeters,
    required this.headingDegrees,
    required this.isMoving,
    required this.placement,
    required this.timestampSeconds,
  });

  double northMeters;
  double eastMeters;
  double distanceMeters;
  double headingDegrees;
  bool isMoving;
  MsgDevicePlacement placement;
  double timestampSeconds;
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

// ── Wayfinding ───────────────────────────────────────────────────────────────

enum MsgRouteProfile { pedestrian, wheelchair, stroller, staff }

enum MsgRouteAvoidance {
  elevators,
  escalators,
  staircases,
  ramps,
  narrowPaths,
  hills,
  revolvingDoors,
  ticketGates,
  barriers,
}

enum MsgInstructionKind {
  start,
  continueStraight,
  turnSlightLeft,
  turnLeft,
  turnSharpLeft,
  turnSlightRight,
  turnRight,
  turnSharpRight,
  levelChange,
  arrive,
}

class MsgRouteOptions {
  MsgRouteOptions({required this.profile, required this.avoid});

  MsgRouteProfile profile;
  List<MsgRouteAvoidance> avoid;
}

class MsgRoutePoint {
  MsgRoutePoint({required this.coordinate, required this.level});

  MsgCoordinate coordinate;
  double level;
}

class MsgLevelChange {
  MsgLevelChange({
    required this.featureType,
    required this.fromLevel,
    required this.toLevel,
    required this.coordinate,
  });

  String featureType;
  double fromLevel;
  double toLevel;
  MsgCoordinate coordinate;
}

class MsgRouteSegment {
  MsgRouteSegment({required this.start, required this.end, required this.distanceMeters});

  MsgCoordinate start;
  MsgCoordinate end;
  double distanceMeters;
}

class MsgRouteInstruction {
  MsgRouteInstruction({
    required this.kind,
    required this.coordinate,
    required this.distanceMeters,
    required this.level,
    required this.durationSeconds,
  });

  MsgInstructionKind kind;
  MsgCoordinate coordinate;
  double distanceMeters;
  double level;
  double durationSeconds;

  /// Set when [kind] is `levelChange`.
  MsgLevelChange? levelChange;
}

class MsgComputedRoute {
  MsgComputedRoute({
    required this.coordinates,
    required this.distanceMeters,
    required this.segments,
    required this.level,
    required this.levelChanges,
    required this.instructions,
    required this.durationSeconds,
  });

  List<MsgCoordinate> coordinates;
  double distanceMeters;
  List<MsgRouteSegment> segments;
  double level;
  List<MsgLevelChange> levelChanges;
  List<MsgRouteInstruction> instructions;
  double durationSeconds;
}

class MsgDurationRow {
  MsgDurationRow({required this.seconds});

  List<double?> seconds;
}

// ── Venue data ───────────────────────────────────────────────────────────────

class MsgAmenity {
  MsgAmenity({required this.id, required this.titleTranslations});

  String id;
  String? title;
  String? category;
  String? icon;
  String? details;
  String? metadataJson;
  Map<String, String> titleTranslations;
}

class MsgFeature {
  MsgFeature({
    required this.id,
    required this.type,
    required this.isLevelChanger,
    required this.titleTranslations,
  });

  String id;
  String type;

  /// GeoJSON geometry object, as JSON.
  String? geometryJson;

  /// GeoJSON properties object, as JSON.
  String? propertiesJson;
  double? level;
  String? featureClass;
  String? propertyType;
  bool isLevelChanger;
  Map<String, String> titleTranslations;
}

class MsgDepartment {
  MsgDepartment({required this.id});

  String id;
  String? name;
  String? placeId;
  String? floorId;
  List<String>? tags;
  String? metadataJson;
}

class MsgJourneyWaypoint {
  double? latitude;
  double? longitude;
  double? level;
  String? floorId;
  String? label;
  double? dwellSeconds;
  double? speed;
  double? transitionSeconds;
}

class MsgJourney {
  MsgJourney({required this.waypoints, required this.displayName});

  String? id;
  String? organizationId;
  String? name;
  String? placeId;
  double? speed;
  List<MsgJourneyWaypoint> waypoints;
  String displayName;
}

class MsgVenueDataChange {
  MsgVenueDataChange({required this.kinds});

  /// Open-ended: `features`, `amenities`, `style`, `floors`, `places`, `geofences`, later more.
  List<String> kinds;
}

sealed class MsgSyncEvent {}

class MsgSyncUpdated extends MsgSyncEvent {
  MsgSyncUpdated({required this.entity, required this.id});

  String entity;
  String id;
}

class MsgSyncDeleted extends MsgSyncEvent {
  MsgSyncDeleted({required this.entity, required this.id});

  String entity;
  String id;
}

class MsgSyncCompleted extends MsgSyncEvent {
  MsgSyncCompleted({required this.applied});

  int applied;
}

class MsgSyncFailed extends MsgSyncEvent {
  MsgSyncFailed({required this.reason});

  String reason;
}

class MsgStoreRecreated extends MsgSyncEvent {
  MsgStoreRecreated({required this.reason});

  String reason;
}

// ── Beacons ──────────────────────────────────────────────────────────────────

enum MsgBeaconKind { iBeacon, eddystone, uwbAccessory }

/// iBeacon: [uuid], [major], [minor]; Eddystone: [namespace], [instance]; UWB accessory: [name].
class MsgBeaconIdentifier {
  MsgBeaconIdentifier({required this.kind});

  MsgBeaconKind kind;
  String? uuid;
  int? major;
  int? minor;
  String? namespace;
  String? instance;
  String? name;
}

class MsgBeaconObservation {
  MsgBeaconObservation({required this.identifier, required this.rssi, required this.timestampMs});

  MsgBeaconIdentifier identifier;
  int rssi;
  int? txPower;
  int timestampMs;
  double? calibratedDistance;
}

class MsgBeaconTelemetry {
  MsgBeaconTelemetry({
    required this.batteryMillivolts,
    required this.temperatureCelsius,
    required this.advertisementCount,
    required this.uptimeSeconds,
    required this.receivedAtMs,
  });

  int batteryMillivolts;
  double temperatureCelsius;
  int advertisementCount;
  double uptimeSeconds;
  int receivedAtMs;
}

sealed class MsgBeaconEvent {}

class MsgBeaconFound extends MsgBeaconEvent {
  MsgBeaconFound({required this.observation});

  MsgBeaconObservation observation;
}

class MsgBeaconUpdated extends MsgBeaconEvent {
  MsgBeaconUpdated({required this.observation});

  MsgBeaconObservation observation;
}

class MsgBeaconLost extends MsgBeaconEvent {
  MsgBeaconLost({required this.identifier});

  MsgBeaconIdentifier identifier;
}

class MsgBeaconTelemetryReceived extends MsgBeaconEvent {
  MsgBeaconTelemetryReceived({required this.identifier, required this.telemetry});

  MsgBeaconIdentifier identifier;
  MsgBeaconTelemetry telemetry;
}

// ── Offline, simulation, diagnostics ─────────────────────────────────────────

enum MsgPackageStateKind { missing, downloading, ready, stale, verifying, failed }

class MsgPackageState {
  MsgPackageState({required this.kind});

  MsgPackageStateKind kind;

  /// 0…1 while [kind] is `downloading`.
  double? progress;

  /// Set when [kind] is `ready`.
  int? version;
}

enum MsgSimulationState { idle, running, paused }

class MsgSimulatedWaypoint {
  MsgSimulatedWaypoint({required this.coordinate, required this.level});

  MsgCoordinate coordinate;
  int level;
}

class MsgSimulatedRoute {
  MsgSimulatedRoute({
    required this.waypoints,
    required this.speed,
    required this.updateIntervalSeconds,
    required this.loops,
    required this.accuracy,
  });

  List<MsgSimulatedWaypoint> waypoints;
  double speed;
  double updateIntervalSeconds;
  bool loops;
  double accuracy;
}

class MsgDiagnostics {
  MsgDiagnostics({
    required this.state,
    required this.isStarted,
    required this.isAuthenticated,
    required this.visibleBeaconCount,
    required this.registeredBeaconCount,
    required this.pdrEnabled,
    required this.pdrRunning,
    required this.visitorReportingEnabled,
    required this.summary,
    required this.generatedAtMs,
  });

  MsgSdkState state;
  bool isStarted;
  bool isAuthenticated;
  MsgPermissionStatus? permissions;
  int visibleBeaconCount;
  int registeredBeaconCount;
  double? lastPositionAgeSeconds;
  MsgPositionSource? lastPositionSource;
  bool pdrEnabled;
  bool pdrRunning;
  bool visitorReportingEnabled;

  /// `notStarted`, `noViablePositioningInputs`, `awaitingFirstFix`, … (the SDK's raw value).
  String? noPositionReason;
  String summary;
  int generatedAtMs;
}

// ── APIs ─────────────────────────────────────────────────────────────────────

/// Calls from Dart into the process-wide SDK instance.
///
/// Errors arrive as `ProximiioFlutterError` with `code` = the SDK's `ProximiioError`
/// case name (`invalidToken`, `locationPermissionDenied`, …) or a bridge code
/// (`notConfigured`, `invalidArgument`, `unsupported`).
@HostApi()
abstract class ProximiioHostApi {
  /// Creates the SDK instance (stopping and replacing an existing one) and
  /// stores it in `Proximiio.shared` for the map plugin.
  @async
  void configure(MsgConfiguration configuration);

  /// Whether an SDK instance exists in this process (made by any engine).
  bool isConfigured();

  @async
  MsgSdkState state();

  @async
  MsgTokenStatus tokenStatus();

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

  // ── Wayfinding ──

  /// Throws `noRoute` with `reason` (and `nearestDistanceMeters` / `blockedBy`) in the details.
  @async
  MsgComputedRoute computeRoute(
    MsgCoordinate from,
    double fromLevel,
    MsgCoordinate to,
    double toLevel,
    MsgRouteOptions options,
  );

  /// Walking seconds between every pair of [points]; `null` where no route exists.
  @async
  List<MsgDurationRow> routeDurations(List<MsgRoutePoint> points, MsgRouteOptions options);

  /// Downloads the venue features (when changed), stores them and installs the route network.
  @async
  int loadRouteNetwork();

  /// Installs the route network from the stored features, without a request. `0` when none are stored.
  @async
  int loadCachedRouteNetwork();

  // ── Venue data ──

  @async
  List<MsgAmenity> amenities();

  @async
  List<MsgFeature> features();

  @async
  List<MsgDepartment> departments();

  /// The organisation's MapLibre style document, as JSON.
  @async
  String mapStyle();

  @async
  List<MsgJourney> journeys();

  @async
  MsgJourney journey(String id);

  // ── Offline packages ──

  @async
  MsgPackageState syncOfflinePackage(String packageId, String? place, bool allowsCellular);

  @async
  MsgPackageState offlinePackageState(String packageId);

  /// Installs a seed from a directory on disk (unpacked package files).
  @async
  void installOfflineSeed(String packageId, String directory);

  @async
  void removeOfflinePackage(String packageId);

  @async
  int offlinePackageDiskUsage(String packageId);

  // ── Simulation ──

  @async
  MsgPositionUpdate? simulatePosition(MsgCoordinate coordinate, int level, double accuracy);

  @async
  void startSimulation(MsgSimulatedRoute route);

  @async
  void pauseSimulation();

  @async
  void resumeSimulation();

  @async
  void stopSimulation();

  @async
  void jumpToWaypoint(int index);

  @async
  MsgSimulationState simulationState();

  // ── Positioning inputs ──

  /// [floorId] is looked up in the SDK's floors; unknown ids mean "no floor".
  @async
  MsgPositionUpdate? setCustomPosition(MsgCoordinate coordinate, double accuracy, String? floorId);

  @async
  MsgFloorChange? setFloor(String? floorId);

  /// `null` [thresholdMeters] keeps the SDK default.
  @async
  void enableRouteSnapping(double? thresholdMeters);

  @async
  void disableRouteSnapping();

  @async
  void enablePdr();

  @async
  void disablePdr();

  @async
  void setPositioningSourcePrivate(int? sinceMs);

  // ── Diagnostics ──

  @async
  MsgDiagnostics diagnostics();

  @async
  void startDiagnosticsRecording();

  @async
  void stopDiagnosticsRecording();

  /// Path of the zipped report.
  @async
  String prepareDiagnosticsReport();
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

  MsgVenueDataChange venueDataChanges();

  MsgSyncEvent syncEvents();

  MsgBeaconEvent beaconEvents();

  MsgPdrUpdate pdrObservations();
}
