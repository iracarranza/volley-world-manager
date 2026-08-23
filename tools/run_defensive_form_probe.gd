extends SceneTree

## Policy section 8: can the defensive resolver choose between
##
##     retain facing + LATERAL      versus      turn/open + TRANSITION
##
## using only relations the engine already has?
##
##     godot --headless --path . --script res://tools/run_defensive_form_probe.gd
##
## The comparison needs **two** numbers per form -- what it costs to enter that
## form from the body's current orientation, and how fast the body then moves.
## This probe asks whether coverage has either.
##
## The first draft of this probe asserted the turn half was already form-aware
## and only the speed half was missing. That was wrong, and the table in half 1
## is what corrected it: the turn cost is deliberately normalised against each
## mode's own reference cadence, so the mode cancels out. Recorded because a
## boundary claimed from architecture rather than measurement is exactly the
## failure this repository keeps catching.
##
## Deterministic. No rally is resolved and no RNG is drawn.

const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

const DEFENDER_AT := Vector2(0.50, 0.80)


func _initialize() -> void:
	_half_one_turn()
	_half_two_speed()
	_half_three_binding()
	_verdict()
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


func _turn(
	player: VolleyballPlayer, mode: RallyPlayerState.MovementMode, fit: float
) -> float:
	return LocomotionModel.direction_change_seconds(
		player, mode, fit,
		RallyMovementSystemModel.TURN_DELAY_WORST_SECONDS,
		RallyMovementSystemModel.TURN_DELAY_BEST_SECONDS,
	)


## ------------------------------------------------------------------- half 1
##
## What does it cost to *enter* each form from a given orientation?
##
## `direction_change_seconds` looks mode-aware -- it takes a mode. It is not, in
## the sense this comparison needs:
##
##     geometric * clamp(reference_cadence_hz(mode) / cadence_hz(player, mode))
##
## Both terms of that ratio are the same mode's, so it measures how far *this
## player's* turnover sits from the midpoint of the band *for that mode*, never
## how the modes differ from each other. A player at their band's midpoint gets
## a factor of exactly 1.0 in every mode.
func _half_one_turn() -> void:
	print("=".repeat(78))
	print("HALF 1 -- what it costs to enter a form.  NOT FORM-AWARE.")
	print("=".repeat(78))
	print("  A reference voli (every rating 50), turning through five fits.\n")
	print("  %-12s %-14s %-14s %-14s" % [
		"facing_fit", "LATERAL_s", "TRANSITION_s", "difference",
	])
	var player := _voli()
	var spread := 0.0
	for fit in [1.0, 0.75, 0.5, 0.25, 0.0]:
		var lateral := _turn(player, RallyPlayerState.MovementMode.LATERAL, float(fit))
		var transition := _turn(
			player, RallyPlayerState.MovementMode.TRANSITION, float(fit)
		)
		spread = maxf(spread, absf(transition - lateral))
		print("  %-12.2f %-14.4f %-14.4f %-14.4f" % [
			float(fit), lateral, transition, transition - lateral,
		])
	print("\n  largest difference across every fit: %.6f s" % spread)
	print("\n  And it is not a property of this one voli. Across the roster the")
	print("  cost still moves -- but it moves with the *player*, identically in")
	print("  both forms:\n")
	print("  %-14s %-14s %-14s %-14s" % [
		"lateral_speed", "LATERAL_s", "TRANSITION_s", "difference",
	])
	for rating in [15, 35, 50, 70, 90]:
		var voli := _voli({"lateral_speed": rating, "transition_speed": rating})
		var lateral := _turn(voli, RallyPlayerState.MovementMode.LATERAL, 0.0)
		var transition := _turn(voli, RallyPlayerState.MovementMode.TRANSITION, 0.0)
		print("  %-14d %-14.4f %-14.4f %-14.4f" % [
			rating, lateral, transition, transition - lateral,
		])
	print("\n  -> **there is no cost to opening up.** The engine prices changing")
	print("     direction; it does not price changing form. A defender who turns")
	print("     their hips to sprint and one who shuffles square pay the same.")


## ------------------------------------------------------------------- half 2
##
## And the speed, which is the other half.
func _half_two_speed() -> void:
	print("\n" + "=".repeat(78))
	print("HALF 2 -- how fast each form moves.  NOT AVAILABLE TO COVERAGE.")
	print("=".repeat(78))
	print("  ENABLE_UNIFIED_SPEED_MODEL = %s\n" % str(
		RallyFeatureFlags.ENABLE_UNIFIED_SPEED_MODEL
	))
	print("  %-10s %-17s %-17s %-19s %-12s" % [
		"rating", "coverage today", "unified LATERAL", "unified TRANSITION",
		"today vs LAT",
	])
	for rating in [20, 40, 50, 60, 80, 95]:
		var player := _voli({
			"lateral_speed": rating, "transition_speed": rating,
		})
		var legacy := LocomotionModel.legacy_maximum_speed(
			player, float(rating) / 100.0,
			LocomotionModel.LEGACY_COVERAGE_CEILING_MPS,
		)
		var lateral := LocomotionModel.maximum_speed(
			player, RallyPlayerState.MovementMode.LATERAL
		)
		var transition := LocomotionModel.maximum_speed(
			player, RallyPlayerState.MovementMode.TRANSITION
		)
		print("  %-10d %-17.4f %-17.4f %-19.4f %-12s" % [
			rating, legacy, lateral, transition,
			"%+.0f%%" % ((legacy / maxf(lateral, 0.01) - 1.0) * 100.0),
		])
	print("\n  The second column is what `evaluate_arrival` actually spends:")
	print("  `legacy_maximum_speed(player, lateral_speed/100, 4.65)`. It takes no")
	print("  mode. There is no LATERAL speed and no TRANSITION speed in that")
	print("  branch -- one ceiling covers every movement a defender makes, and")
	print("  the last column is what switching to the per-mode model would do to")
	print("  every defensive arrival in the game before any form was compared.")


## ------------------------------------------------------------------- half 3
##
## Suppose both halves existed. How much would the comparison actually be worth
## inside a defensive window?
##
## `reachable_distance` ramps from a standstill, so top speed only enters once
## the window outlasts the acceleration to it. Below that, the two forms differ
## by nothing at all, because neither body ever reaches its own ceiling.
func _half_three_binding() -> void:
	print("\n" + "=".repeat(78))
	print("HALF 3 -- when a form's top speed would even bind")
	print("=".repeat(78))
	var player := _voli()
	var accel := lerpf(2.2, 6.8, float(player.acceleration) / 100.0)
	var lateral_top := LocomotionModel.maximum_speed(
		player, RallyPlayerState.MovementMode.LATERAL
	) * LocomotionModel.mass_factor(player)
	var transition_top := LocomotionModel.maximum_speed(
		player, RallyPlayerState.MovementMode.TRANSITION
	) * LocomotionModel.mass_factor(player)
	print("  acceleration %.3f m/s^2; LATERAL tops at %.3f, TRANSITION at %.3f."
		% [accel, lateral_top, transition_top])
	print("  Reaching those tops takes %.3f s and %.3f s from a standstill.\n"
		% [lateral_top / accel, transition_top / accel])
	print("  %-16s %-16s %-16s %-16s" % [
		"available_s", "LATERAL_m", "TRANSITION_m", "gain",
	])
	for available in [0.30, 0.50, 0.58, 0.80, 1.20, 1.80]:
		var lateral := RallyMovementSystemModel.reachable_distance(
			float(available), lateral_top, accel
		)
		var transition := RallyMovementSystemModel.reachable_distance(
			float(available), transition_top, accel
		)
		print("  %-16.2f %-16.4f %-16.4f %-16.4f" % [
			float(available), lateral, transition, transition - lateral,
		])
	print("\n  A defensive window is `ball_time - reaction_delay - turn_delay`.")
	print("  For a reference voli that is roughly 1.10 - 0.37 - 0.20 = 0.53 s on")
	print("  a hard-driven ball, which is inside the flat region above.")


func _verdict() -> void:
	print("\n" + "=".repeat(78))
	print("VERDICT -- BLOCKED, and on two independent grounds")
	print("=".repeat(78))
	print("  1. There is no cost to opening up. `direction_change_seconds`")
	print("     normalises each mode against its own reference cadence, so the")
	print("     mode cancels and turning to sprint is priced identically to")
	print("     shuffling square. A comparison whose two branches pay the same")
	print("     entry fee is not a comparison; whichever form is faster simply")
	print("     wins always, which is a rule, not a decision.")
	print("")
	print("  2. Coverage has no per-form speed. ENABLE_UNIFIED_SPEED_MODEL is")
	print("     false, so `evaluate_arrival` runs on one legacy ceiling with no")
	print("     mode in it. Flipping that flag to obtain the second form changes")
	print("     every defensive arrival in the game by up to 39%, which is a")
	print("     locomotion rebalance wearing an orientation repair's clothes.")
	print("")
	print("  Either one alone is a stop. Neither is repairable by measurement of")
	print("  something already present: both need a relation nobody has measured")
	print("  -- what a hip turn costs, and what a defender's real per-form top")
	print("  speed is. No coefficient is guessed here to paper over that.")
