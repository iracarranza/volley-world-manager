class_name AttackGeometryCalibration
extends RefCounted

## Gate D. What the Gate B and C models actually produce, swept over a generated
## population, against the rates the design is aiming at.
##
## The point of this harness is that under the geometric model **no rate is
## settable**. There is no stuff-rate constant to move. Kill rate, error rate and
## block rate are all consequences of angular spreads, power ranges, contact
## heights and blocker reach, and the only honest way to know what they are is
## to run the models and count.
##
## Nothing here touches `RallySimulator`. It samples the decision and resolution
## chain directly -- courses, power, swing, resolve -- so the emergent mix can be
## read before any of it is wired.

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const AttackPowerModel := preload("res://scripts/simulation/attack_power_model.gd")
const AttackReadModel := preload("res://scripts/simulation/attack_read_model.gd")
const AttackSwingModel := preload("res://scripts/simulation/attack_swing_model.gd")
const AttackResolutionModel := preload(
	"res://scripts/simulation/attack_resolution_model.gd"
)
const ApproachMechanicsModel := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)
const CourtConstants := preload("res://scripts/data/court_constants.gd")
const BallFlightModelRef := preload(
	"res://scripts/simulation/ball_flight_model.gd"
)

## Contact happens just below the top of a hitter's reach -- struck in front of
## and slightly under full extension, not at the fingertip limit.
##
## These two constants together decide the entire block contest, which is the
## single largest finding of this gate. The block test is
## `ball_height_at_net vs blocker_reach`, so what matters is the *difference*
## between where a hitter contacts and how high a blocker gets:
##
##   hitter  = standing_reach + leap - CONTACT_BELOW_REACH
##   blocker = standing_reach + leap * BLOCKER_REACH_EFFORT
##
## At 0.22 and 0.72 the hitter contacted **6 cm below** the blocker's reach, so
## essentially every attack met hands and 36% were stuffed. Real volleyball has
## the hitter contacting comfortably above the block -- that is why attacking
## works at all. At 0.10 and 0.62 the hitter is 12 cm above, which restores a
## gradient instead of a step.
const CONTACT_BELOW_REACH_METERS: float = 0.10
## A blocker jumps from a standstill or a shuffle rather than a full approach,
## and gets appreciably less of their leap than a hitter does.
const BLOCKER_REACH_EFFORT: float = 0.62
const BLOCKER_HALF_WIDTH_METERS: float = 0.45

## Lanes a hitter can be set to, and how often each is used. Pins carry the
## offence, which is what makes their lopsided course cones matter.
const LANE_WEIGHTS := {
	"Left Pin": 0.34, "Right Pin": 0.24, "Front Quick": 0.16,
	"Right Quick": 0.12, "Pipe": 0.14,
}


## `contact_height_override` runs the sweep at a stated contact height instead of
## the one `jumping_reach_cm()` produces, so a geometry problem can be told apart
## from an input problem. Zero uses the model.
static func run(
	sample_count: int = 4000,
	seed_value: int = 20260803,
	contact_height_override: float = 0.0,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hitters := _population(rng)
	var blockers_pool := _population(rng)

	var tally := {
		"in": 0, "out_long": 0, "out_wide": 0, "out_antenna": 0,
		"net": 0, "stuff": 0, "touch": 0, "tool": 0,
	}
	var bias_tally := {}
	var channel_tally := {}
	var speeds: Array[float] = []
	var heights: Array[float] = []
	var clearances: Array[float] = []
	var unreachable := 0

	for index in range(sample_count):
		var hitter: VolleyballPlayer = hitters[rng.randi_range(0, hitters.size() - 1)]
		var lane := _weighted_lane(rng)
		var contact_x: float = CourtConstants.LANE_X[lane]
		var contact := Vector2(contact_x, 0.52)
		var contact_height := hitter.jumping_reach_cm() / 100.0 \
			- CONTACT_BELOW_REACH_METERS
		if contact_height_override > 0.0:
			contact_height = contact_height_override

		## Where they ran in from, and therefore what they can swing at.
		var approach_start := ApproachMechanicsModel.approach_start_position(
			contact, lane, &"home", contact
		)
		var natural := AttackCourseModel.natural_bearing_from_approach(
			approach_start, contact, true
		)
		var swing_range := lerpf(
			22.0, 62.0,
			_rating(hitter, "shot_variety") * 0.6
				+ _rating(hitter, "attack_accuracy") * 0.4
		)
		var courses := AttackCourseModel.available_courses(
			contact, natural, swing_range, true, 17
		)
		if courses.is_empty():
			continue

		var blocker_count := 1 if rng.randf() < 0.62 else 2
		var blockers := _block_at(
			contact_x, blocker_count, blockers_pool, rng
		)

		## Pick the course the hitter believes is most open, from a blurred read.
		var reading := _rating(hitter, "court_vision") * 0.5 \
			+ _rating(hitter, "decision_making") * 0.5
		var read_draws: Array = []
		for _draw in range(blockers.size() * 2):
			read_draws.append(rng.randfn(0.0, 1.0))
		var perceived := AttackReadModel.perceived_blockers(
			blockers, reading, read_draws
		)
		var best: Dictionary = courses[0]
		var best_score := -1.0e9
		for course in courses:
			var reach_far: float = float(course.far_meters)
			var landing := AttackCourseModel.landing_point(
				contact, float(course.bearing_degrees), reach_far * 0.82, true
			)
			var openness: Dictionary = AttackReadModel.course_openness(
				contact, float(course.bearing_degrees), landing,
				perceived, [], true
			)
			var score := float(openness.openness) * 1.0 \
				- float(course.strain) * 0.35
			if score > best_score:
				best_score = score
				best = course

		## How hard, from temperament.
		var cost := AttackCourseModel.swing_cost(
			float(best.offset_degrees), swing_range
		)
		var ceiling := AttackPowerModel.available_ceiling_mps(
			_rating(hitter, "attack_power"),
			rng.randf_range(0.45, 0.95),
			float(cost.power_fraction),
		)
		var aim_distance: float = lerpf(
			float(best.near_meters), float(best.far_meters),
			rng.randf_range(0.30, 0.62)
		)
		## Most swings are drives; a minority are control balls or off-speed.
		var intent_roll := rng.randf()
		var intent_fraction: float = AttackPowerModel.DRIVE_INTENT
		if intent_roll > 0.86:
			intent_fraction = AttackPowerModel.OFF_SPEED_INTENT
		elif intent_roll > 0.66:
			intent_fraction = AttackPowerModel.CONTROL_INTENT
		var chosen := AttackPowerModel.choose_power(
			ceiling, intent_fraction, aim_distance, contact_height,
			AttackPowerModel.aggression_from(
				float(hitter.ego) / 100.0, 0.5,
				_rating(hitter, "tactical_discipline")
			),
			_rating(hitter, "composure"),
			_rating(hitter, "decision_making"),
			clampf(float(blockers.size()) * 0.5, 0.0, 1.0),
			rng.randfn(0.0, 1.0),
		)

		## The angle that would carry the intended distance at that speed.
		var solved := BallFlightModelRef.solve_angle_for_range(
			float(chosen.speed_mps), aim_distance, contact_height
		)
		var intended_angle := -14.0
		if bool(solved.get("driven_found", false)):
			intended_angle = float(solved.driven_angle_degrees)

		var delivered := AttackSwingModel.deliver(
			float(best.bearing_degrees), intended_angle,
			float(chosen.speed_mps),
			_rating(hitter, "attack_accuracy"),
			float(cost.spread_multiplier),
			rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0),
		)
		var resolved := AttackResolutionModel.resolve(
			contact, contact_height,
			float(delivered.bearing_degrees),
			float(delivered.vertical_angle_degrees),
			float(delivered.speed_mps),
			blockers, true,
		)

		speeds.append(float(delivered.speed_mps))
		heights.append(contact_height)
		clearances.append(clampf(float(resolved.net_clearance_meters), -5.0, 5.0))
		if not bool(solved.get("driven_found", false)):
			unreachable += 1
		var bias := str(chosen.bias)
		bias_tally[bias] = int(bias_tally.get(bias, 0)) + 1
		var channel := str(delivered.dominant_channel)
		channel_tally[channel] = int(channel_tally.get(channel, 0)) + 1

		match str(resolved.outcome):
			"in":
				tally["in"] += 1
			"net":
				tally["net"] += 1
			"blocked":
				var kind := str(Dictionary(resolved.block).get("kind", "touch"))
				tally[kind] = int(tally.get(kind, 0)) + 1
			_:
				var reason := str(resolved.out_reason)
				if reason == "long":
					tally["out_long"] += 1
				elif reason == "antenna":
					tally["out_antenna"] += 1
				else:
					tally["out_wide"] += 1

	var total := 0
	for value in tally.values():
		total += int(value)
	return {
		"samples": total,
		"tally": tally,
		"shares": _shares(tally, total),
		"power_bias": _shares(bias_tally, total),
		"miss_channel": _shares(channel_tally, total),
		"mean_speed_mps": _mean(speeds),
		"mean_contact_height_m": _mean(heights),
		"mean_net_clearance_m": _mean(clearances),
		"no_driven_angle_pct": float(unreachable) / float(maxi(total, 1)) * 100.0,
	}


static func _population(rng: RandomNumberGenerator) -> Array:
	var squad: Array = []
	var roles := ["Outside Hitter", "Opposite", "Middle Blocker"]
	for index in range(24):
		squad.append(PlayerGeneratorModel.generate_prospect(
			"Landavol",
			str(roles[index % roles.size()]),
			"OH",
			rng.randi_range(22, 30),
			rng.randi_range(58, 84),
			index + 1,
			"Sweep %d" % index,
			rng.randi(),
		))
	return squad


static func _block_at(
	contact_x: float,
	count: int,
	pool: Array,
	rng: RandomNumberGenerator,
) -> Array:
	var wall: Array = []
	for index in range(count):
		var blocker: VolleyballPlayer = pool[rng.randi_range(0, pool.size() - 1)]
		## The block forms in front of the hitter, imperfectly.
		var offset := (float(index) * 0.5 - 0.25 * float(count - 1)) \
			* 2.0 * BLOCKER_HALF_WIDTH_METERS / CourtConstants.COURT_WIDTH_METERS
		wall.append({
			"net_x": clampf(
				contact_x + offset + rng.randfn(0.0, 0.022), 0.02, 0.98
			),
			"reach_height_m": blocker.jumping_reach_cm(BLOCKER_REACH_EFFORT) / 100.0,
			"half_width_m": BLOCKER_HALF_WIDTH_METERS,
		})
	return wall


static func _rating(player: VolleyballPlayer, attribute: String) -> float:
	return clampf(float(player.get(attribute)) / 100.0, 0.0, 1.0)


static func _weighted_lane(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var running := 0.0
	for lane in LANE_WEIGHTS:
		running += float(LANE_WEIGHTS[lane])
		if roll <= running:
			return str(lane)
	return "Left Pin"


static func _shares(counts: Dictionary, total: int) -> Dictionary:
	var shares := {}
	for key in counts:
		shares[key] = float(counts[key]) / float(maxi(total, 1)) * 100.0
	return shares


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / float(values.size())
