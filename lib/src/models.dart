import 'value.dart';

/// A WGS 84 position.
class Coordinate with ValueEquality {
  /// Creates a coordinate.
  const Coordinate({required this.latitude, required this.longitude});

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() => 'Coordinate($latitude, $longitude)';
}

/// The Proximi.io application the token belongs to.
class ProximiioApplication with ValueEquality {
  /// Creates an application.
  const ProximiioApplication({required this.id, this.name});

  /// Application id.
  final String id;

  /// Application name.
  final String? name;

  @override
  List<Object?> get props => [id, name];

  @override
  String toString() => 'ProximiioApplication($id, $name)';
}

/// A venue (building, site).
class ProximiioPlace with ValueEquality {
  /// Creates a place.
  const ProximiioPlace({required this.id, this.name, this.address, this.tags, this.location, this.metadata});

  /// Place id.
  final String id;

  /// Display name.
  final String? name;

  /// Postal address.
  final String? address;

  /// Tags set in the Proximi.io portal.
  final List<String>? tags;

  /// Location of the place.
  final Coordinate? location;

  /// Custom metadata, decoded from JSON (`Map`, `List`, `String`, `num`, `bool`).
  final Object? metadata;

  @override
  List<Object?> get props => [id, name, address, tags, location, metadata];

  @override
  String toString() => 'ProximiioPlace($id, $name)';
}

/// A floor of a place.
class ProximiioFloor with ValueEquality {
  /// Creates a floor.
  const ProximiioFloor({
    required this.id,
    required this.level,
    this.name,
    this.placeId,
    this.floorId,
    this.anchors = const [],
    this.floorPlanImageUrl,
    this.metadata,
  });

  /// Floor id.
  final String id;

  /// Display name.
  final String? name;

  /// Id of the place the floor belongs to.
  final String? placeId;

  /// Floor id as used by the map data, when it differs from [id].
  final String? floorId;

  /// Level number. A `double`: venues may have intermediate levels such as 0.5.
  final double level;

  /// Corners of the floor plan image.
  final List<Coordinate> anchors;

  /// URL of the floor plan image.
  final String? floorPlanImageUrl;

  /// Custom metadata, decoded from JSON.
  final Object? metadata;

  @override
  List<Object?> get props => [id, name, placeId, floorId, level, anchors, floorPlanImageUrl, metadata];

  @override
  String toString() => 'ProximiioFloor($id, $name, level $level)';
}

/// Why the SDK could not read a zone's geometry.
enum GeometryIssue {
  /// The area could not be decoded.
  unreadableArea,

  /// The outline has too few distinct points to enclose an area.
  degenerateOutline,
}

/// A geofence: a circle ([area] + [radius]) or a polygon ([polygon]).
class ProximiioGeofence with ValueEquality {
  /// Creates a geofence.
  const ProximiioGeofence({
    required this.id,
    required this.radius,
    this.name,
    this.type,
    this.area,
    this.polygon,
    this.address,
    this.placeId,
    this.departmentId,
    this.floorId,
    this.remoteId,
    this.metadata,
    this.geometryIssue,
  });

  /// Geofence id.
  final String id;

  /// Display name.
  final String? name;

  /// Geofence type set in the portal.
  final String? type;

  /// Centre of a circular geofence.
  final Coordinate? area;

  /// Radius in metres of a circular geofence.
  final double radius;

  /// Outline of a polygon geofence.
  final List<Coordinate>? polygon;

  /// Address.
  final String? address;

  /// Id of the place.
  final String? placeId;

  /// Id of the department.
  final String? departmentId;

  /// Id of the floor.
  final String? floorId;

  /// Id in an external system.
  final String? remoteId;

  /// Custom metadata, decoded from JSON.
  final Object? metadata;

  /// Set when the SDK could not read the geometry; such a geofence never triggers.
  final GeometryIssue? geometryIssue;

  /// Whether the geofence is a polygon.
  bool get isPolygon => polygon != null && polygon!.length >= 3;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    area,
    radius,
    polygon,
    address,
    placeId,
    departmentId,
    floorId,
    remoteId,
    metadata,
    geometryIssue,
  ];

  @override
  String toString() => 'ProximiioGeofence($id, $name)';
}

/// A privacy zone: an area where positioning is held back or marked private.
class ProximiioPrivacyZone with ValueEquality {
  /// Creates a privacy zone.
  const ProximiioPrivacyZone({
    required this.id,
    required this.radius,
    this.name,
    this.type,
    this.area,
    this.polygon,
    this.address,
    this.placeId,
    this.departmentId,
    this.floorId,
    this.metadata,
    this.geometryIssue,
  });

  /// Zone id.
  final String id;

  /// Display name.
  final String? name;

  /// Zone type set in the portal.
  final String? type;

  /// Centre of a circular zone.
  final Coordinate? area;

  /// Radius in metres of a circular zone.
  final double radius;

  /// Outline of a polygon zone.
  final List<Coordinate>? polygon;

  /// Address.
  final String? address;

  /// Id of the place.
  final String? placeId;

  /// Id of the department.
  final String? departmentId;

  /// Id of the floor.
  final String? floorId;

  /// Custom metadata, decoded from JSON.
  final Object? metadata;

  /// Set when the SDK could not read the geometry.
  final GeometryIssue? geometryIssue;

  /// Whether the zone is a polygon.
  bool get isPolygon => polygon != null && polygon!.length >= 3;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    area,
    radius,
    polygon,
    address,
    placeId,
    departmentId,
    floorId,
    metadata,
    geometryIssue,
  ];

  @override
  String toString() => 'ProximiioPrivacyZone($id, $name)';
}

/// Location permission.
enum LocationAuthorization {
  /// Not asked yet.
  notDetermined,

  /// Granted while the app is in use.
  whenInUse,

  /// Granted always, including in the background.
  always,

  /// Denied by the user.
  denied,

  /// Not available to this app (parental controls, device policy).
  restricted,
}

/// Location accuracy the user granted.
enum LocationAccuracyAuthorization {
  /// Precise location.
  full,

  /// Approximate location only; indoor positioning does not work.
  reduced,
}

/// Bluetooth permission.
enum BluetoothAuthorization {
  /// Not asked yet.
  notDetermined,

  /// Granted.
  allowed,

  /// Denied by the user.
  denied,

  /// Not available to this app.
  restricted,
}

/// Motion and fitness (activity recognition) permission.
enum MotionAuthorization {
  /// Not asked yet.
  notDetermined,

  /// Granted.
  authorized,

  /// Denied by the user.
  denied,

  /// Not available to this app.
  restricted,

  /// The device has no motion hardware.
  unavailable,
}

/// The permissions the SDK depends on.
class PermissionStatus with ValueEquality {
  /// Creates a permission status.
  const PermissionStatus({
    required this.location,
    required this.accuracy,
    required this.bluetooth,
    required this.motion,
  });

  /// Location permission.
  final LocationAuthorization location;

  /// Location accuracy.
  final LocationAccuracyAuthorization accuracy;

  /// Bluetooth permission.
  final BluetoothAuthorization bluetooth;

  /// Motion permission.
  final MotionAuthorization motion;

  /// Whether location is granted (in use or always).
  bool get isLocationAuthorized =>
      location == LocationAuthorization.whenInUse || location == LocationAuthorization.always;

  @override
  List<Object?> get props => [location, accuracy, bluetooth, motion];

  @override
  String toString() =>
      'PermissionStatus(location: ${location.name}, accuracy: ${accuracy.name}, '
      'bluetooth: ${bluetooth.name}, motion: ${motion.name})';
}
