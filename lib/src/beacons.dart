import 'value.dart';

/// Identity of a beacon or UWB accessory.
sealed class BeaconIdentifier with ValueEquality {
  const BeaconIdentifier();
}

/// An iBeacon.
final class IBeaconIdentifier extends BeaconIdentifier {
  /// Creates an identifier.
  const IBeaconIdentifier({required this.uuid, required this.major, required this.minor});

  /// Proximity UUID, upper case.
  final String uuid;

  /// Major value.
  final int major;

  /// Minor value.
  final int minor;

  @override
  List<Object?> get props => [uuid, major, minor];

  @override
  String toString() => 'iBeacon($uuid/$major/$minor)';
}

/// An Eddystone beacon.
final class EddystoneIdentifier extends BeaconIdentifier {
  /// Creates an identifier.
  const EddystoneIdentifier({required this.namespace, required this.instance});

  /// Namespace, hex.
  final String namespace;

  /// Instance, hex.
  final String instance;

  @override
  List<Object?> get props => [namespace, instance];

  @override
  String toString() => 'Eddystone($namespace/$instance)';
}

/// A UWB accessory (anchor).
final class UwbAccessoryIdentifier extends BeaconIdentifier {
  /// Creates an identifier.
  const UwbAccessoryIdentifier({required this.name});

  /// Accessory name.
  final String name;

  @override
  List<Object?> get props => [name];

  @override
  String toString() => 'UWB($name)';
}

/// One sighting of a beacon.
class BeaconObservation with ValueEquality {
  /// Creates an observation.
  const BeaconObservation({
    required this.identifier,
    required this.rssi,
    required this.timestamp,
    this.txPower,
    this.calibratedDistance,
  });

  /// The beacon.
  final BeaconIdentifier identifier;

  /// Received signal strength, dBm.
  final int rssi;

  /// Advertised transmit power, dBm.
  final int? txPower;

  /// When the beacon was seen.
  final DateTime timestamp;

  /// Distance estimate in metres, when the beacon is calibrated.
  final double? calibratedDistance;

  @override
  List<Object?> get props => [identifier, rssi, txPower, timestamp, calibratedDistance];
}

/// Eddystone telemetry of a beacon.
class BeaconTelemetry with ValueEquality {
  /// Creates telemetry.
  const BeaconTelemetry({
    required this.batteryMillivolts,
    required this.temperatureCelsius,
    required this.advertisementCount,
    required this.uptime,
    required this.receivedAt,
  });

  /// Battery voltage in millivolts.
  final int batteryMillivolts;

  /// Temperature in °C.
  final double temperatureCelsius;

  /// Advertisements sent since power-on.
  final int advertisementCount;

  /// Time since power-on.
  final Duration uptime;

  /// When the telemetry was received.
  final DateTime receivedAt;

  @override
  List<Object?> get props => [batteryMillivolts, temperatureCelsius, advertisementCount, uptime, receivedAt];
}

/// A change in the beacons the device sees. Only beacons of the venue (and custom UUIDs) are reported.
sealed class BeaconEvent with ValueEquality {
  const BeaconEvent();
}

/// A beacon came into range.
final class BeaconFound extends BeaconEvent {
  /// Creates the event.
  const BeaconFound(this.observation);

  /// The sighting.
  final BeaconObservation observation;

  @override
  List<Object?> get props => [observation];
}

/// A beacon in range was seen again.
final class BeaconUpdated extends BeaconEvent {
  /// Creates the event.
  const BeaconUpdated(this.observation);

  /// The sighting.
  final BeaconObservation observation;

  @override
  List<Object?> get props => [observation];
}

/// A beacon went out of range.
final class BeaconLost extends BeaconEvent {
  /// Creates the event.
  const BeaconLost(this.identifier);

  /// The beacon.
  final BeaconIdentifier identifier;

  @override
  List<Object?> get props => [identifier];
}

/// A beacon sent telemetry.
final class BeaconTelemetryReceived extends BeaconEvent {
  /// Creates the event.
  const BeaconTelemetryReceived(this.identifier, this.telemetry);

  /// The beacon.
  final BeaconIdentifier identifier;

  /// The telemetry.
  final BeaconTelemetry telemetry;

  @override
  List<Object?> get props => [identifier, telemetry];
}
