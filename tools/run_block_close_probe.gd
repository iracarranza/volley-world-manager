extends SceneTree

## How close each wall gets, against the gate that decides whether it exists.
##
## `GeometricAttackPromotion.block_wall` drops any blocker whose close fraction
## is under `WALL_JOIN_CLOSE`, and that is the only gate that can return an empty
## wall from a formation that already named a primary. Measured, the home wall is
## absent on 45% of opponent swings while the opponent's wall is never absent --
## so the two sides' close distributions sit on opposite sides of one threshold.
##
## Both closes have been on the BLOCK event all along; nothing here needed
## adding, only reading. Per FAILURE_MODES.md 14, that is the order to try first.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_close_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const Promotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var primary := {"home": [], "opponent": []}
	var assist := {"home": [], "opponent": []}
	var has_assist := {"home": 0, "opponent": 0}
	## The discriminating measurement. The close formula ramps over 0.45 s and can
	## return anything in between, so a binary output means a bimodal input.
	var terms := {"home": [], "opponent": []}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.BLOCK:
					continue
				var side := str(event.metadata.get("side", ""))
				if not primary.has(side):
					continue
				var itemised := Dictionary(
					event.metadata.get("primary_close_terms", {})
				)
				if not itemised.is_empty():
					terms[side].append(itemised)
				if event.metadata.has("primary_close"):
					primary[side].append(float(event.metadata.primary_close))
				if event.metadata.has("assist_close"):
					var value := float(event.metadata.assist_close)
					assist[side].append(value)
					if value > 0.0:
						has_assist[side] = int(has_assist[side]) + 1
	manager.free()

	print("Block close against the join gate -- %d rallies x 2 serving sides"
		% RALLIES)
	print("")
	print("WALL_JOIN_CLOSE  %.3f" % Promotion.WALL_JOIN_CLOSE)
	print("")
	print("A blocker under the gate is not in the wall at all. The share below it")
	print("is the share of the wall that simply is not there.")
	print("")
	_report("primary close", primary)
	print("")
	_report("assist close", assist)
	print("")
	print("What the close is built from. `deficit` is required - usable; at or")
	print("below zero the close is 1.0, at or beyond %.2f it is 0.0, and anything"
		% 0.45)
	print("between returns a fraction. A bimodal deficit is the whole story.")
	print("")
	for key in [
		"available_time", "reaction_delay", "usable_time", "required_seconds",
		"deficit_seconds", "footwork_meters",
	]:
		print("  %-18s home %7.3f   opponent %7.3f" % [
			key, _mean(terms["home"], key), _mean(terms["opponent"], key),
		])
	print("")
	print("deficit_seconds, bucketed. If the middle buckets are empty the close")
	print("is binary because its input is, and no constant in the block model can")
	print("change that.")
	print("")
	print("%-10s %8s %10s %12s %12s %10s" % [
		"side", "n", "<= 0", "0 to 0.225", "0.225 to .45", "> 0.45"])
	for side in ["home", "opponent"]:
		var pool: Array = terms[side]
		if pool.is_empty():
			continue
		var buckets := [0, 0, 0, 0]
		for row in pool:
			var value := float(Dictionary(row).get("deficit_seconds", 0.0))
			if value <= 0.0:
				buckets[0] += 1
			elif value <= 0.225:
				buckets[1] += 1
			elif value <= 0.45:
				buckets[2] += 1
			else:
				buckets[3] += 1
		print("%-10s %8d %10d %12d %12d %10d" % [
			side, pool.size(), buckets[0], buckets[1], buckets[2], buckets[3]])
	print("")
	for side in ["home", "opponent"]:
		var total: int = (assist[side] as Array).size()
		print("  %-9s assist present on %d of %d blocks (%.0f%%)" % [
			side, int(has_assist[side]), total,
			float(has_assist[side]) / maxf(float(total), 1.0) * 100.0,
		])
	quit()


func _mean(pool: Array, key: String) -> float:
	if pool.is_empty():
		return 0.0
	var total := 0.0
	for row in pool:
		total += float(Dictionary(row).get(key, 0.0))
	return total / float(pool.size())


func _report(label: String, pools: Dictionary) -> void:
	print("%-14s %6s %8s %8s %8s %8s %8s %11s" % [
		label, "n", "p10", "p25", "p50", "p75", "p90", "below gate"])
	for side in ["home", "opponent"]:
		var pool: Array = pools[side]
		if pool.is_empty():
			print("%-14s (none)" % side)
			continue
		pool.sort()
		var below := 0
		for value in pool:
			if float(value) < Promotion.WALL_JOIN_CLOSE:
				below += 1
		print("%-14s %6d %8.3f %8.3f %8.3f %8.3f %8.3f %10.0f%%" % [
			side, pool.size(), _p(pool, 0.10), _p(pool, 0.25), _p(pool, 0.50),
			_p(pool, 0.75), _p(pool, 0.90),
			float(below) / float(pool.size()) * 100.0])


func _p(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(
		int(round(fraction * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1)])
