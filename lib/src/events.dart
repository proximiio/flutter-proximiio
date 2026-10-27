import 'models.dart';
import 'value.dart';

/// Lifecycle state of the SDK.
enum ProximiioState {
  /// Created, not authenticated.
  idle,

  /// Token accepted; not positioning.
  authenticated,

  /// [Proximiio.start] in progress.
  starting,

  /// Positioning.
  running,

  /// [Proximiio.stop] in progress.
  stopping,
}

/// Whether the Proximi.io API confirmed the application token in this run; see
/// [Proximiio.tokenStatus].
enum TokenStatus {
  /// The API accepted the token in this run. Venue data syncs and analytics upload.
  verified,

  /// Not confirmed yet: before [Proximiio.authenticate], after a start without a connection, or while
  /// the API refuses the token for less than two hours. Positioning runs on the stored venue data;
  /// nothing syncs or uploads.
  unverified,

  /// The API refused the token for at least two hours (three checks). The SDK stopped and deleted
  /// its local data; [Proximiio.start] throws until [Proximiio.authenticate] succeeds again.
  rejected,
}

/// What produced a position.
enum PositionSource {
  /// Bluetooth beacons.
  bleTrilateration,

  /// The platform location service (GPS, Wi-Fi, fused).
  native,

  /// A position set by the app or a relay.
  custom,

  /// Pedestrian dead reckoning fused with other sources.
  pdrFusion,

  /// Phone-native UWB: the phone's UWB radio ranges compatible anchors (not BlueIoT UWB).
  uwb,

  /// A source added to the SDK after this plugin release.
  unknown,
}

/// A position of the device.
class PositionUpdate with ValueEquality {
  /// Creates a position update.
  const PositionUpdate({
    required this.coordinate,
    required this.horizontalAccuracy,
    required this.source,
    required this.timestamp,
    this.floor,
    this.background = false,
  });

  /// Where the device is.
  final Coordinate coordinate;

  /// Radius of uncertainty in metres.
  final double horizontalAccuracy;

  /// The floor, when known.
  final ProximiioFloor? floor;

  /// What produced the position.
  final PositionSource source;

  /// When the position was measured.
  final DateTime timestamp;

  /// Whether the app was in the background.
  final bool background;

  @override
  List<Object?> get props => [coordinate, horizontalAccuracy, floor, source, timestamp, background];

  @override
  String toString() => 'PositionUpdate($coordinate ±${horizontalAccuracy}m, ${source.name}, floor ${floor?.level})';
}

/// Direction of a floor change.
enum FloorChangeDirection {
  /// To a higher level.
  up,

  /// To a lower level.
  down,

  /// Not known.
  unknown,
}

/// What detected a floor change.
enum FloorChangeSource {
  /// Air pressure.
  barometer,

  /// Beacons.
  beacon,

  /// Set by the app.
  manual,

  /// A source added to the SDK after this plugin release.
  unknown,
}

/// The device changed floor.
class FloorChangeEvent with ValueEquality {
  /// Creates a floor change.
  const FloorChangeEvent({
    required this.direction,
    required this.confidence,
    required this.source,
    required this.timestamp,
    this.previousFloor,
    this.floor,
  });

  /// The floor before the change.
  final ProximiioFloor? previousFloor;

  /// The floor after the change.
  final ProximiioFloor? floor;

  /// Up or down.
  final FloorChangeDirection direction;

  /// Confidence from 0 to 1.
  final double confidence;

  /// What detected the change.
  final FloorChangeSource source;

  /// When the change was detected.
  final DateTime timestamp;

  @override
  List<Object?> get props => [previousFloor, floor, direction, confidence, source, timestamp];

  @override
  String toString() => 'FloorChangeEvent(${previousFloor?.level} → ${floor?.level}, ${source.name})';
}

/// A geofence or privacy-zone transition.
sealed class GeofenceEvent with ValueEquality {
  const GeofenceEvent();
}

/// The device entered a geofence.
final class GeofenceEntered extends GeofenceEvent {
  /// Creates the event.
  const GeofenceEntered(this.geofence);

  /// The geofence.
  final ProximiioGeofence geofence;

  @override
  List<Object?> get props => [geofence];

  @override
  String toString() => 'GeofenceEntered(${geofence.id})';
}

/// The device left a geofence.
final class GeofenceExited extends GeofenceEvent {
  /// Creates the event.
  const GeofenceExited(this.geofence, {required this.dwellTime});

  /// The geofence.
  final ProximiioGeofence geofence;

  /// Time spent inside, as measured by the SDK.
  final Duration dwellTime;

  @override
  List<Object?> get props => [geofence, dwellTime];

  @override
  String toString() => 'GeofenceExited(${geofence.id}, $dwellTime)';
}

/// The device entered a privacy zone.
final class PrivacyZoneEntered extends GeofenceEvent {
  /// Creates the event.
  const PrivacyZoneEntered(this.zone);

  /// The zone.
  final ProximiioPrivacyZone zone;

  @override
  List<Object?> get props => [zone];

  @override
  String toString() => 'PrivacyZoneEntered(${zone.id})';
}

/// The device left a privacy zone.
final class PrivacyZoneExited extends GeofenceEvent {
  /// Creates the event.
  const PrivacyZoneExited(this.zone);

  /// The zone.
  final ProximiioPrivacyZone zone;

  @override
  List<Object?> get props => [zone];

  @override
  String toString() => 'PrivacyZoneExited(${zone.id})';
}

/// Whether positioning is private right now.
class PrivacyZoneState with ValueEquality {
  /// Creates the state.
  const PrivacyZoneState({required this.isInPrivacyZone, required this.isPrivate, this.positioningSourcePrivateSince});

  /// The device is inside a privacy zone.
  final bool isInPrivacyZone;

  /// Since when the positioning source (e.g. a relay) reports the position as private.
  final DateTime? positioningSourcePrivateSince;

  /// Either of the above: the position must be treated as private.
  final bool isPrivate;

  @override
  List<Object?> get props => [isInPrivacyZone, positioningSourcePrivateSince, isPrivate];

  @override
  String toString() => 'PrivacyZoneState(inZone: $isInPrivacyZone, private: $isPrivate)';
}
