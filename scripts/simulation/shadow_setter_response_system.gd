class_name ShadowSetterResponseSystem
extends RefCounted

const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const SetterFailureClassifierModel := preload(
	"res://scripts/simulation/setter_failure_classifier.gd"
)
const READ_PROGRESS: Array[float] = [0.15, 0.40, 0.65]
const MIN_SET_CONTACT_WINDOW_SECONDS: float = 0.06
const MAX_SET_CONTACT_WINDOW_SECONDS: float = 0.16


## Chooses the player expected to own second contact before the reception is
## resolved. This intent supplies the receiver's target; the later evaluate()
## pass still verifies who can actually reach the resulting ball flight.
static func expected_second_contact_intent(
	state: RallyState,
	first_contact_player_id: int,
) -> Dictionary:
	if state == null or state.home_lineup == null:
		return {
			"player_id": -1,
			"target": Vector2(0.50, 0.60),
			"reason": "missing rally state or lineup",
		}
	var preferred_setter_id := state.home_lineup.active_setter_id()
	if preferred_setter_id != first_contact_player_id \
			and state.home_players.has(preferred_setter_id):
		return _intent_for_player(
			state, preferred_setter_id, "active setter available"
		)

	var selected_id := -1
	var selected_score := -INF
	for raw_actor in state.home_players.values():
		var actor := raw_actor as RallyPlayerState
		if actor == null or actor.player == null \
				or actor.player_id == first_contact_player_id:
			continue
		var duty := _second_contact_duty(state.home_plan, actor.player_id)
		var score := _duty_priority(duty, false) * 0.62 \
			+ _player_setting_fit(actor.player) * 0.38
		if score > selected_score or (is_equal_approx(score, selected_score) \
				and actor.player_id < selected_id):
			selected_id = actor.player_id
			selected_score = score
	return _intent_for_player(
		state, selected_id, "emergency second-contact responsibility"
	)


## Lets eligible second-contact players perceive and move toward the outgoing
## reception flight. The supplied RallyState is read-only; every actor used for
## projection is a snapshot.
static func evaluate(
	state: RallyState,
	outgoing_candidate: Dictionary,
	first_contact_player_id: int,
	seed_value: int,
) -> Dictionary:
	if state == null or not bool(outgoing_candidate.get("available", false)):
		return {"available": false, "reason": "missing outgoing flight"}
	var flight := _flight_from_dict(Dictionary(outgoing_candidate.get("flight", {})))
	if flight == null or state.home_lineup == null:
		return {"available": false, "reason": "invalid outgoing flight or lineup"}

	var preferred_setter_id := state.home_lineup.active_setter_id()
	var expected_intent := expected_second_contact_intent(
		state, first_contact_player_id
	)
	var expected_setter_id := int(expected_intent.get("player_id", -1))
	var candidates: Array[Dictionary] = []
	for raw_actor in state.home_players.values():
		var actor := raw_actor as RallyPlayerState
		if actor == null or actor.player == null \
				or actor.player_id == first_contact_player_id:
			continue
		var duty := _second_contact_duty(state.home_plan, actor.player_id)
		var duty_priority := _duty_priority(
			duty, actor.player_id == preferred_setter_id
		)
		var preparation_target := actor.tactical_home
		if actor.player_id == expected_setter_id:
			preparation_target = Vector2(expected_intent.get(
				"target", actor.tactical_home
			))
		var candidate := _evaluate_candidate(
			actor, flight, duty, duty_priority, preparation_target,
			seed_value + actor.player_id * 131,
		)
		candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.get("selection_score", -999.0)),
				float(b.get("selection_score", -999.0))):
			return int(a.get("player_id", -1)) < int(b.get("player_id", -1))
		return float(a.get("selection_score", -999.0)) \
			> float(b.get("selection_score", -999.0))
	)
	var selected: Dictionary = candidates[0] if not candidates.is_empty() else {}
	var expected_candidate := _candidate_for_player(
		candidates, expected_setter_id
	)
	var selected_setter_id := int(selected.get("player_id", -1))
	var ownership_changed := selected_setter_id >= 0 \
		and expected_setter_id >= 0 and selected_setter_id != expected_setter_id
	var failure_classification := SetterFailureClassifierModel.classify(selected)
	return {
		"available": true,
		"shadow_only": true,
		"preferred_setter_id": preferred_setter_id,
		"expected_setter_id": expected_setter_id,
		"expected_setter_target": expected_intent.get(
			"target", Vector2(0.50, 0.60)
		),
		"first_contact_player_id": first_contact_player_id,
		"expected_setter_name": str(expected_intent.get(
			"player_name", "Unassigned"
		)),
		"selected_setter_id": selected_setter_id,
		"selected_setter_name": str(selected.get("player_name", "Unassigned")),
		"selected_matches_expected": int(selected.get("player_id", -1)) \
			== expected_setter_id,
		"ownership_changed": ownership_changed,
		"handoff_reason": _handoff_reason(
			expected_setter_id, selected_setter_id, expected_candidate
		),
		"expected_candidate_reachable": bool(expected_candidate.get(
			"true_reachable", false
		)),
		"expected_candidate_arrival_margin": float(expected_candidate.get(
			"true_arrival_margin", -9.0
		)),
		"expected_candidate_balance": float(expected_candidate.get(
			"true_arrival_balance", 0.0
		)),
		"selected_is_preferred": int(selected.get("player_id", -1)) \
			== preferred_setter_id,
		"selected_reachable": bool(selected.get("true_reachable", false)),
		"selected_actions": Array(selected.get("set_options", [])).duplicate(),
		"selected_perceived_actions": Array(selected.get(
			"perceived_set_options", selected.get("set_options", [])
		)).duplicate(),
		"selected_physically_executable_actions": Array(selected.get(
			"physically_executable_set_options", []
		)).duplicate(),
		"selected_action_count": Array(selected.get("set_options", [])).size(),
		"selected_window_duration_seconds": float(selected.get(
			"window_duration_seconds", 0.0
		)),
		"selected_projected_distance_meters": float(selected.get(
			"projected_distance_meters", 0.0
		)),
		"selected_confidence": float(selected.get("confidence", 0.0)),
		"selected_observation": Dictionary(selected.get(
			"observation", {}
		)).duplicate(true),
		"selected_observation_fingerprint": str(selected.get(
			"observation_fingerprint", ""
		)),
		"selection_observation_only": not bool(selected.get(
			"decision_uses_authoritative_truth", true
		)),
		"selected_true_arrival_margin": float(selected.get(
			"true_arrival_margin", -9.0
		)),
		"selected_initial_distance_meters": float(selected.get(
			"initial_true_distance_meters", 0.0
		)),
		"selected_final_available_time_seconds": float(selected.get(
			"final_available_time_seconds", 0.0
		)),
		"selected_final_target_distance_meters": float(selected.get(
			"final_target_distance_meters", 0.0
		)),
		"selected_final_movement_capacity_meters": float(selected.get(
			"final_movement_capacity_meters", 0.0
		)),
		"selected_final_center_distance_deficit_meters": float(selected.get(
			"final_center_distance_deficit_meters", 0.0
		)),
		"selected_contact_reach_meters": float(selected.get(
			"contact_reach_meters", 0.0
		)),
		"selected_directional_velocity_overcredit_mps": float(selected.get(
			"directional_velocity_overcredit_mps", 0.0
		)),
		"selected_failure_classification": failure_classification,
		"candidates": candidates,
		"candidate_count": candidates.size(),
		"source_state_unchanged": _state_unchanged(state),
	}


static func _evaluate_candidate(
	source_actor: RallyPlayerState,
	flight: BallFlight,
	duty: String,
	duty_priority: float,
	preparation_target: Vector2,
	seed_value: int,
) -> Dictionary:
	var familiarity := Familiarity.familiarity(
		source_actor.player, _signature_tags(flight.signature)
	)
	var estimates := BallReadSystem.estimate_sequence(
		flight, source_actor.player, familiarity, READ_PROGRESS, seed_value
	)
	var flight_stability := float(flight.signature.flight_stability) \
		if flight.signature != null else 0.5
	## Gate 27: the pass destination opens a short playable setting window
	## rather than representing a zero-duration point. Stable passes retain a
	## longer window; serve and movement clocks remain untouched.
	var contact_window_extension := lerpf(
		MIN_SET_CONTACT_WINDOW_SECONDS,
		MAX_SET_CONTACT_WINDOW_SECONDS,
		clampf(flight_stability, 0.0, 1.0),
	)
	var contact_deadline := flight.arrival_time + contact_window_extension
	var preparation := RallyMovementSystem.project_toward(
		source_actor, preparation_target,
		maxf(flight.start_time, 0.0),
		RallyPlayerState.MovementMode.TRANSITION,
	)
	var actor := preparation.get("actor") as RallyPlayerState
	var previous_time := flight.start_time
	var previous_target := actor.position
	var projected_distance := float(preparation.get("distance_meters", 0.0))
	var moments: Array[Dictionary] = []
	var windows: Array[ActionOpportunityWindow] = []
	var active_window: ActionOpportunityWindow = null
	var final_opportunity: ActionOpportunity = null
	var final_estimate: BallFlightEstimate = null
	var final_confidence := 0.0
	var first_decision_time := flight.arrival_time
	for estimate_index in range(estimates.size()):
		var estimate: BallFlightEstimate = estimates[estimate_index]
		var decision_time := maxf(estimate.observed_at, estimate.recognition_time)
		if estimate_index == 0:
			first_decision_time = decision_time
		var projection := RallyMovementSystem.project_toward(
			actor, previous_target, maxf(decision_time - previous_time, 0.0),
			RallyPlayerState.MovementMode.TRANSITION,
		)
		actor = projection.get("actor") as RallyPlayerState
		projected_distance += float(projection.get("distance_meters", 0.0))
		var opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"set", estimate.perceived_destination,
			estimate.perceived_arrival_time + contact_window_extension,
			decision_time, duty_priority,
			estimate.perceived_contact_height_meters, true,
		)
		if opportunity.reachable and active_window == null:
			active_window = ActionOpportunityWindow.create(
				&"set", &"home", actor.player_id, decision_time,
				contact_deadline, &"setter_projected_reachable",
			)
			windows.append(active_window)
		elif not opportunity.reachable and active_window != null:
			active_window.close(decision_time, &"setter_projected_late")
			active_window = null
		var moment := {
			"decision_time": decision_time,
			"projected_position": actor.position,
			"projected_velocity_mps": actor.velocity,
			"perceived_destination": estimate.perceived_destination,
			"perceived_arrival_time": estimate.perceived_arrival_time,
			"destination_error_meters": estimate.destination_error_meters(),
			"confidence": estimate.confidence,
			"reachable": opportunity.reachable,
			"arrival_margin": opportunity.arrival_margin,
			"available_time": opportunity.available_time,
			"target_distance_meters": opportunity.target_distance_meters,
			"movement_capacity_meters": opportunity.movement_capacity_meters,
			"center_distance_deficit_meters": opportunity.center_distance_deficit_meters,
			"contact_reach_meters": opportunity.contact_reach_meters,
			"contact_height_meters": opportunity.contact_height_meters,
			"standing_reachable": opportunity.standing_reachable,
			"jump_reachable": opportunity.jump_reachable,
			"requires_jump": opportunity.requires_jump,
			"directional_velocity_overcredit_mps": opportunity.directional_velocity_overcredit_mps,
		}
		moments.append(moment)
		if active_window != null:
			active_window.record_sample(moment)
		previous_time = decision_time
		previous_target = estimate.perceived_destination
		final_opportunity = opportunity
		final_estimate = estimate
		final_confidence = estimate.confidence
	if active_window != null:
		active_window.close(contact_deadline, &"contact_window_closed")
	var true_opportunity := RallyMovementSystem.evaluate_opportunity(
		actor, &"set", flight.destination, contact_deadline,
		previous_time, duty_priority, flight.contact_height_meters, true,
	)
	var perceived_set_options := _set_options(
		source_actor.player, final_opportunity, final_confidence
	)
	var physically_executable_set_options := _set_options(
		source_actor.player, true_opportunity, final_confidence
	)
	var observation := PlayerObservation.create_setter_observation(
		source_actor.player_id, final_estimate, final_opportunity,
		duty, duty_priority, perceived_set_options,
	)
	var observation_data := observation.to_dict()
	var contact_time := _resolved_contact_time(
		flight, previous_time, contact_deadline, true_opportunity
	)
	var contact_projection := RallyMovementSystem.project_toward(
		actor, flight.destination, maxf(contact_time - previous_time, 0.0),
		RallyPlayerState.MovementMode.TRANSITION,
	)
	var resolved_actor := contact_projection.get("actor") as RallyPlayerState
	var total_window_duration := 0.0
	var window_dicts: Array[Dictionary] = []
	for window in windows:
		total_window_duration += window.duration()
		window_dicts.append(window.to_dict())
	var expected_quality := observation.perceived_expected_quality
	return {
		"player_id": source_actor.player_id,
		"player_name": source_actor.player.display_name,
		"duty": duty,
		"duty_priority": duty_priority,
		## Gate 31: ownership selection is derived only from the player's
		## observation. True opportunity fields below are resolver evidence.
		"selection_score": observation.selection_score(),
		"observation": observation_data,
		"observation_fingerprint": observation.decision_fingerprint(),
		"decision_uses_authoritative_truth": false,
		"confidence": final_confidence,
		"perceived_reachable": final_opportunity.reachable \
			if final_opportunity != null else false,
		"true_reachable": true_opportunity.reachable,
		"true_arrival_margin": true_opportunity.arrival_margin,
		"initial_true_distance_meters": RallyKinematics.court_distance_meters(
			source_actor.position, flight.destination
		),
		"first_decision_delay_seconds": maxf(
			first_decision_time - flight.start_time, 0.0
		),
		"time_remaining_after_first_decision_seconds": maxf(
			contact_deadline - first_decision_time, 0.0
		),
		"contact_window_extension_seconds": contact_window_extension,
		"contact_deadline": contact_deadline,
		"final_available_time_seconds": true_opportunity.available_time,
		"final_target_distance_meters": true_opportunity.target_distance_meters,
		"final_movement_capacity_meters": true_opportunity.movement_capacity_meters,
		"final_center_distance_deficit_meters": true_opportunity.center_distance_deficit_meters,
		"contact_reach_meters": true_opportunity.contact_reach_meters,
		"contact_height_meters": true_opportunity.contact_height_meters,
		"standing_reach_meters": true_opportunity.standing_reach_meters,
		"maximum_contact_height_meters": true_opportunity.maximum_contact_height_meters,
		"vertical_margin_meters": true_opportunity.vertical_margin_meters,
		"standing_reachable": true_opportunity.standing_reachable,
		"jump_reachable": true_opportunity.jump_reachable,
		"requires_jump": true_opportunity.requires_jump,
		"required_takeoff_time_seconds": true_opportunity.required_takeoff_time_seconds,
		"takeoff_time_seconds": true_opportunity.takeoff_time_seconds,
		"recovery_time_seconds": true_opportunity.recovery_time_seconds,
		"used_reaching_extension": true_opportunity.used_reaching_extension,
		"directional_velocity_overcredit_mps": true_opportunity.directional_velocity_overcredit_mps,
		"expected_quality": expected_quality,
		"set_options": perceived_set_options,
		"perceived_set_options": perceived_set_options,
		"physically_executable_set_options": physically_executable_set_options,
		"window_count": windows.size(),
		"window_duration_seconds": total_window_duration,
		"projected_distance_meters": projected_distance,
		"preparation_target": preparation_target,
		"source_position": source_actor.position,
		"preparation_distance_meters": float(preparation.get(
			"distance_meters", 0.0
		)),
		"prepared_position": Vector2(
			Dictionary(preparation).get("actor", source_actor).position
		),
		"final_position": actor.position,
		"resolved_center_position": resolved_actor.position,
		"resolved_velocity_mps": resolved_actor.velocity,
		"resolved_contact_position": flight.destination,
		"resolved_contact_time": contact_time,
		"true_arrival_balance": true_opportunity.arrival_balance,
		"true_physical_feasibility": true_opportunity.physical_feasibility,
		"final_balance": actor.balance,
		"moments": moments,
		"windows": window_dicts,
	}


static func _resolved_contact_time(
	flight: BallFlight,
	decision_time: float,
	contact_deadline: float,
	opportunity: ActionOpportunity,
) -> float:
	if opportunity == null:
		return flight.arrival_time
	var actor_arrival := decision_time + maxf(opportunity.travel_time, 0.0)
	return clampf(
		maxf(flight.arrival_time, actor_arrival),
		flight.arrival_time,
		contact_deadline,
	)


static func _set_options(
	player: VolleyballPlayer,
	opportunity: ActionOpportunity,
	confidence: float,
) -> Array[String]:
	var options: Array[String] = []
	if opportunity == null:
		return options
	if opportunity.physical_feasibility >= 0.25:
		options.append("emergency_bump_set")
	if opportunity.standing_reachable and opportunity.arrival_balance >= 0.38:
		options.append("standing_set")
	if opportunity.jump_reachable and opportunity.arrival_balance >= 0.32:
		options.append("jump_set")
	if opportunity.reachable and opportunity.arrival_balance >= 0.38:
		options.append("controlled_set")
	if opportunity.reachable and opportunity.arrival_balance >= 0.68 \
			and confidence >= 0.58 and player.tempo_control >= 68:
		options.append("quick_tempo_set")
	return options


static func _second_contact_duty(plan: Resource, player_id: int) -> String:
	if plan == null or not plan.has_method("assignment_for"):
		return "No second-contact duty"
	var assignment: Resource = plan.assignment_for(player_id)
	return str(assignment.second_contact_responsibility) \
		if assignment != null else "No second-contact duty"


static func _duty_priority(duty: String, preferred: bool) -> float:
	var value := 0.15
	match duty:
		"Primary emergency setter": value = 0.82
		"Secondary emergency setter": value = 0.62
		"Stay available to attack": value = 0.08
	if preferred:
		value = 1.0
	return value


static func _intent_for_player(
	state: RallyState,
	player_id: int,
	reason: String,
) -> Dictionary:
	var target := Vector2(0.50, 0.60)
	var actor := state.home_players.get(player_id) as RallyPlayerState
	if actor != null:
		target = actor.tactical_home
	if state.home_plan != null \
			and state.home_plan.has_method("setter_release_target"):
		target = state.home_plan.setter_release_target(player_id)
	return {
		"player_id": player_id,
		"player_name": actor.player.display_name \
			if actor != null and actor.player != null else "Unassigned",
		"target": target,
		"reason": reason,
	}


static func _candidate_for_player(
	candidates: Array[Dictionary],
	player_id: int,
) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


static func _handoff_reason(
	expected_setter_id: int,
	selected_setter_id: int,
	expected_candidate: Dictionary,
) -> String:
	if expected_setter_id < 0:
		return "no intended second-contact owner"
	if selected_setter_id == expected_setter_id:
		return "intended setter retained ownership"
	if expected_candidate.is_empty():
		return "intended setter unavailable"
	if not bool(expected_candidate.get("true_reachable", false)):
		return "intended setter arrived late"
	if float(expected_candidate.get("true_arrival_balance", 0.0)) < 0.38:
		return "intended setter reached the ball without enough balance"
	if Array(expected_candidate.get("set_options", [])).is_empty():
		return "intended setter had no viable second-contact action"
	return "alternate setter owned the stronger action window"


static func _player_setting_fit(player: VolleyballPlayer) -> float:
	return clampf(
		float(player.set_accuracy) / 100.0 * 0.48
		+ float(player.ball_control) / 100.0 * 0.30
		+ float(player.decision_making) / 100.0 * 0.22,
		0.0, 1.0,
	)


static func _signature_tags(signature: BallContactSignature) -> Array[String]:
	if signature == null:
		return []
	return [
		"action:%s" % String(signature.action_type),
		"pace:%d" % int(floor(signature.speed_mps / 3.0)),
		"topspin:%d" % int(floor(signature.topspin_rps / 2.0)),
		"sidespin:%d" % int(floor(signature.sidespin_rps / 2.0)),
	]


## This system reads an incoming *pass*, not a set, so its fallbacks are the
## model's own neutral ones rather than the set-shaped defaults
## `ShadowBlockSystem` uses. Passing nothing here is deliberate and is why
## `BallFlight.from_dict()` takes context defaults instead of assuming.
static func _flight_from_dict(data: Dictionary) -> BallFlight:
	return BallFlight.from_dict(data)


static func _state_unchanged(state: RallyState) -> bool:
	for raw_actor in state.home_players.values():
		var actor := raw_actor as RallyPlayerState
		if actor != null and not actor.position.is_equal_approx(actor.tactical_home):
			return false
	return true
