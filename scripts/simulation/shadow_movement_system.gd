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
## 2. **Arrival keeps its speed.** `project_toward` zeroed velocity on arrival
##    and no caller had ever asked it not to, so every leg in the engine ended at
##    a dead stop. It now carries through, and a body that arrives with time still
##    on the leg is brought to rest explicitly instead.
##
## 3. **A redirection is charged before the leg starts.** Momentum that does not
##    point at the target has to be arrested, and a retreating body gives up
##    ground while it sheds it. Both terms come from `RallyMovementSystem`'s own
##    `arrest_terms`, so the stepped and closed forms cannot disagree about the
##    price of a turn. EMBODIED_MOVEMENT_CONTINUITY.md C2.

const MovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const KinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")

## 30 Hz. Linear interpolation between samples this close costs at most about
## half a centimetre at human accelerations, which is far below one screen pixel
## at any sane court scale.
const DEFAULT_STEP_SECONDS: float = 1.0 / 30.0
## Fallback aligned turn charge, used only when no profile can be read. The real
## value is measured per player: turn cost scales with the athlete's turnover, so
## an aligned stride no longer costs everyone the same fixed floor.
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
	## Paid once, from the facing the player actually started with -- and only
	## when the traversal genuinely starts from rest.
	##
	## `RallyMovementSystem._leg_seconds` charges it under exactly that
	## condition ("a player already carrying speed into this leg has already
	## turned"), and this integrator charged it unconditionally. While every
	## player in the engine started every leg at a dead stop the two rules were
	## indistinguishable. Once hitters began carrying speed into their approach,
	## ATTACK became the one phase where the stepper billed a turn the closed
	## form skipped, and the two models parted by 13% on that phase alone while
	## agreeing to better than 0.6% on the three that still start from rest.
	var opening_profile: Dictionary = MovementModel.movement_profile(
		stepper, opening_direction, mode
	)
	## The same three terms the closed form charges, from the same helper, so the
	## two models cannot drift apart about what a redirection costs.
	## NOTE one arrest model, two consumers -- EMBODIED_MOVEMENT_CONTINUITY.md C2.2
	var arrest: Dictionary = MovementModel.arrest_terms(
		stepper.velocity, opening_direction,
		float(opening_profile.get("acceleration", 0.1)),
	)
	var opening_speed := float(arrest.opening_speed)
	var arrest_seconds := float(arrest.seconds)
	var turn_delay := 0.0 if (arrest_seconds > 0.0 or opening_speed > 0.0) \
		else float(opening_profile.get("direction_change_delay", 0.0))
	var moving_time := maxf(duration - turn_delay - arrest_seconds, 0.0)
	## Everything the loop stamps is offset past the turn *and* the arrest, or the
	## arrest sample would land after the first step and the path's times would
	## run backwards.
	var time_base := turn_delay + arrest_seconds
	## What an aligned step costs *this* player. Every step below sets facing to
	## the direction of travel, so this is the charge `project_toward()` will
	## apply, and handing exactly it back keeps each step moving for its full
	## slice. Assuming a fixed floor here would silently shorten every traversal
	## for a quick-turnover player and lengthen it for a slow one.
	var aligned_probe := stepper.snapshot()
	aligned_probe.facing = opening_direction
	var aligned_turn_delay := float(MovementModel.movement_profile(
		aligned_probe, opening_direction, mode
	).get("direction_change_delay", ALIGNED_TURN_DELAY))

	var trail: Array[Vector2] = [stepper.position]
	var sample_times: Array[float] = [0.0]
	var speeds: Array[float] = [stepper.velocity.length()]
	## Recorded per sample so a consumer can draw the body without re-deriving
	## the heading from successive positions -- which is the reconstruction the
	## authoritative path exists to remove.
	var facings: Array[Vector2] = [stepper.facing]
	var velocities: Array[Vector2] = [stepper.velocity]
	## **The arrest, drawn rather than assumed.** A body shedding momentum it
	## cannot use is still moving while it does so, and if it was retreating it
	## gives up ground it then has to cover again. Only the component along the
	## heading is applied, which is exactly the closed form's `ground_lost`; the
	## lateral drift is ignored by both, so neither can disagree about it.
	if arrest_seconds > 0.0001:
		var retreat := minf(stepper.velocity.dot(opening_direction), 0.0)
		var drift_meters := opening_direction * (retreat * arrest_seconds * 0.5)
		stepper.apply_position(
			stepper.position + Vector2(
				drift_meters.x / KinematicsModel.COURT_WIDTH_METERS,
				drift_meters.y / KinematicsModel.COURT_LENGTH_METERS,
			),
			opening_direction * opening_speed,
		)
		trail.append(stepper.position)
		sample_times.append(time_base)
		speeds.append(opening_speed)
		facings.append(stepper.facing)
		velocities.append(stepper.velocity)
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
		## NOTE arrival keeps its speed; standing is charged below -- EMBODIED_MOVEMENT_CONTINUITY.md C0.4
		var projection: Dictionary = MovementModel.project_toward(
			stepper, leg_target, slice + aligned_turn_delay, mode, true
		)
		var advanced := projection.get("actor") as RallyPlayerState
		if advanced == null:
			break
		var arrived := bool(projection.get("reached_target", false))
		if arrived and not waypoint_reached:
			waypoint_reached = true
		stepper = advanced
		elapsed += slice
		steps += 1
		trail.append(stepper.position)
		sample_times.append(time_base + elapsed)
		speeds.append(stepper.velocity.length())
		facings.append(stepper.facing)
		velocities.append(stepper.velocity)
		if arrived and waypoint_reached and stepper.position.distance_to(target) <= 0.001:
			break

	## The body arrived with time still on the leg, so it stands there for the
	## remainder. A leg that ends the instant the body arrives never comes through
	## here and keeps its arrival speed, which is the whole of the C0 contract:
	## the final sample tells the truth about the final instant, and nothing else
	## does. `_committed_path` caps duration at the traversal time so it cannot
	## produce an idle tail; `rally_opportunity_system.gd` samples arbitrary
	## perception gaps and can.
	##
	## The leftover must exceed one integration step, not an epsilon. A leg that
	## arrives on its final slice leaves a rounding residue -- 0.16 ms on a
	## measured 0.267 s leg -- and an epsilon threshold reads that as a body
	## standing still, which zeroed the arrival speed on exactly the legs the
	## contract is about. Below one step the integrator could not represent the
	## standing anyway, so the step is the honest floor.
	if moving_time - elapsed > step and trail.size() >= 2 \
			and stepper.position.distance_to(target) <= 0.002:
		stepper.apply_position(stepper.position, Vector2.ZERO)
		trail.append(stepper.position)
		sample_times.append(time_base + moving_time)
		speeds.append(0.0)
		facings.append(stepper.facing)
		velocities.append(Vector2.ZERO)

	return {
		"available": true,
		"reason": "",
		"trail": trail,
		"sample_times": sample_times,
		"speeds_mps": speeds,
		"facings": facings,
		"velocities": velocities,
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
	var speeds: Array = integration.get("speeds_mps", [])
	for index in range(points.size()):
		if Vector2(points[index]).distance_to(target) > 0.002:
			continue
		if index == 0:
			return float(times[index])
		## Arrival happens *inside* the step that reaches it, and the stepper
		## clamps the player onto the target, so taking the sample time whole
		## rounds every traversal up to the next 1/30 s boundary. That bias is
		## invisible on a one-second leg and systematic on a half-second one --
		## which is what an ATTACK became once hitters carried speed into it, and
		## most of why this integrator and the closed form parted company on that
		## phase alone.
		##
		## Estimated from the step's own entry speed and the metres left to run,
		## using nothing but the integration's own outputs, and never longer than
		## the step it happened in.
		var previous: Vector2 = Vector2(points[index - 1])
		var remaining := KinematicsModel.court_delta_meters(
			previous, target
		).length()
		var entry_speed := float(speeds[index - 1]) if index - 1 < speeds.size() \
			else 0.0
		var span := float(times[index]) - float(times[index - 1])
		if entry_speed <= 0.05 or span <= 0.0:
			return float(times[index])
		return float(times[index - 1]) + minf(remaining / entry_speed, span)
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
