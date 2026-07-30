class_name ShadowAttackSystem
extends RefCounted

const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")
const ApproachMechanicsModel := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)
const READ_PROGRESS: Array[float] = [0.15, 0.45, 0.72]
const SET_DURATIONS: Array[float] = [0.34, 0.48, 0.70, 1.02]


static func evaluate(
	state: RallyState,
	setter_response: Dictionary,
	first_contact_player_id: int,
	seed_value: int,
) -> Dictionary:
	if state == null or state.home_lineup == null:
		return {"available": false, "reason": "missing rally state or lineup"}
	var setter_id := int(setter_response.get("selected_setter_id", -1))
	var setter_candidate := _candidate_for(
		setter_response.get("candidates", []), setter_id
	)
	if setter_candidate.is_empty():
		return {"available": false, "reason": "missing setter candidate"}
	var source_fingerprint := _state_fingerprint(state)
	var set_contact := Vector2(setter_candidate.get(
		"resolved_contact_position", Vector2(0.50, 0.60)
	))
	var set_contact_time := float(setter_candidate.get(
		"resolved_contact_time", state.simulation_time
	))
	var options := _setter_options(
		state, setter_id, first_contact_player_id,
		set_contact, set_contact_time, seed_value,
	)
	if options.is_empty():
		return {
			"available": false,
			"reason": "no legal attack assignments",
			"source_state_unchanged": source_fingerprint == _state_fingerprint(state),
		}
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.get("selection_score", -999.0)), float(b.get(
			"selection_score", -999.0
		))):
			return int(a.get("player_id", -1)) < int(b.get("player_id", -1))
		return float(a.get("selection_score", -999.0)) > float(b.get(
			"selection_score", -999.0
		))
	)
	var selected: Dictionary = options[0]
	var flight := _set_flight(set_contact, set_contact_time, selected)
	var hitter_response := _evaluate_hitter(
		state, selected, flight, first_contact_player_id, seed_value + 410003
	)
	return {
		"available": true,
		"shadow_only": true,
		"setter_id": setter_id,
		"first_contact_player_id": first_contact_player_id,
		"setter_options": options,
		"setter_option_count": options.size(),
		"selected_assignment": selected.duplicate(true),
		"setter_observation": {
			"observer_id": setter_id,
			"side": "home",
			"perceived_action": "choose_attack_option",
			"perceived_teammates": _setter_observed_options(options),
			"decision_uses_authoritative_truth": false,
		},
		"set_flight": flight.to_dict(),
		"hitter_response": hitter_response,
		"source_state_unchanged": source_fingerprint == _state_fingerprint(state),
	}


static func _setter_options(
	state: RallyState,
	setter_id: int,
	first_contact_player_id: int,
	set_contact: Vector2,
	set_contact_time: float,
	seed_value: int,
) -> Array[Dictionary]:
	var assignments := _legal_assignments(state, setter_id)
	var options: Array[Dictionary] = []
	var setter_actor := state.player_state(&"home", setter_id)
	var setter_reading := _reading_quality(
		setter_actor.player if setter_actor != null else null
	)
	for index in range(assignments.size()):
		var assignment: Dictionary = assignments[index]
		var player_id := int(assignment.get("player_id", -1))
		var actor := state.player_state(&"home", player_id)
		if actor == null or actor.player == null:
			continue
		var target := CourtConstants.lane_target(str(assignment.get(
			"lane", "Left Pin"
		)))
		assignment["target"] = target
		var tempo := clampi(int(assignment.get("tempo", 2)), 0, 3)
		var contact_time := set_contact_time + SET_DURATIONS[tempo]
		var preparation := ApproachMechanicsModel.prepare_for_attack(
			state, actor, assignment, first_contact_player_id, set_contact_time
		)
		var prepared_actor := preparation.get("actor") as RallyPlayerState
		if prepared_actor == null:
			continue
		var perceived_actor := prepared_actor.snapshot()
		var error := _position_error(
			lerpf(1.35, 0.10, setter_reading),
			seed_value + player_id * 193 + index * 17,
		)
		perceived_actor.apply_position(
			_clamp_point(prepared_actor.position + error), prepared_actor.velocity
		)
		var priority := float(assignment.get("priority", 1)) / 6.0
		var truth_profile := ApproachMechanicsModel.evaluate_takeoff(
			prepared_actor, target, maxf(contact_time - set_contact_time, 0.0)
		)
		var perceived_profile := ApproachMechanicsModel.evaluate_takeoff(
			perceived_actor, target, maxf(contact_time - set_contact_time, 0.0)
		)
		var perceived := RallyMovementSystem.evaluate_opportunity(
			perceived_actor, &"attack", target, contact_time,
			set_contact_time, priority, 2.55, true, perceived_profile,
		)
		var truth := RallyMovementSystem.evaluate_opportunity(
			prepared_actor, &"attack", target, contact_time,
			set_contact_time, priority, 2.55, true,
			truth_profile,
		)
		var attack_fit := (
			float(actor.player.attack_accuracy) * 0.42
			+ float(actor.player.approach_timing) * 0.34
			+ float(actor.player.attack_power) * 0.24
		) / 100.0
		var perceived_margin_score := clampf(
			perceived.arrival_margin + 0.35, 0.0, 1.0
		)
		var score := perceived_margin_score * 0.34 \
			+ perceived.arrival_balance * 0.18 \
			+ attack_fit * 0.22 + priority * 0.14 \
			+ setter_reading * 0.12
		if player_id == first_contact_player_id:
			score -= 0.08
		options.append({
			"player_id": player_id,
			"player_name": actor.player.display_name,
			"lane": str(assignment.get("lane", "Left Pin")),
			"tempo": tempo,
			"priority": int(assignment.get("priority", 1)),
			"is_decoy": bool(assignment.get("is_decoy", false)),
			"target": target,
			"set_origin": set_contact,
			"set_contact_time": set_contact_time,
			"attack_contact_time": contact_time,
			"perceived_start_position": perceived_actor.position,
			"preparation": _public_preparation(preparation),
			"perceived_approach": perceived_profile,
			"perceived_reachable": perceived.reachable,
			"perceived_arrival_margin": perceived.arrival_margin,
			"perceived_arrival_balance": perceived.arrival_balance,
			"selection_score": score,
			"decision_uses_authoritative_truth": false,
			"true_reachable": truth.reachable,
			"true_arrival_margin": truth.arrival_margin,
			"true_arrival_balance": truth.arrival_balance,
		})
	return options


static func _evaluate_hitter(
	state: RallyState,
	assignment: Dictionary,
	flight: BallFlight,
	first_contact_player_id: int,
	seed_value: int,
) -> Dictionary:
	var player_id := int(assignment.get("player_id", -1))
	var source_actor := state.player_state(&"home", player_id)
	if source_actor == null or source_actor.player == null:
		return {"available": false, "reason": "selected hitter missing"}
	var preparation := ApproachMechanicsModel.prepare_for_attack(
		state, source_actor, assignment, first_contact_player_id, flight.start_time
	)
	var prepared_actor := preparation.get("actor") as RallyPlayerState
	if prepared_actor == null:
		return {"available": false, "reason": "hitter could not prepare"}
	var estimates := BallReadSystem.estimate_sequence(
		flight, source_actor.player, 0.45, READ_PROGRESS, seed_value
	)
	var actor := prepared_actor.snapshot()
	var previous_time := flight.start_time
	## The called lane is known at setter contact. Ball reads refine that target;
	## they do not make a hitter wait motionless for the first visual sample.
	var previous_target := Vector2(assignment.get("target", flight.destination))
	var moments: Array[Dictionary] = []
	var final_estimate: BallFlightEstimate = null
	var final_perceived: ActionOpportunity = null
	for estimate in estimates:
		var decision_time := maxf(estimate.observed_at, estimate.recognition_time)
		var projection := RallyMovementSystem.project_toward(
			actor, previous_target, maxf(decision_time - previous_time, 0.0),
			RallyPlayerState.MovementMode.APPROACH,
		)
		actor = projection.get("actor") as RallyPlayerState
		var approach_profile := ApproachMechanicsModel.evaluate_takeoff(
			actor, estimate.perceived_destination,
			maxf(estimate.perceived_arrival_time - decision_time, 0.0)
		)
		var opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"attack", estimate.perceived_destination,
			estimate.perceived_arrival_time, decision_time,
			float(assignment.get("priority", 1)) / 6.0,
			estimate.perceived_contact_height_meters, true, approach_profile,
		)
		moments.append({
			"decision_time": decision_time,
			"projected_position": actor.position,
			"perceived_destination": estimate.perceived_destination,
			"perceived_arrival_time": estimate.perceived_arrival_time,
			"confidence": estimate.confidence,
			"reachable": opportunity.reachable,
			"arrival_margin": opportunity.arrival_margin,
			"approach_speed_mps": opportunity.approach_speed_mps,
			"approach_quality": opportunity.approach_quality,
			"lateral_control": opportunity.lateral_control,
		})
		previous_time = decision_time
		previous_target = estimate.perceived_destination
		final_estimate = estimate
		final_perceived = opportunity
	if final_estimate == null or final_perceived == null:
		return {"available": false, "reason": "hitter received no set observations"}
	var true_approach := ApproachMechanicsModel.evaluate_takeoff(
		actor, flight.destination, maxf(flight.arrival_time - previous_time, 0.0)
	)
	var perceived_approach := ApproachMechanicsModel.evaluate_takeoff(
		actor, final_estimate.perceived_destination,
		maxf(final_estimate.perceived_arrival_time - previous_time, 0.0)
	)
	var truth := RallyMovementSystem.evaluate_opportunity(
		actor, &"attack", flight.destination, flight.arrival_time,
		previous_time, float(assignment.get("priority", 1)) / 6.0,
		flight.contact_height_meters, true, true_approach,
	)
	var perceived_actions := _attack_actions(
		source_actor.player, final_perceived, final_estimate.confidence,
		perceived_approach
	)
	var physical_actions := _attack_actions(
		source_actor.player, truth, final_estimate.confidence, true_approach
	)
	var observed_opponents := _observe_opponents(
		state, source_actor.player, seed_value + 9001
	)
	var shot := _choose_shot(
		flight.destination, observed_opponents, source_actor.player
	)
	var observation := PlayerObservation.create_attack_observation(
		player_id, final_estimate, final_perceived, perceived_actions,
		observed_opponents, Vector2(shot.get("target", Vector2(0.5, 0.2))),
		{
			"lane": assignment.get("lane", ""),
			"tempo": assignment.get("tempo", 2),
			"transition_preparation": _public_preparation(preparation),
			"perceived_approach": perceived_approach.duplicate(true),
		},
	)
	var selected_action := _best_common_action(perceived_actions, physical_actions)
	var contact_projection := RallyMovementSystem.project_toward(
		actor, flight.destination, maxf(flight.arrival_time - previous_time, 0.0),
		RallyPlayerState.MovementMode.APPROACH,
	)
	var resolved_actor := contact_projection.get("actor") as RallyPlayerState
	var approach_direction := RallyKinematics.court_delta_meters(
		actor.position, flight.destination
	).normalized()
	var takeoff_velocity := approach_direction * float(true_approach.get(
		"approach_speed_mps", 0.0
	))
	var expected_quality := truth.expected_quality
	var quality := clampf(
		(expected_quality.x + expected_quality.y) * 0.5 * 0.62
		+ float(source_actor.player.usable_attack_power()) / 100.0 * 0.20
		+ float(source_actor.player.attack_accuracy) / 100.0 * 0.18,
		0.0, 1.0,
	)
	var attack_duration := lerpf(0.46, 0.24, quality)
	var attack_trajectory := BallTrajectoryModel.create(
		"continuous_attack", flight.destination,
		flight.destination.lerp(Vector2(shot.target), 0.5) + Vector2(0.0, -0.04),
		Vector2(shot.target), flight.arrival_time, attack_duration,
		0.65, flight.contact_height_meters, 0.25,
	)
	return {
		"available": true,
		"player_id": player_id,
		"player_name": source_actor.player.display_name,
		"lane": str(assignment.get("lane", "Left Pin")),
		"tempo": int(assignment.get("tempo", 2)),
		"perceived_actions": perceived_actions,
		"physically_executable_actions": physical_actions,
		"selected_action": selected_action,
		"observation": observation.to_dict(),
		"observation_fingerprint": observation.decision_fingerprint(),
		"decision_uses_authoritative_truth": false,
		"perceived_reachable": final_perceived.reachable,
		"true_reachable": truth.reachable,
		"true_arrival_margin": truth.arrival_margin,
		"true_arrival_balance": truth.arrival_balance,
		"requires_jump": truth.requires_jump,
		"contact_position": flight.destination,
		"contact_time": flight.arrival_time,
		"source_position": source_actor.position,
		"resolved_center_position": resolved_actor.position,
		"resolved_velocity_mps": takeoff_velocity,
		"transition_preparation": _public_preparation(preparation),
		"perceived_approach": perceived_approach,
		"resolved_approach": true_approach,
		"maximum_contact_height_meters": truth.maximum_contact_height_meters,
		"vertical_margin_meters": truth.vertical_margin_meters,
		"quality": quality,
		"target": Vector2(shot.target),
		"direction": str(shot.direction),
		"target_reason": str(shot.reason),
		"incoming_set_trajectory": _trajectory_for_set(flight).to_dict(),
		"outgoing_attack_trajectory": attack_trajectory.to_dict(),
		"moments": moments,
	}


static func _set_flight(
	start: Vector2,
	start_time: float,
	assignment: Dictionary,
) -> BallFlight:
	var tempo := clampi(int(assignment.get("tempo", 2)), 0, 3)
	var duration := SET_DURATIONS[tempo]
	var target := Vector2(assignment.get("target", Vector2(0.5, 0.53)))
	var distance := RallyKinematics.court_distance_meters(start, target)
	var signature := BallContactSignature.create(
		&"set", distance / maxf(duration, 0.01), 0.0,
		lerpf(18.0, 52.0, duration / 1.02), 0.0, 0.0, 0.82,
	)
	return BallFlight.create(start, target, start_time, duration, signature, 2.55)


static func _trajectory_for_set(flight: BallFlight) -> BallTrajectory:
	return BallTrajectoryModel.create(
		"continuous_set", flight.origin, flight.origin.lerp(
			flight.destination, 0.5
		) + Vector2(0.0, -0.06), flight.destination,
		flight.start_time, flight.duration(),
		lerpf(1.3, 2.5, flight.duration() / 1.02), 2.1,
		flight.contact_height_meters,
	)


static func _legal_assignments(
	state: RallyState,
	setter_id: int,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.active_play != null:
		for assignment in state.active_play.assignments:
			if assignment == null or assignment.is_decoy \
					or not state.home_lineup.is_attack_eligible(assignment.player_id) \
					or not state.home_players.has(assignment.player_id):
				continue
			result.append({
				"player_id": assignment.player_id,
				"lane": assignment.lane,
				"tempo": assignment.tempo,
				"priority": assignment.priority,
				"is_decoy": assignment.is_decoy,
			})
	if not result.is_empty():
		return result
	for slot in range(1, 7):
		var player_id := state.home_lineup.player_at_slot(slot)
		var actor := state.player_state(&"home", player_id)
		if player_id == setter_id or actor == null or actor.player == null \
				or not state.home_lineup.is_attack_eligible(player_id) \
				or str(actor.player.position_code) == "L":
			continue
		result.append({
			"player_id": player_id,
			"lane": _fallback_lane(slot),
			"tempo": 3,
			"priority": 1,
			"is_decoy": false,
		})
	return result


static func _observe_opponents(
	state: RallyState,
	hitter: VolleyballPlayer,
	seed_value: int,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var reading := _reading_quality(hitter)
	for raw_actor in state.opponent_players.values():
		var actor := raw_actor as RallyPlayerState
		if actor == null:
			continue
		var error := _position_error(
			lerpf(1.55, 0.08, reading),
			seed_value + actor.player_id * 271,
		)
		result.append({
			"player_id": actor.player_id,
			"perceived_position": _clamp_point(actor.position + error),
			"confidence": reading,
			"front_row_cue": CourtConstants.is_front_row_slot(actor.rotation_slot),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("player_id", -1)) < int(b.get("player_id", -1))
	)
	return result


static func _choose_shot(
	contact: Vector2,
	observed_opponents: Array[Dictionary],
	hitter: VolleyballPlayer,
) -> Dictionary:
	var targets: Array[Vector2] = [
		Vector2(0.18, 0.20), Vector2(0.50, 0.18), Vector2(0.82, 0.20),
		Vector2(0.24, 0.36), Vector2(0.76, 0.36),
	]
	var best := targets[0]
	var best_space := -1.0
	for target in targets:
		var nearest := 9.0
		for opponent in observed_opponents:
			nearest = minf(nearest, RallyKinematics.court_distance_meters(
				Vector2(opponent.get("perceived_position", Vector2.ZERO)), target
			))
		if nearest > best_space:
			best_space = nearest
			best = target
	return {
		"target": best,
		"direction": _direction(contact.x, best),
		"reason": "largest perceived gap",
		"decision_rating": (
			float(hitter.decision_making) + float(hitter.attack_accuracy)
		) / 200.0,
	}


static func _attack_actions(
	player: VolleyballPlayer,
	opportunity: ActionOpportunity,
	confidence: float,
	approach_profile: Dictionary = {},
) -> Array[String]:
	var actions: Array[String] = []
	if opportunity == null or not opportunity.reachable:
		return actions
	actions.append("controlled_roll")
	if player.finesse >= 45 and confidence >= 0.38:
		actions.append("tip")
	var approach_quality := float(approach_profile.get("runup_quality", 0.0))
	var lateral_control := float(approach_profile.get("lateral_control", 0.0))
	if player.attack_accuracy >= 48 and opportunity.arrival_balance >= 0.34 \
			and lateral_control >= 0.36:
		actions.append("placed_attack")
	if player.attack_power >= 52 and opportunity.arrival_balance >= 0.42 \
			and bool(approach_profile.get("power_access", false)):
		actions.append("power_attack")
	if player.tooling >= 58 and confidence >= 0.50 \
			and approach_quality >= 0.46 and lateral_control >= 0.48:
		actions.append("tool_block")
	return actions


static func _public_preparation(preparation: Dictionary) -> Dictionary:
	var result := preparation.duplicate(true)
	result.erase("actor")
	return result


static func _best_common_action(perceived: Array, physical: Array) -> String:
	for action in [
		"power_attack", "placed_attack", "tool_block", "controlled_roll", "tip",
	]:
		if action in perceived and action in physical:
			return action
	return ""


static func _setter_observed_options(options: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in options:
		result.append({
			"player_id": int(option.get("player_id", -1)),
			"lane": str(option.get("lane", "")),
			"tempo": int(option.get("tempo", 2)),
			"perceived_start_position": option.get(
				"perceived_start_position", Vector2.ZERO
			),
			"perceived_reachable": bool(option.get("perceived_reachable", false)),
			"perceived_arrival_margin": float(option.get(
				"perceived_arrival_margin", -9.0
			)),
			"selection_score": float(option.get("selection_score", -999.0)),
		})
	return result


static func _candidate_for(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


static func _reading_quality(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return clampf((
		float(player.anticipation) * 0.34
		+ float(player.court_vision) * 0.34
		+ float(player.decision_making) * 0.22
		+ float(player.composure) * 0.10
	) / 100.0, 0.0, 1.0)


static func _position_error(meters: float, seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var angle := rng.randf_range(-PI, PI)
	var magnitude := meters * rng.randf_range(0.25, 1.0)
	return Vector2(
		cos(angle) * magnitude / RallyKinematics.COURT_WIDTH_METERS,
		sin(angle) * magnitude / RallyKinematics.COURT_LENGTH_METERS,
	)


static func _clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))


static func _fallback_lane(slot: int) -> String:
	if slot == 4:
		return "Left Pin"
	if slot == 2:
		return "Right Pin"
	if slot == 3:
		return "Front Quick"
	return "Pipe"


static func _direction(contact_x: float, target: Vector2) -> String:
	if absf(target.x - contact_x) < 0.18:
		return "line"
	return "cross" if target.x > contact_x else "sharp cross"


static func _state_fingerprint(state: RallyState) -> String:
	var parts: Array[String] = ["%.6f" % state.simulation_time]
	var ids: Array[int] = []
	for player_id in state.home_players:
		ids.append(int(player_id))
	ids.sort()
	for player_id in ids:
		var actor := state.home_players[player_id] as RallyPlayerState
		parts.append("%d:%s:%s" % [player_id, str(actor.position), str(actor.velocity)])
	return "|".join(parts)
