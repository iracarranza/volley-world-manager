extends SceneTree

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const CalibrationReportModel := preload("res://scripts/simulation/rally_calibration_report.gd")
const ServeStyleCalibrationModel := preload("res://scripts/simulation/serve_style_calibration.gd")
const ReceptionProgressionCalibrationModel := preload("res://scripts/simulation/reception_progression_calibration.gd")
const ReceptionDecisionProgressionModel := preload("res://scripts/simulation/reception_decision_progression_calibration.gd")
const SetterHandoffCalibrationModel := preload("res://scripts/simulation/setter_handoff_calibration.gd")
const SetterProgressionCalibrationModel := preload("res://scripts/simulation/setter_progression_calibration.gd")
const ReceptionRolloutCalibrationModel := preload(
	"res://scripts/simulation/reception_rollout_calibration.gd"
)
const SetterRolloutCalibrationModel := preload(
	"res://scripts/simulation/setter_rollout_calibration.gd"
)


func _initialize() -> void:
	var sample_count := 300
	var start_seed := 1000
	var all_serve_styles := false
	var derived_speed_gate := false
	var reader_formations := false
	var canonical_shadow := false
	var repeated_reads := false
	var projected_movement := false
	var opportunity_windows := false
	var shadow_decisions := false
	var decision_progression := false
	var outgoing_flight := false
	var setter_response := false
	var summary_only := false
	var playback_adapter := false
	var serve_to_set := false
	var disabled_rollout := false
	var setter_handoffs := false
	var setter_progression := false
	var live_reception_rollout := false
	var live_setter_rollout := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			sample_count = maxi(int(argument.trim_prefix("--samples=")), 1)
		elif argument.begins_with("--start-seed="):
			start_seed = int(argument.trim_prefix("--start-seed="))
		elif argument == "--all-serve-styles":
			all_serve_styles = true
		elif argument == "--derived-speed":
			derived_speed_gate = true
		elif argument == "--reader-formations":
			reader_formations = true
		elif argument == "--canonical-shadow":
			canonical_shadow = true
		elif argument == "--repeated-reads":
			repeated_reads = true
		elif argument == "--projected-movement":
			projected_movement = true
		elif argument == "--opportunity-windows":
			opportunity_windows = true
		elif argument == "--shadow-decisions":
			shadow_decisions = true
		elif argument == "--decision-progression":
			decision_progression = true
		elif argument == "--outgoing-flight":
			outgoing_flight = true
		elif argument == "--setter-response":
			setter_response = true
		elif argument == "--summary-only":
			summary_only = true
		elif argument == "--playback-adapter":
			playback_adapter = true
		elif argument == "--serve-to-set":
			serve_to_set = true
		elif argument == "--disabled-rollout":
			disabled_rollout = true
		elif argument == "--setter-handoffs":
			setter_handoffs = true
		elif argument == "--setter-progression":
			setter_progression = true
		elif argument == "--live-reception-rollout":
			live_reception_rollout = true
		elif argument == "--live-setter-rollout":
			live_setter_rollout = true

	if live_setter_rollout:
		print(JSON.stringify(SetterRolloutCalibrationModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if live_reception_rollout:
		print(JSON.stringify(ReceptionRolloutCalibrationModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if setter_progression:
		print(JSON.stringify(SetterProgressionCalibrationModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if setter_handoffs:
		print(JSON.stringify(SetterHandoffCalibrationModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if decision_progression:
		print(JSON.stringify(ReceptionDecisionProgressionModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if reader_formations:
		print(JSON.stringify(ReceptionProgressionCalibrationModel.run(
			sample_count, start_seed
		), "\t"))
		quit(0)
		return

	if all_serve_styles:
		var style_summary := ServeStyleCalibrationModel.run(
			sample_count,
			start_seed,
			("disabled_rollout_gate_15" if disabled_rollout else (
			"serve_to_set_comparison_gate_14" if serve_to_set else (
			"playback_adapter_calibration_gate_13" if playback_adapter else (
			"setter_response_calibration_gate_12" if setter_response else (
			"outgoing_flight_calibration_gate_11" if outgoing_flight else (
			"shadow_decision_calibration_gate_9" if shadow_decisions else (
				"opportunity_window_calibration_gate_8" if opportunity_windows else (
				"projected_movement_calibration_gate_7" if projected_movement else (
				"repeated_read_calibration_gate_6" if repeated_reads else (
				"canonical_shadow_calibration_gate_5" if canonical_shadow else (
				"derived_speed_calibration_gate_3" \
					if derived_speed_gate else "serve_style_calibration_gate_2"
			))))))))))),
		)
		print(JSON.stringify(
			_compact_summary(style_summary) if summary_only else style_summary,
			"\t",
		))
		quit(0)
		return

	var manager := GameManagerModel.new()
	manager.seed_vertical_slice_data()
	var report := CalibrationReportModel.new()
	for offset in range(sample_count):
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(start_seed + offset)
		var trace: Dictionary = result.analysis.get("shadow_reception", {}) \
			if result != null and result.analysis is Dictionary else {}
		report.add_shadow_trace(trace)
	print(JSON.stringify(report.build_summary(), "\t"))
	quit(0)


func _compact_summary(summary: Dictionary) -> Dictionary:
	var result := {}
	for key in [
		"gate", "shadow_only", "requested_samples", "available_samples",
		"skipped_samples", "invalid_samples", "style_coverage_complete",
		"canonical_calculated_speed_rate", "canonical_timing_consistency_rate",
		"legacy_timing_consistency_rate", "observations",
		"outgoing_flight_candidate_rate", "outgoing_continuity_valid_rate",
		"setter_response_rate", "setter_reachable_given_response_rate",
		"preferred_setter_selected_rate", "setter_failure_causes", "warnings",
		"reach_counterfactuals",
		"shadow_playback_candidate_rate", "shadow_playback_contract_valid_rate",
		"serve_to_set_comparison_rate",
		"official_serve_to_set_complete_given_comparison_rate",
		"serve_to_set_receiver_agreement_rate", "serve_to_set_setter_agreement_rate",
		"rollout_status_rate", "rollout_official_source_rate",
		"rollout_flag_enabled_rate", "rollout_official_identity_preserved_rate",
		"rollout_candidate_eligible_rate",
	]:
		if summary.has(key):
			result[key] = summary[key]
	var selected_distributions := {}
	var distributions: Dictionary = summary.get("distributions", {})
	for metric in [
		"outgoing_flight_speed_mps", "outgoing_flight_duration_seconds",
		"outgoing_flight_stability", "outgoing_flight_topspin_rps",
		"outgoing_flight_sidespin_rps",
		"outgoing_speed_duration_relative_error", "setter_candidate_count",
		"setter_action_count", "setter_read_confidence",
		"setter_window_duration_seconds", "setter_projected_distance_meters",
		"setter_true_arrival_margin_seconds",
		"receiver_initial_true_distance_meters",
		"receiver_true_arrival_margin_seconds",
		"receiver_first_decision_delay_seconds",
		"receiver_time_remaining_after_first_decision_seconds",
		"receiver_final_available_time_seconds",
		"receiver_final_target_distance_meters",
		"receiver_final_movement_capacity_meters",
		"receiver_final_center_distance_deficit_meters",
		"receiver_contact_reach_meters",
		"receiver_directional_velocity_overcredit_mps",
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
		if distributions.has(metric):
			selected_distributions[metric] = distributions[metric]
	result["distributions"] = selected_distributions
	return result
