class ProximiioInput {
  final String id;
  final String name;
  final String type;
  final double? accuracy;
  final int? rssi;
  final String? uuid;
  final int? major;
  final int? minor;
  final String? namespace;
  final String? instanceId;

  ProximiioInput({
    required this.id,
    required this.name,
    required this.type,
    this.accuracy,
    this.rssi,
    this.uuid,
    this.major,
    this.minor,
    this.namespace,
    this.instanceId,
  });

  factory ProximiioInput.fromMap(Map<String, dynamic> map) {
    return ProximiioInput(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      rssi: map['rssi'] as int?,
      uuid: map['uuid'] as String?,
      major: map['major'] as int?,
      minor: map['minor'] as int?,
      namespace: map['namespace'] as String?,
      instanceId: map['instanceId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'accuracy': accuracy,
      'rssi': rssi,
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'namespace': namespace,
      'instanceId': instanceId,
    };
  }

  @override
  String toString() {
    return 'ProximiioInput(id: $id, name: $name, type: $type)';
  }
}
