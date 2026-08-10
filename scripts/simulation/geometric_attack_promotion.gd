class_name GeometricAttackPromotion
extends RefCounted

## Gate E. The translation layer between a rally and the geometric attack.
##
## `GeometricAttackResolver` is a pure function over a hitter, a contact point, a
## wall and a defence. A rally holds none of those directly -- it holds a block
## *formation* with a primary and an assist and their close fractions, a set of
## live positions, an approach with a jump multiplier, and an RNG it must draw
## from in a fixed order. This turns one into the other, and turns the resolver's
## answer back into the outcome vocabulary the rally continues with.
##
## It is a separate file from the resolver on purpose. The resolver must stay a
## pure function of geometry so it can be swept without a rally; everything that
## knows what a `RallyEvent` or a `RotationLineup` is lives here.

const AttackResolverModel := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const FeatureFlags := preload("res://scripts/simulation/rally_feature_flags.gd")
const AttackPowerModel := preload("res://scripts/simulation/attack_power_model.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")
const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const BlockJumpModelRef := preload("res://scripts/simulation/block_jump_model.gd")
const SignatureMoveModelRef := preload(
	"res://scripts/simulation/signature_move_model.gd"
)

## Where a hitter's contact sits relative to the top of their reach, and how
## much of their leap a blocker gets. These two numbers decide the entire block
## contest -- the test is `ball_height_at_net` against `blocker_reach`, so what
## matters is the difference between them -- and they were calibrated in Gate D.
##
## They live here, in the production path, rather than in the Gate D harness.
## The harness reads them from here so that the swept numbers and the played
## numbers cannot drift apart: a calibration that measures constants the game
## does not use is worse than no calibration.
const CONTACT_BELOW_REACH_METERS: float = 0.10
const BLOCKER_REACH_EFFORT: float = 0.62
## How much net one pair of hands seals, at a full close.
const BLOCKER_HALF_WIDTH_METERS: float = 0.34

## Below this close fraction a blocker is not part of the wall at all. They are
## still moving, still turned, still arriving -- the ball passes where they are
## going to be rather than where they are.
const WALL_JOIN_CLOSE: float = 0.34

## How far off the line they read a block intent moves the wall, in metres.
##
## Sized as one blocker's own half-width rather than picked: shifting by less
## than that leaves the same balls in front of the same hands, and shifting by
## more opens a lane wider than the wall itself. What the intent buys is the
## *other* half of the hitter's cone, not a different court.
const BLOCK_INTENT_SHIFT_METERS: float = 0.34
## How many bearings across the hitter's cone the read averages. A resolution,
## not a menu -- the answer is the cone's centre and this is how finely it is
## found.
const CONE_READ_SAMPLES: int = 9


## Where the wall should stand to meet this swing, in normalised court x.
##
## A wall used to be staged on the hitter's *contact*. That is where the hitter
## jumps, not where the ball crosses the tape: a hitter contacting a metre off
## the net with a turned shoulder sends the ball through a point well inside
## their own position. Measured over 1,013 home blocks, every beaten wall was
## beaten toward court centre -- p10 +0.59 m, median +2.13 m, p90 +3.50 m -- so
## the misses were not scatter around a well-placed wall, they were a wall
## standing somewhere the ball systematically was not. Two metres against a
## 0.34 m half-width is not a width that can be widened into a fix.
##
## What a blocker can see before the swing is the approach: which way the hitter
## is running and where they will meet the ball. That is the line this reads, and
## `read_quality` decides how much of the correction they get -- a blocker who
## has not read the play still ends up near the contact, which is exactly the old
## behaviour, so a bad read costs what it used to cost and a good one no longer
## does.
##
## Intent then takes one side of the remaining cone. Sealing holds the line and
## concedes the angle to the diggers; funnelling gives the line and channels the
## ball into the middle. Until this existed both intents stood on the same point
## and differed only in how tall and wide they were, which is why neither could
## separate from the other on a swinging opponent.
static func wall_stage_x(
	contact: Vector2,
	natural_bearing_degrees: float,
	attacking_negative_y: bool,
	read_quality: float,
	cone_degrees: float,
	block_intent: String = "Balanced",
) -> float:
	## Not the natural line -- the middle of what this hitter can actually do.
	##
	## Reading the approach and standing on the bearing it points at assumes the
	## hitter swings where they are running, and `STRAIN_AVERSION` was calibrated
	## on the measurement that they do not: 60.4% of swings leave the natural line
	## for the biggest available gap. Staged on the natural crossing the wall was
	## still a systematic 0.8 m short of where the ball came through, which is
	## more than a blocker's own half-width -- so the intent dials, which express
	## themselves in reach and width, were swamped by a placement error and both
	## of them simply sampled whichever side of the residual sat nearer the bulk.
	##
	## The cone's centre is what a blocker covers when they cannot read the one
	## shot: it is the geometry of the hitter's repertoire rather than a constant
	## fitted to close the gap, and it does not need to know the choice the hitter
	## has not made yet.
	var predicted := 0.0
	var samples := 0
	for index in range(CONE_READ_SAMPLES):
		var fraction := float(index) / float(CONE_READ_SAMPLES - 1)
		var bearing := natural_bearing_degrees \
			+ lerpf(-cone_degrees, cone_degrees, fraction)
		if absf(bearing) > AttackCourseModel.MAX_COURSE_BEARING_DEGREES:
			continue
		var crossing := AttackCourseModel.net_crossing_x(
			contact, bearing, attacking_negative_y
		)
		if crossing < 0.0 or crossing > 1.0:
			continue
		predicted += crossing
		samples += 1
	if samples == 0:
		predicted = AttackCourseModel.net_crossing_x(
			contact, natural_bearing_degrees, attacking_negative_y
		)
	else:
		predicted /= float(samples)
	var staged := lerpf(contact.x, predicted, clampf(read_quality, 0.0, 1.0))
	## Which way is "angle" and which is "line" is a fact about this hitter, not
	## about which half of the court the wall is standing in. It is the direction
	## the ball is already turning away from the contact -- a right-pin hitter
	## cutting back across their body is turning one way whether their crossing
	## lands at x 0.7 or x 0.4, and a shift defined against court centre flips
	## sign halfway through that range. It did, and it inverted both intents.
	var angle_direction := signf(predicted - contact.x)
	if angle_direction == 0.0:
		angle_direction = 1.0 if contact.x < 0.5 else -1.0
	var shift := 0.0
	match block_intent:
		## Hold the line and concede the angle to the diggers behind.
		"Seal":
			shift = -BLOCK_INTENT_SHIFT_METERS
		## Give the line and stand in the angle, so the ball is channelled to the
		## middle rather than allowed to find the sideline.
		"Funnel":
			shift = BLOCK_INTENT_SHIFT_METERS
	return clampf(
		staged + shift * angle_direction / CourtConstants.COURT_WIDTH_METERS,
		0.05, 0.95,
	)


## Whether this rally resolves its attacks geometrically.
##
## Mirrors the block and attack rollouts: the production flag decides, and a
## development override can open the path in a debug build for calibration and
## for the tests that have to exercise it while the flag is off.
static func enabled(development_requested: bool = false) -> bool:
	if FeatureFlags.ENABLE_GEOMETRIC_ATTACK:
		return true
	return development_requested \
		and FeatureFlags.ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK \
		and OS.is_debug_build()


## The wall in front of this swing.
##
## A `_form_opponent_block` formation names a primary and an assist and says how
## far each of them closed. The geometric resolver does not take a close
## fraction -- it intersects a trajectory with a pair of hands -- so the close
## has to become geometry. A blocker who did not close is not in the wall; one
## who closed partially seals proportionally less net. That is the whole mapping,
## and it is deliberately the only place a close fraction becomes a width, so
## the legacy contest and the geometric one cannot disagree about what closing
## means.
## What a block intends, as geometry rather than as a threshold.
##
## The first version of this dial shifted `_contest_block`'s outcome bands, and
## the geometric promotion overwrote the outcome immediately afterwards -- so
## Seal and Funnel produced 0 stuffs and 1 deflection apiece with the flag on.
## A tactical option that silently does nothing is worse than one never added.
##
## The resolver decides contact by intersecting a trajectory with a pair of
## hands, so intent has to live in the hands. A committed block penetrates: more
## reach over the tape, a tighter seal, and beaten clean when it is wrong. A soft
## block stays down and wide: less penetration, more court taken away, more balls
## slowed rather than ended. That is the same tradeoff the bands described, in
## the only terms this model can read -- and unlike the bands it works on both
## paths, because the legacy contest reads the same wall.
## Reach is what separates the two, not width.
##
## The first attempt had sealing *narrow* each blocker -- and measured, it
## produced 16 stuffs against a funnelling block's 20, which is the dial
## backwards. Narrowing a blocker models smaller hands, not a tighter seal: a
## real seal closes the seam *between* two blockers, which this wall does not
## represent, so shrinking them only removed intersections of every kind and the
## reach bonus could not pay for it.
##
## What actually distinguishes the two is how high the hands get. Penetrating
## over the tape puts the ball down; staying low and wide gets a piece of it and
## leaves it alive. So sealing buys reach at no cost in width, and funnelling
## sells reach for it.
const SEAL_REACH_BONUS: float = 0.16
const SEAL_WIDTH_SCALE: float = 1.0
const FUNNEL_REACH_PENALTY: float = 0.14
const FUNNEL_WIDTH_SCALE: float = 1.16


## The wall a swing is hit into.
##
## `fallback_positions` is where each blocker stands when nothing has staged
## them yet, as a plain id -> position map rather than a team resource. It used
## to be the latter, which only one side of the net has: the opponent's swing
## passed `null` here, so every unstaged home blocker was placed at x = 0.5 --
## the middle of the net, regardless of who they were or where the ball was.
## A dictionary is the one shape both sides can supply.
static func block_wall(
	formation: Dictionary,
	fallback_positions: Dictionary,
	live_positions: Dictionary = {},
	block_intent: String = "Balanced",
	flow_for_team: float = 0.0,
) -> Array:
	var wall: Array = []
	var read_quality := clampf(float(formation.get("read_quality", 0.5)), 0.0, 1.0)
	for role in ["primary", "assist"]:
		var blocker := formation.get(role) as VolleyballPlayer
		if blocker == null:
			continue
		var close := float(formation.get("%s_close" % role, 0.0))
		if close < WALL_JOIN_CLOSE:
			continue
		var reach_effort := BLOCKER_REACH_EFFORT
		var width_scale := 1.0
		match block_intent:
			"Seal":
				reach_effort += SEAL_REACH_BONUS
				width_scale = SEAL_WIDTH_SCALE
			"Funnel":
				reach_effort -= FUNNEL_REACH_PENALTY
				width_scale = FUNNEL_WIDTH_SCALE
		## What this blocker reaches *at the ball*, not at the top of a jump they
		## may already have come down from. `reach_effort` stays the intent's
		## contribution -- sealing asks for a taller wall, funnelling a lower one --
		## and the jump model supplies the rest.
		var jump := BlockJumpModelRef.resolve(
			maxf(
				(blocker.jumping_reach_cm() - blocker.standing_reach_cm()) / 100.0,
				0.0,
			),
			clampf(float(blocker.block_timing) / 100.0, 0.0, 1.0),
			read_quality, close,
		)
		var timed_reach := blocker.standing_reach_cm() / 100.0 \
			+ maxf(
				(blocker.jumping_reach_cm() - blocker.standing_reach_cm()) / 100.0,
				0.0,
			) * float(jump.phase) * (
				clampf(reach_effort, 0.0, 1.0) / BLOCKER_REACH_EFFORT
			)
		wall.append({
			## Where they closed to, when the formation knows. `live_positions`
			## is the blocker's starting slot, so falling back to it puts the
			## wall at the rotation grid instead of at the lane.
			"net_x": float(formation.get(
				"%s_net_x" % role,
				_blocker_net_x(blocker, fallback_positions, live_positions),
			)),
			"reach_height_m": timed_reach if FeatureFlags.ENABLE_BLOCK_JUMP_TIMING \
				else blocker.jumping_reach_cm(
					clampf(reach_effort, 0.0, 1.0)
				) / 100.0,
			## What separates a stuff from a tool, carried to the contact -- and
			## only when the flag is open. `_block_contact` keys off the presence
			## of these, so attaching them unconditionally applied the whole
			## timing model with the flag shut, which is a switch that does not
			## switch anything off.
			"arm_state": str(jump.arm_state) \
				if FeatureFlags.ENABLE_BLOCK_JUMP_TIMING else null,
			"block_effectiveness": float(jump.effectiveness) \
				if FeatureFlags.ENABLE_BLOCK_JUMP_TIMING else null,
			"timing_quality": float(jump.timing_quality),
			"monster_block_charge": SignatureMoveModelRef.charge(
				SignatureMoveModelRef.monster_block_capability(
					clampf(float(blocker.block_timing) / 100.0, 0.0, 1.0),
					clampf(float(blocker.anticipation) / 100.0, 0.0, 1.0),
					clampf(float(blocker.composure) / 100.0, 0.0, 1.0),
				),
				float(blocker.match_confidence), flow_for_team,
			),
			"half_width_m": BLOCKER_HALF_WIDTH_METERS * width_scale
				* clampf(close, 0.0, 1.0),
			"player_id": blocker.id,
			"close": close,
		})
	return wall


## How high a body meets the ball, in metres, for each way of meeting it.
##
## Both forms of each: one taking a `VolleyballPlayer`, which is what the
## resolver has, and one taking the two reach figures in metres, which is what a
## physical profile carries. `BallPresentation` draws from the second pair, so
## the height a flight is *timed* from and the height it is *drawn* from are one
## number arrived at once. They were two, computed from the same body by two
## expressions that agreed by inspection and by nothing else.

## How high this hitter meets the ball, in metres.
##
## The approach's jump multiplier is what a run-up is *for*: a hitter who never
## reached their mark does not get their full leap. Applying it to the leap alone
## and not to standing reach keeps a short hitter with a bad approach from
## shrinking below their own head.
static func contact_height_meters(
	hitter: VolleyballPlayer,
	jump_multiplier: float = 1.0,
) -> float:
	if hitter == null:
		return 0.0
	return hitter_contact_from_reach(
		hitter.standing_reach_cm() / 100.0,
		hitter.jumping_reach_cm() / 100.0,
		jump_multiplier,
	)


static func hitter_contact_from_reach(
	standing_reach_meters: float,
	jumping_reach_meters: float,
	jump_multiplier: float = 1.0,
) -> float:
	var leap := maxf(jumping_reach_meters - standing_reach_meters, 0.0) \
		* clampf(jump_multiplier, 0.0, 1.5)
	return maxf(
		standing_reach_meters + leap - CONTACT_BELOW_REACH_METERS, 0.0
	)


## How high a server meets the ball.
##
## A jump server contacts near the top of their reach like a hitter; a standing
## float server contacts around head height and gets none of their leap. Rather
## than branch on a style string, this scales the leap by an effort figure the
## caller supplies, which is the same shape as the blocker's reach effort and
## keeps one expression for "how much of your jump did you actually use".
const SERVE_JUMP_EFFORT: float = 0.55


static func serve_contact_height_meters(
	server: VolleyballPlayer,
	effort: float = SERVE_JUMP_EFFORT,
) -> float:
	if server == null:
		return 0.0
	return serve_contact_from_reach(
		server.standing_reach_cm() / 100.0,
		server.jumping_reach_cm() / 100.0,
		effort,
	)


## Named separately from the hitter's even though the arithmetic is the same
## one, because the *effort* means something different: a hitter's comes from
## their approach and a server's from their style, and a standing float server
## takes none of their leap at all.
static func serve_contact_from_reach(
	standing_reach_meters: float,
	jumping_reach_meters: float,
	effort: float = SERVE_JUMP_EFFORT,
) -> float:
	return hitter_contact_from_reach(
		standing_reach_meters, jumping_reach_meters, clampf(effort, 0.0, 1.0)
	)


## How high a setter releases the ball, standing.
##
## Just short of full standing reach: hands meet the ball above the forehead, not
## at the top of an outstretched arm.
const SET_RELEASE_OF_STANDING_REACH: float = 0.97


static func set_contact_height_meters(
	setter: VolleyballPlayer,
	jumping: bool = false,
) -> float:
	if setter == null:
		return 0.0
	return set_contact_from_reach(
		setter.standing_reach_cm() / 100.0,
		setter.jumping_reach_cm() / 100.0,
		jumping,
	)


static func set_contact_from_reach(
	standing_reach_meters: float,
	jumping_reach_meters: float,
	jumping: bool = false,
) -> float:
	if not jumping:
		return standing_reach_meters * SET_RELEASE_OF_STANDING_REACH
	return lerpf(standing_reach_meters, jumping_reach_meters, JUMP_SET_EFFORT)


## How much of their leap a setter jumping to the ball actually uses.
const JUMP_SET_EFFORT: float = 0.58

## Where a platform is when it passes a ball, as a share of the passer's own
## height, and the band it never leaves. A pass is played off the forearms in
## front of the body, so it scales with the body but far less than a reach does
## -- a tall passer and a short one both bump from around waist height.
const PASS_CONTACT_OF_HEIGHT: float = 0.52
const PASS_CONTACT_MIN_METERS: float = 0.72
const PASS_CONTACT_MAX_METERS: float = 1.16


static func pass_contact_height_meters(passer: VolleyballPlayer) -> float:
	if passer == null:
		return PASS_CONTACT_MIN_METERS
	return pass_contact_from_height(float(passer.height_cm) / 100.0)


static func pass_contact_from_height(height_meters: float) -> float:
	return clampf(
		height_meters * PASS_CONTACT_OF_HEIGHT,
		PASS_CONTACT_MIN_METERS, PASS_CONTACT_MAX_METERS,
	)


## How high a blocker's hands are over the tape, as a share of full reach.
const BLOCK_CONTACT_OF_JUMPING_REACH: float = 0.96


static func block_contact_from_reach(jumping_reach_meters: float) -> float:
	return jumping_reach_meters * BLOCK_CONTACT_OF_JUMPING_REACH


## A serve has no block to read and no defence to pick a gap in -- it has three
## execution channels and nothing else -- so it draws three values, not eleven.
static func serve_draws(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"bearing": rng.randfn(0.0, 1.0),
		"vertical": rng.randfn(0.0, 1.0),
		"power": rng.randfn(0.0, 1.0),
	}


## Every random input the resolver needs, drawn in one fixed order.
##
## The resolver takes its randomness as data so a swing can be replayed or
## pinned. That only holds if the draws are taken in a stable order regardless of
## which branch the resolver later takes, so they are all pulled here, up front,
## before the resolver sees any of them. Drawing lazily inside the resolver would
## make the stream depend on the shot chosen, and two rallies with the same seed
## would stop matching.
static func draws(
	rng: RandomNumberGenerator,
	blocker_count: int,
	defender_count: int,
) -> Dictionary:
	var read: Array[float] = []
	for index in range(maxi(blocker_count, 0) * 2):
		read.append(rng.randfn(0.0, 1.0))
	var read_floor: Array[float] = []
	for index in range(maxi(defender_count, 0) * 2):
		read_floor.append(rng.randfn(0.0, 1.0))
	return {
		"read": read,
		"read_floor": read_floor,
		"judgment": rng.randfn(0.0, 1.0),
		"bearing": rng.randfn(0.0, 1.0),
		"vertical": rng.randfn(0.0, 1.0),
		"power": rng.randfn(0.0, 1.0),
		"aim_fraction": rng.randf(),
		"intent": _intent(rng.randf()),
	}


## Which of the three intents this swing is taken with.
##
## `choose_power` reads `intent_fraction` as *how much of the available ceiling
## this swing is asking for*, and its meaningful values are the three named
## constants -- drive, control, off-speed. Handing it a raw uniform draw instead
## looks like randomness and is not: a uniform on 0-1 averages 0.5, which sits
## below `CONTROL_INTENT`, so the mean swing in the game was softer than a
## deliberately controlled ball. Measured on live rallies it produced a 9.8 m/s
## mean contact against a sport that spikes at 20-30, and marked 62% of swings
## "held back" -- a hitter who is always holding back is not holding back, they
## are just weak.
##
## The mix is weighted toward driving the ball because that is what a hitter does
## with a set they can attack. Choosing the tier from what the hitter reads open
## -- off-speed into a formed block, drive into a gap -- is the next step and
## belongs with the resolver's own read, not here.
static func _intent(roll: float) -> float:
	if roll < 0.62:
		return AttackPowerModel.DRIVE_INTENT
	if roll < 0.88:
		return AttackPowerModel.CONTROL_INTENT
	return AttackPowerModel.OFF_SPEED_INTENT


## The resolver's answer, in the terms the rally continues with.
##
## The geometric model does not produce a quality scalar and then ask whether the
## quality was high enough; it produces a landing point and reads the outcome off
## it. So the mapping runs the other way from the legacy path: the outcome is
## known first, and `quality` is derived from it for the event record and the
## flow model, which still speak in qualities.
##
##   in          the ball is down in the court and the defence plays it
##   net, out    the hitter missed -- a swing that never had to be judged an
##               error, because it simply did not land in
##   stuff       the block put it down
##   monster_block a charged, near-perfect block put it down
##   touch       hands slowed it; it stays alive and the rally continues
##   tool        off the outside hand and out: the hitter's point
##   block_crush through the hands: the hitter's point
##   high_hands  placed off the hands and out: the hitter's point
static func continuation(swing: Dictionary) -> Dictionary:
	if not bool(swing.get("available", false)):
		return {"resolved": false, "reason": str(swing.get("reason", "unavailable"))}
	var outcome := str(swing.get("outcome", "in"))
	var resolution: Dictionary = swing.get("resolution", {})
	var terminal := ""
	var hitter_point := false
	var attack_missed := false
	match outcome:
		"in":
			pass
		"net", "out":
			terminal = "attack_error"
			attack_missed = true
		"stuff", "monster_block":
			terminal = "blocked"
		"touch":
			pass
		"tool", "block_crush", "high_hands":
			terminal = "kill"
			hitter_point = true
		_:
			pass
	return {
		"resolved": true,
		"outcome": outcome,
		"terminal_outcome": terminal,
		"is_terminal": terminal != "",
		"hitter_point": hitter_point,
		"attack_missed": attack_missed,
		"blocked": outcome in ["stuff", "monster_block", "touch", "tool"],
		"landing": Vector2(swing.get("landing", Vector2(0.5, 0.25))),
		"out_reason": str(resolution.get("out_reason", "")),
		"quality": quality_for(outcome, swing),
		"narrative": Dictionary(swing.get("narrative", {})),
	}


## A quality figure for an outcome the model did not produce one for.
##
## Nothing downstream needs this to decide anything -- the outcome is already
## decided -- but the event record, the flow model and the action vocabulary all
## read a quality, and a swing that resolved geometrically still has to report
## one. It is derived from how well the ball was struck rather than invented:
## a swing that reached its target at the speed it intended scores high whether
## or not a blocker happened to be standing there.
static func quality_for(outcome: String, swing: Dictionary) -> float:
	var delivered: Dictionary = swing.get("delivered", {})
	var power: Dictionary = swing.get("power", {})
	var intended := maxf(float(power.get("speed_mps", 1.0)), 0.001)
	var speed_fidelity := clampf(
		float(delivered.get("speed_mps", 0.0)) / intended, 0.0, 1.0
	)
	var aim_fidelity := clampf(
		1.0 - absf(float(delivered.get("bearing_error_degrees", 0.0))) / 12.0,
		0.0, 1.0,
	)
	var struck := clampf(speed_fidelity * 0.45 + aim_fidelity * 0.55, 0.0, 1.0)
	match outcome:
		"block_crush", "high_hands":
			return clampf(0.72 + struck * 0.28, 0.0, 1.0)
		"tool":
			return clampf(0.55 + struck * 0.30, 0.0, 1.0)
		"in":
			return clampf(0.30 + struck * 0.55, 0.0, 1.0)
		"touch":
			return clampf(0.22 + struck * 0.38, 0.0, 1.0)
		"stuff":
			return clampf(struck * 0.28, 0.0, 1.0)
	## Out or into the net. The swing still happened, and how cleanly it was
	## struck is still the difference between a ball that missed by a metre and
	## one that missed by a hand, but none of it landed in.
	return clampf(struck * 0.18, 0.0, 1.0)


## Where a blocker's hands are on the net, in normalised court x.
static func _blocker_net_x(
	blocker: VolleyballPlayer,
	fallback_positions: Dictionary,
	live_positions: Dictionary,
) -> float:
	if live_positions.has(blocker.id):
		return clampf(Vector2(live_positions[blocker.id]).x, 0.0, 1.0)
	if fallback_positions.has(blocker.id):
		return clampf(Vector2(fallback_positions[blocker.id]).x, 0.0, 1.0)
	return 0.5
