class ProximiioInitState {
  final bool ready;
  final String visitorId;

  ProximiioInitState({
    required this.ready,
    required this.visitorId,
  });

  factory ProximiioInitState.fromMap(Map<String, dynamic> map) {
    return ProximiioInitState(
      ready: map['ready'] as bool,
      visitorId: map['visitorId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ready': ready,
      'visitorId': visitorId,
    };
  }

  @override
  String toString() {
    return 'ProximiioInitState(ready: $ready, visitorId: $visitorId)';
  }
}
