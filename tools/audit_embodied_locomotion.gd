extends SceneTree

## A3 — controlled locomotion counterfactuals, through the production model.
##
##     godot --headless --path . --script res://tools/audit_embodied_locomotion.gd
##
## Every number here comes from `RallyMovementSystem`, which is what
## `RallySimulator._travel` and `_committed_path` call. Nothing is re-derived.
##
## The question each block answers is not "does the model have this input" but
## "does changing it change a physical result, and by how much" -- and then,
## separately, "does the production call path actually supply it".
##
## Confounders held constant unless named as the varied factor: one player
## profile, one mode, one start, one target geometry per row, no RNG.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const Movement := preload("res://scripts/simulation/rally_movement_system.gd")
const Integrator := preload("res://scripts/simulation/shadow_movement_system.gd")

## A metre, in the normalised court units positions are expressed in. Derived
## from the kinematics helper rather than assumed, so a court resize cannot
## silently rescale this whole audit.
var _unit_per_meter: float = 0.0
var _player: VolleyballPlayer = null


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	for candidate in manager.players:
		if candidate != null:
			_player = candidate
			break
	if _player == null:
		push_error("no player to audit")
		quit(2)
		return
	var probe := Vector2(0.5, 0.5)
	_unit_per_meter = 0.01 / maxf(RallyKinematics.court_distance_meters(
		probe, probe + Vector2(0.01, 0.0)
	), 0.00001)
	print("player|%s|acceleration %d|mass %.1f|fatigue %.2f" % [
		_player.display_name if "display_name" in _player else "?",
		_player.acceleration, _player.mass_kg, _player.fatigue,
	])
	print("court units per metre (x axis): %.5f" % _unit_per_meter)
	_facing_block()
	_velocity_block()
	_body_state_block()
	_attribute_block()
	_production_supply_block()
	_reachability_split_block()
	quit()


## An actor at the origin of the audit, with everything stated explicitly so no
## row can differ in something the header does not name.
func _actor(
	velocity_mps: Vector2, facing: Vector2, body: int, fatigue: float
) -> RallyPlayerState:
	var profile: VolleyballPlayer = _player.duplicate(true)
	profile.fatigue = fatigue
	var actor := RallyPlayerState.create(profile, &"home", -1, Vector2(0.5, 0.5))
	actor.velocity = velocity_mps
	actor.facing = facing
	actor.body_state = body
	return actor


## A target a true metric distance away on a given bearing.
##
## The court is 9 m across and 18 m long in the *same* normalised unit, so one
## unit is not one distance -- an offset has to be divided per axis. Scaling a
## unit vector by the x-axis figure made a "6 m" target along y actually 12 m
## away, and the block below then reported the court clamp as a model
## disagreement. Bearing 0 was right by accident, which is why the A3 blocks
## above are unaffected.
func _target_at(distance_meters: float, bearing_degrees: float) -> Vector2:
	var radians := deg_to_rad(bearing_degrees)
	var metres := Vector2(cos(radians), sin(radians)) * distance_meters
	return Vector2(0.5, 0.5) + Vector2(
		metres.x / RallyKinematics.COURT_WIDTH_METERS,
		metres.y / RallyKinematics.COURT_LENGTH_METERS,
	)


func _seconds(actor: RallyPlayerState, target: Vector2) -> float:
	return float(Movement.traversal_result(
		actor, target, RallyPlayerState.MovementMode.TRANSITION
	)["seconds"])


# --- A3.2 facing -----------------------------------------------------------

## Facing is a modelled locomotion cost: `_movement_profile` turns
## `facing . direction` into `facing_fit` and feeds it to
## `LocomotionModel.direction_change_seconds`. This measures what that cost is
## worth, so the next block can say what production discards by zeroing it.
func _facing_block() -> void:
	print("")
	print("=== A3.2 facing, entry velocity zero, TRANSITION ===")
	print("distance_m|facing_vs_travel_deg|seconds|delta_vs_aligned_s")
	for distance: float in [1.5, 3.0, 5.0]:
		var target := _target_at(distance, 0.0)
		var aligned := _seconds(
			_actor(Vector2.ZERO, Vector2(1.0, 0.0),
				RallyPlayerState.BodyState.BALANCED, 0.0), target
		)
		for degrees: float in [0.0, 45.0, 90.0, 135.0, 180.0]:
			var radians := deg_to_rad(degrees)
			var facing := Vector2(cos(radians), sin(radians))
			var seconds := _seconds(
				_actor(Vector2.ZERO, facing,
					RallyPlayerState.BodyState.BALANCED, 0.0), target
			)
			print("%.1f|%.0f|%.4f|%+.4f" % [
				distance, degrees, seconds, seconds - aligned,
			])
		## The production case: `_travel` and `_committed_path` overwrite the
		## actor's ready facing with `Vector2.ZERO`, and `_movement_profile`
		## reads a zero-length facing as a perfect fit.
		var zeroed := _seconds(
			_actor(Vector2.ZERO, Vector2.ZERO,
				RallyPlayerState.BodyState.BALANCED, 0.0), target
		)
		print("%.1f|ZEROED(production)|%.4f|%+.4f" % [
			distance, zeroed, zeroed - aligned,
		])


# --- A3.1 direction and momentum -------------------------------------------

## Carried velocity enters `_leg_seconds` as `max(velocity . direction, 0)`, so
## only the component already aimed at the target is credited and motion away is
## discarded rather than charged. This measures whether a body sprinting away
## from its target is worse off than one standing still -- physically it must
## be, because it has to stop first.
func _velocity_block() -> void:
	print("")
	print("=== A3.1 entry velocity x angle to target, 3.0 m, TRANSITION ===")
	print("entry_speed_mps|angle_to_target_deg|seconds|exit_speed_mps"
		+ "|delta_vs_stationary_s")
	var target := _target_at(3.0, 0.0)
	var stationary := _seconds(
		_actor(Vector2.ZERO, Vector2.ZERO,
			RallyPlayerState.BodyState.BALANCED, 0.0), target
	)
	for speed: float in [0.0, 1.5, 3.0, 4.5, 6.0]:
		for degrees: float in [0.0, 45.0, 90.0, 135.0, 180.0]:
			var radians := deg_to_rad(degrees)
			var velocity: Vector2 = Vector2(cos(radians), sin(radians)) * float(speed)
			var actor := _actor(
				velocity, Vector2.ZERO,
				RallyPlayerState.BodyState.BALANCED, 0.0
			)
			var result: Dictionary = Movement.traversal_result(
				actor, target, RallyPlayerState.MovementMode.TRANSITION
			)
			print("%.1f|%.0f|%.4f|%.3f|%+.4f" % [
				speed, degrees, float(result["seconds"]),
				Vector2(result.get("exit_velocity", Vector2.ZERO)).length(),
				float(result["seconds"]) - stationary,
			])


# --- A3.3 body state -------------------------------------------------------

## `rally_movement_system.gd` names `body_state` once, on a snapshot, and never
## in its locomotion arithmetic. This is the falsification test for that
## reading: if any row differs, the claim is wrong.
func _body_state_block() -> void:
	print("")
	print("=== A3.3 body state, 3.0 m, entry velocity zero ===")
	print("body_state|seconds|delta_vs_balanced_s")
	var target := _target_at(3.0, 0.0)
	var baseline := _seconds(
		_actor(Vector2.ZERO, Vector2.ZERO,
			RallyPlayerState.BodyState.BALANCED, 0.0), target
	)
	var names := RallyPlayerState.BodyState.keys()
	for index in range(names.size()):
		var seconds := _seconds(
			_actor(Vector2.ZERO, Vector2.ZERO, index, 0.0), target
		)
		print("%s|%.4f|%+.4f" % [str(names[index]), seconds, seconds - baseline])


# --- A3.4 attributes and morphology ----------------------------------------

func _attribute_block() -> void:
	print("")
	print("=== A3.4 attributes, 3.0 m, entry velocity zero ===")
	print("factor|value|seconds|delta_vs_typical_s")
	var target := _target_at(3.0, 0.0)
	var typical := _seconds(
		_actor(Vector2.ZERO, Vector2.ZERO,
			RallyPlayerState.BodyState.BALANCED, 0.0), target
	)
	print("baseline|as-seeded|%.4f|%+.4f" % [typical, 0.0])
	for value: int in [10, 50, 90]:
		var actor := _actor(
			Vector2.ZERO, Vector2.ZERO,
			RallyPlayerState.BodyState.BALANCED, 0.0
		)
		actor.player.acceleration = value
		var seconds := _seconds(actor, target)
		print("acceleration|%d|%.4f|%+.4f" % [value, seconds, seconds - typical])
	for mass: float in [58.0, 82.0, 118.0]:
		var actor := _actor(
			Vector2.ZERO, Vector2.ZERO,
			RallyPlayerState.BodyState.BALANCED, 0.0
		)
		actor.player.mass_kg = mass
		var seconds := _seconds(actor, target)
		print("mass_kg|%.0f|%.4f|%+.4f" % [mass, seconds, seconds - typical])
	for fatigue: float in [0.0, 0.5, 1.0]:
		var seconds := _seconds(
			_actor(Vector2.ZERO, Vector2.ZERO,
				RallyPlayerState.BodyState.BALANCED, fatigue), target
		)
		print("fatigue|%.1f|%.4f|%+.4f" % [fatigue, seconds, seconds - typical])


# --- what production actually supplies -------------------------------------

## The counterfactuals above say what the model *can* charge. This says what the
## production call path *does* charge, by reproducing the two constructions
## verbatim: both build a fresh actor -- which `create` gives a real
## side-relative ready facing -- and then assign the caller's `entry_facing`,
## which all sixteen `_committed_path` call sites leave defaulted.
func _production_supply_block() -> void:
	print("")
	print("=== production supply, 3.0 m, entry velocity 4.0 m/s across ===")
	print("case|facing|seconds")
	var target := _target_at(3.0, 0.0)
	var across: Vector2 = Vector2(0.0, 1.0) * 4.0
	var ready_facing := RallyPlayerState.side_relative_ready_facing(&"home")
	var kept := _actor(
		across, ready_facing, RallyPlayerState.BodyState.BALANCED, 0.0
	)
	print("create() default kept|(%.2f, %.2f)|%.4f" % [
		ready_facing.x, ready_facing.y, _seconds(kept, target),
	])
	var overwritten := _actor(
		across, Vector2.ZERO, RallyPlayerState.BodyState.BALANCED, 0.0
	)
	print("overwritten by entry_facing default|(0.00, 0.00)|%.4f" % \
		_seconds(overwritten, target))
	var opposed := _actor(
		across, Vector2(-1.0, 0.0), RallyPlayerState.BodyState.BALANCED, 0.0
	)
	print("facing away from target|(-1.00, 0.00)|%.4f" % _seconds(opposed, target))


# --- A8 the two reachability answers ---------------------------------------

## `_committed_path` asks the closed form how long the leg takes and then hands
## that duration to the stepped integrator to draw. If the two models disagree,
## the body is drawn for exactly as long as the closed form said and arrives
## wherever the integrator puts it -- so the disagreement shows up as distance
## still owed at the end of a leg the resolver believes is complete.
##
## This is the D1 split, stressed on controlled geometry rather than sampled
## from whatever rallies happened to contain.
func _reachability_split_block() -> void:
	print("")
	print("=== A8 closed form vs integrator, TRANSITION ===")
	print("distance_m|entry_speed_mps|entry_angle_deg|closed_form_s"
		+ "|integrated_shortfall_m|reached_flag")
	var worst := 0.0
	var rows := 0
	var disagreeing := 0
	## Targets along the 18 m axis. Laid out along the 9 m axis a 6 m leg from
	## mid-court lands at x = 1.167, and every row then reported the same 1.500 m
	## "disagreement" -- which was the *integrator clamping to the court* while
	## the closed form happily timed a journey off it. That is a real difference
	## between the two models, recorded in the review, but it is not the
	## distance-scaling question this block is asking.
	for distance: float in [1.0, 2.5, 4.0, 6.0, 8.0]:
		var target := _target_at(distance, 90.0)
		for speed: float in [0.0, 2.0, 4.0, 6.0]:
			for degrees: float in [0.0, 90.0, 180.0]:
				var radians := deg_to_rad(degrees)
				var velocity: Vector2 = Vector2(cos(radians), sin(radians)) \
					* float(speed)
				var actor := _actor(
					velocity, Vector2.ZERO,
					RallyPlayerState.BodyState.BALANCED, 0.0
				)
				var seconds := _seconds(actor, target)
				var integration: Dictionary = Integrator.integrate(
					_actor(velocity, Vector2.ZERO,
						RallyPlayerState.BodyState.BALANCED, 0.0),
					target, seconds, RallyPlayerState.MovementMode.TRANSITION,
				)
				## The integrator returns a trail, not a point: the landing is
				## its last sample. Reading a non-existent `position` key gave
				## shortfalls larger than the court, which is how this instrument
				## announced it was wrong rather than reporting a finding.
				var trail: Array = integration.get("trail", [])
				if trail.is_empty():
					continue
				var landing: Vector2 = Vector2(trail[trail.size() - 1])
				var shortfall := RallyKinematics.court_distance_meters(
					landing, target
				)
				rows += 1
				if shortfall > 0.05:
					disagreeing += 1
				worst = maxf(worst, shortfall)
				print("%.1f|%.1f|%.0f|%.4f|%.3f|%s" % [
					distance, speed, degrees, seconds, shortfall,
					str(integration.get("reached_target", false)),
				])
	print("rows|%d" % rows)
	print("rows_short_by_over_5cm|%d" % disagreeing)
	print("worst_shortfall_m|%.3f" % worst)
