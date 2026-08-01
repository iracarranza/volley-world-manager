class_name ApproachMechanicsSystem
extends RefCounted

const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")
const RallyMovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")


## Creates a decision-safe transition snapshot. A hitter releases only after
## recognizing that their current ball responsibility is finished; tactical
## duties can deliberately keep them available longer.
static func prepare_for_attack(
	state: RallyState,
	actor: RallyPlayerState,
	assignment: Dictionary,
	first_contact_player_id: int,
	set_contact_time: float,
	side: StringName = &"home",
) -> Dictionary:
	if state == null or actor == null or actor.player == null:
		return {"available": false}
	var reading := _reading_quality(actor.player)
	var recognition_delay := lerpf(0.30, 0.07, reading)
	var duty_delay := 0.0
	var release_reason := "recognized teammate ownership"
	var assignment_duty := ""
	var zone_priority := 0
	## `home_plan` is keyed by player id, and only home players appear in it.
	## Consulting it for an opponent works today only because the two id ranges
	## happen not to overlap, which is an assumption nothing enforces. Gate the
	## lookup on side so the coincidence can never become a duty leak.
	if side == &"home" and state.home_plan != null:
		var duty: Resource = state.home_plan.assignment_for(actor.player_id)
		if duty != null:
			assignment_duty = str(duty.attack_coverage_responsibility)
			var second_duty := str(duty.second_contact_responsibility)
			if "emergency setter" in second_duty.to_lower():
				duty_delay += 0.12
				release_reason = "held for emergency second contact"
			if bool(duty.emergency_pursuit):
				duty_delay += 0.05
			if assignment_duty == "Release for transition":
				duty_delay -= 0.08
				release_reason = "explicit transition release"
		var zone: Resource = state.home_plan.zone_for(
			actor.player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null and bool(zone.enabled):
			zone_priority = int(zone.priority)
			duty_delay += float(zone_priority) * 0.025
	if actor.player_id == first_contact_player_id:
		duty_delay += 0.18
		release_reason = "completed first contact"
	var release_time := state.simulation_time + maxf(
		recognition_delay + duty_delay, 0.02
	)
	var target := Vector2(assignment.get("target", Vector2(0.5, 0.53)))
	var start := approach_start_position(
		target, str(assignment.get("lane", "Left Pin")), side
	)
	var preparation_time := maxf(set_contact_time - release_time, 0.0)
	var projection := RallyMovementModel.project_toward(
		actor, start, preparation_time, RallyPlayerState.MovementMode.TRANSITION
	)
	var prepared := projection.get("actor") as RallyPlayerState
	if prepared != null:
		prepared.intent = &"prepare_attack"
		prepared.intent_target = start
	return {
		"available": prepared != null,
		"actor": prepared,
		"release_time": release_time,
		"release_reason": release_reason,
		"recognition_delay_seconds": recognition_delay,
		"duty_delay_seconds": duty_delay,
		"defensive_duty": assignment_duty,
		"zone_priority": zone_priority,
		## Playback must render where the hitter physically ended up, not where
		## they were trying to get to. When preparation time is short (tight
		## tempo, contested duty) these two positions diverge, and showing the
		## aspirational mark would draw a run-up the player never actually made.
		"approach_start_position": prepared.position if prepared != null else start,
		## The ideal mark this player was working toward. Kept separately for
		## scouting/debug overlays ("missed their spot by 0.4m") without ever
		## feeding it into anything that draws a court position.
		"approach_target_position": start,
		"preparation_time_seconds": preparation_time,
		"preparation_distance_meters": float(projection.get("distance_meters", 0.0)),
		"reached_approach_start": bool(projection.get("reached_target", false)),
		"prepared_position": prepared.position if prepared != null else actor.position,
		"prepared_velocity_mps": prepared.velocity if prepared != null else actor.velocity,
		"decision_uses_authoritative_truth": false,
	}


## Resolves the run-up that is physically possible from the actor's current
## state. This profile is consumed by the contact envelope and action menu.
static func evaluate_takeoff(
	actor: RallyPlayerState,
	target: Vector2,
	available_time: float,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {}
	var delta := RallyKinematicsModel.court_delta_meters(actor.position, target)
	var distance := delta.length()
	var direction := delta.normalized() if distance > 0.001 else actor.facing
	var lateral_share := absf(direction.x)
	var speed_rating := lerpf(
		float(actor.player.transition_speed),
		float(actor.player.lateral_speed), lateral_share * 0.65
	) / 100.0
	var fatigue_factor := 1.0 - actor.player.fatigue * 0.30
	var mass_factor := lerpf(1.06, 0.90, clampf(
		(actor.player.mass_kg - 55.0) / 60.0, 0.0, 1.0
	))
	var maximum_speed := lerpf(1.35, 5.25, speed_rating) * mass_factor * fatigue_factor
	var acceleration := lerpf(2.2, 6.8, float(actor.player.acceleration) / 100.0) \
		* fatigue_factor
	var alignment := 1.0
	if actor.facing.length_squared() > 0.001 and direction.length_squared() > 0.001:
		alignment = clampf((actor.facing.normalized().dot(direction) + 1.0) * 0.5, 0.0, 1.0)
	var turn_delay := lerpf(0.20, 0.02, alignment)
	var run_time := maxf(available_time - turn_delay, 0.0)
	var start_speed := maxf(actor.velocity.dot(direction), 0.0)
	var ending_speed := minf(start_speed + acceleration * run_time, maximum_speed)
	var capacity := (start_speed + ending_speed) * 0.5 * run_time
	## Approach distance is scored against this player's own preferred run-up
	## rather than a league-wide constant. Middles want a compact approach, tall
	## long-strided outsides want a full runway, and both are correct.
	var approach_profile := actor.player.system_fit(
		VolleyballPlayer.SYSTEM_FIT_APPROACH_DISTANCE
	)
	var tolerance_scale := actor.player.system_fit_tolerance_scale()
	var distance_evaluation := {}
	if approach_profile != null:
		distance_evaluation = approach_profile.evaluate(distance, tolerance_scale)
	var distance_fit := float(distance_evaluation.get("fit", 0.0))
	var in_system := bool(distance_evaluation.get("in_system", false))
	var system_bonus := float(distance_evaluation.get("bonus_multiplier", 1.0))
	var speed_fraction := ending_speed / maxf(maximum_speed, 0.1)
	var timing := float(actor.player.approach_timing) / 100.0
	var lateral_control := clampf(
		lerpf(1.0, float(actor.player.lateral_speed) / 100.0, lateral_share)
		* lerpf(0.72, 1.0, alignment), 0.0, 1.0
	)
	var runway_completion := 1.0 if distance <= 0.05 else clampf(capacity / distance, 0.0, 1.0)
	## Distance fit carries real weight now (0.19, up from a token 0.09) because
	## it is player-specific: missing your own mark is a genuine execution error.
	var quality := clampf(
		speed_fraction * 0.24 + timing * 0.22 + alignment * 0.15
		+ lateral_control * 0.12 + distance_fit * 0.19
		+ actor.balance * 0.08, 0.0, 1.0
	) * lerpf(0.62, 1.0, runway_completion)
	## Landing inside the tight rhythm band is a discrete reward on top of the
	## continuous curve, and it eases the shot-menu gates: being in system can be
	## the difference between having the full menu available and not.
	quality = clampf(quality * system_bonus, 0.0, 1.0)
	var power_threshold := 0.48 if in_system else 0.52
	var menu_threshold := 0.61 if in_system else 0.66
	return {
		"approach_distance_meters": distance,
		"ideal_approach_distance_meters": approach_profile.ideal_value \
			if approach_profile != null else 0.0,
		"approach_distance_tolerance_meters": float(
			distance_evaluation.get("tolerance", 0.0)
		),
		"approach_distance_deviation_meters": float(
			distance_evaluation.get("signed_deviation", 0.0)
		),
		"approach_distance_fit": distance_fit,
		"approach_in_system": in_system,
		"approach_undershot": bool(distance_evaluation.get("undershot", false)),
		"approach_overshot": bool(distance_evaluation.get("overshot", false)),
		"system_fit_bonus": system_bonus,
		"available_run_time_seconds": run_time,
		"approach_speed_mps": ending_speed,
		"maximum_approach_speed_mps": maximum_speed,
		"approach_speed_fraction": speed_fraction,
		"approach_alignment": alignment,
		"lateral_share": lateral_share,
		"lateral_control": lateral_control,
		"runway_completion": runway_completion,
		"runup_quality": quality,
		## A compromised approach reduces how much of the player's rated jump is
		## available; it does not erase their standing two-foot jump.
		"jump_multiplier": lerpf(0.90, 1.08, quality),
		"balance_multiplier": lerpf(0.58, 1.04, quality * lateral_control),
		"power_access": quality >= power_threshold and speed_fraction >= 0.42 \
			and lateral_control >= 0.42,
		"full_shot_menu": quality >= menu_threshold and lateral_control >= 0.56,
	}


## Where a hitter starts their run-up for a ball at `target`.
##
## The depth offset is signed by side and must be: a hitter approaches the net
## from behind it, and "behind" is +y for the home side and -y for the opponent.
## Taking the home offset for an opponent would place their approach mark across
## the net, inside home territory.
static func approach_start_position(
	target: Vector2,
	lane: String,
	side: StringName = &"home",
) -> Vector2:
	var lateral_offset := 0.0
	if lane == "Left Pin":
		lateral_offset = 0.07
	elif lane == "Right Pin":
		lateral_offset = -0.07
	if side == &"opponent":
		return Vector2(
			clampf(target.x + lateral_offset, 0.06, 0.94),
			clampf(target.y - 0.11, 0.04, 0.46),
		)
	return Vector2(
		clampf(target.x + lateral_offset, 0.06, 0.94),
		clampf(target.y + 0.11, 0.54, 0.96),
	)


static func available_attack_families(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
) -> Array[String]:
	var actions: Array[String] = ["controlled_roll"]
	var quality := float(profile.get("runup_quality", 0.0))
	var lateral_control := float(profile.get("lateral_control", 0.0))
	if player.finesse >= 45:
		actions.append("tip")
	if player.attack_accuracy >= 48 and lateral_control >= 0.36 \
			and arrival_margin >= -0.12:
		actions.append("placed_attack")
	if player.attack_power >= 52 and bool(profile.get("power_access", false)) \
			and arrival_margin >= -0.06:
		actions.append("power_attack")
	if player.tooling >= 58 and quality >= 0.46 and lateral_control >= 0.48:
		actions.append("tool_block")
	return actions


static func _reading_quality(player: VolleyballPlayer) -> float:
	return clampf((
		float(player.anticipation) * 0.38
		+ float(player.court_vision) * 0.32
		+ float(player.decision_making) * 0.20
		+ float(player.composure) * 0.10
	) / 100.0, 0.0, 1.0)
