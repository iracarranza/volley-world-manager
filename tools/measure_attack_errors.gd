extends SceneTree

## Does the block have anything to do with an attack going out?
##
##     godot --headless --path . --script res://tools/measure_attack_errors.gd
##
## Reported from playback: volis swing out while the blockers are standing there
## not jumping, because they already know it is going out. A miss at an open net
## is an unforced error and should be rare; a miss should mostly be what pressure
## produces.
##
## `_attack_missed` takes `attack_quality`, `decisiveness` and the hitter's
## fatigue, and nothing else. The set's quality reaches it through
## `attack_quality`, so the reception channel is present. The block is not a
## parameter at all. This counts what that costs: the miss rate split by how much
## block was actually in front of the swing.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var rows := {}
	for rally_seed in range(20000, 20600):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		var events: Array = result.events
		for index in range(events.size()):
			var event = events[index]
			if int(event.event_type) != Events.EventType.ATTACK:
				continue
			## **Read off the swing, not off what happened next.**
			##
			## The first version of this looked forward for a BLOCK event and
			## bucketed by whether one existed -- and a swing that goes out is not
			## blocked, so no BLOCK event follows it. That produced 0% misses
			## against a block and 100% without one, which is not a finding, it is
			## the definition restated. `wall_size` is on the attack event itself
			## and is decided before the outcome is.
			var wall := "wall of %d" % int(event.metadata.get("wall_size", 0))
			var row: Dictionary = rows.get(wall, {"swings": 0, "missed": 0})
			row["swings"] = int(row["swings"]) + 1
			if bool(event.metadata.get("attack_missed", false)):
				row["missed"] = int(row["missed"]) + 1
			rows[wall] = row

	print("attacks by how much block was in front of them")
	print("%-28s %8s %8s %9s" % ["wall", "swings", "missed", "miss rate"])
	var keys := rows.keys()
	keys.sort()
	var total := 0
	var total_missed := 0
	for key in keys:
		var row: Dictionary = rows[key]
		total += int(row["swings"])
		total_missed += int(row["missed"])
		print("%-28s %8d %8d %8.1f%%" % [
			key, int(row["swings"]), int(row["missed"]),
			100.0 * float(row["missed"]) / maxf(float(row["swings"]), 1.0),
		])
	print("%-28s %8d %8d %8.1f%%" % [
		"all", total, total_missed,
		100.0 * float(total_missed) / maxf(float(total), 1.0),
	])
	manager.free()
	quit()
