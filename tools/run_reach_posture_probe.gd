extends SceneTree

## What does a contact at the edge of somebody's range actually look like?
##
##     godot --headless --path . --script res://tools/run_reach_posture_probe.gd
##
## The rig has a `reaching` posture with its own platform yaw, roll and stance
## width, and `rally_simulator.gd`'s own comment records that it fires on 0.0%
## of receptions. The reason is in the classifier: it asks for
## `reach_margin < 0.0`, and a margin below zero is a ball *outside* the
## defender's range -- a ball they did not get. So the branch selects a pose for
## contacts that by definition do not happen.
##
## Reaching is the other side of that line: a contact made at the edge of the
## range rather than beyond it. A small positive margin, not a negative one.
## Where "small" stops is what this measures, on the distribution the threshold
## will act on, rather than being picked and hoped for.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var buckets := {}
	var postures := {}
	var contacts := 0
	var missing := 0
	for rally_seed in range(20000, 20300):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			var type := int(event.event_type)
			if type != Events.EventType.DIG \
					and type != Events.EventType.RECEPTION:
				continue
			if not event.metadata.has("reach_margin_meters"):
				missing += 1
				continue
			contacts += 1
			var margin := float(event.metadata["reach_margin_meters"])
			var bucket := clampf(floorf(margin / 0.25) * 0.25, -1.0, 2.0)
			buckets[bucket] = int(buckets.get(bucket, 0)) + 1
			var posture := str(event.metadata.get("contact_posture", "planted"))
			postures[posture] = int(postures.get(posture, 0)) + 1

	print("%d floor contacts carry a reach margin, %d do not" % [contacts, missing])
	print("\nreach margin, 25 cm buckets  (negative = the ball was out of range)")
	var keys := buckets.keys()
	keys.sort()
	var running := 0
	for key in keys:
		running += int(buckets[key])
		print("  %+5.2f m  %6d  %5.1f%% cumulative" % [
			float(key), int(buckets[key]),
			100.0 * float(running) / maxf(float(contacts), 1.0),
		])
	print("\nposture as classified today")
	for key in postures.keys():
		print("  %-12s %6d  %5.1f%%" % [
			key, int(postures[key]),
			100.0 * float(postures[key]) / maxf(float(contacts), 1.0),
		])
	manager.free()
	quit()
