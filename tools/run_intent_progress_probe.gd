extends SceneTree

## Does the cogniticon's `progress` carry anything to draw?
##
##     godot --headless --path . --script res://tools/run_intent_progress_probe.gd
##
## `COGNITICONS.md` describes a sword that fills as a hitter covers their run-up
## and a shield that fills as a defender collapses into cover. `PlayerCognitionCue`
## carries `progress` as a field, six phase maps in `rally_simulator.gd` fill it
## from `_travel_fraction`, and `cognition_billboard_3d.gd` never mentions it --
## it composes a glyph string from intent, shape, face and trend and stops. So
## the marks on court are static whatever the voli is doing, which is why a live
## read looks like a set of placeholder glyphs.
##
## That is the same dropped-key shape as `reach_margin_meters` and
## `wall_reach_heights` earlier in this session: a quantity computed, published,
## carried most of the way, and let go at the last step. It is the third time.
##
## But a renderer reading a field that is always zero draws nothing either, and
## a fill built on a flat distribution would be a knob that cannot reach its own
## range. So this measures the distribution before anything is drawn from it:
## how often is `progress` non-zero, and per intent, because the doc only claims
## four of the nine intents accumulate at all.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var per_intent := {}
	var samples := 0
	for rally_seed in range(41000, 41060):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			if int(event.event_type) == Events.EventType.SET_DECISION:
				continue
			for key in ["home_phase_intents", "opponent_phase_intents"]:
				var intents := Dictionary(event.metadata.get(key, {}))
				for raw_id in intents:
					var entry := Dictionary(intents[raw_id])
					var intent := str(entry.get("intent", "watching"))
					var progress := float(entry.get("progress", 0.0))
					samples += 1
					var row: Dictionary = per_intent.get(intent, {
						"count": 0, "nonzero": 0, "sum": 0.0, "full": 0,
					})
					row["count"] = int(row["count"]) + 1
					row["sum"] = float(row["sum"]) + progress
					if progress > 0.01:
						row["nonzero"] = int(row["nonzero"]) + 1
					if progress > 0.99:
						row["full"] = int(row["full"]) + 1
					per_intent[intent] = row

	print("%d intent samples\n" % samples)
	print("%-20s %8s %10s %10s %9s" % [
		"intent", "samples", "progress>0", "mean", "at 1.0"])
	var keys := per_intent.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(per_intent[a]["count"]) > int(per_intent[b]["count"]))
	for key in keys:
		var row: Dictionary = per_intent[key]
		var count := maxf(float(row["count"]), 1.0)
		print("%-20s %8d %9.1f%% %10.2f %8.1f%%" % [
			key, int(row["count"]),
			100.0 * float(row["nonzero"]) / count,
			float(row["sum"]) / count,
			100.0 * float(row["full"]) / count,
		])
	manager.free()
	quit()
