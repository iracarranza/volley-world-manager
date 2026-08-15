extends SceneTree

## Where does a dead ball actually sit, and for how long?
##
##     godot --headless --path . --script res://tools/run_dead_ball_probe.gd
##
## Reported: "the ball still freezes on the floor frequently", and that this is
## what gives a defender time for two or three sets of microadjustments before a
## dig. Twice now a plausible reading of playback timing has failed against
## measurement, so this measures before anything is changed.
##
## `_run_rally` draws an event one of two ways. With an `outgoing_trajectory` it
## calls `_play_flight` for the *trajectory's own* duration -- physics, and the
## ball moves the whole time. Without one it calls `_play_contact_pulse` for
## `_gap_to_next`, the interval between two `physical_time` stamps, and the ball
## does whatever `_carry_trajectory` gives it, which is nothing when the event is
## a block that was flown past or a contact that failed.
##
## So the question is how much drawn time falls in the second case, and what the
## ball is doing during it. Counted here per event type, because "the ball sits"
## wants a culprit, not a total.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var names := {
		Events.EventType.SERVE: "SERVE",
		Events.EventType.RECEPTION: "RECEPTION",
		Events.EventType.SET: "SET",
		Events.EventType.ATTACK: "ATTACK",
		Events.EventType.BLOCK: "BLOCK",
		Events.EventType.DEFENSE: "DEFENSE",
	}
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var rows := {}
	var flight_seconds := 0.0
	var pulse_seconds := 0.0
	## The same figure once a flight's coverage is charged against the windows
	## that follow it, which is what `_run_rally` now does.
	var aftermath_seconds := 0.0
	var rallies := 0
	for rally_seed in range(20000, 20200):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		rallies += 1
		var events: Array = result.events
		var drawn_until := -INF
		for index in range(events.size()):
			var event = events[index]
			var type_name: String = names.get(int(event.event_type), "OTHER")
			if type_name == "OTHER":
				continue
			var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if not trajectory.is_empty():
				var flight := clampf(
					float(trajectory.get("duration", 0.5)), 0.08, 3.5
				)
				flight_seconds += flight
				drawn_until = maxf(
					drawn_until,
					float(event.metadata.get("physical_time", 0.0)) + flight,
				)
				continue
			## The gap `_gap_to_next` would hand `_play_contact_pulse`.
			var gap := 0.38
			if event.metadata.has("physical_time"):
				for later in range(index + 1, events.size()):
					if not events[later].metadata.has("physical_time"):
						continue
					gap = maxf(
						float(events[later].metadata["physical_time"])
							- float(event.metadata["physical_time"]),
						0.0,
					)
					break
			pulse_seconds += gap
			var event_start := float(event.metadata.get("physical_time", 0.0))
			var left_over := gap
			if event.metadata.has("physical_time"):
				left_over = maxf(
					event_start + gap - maxf(event_start, drawn_until), 0.0
				)
			aftermath_seconds += left_over
			var key := "%s%s" % [
				type_name, "" if event.success else " (failed)",
			]
			var row: Dictionary = rows.get(key, {"count": 0, "seconds": 0.0,
				"longest": 0.0})
			row["count"] = int(row["count"]) + 1
			row["seconds"] = float(row["seconds"]) + gap
			row["longest"] = maxf(float(row["longest"]), gap)
			row["left"] = float(row.get("left", 0.0)) + left_over
			rows[key] = row

	print("%d rallies" % rallies)
	print("drawn seconds with the ball flying:   %8.1f" % flight_seconds)
	print("drawn seconds with no flight to draw: %8.1f  (%.1f%% of playback)" % [
		pulse_seconds,
		100.0 * pulse_seconds / maxf(flight_seconds + pulse_seconds, 0.001),
	])
	print("  of which is not already drawn flight: %6.1f  (%.1f%% of playback)" % [
		aftermath_seconds,
		100.0 * aftermath_seconds / maxf(flight_seconds + aftermath_seconds, 0.001),
	])
	print("\nwhere the still time goes")
	print("  %-22s %7s %9s %9s %9s %9s" % [
		"event", "count", "seconds", "mean", "longest", "left over"])
	var keys := rows.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return float(rows[a]["seconds"]) > float(rows[b]["seconds"]))
	for key in keys:
		var row: Dictionary = rows[key]
		print("  %-22s %7d %9.1f %9.3f %9.3f %9.1f" % [
			key, int(row["count"]), float(row["seconds"]),
			float(row["seconds"]) / maxf(float(row["count"]), 1.0),
			float(row["longest"]), float(row.get("left", 0.0)),
		])
	manager.free()
	quit()
