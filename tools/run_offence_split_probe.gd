extends SceneTree

## Why does one side of the net swing better than the other?
##
##     godot --headless --path . --script res://tools/run_offence_split_probe.gd
##
## The last structural asymmetry, and the one every other out-of-band number is
## downstream of. `run_rally_balance_probe` reports the gap -- home swings come
## out around 0.48 and opponent swings around 0.33 -- and cannot say which term
## produces it, because attack quality is a product of six things and a product
## that only ever reports itself cannot be asked which factor moved.
##
## `_attack_execution` is:
##
##     capability * (1 - SET_W*(1-set_quality))
##               * (1 - APPROACH_W*(1-approach_fit))
##               * (1 - TIMING_W*(1-timing))
##               * (1 - tempo_demand)
##               - block_pressure
##
## so every one of those is printed per side. A gap in `capability` is a roster
## or attribute-plumbing problem; a gap in `set_quality` is the second contact; a
## gap in the approach terms is the run-up; a gap in `block_pressure` is the wall
## the two sides face. They want completely different fixes and the composite
## cannot distinguish them.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 350
const FIRST_SEED: int = 20000


func _initialize() -> void:
	## Split by what fed the set, not only by side.
	##
	## A set off a serve-receive pass and a set off a dig are different contacts in
	## the sport, and if one side plays mostly one of them a side-only average
	## compares two different questions. This is the control the first version of
	## this probe lacked.
	var sides := {
		"home/pass": _bucket(), "home/dig": _bucket(),
		"opponent/pass": _bucket(), "opponent/dig": _bucket(),
	}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result != null:
				_collect(result, sides)
		manager.free()

	print("=== what each side's swing is made of ===")
	print("")
	var columns := ["home/pass", "home/dig", "opponent/pass", "opponent/dig"]
	print("%-26s %12s %12s %12s %12s" % [
		"term", columns[0], columns[1], columns[2], columns[3],
	])
	for key in [
		"attack_quality", "set_quality", "pass_quality", "runup_quality",
		"approach_quality", "arrival_margin", "wall_size",
	]:
		print("%-26s %12.3f %12.3f %12.3f %12.3f" % [
			key,
			_mean(sides[columns[0]], key), _mean(sides[columns[1]], key),
			_mean(sides[columns[2]], key), _mean(sides[columns[3]], key),
		])
	print("")
	print("%-26s %12d %12d %12d %12d" % [
		"swings",
		int(sides[columns[0]].n), int(sides[columns[1]].n),
		int(sides[columns[2]].n), int(sides[columns[3]].n),
	])
	quit()


func _bucket() -> Dictionary:
	return {"n": 0, "sums": {}}


func _mean(bucket: Dictionary, key: String) -> float:
	return float(Dictionary(bucket.sums).get(key, 0.0)) \
		/ maxf(float(bucket.n), 1.0)


func _add(bucket: Dictionary, key: String, value: float) -> void:
	var sums: Dictionary = bucket.sums
	sums[key] = float(sums.get(key, 0.0)) + value


func _collect(result: Resource, sides: Dictionary) -> void:
	## The set that fed each swing, so set quality is attributed to the attack it
	## produced rather than averaged over a side's sets in general -- a side whose
	## sets are often not swung at would otherwise read better than it plays.
	var last_set_quality := 0.0
	var last_pass_quality := 0.0
	var fed_by := "pass"
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) == RallyEventScript.EventType.RECEPTION:
			last_pass_quality = float(event.quality)
			fed_by = "pass"
			continue
		if int(event.event_type) == RallyEventScript.EventType.DIG:
			last_pass_quality = float(event.quality)
			fed_by = "dig"
			continue
		if int(event.event_type) == RallyEventScript.EventType.SET:
			last_set_quality = float(event.quality)
			continue
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var side := "%s/%s" % [str(event.metadata.get("side", "")), fed_by]
		if not sides.has(side):
			continue
		var bucket: Dictionary = sides[side]
		bucket.n = int(bucket.n) + 1
		var metadata: Dictionary = event.metadata
		var approach: Dictionary = metadata.get("resolved_approach", {})
		_add(bucket, "attack_quality", float(event.quality))
		_add(bucket, "set_quality", last_set_quality)
		_add(bucket, "pass_quality", last_pass_quality)
		_add(bucket, "runup_quality", float(metadata.get("swing_runup_quality", 0.0)))
		_add(bucket, "approach_quality", float(approach.get("approach_quality",
			metadata.get("approach_quality", 0.0))))
		_add(bucket, "arrival_margin", float(metadata.get("arrival_margin", 0.0)))
		_add(bucket, "jump_multiplier", float(metadata.get("jump_multiplier", 1.0)))
		_add(bucket, "approach_distance_meters",
			float(metadata.get("approach_distance_meters", 0.0)))
		_add(bucket, "reached_mark",
			1.0 if bool(metadata.get("reached_approach_mark", false)) else 0.0)
		_add(bucket, "in_system",
			1.0 if bool(metadata.get("swing_in_system", false)) else 0.0)
		_add(bucket, "wall_size", float(metadata.get("wall_size", 0)))
		_add(bucket, "swing_downgraded",
			1.0 if bool(metadata.get("swing_downgraded", false)) else 0.0)
