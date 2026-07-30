class_name AttackProgressionCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyStateBuilderModel := preload(
	"res://scripts/simulation/rally_state_builder.gd"
)
const ShadowAttackSystemModel := preload(
	"res://scripts/simulation/shadow_attack_system.gd"
)

const TIERS := {
	"developing": 40,
	"established": 65,
	"elite": 90,
}


static func run(sample_count: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(sample_count, 1)
	var by_tier := {}
	for tier_name in TIERS:
		var bucket := _new_bucket()
		for offset in range(safe_samples):
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			_apply_tier(manager, int(TIERS[tier_name]))
			var lineup: RotationLineup = manager.current_lineup()
			var setter_id := lineup.active_setter_id()
			var state := RallyStateBuilderModel.build(
				manager.players, lineup, manager.current_defensive_plan(),
				manager.opponent_team, manager.called_play(), false,
				start_seed + offset,
			)
			var response := {
				"selected_setter_id": setter_id,
				"candidates": [{
					"player_id": setter_id,
					"resolved_contact_position": Vector2(0.50, 0.60),
					"resolved_contact_time": 1.0,
				}],
			}
			var shadow := ShadowAttackSystemModel.evaluate(
				state, response, -1, start_seed + offset + 370000,
			)
			_add(bucket, shadow)
		by_tier[tier_name] = _summarize(bucket)
	var developing: Dictionary = by_tier.get("developing", {})
	var established: Dictionary = by_tier.get("established", {})
	var elite: Dictionary = by_tier.get("elite", {})
	return {
		"gate": "attack_observation_progression_gate_39",
		"shadow_only": true,
		"sample_count_per_tier": safe_samples,
		"start_seed": start_seed,
		"by_tier": by_tier,
		"progression": {
			"confidence_monotonic": _nondecreasing(
				developing, established, elite, "confidence_mean"
			),
			"perceived_reach_monotonic": _nondecreasing(
				developing, established, elite, "perceived_reachable_rate"
			),
			"true_reach_monotonic": _nondecreasing(
				developing, established, elite, "true_reachable_rate"
			),
			"action_count_monotonic": _nondecreasing(
				developing, established, elite, "action_count_mean"
			),
			"executable_action_monotonic": _nondecreasing(
				developing, established, elite, "executable_action_rate"
			),
		},
		"fixture_valid": int(developing.get("invalid", 1)) == 0 \
			and int(established.get("invalid", 1)) == 0 \
			and int(elite.get("invalid", 1)) == 0,
	}


static func _apply_tier(manager: Node, rating: int) -> void:
	var bounded := clampi(rating, 1, 100)
	var play: OffensivePlay = manager.called_play()
	var hitter_ids := {}
	if play != null:
		for assignment in play.assignments:
			if assignment != null and not assignment.is_decoy:
				hitter_ids[assignment.player_id] = true
	if hitter_ids.is_empty():
		var lineup: RotationLineup = manager.current_lineup()
		for slot in range(1, 7):
			var player_id := lineup.player_at_slot(slot)
			if lineup.is_attack_eligible(player_id):
				hitter_ids[player_id] = true
	for player in manager.players:
		if not hitter_ids.has(player.id):
			continue
		player.anticipation = bounded
		player.court_vision = bounded
		player.decision_making = bounded
		player.composure = bounded
		player.transition_speed = bounded
		player.acceleration = bounded
		player.jump_reach = bounded
		player.explosiveness = bounded
		player.approach_timing = bounded
		player.attack_accuracy = bounded
		player.attack_power = bounded
		player.finesse = bounded
		player.tooling = bounded


static func _new_bucket() -> Dictionary:
	return {
		"requested": 0, "available": 0, "invalid": 0,
		"perceived_reachable": 0, "true_reachable": 0,
		"executable_actions": 0, "confidence_total": 0.0,
		"action_count_total": 0.0,
	}


static func _add(bucket: Dictionary, shadow: Dictionary) -> void:
	bucket["requested"] += 1
	if not bool(shadow.get("available", false)):
		bucket["invalid"] += 1
		return
	var response: Dictionary = shadow.get("hitter_response", {})
	var observation: Dictionary = response.get("observation", {})
	if not bool(response.get("available", false)) or observation.is_empty():
		bucket["invalid"] += 1
		return
	bucket["available"] += 1
	bucket["perceived_reachable"] += 1 if bool(response.get(
		"perceived_reachable", false
	)) else 0
	bucket["true_reachable"] += 1 if bool(response.get(
		"true_reachable", false
	)) else 0
	bucket["executable_actions"] += 1 if not str(response.get(
		"selected_action", ""
	)).is_empty() else 0
	bucket["confidence_total"] += float(observation.get("confidence", 0.0))
	bucket["action_count_total"] += Array(response.get(
		"perceived_actions", []
	)).size()


static func _summarize(bucket: Dictionary) -> Dictionary:
	var available := maxf(float(bucket.get("available", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"confidence_mean": float(bucket.get("confidence_total", 0.0)) / available,
		"perceived_reachable_rate": float(bucket.get(
			"perceived_reachable", 0
		)) / available,
		"true_reachable_rate": float(bucket.get("true_reachable", 0)) / available,
		"executable_action_rate": float(bucket.get(
			"executable_actions", 0
		)) / available,
		"action_count_mean": float(bucket.get("action_count_total", 0.0)) / available,
	}


static func _nondecreasing(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
) -> bool:
	return float(low.get(key, 0.0)) <= float(middle.get(key, 0.0)) \
		and float(middle.get(key, 0.0)) <= float(high.get(key, 0.0))
