import 'models.dart';
import 'value.dart';

/// Who the route is for. Each profile avoids the level changers and paths it cannot use.
enum RouteProfile {
  /// Walking; every path (the default).
  pedestrian,

  /// Avoids staircases, escalators and narrow paths.
  wheelchair,

  /// Avoids staircases and escalators.
  stroller,

  /// Reserved for staff-only paths; this SDK version routes it like [pedestrian].
  staff,
}

/// Something a route can avoid.
enum RouteAvoidance {
  /// Elevators.
  elevators,

  /// Escalators.
  escalators,

  /// Staircases.
  staircases,

  /// Ramps.
  ramps,

  /// Narrow paths.
  narrowPaths,

  /// Hills.
  hills,

  /// Revolving doors.
  revolvingDoors,

  /// Ticket gates.
  ticketGates,

  /// Barriers.
  barriers,
}

/// Route profile and avoidances. The profile's own avoidances always apply in addition to [avoid].
class RouteOptions with ValueEquality {
  /// Creates route options.
  const RouteOptions({this.profile = RouteProfile.pedestrian, this.avoid = const {}});

  /// Who the route is for.
  final RouteProfile profile;

  /// Extra things to avoid.
  final Set<RouteAvoidance> avoid;

  @override
  List<Object?> get props => [profile, avoid];
}

/// A point with a level, for [Proximiio.routeDurations].
class RoutePoint with ValueEquality {
  /// Creates a route point.
  const RoutePoint(this.coordinate, {required this.level});

  /// Position.
  final Coordinate coordinate;

  /// Level of the floor.
  final double level;

  @override
  List<Object?> get props => [coordinate, level];
}

/// One ride between floors: an elevator, a staircase, an escalator or a ramp.
class LevelChange with ValueEquality {
  /// Creates a level change.
  const LevelChange({
    required this.featureType,
    required this.fromLevel,
    required this.toLevel,
    required this.coordinate,
  });

  /// Type of the level changer: `elevator`, `staircase`, `escalator`, `ramp`, `hill`.
  final String featureType;

  /// Level the ride starts on.
  final double fromLevel;

  /// Level the ride ends on.
  final double toLevel;

  /// Position of the level changer.
  final Coordinate coordinate;

  @override
  List<Object?> get props => [featureType, fromLevel, toLevel, coordinate];
}

/// A straight piece of a route.
class RouteSegment with ValueEquality {
  /// Creates a segment.
  const RouteSegment({required this.start, required this.end, required this.distanceMeters});

  /// Start of the segment.
  final Coordinate start;

  /// End of the segment.
  final Coordinate end;

  /// Length in metres.
  final double distanceMeters;

  @override
  List<Object?> get props => [start, end, distanceMeters];
}

/// What a turn-by-turn instruction tells the visitor to do.
enum RouteInstructionKind {
  /// Start walking.
  start,

  /// Go straight on.
  continueStraight,

  /// Turn slightly left.
  turnSlightLeft,

  /// Turn left.
  turnLeft,

  /// Turn sharply left.
  turnSharpLeft,

  /// Turn slightly right.
  turnSlightRight,

  /// Turn right.
  turnRight,

  /// Turn sharply right.
  turnSharpRight,

  /// Change floor; see [RouteInstruction.levelChange].
  levelChange,

  /// Arrive at the destination.
  arrive,
}

/// One turn-by-turn instruction.
class RouteInstruction with ValueEquality {
  /// Creates an instruction.
  const RouteInstruction({
    required this.kind,
    required this.coordinate,
    required this.distanceMeters,
    required this.level,
    required this.duration,
    this.levelChange,
  });

  /// What to do.
  final RouteInstructionKind kind;

  /// Where to do it.
  final Coordinate coordinate;

  /// Walking distance since the previous instruction, in metres.
  final double distanceMeters;

  /// Level the instruction is on.
  final double level;

  /// Time since the previous instruction.
  final Duration duration;

  /// The ride, when [kind] is [RouteInstructionKind.levelChange].
  final LevelChange? levelChange;

  @override
  List<Object?> get props => [kind, coordinate, distanceMeters, level, duration, levelChange];
}

/// A route computed on the device from the venue's route network.
class ComputedRoute with ValueEquality {
  /// Creates a route.
  const ComputedRoute({
    required this.coordinates,
    required this.distanceMeters,
    required this.segments,
    required this.level,
    required this.levelChanges,
    required this.instructions,
    required this.duration,
  });

  /// The route line.
  final List<Coordinate> coordinates;

  /// Total length in metres.
  final double distanceMeters;

  /// Straight pieces of the route.
  final List<RouteSegment> segments;

  /// Level the route starts on.
  final double level;

  /// Rides between floors, in order.
  final List<LevelChange> levelChanges;

  /// Turn-by-turn instructions.
  final List<RouteInstruction> instructions;

  /// Estimated time: walking plus level changes.
  final Duration duration;

  /// Estimated arrival when leaving at [departure] (now by default).
  DateTime estimatedArrival([DateTime? departure]) => (departure ?? DateTime.now()).add(duration);

  @override
  List<Object?> get props => [coordinates, distanceMeters, segments, level, levelChanges, instructions, duration];

  @override
  String toString() =>
      'ComputedRoute(${distanceMeters.toStringAsFixed(1)} m, $duration, ${levelChanges.length} level changes)';
}

/// Why no route was found. Read from [ProximiioException.noRouteReason].
enum NoRouteReason {
  /// The venue has no route network (no paths drawn, or not loaded yet).
  emptyNetwork,

  /// The start is too far from any path; see [ProximiioException.nearestDistanceMeters].
  startOffNetwork,

  /// The destination is too far from any path; see [ProximiioException.nearestDistanceMeters].
  goalOffNetwork,

  /// Start and destination are on parts of the network that do not connect.
  disconnected,

  /// The levels do not connect through any level changer.
  noLevelTransition,

  /// Only routes through avoided features exist; see [ProximiioException.blockedBy].
  noAccessibleRoute,
}
