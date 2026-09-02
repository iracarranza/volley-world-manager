class_name GeometricAttackResolver
extends RefCounted

## NOTE Gate E: the five Gate B-D models composed into one call -- GEOMETRIC_ATTACK_RESOLVER.md

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
const TacticalInstructionModelRef := preload(
	"res://scripts/simulation/tactical_instruction_model.gd"
)

## How many bearings across the repertoire cone get evaluated. Seventeen is
## enough to find the gap without the scan cost mattering; the chosen bearing is
## perturbed afterwards anyway, so this is a search resolution and not a menu.
const COURSE_SAMPLES: int = 17
## NOTE an open lane against the strain of turning to reach it -- GEOMETRIC_ATTACK_RESOLVER.md
const STRAIN_AVERSION: float = 0.85
## How much air a hitter wants between the ball and the tape when choosing a
## shot. Not a safety factor on the outcome -- execution error is applied after
## this and can still put the ball in the net. This is the margin a hitter aims
## for, and aiming to clear by nothing is not a thing anyone does.
const NET_CLEARANCE_MARGIN_METERS: float = 0.12
## How many target distances get probed looking for one that clears. The search
## is monotone in distance, so this is a resolution and not a menu.
const NET_FEASIBILITY_STEPS: int = 9
## NOTE how many slower swings to try when nothing at full pace clears -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_SPEED_RELIEF_STEPS: int = 6
## How finely a roll shot is softened looking for the flattest arc that still
## clears. Eight resolves the pace range to about 7% of full swing, which is
## finer than the angle it is chasing responds to.
const LOFT_FLATTENING_STEPS: int = 12
## A roll clears the wall; it is not a lob.  The hitter may give up depth to
## stay below this rise rather than send a near-vertical root toward the roof.
## Relative to contact height so a short and a tall hitter produce the same
## shot shape.
const LOFT_MAX_APEX_RISE_METERS: float = 0.70
## NOTE the body-clearance problem immediately under the tape -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_BODY_CLEARANCE_FULL_DEMAND_METERS: float = 0.16
const NET_BODY_CLEARANCE_SAFE_METERS: float = 0.62
const NET_BODY_CLEARANCE_SPREAD_MIN: float = 0.32
const NET_BODY_CLEARANCE_SPREAD_MAX: float = 1.10
const NET_SPEED_RELIEF_FLOOR: float = 0.45
## NOTE cap on how far a bearing error may stretch the path to the tape -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_PATH_STRETCH_CAP: float = 2.0
## NOTE sigmas of vertical execution error the aim clears the tape by -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_CLEARANCE_SPREAD_SIGMAS: float = 2.0
## A float has no Magnus dive to make a steep launch read as a serve. This is
## the upper edge of its authored *intended* launch repertoire. Execution error
## remains free to miss outside it: clipping the delivered random tail would
## turn a choice constraint into an artificial outcome constraint. Resolution
## flies the delivered launch and owns every resulting net/landing change;
## presentation never reshapes it.
const FLOAT_LAUNCH_ANGLE_LIMIT_DEGREES: float = 30.0
## NOTE the least air a hitter accepts when the wanted margin is unreachable -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_CLEARANCE_FLOOR_METERS: float = 0.03
## NOTE how much contact-to-tape air a shortfall may spend -- GEOMETRIC_ATTACK_RESOLVER.md
const NET_SHORTFALL_FLOOR: float = 0.25
## NOTE share of a spike's execution spread that a serve carries -- GEOMETRIC_ATTACK_RESOLVER.md
const SERVE_SPREAD_MULTIPLIER: float = 0.70

## NOTE how far off full pace a server may come to clear the tape -- GEOMETRIC_ATTACK_RESOLVER.md
const SERVE_PACE_RELIEF_STEPS: int = 8
## There is no relief *floor* constant, and there was: `SERVE_PACE_RELIEF_FLOOR`
## sat at 0.55 and stopped the sweep before the serve became feasible. The floor
## is now `BallFlightModel.minimum_speed_to_reach` for the aim and the candidate
## spin -- see `_serve_launch`.
## How many spin settings a server is allowed to consider between none and all
## of theirs. Three is enough to find the trade -- flat, half-brushed, fully
## brushed -- and a finer sweep buys resolution the shot does not have.
const SERVE_SPIN_LEVELS: int = 3
## NOTE the flat SERVE_NET_CLEARANCE_METERS dial is gone; the swing's own rule applies -- GEOMETRIC_ATTACK_RESOLVER.md


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
	attack_type: String = "",
	tactical_call: String = "",
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
	## NOTE the wall as it was when the choice was made, not as it finished -- GEOMETRIC_ATTACK_RESOLVER.md
	var commitment_share := AttackReadModel.commitment_share(approach_quality)
	var perceived_blockers := AttackReadModel.perceived_blockers(
		blockers, reading, Array(draws.get("read", [])), commitment_share
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
			- float(course.strain) * STRAIN_AVERSION \
			+ TacticalInstructionModelRef.attack_target_score_bias(
				tactical_call, contact, probe, attacking_negative_y
			)
		if tactical_call == "tool" and not perceived_blockers.is_empty():
			var crossing := AttackCourseModel.net_crossing_x(
				contact, float(course.bearing_degrees), attacking_negative_y
			)
			var nearest_hand := 10.0
			for blocker in perceived_blockers:
				nearest_hand = minf(nearest_hand, absf(
					crossing - float(blocker.get("net_x", 0.5))
				) * CourtConstants.COURT_WIDTH_METERS)
			## Prefer a credible hand contact, but never remove the open-course
			## read; a sufficiently bad tooling angle can still lose the choice.
			score += lerpf(0.38, -0.20, clampf(nearest_hand / 1.2, 0.0, 1.0))
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
	var shot_shape := _shot_shape(attack_type, float(draws.get(
		"intent", AttackPowerModel.DRIVE_INTENT
	)))
	var chosen := AttackPowerModel.choose_power(
		ceiling, float(shot_shape.intent),
		aim_distance, contact_height_meters,
		AttackPowerModel.aggression_from(
			float(hitter.aggression) / 100.0, team_decisiveness,
			_rating(hitter, "tactical_discipline"),
		),
		_rating(hitter, "composure"),
		_rating(hitter, "decision_making"),
		_block_presence(blockers),
		float(draws.get("judgment", 0.0)),
	)

	## NOTE this swing's spread, once commitment is paid for -- GEOMETRIC_ATTACK_RESOLVER.md
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
		## NOTE the wall reaches the swing here; before this it reached it through nothing -- GEOMETRIC_ATTACK_RESOLVER.md
		* AttackSwingModel.block_spread_multiplier(
			blockers.size(), _wall_seal(blockers)
		)
	## The shot the hitter chose is a mechanical action, not just a caption. A
	## controlled roll uses less of the arm and a larger contact surface; a tip
	## is safer still. Before this term `_identity_hit_type()` selected those
	## actions for a cautious side and the geometric resolver ignored the choice,
	## so “Defensive” attacks were labelled safe while missing more often than
	## full-commitment “Physical” swings.
	swing_spread *= float(shot_shape.spread_multiplier)
	var net_distance_meters := absf(
		contact.y - CourtConstants.NET_Y
	) * CourtConstants.COURT_LENGTH_METERS
	var net_avoidance_demand := 1.0 - smoothstep(
		NET_BODY_CLEARANCE_FULL_DEMAND_METERS,
		NET_BODY_CLEARANCE_SAFE_METERS,
		net_distance_meters,
	)
	var net_control := clampf(
		_rating(hitter, "attack_accuracy") * 0.45
			+ _rating(hitter, "approach_timing") * 0.25
			+ approach_quality * 0.30,
		0.0, 1.0,
	)
	var net_avoidance_multiplier := 1.0 + net_avoidance_demand * lerpf(
		NET_BODY_CLEARANCE_SPREAD_MAX,
		NET_BODY_CLEARANCE_SPREAD_MIN,
		net_control,
	)
	swing_spread *= net_avoidance_multiplier

	## --- the angle that puts that speed where it was aimed -------------------
	## NOTE constrained by the tape; 24% of swings were dives into the net before -- GEOMETRIC_ATTACK_RESOLVER.md
	var gravity_mps2 := BallFlightModel.DEFAULT_GRAVITY_MPS2
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
	if _apex_limited_launch_mode(str(launch.get("mode", ""))):
		var intended_limit := _maximum_loft_angle(
			float(launch.speed_mps), gravity_mps2
		)
		if float(launch.angle_degrees) > intended_limit:
			launch["angle_degrees"] = intended_limit
			launch["apex_limited"] = true
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
	## The feasibility search budgets vertical error for clearing the tape, but an
	## unbounded positive draw can still turn its roll into a near-vertical lob.
	## Limit the ball actually struck as well as the intention; resolution then
	## reads the new landing naturally (including long or out).
	if _apex_limited_launch_mode(str(launch.get("mode", ""))):
		var delivered_limit := _maximum_loft_angle(
			float(delivered.speed_mps), gravity_mps2
		)
		if float(delivered.vertical_angle_degrees) > delivered_limit:
			delivered["vertical_angle_degrees"] = delivered_limit
			launch["apex_limited"] = true

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
						float(hitter.aggression) / 100.0,
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
		"loft_apex_limited": bool(launch.get("apex_limited", false)),
		"net_distance_meters": net_distance_meters,
		"net_avoidance_demand": net_avoidance_demand,
		"net_avoidance_spread_multiplier": net_avoidance_multiplier,
		"delivered": delivered,
		"resolution": resolved,
		"signature_move": move,
		"attack_type": attack_type,
		"tactical_call": tactical_call,
		"shot_spread_multiplier": float(shot_shape.spread_multiplier),
		"landing": resolved.landing,
		"flight": resolved.flight,
		## NOTE when the wall jumped, off the actual blockers -- GEOMETRIC_ATTACK_RESOLVER.md
		"block_jump_timing": _wall_jump_timing(blockers),
		## How formed the wall was when this hitter chose. Published because a
		## swing beaten by a closing block and a swing beaten by a formed one are
		## different events and read identically without it.
		"commitment_share": commitment_share,
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
		## NOTE which hand met the ball and how high it was -- BLOCK_REALISED_CONTACT.md -- GEOMETRIC_ATTACK_RESOLVER.md
		"block_contact_actor_id": int(Dictionary(
			Dictionary(resolved.get("block", {})).get("blocker", {})
		).get("player_id", -1)),
		"block_contact_height_meters": Dictionary(
			resolved.get("block", {})
		).get("height_at_net_meters", null),
		## Where the ball went after the hands, flat rather than as a nested
		## dictionary because two curators between here and the event copy named
		## keys and a nested one has been dropped at that seam three times.
		"block_deflection_landing": Dictionary(
			resolved.get("deflection", {})
		).get("landing", null),
		"block_deflection_speed_mps": float(Dictionary(
			resolved.get("deflection", {})
		).get("speed_mps", 0.0)),
		"block_deflection_vertical_angle_degrees": float(Dictionary(
			resolved.get("deflection", {})
		).get("vertical_angle_degrees", 0.0)),
		"block_deflection_duration_seconds": float(Dictionary(
			resolved.get("deflection", {})
		).get("duration_seconds", 0.0)),
		"block_deflection_playable": bool(Dictionary(
			resolved.get("deflection", {})
		).get("playable", false)),
		"net_height_over_block_meters": float(
			resolved.get("net_height_over_block_meters", 0.0)
		),
		"ball_height_at_net_meters": resolved.get(
			"ball_height_at_net_meters", null
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


## NOTE one serve, aim to launch to flight to landing to verdict -- GEOMETRIC_ATTACK_RESOLVER.md
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
	var launch := _serve_launch(
		contact, bearing, speed, contact_height_meters, distance,
		attacking_negative_y, spin_state,
		AttackSwingModel.vertical_spread_degrees(control, SERVE_SPREAD_MULTIPLIER),
		AttackSwingModel.bearing_spread_degrees(control, SERVE_SPREAD_MULTIPLIER),
		AttackSwingModel.power_error_scale(control, SERVE_SPREAD_MULTIPLIER, false),
		str(server.primary_serve_style).to_lower().contains("float"),
	)
	## **The one launch state.** Everything below reads pace, angle and gravity
	## from here and from nowhere else, which is the whole of what this pass
	## changed: the ball is chosen, then flown, and where it lands is the answer
	## rather than the question.
	var serve_gravity := float(launch.gravity_mps2)
	var chosen_spin: Dictionary = launch.spin
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
		"out_reason": str(resolved.get("out_reason", "")),
		"bearing_degrees": bearing,
		"target_distance_meters": distance,
		"speed_mps": float(delivered.speed_mps),
		"launch_mode": str(launch.mode),
		## The state a consumer needs to fly this ball itself, published rather
		## than left to be reconstructed from two endpoints and a duration --
		## which is what `BallPresentation.launch_speed_mps` had been doing, and
		## why truncating a flight silently changed the speed it left the hand at.
		"launch": {
			"contact": contact,
			"contact_height_meters": contact_height_meters,
			"bearing_degrees": float(delivered.bearing_degrees),
			"angle_degrees": float(delivered.vertical_angle_degrees),
			"speed_mps": float(delivered.speed_mps),
			"horizontal_speed_mps": float(resolved.flight.horizontal_speed_mps),
			"vertical_speed_mps": float(resolved.flight.vertical_speed_mps),
			"gravity_mps2": serve_gravity,
			"spin": chosen_spin,
			"mode": str(launch.mode),
			"cleared": bool(launch.cleared),
		},
		"spin": chosen_spin,
		"delivered": delivered,
		"resolution": resolved,
		"landing": resolved.landing,
		"flight": resolved.flight,
	}


## NOTE the ball this server chooses, swept over arc and pace at the aim -- GEOMETRIC_ATTACK_RESOLVER.md
static func _serve_launch(
	contact: Vector2,
	bearing_degrees: float,
	speed_mps: float,
	contact_height_meters: float,
	aim_distance_meters: float,
	attacking_negative_y: bool,
	spin_state: Dictionary,
	## What this serve is going to scatter by, which is what decides how much air
	## it has to plan for. Both spreads, because a bearing error lengthens the
	## path to the tape and the ball has to stay up over the extra ground.
	vertical_spread_degrees: float,
	bearing_spread_degrees: float,
	## NOTE pace removed per sigma of power shortfall -- GEOMETRIC_ATTACK_RESOLVER.md
	_power_shortfall_scale: float,
	is_float_serve: bool = false,
) -> Dictionary:
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
	## The swing's own clearance rule, applied to the contact it matters most on.
	## See the constants above for why the serve no longer has one of its own.
	var needed := CourtConstants.NET_HEIGHT_METERS + maxf(
		NET_CLEARANCE_MARGIN_METERS,
		ground_to_net * tan(deg_to_rad(
			maxf(vertical_spread_degrees, 0.0) * NET_CLEARANCE_SPREAD_SIGMAS
		)),
	)
	var full_speed := maxf(speed_mps, BallFlightModel.MIN_SPEED_MPS)
	var best := {}
	var best_ground_speed := 0.0
	## The least-bad serve seen anywhere in the sweep, kept in case nothing
	## clears -- the highest ball at the tape, which is the same serve this
	## server was always going to hit, aimed at the problem. `_feasible_launch`
	## reaches for the identical fallback on a swing and says why: a hitter who
	## cannot get the ball over still tries to get the ball over.
	var forced := {}
	var forced_height := -INF
	## NOTE a float buys no Magnus dive, so a steep launch punts -- GEOMETRIC_ATTACK_RESOLVER.md
	for spin_step in range(SERVE_SPIN_LEVELS):
		var used := BallSpin.spin(
			float(spin_state.get("axis", 0.0)),
			float(spin_state.get("rate_rps", 0.0))
				* float(spin_step) / float(SERVE_SPIN_LEVELS - 1),
		)
		var gravity := BallSpin.gravity_for(used)
		## NOTE the pace-relief floor is derived from reach, not dialled -- GEOMETRIC_ATTACK_RESOLVER.md
		var reach_floor := float(BallFlightModel.minimum_speed_to_reach(
			aim_distance_meters, contact_height_meters, gravity
		).speed_mps)
		## A server who cannot carry the ball that far at full pace has no relief
		## to give: the sweep would otherwise interpolate *upward*, handing them
		## speed they do not have.
		var relief_floor := minf(reach_floor, full_speed)
		for step in range(SERVE_PACE_RELIEF_STEPS):
			var trial := lerpf(
				full_speed, relief_floor,
				float(step) / float(SERVE_PACE_RELIEF_STEPS - 1),
			)
			var solved := BallFlightModel.solve_angle_for_range(
				trial, aim_distance_meters, contact_height_meters, gravity
			)
			for branch in [&"driven", &"lofted"]:
				if not bool(solved.get("%s_found" % branch, false)):
					continue
				var angle := float(solved.get("%s_angle_degrees" % branch, 0.0))
				## **Measured under the gravity this candidate flies under.**
				## The sweep used to solve the flight with the ball's own spin
				## gravity and then ask its height at the net under the default
				## 9.8, so a topspin serve was certified over a tape it crossed
				## as much as a metre lower. One ball, two gravities -- §0.
				var height_at_net := _height_at_net(
					trial, angle, contact_height_meters, ground_to_net, gravity
				)
				var candidate := {
					"angle_degrees": angle, "speed_mps": trial,
					"gravity_mps2": gravity, "spin": used,
					"mode": str(branch), "cleared": true,
				}
				if ground_to_net > 0.0 and height_at_net < needed:
					if height_at_net > forced_height:
						forced_height = height_at_net
						forced = candidate.duplicate()
						forced["mode"] = "forced"
						forced["cleared"] = false
					continue
				var ground_speed := trial * cos(deg_to_rad(angle))
				if ground_speed <= best_ground_speed:
					continue
				best_ground_speed = ground_speed
				best = candidate
	if not best.is_empty():
		if is_float_serve \
				and float(best.angle_degrees) > FLOAT_LAUNCH_ANGLE_LIMIT_DEGREES:
			best["angle_degrees"] = FLOAT_LAUNCH_ANGLE_LIMIT_DEGREES
			best["mode"] = "driven_flattened"
			best["cleared"] = _height_at_net(
				float(best.speed_mps), FLOAT_LAUNCH_ANGLE_LIMIT_DEGREES,
				contact_height_meters, ground_to_net,
				float(best.gravity_mps2),
			) >= needed
		return best
	if not forced.is_empty():
		return forced
	## Nothing solved at any pace or spin: this server cannot carry the ball to
	## where they aimed at all. They hit it anyway, flat out and flat, and the
	## resolution below will read the tape off the flight like every other serve.
	return {
		"angle_degrees": AttackPowerModel.DRIVEN_REFERENCE_ANGLE_DEGREES,
		"speed_mps": full_speed,
		"gravity_mps2": BallSpin.gravity_for(spin_state),
		"spin": spin_state,
		"mode": "unsolved",
		"cleared": false,
	}


## NOTE the steepest ball this hitter can hit at the speed they chose -- GEOMETRIC_ATTACK_RESOLVER.md
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
	## NOTE the gravity this ball flies under, not the default -- GEOMETRIC_ATTACK_RESOLVER.md
	gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	## NOTE the aimed path, and the longer one a bearing error puts them on -- GEOMETRIC_ATTACK_RESOLVER.md
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
	## NOTE the clearance this swing needs, not what any swing needs -- GEOMETRIC_ATTACK_RESOLVER.md
	var wanted := maxf(
		NET_CLEARANCE_MARGIN_METERS,
		ground_to_net * tan(deg_to_rad(
			maxf(vertical_spread_degrees, 0.0) * NET_CLEARANCE_SPREAD_SIGMAS
		)),
	)
	var needed := CourtConstants.NET_HEIGHT_METERS + wanted
	var reach := maxf(far_meters, aim_distance)
	var full_speed := maxf(speed_mps, BallFlightModel.MIN_SPEED_MPS)
	## NOTE least-bad swing seen in the search, kept in case nothing clears -- GEOMETRIC_ATTACK_RESOLVER.md
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
		## NOTE nothing driven clears at this pace: try lifting before shedding more -- GEOMETRIC_ATTACK_RESOLVER.md
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
				## NOTE down to the least force that reaches, not a fraction of full pace -- GEOMETRIC_ATTACK_RESOLVER.md
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
	## NOTE nothing was solvable: the hitter cannot carry the ball to the aim -- GEOMETRIC_ATTACK_RESOLVER.md
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


## NOTE the quickest roll shot that still clears, at or below this pace -- GEOMETRIC_ATTACK_RESOLVER.md
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
	## Preserve the intended landing.  Among roots that stay within the physical
	## rise, horizontal pace (and therefore the shortest defensive window) wins.
	## If no sampled root fits, return the lowest clearing one; the final launch
	## guard above clips that pathological tail before the ball is resolved.
	var lowest_clearing := {
		"angle_degrees": steepest_angle,
		"aim_distance": aim_distance,
		"speed_mps": from_speed,
		"mode": "lofted",
		"cleared": true,
	}
	var lowest_rise := INF
	var lowest_ground_speed := 0.0
	var best := {}
	var best_ground_speed := -INF
	for speed_step in range(LOFT_FLATTENING_STEPS + 1):
		var speed := lerpf(
			from_speed, minf(to_speed, from_speed),
			float(speed_step) / float(LOFT_FLATTENING_STEPS),
		)
		var solved := BallFlightModel.solve_angle_for_range(
			speed, aim_distance, contact_height_meters, gravity_mps2
		)
		if not bool(solved.get("lofted_found", false)):
			continue
		var angle := float(solved.lofted_angle_degrees)
		if _height_at_net(
			speed, angle, contact_height_meters, ground_to_net, gravity_mps2
		) < needed:
			continue
		var flight := BallFlightModel.solve_flight(
			speed, angle, contact_height_meters, gravity_mps2
		)
		var rise := maxf(
			float(flight.apex_height_meters) - contact_height_meters, 0.0
		)
		var ground_speed := speed * cos(deg_to_rad(angle))
		var candidate := {
			"angle_degrees": angle,
			"aim_distance": aim_distance,
			"speed_mps": speed,
			"mode": "lofted",
			"cleared": true,
		}
		if rise < lowest_rise - 0.0001 \
				or (is_equal_approx(rise, lowest_rise)
					and ground_speed > lowest_ground_speed):
			lowest_clearing = candidate
			lowest_rise = rise
			lowest_ground_speed = ground_speed
		if rise <= LOFT_MAX_APEX_RISE_METERS \
				and ground_speed > best_ground_speed:
			best = candidate
			best_ground_speed = ground_speed
	return best if not best.is_empty() else lowest_clearing


## Every branch that may choose an upward relief/fallback arc shares the same
## physical ceiling. `forced` was the hole: a failed clearing search could keep
## an 80-degree root, produce a 14.75 m apex, and evade a guard named only for
## `lofted` even though it was the same ball.
static func _apex_limited_launch_mode(mode: String) -> bool:
	## `shortened` is the same physical concession as `lofted`: the hitter could
	## not carry the intended depth, so they lift a shorter ball over the tape.
	## Leaving it out of this list let that rare last-resort branch keep the raw
	## high root (52 degrees in the probe), even though every ordinary roll was
	## already bounded.  The result was a 5-6 m "spike" hiding under a different
	## launch-mode label.
	return mode in ["lofted", "shortened", "forced", "scraped"]


## Highest launch angle whose vertical component rises no more than the roll
## envelope.  Derived from v_y^2 / 2g = h, so the bound stays true at every pace.
static func _maximum_loft_angle(
	speed_mps: float,
	gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,
) -> float:
	var speed := maxf(speed_mps, BallFlightModel.MIN_SPEED_MPS)
	var vertical_limit := sqrt(
		2.0 * maxf(gravity_mps2, 0.1) * LOFT_MAX_APEX_RISE_METERS
	)
	return rad_to_deg(asin(clampf(vertical_limit / speed, 0.0, 1.0)))


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


## NOTE how closed the wall is, 0 to 1 -- GEOMETRIC_ATTACK_RESOLVER.md
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


## The mechanical meaning of the selected attack action. Unknown actions retain
## the resolver's drawn intent so adding a label elsewhere cannot silently
## change an attack; the shared live vocabularies are explicit here.
static func _shot_shape(attack_type: String, drawn_intent: float) -> Dictionary:
	match attack_type:
		"Controlled roll", "Roll shot":
			return {
				"intent": AttackPowerModel.CONTROL_INTENT,
				"spread_multiplier": 0.72,
			}
		"Emergency tip", "Short tip", "Tip":
			return {
				"intent": AttackPowerModel.OFF_SPEED_INTENT,
				"spread_multiplier": 0.62,
			}
		"Power swing", "Tempo swing", "Quick attack", "Pipe attack", "Tool attempt":
			return {
				"intent": AttackPowerModel.DRIVE_INTENT,
				"spread_multiplier": 1.0,
			}
	return {
		"intent": drawn_intent,
		"spread_multiplier": 1.0,
	}


static func _rating(player: VolleyballPlayer, attribute: String) -> float:
	return clampf(float(player.get(attribute)) / 100.0, 0.0, 1.0)


## What each blocker's jump was, keyed by player id.
##
## One entry per body that left the floor, so playback can draw two blockers on
## two different clocks -- a middle who went early beside a pin who went late is
## the picture the wall's timing actually makes, and a single shared figure
## cannot show it.
static func _wall_jump_timing(blockers: Array) -> Dictionary:
	var out := {}
	for raw in blockers:
		var blocker: Dictionary = raw
		if not blocker.has("timing_error_seconds"):
			continue
		out[int(blocker.get("player_id", -1))] = {
			"timing_error_seconds": float(blocker["timing_error_seconds"]),
			"hang_seconds": float(blocker.get("hang_seconds", 0.0)),
			## `rising` means the ball beat them to the apex, which is a late
			## jump. `resolve` makes that split on the close fraction rather than
			## on a draw, and it is the sign the apex is offset by.
			"late": str(blocker.get("arm_state", "extended")) == "rising",
			## Two arms, one, or none -- the shape of the wall this body made.
			"arms": str(blocker.get("arm_commitment", "two")),
		}
	return out
