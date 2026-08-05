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
## it. Higher and everyone hits where their approach already points; lower and
## everyone swings across their body at the biggest gap.
##
## Re-derived in Gate E, because it had to be. While `openness` came out flat
## across the whole cone -- block clearance normalised against a 4 m scale for a
## quantity that spans 30 cm -- this constant was the *only* term with any range,
## so it decided every shot and 91.7% of swings went down the natural line. With
## openness spanning -1 to 1 the balance inverted and 89% went to the sharpest
## available cut instead.
##
## Derived twice, and the second derivation overturned the first. Three roster
## pairings said 1.10; eight say 0.85. Attack error and stuff both move by
## several points between those two samples at a *fixed* value of this constant,
## which is the whole lesson of `ATTACK_SIDE_SYMMETRY_2026_08_03.md` arriving in
## a second place: a figure read off one handful of pairings is a draw from a
## wide distribution, not a measurement.
##
## Eight pairings, both serving assignments, all three attack paths pooled:
##
##   value | off natural line | attack error | block involvement | stuff
##    0.85 |            60.4% |        11.7% |             24.7% | 11.7%
##    1.10 |            37.1% |         9.2% |             27.4% | 13.3%
##    1.40 |            16.8% |         7.6% |             32.8% | 16.3%
##
## 0.85 is the only row with attack error inside the sport's 10-15%, and its
## 11.7% stuff is the closest any row gets to the 12% target. 1.10 -- the value
## three pairings chose -- sits below the error band and overshoots stuff.
##
## Involvement reads lower here than in the per-path tables because this sweep
## pools the transition swing, whose block forms off a dig and is genuinely
## weaker. Read it as a comparison between rows, not against the 35-45% band.
const STRAIN_AVERSION: float = 0.85
## How much air a hitter wants between the ball and the tape when choosing a
## shot. Not a safety factor on the outcome -- execution error is applied after
## this and can still put the ball in the net. This is the margin a hitter aims
## for, and aiming to clear by nothing is not a thing anyone does.
const NET_CLEARANCE_MARGIN_METERS: float = 0.12
## How many target distances get probed looking for one that clears. The search
## is monotone in distance, so this is a resolution and not a menu.
const NET_FEASIBILITY_STEPS: int = 9
## How much of a spike's execution spread a serve carries.
##
## A serve is struck from a standstill, off a self-toss, with no set to read and
## no block to beat -- the one contact in the sport a player rehearses in
## isolation. It should not scatter like a swing taken off a bad set with hands
## in the way.
##
## It matters more here than anywhere else because a serve has to be launched
## *upward*: from a 2.6 m contact a flat ball is 1.5 m high at the net, so the
## driven root cannot clear the tape and every serve takes the lofted one. On
## the lofted branch range is steeply sensitive to launch angle, so vertical
## error turns directly into balls long. Swept on live rallies, 360 serves each,
## measured on both sides of the net:
##
##   value | serve error, home | opponent | combined
##    1.00 |             32.8% |    32.2% |    32.5%
##    0.70 |             15.6% |    10.6% |    13.1%
##    0.45 |              3.9% |     0.0% |     1.9%
##
## The response is steeply nonlinear because the lofted branch amplifies angle
## error into range error. 0.70 lands inside the sport's 8-15%; 0.45 produces a
## serve that essentially cannot miss.
const SERVE_SPREAD_MULTIPLIER: float = 0.70


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
	##
	## Constrained by the tape. Nothing above this point knows the net exists:
	## the course scan reads the block and the floor, and the power model reads
	## the distance, so a hitter could pick a short cut shot whose driven
	## solution is a 53-degree dive into the net and swing at it. Measured in
	## shadow on live rallies that was 24% of swings -- the resolution layer
	## dutifully reported "net" for a choice the decision layer should never have
	## offered. A hitter knows where the tape is.
	var launch := _feasible_launch(
		contact, float(best.bearing_degrees), float(chosen.speed_mps),
		contact_height_meters, aim_distance, float(best.far_meters),
		attacking_negative_y,
	)
	var intended_angle := float(launch.angle_degrees)
	aim_distance = float(launch.aim_distance)

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
		## Why the wall was beaten, carried up rather than left in `resolution`.
		## Every consumer reads the flat keys; a diagnostic buried one level down is
		## a diagnostic nobody asks for. Over the top is a reach problem and around
		## the edge is a positioning one, and they want opposite fixes.
		"block_miss_reason": str(resolved.get("block_miss_reason", "")),
		"net_height_over_block_meters": float(
			resolved.get("net_height_over_block_meters", 0.0)
		),
		"block_edge_miss_meters": float(
			resolved.get("block_edge_miss_meters", 0.0)
		),
		## Where on the tape this ball actually crossed. The wall is staged on the
		## hitter's contact, and a hitter contacting off the net crosses somewhere
		## else entirely -- the gap between the two is the whole question of whether
		## the wall is narrow or simply standing in the wrong place.
		"net_crossing_x": float(resolved.get("net_crossing_x", 0.5)),
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


## One serve, start to finish.
##
## A serve is the same ball as a spike and a different decision. There is no
## approach, so no natural line and no repertoire cone -- a server picks a spot
## and hits it. There is no block, so the only things between contact and the
## floor are the tape and the lines. What is shared is everything that matters:
## the same flight solver, the same net-clearance constraint, the same execution
## channels, and the same resolution that reads the outcome off where the ball
## landed rather than off a quality scalar.
##
## Sharing them is the point. Serves were hardcoded in or out -- a serve that
## visibly stayed inside the court could be scored an error -- because the serve
## path derived its own trajectory and then decided the outcome separately. Two
## descriptions of one ball will always drift apart; there is now one.
static func resolve_serve(
	server: VolleyballPlayer,
	contact: Vector2,
	contact_height_meters: float,
	target: Vector2,
	attacking_negative_y: bool,
	tactical_risk: float,
	draws: Dictionary,
) -> Dictionary:
	if server == null:
		return {"available": false, "reason": "no server"}
	var bearing := AttackCourseModel.bearing_to_point(
		contact, target, attacking_negative_y
	)
	var across := (target.x - contact.x) * CourtConstants.COURT_WIDTH_METERS
	var along := (target.y - contact.y) * CourtConstants.COURT_LENGTH_METERS
	var distance := maxf(sqrt(across * across + along * along), 0.5)

	## How hard, from the serve's own attributes rather than the attack's. Risk
	## is the tactical instruction: a team told to serve aggressively asks more
	## of the ball, and asking more of it is exactly what puts it out.
	var ceiling := AttackPowerModel.available_ceiling_mps(
		_rating(server, "serve_power"), 1.0, 1.0
	)
	var intent := lerpf(
		AttackPowerModel.CONTROL_INTENT, AttackPowerModel.DRIVE_INTENT,
		clampf(tactical_risk, 0.0, 1.0),
	)
	var speed := maxf(
		ceiling * intent * lerpf(
			0.82, 1.0, _rating(server, "serve_technique")
		),
		BallFlightModel.MIN_SPEED_MPS,
	)
	var launch := _feasible_launch(
		contact, bearing, speed, contact_height_meters, distance, distance,
		attacking_negative_y,
	)

	## A serve's control is its own attribute, and consistency is what keeps the
	## ball on the court -- so it, not attack accuracy, sets the spread.
	var control := _rating(server, "serve_consistency") * 0.6 \
		+ _rating(server, "serve_technique") * 0.4
	var delivered := AttackSwingModel.deliver(
		bearing, float(launch.angle_degrees), speed, control,
		SERVE_SPREAD_MULTIPLIER,
		float(draws.get("bearing", 0.0)),
		float(draws.get("vertical", 0.0)),
		float(draws.get("power", 0.0)),
	)
	var resolved := AttackResolutionModel.resolve(
		contact, contact_height_meters,
		float(delivered.bearing_degrees),
		float(delivered.vertical_angle_degrees),
		float(delivered.speed_mps),
		[], attacking_negative_y,
	)
	return {
		"available": true,
		"outcome": str(resolved.outcome),
		"bearing_degrees": bearing,
		"target_distance_meters": distance,
		"speed_mps": float(delivered.speed_mps),
		"launch_mode": str(launch.mode),
		"delivered": delivered,
		"resolution": resolved,
		"landing": resolved.landing,
		"flight": resolved.flight,
	}


## The steepest ball this hitter can actually hit, at the speed they chose.
##
## For a fixed speed, a longer target range means a flatter driven solution and
## therefore more height at the net. So the search is monotone: start at the
## distance the hitter aimed for, and if that ball is in the tape, push the
## target deeper until it clears. That is what a hitter does -- a ball they
## cannot cut sharp gets hit deeper, not into the net.
##
## Three outcomes, in the order a hitter would take them:
##
##   driven   the intended ball clears, or clears once pushed deeper
##   lofted   nothing driven clears, so the ball goes *over* rather than through
##            -- the roll shot a hitter takes off a set that is too tight
##   forced   neither clears at this speed. The swing happens anyway and will
##            very likely be in the net, which is correct: a hitter under a bad
##            set does hit the tape. This is the only path that should produce a
##            net error, and it should be rare.
static func _feasible_launch(
	contact: Vector2,
	bearing_degrees: float,
	speed_mps: float,
	contact_height_meters: float,
	aim_distance: float,
	far_meters: float,
	attacking_negative_y: bool,
) -> Dictionary:
	var ground_to_net := _ground_distance_to_net(
		contact, bearing_degrees, attacking_negative_y
	)
	var needed := CourtConstants.NET_HEIGHT_METERS + NET_CLEARANCE_MARGIN_METERS
	var best_driven := 0.0
	var best_distance := aim_distance
	var reach := maxf(far_meters, aim_distance)
	for step in range(NET_FEASIBILITY_STEPS):
		var probe := lerpf(
			aim_distance, reach, float(step) / float(NET_FEASIBILITY_STEPS - 1)
		)
		var solved := BallFlightModel.solve_angle_for_range(
			speed_mps, probe, contact_height_meters
		)
		if not bool(solved.get("driven_found", false)):
			continue
		var angle := float(solved.driven_angle_degrees)
		if _height_at_net(speed_mps, angle, contact_height_meters, ground_to_net) \
				>= needed:
			return {
				"angle_degrees": angle, "aim_distance": probe,
				"mode": "driven", "cleared": true,
			}
		best_driven = angle
		best_distance = probe
	## Nothing driven gets over. Try lifting it instead.
	var lofted_solve := BallFlightModel.solve_angle_for_range(
		speed_mps, aim_distance, contact_height_meters
	)
	if bool(lofted_solve.get("lofted_found", false)):
		var lofted := float(lofted_solve.lofted_angle_degrees)
		if _height_at_net(speed_mps, lofted, contact_height_meters, ground_to_net) \
				>= needed:
			return {
				"angle_degrees": lofted, "aim_distance": aim_distance,
				"mode": "lofted", "cleared": true,
			}
	return {
		"angle_degrees": best_driven if best_driven != 0.0
			else AttackPowerModel.DRIVEN_REFERENCE_ANGLE_DEGREES,
		"aim_distance": best_distance, "mode": "forced", "cleared": false,
	}


static func _height_at_net(
	speed_mps: float,
	angle_degrees: float,
	contact_height_meters: float,
	ground_to_net: float,
) -> float:
	return BallFlightModel.height_at_distance(
		BallFlightModel.solve_flight(
			speed_mps, angle_degrees, contact_height_meters
		),
		ground_to_net,
	)


## How far the ball travels over the ground before it reaches the net, along the
## bearing it was struck on. A shot angled across the court crosses more ground
## getting there than one hit straight down the line.
static func _ground_distance_to_net(
	contact: Vector2,
	bearing_degrees: float,
	attacking_negative_y: bool,
) -> float:
	var direction := AttackCourseModel.direction_meters(
		bearing_degrees, attacking_negative_y
	)
	var to_net := (CourtConstants.NET_Y - contact.y) \
		* CourtConstants.COURT_LENGTH_METERS
	if absf(direction.y) < 0.000001:
		return 0.0
	return maxf(to_net / direction.y, 0.0)


## How formed the wall in front of the hitter is, 0-1. Two blockers is a full
## wall; one is half a problem; none is an open net.
static func _block_presence(blockers: Array) -> float:
	return clampf(float(blockers.size()) * 0.5, 0.0, 1.0)


static func _rating(player: VolleyballPlayer, attribute: String) -> float:
	return clampf(float(player.get(attribute)) / 100.0, 0.0, 1.0)
