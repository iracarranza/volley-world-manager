class_name ReceptionRolloutCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const ReceptionRolloutAuditModel := preload(
	"res://scripts/simulation/reception_rollout_audit.gd"
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
	var legacy_continuations := 0
	for offset in range(safe_samples):
		var seed_value := start_seed + offset
		var official_manager := _manager()
		var official_result: Resource = official_manager.resolve_active_rally(seed_value)
		var official_summary := _summary(official_result)
		var audit := ReceptionRolloutAuditModel.evaluate(
			official_summary, official_manager.current_lineup()
		)
		var expected_promotion := bool(audit.get("eligible", false))
		eligible += 1 if expected_promotion else 0

		var live_manager := _manager()
		var live_result: Resource = live_manager.resolve_active_rally(seed_value, true)
		var live_summary := _summary(live_result)
		var rollout: Dictionary = live_summary.get("reception_rollout", {})
		var was_promoted := str(rollout.get(
			"selected_source", "official"
		)) == "continuous_reception"
		promoted += 1 if was_promoted else 0
		expected_fallbacks += 1 if not expected_promotion and not was_promoted else 0
		unexpected_selections += 1 if was_promoted != expected_promotion else 0
		if not was_promoted:
			continue
		var integration: Dictionary = live_summary.get(
			"live_reception_integration", {}
		)
		integration_failures += 1 if not bool(integration.get(
			"applied", false
		)) else 0
		legacy_continuations += 1 if _has_legacy_home_set(live_result) else 0
		var first_fingerprint := _reception_fingerprint(live_result)
		var repeated_manager := _manager()
		var repeated_result: Resource = repeated_manager.resolve_active_rally(
			seed_value, true
		)
		var repeated_fingerprint := _reception_fingerprint(repeated_result)
		deterministic_mismatches += 1 \
			if first_fingerprint != repeated_fingerprint else 0
	var denominator := maxf(float(safe_samples), 1.0)
	var promoted_denominator := maxf(float(promoted), 1.0)
	return {
		"gate": "development_live_reception_gate_30",
		"development_only": true,
		"sample_count": safe_samples,
		"start_seed": start_seed,
		"candidate_eligible_rate": float(eligible) / denominator,
		"promotion_rate": float(promoted) / denominator,
		"expected_fallback_rate": float(expected_fallbacks) / denominator,
		"unexpected_selection_count": unexpected_selections,
		"integration_failure_count": integration_failures,
		"deterministic_mismatch_count": deterministic_mismatches,
		"legacy_continuation_given_promotion_rate": float(
			legacy_continuations
		) / promoted_denominator,
		"fixture_valid": unexpected_selections == 0 \
			and integration_failures == 0 \
			and deterministic_mismatches == 0,
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


static func _reception_fingerprint(result: Resource) -> String:
	if result == null:
		return "missing"
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null \
				and event.event_type == RallyEventModel.EventType.RECEPTION \
				and str(event.metadata.get("side", "")) == "home":
			return ReceptionRolloutAuditModel.fingerprint(event.to_dict())
	return "missing"


static func _has_legacy_home_set(result: Resource) -> bool:
	if result == null:
		return false
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEventModel.EventType.SET \
				and str(event.metadata.get("side", "")) == "home" \
				and not bool(event.metadata.get("continuous_reception", false)):
			return true
	return false
