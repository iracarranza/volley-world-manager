extends SceneTree

## How much of a "wall of two" is actually up?
##
##     godot --headless --path . --script res://tools/run_wall_reach_probe.gd
##
## Wiring the block into the aim cone moved nothing: 15.6% of swings went out
## before and 15.9% after, and the open-net bucket that the report is about
## contained *one swing in 710*. That is not a small effect, it is the wrong
## instrument. `wall_size` counts blockers who closed to the lane, and
## `block_wall` scales each blocker's `reach_height_m` by the jump they actually
## got -- so a blocker who never left the floor is in the array at standing
## reach and reads as half a wall.
##
## This counts how many of the reported blockers have their hands above the
## tape, and how far under the hitter's own contact they are, so the threshold
## that separates a wall from a bystander is chosen from the distribution rather
## than guessed at.
##
## **The answer refuted the reason for asking.** Measured over 600 rallies, 709
## swings, 1379 blockers: *every* blocker in every wall had their hands above
## the tape, and the whole distribution of reach against the hitter's contact
## fits in two 20 cm buckets -- 1052 blockers reaching between 0 and 0.2 m
## *above* the ball, 327 between 0.2 and 0.4 m below it. There is no bystander
## population. `wall_size` and "wall actually up" are the same number, and the
## effective-wall recut this probe was written to justify would have been a
## second knob for a distinction that does not exist.
##
## Which relocates the report it came from. A hitter swinging into an open net
## is 1 swing in 710; the simulation puts a genuine double block at the ball's
## height on 670 of them. So "volis swing out while the blockers stand there not
## jumping" is not the hitter's aim being blind to the wall -- it is playback
## drawing a wall that the resolver says was up. See `BACKLOG.md`'s "blockers
## already know the outcome".
##
## Kept because that is the finding, and because the next person to suspect the
## wall of being half-imaginary should be able to re-run it in one command.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var under_buckets := {}
	var above_tape := {}
	var swings := 0
	var rows := {}
	for rally_seed in range(20000, 20600):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			if int(event.event_type) != Events.EventType.ATTACK:
				continue
			var reaches: Array = event.metadata.get("wall_reach_heights", [])
			if reaches.is_empty():
				continue
			swings += 1
			var contact := float(event.metadata.get("contact_height_meters", 3.0))
			var up := 0
			for reach_value in reaches:
				var reach := float(reach_value)
				## Hands below the tape are not a wall by any reading.
				if reach >= 2.43:
					up += 1
				## And how far under the ball the hands were, bucketed at 20 cm,
				## which is the number the threshold has to be chosen from.
				var under := contact - reach
				var bucket := "%+0.1f" % (floorf(under / 0.2) * 0.2)
				under_buckets[bucket] = int(under_buckets.get(bucket, 0)) + 1
			above_tape[up] = int(above_tape.get(up, 0)) + 1
			var key := "reported %d / above tape %d" % [reaches.size(), up]
			var row: Dictionary = rows.get(key, {"swings": 0, "missed": 0})
			row["swings"] = int(row["swings"]) + 1
			if bool(event.metadata.get("attack_missed", false)):
				row["missed"] = int(row["missed"]) + 1
			rows[key] = row

	print("swings with a reported wall: %d" % swings)
	print("\nhow far each blocker's reach was UNDER the hitter's contact")
	var keys := under_buckets.keys()
	keys.sort()
	for key in keys:
		print("  %6s m  %5d" % [key, int(under_buckets[key])])
	print("\nblockers with hands above the tape, per swing")
	var counts := above_tape.keys()
	counts.sort()
	for count in counts:
		print("  %d up  %5d swings" % [int(count), int(above_tape[count])])
	print("\nmiss rate, recut")
	var row_keys := rows.keys()
	row_keys.sort()
	for key in row_keys:
		var row: Dictionary = rows[key]
		print("  %-30s %5d swings %5d missed %6.1f%%" % [
			key, int(row["swings"]), int(row["missed"]),
			100.0 * float(row["missed"]) / maxf(float(row["swings"]), 1.0),
		])
	manager.free()
	quit()
