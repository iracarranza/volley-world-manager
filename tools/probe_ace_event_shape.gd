extends SceneTree

## What does an ace publish, exactly?
##
## `success == false` turned out to mean "touched it and failed" for the serve,
## reception, set and attack families, and "never touched it" only for the block
## and the dig. That leaves the ace unaccounted for: it is a reception nobody
## made, so either it emits no reception at all, or it emits one whose outgoing
## ball is the serve still travelling to the floor. Those want opposite drawing,
## so the difference is worth reading rather than assuming.

const MANAGER := preload("res://scripts/managers/game_manager.gd")


func _initialize() -> void:
	var shown := 0
	for side_index in range(1, 2):
		for index in range(120):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side_index == 0
			var result: Resource = manager.resolve_active_rally(300000 + index)
			if result == null:
				continue
			var outcome := str(result.outcome)
			var is_ace := outcome.contains("ace")
			if not is_ace:
				continue
			print("--- seed %d  side %s  outcome %s" % [
				300000 + index, "home_serving" if side_index == 0 else "opp_serving",
				outcome,
			])
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				var family := str(RallyEvent.EventType.keys()[int(event.event_type)])
				if not (family in ["SERVE", "RECEPTION", "DIG", "POINT"]):
					continue
				var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
				print("    %-10s actor %-14s success %-5s outgoing %s  reach_margin %s" % [
					family, str(event.actor_name), str(event.success),
					"none" if outgoing.is_empty() else "duration %.3f" % float(
						outgoing.get("duration", 0.0)
					),
					str(event.metadata.get("reach_margin_meters", "-")),
				])
			shown += 1
			if shown >= 4:
				quit(0)
				return
	print("aces found: %d" % shown)
	quit(0)
