extends SceneTree

## Does a stuffed ball's flight come from its trajectory yet, or still from a
## constant?
##
##     godot --headless --path . --script res://tools/run_stuff_flight_probe.gd
##
## `_block_deflection_trajectory` has always solved the *soft* branch properly:
## pace absorbed against the blocker's timing and the hands' intent, then
## `struck_arc_from_speed`. The stuff branch did neither -- it flew to the
## attack's own target and took `BLOCK_STUFF_FLIGHT_SECONDS` to get there, a
## constant, which is the reported suspicion stated exactly.
##
## A wired deflection makes that duration a spread rather than a spike, because
## distance over pace differs per stuff. This counts the spread. One value
## repeated is the constant still winning.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var durations := {}
	var landed := 0
	var no_landing := 0
	var blocks := 0
	for rally_seed in range(20000, 20300):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			if int(event.event_type) != Events.EventType.ATTACK:
				continue
			if str(event.metadata.get("block_contact_kind", "")) != "stuff":
				continue
			blocks += 1
			if event.metadata.get("block_deflection_landing", null) == null:
				no_landing += 1
			else:
				landed += 1
		## The flight itself is on the block event that follows.
		for event in result.events:
			if int(event.event_type) != Events.EventType.BLOCK:
				continue
			var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if trajectory.is_empty():
				continue
			var bucket := "%.2f" % (roundf(float(trajectory.get("duration", 0.0)) / 0.05) * 0.05)
			durations[bucket] = int(durations.get(bucket, 0)) + 1

	print("stuffed swings: %d   with a published landing: %d   without: %d" % [
		blocks, landed, no_landing])
	print("\nblock deflection flight times, 50 ms buckets")
	var keys := durations.keys()
	keys.sort()
	for key in keys:
		print("  %6s s  %5d" % [key, int(durations[key])])
	print("\n%d distinct flight times" % durations.size())
	manager.free()
	quit()
