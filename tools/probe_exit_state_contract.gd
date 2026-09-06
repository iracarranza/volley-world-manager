extends SceneTree

## C0 — the exit state of a movement leg, from all three places that state it.
##
##     godot --headless --path . --script res://tools/probe_exit_state_contract.gd
##
## Three answers exist for one leg and this prints them side by side:
##
##   closed   `RallyMovementSystem.traversal_result().exit_velocity` -- what
##            `RallySimulator._travel` returns and `live_velocities` stores.
##   final    the last velocity sample of the integrated path -- what the drawn
##            body is actually doing.
##   path     `RallyMovementPath.exit_velocity`, which is `final` by
##            construction, and is what the authoritative record publishes.
##
## `closed` and `final` are the pair the audit found disagreeing. The four cases
## are the ones `EMBODIED_MOVEMENT_CONTINUITY.md` C0.3 requires a single contract
## to cover: reached, unreached/truncated, waypointed, and a target off the court.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const Movement := preload("res://scripts/simulation/rally_movement_system.gd")
const Integrator := preload("res://scripts/simulation/shadow_movement_system.gd")
const PathModel := preload("res://scripts/models/rally_movement_path.gd")

var _player: VolleyballPlayer = null


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	for candidate in manager.players:
		if candidate != null:
			_player = candidate
			break
	if _player == null:
		push_error("no player to probe")
		quit(2)
		return

	print("=== C0 exit state, one leg, three answers ===")
	print("case|distance_m|entry_mps|reached|closed_mps|final_mps|path_mps|disagreement_mps")
	_reached_block()
	_truncated_block()
	_waypoint_block()
	_off_court_block()
	quit()


## Legs given exactly the time the closed form says they need: the body arrives.
func _reached_block() -> void:
	for distance: float in [1.0, 1.5, 3.0, 5.0, 8.0]:
		for entry: float in [0.0, 3.0, 6.0]:
			_row("reached", distance, entry, 1.0)


## Legs given less time than they need: the body is still travelling.
func _truncated_block() -> void:
	for distance: float in [3.0, 8.0]:
		for entry: float in [0.0, 6.0]:
			for fraction: float in [0.35, 0.70]:
				_row("truncated", distance, entry, fraction)


## A corner the body runs through rather than stopping on.
func _waypoint_block() -> void:
	for distance: float in [3.0, 6.0]:
		for entry: float in [0.0, 4.0]:
			_row("waypoint", distance, entry, 1.0, true)


## A target the integrator will clamp to the court and the closed form will not.
func _off_court_block() -> void:
	for distance: float in [3.0, 6.0]:
		_row("off_court", distance, 0.0, 1.0, false, true)


func _row(
	label: String,
	distance_meters: float,
	entry_speed: float,
	time_fraction: float,
	use_waypoint: bool = false,
	off_court: bool = false,
) -> void:
	var start := Vector2(0.5, 0.5)
	var target := _along_y(start, distance_meters)
	if off_court:
		## Past the baseline, which the integrator clamps and the closed form does
		## not -- the divergence isolated in the audit's A8b.
		target = _along_y(start, distance_meters + 12.0)
	var corner: Variant = _along_y(start, distance_meters * 0.5) if use_waypoint \
		else null

	var actor := RallyPlayerState.create(_player, &"home", -1, start)
	## Entry momentum points at the target, so this measures arrival semantics
	## and not the reversal question C2 owns.
	actor.velocity = Vector2(0.0, 1.0).normalized() * entry_speed

	var closed: Dictionary = Movement.traversal_result(
		actor, target, RallyPlayerState.MovementMode.TRANSITION, corner
	)
	var seconds := float(closed["seconds"]) * time_fraction
	if seconds <= 0.0:
		return
	var integration: Dictionary = Integrator.integrate(
		actor, target, seconds, RallyPlayerState.MovementMode.TRANSITION,
		Integrator.DEFAULT_STEP_SECONDS, corner
	)
	if not bool(integration.get("available", false)):
		print("%s|%.1f|%.1f|unavailable: %s" % [
			label, distance_meters, entry_speed,
			str(integration.get("reason", "")),
		])
		return
	var path: RallyMovementPath = PathModel.from_integration(integration, 0.0)
	var closed_speed := Vector2(closed["exit_velocity"]).length()
	var final_speed := float(integration["final_speed_mps"])
	var path_speed := path.exit_velocity.length() if path != null else NAN
	## When these two differ the body arrived before the leg ended and stood for
	## the remainder, which is the one case the contract says exits at rest.
	var moving_time := float(integration["moving_time_seconds"])
	var last_move := float(integration["sample_times"][
		integration["sample_times"].size() - 1
	]) - float(integration["turn_delay_seconds"])
	print("%s|%.1f|%.1f|%s|%.3f|%.3f|%.3f|%.3f|idle %.3f s" % [
		label, distance_meters, entry_speed,
		"yes" if bool(integration["reached_target"]) else "no",
		closed_speed, final_speed, path_speed,
		absf(closed_speed - final_speed),
		maxf(moving_time - last_move, 0.0),
	])


## A point `metres` down-court from `from`, using the y axis' own scale.
func _along_y(from: Vector2, metres: float) -> Vector2:
	return from + Vector2(0.0, metres / RallyKinematics.COURT_LENGTH_METERS)
