extends SceneTree

## Does MatchScreen draw the ball the simulator resolved?
##
##     godot --headless --path . --script res://tools/run_dig_view_lineage.gd
##
## Closes the verification debt carried from fidelity passes 2 and 2.5. The
## simulation chain was proven then -- 162 of 162 digs matching their set's
## incoming trajectory -- but nothing checked the *drawn* ball, and a matching
## pair of endpoints is not proof that the view consumed the same record.
##
## This calls `BallPresentation.display_trajectory` with exactly the arguments
## `match_screen.gd` gives it: the event's own published `outgoing_trajectory`,
## the next contact, and the same physical profiles. It is the view's own
## function, not a reimplementation of it.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const BallPresentation := preload("res://scripts/simulation/ball_presentation.gd")

const SEEDS: Array = [20010, 20016, 20008]


func _initialize() -> void:
	for seed_value in SEEDS:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = true
		var result: Resource = manager.resolve_active_rally(seed_value)
		print("=== seed %d ===" % seed_value)
		if result == null:
			print("  (no rally)")
			manager.free()
			continue
		var profiles: Dictionary = result.player_physical_profiles
		for index in range(result.events.size()):
			var event: Resource = result.events[index]
			if int(event.event_type) != RallyEventScript.EventType.DIG \
					or not bool(event.success):
				continue
			var published: Dictionary = event.metadata.get(
				"outgoing_trajectory", {}
			)
			var next_contact: Resource = _next_contact(result.events, index)
			var drawn: Dictionary = BallPresentation.display_trajectory(
				event, next_contact, published, profiles
			)
			var set_event: Resource = _next_set(result.events, index)
			var consumed: Dictionary = {}
			if set_event != null:
				consumed = set_event.metadata.get("incoming_pass_trajectory", {})
			print("  dig by %s  spoil %.3f" % [
				str(event.actor_name), float(event.metadata.get("pass_spoil", 0.0))])
			_compare("published -> drawn", published, drawn)
			_compare("published -> set consumed", published, consumed)
		manager.free()
	quit()


func _next_contact(events: Array, from_index: int) -> Resource:
	for index in range(from_index + 1, events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.SET_DECISION:
			return event
	return null


func _next_set(events: Array, from_index: int) -> Resource:
	for index in range(from_index + 1, events.size()):
		var event: Resource = events[index]
		if int(event.event_type) == RallyEventScript.EventType.SET:
			return event
		if int(event.event_type) in [RallyEventScript.EventType.ATTACK,
				RallyEventScript.EventType.POINT]:
			return null
	return null


func _compare(label: String, a: Dictionary, b: Dictionary) -> void:
	if a.is_empty() or b.is_empty():
		print("    %-26s MISSING (a=%d keys, b=%d keys)" % [
			label, a.size(), b.size()])
		return
	var diffs: Array[String] = []
	for key in ["trajectory_type", "start_position", "end_position",
			"start_time", "end_time", "duration", "apex_height_meters",
			"start_height_meters", "end_height_meters"]:
		var av: Variant = a.get(key, null)
		var bv: Variant = b.get(key, null)
		if av == null or bv == null:
			diffs.append("%s missing" % key)
			continue
		if typeof(av) == TYPE_VECTOR2:
			if Vector2(av).distance_to(Vector2(bv)) > 0.0005:
				diffs.append("%s %s vs %s" % [key, str(av), str(bv)])
		elif typeof(av) == TYPE_STRING:
			if str(av) != str(bv):
				diffs.append("%s %s vs %s" % [key, str(av), str(bv)])
		elif absf(float(av) - float(bv)) > 0.0005:
			diffs.append("%s %.4f vs %.4f" % [key, float(av), float(bv)])
	if diffs.is_empty():
		print("    %-26s IDENTICAL on all 9 physical fields" % label)
	else:
		print("    %-26s DIFFERS: %s" % [label, ", ".join(diffs)])
