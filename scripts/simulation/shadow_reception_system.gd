class_name ShadowReceptionSystem
extends RefCounted

const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")
const RallyOpportunityModel := preload("res://scripts/simulation/rally_opportunity_system.gd")
const RallyDecisionModel := preload("res://scripts/simulation/rally_decision_system.gd")
const RallyContactModel := preload("res://scripts/simulation/rally_contact_system.gd")
const ShadowSetterResponseModel := preload("res://scripts/simulation/shadow_setter_response_system.gd")
const RallyPlaybackAdapterModel := preload("res://scripts/simulation/rally_playback_adapter.gd")
const REPEATED_READ_PROGRESS: Array[float] = [0.12, 0.32, 0.52]


## Evaluates reception from persistent positions and player-specific perceived
## flights. The legacy claimant is recorded for comparison and never replaced.
static func evaluate(
	home_players: Array[VolleyballPlayer],
	home_lineup: RotationLineup,
	home_plan: Resource,
	opponent_team: Resource,
	server: VolleyballPlayer,
	serve_style: String,
	serve_quality: float,
	trajectory_data: Dictionary,
	legacy_claimant_id: int,
	seed_value: int,
) -> RallyTrace:
	var trace := RallyTrace.create(&"shadow_reception", seed_value)
	if home_lineup == null or home_plan == null or trajectory_data.is_empty():
		trace.summary = {"available": false, "reason": "missing rally inputs"}
		return trace

	var signature := _serve_signature(
		server, serve_style, serve_quality, trajectory_data
	)
	var legacy_flight := BallFlight.create(
		Vector2(trajectory_data.get("start_position", Vector2.ZERO)),
		Vector2(trajectory_data.get("end_position", Vector2.ZERO)),
		float(trajectory_data.get("start_time", 0.0)),
		float(trajectory_data.get("duration", 0.8)),
		signature,
		float(trajectory_data.get("end_height_meters", 1.0)),
	)
	var timing_diagnostics := RallyKinematicsModel.timing_diagnostics(
		legacy_flight.origin,
		legacy_flight.destination,
		signature.speed_mps,
		legacy_flight.duration(),
		signature.vertical_angle_degrees,
	)
	var flight := BallFlight.create(
		legacy_flight.origin,
		legacy_flight.destination,
		legacy_flight.start_time,
		float(timing_diagnostics.get(
			"implied_duration_seconds", legacy_flight.duration()
		)),
		signature,
		legacy_flight.contact_height_meters,
	)
	var canonical_timing_diagnostics := RallyKinematicsModel.timing_diagnostics(
		flight.origin, flight.destination, signature.speed_mps,
		flight.duration(), signature.vertical_angle_degrees, 0.001,
	)
	var derived_signature := _signature_with_speed(
		signature,
		float(timing_diagnostics.get("effective_recorded_speed_mps", 0.0)),
	)
	var derived_speed_flight := BallFlight.create(
		legacy_flight.origin, legacy_flight.destination, legacy_flight.start_time,
		legacy_flight.duration(), derived_signature,
		legacy_flight.contact_height_meters,
	)
	var state := RallyStateBuilder.build(
		home_players, home_lineup, home_plan, opponent_team,
		null, false, seed_value,
	)
	var best_player_id := -1
	var best_score := -1000.0
	var signature_best_player_id := -1
	var signature_best_score := -1000.0
	var derived_speed_best_player_id := -1
	var derived_speed_best_score := -1000.0
	var repeated_read_best_player_id := -1
	var repeated_read_best_score := -1000.0
	var signature_tags := _signature_tags(signature)
	var derived_signature_tags := _signature_tags(derived_signature)
	for value in state.home_players.values():
		var actor := value as RallyPlayerState
		if actor == null or actor.player == null:
			continue
		var zone: Resource = home_plan.zone_for(
			actor.player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone == null or not bool(zone.enabled):
			continue
		var familiarity := Familiarity.familiarity(actor.player, signature_tags)
		var estimate := BallReadSystem.estimate(
			flight, actor.player, familiarity,
			flight.start_time + flight.duration() * 0.22,
			_seed_for_player(seed_value, actor.player_id),
		)
		var signature_estimate := BallReadSystem.estimate(
			flight, actor.player, familiarity,
			flight.start_time + flight.duration() * 0.22,
			_seed_for_player(seed_value, actor.player_id),
		)
		var derived_familiarity := Familiarity.familiarity(
			actor.player, derived_signature_tags
		)
		var derived_speed_estimate := BallReadSystem.estimate(
			derived_speed_flight, actor.player, derived_familiarity,
			derived_speed_flight.start_time + derived_speed_flight.duration() * 0.22,
			_seed_for_player(seed_value, actor.player_id),
		)
		var priority := float(zone.priority) / 3.0
		var perceived_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", estimate.perceived_destination,
			estimate.perceived_arrival_time, estimate.recognition_time, priority,
		)
		var true_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", flight.destination,
			flight.arrival_time, estimate.recognition_time, priority,
		)
		var signature_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", signature_estimate.perceived_destination,
			signature_estimate.perceived_arrival_time,
			signature_estimate.recognition_time, priority,
		)
		var derived_speed_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", derived_speed_estimate.perceived_destination,
			derived_speed_estimate.perceived_arrival_time,
			derived_speed_estimate.recognition_time, priority,
		)
		var derived_true_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", derived_speed_flight.destination,
			derived_speed_flight.arrival_time,
			derived_speed_estimate.recognition_time, priority,
		)
		var repeated_read := _repeated_read_candidate(
			state, flight, actor, familiarity, priority,
			_seed_for_player(seed_value, actor.player_id),
		)
		var score := _selection_score(
			perceived_opportunity, estimate.confidence, priority
		)
		var signature_score := _selection_score(
			signature_opportunity, signature_estimate.confidence, priority
		)
		var derived_speed_score := _selection_score(
			derived_speed_opportunity, derived_speed_estimate.confidence, priority
		)
		if score > best_score:
			best_score = score
			best_player_id = actor.player_id
		if signature_score > signature_best_score:
			signature_best_score = signature_score
			signature_best_player_id = actor.player_id
		if derived_speed_score > derived_speed_best_score:
			derived_speed_best_score = derived_speed_score
			derived_speed_best_player_id = actor.player_id
		var repeated_read_score := float(repeated_read.get("selection_score", -1000.0))
		if repeated_read_score > repeated_read_best_score:
			repeated_read_best_score = repeated_read_score
			repeated_read_best_player_id = actor.player_id
		trace.add_entry({
			"player_id": actor.player_id,
			"player_name": actor.player.display_name,
			"start_position": actor.position,
			"true_destination": flight.destination,
			"perceived_destination": estimate.perceived_destination,
			"true_arrival_time": flight.arrival_time,
			"perceived_arrival_time": estimate.perceived_arrival_time,
			"recognition_time": estimate.recognition_time,
			"novelty": estimate.novelty,
			"confidence": estimate.confidence,
			"destination_error_meters": estimate.destination_error_meters(),
			"travel_time": perceived_opportunity.travel_time,
			"arrival_margin": perceived_opportunity.arrival_margin,
			"true_arrival_margin": true_opportunity.arrival_margin,
			"reachable": perceived_opportunity.reachable,
			"physical_feasibility": perceived_opportunity.physical_feasibility,
			"expected_quality": perceived_opportunity.expected_quality,
			"tactical_priority": priority,
			"selection_score": score,
			"signature_candidate": {
				"perceived_arrival_time": signature_estimate.perceived_arrival_time,
				"recognition_time": signature_estimate.recognition_time,
				"travel_time": signature_opportunity.travel_time,
				"arrival_margin": signature_opportunity.arrival_margin,
				"reachable": signature_opportunity.reachable,
				"selection_score": signature_score,
			},
			"derived_speed_candidate": {
				"perceived_destination": derived_speed_estimate.perceived_destination,
				"perceived_arrival_time": derived_speed_estimate.perceived_arrival_time,
				"recognition_time": derived_speed_estimate.recognition_time,
				"novelty": derived_speed_estimate.novelty,
				"confidence": derived_speed_estimate.confidence,
				"destination_error_meters": derived_speed_estimate.destination_error_meters(),
				"travel_time": derived_speed_opportunity.travel_time,
				"arrival_margin": derived_speed_opportunity.arrival_margin,
				"reachable": derived_speed_opportunity.reachable,
				"true_arrival_margin": derived_true_opportunity.arrival_margin,
				"physical_feasibility": derived_speed_opportunity.physical_feasibility,
				"expected_quality": derived_speed_opportunity.expected_quality,
				"selection_score": derived_speed_score,
			},
			"repeated_read_candidate": repeated_read,
			"legacy_selected": actor.player_id == legacy_claimant_id,
		})

	for entry in trace.entries:
		entry["independent_speed_candidate"] = {
			"perceived_destination": entry.get("perceived_destination", Vector2.ZERO),
			"perceived_arrival_time": entry.get("perceived_arrival_time", 0.0),
			"recognition_time": entry.get("recognition_time", 0.0),
			"novelty": entry.get("novelty", 0.0),
			"confidence": entry.get("confidence", 0.0),
			"destination_error_meters": entry.get("destination_error_meters", 0.0),
			"travel_time": entry.get("travel_time", 0.0),
			"arrival_margin": entry.get("arrival_margin", 0.0),
			"reachable": entry.get("reachable", false),
			"selection_score": entry.get("selection_score", 0.0),
		}
		entry["shadow_selected"] = int(entry.get("player_id", -1)) \
			== best_player_id
		entry["independent_speed_selected"] = int(entry.get("player_id", -1)) \
			== best_player_id
		entry["signature_selected"] = int(entry.get("player_id", -1)) \
			== signature_best_player_id
		entry["derived_speed_selected"] = int(entry.get("player_id", -1)) \
			== derived_speed_best_player_id
		entry["repeated_read_selected"] = int(entry.get("player_id", -1)) \
			== repeated_read_best_player_id
	var agreement := best_player_id >= 0 and best_player_id == legacy_claimant_id
	var legacy_timing_selection := _entry_for(
		trace.entries, derived_speed_best_player_id
	)
	var selected_legacy_timing_candidate: Dictionary = \
		legacy_timing_selection.get("derived_speed_candidate", {})
	var signature_timing_selection := _entry_for(
		trace.entries, signature_best_player_id
	)
	var selected_signature_candidate: Dictionary = signature_timing_selection.get(
		"signature_candidate", {}
	)
	var derived_speed_selection := _entry_for(
		trace.entries, derived_speed_best_player_id
	)
	var selected_derived_speed_candidate: Dictionary = derived_speed_selection.get(
		"derived_speed_candidate", {}
	)
	var independent_speed_selection := _entry_for(trace.entries, best_player_id)
	var selected_independent_speed_candidate: Dictionary = \
		independent_speed_selection.get("independent_speed_candidate", {})
	var repeated_read_selection := _entry_for(
		trace.entries, repeated_read_best_player_id
	)
	var selected_repeated_read_candidate: Dictionary = repeated_read_selection.get(
		"repeated_read_candidate", {}
	)
	var selected_repeated_moments: Array = selected_repeated_read_candidate.get(
		"moments", []
	)
	var selected_final_moment: Dictionary = selected_repeated_moments[-1] \
		if not selected_repeated_moments.is_empty() else {}
	trace.summary = {
		"available": not trace.entries.is_empty(),
		"legacy_claimant_id": legacy_claimant_id,
		"shadow_claimant_id": best_player_id,
		"agreement": agreement,
		"reason": _comparison_reason(
			trace.entries, legacy_claimant_id, best_player_id, agreement
		),
		"true_destination": flight.destination,
		"flight_start_time": flight.start_time,
		"true_arrival_time": flight.arrival_time,
		"canonical_signature_source": "calculated_speed_derived_duration",
		"signature": _signature_dict(signature),
		"signature_tags": signature_tags,
		"independent_speed_signature": _signature_dict(signature),
		"independent_speed_signature_tags": signature_tags,
		"derived_speed_signature": _signature_dict(derived_signature),
		"derived_speed_signature_tags": derived_signature_tags,
		"timing_diagnostics": timing_diagnostics,
		"canonical_timing_diagnostics": canonical_timing_diagnostics,
		"timing_candidates": {
			"legacy_duration": {
				"duration_seconds": legacy_flight.duration(),
				"shadow_claimant_id": derived_speed_best_player_id,
				"selected_reachable": bool(
					selected_legacy_timing_candidate.get("reachable", false)
				),
				"selected_arrival_margin": float(
					selected_legacy_timing_candidate.get("arrival_margin", 0.0)
				),
			},
			"signature_duration": {
				"duration_seconds": flight.duration(),
				"shadow_claimant_id": signature_best_player_id,
				"selected_reachable": bool(
					selected_signature_candidate.get("reachable", false)
				),
				"selected_arrival_margin": float(
					selected_signature_candidate.get("arrival_margin", 0.0)
				),
			},
			"claimant_changed": derived_speed_best_player_id != best_player_id,
		},
		"speed_candidates": {
			"independent_speed": {
				"speed_mps": signature.speed_mps,
				"shadow_claimant_id": best_player_id,
				"selected_reachable": bool(
					selected_independent_speed_candidate.get("reachable", false)
				),
				"selected_arrival_margin": float(
					selected_independent_speed_candidate.get("arrival_margin", 0.0)
				),
				"selected_destination_error_meters": float(
					selected_independent_speed_candidate.get(
						"destination_error_meters", 0.0
					)
				),
				"selected_recognition_time": float(
					selected_independent_speed_candidate.get(
						"recognition_time", flight.start_time
					)
				),
			},
			"derived_speed": {
				"speed_mps": derived_signature.speed_mps,
				"shadow_claimant_id": derived_speed_best_player_id,
				"selected_reachable": bool(
					selected_derived_speed_candidate.get("reachable", false)
				),
				"selected_arrival_margin": float(
					selected_derived_speed_candidate.get("arrival_margin", 0.0)
				),
				"selected_destination_error_meters": float(
					selected_derived_speed_candidate.get(
						"destination_error_meters", 0.0
					)
				),
				"selected_recognition_time": float(
					selected_derived_speed_candidate.get(
						"recognition_time", flight.start_time
					)
				),
			},
			"claimant_changed": best_player_id != derived_speed_best_player_id,
		},
		"perception_candidates": {
			"observation_progresses": REPEATED_READ_PROGRESS.duplicate(),
			"single_read": {
				"shadow_claimant_id": best_player_id,
				"selected_reachable": bool(
					selected_independent_speed_candidate.get("reachable", false)
				),
				"selected_arrival_margin": float(
					selected_independent_speed_candidate.get("arrival_margin", 0.0)
				),
				"selected_destination_error_meters": float(
					selected_independent_speed_candidate.get(
						"destination_error_meters", 0.0
					)
				),
				"selected_confidence": float(
					selected_independent_speed_candidate.get("confidence", 0.0)
				),
			},
			"repeated_read": {
				"projection_model": "read_only_persistent_movement",
				"shadow_claimant_id": repeated_read_best_player_id,
				"selected_reachable": bool(
					selected_repeated_read_candidate.get("reachable", false)
				),
				"selected_true_reachable": bool(
					selected_repeated_read_candidate.get("true_reachable", false)
				),
				"selected_arrival_margin": float(
					selected_repeated_read_candidate.get("arrival_margin", 0.0)
				),
				"selected_true_arrival_margin": float(
					selected_repeated_read_candidate.get(
						"true_arrival_margin", 0.0
					)
				),
				"selected_destination_error_meters": float(
					selected_repeated_read_candidate.get(
						"destination_error_meters", 0.0
					)
				),
				"selected_confidence": float(
					selected_repeated_read_candidate.get("confidence", 0.0)
				),
				"total_correction_distance_meters": float(
					selected_repeated_read_candidate.get(
						"total_correction_distance_meters", 0.0
					)
				),
				"final_correction_distance_meters": float(
					selected_repeated_read_candidate.get(
						"final_correction_distance_meters", 0.0
					)
				),
				"projected_distance_meters": float(
					selected_repeated_read_candidate.get(
						"projected_distance_meters", 0.0
					)
				),
				"projected_position": selected_repeated_read_candidate.get(
					"projected_position", Vector2.ZERO
				),
				"initial_true_distance_meters": float(
					selected_repeated_read_candidate.get(
						"initial_true_distance_meters", 0.0
					)
				),
				"first_decision_delay_seconds": float(
					selected_repeated_read_candidate.get(
						"first_decision_delay_seconds", 0.0
					)
				),
				"time_remaining_after_first_decision_seconds": float(
					selected_repeated_read_candidate.get(
						"time_remaining_after_first_decision_seconds", 0.0
					)
				),
				"final_available_time_seconds": float(
					selected_repeated_read_candidate.get(
						"final_available_time_seconds", 0.0
					)
				),
				"final_target_distance_meters": float(
					selected_repeated_read_candidate.get(
						"final_target_distance_meters", 0.0
					)
				),
				"final_movement_capacity_meters": float(
					selected_repeated_read_candidate.get(
						"final_movement_capacity_meters", 0.0
					)
				),
				"final_center_distance_deficit_meters": float(
					selected_repeated_read_candidate.get(
						"final_center_distance_deficit_meters", 0.0
					)
				),
				"contact_reach_meters": float(
					selected_repeated_read_candidate.get(
						"contact_reach_meters", 0.0
					)
				),
				"directional_velocity_overcredit_mps": float(
					selected_repeated_read_candidate.get(
						"directional_velocity_overcredit_mps", 0.0
					)
				),
				"stationary_selected_reachable": bool(
					selected_final_moment.get("stationary_reachable", false)
				),
				"stationary_selected_arrival_margin": float(
					selected_final_moment.get("stationary_arrival_margin", 0.0)
				),
				"scheduled_ever_reachable": bool(
					selected_repeated_read_candidate.get(
						"scheduled_ever_reachable", false
					)
				),
				"opportunity_window_count": int(
					selected_repeated_read_candidate.get(
						"opportunity_window_count", 0
					)
				),
				"opportunity_open_duration_seconds": float(
					selected_repeated_read_candidate.get(
						"opportunity_open_duration_seconds", 0.0
					)
				),
				"intent_change_count": int(
					selected_repeated_read_candidate.get(
						"intent_change_count", 0
					)
				),
				"opportunity_closed_early": bool(
					selected_repeated_read_candidate.get(
						"opportunity_closed_early", false
					)
				),
			},
			"claimant_changed": best_player_id != repeated_read_best_player_id,
		},
	}
	var provisional_pass_target := Vector2(0.50, 0.60)
	if home_plan.has_method("setter_release_target"):
		provisional_pass_target = home_plan.setter_release_target(
			home_lineup.active_setter_id()
		)
	var provisional_decision := RallyDecisionModel.select_shadow_reception(
		trace.entries,
		flight.destination,
		flight.arrival_time,
		provisional_pass_target,
	)
	var provisional_contact: Dictionary = provisional_decision.contact_result
	var expected_setter_intent := \
		ShadowSetterResponseModel.expected_second_contact_intent(
			state, int(provisional_contact.get("actor_id", -1))
		)
	var preferred_pass_target := Vector2(expected_setter_intent.get(
		"target", Vector2(0.50, 0.67)
	))
	trace.summary["expected_second_contact_intent"] = expected_setter_intent
	var shadow_decision := RallyDecisionModel.select_shadow_reception(
		trace.entries,
		flight.destination,
		flight.arrival_time,
		preferred_pass_target,
	)
	var shadow_decision_data := shadow_decision.to_dict()
	trace.summary["shadow_decision"] = shadow_decision_data
	var outgoing_candidate := \
		RallyContactModel.resolve_shadow_reception(
			Dictionary(shadow_decision_data.get("contact_result", {}))
		)
	trace.summary["outgoing_flight_candidate"] = outgoing_candidate
	trace.summary["shadow_setter_response"] = ShadowSetterResponseModel.evaluate(
		state, outgoing_candidate,
		int(Dictionary(shadow_decision_data.get(
			"contact_result", {}
		)).get("actor_id", -1)),
		seed_value + 700001,
	)
	trace.summary["shadow_playback_candidate"] = \
		RallyPlaybackAdapterModel.build_shadow_reception_events(
			trace.summary, trace.entries
		)
	return trace


static func _repeated_read_candidate(
	state: RallyState,
	flight: BallFlight,
	actor: RallyPlayerState,
	familiarity: float,
	priority: float,
	seed_value: int,
) -> Dictionary:
	var estimates := BallReadSystem.estimate_sequence(
		flight, actor.player, familiarity, REPEATED_READ_PROGRESS, seed_value
	)
	var moments: Array[Dictionary] = []
	var final_opportunity: ActionOpportunity = null
	var final_estimate: BallFlightEstimate = null
	var previous_destination := Vector2.ZERO
	var previous_decision_time := flight.start_time
	var projected_actor := actor
	var cumulative_projected_distance := 0.0
	var total_correction := 0.0
	var final_correction := 0.0
	var first_decision_time := flight.arrival_time
	for index in range(estimates.size()):
		var estimate: BallFlightEstimate = estimates[index]
		var decision_time := maxf(estimate.observed_at, estimate.recognition_time)
		if index == 0:
			first_decision_time = decision_time
		var projection := {
			"actor": projected_actor,
			"distance_meters": 0.0,
			"ending_speed_mps": projected_actor.velocity.length(),
		}
		if index > 0:
			projection = RallyMovementSystem.project_toward(
				projected_actor,
				previous_destination,
				decision_time - previous_decision_time,
				RallyPlayerState.MovementMode.LATERAL,
			)
			projected_actor = projection.get("actor") as RallyPlayerState
			cumulative_projected_distance += float(
				projection.get("distance_meters", 0.0)
			)
		var opportunity := RallyMovementSystem.evaluate_opportunity(
			projected_actor, &"receive", estimate.perceived_destination,
			estimate.perceived_arrival_time, decision_time, priority,
		)
		var stationary_opportunity := RallyMovementSystem.evaluate_opportunity(
			actor, &"receive", estimate.perceived_destination,
			estimate.perceived_arrival_time, decision_time, priority,
		)
		var correction := 0.0
		if index > 0:
			correction = RallyKinematicsModel.court_distance_meters(
				previous_destination, estimate.perceived_destination
			)
			total_correction += correction
			final_correction = correction
		moments.append({
			"observation_progress": REPEATED_READ_PROGRESS[index],
			"observed_at": estimate.observed_at,
			"decision_time": decision_time,
			"projected_position": projected_actor.position,
			"projected_velocity_mps": projected_actor.velocity,
			"projected_segment_distance_meters": float(
				projection.get("distance_meters", 0.0)
			),
			"projected_distance_meters": cumulative_projected_distance,
			"projected_speed_mps": float(
				projection.get("ending_speed_mps", 0.0)
			),
			"perceived_destination": estimate.perceived_destination,
			"perceived_arrival_time": estimate.perceived_arrival_time,
			"recognition_time": estimate.recognition_time,
			"novelty": estimate.novelty,
			"confidence": estimate.confidence,
			"destination_error_meters": estimate.destination_error_meters(),
			"arrival_time_error_seconds": estimate.arrival_time_error(),
			"travel_time": opportunity.travel_time,
			"available_time": opportunity.available_time,
			"target_distance_meters": opportunity.target_distance_meters,
			"movement_capacity_meters": opportunity.movement_capacity_meters,
			"center_distance_deficit_meters": opportunity.center_distance_deficit_meters,
			"contact_reach_meters": opportunity.contact_reach_meters,
			"directional_velocity_overcredit_mps": opportunity.directional_velocity_overcredit_mps,
			"arrival_margin": opportunity.arrival_margin,
			"reachable": opportunity.reachable,
			"stationary_arrival_margin": stationary_opportunity.arrival_margin,
			"stationary_reachable": stationary_opportunity.reachable,
			"correction_distance_meters": correction,
		})
		previous_destination = estimate.perceived_destination
		previous_decision_time = decision_time
		final_estimate = estimate
		final_opportunity = opportunity
	if final_estimate == null or final_opportunity == null:
		return {"moments": moments, "selection_score": -1000.0}
	var scheduled_timeline: Dictionary = RallyOpportunityModel.evaluate_reception_timeline(
		state, actor.player_id, moments, flight.arrival_time
	)
	var final_decision_time := maxf(
		final_estimate.observed_at, final_estimate.recognition_time
	)
	var true_final_opportunity := RallyMovementSystem.evaluate_opportunity(
		projected_actor, &"receive", flight.destination,
		flight.arrival_time, final_decision_time, priority,
	)
	var contact_options := _contact_options(
		actor.player, final_opportunity, final_estimate.confidence
	)
	var physically_executable_contact_options := _contact_options(
		actor.player, true_final_opportunity, final_estimate.confidence
	)
	var opportunity_closed_early := false
	for raw_window in scheduled_timeline.get("windows", []):
		var window: Dictionary = raw_window
		if str(window.get("close_reason", "")) == "projected_late":
			opportunity_closed_early = true
			break
	return {
		"moments": moments,
		"perceived_destination": final_estimate.perceived_destination,
		"perceived_arrival_time": final_estimate.perceived_arrival_time,
		"recognition_time": final_estimate.recognition_time,
		"novelty": final_estimate.novelty,
		"confidence": final_estimate.confidence,
		"destination_error_meters": final_estimate.destination_error_meters(),
		"travel_time": final_opportunity.travel_time,
		"initial_true_distance_meters": RallyKinematicsModel.court_distance_meters(
			actor.position, flight.destination
		),
		"first_decision_delay_seconds": maxf(
			first_decision_time - flight.start_time, 0.0
		),
		"time_remaining_after_first_decision_seconds": maxf(
			flight.arrival_time - first_decision_time, 0.0
		),
		"final_available_time_seconds": true_final_opportunity.available_time,
		"final_target_distance_meters": true_final_opportunity.target_distance_meters,
		"final_movement_capacity_meters": true_final_opportunity.movement_capacity_meters,
		"final_center_distance_deficit_meters": true_final_opportunity.center_distance_deficit_meters,
		"contact_reach_meters": true_final_opportunity.contact_reach_meters,
		"directional_velocity_overcredit_mps": true_final_opportunity.directional_velocity_overcredit_mps,
		"arrival_margin": final_opportunity.arrival_margin,
		"reachable": final_opportunity.reachable,
		"physical_feasibility": final_opportunity.physical_feasibility,
		"expected_quality": final_opportunity.expected_quality,
		"contact_options": contact_options,
		"perceived_contact_options": contact_options,
		"physically_executable_contact_options": physically_executable_contact_options,
		"true_reachable": true_final_opportunity.reachable,
		"true_arrival_margin": true_final_opportunity.arrival_margin,
		"true_arrival_balance": true_final_opportunity.arrival_balance,
		"true_physical_feasibility": true_final_opportunity.physical_feasibility,
		"selection_score": _selection_score(
			final_opportunity, final_estimate.confidence, priority
		),
		"total_correction_distance_meters": total_correction,
		"final_correction_distance_meters": final_correction,
		"projected_position": projected_actor.position,
		"projected_velocity_mps": projected_actor.velocity,
		"projected_distance_meters": cumulative_projected_distance,
		"opportunity_timeline": scheduled_timeline,
		"scheduled_ever_reachable": bool(
			scheduled_timeline.get("ever_reachable", false)
		),
		"opportunity_window_count": int(
			scheduled_timeline.get("window_count", 0)
		),
		"opportunity_open_duration_seconds": float(
			scheduled_timeline.get("total_open_duration", 0.0)
		),
		"intent_change_count": int(
			scheduled_timeline.get("intent_change_count", 0)
		),
		"opportunity_closed_early": opportunity_closed_early,
	}


static func _contact_options(
	player: VolleyballPlayer,
	opportunity: ActionOpportunity,
	confidence: float,
) -> Array[String]:
	var options: Array[String] = []
	if opportunity.physical_feasibility >= 0.35:
		options.append("emergency_keep_alive")
	if opportunity.reachable and opportunity.arrival_balance >= 0.38:
		options.append("safe_center_pass")
	if opportunity.reachable \
			and opportunity.arrival_margin >= 0.12 \
			and opportunity.arrival_balance >= 0.62 \
			and confidence >= 0.60 \
			and player.ball_control >= 65 \
			and player.decision_making >= 60:
		options.append("quick_release_pass")
	return options


static func _selection_score(
	opportunity: ActionOpportunity,
	confidence: float,
	priority: float,
) -> float:
	var expected_center := (
		opportunity.expected_quality.x + opportunity.expected_quality.y
	) * 0.5
	return (
		(1.0 if opportunity.reachable else -0.65)
		+ opportunity.physical_feasibility * 0.38
		+ expected_center * 0.28
		+ priority * 0.18
		+ confidence * 0.16
		+ clampf(opportunity.arrival_margin, -1.0, 0.5) * 0.24
	)


static func _signature_with_speed(
	source: BallContactSignature,
	speed_mps: float,
) -> BallContactSignature:
	return BallContactSignature.create(
		source.action_type,
		speed_mps,
		source.horizontal_angle_degrees,
		source.vertical_angle_degrees,
		source.topspin_rps,
		source.sidespin_rps,
		source.flight_stability,
	)


static func _serve_signature(
	server: VolleyballPlayer,
	serve_style: String,
	serve_quality: float,
	trajectory_data: Dictionary,
) -> BallContactSignature:
	var start := Vector2(trajectory_data.get("start_position", Vector2.ZERO))
	var end := Vector2(trajectory_data.get("end_position", Vector2.ZERO))
	var delta_meters := Vector2((end.x - start.x) * 9.0, (end.y - start.y) * 18.0)
	var horizontal_angle := rad_to_deg(atan2(delta_meters.x, absf(delta_meters.y)))
	var power := float(server.serve_power) / 100.0 if server != null else 0.5
	var technique := float(server.serve_technique) / 100.0 if server != null else 0.5
	var variation := float(server.serve_variation) / 100.0 if server != null else 0.5
	var control := clampf(serve_quality * 0.55 + technique * 0.30 + power * 0.15, 0.0, 1.0)
	var speed := lerpf(12.0, 28.0, control)
	var vertical_angle := -10.0
	var topspin := lerpf(1.0, 4.0, technique)
	var sidespin := clampf(horizontal_angle / 12.0, -4.0, 4.0) * variation
	var stability := lerpf(0.72, 0.96, technique)
	var action_type: StringName = &"standing_serve"
	match serve_style:
		"Jump Topspin":
			action_type = &"topspin_serve"
			speed += 2.0
			vertical_angle = -18.0
			topspin = lerpf(6.0, 15.0, technique)
		"Jump Float":
			action_type = &"jump_float"
			vertical_angle = -7.0
			topspin = lerpf(-0.35, 0.35, technique)
			sidespin = lerpf(0.35, -0.35, variation)
			stability = lerpf(0.48, 0.20, control)
		"Hybrid":
			action_type = &"hybrid_serve"
			speed += 1.0
			vertical_angle = -14.0
			topspin = lerpf(2.5, 8.5, technique)
			stability = lerpf(0.58, 0.82, technique)
		"Sky Ball":
			action_type = &"sky_ball"
			speed -= 3.0
			vertical_angle = 35.0
			topspin = lerpf(-1.0, 2.0, variation)
			stability = lerpf(0.62, 0.86, technique)
	return BallContactSignature.create(
		action_type, speed, horizontal_angle, vertical_angle,
		topspin, sidespin, stability,
	)


static func _signature_tags(signature: BallContactSignature) -> Array[String]:
	var tags: Array[String] = ["action:%s" % String(signature.action_type)]
	tags.append("speed:%s" % ("fast" if signature.speed_mps >= 22.0 else "moderate"))
	tags.append("topspin:%s" % ("heavy" if absf(signature.topspin_rps) >= 8.0 else "light"))
	if absf(signature.sidespin_rps) >= 2.0:
		tags.append("sidespin:%s" % ("positive" if signature.sidespin_rps > 0.0 else "negative"))
	if signature.flight_stability <= 0.50:
		tags.append("stability:unstable")
	return tags


static func _signature_dict(signature: BallContactSignature) -> Dictionary:
	return {
		"action_type": String(signature.action_type),
		"speed_mps": signature.speed_mps,
		"horizontal_angle_degrees": signature.horizontal_angle_degrees,
		"vertical_angle_degrees": signature.vertical_angle_degrees,
		"topspin_rps": signature.topspin_rps,
		"sidespin_rps": signature.sidespin_rps,
		"flight_stability": signature.flight_stability,
		"baseline_novelty": signature.baseline_novelty(),
	}


static func _comparison_reason(
	entries: Array[Dictionary],
	legacy_id: int,
	shadow_id: int,
	agreement: bool,
) -> String:
	if entries.is_empty():
		return "No eligible serve-receive candidates."
	if agreement:
		return "Legacy and shadow models select the same receiver."
	var legacy := _entry_for(entries, legacy_id)
	var shadow := _entry_for(entries, shadow_id)
	if shadow.is_empty():
		return "Shadow model found no preferred receiver."
	if legacy.is_empty():
		return "Legacy claimant is outside the shadow candidate set."
	if bool(shadow.get("reachable", false)) and not bool(legacy.get("reachable", false)):
		return "Shadow receiver is reachable after recognition; legacy receiver is late."
	var margin_difference := float(shadow.get("arrival_margin", 0.0)) \
		- float(legacy.get("arrival_margin", 0.0))
	if margin_difference >= 0.08:
		return "Shadow receiver has a better perceived arrival margin."
	return "Perception confidence, tactical priority, and expected control change the ranking."


static func _entry_for(entries: Array[Dictionary], player_id: int) -> Dictionary:
	for entry in entries:
		if int(entry.get("player_id", -1)) == player_id:
			return entry
	return {}


static func _seed_for_player(seed_value: int, player_id: int) -> int:
	return seed_value * 104729 + player_id * 8191 + 17
