extends SceneTree

## Gates A-H of the moving-orientation pass: does `facing` evolve honestly once
## a body starts moving?
##
##     godot --headless --path . --script res://tools/run_moving_orientation_probe.gd
##
## The previous pass (`docs/review/READY_ORIENTATION.md`) gave a *resting* body a
## justified orientation and stopped exactly here: a body that had moved had none
## the simulation could defend, because `apply_position` assigned `facing =
## velocity` for every movement alike. That rule says a backpedalling defender is
## facing away from the net and a shuffling blocker is facing down the net rather
## than across it, which is not what either of those movements is.
##
## The policy replaces the universal rule with the movement **form**: IDLE,
## LATERAL, BLOCK_CLOSE and RECOVERY preserve orientation; APPROACH and
## TRANSITION establish it from the route. No angle, distance, speed or turn-rate
## constant is introduced anywhere, and none is needed -- the enum already
## describes the physical movement.
##
## Deterministic. No rally is resolved and no RNG is drawn.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

const DEFENDER_AT := Vector2(0.50, 0.80)

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	_gate_a()
	_gate_b()
	_gate_c()
	_gate_d()
	_gate_e()
	_gate_f()
	_gate_g()
	_gate_h()
	_summary()
	quit()


func _voli(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 701
	player.display_name = "Defender"
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "transition_speed",
		"stamina", "work_rate", "reception", "dig_control", "ball_control",
		"composure", "reception_stability",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


func _actor(
	mode: RallyPlayerState.MovementMode, side: StringName = &"home"
) -> RallyPlayerState:
	var actor := RallyPlayerState.create(_voli(), side, 1, DEFENDER_AT)
	actor.movement_mode = mode
	return actor


func _verdict(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
	print("      %s  %s" % ["PASS" if condition else "FAIL", label])


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## ------------------------------------------------------------------- gate A
##
## IDLE and LATERAL preserve facing. Driven with a velocity that points somewhere
## else entirely, so a preserved facing cannot be an accident of the direction.
func _gate_a() -> void:
	print("=".repeat(78))
	print("GATE A -- IDLE and LATERAL preserve facing")
	print("=".repeat(78))
	print("  %-14s %-16s %-16s %-16s" % [
		"mode", "facing before", "travel dir", "facing after",
	])
	var travel := Vector2(0.8, 0.6).normalized() * 2.4
	for mode_name in ["IDLE", "LATERAL", "BLOCK_CLOSE", "RECOVERY"]:
		var mode: int = RallyPlayerState.MovementMode[mode_name]
		var actor := _actor(mode)
		var before := actor.facing
		actor.apply_position(DEFENDER_AT + Vector2(0.04, 0.02), travel)
		print("  %-14s %-16s %-16s %-16s" % [
			mode_name, str(before.snapped(Vector2(0.001, 0.001))),
			str(travel.normalized().snapped(Vector2(0.001, 0.001))),
			str(actor.facing.snapped(Vector2(0.001, 0.001))),
		])
		_verdict(
			actor.facing.is_equal_approx(before),
			"%s preserves preparation orientation through real movement" % mode_name,
		)


## ------------------------------------------------------------------- gate B
##
## The named case: a defender backpedalling must not end up facing away from the
## net merely because that is where their feet are carrying them.
func _gate_b() -> void:
	print("\n" + "=".repeat(78))
	print("GATE B -- a backpedal does not turn the body around")
	print("=".repeat(78))
	var net_ward := RallyPlayerState.side_relative_ready_facing(&"home")
	print("  A home defender is set toward the net at %s." % str(net_ward))
	print("  They retreat 1.5 m/s straight away from it.\n")
	var actor := _actor(RallyPlayerState.MovementMode.LATERAL)
	var retreat := Vector2(0.0, 1.5)
	actor.apply_position(DEFENDER_AT + Vector2(0.0, 0.05), retreat)
	print("  travel direction  %s" % str(retreat.normalized()))
	print("  facing after      %s" % str(actor.facing))
	_verdict(
		actor.facing.is_equal_approx(net_ward),
		"a backpedalling defender stays square to the net",
	)
	_verdict(
		actor.facing.dot(retreat.normalized()) < 0.0,
		"and is therefore genuinely travelling backward, not turned around",
	)
	## Sideways too -- the other half of what LATERAL means.
	var sideways := _actor(RallyPlayerState.MovementMode.LATERAL)
	sideways.apply_position(DEFENDER_AT + Vector2(0.06, 0.0), Vector2(2.2, 0.0))
	_verdict(
		sideways.facing.is_equal_approx(net_ward),
		"a shuffling defender stays square while travelling sideways",
	)


## ------------------------------------------------------------------- gate C
##
## BLOCK_CLOSE preserves facing, and the whole point is that a close runs along
## the net while the body stays across it.
func _gate_c() -> void:
	print("\n" + "=".repeat(78))
	print("GATE C -- a block close runs along the net, square to it")
	print("=".repeat(78))
	var actor := _actor(RallyPlayerState.MovementMode.BLOCK_CLOSE)
	var before := actor.facing
	var along_the_net := Vector2(3.1, 0.0)
	actor.apply_position(Vector2(0.62, 0.52), along_the_net)
	print("  travel %s, facing %s -> %s" % [
		str(along_the_net.normalized()), str(before), str(actor.facing),
	])
	_verdict(
		actor.facing.is_equal_approx(before),
		"BLOCK_CLOSE keeps the blocker square to the net",
	)
	## And the movement model prices that stance: closing sideways from a
	## net-ward facing is a genuine half-turn, not a free one.
	var profile: Dictionary = RallyMovementSystemModel.movement_profile(
		actor, along_the_net.normalized(), RallyPlayerState.MovementMode.BLOCK_CLOSE
	)
	print("  facing_fit %.4f, turn cost %.4f s" % [
		float(profile.facing_fit), float(profile.direction_change_delay),
	])
	_verdict(
		absf(float(profile.facing_fit) - 0.5) < 0.001,
		"and the close is priced as a lateral movement, at facing_fit 0.5",
	)


## ------------------------------------------------------------------- gate D
##
## APPROACH and TRANSITION establish route-facing -- and only those two.
func _gate_d() -> void:
	print("\n" + "=".repeat(78))
	print("GATE D -- APPROACH and TRANSITION open up and face the route")
	print("=".repeat(78))
	print("  %-14s %-18s %-18s %-10s" % [
		"mode", "travel dir", "facing after", "took route",
	])
	var run := Vector2(0.55, -0.84).normalized() * 3.6
	for mode_name in [
		"IDLE", "LATERAL", "BLOCK_CLOSE", "RECOVERY", "APPROACH", "TRANSITION",
	]:
		var mode: int = RallyPlayerState.MovementMode[mode_name]
		var actor := _actor(mode)
		actor.apply_position(Vector2(0.56, 0.62), run)
		var took_route := actor.facing.is_equal_approx(run.normalized())
		print("  %-14s %-18s %-18s %-10s" % [
			mode_name, str(run.normalized().snapped(Vector2(0.001, 0.001))),
			str(actor.facing.snapped(Vector2(0.001, 0.001))),
			"YES" if took_route else "no",
		])
		var should: bool = mode_name in ["APPROACH", "TRANSITION"]
		_verdict(
			took_route == should,
			"%s %s the route" % [
				mode_name, "establishes" if should else "does not establish",
			],
		)


## ------------------------------------------------------------------- gate E
##
## The invariant: no destination may make itself perfectly prepared before its
## own feasibility has been evaluated.
##
## Two halves. First `_travel`, which used to face its own route and so returned
## `facing_fit` 1.0 for every leg in the engine. Second `project_toward`, whose
## mode is now set before the position rather than after -- so a projection is
## classified by the leg being applied, not by whatever the body did previously.
func _gate_e() -> void:
	print("\n" + "=".repeat(78))
	print("GATE E -- no route prepares itself before it is evaluated")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242
	var target := Vector2(0.62, 0.66)
	var opening := RallyKinematics.court_delta_meters(DEFENDER_AT, target).normalized()
	var toward: Dictionary = simulator._travel(
		_voli(), DEFENDER_AT, target, "lateral", null, Vector2.ZERO, opening
	)
	var away: Dictionary = simulator._travel(
		_voli(), DEFENDER_AT, target, "lateral", null, Vector2.ZERO, -opening
	)
	print("  _travel with facing toward %.4f s, away %.4f s" % [
		float(toward.seconds), float(away.seconds),
	])
	_verdict(
		float(away.seconds) > float(toward.seconds) + 0.001,
		"a leg away from the body's preparation costs more than one toward it",
	)

	## `project_toward` in a preserve-facing mode must not silently acquire the
	## route it was asked to travel.
	var shuffling := _actor(RallyPlayerState.MovementMode.LATERAL)
	var before := shuffling.facing
	var projection: Dictionary = RallyMovementSystemModel.project_toward(
		shuffling, Vector2(0.66, 0.88), 0.9,
		RallyPlayerState.MovementMode.LATERAL, true,
	)
	var projected := projection.get("actor") as RallyPlayerState
	print("  project_toward(LATERAL) facing %s -> %s" % [
		str(before), str(projected.facing),
	])
	_verdict(
		projected.facing.is_equal_approx(before),
		"a projected lateral leg does not adopt its own route",
	)
	var running := _actor(RallyPlayerState.MovementMode.LATERAL)
	var run_projection: Dictionary = RallyMovementSystemModel.project_toward(
		running, Vector2(0.66, 0.40), 0.9,
		RallyPlayerState.MovementMode.TRANSITION, true,
	)
	var ran := run_projection.get("actor") as RallyPlayerState
	print("  project_toward(TRANSITION) from a shuffling body -> %s" % str(ran.facing))
	_verdict(
		not ran.facing.is_equal_approx(before)
			and ran.movement_mode == RallyPlayerState.MovementMode.TRANSITION,
		"a projected transition run is classified by the leg it is applying",
	)


## ------------------------------------------------------------------- gate F
##
## After real defensive movement the claimant must receive the orientation the
## body actually ended in, not the one it was built with.
func _gate_f() -> void:
	print("\n" + "=".repeat(78))
	print("GATE F -- the claimant reads a live orientation, not a stale one")
	print("=".repeat(78))
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = 701
	zone.zone_type = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	zone.center = DEFENDER_AT
	zone.radius_meters = 3.0
	zone.enabled = true
	## Two histories, one ball. A body that ran to the left and one that ran to
	## the right are differently prepared for the same next ball.
	var landing := DEFENDER_AT + Vector2(0.10, 0.0)
	print("  %-30s %-14s %-13s %-12s" % [
		"history", "facing", "reach_margin", "travel_s",
	])
	var margins: Array[float] = []
	for label in ["ran right (toward)", "ran left (away)"]:
		var actor := _actor(RallyPlayerState.MovementMode.TRANSITION)
		var run := Vector2(2.8, 0.0) if label.begins_with("ran right") \
			else Vector2(-2.8, 0.0)
		actor.apply_position(DEFENDER_AT, run)
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			actor.player, zone, landing, 1.10, "dig_control", DEFENDER_AT, -1.0,
			actor.facing,
		)
		margins.append(float(arrival.get("reach_margin_meters", 0.0)))
		print("  %-30s %-14s %-13.4f %-12.4f" % [
			label, str(actor.facing.snapped(Vector2(0.01, 0.01))),
			float(arrival.get("reach_margin_meters", 0.0)),
			float(arrival.get("travel_time", 0.0)),
		])
	_verdict(
		margins[0] > margins[1] + 0.001,
		"the body that ran toward the next ball is better prepared for it",
	)


## ------------------------------------------------------------------- gate G
##
## The same ball, twice, differing only in what the defender did beforehand.
## This is the gate the previous pass could not write: it needs movement to have
## changed orientation, which is exactly what was missing.
func _gate_g() -> void:
	print("\n" + "=".repeat(78))
	print("GATE G -- prior movement changes what a later equal ball costs")
	print("=".repeat(78))
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = 701
	zone.zone_type = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	zone.center = DEFENDER_AT
	zone.radius_meters = 3.2
	zone.enabled = true
	## To the **side**, not behind. A ball straight behind is degenerate for this
	## comparison: the net-ward ready facing is already the worst orientation
	## there is for it, so "turned the wrong way" and "never turned" cannot be
	## separated. Sideways puts the square body in the middle, at facing_fit 0.5,
	## with room on both sides of it -- which is what the gate is actually about.
	var landing := DEFENDER_AT + Vector2(0.133, 0.0)
	print("  One ball, 1.2 m to the defender's right, 1.10 s of flight.\n")
	print("  %-34s %-16s %-13s" % ["prior movement", "facing", "reach_margin"])
	var results := {}
	for label in [
		"stood still (LATERAL shuffle)", "ran that way (TRANSITION)",
		"ran the other way (TRANSITION)",
	]:
		var actor: RallyPlayerState = null
		if label.begins_with("stood"):
			actor = _actor(RallyPlayerState.MovementMode.LATERAL)
			actor.apply_position(DEFENDER_AT, Vector2(1.4, 0.0))
		elif label.begins_with("ran that"):
			actor = _actor(RallyPlayerState.MovementMode.TRANSITION)
			actor.apply_position(DEFENDER_AT, Vector2(3.2, 0.0))
		else:
			actor = _actor(RallyPlayerState.MovementMode.TRANSITION)
			actor.apply_position(DEFENDER_AT, Vector2(-3.2, 0.0))
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			actor.player, zone, landing, 1.10, "dig_control", DEFENDER_AT, -1.0,
			actor.facing,
		)
		results[label] = float(arrival.get("reach_margin_meters", 0.0))
		print("  %-34s %-16s %-13.4f" % [
			label, str(actor.facing.snapped(Vector2(0.01, 0.01))),
			float(arrival.get("reach_margin_meters", 0.0)),
		])
	_verdict(
		results["ran that way (TRANSITION)"]
			> results["stood still (LATERAL shuffle)"] + 0.001,
		"a body already turned that way is better placed than one still square",
	)
	_verdict(
		results["stood still (LATERAL shuffle)"]
			> results["ran the other way (TRANSITION)"] + 0.001,
		"and a body turned the wrong way is worse than one that never turned",
	)


## ------------------------------------------------------------------- gate H
##
## The previous pass's A1-A8 in their load-bearing form: the side mirror, the
## stationary preserve, the graded facing_fit, and one distinct top speed.
func _gate_h() -> void:
	print("\n" + "=".repeat(78))
	print("GATE H -- the certified ready-orientation results still hold")
	print("=".repeat(78))
	var home := RallyPlayerState.create(_voli(), &"home", 1, DEFENDER_AT)
	var away := RallyPlayerState.create(_voli(), &"opponent", 1, Vector2(0.50, 0.20))
	_verdict(
		home.facing.is_equal_approx(-away.facing) and home.facing.length() > 0.5,
		"A1: the two sides still initialise mirrored and meaningful",
	)
	var resting := RallyPlayerState.create(_voli(), &"home", 1, DEFENDER_AT)
	var before := resting.facing
	resting.apply_position(DEFENDER_AT, Vector2.ZERO)
	_verdict(
		resting.facing.is_equal_approx(before),
		"A2: zero movement still preserves orientation",
	)
	print("\n  %-18s %-12s %-12s %-12s" % [
		"facing", "facing_fit", "turn_s", "top_mps",
	])
	var route := Vector2(0.0, 1.0)
	var fits: Array[float] = []
	var speeds: Array[float] = []
	for label in ["toward", "45 deg", "across", "135 deg", "away"]:
		var angle: float = {
			"toward": 0.0, "45 deg": PI * 0.25, "across": PI * 0.5,
			"135 deg": PI * 0.75, "away": PI,
		}[label]
		var actor := _actor(RallyPlayerState.MovementMode.LATERAL)
		actor.facing = route.rotated(float(angle))
		var profile: Dictionary = RallyMovementSystemModel.movement_profile(
			actor, route, RallyPlayerState.MovementMode.LATERAL
		)
		fits.append(float(profile.facing_fit))
		speeds.append(float(profile.maximum_speed))
		print("  %-18s %-12.4f %-12.4f %-12.4f" % [
			label, float(profile.facing_fit),
			float(profile.direction_change_delay), float(profile.maximum_speed),
		])
	_verdict(
		fits[0] > fits[1] and fits[1] > fits[2] and fits[2] > fits[3]
			and fits[3] > fits[4],
		"A3: facing_fit still grades monotonically from toward to away",
	)
	var distinct := {}
	for speed in speeds:
		distinct[snappedf(speed, 0.0001)] = true
	_verdict(
		distinct.size() == 1,
		"A3: and the turn is still never charged to top speed (%d distinct)"
			% distinct.size(),
	)


func _summary() -> void:
	print("\n" + "=".repeat(78))
	print("GATES: %d pass, %d fail" % [_pass_count, _fail_count])
	print("=".repeat(78))
