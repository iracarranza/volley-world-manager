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
## How many slower swings a hitter will consider when nothing at full pace gets
## over the tape, and how far down they will go.
##
## A hitter who cannot clear the net at full pace takes pace off. That is the one
## thing the resolver could not previously do: `_feasible_launch` searched angles
## and aim distances at a *fixed* speed, because `choose_power` had already
## committed to one without knowing the net existed. From a tight set that never
## mattered -- any speed clears from 0.36 m. From four metres back nothing does,
## so the search fell through to its `forced` branch and flew the flat ball
## anyway: Gate D measured balls into the net climbing 4.7% to 54.5% across the
## depth sweep while long, wide and antenna barely moved.
##
## The floor is 0.45 rather than zero because a swing taken at under half pace is
## a different shot -- a roll or a tip -- and that decision belongs to the power
## model's intent, not to a feasibility search quietly turning a spike into one.
const NET_SPEED_RELIEF_STEPS: int = 6
## How finely a roll shot is softened looking for the flattest arc that still
## clears. Eight resolves the pace range to about 7% of full swing, which is
## finer than the angle it is chasing responds to.
const LOFT_FLATTENING_STEPS: int = 8
const NET_SPEED_RELIEF_FLOOR: float = 0.45
## The furthest a bearing error is allowed to stretch the path to the tape when
## a hitter is budgeting for it, as a multiple of the path they aimed on.
##
## Needed because the stretch is `1 / cos` of the error against the net normal
## and runs away without bound as a course approaches parallel with the tape. A
## sharp cross-court swing off the pin genuinely does fly a long way before it
## crosses, but a hitter does not plan around the degenerate tail of that -- they
## plan around a swing that misses by about as much as their swings miss by. Two
## is roughly a 60-degree course budgeting for its own worst realistic day.
const NET_PATH_STRETCH_CAP: float = 2.0
## How many standard deviations of vertical execution error a hitter aims to
## clear the tape by.
##
## It was one, implicitly, by multiplying the spread by itself once -- and one
## sigma is the margin that puts a sixth of your swings in the net on purpose.
## That is what the measurement showed: 5th-percentile clearance sat 0.10 m under
## a planned 0.15 m margin at 2.50 m off the net, exactly one sigma low, with net
## rates of 0.22-0.33 to match. The bearing budget above is worth 1-3 points of
## that; this is worth the rest.
##
## Two rather than three because the relief search below has to be able to find
## the bar. A margin nothing can clear does not stop a hitter swinging -- it drops
## them through to `forced` and flies the same flat ball with no plan at all,
## which is how the previous attempt at this moved the 4.00 m net rate by a point
## and a half in the wrong direction.
const NET_CLEARANCE_SPREAD_SIGMAS: float = 2.0
## The least air a hitter will accept over the tape when the margin they wanted
## is not on offer.
##
## `NET_CLEARANCE_MARGIN_METERS` and the sigma budget above are what a hitter
## *aims* for. This is the tape. They were the same branch: the search looked for
## the margin, and anything that missed it fell through to `forced` and flew a
## ball with no plan behind it -- including balls that cleared the net by twenty
## centimetres and merely missed the preference. Measured, `forced` was 0.15 of
## swings at 2.50 m off the net and 0.36 at 4.00 m, and it netted 86-95% of them,
## which made it 64% and 77% of all net errors at those depths. The netted balls
## averaged +0.04 standard deviations of vertical error -- they were not misses,
## they were plans into the tape.
##
## A preference you cannot afford is a preference you drop. A net you cannot
## clear is a different problem, and only that one is allowed to force a swing.
const NET_CLEARANCE_FLOOR_METERS: float = 0.03
## How much of the air between a hitter's contact point and the tape may be spent
## on safety margin, leaving the rest for the ball to fall through.
##
## The bound that was missing, and the one that made every other number here
## misbehave. A swing cannot arrive at the net higher than it left the hand --
## only a lofted ball does that, and it is a different shot. So the margin a
## hitter asks for is capped by the headroom they actually have, which for a
## 2.91 m reach is 2.81 m of contact against a 2.43 m tape: 0.38 m, all in.
##
## Unbounded, the distance-scaled margin computed to 0.27 m at 2.50 m off the net
## and 0.43 m at 4.00 m. The second is more headroom than exists. The search was
## asking for a ball that cannot be struck, failing to find one, and dropping
## through to `forced` -- which is why `forced` ran 0.14 and 0.34 of swings at
## those depths while relieving the pace all the way to 20% of full moved it by
## nothing at all. It was never a pace problem. It was a request for altitude
## nobody had.
##
## Half, because the remainder has to cover the ball falling on the way: about
## 0.06 m over 2.7 m and 0.15 m over 4.3 m at a driven pace.
## How short a hitter will settle for when they cannot carry the ball to where
## they aimed, as a fraction of the distance they wanted.
##
## A quarter, because past that it is not the same shot -- a ball dropped at a
## third of its intended distance is a tip, and tips are chosen by the power
## model's intent rather than arrived at by a feasibility search.
const NET_SHORTFALL_FLOOR: float = 0.25
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

	## **How much air this swing has, once commitment is paid for.**
	##
	## `cost.spread_multiplier` is the across-body strain of the *course* -- how
	## turned the hitter had to be. It says nothing about how hard they then
	## decided to swing, so a full-commitment hammer and a controlled roll off the
	## same approach were judged by identical accuracy, and the bench's
	## decisiveness instruction reached the ball as speed and nothing else.
	##
	## Combined rather than replaced: they are two independent ways to lose a
	## swing, and a hitter turned back across themselves *and* swinging at their
	## ceiling should pay for both. Placed here, above every consumer, because the
	## last three of these went in below one of theirs.
	var swing_spread := float(cost.spread_multiplier) \
		* AttackPowerModel.commitment_spread_multiplier(
			float(chosen.chosen_fraction)
		) \
		## And the hitter's own state, which until now reached nothing but whether
		## a signature move fired. See `AttackSwingModel.form_spread_multiplier`:
		## this is the one term in a swing's quality that the five-link chain
		## above does not gate, and it is therefore the only way an outstanding
		## hitter can carry further than a merely-decent set allows.
		* AttackSwingModel.form_spread_multiplier(
			match_confidence, flow_for_team
		) \
		## **And the wall, which until now reached the swing through nothing.**
		##
		## The reported defect: hitters swinging out at an open net while the
		## blockers stand there not jumping, because they already know it is
		## going out. A miss with nobody in front of you is an unforced error and
		## should be rare; a miss is what pressure produces. Measured over 600
		## rallies, the rate was no lower against nothing than against two, which
		## is what a cone with no block term in it has to produce.
		##
		## Read off the **actual** wall rather than `perceived_blockers`. What a
		## hitter believes decides which course they pick -- that is the read
		## model's job, above -- but what they have to hit over is whatever is
		## really there. A hitter who misread the block does not get an easier
		## swing for having been wrong; they get a worse outcome, which is the
		## point.
		* AttackSwingModel.block_spread_multiplier(
			blockers.size(), _wall_seal(blockers)
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
		AttackSwingModel.vertical_spread_degrees(
			_rating(hitter, "attack_accuracy"), swing_spread
		),
		AttackSwingModel.bearing_spread_degrees(
			_rating(hitter, "attack_accuracy"), swing_spread
		),
	)
	var intended_angle := float(launch.angle_degrees)
	aim_distance = float(launch.aim_distance)
	## Whatever pace the tape left them. Equal to the chosen speed on any swing
	## that could be hit at full pace, which is nearly all of them from a tight
	## set.
	var launch_speed := float(launch.speed_mps)

	## --- what they actually did ----------------------------------------------
	var delivered := AttackSwingModel.deliver(
		float(best.bearing_degrees), intended_angle, launch_speed,
		_rating(hitter, "attack_accuracy"), swing_spread,
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
		var contacted_blocker: Dictionary = contact_info.get("blocker", {})
		var monster := SignatureMoveModel.resolve_monster_block(
			str(contact_info.get("kind", "touch")),
			float(contacted_blocker.get("timing_quality", 0.0)),
			str(contacted_blocker.get("arm_state", "")),
			float(contacted_blocker.get("monster_block_charge", 0.0)),
			int(contacted_blocker.get("player_id", -1)),
		)
		if bool(monster.get("move_succeeded", false)):
			move = monster
		else:
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
			## One overhead effect per actor/action. An attacker signature wins the
			## cue if both sides charged but the block missed its apex; otherwise the
			## failed Monster Block attempt remains visible on the blocker.
			if str(move.get("attempted_move", "")).is_empty() \
				and not str(monster.get("attempted_move", "")).is_empty():
				move = monster
		if int(move.get("signature_actor_id", -1)) < 0:
			move["signature_actor_id"] = hitter.id
		outcome = str(move.outcome)

	return {
		"available": true,
		"outcome": outcome,
		"course": best,
		"natural_bearing_degrees": natural,
		"swing_range_degrees": swing_range,
		"power": chosen,
		## Whether the feasibility search found a solution over the tape or fell
		## through and flew the ball anyway. Published for the same reason the two
		## block quantities below are: `forced` is the branch that turns a raised
		## bar into more balls in the net rather than fewer, so a change to the
		## margin cannot be read without it.
		"launch_mode": str(launch.mode),
		"launch_cleared": bool(launch.cleared),
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
		## The two quantities the outcome bands actually cut, published rather
		## than consumed inside `_block_contact`. `STUFF_DEPTH_METERS` cuts the
		## first and `TOOL_EDGE_MARGIN_METERS` the second, and neither could be
		## checked against its own distribution because neither left the function
		## that computed it -- which is how a band comes to sit outside the spread
		## it is meant to divide.
		"block_depth_below_reach_meters": Dictionary(
			resolved.get("block", {})
		).get("depth_below_reach_meters", null),
		"block_edge_gap_meters": Dictionary(
			resolved.get("block", {})
		).get("edge_gap_meters", null),
		"block_contact_kind": str(
			Dictionary(resolved.get("block", {})).get("kind", "")
		),
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
			"signature_charge": float(move.get("signature_charge", 0.0)),
			"signature_actor_id": int(move.get("signature_actor_id", hitter.id)),
			"signature_timing_quality": float(move.get("timing_quality", 0.0)),
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
	## What this server puts on the ball. Supplied by the caller rather than
	## derived here, because `BallSpin.from_serve` reads a serve *style* and the
	## resolver has no business knowing about roster fields.
	spin_state: Dictionary = {},
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
	var ceiling := AttackPowerModel.serve_ceiling_mps(_rating(server, "serve_power"))
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
	## A serve's control is its own attribute, and consistency is what keeps the
	## ball on the court -- so it, not attack accuracy, sets the spread. Hoisted
	## above the launch solve because the margin a server aims for is derived from
	## it, and a serve is struck nine metres from the tape: the extreme of the same
	## geometry that puts spikes into the net from four.
	var control := _rating(server, "serve_consistency") * 0.6 \
		+ _rating(server, "serve_technique") * 0.4
	var serve_gravity := BallSpin.gravity_for(spin_state)
	var launch := _feasible_launch(
		contact, bearing, speed, contact_height_meters, distance, distance,
		attacking_negative_y,
		AttackSwingModel.vertical_spread_degrees(control, SERVE_SPREAD_MULTIPLIER),
		AttackSwingModel.bearing_spread_degrees(control, SERVE_SPREAD_MULTIPLIER),
		## **A serve does not give up pace to flatten its arc.**
		##
		## For a swing that is the whole trade -- a roll shot is pace surrendered
		## to get over a wall, and surrendering the least of it is the shot a
		## player picks. A serve has no wall, and pace is not the hitter's
		## incidental choice there but the tactical instruction itself:
		## `tactical_risk` reaches the ball as speed and as nothing else, which is
		## the contract `_test_the_serve_flies_the_same_ball_as_the_spike` holds.
		##
		## Measured: every serve takes the lofted branch, from nine metres back
		## with the tape in the way, so softening applied to all of them. At risk
		## 0.0 / 0.5 / 1.0 the softened serve came back at 11.68 / 11.18 / 11.39
		## m/s -- not merely compressed but non-monotone, the instruction replaced
		## by whatever pace the flattening search happened to stop at.
		false,
		## **And the ball's own gravity.** Solved flat, the search could only ever
		## find the serve a spinless ball can hit -- so a topspin server's launch
		## was certified for one flight and then drawn flying another, and the pace
		## the spin was supposed to buy went nowhere. This is the whole of the
		## remaining serve gap.
		serve_gravity,
	)
	speed = float(launch.speed_mps)
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
		[], attacking_negative_y, serve_gravity,
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
	vertical_spread_degrees: float,
	bearing_spread_degrees: float,
	## Whether pace may be spent to flatten a roll shot. True for a swing, false
	## for a serve -- see `_quickest_clearing_loft`, and the serve's own call.
	may_soften_the_loft: bool = true,
	## **The gravity this ball actually flies under.**
	##
	## The search solved every candidate at 9.8 while the drawing flew the chosen
	## one at up to 26, so the launch certified over the tape and the launch drawn
	## were different balls. On a spike that is a small inconsistency; on a serve
	## it is the whole feature, because a topspin serve exists precisely to be
	## launched steeper than a flat ball could afford and still land inside the
	## endline. Solving it flat means the search never sees the shot the spin
	## makes possible, and settles for a lob instead.
	gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	## The path the hitter aimed on, and the longer one a bearing error puts them
	## on -- and it is the longer one every check below is made against.
	##
	## The vertical budget alone was measured holding at a tight set and failing
	## everywhere else: net errors ran 0.000-0.073 at 0.36 m, 0.147-0.253 at
	## 1.20 m and 0.233-0.367 at 2.50 m, with 5th-percentile clearance falling
	## from 0.112 m (sitting right on the flat margin, exactly as designed) to
	## 0.038 m. A margin that grows with distance was being computed on a distance
	## the ball did not fly. Horizontal error lengthens the path, the ball has to
	## stay in the air over the extra ground, and nothing budgeted for it -- the
	## netted balls off the pin flew 3.70 m to the tape against 3.25 m for the
	## ones that cleared.
	var aimed_to_net := _ground_distance_to_net(
		contact, bearing_degrees, attacking_negative_y
	)
	var ground_to_net := minf(
		maxf(
			_ground_distance_to_net(
				contact, bearing_degrees + bearing_spread_degrees,
				attacking_negative_y,
			),
			_ground_distance_to_net(
				contact, bearing_degrees - bearing_spread_degrees,
				attacking_negative_y,
			),
		),
		aimed_to_net * NET_PATH_STRETCH_CAP,
	)
	## How much air *this* swing needs, rather than how much air any swing needs.
	##
	## The margin was a flat `NET_CLEARANCE_MARGIN_METERS` whatever the distance to
	## the tape, which is a constant standing where a function belongs. Vertical
	## execution error arrives at the net as `ground_to_net * tan(error)`, so one
	## degree costs half a centimetre from a tight set and seven centimetres from
	## four metres back, where the spread runs to 0.35 m against a 0.12 m margin.
	## Aiming to clear by 12 cm from there is aiming to miss.
	##
	## It travels with the speed relief below and not on its own. Measured alone it
	## moved the 4.00 m net rate by a point and a half, because a higher bar with no
	## way to hit softer only sends more solves down the `forced` branch.
	var wanted := maxf(
		NET_CLEARANCE_MARGIN_METERS,
		ground_to_net * tan(deg_to_rad(
			maxf(vertical_spread_degrees, 0.0) * NET_CLEARANCE_SPREAD_SIGMAS
		)),
	)
	var needed := CourtConstants.NET_HEIGHT_METERS + wanted
	var reach := maxf(far_meters, aim_distance)
	var full_speed := maxf(speed_mps, BallFlightModel.MIN_SPEED_MPS)
	## The least-bad swing seen anywhere in the search, kept in case nothing
	## clears.
	##
	## The fallback used to be the flattest thing tried -- the driven solve at full
	## pace, from the first relief step, chosen because it was the first thing
	## written to `best_driven` and never because it was any good. So a hitter who
	## could not get the ball over swung the one ball least likely to get over,
	## and that branch is where the residual net errors live: measured at 2.50 m
	## off the net, `forced` ran 0.10-0.20 of swings against net rates of
	## 0.16-0.30, tracking it lane for lane.
	##
	## A hitter who cannot clear the tape still tries to clear the tape. This
	## keeps the highest ball the search found instead, which is the same swing
	## they were always going to take, aimed at the problem.
	var fallback_height := -INF
	var fallback_angle := AttackPowerModel.DRIVEN_REFERENCE_ANGLE_DEGREES
	var fallback_distance := aim_distance
	var fallback_speed := full_speed

	## Full pace first, then progressively less of it. A hitter who cannot get the
	## ball over at full pace takes pace off; they do not swing through the tape.
	for relief_step in range(NET_SPEED_RELIEF_STEPS):
		var speed := full_speed * lerpf(
			1.0, NET_SPEED_RELIEF_FLOOR,
			float(relief_step) / float(NET_SPEED_RELIEF_STEPS - 1)
		)
		for step in range(NET_FEASIBILITY_STEPS):
			var probe := lerpf(
				aim_distance, reach, float(step) / float(NET_FEASIBILITY_STEPS - 1)
			)
			var solved := BallFlightModel.solve_angle_for_range(
				speed, probe, contact_height_meters, gravity_mps2
			)
			if not bool(solved.get("driven_found", false)):
				continue
			var angle := float(solved.driven_angle_degrees)
			var height := _height_at_net(
				speed, angle, contact_height_meters, ground_to_net, gravity_mps2
			)
			if height >= needed:
				return {
					"angle_degrees": angle, "aim_distance": probe,
					"speed_mps": speed, "mode": "driven", "cleared": true,
				}
			if height > fallback_height:
				fallback_height = height
				fallback_angle = angle
				fallback_distance = probe
				fallback_speed = speed
		## Nothing driven gets over at this pace. Try lifting it instead, before
		## giving up any more speed -- arc is cheaper than pace.
		##
		## **But the flattest arc that clears, not the first one found.** There are
		## only two angles that carry a ball a given range at a given speed, and
		## the lofted root is the high one -- the faster the swing, the closer that
		## root sits to vertical. Taking the first loft the sweep meets therefore
		## took the *steepest* one available, because the sweep starts at full pace.
		##
		## Measured over 240 attacks: 36 came back lofted, mean apex **9.34 m**,
		## mean height at the tape 7.82 m. That is not a roll shot, it is a punt,
		## and the game had been playing them all along -- the drawing re-solved a
		## driven angle over the top of the record, so a nine-metre lob appeared on
		## screen as a flat spike. §0 exactly: the branch went unmeasured because
		## the only instrument pointed at it was reporting a different curve.
		##
		## `_quickest_clearing_loft` takes pace off *within* this decision instead,
		## which walks the lofted root down toward 45 degrees where the arc is
		## shallowest. The order of preference is untouched: a driven ball first, a
		## roll shot before another notch of relief. Deferring the whole loft to
		## the end of the sweep was tried and is worse -- a slower driven root is
		## a higher one, so it swallowed every roll shot in the game and the lofted
		## branch went to zero of 232. One dead branch traded for another.
		var lofted_solve := BallFlightModel.solve_angle_for_range(
			speed, aim_distance, contact_height_meters, gravity_mps2
		)
		if bool(lofted_solve.get("lofted_found", false)):
			var lofted := float(lofted_solve.lofted_angle_degrees)
			var lofted_height := _height_at_net(
				speed, lofted, contact_height_meters, ground_to_net, gravity_mps2
			)
			if lofted_height >= needed:
				if not may_soften_the_loft:
					return {
						"angle_degrees": lofted, "aim_distance": aim_distance,
						"speed_mps": speed, "mode": "lofted", "cleared": true,
					}
				## **Down to the least force that reaches, not to a fraction of
				## full pace.** `NET_SPEED_RELIEF_FLOOR` is 0.45, and from a tight
				## set that still leaves 11 m/s trying to land 7 m away -- which
				## only a near-vertical arc does, so the search kept returning one:
				## the median roll shot came out at 76 degrees and 2.5 s of hang
				## time. The floor is a derived quantity, not a dial. Below the
				## minimum speed for the range nothing reaches at any angle, and at
				## it the two roots merge, which is the shallowest and quickest arc
				## the shot has.
				return _quickest_clearing_loft(
					speed,
					float(BallFlightModel.minimum_speed_to_reach(
						aim_distance, contact_height_meters, gravity_mps2
					).speed_mps),
					aim_distance,
					contact_height_meters, ground_to_net, needed, lofted,
					gravity_mps2,
				)
			if lofted_height > fallback_height:
				fallback_height = lofted_height
				fallback_angle = lofted
				fallback_distance = aim_distance
				fallback_speed = speed
	## Nothing above was even solvable: this hitter cannot carry the ball to where
	## they aimed at the pace they chose, so every probe came back with a negative
	## discriminant and the search never evaluated a real trajectory.
	##
	## The sweep above only ever probes *longer* and only ever relieves speed
	## *downward*, and both are the wrong direction for this failure -- which is
	## why relieving all the way to 20% of full pace moved it by nothing. The
	## failure grows with depth because every target is further away from four
	## metres back than from thirty-six centimetres: `unsolved` ran 0.06 of swings
	## at 0.36 m and 0.15 at 4.00 m, and it put the ball in the net 100% of the
	## time from 1.20 m out, making it the single largest source of net errors at
	## every depth past the tightest.
	##
	## A hitter who cannot drive it that far hits it shorter. The ball goes over
	## and lands in front of the defence, which is a weak attack -- and a weak
	## attack is a thing this game can already resolve. A ball into the tape is
	## not what happens when someone is asked for more than they have.
	##
	## Shortening on its own is not the answer, and measuring it said so: it
	## cleared `unsolved` to zero but the shortened balls still netted 0.65 at
	## 2.50 m and 0.85 at 4.00 m, because a driven solve onto a *nearer* target is
	## a steeper solve, and steeper from four metres back is further into the
	## tape. The shortened candidates have to face the same clearance test as
	## every other candidate, and they have to be allowed to arc -- lifting it is
	## the whole point of giving up the distance.
	if fallback_height == -INF:
		for step in range(NET_FEASIBILITY_STEPS):
			var shortened := aim_distance * lerpf(
				1.0, NET_SHORTFALL_FLOOR,
				float(step + 1) / float(NET_FEASIBILITY_STEPS)
			)
			var short_solve := BallFlightModel.solve_angle_for_range(
				full_speed, shortened, contact_height_meters, gravity_mps2
			)
			for branch in [&"lofted", &"driven"]:
				if not bool(short_solve.get("%s_found" % branch, false)):
					continue
				var short_angle := float(
					short_solve.get("%s_angle_degrees" % branch, 0.0)
				)
				var short_height := _height_at_net(
					full_speed, short_angle, contact_height_meters, ground_to_net,
					gravity_mps2,
				)
				if short_height >= needed:
					return {
						"angle_degrees": short_angle,
						"aim_distance": shortened,
						"speed_mps": full_speed,
						"mode": "shortened", "cleared": true,
					}
				if short_height > fallback_height:
					fallback_height = short_height
					fallback_angle = short_angle
					fallback_distance = shortened
					fallback_speed = full_speed

	## Nothing on offer met the margin. Take the highest ball the search found if
	## it gets over the tape at all -- that is a hitter giving up the shot they
	## wanted, not a hitter giving up on the net.
	var over := CourtConstants.NET_HEIGHT_METERS + NET_CLEARANCE_FLOOR_METERS
	return {
		"angle_degrees": fallback_angle,
		"aim_distance": fallback_distance,
		"speed_mps": fallback_speed,
		"mode": ("scraped" if fallback_height >= over
			else ("unsolved" if fallback_height == -INF else "forced")),
		"cleared": fallback_height >= over,
	}


## The quickest roll shot that still gets over, at or below this pace.
##
## A hitter who has decided to lift the ball has one dial left: how hard. For a
## fixed range there are only two angles that carry the ball, the lofted root is
## the high one, and softening the swing walks it down toward 45 degrees.
##
## **The objective is hang time, not steepness, and getting that wrong is
## instructive.** The first version searched for the flattest clearing loft, on
## the reasoning that a flatter arc is a better shot. It is not, on its own: a
## flat lob is slow, and flight time is `range / (speed * cos(angle))`, so giving
## up pace to flatten can easily *lengthen* the flight. Measured at each attempt
## on the same population:
##
##     full pace, steepest root      apex 9.34 m
##     flattest clearing loft        median flight 2.367 s, p90 3.018
##     bounded to 80% of pace        median flight 3.165 s, p90 3.797
##
## All three are the same mistake -- optimising a proxy. What the defence
## actually gets from a roll shot is *time*, and what a hitter is trying to deny
## them is time, so the thing to minimise is the flight itself. Horizontal speed
## is that, exactly and directly, and it prices the arc and the pace together
## instead of trading one for the other blind.
##
## `steepest_angle` is the loft already known to clear at `from_speed`, returned
## unchanged when nothing softer beats it. This can only improve on it.
static func _quickest_clearing_loft(
	from_speed: float,
	to_speed: float,
	aim_distance: float,
	contact_height_meters: float,
	ground_to_net: float,
	needed: float,
	steepest_angle: float,
	gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var best_angle := steepest_angle
	var best_speed := from_speed
	var best_ground_speed := from_speed * cos(deg_to_rad(steepest_angle))
	for step in range(1, LOFT_FLATTENING_STEPS + 1):
		var speed := lerpf(
			from_speed, minf(to_speed, from_speed),
			float(step) / float(LOFT_FLATTENING_STEPS),
		)
		var solved := BallFlightModel.solve_angle_for_range(
			speed, aim_distance, contact_height_meters, gravity_mps2
		)
		if not bool(solved.get("lofted_found", false)):
			continue
		var angle := float(solved.lofted_angle_degrees)
		var ground_speed := speed * cos(deg_to_rad(angle))
		if ground_speed <= best_ground_speed:
			continue
		if _height_at_net(
			speed, angle, contact_height_meters, ground_to_net, gravity_mps2
		) < needed:
			continue
		best_angle = angle
		best_speed = speed
		best_ground_speed = ground_speed
	return {
		"angle_degrees": best_angle, "aim_distance": aim_distance,
		"speed_mps": best_speed, "mode": "lofted", "cleared": true,
	}


static func _height_at_net(
	speed_mps: float,
	angle_degrees: float,
	contact_height_meters: float,
	ground_to_net: float,
	gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,
) -> float:
	return BallFlightModel.height_at_distance(
		BallFlightModel.solve_flight(
			speed_mps, angle_degrees, contact_height_meters, gravity_mps2
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


## A body's width, and therefore the gap at which a wall has stopped being one.
const SEAM_SPLIT_METERS: float = 0.9


## How closed the wall is, 0 to 1.
##
## Measured where a seam exists: the widest gap between neighbouring blockers'
## spans, against a body's width. Spans that touch or overlap read as sealed; a
## gap you could stand in reads as split.
##
## A wall of one has no seam, so it is sealed by definition. That is not a
## generosity -- what a single blocker lacks is *size*, and the size term
## already charges for it. Folding "there is only one of them" into the seal as
## well would be the same fact billed twice.
static func _wall_seal(blockers: Array) -> float:
	if blockers.size() < 2:
		return 1.0
	var spans: Array[Vector2] = []
	for blocker in blockers:
		var centre := float(blocker.get("net_x", 0.5)) \
			* CourtConstants.COURT_WIDTH_METERS
		var half := float(blocker.get("half_width_m", 0.45))
		spans.append(Vector2(centre - half, centre + half))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var widest_gap := 0.0
	for index in range(1, spans.size()):
		widest_gap = maxf(widest_gap, spans[index].x - spans[index - 1].y)
	return clampf(1.0 - widest_gap / SEAM_SPLIT_METERS, 0.0, 1.0)


## How formed the wall in front of the hitter is, 0-1. Two blockers is a full
## wall; one is half a problem; none is an open net.
static func _block_presence(blockers: Array) -> float:
	return clampf(float(blockers.size()) * 0.5, 0.0, 1.0)


static func _rating(player: VolleyballPlayer, attribute: String) -> float:
	return clampf(float(player.get(attribute)) / 100.0, 0.0, 1.0)
