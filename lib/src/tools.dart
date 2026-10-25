import 'events.dart';
import 'models.dart';
import 'value.dart';

/// State of an offline venue package on the device.
sealed class PackageState with ValueEquality {
  const PackageState();
}

/// Not installed.
final class PackageMissing extends PackageState {
  /// The state.
  const PackageMissing();

  @override
  List<Object?> get props => const [];
}

/// Downloading.
final class PackageDownloading extends PackageState {
  /// The state.
  const PackageDownloading(this.progress);

  /// 0 to 1.
  final double progress;

  @override
  List<Object?> get props => [progress];
}

/// Installed and verified.
final class PackageReady extends PackageState {
  /// The state.
  const PackageReady(this.version);

  /// Installed package version.
  final int version;

  @override
  List<Object?> get props => [version];
}

/// Installed, but a newer version exists.
final class PackageStale extends PackageState {
  /// The state.
  const PackageStale();

  @override
  List<Object?> get props => const [];
}

/// Checking the downloaded files.
final class PackageVerifying extends PackageState {
  /// The state.
  const PackageVerifying();

  @override
  List<Object?> get props => const [];
}

/// The last sync failed; the previous version, if any, stays in use.
final class PackageFailed extends PackageState {
  /// The state.
  const PackageFailed();

  @override
  List<Object?> get props => const [];
}

/// A stop of a [SimulatedRoute].
class SimulatedWaypoint with ValueEquality {
  /// Creates a waypoint.
  const SimulatedWaypoint(this.coordinate, {this.level = 0});

  /// Position.
  final Coordinate coordinate;

  /// Floor level (whole levels only in simulation).
  final int level;

  @override
  List<Object?> get props => [coordinate, level];
}

/// A route the SDK walks along, emitting positions as if the device moved.
class SimulatedRoute with ValueEquality {
  /// Creates a route.
  const SimulatedRoute({
    required this.waypoints,
    this.speed = 1.3,
    this.updateInterval = const Duration(seconds: 1),
    this.loops = false,
    this.accuracy = 5,
  });

  /// Stops, in order; at least two.
  final List<SimulatedWaypoint> waypoints;

  /// Walking speed in m/s.
  final double speed;

  /// Time between positions.
  final Duration updateInterval;

  /// Start over after the last stop.
  final bool loops;

  /// Reported accuracy in metres.
  final double accuracy;

  @override
  List<Object?> get props => [waypoints, speed, updateInterval, loops, accuracy];
}

/// State of the simulation.
enum SimulationState {
  /// No simulation.
  idle,

  /// Walking the route.
  running,

  /// Paused.
  paused,
}

/// A snapshot of what the SDK is doing, for support and debugging screens.
class ProximiioDiagnostics with ValueEquality {
  /// Creates diagnostics.
  const ProximiioDiagnostics({
    required this.state,
    required this.isStarted,
    required this.isAuthenticated,
    required this.visibleBeaconCount,
    required this.registeredBeaconCount,
    required this.pdrEnabled,
    required this.pdrRunning,
    required this.visitorReportingEnabled,
    required this.summary,
    required this.generatedAt,
    this.permissions,
    this.lastPositionAge,
    this.lastPositionSource,
    this.noPositionReason,
  });

  /// Lifecycle state.
  final ProximiioState state;

  /// Whether positioning runs.
  final bool isStarted;

  /// Whether the token was accepted.
  final bool isAuthenticated;

  /// Permissions.
  final PermissionStatus? permissions;

  /// Beacons in range.
  final int visibleBeaconCount;

  /// Beacons in the venue data.
  final int registeredBeaconCount;

  /// Age of the last position.
  final Duration? lastPositionAge;

  /// Source of the last position.
  final PositionSource? lastPositionSource;

  /// Whether PDR is enabled.
  final bool pdrEnabled;

  /// Whether PDR is running.
  final bool pdrRunning;

  /// Whether visitor analytics are reported.
  final bool visitorReportingEnabled;

  /// Why there is no position (`notStarted`, `noViablePositioningInputs`, `awaitingFirstFix`, …).
  final String? noPositionReason;

  /// One-paragraph summary for logs and support tickets.
  final String summary;

  /// When the snapshot was taken.
  final DateTime generatedAt;

  @override
  List<Object?> get props => [
    state,
    isStarted,
    isAuthenticated,
    permissions,
    visibleBeaconCount,
    registeredBeaconCount,
    lastPositionAge,
    lastPositionSource,
    pdrEnabled,
    pdrRunning,
    visitorReportingEnabled,
    noPositionReason,
    summary,
    generatedAt,
  ];

  @override
  String toString() => summary;
}
