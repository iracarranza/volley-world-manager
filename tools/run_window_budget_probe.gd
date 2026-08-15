extends SceneTree

## How long is a contact's window, really?
##
##     godot --headless --path . --script res://tools/run_window_budget_probe.gd
##
## Every cogniticon envelope has to fit inside a window: a blade swoops in,
## charges and slashes, an eye appears, narrows and reacts. The design named
## roughly 0.7 s of motion for a single blade, and named it before anyone had
## checked how long a window lasts. A 0.3 s swoop inside a 0.28 s window is an
## envelope that never finishes, and one inside a 2 s window is a mark that has
## arrived and then waits.
##
## This is the measurement the motion design asked for, taken before any
## envelope is tuned rather than after -- which is the one habit that has held
## up across this whole session.
##
## Windows are per *drawn flight*, because that is the unit playback animates
## over: the interval between one contact and the next. Reported per event type,
## since a set's flight and a spike's flight are not remotely the same length
## and an envelope tuned on the average would be wrong for both.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var per_type := {}
	var all: Array[float] = []
	for rally_seed in range(52000, 52180):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		var contacts: Array = []
		for event in result.events:
			if int(event.event_type) == Events.EventType.SET_DECISION:
				continue
			contacts.append(event)
		for index in range(contacts.size() - 1):
			var here = contacts[index]
			var next = contacts[index + 1]
			var from := float(here.metadata.get("event_time", -1.0))
			var to := float(next.metadata.get("event_time", -1.0))
			if from < 0.0 or to < 0.0 or to <= from:
				continue
			var seconds := to - from
			var name := str(Events.EventType.keys()[int(here.event_type)])
			var row: Array = per_type.get(name, [])
			row.append(seconds)
			per_type[name] = row
			all.append(seconds)

	print("%d windows across 180 rallies\n" % all.size())
	print("%-12s %7s %8s %8s %8s %8s %8s" % [
		"after", "count", "p10", "median", "mean", "p90", "min"])
	var keys := per_type.keys()
	keys.sort()
	for key in keys:
		var row: Array = per_type[key]
		_report(key, row)
	_report("ALL", all)

	## The number every envelope is measured against: how much motion fits in
	## the *short* windows, not the average ones. An envelope that only works at
	## the median is broken on a tenth of the plays, and a tenth of the plays is
	## several a set.
	var sorted := all.duplicate()
	sorted.sort()
	if not sorted.is_empty():
		var p10: float = float(sorted[int(float(sorted.size()) * 0.10)])
		print("\nA tenth of windows are shorter than %.2f s." % p10)
		print("An envelope longer than that does not finish on those plays.")
	manager.free()
	quit()


func _report(label: String, values: Array) -> void:
	if values.is_empty():
		return
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	var count := sorted.size()
	print("%-12s %7d %8.2f %8.2f %8.2f %8.2f %8.2f" % [
		label, count,
		float(sorted[int(float(count) * 0.10)]),
		float(sorted[count / 2]),
		total / float(count),
		float(sorted[mini(int(float(count) * 0.90), count - 1)]),
		float(sorted[0]),
	])
