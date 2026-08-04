class_name RallyMovementSystem
extends RefCounted

const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")
const ContactEnvelopeModel := preload("res://scripts/simulation/contact_envelope_system.gd")

## Seconds spent changing direction, before the player's own turnover scales it.
## The worst case is a full reversal, the best an already-aligned stride.
const TURN_DELAY_WORST_SECONDS: float = 0.20
const TURN_DELAY_BEST_SECONDS: float = 0.02


static func evaluate_opportunity(
	actor: RallyPlayerState,
	action_type: StringName,
	target: Vector2,
	contact_time: float,
	current_time: float,
	tactical_priority: float = 0.0,
	contact_height_meters: float = 1.0,
	allow_jump: bool = false,
	approach_profile: Dictionary = {},
) -> ActionOpportunity:
	var opportunity := ActionOpportunity.new()
	if actor == null or actor.player == null:
		return opportunity
	opportunity.action_type = action_type
	opportunity.side = actor.team_side
	opportunity.player_id = actor.player_id
	opportunity.contact_position = target
	opportunity.contact_time = contact_time
	opportunity.tactical_priority = tactical_priority

	var available_time := maxf(
		contact_time - maxf(current_time, actor.committed_until), 0.0
	)
	var envelope := ContactEnvelopeModel.evaluate(
		actor, action_type, contact_height_meters, available_time, allow_jump,
		approach_profile
	)
	var contact_reach := float(envelope.get("horizontal_reach_meters", 0.0))
	var standing_movement := estimate_movement(
		actor, target, available_time, _movement_mode_for(action_type), contact_reach
	)
	var used_reaching_extension := false
	var baseline_deficit := float(standing_movement.get(
		"center_distance_deficit_meters", 99.0
	))
	## Gate 27: a setter who has already moved within a narrow hand-access gap
	## may finish in a reaching posture. This is action-specific and does not
	## add movement time, speed, or a universal distance allowance.
	if action_type == &"set" and baseline_deficit > 0.001 \
			and baseline_deficit <= 0.18:
		var reaching_actor := actor.snapshot()
		reaching_actor.body_state = RallyPlayerState.BodyState.REACHING
		var reaching_envelope := ContactEnvelopeModel.evaluate(
			reaching_actor, action_type, contact_height_meters,
			available_time, allow_jump
		)
		var reaching_contact_reach := float(reaching_envelope.get(
			"horizontal_reach_meters", contact_reach
		))
		var reaching_movement := estimate_movement(
			reaching_actor, target, available_time,
			_movement_mode_for(action_type), reaching_contact_reach
		)
		if float(reaching_movement.get(
			"center_distance_deficit_meters", 99.0
		)) < baseline_deficit:
			envelope = reaching_envelope
			contact_reach = reaching_contact_reach
			standing_movement = reaching_movement
			used_reaching_extension = true
	var standing_horizontal_reachable := float(standing_movement.get(
		"center_distance_deficit_meters", 99.0
	)) <= 0.001
	var standing_reachable := bool(envelope.get("standing_reachable", false)) \
		and standing_horizontal_reachable
	var takeoff_time := float(envelope.get("takeoff_time_seconds", 0.0))
	var jump_movement := estimate_movement(
		actor, target, maxf(available_time - takeoff_time, 0.0),
		_movement_mode_for(action_type), contact_reach
	)
	var jump_reachable := bool(envelope.get("jump_reachable", false)) \
		and float(jump_movement.get("center_distance_deficit_meters", 99.0)) <= 0.001
	var use_jump := not standing_reachable and jump_reachable
	var movement: Dictionary = jump_movement if use_jump else standing_movement
	var movement_available_time := maxf(available_time - takeoff_time, 0.0) \
		if use_jump else available_time
	opportunity.travel_time = float(movement.get("travel_time", 99.0))
	opportunity.arrival_margin = movement_available_time - opportunity.travel_time
	opportunity.available_time = available_time
	opportunity.target_distance_meters = float(movement.get(
		"distance_meters", 99.0
	))
	opportunity.movement_capacity_meters = float(movement.get(
		"movement_capacity_meters", 0.0
	))
	opportunity.center_distance_deficit_meters = float(movement.get(
		"center_distance_deficit_meters", 99.0
	))
	opportunity.contact_reach_meters = contact_reach
	opportunity.contact_height_meters = contact_height_meters
	opportunity.standing_reach_meters = float(envelope.get(
		"standing_reach_meters", 0.0
	))
	opportunity.maximum_contact_height_meters = float(envelope.get(
		"maximum_contact_height_meters", 0.0
	))
	opportunity.vertical_margin_meters = float(envelope.get(
		"vertical_margin_meters", -99.0
	))
	opportunity.standing_reachable = standing_reachable
	opportunity.jump_reachable = jump_reachable
	opportunity.requires_jump = use_jump
	opportunity.required_takeoff_time_seconds = float(envelope.get(
		"required_takeoff_time_seconds", 0.0
	))
	opportunity.takeoff_time_seconds = takeoff_time if jump_reachable else 0.0
	opportunity.recovery_time_seconds = float(envelope.get(
		"recovery_time_seconds", 0.0
	)) if jump_reachable else 0.0
	opportunity.used_reaching_extension = used_reaching_extension
	opportunity.maximum_speed_mps = float(movement.get("maximum_speed", 0.0))
	opportunity.acceleration_mps2 = float(movement.get("acceleration", 0.0))
	opportunity.direction_change_delay_seconds = float(movement.get(
		"direction_change_delay", 0.0
	))
	opportunity.modeled_start_speed_mps = float(movement.get(
		"modeled_start_speed_mps", 0.0
	))
	opportunity.directional_start_speed_mps = float(movement.get(
		"directional_start_speed_mps", 0.0
	))
	opportunity.directional_velocity_overcredit_mps = float(movement.get(
		"directional_velocity_overcredit_mps", 0.0
	))
	opportunity.reachable = standing_reachable or jump_reachable
	opportunity.arrival_balance = float(movement.get("arrival_balance", 0.0)) \
		* float(envelope.get("balance_factor", 1.0))
	opportunity.physical_feasibility = float(movement.get("feasibility", 0.0)) \
		if opportunity.reachable else 0.0
	opportunity.approach_speed_mps = float(approach_profile.get("approach_speed_mps", 0.0))
	opportunity.approach_quality = float(approach_profile.get("runup_quality", 0.0))
	opportunity.approach_alignment = float(approach_profile.get("approach_alignment", 1.0))
	opportunity.lateral_control = float(approach_profile.get("lateral_control", 1.0))
	opportunity.jump_multiplier = float(approach_profile.get("jump_multiplier", 1.0))

	var technique := _action_technique(actor.player, action_type)
	opportunity.technical_difficulty = clampf(
		1.0 - technique * 0.55 \
		- opportunity.arrival_balance * 0.30 \
		- opportunity.physical_feasibility * 0.15,
		0.0, 1.0,
	)
	var expected_center := clampf(
		technique * 0.45 \
		+ opportunity.arrival_balance * 0.30 \
		+ opportunity.physical_feasibility * 0.25,
		0.0, 1.0,
	)
	var uncertainty := lerpf(
		0.22, 0.06, float(actor.player.composure) / 100.0
	)
	opportunity.expected_quality = Vector2(
		clampf(expected_center - uncertainty, 0.0, 1.0),
		clampf(expected_center + uncertainty, 0.0, 1.0),
	)
	return opportunity


static func estimate_movement(
	actor: RallyPlayerState,
	target: Vector2,
	available_time: float,
	mode: RallyPlayerState.MovementMode,
	contact_reach_meters: float = 0.0,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {
			"distance_meters": 99.0, "travel_time": 99.0,
			"arrival_balance": 0.0, "feasibility": 0.0,
			"maximum_speed": 0.0, "direction": Vector2.ZERO,
		}
	var meter_delta := RallyKinematicsModel.court_delta_meters(
		actor.position, target
	)
	var distance := meter_delta.length()
	var movement_distance := maxf(distance - maxf(contact_reach_meters, 0.0), 0.0)
	var direction := meter_delta.normalized() if distance > 0.001 else Vector2.ZERO
	## RallyPlayerState velocity is expressed in court meters per second.
	var raw_speed := actor.velocity.length()
	var directional_start_speed := maxf(actor.velocity.dot(direction), 0.0)
	## Only velocity already aimed toward the new target reduces travel time.
	## Sideways or opposite momentum must not be credited as forward speed.
	var current_speed := directional_start_speed
	## Restating the speed curve, mass penalty, facing fit, and turn cost here is
	## how this function and `_movement_profile()` drifted apart in the first
	## place -- the copy had to be found and patched separately every time the
	## model changed. One profile now answers for both.
	var profile := _movement_profile(actor, direction, mode)
	var maximum_speed := float(profile.maximum_speed)
	var acceleration := float(profile.acceleration)
	var facing_fit := float(profile.facing_fit)
	var direction_change_delay := float(profile.direction_change_delay)
	var acceleration_time := maxf(
		(maximum_speed - current_speed) / maxf(acceleration, 0.1), 0.0
	)
	var acceleration_distance := current_speed * acceleration_time \
		+ 0.5 * acceleration * acceleration_time * acceleration_time

	var movement_time := 0.0
	if movement_distance > 0.001:
		if movement_distance <= acceleration_distance:
			movement_time = (
				-current_speed
				+ sqrt(maxf(current_speed * current_speed + 2.0 * acceleration * movement_distance, 0.0))
			) / maxf(acceleration, 0.1)
		else:
			movement_time = acceleration_time \
				+ (movement_distance - acceleration_distance) / maxf(maximum_speed, 0.1)
	var travel_time := direction_change_delay + movement_time \
		if movement_distance > 0.001 else 0.0
	var usable_time := maxf(available_time - direction_change_delay, 0.0)
	var capacity_acceleration_time := minf(usable_time, acceleration_time)
	var movement_capacity := current_speed * capacity_acceleration_time \
		+ 0.5 * acceleration * capacity_acceleration_time \
			* capacity_acceleration_time
	if usable_time > acceleration_time:
		movement_capacity += maximum_speed * (usable_time - acceleration_time)
	var arrival_margin := available_time - travel_time
	var edge_pressure := clampf(-arrival_margin / 0.65, 0.0, 1.0)
	var arrival_balance := clampf(
		actor.balance * lerpf(1.0, 0.45, edge_pressure) \
		* lerpf(0.76, 1.0, facing_fit),
		0.0, 1.0,
	)
	var feasibility := clampf(
		available_time / maxf(travel_time, 0.05), 0.0, 1.0
	)
	return {
		"distance_meters": distance,
		"travel_time": travel_time,
		"arrival_balance": arrival_balance,
		"feasibility": feasibility,
		"maximum_speed": maximum_speed,
		"acceleration": acceleration,
		"direction_change_delay": direction_change_delay,
		"modeled_start_speed_mps": current_speed,
		"directional_start_speed_mps": directional_start_speed,
		"directional_velocity_overcredit_mps": maxf(
			raw_speed - directional_start_speed, 0.0
		),
		"movement_capacity_meters": movement_capacity,
		"center_distance_deficit_meters": maxf(
			distance - movement_capacity - maxf(contact_reach_meters, 0.0), 0.0
		),
		"direction": direction,
	}


## Advances a temporary actor snapshot toward a target without mutating the
## supplied rally state. Velocity is carried into the returned snapshot so a
## later perception update can redirect movement already underway.
## `carry_through` decides what arriving means.
##
## The default is a player who has got where they were going and set up there,
## which is right for a defensive mark. It is wrong for a waypoint: a hitter
## running to their approach mark does not stop on it, they run through it into
## the swing. That distinction did not exist, so arrival always wrote
## `Vector2.ZERO` and every player in the engine reached every destination at a
## dead stop -- contradicting this function's own contract two lines above, and
## leaving `_leg_seconds`'s carried-speed branch permanently unreachable.
static func project_toward(
	actor: RallyPlayerState,
	target: Vector2,
	duration: float,
	mode: RallyPlayerState.MovementMode,
	carry_through: bool = false,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {"actor": null, "distance_meters": 0.0, "elapsed": 0.0}
	var projected := actor.snapshot()
	var elapsed := maxf(duration, 0.0)
	var meter_delta := RallyKinematicsModel.court_delta_meters(
		actor.position, target
	)
	var distance := meter_delta.length()
	if elapsed <= 0.0 or distance <= 0.001:
		return {
			"actor": projected, "distance_meters": 0.0,
			"elapsed": elapsed, "reached_target": distance <= 0.001,
		}
	var direction := meter_delta.normalized()
	var profile := _movement_profile(actor, direction, mode)
	var direction_change_delay := float(profile.direction_change_delay)
	var movement_duration := maxf(elapsed - direction_change_delay, 0.0)
	var maximum_speed := float(profile.maximum_speed)
	var acceleration := float(profile.acceleration)
	var forward_speed := maxf(actor.velocity.dot(direction), 0.0)
	var acceleration_time := maxf(
		(maximum_speed - forward_speed) / maxf(acceleration, 0.1), 0.0
	)
	var capacity := 0.0
	var ending_speed := forward_speed
	if movement_duration <= acceleration_time:
		capacity = forward_speed * movement_duration \
			+ 0.5 * acceleration * movement_duration * movement_duration
		ending_speed = minf(
			forward_speed + acceleration * movement_duration, maximum_speed
		)
	else:
		capacity = forward_speed * acceleration_time \
			+ 0.5 * acceleration * acceleration_time * acceleration_time \
			+ maximum_speed * (movement_duration - acceleration_time)
		ending_speed = maximum_speed
	var traveled := minf(capacity, distance)
	var court_delta := Vector2(
		direction.x * traveled / RallyKinematicsModel.COURT_WIDTH_METERS,
		direction.y * traveled / RallyKinematicsModel.COURT_LENGTH_METERS,
	)
	var reached_target := traveled >= distance - 0.001
	var arrival_velocity := direction * ending_speed
	if reached_target and not carry_through:
		arrival_velocity = Vector2.ZERO
	projected.apply_position(
		target if reached_target else actor.position + court_delta,
		arrival_velocity,
	)
	projected.movement_mode = mode
	projected.intent = &"receive"
	projected.intent_target = target
	return {
		"actor": projected,
		"distance_meters": traveled,
		"elapsed": elapsed,
		"movement_duration": movement_duration,
		"direction_change_delay": direction_change_delay,
		"ending_speed_mps": projected.velocity.length(),
		"reached_target": reached_target,
	}


static func generate_reception_opportunities(
	state: RallyState,
) -> Array[ActionOpportunity]:
	var opportunities: Array[ActionOpportunity] = []
	if state == null or state.ball.trajectory == null or state.home_plan == null:
		return opportunities
	var trajectory := state.ball.trajectory
	var contact_time := trajectory.earliest_contact_time(
		state.simulation_time, 0.15, 1.40
	)
	if contact_time < 0.0:
		contact_time = trajectory.end_time
	var target := trajectory.position_at_time(contact_time)
	for value in state.home_players.values():
		var actor := value as RallyPlayerState
		if actor == null:
			continue
		var zone: Resource = state.home_plan.zone_for(
			actor.player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone == null or not bool(zone.enabled):
			continue
		opportunities.append(evaluate_opportunity(
			actor, &"receive", target, contact_time,
			state.simulation_time, float(zone.priority) / 3.0,
		))
	return opportunities


## `_speed_rating()` used to live here. It had no callers left once
## `movement_profile()` started asking `LocomotionModel` for speed, and it had
## quietly drifted from the surviving copy: this one never clamped its result,
## so an out-of-range attribute would have produced a rating above 1.0 and a
## speed past the top of the curve. Deleted rather than left as a second,
## subtly different answer to a question `LocomotionModel` already owns.


## How long this traversal takes, as the closed-form inverse of
## `project_toward()`. That function answers "how far in a given time"; this one
## answers "how long for a given distance" from the identical kinematics, so the
## engine has one movement model rather than two that disagree.
##
## Before this existed, `RallySimulator._movement_time()` carried its own
## formula -- a constant-velocity trip plus a flat startup penalty, with no
## fatigue and a distance-scaled turn cost. Because a flat penalty undercharges
## short traversals and amortises away on long ones, the two models disagreed in
## opposite directions depending on phase: measured at 1.153 for receptions
## against 0.852 for attacks. See `MovementTimingRatioCalibration`.
## `waypoint` models a staged traversal -- a hitter reaching an approach start
## before running through it to contact. The leg through the corner carries its
## speed, so a staged route is not simply two standing starts.
static func traversal_seconds(
	actor: RallyPlayerState,
	target: Vector2,
	mode: RallyPlayerState.MovementMode,
	waypoint: Variant = null,
) -> float:
	return float(traversal_result(actor, target, mode, waypoint)["seconds"])


## The same traversal, keeping the speed the player carries out of it.
##
## `_leg_seconds` has always computed an exit speed and `traversal_seconds` has
## always thrown it away, so every caller got a duration and no state -- which
## is why every leg in the engine began from rest and why the guard below that
## skips the standing-start charge for a moving player had never once fired.
## The value existed; nothing could reach it.
static func traversal_result(
	actor: RallyPlayerState,
	target: Vector2,
	mode: RallyPlayerState.MovementMode,
	waypoint: Variant = null,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {"seconds": 0.0, "exit_speed": 0.0, "exit_velocity": Vector2.ZERO}
	if waypoint == null:
		var single := _leg_seconds(actor, actor.position, target, mode, 0.0)
		return _with_exit_velocity(single, actor.position, target)
	var corner := Vector2(waypoint)
	var first := _leg_seconds(actor, actor.position, corner, mode, 0.0)
	## Only the component of the carried speed aligned with the new heading
	## survives the corner; the rest has to be rebuilt.
	var outgoing := RallyKinematicsModel.court_delta_meters(corner, target)
	var carried := 0.0
	if outgoing.length() > 0.0001:
		var incoming := RallyKinematicsModel.court_delta_meters(actor.position, corner)
		if incoming.length() > 0.0001:
			carried = maxf(
				incoming.normalized().dot(outgoing.normalized()), 0.0
			) * float(first["exit_speed"])
	var second := _leg_seconds(actor, corner, target, mode, carried)
	return _with_exit_velocity(
		{
			"seconds": float(first["seconds"]) + float(second["seconds"]),
			"exit_speed": float(second["exit_speed"]),
		},
		corner, target,
	)


## Turns a scalar exit speed into a velocity along the heading the leg ended on,
## which is the form a player's state carries and the next leg reads.
static func _with_exit_velocity(
	leg: Dictionary, from: Vector2, to: Vector2
) -> Dictionary:
	var heading := RallyKinematicsModel.court_delta_meters(from, to)
	var speed := float(leg.get("exit_speed", 0.0))
	return {
		"seconds": float(leg.get("seconds", 0.0)),
		"exit_speed": speed,
		"exit_velocity": heading.normalized() * speed \
			if heading.length() > 0.0001 else Vector2.ZERO,
	}


static func _leg_seconds(
	actor: RallyPlayerState,
	from: Vector2,
	to: Vector2,
	mode: RallyPlayerState.MovementMode,
	entry_speed: float,
) -> Dictionary:
	var meter_delta := RallyKinematicsModel.court_delta_meters(from, to)
	var distance := meter_delta.length()
	if distance <= 0.001:
		## A zero-length leg costs no time and sheds no speed. Returning
		## `entry_speed` looks harmless and is not: the two-leg form passes 0.0
		## as the first leg's entry and lets it fall back to the actor's own
		## velocity, so a corner that coincides with the start reported an exit
		## of zero and handed the *real* leg a standing start -- the one case
		## where a waypoint silently discards the speed a player is carrying.
		## The home first ball takes exactly that shape: its approach mark and
		## its start are the same point.
		return {
			"seconds": 0.0,
			"exit_speed": entry_speed if entry_speed > 0.0 \
				else actor.velocity.length(),
		}
	var direction := meter_delta.normalized()
	var profile := _movement_profile(actor, direction, mode)
	var maximum_speed := maxf(float(profile.maximum_speed), 0.05)
	var acceleration := maxf(float(profile.acceleration), 0.1)
	## A caller-supplied carried speed wins; otherwise read the actor's own.
	var opening_speed := entry_speed if entry_speed > 0.0 \
		else maxf(actor.velocity.dot(direction), 0.0)
	var seconds := _accelerated_seconds(
		distance, opening_speed, maximum_speed, acceleration
	)
	## Turning is only charged when the traversal actually starts from rest;
	## a player already carrying speed into this leg has already turned.
	if entry_speed <= 0.0:
		seconds += float(profile.direction_change_delay)
	return {
		"seconds": seconds,
		"exit_speed": minf(
			opening_speed + acceleration * seconds, maximum_speed
		),
	}


## Time to cover `distance` accelerating from `entry_speed` toward
## `maximum_speed`. Exactly the traversal `project_toward()` integrates, solved
## for time instead of distance.
static func _accelerated_seconds(
	distance: float,
	entry_speed: float,
	maximum_speed: float,
	acceleration: float,
) -> float:
	var to_top_speed := maxf((maximum_speed - entry_speed) / acceleration, 0.0)
	var distance_while_accelerating := entry_speed * to_top_speed \
		+ 0.5 * acceleration * to_top_speed * to_top_speed
	if distance <= distance_while_accelerating:
		## Still accelerating on arrival: solve 0.5at^2 + v0t - d = 0.
		var discriminant := entry_speed * entry_speed + 2.0 * acceleration * distance
		return (sqrt(maxf(discriminant, 0.0)) - entry_speed) / acceleration
	return to_top_speed + (distance - distance_while_accelerating) / maximum_speed


## Public accessor for the rating-driven movement profile. Exposed so a stepped
## integrator can share this exact tuning -- maximum speed, acceleration, and
## direction-change delay all derive from player ratings, mass, and fatigue, and
## must not be duplicated anywhere.
static func movement_profile(
	actor: RallyPlayerState,
	direction: Vector2,
	mode: RallyPlayerState.MovementMode,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {
			"maximum_speed": 0.0, "acceleration": 0.0,
			"facing_fit": 0.0, "direction_change_delay": 0.0,
		}
	return _movement_profile(actor, direction, mode)


static func _movement_profile(
	actor: RallyPlayerState,
	direction: Vector2,
	mode: RallyPlayerState.MovementMode,
) -> Dictionary:
	var acceleration_rating := float(actor.player.acceleration) / 100.0
	var mass_factor := lerpf(
		1.06, 0.90,
		clampf((actor.player.mass_kg - 55.0) / 60.0, 0.0, 1.0),
	)
	var fatigue_factor := 1.0 - actor.player.fatigue * 0.30
	## Top speed is the product of the two things that physically produce it:
	## how far a step carries this player in this mode, and how often they take
	## one. The single `lerpf(1.35, 5.25, rating)` curve this replaces could not
	## be the product of any plausible pair -- it spanned 3.89x worst-to-best
	## where human turnover spans about 1.8x -- and its floor described a walk.
	## Fatigue is applied inside `cadence_hz()`, because tired legs stop turning
	## over before they stop reaching; it must not be charged again here.
	var maximum_speed := LocomotionModel.maximum_speed(actor.player, mode) \
		* mass_factor
	var acceleration := lerpf(2.2, 6.8, acceleration_rating) * fatigue_factor
	var facing_fit := 1.0
	if actor.facing.length_squared() > 0.001 and direction.length_squared() > 0.001:
		facing_fit = clampf(
			(actor.facing.normalized().dot(direction) + 1.0) * 0.5,
			0.0, 1.0,
		)
	return {
		"maximum_speed": maximum_speed,
		"acceleration": acceleration,
		"facing_fit": facing_fit,
		"stride_meters": LocomotionModel.stride_meters(actor.player, mode),
		"cadence_hz": LocomotionModel.cadence_hz(actor.player, mode),
		## Turnover, not just geometry: a player who turns their legs over faster
		## spends less time planting and redirecting.
		"direction_change_delay": LocomotionModel.direction_change_seconds(
			actor.player, mode, facing_fit, TURN_DELAY_WORST_SECONDS,
			TURN_DELAY_BEST_SECONDS,
		),
	}




static func _movement_mode_for(
	action_type: StringName,
) -> RallyPlayerState.MovementMode:
	match action_type:
		&"receive", &"dig":
			return RallyPlayerState.MovementMode.LATERAL
		&"block", &"assist_block":
			return RallyPlayerState.MovementMode.BLOCK_CLOSE
		&"attack":
			return RallyPlayerState.MovementMode.APPROACH
	return RallyPlayerState.MovementMode.TRANSITION


static func _action_technique(
	player: VolleyballPlayer,
	action_type: StringName,
) -> float:
	match action_type:
		&"receive":
			return float(player.reception) / 100.0
		&"dig":
			return float(player.dig_control) / 100.0
		&"set":
			return clampf(
				float(player.set_accuracy) / 100.0 * 0.55
				+ float(player.hand_control) / 100.0 * 0.30
				+ float(player.tempo_control) / 100.0 * 0.15,
				0.0, 1.0,
			)
		&"attack":
			return float(player.attack_accuracy) / 100.0
		&"block", &"assist_block":
			return float(player.block_timing) / 100.0
	return float(player.ball_control) / 100.0
