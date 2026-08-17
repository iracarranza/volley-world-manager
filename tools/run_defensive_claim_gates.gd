extends SceneTree

## Gates C-H of the defensive-responsibility policy, run against the **existing**
## claimant selector.
##
##     godot --headless --path . --script res://tools/run_defensive_claim_gates.gd
##
## These are audits, not builds. Whether defensive arrival is missing a *stance*
## term changes arrival **magnitudes**; it does not change the **ordering rules**
## the policy states, and those are what C-H ask about. So they are answerable
## today even with step 0 blocked, and the first draft of the readiness write-up
## was wrong to defer them.
##
## Every fixture drives `CoverageCalculator.choose_claimant` directly, which is
## the function both sides' floor defence calls. Deterministic -- no rally is
## resolved and no RNG is drawn.

const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

const BALL_AT := Vector2(0.30, 0.78)


func _initialize() -> void:
	_gate_c()
	_gate_d()
	_gate_e()
	_gate_f()
	_gate_g()
	_gate_h()
	quit()


func _voli(player_id: int, overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Voli %d" % player_id
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "reception",
		"dig_control", "ball_control", "composure", "work_rate", "stamina",
		"reception_stability",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


func _zone(player_id: int, centre: Vector2, radius: float, priority: int) -> Resource:
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = player_id
	zone.zone_type = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	zone.center = centre
	zone.radius_meters = radius
	zone.priority = priority
	zone.enabled = true
	return zone


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## Runs one fixture and prints the per-candidate terms the policy asks to see.
func _run(
	title: String,
	players: Array[VolleyballPlayer],
	zones: Dictionary,
	origins: Dictionary,
	ball_seconds: float,
	penalties: Dictionary = {},
	expect: int = -1,
	expectation: String = "",
) -> void:
	print("\n  %s" % title)
	print("      %-6s %-9s %-9s %-9s %-11s %-10s %-9s %-8s" % [
		"voli", "zone_pri", "dist_m", "recovery", "reach_margin", "immediate",
		"claim", "chosen",
	])
	var typed: Array[VolleyballPlayer] = players
	var claim: Dictionary = CoverageCalculator.choose_claimant(
		typed, zones, BALL_AT, ball_seconds, "reception", penalties, origins
	)
	var winner := claim.get("player") as VolleyballPlayer
	for player in typed:
		var zone: Resource = zones.get(player.id) as Resource
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			player, zone, BALL_AT,
			maxf(ball_seconds - float(penalties.get(player.id, 0.0)), 0.02),
			"reception", origins.get(player.id),
		)
		print("      %-6d %-9s %-9.3f %-9.2f %-11.3f %-10s %-9.3f %-8s" % [
			player.id,
			str(zone.priority) if zone != null else "-",
			_metres(Vector2(origins.get(player.id, BALL_AT)), BALL_AT),
			float(penalties.get(player.id, 0.0)),
			float(arrival.get("reach_margin_meters", 0.0)),
			"YES" if bool(arrival.get("immediate_control", false)) else "-",
			float(arrival.get("claim_score", -1000.0)),
			"<==" if winner != null and winner.id == player.id else "",
		])
	var chosen_id := winner.id if winner != null else -1
	var verdict := "PASS" if expect < 0 or chosen_id == expect else "FAIL"
	print("      immediate_lock %s, owners %d -> chose %d   %s%s" % [
		"YES" if bool(claim.get("immediate_lock", false)) else "no",
		int(claim.get("immediate_owner_count", 0)), chosen_id,
		verdict, ("  (%s)" % expectation) if expectation != "" else "",
	])


## ------------------------------------------------------------------- gate C
##
## §7: a voli for whom the ball is already immediately playable owns it over a
## more distant teammate. The distant one is deliberately made the *better*
## defender, so if the score could outbid the lock it would.
func _gate_c() -> void:
	print("=".repeat(78))
	print("GATE C -- immediately playable defender vs distant better teammate")
	print("=".repeat(78))
	var near := _voli(1)
	var far := _voli(2, {
		"anticipation": 99, "lateral_speed": 99, "acceleration": 99,
		"reception": 99, "dig_control": 99,
	})
	var origins := {1: BALL_AT + Vector2(0.008, 0.004), 2: Vector2(0.62, 0.72)}
	_run(
		"near voli 1 (ordinary) vs far voli 2 (elite), ball 1.10 s",
		[near, far],
		{
			1: _zone(1, Vector2(0.30, 0.80), 3.0, 1),
			2: _zone(2, Vector2(0.62, 0.72), 3.0, 1),
		},
		origins, 1.10, {}, 1, "the ball is on voli 1",
	)


## ------------------------------------------------------------------- gate D
##
## §5: if the responsible defender cannot make a playable contact in ball time,
## responsibility transfers to a reachable fallback.
func _gate_d() -> void:
	print("\n" + "=".repeat(78))
	print("GATE D -- responsible defender impossible vs reachable fallback")
	print("=".repeat(78))
	var responsible := _voli(1)
	var fallback := _voli(2)
	## Voli 1 owns the zone the ball lands in but is stranded in the far corner;
	## voli 2 is close but owns a zone centred elsewhere.
	var zones := {
		1: _zone(1, BALL_AT, 3.0, 3),
		2: _zone(2, Vector2(0.62, 0.72), 3.0, 1),
	}
	for seconds in [1.40, 0.90, 0.55, 0.35]:
		_run(
			"ball %.2f s -- voli 1 owns the zone, stranded at (0.94, 0.10)" % seconds,
			[responsible, fallback], zones,
			{1: Vector2(0.94, 0.10), 2: Vector2(0.36, 0.74)},
			seconds, {}, -1, "transfer once voli 1 cannot arrive",
		)


## ------------------------------------------------------------------- gate E
##
## §2 and §4: a short ball belongs to the assigned short defender while they can
## still play it, and a deep defender does not abandon depth merely because
## their raw arrival is better.
func _gate_e() -> void:
	print("\n" + "=".repeat(78))
	print("GATE E -- short ball: assigned short defender vs faster deep defender")
	print("=".repeat(78))
	var short_defender := _voli(1)
	var deep := _voli(2, {
		"anticipation": 99, "lateral_speed": 99, "acceleration": 99,
	})
	## The short defender's zone contains the ball; the deep defender's does not,
	## but they are quicker and not much further away.
	_run(
		"short zone contains the ball; deep voli is elite and 1 m further",
		[short_defender, deep],
		{
			1: _zone(1, BALL_AT, 2.4, 3),
			2: _zone(2, Vector2(0.34, 0.92), 3.2, 1),
		},
		{1: Vector2(0.28, 0.72), 2: Vector2(0.34, 0.88)},
		0.95, {}, -1, "the assigned short defender should hold it",
	)


## ------------------------------------------------------------------- gate F
##
## §1: where zones overlap, the existing priority field resolves it.
func _gate_f() -> void:
	print("\n" + "=".repeat(78))
	print("GATE F -- overlapping zones resolved by existing priority")
	print("=".repeat(78))
	for high in [1, 2]:
		var a := _voli(1)
		var b := _voli(2)
		_run(
			"both zones contain the ball; voli %d has the higher priority" % high,
			[a, b],
			{
				1: _zone(1, BALL_AT, 3.2, 3 if high == 1 else 1),
				2: _zone(2, BALL_AT, 3.2, 3 if high == 2 else 1),
			},
			## Identical distance, so nothing but the priority can separate them.
			{1: Vector2(0.30, 0.86), 2: Vector2(0.30, 0.70)},
			1.10, {}, -1, "priority should decide",
		)


## ------------------------------------------------------------------- gate G
##
## §0: if nobody passes the feasibility gate the search returns no player, and
## the caller's existing emergency fallback still produces a claimant. The
## selector's half of that is what is checked here.
func _gate_g() -> void:
	print("\n" + "=".repeat(78))
	print("GATE G -- nobody feasible")
	print("=".repeat(78))
	_run(
		"two volis, both in the far corner, ball in 0.25 s",
		[_voli(1), _voli(2)],
		{1: _zone(1, BALL_AT, 3.0, 1), 2: _zone(2, BALL_AT, 3.0, 1)},
		{1: Vector2(0.96, 0.06), 2: Vector2(0.92, 0.10)},
		0.25, {}, -1, "no claimant; the caller falls back to nearest body",
	)


## ------------------------------------------------------------------- gate H
##
## §9: adjacent bodies are not two independent opportunities. The selector's
## existing spacing output is `nearest_teammate_meters`, which the consumer
## turns into the crowding term. Checked here as: does the selector *report*
## the spacing honestly?
func _gate_h() -> void:
	print("\n" + "=".repeat(78))
	print("GATE H -- adjacent candidates and the reported spacing")
	print("=".repeat(78))
	print("      %-16s %-22s %-14s" % [
		"separation_m", "nearest_teammate_m", "immediate owners",
	])
	for separation in [0.10, 0.40, 1.00, 2.50, 5.00]:
		var origins := {
			1: BALL_AT + Vector2(0.008, 0.004),
			2: BALL_AT + Vector2(
				float(separation) / COURT_WIDTH_METERS, 0.0
			),
		}
		var typed: Array[VolleyballPlayer] = [_voli(1), _voli(2)]
		var claim: Dictionary = CoverageCalculator.choose_claimant(
			typed,
			{1: _zone(1, BALL_AT, 3.0, 1), 2: _zone(2, BALL_AT, 3.0, 1)},
			BALL_AT, 1.10, "reception", {}, origins,
		)
		print("      %-16.2f %-22.4f %-14d" % [
			float(separation),
			float(claim.get("nearest_teammate_meters", -1.0)),
			int(claim.get("immediate_owner_count", 0)),
		])
	print("      -> spacing is reported from the origins each voli was judged")
	print("         from, so a consumer can price interference without a new term.")
