extends SceneTree

## NODE 2 of the forward walk: does the setter's movement consume the physical
## state the selection was actually made on?
##
##     godot --headless --path . --script res://tools/run_setter_movement_probe.gd
##
## Target chain:
##
##     selected second-contact voli
##     + realized pass destination
##     + realized pass duration
##     + actual start state / any legitimate head start
##     -> physical setter movement
##     -> realized arrival state / margin
##
## The ball's own time is authoritative. Part 1 asks whether both sides believe
## that; part 2 sweeps the short legs the transfer pass flagged; part 3 reads
## what each side actually publishes.
##
## Part 1 is exact -- `_spatial_setter_choice` and `_movement_time` take no RNG
## draw -- and it works by running **one** selection and then applying the two
## post-selection recipes to it, so the divergence cannot be blamed on the two
## sides having been handed different fixtures.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 71000
const SEED_COUNT: int = 300

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

const SLOT_IDS := {1: 401, 2: 402, 3: 403, 4: 404, 5: 405, 6: 406}
const SETTER_ID: int = 402
const PASS_TARGET := Vector2(0.56, 0.68)

## The literal the opponent path measures its arrival margin against, instead of
## the pass's own duration. Named here so the tables below can show what it
## costs rather than merely that it exists.
const DEFAULT_SECOND_CONTACT_SECONDS: float = 0.68


func _initialize() -> void:
	_part_one()
	_part_two_short_legs()
	_part_three_published()
	quit()


## ------------------------------------------------------------------ fixtures


func _make_player(player_id: int) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Voli %d" % player_id
	for attribute in [
		"set_accuracy", "ball_control", "decision_making", "ego", "leadership",
		"aggression", "acceleration", "lateral_speed", "transition_speed",
		"stamina", "work_rate", "anticipation", "composure",
	]:
		player.set(attribute, 50)
	player.fatigue = 0.0
	return player


func _fixture(positions: Dictionary) -> Dictionary:
	var lineup := RotationLineup.new()
	lineup.setter_id = SETTER_ID
	var players: Array[VolleyballPlayer] = []
	var starts := {}
	for slot_number in SLOT_IDS:
		var player_id: int = SLOT_IDS[slot_number]
		players.append(_make_player(player_id))
		lineup.assign_slot(slot_number, player_id)
		starts[player_id] = Vector2(positions[player_id])
	var plan := DefensivePlan.new()
	plan.rotation_number = 1
	plan.ensure_defaults(lineup, players)
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 3141
	simulator.live_positions = starts.duplicate(true)
	simulator.opponent_live_positions = starts.duplicate(true)
	return {
		"simulator": simulator, "players": players, "starts": starts,
		"plan": plan, "lineup": lineup,
	}


func _positions(setter_at: Vector2) -> Dictionary:
	return {
		401: Vector2(0.78, 0.86), 402: setter_at, 403: Vector2(0.46, 0.58),
		404: Vector2(0.20, 0.60), 405: Vector2(0.18, 0.86), 406: Vector2(0.48, 0.90),
	}


## ------------------------------------------------------------------- part 1
##
## **One selection, two post-selection recipes.**
##
## `home` is `rally_simulator.gd` 1856-1859: take `start` and `travel_time`
## straight out of the choice, and measure the margin against the realized pass
## duration.
##
## `opponent` is 4067-4086: re-read the start from `opponent_live_positions`,
## recompute the travel with `_movement_time(..., "lateral")`, and measure the
## margin against `DEFAULT_SECOND_CONTACT_SECONDS`.
##
## Same fixture, same ball, same chosen voli. Everything that differs below is
## the recipe.
func _part_one() -> void:
	print("=".repeat(78))
	print("PART 1 -- one selection, the two post-selection recipes")
	print("=".repeat(78))
	print("  Identical geometry, identical ball, identical chosen voli.")
	print("  `home` consumes the choice; `opponent` reconstructs from scratch.\n")
	for window in [0.42, 0.68, 0.95, 1.30, 1.80]:
		_compare(Vector2(0.66, 0.60), window, 1.34, "setter at the net")
	print("")
	for window in [0.42, 0.68, 0.95, 1.30, 1.80]:
		_compare(Vector2(0.24, 0.90), window, 1.34, "setter deep left")
	print("")
	print("  And with no head start at all, which isolates the other two")
	print("  reconstructions from the head-start one:")
	for window in [0.68, 1.30]:
		_compare(Vector2(0.24, 0.90), window, 0.0, "no head start")


func _compare(
	setter_at: Vector2, window: float, head_start: float, label: String
) -> void:
	var fixture := _fixture(_positions(setter_at))
	var simulator: Object = fixture.simulator
	var candidates: Array[VolleyballPlayer] = fixture.players
	var preferred: VolleyballPlayer = simulator._second_contact_setter(
		candidates, fixture.plan, SETTER_ID, -1
	)
	var choice: Dictionary = simulator._spatial_setter_choice(
		candidates, fixture.starts, fixture.plan, SETTER_ID, -1, preferred,
		PASS_TARGET, window, head_start,
	)
	var chosen: VolleyballPlayer = choice.player as VolleyballPlayer

	## The home recipe: consume.
	var home_start := Vector2(choice.start)
	var home_travel := float(choice.travel_time)
	var home_margin := window - home_travel

	## The opponent recipe: reconstruct.
	var away_start := Vector2(fixture.starts[chosen.id])
	var detour: Variant = simulator._navigation_waypoint(
		chosen, away_start, PASS_TARGET, fixture.starts
	)
	var away_travel: float = simulator._movement_time(
		chosen, away_start, PASS_TARGET, "lateral",
		detour["corner"] if detour != null else null,
	)
	var away_margin := DEFAULT_SECOND_CONTACT_SECONDS - away_travel

	if label != "":
		print("  %s, window %.2f s, head start %.2f s" % [label, window, head_start])
	print("      %-12s start %-16s dist %-7.3f travel %-7.3f margin %+.3f" % [
		"home", _point(home_start), _metres(home_start, PASS_TARGET),
		home_travel, home_margin,
	])
	print("      %-12s start %-16s dist %-7.3f travel %-7.3f margin %+.3f  %s" % [
		"opponent", _point(away_start), _metres(away_start, PASS_TARGET),
		away_travel, away_margin,
		"" if is_equal_approx(home_margin, away_margin) else "<- DIVERGES",
	])


func _point(position: Vector2) -> String:
	return "(%.2f, %.2f)" % [position.x, position.y]


## ------------------------------------------------------------------- part 2
##
## The short-leg question `41a57b6` §7 recorded, asked of setter movement
## specifically rather than of the transfer decision.
##
## The claim to test is not "small legs are penalised" -- they should be -- but
## whether travel time is **continuous and monotone** in distance. A model that
## jumps discontinuously at the first millimetre cannot express a setter taking
## half a step, and setter movement would then be physically meaningless for the
## commonest case there is.
##
## No cutoff is invented here and none is proposed. This measures.
func _part_two_short_legs() -> void:
	print("\n" + "=".repeat(78))
	print("PART 2 -- short legs: is travel time continuous in distance?")
	print("=".repeat(78))
	var fixture := _fixture(_positions(Vector2(0.66, 0.60)))
	var simulator: Object = fixture.simulator
	var mover: VolleyballPlayer = fixture.players[1]
	print("  One voli, one profile, only the required distance moves.")
	print("  %-14s %-12s %-14s %-14s" % [
		"distance_m", "travel_s", "implied_m/s", "delta_travel_s",
	])
	var previous := -1.0
	for centimetres in [0.0, 0.5, 1.0, 2.0, 5.0, 12.5, 25.0, 50.0, 100.0, 200.0, 400.0]:
		var metres := float(centimetres) / 100.0
		## Straight along the court's long axis so the requested distance is the
		## distance, with no width scaling to reason about.
		var start := PASS_TARGET + Vector2(0.0, metres / COURT_LENGTH_METERS)
		var travel: float = simulator._movement_time(
			mover, start, PASS_TARGET, "transition"
		)
		print("  %-14.4f %-12.4f %-14s %-14s" % [
			metres, travel,
			"--" if metres <= 0.0 else "%.4f" % (metres / maxf(travel, 0.0001)),
			"--" if previous < 0.0 else "%+.4f" % (travel - previous),
		])
		previous = travel
	print("  -> a jump between 0.00 and the first nonzero row is the standing")
	print("     start being charged in full. What matters for this node is")
	print("     whether the rows AFTER that are continuous and monotone.")
	_part_two_obstruction(fixture, mover)


## **Re-testing a claim this repository already published.**
##
## `SECOND_CONTACT_TRANSFER.md` §7 recorded an arrival margin collapsing from
## +1.200 s to -0.133 s over twelve and a half centimetres, and attributed it to
## the movement model charging a full standing start for any nonzero leg. The
## sweep above says that attribution is wrong: 12.5 cm costs 0.2556 s, not the
## ~1.33 s that collapse implies.
##
## The difference between the two measurements is that the earlier fixture had a
## body parked **exactly on the contact point** -- it was the challenger standing
## on the ball -- so the setter's route had to bend around them. That is
## `_navigation_waypoint`, not the standing start. This table separates the two
## by running the identical sweep with and without that body.
func _part_two_obstruction(fixture: Dictionary, mover: VolleyballPlayer) -> void:
	print("\n  Same sweep, with a body standing ON the contact point:")
	print("  %-14s %-14s %-14s %-12s" % [
		"distance_m", "clear_s", "obstructed_s", "detour?",
	])
	var simulator: Object = fixture.simulator
	var bodies := {999: PASS_TARGET}
	for centimetres in [0.5, 2.0, 12.5, 25.0, 50.0, 100.0, 400.0]:
		var metres := float(centimetres) / 100.0
		var start := PASS_TARGET + Vector2(0.0, metres / COURT_LENGTH_METERS)
		var clear: float = simulator._movement_time(
			mover, start, PASS_TARGET, "transition"
		)
		var detour: Variant = simulator._navigation_waypoint(
			mover, start, PASS_TARGET, bodies
		)
		var blocked: float = simulator._movement_time(
			mover, start, PASS_TARGET, "transition",
			detour["corner"] if detour != null else null,
		)
		print("  %-14.4f %-14.4f %-14.4f %-12s" % [
			metres, clear, blocked, "yes" if detour != null else "no",
		])
	print("  -> if the obstructed column is the one that jumps, the earlier")
	print("     write-up named the wrong cause and this corrects it.")


## ------------------------------------------------------------------- part 3
##
## What each side actually publishes on its SET event, which is how anybody
## downstream -- playback, the match centre, the next probe -- learns what the
## setter did.
func _part_three_published() -> void:
	print("\n" + "=".repeat(78))
	print("PART 3 -- what the SET event publishes, per side")
	print("=".repeat(78))
	var keys := [
		"movement_start", "movement_duration", "arrival_margin",
		"emergency_setter", "reach_margin_meters", "claimant_count",
		"setter_position",
	]
	var present := {"home": {}, "opponent": {}}
	var counts := {"home": 0, "opponent": 0}
	## Presence is only half of it: a key can be published and still be measured
	## against the wrong thing. These are the values, so a margin that cannot
	## hear the ball shows up as a distribution that barely moves.
	var stats := {
		"home": {"margin": 0.0, "travel": 0.0, "late": 0, "emergency": 0},
		"opponent": {"margin": 0.0, "travel": 0.0, "late": 0, "emergency": 0},
	}
	var outcomes := {}
	var home_points := 0
	var rallies := 0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			rallies += 1
			if rally != null:
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				if bool(rally.home_team_won):
					home_points += 1
				for event in rally.events:
					if int(event.event_type) != RallyEventScript.EventType.SET:
						continue
					var side := str(event.metadata.get("side", "home"))
					if not counts.has(side):
						continue
					counts[side] = int(counts[side]) + 1
					for key in keys:
						if event.metadata.has(key):
							present[side][key] = int(
								present[side].get(key, 0)
							) + 1
					var cell: Dictionary = stats[side]
					var margin := float(event.metadata.get("arrival_margin", 0.0))
					cell["margin"] = float(cell.margin) + margin
					cell["travel"] = float(cell.travel) \
						+ float(event.metadata.get("movement_duration", 0.0))
					if margin < 0.0:
						cell["late"] = int(cell.late) + 1
					if bool(event.metadata.get("emergency_setter", false)):
						cell["emergency"] = int(cell.emergency) + 1
			manager.free()
	print("  %-24s %-16s %-16s" % ["key", "home", "opponent"])
	for key in keys:
		print("  %-24s %-16s %-16s" % [
			key,
			"%d / %d" % [int(present["home"].get(key, 0)), int(counts.home)],
			"%d / %d" % [
				int(present["opponent"].get(key, 0)), int(counts.opponent),
			],
		])
	print("  a key absent on one side is a state that side cannot be audited on")

	print("\n  VALUES  (a margin measured against a constant barely moves)")
	print("  %-12s %-8s %-11s %-11s %-10s %-10s" % [
		"side", "sets", "margin_s", "travel_s", "late", "emergency",
	])
	for side_name in ["home", "opponent"]:
		var cell: Dictionary = stats[side_name]
		var count := maxf(float(counts[side_name]), 1.0)
		print("  %-12s %-8d %-11.4f %-11.4f %-10.4f %-10.4f" % [
			side_name, int(counts[side_name]), float(cell.margin) / count,
			float(cell.travel) / count, float(cell.late) / count,
			float(cell.emergency) / count,
		])

	print("\n  RALLY OUTCOMES  (regression observation, never a target)")
	print("      home points %d of %d (%.4f)" % [
		home_points, rallies, float(home_points) / maxf(float(rallies), 1.0),
	])
	var outcome_names: Array = outcomes.keys()
	outcome_names.sort()
	for outcome_name in outcome_names:
		print("      %-28s %-5d %.4f" % [
			outcome_name, int(outcomes[outcome_name]),
			float(outcomes[outcome_name]) / maxf(float(rallies), 1.0),
		])


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()
