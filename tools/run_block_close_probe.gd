extends SceneTree

## Why does every block in the game close completely?
##
##     godot --headless --path . --script res://tools/run_block_close_probe.gd
##
## `primary_close` measured 1.00 at every percentile including the minimum, which
## makes the stuff gate's `primary_close >= 0.78` a threshold that cannot fail
## and deletes the whole point of a quick set. Two explanations were on the table
## and both were about the *event*: a selection effect where unclosed blocks
## never emit, or a travel model that is simply too generous.
##
## This asks a third question first, because it is cheaper and it is about the
## *blocker*: `_form_home_block` picks its primary as the front-row blocker whose
## slot is nearest the attack lane. If that is the whole story then a saturated
## primary close is a tautology rather than a defect, the travelling blocker is
## the assist, and the two numbers should look nothing like each other.
##
## Split by tempo, because tempo is what the whole set-height line of work exists
## to make matter, and the claim it rests on is that a quick set beats the middle
## because the middle cannot travel in time.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 400
const FIRST_SEED: int = 30000

const ROWS := [
	"primary_close", "assist_close", "assist_close_attempted",
	"primary_lane_delta_m", "assist_lane_delta_m",
	"primary_required_s", "primary_usable_s", "primary_available_s",
	"assist_required_s", "assist_usable_s", "assist_available_s",
	"set_flight_s", "preset_window_s", "preset_share", "preset_credited_s",
	"primary_closed_fully", "assist_closed_fully", "assist_present",
]


func _initialize() -> void:
	var by_tempo := {}
	## Every blocker the formation nominated, against every blocker that reached
	## an event -- the selection question, answered by counting rather than by
	## reasoning about which branches return early.
	var attacks := 0
	var attacks_with_block_event := 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw_event in result.events:
				var event: Resource = raw_event
				var metadata: Dictionary = event.metadata
				match int(event.event_type):
					RallyEventScript.EventType.ATTACK:
						attacks += 1
					RallyEventScript.EventType.BLOCK:
						attacks_with_block_event += 1
						_collect(
							by_tempo, metadata,
							int(metadata.get("block_tempo", -1)),
							float(metadata.get("set_flight_seconds", 0.0)),
						)
		manager.free()

	var tempos: Array = by_tempo.keys()
	tempos.sort()
	print("=== how far each blocker actually had to travel ===")
	print("")
	var header := "%-24s" % "term"
	for tempo in tempos:
		header += "%12s" % ("tempo %d" % int(tempo))
	print(header)
	for key in ROWS:
		var line := "%-24s" % key
		for tempo in tempos:
			line += "%12.3f" % _mean(by_tempo[tempo], key)
		print(line)
	var counts := "%-24s" % "swings"
	for tempo in tempos:
		counts += "%12d" % int(by_tempo[tempo].n)
	print("")
	print(counts)
	print("")
	print("attacks %d, of which %d carried a block formation (%.1f%%)" % [
		attacks, attacks_with_block_event,
		float(attacks_with_block_event) / maxf(float(attacks), 1.0) * 100.0,
	])
	quit()


func _mean(bucket: Dictionary, key: String) -> float:
	return float(Dictionary(bucket.sums).get(key, 0.0)) \
		/ maxf(float(bucket.n), 1.0)


func _add(bucket: Dictionary, key: String, value: float) -> void:
	var sums: Dictionary = bucket.sums
	sums[key] = float(sums.get(key, 0.0)) + value


func _collect(
	by_tempo: Dictionary,
	metadata: Dictionary,
	tempo: int,
	set_flight: float,
) -> void:
	if not by_tempo.has(tempo):
		by_tempo[tempo] = {"n": 0, "sums": {}}
	var bucket: Dictionary = by_tempo[tempo]
	bucket.n = int(bucket.n) + 1
	var primary: Dictionary = metadata.get("primary_close_terms", {})
	var assist: Dictionary = metadata.get("assist_close_terms", {})
	var primary_close := float(metadata.get("primary_close", 0.0))
	var assist_close := float(metadata.get("assist_close", 0.0))
	_add(bucket, "primary_close", primary_close)
	_add(bucket, "assist_close", assist_close)
	_add(bucket, "assist_close_attempted",
		float(metadata.get("assist_close_attempted", 0.0)))
	## In metres of net, because a lane delta in normalised court x is not a
	## quantity anyone can sanity-check against a volleyball court.
	_add(bucket, "primary_lane_delta_m",
		absf(float(primary.get("lane_delta", 0.0))) * 9.0)
	_add(bucket, "assist_lane_delta_m",
		absf(float(assist.get("lane_delta", 0.0))) * 9.0)
	_add(bucket, "primary_required_s", float(primary.get("required_seconds", 0.0)))
	_add(bucket, "primary_usable_s", float(primary.get("usable_time", 0.0)))
	_add(bucket, "primary_available_s", float(primary.get("available_time", 0.0)))
	_add(bucket, "assist_required_s", float(assist.get("required_seconds", 0.0)))
	_add(bucket, "assist_usable_s", float(assist.get("usable_time", 0.0)))
	_add(bucket, "assist_available_s", float(assist.get("available_time", 0.0)))
	_add(bucket, "set_flight_s", set_flight)
	var preset_window := float(metadata.get("preset_window_seconds", 0.0))
	var preset_share := float(metadata.get("preset_share", 0.0))
	_add(bucket, "preset_window_s", preset_window)
	_add(bucket, "preset_share", preset_share)
	## The part of the budget spent before the ball existed. This is the number
	## the tempo argument turns on: whatever tempo does to the flight, it cannot
	## touch this.
	_add(bucket, "preset_credited_s", preset_window * preset_share)
	_add(bucket, "primary_closed_fully", 1.0 if primary_close >= 0.999 else 0.0)
	_add(bucket, "assist_closed_fully", 1.0 if assist_close >= 0.999 else 0.0)
	_add(bucket, "assist_present", 1.0 if not assist.is_empty() else 0.0)
