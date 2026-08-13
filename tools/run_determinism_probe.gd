extends Node

## Does the same seed produce the same rally, every time?
##
##     xvfb-run -a godot --path . res://tools/determinism_probe.tscn
##
## The rally-timing brief lists "replay produces the same timeline" as an
## acceptance criterion and nothing in the suite asserts it. A resolver is meant
## to be a function of its seed and its inputs; anything reading a global RNG, an
## unordered dictionary, or wall-clock time breaks that quietly, and the symptom
## is a replay that disagrees with the rally it replays.
##
## Each seed is resolved `REPEATS` times in one process and the streams compared
## field by field. **The first differing field is reported**, because "the rallies
## differ" is not actionable and "event 4's actor_id was 12 then 7" is.
const SEEDS: int = 400
const REPEATS: int = 3


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


## Everything about an event that a replay has to reproduce. Deliberately
## includes the physical timestamps, since those are what the renderers now pace
## on -- a stream that agreed on contacts but not on their timing would look
## identical to this check and wrong on screen.
func _fingerprint(result: Resource) -> Array:
	var rows: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if event == null:
			rows.append({"null": true})
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		rows.append({
			"type": int(event.event_type),
			"actor": int(event.actor_id),
			"success": bool(event.success),
			"quality": "%.6f" % float(event.quality),
			"start": str(event.start_position),
			"end": str(event.end_position),
			"event_time": "%.6f" % float(event.metadata.get("event_time", -1.0)),
			"flight": "%.6f" % float(trajectory.get("duration", -1.0)),
			"flight_end": "%.6f" % float(trajectory.get("end_time", -1.0)),
		})
	return rows


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Determinism Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var checked := 0
	var divergent := 0
	var length_mismatches := 0
	var reports: Array = []
	## Which field diverges, counted, because one flapping field across many
	## seeds is a single defect and looks like many.
	var by_field := {}

	for index in range(SEEDS):
		var seed_value := hash("determinism|%d" % index)
		var reference: Array = []
		var diverged := false
		for repeat in range(REPEATS):
			var result: Resource = game_manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var stream := _fingerprint(result)
			if repeat == 0:
				reference = stream
				continue
			checked += 1
			if stream.size() != reference.size():
				length_mismatches += 1
				diverged = true
				if reports.size() < 10:
					reports.append("seed %d: %d events on run 1, %d on run %d"
						% [seed_value, reference.size(), stream.size(), repeat + 1])
				continue
			for row in range(stream.size()):
				var a: Dictionary = reference[row]
				var b: Dictionary = stream[row]
				for key in a:
					if str(a[key]) == str(b.get(key, "<missing>")):
						continue
					diverged = true
					by_field[key] = int(by_field.get(key, 0)) + 1
					if reports.size() < 10:
						reports.append(
							"seed %d, event %d, field '%s': %s then %s"
								% [seed_value, row, str(key), str(a[key]), str(b.get(key))]
						)
					break
		if diverged:
			divergent += 1

	print("=== determinism probe: %d seeds x %d resolves" % [SEEDS, REPEATS])
	print("comparisons made: %d" % checked)
	print("seeds that did not replay identically: %d of %d" % [divergent, SEEDS])
	print("event-count mismatches: %d" % length_mismatches)
	print("diverging fields: %s" % str(by_field))
	if reports.is_empty():
		print("")
		print("every seed reproduced its rally exactly, including physical timestamps.")
	else:
		print("")
		for line in reports:
			print("  %s" % line)
