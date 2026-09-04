extends SceneTree

## Does each drawn ball flight fit the window playback draws it in?
##
##     godot --headless --path . --script res://tools/run_ball_window_probe.gd
##
## The movement-contract pass spent nine commits on one defect shape: a journey's
## own duration and the window it is drawn in disagreeing, so the body is drawn
## at a pace nothing authorised. This asks the same question of the **ball**.
##
## A flight's window is the gap between its own `physical_time` and the next
## contact's. Where that is shorter than the trajectory's own `duration`, the
## ball must be drawn faster than its published flight or jump to keep up;
## where it is longer, the ball arrives and waits.
##
## Reads published metadata only. `outgoing_trajectory.duration` is what the
## resolver said the flight takes; `physical_time` is the clock
## `match_screen._gap_to_next` paces playback with.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 60

## Below this a duration and a window are the same number as far as a viewer is
## concerned; a frame at 60 fps is 0.017 s.
const AGREEMENT_SECONDS: float = 0.01


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var families := {}
	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		manager.match_state.serving_home = (seed_value % 2) == 0
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		var events: Array = result.events
		for index in range(events.size() - 1):
			var event: Resource = events[index]
			var next_contact: Resource = events[index + 1]
			var flight: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if flight.is_empty():
				continue
			var window := float(next_contact.metadata.get("physical_time", 0.0)) \
				- float(event.metadata.get("physical_time", 0.0))
			var duration := float(flight.get("duration", 0.0))
			if window <= 0.0 or duration <= 0.0:
				continue
			var name := str(
				RallyEventScript.EventType.keys()[int(event.event_type)]
			)
			var row: Dictionary = families.get(name, {
				"n": 0, "duration": 0.0, "window": 0.0, "ratio": 0.0,
				"window_shorter": 0, "window_longer": 0, "worst": 0.0,
			})
			row["n"] = int(row.n) + 1
			row["duration"] = float(row.duration) + duration
			row["window"] = float(row.window) + window
			row["ratio"] = float(row.ratio) + duration / window
			if window < duration - AGREEMENT_SECONDS:
				row["window_shorter"] = int(row.window_shorter) + 1
			elif window > duration + AGREEMENT_SECONDS:
				row["window_longer"] = int(row.window_longer) + 1
			row["worst"] = maxf(float(row.worst), absf(duration - window))
			families[name] = row
	print("flight_from|n|mean_flight_s|mean_window_s|flight/window"
		+ "|window_shorter|window_longer|worst_gap_s")
	var keys: Array = families.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = families[key]
		var n := maxf(float(b.n), 1.0)
		print("%s|%d|%.3f|%.3f|%.2f|%d|%d|%.3f" % [
			key, int(b.n), float(b.duration) / n, float(b.window) / n,
			float(b.ratio) / n, int(b.window_shorter), int(b.window_longer),
			float(b.worst),
		])
	quit()
