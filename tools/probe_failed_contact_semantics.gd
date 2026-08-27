extends SceneTree

## Does `success == false` on a contact mean "nobody touched it"?
##
## The drawn ball's far end has to be the floor exactly when the ball reached
## the floor, and the cheapest candidate test is the next contact's `success`.
## That is only correct if a failed contact never put a ball up -- if some
## failures are "touched it and shanked it", forcing the floor would draw a
## touched ball into the ground.
##
## So: for every unsuccessful contact, does it publish an outgoing ball? A
## contact that launches nothing did not happen, which is the same definition
## B0 used when it counted contacts by the ball they published.

const MANAGER := preload("res://scripts/managers/game_manager.gd")


func _initialize() -> void:
	var rows := {}
	for side_index in range(2):
		for index in range(90):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side_index == 0
			var result: Resource = manager.resolve_active_rally(400000 + index)
			if result == null:
				continue
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null or int(event.actor_id) < 0:
					continue
				if int(event.event_type) in [
					RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT
				]:
					continue
				var family := str(RallyEvent.EventType.keys()[int(event.event_type)])
				if not rows.has(family):
					rows[family] = {"fail": 0, "fail_with_ball": 0, "ok": 0, "ok_no_ball": 0}
				var row: Dictionary = rows[family]
				var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
				var launched: bool = not outgoing.is_empty() \
					and float(outgoing.get("duration", 0.0)) > 0.0
				if bool(event.success):
					row["ok"] = int(row["ok"]) + 1
					if not launched:
						row["ok_no_ball"] = int(row["ok_no_ball"]) + 1
				else:
					row["fail"] = int(row["fail"]) + 1
					if launched:
						row["fail_with_ball"] = int(row["fail_with_ball"]) + 1
	print("%-18s %8s %14s %8s %12s" % [
		"family", "failed", "fail w/ ball", "ok", "ok w/o ball",
	])
	var keys: Array = rows.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = rows[key]
		print("%-18s %8d %14d %8d %12d" % [
			str(key), int(row["fail"]), int(row["fail_with_ball"]),
			int(row["ok"]), int(row["ok_no_ball"]),
		])
	quit(0)
