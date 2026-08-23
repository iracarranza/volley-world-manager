extends SceneTree

## Is the defensive shape merely wide, or does it have a hole in it?
##
## The opponent's shape spans 6.05 m of a 9 m court against the home side's
## 5.18 m, and the balls it concedes arrive at x = 0.498 -- dead centre. Width
## alone does not decide anything: six defenders spread evenly across 6 m cover
## the middle better than five bunched into 5 m and one stranded wide.
##
## What separates the two is the *straddle gap* -- the lateral distance between
## the nearest defender left of the ball and the nearest defender right of it. A
## shape that is wide but even has small straddle gaps everywhere. A shape with a
## hole has a large one exactly where the ball keeps going.
##
## Reported split by whether the dig came up, because a hole only matters if the
## balls that beat the defence are the ones falling into it.
##
## Run:
##   godot --headless --path . --script res://tools/run_straddle_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var gap := {}
	var offset := {}
	var outside := {}
	var seen := {}
	for side in ["home", "opponent"]:
		gap[side] = {true: [], false: []}
		offset[side] = {true: [], false: []}
		outside[side] = {true: 0, false: 0}
		seen[side] = {true: 0, false: 0}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.DIG:
					continue
				var side := str(event.metadata.get("side", ""))
				if not gap.has(side):
					continue
				var targets: Dictionary = event.metadata.get(
					"home_phase_targets" if side == "home"
					else "opponent_phase_targets", {}
				)
				if targets.is_empty():
					continue
				var dug := event.success
				var ball_x: float = event.start_position.x
				seen[side][dug] = int(seen[side][dug]) + 1
				## Nearest body either side of the ball's lane.
				var left := -1.0
				var right := 2.0
				for id in targets:
					var x: float = Vector2(targets[id]).x
					if x <= ball_x:
						left = maxf(left, x)
					else:
						right = minf(right, x)
				if left < 0.0 or right > 1.0:
					## The ball is outside the shape entirely -- nobody on one
					## side of it. That is not a gap, it is a flank.
					outside[side][dug] = int(outside[side][dug]) + 1
					continue
				gap[side][dug].append((right - left) * CourtConstants.COURT_WIDTH_METERS)
				offset[side][dug].append(
					minf(ball_x - left, right - ball_x)
						* CourtConstants.COURT_WIDTH_METERS
				)
	manager.free()

	print("Straddle -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("%-10s %-6s %6s %12s %14s %10s" % [
		"side", "dug", "n", "straddle gap", "to nearer edge", "outside"])
	for side in ["home", "opponent"]:
		for dug in [true, false]:
			print("%-10s %-6s %6d %12.2f %14.2f %10d" % [
				side, "yes" if dug else "no", int(seen[side][dug]),
				_m(gap[side][dug]), _m(offset[side][dug]),
				int(outside[side][dug])])
	print("")
	print("`straddle gap` is metres between the two defenders either side of the")
	print("ball's lane; `to nearer edge` is how far the ball sat from the closer of")
	print("them. A failure row with a wide gap and the ball near its middle is a")
	print("hole. `outside` counts balls with nobody on one flank at all.")
	quit()


func _m(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
