class ProximiioPrivacyZone {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final double? radius;

  ProximiioPrivacyZone({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.radius,
  });

  factory ProximiioPrivacyZone.fromMap(Map<String, dynamic> map) {
    return ProximiioPrivacyZone(
      id: map['id'] as String,
      name: map['name'] as String,
      lat: map['lat'] != null ? (map['lat'] as num).toDouble() : null,
      lng: map['lng'] != null ? (map['lng'] as num).toDouble() : null,
      radius: map['radius'] != null ? (map['radius'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
    };
  }

  @override
  String toString() {
    return 'ProximiioPrivacyZone(id: $id, name: $name)';
  }
}
