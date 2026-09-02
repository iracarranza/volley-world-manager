extends Node

## The plan the real `MatchScreen` builds, read out of the real `MatchScreen`.
##
##     xvfb-run -a godot --path . --rendering-method gl_compatibility \
##         res://tools/movement_plan.tscn
##
## Every other movement probe in this pass reproduces `_build_movement_plan` and
## `_pace_plan` from published metadata, which is honest about the record and
## silent about the code. This one instantiates the screen, hands it a resolved
## rally, and calls those two functions directly, so what it prints is the leg
## playback will actually draw -- including the clamps, the re-anchoring to
## `live_positions`, and the separation pass.
##
## Not headless: `MatchCourt3D` needs a rendering context.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 12
const COURT_W: float = 9.0
const COURT_L: float = 18.0


func _ready() -> void:
	get_window().size = Vector2i(960, 640)
	var screen: Node = MATCH_SCREEN.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Object = MANAGER.new()
	manager.seed_vertical_slice_data()
	var rows: Array[String] = []
	var totals := {
		"legs": 0, "with_seconds": 0, "seconds_from_window": 0,
		"delayed": 0, "late_departures": 0, "overspeed": 0, "mismatches": 0,
	}
	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		## The setup `load_and_play_rally` performs before it starts drawing,
		## and only that. Calling the entry point itself would start the
		## playback coroutine, and a plan read while a tween is running is a
		## measurement of the tween.
		screen.active_result = result
		screen._build_player_names(result.events)
		screen.player_handedness = result.player_handedness.duplicate(true)
		screen.player_physical_profiles = \
			result.player_physical_profiles.duplicate(true)
		screen.contact_body_targets.clear()
		var home_positions: Dictionary = result.initial_home_positions
		var opponent_positions: Dictionary = result.initial_opponent_positions
		screen.match_court_3d.setup_players(
			home_positions, opponent_positions, screen.player_names,
			screen.player_handedness, screen.player_physical_profiles,
		)
		screen._cache_contact_body_targets(result.events)
		await get_tree().process_frame
		var events: Array = result.events
		for index in range(events.size() - 1):
			var event: Resource = events[index]
			var next_contact: Resource = events[index + 1]
			if event == null or next_contact == null:
				continue
			var window := float(next_contact.metadata.get("physical_time", 0.0)) \
				- float(event.metadata.get("physical_time", 0.0))
			if window <= 0.0:
				continue
			var plan: Dictionary = screen._build_movement_plan(
				event, next_contact, window
			)
			for raw_player_id in plan:
				var movement: Dictionary = plan[raw_player_id]
				var start := Vector2(movement.get("start", Vector2.ZERO))
				var target := Vector2(movement.get("target", start))
				var delta := target - start
				var metres := Vector2(
					delta.x * COURT_W, delta.y * COURT_L
				).length()
				if metres <= 0.05:
					continue
				totals["legs"] = int(totals.legs) + 1
				var seconds := float(movement.get("seconds", 0.0))
				if seconds > 0.0:
					totals["with_seconds"] = int(totals.with_seconds) + 1
					## A leg whose duration is exactly the window is one nothing
					## timed: `_pace_plan`'s fallback. Counting it separately is
					## the whole question this probe exists to answer.
					if is_equal_approx(seconds, window):
						totals["seconds_from_window"] = int(
							totals.seconds_from_window
						) + 1
				if movement.has("delay_seconds"):
					totals["delayed"] = int(totals.delayed) + 1
				if rows.size() < 20:
					rows.append("%d|%d|%s->%s|%.2f|%.3f|%.3f|%.2f" % [
						seed_value, int(raw_player_id),
						RallyEventScript.EventType.keys()[int(event.event_type)],
						RallyEventScript.EventType.keys()[
							int(next_contact.event_type)
						],
						metres, window, seconds,
						metres / maxf(seconds, 0.0001),
					])
	totals["late_departures"] = screen.playback_late_departures.size()
	totals["overspeed"] = screen.playback_leg_overspeed.size()
	totals["mismatches"] = screen.playback_start_mismatches.size()
	print("seed|player|window_pair|metres|window_s|planned_s|drawn_mps")
	for row in rows:
		print(row)
	print("--- totals over %d rallies" % SEED_COUNT)
	var keys: Array = totals.keys()
	keys.sort()
	for key in keys:
		print("%s|%d" % [key, int(totals[key])])
	get_tree().quit()
