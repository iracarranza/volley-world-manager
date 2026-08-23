extends SceneTree

## The maps are published on an ace. Do they ask anybody to move?
##
## A phase map that repeats every voli's spawn position is published and inert:
## playback reads it, drives each actor to where it already is, and the court
## looks frozen. That is indistinguishable on screen from publishing nothing,
## and only distinguishable here.

const MANAGER := preload("res://scripts/managers/game_manager.gd")

func _initialize() -> void:
	for side in range(2):
		for index in range(110):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(300000 + index)
			if result == null or str(result.terminal_outcome) != "ace":
				continue
			var reception: RallyEvent = null
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event != null and int(event.event_type) == RallyEvent.EventType.RECEPTION:
					reception = event
					break
			if reception == null:
				continue
			print("--- ace seed %d (%s serving)" % [
				300000 + index, "home" if side == 0 else "opponent",
			])
			_side_report(
				"receiving", reception.metadata.get(
					"home_phase_targets" if side == 1 else "opponent_phase_targets", {}
				),
				result.initial_home_positions if side == 1 else result.initial_opponent_positions
			)
			_side_report(
				"serving  ", reception.metadata.get(
					"opponent_phase_targets" if side == 1 else "home_phase_targets", {}
				),
				result.initial_opponent_positions if side == 1 else result.initial_home_positions
			)
	quit(0)


func _side_report(label: String, raw_map: Variant, spawn: Dictionary) -> void:
	var map: Dictionary = raw_map if raw_map is Dictionary else {}
	var moved := 0
	var worst := 0.0
	for raw_id in map:
		var id := int(raw_id)
		if not spawn.has(id):
			continue
		var target := Vector2(map[raw_id]) if not (map[raw_id] is Dictionary) \
			else Vector2(Dictionary(map[raw_id]).get("target", spawn[id]))
		var metres := RallyKinematics.court_delta_meters(
			Vector2(spawn[id]), target
		).length()
		if metres > 0.05:
			moved += 1
		worst = maxf(worst, metres)
	print("    %s  entries %2d  asked to move %d  worst %.3f m" % [
		label, map.size(), moved, worst,
	])
