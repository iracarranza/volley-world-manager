extends SceneTree

## What a decisive identity actually buys and pays, per home swing.
##
## The isolation probe showed home kill rate falling monotonically with
## `decisiveness` while stuffs *rose*. Both cannot be right: the engine's own
## comment says a quick set beats the block because the wall has less time to
## close. This reads the intermediate quantities on the same sweep, so the chain
## can be checked link by link instead of inferred from its endpoint.
##
##   godot --headless --path . --script res://tools/run_tempo_price_probe.gd

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ExecutionScaleModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

const LEVELS := [0.15, 0.50, 0.85]
const SAMPLES := 32
const CAREER_SEEDS := [
	"North Window", "Glass Harbor", "Second Tempo",
	"Quiet Hands", "Golden Rotation", "Long Road Home",
]


func _initialize() -> void:
	print("%-6s %8s %10s %10s %10s %9s %9s %9s %9s" % [
		"decis", "tempo", "assistcls", "arrival", "apprqual", "close", "kill",
		"stuff", "double",
	])
	for level in LEVELS:
		var totals := {}
		var counts := {}
		for career_name in CAREER_SEEDS:
			var seed_value := absi(hash("%s|identity-calibration" % career_name))
			for serving_home in [true, false]:
				var manager := GameManagerModel.new()
				manager.seed_vertical_slice_data()
				manager.team.apply_identity("Balanced")
				manager.team.principles.set("decisiveness", level)
				manager.team.principles.set("transition_commitment", 0.50)
				ExecutionScaleModel.apply_generated_attributes(
					manager.players, seed_value
				)
				ExecutionScaleModel.apply_generated_attributes(
					manager.opponent_team.players, seed_value
				)
				manager.match_state.serving_home = serving_home
				for index in range(SAMPLES):
					var result: Resource = manager.resolve_active_rally(seed_value + index)
					if result == null:
						continue
					_accumulate(result, totals, counts)
		print("%-6.2f %8.3f %10.4f %10.4f %10.4f %9.4f %9.4f %9.4f %9.4f" % [
			level,
			_mean(totals, counts, "tempo"),
			_mean(totals, counts, "assist_close"),
			_mean(totals, counts, "arrival_margin"),
			_mean(totals, counts, "approach_quality"),
			_mean(totals, counts, "close"),
			_ratio(totals, "kills", "home_attacks"),
			_ratio(totals, "stuffs", "home_attacks"),
			_ratio(totals, "doubles", "blocks"),
		])
	quit(0)


func _accumulate(result: Resource, totals: Dictionary, counts: Dictionary) -> void:
	for event_resource in result.events:
		var event: Resource = event_resource
		var type := int(event.event_type)
		if type == RallyEventModel.EventType.SET:
			_add(totals, counts, "set_flight", float(event.metadata.get(
				"flight_seconds", event.metadata.get("set_flight_seconds", 0.0)
			)))
		if type == RallyEventModel.EventType.ATTACK \
				and str(event.metadata.get("side", "")) == "home":
			totals["home_attacks"] = float(totals.get("home_attacks", 0.0)) + 1.0
			_add(totals, counts, "tempo", float(event.metadata.get("tempo", 0)))
			if event.metadata.has("arrival_margin"):
				_add(totals, counts, "arrival_margin",
					float(event.metadata["arrival_margin"]))
			if event.metadata.has("approach_quality"):
				_add(totals, counts, "approach_quality",
					float(event.metadata["approach_quality"]))
		if type == RallyEventModel.EventType.BLOCK:
			var outcome := str(event.metadata.get("outcome", "miss"))
			if outcome == "stuff":
				totals["stuffs"] = float(totals.get("stuffs", 0.0)) + 1.0
			if outcome in ["touch", "funnel", "stuff"]:
				totals["touches"] = float(totals.get("touches", 0.0)) + 1.0
			totals["blocks"] = float(totals.get("blocks", 0.0)) + 1.0
			if event.metadata.has("primary_close"):
				_add(totals, counts, "close", float(event.metadata["primary_close"]))
			## The assist is the blocker who has to travel, so it is the one a
			## quick set should beat. Zero means no second blocker formed at all,
			## which is the outcome a first-tempo ball is supposed to produce --
			## counted separately, because averaging a present assist with an
			## absent one hides exactly the transition being looked for.
			var assist_close := float(event.metadata.get("assist_close", 0.0))
			_add(totals, counts, "assist_close", assist_close)
			if assist_close > 0.0:
				totals["doubles"] = float(totals.get("doubles", 0.0)) + 1.0
	if str(result.terminal_outcome) == "kill" and bool(result.home_team_won):
		totals["kills"] = float(totals.get("kills", 0.0)) + 1.0


func _add(totals: Dictionary, counts: Dictionary, key: String, value: float) -> void:
	totals[key] = float(totals.get(key, 0.0)) + value
	counts[key] = float(counts.get(key, 0.0)) + 1.0


func _mean(totals: Dictionary, counts: Dictionary, key: String) -> float:
	return float(totals.get(key, 0.0)) / maxf(float(counts.get(key, 0.0)), 1.0)


func _ratio(totals: Dictionary, numerator: String, denominator: String) -> float:
	return float(totals.get(numerator, 0.0)) / maxf(float(totals.get(denominator, 0.0)), 1.0)
