class_name ShadowMovementSystem
extends RefCounted

## Shadow-only fixed-step movement integration.
##
## Turns the engine's existing phase-scale projection into a sampled trail, so
## a player's motion becomes a function of time rather than a pair of endpoints
## the view layer has to guess between. Nothing here decides anything: it
## produces evidence, never mutates the source state, and is not wired into the
## resolver or playback.
##
## It reuses `RallyMovementSystem.project_toward()` as the per-step kinematic
## core rather than reimplementing it, so maximum speed, acceleration, mass,
## fatigue, and direction-change cost keep coming from player ratings through
## one code path.
##
## Two adaptations were needed to make that function composable at small steps.
## Both are physical, not cosmetic, and both are measured by
## `MovementIntegrationCalibration`:
##
## 1. **The turn cost is a per-call constant.** `project_toward()` subtracts
##    `direction_change_delay` from every call's duration, which is right when
##    the call covers a whole phase and wrong when it covers 33 ms -- looping it
##    naively would charge a player up to 0.20 s of turning thirty times a
##    second and they would never move at all. The delay is therefore paid once,
##    from the actor's true starting facing, and each subsequent step aligns
##    facing with travel so the per-call charge collapses to its floor, which is
##    then added back to the requested step so the effective moved time is
##    exactly the step.
##
## 2. **Arrival zeroes velocity.** That is correct for arriving at a contact and
##    wrong for a waypoint, which is passed through rather than stopped at. On
##    reaching a waypoint the travel velocity is preserved, and the next step's
##    `velocity.dot(direction)` sheds whatever is not aligned with the new
##    heading. The corner curve and its speed dip are emergent from that, not
##    authored.

const MovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const KinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")

## 30 Hz. Linear interpolation between samples this close costs at most about
## half a centimetre at human accelerations, which is far below one screen pixel
## at any sane court scale.
const DEFAULT_STEP_SECONDS: float = 1.0 / 30.0
## `direction_change_delay` is `lerpf(0.20, 0.02, facing_fit)`, so a perfectly
## aligned actor is charged exactly this. Steps are requested with this added so
## the moved time is the step itself.
const ALIGNED_TURN_DELAY: float = 0.02
const MAXIMUM_STEPS: int = 512


## Integrates one player's traversal and returns the sampled trail. `waypoint`
## may be null; when present the switch to the final target happens on arrival,
## not at any fixed fraction of the duration.
static func integrate(
	actor: RallyPlayerState,
	target: Vector2,
	duration: float,
	mode: RallyPlayerState.MovementMode,
	step_seconds: float = DEFAULT_STEP_SECONDS,
	waypoint: Variant = null,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {"available": false, "reason": "missing actor"}
	if duration <= 0.0:
		return {"available": false, "reason": "non-positive duration"}
	var step := clampf(step_seconds, 0.004, duration)

	var source_position := actor.position
	var source_velocity := actor.velocity
	var stepper := actor.snapshot()

	var first_target: Vector2 = Vector2(waypoint) if waypoint != null else target
	var opening_direction := _direction(stepper.position, first_target)
	## Paid once, from the facing the player actually started with.
	var turn_delay := float(MovementModel.movement_profile(
		stepper, opening_direction, mode
	).get("direction_change_delay", 0.0))
	var moving_time := maxf(duration - turn_delay, 0.0)

	var trail: Array[Vector2] = [stepper.position]
	var sample_times: Array[float] = [0.0]
	var speeds: Array[float] = [stepper.velocity.length()]
	var waypoint_reached := waypoint == null
	var elapsed := 0.0
	var steps := 0
	while elapsed < moving_time - 0.0001 and steps < MAXIMUM_STEPS:
		var leg_target: Vector2 = target if waypoint_reached else Vector2(waypoint)
		var direction := _direction(stepper.position, leg_target)
		if direction == Vector2.ZERO:
			break
		## Aligning facing collapses the per-call turn charge to its floor; the
		## floor is then handed back so the step moves for exactly `slice`.
		stepper.facing = direction
		var slice := minf(step, moving_time - elapsed)
		var carried_speed := stepper.velocity.length()
		var projection: Dictionary = MovementModel.project_toward(
			stepper, leg_target, slice + ALIGNED_TURN_DELAY, mode
		)
		var advanced := projection.get("actor") as RallyPlayerState
		if advanced == null:
			break
		var arrived := bool(projection.get("reached_target", false))
		if arrived and not waypoint_reached:
			## Passed through, not stopped at: keep the travel velocity so the
			## next heading sheds only the component that does not carry over.
			advanced.velocity = direction * carried_speed
			waypoint_reached = true
		stepper = advanced
		elapsed += slice
		steps += 1
		trail.append(stepper.position)
		sample_times.append(turn_delay + elapsed)
		speeds.append(stepper.velocity.length())
		if arrived and waypoint_reached and stepper.position.distance_to(target) <= 0.001:
			break

	return {
		"available": true,
		"reason": "",
		"trail": trail,
		"sample_times": sample_times,
		"speeds_mps": speeds,
		"landing_position": stepper.position,
		"final_speed_mps": stepper.velocity.length(),
		"reached_target": stepper.position.distance_to(target) <= 0.002,
		"waypoint_reached": waypoint_reached,
		"turn_delay_seconds": turn_delay,
		"moving_time_seconds": moving_time,
		"step_seconds": step,
		"step_count": steps,
		"path_length_meters": _trail_length_meters(trail),
		## The source actor must be exactly as it was handed in.
		"source_state_unchanged": actor.position == source_position \
			and actor.velocity == source_velocity,
	}


## How long this traversal actually takes the movement model, as opposed to
## however long a caller allotted for it. Returns -1.0 when the player cannot
## finish inside `window_seconds`.
static func natural_traversal_time(
	actor: RallyPlayerState,
	target: Vector2,
	mode: RallyPlayerState.MovementMode,
	waypoint: Variant = null,
	window_seconds: float = 6.0,
) -> float:
	var integration := integrate(
		actor, target, window_seconds, mode, DEFAULT_STEP_SECONDS, waypoint
	)
	if not bool(integration.get("available", false)):
		return -1.0
	var points: Array = integration.get("trail", [])
	var times: Array = integration.get("sample_times", [])
	for index in range(points.size()):
		if Vector2(points[index]).distance_to(target) <= 0.002:
			return float(times[index])
	return -1.0


## The single-call projection this stepper refines, for direct comparison.
static func reference_projection(
	actor: RallyPlayerState,
	target: Vector2,
	duration: float,
	mode: RallyPlayerState.MovementMode,
) -> Dictionary:
	var projection: Dictionary = MovementModel.project_toward(
		actor, target, duration, mode
	)
	var advanced := projection.get("actor") as RallyPlayerState
	return {
		"landing_position": advanced.position if advanced != null else actor.position,
		"final_speed_mps": float(projection.get("ending_speed_mps", 0.0)),
		"reached_target": bool(projection.get("reached_target", false)),
		"distance_meters": float(projection.get("distance_meters", 0.0)),
	}


static func _direction(from: Vector2, to: Vector2) -> Vector2:
	var delta := KinematicsModel.court_delta_meters(from, to)
	return delta.normalized() if delta.length() > 0.0001 else Vector2.ZERO


static func _trail_length_meters(trail: Array[Vector2]) -> float:
	var total := 0.0
	for index in range(1, trail.size()):
		total += KinematicsModel.court_delta_meters(
			trail[index - 1], trail[index]
		).length()
	return total
