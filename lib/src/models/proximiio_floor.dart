class ProximiioFloor {
  final String id;
  final String name;
  final int level;
  final String? placeId;
  final double? anchors;

  ProximiioFloor({
    required this.id,
    required this.name,
    required this.level,
    this.placeId,
    this.anchors,
  });

  factory ProximiioFloor.fromMap(Map<String, dynamic> map) {
    return ProximiioFloor(
      id: map['id'] as String,
      name: map['name'] as String,
      level: map['level'] as int,
      placeId: map['placeId'] as String?,
      anchors: map['anchors'] != null ? (map['anchors'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'placeId': placeId,
      'anchors': anchors,
    };
  }

  @override
  String toString() {
    return 'ProximiioFloor(id: $id, name: $name, level: $level)';
  }
}
