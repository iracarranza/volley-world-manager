extends SceneTree

## How much of a rally does a voli spend standing in the ready crouch, and where?
##
##     godot --headless --path . --script res://tools/run_idle_stance_probe.gd
##
## Two reports say the same thing from opposite sides. A front-row voli at the
## net stands like a back-row passer with no hands up; and a voli with no
## serve-receive responsibility holds a passing crouch through a serve they are
## never going to touch. Reading the rig, both are one fact:
## `GaitBiomechanics` has exactly **one** floor stance -- knees at -60, hips
## back, arms at -30 -- and `player_actor_3d.gd` returns after the gait for
## anybody who is not the drawn contact actor. So every stationary body on the
## court, in every role, is in a defender's ready position.
##
## Before building a second stance, this asks whether the first one is even
## visible. `gait_blend` is `smoothstep(0.25, 1.5, speed)` and the stance is
## applied at `1 - gait_blend`, so:
##
##   under 0.25 m/s   the ready crouch, undiluted
##   0.25 to 1.5      mixed with the walk
##   over 1.5         gone
##
## If off-ball volis turn out to spend their rallies above 1.5 m/s the stance is
## never on screen and a second one would be a fix for a case that does not
## occur -- which this session has already produced three of. So the question is
## the share of frames under 0.25, split by where on the court the body is.
##
## Sampled off the rendered nodes rather than off `live_positions`, for the
## reason `measure_offball_travel.gd` gives: the dictionary is what playback
## intends and the node is what a viewer sees.
func _initialize() -> void:
	## Pinned for the same reason as the travel probe -- a speed is metres over a
	## frame delta, and headless Godot will hand out deltas no viewer ever sees.
	Engine.max_fps = 60
	var GameManagerScript := load("res://scripts/managers/game_manager.gd")
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false

	var screen: Control = load("res://scenes/screens/match_screen.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	var court = screen.match_court_3d

	## Bands are the gait's own thresholds, so the buckets answer the question
	## the rig actually asks rather than a rounder one beside it.
	var idle := GaitBiomechanics.IDLE_SPEED_MPS
	var walk := GaitBiomechanics.WALK_SPEED_MPS
	var zones := {}
	var frames := 0
	var rallies := 0
	for rally_seed in [12007, 12011, 12019, 12023, 12029, 12031, 12037, 12041]:
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		rallies += 1
		screen.load_and_play_rally(result, 1.0)
		await process_frame
		var previous := {}
		for raw_id in court.player_actors:
			previous[int(raw_id)] = _ground(court.player_actors[raw_id])
		var guard := 0
		while screen.playback_active and guard < 200000:
			guard += 1
			var delta := screen.get_process_delta_time()
			var usable := delta > 0.004
			await process_frame
			if usable:
				frames += 1
			for raw_id in court.player_actors:
				var player_id := int(raw_id)
				var here := _ground(court.player_actors[raw_id])
				var before: Vector2 = previous.get(player_id, here)
				previous[player_id] = here
				if not usable:
					continue
				var speed := before.distance_to(here) / maxf(delta, 0.0001)
				## The net is z = 0 in world metres -- the same fact the
				## blocker's facing override reads when it picks a side.
				var zone := "at the net" if absf(here.y) <= NET_BAND_METERS \
					else ("mid court" if absf(here.y) <= 4.5 else "deep")
				var row: Dictionary = zones.get(zone, {
					"frames": 0, "still": 0, "mixed": 0, "moving": 0,
				})
				row["frames"] = int(row["frames"]) + 1
				if speed < idle:
					row["still"] = int(row["still"]) + 1
				elif speed < walk:
					row["mixed"] = int(row["mixed"]) + 1
				else:
					row["moving"] = int(row["moving"]) + 1
				zones[zone] = row

	print("%d rallies, %d sampled frames\n" % [rallies, frames])
	print("where a body is, and how much of the ready crouch it is wearing")
	print("%-12s %10s %14s %14s %12s" % [
		"zone", "frames", "< 0.25 (full)", "0.25-1.5 (mix)", "> 1.5 (none)"])
	var keys := ["at the net", "mid court", "deep"]
	for key in keys:
		if not zones.has(key):
			continue
		var row: Dictionary = zones[key]
		var total := maxf(float(row["frames"]), 1.0)
		print("%-12s %10d %13.1f%% %13.1f%% %11.1f%%" % [
			key, int(row["frames"]),
			100.0 * float(row["still"]) / total,
			100.0 * float(row["mixed"]) / total,
			100.0 * float(row["moving"]) / total,
		])
	manager.free()
	quit()


## How close to the net counts as being at it. A blocker's stance is taken
## within about a metre of the tape; beyond that they are a defender again, and
## the crouch is right.
const NET_BAND_METERS: float = 1.6


func _ground(actor) -> Vector2:
	var here: Vector3 = actor.global_position
	return Vector2(here.x, here.z)
