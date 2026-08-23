extends SceneTree

## How close to breaking is each seed-pinned test fixture?
##
##     godot --headless --path . --script res://tools/run_seed_fixture_fragility.gd
##
## Eight test functions pin a literal rally seed. Six of them need the rally to
## have a *shape* -- a shadow reception trace, a geometric attack record, a
## continuous trail -- and none of the six guards against its absence. Two broke
## this session when the forward serve changed which rallies reach a reception,
## and both were repaired by moving the seed, which fixes the symptom.
##
## The useful number is not whether the pinned seed works today. It is **what
## fraction of neighbouring seeds would also have worked**. A fixture whose
## property holds on nine seeds in ten is incidental to the seed and robust; one
## that holds on three in ten is a coin flip that happens to be showing heads,
## and the next physics change will land on it.
##
## Reports the pinned seed's own verdict alongside that rate, so a fixture can be
## triaged as "safe", "one change from breaking", or "already lucky".

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")

const NEIGHBOURS: int = 40

## The six shape-dependent fixtures, and what each one needs the rally to have.
const FIXTURES := [
	{"gate": "_test_shadow_reception_trace", "seed": 1002, "need": "reception_trace"},
	{"gate": "_test_gate_fifteen_disabled_rollout", "seed": 150001, "need": "rollout"},
	{"gate": "_test_gate_fifty_continuous_reachability_timeline", "seed": 1002,
		"need": "continuous_trail"},
	{"gate": "_test_geometric_attack_promotion_translates_a_rally", "seed": 770012,
		"need": "geometric_attack"},
	{"gate": "_test_minor_region_behaviour", "seed": 77531, "need": "rally"},
	{"gate": "_test_default_offense_without_saved_play", "seed": 4411, "need": "rally"},
]


func _initialize() -> void:
	print("%-54s %-8s %-7s %s" % ["gate", "seed", "pinned", "neighbours holding"])
	for entry in FIXTURES:
		var fixture := Dictionary(entry)
		var seed_value := int(fixture.seed)
		var need := str(fixture.need)
		var pinned := _holds(seed_value, need)
		var held := 0
		for offset in range(NEIGHBOURS):
			if _holds(seed_value + offset, need):
				held += 1
		print("%-54s %-8d %-7s %d/%d = %.2f" % [
			str(fixture.gate), seed_value, "yes" if pinned else "NO",
			held, NEIGHBOURS, float(held) / float(NEIGHBOURS)])
	quit()


## Whether one rally has the shape a fixture needs. Fresh manager each time, so
## the answer belongs to that seed and not to what preceded it -- the pinned
## tests all construct their own manager too.
func _holds(seed_value: int, need: String) -> bool:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = manager.resolve_active_rally(seed_value)
	var verdict := false
	if result != null:
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		var summary: Dictionary = trace.get("summary", {})
		match need:
			"rally":
				verdict = true
			"reception_trace":
				verdict = bool(summary.get("available", false)) \
					and not Array(trace.get("entries", [])).is_empty()
			"rollout":
				var rollout: Dictionary = summary.get("reception_rollout", {})
				verdict = bool(rollout.get("activation_implemented", false)) \
					and int(rollout.get("selected_event_count", -1)) \
						== result.events.size()
			"continuous_trail":
				var repeated: Dictionary = Dictionary(
					summary.get("perception_candidates", {})
				).get("repeated_read", {})
				verdict = not Array(
					repeated.get("continuous_trail", [])
				).is_empty()
			"geometric_attack":
				var record: Dictionary = summary.get("geometric_attack", {})
				verdict = bool(record.get("available", false)) \
					and not str(record.get("outcome", "")).is_empty() \
					and float(record.get("speed_mps", 0.0)) > 0.0
	manager.free()
	return verdict
