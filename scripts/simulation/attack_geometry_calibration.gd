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
const SignatureMoveModel := preload(
	"res://scripts/simulation/signature_move_model.gd"
)
const AttackResolverModel := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
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
## A blocker jumps from a standstill or a shuffle rather than a full approach,
## and gets appreciably less of their leap than a hitter does.
##
## How much net a pair of hands actually seals was narrowed from 0.45 in this
## gate: at 0.45 the block was involved in 55% of swings against a 35-45% target,
## and the lateral window is the term that decides involvement.
##
## Gate E moved all three into `GeometricAttackPromotion`, the production path,
## and this harness now reads them from there. A calibration that sweeps
## constants the game does not use is worse than no calibration, and these are
## exactly the numbers a later tuning pass would be tempted to edit in one place
## and not the other.
const CONTACT_BELOW_REACH_METERS: float = \
	GeometricAttackPromotion.CONTACT_BELOW_REACH_METERS
const BLOCKER_REACH_EFFORT: float = GeometricAttackPromotion.BLOCKER_REACH_EFFORT
const BLOCKER_HALF_WIDTH_METERS: float = \
	GeometricAttackPromotion.BLOCKER_HALF_WIDTH_METERS

## Lanes a hitter can be set to, and how often each is used. Pins carry the
## offence, which is what makes their lopsided course cones matter.
const LANE_WEIGHTS := {
	"Left Pin": 0.34, "Right Pin": 0.24, "Front Quick": 0.16,
	"Right Quick": 0.12, "Pipe": 0.14,
}


## `contact_height_override` runs the sweep at a stated contact height instead of
## the one `jumping_reach_cm()` produces, so a geometry problem can be told apart
## from an input problem. Zero uses the model.
## How far off the tape a swept contact happens, in metres.
##
## This was a literal `0.52` in the contact vector -- 0.36 m off the net, for
## every one of four thousand samples. That is the tight front-row ideal, and it
## is the *hardest* case to block: the closer to the tape a ball is struck, the
## less distance it covers before the net and the higher it crosses. Fitting the
## block constants there and then playing at any other depth overshoots, and the
## live distribution now spans 0.87 m at p10 to 3.98 m at p90.
##
## A constant is the wrong shape for this. It is the same defect the rest of this
## work keeps finding -- a figure chosen at one point of a distribution and then
## asked to describe the whole of it -- so the parameter is here, the default is
## the old literal so nothing silently moves, and `depth_sweep()` reads the mix
## across the range the game produces.
const DEFAULT_CONTACT_DEPTH_METERS: float = 0.36

## The depths the sweep reads, in metres off the tape. A tight quick, a normal
## front-row swing, a set off the net, and a back-row pipe -- the span a real
## offence produces rather than the one point the harness used to sit on.
const SWEPT_CONTACT_DEPTHS: Array[float] = [0.36, 1.00, 1.80, 2.80, 4.00]


static func run(
	sample_count: int = 4000,
	seed_value: int = 20260803,
	contact_height_override: float = 0.0,
	contact_depth_meters: float = DEFAULT_CONTACT_DEPTH_METERS,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hitters := _population(rng)
	var blockers_pool := _population(rng)

	var tally := {
		"in": 0, "out_long": 0, "out_wide": 0, "out_antenna": 0,
		"net": 0, "stuff": 0, "touch": 0, "tool": 0,
		"block_crush": 0, "high_hands": 0,
	}
	var bias_tally := {}
	var channel_tally := {}
	var speeds: Array[float] = []
	var heights: Array[float] = []
	var clearances: Array[float] = []
	var unreachable := 0
	var attempts := 0
	var conversions := 0

	for index in range(sample_count):
		var hitter: VolleyballPlayer = hitters[rng.randi_range(0, hitters.size() - 1)]
		var lane := _weighted_lane(rng)
		var contact_x: float = CourtConstants.LANE_X[lane]
		## Home attacks toward decreasing y, so their own half is the far side of
		## the net and depth is added rather than subtracted.
		var contact := Vector2(
			contact_x,
			CourtConstants.NET_Y
				+ contact_depth_meters / CourtConstants.COURT_LENGTH_METERS,
		)
		var contact_height := hitter.jumping_reach_cm() / 100.0 \
			- CONTACT_BELOW_REACH_METERS
		if contact_height_override > 0.0:
			contact_height = contact_height_override

		var blocker_count := 1 if rng.randf() < 0.62 else 2
		## Staged where the ball crosses the tape, not where the hitter jumps.
		##
		## `_block_at` took the contact's x, so a wall at depth stood a full
		## `tan(bearing) * off_net_metres` from the ball -- and the harness reported
		## block involvement falling from 32.7% at 0.36 m to 0.5% at 4.00 m while the
		## ball cleared the tape by a comfortable 0.14-0.29 m at every one of them.
		## That is not a block being beaten, it is a block standing somewhere else,
		## and it would have been read as the constants needing to be softer.
		var approach_start := ApproachMechanicsModel.approach_start_position(
			contact, lane, &"home", contact
		)
		var blockers := _block_at(
			GeometricAttackPromotion.wall_stage_x(
				contact,
				AttackCourseModel.natural_bearing_from_approach(
					approach_start, contact, true
				),
				true,
				## A competent, committed read. The harness is measuring what the
				## block constants do when the block is where it meant to be; how
				## often it is not is a separate question the rally answers.
				1.0,
				lerpf(22.0, 62.0,
					_rating(hitter, "shot_variety") * 0.6
						+ _rating(hitter, "attack_accuracy") * 0.4),
			),
			blocker_count, blockers_pool, rng,
		)

		## The production swing, not a second copy of it.
		##
		## This used to re-implement the whole chain by hand -- read the block, score
		## the courses, choose the power, solve the angle, deliver, resolve -- which
		## meant the harness could fall behind the resolver silently, and it had. The
		## resolver gained `_feasible_launch` because 24% of swings were choosing a
		## driven solution that dives into the tape; the copy here never did, so it
		## reported a hitter contacting a metre off the net as unable to clear the net
		## at all -- 72% errors and block involvement at 1.6% for an ordinary spike.
		##
		## A calibration that measures a chain the game does not run is worse than no
		## calibration, which is the same rule this file already states about its
		## constants. It now applies to the chain as well.
		var swing := AttackResolverModel.resolve_swing(
			hitter, contact, contact_height, lane, blockers, [], true,
			rng.randf_range(0.45, 0.95), 0.5,
			rng.randf_range(-0.5, 0.7), rng.randf_range(-0.6, 0.6),
			GeometricAttackPromotion.draws(rng, blockers.size(), 0),
		)
		if not bool(swing.get("available", false)):
			continue
		var resolved: Dictionary = swing.resolution
		var delivered: Dictionary = swing.delivered
		var narrative: Dictionary = swing.narrative
		speeds.append(float(delivered.speed_mps))
		heights.append(contact_height)
		clearances.append(float(resolved.net_clearance_meters))
		bias_tally[str(narrative.power_bias)] = int(
			bias_tally.get(str(narrative.power_bias), 0)
		) + 1
		channel_tally[str(narrative.miss_channel)] = int(
			channel_tally.get(str(narrative.miss_channel), 0)
		) + 1
		if not str(narrative.get("attempted_move", "")).is_empty():
			attempts += 1
			if bool(narrative.get("move_succeeded", false)):
				conversions += 1
		if not bool(swing.power.get("reachable", true)):
			unreachable += 1

		## `resolve_swing` has already folded the signature move into its outcome,
		## so `stuff`/`touch`/`tool`/`block_crush`/`high_hands` arrive named.
		var outcome := str(swing.outcome)
		match outcome:
			"in", "net":
				tally[outcome] += 1
			"out":
				var reason := str(resolved.out_reason)
				if reason == "long":
					tally["out_long"] += 1
				elif reason == "antenna":
					tally["out_antenna"] += 1
				else:
					tally["out_wide"] += 1
			_:
				tally[outcome] = int(tally.get(outcome, 0)) + 1

	var total := 0
	for value in tally.values():
		total += int(value)
	return {
		"samples": total,
		"tally": tally,
		"move_attempts_pct": float(attempts) / float(maxi(total, 1)) * 100.0,
		"move_conversion_pct": float(conversions) / float(maxi(attempts, 1)) * 100.0,
		"shares": _shares(tally, total),
		"power_bias": _shares(bias_tally, total),
		"miss_channel": _shares(channel_tally, total),
		"mean_speed_mps": _mean(speeds),
		"mean_contact_height_m": _mean(heights),
		"mean_net_clearance_m": _mean(clearances),
		## Median, because the mean of this is not a quantity. A handful of swings
		## solved onto a steep arc drag it metres negative while most of the sample
		## clears the tape comfortably, which reads as non-monotone in depth and says
		## nothing true about a typical ball.
		"median_net_clearance_m": _median(clearances),
		"no_driven_angle_pct": float(unreachable) / float(maxi(total, 1)) * 100.0,
		"contact_depth_meters": contact_depth_meters,
	}


## The same sweep read across the depths a real offence produces.
##
## The block constants have to describe the whole range, not the tightest point
## of it. A row-by-row table is what makes an overshoot legible as a gradient
## instead of arriving later as a single number that disagrees with the harness.
static func depth_sweep(
	sample_count: int = 4000,
	seed_value: int = 20260803,
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for depth in SWEPT_CONTACT_DEPTHS:
		rows.append(run(sample_count, seed_value, 0.0, depth))
	return rows


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


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return float(sorted_values[sorted_values.size() / 2])


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / float(values.size())
