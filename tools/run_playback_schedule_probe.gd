extends SceneTree

## What does a rally look like once it is laid out on its own clock?
##
## Playback is about to stop accumulating per-event animation slots and start
## reading `physical_time`. The constants that layout needs -- how much to
## dilate physical time so captions stay readable, and what counts as
## "simultaneous" -- should come from the distribution of real gaps rather than
## from taste. This prints that distribution.
##
## The concurrency epsilon in particular is not a rounding tolerance. Events
## that share a physical moment are events the viewer should see happen
## together; the histogram below is what decides where that boundary sits, and
## whether there is a clean separation between "same instant" and "next beat"
## or merely a continuum that any threshold would cut arbitrarily.
##
## Run:
##   godot --headless --path . --script res://tools/run_playback_schedule_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 2
const RALLIES: int = 150

## Bucket edges in seconds. Deliberately fine at the bottom: the question is
## whether near-zero gaps are a distinct population or the tail of a continuum.
const BUCKETS: Array[float] = [
	0.0, 0.005, 0.02, 0.05, 0.10, 0.20, 0.40, 0.70, 1.00, 1.50, 99.0,
]

const TYPE_NAMES: Dictionary = {
	RallyEventScript.EventType.SERVE: "SERVE",
	RallyEventScript.EventType.RECEPTION: "RECEPTION",
	RallyEventScript.EventType.SET: "SET",
	RallyEventScript.EventType.ATTACK: "ATTACK",
	RallyEventScript.EventType.BLOCK: "BLOCK",
	RallyEventScript.EventType.DIG: "DIG",
	RallyEventScript.EventType.ATTACK_COVERAGE: "ATTACK_COVERAGE",
	RallyEventScript.EventType.POINT: "POINT",
}


func _initialize() -> void:
	var gaps: Array[float] = []
	var zero_pairs := {}
	var spans: Array[float] = []
	var event_counts: Array[int] = []
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
				if result == null:
					continue
				_collect(result, gaps, zero_pairs, spans, event_counts)
			manager.free()
	_report(gaps, zero_pairs, spans, event_counts)
	quit()


func _collect(
	result: Resource,
	gaps: Array[float],
	zero_pairs: Dictionary,
	spans: Array[float],
	event_counts: Array[int],
) -> void:
	var previous := -1.0
	var previous_name := ""
	var first := -1.0
	var last := 0.0
	for raw_event in result.events:
		var event: Resource = raw_event
		if not event.metadata.has("physical_time"):
			continue
		var moment := float(event.metadata["physical_time"])
		var name := str(TYPE_NAMES.get(event.event_type, "?"))
		if first < 0.0:
			first = moment
		else:
			var gap := moment - previous
			gaps.append(gap)
			if gap < 0.02:
				var key := "%s -> %s" % [previous_name, name]
				zero_pairs[key] = int(zero_pairs.get(key, 0)) + 1
		previous = moment
		previous_name = name
		last = maxf(last, moment)
	if first >= 0.0:
		spans.append(last - first)
		event_counts.append(result.events.size())


func _report(
	gaps: Array[float],
	zero_pairs: Dictionary,
	spans: Array[float],
	event_counts: Array[int],
) -> void:
	gaps.sort()
	spans.sort()
	print("Playback schedule probe -- %d rallies, %d inter-event gaps"
		% [spans.size(), gaps.size()])
	print("")
	print("gap distribution (seconds between consecutive events)")
	var total := maxf(float(gaps.size()), 1.0)
	for bucket_index in range(BUCKETS.size() - 1):
		var low := BUCKETS[bucket_index]
		var high := BUCKETS[bucket_index + 1]
		var count := 0
		for gap in gaps:
			if gap >= low and gap < high:
				count += 1
		print("  %6.3f - %6.3f  %5d  %5.1f%%  %s" % [
			low, high, count, 100.0 * float(count) / total,
			"#".repeat(roundi(60.0 * float(count) / total)),
		])
	print("")
	print("  median gap  %.3f s" % _percentile(gaps, 0.50))
	print("  p90 gap     %.3f s" % _percentile(gaps, 0.90))
	print("  max gap     %.3f s" % (gaps[-1] if not gaps.is_empty() else 0.0))
	print("")
	print("rally span: median %.2f s, p90 %.2f s, max %.2f s" % [
		_percentile(spans, 0.50), _percentile(spans, 0.90),
		spans[-1] if not spans.is_empty() else 0.0,
	])
	var mean_events := 0.0
	for count in event_counts:
		mean_events += float(count)
	mean_events /= maxf(float(event_counts.size()), 1.0)
	print("mean events per rally %.1f" % mean_events)
	print("")
	if zero_pairs.is_empty():
		print("No sub-20ms gaps: no event pair is simultaneous, so a concurrency")
		print("rule would never fire and every event wants its own beat.")
	else:
		print("sub-20ms pairs (candidates for one shared beat):")
		var keys := zero_pairs.keys()
		keys.sort_custom(func(a, b): return int(zero_pairs[a]) > int(zero_pairs[b]))
		for key in keys:
			print("  %-24s %5d" % [key, int(zero_pairs[key])])
	print("")
	print("Today every event is clamped into a 0.55-2.60 s slot, so a %.1f s"
		% _percentile(spans, 0.50))
	print("rally is drawn over roughly %.1f s of wall clock." % (mean_events * 0.9))


## Nearest-rank on an already-sorted array.
func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		int(floor(fraction * float(sorted_values.size()))),
		0, sorted_values.size() - 1,
	)
	return sorted_values[index]
