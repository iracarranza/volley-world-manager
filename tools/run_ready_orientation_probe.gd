extends SceneTree

## Gates A1-A6 of the ready-orientation policy.
##
##     godot --headless --path . --script res://tools/run_ready_orientation_probe.gd
##
## `facing` is physical feet/body preparation orientation -- not gaze, not a
## predicted landing point, not the route being evaluated. These gates check that
## it is initialised per side, survives standing still, is spent on startup
## rather than top speed, and cannot be manufactured by the route it is measured
## against.
##
## Deterministic; no rally resolved, no RNG drawn.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	_a1_initialisation()
	_a2_persistence()
	_a3_monotonic()
	_a4_route_cannot_prepare_itself()
	_a5_no_future_knowledge()
	_a6_independence()
	_a7_claimant()
	quit()


func _voli(player_id: int = 901) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Voli"
	for attribute in [
		"acceleration", "lateral_speed", "transition_speed", "stamina",
		"work_rate", "anticipation", "composure",
	]:
		player.set(attribute, 50)
	player.fatigue = 0.0
	return player


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## A1 -- opposite sides initialise mirrored, and neither is the other's value.
func _a1_initialisation() -> void:
	print("=".repeat(78))
	print("A1 -- side-relative initialisation")
	print("=".repeat(78))
	var home := RallyPlayerState.create(_voli(), &"home", 1, Vector2(0.50, 0.80))
	var away := RallyPlayerState.create(_voli(902), &"opponent", 1, Vector2(0.50, 0.20))
	print("  home     facing (%.2f, %.2f)" % [home.facing.x, home.facing.y])
	print("  opponent facing (%.2f, %.2f)" % [away.facing.x, away.facing.y])
	var mirrored := home.facing.is_equal_approx(-away.facing)
	var meaningful := home.facing.length() > 0.5 and away.facing.length() > 0.5
	print("  -> mirrored %s, both meaningful %s   %s" % [
		"yes" if mirrored else "NO", "yes" if meaningful else "NO",
		"PASS" if mirrored and meaningful else "FAIL",
	])
	print("  both face the net: home attacks toward low y, the opponent toward high y.")


## A2 -- standing still preserves facing. `apply_position` only rewrites it when
## the body is actually carrying velocity.
func _a2_persistence() -> void:
	print("\n" + "=".repeat(78))
	print("A2 -- zero movement preserves facing")
	print("=".repeat(78))
	var actor := RallyPlayerState.create(_voli(), &"home", 1, Vector2(0.50, 0.80))
	var original := actor.facing
	actor.apply_position(Vector2(0.50, 0.80), Vector2.ZERO)
	var after_rest := actor.facing
	actor.apply_position(Vector2(0.44, 0.74), Vector2(0.9, -0.4))
	var after_move := actor.facing
	print("  initial      (%.3f, %.3f)" % [original.x, original.y])
	print("  after rest   (%.3f, %.3f)   preserved %s" % [
		after_rest.x, after_rest.y,
		"yes" if after_rest.is_equal_approx(original) else "NO",
	])
	print("  after moving (%.3f, %.3f)   changed   %s" % [
		after_move.x, after_move.y,
		"yes" if not after_move.is_equal_approx(original) else "NO",
	])
	print("  -> %s" % (
		"PASS" if after_rest.is_equal_approx(original)
			and not after_move.is_equal_approx(original) else "FAIL"
	))


## A3 -- the same body, same trip, same clock: only the orientation moves.
## `facing_fit` must fall monotonically and the trip must lengthen, while
## `maximum_speed` does not move at all.
func _a3_monotonic() -> void:
	print("\n" + "=".repeat(78))
	print("A3 -- toward / across / away is monotone in startup, flat in top speed")
	print("=".repeat(78))
	var start := Vector2(0.50, 0.80)
	var target := Vector2(0.62, 0.66)
	var opening := RallyKinematics.court_delta_meters(start, target).normalized()
	print("  %-16s %-12s %-13s %-12s %-12s" % [
		"facing", "facing_fit", "turn_delay_s", "travel_s", "max_speed",
	])
	var previous_fit := 2.0
	var previous_travel := -1.0
	var speeds := {}
	var monotone := true
	for entry in [
		{"name": "toward", "facing": opening},
		{"name": "45 deg off", "facing": (opening + Vector2(-opening.y, opening.x)).normalized()},
		{"name": "across (90)", "facing": Vector2(-opening.y, opening.x)},
		{"name": "135 deg off", "facing": (-opening + Vector2(-opening.y, opening.x)).normalized()},
		{"name": "away", "facing": -opening},
	]:
		var actor := RallyPlayerState.create(_voli(), &"home", 1, start)
		actor.velocity = Vector2.ZERO
		actor.facing = Vector2(entry.facing).normalized()
		var profile: Dictionary = RallyMovementSystemModel._movement_profile(
			actor, opening, RallyPlayerState.MovementMode.LATERAL
		)
		var trip: Dictionary = RallyMovementSystemModel.traversal_result(
			actor, target, RallyPlayerState.MovementMode.LATERAL
		)
		var fit := float(profile.facing_fit)
		var travel := float(trip.seconds)
		if fit > previous_fit + 0.0001 or travel < previous_travel - 0.0001:
			monotone = false
		previous_fit = fit
		previous_travel = travel
		speeds[snappedf(float(profile.maximum_speed), 0.00001)] = true
		print("  %-16s %-12.4f %-13.4f %-12.4f %-12.4f" % [
			str(entry.name), fit,
			float(profile.direction_change_delay), travel,
			float(profile.maximum_speed),
		])
	print("  -> monotone %s, distinct top speeds %d   %s" % [
		"yes" if monotone else "NO", speeds.size(),
		"PASS" if monotone and speeds.size() == 1 else "FAIL",
	])


## A4 -- the route cannot prepare itself.
##
## `_travel` used to set `actor.facing = opening.normalized()` before evaluating,
## which made every requested route perfectly aligned by construction. The gate
## is that a supplied orientation now survives into the trip.
func _a4_route_cannot_prepare_itself() -> void:
	print("\n" + "=".repeat(78))
	print("A4 -- `_travel` does not face its own route")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242
	var start := Vector2(0.50, 0.80)
	var target := Vector2(0.62, 0.66)
	var opening := RallyKinematics.court_delta_meters(start, target).normalized()
	print("  %-24s %-12s %-12s" % ["entry_facing", "travel_s", "delta_s"])
	var baseline := 0.0
	var moved := false
	for entry in [
		{"name": "unknown (zero)", "facing": Vector2.ZERO},
		{"name": "toward the target", "facing": opening},
		{"name": "across the target", "facing": Vector2(-opening.y, opening.x)},
		{"name": "away from the target", "facing": -opening},
	]:
		var leg: Dictionary = simulator._travel(
			_voli(), start, target, "lateral", null, Vector2.ZERO,
			Vector2(entry.facing),
		)
		if baseline == 0.0:
			baseline = float(leg.seconds)
		elif absf(float(leg.seconds) - baseline) > 0.0005:
			moved = true
		print("  %-24s %-12.4f %-12.4f" % [
			str(entry.name), float(leg.seconds), float(leg.seconds) - baseline,
		])
	print("  -> a supplied orientation changes the trip: %s" % (
		"PASS" if moved else "FAIL -- the route is still preparing itself"
	))
	print("     zero means UNKNOWN and keeps the pre-existing behaviour, which is")
	print("     what lets un-migrated callers land unchanged.")


## A5 -- preparation cannot be chosen by the ball it is tested against.
##
## Demonstrated structurally: the initialiser takes a *side*, and nothing else.
## Two completely different incoming balls against the same fresh actor must
## produce the same preparation, because the ball is not an input to it.
func _a5_no_future_knowledge() -> void:
	print("\n" + "=".repeat(78))
	print("A5 -- the future ball does not choose the preparation")
	print("=".repeat(78))
	print("  %-26s %-18s" % ["ball would land at", "initialised facing"])
	var facings := {}
	for landing in [
		Vector2(0.20, 0.60), Vector2(0.80, 0.95), Vector2(0.50, 0.55),
		Vector2(0.05, 0.99),
	]:
		var actor := RallyPlayerState.create(_voli(), &"home", 1, Vector2(0.50, 0.80))
		facings[Vector2(actor.facing)] = true
		print("  (%.2f, %.2f)%-16s (%.3f, %.3f)" % [
			landing.x, landing.y, "", actor.facing.x, actor.facing.y,
		])
	print("  -> distinct facings %d   %s" % [
		facings.size(),
		"PASS -- the ball is not an input" if facings.size() == 1 else "FAIL",
	])


## A6 -- velocity and facing stay independent inputs.
func _a6_independence() -> void:
	print("\n" + "=".repeat(78))
	print("A6 -- velocity and facing are independent")
	print("=".repeat(78))
	var start := Vector2(0.50, 0.80)
	var target := Vector2(0.62, 0.66)
	var opening := RallyKinematics.court_delta_meters(start, target).normalized()
	print("  %-22s %-22s %-12s" % ["velocity", "facing", "travel_s"])
	var results := {}
	for velocity_name in ["still", "toward 1.5 m/s"]:
		for facing_name in ["toward", "away"]:
			var actor := RallyPlayerState.create(_voli(), &"home", 1, start)
			## Set directly rather than through `apply_position`, which derives
			## facing from velocity -- the point here is that the two can be set
			## apart and the model reads both.
			actor.velocity = opening * 1.5 if velocity_name != "still" else Vector2.ZERO
			actor.facing = opening if facing_name == "toward" else -opening
			var trip: Dictionary = RallyMovementSystemModel.traversal_result(
				actor, target, RallyPlayerState.MovementMode.LATERAL
			)
			results["%s|%s" % [velocity_name, facing_name]] = float(trip.seconds)
			print("  %-22s %-22s %-12.4f" % [
				velocity_name, facing_name, float(trip.seconds),
			])
	var facing_moves_it := absf(
		results["still|toward"] - results["still|away"]
	) > 0.0005
	var velocity_moves_it := absf(
		results["still|toward"] - results["toward 1.5 m/s|toward"]
	) > 0.0005
	print("  -> facing alone moves it %s, velocity alone moves it %s   %s" % [
		"yes" if facing_moves_it else "NO",
		"yes" if velocity_moves_it else "NO",
		"PASS" if facing_moves_it and velocity_moves_it else "FAIL",
	])


## A7 -- the claimant now sees a direction.
##
## The same defender, the same distance, the same clock. Only where the ball
## comes from moves. Before this pass all four rows were identical, because
## `evaluate_arrival` had no facing to read and its only startup term was an
## omnidirectional `reaction_delay`.
func _a7_claimant() -> void:
	print("\n" + "=".repeat(78))
	print("A7 -- the defensive claimant differs by direction")
	print("=".repeat(78))
	var at := Vector2(0.50, 0.80)
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = 901
	zone.zone_type = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	zone.center = at
	zone.radius_meters = 3.0
	zone.enabled = true
	## A home defender is set toward the net, which is low y.
	var facing := RallyPlayerState.side_relative_ready_facing(&"home")
	print("  home defender set toward the net; ball 2.5 m away on four sides.")
	print("  %-14s %-12s %-13s %-13s %-12s" % [
		"ball from", "facing_fit", "turn_delay_s", "reach_margin", "travel_s",
	])
	var margins := {}
	for label in ["the net (front)", "behind", "left", "right"]:
		var offset := Vector2.ZERO
		match label:
			"the net (front)": offset = Vector2(0.0, -2.5 / COURT_LENGTH_METERS)
			"behind": offset = Vector2(0.0, 2.5 / COURT_LENGTH_METERS)
			"left": offset = Vector2(-2.5 / COURT_WIDTH_METERS, 0.0)
			"right": offset = Vector2(2.5 / COURT_WIDTH_METERS, 0.0)
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			_voli(), zone, at + offset, 1.60, "reception", at, -1.0, facing
		)
		margins[snappedf(float(arrival.get("reach_margin_meters", 0.0)), 0.0001)] = true
		print("  %-14s %-12.4f %-13.4f %-13.4f %-12.4f" % [
			label, float(arrival.get("facing_fit", -1.0)),
			float(arrival.get("turn_delay_seconds", -1.0)),
			float(arrival.get("reach_margin_meters", 0.0)),
			float(arrival.get("travel_time", 0.0)),
		])
	print("  -> distinct reach margins %d   %s" % [
		margins.size(),
		"PASS -- the claimant is no longer direction-blind" if margins.size() > 1
			else "FAIL -- still one answer for four directions",
	])
