extends SceneTree

## What the offence actually calls, over live rallies.
##
## Every rate this project measures from rallies is really a rate for whichever
## lane the offence happens to be stuck on, so the mix has to be readable before
## any of them can be trusted. It moved once already without anyone noticing:
## an earlier reading had 65 of 66 swings at Front Quick, and it now reads 82%
## Right Pin.
##
## Prints the joint distribution because the marginals hide the finding. Lane
## and base tempo are one-to-one -- both are fields on the same
## `HitterAssignment` -- so `_apply_identity_tempo`, which rewrites the tempo and
## never the lane, can only redistribute tempo *within* a lane. Fixing tempo
## variety does not open the lanes; fixing the lanes brings tempo with it.
const GameManagerModel := preload("res://scripts/managers/game_manager.gd")


func _initialize() -> void:
	var manager := GameManagerModel.new()
	manager.seed_vertical_slice_data()
	var lanes := {}
	var tempos := {}
	var joint := {}
	var base_tempos := {}
	var n := 0
	for offset in range(180):
		manager.match_state.serving_home = offset % 2 == 0
		var result: Resource = manager.resolve_active_rally(770000 + offset)
		if result == null or not (result.analysis is Dictionary):
			continue
		var effects: Dictionary = result.analysis.get("identity_effects", {})
		var sel: Dictionary = effects.get("attack_selection", {})
		if sel.is_empty():
			continue
		n += 1
		var lane := str(sel.get("lane", "?"))
		var tempo := int(sel.get("selected_tempo", -1))
		var base := int(sel.get("base_tempo", -1))
		lanes[lane] = int(lanes.get(lane, 0)) + 1
		tempos[tempo] = int(tempos.get(tempo, 0)) + 1
		base_tempos[base] = int(base_tempos.get(base, 0)) + 1
		var key := "%s|%d" % [lane, tempo]
		joint[key] = int(joint.get(key, 0)) + 1
	print("home attacks sampled: %d" % n)
	print("--- lane ---")
	for k in lanes:
		print("  %-14s %4d  %.3f" % [k, lanes[k], float(lanes[k]) / n])
	print("--- selected tempo ---")
	for k in tempos:
		print("  %-14d %4d  %.3f" % [k, tempos[k], float(tempos[k]) / n])
	print("--- base tempo (before identity shift) ---")
	for k in base_tempos:
		print("  %-14d %4d  %.3f" % [k, base_tempos[k], float(base_tempos[k]) / n])
	print("--- joint lane|tempo ---")
	for k in joint:
		print("  %-18s %4d" % [k, joint[k]])
	quit(0)
