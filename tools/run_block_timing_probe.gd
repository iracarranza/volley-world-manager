extends SceneTree

## When does a blocker actually leave the floor, relative to the hitter?
##
## The observation this exists to check: watching a slow roll shot, the block's
## whole jump sequence appeared to start only *after* the attacker's contact.
## Playback poses the "next contact" during the current event's flight, so if a
## block event follows its attack in the sequence, the blocker's wind-up occupies
## the attack's own flight window -- meaning the wall goes up while the ball is
## already travelling, and is at full extension only when the ball reaches it.
##
## A real blocker is at their apex around the *hitter's* contact, having left the
## floor before it. If the ordering below is attack-then-block, the pose timing
## is anchored to the wrong event and no amount of tuning the block model fixes
## it.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_timing_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 1
const RALLIES: int = 60


func _initialize() -> void:
	var blocked := 0
	var orderings := {}
	var gaps: Array[float] = []
	var attack_flights: Array[float] = []
	for pairing in range(PAIRINGS):
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(result, orderings, gaps, attack_flights)
				blocked += _block_count(result)
			manager.free()
	print("blocks seen: %d" % blocked)
	print("")
	print("what immediately precedes a block:")
	for key in orderings:
		print("  %-12s %d" % [key, orderings[key]])
	print("")
	_report("gap from the preceding event, seconds", gaps)
	_report("that attack's own flight time, seconds", attack_flights)
	print("")
	print("A blocker's wind-up occupies the preceding event's flight window.")
	print("If that window is the attack's, the wall rises after the swing.")
	quit()


func _block_count(result: Resource) -> int:
	var count := 0
	for event in result.events:
		if int((event as Resource).event_type) == RallyEventScript.EventType.BLOCK:
			count += 1
	return count


func _collect(
	result: Resource,
	orderings: Dictionary,
	gaps: Array[float],
	attack_flights: Array[float],
) -> void:
	var events: Array = result.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.BLOCK:
			continue
		var previous_name := "(start)"
		if index > 0:
			previous_name = str((events[index - 1] as Resource).type_name())
		orderings[previous_name] = int(orderings.get(previous_name, 0)) + 1
		if index > 0:
			var previous: Resource = events[index - 1]
			gaps.append(
				float(event.metadata.get("event_time", 0.0))
					- float(previous.metadata.get("event_time", 0.0))
			)
			if int(previous.event_type) == RallyEventScript.EventType.ATTACK:
				attack_flights.append(
					float(previous.metadata.get("flight_time", 0.0))
				)


func _report(label: String, values: Array[float]) -> void:
	if values.is_empty():
		print("%s: no samples" % label)
		return
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print(
		"%s: n=%d min %.3f  p50 %.3f  mean %.3f  max %.3f"
		% [
			label, values.size(), values[0],
			values[values.size() / 2], total / float(values.size()),
			values[values.size() - 1],
		]
	)
