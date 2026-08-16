extends SceneTree

## What an `ATTACK_COVERAGE` contact actually owns.
##
##     godot --headless --path . --script res://tools/run_coverage_census.gd
##
## Coverage is the last successful contact in the rally whose physical ball is
## not its own: `_ensure_event_trajectories` builds one after the fact from a
## 0.58 s constant and a 1.8 m apex. This counts how often that happens, on which
## of the three coverage sites, and what the second contact after it was given --
## which is the question that decides whether the fabrication is display-only or
## reaches the resolver.
##
## A fresh `GameManager` per rally, so a difference belongs to that rally.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 30000
const SEED_COUNT: int = 700


func _initialize() -> void:
	var rows: Array[String] = []
	rows.append(
		"side|seed|serving_home|actor|success|quality|src|dur|apex|start_h|end_h"
		+ "|from_x|from_y|to_x|to_y|target_err|event_time|next|next_gap|contacts"
	)
	var totals := {
		"rallies": 0, "coverage": 0, "successful": 0,
		"fabricated": 0, "owned": 0,
	}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			totals["rallies"] = int(totals.rallies) + 1
			if rally != null:
				rows.append_array(_rows_for(rally, serving_home, seed_value, totals))
			manager.free()
	var path := "user://coverage_census.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("rallies %d | coverage contacts %d | successful %d | of those, ball"
		% [int(totals.rallies), int(totals.coverage), int(totals.successful)]
		+ " owned %d, fabricated afterwards %d"
		% [int(totals.owned), int(totals.fabricated)])
	print("wrote %s (%d rows)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1])
	quit()


func _rows_for(
	rally: Resource, serving_home: bool, seed_value: int, totals: Dictionary
) -> Array[String]:
	var rows: Array[String] = []
	var events: Array = rally.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.ATTACK_COVERAGE:
			continue
		totals["coverage"] = int(totals.coverage) + 1
		var successful := bool(event.success)
		if successful:
			totals["successful"] = int(totals.successful) + 1
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		## **The tell.** `_ensure_event_trajectories` runs after the rally is
		## resolved, so a ball it built carries the default 1.0 m heights and the
		## `default` marker. A contact that resolved its own would say otherwise.
		var source := str(trajectory.get("height_source", "-"))
		if successful:
			if source == "default":
				totals["fabricated"] = int(totals.fabricated) + 1
			else:
				totals["owned"] = int(totals.owned) + 1
		var next_type := "-"
		var next_gap := -1.0
		if index + 1 < events.size():
			var following: Resource = events[index + 1]
			next_type = str(RallyEventScript.EventType.keys()[
				int(following.event_type)
			])
			next_gap = float(following.metadata.get("event_time", -1.0)) \
				- float(event.metadata.get("event_time", 0.0))
		rows.append(
			"%s|%d|%s|%d|%s|%.4f|%s|%.4f|%.4f|%.4f|%.4f|%.5f|%.5f|%.5f|%.5f"
			% [
				str(event.metadata.get("side", "?")), seed_value,
				"1" if serving_home else "0", int(event.actor_id),
				"1" if successful else "0", float(event.quality), source,
				float(trajectory.get("duration", -1.0)),
				float(trajectory.get("apex_height_meters", -1.0)),
				float(trajectory.get("start_height_meters", -1.0)),
				float(trajectory.get("end_height_meters", -1.0)),
				event.start_position.x, event.start_position.y,
				event.end_position.x, event.end_position.y,
			]
			+ "|%.4f|%.4f|%s|%.4f|%d" % [
				Vector2(event.start_position).distance_to(
					Vector2(event.end_position)
				) * CourtConstants.COURT_WIDTH_METERS,
				float(event.metadata.get("event_time", -1.0)),
				next_type, next_gap, events.size(),
			]
		)
	return rows
