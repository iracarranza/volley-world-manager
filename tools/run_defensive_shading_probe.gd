extends SceneTree

## Does each side's defensive shape move with the attack it is facing?
##
## The opponent's closest defender is 0.30 m further from the ball than the home
## side's closest, while both claimants pick near-optimally and the balls the
## opponent covers land *more centrally*. Aggregate depth and lateral spread are
## similar between the sides, so the shape is not wrong in bulk -- which leaves
## the question of whether it is *aimed*.
##
## A symmetric shape and a targeted shape have identical means. What separates
## them is the slope: how far the shape's centroid moves per metre the attack
## moves. A shape that shades has a positive slope; one staged the same way
## regardless of where the ball is coming from has a slope near zero.
##
## Run:
##   godot --headless --path . --script res://tools/run_defensive_shading_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var lane := {"home": [], "opponent": []}
	var centre := {"home": [], "opponent": []}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var last_attack_x := -1.0
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null:
					continue
				if event.event_type == RallyEventScript.EventType.ATTACK:
					last_attack_x = event.start_position.x
					continue
				if event.event_type != RallyEventScript.EventType.DEFENSE \
						or last_attack_x < 0.0:
					continue
				var side := str(event.metadata.get("side", ""))
				if not lane.has(side):
					continue
				var targets: Dictionary = event.metadata.get(
					"home_phase_targets" if side == "home"
					else "opponent_phase_targets", {}
				)
				if targets.is_empty():
					continue
				var total := 0.0
				for id in targets:
					total += Vector2(targets[id]).x
				lane[side].append(last_attack_x)
				centre[side].append(total / float(targets.size()))
	manager.free()

	print("Defensive shading -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("%-10s %6s %10s %12s %10s" % [
		"side", "n", "lane sd", "centroid sd", "slope"])
	for side in ["home", "opponent"]:
		var l: Array = lane[side]
		var c: Array = centre[side]
		if l.size() < 3:
			print("%-10s (too few samples)" % side)
			continue
		print("%-10s %6d %10.3f %12.3f %10.3f" % [
			side, l.size(), _sd(l), _sd(c), _slope(l, c)])
	print("")
	print("Slope is metres of centroid per metre of attack lane, both in")
	print("normalised court x. A shape that shades the attack reads positive; one")
	print("staged the same way whatever it faces reads near zero, and its centroid")
	print("standard deviation collapses with it.")
	quit()


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _sd(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var m := _mean(values)
	var total := 0.0
	for value in values:
		total += pow(float(value) - m, 2.0)
	return sqrt(total / float(values.size()))


## Least-squares slope of y on x.
func _slope(x: Array, y: Array) -> float:
	var mx := _mean(x)
	var my := _mean(y)
	var cov := 0.0
	var varx := 0.0
	for index in range(x.size()):
		var dx := float(x[index]) - mx
		cov += dx * (float(y[index]) - my)
		varx += dx * dx
	if varx < 0.000001:
		return 0.0
	return cov / varx
