import Foundation
import Proximiio

/// Wayfinding types ↔ transport types.
enum RouteMappers {

  static func sdkCoordinate(_ value: MsgCoordinate) -> ProximiioCoordinate {
    ProximiioCoordinate(latitude: value.latitude, longitude: value.longitude)
  }

  static func options(_ value: MsgRouteOptions) -> RouteOptions {
    let profile: RouteOptions.Profile
    switch value.profile {
    case .pedestrian: profile = .pedestrian
    case .wheelchair: profile = .wheelchair
    case .stroller: profile = .stroller
    case .staff: profile = .staff
    }
    return RouteOptions(profile: profile, avoid: Set(value.avoid.map(avoidance)))
  }

  private static func avoidance(_ value: MsgRouteAvoidance) -> RouteOptions.Avoidance {
    switch value {
    case .elevators: return .elevators
    case .escalators: return .escalators
    case .staircases: return .staircases
    case .ramps: return .ramps
    case .narrowPaths: return .narrowPaths
    case .hills: return .hills
    case .revolvingDoors: return .revolvingDoors
    case .ticketGates: return .ticketGates
    case .barriers: return .barriers
    }
  }

  /// Same names as the Dart enum (and the Android `camelName`).
  private static func avoidanceName(_ value: RouteOptions.Avoidance) -> String {
    switch value {
    case .elevators: return "elevators"
    case .escalators: return "escalators"
    case .staircases: return "staircases"
    case .ramps: return "ramps"
    case .narrowPaths: return "narrowPaths"
    case .hills: return "hills"
    case .revolvingDoors: return "revolvingDoors"
    case .ticketGates: return "ticketGates"
    case .barriers: return "barriers"
    @unknown default: return value.rawValue
    }
  }

  static func point(_ value: MsgRoutePoint) -> RoutePoint {
    RoutePoint(coordinate: sdkCoordinate(value.coordinate), level: value.level)
  }

  static func route(_ value: ComputedRoute) -> MsgComputedRoute {
    MsgComputedRoute(
      coordinates: value.coordinates.map(Mappers.coordinate),
      distanceMeters: value.distanceMeters,
      segments: value.segments.map(segment),
      level: value.level,
      levelChanges: value.levelChanges.map(levelChange),
      instructions: value.instructions.map(instruction),
      durationSeconds: value.durationSeconds
    )
  }

  private static func segment(_ value: RouteSegment) -> MsgRouteSegment {
    MsgRouteSegment(
      start: Mappers.coordinate(value.start),
      end: Mappers.coordinate(value.end),
      distanceMeters: value.distanceMeters
    )
  }

  private static func levelChange(_ value: LevelChange) -> MsgLevelChange {
    MsgLevelChange(
      featureType: value.featureType,
      fromLevel: value.fromLevel,
      toLevel: value.toLevel,
      coordinate: Mappers.coordinate(value.coordinate)
    )
  }

  private static func instruction(_ value: RouteInstruction) -> MsgRouteInstruction {
    var change: MsgLevelChange?
    let kind: MsgInstructionKind
    switch value.kind {
    case .start: kind = .start
    case .continueStraight: kind = .continueStraight
    case .turnSlightLeft: kind = .turnSlightLeft
    case .turnLeft: kind = .turnLeft
    case .turnSharpLeft: kind = .turnSharpLeft
    case .turnSlightRight: kind = .turnSlightRight
    case .turnRight: kind = .turnRight
    case .turnSharpRight: kind = .turnSharpRight
    case .levelChange(let value):
      kind = .levelChange
      change = levelChange(value)
    case .arrive: kind = .arrive
    @unknown default: kind = .continueStraight
    }
    return MsgRouteInstruction(
      kind: kind,
      coordinate: Mappers.coordinate(value.coordinate),
      distanceMeters: value.distanceMeters,
      level: value.level,
      durationSeconds: value.durationSeconds,
      levelChange: change
    )
  }

  /// Fills the `noRoute` error details: `reason`, and `nearestDistanceMeters` or `blockedBy`.
  static func noRouteDetails(_ reason: NoRouteReason, into details: inout [String: String]) {
    switch reason {
    case .emptyNetwork:
      details["reason"] = "emptyNetwork"
    case .startOffNetwork(let distance):
      details["reason"] = "startOffNetwork"
      details["nearestDistanceMeters"] = String(distance)
    case .goalOffNetwork(let distance):
      details["reason"] = "goalOffNetwork"
      details["nearestDistanceMeters"] = String(distance)
    case .disconnected:
      details["reason"] = "disconnected"
    case .noLevelTransition:
      details["reason"] = "noLevelTransition"
    case .noAccessibleRoute(let blockedBy):
      details["reason"] = "noAccessibleRoute"
      details["blockedBy"] = blockedBy.map(avoidanceName).joined(separator: ",")
    @unknown default:
      details["reason"] = Mappers.caseName(reason)
    }
  }
}
