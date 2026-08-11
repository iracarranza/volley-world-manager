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
	var Events := load("res://scripts/models/rally_event.gd")
	var overspeed := {}
	var overlaps: Array = []
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
	var worst_when := {}
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
			## The first frames of a rally report a delta of almost nothing, and
			## a real 2 cm step divided by it reads as 163 m/s. Every "teleport"
			## this probe found before this guard was one of those: a centimetre
			## of movement and a broken denominator. Frames with an implausible
			## delta are counted for distance and skipped for speed.
			var delta := screen.get_process_delta_time()
			var delta_is_usable := delta > 0.004
			await process_frame
			for raw_id in court.player_actors:
				var player_id := int(raw_id)
				var here := _ground(court.player_actors[raw_id])
				var before: Vector2 = previous.get(player_id, here)
				var metres := before.distance_to(here)
				totals[player_id] = float(totals.get(player_id, 0.0)) + metres
				var speed := metres / maxf(delta, 0.0001)
				if delta_is_usable and speed > float(worst_step.get(player_id, 0.0)):
					worst_step[player_id] = speed
					## What was on screen when it happened. A jump is only
					## diagnosable if you know which contact it belongs to, and
					## the event label is what playback itself says it is drawing.
					worst_when[player_id] = "%.2f m during %s" % [
						metres, str(screen.event_label.text),
					]
				previous[player_id] = here
			## **How close do two volis get to standing in the same place?**
			##
			## Reported as the whole opposition standing inside each other during
			## block follow. Nothing in playback keeps two bodies apart -- each is
			## placed from its own leg and the legs are independent -- so the only
			## way to see it is to measure the closest pair on each side, every
			## frame. A shoulder is about 0.45 m wide, so anything under half a
			## metre is two bodies overlapping on screen.
			for side in [[1, 6], [101, 106]]:
				var closest := 99.0
				var pair_key := ""
				for a in range(int(side[0]), int(side[1]) + 1):
					for b in range(a + 1, int(side[1]) + 1):
						if not court.player_actors.has(a) or not court.player_actors.has(b):
							continue
						var gap: float = _ground(court.player_actors[a]).distance_to(
							_ground(court.player_actors[b])
						)
						if gap < closest:
							closest = gap
							pair_key = "%d+%d" % [a, b]
				if closest < 0.5 and closest < 99.0:
					overlaps.append({
						"pair": pair_key, "gap": closest,
						"when": str(screen.event_label.text),
					})
		## The legs playback had to draw faster than a body moves, attributed to
		## the contact they belong to. `MatchScreen` has recorded these since the
		## pacing pass landed and nothing has ever read them, which is why "one
		## voli teleports" has been a story rather than a diagnosis.
		for entry in screen.playback_leg_overspeed:
			var key := "%s" % Events.EventType.keys()[int(entry.get("event_type", -1))] \
				if entry.has("event_type") else "unknown"
			var row: Dictionary = overspeed.get(key, {"count": 0, "worst": 0.0, "metres": 0.0})
			row["count"] = int(row["count"]) + 1
			row["worst"] = maxf(float(row["worst"]), float(entry.get("speed", 0.0)))
			row["metres"] = maxf(float(row["metres"]), float(entry.get("metres", 0.0)))
			overspeed[key] = row

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
			print("        ^ %s" % str(worst_when.get(player_id, "?")))
	print("%d of %d volis had at least one frame above 12 m/s" % [
		teleporting, ids.size(),
	])
	print("")
	print("legs playback could not pace, by the contact they belong to")
	print("%-16s %7s %10s %10s" % ["contact", "legs", "worst m/s", "worst m"])
	for key in overspeed:
		var row: Dictionary = overspeed[key]
		print("%-16s %7d %10.1f %10.2f" % [
			key, int(row["count"]), float(row["worst"]), float(row["metres"]),
		])
	print("")
	print("frames where two volis on a side were inside half a metre of each other")
	var by_moment := {}
	for entry in overlaps:
		var key := "%s  %s" % [str(entry["pair"]), str(entry["when"])]
		var row: Dictionary = by_moment.get(key, {"frames": 0, "closest": 99.0})
		row["frames"] = int(row["frames"]) + 1
		row["closest"] = minf(float(row["closest"]), float(entry["gap"]))
		by_moment[key] = row
	print("%-46s %8s %9s" % ["pair and moment", "frames", "closest m"])
	for key in by_moment:
		var row: Dictionary = by_moment[key]
		print("%-46s %8d %9.2f" % [key, int(row["frames"]), float(row["closest"])])
	print("%d overlapping frames in total" % overlaps.size())
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
