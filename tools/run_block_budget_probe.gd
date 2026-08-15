extends SceneTree

## How much of the block's closing budget actually varies with tempo.
##
## `close_time` is `set_flight_time + preset_window * preset_share + ...`, and
## only the first term moves with tempo. If the constant part dominates, the
## wall does most of its closing before the set exists and no tempo can shift
## it -- which is the leading candidate for why a near-full tempo step buys the
## offence a 3.4% reduction in double blocks while costing the hitter 35% of
## their arrival margin. See docs/design/PRINCIPLE_PRICING.md.
##
##   godot --headless --path . --script res://tools/run_block_budget_probe.gd

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ExecutionScaleModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

const SAMPLES := 40
const CAREER_SEEDS := [
	"North Window", "Glass Harbor", "Second Tempo",
	"Quiet Hands", "Golden Rotation", "Long Road Home",
]


func _initialize() -> void:
	## Keyed by the tempo the swing was actually hit at, so the reading is per
	## tempo rather than per identity -- the identity only decides how often each
	## tempo comes up.
	var by_tempo := {}
	for career_name in CAREER_SEEDS:
		var seed_value := absi(hash("%s|identity-calibration" % career_name))
		for serving_home in [true, false]:
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			manager.team.apply_identity("Balanced")
			ExecutionScaleModel.apply_generated_attributes(manager.players, seed_value)
			ExecutionScaleModel.apply_generated_attributes(
				manager.opponent_team.players, seed_value
			)
			manager.match_state.serving_home = serving_home
			for index in range(SAMPLES):
				var result: Resource = manager.resolve_active_rally(seed_value + index)
				if result != null:
					_scan(result, by_tempo)
	print("%6s %7s %11s %11s %11s %11s %11s %11s %11s %11s" % [
		"tempo", "n", "available", "required", "usable", "deficit", "close",
		"assistcls", "doubles", "setflight",
	])
	var tempos: Array = by_tempo.keys()
	tempos.sort()
	for tempo in tempos:
		var bucket: Dictionary = by_tempo[tempo]
		var n := float(bucket["n"])
		if n < 1.0:
			continue
		print("%6d %7d %11.4f %11.4f %11.4f %11.4f %11.4f %11.4f %11.4f %11.4f" % [
			tempo, int(n),
			float(bucket["available"]) / n,
			float(bucket["required"]) / n,
			float(bucket["usable"]) / n,
			float(bucket["deficit"]) / n,
			float(bucket["close"]) / n,
			float(bucket["assist"]) / n,
			float(bucket["doubles"]) / n,
			float(bucket["setflight"]) / n,
		])
	quit(0)


## The tempo lives on the ATTACK event and the close terms on the BLOCK event,
## so they are paired by walking the rally in order and remembering the last
## tempo seen.
func _scan(result: Resource, by_tempo: Dictionary) -> void:
	var last_tempo := -1
	var last_set_flight := 0.0
	for event_resource in result.events:
		var event: Resource = event_resource
		var type := int(event.event_type)
		if type == RallyEventModel.EventType.SET:
			var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
			last_set_flight = float(outgoing.get("duration", 0.0))
		if type == RallyEventModel.EventType.ATTACK:
			last_tempo = int(event.metadata.get("tempo", -1))
		if type != RallyEventModel.EventType.BLOCK or last_tempo < 0:
			continue
		var terms: Dictionary = event.metadata.get("primary_close_terms", {})
		if terms.is_empty():
			continue
		if not by_tempo.has(last_tempo):
			by_tempo[last_tempo] = {
				"n": 0.0, "available": 0.0, "required": 0.0,
				"usable": 0.0, "deficit": 0.0, "close": 0.0,
				"assist": 0.0, "doubles": 0.0, "setflight": 0.0,
			}
		var bucket: Dictionary = by_tempo[last_tempo]
		bucket["n"] = float(bucket["n"]) + 1.0
		bucket["available"] = float(bucket["available"]) \
			+ float(terms.get("available_time", 0.0))
		bucket["required"] = float(bucket["required"]) \
			+ float(terms.get("required_seconds", 0.0))
		bucket["usable"] = float(bucket["usable"]) \
			+ float(terms.get("usable_time", 0.0))
		bucket["deficit"] = float(bucket["deficit"]) \
			+ float(terms.get("deficit_seconds", 0.0))
		bucket["close"] = float(bucket["close"]) \
			+ float(event.metadata.get("primary_close", 0.0))
		## The assist is the blocker who actually has to travel, so it is the one
		## tempo should be able to beat. Zero means no second blocker formed.
		var assist_close := float(event.metadata.get("assist_close", 0.0))
		bucket["assist"] = float(bucket["assist"]) + assist_close
		if assist_close > 0.0:
			bucket["doubles"] = float(bucket["doubles"]) + 1.0
		bucket["setflight"] = float(bucket["setflight"]) + last_set_flight
