package io.proximi.flutter_proximiio

import io.proximi.flutter_proximiio.Mappers.camelName
import io.proximi.sdk.core.model.ProximiioCoordinate
import io.proximi.sdk.wayfinding.ComputedRoute
import io.proximi.sdk.wayfinding.LevelChange
import io.proximi.sdk.wayfinding.NoRouteReason
import io.proximi.sdk.wayfinding.RouteInstruction
import io.proximi.sdk.wayfinding.RouteOptions
import io.proximi.sdk.wayfinding.RoutePoint
import io.proximi.sdk.wayfinding.RouteSegment

/** Wayfinding types ↔ transport types. */
internal object RouteMappers {

  fun sdkCoordinate(value: MsgCoordinate) = ProximiioCoordinate(latitude = value.latitude, longitude = value.longitude)

  fun options(value: MsgRouteOptions) = RouteOptions(
    profile = when (value.profile) {
      MsgRouteProfile.PEDESTRIAN -> RouteOptions.Profile.PEDESTRIAN
      MsgRouteProfile.WHEELCHAIR -> RouteOptions.Profile.WHEELCHAIR
      MsgRouteProfile.STROLLER -> RouteOptions.Profile.STROLLER
      MsgRouteProfile.STAFF -> RouteOptions.Profile.STAFF
    },
    avoid = value.avoid.map(::avoidance).toSet(),
  )

  private fun avoidance(value: MsgRouteAvoidance): RouteOptions.Avoidance = when (value) {
    MsgRouteAvoidance.ELEVATORS -> RouteOptions.Avoidance.ELEVATORS
    MsgRouteAvoidance.ESCALATORS -> RouteOptions.Avoidance.ESCALATORS
    MsgRouteAvoidance.STAIRCASES -> RouteOptions.Avoidance.STAIRCASES
    MsgRouteAvoidance.RAMPS -> RouteOptions.Avoidance.RAMPS
    MsgRouteAvoidance.NARROW_PATHS -> RouteOptions.Avoidance.NARROW_PATHS
    MsgRouteAvoidance.HILLS -> RouteOptions.Avoidance.HILLS
    MsgRouteAvoidance.REVOLVING_DOORS -> RouteOptions.Avoidance.REVOLVING_DOORS
    MsgRouteAvoidance.TICKET_GATES -> RouteOptions.Avoidance.TICKET_GATES
    MsgRouteAvoidance.BARRIERS -> RouteOptions.Avoidance.BARRIERS
  }

  fun point(value: MsgRoutePoint) = RoutePoint(coordinate = sdkCoordinate(value.coordinate), level = value.level)

  fun route(value: ComputedRoute) = MsgComputedRoute(
    coordinates = value.coordinates.map(Mappers::coordinate),
    distanceMeters = value.distanceMeters,
    segments = value.segments.map(::segment),
    level = value.level,
    levelChanges = value.levelChanges.map(::levelChange),
    instructions = value.instructions.map(::instruction),
    durationSeconds = value.durationSeconds,
  )

  private fun segment(value: RouteSegment) = MsgRouteSegment(
    start = Mappers.coordinate(value.start),
    end = Mappers.coordinate(value.end),
    distanceMeters = value.distanceMeters,
  )

  private fun levelChange(value: LevelChange) = MsgLevelChange(
    featureType = value.featureType,
    fromLevel = value.fromLevel,
    toLevel = value.toLevel,
    coordinate = Mappers.coordinate(value.coordinate),
  )

  private fun instruction(value: RouteInstruction): MsgRouteInstruction {
    val kind = when (val kind = value.kind) {
      RouteInstruction.Kind.Start -> MsgInstructionKind.START
      RouteInstruction.Kind.ContinueStraight -> MsgInstructionKind.CONTINUE_STRAIGHT
      RouteInstruction.Kind.TurnSlightLeft -> MsgInstructionKind.TURN_SLIGHT_LEFT
      RouteInstruction.Kind.TurnLeft -> MsgInstructionKind.TURN_LEFT
      RouteInstruction.Kind.TurnSharpLeft -> MsgInstructionKind.TURN_SHARP_LEFT
      RouteInstruction.Kind.TurnSlightRight -> MsgInstructionKind.TURN_SLIGHT_RIGHT
      RouteInstruction.Kind.TurnRight -> MsgInstructionKind.TURN_RIGHT
      RouteInstruction.Kind.TurnSharpRight -> MsgInstructionKind.TURN_SHARP_RIGHT
      is RouteInstruction.Kind.LevelChange -> MsgInstructionKind.LEVEL_CHANGE
      RouteInstruction.Kind.Arrive -> MsgInstructionKind.ARRIVE
    }
    return MsgRouteInstruction(
      kind = kind,
      coordinate = Mappers.coordinate(value.coordinate),
      distanceMeters = value.distanceMeters,
      level = value.level,
      durationSeconds = value.durationSeconds,
      levelChange = (value.kind as? RouteInstruction.Kind.LevelChange)?.let { levelChange(it.change) },
    )
  }

  /** Fills the `noRoute` error details: `reason`, and `nearestDistanceMeters` or `blockedBy`. */
  fun noRouteDetails(reason: NoRouteReason, details: MutableMap<String, String>) {
    details["reason"] = when (reason) {
      NoRouteReason.EmptyNetwork -> "emptyNetwork"
      is NoRouteReason.StartOffNetwork -> {
        details["nearestDistanceMeters"] = reason.nearestDistanceMeters.toString()
        "startOffNetwork"
      }
      is NoRouteReason.GoalOffNetwork -> {
        details["nearestDistanceMeters"] = reason.nearestDistanceMeters.toString()
        "goalOffNetwork"
      }
      NoRouteReason.Disconnected -> "disconnected"
      NoRouteReason.NoLevelTransition -> "noLevelTransition"
      is NoRouteReason.NoAccessibleRoute -> {
        details["blockedBy"] = reason.blockedBy.joinToString(",") { it.camelName() }
        "noAccessibleRoute"
      }
    }
  }
}
