extends SceneTree

## Which seeds promote both a live attack and a live block?
##
##     godot --headless --path . --script res://tools/run_live_promotion_scan.gd
##
## Gates 42 and 49 pin a seed that happens to produce an audited continuous
## contact, and that property is downstream of everything -- the passer
## assignment, the set's landing point, the setter's option decision, the
## opponent's attributes. It has now been re-selected four times, each time by
## hand.
##
## This is that search in one command. It prints several qualifying seeds rather
## than the first, so the replacement is a choice from a population instead of a
## coincidence of one.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
func _initialize() -> void:
	var hits := []
	for seed_value in range(300000, 300400):
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(seed_value, true)
		var summary: Dictionary = Dictionary(
			result.analysis.get("shadow_reception", {})).get("summary", {})
		var attack_rollout: Dictionary = summary.get("attack_rollout", {})
		var attack_integration: Dictionary = summary.get("live_attack_integration", {})
		var block_rollout: Dictionary = summary.get("block_rollout", {})
		var block_integration: Dictionary = summary.get("live_block_integration", {})
		var live_attack := false
		var promoted_block := false
		for raw in result.events:
			var e: Resource = raw
			if int(e.event_type) == RallyEventScript.EventType.ATTACK \
					and bool(e.metadata.get("continuous_attack", false)):
				live_attack = true
			if int(e.event_type) == RallyEventScript.EventType.BLOCK \
					and bool(e.metadata.get("continuous_block", false)):
				promoted_block = true
		var attack_ok := str(attack_rollout.get("selected_source", "")) == "continuous_attack" \
			and live_attack and bool(attack_integration.get("applied", false)) \
			and int(attack_integration.get("contact_number", 0)) == 3 \
			and str(attack_integration.get("ball_status", "")) == "IN_FLIGHT"
		var block_ok := str(block_rollout.get("selected_source", "")) == "continuous_block" \
			and promoted_block and bool(block_integration.get("applied", false))
		if attack_ok and block_ok:
			hits.append(seed_value)
		manager.free()
		if hits.size() >= 6:
			break
	print("seeds promoting BOTH a live attack and a live block: ", hits)
	quit()
