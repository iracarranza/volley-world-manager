class_name AttackRolloutCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const AttackRolloutAuditModel := preload(
	"res://scripts/simulation/attack_rollout_audit.gd"
)
const RallyEventModel := preload("res://scripts/models/rally_event.gd")


static func run(sample_count: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(sample_count, 1)
	var shadow_available := 0
	var observation_valid := 0
	var candidate_eligible := 0
	var promoted := 0
	var expected_fallbacks := 0
	var unexpected_selections := 0
	var integration_failures := 0
	var deterministic_mismatches := 0
	var legacy_blocks := 0
	var failure_reasons := {}
	var promoted_seeds: Array[int] = []
	for offset in range(safe_samples):
		var seed_value := start_seed + offset
		var official_manager := _manager()
		var official_result: Resource = official_manager.resolve_active_rally(seed_value)
		var official_summary := _summary(official_result)
		var shadow: Dictionary = official_summary.get("shadow_attack", {})
		shadow_available += 1 if bool(shadow.get("available", false)) else 0
		var official_audit := AttackRolloutAuditModel.evaluate(
			official_summary, official_manager.current_lineup()
		)
		observation_valid += 1 if bool(official_audit.get(
			"observation_boundary_valid", false
		)) else 0

		var live_manager := _manager()
		var live_result: Resource = live_manager.resolve_active_rally(seed_value, true)
		var live_summary := _summary(live_result)
		var rollout: Dictionary = live_summary.get("attack_rollout", {})
		var audit: Dictionary = rollout.get("candidate_audit", {})
		var upstream_live := str(Dictionary(live_summary.get(
			"setter_rollout", {}
		)).get("selected_source", "official")) == "continuous_setter"
		var expected_promotion := upstream_live and bool(audit.get("eligible", false))
		candidate_eligible += 1 if expected_promotion else 0
		for reason in audit.get("failure_reasons", []):
			failure_reasons[str(reason)] = int(failure_reasons.get(
				str(reason), 0
			)) + 1
		var was_promoted := str(rollout.get(
			"selected_source", "official"
		)) == "continuous_attack"
		promoted += 1 if was_promoted else 0
		if was_promoted and promoted_seeds.size() < 12:
			promoted_seeds.append(seed_value)
		expected_fallbacks += 1 if not expected_promotion and not was_promoted else 0
		unexpected_selections += 1 if was_promoted != expected_promotion else 0
		if not was_promoted:
			continue
		var integration: Dictionary = live_summary.get(
			"live_attack_integration", {}
		)
		integration_failures += 1 if not bool(integration.get(
			"applied", false
		)) or int(integration.get("contact_number", 0)) != 3 else 0
		legacy_blocks += 1 if _has_legacy_opponent_block(live_result) else 0
		var first_fingerprint := _attack_fingerprint(live_result)
		var repeated_manager := _manager()
		var repeated_result: Resource = repeated_manager.resolve_active_rally(
			seed_value, true
		)
		deterministic_mismatches += 1 \
			if first_fingerprint != _attack_fingerprint(repeated_result) else 0
	var denominator := maxf(float(safe_samples), 1.0)
	var promoted_denominator := maxf(float(promoted), 1.0)
	return {
		"gate": "development_live_attack_gate_42",
		"development_only": true,
		"sample_count": safe_samples,
		"start_seed": start_seed,
		"shadow_available_rate": float(shadow_available) / denominator,
		"observation_boundary_valid_rate": float(observation_valid) / denominator,
		"candidate_eligible_rate": float(candidate_eligible) / denominator,
		"promotion_rate": float(promoted) / denominator,
		"expected_fallback_rate": float(expected_fallbacks) / denominator,
		"unexpected_selection_count": unexpected_selections,
		"integration_failure_count": integration_failures,
		"deterministic_mismatch_count": deterministic_mismatches,
		"legacy_block_given_promotion_rate": float(legacy_blocks) \
			/ promoted_denominator,
		"audit_failure_reasons": failure_reasons,
		"promoted_seeds": promoted_seeds,
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


static func _attack_fingerprint(result: Resource) -> String:
	if result == null:
		return "missing"
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEventModel.EventType.ATTACK \
				and bool(event.metadata.get("continuous_attack", false)):
			var integration: Dictionary = event.metadata.get(
				"persistent_state_update", {}
			)
			return AttackRolloutAuditModel.fingerprint({
				"actor_id": event.actor_id,
				"selected_action": event.metadata.get("attack_type", ""),
				"contact_position": event.start_position,
				"contact_time": event.metadata.get("event_time", 0.0),
				"target": event.end_position,
				"center_position": integration.get(
					"hitter_center_position", Vector2.ZERO
				),
				"observation_fingerprint": integration.get(
					"observation_fingerprint", ""
				),
			})
	return "missing"


static func _has_legacy_opponent_block(result: Resource) -> bool:
	if result == null:
		return false
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEventModel.EventType.BLOCK \
				and str(event.metadata.get("side", "")) == "opponent":
			return true
	return false
