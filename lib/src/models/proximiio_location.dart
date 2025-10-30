class ProximiioLocation {
  final double lat;
  final double lng;
  final double? accuracy;
  final String? sourceType;
  final double? speed;
  final double? bearing;
  final int? timestamp;

  ProximiioLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.sourceType,
    this.speed,
    this.bearing,
    this.timestamp,
  });

  factory ProximiioLocation.fromMap(Map<String, dynamic> map) {
    return ProximiioLocation(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      sourceType: map['sourceType'] as String?,
      speed: map['speed'] != null ? (map['speed'] as num).toDouble() : null,
      bearing: map['bearing'] != null ? (map['bearing'] as num).toDouble() : null,
      timestamp: map['timestamp'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'sourceType': sourceType,
      'speed': speed,
      'bearing': bearing,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'ProximiioLocation(lat: $lat, lng: $lng, accuracy: $accuracy, sourceType: $sourceType)';
  }
}
