extends Node

## Before/after frames of the drawn ball, in the real court.
##
## This did not exist. The render tools are galleries and single-screen shots,
## so "before and after frames of playback" had to be reported as unavailable --
## which was true of the instrumentation and not of the engine. The court draws a
## ball from a display trajectory and a progress value, and both of those are
## computable headless, so filming a leg needs the court and nothing else. No
## MatchScreen, no playback loop, no async pacing: just the same
## `set_ball_trajectory_sample` the real thing calls, stepped by hand.
##
## The two curves come from one rally. The "after" trajectory is what
## `BallPresentation` produces now; the "before" one reproduces the defect it
## repaired -- a terminal leg whose far end is where the ball *is* when the
## published flight time runs out, rather than where it lands. The ball is the
## only thing that differs between a matched pair of frames.

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")

const OUT_DIR := "res://artifacts/m8-visual/frames"
## Five samples across the leg: leaving, two thirds of the way up or down, and
## arriving. The last one is the frame that matters -- it is where the old
## curve stopped in the air and the new one reaches the floor.
const STEPS := [0.0, 0.25, 0.5, 0.75, 1.0]

var _court: MatchCourt3D
var _saved := 0


func _ready() -> void:
	get_window().size = Vector2i(960, 640)
	_court = COURT.instantiate() as MatchCourt3D
	add_child(_court)
	await get_tree().process_frame

	## **The seed is searched for, not chosen.**
	##
	## The canonical M8 seed was filmed first and showed nothing: its terminal
	## ball already landed, so before and after were the same curve to three
	## decimals and the pair of frames was evidence of nothing. 56 of 119
	## terminal legs carried the defect and 76005 was one of the other 63.
	##
	## So the rally is the one that exhibits it worst, found by rebuilding each
	## candidate's pre-repair far end and keeping the highest.
	var result: Resource = null
	var best := -1.0
	var best_seed := -1
	for index in range(80):
		var probe = MANAGER.new()
		probe.seed_vertical_slice_data()
		probe.match_state.serving_home = true
		var candidate: Resource = probe.resolve_active_rally(500000 + index)
		if candidate == null:
			continue
		var height := _terminal_pre_repair_height(candidate)
		if height > best:
			best = height
			best_seed = 500000 + index
			result = candidate
	if result == null:
		push_error("no rally with a drawable terminal leg")
		get_tree().quit(1)
		return
	print("filming seed %d, whose terminal ball was drawn stopping %.3f m up" % [
		best_seed, best,
	])
	_court.setup_players(
		result.initial_home_positions, result.initial_opponent_positions,
		{}, result.player_handedness, result.player_physical_profiles
	)
	await get_tree().process_frame

	var contacts := _contacts_of(result)
	if contacts.is_empty():
		push_error("no contacts in the chosen rally")
		get_tree().quit(1)
		return

	## The rally's last leg: the ball nobody plays. This is the witness.
	var last: RallyEvent = contacts[-1]
	var trajectory: Dictionary = last.metadata.get("outgoing_trajectory", {})
	if trajectory.is_empty():
		push_error("terminal contact publishes no ball")
		get_tree().quit(1)
		return
	var after: Dictionary = BP.display_trajectory(
		last, null, trajectory, result.player_physical_profiles
	)
	var before := _pre_repair(after, float(trajectory.get("duration", 0.5)))
	print("terminal leg: after ends at %.3f m, before ended at %.3f m" % [
		float(after.get("end_height_meters", NAN)),
		float(before.get("end_height_meters", NAN)),
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _film("after", after)
	await _film("before", before)
	print("frames written: %d" % _saved)
	get_tree().quit(0 if _saved == STEPS.size() * 2 else 1)


## How high this rally's terminal ball was drawn stopping, before the repair.
## Negative when the rally has no drawable terminal leg at all.
func _terminal_pre_repair_height(candidate: Resource) -> float:
	var contacts := _contacts_of(candidate)
	if contacts.is_empty():
		return -1.0
	var last: RallyEvent = contacts[-1]
	var trajectory: Dictionary = last.metadata.get("outgoing_trajectory", {})
	if trajectory.is_empty():
		return -1.0
	var after: Dictionary = BP.display_trajectory(
		last, null, trajectory, candidate.player_physical_profiles
	)
	return float(_pre_repair(
		after, float(trajectory.get("duration", 0.5))
	).get("end_height_meters", -1.0))


func _contacts_of(candidate: Resource) -> Array:
	var contacts: Array = []
	for raw_event in candidate.events:
		var event := raw_event as RallyEvent
		if event == null or int(event.actor_id) < 0:
			continue
		if int(event.event_type) in [
			RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT
		]:
			continue
		contacts.append(event)
	return contacts


## The far end this leg had before the repair: where the ball is once the
## published flight time is spent, which for a ball still falling is short of
## the floor. Rebuilt rather than reverted, so both frames come from one run.
func _pre_repair(after: Dictionary, raw_duration: float) -> Dictionary:
	var before := after.duplicate(true)
	if not before.has("launch_vertical_mps"):
		return before
	## The duration the leg had *before* the repair, which is the trajectory's
	## own -- not `after["duration"]`, because the repair overwrote that with the
	## fall time. Reading it back would integrate across the very extension being
	## undone and hand back the repaired answer, which is exactly what the first
	## version of this did: it reported every candidate already at the floor and
	## disagreed with the probe that found 56 of 119 above it.
	var flown := maxf(float(before.get(
		"physical_duration_seconds", raw_duration
	)), 0.001)
	var start_height := float(before.get("start_height_meters", 1.0))
	before["end_height_meters"] = maxf(
		start_height + float(before.launch_vertical_mps) * flown
			- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * flown * flown,
		BP.FLOOR_CONTACT_HEIGHT_METERS,
	)
	before["duration"] = flown
	return before


func _film(label: String, display: Dictionary) -> void:
	_court.begin_ball_flight(display, 0.6)
	for step in STEPS:
		_court.set_ball_trajectory_sample(display, float(step))
		await get_tree().process_frame
		await get_tree().process_frame
		var path := "%s/terminal_%s_%02d.png" % [
			OUT_DIR, label, int(round(float(step) * 100.0))
		]
		var image := get_tree().root.get_texture().get_image()
		if image == null:
			push_error("no viewport image -- is this running headless?")
			return
		image.save_png(path)
		_saved += 1
		print("saved %s  (ball y %.3f m)" % [
			ProjectSettings.globalize_path(path),
			_court.trajectory_world_position(display, float(step)).y,
		])
