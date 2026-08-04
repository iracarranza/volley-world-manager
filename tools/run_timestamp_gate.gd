extends SceneTree

## Does every rally event know when it happened?
##
## Playback currently walks the event list with an accumulator: each event is
## given a slot of animation time and the next one starts when that slot ends.
## That is a running total of *drawing* durations, not a clock -- two contacts
## that physically overlap are drawn in sequence, and an event that costs the
## ball no time at all still pushes everything after it later. Before playback
## can be driven by the simulation's own timeline, the timeline has to exist and
## be trustworthy, which is three separate claims:
##
##   coverage   every event carries `physical_time`
##   ordering   the stamps are non-decreasing in list order
##   floor      the causality floor almost never has to correct one
##
## The third is the real gate. `_stamp_physical_times` clamps each stamp up to
## the running maximum so playback can never be handed a timeline that runs
## backwards, but that clamp is a *floor*, not a schedule: every time it fires,
## some event's own derivation disagreed with the event before it, and the
## number printed here is how often the derivations are wrong rather than how
## well the guard works. A gate that only checked ordering would read the guard's
## output and call the timeline sound.
##
## Run:
##   godot --headless --path . --script res://tools/run_timestamp_gate.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 2
const RALLIES: int = 150

const TYPE_NAMES: Dictionary = {
	RallyEventScript.EventType.SERVE: "SERVE",
	RallyEventScript.EventType.RECEPTION: "RECEPTION",
	RallyEventScript.EventType.SET: "SET",
	RallyEventScript.EventType.ATTACK: "ATTACK",
	RallyEventScript.EventType.BLOCK: "BLOCK",
	RallyEventScript.EventType.DEFENSE: "DEFENSE",
	RallyEventScript.EventType.POINT: "POINT",
}


func _initialize() -> void:
	var stats := {
		"rallies": 0, "events": 0, "stamped": 0, "breaks": 0, "floored": 0,
		"per_type": {}, "unstamped": {}, "transitions": {},
		"span_total": 0.0,
	}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result != null:
					_collect(result, stats)
			manager.free()
	_report(stats)
	quit()


func _collect(result: Resource, stats: Dictionary) -> void:
	stats.rallies += 1
	var previous := -1.0
	var previous_name := "start"
	var last := 0.0
	for raw_event in result.events:
		var event: Resource = raw_event
		var name := str(TYPE_NAMES.get(event.event_type, "?"))
		stats.events += 1
		var per_type: Dictionary = stats.per_type
		per_type[name] = int(per_type.get(name, 0)) + 1
		if not event.metadata.has("physical_time"):
			var unstamped: Dictionary = stats.unstamped
			unstamped[name] = int(unstamped.get(name, 0)) + 1
			continue
		stats.stamped += 1
		var moment := float(event.metadata["physical_time"])
		if moment < previous - 0.0001:
			stats.breaks += 1
		if event.metadata.has("physical_time_floored"):
			stats.floored += 1
			var key := "%s -> %s" % [previous_name, name]
			var transitions: Dictionary = stats.transitions
			var entry: Dictionary = transitions.get(key, {"count": 0, "worst": 0.0})
			entry["count"] = int(entry["count"]) + 1
			entry["worst"] = maxf(
				float(entry["worst"]),
				float(event.metadata["physical_time_floored"]),
			)
			transitions[key] = entry
		previous = moment
		previous_name = name
		last = maxf(last, moment)
	stats.span_total += last


func _report(stats: Dictionary) -> void:
	var events := maxf(float(stats.events), 1.0)
	print("Timestamp gate -- %d rallies, %d events" % [stats.rallies, stats.events])
	print("")
	print("coverage   %d/%d  (%.1f%%)" % [
		stats.stamped, stats.events, 100.0 * float(stats.stamped) / events,
	])
	print("ordering   %d backwards steps" % stats.breaks)
	print("floor      %d corrections (%.2f per rally)" % [
		stats.floored, float(stats.floored) / maxf(float(stats.rallies), 1.0),
	])
	print("mean rally span %.2f s" % [
		float(stats.span_total) / maxf(float(stats.rallies), 1.0),
	])
	var unstamped: Dictionary = stats.unstamped
	if not unstamped.is_empty():
		print("")
		print("unstamped by type:")
		for name in unstamped:
			print("  %-12s %d" % [name, int(unstamped[name])])
	var transitions: Dictionary = stats.transitions
	if not transitions.is_empty():
		print("")
		print("floor fired on:")
		var keys := transitions.keys()
		keys.sort_custom(func(a, b):
			return int(transitions[a]["count"]) > int(transitions[b]["count"]))
		for key in keys:
			var entry: Dictionary = transitions[key]
			print("  %-24s %5d   worst %+.3f s" % [
				key, int(entry["count"]), float(entry["worst"]),
			])
	print("")
	print("The floor is a guard, not a schedule. Every correction above is an")
	print("event whose own derived moment disagreed with the contact before it.")
