extends SceneTree

## The six short-ball responsibility fixtures, against the **existing** claimant.
##
##     godot --headless --path . --script res://tools/run_short_ball_sweep.gd
##
## Policy: assignment -> feasible controlled contact -> existing
## relationship/tiebreak. Proximity informs feasibility, never authority. No
## blanket front-row priority. A compromised nominal claimant may transfer to a
## clearly viable adjacent defender. The immediate-control lock keeps precedence.
##
## The sweep may change claimant **ordering**. It may not be tuned toward a dig,
## kill, side-out or rally-length target, and no standalone short-ball bonus may
## be added unless the existing authority + feasibility model demonstrably cannot
## express the policy. So this runs the fixtures *first* and moves nothing until
## a fixture says a weight must move.
##
## Every fixture drives `CoverageCalculator.choose_claimant` directly -- the
## function both sides' floor defence calls. Deterministic; no rally is resolved
## and no RNG is drawn.
##
## **How a compromised body is expressed.** The claimant selector does not see
## `body_state`; the resolver hands it `time_penalties`, which is how a landing
## blocker's or a diving defender's recovery debt already reaches it
## (`_recovery_time_penalties`). Fixtures 5 and 6 therefore construct the
## compromised state as the debt the resolver would supply, which is the same
## channel and not a fixture-only invention.

const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

## Short: just behind the attack line, in front of the back-row defenders.
const SHORT_BALL := Vector2(0.42, 0.62)

var _pass_count: int = 0
var _fail_count: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_fixture_one()
	_fixture_two()
	_fixture_three()
	_fixture_four()
	_fixture_five()
	_fixture_six()
	_summary()
	quit()


func _voli(player_id: int, overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Voli %d" % player_id
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "reception",
		"dig_control", "ball_control", "composure", "work_rate", "stamina",
		"reception_stability", "transition_speed",
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


func _verdict(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		_failures.append(label)
	print("      %s  %s" % ["PASS" if condition else "FAIL", label])


## One fixture, printed with every term the policy names.
func _run(
	title: String,
	players: Array[VolleyballPlayer],
	zones: Dictionary,
	origins: Dictionary,
	ball_seconds: float,
	penalties: Dictionary = {},
) -> Dictionary:
	print("\n  %s" % title)
	print("      %-6s %-9s %-9s %-10s %-12s %-10s %-9s %-7s" % [
		"voli", "zone_pri", "dist_m", "recovery", "reach_margin", "immediate",
		"claim", "chosen",
	])
	var typed: Array[VolleyballPlayer] = players
	var claim: Dictionary = CoverageCalculator.choose_claimant(
		typed, zones, SHORT_BALL, ball_seconds, "dig_control", penalties, origins
	)
	var winner := claim.get("player") as VolleyballPlayer
	for player in typed:
		var zone: Resource = zones.get(player.id) as Resource
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			player, zone, SHORT_BALL,
			maxf(ball_seconds - float(penalties.get(player.id, 0.0)), 0.02),
			"dig_control", origins.get(player.id),
		)
		print("      %-6d %-9s %-9.3f %-10.2f %-12.3f %-10s %-9.3f %-7s" % [
			player.id,
			str(zone.priority) if zone != null else "-",
			_metres(Vector2(origins.get(player.id, SHORT_BALL)), SHORT_BALL),
			float(penalties.get(player.id, 0.0)),
			float(arrival.get("reach_margin_meters", 0.0)),
			"YES" if bool(arrival.get("immediate_control", false)) else "-",
			float(arrival.get("claim_score", -1000.0)),
			"<==" if winner != null and winner.id == player.id else "",
		])
	print("      immediate_lock %s, owners %d" % [
		"YES" if bool(claim.get("immediate_lock", false)) else "no",
		int(claim.get("immediate_owner_count", 0)),
	])
	return claim


## ---------------------------------------------------------------- fixture 1
##
## A clear short ball inside A's responsibility. A owns it.
func _fixture_one() -> void:
	print("=".repeat(78))
	print("FIXTURE 1 -- clear short ball in A's responsibility")
	print("=".repeat(78))
	var claim := _run(
		"A's zone contains the ball and A is closest; B is a back-row defender",
		[_voli(1), _voli(2)],
		{
			1: _zone(1, SHORT_BALL, 2.6, 3),
			2: _zone(2, Vector2(0.42, 0.88), 3.2, 2),
		},
		{1: Vector2(0.40, 0.66), 2: Vector2(0.42, 0.90)},
		0.95,
	)
	var winner := claim.get("player") as VolleyballPlayer
	_verdict(winner != null and winner.id == 1, "the assigned short defender owns it")


## ---------------------------------------------------------------- fixture 2
##
## The same ball, but A is compromised -- still getting up from the previous
## contact -- and B is clearly viable. Responsibility may transfer.
func _fixture_two() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURE 2 -- A compromised, B clearly viable")
	print("=".repeat(78))
	var zones := {
		1: _zone(1, SHORT_BALL, 2.6, 3),
		2: _zone(2, Vector2(0.42, 0.74), 3.2, 2),
	}
	## **B has to actually be viable.** The first draft of this fixture put B
	## 2.88 m out on a 0.95 s ball, where their reach margin was -1.047 -- they
	## were never a candidate, so "never transferred" was measuring an empty
	## alternative rather than a stubborn selector. B now sits 1.3 m out on a
	## longer ball and is comfortably reachable.
	var origins := {1: Vector2(0.40, 0.66), 2: Vector2(0.42, 0.695)}
	print("\n  Recovery debt swept, everything else held. The transfer must")
	print("  happen because A cannot make the contact, not because B is nicer.")
	var transferred_at := -1.0
	## **Swept past the point where A is genuinely unable.** The first draft
	## stopped at 0.80 s of debt on a 1.25 s ball, which still leaves A 0.45 s --
	## more than their 0.37 s reaction -- so A could genuinely still play it and
	## keeping the ball was correct. "Never transferred" was measuring a regime
	## where no transfer should happen. The sweep now runs into the regime where
	## A has no usable time at all.
	for debt in [0.0, 0.40, 0.80, 0.95, 1.10, 1.24]:
		var claim := _run(
			"A owes %.2f s of recovery" % debt,
			[_voli(1), _voli(2)], zones, origins, 1.25,
			{1: float(debt)},
		)
		var winner := claim.get("player") as VolleyballPlayer
		if winner != null and winner.id == 2 and transferred_at < 0.0:
			transferred_at = float(debt)
	_verdict(
		transferred_at > 0.0,
		"a compromised nominal claimant transfers (first at %.2f s of debt)"
			% transferred_at if transferred_at > 0.0
			else "a compromised nominal claimant transfers -- NEVER TRANSFERRED",
	)


## ---------------------------------------------------------------- fixture 3
##
## A short ball on a responsibility boundary with two viable defenders. The
## existing relationship -- the zone priority the manager's plan assigns --
## resolves it, and nothing else may.
func _fixture_three() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURE 3 -- boundary short ball, two viable defenders")
	print("=".repeat(78))
	var chosen := []
	for high in [1, 2]:
		var claim := _run(
			"both zones contain the ball, identical bodies; voli %d has priority" % high,
			[_voli(1), _voli(2)],
			{
				1: _zone(1, SHORT_BALL, 3.0, 3 if high == 1 else 1),
				2: _zone(2, SHORT_BALL, 3.0, 3 if high == 2 else 1),
			},
			## Mirrored about the ball, so geometry cannot separate them.
			{1: Vector2(0.42, 0.56), 2: Vector2(0.42, 0.68)},
			1.05,
		)
		var winner := claim.get("player") as VolleyballPlayer
		chosen.append(winner.id if winner != null else -1)
	_verdict(
		chosen[0] == 1 and chosen[1] == 2,
		"the assigned relationship resolves a boundary ball, both ways",
	)


## ---------------------------------------------------------------- fixture 4
##
## A distant elite claimant must not steal a short ball through a generic
## pursuit score. The near defender is deliberately ordinary.
func _fixture_four() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURE 4 -- distant elite claimant cannot steal")
	print("=".repeat(78))
	var elite := {
		"anticipation": 99, "lateral_speed": 99, "acceleration": 99,
		"reception": 99, "dig_control": 99, "ball_control": 99,
	}
	## **Assignment first.** The first draft gave both volis the same zone
	## priority, so the policy's opening clause -- assignment defines the
	## plausible claimant set -- was not expressed at all, and two co-owners with
	## equal responsibility were being read as a steal. The near voli is the
	## assigned one here.
	var stolen_at := -1.0
	for distance in [2.5, 3.5, 5.0]:
		var far_origin := SHORT_BALL + Vector2(
			0.0, float(distance) / COURT_LENGTH_METERS
		)
		var claim := _run(
			"ordinary voli 1 on the ball; elite voli 2 at %.1f m" % distance,
			[_voli(1), _voli(2, elite)],
			{
				1: _zone(1, SHORT_BALL, 2.6, 3),
				2: _zone(2, far_origin, 3.2, 1),
			},
			{1: SHORT_BALL + Vector2(0.006, 0.004), 2: far_origin},
			1.30,
		)
		var winner := claim.get("player") as VolleyballPlayer
		if winner != null and winner.id == 2 and stolen_at < 0.0:
			stolen_at = float(distance)
	_verdict(
		stolen_at < 0.0,
		"no distance let a distant elite take a ball already on somebody"
			if stolen_at < 0.0
			else "a distant elite stole it at %.1f m" % stolen_at,
	)


## ---------------------------------------------------------------- fixture 5
##
## A blocker still committed at the net -- airborne, or landing -- cannot
## automatically own a short ball dropped behind the block.
func _fixture_five() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURE 5 -- committed/airborne blocker cannot auto-own")
	print("=".repeat(78))
	var tip := Vector2(0.46, 0.56)
	print("\n  The ball is tipped just behind the block, so the blocker is the")
	print("  nearest body by a wide margin -- which is exactly the case a")
	print("  proximity-as-authority selector gets wrong. The blocker's committed")
	print("  state reaches the selector as the recovery debt `_note_block_airborne`")
	print("  and `_recovery_time_penalties` already produce.")
	print("")
	print("  A back-row defender stands 1.8 m behind the tip and is genuinely")
	print("  viable. The first draft of this fixture put them 4 m out, where they")
	print("  could not reach the ball at all -- so the blocker won by being the")
	print("  only body who could touch it, which is the fallback working, not the")
	print("  lock failing. A fixture with no alternative cannot test a transfer.")
	## **What the policy forbids is owning it while unable to act**, not a
	## blocker participating at all. The first draft asserted that no recovery
	## debt could leave the ball with the blocker, and that is stronger than the
	## policy and worse volleyball: a blocker landing with 0.3 s of usable time
	## and the ball a metre behind them digs it, constantly. So this sweeps the
	## debt and reports where responsibility actually transfers, rather than
	## asserting a point.
	print("\n      %-10s %-14s %-14s %-10s" % [
		"debt s", "usable s", "immediate", "chosen",
	])
	var transferred_at := -1.0
	for debt in [0.0, 0.20, 0.40, 0.58, 0.70, 0.90]:
		var players: Array[VolleyballPlayer] = [_voli(1), _voli(2)]
		var zones := {
			1: _zone(1, Vector2(0.46, 0.50), 2.2, 2),
			2: _zone(2, Vector2(0.46, 0.66), 3.2, 2),
		}
		var origins := {1: Vector2(0.46, 0.505), 2: Vector2(0.46, 0.655)}
		var claim: Dictionary = CoverageCalculator.choose_claimant(
			players, zones, tip, 0.95, "dig_control", {1: float(debt)}, origins
		)
		var blocker_arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			players[0], zones[1], tip,
			maxf(0.95 - float(debt), 0.02), "dig_control", origins[1],
		)
		var winner := claim.get("player") as VolleyballPlayer
		print("      %-10.2f %-14.3f %-14s %-10d" % [
			float(debt), float(blocker_arrival.get("available_time", 0.0)),
			"YES" if bool(blocker_arrival.get("immediate_control", false)) else "-",
			winner.id if winner != null else -1,
		])
		if winner != null and winner.id == 2 and transferred_at < 0.0:
			transferred_at = float(debt)
	_verdict(
		transferred_at > 0.0,
		"a blocker with no usable time loses the ball behind them (at %.2f s of debt)"
			% transferred_at if transferred_at > 0.0
			else "a blocker with no usable time loses the ball -- NEVER TRANSFERRED",
	)


## ---------------------------------------------------------------- fixture 6
##
## And the other half: once landed and recovered, that same blocker may own it
## when they are genuinely the best viable play. The policy forbids a blanket
## front-row priority, not front-row participation.
func _fixture_six() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURE 6 -- landed and recovered blocker may own it")
	print("=".repeat(78))
	var tip := Vector2(0.46, 0.56)
	var claim: Dictionary = CoverageCalculator.choose_claimant(
		[_voli(1), _voli(2)] as Array[VolleyballPlayer],
		{
			1: _zone(1, Vector2(0.46, 0.50), 2.2, 2),
			2: _zone(2, Vector2(0.46, 0.76), 3.2, 2),
		},
		tip, 0.70, "dig_control", {},
		{1: Vector2(0.46, 0.505), 2: Vector2(0.46, 0.78)},
	)
	var winner := claim.get("player") as VolleyballPlayer
	print("\n      no recovery debt -> chosen %d, immediate_lock %s" % [
		winner.id if winner != null else -1,
		"YES" if bool(claim.get("immediate_lock", false)) else "no",
	])
	_verdict(
		winner != null and winner.id == 1,
		"the same blocker, recovered, takes the ball they are best placed for",
	)


func _summary() -> void:
	print("\n" + "=".repeat(78))
	print("FIXTURES: %d pass, %d fail" % [_pass_count, _fail_count])
	if not _failures.is_empty():
		for failure in _failures:
			print("  FAILED: %s" % failure)
	print("=".repeat(78))
