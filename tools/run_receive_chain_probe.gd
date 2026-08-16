extends SceneTree

## Is the realized serve ball authoritative all the way to one outgoing pass?
##
##     godot --headless --path . --script res://tools/run_receive_chain_probe.gd
##
## Walks the leg immediately after the certified serve:
##
##     authoritative serve -> choose receiver -> ball-timed movement/read
##     -> realized reception -> quality/playability -> ONE pass
##
## **Reads published facts rather than recomputing them.** Every quantity below
## is already on the reception event, which is the point: a probe that re-derives
## the receiver's movement from positions would be a second opinion about the
## thing it is auditing. The one exception is stated where it happens.
##
## Isolated rallies, a fresh `GameManager` per seed, so one divergence cannot
## cascade into the next.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 52000
const SEED_COUNT: int = 500

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	_controlled_gates()
	var rows: Array[String] = []
	rows.append(
		"side|seed|serving_home|receiver|success|quality|serve_seconds"
		+ "|start_distance_m|reach_shortfall_m|move_seconds|reach_margin_m"
		+ "|set_contact_h|pass_apex|pass_end_x|pass_end_y|pass_duration"
	)
	var counts := {
		"rallies": 0, "serve_events": 0, "serve_errors": 0,
		"receptions": 0, "playable": 0, "unplayable": 0,
		"reception_after_error": 0,
		"height_from_pass": 0, "height_fallback": 0,
		"no_reach_margin": 0, "no_outgoing": 0,
		"home_points": 0,
	}
	var quality_total := 0.0
	var serve_seconds_total := 0.0
	var start_distance_total := 0.0
	var shortfall_total := 0.0
	var shortfall_nonzero := 0
	var outcomes := {}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			counts["rallies"] = int(counts.rallies) + 1
			if rally != null:
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				if bool(rally.home_team_won):
					counts["home_points"] = int(counts.home_points) + 1
				var serve_failed := false
				for event in rally.events:
					var kind := int(event.event_type)
					if kind == RallyEventScript.EventType.SERVE:
						counts["serve_events"] = int(counts.serve_events) + 1
						if not bool(event.success):
							counts["serve_errors"] = int(counts.serve_errors) + 1
							serve_failed = true
						continue
					if kind != RallyEventScript.EventType.RECEPTION:
						continue
					## **Gate 3, observed rather than asserted.** A reception event
					## after a failed serve would mean the OUT short-circuit leaked.
					if serve_failed:
						counts["reception_after_error"] = \
							int(counts.reception_after_error) + 1
					var row := _read_reception(
						event, seed_value, serving_home, counts
					)
					rows.append(str(row.line))
					quality_total += float(row.quality)
					serve_seconds_total += float(row.serve_seconds)
					start_distance_total += float(row.start_distance)
					if float(row.shortfall) > 0.001:
						shortfall_nonzero += 1
						shortfall_total += float(row.shortfall)
			manager.free()

	var path := "user://receive_chain.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()

	var receptions := maxf(float(counts.receptions), 1.0)
	print("=".repeat(78))
	print("RECEIVE CHAIN -- %d isolated rallies per side" % SEED_COUNT)
	print("=".repeat(78))
	print("\n  SERVE")
	print("      serve events %d, errors %d (%.4f), in %d" % [
		int(counts.serve_events), int(counts.serve_errors),
		float(counts.serve_errors) / maxf(float(counts.serve_events), 1.0),
		int(counts.serve_events) - int(counts.serve_errors),
	])
	print("      receptions after a failed serve: %d   <- must be 0"
		% int(counts.reception_after_error))

	print("\n  RECEPTION")
	print("      receptions %d, playable %d (%.4f), unplayable %d" % [
		int(counts.receptions), int(counts.playable),
		float(counts.playable) / receptions, int(counts.unplayable),
	])
	print("      mean quality %.4f" % (quality_total / receptions))
	print("      mean serve flight %.4f s  (the response window)"
		% (serve_seconds_total / receptions))
	print("      mean start distance %.4f m" % (start_distance_total / receptions))
	print("      receptions the receiver did not fully reach: %d (%.4f), mean shortfall %.4f m"
		% [shortfall_nonzero, float(shortfall_nonzero) / receptions,
			shortfall_total / maxf(float(shortfall_nonzero), 1.0)])

	print("\n  ONE PASS -- does the realized reception own what the setter reads?")
	print("      set contact height from the pass   %d (%.4f)" % [
		int(counts.height_from_pass),
		float(counts.height_from_pass) / receptions,
	])
	print("      set contact height ABSENT          %d (%.4f)  <- setter falls back" % [
		int(counts.height_fallback),
		float(counts.height_fallback) / receptions,
	])
	print("      reach margin absent                %d (%.4f)" % [
		int(counts.no_reach_margin),
		float(counts.no_reach_margin) / receptions,
	])
	print("      outgoing trajectory absent         %d (%.4f)" % [
		int(counts.no_outgoing), float(counts.no_outgoing) / receptions,
	])

	print("\n  RALLY OUTCOMES  (regression observation, not a target)")
	print("      home points %d of %d (%.4f)" % [
		int(counts.home_points), int(counts.rallies),
		float(counts.home_points) / maxf(float(counts.rallies), 1.0),
	])
	var names: Array = outcomes.keys()
	names.sort()
	for name in names:
		print("      %-28s %-5d %.4f" % [
			name, int(outcomes[name]),
			float(outcomes[name]) / maxf(float(counts.rallies), 1.0),
		])
	print("\nwrote %s (%d rows)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1])
	quit()


## Gates 1 and 2, controlled rather than inferred.
##
## The census above shows a correlation between flight time and shortfall; that
## is not the same as showing the ball's clock *causes* the movement bound. These
## drive `_reached_point` directly with one variable moving at a time.
func _controlled_gates() -> void:
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 7777
	var receiver := VolleyballPlayer.new()
	var target := Vector2(0.25, 0.30)

	print("=".repeat(78))
	print("CONTROLLED GATES")
	print("=".repeat(78))
	print("\n  GATE 1 -- same receiver and start, faster vs slower serve")
	print("      the ball's own flight is the window; nothing else changes")
	print("      %-10s %-14s %-14s" % ["seconds", "reached_m", "shortfall_m"])
	var start := Vector2(0.62, 0.62)
	var wanted := _metres(start, target)
	for seconds in [0.60, 0.90, 1.20, 1.60, 2.20]:
		var reached: Vector2 = simulator._reached_point(
			receiver, start, target, seconds, "lateral", 0.0
		)
		print("      %-10.2f %-14.4f %-14.4f" % [
			seconds, wanted - _metres(reached, target), _metres(reached, target),
		])
	print("      required trip %.4f m" % wanted)

	print("\n  GATE 2 -- same serve, receiver nearer vs farther")
	print("      required movement changes; the ball's flight time does not")
	print("      %-12s %-14s %-14s" % ["start_dist_m", "reached_m", "shortfall_m"])
	for offset in [0.02, 0.08, 0.16, 0.26, 0.38]:
		var near := Vector2(target.x + offset, target.y + offset)
		var required := _metres(near, target)
		var reached: Vector2 = simulator._reached_point(
			receiver, near, target, 1.20, "lateral", 0.0
		)
		print("      %-12.4f %-14.4f %-14.4f" % [
			required, required - _metres(reached, target), _metres(reached, target),
		])
	print("      flight time held at 1.20 s in every row\n")


func _read_reception(
	event: Resource, seed_value: int, serving_home: bool, counts: Dictionary
) -> Dictionary:
	var metadata: Dictionary = event.metadata
	counts["receptions"] = int(counts.receptions) + 1
	if bool(event.success):
		counts["playable"] = int(counts.playable) + 1
	else:
		counts["unplayable"] = int(counts.unplayable) + 1

	var incoming: Dictionary = metadata.get("incoming_trajectory", {})
	var outgoing: Dictionary = metadata.get("outgoing_trajectory", {})
	if outgoing.is_empty():
		counts["no_outgoing"] = int(counts.no_outgoing) + 1
	var serve_seconds := float(incoming.get("duration", 0.0))

	## The only recomputed quantity, and it is arithmetic on two published
	## points rather than a second model: the court is 9 x 18 m, so a normalised
	## delta becomes metres. `movement_start` is where the receiver was and
	## `event.start_position` is where the ball had to be met.
	var start := Vector2(metadata.get("movement_start", event.start_position))
	var target := Vector2(incoming.get("end_position", event.start_position))
	var reached := Vector2(metadata.get("movement_target", target))
	var start_distance := _metres(start, target)
	## Positive when the receiver could not finish the trip inside the ball's
	## flight. `movement_target` is `_reached_point`, which is already clamped to
	## what the serve's own duration allowed.
	var shortfall := _metres(reached, target)

	## **The tell.** `_reception_pass_result` always publishes this key, so a zero
	## here means the pass dict was rebuilt without it and the setter fell back to
	## a height derived from reception quality and a fresh RNG draw.
	var set_height := float(metadata.get("set_contact_height_meters", 0.0))
	if set_height > 0.0:
		counts["height_from_pass"] = int(counts.height_from_pass) + 1
	else:
		counts["height_fallback"] = int(counts.height_fallback) + 1
	if is_zero_approx(float(metadata.get("reach_margin_meters", 0.0))):
		counts["no_reach_margin"] = int(counts.no_reach_margin) + 1

	var pass_end := Vector2(outgoing.get("end_position", Vector2.ZERO))
	return {
		"quality": float(event.quality),
		"serve_seconds": serve_seconds,
		"start_distance": start_distance,
		"shortfall": shortfall,
		"line": "%s|%d|%s|%d|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.5f|%.5f|%.4f" % [
			str(metadata.get("side", "?")), seed_value,
			"1" if serving_home else "0", int(event.actor_id),
			"1" if bool(event.success) else "0", float(event.quality),
			serve_seconds, start_distance, shortfall,
			float(metadata.get("movement_duration", -1.0)),
			float(metadata.get("reach_margin_meters", 0.0)),
			set_height, float(metadata.get("pass_apex_meters", 0.0)),
			pass_end.x, pass_end.y, float(outgoing.get("duration", 0.0)),
		],
	}


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()
