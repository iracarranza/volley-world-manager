extends SceneTree

## What the block's outcome bands are actually cutting.
##
## `_contest_block` sorts a swing into stuff / touch / funnel / miss by comparing
## `contest - attack_quality` against three fixed margins, and a block intent shifts
## all three. Whether the two intents *separate* -- seal ending more rallies at the
## net, funnel getting a piece of more balls without ending them -- depends entirely
## on where that difference sits relative to the margins. Bands set against one
## distribution stop separating when the distribution moves, which is exactly what
## happened when the opponent started swinging instead of lobbing.
##
## So this reports the distribution, not just the outcome counts. A margin outside
## the distribution it cuts is the same defect this session has now found five
## times, and the only way to see it is to look at the spread.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_band_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150
const INTENTS: Array[String] = ["Seal", "Balanced", "Funnel"]
const OUTCOMES: Array[String] = ["stuff", "touch", "funnel", "miss"]


func _initialize() -> void:
	var counts := {}
	var margins := {}
	var misses := {}
	var clearances := {}
	var edges := {}
	var biases := {}
	for intent in INTENTS:
		counts[intent] = {}
		margins[intent] = []
		misses[intent] = {}
		clearances[intent] = []
		edges[intent] = []
		biases[intent] = []
		for roster_seed in ROSTER_SEEDS:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			for rotation_number in manager.defensive_plans:
				var plan: Resource = manager.defensive_plans[rotation_number]
				if plan != null:
					plan.block_intent = intent
			for serving_home in [true, false]:
				manager.match_state.serving_home = serving_home
				for seed_value in range(5000, 5000 + RALLIES):
					var result: Resource = manager.resolve_active_rally(seed_value)
					if result == null:
						continue
					for raw_event in result.events:
						var event := raw_event as RallyEvent
						if event == null \
								or event.event_type != RallyEventScript.EventType.BLOCK \
								or str(event.metadata.get("side", "")) != "home":
							continue
						var outcome := str(event.metadata.get("outcome", "miss"))
						var bucket: Dictionary = counts[intent]
						bucket[outcome] = int(bucket.get(outcome, 0)) + 1
						counts[intent] = bucket
						## What the bands are compared against: how far the block's
						## contest exceeded the swing it faced.
						if event.metadata.has("contest_margin"):
							margins[intent].append(
								float(event.metadata["contest_margin"])
							)
						if outcome == "miss":
							var why := str(
								event.metadata.get("block_miss_reason", "unknown")
							)
							var beaten: Dictionary = misses.get(intent, {})
							beaten[why] = int(beaten.get(why, 0)) + 1
							misses[intent] = beaten
							if event.metadata.has("net_height_over_block_meters"):
								clearances[intent].append(float(
									event.metadata["net_height_over_block_meters"]
								))
							if event.metadata.has("net_crossing_x"):
								## Signed, toward court centre. The wall stands on the
								## hitter's contact; a bias here means it is standing in the
								## wrong place, and spread alone means it is merely narrow.
								var wall_x := float(Vector2(event.metadata.get(
									"primary_position", Vector2(0.5, 0.5)
								)).x)
								var toward_centre := 1.0 if wall_x < 0.5 else -1.0
								biases[intent].append(
									(float(event.metadata["net_crossing_x"]) - wall_x)
									* toward_centre * 9.0
								)
							if why.contains("around") \
									and event.metadata.has("block_edge_miss_meters"):
								edges[intent].append(-float(
									event.metadata["block_edge_miss_meters"]
								))
			manager.free()

	print("Block bands -- %d rosters x %d rallies x 2 serving sides, home blocks"
		% [ROSTER_SEEDS.size(), RALLIES])
	print("")
	print("%-10s %8s %8s %8s %8s %8s %10s" % [
		"intent", "stuff", "touch", "funnel", "miss", "n", "partials"
	])
	for intent in INTENTS:
		var bucket: Dictionary = counts[intent]
		var total := 0
		for key in bucket:
			total += int(bucket[key])
		var partials := int(bucket.get("touch", 0)) + int(bucket.get("funnel", 0))
		var row := "%-10s" % intent
		for outcome in OUTCOMES:
			row += " %8d" % int(bucket.get(outcome, 0))
		print(row + " %8d %10d" % [total, partials])
	print("")
	print("Seal must stuff more; funnel must reach more partials. Tied columns mean")
	print("the two intents are cutting the same part of the distribution.")
	print("")
	print("%-10s %8s %8s %8s %8s %8s   %6s" % [
		"margin", "p10", "p25", "p50", "p75", "p90", "n"
	])
	for intent in INTENTS:
		var pool: Array = margins[intent]
		if pool.is_empty():
			print("%-10s (contest_margin not stamped)" % intent)
			continue
		pool.sort()
		print("%-10s %8.3f %8.3f %8.3f %8.3f %8.3f   %6d" % [
			intent,
			_percentile(pool, 0.10), _percentile(pool, 0.25),
			_percentile(pool, 0.50), _percentile(pool, 0.75),
			_percentile(pool, 0.90), pool.size(),
		])
	print("")
	print("")
	## A dial can only move outcomes it participates in. If most swings never meet
	## the wall at all, the intent has almost nothing to shift.
	print("%-10s %14s %10s %10s %12s   %s" % [
		"beaten", "no wall", "over", "around", "over+around", "metres over the top p50"
	])
	for intent in INTENTS:
		var beaten: Dictionary = misses.get(intent, {})
		var pool: Array = clearances.get(intent, [])
		pool.sort()
		print("%-10s %14d %10d %10d %12d   %+.3f m" % [
			intent,
			int(beaten.get("no wall", 0)), int(beaten.get("over", 0)),
			int(beaten.get("around", 0)), int(beaten.get("over and around", 0)),
			_percentile(pool, 0.50),
		])
	print("")
	## A wall beaten by a hand's width is too narrow. One beaten by a metre is
	## standing somewhere else, and no width would have saved it.
	print("%-10s %10s %10s %10s %10s %10s   %6s" % [
		"crossing", "p10", "p25", "p50", "p75", "p90", "n"
	])
	print("   metres from the wall's centre toward court centre, all misses")
	for intent in INTENTS:
		var pool: Array = biases.get(intent, [])
		if pool.is_empty():
			print("%-10s (net_crossing_x not stamped)" % intent)
			continue
		pool.sort()
		print("%-10s %10.3f %10.3f %10.3f %10.3f %10.3f   %6d" % [
			intent,
			_percentile(pool, 0.10), _percentile(pool, 0.25),
			_percentile(pool, 0.50), _percentile(pool, 0.75),
			_percentile(pool, 0.90), pool.size(),
		])
	print("")
	print("%-10s %10s %10s %10s %10s   %6s" % [
		"past hand", "p10", "p25", "p50", "p75", "n"
	])
	for intent in INTENTS:
		var pool: Array = edges.get(intent, [])
		if pool.is_empty():
			print("%-10s (no lateral misses stamped)" % intent)
			continue
		pool.sort()
		print("%-10s %10.3f %10.3f %10.3f %10.3f   %6d" % [
			intent,
			_percentile(pool, 0.10), _percentile(pool, 0.25),
			_percentile(pool, 0.50), _percentile(pool, 0.75), pool.size(),
		])
	quit()


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
