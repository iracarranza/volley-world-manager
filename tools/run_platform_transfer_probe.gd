extends SceneTree

## M4 slice 2, first half: **what does the current platform contact actually
## produce, in the units section 6 uses?**
##
##     godot --headless --path . --script res://tools/run_platform_transfer_probe.gd
##
## `PLATFORM_CONTACT.md` section 11 asks slice 2 to measure "outgoing speed,
## vertical, apex, destination error" and then to say how often the ball the
## current model produces lies outside the envelope the shadow says was available.
## The second question needs T1 and T2, which are unauthored. **The first does
## not**, and it is the one that has to come first: T1 relates incoming speed to
## outgoing speed, and nobody has looked at what the shipped model does with
## incoming speed at all.
##
## So this probe authors nothing. It reads the two shipped resolvers' own
## published output and converts it into section 6's contract:
##
##     outgoing_vertical_mps  = sqrt(2 g * apex_rise)      -- the rise is published
##     outgoing_horizontal    = court distance / duration  -- both published
##     outgoing_speed_mps     = hypot of the two
##
## and puts it beside `incoming_speed_mps`, which both resolvers already publish
## and which the probe therefore does not have to reconstruct.
##
## **The sharp question is the last table.** Section 11 predicts the bands may be
## fiction. The falsifiable form of that, in T1's own units, is: does the outgoing
## ball carry *any* information about how hard the incoming ball arrived?

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const BallFlight := preload("res://scripts/simulation/ball_flight_model.gd")

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	var rows := _sweep()
	_by_family(rows)
	_by_posture(rows)
	_incoming_against_outgoing(rows)
	_coverage(rows)
	quit()


func _sweep() -> Array:
	var rows: Array = []
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally == null:
				manager.free()
				continue
			for entry in rally.events:
				var event := entry as RallyEvent
				if event == null:
					continue
				var family := ""
				match event.event_type:
					RallyEventScript.EventType.RECEPTION: family = "reception"
					RallyEventScript.EventType.DIG: family = "dig"
					RallyEventScript.EventType.ATTACK_COVERAGE:
						family = "coverage"
					_:
						continue
				var row := _row(event, family)
				if not row.is_empty():
					rows.append(row)
			manager.free()
	return rows


## One platform contact, converted into section 6's contract from what the event
## already publishes. Nothing here is authored; every term is read.
func _row(event: RallyEvent, family: String) -> Dictionary:
	var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
	if outgoing.is_empty():
		## A contact that never controlled the ball has no outgoing flight, and
		## stamping one on a miss is the event-truth corruption the resolvers
		## deliberately avoid. Those rows are not measurable and are not counted.
		return {}
	var rise := float(outgoing.get("apex_rise_meters", outgoing.get(
		"apex_height_meters", 0.0
	)))
	## `duration`, which is what `BallTrajectory.to_dict()` publishes. The first
	## draft read `duration_seconds` -- the key `_truncated_arc` uses internally
	## -- found nothing on every flight, and reported **zero measurable contacts**
	## over 600 rallies. A probe that reads a key nobody writes returns an empty
	## population, and an empty population reads exactly like a finding.
	var duration := float(outgoing.get("duration", 0.0))
	if duration <= 0.0001:
		return {}
	var start := Vector2(outgoing.get("start_position", Vector2.ZERO))
	var end := Vector2(outgoing.get("end_position", start))
	var horizontal_meters := Vector2(
		(end.x - start.x) * COURT_WIDTH_METERS,
		(end.y - start.y) * COURT_LENGTH_METERS,
	).length()
	var vertical := sqrt(2.0 * BallFlight.DEFAULT_GRAVITY_MPS2 * maxf(rise, 0.0))
	var horizontal := horizontal_meters / duration
	return {
		"family": family,
		"posture": str(event.metadata.get("contact_posture", "unstated")),
		"incoming": float(event.metadata.get("incoming_speed_mps", -1.0)),
		"vertical": vertical,
		"horizontal": horizontal,
		"speed": sqrt(vertical * vertical + horizontal * horizontal),
		"apex_rise": rise,
		"duration": duration,
		"distance": horizontal_meters,
		"target_error": float(event.metadata.get("target_error_meters", -1.0)),
	}


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "min": 0.0, "p50": 0.0, "max": 0.0, "mean": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {
		"n": sorted.size(),
		"min": float(sorted[0]),
		"p50": float(sorted[sorted.size() / 2]),
		"max": float(sorted[sorted.size() - 1]),
		"mean": total / sorted.size(),
	}


func _column(rows: Array, key: String) -> Array:
	var values: Array = []
	for row in rows:
		values.append(float(row[key]))
	return values


func _families(rows: Array) -> Array:
	var seen := {}
	for row in rows:
		seen[str(row["family"])] = true
	var names: Array = seen.keys()
	names.sort()
	return names


## ------------------------------------------------------------------ part one
func _by_family(rows: Array) -> void:
	print("=".repeat(78))
	print("PART 1 -- the shipped ball, in section 6's units")
	print("=".repeat(78))
	print("  %d controlled platform contacts over %d rallies.\n" % [
		rows.size(), RALLIES_PER_SERVER * 2,
	])
	for family in _families(rows):
		var subset: Array = rows.filter(func(row): return row["family"] == family)
		print("  %s -- %d contacts" % [family, subset.size()])
		print("    %-22s %-9s %-9s %-9s %-9s" % [
			"quantity", "min", "p50", "max", "mean",
		])
		for entry in [
			["outgoing speed m/s", "speed"],
			["  vertical m/s", "vertical"],
			["  horizontal m/s", "horizontal"],
			["apex rise m", "apex_rise"],
			["flight duration s", "duration"],
			["pass distance m", "distance"],
		]:
			var stats := _stats(_column(subset, str(entry[1])))
			print("    %-22s %-9.3f %-9.3f %-9.3f %-9.3f" % [
				str(entry[0]), stats.min, stats.p50, stats.max, stats.mean,
			])
		var errors: Array = []
		for row in subset:
			if float(row["target_error"]) >= 0.0:
				errors.append(float(row["target_error"]))
		if errors.is_empty():
			print("    %-22s %s" % ["destination error m", "not published"])
		else:
			var error_stats := _stats(errors)
			print("    %-22s %-9.3f %-9.3f %-9.3f %-9.3f  (n=%d)" % [
				"destination error m", error_stats.min, error_stats.p50,
				error_stats.max, error_stats.mean, error_stats.n,
			])
		print("")


## ------------------------------------------------------------------ part two
func _by_posture(rows: Array) -> void:
	print("=".repeat(78))
	print("PART 2 -- and how it varies with the circumstance it was made in")
	print("=".repeat(78))
	print("  Posture is section 4's own circumstance variable, and it is the one")
	print("  the shipped bands do read -- through `execution` and `spoil`. So this")
	print("  table should show real spread, and its width is the range any")
	print("  replacement has to be able to reproduce.\n")
	var buckets := {}
	for row in rows:
		var key := "%s / %s" % [row["family"], row["posture"]]
		var bucket: Array = buckets.get(key, [])
		bucket.append(row)
		buckets[key] = bucket
	var keys: Array = buckets.keys()
	keys.sort()
	print("  %-30s %-7s %-11s %-11s %-11s" % [
		"family / posture", "n", "speed p50", "vertical p50", "rise p50",
	])
	for key in keys:
		var subset: Array = buckets[key]
		print("  %-30s %-7d %-11.3f %-11.3f %-11.3f" % [
			key, subset.size(),
			_stats(_column(subset, "speed")).p50,
			_stats(_column(subset, "vertical")).p50,
			_stats(_column(subset, "apex_rise")).p50,
		])


## ---------------------------------------------------------------- part three
##
## T1's own question, asked of the shipped model. If the answer is "none", the
## relation slice 3 has to author is not a refinement of what is there -- it is a
## channel that does not exist.
func _incoming_against_outgoing(rows: Array) -> void:
	print("\n" + "=".repeat(78))
	print("PART 3 -- does the outgoing ball know how hard the incoming one was?")
	print("=".repeat(78))
	var measurable: Array = rows.filter(
		func(row): return float(row["incoming"]) > 0.0
	)
	print("  %d of %d contacts publish an incoming speed." % [
		measurable.size(), rows.size(),
	])
	if measurable.is_empty():
		print("  Nothing to correlate; the input T1 relates from is not recorded.")
		return
	var incoming := _stats(_column(measurable, "incoming"))
	print("  Incoming speed spans %.2f to %.2f m/s (p50 %.2f), so the *input*" % [
		incoming.min, incoming.max, incoming.p50,
	])
	print("  genuinely varies -- this is not a flat predictor being asked to")
	print("  explain a varying output.\n")
	for family in _families(measurable):
		var subset: Array = measurable.filter(
			func(row): return row["family"] == family
		)
		if subset.size() < 12:
			continue
		print("  %s -- %d contacts, split into incoming-speed quartiles" % [
			family, subset.size(),
		])
		var sorted_rows := subset.duplicate()
		sorted_rows.sort_custom(
			func(a, b): return float(a["incoming"]) < float(b["incoming"])
		)
		var quarter := sorted_rows.size() / 4
		print("    %-20s %-13s %-13s %-13s" % [
			"incoming quartile", "incoming p50", "outgoing p50", "vertical p50",
		])
		for index in range(4):
			var start_index := index * quarter
			var end_index := sorted_rows.size() if index == 3 \
				else (index + 1) * quarter
			var slice_rows: Array = sorted_rows.slice(start_index, end_index)
			if slice_rows.is_empty():
				continue
			print("    %-20s %-13.3f %-13.3f %-13.3f" % [
				"Q%d" % (index + 1),
				_stats(_column(slice_rows, "incoming")).p50,
				_stats(_column(slice_rows, "speed")).p50,
				_stats(_column(slice_rows, "vertical")).p50,
			])
		print("    correlation(incoming, outgoing speed)    r = %+.4f" % _pearson(
			_column(subset, "incoming"), _column(subset, "speed")
		))
		## **Decomposed, because the total is misleading on its own.** Outgoing
		## speed is the hypotenuse of a vertical the apex band sets and a
		## horizontal that is `distance / duration` -- so a *shorter* flight
		## raises the total without any speed having been retained. Correlating
		## only the hypotenuse cannot tell a transfer relation from a duration
		## artefact, and on the reception it does not.
		print("    correlation(incoming, outgoing vertical) r = %+.4f" % _pearson(
			_column(subset, "incoming"), _column(subset, "vertical")
		))
		print("    correlation(incoming, horizontal)        r = %+.4f" % _pearson(
			_column(subset, "incoming"), _column(subset, "horizontal")
		))
		print("    correlation(incoming, flight duration)   r = %+.4f" % _pearson(
			_column(subset, "incoming"), _column(subset, "duration")
		))
		print("    correlation(incoming, pass distance)     r = %+.4f" % _pearson(
			_column(subset, "incoming"), _column(subset, "distance")
		))
		print("")
	print("  Read the quartile columns before the r. A correlation near zero with")
	print("  a flat quartile ladder is one finding -- the incoming ball reaches")
	print("  nothing. A correlation near zero with a *moving* ladder would be a")
	print("  non-monotonic relation, which is a different problem entirely.")
	print("")
	print("  And read the decomposition before believing a large r. Only the")
	print("  vertical row can carry a transfer relation, because it is the only")
	print("  component the contact model sets; the horizontal row is geometry")
	print("  divided by a duration the vertical already decided.")


## ----------------------------------------------------------------- part four
##
## Split out because it is not a distribution, it is a single value repeated.
func _coverage(rows: Array) -> void:
	print("\n" + "=".repeat(78))
	print("PART 4 -- coverage does not produce a ball, it produces a drawing")
	print("=".repeat(78))
	var subset: Array = rows.filter(func(row): return row["family"] == "coverage")
	if subset.is_empty():
		print("  No coverage contacts in this population.")
		return
	var speed := _stats(_column(subset, "speed"))
	var rise := _stats(_column(subset, "apex_rise"))
	var duration := _stats(_column(subset, "duration"))
	var distance := _stats(_column(subset, "distance"))
	print("  %d coverage contacts, and every column is min == p50 == max:\n" % [
		subset.size(),
	])
	print("    outgoing speed   %.3f .. %.3f m/s" % [speed.min, speed.max])
	print("    apex rise        %.3f .. %.3f m" % [rise.min, rise.max])
	print("    flight duration  %.3f .. %.3f s" % [duration.min, duration.max])
	print("    pass distance    %.3f .. %.3f m" % [distance.min, distance.max])
	print("")
	print("  Traced rather than inferred: no coverage site calls a pass resolver.")
	print("  The three `ATTACK_COVERAGE` events publish no `outgoing_trajectory`,")
	print("  so the flight is stamped by the end-of-rally display fallback, whose")
	print("  own arm reads `flight_time = 0.58` and `apex = 1.8` for this type.")
	print("  The distance is fixed too -- the coverage target is `contact` plus a")
	print("  literal (0.04, 0.05), which is 0.969 m on every one of them.")
	print("")
	print("  So section 4's line that coverage's missing state is class B rather")
	print("  than C understates it. The state is derivable, yes -- but there is")
	print("  also nothing downstream to give it to, because coverage has no")
	print("  contact model at all. **This is the cheapest real physics in M4**:")
	print("  it is the only context where promoting a resolver replaces a")
	print("  constant rather than a calibrated band, so nothing has to be shown")
	print("  to be worse than what it replaces.")


func _pearson(xs: Array, ys: Array) -> float:
	if xs.size() != ys.size() or xs.size() < 2:
		return 0.0
	var mean_x := 0.0
	var mean_y := 0.0
	for index in range(xs.size()):
		mean_x += float(xs[index])
		mean_y += float(ys[index])
	mean_x /= xs.size()
	mean_y /= ys.size()
	var covariance := 0.0
	var variance_x := 0.0
	var variance_y := 0.0
	for index in range(xs.size()):
		var dx := float(xs[index]) - mean_x
		var dy := float(ys[index]) - mean_y
		covariance += dx * dy
		variance_x += dx * dx
		variance_y += dy * dy
	if variance_x <= 0.0 or variance_y <= 0.0:
		return 0.0
	return covariance / sqrt(variance_x * variance_y)
