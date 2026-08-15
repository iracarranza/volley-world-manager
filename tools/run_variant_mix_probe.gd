extends SceneTree

## How often is a mark loud, in the cues the compiler actually emits?
##
##     godot --headless --path . --script res://tools/run_variant_mix_probe.gd
##
## `CogniticonMotion.variant_for` maps a cue's state and affect onto `plain`,
## `ascendant` or `broken`, and the design says the middle has to stay wide: a
## vocabulary where every mark is flaming is a vocabulary with one word in it.
##
## The first gate written for that counted the **state space** -- all seven
## states crossed with all six affects -- found 12 of 42 plain, and failed. That
## is the §0 failure mode exactly: the state space is uniform and real cues are
## not, so it measured a distribution nobody ever sees. `upset` and `sad` are
## rare in compiled cues and `neutral` is most of them; the crossing gives each
## the same weight.
##
## This measures the real thing, which is what the threshold then gets set
## against.
func _initialize() -> void:
	var Compiler := load("res://scripts/simulation/cognition_compiler.gd")
	var Motion := load("res://scripts/data/cogniticon_motion.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var variants := {}
	var affects := {}
	var states := {}
	var total := 0
	for rally_seed in range(61000, 61240):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for cue in Compiler.compile(result):
			var state := str(cue.state)
			var affect := str(cue.affect)
			var variant: String = Motion.variant_for(state, affect)
			variants[variant] = int(variants.get(variant, 0)) + 1
			affects[affect] = int(affects.get(affect, 0)) + 1
			states[state] = int(states.get(state, 0)) + 1
			total += 1

	print("%d cues across 240 rallies\n" % total)
	_report("variant", variants, total)
	print("")
	_report("affect", affects, total)
	print("")
	_report("state", states, total)

	var plain := int(variants.get("plain", 0))
	print("\nPlain is %.1f%% of compiled cues." % [
		float(plain) / maxf(float(total), 1.0) * 100.0])
	print("A threshold on the state space would have asked for 50%, which is a")
	print("number about a distribution nobody ever sees.")
	manager.free()
	quit()


func _report(label: String, table: Dictionary, total: int) -> void:
	var keys := table.keys()
	keys.sort_custom(func(a, b): return int(table[a]) > int(table[b]))
	print("%-16s %8s %8s" % [label, "count", "share"])
	for key in keys:
		print("%-16s %8d %7.1f%%" % [
			key, int(table[key]),
			float(table[key]) / maxf(float(total), 1.0) * 100.0,
		])
