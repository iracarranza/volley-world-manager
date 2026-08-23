extends SceneTree

## Where does correcting the serve's published heights first change the rally?
##
##     godot --headless --path . --script res://tools/run_serve_height_fork.gd
##
## **One seed, one manager.** The dig lineage probe reuses a `GameManager`
## across a seed range, so rotation, fatigue and match flow carry between
## rallies -- a single early divergence would cascade and look like a broad
## effect. Each rally here gets a fresh manager, so a difference is that rally's
## own and nothing else's.
##
## Writes a per-seed fingerprint to user:// so the two states can be diffed
## outside the engine.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 20000
const SEED_COUNT: int = 120


func _initialize() -> void:
	var label := "experiment" if _serve_heights_resolved() else "baseline"
	var lines: Array[String] = []
	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			lines.append("%d|null" % seed_value)
			manager.free()
			continue
		var parts: Array[String] = ["%d|%s|%s|%d" % [
			seed_value, str(result.terminal_outcome),
			str(result.home_team_won), result.events.size()]]
		for raw in result.events:
			var event: Resource = raw
			var trajectory: Dictionary = event.metadata.get(
				"outgoing_trajectory", {}
			)
			parts.append("%s:%s:%s:%.6f:%.6f,%.6f>%.6f,%.6f:%.6f" % [
				str(RallyEventScript.EventType.keys()[int(event.event_type)]),
				str(event.actor_id), str(event.success), float(event.quality),
				event.start_position.x, event.start_position.y,
				event.end_position.x, event.end_position.y,
				float(trajectory.get("duration", -1.0)),
			])
		lines.append("|".join(parts))
		manager.free()
	var path := "user://serve_fork_%s.txt" % label
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("wrote %s (%d seeds, isolated managers)" % [
		ProjectSettings.globalize_path(path), lines.size()])
	quit()


## Which state this build is in, read off the rally rather than off the source.
func _serve_heights_resolved() -> bool:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = manager.resolve_active_rally(FIRST_SEED)
	var resolved := false
	if result != null:
		for raw in result.events:
			var event: Resource = raw
			if int(event.event_type) != RallyEventScript.EventType.SERVE:
				continue
			var trajectory: Dictionary = event.metadata.get(
				"outgoing_trajectory", {}
			)
			resolved = str(trajectory.get("height_source", "")) == "resolved"
			break
	manager.free()
	return resolved
