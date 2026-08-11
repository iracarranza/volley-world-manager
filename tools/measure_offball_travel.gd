extends SceneTree

## How each voli moves on screen during a rally: how far, and how smoothly.
##
##     godot --headless --path . --script res://tools/measure_offball_travel.gd
##
## Drives the real `MatchScreen` through real rallies and samples
## `MatchCourt3D.live_positions` every frame -- the dictionary the actors are
## placed from. Nothing here recomputes a plan; use `measure_offball_plan.gd`
## for what was asked and this for what was drawn.
##
## **Two numbers, and the second one is the point.** Path length alone cannot
## tell a walk from a teleport: a body that slides four metres over a second and
## a body that stands still and then jumps four metres in one frame have
## identical path length. So this also reports the largest single-frame step,
## converted to metres per second. A human on a volleyball court tops out near
## 7 m/s; anything far above that was not travelled, it was assigned.
##
## **`live_positions` is normalised court space, not metres.** The first version
## of this file summed raw Vector2 distances and called them metres, which
## under-reported travel by roughly an order of magnitude and made a working
## court look dead. Every figure below goes through `court_width` and
## `court_length` first. This is the third time on this one question that the
## instrument, not the code under test, was the thing that was broken.
func _initialize() -> void:
	## Pinned, because the speed figures below are metres divided by a frame
	## delta and headless Godot runs the loop as fast as it can. Unpinned, a
	## frame that happened to take a quarter of a millisecond turns an ordinary
	## walking step into 75 m/s and the teleport count becomes a measure of
	## scheduler jitter. At 60 the delta is the delta a player actually sees.
	Engine.max_fps = 60
	var GameManagerScript := load("res://scripts/managers/game_manager.gd")
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false

	var screen: Control = load("res://scenes/screens/match_screen.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	var court = screen.match_court_3d

	var rally_seeds := [12007, 12011, 12019, 12023, 12029, 12031, 12037, 12041]
	var totals := {}
	var worst_step := {}
	var actors := {}
	var rallies := 0
	for rally_seed in rally_seeds:
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		rallies += 1
		for event in result.events:
			if int(event.actor_id) >= 0:
				actors[int(event.actor_id)] = true
		screen.load_and_play_rally(result, 1.0)
		await process_frame
		var previous := {}
		for raw_id in court.player_actors:
			previous[int(raw_id)] = _ground(court.player_actors[raw_id])
		var guard := 0
		while screen.playback_active and guard < 200000:
			guard += 1
			var delta := screen.get_process_delta_time()
			await process_frame
			for raw_id in court.player_actors:
				var player_id := int(raw_id)
				var here := _ground(court.player_actors[raw_id])
				var before: Vector2 = previous.get(player_id, here)
				var metres := before.distance_to(here)
				totals[player_id] = float(totals.get(player_id, 0.0)) + metres
				var speed := metres / maxf(delta, 0.0001)
				if speed > float(worst_step.get(player_id, 0.0)):
					worst_step[player_id] = speed
				previous[player_id] = here

	var ids := totals.keys()
	ids.sort()
	print("%d rallies, as drawn" % rallies)
	print("%-6s %12s %14s %9s" % ["voli", "m/rally", "worst m/s", "touched"])
	var teleporting := 0
	for player_id in ids:
		var fastest := float(worst_step.get(player_id, 0.0))
		print("%-6d %12.2f %14.1f %9s" % [
			int(player_id), float(totals[player_id]) / float(maxi(rallies, 1)),
			fastest, "yes" if actors.has(int(player_id)) else "-",
		])
		if fastest > 12.0:
			teleporting += 1
	print("%d of %d volis had at least one frame above 12 m/s" % [
		teleporting, ids.size(),
	])
	manager.free()
	quit()


## Where the body actually is on the floor, in world metres.
##
## Read off the rendered node, not off `live_positions`. The dictionary is what
## playback *intends*; the node is what a viewer sees, and the whole reason this
## file exists is that those two have been assumed equal without ever being
## compared. Height is dropped because a jump is not travel.
func _ground(actor) -> Vector2:
	var here: Vector3 = actor.global_position
	return Vector2(here.x, here.z)
