extends SceneTree

## Does seed 5012 still contain the double block its determinism gate samples?
##
## `_test_double_block_wall_positions` replays one hardcoded seed twice and
## compares the wall coordinates. It fails if the two differ -- and equally if
## the sample is *absent*, because the assertion also requires two samples. Those
## are opposite findings sharing one failure message, so this separates them:
## whether the rally still produces a home block with an assist at all, and
## whether the coordinates it produces are stable across replays.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")


func _initialize() -> void:
	for attempt in range(2):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = true
		var result: Resource = manager.resolve_active_rally(5012)
		var home_blocks := 0
		var with_assist := 0
		var detail := ""
		for raw in result.events:
			var event: Resource = raw
			if event == null or int(event.event_type) != EVENT.EventType.BLOCK:
				continue
			if str(event.metadata.get("side", "")) != "home":
				continue
			home_blocks += 1
			var assist := int(event.metadata.get("assist_id", -1))
			if assist >= 0:
				with_assist += 1
				detail = "primary=%s assist=%s live=%s" % [
					event.metadata.get("primary_position", "-"),
					event.metadata.get("assist_position", "-"),
					event.metadata.get("blocker_live_positions", {}),
				]
		print("replay %d: %d home blocks, %d with an assist" % [
			attempt + 1, home_blocks, with_assist,
		])
		if not detail.is_empty():
			print("    %s" % detail)
		manager.free()
	quit()
