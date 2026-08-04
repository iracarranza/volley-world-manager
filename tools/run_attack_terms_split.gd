extends SceneTree

## Which term of the attack moved when the clock started running?
##
## Starting `rally_clock` on home-served rallies dropped attack quality on both
## sides of those rallies -- home's by 42% relative. Two hypotheses have already
## died guessing at the mechanism from the source (a live-integrator rejection,
## then a movement-budget clamp), so this reads the terms the attack is actually
## built from instead of reasoning about which one ought to have changed.
##
## `_attack_execution` takes set quality, arrival margin, tempo demand and block
## pressure. Every one of those is already recorded on the ATTACK event. Split by
## serving assignment, because only home-served rallies changed, and the
## opponent-served half is the control -- it must come out bit-identical.
##
## Run:
##   godot --headless --path . --script res://tools/run_attack_terms_split.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const HOME_PLAYBOOK_TEMPO: int = 3

## Numeric attack-event metadata worth a mean. Anything absent on a given event
## is skipped rather than counted as zero, so a term that only some paths record
## does not read as a term that collapsed.
const TERMS: Array[String] = [
	"quality", "arrival_margin", "approach_speed_mps", "approach_quality",
	"approach_distance_meters", "movement_duration", "set_flight_time",
	"jump_multiplier", "lateral_control", "flight_time",
]


func _initialize() -> void:
	var buckets := {}
	for serving_home in [true, false]:
		buckets[serving_home] = {"home": {}, "opponent": {}}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.opponent_team.tendencies["tempo"] = HOME_PLAYBOOK_TEMPO
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result != null:
					_collect(result, buckets[serving_home])
			manager.free()
	print("Attack terms by serving assignment -- %d pairings x %d rallies"
		% [PAIRINGS, RALLIES])
	print("")
	print("%-26s %11s %11s %11s %11s" % [
		"term", "hsrv/home", "hsrv/opp", "osrv/home", "osrv/opp",
	])
	for term in TERMS:
		print("%-26s %11s %11s %11s %11s" % [
			term,
			_mean(buckets[true], "home", term), _mean(buckets[true], "opponent", term),
			_mean(buckets[false], "home", term), _mean(buckets[false], "opponent", term),
		])
	print("")
	print("%-26s %11d %11d %11d %11d" % [
		"attacks sampled",
		_count(buckets[true], "home"), _count(buckets[true], "opponent"),
		_count(buckets[false], "home"), _count(buckets[false], "opponent"),
	])
	print("")
	print("The last two columns are the control: nothing outside the home-serve")
	print("path changed, so they must match across trees exactly.")
	quit()


func _collect(result: Resource, bucket: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var side := str(event.metadata.get("side", ""))
		if not bucket.has(side):
			continue
		var totals: Dictionary = bucket[side]
		for term in TERMS:
			var value: Variant = event.quality if term == "quality" \
				else event.metadata.get(term, null)
			if value == null:
				continue
			var entry: Array = totals.get(term, [0.0, 0])
			entry[0] = float(entry[0]) + float(value)
			entry[1] = int(entry[1]) + 1
			totals[term] = entry
		bucket[side] = totals


func _mean(bucket: Dictionary, side: String, term: String) -> String:
	var totals: Dictionary = bucket[side]
	if not totals.has(term):
		return "-"
	var entry: Array = totals[term]
	if int(entry[1]) == 0:
		return "-"
	return "%.4f" % (float(entry[0]) / float(entry[1]))


func _count(bucket: Dictionary, side: String) -> int:
	var totals: Dictionary = bucket[side]
	if not totals.has("quality"):
		return 0
	return int(totals["quality"][1])
