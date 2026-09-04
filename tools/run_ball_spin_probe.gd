extends SceneTree

## Does the resolved spin vary enough to be worth drawing?
##
##     godot --headless --path . --script res://tools/run_ball_spin_probe.gd
##
## `docs/FAILURE_MODES.md` section 0 says measure the distribution before
## shipping the thing that acts on it, and nobody has ever measured this one.
## `BallSpin` has resolved `axis` and `rate_rps` since it was written, and until
## `_stamp_spin` only `launch_gravity_mps2` ever left the resolver -- so a
## topspin serve and a float have been indistinguishable to everything
## downstream, and three of the proposed ball treatments depict rotation.
##
## Two questions, and a treatment dies on either answer:
##
##   rate   if the spread is narrow, a band frequency keyed to it carries no
##          information and a ribbon is a caption with extra steps
##   axis   `from_serve` hardcodes a handedness lean of +/-0.18 and only a swing
##          across the body moves it further. If nothing ever leaves that lean,
##          there is no sidespin in this game and the skew treatment is dead
##          whatever the camera angle
##
## Reads `outgoing_trajectory.launch_spin`. A family that reports `no_spin` is
## one that produces none at all -- which for a set or a dig is the correct
## answer rather than a gap.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 150

## `BallSpin.FLOAT_RATE_RPS`. At or under this the ball is a float and has no
## rotation to draw, which is a treatment rather than an absence.
const FLOAT_RATE_RPS: float = 0.75
## The lean `from_serve` puts on every topspin serve. Past it, a swing actually
## cut across the ball.
const HANDEDNESS_LEAN: float = 0.18


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var families := {}
	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		manager.match_state.serving_home = (seed_value % 2) == 0
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		for event in result.events:
			var flight: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if flight.is_empty():
				continue
			var name := str(
				RallyEventScript.EventType.keys()[int(event.event_type)]
			)
			var row: Dictionary = families.get(name, _row())
			var spin: Dictionary = flight.get("launch_spin", {})
			if spin.is_empty():
				row["no_spin"] = int(row.no_spin) + 1
				families[name] = row
				continue
			var rate := float(spin.get("rate_rps", 0.0))
			var axis := float(spin.get("axis", 0.0))
			row["n"] = int(row.n) + 1
			row["rate_min"] = minf(float(row.rate_min), rate)
			row["rate_max"] = maxf(float(row.rate_max), rate)
			row["axis_min"] = minf(float(row.axis_min), axis)
			row["axis_max"] = maxf(float(row.axis_max), axis)
			row["gravity"] = float(row.gravity) \
				+ float(flight.get("launch_gravity_mps2", 0.0))
			if rate <= FLOAT_RATE_RPS:
				row["floats"] = int(row.floats) + 1
			if absf(axis) > HANDEDNESS_LEAN + 0.001:
				row["cut_across"] = int(row.cut_across) + 1
			Array(row.rates).append(rate)
			Array(row.axes).append(absf(axis))
			families[name] = row
	print("family|n|no_spin|mean_rps|min|p10|p50|p90|max"
		+ "|mean_abs_axis|axis_min|axis_max|floats|cut_across|mean_gravity")
	var keys: Array = families.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = families[key]
		if int(b.n) == 0:
			print("%s|0|%d|-|-|-|-|-|-|-|-|-|-|-|-" % [key, int(b.no_spin)])
			continue
		var rates: Array = b.rates
		var axes: Array = b.axes
		rates.sort()
		var n := float(b.n)
		print("%s|%d|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.3f|%.3f|%.3f|%d|%d|%.2f" % [
			key, int(b.n), int(b.no_spin),
			_mean(rates), float(b.rate_min),
			_percentile(rates, 0.10), _percentile(rates, 0.50),
			_percentile(rates, 0.90), float(b.rate_max),
			_mean(axes), float(b.axis_min), float(b.axis_max),
			int(b.floats), int(b.cut_across), float(b.gravity) / n,
		])
	quit()


func _row() -> Dictionary:
	return {
		"n": 0, "no_spin": 0, "rate_min": INF, "rate_max": -INF,
		"axis_min": INF, "axis_max": -INF, "gravity": 0.0,
		"floats": 0, "cut_across": 0, "rates": [], "axes": [],
	}


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(clampf(
		round(fraction * float(sorted_values.size() - 1)),
		0.0, float(sorted_values.size() - 1),
	))
	return float(sorted_values[index])
