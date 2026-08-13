extends Node

## Which ball flights last longer than a volleyball rally does.
##
##     xvfb-run -a godot --path . res://tools/long_flight_probe.tscn
##
## `tools/playback_timing_probe.tscn` measured ball legs over 240 rallies and
## found a 95th percentile of 1.51 seconds and a maximum of 31.00 -- two legs
## over four seconds in 1,506. Playback's old ceiling of 2.60 had been absorbing
## them silently, which is why a flight eleven times longer than any real one
## had never been reported.
##
## **This probe only catches them.** It records the seed, the magnitude and every
## field the offending trajectory carries, and it does not attempt to say why.
## Two per 1,500 legs is too rare to characterise from a sample this thin without
## first collecting a decent number of them, and guessing at a cause from two
## examples is how a threshold gets written without measuring its distribution.
const RALLIES: int = 3000
const LONG_SECONDS: float = 4.0
const KEEP_EXAMPLES: int = 12


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Flight Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var legs := 0
	var long_legs := 0
	var longest := 0.0
	var examples: Array = []
	## Which event type each long flight left, and how long the ones that are
	## merely suspicious run. Counting by event type is the one grouping that is
	## certainly correct without reading the resolver.
	var by_event := {}
	var over := {"4s": 0, "6s": 0, "10s": 0, "20s": 0}

	for index in range(RALLIES):
		var seed_value := hash("longflight|%d" % index)
		var result: Resource = game_manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		for raw_event in result.events:
			var event: Resource = raw_event
			if event == null:
				continue
			var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if trajectory.is_empty():
				continue
			legs += 1
			var duration := float(trajectory.get("duration", 0.0))
			longest = maxf(longest, duration)
			if duration < LONG_SECONDS:
				continue
			long_legs += 1
			over["4s"] += 1
			over["6s"] += int(duration >= 6.0)
			over["10s"] += int(duration >= 10.0)
			over["20s"] += int(duration >= 20.0)
			var type_name := str(event.type_name())
			by_event[type_name] = int(by_event.get(type_name, 0)) + 1
			if examples.size() < KEEP_EXAMPLES:
				examples.append({
					"seed": seed_value,
					"event": type_name,
					"duration": duration,
					"trajectory": trajectory,
					"terminal_outcome": str(result.terminal_outcome),
				})

	print("=== long flight probe: %d rallies, %d ball legs" % [RALLIES, legs])
	print("legs of %.1fs or more: %d (%.3f%% of legs), longest %.2fs" % [
		LONG_SECONDS, long_legs,
		100.0 * float(long_legs) / maxf(float(legs), 1.0), longest,
	])
	print("over 4s: %d | over 6s: %d | over 10s: %d | over 20s: %d" % [
		over["4s"], over["6s"], over["10s"], over["20s"],
	])
	print("by event type: %s" % str(by_event))
	print("")
	for example in examples:
		print("--- seed %d | %s | %.2fs | rally ended %s" % [
			int(example["seed"]), str(example["event"]),
			float(example["duration"]), str(example["terminal_outcome"]),
		])
		var trajectory: Dictionary = example["trajectory"]
		## Every field, unfiltered. Which one explains it is exactly the question
		## this probe is refusing to answer from two samples.
		var keys: Array = trajectory.keys()
		keys.sort()
		for key in keys:
			print("      %s = %s" % [str(key), str(trajectory[key])])
