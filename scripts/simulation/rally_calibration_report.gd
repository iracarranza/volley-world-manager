class_name RallyCalibrationReport
extends RefCounted

## Aggregates shadow traces into measured distributions. It is deliberately
## read-only with respect to rally outcomes and player state.
var requested_samples: int = 0
var available_samples: int = 0
var skipped_samples: int = 0
var invalid_samples: int = 0
var agreement_samples: int = 0
var reachable_shadow_samples: int = 0
var legacy_timing_consistent_samples: int = 0
var canonical_timing_consistent_samples: int = 0
var signature_reachable_samples: int = 0
var timing_candidate_changed_samples: int = 0
var derived_speed_reachable_samples: int = 0
var derived_speed_candidate_changed_samples: int = 0
var canonical_calculated_speed_samples: int = 0
var repeated_read_reachable_samples: int = 0
var repeated_read_candidate_changed_samples: int = 0
var stationary_repeated_read_reachable_samples: int = 0
var scheduled_opportunity_samples: int = 0
var opportunity_closed_early_samples: int = 0
var shadow_decision_samples: int = 0
var shadow_decision_conflict_samples: int = 0
var shadow_contact_success_samples: int = 0
var shadow_decision_legacy_agreement_samples: int = 0
var outgoing_flight_samples: int = 0
var outgoing_continuity_valid_samples: int = 0
var setter_response_samples: int = 0
var setter_reachable_samples: int = 0
var setter_preferred_samples: int = 0
var playback_candidate_samples: int = 0
var playback_contract_valid_samples: int = 0
var serve_to_set_comparison_samples: int = 0
var official_serve_to_set_complete_samples: int = 0
var serve_to_set_receiver_agreement_samples: int = 0
var serve_to_set_setter_agreement_samples: int = 0
var rollout_status_samples: int = 0
var rollout_official_source_samples: int = 0
var rollout_flag_enabled_samples: int = 0
var rollout_identity_preserved_samples: int = 0
var rollout_candidate_eligible_samples: int = 0
var shadow_action_choices: Dictionary = {}
var setter_failure_causes: Dictionary = {}
var metrics: Dictionary = {}
var styles: Dictionary = {}
var gate_name: String = "rally_calibration_gate_1"


func _init(report_gate_name: String = "rally_calibration_gate_1") -> void:
	gate_name = report_gate_name
	for metric_name in [
		"serve_speed_mps",
		"recorded_duration_seconds",
		"implied_duration_seconds",
		"effective_recorded_speed_mps",
		"relative_duration_error",
		"recognition_delay_seconds",
		"destination_error_meters",
		"arrival_margin_seconds",
		"signature_arrival_margin_seconds",
		"candidate_arrival_margin_delta_seconds",
		"derived_speed_mps",
		"derived_speed_arrival_margin_seconds",
		"derived_speed_destination_error_meters",
		"derived_speed_recognition_delay_seconds",
		"derived_speed_destination_error_delta_meters",
		"derived_speed_recognition_delay_delta_seconds",
		"repeated_read_destination_error_meters",
		"repeated_read_destination_error_delta_meters",
		"repeated_read_confidence",
		"repeated_read_confidence_delta",
		"repeated_read_arrival_margin_seconds",
		"receiver_true_arrival_margin_seconds",
		"repeated_read_total_correction_distance_meters",
		"repeated_read_final_correction_distance_meters",
		"repeated_read_projected_distance_meters",
		"repeated_read_arrival_margin_gain_vs_stationary_seconds",
		"receiver_initial_true_distance_meters",
		"receiver_first_decision_delay_seconds",
		"receiver_time_remaining_after_first_decision_seconds",
		"receiver_final_available_time_seconds",
		"receiver_final_target_distance_meters",
		"receiver_final_movement_capacity_meters",
		"receiver_final_center_distance_deficit_meters",
		"receiver_contact_reach_meters",
		"receiver_directional_velocity_overcredit_mps",
		"opportunity_window_count",
		"opportunity_open_duration_seconds",
		"scheduled_intent_change_count",
		"shadow_decision_option_count",
		"shadow_decision_ambiguity",
		"shadow_contact_quality",
		"selected_contact_option_count",
		"outgoing_flight_speed_mps",
		"outgoing_flight_duration_seconds",
		"outgoing_flight_stability",
		"outgoing_flight_topspin_rps",
		"outgoing_flight_sidespin_rps",
		"outgoing_speed_duration_relative_error",
		"setter_candidate_count",
		"setter_action_count",
		"setter_read_confidence",
		"setter_window_duration_seconds",
		"setter_projected_distance_meters",
		"setter_true_arrival_margin_seconds",
		"setter_initial_true_distance_meters",
		"setter_final_available_time_seconds",
		"setter_final_target_distance_meters",
		"setter_final_movement_capacity_meters",
		"setter_final_center_distance_deficit_meters",
		"setter_contact_reach_meters",
		"setter_directional_velocity_overcredit_mps",
		"shadow_playback_event_count",
		"serve_to_set_pass_destination_delta_meters",
		"serve_to_set_pass_duration_delta_seconds",
		"serve_to_set_shadow_action_count",
	]:
		metrics[metric_name] = []


func add_shadow_trace(trace: Dictionary) -> void:
	requested_samples += 1
	var summary: Dictionary = trace.get("summary", {})
	var entries: Array = trace.get("entries", [])
	var timing: Dictionary = summary.get("timing_diagnostics", {})
	var canonical_timing: Dictionary = summary.get(
		"canonical_timing_diagnostics", {}
	)
	var candidates: Dictionary = summary.get("timing_candidates", {})
	var speed_candidates: Dictionary = summary.get("speed_candidates", {})
	var perception_candidates: Dictionary = summary.get("perception_candidates", {})
	var shadow_decision: Dictionary = summary.get("shadow_decision", {})
	var outgoing_candidate: Dictionary = summary.get(
		"outgoing_flight_candidate", {}
	)
	var setter_response: Dictionary = summary.get("shadow_setter_response", {})
	var playback_candidate: Dictionary = summary.get(
		"shadow_playback_candidate", {}
	)
	var serve_to_set: Dictionary = summary.get("serve_to_set_comparison", {})
	var rollout: Dictionary = summary.get("reception_rollout", {})
	if trace.is_empty() or not bool(summary.get("available", false)):
		skipped_samples += 1
		return
	if timing.is_empty():
		invalid_samples += 1
		return
	available_samples += 1
	canonical_calculated_speed_samples += 1 if str(summary.get(
		"canonical_signature_source", ""
	)) == "calculated_speed_derived_duration" else 0
	agreement_samples += 1 if bool(summary.get("agreement", false)) else 0
	legacy_timing_consistent_samples += 1 \
		if bool(timing.get("within_tolerance", false)) else 0
	canonical_timing_consistent_samples += 1 \
		if bool(canonical_timing.get("within_tolerance", false)) else 0
	var signature_candidate: Dictionary = candidates.get("signature_duration", {})
	var legacy_candidate: Dictionary = candidates.get("legacy_duration", {})
	var independent_speed: Dictionary = speed_candidates.get("independent_speed", {})
	var derived_speed: Dictionary = speed_candidates.get("derived_speed", {})
	var single_read: Dictionary = perception_candidates.get("single_read", {})
	var repeated_read: Dictionary = perception_candidates.get("repeated_read", {})
	signature_reachable_samples += 1 \
		if bool(signature_candidate.get("selected_reachable", false)) else 0
	timing_candidate_changed_samples += 1 \
		if bool(candidates.get("claimant_changed", false)) else 0
	derived_speed_reachable_samples += 1 \
		if bool(derived_speed.get("selected_reachable", false)) else 0
	derived_speed_candidate_changed_samples += 1 \
		if bool(speed_candidates.get("claimant_changed", false)) else 0
	repeated_read_reachable_samples += 1 \
		if bool(repeated_read.get("selected_reachable", false)) else 0
	repeated_read_candidate_changed_samples += 1 \
		if bool(perception_candidates.get("claimant_changed", false)) else 0
	stationary_repeated_read_reachable_samples += 1 \
		if bool(repeated_read.get("stationary_selected_reachable", false)) else 0
	scheduled_opportunity_samples += 1 \
		if bool(repeated_read.get("scheduled_ever_reachable", false)) else 0
	opportunity_closed_early_samples += 1 \
		if bool(repeated_read.get("opportunity_closed_early", false)) else 0
	var decision_made := int(shadow_decision.get("selected_player_id", -1)) >= 0
	shadow_decision_samples += 1 if decision_made else 0
	shadow_decision_conflict_samples += 1 \
		if bool(shadow_decision.get("conflict", false)) else 0
	var contact_result: Dictionary = shadow_decision.get("contact_result", {})
	shadow_contact_success_samples += 1 \
		if bool(contact_result.get("success", false)) else 0
	shadow_decision_legacy_agreement_samples += 1 \
		if decision_made and int(shadow_decision.get("selected_player_id", -1)) \
			== int(summary.get("legacy_claimant_id", -2)) else 0
	if decision_made:
		var action_name := str(shadow_decision.get("selected_action", "no_action"))
		shadow_action_choices[action_name] = int(
			shadow_action_choices.get(action_name, 0)
		) + 1
	var outgoing_available := bool(outgoing_candidate.get("available", false))
	outgoing_flight_samples += 1 if outgoing_available else 0
	var outgoing_continuity: Dictionary = outgoing_candidate.get("continuity", {})
	outgoing_continuity_valid_samples += 1 \
		if outgoing_available and bool(outgoing_continuity.get("valid", false)) else 0
	var outgoing_flight: Dictionary = outgoing_candidate.get("flight", {})
	var outgoing_signature: Dictionary = outgoing_flight.get("signature", {})
	if outgoing_available:
		_append_metric(
			"outgoing_flight_speed_mps", outgoing_signature.get("speed_mps", 0.0)
		)
		_append_metric(
			"outgoing_flight_duration_seconds", outgoing_flight.get("duration", 0.0)
		)
		_append_metric(
			"outgoing_flight_stability",
			outgoing_signature.get("flight_stability", 0.0),
		)
		_append_metric(
			"outgoing_flight_topspin_rps", outgoing_signature.get("topspin_rps", 0.0)
		)
		_append_metric(
			"outgoing_flight_sidespin_rps", outgoing_signature.get("sidespin_rps", 0.0)
		)
		_append_metric(
			"outgoing_speed_duration_relative_error",
			outgoing_continuity.get("speed_duration_relative_error", 0.0),
		)
	var setter_available := bool(setter_response.get("available", false))
	setter_response_samples += 1 if setter_available else 0
	setter_reachable_samples += 1 \
		if setter_available and bool(setter_response.get("selected_reachable", false)) else 0
	setter_preferred_samples += 1 \
		if setter_available and bool(setter_response.get("selected_is_preferred", false)) else 0
	if setter_available:
		var failure_classification: Dictionary = setter_response.get(
			"selected_failure_classification", {}
		)
		var failure_cause := str(failure_classification.get(
			"primary_cause", "unclassified"
		))
		setter_failure_causes[failure_cause] = int(
			setter_failure_causes.get(failure_cause, 0)
		) + 1
		_append_metric("setter_candidate_count", setter_response.get("candidate_count", 0))
		_append_metric("setter_action_count", setter_response.get("selected_action_count", 0))
		_append_metric("setter_read_confidence", setter_response.get("selected_confidence", 0.0))
		_append_metric("setter_window_duration_seconds", setter_response.get("selected_window_duration_seconds", 0.0))
		_append_metric("setter_projected_distance_meters", setter_response.get("selected_projected_distance_meters", 0.0))
		_append_metric("setter_true_arrival_margin_seconds", setter_response.get("selected_true_arrival_margin", 0.0))
		_append_metric("setter_initial_true_distance_meters", setter_response.get("selected_initial_distance_meters", 0.0))
		_append_metric("setter_final_available_time_seconds", setter_response.get("selected_final_available_time_seconds", 0.0))
		_append_metric("setter_final_target_distance_meters", setter_response.get("selected_final_target_distance_meters", 0.0))
		_append_metric("setter_final_movement_capacity_meters", setter_response.get("selected_final_movement_capacity_meters", 0.0))
		_append_metric("setter_final_center_distance_deficit_meters", setter_response.get("selected_final_center_distance_deficit_meters", 0.0))
		_append_metric("setter_contact_reach_meters", setter_response.get("selected_contact_reach_meters", 0.0))
		_append_metric("setter_directional_velocity_overcredit_mps", setter_response.get("selected_directional_velocity_overcredit_mps", 0.0))
	var playback_available := bool(playback_candidate.get("available", false))
	playback_candidate_samples += 1 if playback_available else 0
	playback_contract_valid_samples += 1 \
		if playback_available and bool(playback_candidate.get(
			"trajectory_contract_valid", false
		)) and not bool(playback_candidate.get(
			"official_events_mutated", true
		)) else 0
	if playback_available:
		_append_metric(
			"shadow_playback_event_count",
			playback_candidate.get("event_count", 0),
		)
	var comparison_available := bool(serve_to_set.get("available", false))
	serve_to_set_comparison_samples += 1 if comparison_available else 0
	official_serve_to_set_complete_samples += 1 \
		if comparison_available and bool(serve_to_set.get(
			"official_path_complete", false
		)) else 0
	serve_to_set_receiver_agreement_samples += 1 \
		if comparison_available and bool(serve_to_set.get(
			"receiver_agreement", false
		)) else 0
	serve_to_set_setter_agreement_samples += 1 \
		if comparison_available and bool(serve_to_set.get(
			"setter_agreement", false
		)) else 0
	if comparison_available:
		var destination_delta := float(serve_to_set.get(
			"pass_destination_delta_meters", -1.0
		))
		if destination_delta >= 0.0:
			_append_metric(
				"serve_to_set_pass_destination_delta_meters", destination_delta
			)
		_append_metric(
			"serve_to_set_pass_duration_delta_seconds",
			serve_to_set.get("pass_duration_delta_seconds", 0.0),
		)
		_append_metric(
			"serve_to_set_shadow_action_count",
			serve_to_set.get("shadow_set_action_count", 0),
		)
	var rollout_available := not rollout.is_empty()
	rollout_status_samples += 1 if rollout_available else 0
	rollout_official_source_samples += 1 \
		if rollout_available and str(rollout.get(
			"selected_source", ""
		)) == "official" else 0
	rollout_flag_enabled_samples += 1 \
		if rollout_available and bool(rollout.get("flag_enabled", false)) else 0
	rollout_identity_preserved_samples += 1 \
		if rollout_available and bool(rollout.get(
			"official_identity_preserved", false
		)) else 0
	rollout_candidate_eligible_samples += 1 \
		if rollout_available and bool(Dictionary(rollout.get(
			"candidate_audit", {}
		)).get("eligible", false)) else 0
	_append_metric("serve_speed_mps", timing.get("signature_speed_mps", 0.0))
	_append_metric("recorded_duration_seconds", timing.get("recorded_duration_seconds", 0.0))
	_append_metric("implied_duration_seconds", timing.get("implied_duration_seconds", 0.0))
	_append_metric("effective_recorded_speed_mps", timing.get("effective_recorded_speed_mps", 0.0))
	_append_metric("relative_duration_error", timing.get("relative_duration_error", 0.0))
	_append_metric("derived_speed_mps", derived_speed.get("speed_mps", 0.0))
	_append_metric(
		"derived_speed_arrival_margin_seconds",
		derived_speed.get("selected_arrival_margin", 0.0),
	)
	_append_metric(
		"derived_speed_destination_error_meters",
		derived_speed.get("selected_destination_error_meters", 0.0),
	)
	var flight_start := float(summary.get("flight_start_time", 0.0))
	var independent_recognition_delay := float(
		independent_speed.get("selected_recognition_time", flight_start)
	) - flight_start
	var derived_recognition_delay := float(
		derived_speed.get("selected_recognition_time", flight_start)
	) - flight_start
	_append_metric(
		"derived_speed_recognition_delay_seconds", derived_recognition_delay
	)
	_append_metric(
		"derived_speed_destination_error_delta_meters",
		float(derived_speed.get("selected_destination_error_meters", 0.0))
			- float(independent_speed.get("selected_destination_error_meters", 0.0)),
	)
	_append_metric(
		"derived_speed_recognition_delay_delta_seconds",
		derived_recognition_delay - independent_recognition_delay,
	)
	_append_metric(
		"repeated_read_destination_error_meters",
		repeated_read.get("selected_destination_error_meters", 0.0),
	)
	_append_metric(
		"repeated_read_destination_error_delta_meters",
		float(repeated_read.get("selected_destination_error_meters", 0.0))
			- float(single_read.get("selected_destination_error_meters", 0.0)),
	)
	_append_metric(
		"repeated_read_confidence", repeated_read.get("selected_confidence", 0.0)
	)
	_append_metric(
		"repeated_read_confidence_delta",
		float(repeated_read.get("selected_confidence", 0.0))
			- float(single_read.get("selected_confidence", 0.0)),
	)
	_append_metric(
		"repeated_read_arrival_margin_seconds",
		repeated_read.get("selected_arrival_margin", 0.0),
	)
	_append_metric(
		"receiver_true_arrival_margin_seconds",
		repeated_read.get("selected_true_arrival_margin", 0.0),
	)
	_append_metric(
		"repeated_read_total_correction_distance_meters",
		repeated_read.get("total_correction_distance_meters", 0.0),
	)
	_append_metric(
		"repeated_read_final_correction_distance_meters",
		repeated_read.get("final_correction_distance_meters", 0.0),
	)
	_append_metric(
		"repeated_read_projected_distance_meters",
		repeated_read.get("projected_distance_meters", 0.0),
	)
	_append_metric(
		"repeated_read_arrival_margin_gain_vs_stationary_seconds",
		float(repeated_read.get("selected_arrival_margin", 0.0))
			- float(repeated_read.get("stationary_selected_arrival_margin", 0.0)),
	)
	_append_metric(
		"receiver_initial_true_distance_meters",
		repeated_read.get("initial_true_distance_meters", 0.0),
	)
	_append_metric(
		"receiver_first_decision_delay_seconds",
		repeated_read.get("first_decision_delay_seconds", 0.0),
	)
	_append_metric(
		"receiver_time_remaining_after_first_decision_seconds",
		repeated_read.get("time_remaining_after_first_decision_seconds", 0.0),
	)
	_append_metric(
		"receiver_final_available_time_seconds",
		repeated_read.get("final_available_time_seconds", 0.0),
	)
	_append_metric(
		"receiver_final_target_distance_meters",
		repeated_read.get("final_target_distance_meters", 0.0),
	)
	_append_metric(
		"receiver_final_movement_capacity_meters",
		repeated_read.get("final_movement_capacity_meters", 0.0),
	)
	_append_metric(
		"receiver_final_center_distance_deficit_meters",
		repeated_read.get("final_center_distance_deficit_meters", 0.0),
	)
	_append_metric(
		"receiver_contact_reach_meters",
		repeated_read.get("contact_reach_meters", 0.0),
	)
	_append_metric(
		"receiver_directional_velocity_overcredit_mps",
		repeated_read.get("directional_velocity_overcredit_mps", 0.0),
	)
	_append_metric(
		"opportunity_window_count",
		repeated_read.get("opportunity_window_count", 0),
	)
	_append_metric(
		"opportunity_open_duration_seconds",
		repeated_read.get("opportunity_open_duration_seconds", 0.0),
	)
	_append_metric(
		"scheduled_intent_change_count",
		repeated_read.get("intent_change_count", 0),
	)
	_append_metric(
		"shadow_decision_option_count", shadow_decision.get("option_count", 0)
	)
	_append_metric(
		"shadow_decision_ambiguity", shadow_decision.get("ambiguity", 0.0)
	)
	_append_metric(
		"shadow_contact_quality", contact_result.get("quality", 0.0)
	)
	var selected_contact_option_count := 0
	for raw_option in shadow_decision.get("options", []):
		var decision_option: Dictionary = raw_option
		if int(decision_option.get("player_id", -1)) \
				== int(shadow_decision.get("selected_player_id", -2)):
			selected_contact_option_count = Array(
				decision_option.get("contact_options", [])
			).size()
			break
	_append_metric(
		"selected_contact_option_count", selected_contact_option_count
	)

	var selected := _selected_entry(entries)
	if not selected.is_empty():
		reachable_shadow_samples += 1 if bool(selected.get("reachable", false)) else 0
		_append_metric(
			"recognition_delay_seconds",
			float(selected.get("recognition_time", 0.0))
				- float(summary.get("flight_start_time", 0.0)),
		)
		_append_metric("destination_error_meters", selected.get("destination_error_meters", 0.0))
		_append_metric("arrival_margin_seconds", selected.get("arrival_margin", 0.0))
	_append_metric(
		"signature_arrival_margin_seconds",
		signature_candidate.get("selected_arrival_margin", 0.0),
	)
	_append_metric(
		"candidate_arrival_margin_delta_seconds",
		float(signature_candidate.get("selected_arrival_margin", 0.0))
			- float(legacy_candidate.get("selected_arrival_margin", 0.0)),
	)

	var signature: Dictionary = summary.get("signature", {})
	var style := str(signature.get("action_type", "unknown"))
	if not styles.has(style):
		styles[style] = {
			"samples": 0, "agreements": 0, "reachable": 0,
			"timing_consistent": 0, "signature_reachable": 0,
			"candidate_changed": 0,
			"recorded_durations": [], "implied_durations": [],
			"serve_speeds": [], "legacy_arrival_margins": [],
			"signature_arrival_margins": [],
			"derived_speeds": [], "derived_reachable": 0,
			"derived_candidate_changed": 0,
			"derived_destination_errors": [],
			"derived_recognition_delays": [],
			"repeated_reachable": 0, "repeated_candidate_changed": 0,
			"repeated_destination_errors": [],
			"repeated_confidences": [], "repeated_corrections": [],
		}
	styles[style]["samples"] += 1
	styles[style]["agreements"] += 1 if bool(summary.get("agreement", false)) else 0
	styles[style]["reachable"] += 1 if bool(selected.get("reachable", false)) else 0
	styles[style]["timing_consistent"] += 1 \
		if bool(timing.get("within_tolerance", false)) else 0
	styles[style]["signature_reachable"] += 1 \
		if bool(signature_candidate.get("selected_reachable", false)) else 0
	styles[style]["candidate_changed"] += 1 \
		if bool(candidates.get("claimant_changed", false)) else 0
	styles[style]["recorded_durations"].append(float(
		timing.get("recorded_duration_seconds", 0.0)
	))
	styles[style]["implied_durations"].append(float(
		timing.get("implied_duration_seconds", 0.0)
	))
	styles[style]["serve_speeds"].append(float(
		timing.get("signature_speed_mps", 0.0)
	))
	styles[style]["legacy_arrival_margins"].append(float(
		legacy_candidate.get("selected_arrival_margin", 0.0)
	))
	styles[style]["signature_arrival_margins"].append(float(
		signature_candidate.get("selected_arrival_margin", 0.0)
	))
	styles[style]["derived_speeds"].append(float(
		derived_speed.get("speed_mps", 0.0)
	))
	styles[style]["derived_reachable"] += 1 \
		if bool(derived_speed.get("selected_reachable", false)) else 0
	styles[style]["derived_candidate_changed"] += 1 \
		if bool(speed_candidates.get("claimant_changed", false)) else 0
	styles[style]["derived_destination_errors"].append(float(
		derived_speed.get("selected_destination_error_meters", 0.0)
	))
	styles[style]["derived_recognition_delays"].append(
		derived_recognition_delay
	)
	styles[style]["repeated_reachable"] += 1 \
		if bool(repeated_read.get("selected_reachable", false)) else 0
	styles[style]["repeated_candidate_changed"] += 1 \
		if bool(perception_candidates.get("claimant_changed", false)) else 0
	styles[style]["repeated_destination_errors"].append(float(
		repeated_read.get("selected_destination_error_meters", 0.0)
	))
	styles[style]["repeated_confidences"].append(float(
		repeated_read.get("selected_confidence", 0.0)
	))
	styles[style]["repeated_corrections"].append(float(
		repeated_read.get("total_correction_distance_meters", 0.0)
	))


func build_summary() -> Dictionary:
	var distributions := {}
	for metric_name in metrics:
		distributions[metric_name] = _distribution(metrics[metric_name])
	var style_summary := {}
	for style in styles:
		var raw: Dictionary = styles[style]
		var count := maxi(int(raw.get("samples", 0)), 1)
		style_summary[style] = {
			"samples": int(raw.get("samples", 0)),
			"agreement_rate": float(raw.get("agreements", 0)) / float(count),
			"shadow_reachable_rate": float(raw.get("reachable", 0)) / float(count),
			"timing_consistency_rate": float(raw.get("timing_consistent", 0)) / float(count),
			"signature_duration_reachable_rate": float(
				raw.get("signature_reachable", 0)
			) / float(count),
			"timing_candidate_claimant_change_rate": float(
				raw.get("candidate_changed", 0)
			) / float(count),
			"recorded_duration_seconds": _distribution(
				raw.get("recorded_durations", [])
			),
			"implied_duration_seconds": _distribution(
				raw.get("implied_durations", [])
			),
			"serve_speed_mps": _distribution(raw.get("serve_speeds", [])),
			"legacy_arrival_margin_seconds": _distribution(
				raw.get("legacy_arrival_margins", [])
			),
			"signature_arrival_margin_seconds": _distribution(
				raw.get("signature_arrival_margins", [])
			),
			"derived_speed_mps": _distribution(raw.get("derived_speeds", [])),
			"derived_speed_reachable_rate": float(
				raw.get("derived_reachable", 0)
			) / float(count),
			"derived_speed_claimant_change_rate": float(
				raw.get("derived_candidate_changed", 0)
			) / float(count),
			"derived_speed_destination_error_meters": _distribution(
				raw.get("derived_destination_errors", [])
			),
			"derived_speed_recognition_delay_seconds": _distribution(
				raw.get("derived_recognition_delays", [])
			),
			"repeated_read_reachable_rate": float(
				raw.get("repeated_reachable", 0)
			) / float(count),
			"repeated_read_claimant_change_rate": float(
				raw.get("repeated_candidate_changed", 0)
			) / float(count),
			"repeated_read_destination_error_meters": _distribution(
				raw.get("repeated_destination_errors", [])
			),
			"repeated_read_confidence": _distribution(
				raw.get("repeated_confidences", [])
			),
			"repeated_read_total_correction_distance_meters": _distribution(
				raw.get("repeated_corrections", [])
			),
		}
	var denominator := maxf(float(available_samples), 1.0)
	var decision_denominator := maxf(float(shadow_decision_samples), 1.0)
	var outgoing_denominator := maxf(float(outgoing_flight_samples), 1.0)
	var setter_denominator := maxf(float(setter_response_samples), 1.0)
	var playback_denominator := maxf(float(playback_candidate_samples), 1.0)
	var comparison_denominator := maxf(
		float(serve_to_set_comparison_samples), 1.0
	)
	var rollout_denominator := maxf(float(rollout_status_samples), 1.0)
	var warnings: Array[String] = []
	var observations: Array[String] = []
	if invalid_samples > 0:
		warnings.append("Some eligible receptions produced incomplete shadow timing evidence.")
	if available_samples > 0 and float(
		canonical_timing_consistent_samples
	) / denominator < 1.0:
		warnings.append("Canonical calculated-speed flights contain inconsistent durations.")
	if available_samples > 0 and float(
		legacy_timing_consistent_samples
	) / denominator < 0.80:
		observations.append(
			"Legacy official serve duration differs from calculated-speed timing in more than 20% of samples."
		)
	if available_samples > 0 and float(reachable_shadow_samples) / denominator < 0.50:
		warnings.append("The shadow-selected receiver is late in more than half of measured serves.")
	if styles.size() < 2:
		warnings.append("The batch covers fewer than two serve styles; style comparisons are not yet supported.")
	var reach_counterfactuals := {
		"contact_reach_meters": [0.0, 0.30, 0.60, 0.90, 1.20],
		"time_buffer_seconds": [0.0, 0.05, 0.10, 0.15, 0.20],
		"receiver_contact_reach_rates": _deficit_threshold_rates(
			metrics.get("receiver_final_center_distance_deficit_meters", []),
			[0.0, 0.30, 0.60, 0.90, 1.20],
		),
		"setter_contact_reach_rates": _deficit_threshold_rates(
			metrics.get("setter_final_center_distance_deficit_meters", []),
			[0.0, 0.30, 0.60, 0.90, 1.20],
		),
		"receiver_time_buffer_rates": _margin_buffer_rates(
			metrics.get("receiver_true_arrival_margin_seconds", []),
			[0.0, 0.05, 0.10, 0.15, 0.20],
		),
		"setter_time_buffer_rates": _margin_buffer_rates(
			metrics.get("setter_true_arrival_margin_seconds", []),
			[0.0, 0.05, 0.10, 0.15, 0.20],
		),
	}
	return {
		"gate": gate_name,
		"shadow_only": true,
		"requested_samples": requested_samples,
		"available_samples": available_samples,
		"skipped_samples": skipped_samples,
		"invalid_samples": invalid_samples,
		"claimant_agreement_rate": float(agreement_samples) / denominator,
		"canonical_calculated_speed_rate": float(
			canonical_calculated_speed_samples
		) / denominator,
		"shadow_reachable_rate": float(reachable_shadow_samples) / denominator,
		"signature_duration_reachable_rate": float(
			signature_reachable_samples
		) / denominator,
		"timing_candidate_claimant_change_rate": float(
			timing_candidate_changed_samples
		) / denominator,
		"derived_speed_reachable_rate": float(
			derived_speed_reachable_samples
		) / denominator,
		"derived_speed_claimant_change_rate": float(
			derived_speed_candidate_changed_samples
		) / denominator,
		"repeated_read_reachable_rate": float(
			repeated_read_reachable_samples
		) / denominator,
		"repeated_read_claimant_change_rate": float(
			repeated_read_candidate_changed_samples
		) / denominator,
		"stationary_repeated_read_reachable_rate": float(
			stationary_repeated_read_reachable_samples
		) / denominator,
		"scheduled_opportunity_rate": float(
			scheduled_opportunity_samples
		) / denominator,
		"opportunity_closed_early_rate": float(
			opportunity_closed_early_samples
		) / denominator,
		"shadow_decision_rate": float(shadow_decision_samples) / denominator,
		"shadow_decision_conflict_rate": float(
			shadow_decision_conflict_samples
		) / denominator,
		"shadow_contact_success_rate": float(
			shadow_contact_success_samples
		) / denominator,
		"shadow_contact_success_given_decision_rate": float(
			shadow_contact_success_samples
		) / decision_denominator,
		"shadow_decision_legacy_agreement_rate": float(
			shadow_decision_legacy_agreement_samples
		) / denominator,
		"shadow_decision_legacy_agreement_given_decision_rate": float(
			shadow_decision_legacy_agreement_samples
		) / decision_denominator,
		"shadow_action_choices": shadow_action_choices.duplicate(true),
		"outgoing_flight_candidate_rate": float(
			outgoing_flight_samples
		) / denominator,
		"outgoing_continuity_valid_rate": float(
			outgoing_continuity_valid_samples
		) / outgoing_denominator,
		"setter_response_rate": float(setter_response_samples) / denominator,
		"setter_reachable_given_response_rate": float(
			setter_reachable_samples
		) / setter_denominator,
		"preferred_setter_selected_rate": float(
			setter_preferred_samples
		) / setter_denominator,
		"setter_failure_causes": setter_failure_causes.duplicate(true),
		"shadow_playback_candidate_rate": float(
			playback_candidate_samples
		) / denominator,
		"shadow_playback_contract_valid_rate": float(
			playback_contract_valid_samples
		) / playback_denominator,
		"serve_to_set_comparison_rate": float(
			serve_to_set_comparison_samples
		) / denominator,
		"official_serve_to_set_complete_given_comparison_rate": float(
			official_serve_to_set_complete_samples
		) / comparison_denominator,
		"serve_to_set_receiver_agreement_rate": float(
			serve_to_set_receiver_agreement_samples
		) / comparison_denominator,
		"serve_to_set_setter_agreement_rate": float(
			serve_to_set_setter_agreement_samples
		) / comparison_denominator,
		"rollout_status_rate": float(rollout_status_samples) / denominator,
		"rollout_official_source_rate": float(
			rollout_official_source_samples
		) / rollout_denominator,
		"rollout_flag_enabled_rate": float(
			rollout_flag_enabled_samples
		) / rollout_denominator,
		"rollout_official_identity_preserved_rate": float(
			rollout_identity_preserved_samples
		) / rollout_denominator,
		"rollout_candidate_eligible_rate": float(
			rollout_candidate_eligible_samples
		) / rollout_denominator,
		"canonical_timing_consistency_rate": float(
			canonical_timing_consistent_samples
		) / denominator,
		"legacy_timing_consistency_rate": float(
			legacy_timing_consistent_samples
		) / denominator,
		"distributions": distributions,
		"by_serve_style": style_summary,
		"warnings": warnings,
		"observations": observations,
		"reach_counterfactuals": reach_counterfactuals,
	}


func _append_metric(metric_name: String, raw_value: Variant) -> void:
	var value := float(raw_value)
	if is_finite(value):
		metrics[metric_name].append(value)


func _selected_entry(entries: Array) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if bool(entry.get("shadow_selected", false)):
			return entry
	return {}


func _distribution(raw_values: Array) -> Dictionary:
	if raw_values.is_empty():
		return {"count": 0}
	var values := raw_values.duplicate()
	values.sort()
	var total := 0.0
	for raw_value in values:
		total += float(raw_value)
	return {
		"count": values.size(),
		"minimum": float(values[0]),
		"mean": total / float(values.size()),
		"p10": _percentile(values, 0.10),
		"p50": _percentile(values, 0.50),
		"p90": _percentile(values, 0.90),
		"maximum": float(values[-1]),
	}


static func _deficit_threshold_rates(
	values: Array,
	thresholds: Array,
) -> Dictionary:
	var result := {}
	var denominator := maxf(float(values.size()), 1.0)
	for raw_threshold in thresholds:
		var threshold := float(raw_threshold)
		var count := 0
		for raw_value in values:
			count += 1 if float(raw_value) <= threshold + 0.0001 else 0
		result["%.2f" % threshold] = float(count) / denominator
	return result


static func _margin_buffer_rates(
	values: Array,
	buffers: Array,
) -> Dictionary:
	var result := {}
	var denominator := maxf(float(values.size()), 1.0)
	for raw_buffer in buffers:
		var buffer := float(raw_buffer)
		var count := 0
		for raw_value in values:
			count += 1 if float(raw_value) + buffer >= 0.0 else 0
		result["%.2f" % buffer] = float(count) / denominator
	return result


func _percentile(sorted_values: Array, ratio: float) -> float:
	var index := clampi(
		roundi(clampf(ratio, 0.0, 1.0) * float(sorted_values.size() - 1)),
		0,
		sorted_values.size() - 1,
	)
	return float(sorted_values[index])
