extends SceneTree

## What the wall a swing is hit into actually measures.
##
## `GeometricAttackPromotionModel.block_wall` builds each blocker as three
## numbers -- where their hands are on the net, how high they reach, and how much
## net they seal. The third is
##
##     half_width_m = BLOCKER_HALF_WIDTH_METERS * width_scale * close
##
## and that last factor is a modelling claim worth checking: it says a blocker who
## closed the seam badly is physically *narrower*. Hands span what they span. A
## poor close should leave a blocker in the wrong place, not shrink them.
##
## So this reports the close distribution and the half-widths it produces, against
## the span a pair of blocking hands actually covers. A body dimension scaled by an
## effort fraction is the same defect as a threshold set outside its distribution:
## a number that cannot be read as the thing it is named after.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_wall_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const PromotionScript := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150


func _initialize() -> void:
	var closes: Array = []
	var wall_sizes := {}
	for roster_seed in ROSTER_SEEDS:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
		ExecutionScale.apply_generated_attributes(
			manager.opponent_team.players, roster_seed
		)
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
					var primary := float(event.metadata.get("primary_close", 0.0))
					var assist := float(event.metadata.get("assist_close", 0.0))
					closes.append(primary)
					var joined := 0
					if primary >= PromotionScript.WALL_JOIN_CLOSE:
						joined += 1
					if int(event.metadata.get("assist_id", -1)) >= 0:
						closes.append(assist)
						if assist >= PromotionScript.WALL_JOIN_CLOSE:
							joined += 1
					wall_sizes[joined] = int(wall_sizes.get(joined, 0)) + 1
		manager.free()

	closes.sort()
	print("Block wall -- %d rosters x %d rallies x 2 serving sides, home blocks"
		% [ROSTER_SEEDS.size(), RALLIES])
	print("")
	print("close fraction, per blocker asked to join the wall (n=%d)" % closes.size())
	print("   p10 %.3f  p25 %.3f  p50 %.3f  p75 %.3f  p90 %.3f" % [
		_percentile(closes, 0.10), _percentile(closes, 0.25),
		_percentile(closes, 0.50), _percentile(closes, 0.75),
		_percentile(closes, 0.90),
	])
	var joins := 0
	for value in closes:
		if float(value) >= PromotionScript.WALL_JOIN_CLOSE:
			joins += 1
	print("   at or above WALL_JOIN_CLOSE (%.2f): %d of %d" % [
		PromotionScript.WALL_JOIN_CLOSE, joins, closes.size(),
	])
	print("")
	print("half-width in metres, as the wall is built today (const %.2f x close)"
		% PromotionScript.BLOCKER_HALF_WIDTH_METERS)
	var widths: Array = []
	for value in closes:
		if float(value) < PromotionScript.WALL_JOIN_CLOSE:
			continue
		widths.append(PromotionScript.BLOCKER_HALF_WIDTH_METERS * float(value))
	widths.sort()
	print("   p10 %.3f  p25 %.3f  p50 %.3f  p75 %.3f  p90 %.3f   (n=%d)" % [
		_percentile(widths, 0.10), _percentile(widths, 0.25),
		_percentile(widths, 0.50), _percentile(widths, 0.75),
		_percentile(widths, 0.90), widths.size(),
	])
	print("")
	print("   For scale: a pair of blocking hands spans roughly 0.55-0.60 m outer")
	print("   edge to outer edge, and a ball whose centre passes within its own")
	print("   radius (0.105 m) of that edge still touches. So the half-width a")
	print("   fully committed blocker presents is about 0.38-0.41 m -- and it does")
	print("   not shrink when they close the seam late.")
	print("")
	print("wall size actually built")
	for size in [0, 1, 2]:
		print("   %d blocker(s): %d" % [size, int(wall_sizes.get(size, 0))])
	quit()


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
