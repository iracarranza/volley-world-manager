extends SceneTree

## Is the defence standing too deep for the balls that beat it?
##
## Aggregate start depth and landing depth are close on both sides, which says
## nothing -- a defence that covers deep balls well and short balls not at all
## averages out to "about right". What separates the two is splitting the balls
## each side faces by whether the dig came up.
##
## If failures land systematically shorter than successes, the shape is too deep
## for the shots that are actually beating it, and that is a positioning fix. If
## failures land at the same depth as successes, depth is not the axis and the
## problem is lateral, temporal, or in the contest itself.
##
## Run:
##   godot --headless --path . --script res://tools/run_defensive_depth_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")
const RallyKinematicsScript := preload("res://scripts/simulation/rally_kinematics.gd")

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	## side -> dug -> samples
	var depth := {}
	var travel := {}
	var start_depth := {}
	for side in ["home", "opponent"]:
		depth[side] = {true: [], false: []}
		travel[side] = {true: [], false: []}
		start_depth[side] = {true: [], false: []}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.DEFENSE:
					continue
				var side := str(event.metadata.get("side", ""))
				if not depth.has(side) or not event.metadata.has("movement_start"):
					continue
				var dug := event.success
				var ball: Vector2 = event.start_position
				var start: Vector2 = event.metadata["movement_start"]
				depth[side][dug].append(
					absf(ball.y - CourtConstants.NET_Y)
						* CourtConstants.COURT_LENGTH_METERS
				)
				start_depth[side][dug].append(
					absf(start.y - CourtConstants.NET_Y)
						* CourtConstants.COURT_LENGTH_METERS
				)
				travel[side][dug].append(
					RallyKinematicsScript.court_distance_meters(start, ball)
				)
	manager.free()

	print("Defensive depth -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("%-10s %-8s %6s %12s %12s %10s" % [
		"side", "dug", "n", "ball depth", "stood at", "travel"])
	for side in ["home", "opponent"]:
		for dug in [true, false]:
			var d: Array = depth[side][dug]
			print("%-10s %-8s %6d %12.2f %12.2f %10.2f" % [
				side, "yes" if dug else "no", d.size(),
				_m(d), _m(start_depth[side][dug]), _m(travel[side][dug])])
	print("")
	print("`ball depth` and `stood at` are metres from the net. A failure row that")
	print("is shorter than its success row means the shape is too deep for what is")
	print("beating it. A failure row that is *deeper* means the opposite, and a")
	print("failure row at the same depth means depth is not the axis at all.")
	quit()


func _m(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
