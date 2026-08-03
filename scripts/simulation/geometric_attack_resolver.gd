class_name GeometricAttackResolver
extends RefCounted

## Gate E. The five Gate B-D models composed into one call the resolver can make.
##
## Everything upstream of this is a pure model that knows nothing about a rally.
## This is the seam: one function that takes a hitter, a contact, a block and a
## defence, and returns a fully resolved swing -- course chosen, power chosen,
## swing delivered, ball flown, outcome read off where it landed.
##
## It exists so that promoting the geometry into `RallySimulator` is *one*
## substitution rather than five. The simulator has three attack paths and the
## serve has two more; wiring each of them to five models individually is how
## three copies of `_attack_execution` happened in the first place.
##
## Deterministic given its draws. Every random input arrives through `draws`,
## so a seeded rally replays identically and a caller can hand it fixed values
## to test a specific swing.

const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const AttackPowerModel := preload("res://scripts/simulation/attack_power_model.gd")
const AttackReadModel := preload("res://scripts/simulation/attack_read_model.gd")
const AttackSwingModel := preload("res://scripts/simulation/attack_swing_model.gd")
const AttackResolutionModel := preload(
	"res://scripts/simulation/attack_resolution_model.gd"
)
const SignatureMoveModel := preload(
	"res://scripts/simulation/signature_move_model.gd"
)
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const ApproachMechanicsModel := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)

## How many bearings across the repertoire cone get evaluated. Seventeen is
## enough to find the gap without the scan cost mattering; the chosen bearing is
## perturbed afterwards anyway, so this is a search resolution and not a menu.
const COURSE_SAMPLES: int = 17
## How much a hitter weighs an open lane against the strain of turning to reach
## it. Higher and everyone swings across their body at the biggest gap.
const STRAIN_AVERSION: float = 0.35


## One swing, start to finish.
##
## `draws` supplies every random input by name so the caller owns determinism:
## `read` (one per blocker, two each), `judgment`, `bearing`, `vertical`,
## `power`, `aim_fraction`, `intent`.
static func resolve_swing(
	hitter: VolleyballPlayer,
	contact: Vector2,
	contact_height_meters: float,
	lane: String,
	blockers: Array,
	defenders: Array,
	attacking_negative_y: bool,
	approach_quality: float,
	team_decisiveness: float,
	match_confidence: float,
	flow_for_team: float,
	draws: Dictionary,
) -> Dictionary:
	if hitter == null:
		return {"available": false, "reason": "no hitter"}

	## --- the courses this hitter could credibly swing -----------------------
	var approach_start := ApproachMechanicsModel.approach_start_position(
		contact, lane, &"home" if attacking_negative_y else &"opponent", contact
	)
	var natural := AttackCourseModel.natural_bearing_from_approach(
		approach_start, contact, attacking_negative_y
	)
	var swing_range := lerpf(
		22.0, 62.0,
		_rating(hitter, "shot_variety") * 0.6
			+ _rating(hitter, "attack_accuracy") * 0.4
	)
	var courses := AttackCourseModel.available_courses(
		contact, natural, swing_range, attacking_negative_y, COURSE_SAMPLES
	)
	if courses.is_empty():
		return {"available": false, "reason": "no legal course"}

	## --- what they believe is open ------------------------------------------
	var reading := _rating(hitter, "court_vision") * 0.5 \
		+ _rating(hitter, "decision_making") * 0.5
	var perceived_blockers := AttackReadModel.perceived_blockers(
		blockers, reading, Array(draws.get("read", []))
	)
	var perceived_defenders := AttackReadModel.perceived_defenders(
		defenders, reading, Array(draws.get("read_floor", []))
	)
	var aim_fraction := clampf(float(draws.get("aim_fraction", 0.46)), 0.0, 1.0)
	var best: Dictionary = courses[0]
	var best_score := -1.0e9
	for course in courses:
		var probe := AttackCourseModel.landing_point(
			contact, float(course.bearing_degrees),
			lerpf(
				float(course.near_meters), float(course.far_meters), aim_fraction
			),
			attacking_negative_y,
		)
		var openness := AttackReadModel.course_openness(
			contact, float(course.bearing_degrees), probe,
			perceived_blockers, perceived_defenders, attacking_negative_y,
		)
		var score := float(openness.openness) \
			- float(course.strain) * STRAIN_AVERSION
		if score > best_score:
			best_score = score
			best = course

	## --- how hard ------------------------------------------------------------
	var cost := AttackCourseModel.swing_cost(
		float(best.offset_degrees), swing_range
	)
	var ceiling := AttackPowerModel.available_ceiling_mps(
		_rating(hitter, "attack_power"), approach_quality,
		float(cost.power_fraction),
	)
	var aim_distance := lerpf(
		float(best.near_meters), float(best.far_meters), aim_fraction
	)
	var chosen := AttackPowerModel.choose_power(
		ceiling, float(draws.get("intent", AttackPowerModel.DRIVE_INTENT)),
		aim_distance, contact_height_meters,
		AttackPowerModel.aggression_from(
			float(hitter.ego) / 100.0, team_decisiveness,
			_rating(hitter, "tactical_discipline"),
		),
		_rating(hitter, "composure"),
		_rating(hitter, "decision_making"),
		_block_presence(blockers),
		float(draws.get("judgment", 0.0)),
	)

	## --- the angle that puts that speed where it was aimed -------------------
	var solved := BallFlightModel.solve_angle_for_range(
		float(chosen.speed_mps), aim_distance, contact_height_meters
	)
	var intended_angle := AttackPowerModel.DRIVEN_REFERENCE_ANGLE_DEGREES
	if bool(solved.get("driven_found", false)):
		intended_angle = float(solved.driven_angle_degrees)

	## --- what they actually did ----------------------------------------------
	var delivered := AttackSwingModel.deliver(
		float(best.bearing_degrees), intended_angle, float(chosen.speed_mps),
		_rating(hitter, "attack_accuracy"), float(cost.spread_multiplier),
		float(draws.get("bearing", 0.0)),
		float(draws.get("vertical", 0.0)),
		float(draws.get("power", 0.0)),
	)

	## --- where it ended up ----------------------------------------------------
	var resolved := AttackResolutionModel.resolve(
		contact, contact_height_meters,
		float(delivered.bearing_degrees),
		float(delivered.vertical_angle_degrees),
		float(delivered.speed_mps),
		blockers, attacking_negative_y,
	)

	## --- and whether it was a signature ---------------------------------------
	var move := {}
	var outcome := str(resolved.outcome)
	if outcome == "blocked":
		var contact_info: Dictionary = resolved.block
		move = SignatureMoveModel.resolve_contact(
			str(contact_info.get("kind", "touch")),
			float(delivered.speed_mps),
			float(delivered.bearing_error_degrees),
			float(contact_info.get("depth_below_reach_meters", 0.0)),
			blockers.size(),
			SignatureMoveModel.charge(
				SignatureMoveModel.crush_capability(
					_rating(hitter, "attack_power"),
					float(hitter.ego) / 100.0,
					_rating(hitter, "leadership"),
				),
				match_confidence, flow_for_team,
			),
			SignatureMoveModel.charge(
				SignatureMoveModel.high_hands_capability(
					_rating(hitter, "attack_accuracy"),
					_rating(hitter, "composure"),
					_rating(hitter, "decision_making"),
				),
				match_confidence, flow_for_team,
			),
		)
		outcome = str(move.outcome)

	return {
		"available": true,
		"outcome": outcome,
		"course": best,
		"natural_bearing_degrees": natural,
		"swing_range_degrees": swing_range,
		"power": chosen,
		"delivered": delivered,
		"resolution": resolved,
		"signature_move": move,
		"landing": resolved.landing,
		"flight": resolved.flight,
		## What a rally record and the action vocabulary read: why this ball did
		## what it did, in terms a person can say out loud.
		"narrative": {
			"power_bias": str(chosen.bias),
			"miss_channel": str(delivered.dominant_channel),
			"reached": bool(chosen.reachable),
			"attempted_move": str(move.get("attempted_move", "")),
			"move_succeeded": bool(move.get("move_succeeded", false)),
			"confidence_cost": float(move.get("confidence_cost", 0.0)),
		},
	}


## How formed the wall in front of the hitter is, 0-1. Two blockers is a full
## wall; one is half a problem; none is an open net.
static func _block_presence(blockers: Array) -> float:
	return clampf(float(blockers.size()) * 0.5, 0.0, 1.0)


static func _rating(player: VolleyballPlayer, attribute: String) -> float:
	return clampf(float(player.get(attribute)) / 100.0, 0.0, 1.0)
