class ProximiioGeofence {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final double? radius;
  final String? departmentId;
  final String? floorId;
  final int? level;

  ProximiioGeofence({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.radius,
    this.departmentId,
    this.floorId,
    this.level,
  });

  factory ProximiioGeofence.fromMap(Map<String, dynamic> map) {
    return ProximiioGeofence(
      id: map['id'] as String,
      name: map['name'] as String,
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      radius: map['radius'] != null ? (map['radius'] as num).toDouble() : null,
      departmentId: map['departmentId'] as String?,
      floorId: map['floorId'] as String?,
      level: map['level'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'departmentId': departmentId,
      'floorId': floorId,
      'level': level,
    };
  }

  @override
  String toString() {
    return 'ProximiioGeofence(id: $id, name: $name)';
  }
}
