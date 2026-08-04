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
static func block_wall(
	formation: Dictionary,
	team: Resource,
	live_positions: Dictionary = {},
) -> Array:
	var wall: Array = []
	for role in ["primary", "assist"]:
		var blocker := formation.get(role) as VolleyballPlayer
		if blocker == null:
			continue
		var close := float(formation.get("%s_close" % role, 0.0))
		if close < WALL_JOIN_CLOSE:
			continue
		wall.append({
			"net_x": _blocker_net_x(blocker, team, live_positions),
			"reach_height_m": blocker.jumping_reach_cm(BLOCKER_REACH_EFFORT) / 100.0,
			"half_width_m": BLOCKER_HALF_WIDTH_METERS * clampf(close, 0.0, 1.0),
			"player_id": blocker.id,
			"close": close,
		})
	return wall


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
	var standing := hitter.standing_reach_cm() / 100.0
	var full := hitter.jumping_reach_cm() / 100.0
	var leap := maxf(full - standing, 0.0) * clampf(jump_multiplier, 0.0, 1.5)
	return maxf(standing + leap - CONTACT_BELOW_REACH_METERS, 0.0)


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
	var standing := server.standing_reach_cm() / 100.0
	var leap := maxf(server.jumping_reach_cm() / 100.0 - standing, 0.0)
	return maxf(standing + leap * clampf(effort, 0.0, 1.0)
		- CONTACT_BELOW_REACH_METERS, 0.0)


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
		"stuff":
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
		"blocked": outcome in ["stuff", "touch", "tool"],
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
	team: Resource,
	live_positions: Dictionary,
) -> float:
	if live_positions.has(blocker.id):
		return clampf(Vector2(live_positions[blocker.id]).x, 0.0, 1.0)
	if team != null and team.has_method("court_position"):
		return clampf(Vector2(team.court_position(blocker.id, "block")).x, 0.0, 1.0)
	return 0.5
