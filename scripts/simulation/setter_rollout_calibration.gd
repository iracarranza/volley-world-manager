class_name SetterRolloutCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const ReceptionRolloutAuditModel := preload(
	"res://scripts/simulation/reception_rollout_audit.gd"
)
const SetterRolloutAuditModel := preload(
	"res://scripts/simulation/setter_rollout_audit.gd"
)
const RallyEventModel := preload("res://scripts/models/rally_event.gd")


static func run(sample_count: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(sample_count, 1)
	var eligible := 0
	var promoted := 0
	var expected_fallbacks := 0
	var unexpected_selections := 0
	var integration_failures := 0
	var deterministic_mismatches := 0
	var legacy_attacks := 0
	var observation_boundary_failures := 0
	var observed_setter_responses := 0
	var audit_failure_reasons := {}
	for offset in range(safe_samples):
		var seed_value := start_seed + offset
		var official_manager := _manager()
		var official_result: Resource = official_manager.resolve_active_rally(seed_value)
		var official_summary := _summary(official_result)
		var reception_audit := ReceptionRolloutAuditModel.evaluate(
			official_summary, official_manager.current_lineup()
		)
		var setter_audit := SetterRolloutAuditModel.evaluate(
			official_summary, official_manager.current_lineup()
		)
		var response_available := bool(Dictionary(official_summary.get(
			"shadow_setter_response", {}
		)).get("available", false))
		observed_setter_responses += 1 if response_available else 0
		observation_boundary_failures += 1 \
			if response_available and not bool(setter_audit.get(
				"observation_boundary_valid", false
			)) else 0
		for reason in setter_audit.get("failure_reasons", []):
			audit_failure_reasons[str(reason)] = int(audit_failure_reasons.get(
				str(reason), 0
			)) + 1
		var expected_promotion := bool(reception_audit.get("eligible", false)) \
			and bool(setter_audit.get("eligible", false))
		eligible += 1 if expected_promotion else 0

		var live_manager := _manager()
		var live_result: Resource = live_manager.resolve_active_rally(seed_value, true)
		var live_summary := _summary(live_result)
		var rollout: Dictionary = live_summary.get("setter_rollout", {})
		var was_promoted := str(rollout.get(
			"selected_source", "official"
		)) == "continuous_setter"
		promoted += 1 if was_promoted else 0
		expected_fallbacks += 1 if not expected_promotion and not was_promoted else 0
		unexpected_selections += 1 if was_promoted != expected_promotion else 0
		if not was_promoted:
			continue
		var integration: Dictionary = live_summary.get(
			"live_setter_integration", {}
		)
		integration_failures += 1 if not bool(integration.get(
			"applied", false
		)) or int(integration.get("contact_number", 0)) != 2 \
			or not bool(Dictionary(integration.get(
				"outgoing_set_state", {}
			)).get("applied", false)) else 0
		legacy_attacks += 1 if _has_legacy_home_attack(live_result) else 0
		var first_fingerprint := _setter_fingerprint(live_result)
		var repeated_manager := _manager()
		var repeated_result: Resource = repeated_manager.resolve_active_rally(
			seed_value, true
		)
		deterministic_mismatches += 1 \
			if first_fingerprint != _setter_fingerprint(repeated_result) else 0
	var denominator := maxf(float(safe_samples), 1.0)
	var promoted_denominator := maxf(float(promoted), 1.0)
	return {
		"gate": "development_live_setter_gate_36",
		"development_only": true,
		"sample_count": safe_samples,
		"start_seed": start_seed,
		"candidate_eligible_rate": float(eligible) / denominator,
		"promotion_rate": float(promoted) / denominator,
		"expected_fallback_rate": float(expected_fallbacks) / denominator,
		"unexpected_selection_count": unexpected_selections,
		"integration_failure_count": integration_failures,
		"deterministic_mismatch_count": deterministic_mismatches,
		"observation_boundary_failure_count": observation_boundary_failures,
		"observed_setter_response_count": observed_setter_responses,
		"audit_failure_reasons": audit_failure_reasons,
		"legacy_attack_given_promotion_rate": float(legacy_attacks) \
			/ promoted_denominator,
		"fixture_valid": unexpected_selections == 0 \
			and integration_failures == 0 \
			and deterministic_mismatches == 0 \
			and observation_boundary_failures == 0,
	}


static func _manager() -> Node:
	var manager := GameManagerModel.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	return manager


static func _summary(result: Resource) -> Dictionary:
	if result == null or not (result.analysis is Dictionary):
		return {}
	var trace: Dictionary = result.analysis.get("shadow_reception", {})
	return trace.get("summary", {})


static func _setter_fingerprint(result: Resource) -> String:
	if result == null:
		return "missing"
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEventModel.EventType.SET \
				and str(event.metadata.get("side", "")) == "home" \
				and bool(event.metadata.get("continuous_setter", false)):
			return SetterRolloutAuditModel.fingerprint({
				"actor_id": event.actor_id,
				"selected_action": str(event.metadata.get("setter_action", "")),
				"contact_position": event.start_position,
				"contact_time": float(event.metadata.get("event_time", 0.0)),
				"center_position": Dictionary(event.metadata.get(
					"persistent_state_update", {}
				)).get("setter_center_position", Vector2.ZERO),
				"observation_fingerprint": Dictionary(event.metadata.get(
					"persistent_state_update", {}
				)).get("observation_fingerprint", ""),
			})
	return "missing"


static func _has_legacy_home_attack(result: Resource) -> bool:
	if result == null:
		return false
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEventModel.EventType.ATTACK \
				and str(event.metadata.get("side", "")) == "home":
			return true
	return false
