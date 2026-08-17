extends SceneTree

## Audit step 0 of the defensive-responsibility pass: does a resting defender
## have a direction they are prepared to defend?
##
##     godot --headless --path . --script res://tools/run_defensive_readiness_probe.gd
##
## The policy's §12 forks on exactly this:
##
##   YES -- `RallyPlayerState.facing` carries a real orientation for a defender
##          standing and waiting, and the defensive claimant simply cannot see
##          it. That is PLUMBING: propagate velocity and facing into arrival.
##
##   NO  -- stationary defenders end up uniformly ready in every direction, so
##          there is nothing to propagate. That is a MISSING PHYSICAL STATE, and
##          the policy says stop rather than compensate with claimant weights.
##
## The probe answers it in three layers, because the interesting part is *where*
## the signal dies:
##
##   1. the movement model, driven with an honestly-set facing;
##   2. the resolver's only route into that model, `_travel`;
##   3. the defensive claimant's actual arrival function.
##
## All three are deterministic. No rally is resolved and no RNG is drawn.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

## A defender standing still, and a ball arriving behind them. If preparation
## exists at all, these two orientations must not cost the same.
const DEFENDER_AT := Vector2(0.50, 0.80)
const BALL_AT := Vector2(0.62, 0.66)
const BALL_SECONDS: float = 0.62


func _initialize() -> void:
	_layer_one_model()
	_layer_two_resolver()
	_layer_three_claimant()
	_verdict()
	quit()


func _defender() -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 701
	player.display_name = "Defender"
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "transition_speed",
		"stamina", "work_rate", "reception", "dig_control", "ball_control",
		"composure",
	]:
		player.set(attribute, 50)
	player.fatigue = 0.0
	return player


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## ------------------------------------------------------------------ layer 1
##
## Can the movement model express directional preparation at all?
##
## `_movement_profile` computes `facing_fit = (facing . direction + 1) / 2` and
## spends it on the direction-change delay and on arrival balance. Drive it with
## a facing that is honestly set and see whether the number moves.
##
## If this table is flat, the capability does not exist and nothing downstream
## matters. If it moves, the capability exists and the question becomes who
## destroys it.
func _layer_one_model() -> void:
	print("=".repeat(78))
	print("LAYER 1 -- can the MOVEMENT MODEL express a prepared direction?")
	print("=".repeat(78))
	print("  One defender at (0.50, 0.80), one ball at (0.62, 0.66), %.2f s." % BALL_SECONDS)
	print("  Only `actor.facing` moves. Velocity is zero in every row -- this is")
	print("  a standing defender, which is the case the policy is about.\n")
	print("  %-22s %-12s %-12s %-12s" % [
		"facing", "facing_fit", "travel_s", "balance",
	])
	var opening := Vector2(
		(BALL_AT.x - DEFENDER_AT.x) * COURT_WIDTH_METERS,
		(BALL_AT.y - DEFENDER_AT.y) * COURT_LENGTH_METERS,
	).normalized()
	var cases := {
		"toward the ball": opening,
		"90 deg across": Vector2(-opening.y, opening.x),
		"away from the ball": -opening,
		"the class default": Vector2(0.0, -1.0),
	}
	for label in cases:
		var actor := RallyPlayerState.create(_defender(), &"home", -1, DEFENDER_AT)
		actor.velocity = Vector2.ZERO
		actor.facing = Vector2(cases[label]).normalized()
		var profile: Dictionary = RallyMovementSystemModel._movement_profile(
			actor, opening, RallyPlayerState.MovementMode.LATERAL
		)
		var result: Dictionary = RallyMovementSystemModel.traversal_result(
			actor, BALL_AT, RallyPlayerState.MovementMode.LATERAL
		)
		print("  %-22s %-12.4f %-12.4f %-12.4f" % [
			label, float(profile.facing_fit), float(result.seconds),
			float(profile.get("direction_change_delay", 0.0)),
		])
	print("\n  (last column is `direction_change_delay`, the turn cost)")
	print("  -> if these differ, the model CAN price preparation.")


## ------------------------------------------------------------------ layer 2
##
## `_travel` is the resolver's only route into the movement model. It builds a
## fresh `RallyPlayerState` per call and sets:
##
##     actor.facing = opening.normalized()
##
## with the comment *"The resolver does not track facing at this point ... Face
## the route."* So whatever the caller believed about orientation, the actor is
## made to face exactly where it is going.
##
## Same two orientations as layer 1, through the resolver instead.
func _layer_two_resolver() -> void:
	print("\n" + "=".repeat(78))
	print("LAYER 2 -- does the RESOLVER carry that orientation into the model?")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 909
	print("  **Momentum is expressible here; stance is not.** `_travel` takes an")
	print("  `entry_velocity`, so a body already moving carries it -- but it")
	print("  takes no facing, and overwrites whatever the actor had with the")
	print("  route direction. The two halves of `RallyPlayerState` are treated")
	print("  very differently.\n")
	var opening := Vector2(
		(BALL_AT.x - DEFENDER_AT.x) * COURT_WIDTH_METERS,
		(BALL_AT.y - DEFENDER_AT.y) * COURT_LENGTH_METERS,
	).normalized()
	print("  %-30s %-14s %-14s" % ["caller supplies", "travel_s", "delta_s"])
	var baseline := 0.0
	for label in [
		"nothing (standing)", "velocity 1.5 m/s toward",
		"velocity 1.5 m/s away", "facing toward -- impossible",
		"facing away -- impossible",
	]:
		var entry := Vector2.ZERO
		if label.begins_with("velocity") and label.ends_with("toward"):
			entry = opening * 1.5
		elif label.begins_with("velocity"):
			entry = -opening * 1.5
		var leg: Dictionary = simulator._travel(
			_defender(), DEFENDER_AT, BALL_AT, "lateral", null, entry
		)
		if baseline == 0.0:
			baseline = float(leg.seconds)
		print("  %-30s %-14.4f %-14.4f" % [
			label, float(leg.seconds), float(leg.seconds) - baseline,
		])
	print("  -> the two velocity rows differ, so momentum survives the boundary.")
	print("     The two facing rows are identical to the standing row, because")
	print("     `_travel` has no facing parameter: a caller cannot express one,")
	print("     and the actor is faced down the route regardless.")


## ------------------------------------------------------------------ layer 3
##
## And the path the defensive claimant actually takes.
##
## `CoverageCalculator.evaluate_arrival(player, zone, landing, ball_time, skill,
## origin, unassigned_reach)` takes a `VolleyballPlayer` and a point. There is no
## `RallyPlayerState`, so no velocity, no facing, no body state. Startup is
## `reaction_delay = lerp(0.56, 0.18, anticipation)` -- one scalar per voli,
## identical in every direction.
func _layer_three_claimant() -> void:
	print("\n" + "=".repeat(78))
	print("LAYER 3 -- what the DEFENSIVE CLAIMANT actually evaluates")
	print("=".repeat(78))
	print("  %-26s %-12s %-13s %-12s" % [
		"ball arrives from", "reachable", "reach_margin", "travel_s",
	])
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = 701
	zone.zone_type = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	zone.center = DEFENDER_AT
	zone.radius_meters = 3.0
	zone.enabled = true
	## Four balls the same distance away, on four sides. A defender prepared for
	## one of them should not answer identically for all four.
	var distance := _metres(DEFENDER_AT, BALL_AT)
	for label in ["in front", "behind", "left", "right"]:
		var offset := Vector2.ZERO
		match label:
			"in front": offset = Vector2(0.0, -distance / COURT_LENGTH_METERS)
			"behind": offset = Vector2(0.0, distance / COURT_LENGTH_METERS)
			"left": offset = Vector2(-distance / COURT_WIDTH_METERS, 0.0)
			"right": offset = Vector2(distance / COURT_WIDTH_METERS, 0.0)
		var landing := DEFENDER_AT + offset
		## A generous window on purpose. With an unreachable ball every row
		## reads "NO" and the identity proves nothing; these four are all
		## comfortably reachable, so an identical answer is an identical
		## *answer* rather than four shared refusals.
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			_defender(), zone, landing, 1.60, "reception", DEFENDER_AT
		)
		print("  %-26s %-12s %-13.4f %-12.4f" % [
			label, "yes" if bool(arrival.get("reachable", false)) else "NO",
			float(arrival.get("reach_margin_meters", 0.0)),
			float(arrival.get("travel_time", 0.0)),
		])
	print("  -> four directions, one answer. `evaluate_arrival` has no facing")
	print("     parameter and no velocity parameter; its only startup term is")
	print("     `reaction_delay` from `anticipation`, which is omnidirectional.")


## ------------------------------------------------------------------ verdict
func _verdict() -> void:
	print("\n" + "=".repeat(78))
	print("WHERE THE SIGNAL DIES")
	print("=".repeat(78))
	print("  RallyPlayerState.facing        default Vector2(0, -1), a constant")
	print("  apply_position()               updates facing ONLY when velocity")
	print("                                 is non-zero -- a standing defender")
	print("                                 never updates it")
	print("  _travel()                      overwrites facing with the route")
	print("                                 direction on every call")
	print("  evaluate_arrival()             never receives an actor at all")
	print("")
	print("  So there is no system anywhere that decides which way a defender is")
	print("  oriented while waiting for an attack. `facing` is not unset by")
	print("  accident -- it is actively pinned to the direction of travel, which")
	print("  makes `facing_fit` 1.0 for every voli on every leg.")
