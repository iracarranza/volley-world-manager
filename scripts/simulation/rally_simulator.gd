class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const CoverageModel := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const DefensivePlanModel := preload("res://scripts/models/defensive_plan.gd")
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const ShadowReceptionSystemModel := preload("res://scripts/simulation/shadow_reception_system.gd")
const RallyShadowComparisonModel := preload("res://scripts/simulation/rally_shadow_comparison.gd")
const RallyRolloutPolicyModel := preload("res://scripts/simulation/rally_rollout_policy.gd")
const RallyFeatureFlagsModel := preload("res://scripts/simulation/rally_feature_flags.gd")
const GeometricAttackResolverModel := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const GeometricAttackPromotionModel := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)
const RallyStateBuilderModel := preload("res://scripts/simulation/rally_state_builder.gd")
const LiveReceptionIntegratorModel := preload(
	"res://scripts/simulation/live_reception_integrator.gd"
)
const LiveSetterIntegratorModel := preload(
	"res://scripts/simulation/live_setter_integrator.gd"
)
const ShadowAttackSystemModel := preload(
	"res://scripts/simulation/shadow_attack_system.gd"
)
const LiveAttackIntegratorModel := preload(
	"res://scripts/simulation/live_attack_integrator.gd"
)
const ApproachMechanicsModel := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)
const AttackCourseModelRef := preload(
	"res://scripts/simulation/attack_course_model.gd"
)
const ShadowBlockSystemModel := preload(
	"res://scripts/simulation/shadow_block_system.gd"
)
const LiveBlockIntegratorModel := preload(
	"res://scripts/simulation/live_block_integrator.gd"
)
const RallyMovementSystemModel := preload(
	"res://scripts/simulation/rally_movement_system.gd"
)
const SetterCapabilityModel := preload(
	"res://scripts/simulation/setter_capability_system.gd"
)
const AttemptJudgmentModel := preload(
	"res://scripts/simulation/attempt_judgment.gd"
)
const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")
const RallyKinematicsModel := preload(
	"res://scripts/simulation/rally_kinematics.gd"
)
## How many attack exchanges a rally may contain. Measured, and it is a backstop
## rather than a rule.
##
## Flagged in the constant audit on the guess that a cap of four sat at the median
## rally length and was therefore ending rallies that play should have ended. That
## guess was wrong. Over 200 rallies the swing distribution is:
##
##   swings per rally    0    1    2    3    5
##   rallies            40  123   26    9    2
##
## The cap binds in 1.0% of rallies -- two of two hundred -- which is what a
## runaway guard should look like.
##
## **What the same measurement does say is worse, and is not about this number.**
## The median rally contains *one* swing. 123 of 200 rallies end on the first
## attack and only 37 ever reach a second. A rally in this sport is a sequence of
## transitions; here it is almost always a single exchange, which means the floor
## defence essentially never keeps a ball alive. That is the same finding as a
## home kill rate of 0.83-0.91 per swing seen from the other side, and it is the
## floor defence that every geometric-attack flag comment already names as the
## blocker. Raising this constant would change none of it.
const MAX_EXCHANGES: int = 4

## `OPPONENT_SERVE`, `OPPONENT_BLOCK` and `OPPONENT_DEFENSE` were flat
## ratings standing in for the whole opponent side, from when that side was a
## simplified parallel implementation rather than a real roster. Nothing has
## read them since the opponent started being resolved through the same
## systems as the home team; three unexplained magic floats were all that
## remained of it.

## Fallbacks for a setter with no derived release profile. These are the
## midpoints of the bands `VolleyballPlayer.refresh_system_fit_profiles()`
## produces, so a profile-less setter behaves like an average one.
## Where the two blockers stand when a wall forms. A double block is two players
## shoulder to shoulder at the net, not two markers at one coordinate: playback
## had been placing each blocker at their own defensive court position, which for
## a block resolves both onto the attack lane and draws them stacked. Geometry is
## the resolver's to own, so the pair is recorded on the event.
## Centre-to-centre between the two blockers, as a fraction of court width --
## 0.855 m. Measured against the bodies that have to stand there: the widest torso
## in the game is a Tomato at 0.715 m, and the previous 0.085 left it 5 cm of
## clearance from its neighbour. A sealed double block is shoulder to shoulder, not
## interpenetrating, and 14 cm reads as the former.
const BLOCK_SHOULDER_OFFSET: float = 0.095
const BLOCK_NET_DEPTH: float = 0.032

## Lane a blocker covers with their arms without moving their feet.
const BLOCK_LATERAL_REACH_METERS: float = 0.45
## How much of the time between the pass and the set's release a blocker can
## actually use to move.
##
## Closing used to begin at set contact, giving a high ball 0.69 s and a quick
## set 0.23 s -- and reaction plus the block jump consume about 0.49 s of
## either, so blockers had roughly 0.2 m of footwork at any tempo and could not
## cover one metre of net. A lane 0.9 m from the nearest blocker sat at the
## block-quality clamp floor. Real blockers read the pass and the setter's body
## and are moving well before the ball leaves the hands.
##
## Not all of that window is usable: the set's direction is not certain until it
## is released, and a blocker who commits early to the wrong lane is worse off
## than one who waited. That uncertainty is what `read_quality` models, so this
## is the share a blocker spends moving rather than waiting.
const BLOCK_PRESET_SHARE_MISREAD: float = 0.26
const BLOCK_PRESET_SHARE_READ: float = 0.72

## Loading and leaving the ground. A blocker still shuffling when the ball
## arrives has not blocked it, so this comes off the end of the closing window.
const BLOCK_PLANT_SECONDS: float = 0.26
## How late a blocker must be for the lane to be completely open.
const BLOCK_CLOSE_FAILURE_SECONDS: float = 0.45
## What a completely beaten blocker still contributes -- a hand in the air near
## the ball, not a wall. Zero would say a late blocker is not on the court.
const BLOCK_UNCLOSED_SHARE: float = 0.18

## One blocker against a hitter with the whole court is not most of a wall. At
## 0.78 a solo block outscored a typical swing, so the engine stuffed 28% of
## attacks and produced fifteen kills in three hundred and fifty swings.
const BLOCK_SOLO_SHARE: float = 0.62
## How much of what the primary left open a sealed assist covers.
const BLOCK_ASSIST_SHARE: float = 0.34

## How much a formed block takes off the swing hit into it. The primary carries
## most of it; a sealed assist adds the rest of the wall.
## Deliberately modest, because the block gets two bites: it lowers the swing
## here and then contests it. At 0.20/0.08 -- values set while the block was
## still saturated and therefore constant -- the two compounded into a 0.386
## stuff rate once closes actually varied.
const BLOCK_PRIMARY_PRESSURE: float = 0.06
const BLOCK_ASSIST_PRESSURE: float = 0.03

## What a hitter brings to a swing, as a fraction of an ideal one. These sum to
## 1.0 on purpose: a quality that is a fraction of an ideal can be compared with
## a block quality that is also a fraction of an ideal, and a margin of 0.06
## between them means something.
const ATTACK_ACCURACY_WEIGHT: float = 0.50
const ATTACK_POWER_WEIGHT: float = 0.32
const ATTACK_DECISION_WEIGHT: float = 0.18

## Generated competitive hitters sit below an ideal 0.78 capability. Passing their
## raw rating through at full slope made a five-point ability gap produce a
## 2.6x swing in mean attack quality and moved match error rates from 0.00 to
## 0.60. Compressing around the population centre preserves ordering and elite
## separation without turning ordinary roster variance into a hard error cliff.
const ATTACK_CAPABILITY_PIVOT: float = 0.78
const ATTACK_CAPABILITY_GAIN: float = 0.50

## How much of the swing each dimension of the opportunity can take away. They
## multiply rather than add, because a swing is only as good as the worst thing
## about it.
const SET_OPPORTUNITY_WEIGHT: float = 0.40
const APPROACH_OPPORTUNITY_WEIGHT: float = 0.26
const TIMING_OPPORTUNITY_WEIGHT: float = 0.45

## Arriving this far behind the ball costs the whole timing dimension.
const LATE_ARRIVAL_SECONDS: float = 0.60

## Execution spread that is not attributable to anything modelled.
const ATTACK_EXECUTION_NOISE: float = 0.10

## Midpoint of the attack-error response. A hard comparison here turned normal
## roster variance into a cliff: strong lineups were error-free while lineups
## five ability points lower missed almost half their swings. Quality now moves
## a bounded probability around this midpoint instead.
const ATTACK_ERROR_THRESHOLD: float = 0.24
const ATTACK_ERROR_FLOOR: float = 0.10
const ATTACK_ERROR_CEILING: float = 0.30
const ATTACK_ERROR_RESPONSE_WIDTH: float = 0.12

## How decisively the block has to beat the swing for each outcome.
##
## Re-derived twice. At -0.06 and -0.24 the block touched 82% of all attacks and
## rallies never ended. Tightening to positive margins fixed that against a
## block that could not move; once closing began at the pass rather than at set
## contact, blockers reached lanes they never used to and the touch rate went
## back to 0.61 on the same numbers. A margin is a statement about how much the
## block has to win by, and it only means something against a given amount of
## block -- change what the wall can reach and it has to be restated.
## Where a block's contest margin has to land for each outcome, set from the
## distribution of that margin rather than from taste.
##
## `contest - attack_quality` is one number and these are three thresholds on it,
## so the only way to know what share each outcome gets is to know where the
## distribution sits. Measured over 1,013 home blocks against an opponent that
## swings: p10 -0.176, p25 -0.052, p50 0.077, p75 0.237, p90 0.363.
##
## The old trio -- 0.10, 0.18, 0.22 -- packed all three bands into a 0.12-wide
## window near the middle of a spread half a unit across, and the consequence was
## not subtle: **the `funnel` outcome fired zero times under every intent**, because
## its band was 0.08 wide and the touch band above it took everything. A three-way
## cascade with a dead middle rung is a two-way cascade, and the block-intent dials
## that shift that rung were shifting nothing.
##
## Set to the shares Gate D asks for: a stuff at roughly the top eighth of the
## distribution, and touch plus funnel taking about another thirty percent, so the
## block is involved in 40% of attacks and terminates 12% of them.
##
## **These are the legacy resolver's, and nothing reads them while the geometric
## attack is open.** `_geometric_promotion` overwrites `block_outcome` whenever
## `ENABLE_GEOMETRIC_ATTACK` is true, so on the production path the outcome comes
## from `AttackResolutionModel._block_contact` -- a height and edge comparison
## against a real wall -- and these three thresholds decide nothing. Changing them
## produced byte-identical rallies, which is how that was discovered.
##
## They are kept rather than deleted because `_contest_block` is a live fallback:
## turn the geometric flag off and it resolves every block again. What must not
## happen is what already had -- a calibration tuning them and reporting the
## result as the game's block mix. `ExecutionScaleCalibration.contest_shares`
## did exactly that, had zero callers, and has been deleted.
const BLOCK_STUFF_MARGIN: float = 0.34
const BLOCK_TOUCH_MARGIN: float = 0.237
const BLOCK_FUNNEL_MARGIN: float = 0.12

## A serve is missed when the server asks more of it than their control
## supports. `SERVE_ERROR_CEILING` is the miss rate of a server with no control
## at all asking everything of the ball.
const SERVE_ERROR_CEILING: float = 0.52
const SERVE_BASE_DEMAND: float = 0.42
const SERVE_RISK_DEMAND: float = 0.58

## How much of a transition set the arriving ball can take away, and how much
## of a bad ball a commanding setter buys back. Recovery is what makes a
## setter's attributes matter most exactly when the ball is worst.
const TRANSITION_BALL_WEIGHT: float = 0.62
const TRANSITION_BALL_RECOVERY: float = 0.40

## What a ball off the block is worth relative to a clean one, at a fully formed
## wall. Without this a block touch recycled at full quality and a blocker was
## worth nothing unless they stuffed it outright.
const BLOCK_DEFLECTION_CARRY: float = 0.55

## How the opponent's swing is priced against arrival.
##
## A pin hitter transitioning two or three metres is routinely a fraction of a
## second behind the set and swings anyway -- that is ordinary volleyball, and
## penalising it collapses the offence onto the middles, who start at the net
## and are never late. So the first `LATE_GRACE` seconds are free. Past that the
## penalty ramps hard over `LATE_RAMP` to a weight that deliberately exceeds the
## 0.42 attack-power term, because a hitter six metres away must lose to a
## weaker hitter who is actually there.
const OPPONENT_HITTER_LATE_GRACE: float = 0.35
const OPPONENT_HITTER_LATE_RAMP: float = 0.50
const OPPONENT_HITTER_LATENESS_WEIGHT: float = 0.90
## Bisection steps used to walk an unreachable contact point back to a reachable
## one. Six halvings resolve the segment to under two percent of its length,
## which is a couple of centimetres of court.
const REACHABLE_CONTACT_BISECTIONS: int = 6

## How much a swing taken off the net takes away from the block contesting it.
## Full relief at three metres back, which is the attack line: a back-row swing
## crosses higher and later than a ball struck at the tape, and the blockers are
## pressed to the net rather than out where the ball is.
const BLOCK_DEPTH_RELIEF_FULL_METERS: float = 3.0
const BLOCK_DEPTH_RELIEF_WEIGHT: float = 0.10

## How a ball off the block flies. The angle is a squirt off the hands rather
## than a struck ball, so it hangs: four metres takes about 0.7s, which is what
## makes chasing one legible rather than teleportation. A stuff is the exception
## -- driven down, over in a fifth of a second, and the rally ends there.
const BLOCK_DEFLECTION_LAUNCH_ANGLE_DEGREES: float = 30.0
const BLOCK_DEFLECTION_MIN_SECONDS: float = 0.22
const BLOCK_STUFF_FLIGHT_SECONDS: float = 0.20

## Contact depth for an opponent swing, by row. The front-row value sits at the
## net; the back-row value sits behind their attack line at y = 1/3, because a
## back-row player taking off at the net is a violation, not a tempo choice.
const OPPONENT_FRONT_ROW_CONTACT_Y: float = 0.48
const OPPONENT_BACK_ROW_CONTACT_Y: float = 0.30

## How much of a contact's spread is temperament rather than technique, and what
## share of the base spread a perfectly reliable player still carries. The floor
## is not zero: nobody executes identically twice.
const CONSISTENCY_COMPOSURE_WEIGHT: float = 0.40
const CONSISTENCY_FLOOR_SHARE: float = 0.30

## Converting the old uniform execution error to a normal one without changing
## how much ordinary contacts scatter: a uniform on [-s, s] has standard
## deviation s/sqrt(3), so a normal with that deviation matches it in the body
## of the distribution and differs only in the tails. The limit is far enough
## out that a contest is never flatly impossible -- 3.5 deviations is about a
## 2e-4 residual -- while still ruling out a freak draw putting a set in the
## stands.
const UNIFORM_TO_NORMAL_DEVIATION: float = 0.5773502691896258
const EXECUTION_ERROR_DEVIATION_LIMIT: float = 3.5

## Where an own-side delivery actually arrives, in metres of standard deviation
## from where it was aimed.
##
## Own-side contacts do not need trajectory simulation -- there is no line to be
## on the wrong side of and no block to intersect -- but they do have to emit a
## *position*, because the next contact's geometry reads it. Until now a set
## landed on `CourtConstants.lane_target(lane)`, a fixed table entry, so a 0.95
## set and a 0.35 set delivered the ball to the identical point and set quality
## had no geometric consequence whatsoever.
##
## Values are the ones specified in
## docs/textbook/EVENT_CALCULATION_TAXONOMY.md, which designed this before it
## was built. Stated in metres and converted per axis at the point of use,
## because the court is 9 m across and 18 m deep -- one normalized number would
## scatter a ball twice as far sideways as long.
const SET_DELIVERY_STDEV_WORST_M: float = 0.40
const SET_DELIVERY_STDEV_BEST_M: float = 0.08
const PASS_DELIVERY_STDEV_WORST_M: float = 0.50
const PASS_DELIVERY_STDEV_BEST_M: float = 0.10

## How far a delivery is allowed to stray before it stops being a delivery.
##
## A set nominally lands at y = 0.53, which is 0.54 m from the net, and the
## worst-case spread is 0.40 m -- so an unclamped tail can put the ball through
## the net onto the opponent's side. That is a real volleyball event (the
## overpass), and emitting a position rather than a table entry is exactly what
## makes it *detectable*, but there is no rally branch that plays one out yet.
## Until there is, the delivery is held on its own side rather than silently
## teleporting the rally.
const HOME_SET_DELIVERY_MIN_Y: float = 0.51
const HOME_SET_DELIVERY_MAX_Y: float = 0.80
const OPPONENT_PASS_DELIVERY_MIN_Y: float = 0.20
const OPPONENT_PASS_DELIVERY_MAX_Y: float = 0.49

## What a defender brings to a dig, as a fraction of an ideal one. Sums to 1.0
## so the result can be compared with an attack quality that is also a fraction
## of an ideal, which is the whole point of a contest between them.
const DIG_RECEPTION_WEIGHT: float = 0.34
const DIG_ANTICIPATION_WEIGHT: float = 0.30
const DIG_CONTROL_WEIGHT: float = 0.22
const DIG_LATERAL_WEIGHT: float = 0.14

## How much of the dig each dimension of the opportunity can take away. Getting
## there is most of it: a defender who is not at the ball has no technique to
## apply, which is why this multiplies rather than adds.
const DIG_TIMING_WEIGHT: float = 0.75
const DIG_POSTURE_WEIGHT: float = 0.55

## Arriving this far behind the ball costs the whole timing dimension. Shorter
## than the hitter's window because the ball is already travelling at attack
## speed when a defender has to move to it.
const DIG_REACH_MARGIN_METERS: float = 0.45

## Where a pass stops supporting a quicker call and starts forcing a slower one.
## Asserted rather than swept -- see `_tempo_call`.
const OPPONENT_QUICK_CALL_PASS: float = 0.68
const OPPONENT_SLOW_CALL_PASS: float = 0.38

## How much the attacker is favoured when swing and dig are equally good. A
## clean swing beats a set defence more often than not, so an even contest is
## not a coin flip.
## Measured, not assumed: with the block re-derived, 416 swings reached the
## floor and 82% of them came up. A clean swing beating a set defence should not
## be the exception, and at 0.09 an even contest was close to a coin flip on a
## scale where the two sides sit at parity.
const DIG_ATTACKER_ADVANTAGE: float = 0.20

## One defender is not a whole defence. The attacker picks where the ball goes;
## a defender covers the zone they were assigned. Without this the dig scale
## centred above the swing scale -- exactly the mismatch a solo block had at
## 0.78 -- and 470 swings produced 42 kills against 63 errors and 44 stuffs.
const DIG_SOLO_SHARE: float = 0.62
const DIG_EXECUTION_NOISE: float = 0.10

## How hard a swing attempted outside the approach's capability bites. Mirrors
## `SetterCapabilitySystem.OVERREACH_SEVERITY` at the second contact: a hitter a
## long way past what their run-up gave them does not merely hit worse, they put
## the ball out.
const ATTACK_OVERREACH_SEVERITY: float = 1.60

## Sum of the opponent serve-quality weights, used to normalise them.
const OPPONENT_SERVE_WEIGHT_TOTAL: float = 0.72

## Nominal pass-to-setter flight, for the opponent side where the real value is
## not separately modelled. The home paths pass their measured window instead.
## The tempo a ball dug out of defence is set at, before the setter's own read
## adjusts it. High, because a scramble ball is high -- and the same figure on
## both sides of the net, which is the point: this used to be a literal 3 in
## `_fallback_assignment` on one side and a serve-receive tendency on the other.
const TRANSITION_TEMPO_BASE: int = 3

## FLAGGED. These four bound every setter's tempo and are now load-bearing:
## `ENABLE_OPPONENT_APPROACH_WINDOW` spends `DEFAULT_SET_RELEASE_SECONDS +
## DEFAULT_SECOND_CONTACT_SECONDS` as the pass-to-release window that lets a
## hitter walk to their mark, so a fix rests on two numbers nothing derived.
##
## They are defensible *as defaults* -- a mean pass-to-release time is a real
## quantity and `SYSTEM_FIT_SET_RELEASE` already varies it per setter. What is
## missing is not a derivation for the mean but a consequence for the tail: a
## setter working far outside their band is modelled as merely *inaccurate*, and
## that is not what happens. A ball held too long is a lift, and a poor or
## out-of-position setter -- a libero forced to set, a young middle taking the
## second ball -- commits ball-handling faults at a rate the sport notices.
## `MINIMUM_SET_RELEASE_SECONDS` and `MAXIMUM_SET_RELEASE_SECONDS` currently clamp
## silently where they should sometimes produce a fault instead.
##
## So the work here is a lift/double-contact outcome driven by `setting_technique`
## against the release the situation demands, not a better constant.
const DEFAULT_SECOND_CONTACT_SECONDS: float = 0.68

const DEFAULT_SET_RELEASE_SECONDS: float = 0.42
const DEFAULT_SET_RELEASE_TOLERANCE: float = 0.105
const MINIMUM_SET_RELEASE_SECONDS: float = 0.15
const MAXIMUM_SET_RELEASE_SECONDS: float = 0.75

var rng := RandomNumberGenerator.new()
## Gate E's own stream. See `_geometric_swing` -- the geometric attack is
## evaluated on every swing whether or not it is promoted, so it must not draw
## from `rng` or an unpromoted shadow would change every rally in the game.
var geometric_rng := RandomNumberGenerator.new()
var geometric_swing_index: int = 0
## Serve records are held here rather than written straight onto the result,
## because `_build_rally_analysis` replaces `result.analysis` wholesale and a
## serve is resolved long before that runs.
var geometric_serves: Dictionary = {}
## Whether this rally was asked to open development-only promotions. It is a
## parameter of `resolve()` and the geometric attack is decided in three
## different functions, so it is held for the rally rather than threaded
## through every continuation signature.
var geometric_development_open: bool = false
## The opponent's defensive plan for this rally, built on first use.
var opponent_plan: Resource = null
var rally_clock: float = 0.0
var live_positions: Dictionary = {}
var opponent_live_positions: Dictionary = {}
## What each player is carrying, alongside where they are.
##
## `live_positions` has always been the resolver's authoritative state and it
## holds positions only, so a player who had just sprinted across the court
## existed at rest on the next contact. The continuous movement work unified the
## *formula* -- `_movement_time` asks the same model reachability does -- but not
## the state: `project_toward` is called by every shadow and calibration system
## and by the resolver never. These two dictionaries are the missing half.
var live_velocities: Dictionary = {}
var opponent_live_velocities: Dictionary = {}
## Who is still getting up, on either side of the net. Keyed by player id, and
## holding the state, the moment they are a defender again, and how long the debt
## was -- so a dig taken halfway through a recovery is priced on how much of it is
## left rather than on a flag.
var player_recovery: Dictionary = {}
## The last dig's control figure and the force it faced, so the DEFENSE event can
## report the same two inputs the reception does. Held rather than returned
## because `_dig_recovery` answers one question and three call sites ask it.
var last_dig_control: float = 0.5
var last_dig_force: float = 0.0
var last_dig_speed: float = 0.0
## A dig's posture was computed and then thrown away, so every DEFENSE event
## reported the default and the census read digs as 100% planted -- a measurement
## of the stamp, not of the engine.
var last_dig_posture: String = "planted"
## What the rally's recoveries cost in condition, to be charged by the caller.
var recovery_fatigue_cost: Dictionary = {}
var shadow_reception_trace: RallyTrace
var home_principles: Resource
var opponent_principles: Resource
var identity_effects: Dictionary = {}
var rally_seed: int = 0


func resolve(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	active_play: OffensivePlay,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int,
	development_continuous_reception: bool = false,
	team_principles: Resource = null,
) -> Resource:
	rng.seed = seed_value
	rally_seed = seed_value
	geometric_swing_index = 0
	geometric_serves = {}
	geometric_development_open = development_continuous_reception
	opponent_plan = null
	home_principles = team_principles if team_principles != null \
		else TeamPrinciplesModel.for_identity("Balanced")
	## The other bench has opinions too. Every read of a principle on this side
	## returned a hardcoded 0.5, so a home coach choosing Physical (decisiveness
	## 0.86) or Defensive (0.18) was choosing an identity the opponent
	## structurally could not have -- invisible while both sat at Balanced's
	## 0.50, and a permanent one-sided advantage the moment anybody picked
	## anything else.
	opponent_principles = opponent_team.principles() \
		if opponent_team != null and opponent_team.has_method("principles") \
		else TeamPrinciplesModel.for_identity("Balanced")
	identity_effects = {
		"serve_risk": {},
		"attack_selection": {},
		"confidence_volatility": 1.0 + (
			float(home_principles.emotional_expression) - 0.5
		) * 0.6,
	}
	rally_clock = 0.0
	shadow_reception_trace = null
	## Nobody starts a rally on the floor.
	player_recovery = {}
	recovery_fatigue_cost = {}
	live_positions = _initial_home_positions(lineup, defensive_plan, not home_serving)
	## Everyone starts the rally genuinely at rest -- this is the one moment the
	## old assumption was true.
	live_velocities = {}
	opponent_live_velocities = {}
	opponent_live_positions = _initial_opponent_positions(opponent_team, home_serving)
	var result: Resource = RallyResultModel.new()
	result.initial_home_positions = live_positions.duplicate(true)
	result.initial_opponent_positions = opponent_live_positions.duplicate(true)
	result.player_handedness = _playback_handedness(players, opponent_team)
	result.player_physical_profiles = _playback_physical_profiles(players, opponent_team)
	result.active_play_name = active_play.play_name \
		if active_play != null else "Default T3 Outside"
	if home_serving:
		return _resolve_home_serve(
			result, players, lineup, opponent_team, defensive_plan
		)
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	var opponent_server := opponent_team.player_by_id(
		opponent_lineup.player_at_slot(1) if opponent_lineup != null else -1
	) as VolleyballPlayer
	if opponent_server == null:
		opponent_server = opponent_team.best_server() as VolleyballPlayer
	var server_name := opponent_server.display_name
	var setter := _player_by_id(players, lineup.active_setter_id())
	## Weights are relative importance and are normalised by their own total, so
	## this is a genuine 0-1 quality rather than one capped at the coefficient
	## sum. They previously added to 0.72, which meant an opponent server with
	## every rating at 100 produced 0.72 -- and since reception subtracts
	## `serve_quality * 0.48`, the most dangerous serve in the game could apply
	## only 0.35 of pressure. The home formula already spans the full range
	## because its tactical risk term makes up the remainder.
	var opponent_serve_weighted := _power_rating(opponent_server, "serve_power") * 0.28 \
		+ _rating(opponent_server, "serve_technique") * 0.13 \
		+ _rating(opponent_server, "serve_placement") * 0.07 \
		+ _rating(opponent_server, "serve_consistency") * 0.12 \
		+ _rating(opponent_server, "serve_aggression") * 0.04 \
		+ _serve_style_proficiency(opponent_server) * 0.08
	var serve_quality := clampf(
		opponent_serve_weighted / OPPONENT_SERVE_WEIGHT_TOTAL
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
	var opponent_risk := _rating(opponent_server, "serve_aggression")
	var opponent_serve_base: Vector2 = opponent_team.court_position(
		opponent_server.id, "defense"
	)
	## Behind the baseline at the server's own lane, not at a literal 0.80.
	## `_initial_opponent_positions` places them from `court_position`, so a
	## hardcoded launch x left the ball a fifth of a metre off the body that struck
	## it -- small, but exactly the kind of gap the eye reads as the ball not being
	## hit by anybody.
	var opponent_serve_origin := CourtConstants.serve_origin(
		opponent_serve_base.x, false
	)
	var serve_error_chance := _serve_error_chance(opponent_server, opponent_risk)
	var serve_error := rng.randf() < serve_error_chance
	var intended_target := str(opponent_team.tendencies.get("serve_target", "Zone 5"))
	var serve_landing := _serve_landing_point(
		intended_target, opponent_server, players, lineup, true
	)
	## Gate E: the same serve through the shared ballistics, in shadow.
	_geometric_serve_record(
		"geometric_serve_opponent", opponent_server,
		opponent_serve_origin, serve_landing, false, opponent_risk,
	)
	## Recorded against the intent above, moved below: the shadow resolver aims
	## where the server aimed and reaches its own verdict, while the official
	## ball has to go where the official verdict already says it went.
	if serve_error:
		serve_landing = _errant_serve_landing(serve_landing, serve_quality, true)
	var serve_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_serve_origin, serve_landing),
		_serve_launch_angle_degrees(opponent_server, serve_quality),
	)
	var serve_time := float(serve_arc.duration_seconds)
	var serve_trajectory := _ball_trajectory(
		"serve", opponent_serve_origin, serve_landing, serve_time,
		float(serve_arc.apex_height_meters),
	)
	## Where this server belongs once the ball is gone: their own defensive spot,
	## the same one every other opponent gets from `court_position`.
	_add_event(result, RallyEventModel.EventType.SERVE, opponent_server.id, server_name,
		opponent_serve_origin, serve_landing, not serve_error, serve_quality,
		"%s serve" % opponent_server.primary_serve_style if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.", {
			"side": "opponent", "target": intended_target,
			"server_id": opponent_server.id, "server_slot": 1,
			"serve_style": opponent_server.primary_serve_style,
			"flight_time": serve_time,
			"event_time": 0.0, "contact_time": serve_time,
			## Struck from behind the baseline, then onto the court.
			##
			## A server is off the court when they contact the ball and back in it
			## before the return arrives -- that walk-in is a real part of the phase
			## and playback had no way to draw it, because the server's position was
			## never behind the line to begin with. Stating both ends here lets the
			## journey be drawn over the serve's own flight.
			"movement_start": opponent_serve_origin,
			"movement_target": opponent_serve_base,
			"outgoing_trajectory": serve_trajectory,
		})
	## And the resolver reasons from the court, not the service zone, for every
	## contact after this one.
	opponent_live_positions[opponent_server.id] = opponent_serve_base
	rally_clock = serve_time

	if serve_error:
		return _finish_serve_error(result, server_name)

	var reception_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		defensive_plan.zones_for(DefensiveZoneModel.ZoneType.SERVE_RECEIVE),
		serve_landing, serve_time, "reception",
	)
	var receiver := reception_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = _nearest_reception_player(players, lineup, defensive_plan, serve_landing)
	var receiver_zone: Resource = defensive_plan.zone_for(
		receiver.id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	) if defensive_plan != null and receiver != null else null
	shadow_reception_trace = ShadowReceptionSystemModel.evaluate(
		players, lineup, defensive_plan, opponent_team,
		opponent_server, opponent_server.primary_serve_style,
		serve_quality, serve_trajectory,
		receiver.id if receiver != null else -1,
		seed_value,
	)
	var shadow_summary: Dictionary = shadow_reception_trace.summary
	shadow_summary["rollout_entries"] = shadow_reception_trace.entries.duplicate(true)
	var rollout_requested := development_continuous_reception \
		and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE
	var reception_rollout := RallyRolloutPolicyModel.select_reception_source(
		result.events, shadow_summary, lineup, rollout_requested
	)
	var selected_live_reception: Dictionary = reception_rollout.get(
		"selected_reception", {}
	)
	var live_reception_integration: Dictionary = {}
	var live_state: RallyState = null
	if str(reception_rollout.get("selected_source", "official")) \
			== "continuous_reception":
		live_state = RallyStateBuilderModel.build(
			players, lineup, defensive_plan, opponent_team,
			active_play, false, seed_value
		)
		live_reception_integration = LiveReceptionIntegratorModel.apply(
			live_state, shadow_summary, selected_live_reception
		)
		if not bool(live_reception_integration.get("applied", false)):
			reception_rollout = RallyRolloutPolicyModel.select_reception_source(
				result.events, shadow_summary, lineup, false
			)
			selected_live_reception = {}
		else:
			shadow_summary["live_reception_integration"] = \
				live_reception_integration
			var canonical_serve_duration := maxf(
				float(shadow_summary.get("true_arrival_time", serve_time))
					- float(shadow_summary.get("flight_start_time", 0.0)),
				0.01,
			)
			var serve_event := result.events[0] as RallyEvent
			if serve_event != null:
				serve_event.metadata["flight_time"] = canonical_serve_duration
				serve_event.metadata["contact_time"] = float(shadow_summary.get(
					"true_arrival_time", canonical_serve_duration
				))
				serve_event.metadata["outgoing_trajectory"] = _ball_trajectory(
					"continuous_serve", serve_event.start_position,
					serve_event.end_position, canonical_serve_duration, 0.45,
					float(shadow_summary.get("flight_start_time", 0.0)),
				)
				serve_event.metadata["continuous_reception_timing"] = true
	var rollout_evidence := reception_rollout.duplicate(true)
	rollout_evidence.erase("selected_events")
	rollout_evidence.erase("selected_reception")
	shadow_summary["reception_rollout"] = rollout_evidence
	shadow_summary.erase("rollout_entries")
	shadow_reception_trace.summary = shadow_summary
	var using_live_reception := not selected_live_reception.is_empty() \
		and bool(live_reception_integration.get("applied", false))
	if using_live_reception:
		var live_receiver_id := int(selected_live_reception.get("actor_id", -1))
		var live_receiver := _player_by_id(players, live_receiver_id)
		if live_receiver != null:
			receiver = live_receiver
			receiver_arrived = true
	var arrival: Dictionary = reception_claim.get("arrival", {})
	if using_live_reception:
		## The promoted contact measures its margin in seconds, so it is
		## converted here rather than silently reinterpreted. This is the only
		## place the two systems' margins meet, and it is now the only place a
		## conversion happens.
		arrival = live_reception_integration.get("arrival", {}).duplicate()
		arrival["reach_margin_meters"] = CoverageModel.reach_margin_from_seconds(
			receiver, float(arrival.get("arrival_margin_seconds", 0.0))
		)
	var arrival_bonus := clampf(
		float(arrival.get("reach_margin_meters", -1.0)) * 0.07, -0.16, 0.12
	)
	var support_count := int(reception_claim.get("support_count", 0))
	var support_bonus := minf(float(support_count) * 0.025, 0.075)
	var seam_conflict := bool(reception_claim.get("seam_conflict", false))
	if using_live_reception:
		support_count = 0
		support_bonus = 0.0
		seam_conflict = false
	var seam_penalty := 0.09 if seam_conflict else 0.0
	## How much pace and movement the serve attempted, on top of how well it was
	## executed. `opponent_risk` was computed above for the error-chance roll and
	## went nowhere else -- the opponent's reception of a home serve prices this
	## exact concept (`serve_risk_pressure` there) and the home side's reception of
	## an opponent serve did not, so an aggressive serve that landed clean cost
	## the server nothing extra on this side of the net while it cost the
	## opponent's own receivers on theirs.
	var opponent_risk_pressure := (opponent_risk - 0.5) * 0.16 \
		if RallyFeatureFlagsModel.ENABLE_UNIFIED_RECEPTION_SKILL else 0.0
	var reception_base := _reception_skill(receiver) \
		if RallyFeatureFlagsModel.ENABLE_UNIFIED_RECEPTION_SKILL \
		else _rating(receiver, "reception") * 0.65 \
			+ _rating(receiver, "ball_control") * 0.20 \
			+ _rating(receiver, "composure") * 0.15
	## No flat bonus. A `+ 0.30` term used to sit at the end of this sum and it
	## almost exactly cancelled the best serve in the game: serve pressure is
	## `serve_quality * 0.48` and serve quality never exceeded 0.645, so the most
	## dangerous serve possible subtracted 0.31 while every reception was handed
	## 0.30 back unconditionally. Reception quality never fell below 0.387 against
	## an ace threshold of 0.18, which is why the engine produced no aces at all.
	result.reception_quality = clampf(reception_base - serve_quality * 0.48 \
		- opponent_risk_pressure \
		- CoverageModel.reception_body_penalty(receiver, arrival, serve_quality) \
		+ arrival_bonus + support_bonus - seam_penalty \
		+ rng.randf_range(-0.14, 0.14),
		0.0, 1.0)
	if using_live_reception:
		result.reception_quality = clampf(float(selected_live_reception.get(
			"quality", 0.0
		)), 0.0, 1.0)
	if not receiver_arrived:
		result.reception_quality = minf(result.reception_quality, 0.12)
	var reception_success: bool = receiver_arrived \
		and float(result.reception_quality) >= 0.18
	var receiver_start: Vector2 = live_positions.get(receiver.id, serve_landing)
	var receiver_move_time := _movement_time(
		receiver, receiver_start, serve_landing, "lateral"
	)
	if using_live_reception:
		var live_metadata: Dictionary = selected_live_reception.get("metadata", {})
		receiver_start = Vector2(live_metadata.get(
			"movement_start", receiver_start
		))
		receiver_move_time = float(live_metadata.get(
			"movement_duration", receiver_move_time
		))
		live_positions[receiver.id] = Vector2(live_reception_integration.get(
			"receiver_center_position", serve_landing
		))
		rally_clock = float(live_reception_integration.get(
			"simulation_time", rally_clock
		))
	var receiver_reach := _reached_point(
		receiver, receiver_start, serve_landing, serve_time, "lateral"
	)
	if not using_live_reception:
		## Short of the ball is where a beaten passer actually is, and it is what
		## the rest of the rally should reason from as well as what playback
		## should draw.
		live_positions[receiver.id] = receiver_reach
	var preferred_release: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id()) \
		if defensive_plan != null else Vector2(0.50, 0.60)
	var desired_pass_target: Vector2 = _desired_pass_target(preferred_release, serve_landing)
	var reception_pass := _reception_pass_result(
		receiver, receiver_start, serve_landing, desired_pass_target,
		opponent_serve_origin, serve_quality, arrival,
		float(result.reception_quality), 0.51, 0.98, serve_trajectory,
	)
	if using_live_reception:
		var selected_metadata: Dictionary = selected_live_reception.get(
			"metadata", {}
		)
		var selected_trajectory: Dictionary = selected_metadata.get(
			"outgoing_trajectory", {}
		)
		reception_pass = {
			"trajectory": selected_trajectory,
			"destination": Vector2(selected_trajectory.get(
				"end_position", desired_pass_target
			)),
			"body_alignment": 1.0,
			"platform_feasibility": float(arrival.get(
				"physical_feasibility", 1.0
			)),
			"contact_posture": str(Dictionary(shadow_summary.get(
				"shadow_decision", {}
			)).get("selected_action", "continuous reception")),
			## Carried across rather than recomputed. The live layer replaces
			## where the ball went, not what the contact did to the passer, and
			## its own posture vocabulary ("continuous reception") is not one of
			## the four the recovery bands are written against -- recomputing
			## from it would silently return everyone to their feet.
			"contact_recovery": str(reception_pass.contact_recovery),
		}
	var pass_trajectory: Dictionary = reception_pass.trajectory
	## Book the cost of the contact before the rally moves on, so the transition
	## below reads a receiver who is still getting up rather than one who is not.
	_note_recovery(receiver, str(reception_pass.contact_recovery), rally_clock)
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		serve_landing, Vector2(reception_pass.destination), reception_success,
		result.reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s %s" % [
			roundi(float(result.reception_quality) * 100.0),
			_quality_phrase(float(result.reception_quality)),
			_arrival_phrase(arrival, receiver_arrived, support_count) \
			+ (" Equal-priority passers hesitated at the seam." if seam_conflict else ""),
		], {"side": "home", "landing": serve_landing,
			"planner_zone_center": Vector2(receiver_zone.center) \
				if receiver_zone != null else receiver_start,
			"planner_zone_radius_meters": float(receiver_zone.radius_meters) \
				if receiver_zone != null else 0.0,
			"planner_zone_priority": int(receiver_zone.priority) \
				if receiver_zone != null else 0,
			"flight_time": serve_time, "arrival": arrival,
			"support_count": support_count, "seam_conflict": seam_conflict,
			"claim_margin": float(reception_claim.get("claim_margin", 1.0)),
			"movement_start": receiver_start,
			"movement_target": receiver_reach,
			"movement_duration": receiver_move_time,
			"event_time": _contact_time(serve_trajectory, rally_clock),
			"incoming_trajectory": serve_trajectory,
			"outgoing_trajectory": pass_trajectory,
			"body_alignment": reception_pass.body_alignment,
			"platform_feasibility": reception_pass.platform_feasibility,
			"contact_posture": reception_pass.contact_posture,
			"contact_recovery": reception_pass.contact_recovery,
			"contact_control": reception_pass.get("contact_control", 0.5),
			"movement_alignment": reception_pass.get("movement_alignment", 0.5),
			"incoming_force": reception_pass.get("incoming_force", 0.0),
			"incoming_speed_mps": reception_pass.get("incoming_speed_mps", 0.0),
			"desired_pass_target": desired_pass_target,
			"setter_release_target": preferred_release,
			"actual_pass_target": reception_pass.destination,
			"continuous_reception": using_live_reception,
			"rollout_source": str(reception_rollout.get(
				"selected_source", "official"
			)),
			"persistent_state_update": live_reception_integration.duplicate(true) \
				if using_live_reception else {}})
	if seam_conflict:
		result.key_factors.append(ExplanationText.factor("seam_conflict"))
	if not reception_success:
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		})
	var setter_rollout_requested := using_live_reception \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_SETTER_OVERRIDE
	var setter_rollout := RallyRolloutPolicyModel.select_setter_source(
		shadow_summary, lineup, setter_rollout_requested
	)
	var selected_live_setter: Dictionary = setter_rollout.get(
		"selected_setter", {}
	)
	var live_setter_integration: Dictionary = {}
	if str(setter_rollout.get("selected_source", "official")) \
			== "continuous_setter":
		live_setter_integration = LiveSetterIntegratorModel.apply(
			live_state, selected_live_setter
		)
		if not bool(live_setter_integration.get("applied", false)):
			setter_rollout = RallyRolloutPolicyModel.select_setter_source(
				shadow_summary, lineup, false
			)
			selected_live_setter = {}
		else:
			shadow_summary["live_setter_integration"] = \
				live_setter_integration
	var setter_rollout_evidence := setter_rollout.duplicate(true)
	setter_rollout_evidence.erase("selected_setter")
	shadow_summary["setter_rollout"] = setter_rollout_evidence
	shadow_reception_trace.summary = shadow_summary
	var using_live_setter := not selected_live_setter.is_empty() \
		and bool(live_setter_integration.get("applied", false))
	var attack_state := live_state
	if attack_state == null:
		attack_state = RallyStateBuilderModel.build(
			players, lineup, defensive_plan, opponent_team,
			active_play, false, seed_value
		)
	var shadow_attack := ShadowAttackSystemModel.evaluate(
		attack_state,
		Dictionary(shadow_summary.get("shadow_setter_response", {})),
		receiver.id, seed_value + 1700003,
	)
	shadow_summary["shadow_attack"] = shadow_attack
	## Gate 44: shadow-only attack-to-block observation. Always evaluated
	## alongside the shadow attack it observes; never promoted into an
	## official BLOCK event and never gated by a rollout flag.
	shadow_summary["shadow_block"] = ShadowBlockSystemModel.evaluate(
		attack_state, shadow_attack, seed_value + 1900007,
	)
	var attack_rollout_requested := using_live_setter \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_ATTACK_OVERRIDE
	var attack_rollout := RallyRolloutPolicyModel.select_attack_source(
		shadow_summary, lineup, attack_rollout_requested
	)
	var selected_live_attack: Dictionary = attack_rollout.get(
		"selected_attack", {}
	)
	var attack_rollout_evidence := attack_rollout.duplicate(true)
	attack_rollout_evidence.erase("selected_attack")
	shadow_summary["attack_rollout"] = attack_rollout_evidence
	shadow_reception_trace.summary = shadow_summary
	var using_live_attack := not selected_live_attack.is_empty() \
		and str(attack_rollout.get("selected_source", "official")) \
			== "continuous_attack"
	if using_live_attack and not bool(LiveAttackIntegratorModel.validate(
		live_state, selected_live_attack
	).get("valid", false)):
		attack_rollout = RallyRolloutPolicyModel.select_attack_source(
			shadow_summary, lineup, false
		)
		selected_live_attack = {}
		using_live_attack = false
		attack_rollout_evidence = attack_rollout.duplicate(true)
		attack_rollout_evidence.erase("selected_attack")
		shadow_summary["attack_rollout"] = attack_rollout_evidence
		shadow_reception_trace.summary = shadow_summary
	var live_attack_integration: Dictionary = {}
	var home_second_contact := _home_second_contact_candidates(players, lineup)
	setter = _second_contact_setter(
		home_second_contact.candidates, defensive_plan,
		lineup.active_setter_id(), receiver.id,
	)
	var set_contact: Vector2 = reception_pass.destination
	var second_contact_window := float(pass_trajectory.get("duration", 0.68))
	var setter_choice := _spatial_setter_choice(
		home_second_contact.candidates, home_second_contact.starts,
		defensive_plan, lineup.active_setter_id(), receiver.id, setter,
		set_contact, second_contact_window,
	)
	setter = setter_choice.player as VolleyballPlayer
	var setter_start: Vector2 = setter_choice.start
	var setter_move_time := float(setter_choice.travel_time)
	var setter_arrival_margin := second_contact_window - setter_move_time
	if using_live_setter:
		var promoted_setter := _player_by_id(
			players, int(selected_live_setter.get("actor_id", -1))
		)
		if promoted_setter != null:
			setter = promoted_setter
		set_contact = Vector2(selected_live_setter.get(
			"contact_position", set_contact
		))
		setter_start = Vector2(selected_live_setter.get(
			"movement_start", setter_start
		))
		setter_move_time = float(selected_live_setter.get(
			"movement_duration", setter_move_time
		))
		setter_arrival_margin = float(selected_live_setter.get(
			"arrival_margin", setter_arrival_margin
		))
		second_contact_window = maxf(
			float(selected_live_setter.get("contact_time", rally_clock))
				- rally_clock,
			0.0,
		)
	## Playback draws support movement one ball-flight leg at a time. Without
	## this hint the setter is drawn as a generic support player during the
	## serve's flight, then snapped onto their real transition line once they
	## become the set's actor -- visible as running backwards. Staging the
	## target on the reception event lets that leg carry them to setter_start
	## directly, so the following leg starts where it already expects.
	var reception_event_for_staging := result.events[-1] as RallyEvent
	if reception_event_for_staging != null:
		reception_event_for_staging.metadata["staged_next_actor_id"] = setter.id
		reception_event_for_staging.metadata["staged_next_position"] = setter_start
	var emergency_setter := setter != null and setter.id != lineup.active_setter_id()

	var follow_threshold := 0.22 + _rating(setter, "decision_making") * 0.35 \
		+ _rating(setter, "tactical_discipline") * 0.18
	result.play_was_followed = active_play != null \
		and result.reception_quality >= 0.42 \
		and rng.randf() < follow_threshold
	var assignment := _choose_assignment(
		active_play, result.play_was_followed, players, lineup, setter.id
	)
	if using_live_attack:
		assignment = _assignment_from_dict(Dictionary(selected_live_attack.get(
			"assignment", {}
		)))
		## A player may attack after receiving, but cannot make the second and
		## third contacts consecutively. Reject an otherwise valid live candidate
		## if emergency setting made its assigned hitter the last toucher.
		if assignment != null and assignment.player_id == setter.id:
			using_live_attack = false
			selected_live_attack = {}
			attack_rollout_evidence["selected_source"] = "official"
			attack_rollout_evidence["fallback_reason"] = \
				"selected hitter made second contact"
			shadow_summary["attack_rollout"] = attack_rollout_evidence
			shadow_reception_trace.summary = shadow_summary
			assignment = _choose_assignment(
				active_play, false, players, lineup, setter.id
			)
	var hitter := _player_by_id(players, assignment.player_id) if assignment != null else null
	if hitter == null or hitter.id == setter.id:
		hitter = _fallback_hitter(players, lineup, setter.id)
		assignment = _fallback_assignment(hitter, lineup)
	var base_tempo := int(assignment.tempo)
	assignment = _apply_identity_tempo(assignment, float(result.reception_quality))
	identity_effects["attack_selection"] = {
		"lane": assignment.lane,
		"base_tempo": base_tempo,
		"selected_tempo": assignment.tempo,
		"pin_focus": float(home_principles.pin_focus),
		"decisiveness": float(home_principles.decisiveness),
		"tempo_variation": float(home_principles.tempo_variation),
	}
	if active_play == null:
		result.key_factors.append(ExplanationText.factor("default_offense"))
	else:
		result.key_factors.append(ExplanationText.factor(
			"play_followed" if result.play_was_followed else "play_abandoned"
		))
	result.key_factors.append(ExplanationText.factor(
		"good_pass" if result.reception_quality >= 0.58 else "poor_pass"
	))
	_add_event(result, RallyEventModel.EventType.SET_DECISION, setter.id, setter.display_name,
		Vector2(0.50, 0.67), Vector2(0.50, 0.60), true,
		result.reception_quality,
		"Emergency setter decision" if emergency_setter else "Setter decision",
		"Stays with %s." % result.active_play_name if result.play_was_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id,
			## The decision is taken when the ball reaches the setter, and the
			## window runs from there.
			"event_time": _contact_time(pass_trajectory, rally_clock),
			"deadline": _contact_time(pass_trajectory, rally_clock)
				+ second_contact_window,
			"incoming_trajectory": pass_trajectory})

	## What this setter can do with the ball they are about to receive, and what
	## it costs them if they try for more. Nothing is forbidden here: a setter
	## may attempt a tempo beyond their command or reach for a ball above their
	## jump, and the penalty scales with how far outside they went.
	##
	## A setter who arrives early can take a short approach into a jump set,
	## which is exactly how they buy the height a sailing pass demands; one who
	## is still scrambling takes it flat-footed. Arrival margin is already the
	## measure of that, so it becomes the approach the jump gets.
	var setter_approach_quality := clampf(
		inverse_lerp(-0.25, 0.45, setter_arrival_margin), 0.0, 1.0
	)
	var setter_capability := SetterCapabilityModel.evaluate(
		setter, assignment.tempo, float(result.reception_quality),
		SetterCapabilityModel.pass_contact_height_meters(
			float(result.reception_quality), rng.randf()
		),
		setter_approach_quality,
	)
	var resolved_tempo := int(setter_capability.resolved_tempo)
	if bool(setter_capability.tempo_downgraded):
		assignment = _downgraded_assignment(assignment, resolved_tempo)
		result.key_factors.append(ExplanationText.factor("play_abandoned"))
	var tempo_demand := float(3 - resolved_tempo) * 0.055 \
		* lerpf(1.0, 0.65, _rating(setter, "tempo_control"))
	## The lane the setter is *aiming* at. `_set_geometry` reads this rather than
	## where the ball ends up, because difficulty is a property of the attempt.
	var intended_set_target := CourtConstants.lane_target(assignment.lane)
	var set_target := intended_set_target
	var set_geometry := _set_geometry(
		setter, setter_start, set_contact, intended_set_target, preferred_release
	)
	## One number carrying both the overreach and the reach cost, so the severity
	## of attempting something beyond a setter lives with the model that decides
	## what "beyond" means rather than being restated here.
	var capability_penalty := float(setter_capability.quality_penalty)
	var home_set_terms := _set_terms(
		setter, float(setter_capability.effective_pass_quality),
		tempo_demand, capability_penalty, setter_arrival_margin,
		float(set_geometry.difficulty),
		(Familiarity.execution_modifier(setter) - 1.0) * 0.16,
	)
	result.set_quality = clampf(
		float(home_set_terms.quality)
			+ _execution_error(setter, "set_accuracy", 0.12),
		0.0, 1.0,
	)
	## Resolved here rather than at the aim, because it needs the quality that
	## was only just computed -- and resolved *before* the arc, so the flight,
	## the SET event's end position, the hitter's contact point and the coverage
	## shape all describe the same ball.
	set_target = _delivered_point(
		intended_set_target, float(result.set_quality),
		SET_DELIVERY_STDEV_WORST_M, SET_DELIVERY_STDEV_BEST_M,
		HOME_SET_DELIVERY_MIN_Y, HOME_SET_DELIVERY_MAX_Y,
	)
	var set_angle := _set_launch_angle_degrees(
		setter, assignment.tempo, float(result.set_quality)
	)
	var set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_contact, set_target), set_angle
	)
	var set_flight_time: float = float(set_arc.duration_seconds)
	var release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var release_interval := _release_interval(release_profile, float(result.set_quality))
	## The instant the ball leaves the setter's hands. The set flight, the SET
	## event, and the hitter's approach window are all timed from this one value.
	var set_contact_time := rally_clock + second_contact_window + release_interval
	var set_trajectory := _ball_trajectory(
		"set", set_contact, set_target, set_flight_time,
		float(set_arc.apex_height_meters),
		set_contact_time
	)
	if using_live_attack:
		set_trajectory = Dictionary(selected_live_attack.get(
			"set_trajectory", set_trajectory
		)).duplicate(true)
		set_flight_time = float(set_trajectory.get(
			"duration", set_flight_time
		))
	if using_live_setter:
		live_setter_integration["outgoing_set_state"] = \
			LiveSetterIntegratorModel.launch_set(
				live_state, set_trajectory, setter.id
			)
		shadow_summary["live_setter_integration"] = \
			live_setter_integration.duplicate(true)
		shadow_reception_trace.summary = shadow_summary
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, result.set_quality >= 0.24,
		result.set_quality, "Set to %s" % assignment.lane,
		("T%d set for %s · %d%% accuracy." % [
			assignment.tempo, hitter.display_name,
			roundi(float(result.set_quality) * 100.0),
		]) + (" Emergency second-contact assignment activated." if emergency_setter else "")
		+ (" Arrived %.2fs before contact." % setter_arrival_margin
			if setter_arrival_margin >= 0.0 else
			" Arrived %.2fs late; set control was reduced." % absf(setter_arrival_margin)),
		{"side": "home", "set_path": "home_first_ball",
			"set_terms": home_set_terms, "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"arrival_margin": setter_arrival_margin,
			"deadline": set_contact_time,
			"event_time": set_contact_time,
			"release_interval": release_interval,
			## Where the setter aimed, alongside `end_position` which is where
			## the ball went. Separating the two is what makes set accuracy
			## measurable at all -- and readable in playback as intent versus
			## result rather than a single number.
			"intended_target": intended_set_target,
			## Why this setter could run this ball and not another one. Carried
			## on the event so the limit is readable in the rally record rather
			## than only visible as a lower quality number.
			"setter_capability": setter_capability.duplicate(true),
			"incoming_trajectory": pass_trajectory,
			"outgoing_trajectory": set_trajectory,
			"set_distance_meters": set_geometry.distance_meters,
			"set_angle_degrees": set_geometry.angle_degrees,
			"release_distance_meters": set_geometry.release_distance_meters,
			"body_orientation_fit": set_geometry.body_orientation_fit,
			"set_balance": set_geometry.set_balance,
			"set_stability": set_geometry.set_stability})
	var set_event := result.events[-1] as RallyEvent
	if using_live_setter and set_event != null:
		set_event.metadata["continuous_setter"] = true
		set_event.metadata["setter_action"] = str(selected_live_setter.get(
			"selected_action", ""
		))
		set_event.metadata["persistent_state_update"] = \
			live_setter_integration.duplicate(true)
	live_positions[setter.id] = Vector2(live_setter_integration.get(
		"setter_center_position", set_contact
	)) if using_live_setter else set_contact
	rally_clock = set_contact_time
	if assignment.tempo <= 1:
		result.key_factors.append(ExplanationText.factor("fast_tempo"))

	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	## Before preparation relocates it. The budget asks how far the hitter had to
	## come, and preparation's whole job is to move them -- reading `hitter_start`
	## afterwards would measure the distance they had left, not the distance they
	## faced.
	var hitter_standing_at := hitter_start
	var hitter_move_time := _movement_time(
		hitter, hitter_start, set_target, "transition"
	)
	var hitter_arrival_margin := float(set_flight_time) - hitter_move_time
	var approach_preparation: Dictionary = {}
	var resolved_approach: Dictionary = {}
	var prepared_actor: RallyPlayerState = null
	var hitter_entry_velocity := Vector2.ZERO
	if using_live_attack:
		hitter_start = Vector2(selected_live_attack.get(
			"source_position", hitter_start
		))
		hitter_move_time = maxf(float(selected_live_attack.get(
			"contact_time", rally_clock + set_flight_time
		)) - rally_clock, 0.0)
		hitter_arrival_margin = float(selected_live_attack.get(
			"arrival_margin", hitter_arrival_margin
		))
		approach_preparation = Dictionary(selected_live_attack.get(
			"transition_preparation", {}
		)).duplicate(true)
		resolved_approach = Dictionary(selected_live_attack.get(
			"resolved_approach", {}
		)).duplicate(true)
	else:
		var hitter_actor := attack_state.player_state(&"home", hitter.id) \
			if attack_state != null else null
		if hitter_actor != null:
			hitter_actor = hitter_actor.snapshot()
			## Seeded from what this hitter is actually carrying. The state
			## builder makes every actor at rest, so passing `hitter_actor.velocity`
			## back in was passing zero back in, and `prepare_for_attack` then
			## reported `prepared_velocity_mps` of zero for 91% of hitters.
			hitter_actor.apply_position(
				hitter_start, live_velocities.get(hitter.id, Vector2.ZERO)
			)
			var assignment_data := {
				"player_id": assignment.player_id,
				"lane": assignment.lane,
				"tempo": assignment.tempo,
				"priority": assignment.priority,
				"target": set_target,
			}
			approach_preparation = ApproachMechanicsModel.prepare_for_attack(
				attack_state, hitter_actor, assignment_data, receiver.id, rally_clock
			)
			prepared_actor = approach_preparation.get("actor") as RallyPlayerState
			approach_preparation.erase("actor")
			if prepared_actor != null:
				## Preparation relocates where this phase's run-up begins: the
				## travel to the staging mark already happened while the hitter
				## was released. The journey now drawn and timed is
				## staged mark -> approach start -> contact, so both the duration
				## and the arrival margin have to be recomputed. Leaving them
				## stale pairs a staged start with the unstaged duration, and
				## playback draws the short leg at the long leg's pace.
				hitter_start = prepared_actor.position
				hitter_entry_velocity = prepared_actor.velocity
				var hitter_leg := _travel(
					hitter, hitter_start, set_target, "transition",
					Vector2(approach_preparation.get(
						"approach_start_position",
						_approach_start_position(set_target, hitter_start, false)
					)),
					prepared_actor.velocity,
				)
				hitter_move_time = float(hitter_leg.seconds)
				live_velocities[hitter.id] = hitter_leg.exit_velocity
				hitter_arrival_margin = float(set_flight_time) - hitter_move_time
	set_target = _reachable_contact(
		hitter_start, set_target, hitter_move_time, float(set_flight_time)
	)
	hitter_arrival_margin = _clamped_arrival_margin(hitter_arrival_margin)
	_retarget_set_event(
		set_event, set_target, "set", float(set_flight_time),
		float(set_trajectory.get(
			"apex_rise_meters", float(set_arc.apex_height_meters)
		)),
		set_contact_time,
	)
	## Read the run-up against the contact that will actually be struck. The
	## takeoff evaluation used to run inside the preparation branch above,
	## against the target the set aimed at; a clamped contact would then have
	## been scored on a runway nobody ran.
	if prepared_actor != null:
		resolved_approach = ApproachMechanicsModel.evaluate_takeoff(
			prepared_actor, set_target, float(set_flight_time)
		)
	## Same staging leg as the setter's: the hitter should already be at
	## hitter_start (their staged approach mark) by the time this set's flight
	## finishes, not shown getting there and running the approach in one motion.
	var set_event_for_staging := result.events[-1] as RallyEvent
	if set_event_for_staging != null:
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
	var approach_fit := _approach_execution_fit(hitter, resolved_approach)
	## The block this swing is actually hit into. Attack quality had no opposing
	## term at all: it summed roughly 1.5 of positive coefficients against
	## penalties that rarely reached 0.2, so it never fell below 0.310 against an
	## error threshold of 0.29 and the engine produced no attack errors. Hitting
	## into a sealed block is the risk that was missing, and the block's
	## formation is knowable before the contest is settled.
	var opponent_block_formation := _form_opponent_block(
		opponent_team, set_target.x, assignment.tempo,
		float(result.set_quality), set_contact.x, set_flight_time,
		second_contact_window + release_interval,
	)
	## Scouting sharpens a block that has already formed, so it belongs to the
	## formation. It used to be applied *after* the contest, with its own stuff
	## margin, its own close threshold and its own recycle rule -- a second copy
	## of the contest, on one side of the net only. Folding it into the
	## formation's quality leaves exactly one place a block outcome is decided.
	var block_adaptation := _opponent_block_adaptation_bonus(
		opponent_team, assignment.lane, assignment.tempo
	)
	if block_adaptation > 0.0:
		opponent_block_formation["quality"] = clampf(
			float(opponent_block_formation.get("quality", 0.0)) + block_adaptation,
			0.05, 0.98,
		)
	opponent_block_formation["adaptation_bonus"] = block_adaptation
	var block_pressure := float(opponent_block_formation.get("primary_close", 0.0)) \
		* BLOCK_PRIMARY_PRESSURE \
		+ float(opponent_block_formation.get("assist_close", 0.0)) \
		* BLOCK_ASSIST_PRESSURE
	result.attack_quality = clampf(
		_attack_execution(
			hitter, float(result.set_quality), approach_fit, hitter_arrival_margin,
			tempo_demand, block_pressure,
			Familiarity.attack_geometry(hitter, assignment.lane)
			+ (Familiarity.execution_modifier(hitter) - 1.0) * 0.14,
		) + _execution_error(hitter, "attack_accuracy", ATTACK_EXECUTION_NOISE),
		0.0, 1.0,
	)
	var hit_type := _hit_type(assignment, hitter)
	var available_attacks := ApproachMechanicsModel.available_attack_families(
		hitter, resolved_approach, hitter_arrival_margin
	)
	hit_type = _identity_hit_type(
		hit_type, available_attacks, float(result.set_quality), hitter_arrival_margin
	)
	identity_effects["attack_selection"]["hit_type"] = hit_type
	## What this hitter meant to do, kept before the run-up can talk them out of it.
	##
	## Every swing in the game passes through two independent downgrades -- the
	## set-quality gate that picks the shot, and `backs_off` below, which rewrites
	## it again from the approach. Only the second one's *output* was ever
	## published, so a side that almost never spikes looked identical whether its
	## sets were bad or its run-ups were, and three separate investigations went
	## looking for the cause in the first gate.
	var intended_hit_type := hit_type
	## Capability is not permission at the third contact either.
	##
	## This used to silently rewrite a power swing into a roll shot whenever the
	## run-up had not unlocked power, so a hitter could never attempt more than
	## the approach gave them -- and because the substitute was always
	## executable, no swing in the game was ever bad enough to be an error. Now
	## the hitter's own judgment decides whether to take the safer ball, and
	## swinging anyway costs quality in proportion to how far outside their
	## approach the swing sits.
	var swing_deficit_terms := ApproachMechanicsModel.attack_family_deficit_terms(
		hitter, resolved_approach, hitter_arrival_margin,
		ApproachMechanicsModel.attack_family_for_hit_type(hit_type),
	)
	var swing_deficit := float(swing_deficit_terms.total)
	var swing_downgraded := AttemptJudgmentModel.backs_off(hitter, swing_deficit)
	if swing_downgraded:
		hit_type = "Controlled roll" if "controlled_roll" in available_attacks \
			else "Emergency tip"
		swing_deficit = ApproachMechanicsModel.attack_family_deficit(
			hitter, resolved_approach, hitter_arrival_margin,
			ApproachMechanicsModel.attack_family_for_hit_type(hit_type),
		)
	if swing_deficit > 0.0:
		result.attack_quality = clampf(
			float(result.attack_quality) - swing_deficit * ATTACK_OVERREACH_SEVERITY,
			0.0, 1.0,
		)
	var opponent_defenders: Array[Vector2] = []
	for defender_resource in opponent_team.on_court_players():
		var defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if defender != null:
			opponent_defenders.append(opponent_live_positions.get(
				defender.id, opponent_team.court_position(defender.id, "defense")
			))
	var opponent_plan_for_wall := _opponent_defensive_plan(opponent_team)
	shadow_summary["geometric_attack"] = _geometric_swing_record(
		_geometric_swing(
			hitter, set_target, assignment.lane, opponent_block_formation,
			_opponent_block_fallbacks(opponent_team), opponent_live_positions,
			opponent_defenders, true,
			float(resolved_approach.get("jump_multiplier", 1.0)),
			## `_approach_execution_fit`, not `runup_quality`. The other two
			## swings pass the fit and this one passed the raw run-up, so the
			## same physical approach entered the resolver on two different
			## scales depending on which contact it was.
			_approach_execution_fit(hitter, resolved_approach),
			float(home_principles.decisiveness), 0.0,
			str(opponent_plan_for_wall.block_intent) \
				if opponent_plan_for_wall != null else "Balanced",
		),
		"home",
	)
	shadow_reception_trace.summary = shadow_summary
	var geometric := _geometric_promotion(
		Dictionary(shadow_summary["geometric_attack"])
	)
	var attack_choice := _choose_attack_target(
		hitter, CourtConstants.lane_target(assignment.lane), hit_type,
		opponent_defenders,
	)
	if using_live_attack:
		result.attack_quality = clampf(float(selected_live_attack.get(
			"quality", result.attack_quality
		)), 0.0, 1.0)
		hit_type = str(selected_live_attack.get(
			"selected_action", hit_type
		)).replace("_", " ").capitalize()
		attack_choice = {
			"target": Vector2(selected_live_attack.get(
				"target", attack_choice.target
			)),
			"direction": str(selected_live_attack.get(
				"direction", attack_choice.direction
			)),
			"reason": str(selected_live_attack.get(
				"target_reason", "largest perceived gap"
			)),
		}
	var attack_effectiveness := _attack_effectiveness(
		float(result.attack_quality), float(home_principles.decisiveness),
	)
	identity_effects["attack_selection"]["effectiveness"] = attack_effectiveness
	var attack_target: Vector2 = attack_choice.target
	var intended_attack_target := attack_target
	var attack_missed := _attack_missed(float(result.attack_quality))
	if not geometric.is_empty():
		## A geometric swing is not aimed at a point and then scattered off it.
		## It is struck along a course at a speed and it lands where the ball
		## lands, so the error and the endpoint are the same fact and there is
		## nothing left for `_errant_attack_target` to invent. The lane's target
		## stays as `intended_attack_target`, which is what the record and the
		## opponent's read are actually about.
		attack_missed = bool(geometric.attack_missed)
		attack_target = Vector2(geometric.target)
	elif attack_missed:
		attack_target = _errant_attack_target(
			intended_attack_target, float(result.attack_quality)
		)
		## A promoted continuous attack describes the intended successful
		## contact. Once the official quality rules it an error, its persistent
		## endpoint cannot override the visible miss.
		using_live_attack = false
	var approach_start := Vector2(approach_preparation.get(
		"approach_start_position",
		_approach_start_position(set_target, hitter_start, false)
	))
## The same compromise the opponent makes. A hitter handed an unplayable set
	## rolls it over rather than swinging at it, and until now only one side of the
	## net could do that.
	if RallyFeatureFlagsModel.ENABLE_UNIFIED_ATTACK_SHAPE:
		hit_type = _compromised_shot_type(
			hitter, hit_type, float(result.set_quality)
		)
	var attack_angle := _attack_launch_angle_degrees(
		hitter, hit_type, float(result.attack_quality)
	)
	var attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_target, attack_target), attack_angle
	)
	var attack_flight := float(attack_arc.duration_seconds)
	var attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, attack_flight,
		float(attack_arc.apex_height_meters),
		rally_clock + set_flight_time
	)
	if using_live_attack:
		attack_trajectory = Dictionary(selected_live_attack.get(
			"attack_trajectory", attack_trajectory
		)).duplicate(true)
		attack_flight = float(attack_trajectory.get(
			"duration", attack_flight
		))
		live_attack_integration = LiveAttackIntegratorModel.apply(
			live_state, selected_live_attack
		)
		if not bool(live_attack_integration.get("applied", false)):
			using_live_attack = false
		else:
			shadow_summary["live_attack_integration"] = \
				live_attack_integration.duplicate(true)
			shadow_reception_trace.summary = shadow_summary
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, result.attack_quality >= 0.25,
		result.attack_quality, "%s: %s" % [hitter.display_name, hit_type],
		("%s from %s at T%d · %d%% contact quality." % [
			hit_type, assignment.lane, assignment.tempo,
			roundi(float(result.attack_quality) * 100.0),
		]) + (" Arrived %.2fs before the ball." % hitter_arrival_margin
			if hitter_arrival_margin >= 0.0 else
			" Arrived %.2fs late and lost the approach window." % absf(hitter_arrival_margin)),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			## Step 2 of the tempo chain: what the set's flight gave this hitter
			## against what they needed. Published, not spent -- see
			## `_approach_budget`.
			"approach_budget": _approach_budget(
				hitter, hitter_standing_at, approach_preparation, set_target,
				float(set_flight_time), int(assignment.tempo),
			),
			"attack_type": hit_type, "attack_direction": attack_choice.direction,
			"intended_type": intended_hit_type,
			"swing_downgraded": swing_downgraded,
			"swing_deficit_terms": swing_deficit_terms,
			"swing_runup_quality": float(resolved_approach.get("runup_quality", 0.0)),
			"swing_in_system": bool(resolved_approach.get("approach_in_system", false)),
			"target_reason": attack_choice.reason,
			"intended_target": intended_attack_target,
			"geometric_outcome": str(geometric.get("outcome", "")),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": attack_missed,
			"attack_effectiveness": attack_effectiveness,
			"movement_start": hitter_start,
			"approach_start_position": approach_start,
			"approach_target_position": Vector2(approach_preparation.get(
				"approach_target_position", approach_start
			)),
			"reached_approach_mark": bool(approach_preparation.get(
				"reached_approach_start", true
			)),
			"transition_preparation": approach_preparation.duplicate(true),
			"resolved_approach": resolved_approach.duplicate(true),
			"available_attack_actions": available_attacks.duplicate(),
			"approach_speed_mps": float(resolved_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(resolved_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(resolved_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(resolved_approach.get("approach_in_system", false)),
			"jump_multiplier": float(resolved_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(resolved_approach.get("lateral_control", 0.0)),
			"movement_duration": hitter_move_time,
			"movement_entry_velocity": hitter_entry_velocity,
			"arrival_margin": hitter_arrival_margin,
			"deadline": rally_clock + float(set_flight_time),
			"event_time": rally_clock + float(set_flight_time),
			"set_flight_time": float(set_flight_time),
			"incoming_trajectory": set_trajectory,
			"outgoing_trajectory": attack_trajectory})
	var live_attack_event := result.events[-1] as RallyEvent
	if using_live_attack and live_attack_event != null:
		live_attack_event.metadata["continuous_attack"] = true
		live_attack_event.metadata["observation_targeting"] = true
		live_attack_event.metadata["persistent_state_update"] = \
			live_attack_integration.duplicate(true)
	live_positions[hitter.id] = Vector2(live_attack_integration.get(
		"hitter_center_position", set_target
	)) if using_live_attack else set_target
	rally_clock += float(set_flight_time)
	if attack_missed:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})

	## Gates 48 and 49: the guarded block selection boundary, evaluated at the
	## point of use so the promotion chain is definitively known. A block only
	## makes sense against the attack the blockers actually read, so promotion
	## requires the Gate 42 attack to have been promoted first -- otherwise the
	## shadow block closed on a lane the official ball never went to.
	var block_rollout_requested := using_live_attack \
		and development_continuous_reception and OS.is_debug_build() \
		and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_BLOCK_OVERRIDE
	var block_rollout := RallyRolloutPolicyModel.select_block_source(
		shadow_summary, opponent_team.current_lineup(), block_rollout_requested
	)
	var selected_live_block: Dictionary = block_rollout.get("selected_block", {})
	var using_live_block := not selected_live_block.is_empty() \
		and str(block_rollout.get("selected_source", "official")) == "continuous_block"
	if using_live_block and not bool(LiveBlockIntegratorModel.validate(
		live_state, selected_live_block
	).get("valid", false)):
		block_rollout = RallyRolloutPolicyModel.select_block_source(
			shadow_summary, opponent_team.current_lineup(), false
		)
		selected_live_block = {}
		using_live_block = false
	var block_rollout_evidence := block_rollout.duplicate(true)
	block_rollout_evidence.erase("selected_block")
	shadow_summary["block_rollout"] = block_rollout_evidence
	shadow_reception_trace.summary = shadow_summary

	# Resolve the block from the opponent's actual front-row geometry. A
	# roster-wide best blocker must not cover every pin regardless of distance.
	## The opponent's wall, with the opponent's intent. Their plan is built from
	## the same defaults a home coach starts on, so a Balanced intent here is the
	## same Balanced intent the player would have.
	var opponent_plan_for_block := _opponent_defensive_plan(opponent_team)
	var block_resolution := _contest_block(
		opponent_block_formation, attack_effectiveness, 0.0,
		str(opponent_plan_for_block.block_intent) \
			if opponent_plan_for_block != null else "Balanced",
	)

	var live_block_integration: Dictionary = {}
	if using_live_block:
		live_block_integration = LiveBlockIntegratorModel.apply(
			live_state, selected_live_block
		)
		if not bool(live_block_integration.get("applied", false)):
			using_live_block = false
			block_rollout_evidence["selected_source"] = "official"
			block_rollout_evidence["fallback_reason"] = str(
				live_block_integration.get("reason", "block integration failed")
			)
			shadow_summary["block_rollout"] = block_rollout_evidence
			shadow_reception_trace.summary = shadow_summary
		else:
			## The promoted contact replaces who blocked and what happened, but
			## not the coverage geometry the legacy resolver derived; that is
			## still the official continuation, exactly as Gate 42 left blocking
			## on the legacy path after promoting the attack.
			var promoted_primary := opponent_team.player_by_id(
				int(live_block_integration.get("primary_id", -1))
			) as VolleyballPlayer
			var promoted_assist := opponent_team.player_by_id(
				int(live_block_integration.get("assist_id", -1))
			) as VolleyballPlayer
			if promoted_primary != null:
				block_resolution["primary"] = promoted_primary
				block_resolution["assist"] = promoted_assist
				block_resolution["outcome"] = str(
					live_block_integration.get("outcome", "recycle")
				)
			shadow_summary["live_block_integration"] = \
				live_block_integration.duplicate(true)
			shadow_reception_trace.summary = shadow_summary
	var opponent_blocker := block_resolution.primary as VolleyballPlayer
	var assisting_blocker := block_resolution.assist as VolleyballPlayer
	var primary_close := float(block_resolution.primary_close)
	var assist_close := float(block_resolution.assist_close)
	var block_strength := float(block_resolution.quality)
	## Already folded into the formation's quality before the contest ran; read
	## back here only to explain the rally.
	var adaptation_bonus := float(block_resolution.get("adaptation_bonus", 0.0))
	if adaptation_bonus >= 0.035:
		result.key_factors.append(ExplanationText.factor("opponent_adapted"))
	## The contest is the whole answer. A flat 18-48% "beaten block still gets a
	## hand on it" roll used to run on top of it, on this side of the net only.
	## It duplicated the contest's own `funnel` band, and because it was written
	## against a `primary_close` that was 99.5% saturated it fired at close to
	## its ceiling on almost every swing -- two thirds of all attacks recycled
	## into a continuation and rallies never ended.
	var block_outcome := str(block_resolution.outcome)
	if not geometric.is_empty():
		## The contest above still ran, and everything it decided other than the
		## outcome -- who blocked, how far they closed, the coverage shape, the
		## scouting bonus -- is still the rally's. What the geometry replaces is
		## the one thing it can answer better: whether the ball actually met the
		## hands, which is a question about where the ball was and where the
		## hands were rather than about two quality scalars.
		block_outcome = str(geometric.block_outcome)
	var blocked := block_outcome == "stuff"
	# A positional partial block is the same continuation class as the older
	# "recycle" result: the home attack-coverage unit must play the deflection.
	var recycled := block_outcome in ["recycle", "touch", "funnel"]
	var recycle_target := _attack_coverage_target(set_target, block_strength) \
		if recycled else Vector2(set_target.x, 0.50)
	var net_contact := Vector2(set_target.x, 0.50)
	var attack_event: Resource = result.events[-1]
	## A block that never touches the ball must not shorten the shot.
	##
	## This truncation used to be unconditional, so every attack resolved
	## against a block ended at the net -- about three percent of the court from
	## where it started. The spike was drawn barely moving, and the rest of the
	## distance arrived as the block's "deflection", which read as the ball
	## teleporting onto whoever dug it. Re-slicing is correct only when the
	## block actually intercepts; otherwise the shot keeps its full arc and
	## chains straight into the defence.
	var block_contacts_ball := blocked or recycled
	if block_contacts_ball:
		## Same shot as attack_trajectory above, re-sliced to where it actually
		## crosses the net rather than where it was originally headed -- same
		## launch angle, shorter distance, so duration/apex still fall out of
		## the geometry instead of being a separate hardcoded segment.
		var attack_to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(set_target, net_contact), attack_angle
		)
		attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, net_contact,
			float(attack_to_block_arc.duration_seconds),
			float(attack_to_block_arc.apex_height_meters),
			float(attack_event.metadata.get("event_time", rally_clock))
		)
	## Walk the opponent's blockers to their wall during the *set's* flight,
	## which is when a block actually forms. Without this they were drawn
	## sprinting to the antenna during the attack's flight instead -- and an
	## attack-to-block segment can be 0.14s, so a blocker caught deep in
	## transition covered seven metres inside it. The home side already stages
	## its blockers this way through `home_phase_targets` on the opponent's
	## attack event; this is the same mechanism pointed the other way, which is
	## why only opponent blockers showed up in the movement audit.
	var opponent_wall_x := _wall_stage_x(
		hitter, set_target, str(assignment.lane), true,
		float(opponent_block_formation.get("read_quality", 0.0)),
		str(opponent_plan_for_wall.block_intent) \
			if opponent_plan_for_wall != null else "Balanced",
	)
	var opponent_wall := _block_wall_positions(opponent_wall_x, true)
	var opponent_block_stage := {}
	if opponent_blocker != null:
		opponent_block_stage[opponent_blocker.id] = Vector2(opponent_wall.primary_position)
	if assisting_blocker != null:
		opponent_block_stage[assisting_blocker.id] = Vector2(opponent_wall.assist_position)
	## And the other four, who until now were staged nowhere at all. The two
	## blockers were walked to the wall and everybody else was left standing
	## wherever the previous phase had put them, so the opponent's floor defence
	## met a spike from a position nothing had chosen. This is the same
	## preparation the home six get on the opponent's attack, pointed the other
	## way.
	var opponent_floor_stage := _floor_phase_positions(
		opponent_team.current_lineup(), _opponent_defensive_plan(opponent_team),
		set_target.x,
		opponent_blocker.id if opponent_blocker != null else -1,
		assisting_blocker.id if assisting_blocker != null else -1,
		true, opponent_wall_x,
	)
	for raw_floor_id in opponent_floor_stage:
		var floor_id := int(raw_floor_id)
		if opponent_block_stage.has(floor_id):
			continue
		opponent_block_stage[floor_id] = Vector2(opponent_floor_stage[raw_floor_id])
	for raw_player_id in opponent_block_stage:
		opponent_live_positions[int(raw_player_id)] = Vector2(
			opponent_block_stage[raw_player_id]
		)
	if not opponent_block_stage.is_empty():
		attack_event.metadata["opponent_phase_targets"] = opponent_block_stage
	var post_block_target := recycle_target if recycled else attack_target
	if blocked:
		post_block_target = Vector2(set_target.x, 0.57)
	## A ball that went out off the hands is not a recycled ball, and its
	## endpoint is the one the geometry already produced -- outside the court,
	## which is exactly why it is the hitter's point.
	if not geometric.is_empty() and bool(geometric.hitter_point):
		post_block_target = Vector2(geometric.target)
	## An untouched ball carries no deflection segment: the attack's own flight
	## already reaches the floor, and emitting a second overlapping path is what
	## made the ball appear twice in two places.
	## The deflection leaves the hands when the ball reaches them, which is
	## after the swing. `rally_clock` here is still the moment the set left the
	## setter, so this stamped every touched block a full set-flight early.
	var opponent_block_trajectory := _block_deflection_trajectory(
		net_contact, post_block_target, blocked, 0.35,
		_swing_reaches_net(attack_trajectory, rally_clock + float(set_flight_time)),
	) if block_contacts_ball else {}
	var opponent_block_segments: Array[Dictionary] = block_resolution.coverage_segments
	var opponent_blocker_id := opponent_blocker.id if opponent_blocker != null else -1
	var opponent_blocker_name := opponent_blocker.display_name \
		if opponent_blocker != null else "Open block"
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker_id,
		opponent_blocker_name,
		Vector2(set_target.x, 0.47), post_block_target, block_outcome != "miss",
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane.%s" % [
			roundi(block_strength * 100.0),
			" Scouting anticipated this pattern." if adaptation_bonus >= 0.035 else "",
		], {"side": "opponent", "lane": assignment.lane,
			"adaptation_bonus": adaptation_bonus, "outcome": block_outcome,
			"continuous_block": using_live_block,
			"deflection_target": post_block_target,
			"coverage_segments": opponent_block_segments,
			"primary_close": primary_close,
			"assist_close": assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			## The wall that was staged, not a second one computed from the
			## contact. Recomputing it here is how the drawn wall and the
			## contested wall came apart the first time.
			"primary_position": Vector2(opponent_wall.primary_position),
			"assist_position": Vector2(opponent_wall.assist_position),
			"setter_pull": block_resolution.setter_pull,
			"read_quality": block_resolution.read_quality,
			"event_time": _swing_reaches_net(
				attack_event.metadata.outgoing_trajectory, rally_clock
			),
			"incoming_trajectory": attack_event.metadata.outgoing_trajectory,
			"outgoing_trajectory": opponent_block_trajectory})
	## Three of the geometric outcomes end the rally at the net in the hitter's
	## favour -- through the hands, off the hands and out, or placed off them on
	## purpose. The legacy path has no vocabulary for any of them: a swing that
	## touched the block could only be stuffed or recycled, so a hitter using the
	## block was scored as a hitter who had been stopped by it. This claims the
	## point before the recycle branch can take the ball back into home coverage.
	if not geometric.is_empty() and bool(geometric.hitter_point):
		result.key_factors.append(ExplanationText.factor("attack_control"))
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": result.active_play_name,
		})
	if blocked:
		result.key_factors.append(ExplanationText.factor("strong_block"))
		return _finish(result, "blocked", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	if recycled:
		var coverage_result := _resolve_attack_coverage(
			players, lineup, defensive_plan, hitter, recycle_target, block_strength
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
		var coverer_start: Vector2 = live_positions.get(
			coverer.id, recycle_target
		) if coverer != null else recycle_target
		var coverer_move_time := _movement_time(
			coverer, coverer_start, recycle_target, "lateral"
		) if coverer != null else 4.0
		var coverer_reach := _reached_point(
			coverer, coverer_start, recycle_target,
			float(opponent_block_trajectory.get("duration", 0.24)), "lateral",
		) if coverer != null else recycle_target
		if coverer != null:
			live_positions[coverer.id] = coverer_reach
		var coverage_pass_target := recycle_target + Vector2(0.04, -0.05)
		_add_event(result, RallyEventModel.EventType.DEFENSE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Attack coverage",
			recycle_target, coverage_pass_target,
			coverage_success, coverage_quality,
			"%s covers the block touch" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% recycle control from the assigned attack-coverage shape." % roundi(
				coverage_quality * 100.0
			), {"side": "home", "coverage": "attack",
				"blocked_hitter_id": hitter.id,
				"movement_start": coverer_start,
				"movement_target": coverer_reach,
				"movement_duration": coverer_move_time,
				## Coverage happens when the blocked ball comes back down, which
				## is the end of the deflection's own arc. `rally_clock` here is
				## still the set's contact time -- earlier than the block itself,
				## so this stamped the cover as happening before the touch it
				## covers.
				"event_time": float(opponent_block_trajectory.get(
					"end_time", rally_clock + float(set_flight_time)
				))})
		rally_clock = maxf(rally_clock, float(opponent_block_trajectory.get(
			"end_time", rally_clock + float(set_flight_time)
		)))
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		result.key_factors.append(ExplanationText.factor("attack_recycled"))
		## A ball that came off the block is not a clean one. The coverage
		## contact's own control is what the setter has to work with, and a
		## formed wall degrades it further -- which is the only channel a
		## blocker has to the result other than a stuff.
		return _resolve_home_continuation(
			result, players, lineup, coverer, coverage_pass_target,
			opponent_team, defensive_plan, 1,
			coverage_quality * lerpf(
				1.0, BLOCK_DEFLECTION_CARRY, clampf(block_strength, 0.0, 1.0)
			),
		)

	## A deflected ball reaches the floor slower, and the defence gets that time.
	##
	## The home dig has always added it -- `+0.24 s` for a touch, `+0.06` for a
	## funnel -- and this side got the raw flight. That is the side it matters
	## most to: the opponent's block touches 22.9% of home swings against the
	## home block's 6.5%, so the bonus was withheld from the defence that earns
	## it four times as often. Decomposed, this is most of a `reach_margin` of
	## +0.333 m for the home defender against -0.094 m here, on identical
	## rosters, which in turn carries the dig rate gap of 0.320 to 0.142.
	var opponent_defense_time := attack_flight
	if block_outcome == "touch":
		opponent_defense_time += 0.24
	elif block_outcome == "funnel":
		opponent_defense_time += 0.06
	var opponent_defense := _choose_opponent_defender(
		opponent_team, attack_target, opponent_defense_time
	)
	var opponent_defender := opponent_defense.player as VolleyballPlayer
	var read_tags: Array[String] = ["hand:%s" % hitter.dominant_hand.to_lower(),
		"attack:%s" % str(attack_choice.direction).to_lower().replace("-", "_")]
	var read_modifier := Familiarity.read_modifier(
		opponent_defender, read_tags, float(opponent_team.scouting_confidence)
	)
	var floor_defense_bonus := _opponent_floor_defense_adaptation_bonus(
		opponent_team, assignment.lane
	)
	## The same plan read the home defender gets. Scouting and familiarity were
	## the only things this side could bring to a dig, because responsibility
	## fit and posture are read off a defensive plan and this side had none. It
	## has one now, so it reads from it -- otherwise giving the opponent a plan
	## would have positioned them by it without ever letting them know it.
	## `_opponent_attack_type` classifies a landing point in home-court
	## coordinates, so the home side's ball is mirrored into that frame rather
	## than handed the hitter's shot name, which none of the classifier's
	## branches would ever match.
	var opponent_posture_read := _defensive_responsibility_fit(
		_opponent_defensive_plan(opponent_team), opponent_defender.id,
		attack_target,
		_opponent_attack_type(Vector2(attack_target.x, 1.0 - attack_target.y)),
	)
	var opponent_dig_terms := _defense_terms(
		opponent_defender, float(opponent_defense.reach_margin_meters),
		read_modifier + floor_defense_bonus + opponent_posture_read,
		CoverageModel.reception_body_penalty(
			opponent_defender, Dictionary(opponent_defense.get("arrival", {})),
			attack_effectiveness,
		),
		int(opponent_defense.get("support_count", 0)),
	)
	opponent_dig_terms["contested_against"] = attack_effectiveness
	var defense_strength := float(opponent_dig_terms.quality)
	Familiarity.record_exposure(opponent_defender, read_tags)
	var dug: bool = _dig_contest(opponent_defender, defense_strength, attack_effectiveness)
	## A dig has a body cost too, and until now only a serve reception did -- so a
	## libero dug a swing off the floor and stood up unaffected, while the same
	## libero receiving a serve paid for it.
	var opponent_dig_recovery := _dig_recovery(
		opponent_defender, opponent_dig_terms, attack_effectiveness,
		attack_trajectory, float(opponent_defense.distance_meters),
	)
	var opponent_pass_target := attack_target + Vector2(0.04, -0.03)
	## When the ball actually reaches the defender, which is the end of the
	## swing's own arc. The transition that follows builds its second-contact
	## window from `rally_clock`, so the clock has to arrive here too -- left at
	## the set's contact time it would place the next set *before* this dig.
	var opponent_dig_time := float(attack_trajectory.get(
		"end_time", rally_clock + attack_flight
	))
	var opponent_defender_reach := _reached_point(
		opponent_defender, Vector2(opponent_defense.start), attack_target,
		attack_flight, "lateral",
	)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name,
		attack_target, opponent_pass_target, dug,
		defense_strength, "Defensive contact",
		"%s %s the %s attack after moving %.1fm.%s" % [
			opponent_defender.display_name, "controls" if dug else "cannot reach",
			str(attack_choice.direction), float(opponent_defense.distance_meters),
			" Scouting anticipated this lane." if floor_defense_bonus >= 0.035 else "",
		], {"side": "opponent", "dig_terms": opponent_dig_terms,
			"movement_start": opponent_defense.start,
			"movement_duration": opponent_defense.travel_time,
			"reach_margin_meters": opponent_defense.reach_margin_meters,
			## The whole arrival, as the home side has always stamped. Without it
			## the two sides could not be compared on the terms the claim is
			## actually decided on -- distance to the ball, reach, time available --
			## so a 0.48 m reach-margin gap could be seen and not attributed.
			"arrival": Dictionary(opponent_defense.get("arrival", {})),
			"claimed": bool(opponent_defense.get("claimed", false)),
			"flight_time": opponent_defense_time,
			## The shape this dig was claimed out of. The home dig event has
			## carried `home_phase_targets` all along and this one carried
			## nothing, so the two sides' defensive shapes could not be compared
			## -- only the distance each ended up covering, which is the result
			## rather than the reason. Without it the opponent's best-available
			## defender is unmeasurable and "their shape is worse" stays a guess.
			"opponent_phase_targets": opponent_live_positions.duplicate(true),
			"movement_target": opponent_defender_reach,
			## The dig happens when the swing reaches the floor, which the
			## swing's own trajectory already states. Deriving it from
			## `rally_clock` instead misses the set flight that separates them.
			"event_time": opponent_dig_time,
			"attack_direction": attack_choice.direction,
			"contact_recovery": opponent_dig_recovery,
			"contact_control": last_dig_control,
			"incoming_force": last_dig_force,
			"incoming_speed_mps": last_dig_speed,
			"contact_posture": last_dig_posture,
			"recovering_count": _recovering_count(rally_clock),
			"adaptation_bonus": floor_defense_bonus})
	_note_recovery(opponent_defender, opponent_dig_recovery, opponent_dig_time)
	## Where they actually ended up, not where the ball was. A defender who was
	## beaten to it starts the next phase short of it, which is the position the
	## rest of the rally should reason from.
	opponent_live_positions[opponent_defender.id] = opponent_defender_reach
	rally_clock = maxf(rally_clock, opponent_dig_time)
	if dug:
		result.key_factors.append(ExplanationText.factor("strong_defense"))
		return _resolve_opponent_transition(
			result, players, lineup, hitter, opponent_pass_target,
			opponent_team, defensive_plan, 1, defense_strength, false,
			opponent_defender.id,
		)
	result.key_factors.append(ExplanationText.factor("attack_control"))
	var kill_key := "kill_default" if active_play == null else (
		"kill_called" if result.play_was_followed else "kill_improvised"
	)
	return _finish(result, "kill", true, hitter.id, {
		"setter": setter.display_name,
		"hitter": hitter.display_name,
		"play": result.active_play_name,
	}, kill_key)


func _resolve_home_serve(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
) -> Resource:
	var server := _best_home_server(players, lineup)
	var serve_risk := 0.5
	if defensive_plan != null:
		serve_risk = float(defensive_plan.serve_risk)
	var called_serve_risk := serve_risk
	serve_risk = clampf(
		serve_risk + (float(home_principles.serve_aggression) - 0.5) * 0.70,
		0.0, 1.0,
	)
	identity_effects["serve_risk"] = {
		"called": called_serve_risk,
		"effective": serve_risk,
		"serve_aggression": float(home_principles.serve_aggression),
	}
	var serve_quality := clampf(
		_power_rating(server, "serve_power") * 0.25
		+ _rating(server, "serve_technique") * 0.20
		+ _rating(server, "serve_placement") * 0.13
		+ _rating(server, "serve_consistency") * 0.14
		+ _serve_style_proficiency(server) * 0.13
		+ serve_risk * 0.15 + rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	var error_chance := _serve_error_chance(server, serve_risk)
	var serve_error := rng.randf() < error_chance
	var target_name := str(
		defensive_plan.serve_target if defensive_plan != null else "Zone 5"
	)
	var opponent_landing := _serve_landing_point(
		target_name, server, [], null, false
	)
	_geometric_serve_record(
		"geometric_serve_home", server,
		CourtConstants.serve_origin(0.82, true), opponent_landing, true, serve_risk,
	)
	if serve_error:
		opponent_landing = _errant_serve_landing(
			opponent_landing, serve_quality, false
		)
	var serve_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(CourtConstants.serve_origin(0.82, true), opponent_landing),
		_serve_launch_angle_degrees(server, serve_quality),
	)
	var serve_time := float(serve_arc.duration_seconds)
	## Named so the reception can carry it as its incoming ball, exactly as the
	## opponent-serve path already does.
	var serve_trajectory := _ball_trajectory(
		"serve", CourtConstants.serve_origin(0.82, true), opponent_landing,
		serve_time, float(serve_arc.apex_height_meters),
	)
	## Their floor-defence spot, from the plan if there is one and the rotation
	## grid if there is not -- the same fallback `_initial_home_positions` uses.
	var home_serve_base: Vector2 = CourtConstants.slot_position(1)
	if defensive_plan != null:
		home_serve_base = defensive_plan.defender_position(server.id, home_serve_base)
	_add_event(result, RallyEventModel.EventType.SERVE, server.id, server.display_name,
		CourtConstants.serve_origin(0.82, true), opponent_landing, not serve_error,
		serve_quality, "%s serves" % server.display_name,
		"%s · %d%% pressure at %d%% selected risk." % [server.primary_serve_style,
			roundi(serve_quality * 100.0), roundi(serve_risk * 100.0),
		], {"side": "home", "target": target_name, "flight_time": serve_time,
			"server_id": server.id, "server_slot": 1,
			"serve_style": server.primary_serve_style,
			"event_time": 0.0, "contact_time": serve_time,
			## See the opponent serve: struck from behind the baseline, then onto
			## the court over the serve's own flight.
			"movement_start": CourtConstants.serve_origin(0.82, true),
			"movement_target": home_serve_base,
			"outgoing_trajectory": serve_trajectory})
	live_positions[server.id] = home_serve_base
	if serve_error:
		return _finish(result, "serve_error", false, server.id, {
			"server": server.display_name,
		})
	## The ball is now in the air, and the clock has to say so.
	##
	## The opponent-serve path has always done this. This one never did, so
	## `rally_clock` stayed at zero through the serve, the reception and into
	## the transition -- every contact on a home-served rally derived its moment
	## from a clock that had not started. It is the reason the timestamp gate saw
	## a quarter of all inter-event gaps at zero and still reported the timeline
	## sound: stamps that are all equal are never out of order.
	rally_clock = serve_time
	var opponent_coverage := _opponent_reception_coverage(opponent_team)
	var opponent_claim: Dictionary = CoverageModel.choose_claimant(
		opponent_coverage.players, opponent_coverage.zones,
		opponent_landing, serve_time, "reception",
	)
	var receiver := opponent_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = opponent_team.best_defender() as VolleyballPlayer
	var opponent_arrival: Dictionary = opponent_claim.get("arrival", {})
	var receiver_zone: Resource = opponent_coverage.zones.get(receiver.id) as Resource
	var receiver_start: Vector2 = opponent_live_positions.get(
		receiver.id,
		Vector2(receiver_zone.center) if receiver_zone != null \
		else opponent_team.court_position(receiver.id, "serve_receive"),
	)
	var receiver_move_time := _movement_time(
		receiver, receiver_start, opponent_landing, "lateral"
	)
	var support_count := int(opponent_claim.get("support_count", 0))
	var serve_receive_bonus := _opponent_serve_receive_adaptation_bonus(
		opponent_team, target_name
	)
	## Quality describes execution; selected risk describes how much pace and
	## movement the serve attempts. Centre this at the legacy 0.50 call so the
	## Balanced calibration does not move merely because identities exist.
	var serve_risk_pressure := (serve_risk - 0.5) * 0.16
	var opponent_reception_base := _reception_skill(receiver) \
		if RallyFeatureFlagsModel.ENABLE_UNIFIED_RECEPTION_SKILL \
		else _rating(receiver, "reception") * 0.58 \
			+ _rating(receiver, "ball_control") * 0.24
	var reception_quality := clampf(
		opponent_reception_base
		- serve_quality * 0.44
		- serve_risk_pressure
		- CoverageModel.reception_body_penalty(receiver, opponent_arrival, serve_quality)
		+ clampf(
			float(opponent_arrival.get("reach_margin_meters", -1.0)) * 0.07,
			-0.16, 0.12,
		)
		+ minf(float(support_count) * 0.025, 0.075)
		+ serve_receive_bonus + rng.randf_range(-0.12, 0.12),
		0.0, 1.0,
	)
	if not receiver_arrived:
		reception_quality = minf(reception_quality, 0.12)
	result.reception_quality = reception_quality
	var reception_success := receiver_arrived and reception_quality >= 0.18
	var opponent_receiver_reach := _reached_point(
		receiver, receiver_start, opponent_landing, serve_time, "lateral"
	)
	opponent_live_positions[receiver.id] = opponent_receiver_reach
	## Where the setter will stand, resolved before the pass rather than after it
	## so the pass can be thrown at them.
	var opponent_setter_release := _opponent_setter_release_target(opponent_team)
	## One pass, computed once.
	##
	## This event used to end at a `_delivered_point` scatter while the rally
	## continued from a *separate* `_reception_pass_result` scatter computed
	## further down -- two independent draws, so the pass that was drawn and the
	## pass that was played landed in different places. The home side has always
	## used one result for both.
	var opponent_pass := _reception_pass_result(
		receiver, receiver_start, opponent_landing, opponent_setter_release,
		CourtConstants.serve_origin(0.82, true), serve_quality, opponent_arrival,
		reception_quality, 0.02, 0.49, serve_trajectory,
	)
	var opponent_pass_destination := Vector2(opponent_pass.destination)
	_note_recovery(receiver, str(opponent_pass.contact_recovery), rally_clock)
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		opponent_landing, opponent_pass_destination,
		reception_success,
		reception_quality, "%s receives" % receiver.display_name,
		"Opponent reception quality: %d%%. %s%s" % [
			roundi(reception_quality * 100.0),
			_arrival_phrase(opponent_arrival, receiver_arrived, support_count),
			" Scouting anticipated this target." if serve_receive_bonus >= 0.035 else "",
		], {"side": "opponent", "landing": opponent_landing,
			"flight_time": serve_time, "arrival": opponent_arrival,
			"support_count": support_count, "adaptation_bonus": serve_receive_bonus,
			"serve_risk_pressure": serve_risk_pressure,
			"movement_start": receiver_start,
			"movement_target": opponent_receiver_reach,
			"movement_duration": receiver_move_time,
			## The three keys that made this side's timeline synthetic. Without an
			## outgoing trajectory `_ensure_event_trajectories` invented one from
			## `flight_time` -- which on a reception is the *incoming* serve's
			## duration -- and stamped it at the `event_time` default of zero.
			"event_time": _contact_time(serve_trajectory, rally_clock),
			"incoming_trajectory": serve_trajectory,
			"outgoing_trajectory": opponent_pass.trajectory,
			"body_alignment": opponent_pass.body_alignment,
			"platform_feasibility": opponent_pass.platform_feasibility,
			"contact_posture": opponent_pass.contact_posture,
			"contact_recovery": opponent_pass.contact_recovery,
			"contact_control": opponent_pass.get("contact_control", 0.5),
			"movement_alignment": opponent_pass.get("movement_alignment", 0.5),
			"incoming_force": opponent_pass.get("incoming_force", 0.0),
			"incoming_speed_mps": opponent_pass.get("incoming_speed_mps", 0.0),
			"setter_release_target": opponent_setter_release,
			"actual_pass_target": opponent_pass_destination})
	if not reception_success:
		return _finish(result, "ace", true, server.id, {"server": server.display_name})
	## `opponent_setter_release` is resolved above, before the pass, because the
	## pass is thrown at it. It used to be the hardcoded court centre (0.50,
	## 0.34), which put the setter directly on top of whoever was covering the
	## middle -- the setter marker visibly vanished inside another opponent's
	## during serve receive -- and had them setting from a position no setter
	## takes.
	## Stage the setter where a setter stands.
	##
	## The receiver gets a live position on the line above and the setter never
	## did, so `_resolve_opponent_transition` fell through to
	## `court_position(id, "transition")` -- the rotation's transition base --
	## and had the setter run to the release point from there on every single
	## serve. Measured over 488 sets that put their arrival term at -0.153
	## against the home setter's -0.022, about 0.85s late against 0.12s, and it
	## dragged two more terms with it: a setter reaching from the wrong place is
	## the same setter whose delivery lands outside their capability and whose
	## set travels a worse angle. Those three terms carried the entire 0.287 set
	## gap, which in turn was the largest asymmetry left in the engine.
	##
	## The home setter is walked to their release target during the serve's
	## flight through `staged_next_position` on the reception event. This is that,
	## for the one player on the other side of the net who needed it.
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	if opponent_lineup != null:
		var opponent_setter_id := opponent_lineup.active_setter_id()
		## Not when the setter is the one receiving. This walked them to their
		## release seat during the flight of a serve they were about to pass,
		## which was harmless only while they also set every ball regardless.
		## Now that an emergency setter can take over, staging the receiver as
		## setter would move a player who is neither.
		if opponent_setter_id == receiver.id:
			opponent_setter_id = -1
		if opponent_setter_id >= 0:
			opponent_live_positions[opponent_setter_id] = opponent_setter_release
			## And playback has to be told to *walk* them there.
			##
			## Writing `opponent_live_positions` alone moves the setter for the
			## model and teleports them for the viewer: the next frame simply
			## draws them somewhere else. The comment above this block already
			## said the home setter is walked across through
			## `staged_next_position` on the reception event, and then this did
			## only half of that -- the half nobody can see.
			var opponent_reception_event := result.events[-1] as RallyEvent
			if opponent_reception_event != null \
					and opponent_reception_event.event_type \
						== RallyEventModel.EventType.RECEPTION:
				opponent_reception_event.metadata["staged_next_actor_id"] = \
					opponent_setter_id
				opponent_reception_event.metadata["staged_next_position"] = \
					opponent_setter_release
	## The pass has to find them, rather than arrive on them.
	##
	## Staging the setter fixed where they start; it left the ball landing on
	## that exact spot every time, however badly it was passed, so the setter had
	## no ground to cover at all and arrived *earlier* than the home setter
	## (+0.060 against -0.022) -- a fix that overshot rather than landed. The
	## home pass has always scattered through `_reception_pass_result`, whose
	## only home-specific line was a y clamp; with that clamp a parameter, the
	## opponent's pass is thrown by the same arm. That call now happens above,
	## before the reception event, so the ball the viewer is shown and the ball
	## the rally continues from are the same one.
	return _resolve_opponent_transition(
		result, players, lineup, server, opponent_pass_destination,
		opponent_team, defensive_plan, 1, reception_quality, true, receiver.id,
	)


func _resolve_opponent_transition(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	original_hitter: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
	## The ball this setter actually receives. The home side got this first and
	## it changed almost nothing, because most continuations come through here:
	## when the opponent digs a home swing the rally runs this path, not
	## `_resolve_home_continuation()`. A propagation link on one side of the net
	## is a link on the rarer half of the rallies.
	incoming_quality: float = 1.0,
	## True when this is a serve reception rather than a ball dug out of a
	## rally. The opponent had no first-ball path at all: every attack they made
	## in the game was built off a scramble set, including the one off their own
	## serve receive, while the home side ran the full capability model.
	first_ball: bool = false,
	## Who played the ball into this setter. The opponent had no use for it
	## because it always set with `opponent_team.setter()` -- so on the rallies
	## where that setter made the dig themselves, they rose from the floor and
	## set their own ball. The home side has covered for its setter since the
	## beginning through `_second_contact_setter`; this side had no concept of
	## an emergency setter at all.
	first_contact_player_id: int = -1,
) -> Resource:
	var transition_penalty := float(exchange_number - 1) * 0.035
	## The pass destination is the setter's physical contact point. Keeping a
	## separate display-only setter coordinate made the ball originate away from
	## the marker and introduced a visible snap at every opponent set.
	var opponent_setter_position := dig_position
	## The same two-step choice the home side makes: the plan's nominated cover
	## when the designated setter is unavailable, then whoever can actually get
	## to the ball. Both selectors are now one implementation taking a candidate
	## list, so neither side can drift from the other again.
	var opponent_second_contact := _opponent_second_contact_candidates(opponent_team)
	var opponent_plan_for_setter := _opponent_defensive_plan(opponent_team)
	var opponent_setter := _second_contact_setter(
		opponent_second_contact.candidates, opponent_plan_for_setter,
		int(opponent_team.setter_id), first_contact_player_id,
	)
	if opponent_setter == null:
		opponent_setter = opponent_team.setter() as VolleyballPlayer
	var opponent_setter_choice := _spatial_setter_choice(
		opponent_second_contact.candidates, opponent_second_contact.starts,
		opponent_plan_for_setter, int(opponent_team.setter_id),
		first_contact_player_id, opponent_setter,
		opponent_setter_position, DEFAULT_SECOND_CONTACT_SECONDS,
	)
	if opponent_setter_choice.player != null:
		opponent_setter = opponent_setter_choice.player as VolleyballPlayer
	if opponent_setter == null:
		opponent_setter = opponent_team.setter() as VolleyballPlayer
	var setter_start: Vector2 = opponent_live_positions.get(
		opponent_setter.id, opponent_team.court_position(opponent_setter.id, "transition")
	)
	var setter_move_time := _movement_time(
		opponent_setter, setter_start, opponent_setter_position, "lateral"
	)
	## The same quantity the home setter is scored on: how much of the pass
	## flight is left once they have reached the ball. A setter who arrives
	## early can load a jump set; one still scrambling takes it flat-footed.
	var setter_arrival_margin := DEFAULT_SECOND_CONTACT_SECONDS - setter_move_time
	var set_geometry := _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		Vector2(0.50, 0.48), Vector2(0.50, 0.48)
	)
	## Same model as the home transition set, and now the same attributes. The
	## two sides read different ones -- this side set_accuracy, court_vision and
	## decision_making, the home side set_accuracy, ball_control and composure --
	## so a setter improved on one team's terms was not improved on the other's.
	## The opponent's own capability read, run on a serve reception exactly as
	## the home setter's is. On a dug ball there is no called play to overreach
	## against, so the penalty is zero and the pass stands as it arrived.
	## A dug ball is set high by anybody. The opponent asked its serve-receive
	## tendency what to run on a scramble ball too, so it played the same middle
	## tempo out of defence as it does off a clean pass -- while the home side
	## has always set its own transition high. The tendency is what the bench
	## prefers *when there is a choice*, and out of defence there is not one.
	var opponent_tempo_call := _tempo_call(
		opponent_setter,
		int(opponent_team.tendencies.get("tempo", 2)) if first_ball \
			else TRANSITION_TEMPO_BASE,
		incoming_quality,
	)
	## Capability, on every ball rather than only the first one.
	##
	## This was gated on `first_ball`, which meant an opponent set out of
	## defence paid no capability penalty at all -- the mirror of the defect
	## just fixed on the home transition set. Fixing one and leaving the other
	## would have made the two transition sets differ by side, which is the
	## exact shape this engine has produced eleven times now. A setter taking a
	## dug ball is doing the same thing they do off a pass: reaching for a
	## contact at some height, off some approach, for some tempo.
	var opponent_capability := SetterCapabilityModel.evaluate(
		opponent_setter, opponent_tempo_call, incoming_quality,
		SetterCapabilityModel.pass_contact_height_meters(
			incoming_quality, rng.randf()
		),
		clampf(inverse_lerp(-0.25, 0.45, setter_arrival_margin), 0.0, 1.0),
	)
	var opponent_pass_quality := float(
		opponent_capability.get("effective_pass_quality", incoming_quality)
	)
	var opponent_capability_penalty := float(
		opponent_capability.get("quality_penalty", 0.0)
	)
	## And the verdict is acted on, not just billed for.
	##
	## `SetterCapabilityModel.evaluate` answers two things: what this set
	## costs the setter, and what tempo they can actually run. The home side
	## reads both -- it pays the penalty *and* abandons the play through
	## `_downgraded_assignment`. This side read the bill and threw away the
	## verdict: `resolved_tempo` and `tempo_downgraded` appear nowhere on the
	## opponent path, so an opponent setter was told they could not run the
	## tempo they called, charged for attempting it, and then ran it anyway.
	## The whole point of the model is that capability is not permission, and
	## it was only enforced against one team.
	if bool(opponent_capability.get("tempo_downgraded", false)):
		opponent_tempo_call = int(
			opponent_capability.get("resolved_tempo", opponent_tempo_call)
		)
	var opponent_set_quality := clampf(
		_set_execution(
			opponent_setter, opponent_pass_quality, transition_penalty,
			opponent_capability_penalty, setter_arrival_margin,
			float(set_geometry.difficulty),
			(Familiarity.execution_modifier(opponent_setter) - 1.0) * 0.16,
		) + _execution_error(opponent_setter, "set_accuracy", 0.12),
		0.08, 0.94,
	)
	## The tempo the setter can deliver, which on a downgraded first ball is not
	## the one the bench called. Re-reading the tendency here is what let the
	## downgrade above be computed and then ignored a dozen lines later.
	var opponent_tempo := opponent_tempo_call
	## _choose_opponent_attack needs a flight-time estimate before the real set
	## target is known. Estimate it against the same placeholder target
	## set_geometry's first pass already uses above; the real distance-based
	## value is recomputed below once opponent_contact is final, mirroring how
	## opponent_set_quality is already computed twice in this function.
	var estimated_set_flight_time: float = float(RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(
			opponent_setter_position, Vector2(0.50, 0.48)
		),
		_set_launch_angle_degrees(opponent_setter, opponent_tempo, opponent_set_quality),
	).duration_seconds)
	var attack_choice := _choose_opponent_attack(
		opponent_team, opponent_setter, opponent_set_quality,
		_home_target_hint(defensive_plan), estimated_set_flight_time,
	)
	var opponent_hitter := attack_choice.player as VolleyballPlayer
	var opponent_contact: Vector2 = attack_choice.contact
	## `_choose_opponent_attack` returns who swings, from where, and what shot --
	## it has never returned a lane. Every reader of one therefore took the
	## `"Left Pin"` default, so the opponent's approach was prepared for the left
	## pin, their familiarity accrued to the left pin, and their swing was
	## resolved along the left pin's natural course, wherever the hitter actually
	## contacted the ball. While a lane was only a label on an event that cost
	## nothing; once it began deciding the ball's course it sent right-side
	## swings across the wrong diagonal and out, and the opponent missed at over
	## twice the home side's rate.
	var opponent_lane := CourtConstants.lane_at_x(opponent_contact.x)
	## The opponent searches the floor for a gap through the same function the
	## home side does. `_choose_opponent_attack()` still picks who swings and
	## what shot; where the ball goes was a random depth band until now.
	var home_defenders: Array[Vector2] = []
	for defender in players:
		if defender == null:
			continue
		var defender_slot := lineup.slot_for_player(defender.id)
		if defender_slot <= 0:
			continue
		home_defenders.append(live_positions.get(
			defender.id, CourtConstants.slot_position(defender_slot)
		))
	var opponent_aim := _choose_attack_target(
		opponent_hitter, opponent_contact, str(attack_choice.attack_type),
		home_defenders, true,
	)
	attack_choice["target"] = opponent_aim.target
	attack_choice["direction"] = opponent_aim.direction
	var home_target: Vector2 = attack_choice.target
	set_geometry = _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		opponent_contact, Vector2(0.50, 0.48)
	)
	## The authoritative value, once the real hitter and contact point are known.
	## This is the one that feeds the swing, and it kept the retired formula
	## after the provisional computation above was moved onto the shared model --
	## so the propagation link and the aligned attribute list reached the
	## estimate and never reached the ball.
	## The geometry of the set that is actually being played.
	##
	## `set_geometry` above is computed before the hitter is chosen, against
	## `Vector2(0.50, 0.48)` standing in for a target nobody knows yet -- and
	## then reused here, where the target *is* known, so every opponent set in
	## the game was scored for difficulty as though it were being delivered to
	## the middle of the court. The home side has never done this: it reads
	## `intended_set_target` and the setter's release seat, which is why its
	## difficulty term sits at 0.077 against this side's 0.131.
	##
	## It went unnoticed while the setter stood exactly where the pass landed,
	## because a placeholder distance and a real one were both short. Scattering
	## the pass gave the setter ground to cover and the fiction started costing
	## the opponent a set.
	var resolved_set_geometry := _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		opponent_contact, _opponent_setter_release_target(opponent_team),
	)
	var opponent_set_terms := _set_terms(
		opponent_setter, opponent_pass_quality, transition_penalty,
		opponent_capability_penalty, setter_arrival_margin,
		float(resolved_set_geometry.difficulty),
		(Familiarity.execution_modifier(opponent_setter) - 1.0) * 0.16,
	)
	opponent_set_quality = clampf(
		float(opponent_set_terms.quality)
			+ _execution_error(opponent_setter, "set_accuracy", 0.12),
		0.08, 0.94,
	)
	## Decide roll-against-swing on the set that was delivered.
	##
	## `_choose_opponent_attack` had to pick a hitter before the contact existed,
	## so it read the *first* `opponent_set_quality` above -- computed against
	## `set_geometry.difficulty`, whose target is the placeholder `(0.50, 0.48)`
	## rather than the contact the setter actually found. The two are not close:
	## the SET event stamps a median of 0.755 while shot selection was reading
	## about 0.344, and the consequence was that 97% of opponent attacks came out
	## as rolls or tips -- three power swings in a hundred and twenty -- despite
	## only 11% of their sets falling below the compromise threshold.
	##
	## That is upstream of most of the dig asymmetry. A side that rolls nearly
	## every ball hands the other side a slow lofted one to read, which is the
	## 0.526 s of defensive flight time against 0.339 s, and everything the reach
	## margin and the dig rate inherit from it.
	##
	## Re-applied here rather than fixed in place because the ordering is genuinely
	## circular: the contact decides the set's difficulty and the set's difficulty
	## decides the shot. Who swings stays chosen on the estimate; only what they
	## do with it is re-read. The improvisation draw is carried from the first
	## decision rather than redrawn, so the number of draws a rally consumes is
	## unchanged and no seeded outcome downstream is re-sequenced.
	if RallyFeatureFlagsModel.ENABLE_DELIVERED_SET_SHOT_CHOICE \
			and attack_choice.has("intended_type"):
		var delivered_type := str(attack_choice.intended_type)
		if RallyFeatureFlagsModel.ENABLE_UNIFIED_ATTACK_SHAPE:
			delivered_type = _compromised_shot_type(
				opponent_hitter, delivered_type, opponent_set_quality
			)
		elif opponent_set_quality < 0.38 \
				or float(attack_choice.improvise_roll) \
					< 0.12 + _rating(opponent_hitter, "decision_making") * 0.08:
			delivered_type = "Roll shot" if opponent_set_quality >= 0.30 \
				else "Emergency tip"
		attack_choice["attack_type"] = delivered_type
	var set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_setter_position, opponent_contact),
		_set_launch_angle_degrees(opponent_setter, opponent_tempo, opponent_set_quality),
	)
	var set_flight_time: float = float(set_arc.duration_seconds)
	## When the setter actually touches the ball.
	##
	## This set was stamped at bare `rally_clock` -- the moment of the pass that
	## fed it -- so the opponent set left the setter's hands at the same instant
	## the ball arrived at them, with no flight from the passer and no release.
	## 210 of the sub-20ms event gaps in `run_playback_schedule_probe` were this
	## one thing.
	##
	## The home side has always used the incoming pass's own flight plus a
	## release interval drawn from the setter's system fit, and this function
	## already knew the figure: it hands `DEFAULT_SET_RELEASE_SECONDS +
	## DEFAULT_SECOND_CONTACT_SECONDS` to `_form_home_block` below, described
	## there as "the opponent's own pass-to-release time". The block was reading a
	## delay the set itself did not take.
	var opponent_incoming_pass: Dictionary = {}
	if not result.events.is_empty():
		opponent_incoming_pass = Dictionary(
			(result.events[-1] as RallyEvent).metadata.get("outgoing_trajectory", {})
		)
	var opponent_second_contact_window := float(
		opponent_incoming_pass.get("duration", DEFAULT_SECOND_CONTACT_SECONDS)
	)
	var opponent_release_interval := _release_interval(
		opponent_setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE),
		opponent_set_quality,
	)
	var opponent_set_contact_time := rally_clock \
		+ opponent_second_contact_window + opponent_release_interval
	_add_event(result, RallyEventModel.EventType.SET, opponent_setter.id,
		opponent_setter.display_name,
		dig_position, opponent_contact, true, opponent_set_quality,
		"Opponent transition set · exchange %d" % exchange_number,
		"Contact 2 of 3 · %d%% set quality." % roundi(opponent_set_quality * 100.0),
		{"side": "opponent",
			"set_path": "opponent_first_ball" if first_ball else "opponent_transition",
			"set_terms": opponent_set_terms,
			"setter_position": opponent_setter_position,
			"movement_start": setter_start, "movement_duration": setter_move_time,
			"set_distance_meters": resolved_set_geometry.distance_meters,
			"set_angle_degrees": resolved_set_geometry.angle_degrees,
			"body_orientation_fit": resolved_set_geometry.body_orientation_fit,
			"set_flight_time": set_flight_time,
			"event_time": opponent_set_contact_time,
			"outgoing_trajectory": _ball_trajectory(
				"opponent_set", opponent_setter_position, opponent_contact,
				set_flight_time, float(set_arc.apex_height_meters),
				opponent_set_contact_time
			)})
	var opponent_set_event := result.events[-1] as RallyEvent
	opponent_live_positions[opponent_setter.id] = opponent_setter_position
	## Provisional: recomputed below once preparation has staged the hitter.
	var hitter_arrival_margin: float = set_flight_time - float(attack_choice.travel_time)
	## The wall this swing is hit into, formed before it is scored -- the same
	## order the home attack uses. The opponent swing used to be
	## `attack_power * 0.62 + set_quality * 0.20 + 0.08`: a third execution scale,
	## with no approach term and no opposing block, compared against the same
	## contest and the same error threshold as the home side's.
	var home_block_formation := _form_home_block(
		players, lineup, defensive_plan, opponent_contact.x,
		opponent_tempo, opponent_set_quality,
		opponent_setter_position.x, set_flight_time,
		## The opponent's own pass-to-release time. Mirrors what the home set
		## gives the opponent block; the home block was reading this pass too.
		DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS,
	)
	## The home block reads the opponent, the way the opponent block reads them.
	##
	## `_opponent_block_adaptation_bonus` gives the opponent's wall a quality
	## bonus when it anticipated the lane and tempo it is facing, drawn from
	## `observe_rally` accumulating what the home team keeps doing. The home wall
	## had no equivalent -- `observe_rally` is called once per rally for the
	## opponent alone and nothing records what the *opponent* keeps doing -- so
	## scouting in this engine ran one way across the net.
	##
	## It is read per blocker rather than per team, through the familiarity model
	## the opponent's floor defence already uses. That is a deliberate difference
	## from the opponent's team-level `block_bonus()`: a blocker who has faced
	## this hitter in this lane has learned something a team average cannot
	## express, and it needs no new store because familiarity already persists on
	## the player. The team-level half -- a home equivalent of `observe_rally`
	## and `scouting_confidence` -- does need one, and is not built here.
	var home_block_read_tags: Array[String] = [
		"attack:%s" % str(attack_choice.get("attack_type", "Attack"))
			.to_lower().replace(" ", "_"),
		"lane:%s" % opponent_lane.to_lower().replace(" ", "_"),
	]
	var home_block_adaptation := 0.0
	var reading_blocker := home_block_formation.get("primary") as VolleyballPlayer
	if reading_blocker != null:
		home_block_adaptation = maxf(
			Familiarity.read_modifier(reading_blocker, home_block_read_tags), 0.0
		)
		Familiarity.record_exposure(reading_blocker, home_block_read_tags)
	if home_block_adaptation > 0.0:
		home_block_formation["quality"] = clampf(
			float(home_block_formation.get("quality", 0.0)) + home_block_adaptation,
			0.05, 0.98,
		)
	home_block_formation["adaptation_bonus"] = home_block_adaptation
	## Put the home wall where the home wall is.
	##
	## `_blocker_net_x` reads `live_positions` first and falls back to the
	## blocking team's `court_position` -- but the home side is not an
	## `OpponentTeam`, so this call site passes `null` and the fallback is the
	## literal 0.5 at the end of that function. Home blockers who had not
	## happened to be written into `live_positions` earlier in the rally were
	## therefore all standing at mid-net, so a swing to either pin met nobody:
	## 0 stuffs and 1 deflection across 300 rallies with the geometric attack
	## open. It is also why two home blockers render on top of each other --
	## they were literally at the same coordinate.
	##
	## The positions already existed; they were computed after the swing, for
	## the block event's metadata, and never fed back to the model that needed
	## them. `_block_wall_positions` gives the pair a shoulder offset, so staging
	## both fixes the geometry and the picture at once.
	var home_wall_x := _wall_stage_x(
		opponent_hitter, opponent_contact, opponent_lane, false,
		float(home_block_formation.get("read_quality", 0.0)),
		str(defensive_plan.block_intent) if defensive_plan != null else "Balanced",
	)
	var home_wall_positions := _block_wall_positions(home_wall_x, false)
	var staged_home_primary := home_block_formation.get("primary") as VolleyballPlayer
	var staged_home_assist := home_block_formation.get("assist") as VolleyballPlayer
	## Staged on the opponent's set as well as in `live_positions`, so the wall
	## forms during the set's flight instead of appearing at the net. Same
	## omission as the setter above, made in the same session: the model was
	## given the position and the viewer was given a jump.
	var home_block_stage := {}
	if staged_home_primary != null:
		live_positions[staged_home_primary.id] = Vector2(
			home_wall_positions.primary_position
		)
		home_block_stage[staged_home_primary.id] = Vector2(
			home_wall_positions.primary_position
		)
	if staged_home_assist != null:
		live_positions[staged_home_assist.id] = Vector2(
			home_wall_positions.assist_position
		)
		home_block_stage[staged_home_assist.id] = Vector2(
			home_wall_positions.assist_position
		)
	if not home_block_stage.is_empty():
		var set_event_for_wall := result.events[-1] as RallyEvent
		if set_event_for_wall != null:
			var existing: Dictionary = set_event_for_wall.metadata.get(
				"home_phase_targets", {}
			)
			for raw_id in home_block_stage:
				existing[raw_id] = home_block_stage[raw_id]
			set_event_for_wall.metadata["home_phase_targets"] = existing
	var home_block_pressure := float(
		home_block_formation.get("primary_close", 0.0)
	) * BLOCK_PRIMARY_PRESSURE + float(
		home_block_formation.get("assist_close", 0.0)
	) * BLOCK_ASSIST_PRESSURE
	## Mirrors the home side's demand exactly: a faster tempo asks more of the
	## hitter, and a setter who commands tempo asks less of them.
	var opponent_tempo_demand := float(3 - clampi(opponent_tempo, 0, 3)) * 0.055 \
		* lerpf(1.0, 0.65, _rating(opponent_setter, "tempo_control"))
	var opponent_attack_noise := _execution_error(
		opponent_hitter, "attack_accuracy", ATTACK_EXECUTION_NOISE
	)
	## Provisional: the run-up has not been evaluated yet, so this scores the
	## swing as if the approach were merely adequate. Recomputed below once the
	## real approach exists.
	var opponent_attack := clampf(
		_attack_execution(
			opponent_hitter, opponent_set_quality, 0.5, hitter_arrival_margin,
			opponent_tempo_demand, home_block_pressure,
		) + opponent_attack_noise,
		0.0, 1.0,
	)
	## Gate 43, mirrored. The opponent hitter now has a causal approach instead
	## of a purely geometric mark: responsibility sets their release time, and
	## the resulting run-up changes approach speed, lateral control, usable jump,
	## and which attack families are physically available. Two things depended on
	## this being absent -- the shadow block was reading a hitter-approach cue
	## with nothing behind it, and 2D playback had no staged approach to draw,
	## which is why opponent spikes were unreadable.
	var opponent_state := RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, true,
		rng.seed + exchange_number * 2411,
	)
	opponent_state.simulation_time = maxf(rally_clock - 0.55, 0.0)
	var opponent_hitter_actor := opponent_state.player_state(
		&"opponent", opponent_hitter.id
	)
	if opponent_hitter_actor != null:
		opponent_hitter_actor.apply_position(
			Vector2(attack_choice.start),
			opponent_live_velocities.get(opponent_hitter.id, Vector2.ZERO),
		)
	var opponent_preparation := ApproachMechanicsModel.prepare_for_attack(
		opponent_state, opponent_hitter_actor,
		{
			"player_id": opponent_hitter.id,
			"lane": opponent_lane,
			"tempo": opponent_tempo,
			"target": opponent_contact,
		},
		opponent_setter.id, opponent_set_contact_time + set_flight_time, &"opponent",
	)
	var opponent_prepared := opponent_preparation.get("actor") as RallyPlayerState
	opponent_preparation.erase("actor")
	var opponent_approach_start := _approach_start_position(
		opponent_contact, Vector2(attack_choice.start), true
	)
	if opponent_prepared != null:
		opponent_approach_start = opponent_prepared.position
	## Recompute over the route the hitter actually runs. `attack_choice` timed
	## the trip from where the hitter stood before preparation relocated them to
	## their approach mark, so reporting the staged start with the unstaged
	## duration describes them covering a short leg at a long leg's pace. This is
	## the same defect the movement-fluidity work fixed on the home side, and it
	## only surfaced here once block pressure made continuations common enough to
	## shift the ATTACK phase's timing ratio to 1.083.
	var opponent_leg := _travel(
		opponent_hitter, opponent_approach_start, opponent_contact, "transition",
		null,
		opponent_prepared.velocity if opponent_prepared != null else Vector2.ZERO,
	)
	var opponent_move_time := float(opponent_leg.seconds)
	opponent_live_velocities[opponent_hitter.id] = opponent_leg.exit_velocity
	hitter_arrival_margin = set_flight_time - opponent_move_time
	opponent_contact = _reachable_contact(
		opponent_approach_start, opponent_contact, opponent_move_time,
		set_flight_time,
	)
	hitter_arrival_margin = _clamped_arrival_margin(hitter_arrival_margin)
	## And so does the lane.
	##
	## `opponent_lane` was read off the contact the set *aimed* at, three hundred
	## lines above. The clamp then moves that contact, and everything the lane
	## decides was left pointing at the old one: the wall is restaged below against
	## the new contact but the old lane, familiarity accrues to a lane the hitter
	## did not swing from, and `_geometric_swing` resolves the ball along the old
	## lane's natural course.
	##
	## Measured at 36% of opponent swings (`tools/run_lane_drift_probe.gd`), and
	## not scattered: 40 of the 43 are one migration, Right Quick to Right Pin. A
	## middle who cannot reach the quick gets dragged back down their own approach,
	## which runs outward, and arrives at the pin still labelled a quick.
	##
	## Same clamp and same shape as the stale arrival margin above -- see
	## FAILURE_MODES.md 15. Flagged separately because it is a different
	## consequence with a different blast radius: this one moves the wall and the
	## ball's course, not the hitter's billing.
	if RallyFeatureFlagsModel.ENABLE_CLAMPED_CONTACT_LANE:
		opponent_lane = CourtConstants.lane_at_x(opponent_contact.x)
	## And the wall moves with it.
	##
	## The wall above was staged against the contact the set was *aimed* at.
	## `_reachable_contact` then moves that contact to wherever the hitter can
	## actually get, and nothing re-read it -- so the resolver contested a wall
	## built for a point the ball no longer came from, while the 2D court and the
	## 3D view drew a third position recomputed from the final contact. Three
	## readings of one fact, none of them reconciled.
	##
	## The staged position above stays what it is: it is where the blockers
	## committed during the set's flight, and playback should show them heading
	## there. This is the adjustment they make once the hitter commits, which is
	## what a blocker does and what the resolver has to contest.
	home_wall_x = _wall_stage_x(
		opponent_hitter, opponent_contact, opponent_lane, false,
		float(home_block_formation.get("read_quality", 0.0)),
		str(defensive_plan.block_intent) if defensive_plan != null else "Balanced",
	)
	home_wall_positions = _block_wall_positions(home_wall_x, false)
	if staged_home_primary != null:
		live_positions[staged_home_primary.id] = Vector2(
			home_wall_positions.primary_position
		)
	if staged_home_assist != null:
		live_positions[staged_home_assist.id] = Vector2(
			home_wall_positions.assist_position
		)
	## Rebuilding the arc must not rebuild the clock with it. This passed
	## `rally_clock`, so whenever the reachable-contact clamp moved the target --
	## often -- the retarget silently restamped the set back to the moment of the
	## pass, undoing the release above. The home set and the home continuation
	## both pass their own contact time here; this was the only one that did not.
	_retarget_set_event(
		opponent_set_event, opponent_contact, "opponent_set", set_flight_time,
		float(set_arc.apex_height_meters), opponent_set_contact_time,
	)
	var opponent_approach := ApproachMechanicsModel.evaluate_takeoff(
		opponent_prepared, opponent_contact, set_flight_time
	) if opponent_prepared != null else {}
	var opponent_attack_actions: Array[String] = \
		ApproachMechanicsModel.available_attack_families(
			opponent_hitter, opponent_approach, hitter_arrival_margin
		) if not opponent_approach.is_empty() else ([] as Array[String])
	## A run-up that never happened cannot lend its quality to the swing. This
	## is the same coupling Gate 43 gave the home side, and it now feeds the
	## same execution model rather than a bolt-on adjustment.
	if not opponent_approach.is_empty():
		opponent_attack = clampf(
			_attack_execution(
				opponent_hitter, opponent_set_quality,
				_approach_execution_fit(opponent_hitter, opponent_approach),
				hitter_arrival_margin, opponent_tempo_demand, home_block_pressure,
				## The same familiarity the home swing gets. Omitting it here was
				## worth nine kills to one once the attack started winning.
				Familiarity.attack_geometry(opponent_hitter, opponent_lane)
				+ (Familiarity.execution_modifier(opponent_hitter) - 1.0) * 0.14
				+ (float(opponent_approach.get("jump_multiplier", 1.0)) - 1.0) * 0.18,
			) + opponent_attack_noise,
			0.0, 1.0,
		)
	## Capability shapes this swing too. Unifying the execution model left the
	## opponent as the only one of the three swings paying neither a tempo demand
	## nor an overreach penalty, and on the flat fixture that showed up as
	## opponent swings averaging 0.360 against home swings at 0.264 -- a
	## systematic edge to one side of the net with nothing behind it.
	##
	## The back-off changes the shot and its quality but not where it was aimed:
	## the opponent's target is chosen before the run-up is evaluated, so a
	## downgraded swing still flies at the spot the full swing had picked. That
	## understates the downgrade and is the remaining asymmetry here.
	var opponent_deficit_terms := ApproachMechanicsModel.attack_family_deficit_terms(
		opponent_hitter, opponent_approach, hitter_arrival_margin,
		ApproachMechanicsModel.attack_family_for_hit_type(
			str(attack_choice.attack_type)
		),
	)
	var opponent_swing_deficit := float(opponent_deficit_terms.total)
	var opponent_chosen_type := str(attack_choice.attack_type)
	var opponent_swing_downgraded := AttemptJudgmentModel.backs_off(
		opponent_hitter, opponent_swing_deficit
	)
	if opponent_swing_downgraded:
		attack_choice["attack_type"] = "Roll shot"
		opponent_swing_deficit = ApproachMechanicsModel.attack_family_deficit(
			opponent_hitter, opponent_approach, hitter_arrival_margin,
			ApproachMechanicsModel.attack_family_for_hit_type("Roll shot"),
		)
	if opponent_swing_deficit > 0.0:
		opponent_attack = clampf(
			opponent_attack - opponent_swing_deficit * ATTACK_OVERREACH_SEVERITY,
			0.0, 1.0,
		)
	## The same geometric swing the home first ball resolves in shadow, on the
	## other side of the net. Recording both sides is the point: the symmetry
	## gate measures a six-point home tilt today, and one shared resolver is the
	## most plausible way that goes away -- which can only be checked if both
	## sides are measured through it.
	var opponent_record := _geometric_swing_record(
		_geometric_swing(
			opponent_hitter, opponent_contact,
			opponent_lane, home_block_formation,
			_home_block_fallbacks(players, lineup), live_positions,
			home_defenders, false,
			float(opponent_approach.get("jump_multiplier", 1.0)),
			_approach_execution_fit(opponent_hitter, opponent_approach)
				if not opponent_approach.is_empty() else 0.5,
			## Their swing, their temperament. This read
			## `home_principles.decisiveness` once, so a decisive home identity
			## made the *opponent* swing harder at gaps they had not chosen to
			## take; the fix for that was a literal 0.5, which is the same defect
			## wearing a neutral face -- a side that cannot be aggressive or
			## controlled no matter what its bench believes. It has principles
			## now, so it reads its own.
			float(opponent_principles.decisiveness), 0.0,
			str(defensive_plan.block_intent) if defensive_plan != null \
				else "Balanced",
		),
		"opponent",
	)
	if shadow_reception_trace != null:
		shadow_reception_trace.summary["geometric_attack_opponent"] = opponent_record
	var geometric := _geometric_promotion(opponent_record)
	if not geometric.is_empty():
		home_target = Vector2(geometric.target)

	## Let playback walk the hitter to their approach mark during the set,
	## instead of teleporting them into a swing when the attack event begins.
	if opponent_set_event != null:
		opponent_set_event.metadata["staged_next_actor_id"] = opponent_hitter.id
		opponent_set_event.metadata["staged_next_position"] = opponent_approach_start

	## The swing's shape is solved only now, so the run-up that just adjusted
	## `opponent_attack` also shapes the arc it produces.
	var opponent_net_contact := Vector2(opponent_contact.x, 0.50)
	var opponent_attack_angle := _attack_launch_angle_degrees(
		opponent_hitter, str(attack_choice.attack_type), opponent_attack
	)
	## The full shot, to where it is actually aimed. `_contest_block()`
	## re-slices this to the net if the block touches it; truncating here
	## unconditionally made every opponent spike travel about three percent of
	## the court and the rest arrive as a "deflection".
	var opponent_attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_contact, home_target),
		opponent_attack_angle,
	)
	var opponent_attack_trajectory := _ball_trajectory(
		"attack", opponent_contact, home_target,
		float(opponent_attack_arc.duration_seconds),
		float(opponent_attack_arc.apex_height_meters),
		opponent_set_contact_time + set_flight_time
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id,
		opponent_hitter.display_name,
		opponent_contact, home_target, true, opponent_attack,
		"Opponent transition swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %s toward %s at %d%% quality." % [
			str(attack_choice.attack_type), str(attack_choice.direction),
			roundi(opponent_attack * 100.0),
		],
		{"side": "opponent", "lane_x": opponent_contact.x,
			## Beside `lane_x`, which is the contact this swing was actually struck
			## from, so the two can be compared. The home ATTACK event has always
			## stamped its lane; this one never did.
			"lane": opponent_lane,
			## The contact this swing was *asked* for, beside the one it got.
			## `hitter_start` and `hitter_travel_time` were already stamped, so the
			## only missing term was the ask -- and without it nothing downstream
			## could see how far back the reachability clamp had pushed the swing.
			"ideal_contact": _opponent_attack_contact(
				opponent_team, opponent_hitter
			),
			"set_flight_seconds": set_flight_time,
			"attack_type": attack_choice.attack_type,
			## Both downgrades, separately. `intended_type` is what the position and
			## the set called for, `chosen_type` what the set-quality gate left, and
			## `attack_type` what the run-up left after that. Collapsing the three
			## into one published figure is why "the opponent never spikes" was
			## attributed to the set-quality gate twice before it was measured.
			"intended_type": attack_choice.get("intended_type", ""),
			"chosen_type": opponent_chosen_type,
			"swing_downgraded": opponent_swing_downgraded,
			"swing_deficit_terms": opponent_deficit_terms,
			"swing_runup_quality": float(opponent_approach.get("runup_quality", 0.0)),
			"swing_in_system": bool(opponent_approach.get("approach_in_system", false)),
			"attack_direction": attack_choice.direction,
			"hitter_start": attack_choice.start,
			"hitter_travel_time": attack_choice.travel_time,
			"arrival_margin": hitter_arrival_margin,
			"movement_start": opponent_approach_start,
			"approach_start_position": opponent_approach_start,
			"approach_target_position": Vector2(opponent_preparation.get(
				"approach_target_position", opponent_approach_start
			)),
			"reached_approach_start": bool(opponent_preparation.get(
				"reached_approach_start", true
			)),
			## Why this swing ended the way it did, on the event, so the three
			## attack paths can be compared without re-deriving it. Only the
			## home continuation recorded any of this, which is why an opponent
			## error rate of 0.411 against the home side's 0.184 could be seen
			## and not explained.
			"geometric_outcome": str(geometric.get("outcome", "")),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": bool(geometric.get("attack_missed", false)),
			"transition_preparation": opponent_preparation.duplicate(true),
			"resolved_approach": opponent_approach.duplicate(true),
			"available_attack_actions": opponent_attack_actions.duplicate(),
			"approach_speed_mps": float(opponent_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(opponent_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(opponent_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(opponent_approach.get("approach_in_system", false)),
			"jump_multiplier": float(opponent_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(opponent_approach.get("lateral_control", 0.0)),
			"event_time": opponent_set_contact_time + set_flight_time,
			"launch_angle_degrees": opponent_attack_angle,
			"movement_duration": opponent_move_time,
			"movement_entry_velocity": opponent_prepared.velocity \
				if opponent_prepared != null else Vector2.ZERO,
			"outgoing_trajectory": opponent_attack_trajectory})
	var opponent_attack_event := result.events[-1] as RallyEvent
	opponent_live_positions[opponent_hitter.id] = opponent_contact
	## The opponent could not miss a swing. Not "rarely" -- there was no branch
	## for it anywhere on this path, so every transition ball the opponent hit
	## either beat the block or was dug, and a home hitter who errs at the
	## sport's rate was being compared against an opponent who never errs at
	## all. That is the asymmetry the symmetry gate was written to find, and it
	## closes here because both sides now miss through the same ballistics.
	if not geometric.is_empty() and bool(geometric.attack_missed):
		return _finish(result, "opponent_attack_error", true, opponent_hitter.id, {
			"hitter": opponent_hitter.display_name,
		})
	var block_result := _contest_block(
		home_block_formation, opponent_attack,
		absf(0.50 - opponent_contact.y) * CourtConstants.COURT_LENGTH_METERS,
		str(defensive_plan.block_intent) if defensive_plan != null else "Balanced",
	)
	var blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var home_block := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	if not geometric.is_empty():
		block_outcome = str(geometric.block_outcome)
	if blocker != null:
		live_positions[blocker.id] = Vector2(opponent_contact.x, 0.54)
	if assisting_blocker != null:
		live_positions[assisting_blocker.id] = Vector2(opponent_contact.x, 0.54)
	var deflection_target := home_target
	if block_outcome in ["touch", "funnel"]:
		deflection_target = _home_block_deflection_target(
			home_target, opponent_contact.x, home_block, block_outcome,
			str(defensive_plan.block_defense_relationship) if defensive_plan != null else "Balanced"
		)
	var home_block_target := Vector2(opponent_contact.x, 0.43) \
		if block_outcome == "stuff" else deflection_target
	## Same contract as the two home-attack block paths: only a block that
	## actually touches the ball shortens the shot or deflects it.
	var home_block_contacts := block_outcome != "miss"
	if home_block_contacts and opponent_attack_event != null:
		var opponent_flight: Dictionary = opponent_attack_event.metadata.get(
			"outgoing_trajectory", {}
		)
		var opponent_angle := float(opponent_attack_event.metadata.get(
			"launch_angle_degrees", 12.0
		))
		var opponent_start: Vector2 = Vector2(opponent_flight.get(
			"start_position", opponent_net_contact
		))
		var to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(
				opponent_start, opponent_net_contact
			), opponent_angle,
		)
		opponent_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", opponent_start, opponent_net_contact,
			float(to_block_arc.duration_seconds),
			float(to_block_arc.apex_height_meters),
			float(opponent_flight.get("start_time", rally_clock)),
		)
	## Same correction as the home block's: the ball has to arrive before the
	## hands can touch it.
	var home_block_trajectory := _block_deflection_trajectory(
		opponent_net_contact, home_block_target, block_outcome == "stuff", 0.42,
		_swing_reaches_net(
			opponent_attack_trajectory, opponent_set_contact_time + set_flight_time
		),
	) if home_block_contacts else {}
	var assist_text := ""
	if assisting_blocker != null:
		assist_text = " %s assisted at %d%% close." % [
			assisting_blocker.display_name,
			roundi(float(block_result.assist_close) * 100.0),
		]
	var blocker_id := blocker.id if blocker != null else -1
	var assisting_blocker_id := assisting_blocker.id \
		if assisting_blocker != null else -1
	var floor_phase_positions := _home_floor_phase_positions(
		lineup, defensive_plan, opponent_contact.x,
		blocker_id, assisting_blocker_id, home_wall_x,
	)
	for raw_player_id in floor_phase_positions:
		live_positions[int(raw_player_id)] = Vector2(
			floor_phase_positions[raw_player_id]
		)
	if opponent_attack_event != null:
		opponent_attack_event.metadata["home_phase_targets"] = \
			floor_phase_positions.duplicate(true)
	var blocker_name := blocker.display_name if blocker != null else "No assigned blocker"
	_add_event(result, RallyEventModel.EventType.BLOCK, blocker_id, blocker_name,
		Vector2(opponent_contact.x, 0.53), Vector2(opponent_contact.x, 0.50),
		block_outcome != "miss", home_block,
		"%s · %s" % [blocker_name, block_outcome.capitalize()],
		"Primary close %d%%; block quality %d%%.%s" % [
			roundi(float(block_result.primary_close) * 100.0),
			roundi(home_block * 100.0), assist_text,
		], {"side": "home", "outcome": block_outcome,
			"contest_margin": float(block_result.get("contest_margin", 0.0)),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			"net_height_over_block_meters": float(
				geometric.get("net_height_over_block_meters", 0.0)
			),
			"block_edge_miss_meters": float(
				geometric.get("block_edge_miss_meters", 0.0)
			),
			"net_crossing_x": float(geometric.get("net_crossing_x", 0.5)),
			"adaptation_bonus": home_block_adaptation,
			"home_phase_targets": floor_phase_positions.duplicate(true),
			"primary_close": block_result.primary_close,
			"assist_close": block_result.assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"primary_position": Vector2(home_wall_positions.primary_position),
			"assist_position": Vector2(home_wall_positions.assist_position),
			"deflection_target": deflection_target,
			"coverage_segments": block_result.coverage_segments,
			"setter_pull": block_result.setter_pull,
			"read_quality": block_result.read_quality,
			"opponent_setter_position": opponent_setter_position,
			"event_time": _contact_time(opponent_attack_trajectory, rally_clock),
			"incoming_trajectory": opponent_attack_trajectory,
			"outgoing_trajectory": home_block_trajectory})
	## The mirror of the home side's net-decided point: through the hands, off
	## them and out, or placed off them on purpose. Claimed before the touch and
	## funnel branches, which would otherwise hand the ball back to a home
	## defender who is not going to get it.
	if not geometric.is_empty() and bool(geometric.hitter_point):
		return _finish(result, "opponent_kill", false, -1, {
			"hitter": original_hitter.display_name,
		})
	if block_outcome == "stuff":
		return _finish(result, "counter_block", true, blocker_id, {
			"hitter": original_hitter.display_name,
			"blocker": blocker_name,
		})
	if block_outcome == "touch":
		result.key_factors.append(ExplanationText.factor("block_touch"))
		opponent_attack = maxf(opponent_attack - 0.10 - home_block * 0.05, 0.12)
		home_target = deflection_target
	elif block_outcome == "funnel":
		result.key_factors.append(ExplanationText.factor("block_funnel"))
		opponent_attack = maxf(opponent_attack - 0.035, 0.12)
		home_target = deflection_target
	var attack_type := _opponent_attack_type(home_target)
	## **The dig's flight budget is the flight that was drawn.**
	##
	## This was the whole dig asymmetry, and it was never a defensive defect. The
	## same opponent swing was solved twice with two different launch angles: the
	## drawn arc used the hitter's own shot shape, and the defender's budget was
	## re-solved through `_opponent_attack_type` -- a *defensive* classifier, whose
	## "Short tip" branch covers everything landing inside y 0.80, which is most of
	## the court. So most opponent swings were lobbed at 22-32 degrees for timing
	## purposes and hit flat at 5-14 degrees for drawing purposes.
	##
	## Measured on identical rosters: home defenders got 0.739 s of flight and
	## opponent defenders 0.490 s, and every downstream term inherited exactly that
	## gap -- reaction delay was equal at 0.325 s against 0.333 s, and physical
	## reach differed by 0.74 m purely because one side had 2.5x the time to travel.
	## Three earlier passes chased this as a claim or positioning problem.
	##
	## `attack_type` above still classifies the ball for the *defence* -- which is
	## what it was written for -- and no longer decides how fast it flies.
	var attack_time := float(RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(opponent_contact, home_target),
		_attack_launch_angle_degrees(opponent_hitter, attack_type, opponent_attack),
	).duration_seconds)
	if RallyFeatureFlagsModel.ENABLE_UNIFIED_ATTACK_SHAPE:
		attack_time = float(opponent_attack_trajectory.get("duration", attack_time))
		if block_outcome in ["touch", "funnel"]:
			## Off the hands the ball is going somewhere else, so the remaining
			## flight is genuinely a new solve -- on the hitter's shot shape, not
			## the defence's.
			attack_time = float(RallyKinematics.solve_launch_arc(
				RallyKinematics.court_distance_meters(
					opponent_contact, home_target
				),
				_attack_launch_angle_degrees(
					opponent_hitter, str(attack_choice.attack_type), opponent_attack
				),
			).duration_seconds)
	if block_outcome == "touch":
		attack_time += 0.24
	elif block_outcome == "funnel":
		attack_time += 0.06
	var defense_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		_zones_at_phase_positions(
			defensive_plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE),
			floor_phase_positions,
		),
		home_target, attack_time, "reception",
		## Anyone still getting up from the last ball has that long less to reach
		## this one.
		_recovery_time_penalties(rally_clock),
	)
	var defender := defense_claim.get("player") as VolleyballPlayer
	var defender_arrived := defender != null
	var home_claimed := defender_arrived
	if defender == null:
		defender = _nearest_floor_defender(players, lineup, defensive_plan, home_target)
	if defender == null:
		return _finish(result, "long_rally_loss", false, -1, {
			"hitter": original_hitter.display_name,
		})
	var defense_arrival: Dictionary = defense_claim.get("arrival", {})
	var support_count := int(defense_claim.get("support_count", 0))
	var responsibility_fit := _defensive_responsibility_fit(
		defensive_plan, defender.id, home_target, attack_type
	)
	## The plan's posture is a read, not a bonus bolted onto the result: it tells
	## the defender where the ball is going before it goes there, which is
	## exactly what `read_bonus` carries on the other two dig sites.
	var posture_read := responsibility_fit
	if defensive_plan != null:
		var short_ball := attack_type == "Short tip"
		if defensive_plan.short_ball_posture == "Compress Short":
			posture_read += 0.08 if short_ball else -0.035
		if defensive_plan.defensive_depth == "Deep":
			posture_read += -0.055 if short_ball else 0.035
		elif defensive_plan.defensive_depth == "Shallow":
			posture_read += 0.045 if short_ball else -0.035
	var home_dig_terms := _defense_terms(
		defender,
		float(defense_arrival.get("reach_margin_meters", -1.0)),
		posture_read,
		CoverageModel.reception_body_penalty(
			defender, defense_arrival, opponent_attack
		),
		support_count,
	)
	home_dig_terms["contested_against"] = opponent_attack
	var defense_quality := float(home_dig_terms.quality)
	## Never reaching the ball is already most of what the timing term says; this
	## keeps the hard floor the arrival model asserts separately.
	if not defender_arrived:
		defense_quality = minf(defense_quality, 0.10)
		home_dig_terms["unarrived_floor"] = true
	var defense_success: bool = defender_arrived \
		and _dig_contest(defender, defense_quality, opponent_attack)
	var home_dig_recovery := _dig_recovery(
		defender, home_dig_terms, opponent_attack, opponent_attack_trajectory,
		CoverageModel.court_distance_meters(
			live_positions.get(
				defender.id,
				defensive_plan.defender_position(defender.id, home_target),
			),
			home_target,
		),
	)
	var defender_start: Vector2 = live_positions.get(
		defender.id, defensive_plan.defender_position(defender.id, home_target)
	)
	var defender_move_time := _movement_time(
		defender, defender_start, home_target, "lateral"
	)
	var defender_reach := _reached_point(
		defender, defender_start, home_target, attack_time, "lateral"
	)
	live_positions[defender.id] = defender_reach
	var defense_pass_target := home_target + Vector2(0.03, -0.04)
	## See the mirrored site on the home swing: the continuation's second-contact
	## window is measured from `rally_clock`, so the clock has to reach the dig.
	var home_dig_time := float(opponent_attack_trajectory.get(
		"end_time", rally_clock + attack_time
	))
	rally_clock = maxf(rally_clock, home_dig_time)
	_add_event(result, RallyEventModel.EventType.DEFENSE, defender.id, defender.display_name,
		home_target, defense_pass_target, defense_success,
		defense_quality, "%s defends" % defender.display_name,
		"%d%% defensive contact against a %d%% attack. %s %s" % [
			roundi(defense_quality * 100.0), roundi(opponent_attack * 100.0),
			_responsibility_phrase(defensive_plan, defender.id, attack_type),
			_arrival_phrase(defense_arrival, defender_arrived, support_count),
		], {"side": "home", "dig_terms": home_dig_terms,
			"attack_type": attack_type,
			"planner_floor_center": Vector2(floor_phase_positions.get(
				defender.id, defender_start
			)),
			"home_phase_targets": floor_phase_positions.duplicate(true),
			"responsibility_fit": responsibility_fit,
			"flight_time": attack_time, "arrival": defense_arrival,
			"claimed": home_claimed,
			"support_count": support_count,
			"movement_start": defender_start,
			"movement_target": defender_reach,
			"movement_duration": defender_move_time,
			## The dig happens when the swing reaches the floor, which the
			## swing's own trajectory already states.
			"contact_recovery": home_dig_recovery,
			"contact_control": last_dig_control,
			"incoming_force": last_dig_force,
			"incoming_speed_mps": last_dig_speed,
			"contact_posture": last_dig_posture,
			"recovering_count": _recovering_count(rally_clock),
			"event_time": home_dig_time})
	_note_recovery(defender, home_dig_recovery, home_dig_time)
	result.key_factors.append(ExplanationText.factor(
		"defense_assignment_fit" if responsibility_fit >= 0.02 \
		else "defense_assignment_stretch"
	))
	if not defense_success:
		return _finish(result, "opponent_kill", false, -1, {
			"hitter": original_hitter.display_name,
		})
	if exchange_number >= MAX_EXCHANGES:
		var safety_win: bool = defense_quality + rng.randf_range(-0.18, 0.18) > 0.60
		return _finish(
			result,
			"long_rally_win" if safety_win else "long_rally_loss",
			safety_win,
			defender.id,
			{"hitter": original_hitter.display_name},
		)
	return _resolve_home_continuation(
		result, players, lineup, defender, defense_pass_target,
		opponent_team, defensive_plan, exchange_number, defense_quality,
	)


func _resolve_home_continuation(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defender: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
	## How good the ball arriving at this setter is. A dig that barely stays up
	## and a block touch clawed off the floor are not the same ball as a clean
	## one, and until this existed they were: the transition set read only the
	## setter's own attributes, so a shanked dig produced exactly the set a
	## perfect one did. Every non-terminal contact reset the rally to neutral,
	## which is why only the swing -- the contact that ends a rally -- had any
	## measurable effect on who won it.
	incoming_quality: float = 1.0,
) -> Resource:
	var cont_second_contact := _home_second_contact_candidates(players, lineup)
	var setter := _second_contact_setter(
		cont_second_contact.candidates, defensive_plan,
		lineup.active_setter_id(), defender.id,
	)
	# Preserve contact continuity: the transition set begins where the dig
	# actually finishes instead of teleporting the ball to center court.
	var set_contact := dig_position
	var second_contact_window := 0.68
	var setter_choice := _spatial_setter_choice(
		cont_second_contact.candidates, cont_second_contact.starts,
		defensive_plan, lineup.active_setter_id(), defender.id, setter,
		set_contact, second_contact_window,
	)
	setter = setter_choice.player as VolleyballPlayer
	var setter_start: Vector2 = setter_choice.start
	var setter_move_time := float(setter_choice.travel_time)
	var setter_arrival_margin := second_contact_window - setter_move_time
	var defense_event_for_staging := result.events[-1] as RallyEvent
	if defense_event_for_staging != null:
		defense_event_for_staging.metadata["staged_next_actor_id"] = setter.id
		defense_event_for_staging.metadata["staged_next_position"] = setter_start
	var emergency_setter := setter != null and setter.id != lineup.active_setter_id()
	var hitter := _fallback_hitter(players, lineup, setter.id)
	var assignment := _fallback_assignment(hitter, lineup)
	## The same read the opponent's setter makes, off the same base. This path
	## took `_fallback_assignment`'s literal 3 and never varied it, so a home
	## setter given a clean dig and the judgment to use it ran the same high
	## ball as one scrambling -- and the histogram's `tempo_demand` term of
	## 0.000 on this path was that constant showing up as a cost nobody paid.
	assignment.tempo = _tempo_call(setter, TRANSITION_TEMPO_BASE, incoming_quality)
	var exchange_penalty := float(exchange_number) * 0.04
	## What this setter can actually deliver off this ball.
	##
	## The transition set was the only set in the engine paying neither a
	## capability penalty nor a geometry difficulty -- both passed as literal
	## 0.0 -- and carrying no familiarity term at all. It was also the only one
	## that emitted no `set_terms`, so the gap was invisible to every
	## measurement: the per-path histogram could rank this path and not
	## decompose it. Three of the six things a set is made of reached every set
	## in the game except this one.
	##
	## The reach term is the substantial one here. A setter taking a low, ugly
	## dig is contacting the ball below their standing reach or above what the
	## approach lets them jump to, and that is priced identically for a first
	## ball. It was simply never asked on this path.
	var setter_capability := SetterCapabilityModel.evaluate(
		setter, assignment.tempo, incoming_quality,
		SetterCapabilityModel.pass_contact_height_meters(
			incoming_quality, rng.randf()
		),
		clampf(inverse_lerp(-0.25, 0.45, setter_arrival_margin), 0.0, 1.0),
	)
	## Capability is not permission here either. The first ball abandons a tempo
	## its setter cannot run; a transition ball that cannot be run fast is no
	## different. This is inert today because `_fallback_assignment` always calls
	## tempo 3 and there is nothing slower to fall back to -- the transition
	## tempo is a constant, which is its own recorded defect. Wiring it now means
	## the day that constant becomes a decision, this path already obeys it.
	if bool(setter_capability.tempo_downgraded):
		assignment = _downgraded_assignment(
			assignment, int(setter_capability.resolved_tempo)
		)
	## The lane the setter is aiming at, hoisted above the quality it feeds:
	## difficulty is a property of the attempt, so geometry is read off the
	## intent rather than off where the ball ended up. Same rule as the first
	## ball, which reads `intended_set_target` for exactly this reason.
	var intended_set_target := CourtConstants.lane_target(assignment.lane)
	var cont_release_target: Vector2 = defensive_plan.setter_release_target(
		lineup.active_setter_id()
	) if defensive_plan != null else Vector2(0.50, 0.60)
	var cont_set_geometry := _set_geometry(
		setter, setter_start, set_contact, intended_set_target, cont_release_target
	)
	## A transition set is harder than one off a served ball and the tempo it
	## runs costs something: `exchange_penalty` carries the first, the tempo
	## demand every other set pays carries the second.
	var cont_tempo_demand := float(3 - int(setter_capability.resolved_tempo)) \
		* 0.055 * lerpf(1.0, 0.65, _rating(setter, "tempo_control"))
	var cont_set_terms := _set_terms(
		setter, float(setter_capability.effective_pass_quality),
		exchange_penalty + cont_tempo_demand,
		float(setter_capability.quality_penalty), setter_arrival_margin,
		float(cont_set_geometry.difficulty),
		(Familiarity.execution_modifier(setter) - 1.0) * 0.16,
	)
	var set_quality := clampf(
		float(cont_set_terms.quality)
			+ _execution_error(setter, "set_accuracy", 0.14),
		0.10, 0.92,
	)
	## Same promotion as the first-ball set: the transition set stops landing on
	## its lane's table entry and starts landing where this setter put it.
	var set_target := _delivered_point(
		intended_set_target, set_quality,
		SET_DELIVERY_STDEV_WORST_M, SET_DELIVERY_STDEV_BEST_M,
		HOME_SET_DELIVERY_MIN_Y, HOME_SET_DELIVERY_MAX_Y,
	)
	var continuation_set_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_contact, set_target),
		_set_launch_angle_degrees(setter, assignment.tempo, set_quality),
	)
	var continuation_flight_time: float = float(continuation_set_arc.duration_seconds)
	var cont_release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var cont_release_interval := _release_interval(cont_release_profile, set_quality)
	## The transition set leaves the setter's hands once they have travelled to
	## the dig, taken the ball, and released it. Every later contact in this
	## continuation is timed from that instant, mirroring the main set path --
	## without it the set flight would start after the attack flight it feeds.
	var cont_set_contact_time := rally_clock + second_contact_window + cont_release_interval
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, set_quality >= 0.20, set_quality,
		("Emergency second-contact set" if emergency_setter else "Transition set") \
		+ " · exchange %d" % exchange_number,
		"Contact 2 of 3 after %s's dig · %d%% set quality." % [
			defender.display_name, roundi(set_quality * 100.0),
		], {"side": "home", "set_path": "home_transition",
			"set_terms": cont_set_terms,
			"setter_capability": setter_capability.duplicate(true),
			"set_distance_meters": cont_set_geometry.distance_meters,
			"set_angle_degrees": cont_set_geometry.angle_degrees,
			"body_orientation_fit": cont_set_geometry.body_orientation_fit,
			"emergency_setter": emergency_setter,
			"first_contact_id": defender.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"arrival_margin": setter_arrival_margin,
			"flight_time": continuation_flight_time,
			"release_interval": cont_release_interval,
			"intended_target": intended_set_target,
			"deadline": cont_set_contact_time,
			"event_time": cont_set_contact_time,
			"outgoing_trajectory": _ball_trajectory(
				"set", set_contact, set_target, continuation_flight_time,
				float(continuation_set_arc.apex_height_meters), cont_set_contact_time
			)})
	live_positions[setter.id] = set_contact
	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	var transition_state := RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, true,
		rng.seed + exchange_number * 1009,
	)
	transition_state.simulation_time = maxf(rally_clock - 0.55, 0.0)
	for raw_player_id in transition_state.home_players:
		var phase_actor := transition_state.player_state(&"home", int(raw_player_id))
		if phase_actor != null:
			phase_actor.apply_position(
				Vector2(live_positions.get(
					int(raw_player_id), phase_actor.position
				)),
				live_velocities.get(int(raw_player_id), Vector2.ZERO),
			)
	var hitter_actor := transition_state.player_state(&"home", hitter.id)
	var continuation_assignment := {
		"player_id": hitter.id, "lane": assignment.lane,
		"tempo": assignment.tempo, "priority": assignment.priority,
		"target": set_target,
	}
	var transition_preparation := ApproachMechanicsModel.prepare_for_attack(
		transition_state, hitter_actor, continuation_assignment, defender.id,
		cont_set_contact_time,
	)
	var prepared_hitter := transition_preparation.get("actor") as RallyPlayerState
	transition_preparation.erase("actor")
	if prepared_hitter != null:
		hitter_start = prepared_hitter.position
	var continuation_leg := _travel(
		hitter, hitter_start, set_target, "transition", null,
		prepared_hitter.velocity if prepared_hitter != null else Vector2.ZERO,
	)
	var hitter_move_time := float(continuation_leg.seconds)
	live_velocities[hitter.id] = continuation_leg.exit_velocity
	var hitter_arrival_margin := continuation_flight_time - hitter_move_time
	set_target = _reachable_contact(
		hitter_start, set_target, hitter_move_time, continuation_flight_time
	)
	hitter_arrival_margin = _clamped_arrival_margin(hitter_arrival_margin)
	var set_event_for_staging := result.events[-1] as RallyEvent
	_retarget_set_event(
		set_event_for_staging, set_target, "set", continuation_flight_time,
		float(continuation_set_arc.apex_height_meters), cont_set_contact_time,
	)
	if set_event_for_staging != null:
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
	var continuation_approach := ApproachMechanicsModel.evaluate_takeoff(
		prepared_hitter, set_target, continuation_flight_time
	) if prepared_hitter != null else {}
	var continuation_actions := ApproachMechanicsModel.available_attack_families(
		hitter, continuation_approach, hitter_arrival_margin
	)
	## The wall, formed before the swing is scored rather than after.
	##
	## This path used to pass a block pressure of zero, which made it the only
	## one of the three swings that could not be hurried by hands in front of it:
	## the block was still resolved, but *after* the swing quality already
	## existed, so it could take the ball away and never make the ball harder to
	## hit. Forming here and contesting the same formation below is what the
	## first-ball path already does, and it means one wall does both jobs instead
	## of a wall that only ever arrives too late to matter.
	var cont_formation := _form_opponent_block(
		opponent_team, set_target.x, assignment.tempo, set_quality,
		set_contact.x, continuation_flight_time,
		second_contact_window + cont_release_interval,
	)
	var cont_block_pressure := float(
		cont_formation.get("primary_close", 0.0)
	) * BLOCK_PRIMARY_PRESSURE + float(
		cont_formation.get("assist_close", 0.0)
	) * BLOCK_ASSIST_PRESSURE
	## The third copy of the execution scale, now the same model as the other
	## two. A transition swing is harder than one off a served ball, and
	## `exchange_penalty` is what carries that -- as a demand on the swing, the
	## same slot tempo occupies in the first-ball case.
	var attack_quality := clampf(
		_attack_execution(
			hitter, set_quality,
			_approach_execution_fit(hitter, continuation_approach),
			hitter_arrival_margin, exchange_penalty, cont_block_pressure,
			## The familiarity the other two swings already get. This was the
			## only attack in the game with no exposure term, so a transition
			## hitter could be fed the same lane all match and never be read for
			## it -- half of the scouting system was write-only against them.
			Familiarity.attack_geometry(hitter, assignment.lane)
			+ (Familiarity.execution_modifier(hitter) - 1.0) * 0.14,
		) + _execution_error(hitter, "attack_accuracy", ATTACK_EXECUTION_NOISE),
		0.0, 1.0,
	)
	var continuation_approach_start := Vector2(transition_preparation.get(
		"approach_start_position",
		_approach_start_position(set_target, hitter_start, false)
	))
	## Same rule as the first-ball swing: capability shapes the outcome, it does
	## not remove the option.
	var continuation_hit_type := _hit_type(assignment, hitter)
	var continuation_intended_type := continuation_hit_type
	var continuation_deficit := ApproachMechanicsModel.attack_family_deficit(
		hitter, continuation_approach, hitter_arrival_margin,
		ApproachMechanicsModel.attack_family_for_hit_type(continuation_hit_type),
	)
	var continuation_downgraded := AttemptJudgmentModel.backs_off(
		hitter, continuation_deficit
	)
	if continuation_downgraded:
		continuation_hit_type = "Controlled roll" \
			if "controlled_roll" in continuation_actions else "Emergency tip"
		continuation_deficit = ApproachMechanicsModel.attack_family_deficit(
			hitter, continuation_approach, hitter_arrival_margin,
			ApproachMechanicsModel.attack_family_for_hit_type(continuation_hit_type),
		)
	if continuation_deficit > 0.0:
		attack_quality = clampf(
			attack_quality - continuation_deficit * ATTACK_OVERREACH_SEVERITY,
			0.0, 1.0,
		)
	## The same wall that pressured the swing, now contested against it. Forming
	## it twice would let the block that hurried the hitter and the block that
	## touched the ball be two different blocks.
	##
	## It is resolved here, above the swing's result, because the geometric
	## swing needs the wall in front of it and the swing's result is the thing
	## the geometric path replaces. `_contest_block` draws no randomness, so
	## hoisting it does not move the rally's stream by a single value.
	var cont_opponent_plan := _opponent_defensive_plan(opponent_team)
	var block_result := _contest_block(
		cont_formation, attack_quality, 0.0,
		str(cont_opponent_plan.block_intent) if cont_opponent_plan != null \
			else "Balanced",
	)
	var continuation_defenders: Array[Vector2] = []
	for defender_resource in opponent_team.on_court_players():
		var court_defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if court_defender != null:
			continuation_defenders.append(opponent_live_positions.get(
				court_defender.id,
				opponent_team.court_position(court_defender.id, "defense"),
			))
	## Where this swing is aimed.
	##
	## It used to be `Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))`:
	## straight back over the setter's line, at a uniformly random depth. The
	## other two swings call `_choose_attack_target`, which reads
	## `attack_accuracy`, `shot_variety` and `decision_making`, scans the court
	## for the gap, and errs by an amount the hitter's accuracy decides. On this
	## path none of those attributes touched the ball and the defenders standing
	## in the court were invisible to it -- a transition hitter aimed the same
	## way whether they were the best finisher on the roster or the worst.
	##
	## The contact passed is `set_target`, the point the ball is actually struck
	## from after the reachability clamp, rather than the lane table entry the
	## first ball still hands it. That difference is deliberate and is the first
	## ball's to fix, not this one's.
	var attack_choice := _choose_attack_target(
		hitter, set_target, continuation_hit_type, continuation_defenders
	)
	var attack_target: Vector2 = attack_choice.target
	## The third swing, against the wall this path actually forms.
	var cont_wall_plan := _opponent_defensive_plan(opponent_team)
	var transition_record := _geometric_swing_record(
		_geometric_swing(
			hitter, set_target, str(assignment.lane), block_result,
			_opponent_block_fallbacks(opponent_team), opponent_live_positions,
			continuation_defenders, true,
			float(continuation_approach.get("jump_multiplier", 1.0)),
			_approach_execution_fit(hitter, continuation_approach),
			float(home_principles.decisiveness), 0.0,
			str(cont_wall_plan.block_intent) if cont_wall_plan != null \
				else "Balanced",
		),
		"transition",
	)
	if shadow_reception_trace != null:
		shadow_reception_trace.summary["geometric_attack_transition"] = transition_record
	var geometric := _geometric_promotion(transition_record)
	var intended_attack_target := attack_target
	var attack_missed := _attack_missed(attack_quality)
	if not geometric.is_empty():
		attack_missed = bool(geometric.attack_missed)
		attack_target = Vector2(geometric.target)
	elif attack_missed:
		attack_target = _errant_attack_target(intended_attack_target, attack_quality)
	## One shot shape, used both for the full flight and -- if a block touches
	## it -- for the re-sliced leg to the net, so the two describe the same ball.
	var continuation_attack_angle := _attack_launch_angle_degrees(
		hitter, continuation_hit_type, attack_quality
	)
	var continuation_attack_arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(set_target, attack_target),
		continuation_attack_angle,
	)
	var continuation_attack_flight: float = float(continuation_attack_arc.duration_seconds)
	## Named rather than inlined into the event: the dig below reads this same
	## trajectory's `end_time` so the two contacts agree on when the ball landed.
	var continuation_attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, continuation_attack_flight,
		float(continuation_attack_arc.apex_height_meters),
		cont_set_contact_time + continuation_flight_time,
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, attack_quality >= 0.25, attack_quality,
		"T3 outside swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %d%% attack quality." % roundi(attack_quality * 100.0),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": continuation_hit_type,
			"intended_type": continuation_intended_type,
			"swing_downgraded": continuation_downgraded,
			"intended_target": intended_attack_target,
			"geometric_outcome": str(geometric.get("outcome", "")),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": attack_missed,
			"movement_start": hitter_start,
			"approach_start_position": continuation_approach_start,
			"approach_target_position": Vector2(transition_preparation.get(
				"approach_target_position", continuation_approach_start
			)),
			"reached_approach_mark": bool(transition_preparation.get(
				"reached_approach_start", true
			)),
			"transition_preparation": transition_preparation.duplicate(true),
			"resolved_approach": continuation_approach.duplicate(true),
			"available_attack_actions": continuation_actions.duplicate(),
			"approach_speed_mps": float(continuation_approach.get("approach_speed_mps", 0.0)),
			"approach_quality": float(continuation_approach.get("runup_quality", 0.0)),
			"approach_distance_meters": float(continuation_approach.get(
				"approach_distance_meters", 0.0
			)),
			"approach_in_system": bool(continuation_approach.get(
				"approach_in_system", false
			)),
			"jump_multiplier": float(continuation_approach.get("jump_multiplier", 1.0)),
			"lateral_control": float(continuation_approach.get("lateral_control", 0.0)),
			"movement_duration": hitter_move_time,
			"movement_entry_velocity": prepared_hitter.velocity \
				if prepared_hitter != null else Vector2.ZERO,
			"arrival_margin": hitter_arrival_margin,
			"set_flight_time": continuation_flight_time,
			"flight_time": continuation_attack_flight,
			"event_time": cont_set_contact_time + continuation_flight_time,
			"outgoing_trajectory": continuation_attack_trajectory})
	live_positions[hitter.id] = set_target
	## The continuation now owns a real timeline instead of stamping every
	## contact with the dig's clock: set contact, then the set flight, then the
	## attack. Later contacts read `rally_clock` and inherit it.
	rally_clock = cont_set_contact_time + continuation_flight_time
	if attack_missed:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	var opponent_blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var primary_close := float(block_result.primary_close)
	var assist_close := float(block_result.assist_close)
	var block_quality := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	if not geometric.is_empty():
		block_outcome = str(geometric.block_outcome)
	var blocked := block_outcome == "stuff"
	## Same contract as the main attack path: a block only shortens the shot if
	## it actually touches it, and an untouched ball carries no deflection leg.
	## Without this the continuation attack flew its full arc *and* the block
	## emitted an overlapping path from the net, so the ball was described in
	## two places at once.
	var cont_block_contacts := blocked \
		or block_outcome in ["recycle", "touch", "funnel"]
	## Same blocker staging as the first-ball path: form the wall during the
	## set's flight rather than during the attack-to-block segment, which can be
	## a seventh of a second.
	var cont_wall_x := _wall_stage_x(
		hitter, set_target, str(assignment.lane), true,
		float(block_result.get("read_quality", 0.0)),
		str(cont_wall_plan.block_intent) if cont_wall_plan != null else "Balanced",
	)
	var cont_wall := _block_wall_positions(cont_wall_x, true)
	var cont_block_stage := {}
	if opponent_blocker != null:
		cont_block_stage[opponent_blocker.id] = Vector2(cont_wall.primary_position)
	if assisting_blocker != null:
		cont_block_stage[assisting_blocker.id] = Vector2(cont_wall.assist_position)
	var cont_floor_stage := _floor_phase_positions(
		opponent_team.current_lineup(), _opponent_defensive_plan(opponent_team),
		set_target.x,
		opponent_blocker.id if opponent_blocker != null else -1,
		assisting_blocker.id if assisting_blocker != null else -1,
		true, cont_wall_x,
	)
	for raw_floor_id in cont_floor_stage:
		var floor_id := int(raw_floor_id)
		if not cont_block_stage.has(floor_id):
			cont_block_stage[floor_id] = Vector2(cont_floor_stage[raw_floor_id])
	for raw_player_id in cont_block_stage:
		opponent_live_positions[int(raw_player_id)] = Vector2(
			cont_block_stage[raw_player_id]
		)
	if not cont_block_stage.is_empty():
		(result.events[-1] as RallyEvent).metadata["opponent_phase_targets"] = \
			cont_block_stage
	var cont_net_contact := Vector2(set_target.x, 0.50)
	var block_event_end := Vector2(set_target.x, 0.50) if not blocked \
		else Vector2(set_target.x, 0.47)
	if cont_block_contacts:
		var cont_attack_event: Resource = result.events[-1]
		var cont_to_block_arc := RallyKinematics.solve_launch_arc(
			RallyKinematics.court_distance_meters(set_target, cont_net_contact),
			continuation_attack_angle,
		)
		cont_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, cont_net_contact,
			float(cont_to_block_arc.duration_seconds),
			float(cont_to_block_arc.apex_height_meters),
			cont_set_contact_time + continuation_flight_time,
		)
	var block_event_detail := "Primary close %d%%; block quality %d%%." % [
		roundi(primary_close * 100.0), roundi(block_quality * 100.0),
	]
	if assisting_blocker != null:
		block_event_detail += " %s assisted at %d%% close." % [
			assisting_blocker.display_name, roundi(assist_close * 100.0)
		]
	_add_event(result, RallyEventModel.EventType.BLOCK,
		opponent_blocker.id if opponent_blocker != null else -1,
		opponent_blocker.display_name if opponent_blocker != null else "Open block",
		Vector2(set_target.x, 0.47),
		block_event_end, blocked, block_quality,
		"Opponent block · exchange %d" % exchange_number,
		block_event_detail, {"side": "opponent", "outcome": block_outcome,
		"primary_close": primary_close, "assist_close": assist_close,
		"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
		"primary_position": Vector2(cont_wall.primary_position),
		"assist_position": Vector2(cont_wall.assist_position),
		"coverage_segments": block_result.coverage_segments,
		"setter_pull": block_result.setter_pull,
		"read_quality": block_result.read_quality,
		"event_time": _swing_reaches_net(continuation_attack_trajectory, rally_clock),
		## The swing this block is contesting. The continuation block was the one
		## contact in the engine with no incoming arc at all, so playback had to
		## infer where the ball came from and the stamp above had nothing to derive
		## itself from.
		"incoming_trajectory": continuation_attack_trajectory,
		"outgoing_trajectory": _block_deflection_trajectory(
			cont_net_contact, block_event_end, blocked, 0.42,
			_swing_reaches_net(continuation_attack_trajectory, rally_clock),
		) if cont_block_contacts else {}})
	if not geometric.is_empty() and bool(geometric.hitter_point):
		result.key_factors.append(ExplanationText.factor("attack_control"))
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": "Default T3 Outside",
		})
	if blocked:
		return _finish(result, "blocked", false, hitter.id, {"hitter": hitter.display_name})
	## A transition dig is the same act as any other; the defender is simply
	## already in the rally rather than reading a first-ball swing. It was not
	## treated as one: this path took the roster's best digger regardless of
	## where the ball went, and handed `_defense_execution` a flat zero arrival
	## margin -- a defender who is always exactly on time for a ball they never
	## had to move to, chosen by a search that could not lose.
	## A deflected ball takes longer to arrive, and the defender behind it gets
	## that time. Both other dig sites already add it -- the home dig off an
	## opponent swing and the opponent dig off the home first ball -- and this one
	## did not, so the same block touch bought the home defence 0.24 s and bought
	## this defence nothing. Three sites, one rule.
	var cont_defense_time := continuation_attack_flight
	if block_outcome == "touch":
		cont_defense_time += 0.24
	elif block_outcome == "funnel":
		cont_defense_time += 0.06
	var cont_defense := _choose_opponent_defender(
		opponent_team, attack_target, cont_defense_time
	)
	var opponent_defender := cont_defense.player as VolleyballPlayer
	## What this defender knows, and what their body costs them.
	##
	## Both were passed as literal 0.0, which made this the one dig in the engine
	## with no read at all: no scouting, no adaptation, no plan, and no posture
	## penalty either. The other two dig sites build both from models that
	## already exist, and this path simply never called them. Every term below is
	## the same call the opponent's first-ball dig makes.
	var cont_read_tags: Array[String] = [
		"hand:%s" % hitter.dominant_hand.to_lower(),
		"attack:%s" % str(attack_choice.direction).to_lower().replace("-", "_"),
	]
	var cont_read_modifier := Familiarity.read_modifier(
		opponent_defender, cont_read_tags, float(opponent_team.scouting_confidence)
	)
	var cont_floor_bonus := _opponent_floor_defense_adaptation_bonus(
		opponent_team, assignment.lane
	)
	## `_opponent_attack_type` classifies a landing point in home-court
	## coordinates, so the ball is mirrored into that frame rather than handed a
	## shot name none of its branches would match.
	var cont_posture_read := _defensive_responsibility_fit(
		cont_opponent_plan, opponent_defender.id, attack_target,
		_opponent_attack_type(Vector2(attack_target.x, 1.0 - attack_target.y)),
	)
	var cont_dig_terms := _defense_terms(
		opponent_defender, float(cont_defense.reach_margin_meters),
		cont_read_modifier + cont_floor_bonus + cont_posture_read,
		CoverageModel.reception_body_penalty(
			opponent_defender, Dictionary(cont_defense.get("arrival", {})),
			attack_quality,
		),
		int(cont_defense.get("support_count", 0)),
	)
	cont_dig_terms["contested_against"] = attack_quality
	## A read is only worth having if something was recorded to read. The
	## first-ball dig logs its exposure here; this one never did, so the
	## familiarity term above would have stayed at its neutral value for the
	## whole match no matter how often the same hitter took the same lane.
	Familiarity.record_exposure(opponent_defender, cont_read_tags)
	var defense_quality := float(cont_dig_terms.quality)
	var dug: bool = _dig_contest(opponent_defender, defense_quality, attack_quality)
	var cont_dig_recovery := _dig_recovery(
		opponent_defender, cont_dig_terms, attack_quality,
		continuation_attack_trajectory, float(cont_defense.distance_meters),
	)
	## This branch carried no spatial metadata at all, so playback fell back to
	## the contact point and walked the digger there from wherever they stood,
	## however far that was. The dig outcome above is unchanged -- only the
	## journey drawn to it is now the one they could make.
	var transition_defender_start: Vector2 = opponent_live_positions.get(
		opponent_defender.id,
		opponent_team.court_position(opponent_defender.id, "defense"),
	) if opponent_defender != null else attack_target
	var transition_defender_reach := _reached_point(
		opponent_defender, transition_defender_start, attack_target,
		continuation_attack_flight, "lateral",
	)
	if opponent_defender != null:
		opponent_live_positions[opponent_defender.id] = transition_defender_reach
	var cont_dig_time := float(continuation_attack_trajectory.get(
		"end_time", rally_clock + continuation_attack_flight
	))
	rally_clock = maxf(rally_clock, cont_dig_time)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name, attack_target,
		attack_target + Vector2(0.04, -0.03), dug, defense_quality,
		"Opponent dig · exchange %d" % exchange_number,
		"Contact 1 of 3 · %d%% control." % roundi(defense_quality * 100.0),
		{"side": "opponent",
			"movement_start": transition_defender_start,
			"movement_target": transition_defender_reach,
			## The dig happens when the swing reaches the floor, which the
			## swing's own trajectory already states.
			"contact_recovery": cont_dig_recovery,
			"contact_control": last_dig_control,
			"incoming_force": last_dig_force,
			"incoming_speed_mps": last_dig_speed,
			"contact_posture": last_dig_posture,
			"recovering_count": _recovering_count(rally_clock),
			"event_time": cont_dig_time})
	_note_recovery(opponent_defender, cont_dig_recovery, cont_dig_time)
	if not dug:
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": "Default T3 Outside",
		}, "kill_default")
	return _resolve_opponent_transition(
		result, players, lineup, hitter, attack_target,
		opponent_team, defensive_plan, exchange_number + 1, defense_quality,
		false, opponent_defender.id,
	)


## The block that forms against this attack, before the swing is contested.
##
## Split out because attack quality needs to know what it is hitting into. The
## close fractions depend on the lane, the tempo and the set -- none of which
## need the attack's own quality -- so the formation can be resolved first and
## the contest settled afterwards with the same numbers, rather than the swing
## being scored against nothing and the block appearing only after the fact.
func _form_opponent_block(
	opponent_team: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	setter_x: float,
	set_flight_time: float,
	## Seconds between the pass and the set leaving the setter's hands. The
	## block is already reading and moving through this.
	preset_window_seconds: float = 0.0,
) -> Dictionary:
	var lineup: RotationLineup = opponent_team.current_lineup() if opponent_team != null else null
	var front_blockers: Array[VolleyballPlayer] = []
	var setter_pull := {}
	if opponent_team == null or lineup == null:
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	for player_id in lineup.front_row_player_ids():
		var player := opponent_team.player_by_id(player_id) as VolleyballPlayer
		if player != null:
			front_blockers.append(player)
			var slot_number := lineup.slot_for_player(player.id)
			var start: Vector2 = CourtConstants.slot_position(slot_number)
			var discipline := clampf(
				(_rating(player, "tactical_discipline") * 0.65
				+ _rating(player, "anticipation") * 0.35), 0.0, 1.0
			)
			var pull_weight := (1.0 - discipline) * 0.18
			var pulled_x := lerpf(start.x, setter_x, pull_weight)
			setter_pull[player.id] = absf(pulled_x - start.x)
	if front_blockers.is_empty():
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	var primary: VolleyballPlayer
	var primary_distance := 1000.0
	for candidate in front_blockers:
		var slot_number := lineup.slot_for_player(candidate.id)
		var candidate_x := CourtConstants.slot_position(slot_number).x
		var distance := absf(candidate_x - attack_x)
		if distance < primary_distance:
			primary = candidate
			primary_distance = distance
	## How long the blockers actually have: the set's own flight time, which the
	## kinematics solver already produced from real distance and launch angle.
	##
	## This used to be `0.30 + tempo * 0.045 + (1 - set_quality) * 0.18` -- a
	## table that gave a middle blocker 0.30 s of movement to cover 2.9 m of net,
	## which is physically impossible, so double blocks formed in 1% of rallies
	## and tempo could not change the block. Flight time already encodes tempo: a
	## quick set lands in a fraction of the time a high ball takes, so the middle
	## closes on a high ball and does not on a quick one. That is the whole
	## tempo-versus-block dynamic, and it now falls out of the ball's own physics
	## rather than a constant.
	var read_total := 0.0
	for reader in front_blockers:
		read_total += _blocker_read_quality(reader, tempo, set_quality, setter_x)
	var read_quality := read_total / maxf(float(front_blockers.size()), 1.0)
	## The pre-set window is only worth what a blocker can do with it, and what
	## they can do with it is decided by their read. During that time nobody
	## knows where the set is going: a blocker who reads the pass and the
	## setter's body moves early and moves the right way, while one who does not
	## has to wait for the release. A flat share gave every blocker the good
	## version of that and made the wall far too strong -- 0.19 stuffs and 0.64
	## touched -- while leaving reading worth nothing.
	var preset_share := lerpf(
		BLOCK_PRESET_SHARE_MISREAD, BLOCK_PRESET_SHARE_READ, read_quality
	)
	var close_time := maxf(set_flight_time, 0.0) \
		+ maxf(preset_window_seconds, 0.0) * preset_share \
		+ (1.0 - set_quality) * 0.10
	close_time += lerpf(-0.09, 0.09, read_quality)
	## The same commitment the home block pays for. `_form_home_block` shifts
	## its closing window by `(block_commitment - 0.5) * 0.18`, so a Physical
	## home side (0.82) reaches its wall while a Defensive one (0.26) holds back
	## and plays the floor. This side had no such term at all, which made the
	## block philosophy a home-only lever on an axis both benches should own.
	close_time += (float(opponent_principles.block_commitment) - 0.5) * 0.18
	var primary_close := _blocker_close_fraction(
		primary, lineup, attack_x, close_time
	)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var close_fraction := _blocker_close_fraction(
			candidate, lineup, attack_x, close_time
		)
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	var block_quality := _block_wall_quality(primary_skill, assist_skill)
	return {
		"primary": primary,
		"assist": assist,
		"primary_close": primary_close,
		"assist_close": assist_close,
		"quality": block_quality,
		"coverage_segments": _home_block_segments(
			attack_x, primary, primary_close, assist, assist_close
		),
		"setter_pull": setter_pull,
		"read_quality": read_quality,
	}


## Settles a formed block against the swing that was actually hit at it. One
## copy, both sides of the net, every exchange.
## What a block intends, as three shifts to the outcome bands.
##
## The bands must stay ordered -- funnel below touch below stuff -- so an intent
## moves all three rather than one, and what it really changes is the *width* of
## the band where the block gets a piece of the ball without ending the rally.
##
## Sealing narrows it from both directions: the wall is committed, so it either
## beats the swing outright or the swing goes past it. Funnelling widens it: the
## block is not trying to end the rally, it is trying to slow the ball down and
## put it somewhere the floor is already standing. That is the whole tactical
## choice, and it is a real one -- a terminal block wins points a funnel does
## not, and a funnel keeps rallies alive that a beaten seal loses.
static func _block_intent_margins(intent: String) -> Dictionary:
	## Sized against the same distribution the bands are. The previous shifts moved
	## the touch rung by 0.015 between the two intents -- a fortieth of the spread --
	## and asked a sample of fifty blocks to resolve it. That is not a dial, it is
	## noise with a name, and it is why the two intents came out tied at twenty
	## partials each once the opponent started swinging.
	##
	## These move real shares: a seal's stuff rung sits about six points of the
	## distribution lower than a funnel's, and a funnel's own rung sits sixteen
	## points below a seal's, so the tactical choice shows up in tens of events
	## rather than in ones.
	match intent:
		"Seal":
			return {"stuff": -0.06, "touch": -0.02, "funnel": 0.09}
		"Funnel":
			return {"stuff": 0.09, "touch": -0.03, "funnel": -0.07}
	return {"stuff": 0.0, "touch": 0.0, "funnel": 0.0}


func _contest_block(
	formation: Dictionary,
	attack_quality: float,
	contact_depth_from_net: float = 0.0,
	block_intent: String = "Balanced",
) -> Dictionary:
	var resolved := formation.duplicate(true)
	resolved["primary"] = formation.get("primary")
	resolved["assist"] = formation.get("assist")
	## A swing taken off the net is harder to block, and the block model had no
	## term for it: it read lane alignment and timing only, so a ball struck
	## three metres back was contested exactly like one struck at the tape. That
	## did not matter while every attack contacted at the net. It started
	## mattering the moment hitters were allowed to swing from where they could
	## actually reach, which pushed the mean opponent contact from the tape to
	## roughly a metre and a half behind it and pushed the stuff rate through its
	## balance ceiling.
	var depth_relief := clampf(
		contact_depth_from_net / BLOCK_DEPTH_RELIEF_FULL_METERS, 0.0, 1.0
	) * BLOCK_DEPTH_RELIEF_WEIGHT
	var block_quality := maxf(float(formation.get("quality", 0.0)) - depth_relief, 0.0)
	var primary_close := float(formation.get("primary_close", 0.0))
	## A terminal stuff needs the block to clearly beat the swing and to have
	## sealed the lane, not merely to have edged it. These margins were set
	## against a block whose quality sat in a 0.04-wide band; once quality spread
	## across 0.43-0.77 the old +0.14 margin turned a third of all attacks into
	## stuff blocks.
	var contest := block_quality + _execution_error(
		formation.get("primary") as VolleyballPlayer, "block_timing", 0.13
	)
	var intent_shift := _block_intent_margins(block_intent)
	var outcome := "miss"
	if contest > attack_quality + BLOCK_STUFF_MARGIN + float(intent_shift.stuff) \
			and primary_close >= 0.78:
		outcome = "stuff"
	elif contest > attack_quality + BLOCK_TOUCH_MARGIN + float(intent_shift.touch):
		outcome = "touch"
	elif contest > attack_quality + BLOCK_FUNNEL_MARGIN + float(intent_shift.funnel):
		outcome = "funnel"
	resolved["outcome"] = outcome
	resolved["block_intent"] = block_intent
	## How far the block's contest exceeded the swing, which is the single number
	## all three bands are thresholds on. Reported so the bands can be set from the
	## distribution they cut rather than from the outcomes they happened to produce.
	resolved["contest_margin"] = contest - attack_quality
	return resolved


## Formation and contest together, for callers that do not need to score an
## attack against the block first.
func _resolve_opponent_block(
	opponent_team: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	attack_quality: float,
	setter_x: float,
	set_flight_time: float,
	preset_window_seconds: float = 0.0,
) -> Dictionary:
	return _contest_block(
		_form_opponent_block(
			opponent_team, attack_x, tempo, set_quality, setter_x,
			set_flight_time, preset_window_seconds,
		),
		attack_quality,
	)


func _attack_coverage_target(set_target: Vector2, block_quality: float) -> Vector2:
	var spread := lerpf(0.14, 0.05, clampf(block_quality, 0.0, 1.0))
	return Vector2(
		clampf(set_target.x + rng.randf_range(-spread, spread), 0.08, 0.92),
		rng.randf_range(0.54, 0.70),
	)


## Search resolution for open-floor scanning. These are sample points for a
## search across the whole legal court, NOT a menu of permitted targets: the
## chosen point is continuously perturbed afterwards, so landing spots form a
## distribution over the floor rather than clustering on a handful of dots.
const ATTACK_SCAN_COLUMNS: int = 13
const ATTACK_SCAN_ROWS: int = 9
const ATTACK_COURT_MIN := Vector2(0.055, 0.055)
const ATTACK_COURT_MAX := Vector2(0.945, 0.445)

## How far past the line a missed attack lands, how far onto the hitter's own
## side a netted one drops, and how far below the error threshold a swing has
## to be before it goes into the net rather than out.
##
## Stated in metres and converted per axis rather than kept as one normalized
## number, because the two axes are not the same scale: the court is 9 m across
## and 18 m deep, so a single normalized overshoot puts a wide ball twice as far
## out as a long one. The first version of this used a flat 0.045 normalized
## units and landed *inside* the painted lines -- 0.09 m in from the sideline,
## 0.18 m in from the endline -- because the renderer maps normalized 0 and 1
## onto the lines themselves. The ball was correctly ruled out and still drawn
## in, which is the exact complaint this was meant to fix.
const ATTACK_ERROR_OVERSHOOT_METERS: float = 0.60
const ATTACK_NET_ERROR_DROP_METERS: float = 0.50
const ATTACK_NET_ERROR_FRACTION: float = 0.5


## Where a swing that misses actually lands.
##
## The error verdict is read off `attack_quality` *after* the ATTACK event has
## been emitted, and used to leave the trajectory pointed at the target the
## hitter intended. Playback therefore drew the ball landing cleanly inside the
## court and then ended the rally with "the attack misses the court": the ball
## appeared to vanish at the end of a legal-looking arc. An error has to move
## the ball, not just the scoreline.
##
## The miss is pushed past whichever line the intended target was already
## nearest, so a cross-court swing sails wide and a deep swing sails long
## rather than every error teleporting to one arbitrary spot. A swing with
## almost nothing behind it goes into the net instead, which is what a badly
## mistimed attack actually does. Deterministic on purpose -- it reads only the
## intended target and the quality that already decided the outcome, so a
## replayed seed still draws the identical miss.
## What the hitter is given, against what they need -- in **two windows**, because
## the approach is paid for out of two different clocks.
##
## The first version of this charged both legs against the set's flight and reported
## a deficit on 100% of attacks. That was wrong, and the way it was caught is worth
## keeping: the same measurement also said the approach model reached its mark on
## 100% of attacks, and two measures of one event cannot both be right when they
## disagree completely. The approach model was the honest one.
##
## `ApproachMechanicsSystem.prepare_for_attack()` runs the walk to the approach mark
## during `set_contact_time - release_time` -- the window between the hitter being
## released from their previous duty and the setter touching the ball. That leg is
## already over when the set goes up. Only the **run-up** competes with the set's
## flight.
##
## So there are two budgets and they must not be added:
##
## - **preparation:** the walk to the mark, against the pre-set window.
## - **run-up:** the approach itself, against the set's flight.
##
## Both are reported. Adding them charges the walk twice and inflates the deficit by
## roughly a second, which is how a real 0.13 s overrun at third tempo came out as
## 1.02 s and made the compromise branch look like it would fire on everything.
func _approach_budget(
	hitter: VolleyballPlayer,
	standing_at: Vector2,
	preparation: Dictionary,
	contact_point: Vector2,
	set_flight_seconds: float,
	tempo: int,
) -> Dictionary:
	if hitter == null:
		return {}
	var ideal_mark := Vector2(preparation.get("approach_target_position", standing_at)) \
		if not preparation.is_empty() else standing_at
	var to_mark := _movement_time(hitter, standing_at, ideal_mark, "transition")
	var run_up := _movement_time(hitter, ideal_mark, contact_point, "transition")
	## What the model actually allowed for the walk. Zero when the hitter was
	## released at or after the set, which is its own kind of squeeze.
	var preparation_window := float(preparation.get("preparation_time_seconds", 0.0))
	return {
		"tempo": tempo,
		## The run-up's clock, which is the one the tempo chain is about.
		"available_seconds": set_flight_seconds,
		"required_seconds": run_up,
		"deficit_seconds": run_up - set_flight_seconds,
		## The walk's clock, kept separate.
		"preparation_window_seconds": preparation_window,
		"to_mark_seconds": to_mark,
		"preparation_deficit_seconds": to_mark - preparation_window,
		"run_up_seconds": run_up,
		## Where the mark ended up, so its ball-to-ball spread can be measured. A
		## mark that does not move with the delivered set would show a spread of
		## zero, and the walk to it would be the same length every rally.
		"ideal_mark": ideal_mark,
		"contact_point": contact_point,
		## Whether the hitter got to the mark they were aiming at, which the approach
		## model decides. This should now agree with `preparation_deficit_seconds`
		## rather than contradict it -- if it does not, one of the two is still wrong.
		"reached_ideal_mark": bool(preparation.get("reached_approach_start", true)),
	}


func _errant_attack_target(intended: Vector2, attack_quality: float) -> Vector2:
	var lane_x := clampf(intended.x, ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x)
	var wide_overshoot := ATTACK_ERROR_OVERSHOOT_METERS / CourtConstants.COURT_WIDTH_METERS
	var deep_overshoot := ATTACK_ERROR_OVERSHOOT_METERS / CourtConstants.COURT_LENGTH_METERS
	if attack_quality < ATTACK_ERROR_THRESHOLD * ATTACK_NET_ERROR_FRACTION:
		## Into the net: the ball is stopped by the tape and drops on the
		## hitter's own side of it, which is past `NET_Y` rather than short of
		## it -- the opponent's court is the half with the *smaller* y.
		return Vector2(lane_x, CourtConstants.NET_Y
			+ ATTACK_NET_ERROR_DROP_METERS / CourtConstants.COURT_LENGTH_METERS)
	var to_left := intended.x - ATTACK_COURT_MIN.x
	var to_right := ATTACK_COURT_MAX.x - intended.x
	## Y decreases toward the opponent baseline, so the endline is the floor.
	var to_endline := intended.y - ATTACK_COURT_MIN.y
	## Measured from the court boundary the renderer actually paints -- 0 and 1,
	## not `ATTACK_COURT_MIN`/`MAX`, which are the inset margin the targeting
	## search aims within. Landing past the inset but inside the line is what
	## made a called-out ball look in.
	if to_endline <= to_left and to_endline <= to_right:
		return Vector2(lane_x, -deep_overshoot)
	if to_left <= to_right:
		return Vector2(-wide_overshoot, intended.y)
	return Vector2(1.0 + wide_overshoot, intended.y)

## The same three numbers for a serve, and the same reasoning behind them.
##
## A serve misses in one of three ways and the tape is the commonest, so the
## net channel is entered on a wider band of quality than the attack's.
const SERVE_ERROR_OVERSHOOT_METERS: float = 0.60
const SERVE_NET_ERROR_DROP_METERS: float = 0.50
const SERVE_NET_ERROR_QUALITY: float = 0.42


## Where a serve that misses actually lands.
##
## `_serve_landing_point` clamps its result to the receiving half -- x into
## [0.06, 0.94] and y into the legal depth band -- so it is structurally
## incapable of producing a ball that is out. The error verdict is a separate
## coin flip against `_serve_error_chance`, taken before the landing point is
## computed and never fed into it, so a serve ruled out was drawn landing
## cleanly inside the court and the rally then ended with "the serve does not
## enter the court". That is the same defect `_errant_attack_target` was written
## for, on the one contact that starts every rally, and it went unfixed because
## the attack fix was made where the attack was wrong rather than where the
## engine was.
##
## Deterministic, like the attack version: it reads the intended target and the
## quality that already decided the outcome, so a replayed seed draws the
## identical miss.
func _errant_serve_landing(
	intended: Vector2,
	serve_quality: float,
	landing_on_home_side: bool,
) -> Vector2:
	var wide_overshoot := SERVE_ERROR_OVERSHOOT_METERS \
		/ CourtConstants.COURT_WIDTH_METERS
	var deep_overshoot := SERVE_ERROR_OVERSHOOT_METERS \
		/ CourtConstants.COURT_LENGTH_METERS
	var net_drop := SERVE_NET_ERROR_DROP_METERS / CourtConstants.COURT_LENGTH_METERS
	var lane_x := clampf(intended.x, 0.06, 0.94)
	if serve_quality < SERVE_NET_ERROR_QUALITY:
		## Into the tape, dropping on the server's own side of it -- which is
		## the half the ball came from, the opposite one to where it was aimed.
		return Vector2(lane_x, CourtConstants.NET_Y
			+ (-net_drop if landing_on_home_side else net_drop))
	## Otherwise it carried. Past whichever line the intended target already sat
	## nearest, so a deep serve sails long and one aimed near a sideline sails
	## wide, rather than every miss landing on one arbitrary spot.
	var endline := 1.0 if landing_on_home_side else 0.0
	var to_endline := absf(intended.y - endline)
	var to_left := intended.x
	var to_right := 1.0 - intended.x
	if to_endline <= to_left and to_endline <= to_right:
		return Vector2(lane_x, endline
			+ (deep_overshoot if landing_on_home_side else -deep_overshoot))
	if to_left <= to_right:
		return Vector2(-wide_overshoot, intended.y)
	return Vector2(1.0 + wide_overshoot, intended.y)


## Depth a shot family naturally wants, as a fraction from the net (0) to the
## endline (1). Power swings drive deep; rolls and tips die short.
const ATTACK_DEPTH_PREFERENCE := {
	"Power swing": 0.70,
	"Tempo swing": 0.60,
	"Quick attack": 0.52,
	"Pipe attack": 0.68,
	"High-ball swing": 0.62,
	"Controlled roll": 0.34,
	"Emergency tip": 0.20,
}


## Where this hitter aims, chosen continuously from the actual open floor.
##
## This used to pick from five fixed coordinates, so every attack in the game
## landed on one of five spots regardless of where the defence stood. The floor
## is now scanned properly: each sample is scored by how far it sits from the
## nearest defender, how naturally it fits the shot family being hit, and how
## far the hitter has to swing away from their approach line to reach it -- a
## sharp cross-court from a tight set is a harder ball than an easy line shot,
## and only a hitter with the accuracy and shot variety to attempt it should.
##
## The winning sample is then displaced by an aiming error that shrinks with
## `attack_accuracy`, so the resolved target is a continuous point that no
## table contains.
## Where this swing is aimed, for either side of the net.
##
## Written for the home side only, which made the home attack the one that
## searched the floor for a gap while the opponent's picked a depth band at
## random. Invisible while kills were 12% of swings; at 54% it decided matches,
## and 180 rallies produced 117 home kills against 13 opponent ones.
##
## `defenders` are the positions to hit away from, and `mirrored` flips the
## result into the home half for an opponent swing. Everything else -- the swing
## range, the read roll, the accuracy-shrinking aiming error -- is the same act
## on both sides because it is the same act.
func _choose_attack_target(
	hitter: VolleyballPlayer,
	contact: Vector2,
	hit_type: String,
	defenders: Array[Vector2],
	mirrored: bool = false,
) -> Dictionary:
	var accuracy := _rating(hitter, "attack_accuracy")
	var variety := _rating(hitter, "shot_variety")
	var reading := _rating(hitter, "decision_making")
	## Defender positions arrive in their own half; the scan happens in the
	## attacked half, so an opponent swing compares against mirrored defenders.
	if mirrored:
		var flipped: Array[Vector2] = []
		for defender_position in defenders:
			flipped.append(Vector2(defender_position.x, 1.0 - defender_position.y))
		defenders = flipped
		contact = Vector2(contact.x, 1.0 - contact.y)

	## How far off their natural line this hitter can credibly swing. A narrow
	## repertoire keeps them hitting where their approach already points.
	var swing_range := lerpf(0.22, 0.62, variety * 0.6 + accuracy * 0.4)
	var preferred_depth := float(ATTACK_DEPTH_PREFERENCE.get(hit_type, 0.6))

	var best_target := Vector2(
		clampf(1.0 - contact.x, ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x),
		lerpf(ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, preferred_depth),
	)
	var best_score := -1.0e9
	for column in range(ATTACK_SCAN_COLUMNS):
		var x := lerpf(
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x,
			float(column) / float(ATTACK_SCAN_COLUMNS - 1)
		)
		if absf(x - contact.x) > swing_range:
			continue
		for row in range(ATTACK_SCAN_ROWS):
			var y := lerpf(
				ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y,
				float(row) / float(ATTACK_SCAN_ROWS - 1)
			)
			var candidate := Vector2(x, y)
			var nearest := 10.0
			for defender_position in defenders:
				nearest = minf(
					nearest,
					CoverageModel.court_distance_meters(defender_position, candidate)
				)
			var depth_fraction := inverse_lerp(
				ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, y
			)
			var score := nearest 				- absf(depth_fraction - preferred_depth) * 3.2 				- absf(x - contact.x) * 1.6
			if score > best_score:
				best_score = score
				best_target = candidate

	## A hitter who reads the floor well finds the gap; one who does not commits
	## to their own line regardless of who is standing in it.
	var instinctive := Vector2(
		clampf(
			contact.x + (0.5 - contact.x) * 0.7,
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x
		),
		lerpf(ATTACK_COURT_MAX.y, ATTACK_COURT_MIN.y, preferred_depth),
	)
	var aim := best_target if rng.randf() < reading else instinctive

	## Aiming error, continuous and shrinking with accuracy. This is what makes
	## the resolved point one no table contains.
	var spread := lerpf(0.115, 0.022, accuracy)
	var target := Vector2(
		clampf(
			aim.x + rng.randf_range(-spread, spread),
			ATTACK_COURT_MIN.x, ATTACK_COURT_MAX.x
		),
		clampf(
			aim.y + rng.randf_range(-spread, spread) * 0.8,
			ATTACK_COURT_MIN.y, ATTACK_COURT_MAX.y
		),
	)
	var resolved_target := Vector2(target.x, 1.0 - target.y) if mirrored else target
	return {
		"target": resolved_target,
		"direction": _attack_direction(contact.x, target),
		"reason": "open floor" if aim == best_target else "hit their own line",
	}


## Who on the opponent plays this ball, through the same search the home side
## uses.
##
## This was a hand-rolled scan and it lost the rally in three separate ways. It
## struck the setter and both middles off the list, so a six-player defence
## defended with three. It reported no support count, so the covered-defender
## term was permanently zero on one side of the net and averaged 0.30 on the
## other. And it made a defender run to the exact landing coordinate, while
## `choose_claimant` credits the home defender with a metre and a half of reach
## before asking them to move at all -- which is most of why the home defender
## arrived with 0.97s to spare and the opponent 0.56s late, and why the home
## side dug 42% of balls to the opponent's 23% with identical dig attributes on
## both sides by construction.
##
## None of those were decisions. They were the shape of a second implementation
## written for the same job, and the fix is not to correct them one by one but
## to stop having two.
func _choose_opponent_defender(
	opponent_team: Resource,
	target: Vector2,
	flight_time: float,
) -> Dictionary:
	var defenders: Array[VolleyballPlayer] = []
	for defender_resource in opponent_team.on_court_players():
		var defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if defender != null:
			defenders.append(defender)
	if defenders.is_empty():
		return {"player": null, "start": target, "distance_meters": 99.0,
			"travel_time": 9.0, "reach_margin_meters": -9.0, "support_count": 0,
			"edge_ratio": 1.5}
	var plan := _opponent_defensive_plan(opponent_team)
	var zones := _zones_at_phase_positions(
		plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE),
		opponent_live_positions,
	) if plan != null else {}
	var claim := CoverageModel.choose_claimant(
		defenders, zones, target, flight_time, "reception",
		_recovery_time_penalties(rally_clock),
	)
	var claimant := claim.get("player") as VolleyballPlayer
	var arrival: Dictionary = claim.get("arrival", {})
	var claimed := claimant != null
	if claimant == null:
		## Nobody could reach it. The search says so by returning no player, and
		## the ball still has to be described as landing on somebody, so the
		## nearest body takes it and eats the deficit -- evaluated through the
		## same function, so the margin it reports is on the same scale as a
		## claimed ball's rather than a second opinion about the same event.
		claimant = _nearest_opponent_body(opponent_team, target)
		arrival = CoverageModel.evaluate_arrival(
			claimant, zones.get(claimant.id) as Resource,
			target, flight_time, "reception",
		) if claimant != null else {}
	var start: Vector2 = opponent_live_positions.get(
		claimant.id, opponent_team.court_position(claimant.id, "defense")
	) if claimant != null else target
	var travel_time := _movement_time(claimant, start, target, "lateral") \
		if claimant != null else 9.0
	## `evaluate_arrival` reports its margin in *metres* -- it is
	## `physical_reach - distance`, how much further the defender could have
	## reached -- and `_defense_execution` reads it against
	## `DIG_LATE_ARRIVAL_SECONDS`. That mismatch is older than this function and
	## is not corrected here, because correcting it would silently rescale every
	## dig in the engine including the home side's. What matters for the two
	## sides being comparable is that they are on the *same* scale, so the
	## fallback reports metres too rather than the seconds it used to.
	var fallback_margin := CoverageModel.court_distance_meters(start, target)
	return {
		"player": claimant,
		"claimed": claimed,
		"start": start,
		"distance_meters": fallback_margin,
		"travel_time": travel_time,
		"reach_margin_meters": float(
			arrival.get("reach_margin_meters", -fallback_margin)
		),
		"edge_ratio": float(arrival.get("edge_ratio", 1.2)),
		"support_count": int(claim.get("support_count", 0)),
		"arrival": arrival,
	}


## The nearest opponent to a ball nobody claimed.
func _nearest_opponent_body(
	opponent_team: Resource, target: Vector2
) -> VolleyballPlayer:
	var nearest: VolleyballPlayer = null
	var best := INF
	for defender_resource in opponent_team.on_court_players():
		var defender: VolleyballPlayer = defender_resource as VolleyballPlayer
		if defender == null:
			continue
		var start: Vector2 = opponent_live_positions.get(
			defender.id, opponent_team.court_position(defender.id, "defense")
		)
		var distance := CoverageModel.court_distance_meters(start, target)
		if distance < best:
			best = distance
			nearest = defender
	return nearest if nearest != null else opponent_team.best_defender()


## Where this opponent hitter can legally and physically contact the ball.
##
## The lane comes from the position code as before, but the depth now comes from
## the rotation. A back-row player taking off at the net is an over-the-net
## violation, and it was also the geometry that produced the pin-to-pin sprints:
## every eligible hitter was handed a front-row contact point regardless of
## where the rotation had actually put them.
func _opponent_attack_contact(
	opponent_team: Resource, hitter: VolleyballPlayer
) -> Vector2:
	var code := str(hitter.position_code)
	var lane_x := 0.50
	if code in ["OH1", "OH2"]:
		lane_x = 0.18
	elif code == "OP":
		lane_x = 0.82
	var lineup: Resource = opponent_team.current_lineup()
	var front_row := true
	if lineup != null:
		var slot_number: int = lineup.slot_for_player(hitter.id)
		if slot_number >= 1:
			front_row = CourtConstants.is_front_row_slot(slot_number)
	return Vector2(
		lane_x, OPPONENT_FRONT_ROW_CONTACT_Y if front_row \
			else OPPONENT_BACK_ROW_CONTACT_Y
	)


## The ideal contact point pulled back to one this hitter can actually reach.
##
## Scoring hitters on how late they are cannot fix a scramble where *everybody*
## is late: the penalty saturates for all of them, the comparison collapses back
## onto the arm, and the biggest arm gets handed a contact point six metres
## away. The geometry has to give instead of the ranking. A hitter who cannot
## get to the pin hits from wherever along that line they can reach, which is
## what a scrambling team actually does -- and it degrades their offence through
## the existing approach machinery rather than through a special case.
func _reachable_attack_contact(
	hitter: VolleyballPlayer,
	start: Vector2,
	ideal_contact: Vector2,
	set_flight_time: float,
) -> Vector2:
	## The whole journey used to be charged against the set's flight alone, which
	## is the double-charge the home side's `_approach_budget` was built to stop
	## and which was never taken off this side. A hitter does not stand still
	## until the ball leaves the setter's hands: they transition out and walk to
	## their mark while the pass is in the air and the setter is releasing it, and
	## only the run-up from the mark to the contact is paid out of the set's hang
	## time.
	##
	## Measured with the walk double-charged: 541 of 552 opponent swings clamped
	## short, a 6.12 m run at both p50 and p90 against a 0.55 s set, and contacts
	## landing a median 5.48 m off the net when the ask was 3.60 m -- an opponent
	## swinging from their own baseline on nearly every ball. That is also the
	## whole of the block's placement error, since the crossing displacement is
	## `tan(bearing) * off_net_metres`.
	var budget := set_flight_time + OPPONENT_HITTER_LATE_GRACE
	if RallyFeatureFlagsModel.ENABLE_OPPONENT_APPROACH_WINDOW:
		budget += DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS
	if _movement_time(hitter, start, ideal_contact, "transition") <= budget:
		return ideal_contact
	## Movement time rises monotonically with distance, so bisecting the segment
	## converges on the furthest reachable point without needing to invert the
	## locomotion model.
	var low := 0.0
	var high := 1.0
	for _iteration in range(REACHABLE_CONTACT_BISECTIONS):
		var middle := (low + high) * 0.5
		if _movement_time(
			hitter, start, start.lerp(ideal_contact, middle), "transition"
		) <= budget:
			low = middle
		else:
			high = middle
	return start.lerp(ideal_contact, low)


## How far along their run a player actually got, when the ball beat them there.
##
## Playback draws each contact's actor travelling to the contact point over the
## previous ball's flight. For a defender who never reached the ball that is a
## lie in the player's favour and it reads as a teleport: they were shown
## arriving, at whatever speed the geometry demanded, and then failing for
## reasons the picture did not show. Emitting the point they actually reached
## lets the ball land next to somebody who is visibly short of it, which is what
## the simulator already decided happened.
##
## Bisected against `_movement_time` rather than scaled by the time fraction,
## because locomotion has an acceleration phase: a player who has used 60% of
## the time has covered less than 60% of the ground, and the difference is
## exactly the early part of the run where the error would be most visible.
func _reached_point(
	mover: VolleyballPlayer,
	start: Vector2,
	target: Vector2,
	available_time: float,
	mode: String,
) -> Vector2:
	if mover == null or available_time <= 0.0:
		return start
	if _movement_time(mover, start, target, mode) <= available_time:
		return target
	var low := 0.0
	var high := 1.0
	for _iteration in range(REACHABLE_CONTACT_BISECTIONS):
		var middle := (low + high) * 0.5
		if _movement_time(
			mover, start, start.lerp(target, middle), mode
		) <= available_time:
			low = middle
		else:
			high = middle
	return start.lerp(target, low)


func _choose_opponent_attack(
	opponent_team: Resource,
	setter: VolleyballPlayer,
	set_quality: float,
	open_target: Vector2,
	set_flight_time: float,
) -> Dictionary:
	var candidates: Array[Resource] = opponent_team.eligible_hitters(setter.id)
	if candidates.is_empty():
		candidates.append(opponent_team.best_hitter())
	var reachable: Array[Dictionary] = []
	var every_option: Array[Dictionary] = []
	for resource in candidates:
		var candidate: VolleyballPlayer = resource as VolleyballPlayer
		if candidate == null:
			continue
		var quick_demand := 0.13 if str(candidate.position_code).begins_with("M") else 0.0
		var candidate_start: Vector2 = opponent_live_positions.get(
			candidate.id, opponent_team.court_position(candidate.id, "transition")
		)
		var candidate_contact := _reachable_attack_contact(
			candidate, candidate_start,
			_opponent_attack_contact(opponent_team, candidate), set_flight_time,
		)
		var candidate_travel := _movement_time(
			candidate, candidate_start, candidate_contact, "transition"
		)
		var lateness := maxf(candidate_travel - set_flight_time, 0.0)
		## Arrival used to be worth at most 0.12 of the option score against 0.42
		## for hitting power and +/-0.12 of noise, so the biggest arm won the
		## swing from anywhere on the court and playback dutifully slid a
		## back-row opposite from the left pin to the right one in the 0.3s a
		## quick set is in the air -- twenty-five metres a second. The penalty is
		## now the dominant term rather than a nudge: being marginally behind the
		## set still costs less than a weak arm, but being a court away costs
		## more than any arm is worth. Late hitters stay in the pool rather than
		## being excluded, so a setter under pressure still has somebody to go
		## to and the rotation still produces a variety of hitters.
		var option_score := _power_rating(candidate, "attack_power") * 0.42 \
			+ _rating(candidate, "attack_accuracy") * 0.24 \
			+ _rating(candidate, "approach_timing") * 0.18 \
			+ set_quality * 0.16 - quick_demand * (1.0 - set_quality) \
			- clampf(
				(lateness - OPPONENT_HITTER_LATE_GRACE) / OPPONENT_HITTER_LATE_RAMP,
				0.0, 1.0,
			) * OPPONENT_HITTER_LATENESS_WEIGHT \
			+ rng.randf_range(-0.12, 0.12)
		var option := {
			"player": candidate, "start": candidate_start,
			"contact": candidate_contact, "travel_time": candidate_travel,
			"lateness": lateness, "score": option_score,
		}
		every_option.append(option)
		if lateness <= 0.0:
			reachable.append(option)
	var chosen: Dictionary = every_option[0]
	for option in every_option:
		if float(option.score) > float(chosen.score):
			chosen = option
	var best := chosen.player as VolleyballPlayer
	var code := str(best.position_code)
	var start := Vector2(chosen.start)
	var contact := Vector2(chosen.contact)
	var contact_x := contact.x
	var travel_time := float(chosen.travel_time)
	var intended_type := "Quick attack" \
		if code.begins_with("M") and set_quality >= 0.46 else "Power swing"
	## Drawn ahead of the branch, so the number of draws a rally consumes does not
	## depend on which way the branch goes, and returned alongside the shot, because
	## the shot decided here is provisional: it is chosen against a set quality
	## computed for a *placeholder* target, and the real one is not known until the
	## contact is final. Re-deciding later with a fresh draw would consume a second
	## number and re-sequence every seeded outcome after it.
	##
	## Gated on the flag that needs it, because the original `set_quality < 0.38 or
	## rng.randf()` short-circuits: hoisting the draw is the correct shape but it is
	## not free, and taken unconditionally with the flag off it re-sequenced roughly
	## one rally in three hundred and moved the attack-symmetry ratchet 0.654 to
	## 0.660 while delivering nothing. A flag that is off has to be byte-identical
	## or the reading it is measured against is not the one it will ship into.
	var improvise_roll := 0.0
	var attack_type := intended_type
	if RallyFeatureFlagsModel.ENABLE_UNIFIED_ATTACK_SHAPE:
		improvise_roll = rng.randf()
		attack_type = _compromised_shot_type(best, intended_type, set_quality)
	elif RallyFeatureFlagsModel.ENABLE_DELIVERED_SET_SHOT_CHOICE:
		improvise_roll = rng.randf()
		if set_quality < 0.38 \
				or improvise_roll < 0.12 + _rating(best, "decision_making") * 0.08:
			attack_type = "Roll shot" if set_quality >= 0.30 else "Emergency tip"
	else:
		if set_quality < 0.38 \
				or rng.randf() < 0.12 + _rating(best, "decision_making") * 0.08:
			attack_type = "Roll shot" if set_quality >= 0.30 else "Emergency tip"
	var target := open_target
	if attack_type in ["Roll shot", "Emergency tip"]:
		target.y = rng.randf_range(0.58, 0.72)
	else:
		target.y = rng.randf_range(0.80, 0.93)
	return {"player": best, "start": start, "contact": contact,
		"target": target, "travel_time": travel_time,
		"attack_type": attack_type, "intended_type": intended_type,
		"improvise_roll": improvise_roll,
		"direction": _attack_direction(contact_x, target)}


func _home_target_hint(defensive_plan: Resource) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(0.18, 0.86), Vector2(0.50, 0.84), Vector2(0.82, 0.86),
		Vector2(0.34, 0.66), Vector2(0.66, 0.66),
	]
	if defensive_plan == null:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var zones: Dictionary = defensive_plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE)
	var best := candidates[0]
	var best_gap := -1.0
	for target in candidates:
		var nearest := 10.0
		for player_id in zones:
			var zone: Resource = zones[player_id]
			if zone != null and bool(zone.enabled):
				nearest = minf(nearest, Vector2(zone.center).distance_to(target))
		if nearest > best_gap:
			best = target
			best_gap = nearest
	return best


func _attack_direction(contact_x: float, target: Vector2) -> String:
	if target.y < 0.76:
		return "short court"
	if absf(target.x - contact_x) <= 0.20:
		return "line"
	if absf(target.x - 0.50) <= 0.14:
		return "seam"
	return "cross-court"


func _initial_home_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	receiving: bool,
) -> Dictionary:
	var positions := {}
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var position := CourtConstants.slot_position(slot_number)
		## The server stands where the ball comes from.
		##
		## The serve event has always launched from `serve_origin()` -- behind the
		## baseline, off the court, which is where a serve is legally struck -- while
		## the server themselves was placed on the rotation grid *inside* the court.
		## So playback drew the ball leaving from a point nobody was standing at, a
		## metre or so behind a player who never moved. They walk in afterwards; see
		## the SERVE event's own `movement_target`.
		if not receiving and slot_number == 1:
			positions[player_id] = CourtConstants.serve_origin(position.x, true)
			continue
		if defensive_plan != null:
			if receiving:
				var zone: Resource = defensive_plan.zone_for(
					player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
				)
				if zone != null:
					position = Vector2(zone.center)
			else:
				position = defensive_plan.defender_position(player_id, position)
		positions[player_id] = position
	return positions


func _initial_opponent_positions(
	opponent_team: Resource,
	receiving: bool,
) -> Dictionary:
	var positions := {}
	if opponent_team == null:
		return positions
	var reception_zones: Dictionary = {}
	if receiving:
		reception_zones = _opponent_reception_coverage(opponent_team).zones
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	var serving_id := opponent_lineup.player_at_slot(1) \
		if opponent_lineup != null and not receiving else -1
	for player_resource in opponent_team.on_court_players():
		var player := player_resource as VolleyballPlayer
		if player == null:
			continue
		var position: Vector2 = opponent_team.court_position(player.id, "defense")
		var zone: Resource = reception_zones.get(player.id) as Resource
		if zone != null and bool(zone.enabled):
			position = Vector2(zone.center)
		## Mirrored, for the same reason as the home side: the ball leaves from
		## behind this baseline, so the server does too.
		if player.id == serving_id:
			position = CourtConstants.serve_origin(position.x, false)
		positions[player.id] = position
	return positions


func _playback_handedness(
	players: Array[VolleyballPlayer],
	opponent_team: Resource,
) -> Dictionary:
	var handedness := {}
	for player in players:
		handedness[player.id] = player.dominant_hand
	if opponent_team != null:
		for player_resource in opponent_team.on_court_players():
			var player := player_resource as VolleyballPlayer
			if player != null:
				handedness[player.id] = player.dominant_hand
	return handedness


func _playback_physical_profiles(
	players: Array[VolleyballPlayer],
	opponent_team: Resource,
) -> Dictionary:
	var profiles := {}
	for player in players:
		profiles[player.id] = _physical_playback_profile(player)
	if opponent_team != null:
		for player_resource in opponent_team.on_court_players():
			var player := player_resource as VolleyballPlayer
			if player != null:
				profiles[player.id] = _physical_playback_profile(player)
	return profiles


func _physical_playback_profile(player: VolleyballPlayer) -> Dictionary:
	return {
		"height_cm": player.height_cm,
		"wingspan_cm": player.wingspan_cm,
		"stride_length_m": player.stride_length_m,
		## What this player is. Generation has assigned a body type since it
		## existed, and it reached height, mass, wingspan and six attribute
		## ceilings -- everything except the one place a player is actually
		## looked at.
		"body_type": player.body_type,
		"standing_reach_meters": player.standing_reach_cm() / 100.0,
		"jumping_reach_meters": player.jumping_reach_cm() / 100.0,
	}


func _zones_at_phase_positions(
	source_zones: Dictionary,
	phase_positions: Dictionary,
) -> Dictionary:
	var zones := {}
	for raw_player_id in source_zones:
		var player_id := int(raw_player_id)
		var source: Resource = source_zones[raw_player_id] as Resource
		if source == null:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player_id
		zone.zone_type = source.zone_type
		zone.center = phase_positions.get(player_id, Vector2(source.center))
		zone.radius_meters = source.radius_meters
		zone.priority = source.priority
		zone.enabled = source.enabled
		zones[player_id] = zone
	return zones


func _home_floor_phase_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	primary_blocker_id: int,
	assisting_blocker_id: int,
	wall_x: float = NAN,
) -> Dictionary:
	return _floor_phase_positions(
		lineup, defensive_plan, attack_x,
		primary_blocker_id, assisting_blocker_id, false, wall_x,
	)


## Where a defending six stands while the ball is being attacked at them.
##
## This used to exist for the home side only, and that single fact was most of
## the engine's home advantage. The home six were walked to their floor-defence
## shape during the attack's flight, so they met the ball having already
## arrived; the opponent six were left wherever the previous phase had put them
## -- at the block wall, at a hitter's contact point -- and had to cover that
## ground inside the attack. Measured over 407 digs the home defender arrived
## with 0.97s to spare and the opponent 0.56s late, a gap of a second and a half
## in a model whose timing term saturates at 1.2s. Home dug 42% of balls and the
## opponent 23%, with identical dig attributes on both sides by construction.
##
## Nothing about standing in your defensive shape is home-specific, so the side
## is now a parameter rather than a copy: the y axis mirrors, the depth and
## posture adjustments flip with it, and both sixes get the same preparation.
func _floor_phase_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	primary_blocker_id: int,
	assisting_blocker_id: int,
	opponent_side: bool,
	wall_x: float = NAN,
) -> Dictionary:
	var positions := {}
	if lineup == null:
		return positions
	## Mirroring is the whole difference. `+1` walks a home defender back from
	## the net and an opponent defender toward it, so every depth term carries
	## the side's sign rather than the home side's.
	var forward := -1.0 if opponent_side else 1.0
	var relationship := str(defensive_plan.block_defense_relationship) \
		if defensive_plan != null else "Balanced"
	var depth := str(defensive_plan.defensive_depth) \
		if defensive_plan != null else "Balanced"
	var short_posture := str(defensive_plan.short_ball_posture) \
		if defensive_plan != null else "Standard"
	## The wall, at its two shoulders. Both blockers used to be handed the *same*
	## point -- `Vector2(attack_x, wall_y)` -- so in 3D playback their bodies were
	## stacked by construction rather than merely close: one actor standing inside
	## another. The 2D court never showed it because it draws its squares from
	## `_block_wall_positions()`, which has always separated them; the 3D view takes
	## its placement from this function, and nothing reconciled the two.
	##
	## Same source now. A wall is two players side by side and that is a fact about
	## where they stand, not a detail of how one view draws them.
	## Staged on the crossing the blocking side read, when one was supplied. The
	## floor behind them still shades on the attack lane: where the hitter is and
	## where the ball goes through the tape are different facts, and only the wall
	## stands on the second one.
	var wall := _block_wall_positions(
		attack_x if is_nan(wall_x) else wall_x, opponent_side
	)
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id == primary_blocker_id:
			positions[player_id] = Vector2(wall.primary_position)
			continue
		if player_id == assisting_blocker_id:
			positions[player_id] = Vector2(wall.assist_position)
			continue
		var fallback := CourtConstants.slot_position(slot_number)
		var target: Vector2 = defensive_plan.defender_position(player_id, fallback) \
			if defensive_plan != null else fallback

		var zone: Resource = defensive_plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
		) if defensive_plan != null else null
		if zone != null and bool(zone.enabled):
			target = Vector2(zone.center)
		var coverage_focus := 0.50
		if relationship == "Defend Line":
			coverage_focus = attack_x
		elif relationship == "Defend Cross":
			coverage_focus = 1.0 - attack_x
		var front_row := CourtConstants.is_front_row_slot(slot_number)
		target.x = lerpf(target.x, coverage_focus, 0.09 if front_row else 0.18)
		if depth == "Deep":
			target.y += 0.035 * forward
		elif depth == "Shallow":
			target.y -= 0.035 * forward
		if short_posture == "Compress Short":
			target.y = lerpf(target.y, 0.32 if opponent_side else 0.68, 0.18)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if assignment != null \
				and "inside seam" in str(assignment.seam_responsibility).to_lower():
			target.x = lerpf(target.x, 0.50, 0.08)
		positions[player_id] = Vector2(
			clampf(target.x, 0.06, 0.94),
			clampf(target.y, 0.04, 0.44) if opponent_side \
				else clampf(target.y, 0.56, 0.96),
		)
	return positions


## What tempo the opponent calls on this ball.
##
## It was `tendencies.get("tempo", 2)` -- the same number on every ball of every
## rally of every match. Structurally that already mirrored the home side, which
## also calls before the pass and lets `SetterCapabilityModel` resolve down; what
## it did not mirror is that the home call comes from a playbook and ranges 0 to
## 3 while this one never varied. A side that always runs the same play cannot be
## caught running the wrong one, which is why the capability model's downgrade
## branch never once fired here.
##
## The thresholds below are asserted, not derived. There is no home-side
## equivalent to mirror, because the home tempo comes from a playbook the
## opponent does not have, so this is calibration by assertion until the roster
## influence sweep prices it properly. It was measured before being kept: the
## promoted symmetry estimator moves from 0.617 to 0.594 -- from three
## thousandths inside the bound to twenty-six -- against 0.007 of opponent set
## quality. The likely mechanism is that a varying tempo sometimes catches the
## home block closing for the wrong ball, since set flight time is what
## `_contest_block` gets its close window from; that is plausible and unverified,
## and worth confirming before these numbers are trusted further.
## What tempo this setter calls off this ball. One function, both sides.
##
## It was `_opponent_tempo_call` and only the opponent used it; the home side
## took `assignment.tempo` from the called play on a first ball and a hardcoded
## 3 out of `_fallback_assignment` on every transition. That is two constants
## rather than one decision, and `_set_launch_angle_degrees` makes the
## difference enormous: tempo 3 leaves at 45-55 degrees, tempo 2 at 25-35.
##
## Measured, identical rosters, the set flight the hitter gets to run under:
##
##   home_first_ball        0.902s      opponent_first_ball    0.488s
##   home_transition        1.063s      opponent_transition    0.489s
##
## Half the airtime is half the approach, which is why the opponent hitter
## arrived 0.33s late against the home side's 0.06s, ran up 36% slower, jumped
## lower and erred at twice the rate on every out-channel at once.
func _tempo_call(
	setter: VolleyballPlayer,
	requested_tempo: int,
	pass_quality: float,
) -> int:
	var called := clampi(
		requested_tempo,
		SetterCapabilityModel.QUICK_TEMPO, SetterCapabilityModel.SLOWEST_TEMPO,
	)
	## Lower is quicker: tempo 0 is the first-tempo ball, 3 the high one.
	if pass_quality >= OPPONENT_QUICK_CALL_PASS:
		called -= 1
	elif pass_quality < OPPONENT_SLOW_CALL_PASS:
		called += 1
	## A setter who reads the game runs closer to the edge of what the pass
	## allows; one who does not plays it safe.
	if _rating(setter, "decision_making") >= 0.72 \
			and pass_quality >= OPPONENT_SLOW_CALL_PASS:
		called -= 1
	return clampi(
		called,
		SetterCapabilityModel.QUICK_TEMPO, SetterCapabilityModel.SLOWEST_TEMPO,
	)


## The opponent's defensive plan, built once per rally from their own lineup.
##
## They have never had one. Every read of a posture, a seam responsibility or a
## floor-defence zone on that side of the net returned a default, so the
## opponent defended from the rotation grid while the home side defended from a
## plan. `ensure_defaults` produces exactly the plan a home coach starts from,
## which is the right baseline: the opponent is not being given a better system
## than the player, it is being given the same one.
func _opponent_defensive_plan(opponent_team: Resource) -> Resource:
	if opponent_plan != null:
		return opponent_plan
	if opponent_team == null:
		return null
	var lineup: RotationLineup = opponent_team.current_lineup()
	if lineup == null:
		return null
	opponent_plan = DefensivePlanModel.new()
	opponent_plan.ensure_defaults(lineup)
	## Deliberately no floor preset on top.
	##
	## `ensure_defaults` seeds `defender_positions` from
	## `CourtConstants.ROTATION_SLOT_POSITIONS`, whose own comment says it "is
	## NOT a tactical formation and must not be used to position players during
	## live play" -- it exists to check overlap legality at the moment of serve.
	## That is a real defect, and it is the *home* side's defect too:
	## `apply_floor_preset` is only ever called from the tactics screen, so a
	## default career plan defends from the rotation grid exactly like this one
	## does. Applying Perimeter here alone would hand the opponent a floor
	## system the player has to go and choose, which is the same asymmetry as
	## the one this gate exists to remove, pointed the other way. Both sides
	## move together or neither does.
	## Mirrored at the source, not at every reader. `ensure_defaults` lays the
	## plan out in home coordinates because that is the only court it has ever
	## described, and a zone centred on the home back row is not a place an
	## opponent defender can stand. Flipping it once here means any reader that
	## does not have a staged position for somebody still gets a centre on the
	## right half of the net, instead of a defender who appears to be defending
	## from inside the other team.
	for zone_type in [
		DefensiveZoneModel.ZoneType.FLOOR_DEFENSE,
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE,
	]:
		for raw_player_id in opponent_plan.zones_for(zone_type):
			var zone: Resource = opponent_plan.zone_for(int(raw_player_id), zone_type)
			if zone == null:
				continue
			zone.center = Vector2(zone.center.x, 1.0 - zone.center.y)
	for raw_player_id in opponent_plan.defender_positions:
		var seat: Vector2 = opponent_plan.defender_positions[raw_player_id]
		opponent_plan.defender_positions[raw_player_id] = Vector2(seat.x, 1.0 - seat.y)
	return opponent_plan


func _approach_start_position(
	contact_position: Vector2,
	current_position: Vector2,
	opponent_side: bool,
) -> Vector2:
	var local_contact := Vector2(
		contact_position.x, 1.0 - contact_position.y
	) if opponent_side else contact_position
	var local_current := Vector2(
		current_position.x, 1.0 - current_position.y
	) if opponent_side else current_position
	## Delegated rather than derived here. This function used to carry its own
	## copy of the run-up geometry, and the two disagreed in *sign* -- this one
	## started a pin outside the contact, `ApproachMechanicsSystem`'s started them
	## inside it. Since that one is what `prepare_for_attack()` calls, the engine
	## ran its pins inside-out while this fallback drew them the other way.
	var pin_distance := absf(local_contact.x - 0.50)
	var approach_depth := 0.135 * lerpf(
		0.88, 1.12, clampf(pin_distance / 0.34, 0.0, 1.0)
	)
	var approach := ApproachMechanicsModel.approach_start_position(
		local_contact, "", &"home", local_current, approach_depth
	)
	return Vector2(approach.x, 1.0 - approach.y) if opponent_side else approach


func _movement_time(
	player: VolleyballPlayer,
	start: Vector2,
	target: Vector2,
	movement_kind: String,
	waypoint: Variant = null,
	## What this player is already carrying into the leg. Every traversal in the
	## engine was timed from a dead stop -- 14,991 legs of 14,991 -- so the guard
	## in `_leg_seconds` that exists to stop a moving player being charged a
	## standing start and a turn had never once fired. Measured, that cost 1.020s
	## for a mean 2.35 m leg where an entry at half top speed costs 0.674s, and
	## it is why 83% of attack contacts were placed beyond the hitter's reach.
	##
	## Zero stays right where a player genuinely is stationary. It simply is not
	## the common case, and `prepare_for_attack` has been returning the real
	## figure as `prepared_velocity_mps` all along with nothing reading it.
	entry_velocity: Vector2 = Vector2.ZERO,
) -> float:
	return float(_travel(
		player, start, target, movement_kind, waypoint, entry_velocity
	)["seconds"])


## A traversal, keeping what the player carries out of it.
##
## Callers that merely ask "how long would this take" -- candidate scoring in
## `_spatial_setter_choice`, defender searches -- want the duration and must not
## record anything, because most of those players never move. Callers that
## *commit* a movement take the exit velocity and store it, so the next leg
## begins where the last one ended instead of from a dead stop.
func _travel(
	player: VolleyballPlayer,
	start: Vector2,
	target: Vector2,
	movement_kind: String,
	waypoint: Variant = null,
	entry_velocity: Vector2 = Vector2.ZERO,
) -> Dictionary:
	if player == null:
		return {"seconds": 4.0, "exit_velocity": Vector2.ZERO}
	## One movement model. This used to carry its own constant-velocity formula
	## with a flat startup penalty, which disagreed with the kinematics every
	## reachability decision is built on -- and disagreed in opposite directions
	## by phase, because a flat penalty undercharges short traversals and
	## amortises away on long ones. It now asks the same model.
	var actor := RallyPlayerState.create(player, &"home", -1, start)
	actor.velocity = entry_velocity
	var opening := RallyKinematicsModel.court_delta_meters(start, target)
	if opening.length() > 0.0001:
		## The resolver does not track facing at this point, and charging a full
		## reorientation the player may not need would reintroduce a second
		## disagreement. Face the route; the turn floor still applies.
		actor.facing = opening.normalized()
	return RallyMovementSystemModel.traversal_result(
		actor, target, _movement_mode_for_kind(movement_kind), waypoint
	)


static func _movement_mode_for_kind(
	movement_kind: String,
) -> RallyPlayerState.MovementMode:
	match movement_kind:
		"lateral":
			return RallyPlayerState.MovementMode.LATERAL
		"approach":
			return RallyPlayerState.MovementMode.APPROACH
	return RallyPlayerState.MovementMode.TRANSITION


## Where this wall should form, in normalised court x.
##
## The one place the blocking side's read is turned into a position. Every
## staging site used to pass the hitter's contact straight through, which is
## where the hitter jumps rather than where the ball crosses; see
## `RallyFeatureFlags.ENABLE_BLOCK_CROSSING_READ` for what that cost and what it
## measured.
##
## Falls back to the contact when the read is closed, so the flag is genuinely a
## switch between two staged positions and not between a position and nothing.
func _wall_stage_x(
	hitter: VolleyballPlayer,
	contact: Vector2,
	lane: String,
	attacking_negative_y: bool,
	read_quality: float,
	block_intent: String,
) -> float:
	if hitter == null or not RallyFeatureFlagsModel.ENABLE_BLOCK_CROSSING_READ:
		return contact.x
	var approach_start := ApproachMechanicsModel.approach_start_position(
		contact, lane, &"home" if attacking_negative_y else &"opponent", contact
	)
	return GeometricAttackPromotionModel.wall_stage_x(
		contact,
		AttackCourseModelRef.natural_bearing_from_approach(
			approach_start, contact, attacking_negative_y
		),
		attacking_negative_y, read_quality,
		## The cone this hitter can turn the ball through, on the same terms the
		## resolver gives them. A blocker facing a hitter with range knows it.
		lerpf(22.0, 62.0,
			_rating(hitter, "shot_variety") * 0.6
				+ _rating(hitter, "attack_accuracy") * 0.4),
		block_intent,
	)


## The two positions a block wall occupies, pressed to the net on the blocking
## team's own side. The assist closes inward from the middle of the court, so
## the wall extends toward centre rather than off the sideline.
static func _block_wall_positions(
	lane_x: float,
	opponent_side: bool,
) -> Dictionary:
	var wall_y := CourtConstants.NET_Y - BLOCK_NET_DEPTH if opponent_side \
		else CourtConstants.NET_Y + BLOCK_NET_DEPTH
	var inward := 1.0 if lane_x < 0.5 else -1.0
	return {
		"primary_position": Vector2(clampf(lane_x, 0.05, 0.95), wall_y),
		"assist_position": Vector2(
			clampf(lane_x + BLOCK_SHOULDER_OFFSET * inward, 0.05, 0.95), wall_y
		),
	}


## Where this opponent setter takes the ball in serve receive: the same release
## the home side uses, mirrored, rather than a fixed point in the middle of the
## court. Shared so the reception's pass target and the setter's own position
## cannot drift apart and leave the ball landing somewhere the setter is not.
static func _opponent_setter_release_target(opponent_team: Resource) -> Vector2:
	if opponent_team == null:
		return Vector2(0.62, 0.34)
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	if opponent_lineup == null:
		return Vector2(0.62, 0.34)
	return CourtConstants.mirror_to_opponent(
		CourtConstants.setter_serve_receive_position(
			opponent_lineup.slot_for_player(opponent_lineup.active_setter_id())
		)
	)


## Time between the ball reaching the setter's hands and leaving them.
##
## Both halves of the setter's `SYSTEM_FIT_SET_RELEASE` profile are consumed:
## `ideal_value` is their natural rhythm (quick setters release sooner) and
## `tolerance` is how far off it they can work. A clean ball goes out at the
## fast edge of that band and a mishandled one at the slow edge, so an
## adaptable setter genuinely varies tempo with the ball they get while a rigid
## one clusters on their ideal. The band belongs to the player, not to a tuned
## constant here.
static func _release_interval(profile: SystemFitProfile, set_quality: float) -> float:
	var ideal := profile.ideal_value if profile != null \
		else DEFAULT_SET_RELEASE_SECONDS
	var band := profile.tolerance if profile != null \
		else DEFAULT_SET_RELEASE_TOLERANCE
	return clampf(
		ideal + lerpf(band, -band, clampf(set_quality, 0.0, 1.0)),
		MINIMUM_SET_RELEASE_SECONDS, MAXIMUM_SET_RELEASE_SECONDS,
	)


## A ball coming off the block, timed by geometry rather than a constant.
##
## The three deflection segments each carried a hardcoded 0.18-0.30 s. A stuff
## driven straight down is that fast. A ball squirting up off the hands and
## travelling four metres is not -- and the defender chasing it was drawn
## covering that ground in a quarter of a second, about sixteen metres a
## second. A stuff keeps its constant, because the rally ends on it and nobody
## chases; every other deflection now solves the same arc every other flight in
## this file solves.
func _block_deflection_trajectory(
	from_point: Vector2,
	to_point: Vector2,
	stuffed: bool,
	apex_hint: float,
	start_time: float,
) -> Dictionary:
	if stuffed:
		return _ball_trajectory(
			"block_deflection", from_point, to_point,
			BLOCK_STUFF_FLIGHT_SECONDS, apex_hint, start_time
		)
	var arc := RallyKinematics.solve_launch_arc(
		RallyKinematics.court_distance_meters(from_point, to_point),
		BLOCK_DEFLECTION_LAUNCH_ANGLE_DEGREES,
	)
	return _ball_trajectory(
		"block_deflection", from_point, to_point,
		maxf(float(arc.duration_seconds), BLOCK_DEFLECTION_MIN_SECONDS),
		maxf(float(arc.apex_height_meters), apex_hint),
		start_time,
	)


## The ball is contacted where the hitter can be, not where the set wanted them.
##
## `evaluate_takeoff` already knows this: on seed 6144 it reports a hitter
## covering 0.19 m of a 2.07 m runway inside a 0.228 s set flight -- 4.5% -- and
## the rally emitted the ATTACK event at the far end of that runway anyway.
## Nothing was wrong with the movement model; the resolver asked it a question,
## was told the hitter could not get there, and placed the contact there
## regardless. Playback then had to cover two metres in a quarter second, which
## is the 9.1 m/s teleport, and capping the animation would only have left the
## hitter short while the ball met empty air.
##
## So the contact slides back down the hitter's own path to the point they
## actually reach. A ball met at the wrong point is a worse ball -- already
## priced, through the negative arrival margin this same shortfall produces --
## and the swing still happens, from where the swing really is.
##
## All three attack paths call this, deliberately. It was first added to the
## home continuation alone, which left the opponent swinging at contacts it
## never reached: the same one-side-modelled-fully defect this engine has now
## produced ten times, and the tenth was introduced by the fix for the ninth.
static func _reachable_contact(
	hitter_start: Vector2,
	intended_contact: Vector2,
	hitter_move_time: float,
	flight_time: float,
) -> Vector2:
	if hitter_move_time <= flight_time or hitter_move_time <= 0.001:
		return intended_contact
	return hitter_start.lerp(
		intended_contact, clampf(flight_time / hitter_move_time, 0.0, 1.0)
	)


## The lateness that survives the clamp above.
##
## `_reachable_contact` exists precisely so a hitter who cannot get to the ideal
## contact strikes the ball short of it instead of missing -- it pulls the
## contact back to the point they reach as the ball arrives. So once it binds,
## the hitter is on time *by construction*, and the margin is zero.
##
## Both swings kept billing the pre-clamp figure. The opponent's hitter was
## therefore charged a mean 0.461 s of lateness against a contact they no longer
## took: the ball was moved to them and they were penalised for not reaching
## where it used to be. That single stale number was 0.662 of their 0.958 mean
## approach deficit, and it is why they backed off 71% of their swings against
## the home side's 2% -- the two sides run identical code and only this term
## binds on one of them.
##
## Returned from beside the clamp rather than recomputed at each call site, so
## the rule about when lateness survives lives in one place.
static func _clamped_arrival_margin(margin_before_clamp: float) -> float:
	if not RallyFeatureFlagsModel.ENABLE_CLAMPED_ARRIVAL_MARGIN:
		return margin_before_clamp
	## Exact against `_reachable_contact`'s own arithmetic: it either returns the
	## intended contact untouched, leaving a non-negative margin alone, or scales
	## the route so arrival lands on the ball. It shares that function's
	## constant-speed approximation of the route and adds no second one.
	return maxf(margin_before_clamp, 0.0)


## Land the set where the swing now happens.
##
## The set event is emitted before the hitter's route is known, so a clamped
## contact would otherwise leave the ball drawn to one point and struck at
## another. The flight time is deliberately *not* re-solved: a setter delivering
## short of the lane lofts the ball rather than releasing it earlier, so the
## hang time every later contact is timed from stays exactly as it was and only
## the landing point moves. Re-solving would also be circular -- a shorter ball
## flies for less time, which shortens the runway that produced the clamp.
func _retarget_set_event(
	set_event: RallyEvent,
	contact: Vector2,
	kind: String,
	flight_time: float,
	apex_height: float,
	release_time: float,
) -> void:
	if set_event == null or set_event.end_position.is_equal_approx(contact):
		return
	set_event.end_position = contact
	set_event.metadata["outgoing_trajectory"] = _ball_trajectory(
		kind, set_event.start_position, contact, flight_time, apex_height,
		release_time,
	)


## When the incoming ball actually arrived, from its own arc.
##
## Seven event stamps read `rally_clock` bare. The timestamp gate reports full
## coverage and no backwards steps for them, which is the point worth stating: a
## bare clock is not *wrong*, it is *underived*. It says "whenever the resolver
## happened to be" instead of "when this ball reached this player", and those agree
## only until something between the two contacts moves. Every one of the seven had
## the arc it was waiting on already in scope.
func _contact_time(trajectory: Dictionary, fallback: float) -> float:
	return float(trajectory.get("end_time", fallback))


## When the swing reached the tape, or `fallback` if this arc cannot say.
##
## A block is not timed like the contacts either side of it. Reception, set and dig
## all happen when the ball *finishes* its flight, so `_contact_time` is right for
## them; a block happens partway through one. `_net_crossing_time` below has always
## known how to find that instant and only the timeline finaliser was asking it --
## and only for blocks that never touched the ball. A block that *did* touch it took
## its moment from the deflection arc's own start timestamp, which was whatever the
## call site passed, so the hands moved on a clock nobody had derived.
##
## An on-time block and an on-time swing are the same moment in the sport, give or
## take the fraction of a second the ball takes to cross: on a normal cross-court
## swing from y 0.55 to 0.15 the tape sits an eighth of the way along.
func _swing_reaches_net(trajectory: Dictionary, fallback: float) -> float:
	var moment := _net_crossing_time(trajectory)
	return fallback if moment < 0.0 else moment


func _ball_trajectory(
	kind: String,
	start: Vector2,
	end: Vector2,
	flight_time: float,
	apex_height: float,
	start_timestamp: float = -1.0,
) -> Dictionary:
	var timestamp := rally_clock if start_timestamp < 0.0 else start_timestamp
	var direction := end - start
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var curve_amount := clampf(direction.length() * 0.08, 0.0, 0.035)
	var control := start.lerp(end, 0.5) + perpendicular * curve_amount
	var trajectory: Resource = BallTrajectoryModel.create(
		kind, start, control, end, timestamp, flight_time, apex_height
	)
	var data: Dictionary = trajectory.to_dict()
	## RallyKinematics solves vertical displacement above launch level. Preserve
	## that contract explicitly; legacy `apex_height_meters` is retained because
	## calibration reads it for the duration/rise invariant.
	data["apex_rise_meters"] = apex_height
	data["height_contract"] = "relative_rise"
	return data


func _desired_pass_target(release_target: Vector2, reception_contact: Vector2) -> Vector2:
	# A distant passer aims slightly higher/off the net to reduce overpass risk;
	# nearby passers can safely feed the setter's release point more directly.
	var distance_meters := Vector2(
		(reception_contact.x - release_target.x) * 9.0,
		(reception_contact.y - release_target.y) * 18.0,
	).length()
	var safety_offset := clampf((distance_meters - 4.0) * 0.006, 0.0, 0.045)
	return Vector2(release_target.x, clampf(release_target.y + safety_offset, 0.55, 0.70))


func _set_geometry(
	setter: VolleyballPlayer,
	setter_start: Vector2,
	contact: Vector2,
	target: Vector2,
	release_target: Vector2,
) -> Dictionary:
	var set_vector := Vector2((target.x - contact.x) * 9.0, (target.y - contact.y) * 18.0)
	var arrival_vector := Vector2(
		(contact.x - setter_start.x) * 9.0, (contact.y - setter_start.y) * 18.0
	)
	var distance_meters := set_vector.length()
	var release_distance := Vector2(
		(contact.x - release_target.x) * 9.0,
		(contact.y - release_target.y) * 18.0,
	).length()
	var angle_degrees := absf(rad_to_deg(set_vector.angle()))
	var orientation_fit := 1.0
	if arrival_vector.length() > 0.15 and set_vector.length() > 0.15:
		orientation_fit = clampf(
			(arrival_vector.normalized().dot(set_vector.normalized()) + 1.0) * 0.5,
			0.0, 1.0,
		)
	var net_distance_meters := absf(contact.y - CourtConstants.NET_Y) * 18.0
	var balance := _rating(setter, "set_balance")
	var stability := _rating(setter, "set_stability")
	var tight_risk := clampf((0.55 - net_distance_meters) * 0.10, 0.0, 0.055) \
		* lerpf(1.0, 0.55, stability)
	var distance_difficulty := maxf(distance_meters - 2.0, 0.0) * 0.012 \
		* lerpf(1.0, 0.68, stability)
	var orientation_difficulty := (1.0 - orientation_fit) * 0.10 \
		* lerpf(1.0, 0.48, balance)
	var difficulty := clampf(
		distance_difficulty
		+ release_distance * 0.020
		+ orientation_difficulty
		+ tight_risk,
		0.0, 0.28,
	)
	return {
		"distance_meters": distance_meters,
		"angle_degrees": angle_degrees,
		"release_distance_meters": release_distance,
		"body_orientation_fit": orientation_fit,
		"set_balance": balance,
		"set_stability": stability,
		"net_distance_meters": net_distance_meters,
		"difficulty": difficulty,
	}


func _reception_pass_result(
	receiver: VolleyballPlayer,
	start_position: Vector2,
	contact_position: Vector2,
	desired_target: Vector2,
	serve_origin: Vector2,
	serve_force: float,
	arrival: Dictionary,
	reception_quality: float,
	landing_min_y: float = 0.51,
	landing_max_y: float = 0.98,
	## The flight the defender is receiving. Only the recovery bands read it, so a
	## real ball speed can decide whether someone is driven off a serve without
	## re-rating the platform feasibility that every reception in the game is
	## calibrated against.
	incoming_trajectory: Dictionary = {},
) -> Dictionary:
	var movement_vector := contact_position - start_position
	var desired_vector := desired_target - contact_position
	var incoming_vector := contact_position - serve_origin
	var movement_direction := movement_vector.normalized() \
		if movement_vector.length() > 0.008 else desired_vector.normalized()
	var desired_direction := desired_vector.normalized()
	var incoming_direction := incoming_vector.normalized()
	var movement_alignment := clampf(
		(movement_direction.dot(desired_direction) + 1.0) * 0.5, 0.0, 1.0
	)
	var redirect_demand := clampf(
		absf(incoming_direction.angle_to(desired_direction)) / PI, 0.0, 1.0
	)
	var reach_margin := float(arrival.get("reach_margin_meters", -0.5))
	var settle_factor := clampf((reach_margin + 0.25) / 1.25, 0.0, 1.0)
	var edge_ratio := float(arrival.get("edge_ratio", 1.0))
	var body_alignment := clampf(
		movement_alignment * 0.42 + settle_factor * 0.38
		+ (1.0 - clampf(edge_ratio, 0.0, 1.2) / 1.2) * 0.20,
		0.0, 1.0,
	)
	var platform_feasibility := clampf(
		_rating(receiver, "reception") * 0.30
		+ _rating(receiver, "ball_control") * 0.18
		+ _rating(receiver, "reception_balance") * 0.15
		+ _rating(receiver, "reception_stability") * 0.14
		+ body_alignment * 0.18
		+ settle_factor * 0.12
		- redirect_demand * 0.08
		- serve_force * (1.0 - _rating(receiver, "reception_stability")) * 0.16,
		0.0, 1.0,
	)
	var execution := clampf(
		platform_feasibility * 0.66 + reception_quality * 0.34, 0.0, 1.0
	)
	var error_scale := pow(1.0 - execution, 1.35)
	var perpendicular := Vector2(-desired_direction.y, desired_direction.x)
	## Normal rather than uniform, matched on deviation so an ordinary pass
	## scatters exactly as far as it used to. Under a uniform, a passer whose
	## `error_scale` was small enough simply could not put the ball outside a
	## fixed box around the setter -- not unlikely, impossible -- which is the
	## same shape of defect that made block outcomes unreachable.
	var directional_error := _normal_from_uniform_halfwidth(0.30) * error_scale
	var depth_error := _normal_from_uniform_halfwidth(0.24) * error_scale
	var destination := desired_target \
		+ perpendicular * directional_error + desired_direction * depth_error
	if execution < 0.18:
		destination += Vector2(
			rng.randf_range(-0.25, 0.25), rng.randf_range(-0.04, 0.18)
		)
	## The half the ball has to stay on. Hardcoded to the home court until the
	## opponent needed the same function, which is the whole reason they did not
	## have it: a pass that could only land between y 0.51 and 0.98 was a pass
	## only one team could throw.
	destination = Vector2(
		clampf(destination.x, 0.02, 0.98),
		clampf(destination.y, landing_min_y, landing_max_y),
	)
	var pass_distance := CoverageModel.court_distance_meters(
		contact_position, destination
	)
	var flight_time := clampf(
		0.38 + pass_distance / lerpf(5.2, 8.4, execution), 0.42, 1.25
	)
	var posture := "planted"
	if reach_margin < 0.0:
		posture = "reaching"
	elif movement_alignment < POSTURE_OFF_AXIS_ALIGNMENT:
		## Read off the *directional* term rather than the composite. Measured,
		## `body_alignment` is partly built from the edge ratio, so testing
		## off-axis against it meant testing the moving signal twice: whichever of
		## the two branches came first swallowed the other, and the loser was dead
		## whatever its threshold. `movement_alignment` is the one term that is
		## purely about which way the body was going.
		posture = "off-axis"
	elif edge_ratio > POSTURE_MOVING_EDGE_RATIO:
		posture = "moving"
	return {
		"destination": destination,
		"body_alignment": body_alignment,
		"platform_feasibility": platform_feasibility,
		"contact_posture": posture,
		## Control, not execution. A reception's `execution` averages around two
		## thirds and a dig's quality around a third, so handing the shared bands
		## each side's raw figure made the states unreachable on one path and
		## routine on the other -- measured, receptions came back 100% platform
		## while a third of digs went to a knee.
		##
		## Both are now the same question: how well did the contact hold up
		## against what it faced. For a dig that is quality against the swing; for
		## a reception it is execution against how hard the ball arrived.
		"contact_recovery": _contact_recovery_state(
			receiver, posture, execution,
			_incoming_ball_force(incoming_trajectory, serve_force),
		),
		## Reported so the census can measure the two inputs the bands read,
		## rather than inferring their distribution from the outcome.
		"contact_control": execution,
		"movement_alignment": movement_alignment,
		"incoming_force": _incoming_ball_force(incoming_trajectory, serve_force),
		"incoming_speed_mps": _incoming_ball_speed(incoming_trajectory),
		"trajectory": _ball_trajectory(
			"reception_pass", contact_position, destination,
			flight_time, lerpf(1.1, 2.8, execution), rally_clock
		),
	}


## Whether a defender stayed on their feet, and what happened to them if not.
##
## `contact_posture` says how *strained* the contact was; this says what the
## strain did to the player. They are separate axes on purpose: a reaching
## contact taken well leaves a defender standing, and a planted contact taken
## into a ball travelling far too fast does not.
##
## Four states, in ascending cost, and every one of them is legible from the
## stands without a caption:
##
## - **platform** -- stayed up, played it off the forearms.
## - **knee** -- went down on one knee to finish the play. Follows a *reaching*
##   or *moving* contact taken poorly, or comes from a defender whose reception
##   stability is low enough that they go down on ordinary balls too.
## - **fall** -- went to the floor. Follows an *off-axis* contact taken poorly,
##   or a defender with low reception balance -- being unable to square up and
##   being unable to stay up are the same failing seen twice.
## - **blown_away** -- did not play it so much as get hit by it. Requires *both*
##   a badly taken contact **and** a ball arriving hard, which is why it cannot
##   come from a reaching contact: a defender already stretched for a ball is
##   not standing in front of it.
##
## The costs are what make this more than a pose. A knee or a fall takes the
## defender out of the next contact; being blown away takes them out of the
## rally. That is the first time a defensive *success* has a price, which is the
## whole reason the knee was worth modelling -- see `docs/design/CLUB_LIFE.md` on
## failure being legible and gentle.
##
## Thresholds are named rather than inline so the four bands can be retuned as a
## set. A recovery state that fires on a third of contacts is wallpaper; one that
## fires on none is a pose nobody sees.
## How badly a contact has to go, per contact type.
##
## **Two thresholds per type, not one shared pair**, and that is a measurement
## rather than a preference. `contact_control` puts both contacts on the same
## *axis*, but not in the same *place* on it: measured over 720 rallies, a
## reception's control sits at a median of 0.81 while a dig's sits at 0.37,
## because receiving a serve in this engine is genuinely much easier than digging
## a swing. One shared threshold cannot describe both -- the pair that gave digs a
## sane 18% knee rate made receptions literally unreachable at 100% platform, and
## the pair that reached receptions put a third of all digs on the floor.
##
## What a contact of each posture normally produces, measured over 1,078 of them.
##
## **`poor` is relative to the posture, not to the contact type.** That is the
## finding this table exists to record. A flat threshold made the two conditions
## the bands ask for -- a poor contact *and* a difficult posture -- into the same
## condition: cross-tabulated, 138 of 155 reaching contacts were poor and 0 of 431
## off-axis ones were, because a reaching contact scores badly *by definition* and
## an off-axis one does not. So "reaching and poor" meant reaching, "off-axis and
## poor" meant never, and two of the four bands were unreachable while a third was
## wallpaper.
##
## Posture also explains most of what looked like a contact-type difference: a
## dig's control sits far below a reception's mainly because a third of digs are
## reaching and almost no receptions are. One table replaces two.
const POSTURE_EXPECTED_CONTROL := {
	"planted": 0.54,
	"moving": 0.59,
	"reaching": 0.08,
	"off-axis": 0.61,
}

## How far below its posture's norm a contact has to fall to be poor, as a
## *share* of that norm rather than a flat subtraction.
##
## Flat did not survive contact with the table above. A reaching contact normally
## scores 0.08, so subtracting a fixed 0.09 gave it a negative threshold and made
## the branch impossible -- the same "band outside its own distribution" failure as
## the speed range and the alignment bound, arrived at from the opposite direction.
## Proportional puts roughly the worst quarter of every posture below the line, on
## a scale that spans an order of magnitude.
const RECOVERY_POOR_SHARE: float = 0.18
const RECOVERY_LOW_FOOTING: float = 0.34
const RECOVERY_LOW_BALANCE: float = 0.34

## How hard the ball has to arrive to drive an average voli off it, on the force
## scale above -- about 17 m/s, which the census puts in the top tenth of arcs.
##
## **One gate, not two.** The band originally asked for a *dire* contact as well
## as a heavy ball, and measured that turned out to be self-defeating: the
## contacts with the worst control are the ones the defender had to stretch for,
## and a defender stretching is explicitly not being blown away. Requiring both
## made the band structurally empty -- 0 of 1,078 contacts. What actually happens
## is a defender standing in the right place taking something too fast for them,
## so the force does the work and a poor contact is the qualifier.
const RECOVERY_HEAVY_FORCE: float = 0.78

## Where a contact stops being planted, per branch.
##
## All three were inline numbers, and two of them sat outside the distribution
## they were testing. Measured over 1,078 contacts: `body_alignment` runs from a
## 5th percentile of 0.442 upward, so an off-axis bound of 0.42 could never fire,
## and `edge_ratio` reaches 0.82 in only the top tenth. The consequence was not
## subtle -- **the off-axis and moving dig postures were never drawn in a live
## match at all**, and two of the four bodies built for playback existed only in
## the portfolio.
##
## Re-centred so each branch owns a real share: off-axis about a seventh of
## contacts, moving about a fifth. The ordering is unchanged -- a defender who
## could not reach it is described as reaching first, whatever else was also true.
## Off-axis is tested *before* moving, and that ordering is load-bearing. Low
## alignment and a high edge ratio are strongly correlated -- alignment is partly
## built from the edge ratio -- so with moving first, every off-axis contact was
## classified as moving instead and the branch stayed dead even after its bound
## was corrected. "Could not square up" is the more specific claim of the two.
## Both from the measured distribution of the term each one tests:
## `movement_alignment` has a median of 0.254 -- a receiver ordinarily moves toward
## the ball rather than toward the setter -- and `edge_ratio` a median of 0.239.
const POSTURE_OFF_AXIS_ALIGNMENT: float = 0.10
const POSTURE_MOVING_EDGE_RATIO: float = 0.42

## A dig says the same four things from different evidence.
##
## `timing` cannot serve as the moving test here: it is derived from the reach
## margin, so a defender who was *not* reaching always scores 1.0 and the branch is
## unreachable by construction rather than by threshold. Distance travelled is the
## honest signal -- a defender who ran two metres dug it on the move.
##
## The body-penalty bound is small because the term is: measured, it runs 0.01 to
## 0.04, so a bound of 0.34 was testing against a number that never gets there.
const POSTURE_DIG_OFF_AXIS_PENALTY: float = 0.045
const POSTURE_DIG_MOVING_METERS: float = 1.6

## The speed band the force is read against, in metres per second.
##
## Set from the engine's own arcs, not from real volleyball. The first version used
## 9-26 m/s, which is roughly right for a real jump serve and roughly double what
## this engine draws: measured, balls arrive at a median of 7-11 m/s with a 95th
## percentile near 20, so a 26 m/s ceiling put every contact in the bottom third
## of the band and made `blown_away` unreachable at any threshold. A band has to
## span the distribution it is normalising, or it is not normalising it.
const RECOVERY_SLOW_BALL_MPS: float = 7.0
const RECOVERY_FAST_BALL_MPS: float = 20.0

## Reference mass for the anchor term, in kilos. A voli at this weight neither
## resists nor invites being driven off a ball; the roster spans roughly 55-115.
const RECOVERY_REFERENCE_MASS_KG: float = 82.0

## How long each state costs the player, in seconds, before they are a defender
## again. These are the numbers that make a recovery a *rally* event rather than
## a pose: a knee is most of a contact, a fall is a contact and the transition
## after it, and being blown away is the rest of the exchange.
const RECOVERY_DELAY_SECONDS := {
	"platform": 0.0,
	"knee": 0.55,
	"fall": 0.95,
	"blown_away": 1.35,
}

## How much of a dig a defender who is still getting up gives away, at the moment
## they hit the floor. Scales to nothing as their debt runs out.
const RECOVERY_DIG_PENALTY: float = 0.55

## What one trip to the floor costs in condition. Small per event and deliberately
## ordered like the delays -- a libero who hits the floor every rally should feel
## it by the fifth set, not by the second point.
const RECOVERY_FATIGUE_COST := {
	"platform": 0.0,
	"knee": 0.004,
	"fall": 0.008,
	"blown_away": 0.013,
}


## How well this voli stays on their feet, as three separate questions.
##
## The first version of this read two raw attributes and nothing else, which made
## every band a referendum on a single number -- and left `composure`,
## `explosiveness`, `work_rate`, `ball_control` and the voli's own *mass* with no
## say in whether they ended up on the floor, despite all five being exactly what
## decides it.
##
## They are kept as three composites rather than one, because the three outcomes
## are not degrees of the same failing:
##
## - **footing** is staying square and re-planting -- the knee band.
## - **balance** is not toppling when you could not square up -- the fall band.
## - **anchor** is not being moved by the ball at all -- the blow-away band, and
##   the only one where being *heavy* is an advantage.
## How hard the ball was actually travelling, from the flight that was drawn.
##
## The recovery bands used to be handed a *quality* -- the serve's rating, or the
## attack's effectiveness -- as their idea of force, which meant a perfectly
## placed floater and a jump serve at the same rating hit a defender equally hard.
## Speed is a property of the arc, and the arc is already built and drawn, so this
## reads it rather than standing in for it: distance over duration, normalised
## into the band above. `fallback` covers the paths where no trajectory exists
## yet, so the change can never make a contact forceless.
func _incoming_ball_force(trajectory: Dictionary, fallback: float) -> float:
	var speed := _incoming_ball_speed(trajectory)
	if speed <= 0.0:
		return clampf(fallback, 0.0, 1.0)
	return clampf(
		inverse_lerp(RECOVERY_SLOW_BALL_MPS, RECOVERY_FAST_BALL_MPS, speed),
		0.0, 1.0,
	)


## Ground speed of the drawn arc, in metres per second, or zero when there is no
## arc to read. Separate from the force so the census can report the raw figure --
## the first version of the band was set from real volleyball speeds and left
## `blown_away` unreachable, because this engine's balls travel at about half of
## them and no amount of tuning a threshold fixes a wrong axis.
func _incoming_ball_speed(trajectory: Dictionary) -> float:
	var duration := float(trajectory.get("duration", 0.0))
	if duration <= 0.01:
		return 0.0
	var metres := CoverageModel.court_distance_meters(
		Vector2(trajectory.get("start_position", Vector2.ZERO)),
		Vector2(trajectory.get("end_position", Vector2.ZERO)),
	)
	if metres <= 0.05:
		return 0.0
	return metres / duration


## What a dig cost the defender, on the same four bands as a reception.
##
## A dig is the same act with a harder ball, so it resolves through the same
## function -- but its inputs have to be translated, because a dig *quality* is
## not a reception *execution*: dig quality averages around a third where
## reception execution averages around two thirds, so feeding it in raw would put
## nearly every dig in the world on the floor.
##
## The honest translation is the margin. A dig that comfortably beat the swing it
## faced was clean; one that barely survived was desperate; one that lost was a
## body on the floor. That is exactly the comparison `_dig_contest` already makes,
## so the recovery is read off the same difference the outcome is.
func _dig_recovery(
	defender: VolleyballPlayer,
	dig_terms: Dictionary,
	attack_quality: float,
	trajectory: Dictionary,
	travel_meters: float = 0.0,
) -> String:
	if defender == null:
		return "platform"
	## The dig's own quality, unadjusted. It used to be netted against the swing
	## it faced, which double-counted the ball: a hard swing lowered the control
	## figure *and* then satisfied the force gate, so the two conditions the
	## blow-away band wanted to be independent were the same condition twice.
	## Measured, that put 44% of receptions in the blow-away band. Force is now
	## only ever read once, as force.
	var execution := clampf(float(dig_terms.get("quality", 0.0)), 0.0, 1.0)
	var posture := "planted"
	if float(dig_terms.get("reach_margin_meters", 0.0)) < 0.0:
		posture = "reaching"
	elif float(dig_terms.get("posture", 0.0)) > POSTURE_DIG_OFF_AXIS_PENALTY:
		posture = "off-axis"
	elif travel_meters > POSTURE_DIG_MOVING_METERS:
		posture = "moving"
	last_dig_control = execution
	last_dig_force = _incoming_ball_force(trajectory, attack_quality)
	last_dig_speed = _incoming_ball_speed(trajectory)
	last_dig_posture = posture
	return _contact_recovery_state(
		defender, posture, execution, last_dig_force, "dig"
	)


func _recovery_footing(receiver: VolleyballPlayer) -> float:
	## `work_rate` subtracts on purpose. A defender who works harder does not stay
	## up more -- they commit to balls a lazier one lets drop, and going to a knee
	## is what committing looks like. Modelling effort as poise would have made the
	## most willing defenders the ones who never go down, which is backwards.
	## The four positive weights sum to one, and `work_rate` is signed against its
	## midpoint rather than subtracted outright. Weights that summed to less than
	## one silently moved every voli toward the floor -- an ordinary defender rated
	## 0.35 across the board scored 0.30 against a 0.34 threshold and went down on
	## every single contact, which is a scale error wearing the costume of a
	## design decision.
	return clampf(
		_rating(receiver, "reception_stability") * 0.52
		+ _rating(receiver, "explosiveness") * 0.20
		+ _rating(receiver, "composure") * 0.16
		+ _rating(receiver, "ball_control") * 0.12
		- (_rating(receiver, "work_rate") - 0.5) * 0.14,
		0.0, 1.0,
	)


func _recovery_balance(receiver: VolleyballPlayer) -> float:
	return clampf(
		_rating(receiver, "reception_balance") * 0.48
		+ _rating(receiver, "ball_control") * 0.20
		+ _rating(receiver, "composure") * 0.17
		+ _rating(receiver, "lateral_speed") * 0.15,
		0.0, 1.0,
	)


## Resistance to simply being driven off the ball. Mass is real here and nowhere
## else in the recovery model: a heavy voli is harder to move and no steadier for
## it, which is the one place in the game where the heaviest bodies have a plain
## physical advantage rather than a stylistic one.
func _recovery_anchor(receiver: VolleyballPlayer) -> float:
	if receiver == null:
		return 0.5
	var mass_edge := clampf(
		(receiver.mass_kg - RECOVERY_REFERENCE_MASS_KG) / 60.0, -0.45, 0.45
	)
	return clampf(
		_rating(receiver, "reception_stability") * 0.46
		+ _rating(receiver, "explosiveness") * 0.28
		+ _rating(receiver, "composure") * 0.26
		+ mass_edge * 0.40,
		0.0, 1.0,
	)


## What a receiver brings to a serve reception, before the serve itself is
## weighed. One formula for both sides of the net.
##
## Written out twice before this: the home side (opponent serving) summed
## reception 0.65 + ball_control 0.20 + composure 0.15 -- three attributes to
## 1.0. The opponent side (home serving) summed reception 0.58 + ball_control
## 0.24 -- two attributes to 0.82, composure never read at all. Measured across
## 629 receptions on identical rosters: home reception quality averaged 0.606,
## the opponent's 0.378 -- the largest single asymmetry in the engine, and it
## was upstream of the whole chain the set-quality histogram measured
## downstream of it (opponent set capability_penalty 0.297 against home's
## 0.132, opponent attack error 47.7% against home's 15.4%). Composure alone
## does not explain a 0.228 gap; the short weights did the rest.
func _reception_skill(receiver: VolleyballPlayer) -> float:
	return _rating(receiver, "reception") * 0.65 \
		+ _rating(receiver, "ball_control") * 0.20 \
		+ _rating(receiver, "composure") * 0.15


func _contact_recovery_state(
	receiver: VolleyballPlayer,
	posture: String,
	control: float,
	incoming_force: float,
	contact_kind: String = "reception",
) -> String:
	var footing := _recovery_footing(receiver)
	var balance := _recovery_balance(receiver)
	var poor := control < float(
		POSTURE_EXPECTED_CONTROL.get(posture, 0.54)
	) * (1.0 - RECOVERY_POOR_SHARE)

	## Checked first, because being knocked off a ball overrides every softer
	## thing that could also have been true of the same contact.
	##
	## The force the ball has to bring is set by the defender rather than by a
	## constant: an anchored voli needs a genuinely heavy ball to be moved, a
	## light one is moved by less. At the reference anchor this is exactly the
	## old threshold, so the band is widened in both directions rather than
	## loosened.
	var force_needed := RECOVERY_HEAVY_FORCE \
		+ (_recovery_anchor(receiver) - 0.5) * 0.44
	if poor and incoming_force >= force_needed \
			and posture in ["planted", "off-axis", "moving"]:
		return "blown_away"
	if (posture == "off-axis" and poor) or balance < RECOVERY_LOW_BALANCE:
		return "fall"
	if (poor and posture in ["reaching", "moving"]) \
			or footing < RECOVERY_LOW_FOOTING:
		return "knee"
	return "platform"


## Record what a contact cost the player who made it, and charge it.
##
## Two costs, and they are different in kind. The *delay* is spent inside this
## rally -- it is why a defender who dug off the floor is not the one covering
## the next ball -- and the *fatigue* is spent across the match. Both are booked
## here so no call site can take the pose without the price.
func _note_recovery(
	player: VolleyballPlayer, state: String, at_time: float
) -> void:
	if player == null or state == "platform":
		return
	var delay := float(RECOVERY_DELAY_SECONDS.get(state, 0.0))
	if delay <= 0.0:
		return
	## A springy defender is back up sooner. Bounded so the difference between the
	## quickest and the slowest voli is meaningful without letting anyone shrug
	## off a blow-away.
	var quickness := clampf(
		_rating(player, "explosiveness") * 0.6 + _rating(player, "work_rate") * 0.4,
		0.0, 1.0,
	)
	var scaled := delay * lerpf(1.28, 0.74, quickness)
	player_recovery[player.id] = {
		"state": state,
		"ready_at": at_time + scaled,
		"delay": scaled,
	}
	## Recorded, not charged. See `RallyResult.recovery_fatigue`.
	var cost := float(RECOVERY_FATIGUE_COST.get(state, 0.0))
	if cost > 0.0:
		recovery_fatigue_cost[player.id] = float(
			recovery_fatigue_cost.get(player.id, 0.0)
		) + cost


## The seconds each player still owes, in the shape `choose_claimant` takes.
##
## This is where a recovery stops being bookkeeping. A defender getting off the
## floor has less of the next ball's flight available to reach it -- literally,
## not as a penalty -- so the claim search sees a shorter clock for them and
## somebody else takes the ball. Without it the whole cost was inert: measured,
## zero digs in 720 rallies were ever taken out of a recovery.
## How many players are on the floor right now. Reported on contacts so the census
## can see the cost being paid: the *primary* effect of a recovery is that the
## player is not chosen for the next ball at all, which makes the dig-quality
## multiplier invisible in the outcome -- the exclusion succeeded, so the excluded
## player never appears in the sample. A count of who was down is the thing that
## can actually be observed.
func _recovering_count(at_time: float) -> int:
	return _recovery_time_penalties(at_time).size()


func _recovery_time_penalties(at_time: float) -> Dictionary:
	var penalties := {}
	for player_id in player_recovery:
		var record: Dictionary = player_recovery[player_id]
		var owed := float(record.get("ready_at", 0.0)) - at_time
		if owed > 0.01:
			penalties[player_id] = owed
	return penalties


## How much of their recovery this player still owes at `at_time`, as a fraction
## of the debt they took on. Zero once they are up.
func _recovery_debt(player_id: int, at_time: float) -> float:
	var record: Dictionary = player_recovery.get(player_id, {})
	if record.is_empty():
		return 0.0
	var delay := float(record.get("delay", 0.0))
	if delay <= 0.0:
		return 0.0
	return clampf((float(record.get("ready_at", 0.0)) - at_time) / delay, 0.0, 1.0)


## Who is physically taking this second contact, and from where.
##
## The candidate list, their starting positions and the designated setter's id
## all arrive as arguments rather than being read off `lineup` and
## `live_positions` directly, because both sides of the net need this and they
## keep their players in different places. That was the whole defect: the home
## side ran this and `_second_contact_setter` below, and the opponent ran
## `opponent_team.setter()` -- one line, always the same player, including on
## the ball that player had just dug themselves.
##
## On identical rosters that showed up as a `capability` term of 0.625 for the
## home transition set against 0.878 for the opponent's, which is only possible
## if the two sides are choosing different people to set. One of them was not
## choosing at all.
func _spatial_setter_choice(
	candidates: Array[VolleyballPlayer],
	starts: Dictionary,
	defensive_plan: Resource,
	designated_setter_id: int,
	first_contact_player_id: int,
	preferred_setter: VolleyballPlayer,
	target: Vector2,
	available_time: float,
) -> Dictionary:
	var best := {"player": preferred_setter, "start": target, "travel_time": 4.0}
	var best_score := -1000.0
	for candidate in candidates:
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var start: Vector2 = starts.get(candidate.id, target)
		## Getting up comes out of the same budget as getting there. A voli still
		## on the floor is not a candidate to set the next ball, and this is what
		## says so -- without it the emergency setter search would happily pick
		## someone lying down because they were standing in the right place.
		var travel_time := _movement_time(candidate, start, target, "transition") \
			+ float(player_recovery.get(candidate.id, {}).get("delay", 0.0)) \
			* _recovery_debt(candidate.id, rally_clock)
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var duty := str(assignment.second_contact_responsibility) \
			if assignment != null else "No second-contact duty"
		var duty_bonus := 0.0
		match duty:
			"Primary emergency setter": duty_bonus = 0.34
			"Secondary emergency setter": duty_bonus = 0.18
			"Stay available to attack": duty_bonus = -0.16
			"No second-contact duty": duty_bonus = -0.24
		if candidate.id == designated_setter_id:
			duty_bonus += 0.46
		elif candidate == preferred_setter:
			duty_bonus += 0.20
		var arrival_score := clampf((available_time - travel_time) / 1.2, -1.0, 1.0)
		var score := arrival_score * 0.52 \
			+ _rating(candidate, "set_accuracy") * 0.28 \
			+ _rating(candidate, "decision_making") * 0.12 + duty_bonus
		if score > best_score:
			best_score = score
			best = {"player": candidate, "start": start, "travel_time": travel_time}
	return best


## The designated setter, unless they took the first contact -- then whoever the
## plan nominated to cover for them.
func _second_contact_setter(
	candidates: Array[VolleyballPlayer],
	defensive_plan: Resource,
	designated_setter_id: int,
	first_contact_player_id: int,
) -> VolleyballPlayer:
	var regular_setter := _player_by_id(candidates, designated_setter_id)
	if regular_setter != null and regular_setter.id != first_contact_player_id:
		return regular_setter
	var best: VolleyballPlayer
	var best_score := -1000.0
	for candidate in candidates:
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.second_contact_responsibility) \
			if assignment != null else "No second-contact duty"
		var responsibility_bonus := 0.0
		match responsibility:
			"Primary emergency setter":
				responsibility_bonus = 0.42
			"Secondary emergency setter":
				responsibility_bonus = 0.24
			"Stay available to attack":
				responsibility_bonus = -0.10
			"No second-contact duty":
				responsibility_bonus = -0.22
		var score := _rating(candidate, "set_accuracy") * 0.44 \
			+ _rating(candidate, "ball_control") * 0.28 \
			+ _rating(candidate, "decision_making") * 0.16 \
			+ responsibility_bonus
		if score > best_score:
			best = candidate
			best_score = score
	return best


## The six players on court and where each of them currently is, in the shape
## the two selectors above take. One per side, because that is the only thing
## about second-contact selection that differs between them.
func _home_second_contact_candidates(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> Dictionary:
	var candidates: Array[VolleyballPlayer] = []
	var starts := {}
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null:
			continue
		candidates.append(candidate)
		starts[candidate.id] = live_positions.get(
			candidate.id, CourtConstants.slot_position(slot_number)
		)
	return {"candidates": candidates, "starts": starts}


func _opponent_second_contact_candidates(opponent_team: Resource) -> Dictionary:
	var candidates: Array[VolleyballPlayer] = []
	var starts := {}
	if opponent_team == null:
		return {"candidates": candidates, "starts": starts}
	for raw_candidate in opponent_team.on_court_players():
		var candidate: VolleyballPlayer = raw_candidate as VolleyballPlayer
		if candidate == null:
			continue
		candidates.append(candidate)
		starts[candidate.id] = opponent_live_positions.get(
			candidate.id,
			opponent_team.court_position(candidate.id, "transition"),
		)
	return {"candidates": candidates, "starts": starts}


func _home_block_deflection_target(
	original_target: Vector2,
	attack_x: float,
	block_quality: float,
	outcome: String,
	relationship: String,
) -> Vector2:
	if outcome == "touch":
		return Vector2(
			clampf(attack_x + rng.randf_range(-0.16, 0.16), 0.08, 0.92),
			rng.randf_range(0.58, lerpf(0.82, 0.69, block_quality)),
		)
	var funnel_x := 0.50
	if relationship == "Defend Line":
		funnel_x = 0.35 if attack_x < 0.5 else 0.65
	elif relationship == "Defend Cross":
		funnel_x = 0.72 if attack_x < 0.5 else 0.28
	return Vector2(
		clampf(lerpf(original_target.x, funnel_x, 0.26), 0.08, 0.92),
		clampf(original_target.y + 0.02, 0.54, 0.94),
	)


func _resolve_attack_coverage(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	blocked_hitter: VolleyballPlayer,
	target: Vector2,
	block_quality: float,
) -> Dictionary:
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == blocked_hitter.id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.attack_coverage_responsibility) \
			if assignment != null else "Cover nearest attacker"
		var start := CourtConstants.slot_position(slot_number)
		if defensive_plan != null:
			start = defensive_plan.defender_position(candidate.id, start)
		start = live_positions.get(candidate.id, start)
		var proximity := 1.0 - clampf(
			CoverageModel.court_distance_meters(start, target) / 9.0, 0.0, 1.0
		)
		var responsibility_bonus := 0.0
		match responsibility:
			"Cover nearest attacker":
				responsibility_bonus = proximity * 0.20
			"Cover assigned hitter":
				responsibility_bonus = 0.13
			"Take second contact":
				responsibility_bonus = 0.07
			"Release for transition":
				responsibility_bonus = -0.14
		var deflection_priority := int(assignment.deflection_priority) \
			if assignment != null else 1
		var score := proximity * 0.42 \
			+ _rating(candidate, "ball_control") * 0.24 \
			+ _rating(candidate, "anticipation") * 0.18 \
			+ responsibility_bonus + float(deflection_priority - 1) * 0.045
		if score > best_score:
			best = candidate
			best_score = score
	if best == null:
		return {"player": null, "quality": 0.0, "success": false}
	var quality := clampf(
		best_score - block_quality * 0.22 + rng.randf_range(-0.10, 0.10),
		0.0, 1.0,
	)
	return {"player": best, "quality": quality, "success": quality >= 0.32}


func _finish_serve_error(result: Resource, server_name: String) -> Resource:
	return _finish(result, "serve_error", true, -1, {"server": server_name})


func _finish(
	result: Resource,
	outcome: String,
	home_won: bool,
	decisive_actor_id: int,
	values: Dictionary,
	explanation_key: String = "",
) -> Resource:
	result.home_team_won = home_won
	result.terminal_outcome = outcome
	result.decisive_actor_id = decisive_actor_id
	result.recovery_fatigue = recovery_fatigue_cost.duplicate()
	var chosen_key := explanation_key if not explanation_key.is_empty() else outcome
	result.explanation = ExplanationText.explanation(chosen_key, values)
	var end_position := Vector2(0.5, 0.90) if home_won else Vector2(0.5, 0.12)
	_add_event(result, RallyEventModel.EventType.POINT, decisive_actor_id,
		"Home" if home_won else "Opponent", end_position, end_position,
		home_won, 1.0, ExplanationText.headline(outcome), result.explanation)
	result.analysis = _build_rally_analysis(result)
	for serve_key in geometric_serves:
		result.analysis[serve_key] = geometric_serves[serve_key]
	result.analysis["team_identity"] = str(home_principles.preset_name)
	result.analysis["team_principles"] = home_principles.to_dict()
	result.analysis["identity_effects"] = identity_effects.duplicate(true)
	if shadow_reception_trace != null:
		var existing_rollout: Dictionary = shadow_reception_trace.summary.get(
			"reception_rollout", {}
		)
		if str(existing_rollout.get("selected_source", "official")) == "official":
			existing_rollout["selected_event_count"] = result.events.size()
			existing_rollout["official_identity_preserved"] = true
			shadow_reception_trace.summary["reception_rollout"] = existing_rollout
		shadow_reception_trace.summary["serve_to_set_comparison"] = \
			RallyShadowComparisonModel.compare_serve_to_set(
				result.events, shadow_reception_trace.summary
			)
		if not shadow_reception_trace.summary.has("reception_rollout"):
			var rollout := RallyRolloutPolicyModel.select_reception_source(
				result.events, shadow_reception_trace.summary
			)
			rollout.erase("selected_events")
			rollout.erase("selected_reception")
			shadow_reception_trace.summary["reception_rollout"] = rollout
		result.analysis["shadow_reception"] = shadow_reception_trace.to_dict()
	_finalize_rally_timeline(result)
	return result


func _build_rally_analysis(result: Resource) -> Dictionary:
	var attack_types: Array[String] = []
	var directions: Array[String] = []
	var longest_movement := 0.0
	var lowest_arrival_margin := 99.0
	var blocker_read_values: Array[float] = []
	for event_resource in result.events:
		var event: Resource = event_resource
		if int(event.event_type) == RallyEventModel.EventType.ATTACK:
			var attack_type := str(event.metadata.get("attack_type", "Attack"))
			if attack_type not in attack_types:
				attack_types.append(attack_type)
			var direction := str(event.metadata.get("attack_direction", ""))
			if not direction.is_empty() and direction not in directions:
				directions.append(direction)
		longest_movement = maxf(longest_movement, float(event.metadata.get("movement_duration", 0.0)))
		## Seconds, and only seconds. `arrival_margin` on an event is a hitter's
		## or a setter's time to spare; a defender's margin lives under
		## `reach_margin_meters` because it is a distance. This loop used to take
		## a `min` across both, so the answer was whichever unit happened to
		## produce the smaller number.
		if event.metadata.has("arrival_margin"):
			lowest_arrival_margin = minf(lowest_arrival_margin, float(event.metadata.arrival_margin))
		if event.metadata.has("read_quality"):
			blocker_read_values.append(float(event.metadata.read_quality))
	var average_read := -1.0
	if not blocker_read_values.is_empty():
		average_read = 0.0
		for value in blocker_read_values:
			average_read += value
		average_read /= blocker_read_values.size()
	return {"contacts": result.events.size() - 1,
		"attack_types": attack_types, "directions": directions,
		"longest_movement": longest_movement,
		"lowest_arrival_margin": lowest_arrival_margin if lowest_arrival_margin < 90.0 else 0.0,
		"average_block_read": average_read}


## When each event physically happened, on the clock the rally was simulated on.
##
## An event's moment is when its actor touches the ball and sends it, which is
## exactly its outgoing trajectory's `start_time`. Measured across 300 rallies,
## every event that carries both that and a resolver-supplied `event_time`
## agrees to within a microsecond, so the trajectory is authoritative and the
## hand-placed stamps are corroboration rather than a second opinion.
##
## Two kinds carry neither and are derived rather than invented:
##
##   A block that never touched the ball has an empty `outgoing_trajectory` --
##   the resolver deliberately emits no deflection segment for an untouched
##   ball -- and was stamped with bare `rally_clock`, which at that point is
##   still the moment the *set* left the setter's hands. That produced 90
##   blocks per 300 rallies recorded 0.782 s *before* the swing they blocked.
##   The real moment is when the ball crosses the net, which is a known
##   fraction along the attack's own flight.
##
##   POINT has no trajectory and no stamp at all. It happens when the ball
##   finishes, which is the last trajectory's end.
##
## The running maximum at the end is a causality floor, not a schedule: events
## are emitted in the order they occur, so a physical time may not precede the
## event before it. It is counted, because a floor that fires often would mean
## the derivations above are wrong.
func _stamp_physical_times(result: Resource) -> int:
	var corrections := 0
	var previous := 0.0
	var ball_free_at := 0.0
	for event_resource in result.events:
		var event: Resource = event_resource
		var metadata: Dictionary = event.metadata
		var trajectory: Dictionary = metadata.get("outgoing_trajectory", {})
		var moment := -1.0
		if trajectory.has("start_time"):
			moment = float(trajectory["start_time"])
		elif int(event.event_type) == RallyEventModel.EventType.BLOCK:
			## An untouched block: the ball passed the hands rather than meeting
			## them, so its moment is the net crossing of the swing it failed to
			## intercept. `incoming_trajectory` is that swing.
			## Ahead of the generic `event_time` fallback on purpose: the stamp
			## these blocks carry is the known-bad one, still holding the moment
			## the set left the setter's hands. Deriving beats trusting it.
			moment = _net_crossing_time(metadata.get("incoming_trajectory", {}))
			if moment < 0.0 and metadata.has("event_time"):
				moment = float(metadata["event_time"])
		elif metadata.has("event_time"):
			moment = float(metadata["event_time"])
		elif int(event.event_type) == RallyEventModel.EventType.POINT:
			moment = ball_free_at
		if moment < 0.0:
			moment = previous
		if moment < previous:
			corrections += 1
			metadata["physical_time_floored"] = previous - moment
			moment = previous
		metadata["physical_time"] = moment
		event.metadata = metadata
		previous = moment
		if trajectory.has("end_time"):
			ball_free_at = maxf(ball_free_at, float(trajectory["end_time"]))
		else:
			ball_free_at = maxf(ball_free_at, moment)
	return corrections


## Where the ball crosses the net on its way from a swing to the floor, as a
## fraction of that flight. A block that never touched it still happened, and
## it happened here.
func _net_crossing_time(attack_trajectory: Dictionary) -> float:
	if not attack_trajectory.has("start_time"):
		return -1.0
	var start := Vector2(attack_trajectory.get("start_position", Vector2(0.5, 0.6)))
	var end := Vector2(attack_trajectory.get("end_position", Vector2(0.5, 0.2)))
	var span := end.y - start.y
	if absf(span) < 0.0001:
		return float(attack_trajectory["start_time"])
	var fraction := clampf((CourtConstants.NET_Y - start.y) / span, 0.0, 1.0)
	return float(attack_trajectory["start_time"]) 		+ float(attack_trajectory.get("duration", 0.0)) * fraction


func _finalize_rally_timeline(result: Resource) -> void:
	_ensure_event_trajectories(result)
	result.analysis["physical_time_corrections"] = _stamp_physical_times(result)
	var timeline := 0.0
	for event_resource in result.events:
		var event: Resource = event_resource
		var metadata: Dictionary = event.metadata
		## What the resolver itself said, kept before this function replaces it.
		##
		## `event_time` is read here as a request and then written back over with
		## the finalised value, so the resolver's own physical timestamp -- the
		## one the rally was actually simulated on -- is destroyed on the way
		## out. Nothing downstream could tell a time the physics produced from a
		## time this loop invented, and the coverage question ("does every event
		## carry a real one?") could not be asked at all from outside.
		##
		## Recorded, not yet used. Driving playback from it means deleting the
		## accumulator that currently guarantees monotonic ordering, and that is
		## only safe once the coverage is known rather than assumed.
		var requested_time := float(metadata.get("event_time", timeline))
		if metadata.has("event_time"):
			metadata["resolver_event_time"] = requested_time
		timeline = maxf(timeline, requested_time)
		var movement_duration := float(metadata.get("movement_duration", 0.0))
		var flight_duration := float(metadata.get("flight_time", 0.0)) \
			if int(event.event_type) == RallyEventModel.EventType.SERVE else 0.0
		var trajectory_data: Dictionary = metadata.get("outgoing_trajectory", {})
		var trajectory_duration := float(trajectory_data.get("duration", 0.0))
		var default_duration := 0.12
		match int(event.event_type):
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				default_duration = 0.34
			RallyEventModel.EventType.SET:
				default_duration = 0.28
			RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK:
				default_duration = 0.24
			RallyEventModel.EventType.POINT:
				default_duration = 0.10
		var duration := maxf(
			default_duration,
			maxf(movement_duration, maxf(flight_duration, trajectory_duration))
		)
		metadata["event_time"] = timeline
		metadata["event_duration"] = duration
		event.metadata = metadata
		## The ball's own motion advances the rally clock. Nothing else does.
		##
		## This used to advance by `duration`, which is the longest of the ball's
		## flight, the actor's traversal, and a per-type floor -- so a defender
		## taking a read step held the ball in the air until they finished, and a
		## block that never touched it still cost 0.24 s of dead clock. Because
		## the running total is then `maxf`'d against each event's real physical
		## time, once the accumulation drifts ahead it stays ahead and pushes the
		## whole remainder of the rally later.
		##
		## Measured over 300 rallies: 0.96 s per rally of held ball against a
		## 5.78 s mean span -- 17% of playback, most of it DEFENSE at 0.483 s a
		## time with 126 of 162 bound by movement rather than by the ball.
		##
		## `event_duration` is untouched, so an actor's animation still knows how
		## long it takes; it now runs *alongside* the flight instead of in series
		## with it, which is what it does in the sport.
		timeline += maxf(flight_duration, trajectory_duration)


func _ensure_event_trajectories(result: Resource) -> void:
	for event_index in range(result.events.size()):
		var event: Resource = result.events[event_index]
		if event.event_type == RallyEventModel.EventType.POINT \
				or event.metadata.has("outgoing_trajectory"):
			continue
		var start: Vector2 = event.start_position
		var end: Vector2 = event.end_position
		if event.event_type == RallyEventModel.EventType.BLOCK \
				and event.metadata.has("deflection_target"):
			end = Vector2(event.metadata.deflection_target)
		var flight_time := float(event.metadata.get("flight_time", 0.0))
		if flight_time <= 0.0:
			match int(event.event_type):
				RallyEventModel.EventType.SERVE: flight_time = 0.72
				RallyEventModel.EventType.RECEPTION: flight_time = 0.62
				RallyEventModel.EventType.SET: flight_time = 0.72
				RallyEventModel.EventType.ATTACK: flight_time = 0.42
				RallyEventModel.EventType.BLOCK: flight_time = 0.24
				RallyEventModel.EventType.DEFENSE: flight_time = 0.58
				_: continue
		var apex := 0.5
		match int(event.event_type):
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				apex = 1.8
			RallyEventModel.EventType.SET:
				apex = 2.4
		event.metadata["outgoing_trajectory"] = _ball_trajectory(
			event.type_name().to_lower(), start, end, flight_time, apex,
			float(event.metadata.get("event_time", 0.0))
		)


func _add_event(
	result: Resource,
	event_type: int,
	actor_id: int,
	actor_name: String,
	start: Vector2,
	end: Vector2,
	success: bool,
	quality: float,
	headline: String,
	detail: String,
	metadata: Dictionary = {},
) -> void:
	var event: Resource = RallyEventModel.new()
	event.sequence = result.events.size()
	event.event_type = event_type
	event.actor_id = actor_id
	event.actor_name = actor_name
	event.start_position = start
	event.end_position = end
	event.success = success
	event.quality = quality
	event.headline = headline
	event.detail = detail
	event.metadata = metadata.duplicate(true)
	result.events.append(event)


func _opponent_block_adaptation_bonus(
	opponent_team: Resource,
	lane: String,
	tempo: int,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 0.0
	if opponent_team.anticipated_lane() == lane:
		pattern_match += 0.65
	if opponent_team.anticipated_tempo() == tempo:
		pattern_match += 0.35
	return opponent_team.block_bonus() * pattern_match * 0.12


func _opponent_floor_defense_adaptation_bonus(
	opponent_team: Resource,
	lane: String,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 1.0 if opponent_team.anticipated_lane() == lane else 0.0
	return opponent_team.floor_defense_bonus() * pattern_match * 0.12


func _opponent_serve_receive_adaptation_bonus(
	opponent_team: Resource,
	target: String,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 1.0 if opponent_team.anticipated_serve_target() == target else 0.0
	return opponent_team.serve_receive_bonus() * pattern_match * 0.12


func _opponent_attack_type(target: Vector2) -> String:
	if target.y < 0.80:
		return "Short tip"
	if target.x < 0.38 or target.x > 0.62:
		return "Line attack"
	return "Seam attack"


func _defensive_responsibility_fit(
	defensive_plan: Resource,
	player_id: int,
	target: Vector2,
	attack_type: String,
) -> float:
	if defensive_plan == null:
		return 0.0
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return -0.035
	var fit := 0.0
	if attack_type == "Short tip" and "Tip" in str(assignment.short_ball_responsibility):
		fit += 0.035 + float(assignment.short_ball_priority) * 0.015
	elif attack_type == "Seam attack" and "seam" in str(assignment.seam_responsibility).to_lower():
		fit += 0.045
	elif attack_type == "Line attack" and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.035
	if defensive_plan.floor_system == "Perimeter" \
			and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.015
	elif defensive_plan.floor_system == "Middle-Up" \
			and "Middle-up" in str(assignment.base_responsibility):
		fit += 0.02
	elif defensive_plan.floor_system == "Rotation Defense" \
			and "Rotation" in str(assignment.base_responsibility):
		fit += 0.02
	var base_position: Vector2 = defensive_plan.defender_position(player_id, target)
	fit += lerpf(-0.025, 0.025, 1.0 - clampf(base_position.distance_to(target), 0.0, 1.0))
	return clampf(fit, -0.04, 0.08)


func _responsibility_phrase(
	defensive_plan: Resource,
	player_id: int,
	attack_type: String,
) -> String:
	if defensive_plan == null:
		return "No saved responsibility shaped the contact."
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return "The defender covered outside a saved responsibility."
	return "%s met the %s responsibility behind the %s." % [
		str(assignment.base_responsibility), attack_type.to_lower(),
		str(defensive_plan.block_strategy).to_lower(),
	]


func _choose_assignment(
	play: OffensivePlay,
	follow_play: bool,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
) -> HitterAssignment:
	if play == null or play.assignments.is_empty():
		return null
	if follow_play:
		var primary := play.assignment_for_player(play.primary_hitter_id)
		if primary != null and primary.player_id != excluded_player_id:
			return primary
	var candidates: Array[HitterAssignment] = []
	for assignment in play.assignments:
		if assignment.player_id != excluded_player_id \
				and _player_by_id(players, assignment.player_id) != null \
				and lineup.slot_for_player(assignment.player_id) >= 0:
			candidates.append(assignment)
	if candidates.is_empty():
		return null
	if not is_equal_approx(float(home_principles.pin_focus), 0.5):
		var total_weight := 0.0
		var weights: Array[float] = []
		for assignment in candidates:
			var pin_lane := assignment.lane in ["Left Pin", "Right Pin"]
			var middle_lane := assignment.lane in ["Front Quick", "Right Quick"]
			var weight := 1.0
			if pin_lane:
				weight = lerpf(0.35, 1.65, float(home_principles.pin_focus))
			elif middle_lane:
				weight = lerpf(1.65, 0.35, float(home_principles.pin_focus))
			weights.append(weight)
			total_weight += weight
		var roll := rng.randf() * total_weight
		for index in range(candidates.size()):
			roll -= weights[index]
			if roll <= 0.0:
				return candidates[index]
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _apply_identity_tempo(
	assignment: HitterAssignment,
	reception_quality: float,
) -> HitterAssignment:
	if assignment == null:
		return assignment
	var adjusted := assignment.duplicate(true) as HitterAssignment
	if reception_quality < 0.36:
		return adjusted
	var tempo_shift := 0
	var commitment := lerpf(
		float(home_principles.decisiveness),
		float(home_principles.transition_commitment),
		0.45,
	)
	if commitment >= 0.66:
		tempo_shift -= 1
	elif commitment <= 0.34:
		tempo_shift += 1
	if float(home_principles.tempo_variation) >= 0.66 and reception_quality >= 0.48:
		tempo_shift += [-1, 0, 1][posmod(rally_seed, 3)]
	adjusted.tempo = clampi(adjusted.tempo + tempo_shift, 0, 3)
	return adjusted


func _identity_hit_type(
	default_type: String,
	available_attacks: Array,
	set_quality: float,
	arrival_margin: float,
) -> String:
	var decisiveness := float(home_principles.decisiveness)
	if decisiveness <= 0.30 and (set_quality < 0.48 or arrival_margin < 0.05):
		return "Controlled roll" if "controlled_roll" in available_attacks \
			else "Emergency tip"
	if decisiveness >= 0.75 and default_type == "Tempo swing" \
			and "power_swing" in available_attacks:
		return "Power swing"
	return default_type


func _attack_effectiveness(
	execution_quality: float,
	decisiveness: float = 0.5,
) -> float:
	## Execution still decides whether the ball lands in. Decisiveness instead
	## prices what the attack does when it clears that gate: a controlled side
	## keeps more balls alive, while a committed side accepts more overreach for
	## greater pressure on the block and floor defence. Neutral identity returns
	## execution unchanged, preserving the engine's existing calibration baseline.
	var intention_multiplier := lerpf(0.85, 1.15, clampf(decisiveness, 0.0, 1.0))
	return clampf(
		execution_quality * intention_multiplier, 0.0, 1.0
	)


## A copy of the called assignment at a tempo the setter can actually run. The
## original play resource is left untouched: the offence still called what it
## called, and the record should show the call and the downgrade separately.
func _downgraded_assignment(
	assignment: HitterAssignment,
	tempo: int,
) -> HitterAssignment:
	if assignment == null:
		return assignment
	var adjusted := assignment.duplicate(true) as HitterAssignment
	adjusted.tempo = clampi(tempo, 0, 3)
	return adjusted


func _fallback_hitter(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
) -> VolleyballPlayer:
	var outside_candidates: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and candidate.id != excluded_player_id \
				and candidate.position_role == "Outside Hitter" \
				and CourtConstants.is_front_row_slot(slot_number):
			outside_candidates.append(candidate)
	if not outside_candidates.is_empty():
		var nearest := outside_candidates[0]
		var nearest_distance := 10.0
		for candidate in outside_candidates:
			var slot_number := lineup.slot_for_player(candidate.id)
			var position := CourtConstants.slot_position(slot_number)
			var pin_x := 0.12 if position.x <= 0.5 else 0.88
			var distance := absf(position.x - pin_x)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
		return nearest
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player != null and player.id != excluded_player_id:
			return player
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null and player.id != excluded_player_id \
				and lineup.is_attack_eligible(player.id) \
				and player.position_role != "Libero":
			return player
	return null


## `_best_blocker()` used to pick a blocker by `block_timing + jump_reach`.
## It has had no callers since blocking moved to `ShadowBlockSystem` and the
## coordinated form-then-contest path, which reads the whole front row rather
## than crowning one player. Removed rather than kept as a second, cruder
## answer to a question the block system now owns.


## `set_flight_time` is the opponent set's own flight, for the same reason the
## opponent block uses it: it is how long home blockers actually have.
## The home wall as it forms, before the swing it will face is scored. Both
## sides now form first and contest afterwards, through the same
## `_contest_block()`: the home block used to carry its own copy of the margins,
## and when the opponent side was retuned the two immediately diverged -- the
## home block stuffed 36 attacks in a sweep where the opponent block stuffed
## none. A second copy of a contest is a second balance to maintain.
func _form_home_block(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	opponent_setter_x: float,
	set_flight_time: float,
	preset_window_seconds: float = 0.0,
) -> Dictionary:
	var front_blockers: Array[VolleyballPlayer] = []
	var setter_pull := {}
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if player != null and (assignment == null or bool(assignment.block_participation)):
			front_blockers.append(player)
			var slot_number := lineup.slot_for_player(player.id)
			var start: Vector2 = live_positions.get(
				player.id, CourtConstants.slot_position(slot_number)
			)
			var discipline := clampf(
				(_rating(player, "tactical_discipline") * 0.65
				+ _rating(player, "anticipation") * 0.35), 0.0, 1.0
			)
			var pull_weight := (1.0 - discipline) * 0.18
			var pulled_x := lerpf(start.x, opponent_setter_x, pull_weight)
			setter_pull[player.id] = absf(pulled_x - start.x)
			live_positions[player.id] = Vector2(pulled_x, start.y)
	if front_blockers.is_empty():
		return {
			"primary": null, "assist": null, "primary_close": 0.0,
			"assist_close": 0.0, "quality": 0.0, "outcome": "miss",
			"coverage_segments": [], "setter_pull": setter_pull,
		}
	var primary: VolleyballPlayer
	var primary_distance := 1000.0
	for candidate in front_blockers:
		var slot_number := lineup.slot_for_player(candidate.id)
		var candidate_x := CourtConstants.slot_position(slot_number).x
		var distance := absf(candidate_x - attack_x)
		if distance < primary_distance:
			primary = candidate
			primary_distance = distance
	## How long the blockers actually have: the set's own flight time, which the
	## kinematics solver already produced from real distance and launch angle.
	##
	## This used to be `0.30 + tempo * 0.045 + (1 - set_quality) * 0.18` -- a
	## table that gave a middle blocker 0.30 s of movement to cover 2.9 m of net,
	## which is physically impossible, so double blocks formed in 1% of rallies
	## and tempo could not change the block. Flight time already encodes tempo: a
	## quick set lands in a fraction of the time a high ball takes, so the middle
	## closes on a high ball and does not on a quick one. That is the whole
	## tempo-versus-block dynamic, and it now falls out of the ball's own physics
	## rather than a constant.
	var read_total := 0.0
	for reader in front_blockers:
		read_total += _blocker_read_quality(reader, tempo, set_quality, opponent_setter_x)
	var read_quality := read_total / maxf(float(front_blockers.size()), 1.0)
	## The pre-set window is only worth what a blocker can do with it, and what
	## they can do with it is decided by their read. During that time nobody
	## knows where the set is going: a blocker who reads the pass and the
	## setter's body moves early and moves the right way, while one who does not
	## has to wait for the release. A flat share gave every blocker the good
	## version of that and made the wall far too strong -- 0.19 stuffs and 0.64
	## touched -- while leaving reading worth nothing.
	var preset_share := lerpf(
		BLOCK_PRESET_SHARE_MISREAD, BLOCK_PRESET_SHARE_READ, read_quality
	)
	var close_time := maxf(set_flight_time, 0.0) \
		+ maxf(preset_window_seconds, 0.0) * preset_share \
		+ (1.0 - set_quality) * 0.10
	close_time += lerpf(-0.09, 0.09, read_quality)
	var identity_commitment_seconds := (
		float(home_principles.block_commitment) - 0.5
	) * 0.18
	close_time += identity_commitment_seconds
	identity_effects["block_commitment"] = {
		"principle": float(home_principles.block_commitment),
		"closing_time_adjustment": identity_commitment_seconds,
	}
	var strategy := str(defensive_plan.block_strategy) if defensive_plan != null \
		else "Read Block"
	var pin_attack := attack_x <= 0.34 or attack_x >= 0.66
	if strategy == "Commit Pin":
		close_time += 0.10 if pin_attack else -0.08
	elif strategy == "Commit Middle":
		close_time += 0.10 if not pin_attack else -0.09
	var primary_close := _blocker_close_fraction(
		primary, lineup, attack_x, close_time
	)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var close_fraction := _blocker_close_fraction(
			candidate, lineup, attack_x, close_time
		)
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	var block_quality := _block_wall_quality(primary_skill, assist_skill)
	return {
		"primary": primary,
		"assist": assist,
		"primary_close": primary_close,
		"assist_close": assist_close,
		"quality": block_quality,
		"outcome": "miss",
		"coverage_segments": _home_block_segments(
			attack_x, primary, primary_close, assist, assist_close
		),
		"setter_pull": setter_pull,
		"read_quality": read_quality,
	}


func _blocker_read_quality(
	blocker: VolleyballPlayer,
	tempo: int,
	set_quality: float,
	opponent_setter_x: float,
) -> float:
	var cue_clarity := (1.0 - set_quality) * 0.18 \
		+ absf(opponent_setter_x - 0.5) * 0.16 \
		+ float(clampi(tempo, 0, 3)) * 0.025
	return clampf(
		_rating(blocker, "anticipation") * 0.34
		+ _rating(blocker, "court_vision") * 0.25
		+ _rating(blocker, "decision_making") * 0.21
		+ _rating(blocker, "tactical_discipline") * 0.20
		+ cue_clarity - rng.randf_range(0.0, 0.08), 0.0, 1.0
	)


func _blocker_close_fraction(
	blocker: VolleyballPlayer,
	lineup: RotationLineup,
	attack_x: float,
	available_time: float,
) -> float:
	if blocker == null:
		return 0.0
	var slot_number := lineup.slot_for_player(blocker.id)
	var start_position: Vector2 = live_positions.get(
		blocker.id, CourtConstants.slot_position(slot_number)
	)
	var start_x := start_position.x
	var anticipation := _rating(blocker, "anticipation")
	var reaction_delay := lerpf(0.34, 0.12, anticipation)
	var movement_time := maxf(available_time - reaction_delay, 0.0)
	## Blocking closes through the shared locomotion model like every other
	## movement in the engine. It used to carry its own `lerpf(1.25, 4.40,
	## lateral_speed)` -- a fourth private copy of the speed curve -- so none of
	## the stride, cadence or limb-turnover work reached blocking at all. Side is
	## irrelevant here: `movement_profile()` reads the player, facing and
	## velocity, never which half of the court they stand on.
	var closing_actor := RallyPlayerState.create(
		blocker, &"home", slot_number, start_position
	)
	## A blocker covers some of the lane with their arms without moving their
	## feet, but nothing like the 0.72 m this used to grant. That constant
	## swamped the 0.135 s a slow tempo actually buys the block.
	var lane_delta := attack_x - start_x
	var footwork_x := start_x + signf(lane_delta) * maxf(
		absf(lane_delta) - BLOCK_LATERAL_REACH_METERS / 9.0, 0.0
	)
	## How long the close actually takes, through the shared model, from a
	## standstill.
	##
	## This used to be `maximum_speed * movement_time`: the blocker left the
	## ready stance already at top speed, never decelerated, and was credited
	## with shuffling until the instant of contact. Every close in the game
	## resolved at exactly 1.0 as a result -- a middle covered three metres to
	## the pin and sealed it every time, so "late block" described nothing.
	## Acceleration comes from the same traversal solver every other movement
	## uses, and the block jump has to be loaded before the ball arrives rather
	## than after it.
	var required_seconds := RallyMovementSystemModel.traversal_seconds(
		closing_actor,
		Vector2(footwork_x, start_position.y),
		RallyPlayerState.MovementMode.BLOCK_CLOSE,
	)
	var usable_time := maxf(movement_time - BLOCK_PLANT_SECONDS, 0.0)
	return clampf(
		1.0 - maxf(required_seconds - usable_time, 0.0) / BLOCK_CLOSE_FAILURE_SECONDS,
		0.0, 1.0,
	)


## How well this hitter's run-up served the swing, as a fraction of an ideal
## approach. Their own approach timing is part of it: the profile measures the
## run-up they produced, not how well they habitually produce one.
func _approach_execution_fit(
	hitter: VolleyballPlayer,
	approach_profile: Dictionary,
) -> float:
	return clampf(
		_rating(hitter, "approach_timing") * 0.24
		+ float(approach_profile.get("runup_quality", 0.5)) * 0.48
		+ float(approach_profile.get("lateral_control", 0.5)) * 0.16
		+ float(approach_profile.get("approach_speed_fraction", 0.5)) * 0.12,
		0.0, 1.0,
	)


## One swing, wherever in the rally it happens.
##
## The engine carried three copies of this. The home attack summed 1.50 of
## positive weight across ratings, approach and set quality; the opponent attack
## used `attack_power * 0.62 + set_quality * 0.20 + 0.08`; the continuation used
## a third set of weights again. All three were then compared against the same
## block contest and the same error threshold, which only made sense for one of
## them at a time.
##
## Capability is what the hitter brings, normalised to a fraction of an ideal
## hitter. Opportunity is what the rally handed them, and it is a **product**:
## a great hitter off a terrible set, with no run-up, arriving late, should put
## the ball in the stands. Summing those terms instead put roughly 0.75 of
## rating weight under every swing in the game, so attack quality never fell
## below 0.321 against a 0.29 error threshold and the engine produced no attack
## errors at all -- not few, none, across 180 rallies.
func _attack_execution(
	hitter: VolleyballPlayer,
	set_quality: float,
	approach_fit: float,
	arrival_margin: float,
	tempo_demand: float,
	block_pressure: float,
	familiarity_bonus: float = 0.0,
) -> float:
	if hitter == null:
		return 0.0
	var raw_capability := clampf(
		_rating(hitter, "attack_accuracy") * ATTACK_ACCURACY_WEIGHT
		+ _power_rating(hitter, "attack_power") * ATTACK_POWER_WEIGHT
		+ _rating(hitter, "decision_making") * ATTACK_DECISION_WEIGHT
		+ familiarity_bonus,
		0.0, 1.0,
	)
	var capability := clampf(
		ATTACK_CAPABILITY_PIVOT
			+ (raw_capability - ATTACK_CAPABILITY_PIVOT) * ATTACK_CAPABILITY_GAIN,
		0.0, 1.0,
	)
	## Arriving early is worth nothing extra -- the ball still has to come down
	## -- so this saturates at the margin rather than rewarding it.
	var timing := clampf(
		(arrival_margin + LATE_ARRIVAL_SECONDS) / LATE_ARRIVAL_SECONDS, 0.0, 1.0
	)
	var opportunity := (
		1.0 - SET_OPPORTUNITY_WEIGHT * (1.0 - clampf(set_quality, 0.0, 1.0))
	) * (
		1.0 - APPROACH_OPPORTUNITY_WEIGHT * (1.0 - clampf(approach_fit, 0.0, 1.0))
	) * (
		1.0 - TIMING_OPPORTUNITY_WEIGHT * (1.0 - timing)
	) * (
		1.0 - clampf(tempo_demand, 0.0, 0.60)
	)
	return clampf(capability * opportunity - block_pressure, 0.0, 1.0)


## Gate E. The geometric swing for this attack, alongside the legacy one.
##
## Every attack site calls this. Today nothing downstream reads the answer
## unless the rollout is open -- it is recorded into the shadow summary so the
## geometric outcome mix can be measured against the legacy one on live rallies
## rather than on a synthetic sweep. That is the same order Gates 44 through 49
## ran in, and for the same reason: an outcome model that has only ever been
## swept in isolation has never met the inputs a rally actually produces.
##
## The draws come from `geometric_rng`, a stream of its own seeded from the rally
## seed and the contact index. This is not tidiness. The shadow pass runs on
## every attack whether or not it is promoted, so drawing from `rng` would
## advance the rally's own stream and silently change every rally in the game --
## the same defect that rerolled the world when `ego` drew from the shared
## generation stream. A private stream means an unpromoted geometric attack is
## exactly as invisible as it claims to be.
func _geometric_swing(
	hitter: VolleyballPlayer,
	contact: Vector2,
	lane: String,
	formation: Dictionary,
	blocking_fallbacks: Dictionary,
	blocking_live: Dictionary,
	defenders: Array,
	attacking_negative_y: bool,
	jump_multiplier: float,
	approach_quality: float,
	decisiveness: float,
	flow_for_team: float,
	block_intent: String = "Balanced",
) -> Dictionary:
	if hitter == null:
		return {}
	geometric_rng.seed = hash("%d|geometric|%d|%d" % [
		rally_seed, hitter.id, geometric_swing_index
	])
	geometric_swing_index += 1
	var wall := GeometricAttackPromotionModel.block_wall(
		formation, blocking_fallbacks, blocking_live, block_intent
	)
	var height := GeometricAttackPromotionModel.contact_height_meters(
		hitter, jump_multiplier
	)
	var swing := GeometricAttackResolverModel.resolve_swing(
		hitter, contact, height,
		lane, wall, defenders, attacking_negative_y, approach_quality, decisiveness,
		float(hitter.match_confidence), flow_for_team,
		GeometricAttackPromotionModel.draws(
			geometric_rng, wall.size(), defenders.size()
		),
	)
	## The two inputs a sweep cannot supply for itself. Gate D contacted at full
	## jumping reach because it had no approach to ask; a rally does, and whether
	## that difference explains the net rate is the first question the shadow was
	## wired to answer.
	swing["contact_height_meters"] = height
	swing["jump_multiplier"] = jump_multiplier
	swing["wall_size"] = wall.size()
	return swing


## Gate E. The geometric serve, alongside the legacy one.
##
## Same private stream as the swing, for the same reason, and the record goes
## straight onto `result.analysis` because a serve happens before the shadow
## trace this rally will carry exists.
func _geometric_serve_record(
	key: String,
	server: VolleyballPlayer,
	contact: Vector2,
	target: Vector2,
	attacking_negative_y: bool,
	tactical_risk: float,
) -> void:
	if server == null:
		return
	geometric_rng.seed = hash("%d|serve|%s|%d" % [rally_seed, key, server.id])
	var serve: Dictionary = GeometricAttackResolverModel.resolve_serve(
		server, contact,
		GeometricAttackPromotionModel.serve_contact_height_meters(server),
		target, attacking_negative_y, tactical_risk,
		GeometricAttackPromotionModel.serve_draws(geometric_rng),
	)
	if not bool(serve.get("available", false)):
		return
	var resolution: Dictionary = serve.get("resolution", {})
	geometric_serves[key] = {
		"outcome": str(serve.outcome),
		"out_reason": str(resolution.get("out_reason", "")),
		"speed_mps": float(serve.speed_mps),
		"bearing_degrees": float(serve.bearing_degrees),
		"launch_mode": str(serve.launch_mode),
		"landing": Vector2(serve.landing),
		"net_clearance_meters": float(resolution.get("net_clearance_meters", 0.0)),
	}


## The shadow record for one geometric swing: what it decided and what it would
## have produced, small enough to keep on every attack of every rally.
## Where each blocker stands when nothing has staged them, one map per side.
##
## `GeometricAttackPromotion.block_wall` used to take a team resource for this,
## which only the opponent has -- so the opponent's own swing passed `null` and
## every unstaged home blocker was placed at the middle of the net. A hitter
## aiming around a wall was aiming around a wall that was not where it stood.
func _home_block_fallbacks(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> Dictionary:
	var fallbacks := {}
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null:
			fallbacks[player.id] = CourtConstants.slot_position(slot_number)
	return fallbacks


func _opponent_block_fallbacks(opponent_team: Resource) -> Dictionary:
	var fallbacks := {}
	if opponent_team == null:
		return fallbacks
	for raw_player in opponent_team.on_court_players():
		var player: VolleyballPlayer = raw_player as VolleyballPlayer
		if player != null:
			fallbacks[player.id] = opponent_team.court_position(player.id, "block")
	return fallbacks


func _geometric_swing_record(swing: Dictionary, side: String) -> Dictionary:
	if swing.is_empty():
		return {"side": side, "available": false, "reason": "no hitter"}
	var continuation := GeometricAttackPromotionModel.continuation(swing)
	if not bool(continuation.get("resolved", false)):
		return {
			"side": side, "available": false,
			"reason": str(continuation.get("reason", "unresolved")),
		}
	var course: Dictionary = swing.get("course", {})
	var delivered: Dictionary = swing.get("delivered", {})
	return {
		"side": side,
		"available": true,
		"outcome": str(continuation.outcome),
		"terminal_outcome": str(continuation.terminal_outcome),
		"quality": float(continuation.quality),
		"landing": Vector2(continuation.landing),
		"out_reason": str(continuation.out_reason),
		"bearing_degrees": float(course.get("bearing_degrees", 0.0)),
		"offset_degrees": float(course.get("offset_degrees", 0.0)),
		"speed_mps": float(delivered.get("speed_mps", 0.0)),
		"bearing_error_degrees": float(delivered.get("bearing_error_degrees", 0.0)),
		"contact_height_meters": float(swing.get("contact_height_meters", 0.0)),
		"jump_multiplier": float(swing.get("jump_multiplier", 1.0)),
		"wall_size": int(swing.get("wall_size", 0)),
		"vertical_angle_degrees": float(delivered.get("vertical_angle_degrees", 0.0)),
		"block_kind": str(
			Dictionary(swing.get("resolution", {}).get("block", {})).get("kind", "")
		),
		## Why the wall was beaten, when it was. This record is the only thing
		## promotion sees -- a key the resolver states but the curator drops is a
		## key nothing downstream can read, however faithfully the layers below
		## carry it.
		"block_miss_reason": str(swing.get("block_miss_reason", "")),
		"net_height_over_block_meters": float(
			swing.get("net_height_over_block_meters", 0.0)
		),
		"block_edge_miss_meters": float(swing.get("block_edge_miss_meters", 0.0)),
		"net_crossing_x": float(swing.get("net_crossing_x", 0.5)),
		"narrative": Dictionary(continuation.narrative),
	}


## Gate E promotion. What the geometric resolver decided, or `{}` when attacks
## are still resolved by `_attack_execution` and `_contest_block`.
##
## The shadow record is already the translation; this only decides whether the
## rally is allowed to *act* on it, and re-expresses the outcome in the legacy
## block vocabulary so the block event, the deflection leg and the coverage
## branch keep reading the one string they have always read.
##
## What promotion takes over is the swing's result: where the ball lands,
## whether it landed in, and whether the wall got to it. What it deliberately
## does not take over is the drawn arc -- `solve_launch_arc` is a ground-to-
## ground solver and the resolver launches from three metres up, which is the
## whole reason `_feasible_launch` exists. Handing it the resolver's elevation
## would draw a spike that leaves the hitter's hand going upward at a negative
## angle. The trajectory stays on the existing kinematics until it is promoted
## on its own terms.
##
##   in                        the ball is down and the defence has to play it
##   net, out                  the swing missed; no block was involved
##   stuff                     the wall put it down
##   touch                     hands slowed it and the rally continues
##   tool, block_crush,
##   high_hands                the hitter's point, decided at the net
## The one thing promotion deliberately leaves alone is `attack_quality`.
##
## The resolver derives a quality *from* its outcome, which is the right shape
## for a model that owns the whole swing -- but the legacy execution chain is
## still running here, and it is what the resolver's own bearing and power
## channels are driven by. Overwriting it would mean a hitter dragged out of
## position and swinging late reported whatever quality their result happened to
## imply, so a displaced hitter who still found the floor scored higher than a
## well-set one the block grazed. Execution is how the swing was struck; outcome
## is what it produced. They are allowed to disagree, and in this sport they do.
func _geometric_promotion(record: Dictionary) -> Dictionary:
	if not GeometricAttackPromotionModel.enabled(geometric_development_open):
		return {}
	if not bool(record.get("available", false)):
		return {}
	var outcome := str(record.get("outcome", "in"))
	var terminal := str(record.get("terminal_outcome", ""))
	## Only three of the eight outcomes involve the wall touching the ball, and
	## `tool` and `high_hands` are two of them -- the hands are what sent the
	## ball out. They read as a touch so the block still deflects on screen; the
	## hitter's point is claimed before the recycle branch can see them.
	var block_outcome := "miss"
	if outcome in ["stuff"]:
		block_outcome = "stuff"
	elif outcome in ["touch", "tool", "high_hands"]:
		block_outcome = "touch"
	return {
		"outcome": outcome,
		"block_outcome": block_outcome,
		"attack_missed": terminal == "attack_error",
		"hitter_point": terminal == "kill",
		"target": Vector2(record.get("landing", Vector2(0.5, 0.25))),
		"quality": clampf(float(record.get("quality", 0.0)), 0.0, 1.0),
		"speed_mps": float(record.get("speed_mps", 0.0)),
		"launch_angle_degrees": float(record.get("vertical_angle_degrees", 0.0)),
		"out_reason": str(record.get("out_reason", "")),
		## Why the wall was beaten, when it was. Over the top is a reach problem
		## and around the edge is a positioning one; they want opposite fixes and
		## the outcome alone cannot tell them apart.
		"block_miss_reason": str(record.get("block_miss_reason", "")),
		"net_height_over_block_meters": float(
			record.get("net_height_over_block_meters", 0.0)
		),
		"block_edge_miss_meters": float(record.get("block_edge_miss_meters", 0.0)),
		"net_crossing_x": float(record.get("net_crossing_x", 0.5)),
	}


func _attack_missed(attack_quality: float) -> bool:
	var response := 1.0 / (1.0 + exp(
		(clampf(attack_quality, 0.0, 1.0) - ATTACK_ERROR_THRESHOLD)
			/ ATTACK_ERROR_RESPONSE_WIDTH
	))
	var miss_chance := lerpf(ATTACK_ERROR_FLOOR, ATTACK_ERROR_CEILING, response)
	return rng.randf() < miss_chance


## How often this serve misses, given how much the server is asking of it.
##
## Both serve sites carried their own sum of small offsets --
## `0.025 + risk * 0.07 + aggression * 0.025 - consistency * 0.065 - style * 0.02`
## and a near-twin -- and neither could reach the sport. The maximum either
## expression could return was 0.12, at maximum aggression against a server with
## zero consistency; a typical server produced 0.022. A rate that cannot enter
## its own band is not a low rate, it is an absent mechanism, and serve
## aggression was therefore free.
##
## A serve misses when the server asks more of it than their control supports.
## Demand comes from the tactical risk and the server's own aggression; control
## is technique and consistency, normalised. Neither term is an offset, so the
## rate spans the range instead of resting on its floor.
func _serve_error_chance(server: VolleyballPlayer, tactical_risk: float) -> float:
	if server == null:
		return SERVE_BASE_DEMAND * SERVE_ERROR_CEILING
	var control := clampf(
		_rating(server, "serve_consistency") * 0.45
		+ _rating(server, "serve_technique") * 0.30
		+ _serve_style_proficiency(server) * 0.25,
		0.0, 1.0,
	)
	var demand := clampf(
		SERVE_BASE_DEMAND
		+ clampf(tactical_risk, 0.0, 1.0) * SERVE_RISK_DEMAND * 0.6
		+ _rating(server, "serve_aggression") * SERVE_RISK_DEMAND * 0.4,
		0.0, 1.0,
	)
	return clampf(SERVE_ERROR_CEILING * demand * (1.0 - control), 0.005, 0.45)


## One set, wherever in the rally and whichever side of the net.
##
## There were two models. The home first ball summed 1.18 of un-normalised
## weight -- 0.90 of ratings plus 0.28 of pass quality -- while the transition
## set was a normalised capability times what the arriving ball allowed. A
## typical home set scored about 0.75 and a typical opponent set about 0.48, and
## since every opponent attack in the game was built off a transition set, that
## 0.27 gap was worth roughly 0.11 of attack quality: twice what a +15 hitter is
## worth, handed to one side of the net for free. It produced 115 home kills
## against 17.
##
## `capability_penalty` carries what `SetterCapabilitySystem` charges for
## attempting a tempo beyond command or reaching above the jump; it is zero for
## a transition set, which has no play called on it to overreach.
func _set_execution(
	setter: VolleyballPlayer,
	usable_pass_quality: float,
	tempo_demand: float,
	capability_penalty: float,
	arrival_margin: float,
	geometry_difficulty: float,
	familiarity_bonus: float = 0.0,
) -> float:
	return float(_set_terms(
		setter, usable_pass_quality, tempo_demand, capability_penalty,
		arrival_margin, geometry_difficulty, familiarity_bonus,
	).quality)


## The same set, with its working shown.
##
## The dig composite was asked which factor moved and answered that the question
## belonged one contact earlier: measured across all contacts, the home side
## sets at 0.484 and the opponent at 0.254, the largest single asymmetry in the
## engine. The same instrument is pointed at the set rather than guessing which
## of its six subtracted terms is responsible.
func _set_terms(
	setter: VolleyballPlayer,
	usable_pass_quality: float,
	tempo_demand: float,
	capability_penalty: float,
	arrival_margin: float,
	geometry_difficulty: float,
	familiarity_bonus: float = 0.0,
) -> Dictionary:
	if setter == null:
		return {"quality": 0.0, "capability": 0.0, "usable": 0.0, "pass": 0.0,
			"tempo_demand": 0.0, "capability_penalty": 0.0,
			"geometry_difficulty": 0.0, "arrival": 0.0, "familiarity": 0.0}
	var capability := _transition_set_capability(setter)
	var usable := _usable_transition_ball(usable_pass_quality, capability)
	var arrival := clampf(arrival_margin * 0.18, -0.42, 0.08)
	return {
		"quality": clampf(
			capability * (1.0 - TRANSITION_BALL_WEIGHT * (1.0 - usable))
			- tempo_demand - capability_penalty - geometry_difficulty
			+ arrival + familiarity_bonus,
			0.0, 1.0,
		),
		"capability": capability,
		"usable": usable,
		"pass": usable_pass_quality,
		"tempo_demand": tempo_demand,
		"capability_penalty": capability_penalty,
		"geometry_difficulty": geometry_difficulty,
		"arrival": arrival,
		"familiarity": familiarity_bonus,
	}


## What a setter brings to a ball played out of defence, as a fraction of an
## ideal one. One list of attributes for both sides of the net.
##
## `hand_control` and `tempo_control` are in here because they are what
## `SetterCapabilitySystem` reads at the first ball, and a setter who is better
## at setting should be better at setting in transition too. Neither transition
## formula referenced them before, on either side, so two of the four attributes
## a setter is built on reached nothing after the first contact.
func _transition_set_capability(setter: VolleyballPlayer) -> float:
	if setter == null:
		return 0.0
	return clampf(
		_rating(setter, "set_accuracy") * 0.34
		+ _rating(setter, "hand_control") * 0.22
		+ _rating(setter, "tempo_control") * 0.16
		+ _rating(setter, "ball_control") * 0.15
		+ _rating(setter, "composure") * 0.13,
		0.0, 1.0,
	)


## How much of the arriving ball this setter can actually use. Command buys back
## part of a bad one, so the gap between setters is widest when the ball is
## worst -- which is the situation a good setter is for.
func _usable_transition_ball(incoming_quality: float, capability: float) -> float:
	var usable := clampf(incoming_quality, 0.0, 1.0)
	return usable + (1.0 - usable) * capability * TRANSITION_BALL_RECOVERY


## How widely a player's execution scatters around what they are capable of.
##
## Every contact in the engine carried a flat spread -- the same +/-0.10 for a
## world-class hitter and a replacement-level one -- so consistency was not an
## attribute. That is why only the hitter registered in results: a +15 change one
## contact upstream moves the ball it feeds by about 0.02, against a shared
## +/-0.10 of noise on that contact and another fresh term on the next. Anything
## more than one link from the terminal act was drowned before it could reach
## the scoreboard.
##
## Reliability is composure -- holding technique together under rally pressure --
## plus the technical rating that governs the act itself. An elite player does
## not merely average better; their bad contact is much closer to their good one,
## which is what makes them felt through a chain rather than only at its end.
func _execution_spread(
	player: VolleyballPlayer,
	control_attribute: String,
	base_spread: float,
) -> float:
	if player == null:
		return base_spread
	var reliability := clampf(
		_rating(player, "composure") * CONSISTENCY_COMPOSURE_WEIGHT
		+ _rating(player, control_attribute)
		* (1.0 - CONSISTENCY_COMPOSURE_WEIGHT),
		0.0, 1.0,
	)
	return base_spread * lerpf(1.0, CONSISTENCY_FLOOR_SHARE, reliability)


## A symmetric execution error for one contact, already scaled by who is making
## it. Callers that need the same draw twice keep the value rather than calling
## this again.
func _execution_error(
	player: VolleyballPlayer,
	control_attribute: String,
	base_spread: float,
) -> float:
	var spread := _execution_spread(player, control_attribute, base_spread)
	## Normal, not uniform on [-spread, spread].
	##
	## A uniform draw has hard support boundaries, and every consumer of this
	## value is eventually compared against a threshold. So whenever a
	## contest's systematic margin sat further than `spread` from its
	## threshold, the outcome stopped being uncertain at all -- not unlikely,
	## impossible. The block contest showed it plainly: swept across generated
	## roster pairings, one pairing recorded zero stuff blocks in 127 contests
	## and another 84 in 144, because their mean margins sat 0.085 below and
	## 0.102 above the same cutoff while blocker spread ran 0.04-0.13. There
	## was no gradient between them for a squad to move along, which is the
	## wrong shape for a game about incremental improvement.
	##
	## Matched on standard deviation (a uniform's is its half-width over root
	## three), so ordinary contacts scatter exactly as much as before and only
	## the tails change. Clamped well outside the old bound purely to stop a
	## freak draw putting a set in the stands; at 3.5 deviations the residual
	## probability is about 2e-4, which is rare rather than forbidden.
	return _normal_from_uniform_halfwidth(spread)


## A normal draw carrying the same standard deviation a uniform on
## [-half_width, half_width] would have, clamped where a freak draw stops being
## rare and starts being absurd. Shared so that every site converted away from
## `randf_range` scatters identically to how it used to on ordinary contacts.
func _normal_from_uniform_halfwidth(half_width: float) -> float:
	var deviation := half_width * UNIFORM_TO_NORMAL_DEVIATION
	var limit := deviation * EXECUTION_ERROR_DEVIATION_LIMIT
	return clampf(rng.randfn(0.0, deviation), -limit, limit)


## Where an own-side delivery lands, given where it was aimed and how well it
## was executed.
##
## This is the whole of the "positional promotion": no flight is simulated and
## no boundary is tested, but the contact stops arriving at a table entry and
## starts arriving at a point that depends on the player. That is what the next
## contact's geometry needs -- a hitter's available angles depend on where the
## set actually is, not on where the lane says it should be.
##
## Normal rather than uniform, matching `_execution_error`. A uniform spread
## would make "can this setter miss the pin" a hard threshold on quality instead
## of a tail, which is the same defect that made block outcomes impossible
## rather than unlikely.
func _delivered_point(
	intended: Vector2,
	quality: float,
	worst_stdev_meters: float,
	best_stdev_meters: float,
	min_y: float,
	max_y: float,
) -> Vector2:
	var stdev_meters := lerpf(
		worst_stdev_meters, best_stdev_meters, clampf(quality, 0.0, 1.0)
	)
	var limit := stdev_meters * EXECUTION_ERROR_DEVIATION_LIMIT
	var offset_x := clampf(rng.randfn(0.0, stdev_meters), -limit, limit) \
		/ CourtConstants.COURT_WIDTH_METERS
	var offset_y := clampf(rng.randfn(0.0, stdev_meters), -limit, limit) \
		/ CourtConstants.COURT_LENGTH_METERS
	return Vector2(
		clampf(intended.x + offset_x, 0.04, 0.96),
		clampf(intended.y + offset_y, min_y, max_y),
	)


## One dig, wherever in the rally it happens.
##
## The engine carried three of these too. Home defence summed 0.96 of weight
## across four attributes, the opponent's summed 0.84 across two, and the
## continuation summed 0.86 across three -- and all three were compared against
## an attack quality on a fourth scale, with three different offsets. Once the
## swing became a fraction of an ideal swing, none of them meant anything: a
## defender composite near 0.61 against a typical swing of 0.42 dug almost
## everything, and rallies stopped ending.
##
## Same shape as the swing. Capability is what the defender brings, normalised.
## Opportunity is what the rally gave them, as a product, because a defender who
## did not get there has no technique to apply. `read_bonus` carries scouting,
## responsibility fit and defensive-plan posture -- the things that tell a
## defender where the ball is going before it goes there.
## The dig, given how much reach the defender had left over.
##
## The second parameter is *metres*, not seconds. It used to be called
## `arrival_margin` and weighed against a constant called
## `DIG_LATE_ARRIVAL_SECONDS`, and every production caller was already feeding it
## `physical_reach - distance` from the coverage model -- so the model was not
## wrong, its name was, which is worse in one specific way: it told anyone
## reading it that a seconds value belonged here, and eventually something put
## one in.
func _defense_execution(
	defender: VolleyballPlayer,
	reach_margin_meters: float,
	read_bonus: float,
	posture_penalty: float,
	support_count: int,
) -> float:
	return float(_defense_terms(
		defender, reach_margin_meters, read_bonus, posture_penalty, support_count
	).quality)


## The same dig, with its working shown.
##
## Every attempt to explain why one side of the net digs better than the other
## has so far been a guess at which term was responsible, and two of those
## guesses were wrong -- the parallel implementation, then the timing term. A
## composite that only ever reports its product cannot be asked which factor
## moved, so it now reports the factors too and the question can be measured
## instead of argued.
func _defense_terms(
	defender: VolleyballPlayer,
	reach_margin_meters: float,
	read_bonus: float,
	posture_penalty: float,
	support_count: int,
) -> Dictionary:
	if defender == null:
		return {"quality": 0.0, "capability": 0.0, "timing": 0.0,
			"posture": 0.0, "support": 0.0, "opportunity": 0.0,
			"read_bonus": 0.0, "reach_margin_meters": 0.0, "recovery": 1.0}
	var capability := clampf(
		_rating(defender, "reception") * DIG_RECEPTION_WEIGHT
		+ _rating(defender, "anticipation") * DIG_ANTICIPATION_WEIGHT
		+ _rating(defender, "dig_control") * DIG_CONTROL_WEIGHT
		+ _rating(defender, "lateral_speed") * DIG_LATERAL_WEIGHT
		+ read_bonus,
		0.0, 1.0,
	)
	var timing := clampf(
		(reach_margin_meters + DIG_REACH_MARGIN_METERS) / DIG_REACH_MARGIN_METERS,
		0.0, 1.0,
	)
	## A covered defender is playing a ball someone else could also reach, which
	## is worth something but cannot exceed being in position for it.
	var support := minf(float(maxi(support_count, 0)) * 0.03, 0.09)
	## What the last ball cost them. A defender who went to a knee, fell, or was
	## driven off a ball is playing this one out of a recovery, and until now a
	## defensive *success* had no price at all -- the same player dug the next ball
	## exactly as well from the floor as from their feet. Scaled by how much of the
	## debt is left, so it fades rather than switching off.
	var recovery := 1.0 - RECOVERY_DIG_PENALTY * _recovery_debt(
		defender.id, rally_clock
	)
	var opportunity := (1.0 - DIG_TIMING_WEIGHT * (1.0 - timing)) \
		* (1.0 - DIG_POSTURE_WEIGHT * clampf(posture_penalty, 0.0, 1.0)) \
		* (1.0 + support) * recovery
	return {
		"quality": clampf(capability * opportunity * DIG_SOLO_SHARE, 0.0, 1.0),
		"capability": capability,
		"timing": timing,
		"posture": clampf(posture_penalty, 0.0, 1.0),
		"support": support,
		"opportunity": opportunity,
		"read_bonus": read_bonus,
		"reach_margin_meters": reach_margin_meters,
		"recovery": recovery,
	}


## Whether this dig comes up, against the swing that was actually hit.
##
## One contest, all three places a ball is dug. The attacker's advantage is
## explicit rather than hidden in three different random offsets, so it can be
## calibrated in one place and read in one place.
func _dig_contest(
	defender: VolleyballPlayer,
	defense_quality: float,
	attack_quality: float,
) -> bool:
	return defense_quality + _execution_error(
		defender, "dig_control", DIG_EXECUTION_NOISE
	) > attack_quality + DIG_ATTACKER_ADVANTAGE


## The wall two blockers make, from what each of them brings.
##
## Written out twice, once per side of the net, until this: `assist_close` was
## already inside `assist_skill` and was multiplied in again, which squared the
## assist's contribution and capped even a perfect unassisted blocker at 0.67.
##
## The assist closes part of what the primary leaves open rather than adding a
## flat share, so a second blocker matters most when the first is beaten and
## least when they already sealed it. That is the shape of a real double block,
## and it makes beating one blocker ordinary while a well-formed double is the
## thing a hitter genuinely has to solve.
func _block_wall_quality(primary_skill: float, assist_skill: float) -> float:
	var solo := clampf(primary_skill, 0.0, 1.0) * BLOCK_SOLO_SHARE
	return clampf(
		solo + (1.0 - solo) * clampf(assist_skill, 0.0, 1.0) * BLOCK_ASSIST_SHARE,
		0.05, 0.98,
	)


func _block_contact_skill(blocker: VolleyballPlayer, close_fraction: float) -> float:
	if blocker == null:
		return 0.0
	var technique := clampf(
		_rating(blocker, "block_timing") * 0.46
		+ _available_jump_rating(blocker) * 0.29
		+ _body_reach_rating(blocker) * 0.15
		+ _rating(blocker, "anticipation") * 0.10,
		0.0, 1.0,
	)
	## Closing multiplies the block rather than adding to it. As a 0.14 additive
	## term a blocker who reached only a fifth of the lane still scored 84% of a
	## sealed block's quality, so making the close physical changed the number
	## and not the outcome. A blocker who did not get there does not block.
	return clampf(
		technique * lerpf(BLOCK_UNCLOSED_SHARE, 1.0, clampf(close_fraction, 0.0, 1.0)),
		0.05, 0.98,
	)


func _block_coverage_segment(
	center_x: float,
	blocker: VolleyballPlayer,
	close_fraction: float,
	completeness: float,
) -> Dictionary:
	var wingspan_width := clampf(
		(blocker.wingspan_cm if blocker != null else 190.0) / 900.0,
		0.16, 0.27,
	)
	var effective_width := wingspan_width * lerpf(0.42, 1.0, close_fraction)
	return {
		"x_min": clampf(center_x - effective_width * 0.5, 0.02, 0.98),
		"x_max": clampf(center_x + effective_width * 0.5, 0.02, 0.98),
		"completeness": clampf(completeness * close_fraction, 0.0, 1.0),
	}


func _home_block_segments(
	attack_x: float,
	primary: VolleyballPlayer,
	primary_close: float,
	assist: VolleyballPlayer,
	assist_close: float,
) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	segments.append(_block_coverage_segment(
		attack_x, primary, primary_close, _block_contact_skill(primary, primary_close)
	))
	if assist != null:
		segments.append(_block_coverage_segment(
			attack_x, assist, assist_close,
			_block_contact_skill(assist, assist_close)
		))
	return segments


func _best_home_server(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> VolleyballPlayer:
	# Service ownership follows rotational zone 1. The server's attributes still
	# determine quality; the strongest server cannot replace the legal server.
	return _player_by_id(players, lineup.player_at_slot(1))


## How poor a set has to be before the hitter gives up the swing.
##
## The rule lived on the opponent side only, at a threshold of 0.38 -- and measured,
## opponent first-ball sets have a median of 0.344, so it fired on more than half of
## their attacks. The opponent essentially never spiked: it rolled the ball over at
## 20-32 degrees instead of 5-14, while the home side swung at everything because it
## had no such rule at all.
##
## That one difference produced the whole dig asymmetry. Home defenders were digging
## lobs with 0.739 s of flight and opponent defenders spikes with 0.490 s, and every
## claim term downstream inherited exactly that gap while reaction delay and raw
## speed came out identical on both sides. Three earlier passes read it as a
## positioning problem.
##
## Now shared, and set from the pooled distribution rather than one side's: roughly
## the worst eighth of home sets and worst third of the opponent's, which keeps the
## compromise a real event on both sides without either team abandoning the swing as
## its default.
const ATTACK_COMPROMISE_SET_QUALITY: float = 0.30

## And how mediocre it has to be before a hitter might *choose* the safe shot.
##
## The improvisation roll was unconditional on the side that had it, which meant a
## hitter could tip a perfect set for no reason. Nobody rolls a good set over.
const ATTACK_IMPROVISE_SET_QUALITY: float = 0.40


## The shot a hitter actually plays, given the ball they were given.
##
## `intended` is what the lane or the position called for. A set too poor to swing
## at is downgraded rather than mishit: a roll shot if there is anything to work
## with, a tip if there is not. Improvisation is a roll of the dice weighted by the
## hitter's own decision-making, because choosing the safe shot is a read rather
## than a failure.
func _compromised_shot_type(
	hitter: VolleyballPlayer, intended: String, set_quality: float
) -> String:
	## The roll is always *drawn*, and only then gated. Drawing conditionally changes
	## how many numbers a rally consumes, which re-sequences every seeded outcome
	## after it -- the block-intent gates promptly flipped on samples of 25 against
	## 25, measuring a different random stream rather than a different block.
	var roll := rng.randf()
	var improvises := set_quality < ATTACK_IMPROVISE_SET_QUALITY \
		and roll < 0.10 + _rating(hitter, "decision_making") * 0.08
	if set_quality >= ATTACK_COMPROMISE_SET_QUALITY and not improvises:
		return intended
	return "Roll shot" if set_quality >= ATTACK_COMPROMISE_SET_QUALITY * 0.6 \
		else "Emergency tip"


func _hit_type(assignment: HitterAssignment, hitter: VolleyballPlayer) -> String:
	if assignment.lane in ["Front Quick", "Right Quick"]:
		return "Quick attack"
	if assignment.lane == "Pipe":
		return "Pipe attack"
	if assignment.tempo == 3:
		return "High-ball swing"
	if hitter.attack_power >= 82:
		return "Power swing"
	return "Tempo swing"


func _fallback_assignment(hitter: VolleyballPlayer, lineup: RotationLineup) -> HitterAssignment:
	var assignment := HitterAssignment.new()
	assignment.player_id = hitter.id
	assignment.start_position = CourtConstants.slot_position(
		lineup.slot_for_player(hitter.id)
	)
	assignment.lane = "Left Pin" if assignment.start_position.x <= 0.5 \
		else "Right Pin"
	assignment.tempo = 3
	return assignment


func _assignment_from_dict(data: Dictionary) -> HitterAssignment:
	if data.is_empty():
		return null
	var assignment := HitterAssignment.new()
	assignment.player_id = int(data.get("player_id", -1))
	assignment.start_position = Vector2(data.get(
		"perceived_start_position", Vector2(0.5, 0.75)
	))
	assignment.lane = str(data.get("lane", "Left Pin"))
	assignment.tempo = clampi(int(data.get("tempo", 2)), 0, 3)
	assignment.priority = clampi(int(data.get("priority", 1)), 1, 6)
	assignment.is_decoy = false
	return assignment


func _lineup_players(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null:
			result.append(player)
	return result


func _serve_landing_point(
	target_name: String,
	server: VolleyballPlayer,
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	var home_y := 0.84 if landing_on_home_side else 0.16
	var short_y := 0.67 if landing_on_home_side else 0.33
	var intended := Vector2(0.20, home_y)
	match target_name:
		"Zone 1":
			intended = Vector2(0.80, home_y)
		"Short Middle":
			intended = Vector2(0.50, short_y)
		"Weak Passer":
			intended = _weak_passer_target(home_players, lineup, landing_on_home_side)
		_:
			intended = Vector2(0.20, home_y)
	var accuracy := _rating(server, "serve_placement")
	var deviation := lerpf(0.105, 0.018, accuracy)
	var min_y := 0.54 if landing_on_home_side else 0.04
	var max_y := 0.96 if landing_on_home_side else 0.46
	return Vector2(
		clampf(intended.x + rng.randf_range(-deviation, deviation), 0.06, 0.94),
		clampf(intended.y + rng.randf_range(-deviation * 0.65, deviation * 0.65), min_y, max_y),
	)


func _weak_passer_target(
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	if landing_on_home_side and lineup != null:
		var weakest: VolleyballPlayer = null
		var weakest_slot := 5
		for slot_number in [5, 6, 1]:
			var candidate: VolleyballPlayer
			for player_resource in home_players:
				var player := player_resource as VolleyballPlayer
				if player.id == lineup.player_at_slot(slot_number):
					candidate = player
					break
			if candidate != null and (weakest == null or candidate.reception < weakest.reception):
				weakest = candidate
				weakest_slot = slot_number
		return CourtConstants.slot_position(weakest_slot)
	return Vector2(0.78, 0.16)


## Intended shot shape for a serve: how lofted the launch is, by style. This is
## the free "tempo/force intent" input; RallyKinematics.solve_launch_arc()
## derives the resulting duration and apex from it and the real distance to
## the landing point, rather than either being chosen directly.
func _serve_launch_angle_degrees(server: VolleyballPlayer, serve_quality: float) -> float:
	var angle_min := 16.0
	var angle_max := 24.0
	match server.primary_serve_style:
		"Jump Topspin":
			angle_min = 10.0
			angle_max = 16.0
		"Hybrid":
			angle_min = 12.0
			angle_max = 18.0
		"Jump Float":
			angle_min = 14.0
			angle_max = 20.0
		"Sky Ball":
			angle_min = 55.0
			angle_max = 65.0
	return _jittered_launch_angle(
		angle_min, angle_max, _power_rating(server, "serve_power"), serve_quality
	)


func _serve_style_proficiency(server: VolleyballPlayer) -> float:
	var scores := server.serve_style_proficiencies
	if scores.is_empty():
		scores = AttributeProfiles.serve_style_proficiencies(server)
	return clampf(float(scores.get(server.primary_serve_style, 50)) / 100.0, 0.01, 1.0)


## Intended shot shape for a set, by tempo. `tempo` is already the real
## tactical input (chosen by the called offensive play, not hardcoded); this
## only changes what a tempo *means physically*, from a table lookup to a
## shape that a real distance is then flown at.
func _set_launch_angle_degrees(
	setter: VolleyballPlayer, tempo: int, set_quality: float
) -> float:
	var angle_min := 6.0
	var angle_max := 10.0
	match clampi(tempo, 0, 3):
		1:
			angle_min = 12.0
			angle_max = 18.0
		2:
			angle_min = 25.0
			angle_max = 35.0
		3:
			angle_min = 45.0
			angle_max = 55.0
	var touch := (_rating(setter, "tempo_control") + _rating(setter, "hand_control")) * 0.5
	return _jittered_launch_angle(angle_min, angle_max, touch, set_quality)


## Intended shot shape for an attack, by the hitter's chosen action. Covers
## both the home-side hit_type vocabulary (_hit_type()) and the opponent-side
## attack_type vocabulary (_opponent_attack_type()), since both currently feed
## the same trajectory construction.
func _attack_launch_angle_degrees(
	hitter: VolleyballPlayer, attack_type: String, attack_quality: float
) -> float:
	var angle_min := 8.0
	var angle_max := 12.0
	match attack_type:
		"Quick attack":
			angle_min = 5.0
			angle_max = 8.0
		"Power swing":
			angle_min = 6.0
			angle_max = 10.0
		"Pipe attack", "Line attack", "Seam attack":
			angle_min = 8.0
			angle_max = 14.0
		"High-ball swing":
			angle_min = 10.0
			angle_max = 16.0
		"Controlled roll", "Roll shot":
			angle_min = 20.0
			angle_max = 30.0
		"Emergency tip", "Short tip":
			angle_min = 22.0
			angle_max = 32.0
	return _jittered_launch_angle(
		angle_min, angle_max, _power_rating(hitter, "attack_power"), attack_quality
	)


## Shared shape for every launch-angle helper above: a better-executed shot
## (higher rating) reliably flattens toward the harder-to-defend end of its
## action's range; a worse-executed one (lower quality) drifts away from
## whatever was intended, within the same safe range. Skill changes which
## angle is chosen; contact quality changes how well that choice is executed
## -- neither ever escapes the range RallyKinematics.solve_launch_arc() was
## calibrated against.
func _jittered_launch_angle(
	angle_min: float, angle_max: float, skill: float, quality: float
) -> float:
	var intended := lerpf(angle_max, angle_min, clampf(skill, 0.0, 1.0))
	var jitter := (1.0 - clampf(quality, 0.0, 1.0)) * (angle_max - angle_min) * 0.4
	return clampf(intended + rng.randf_range(-jitter, jitter), angle_min, angle_max)


func _nearest_reception_player(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	return _nearest_zone_player(
		_lineup_players(players, lineup), zones, landing_point, true
	)


func _nearest_floor_defender(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	)
	var pursuit_candidates: Array[VolleyballPlayer] = []
	for candidate in _lineup_players(players, lineup):
		var assignment: Resource = defensive_plan.assignment_for(candidate.id)
		if assignment == null or bool(assignment.emergency_pursuit):
			pursuit_candidates.append(candidate)
	return _nearest_zone_player(
		pursuit_candidates, zones, landing_point, true
	)


func _nearest_zone_player(
	candidates: Array[VolleyballPlayer],
	zones: Dictionary,
	landing_point: Vector2,
	require_enabled: bool,
) -> VolleyballPlayer:
	var nearest: VolleyballPlayer
	var nearest_distance := 1000.0
	for candidate in candidates:
		var zone: Resource = zones.get(candidate.id) as Resource
		if zone == null or (require_enabled and not bool(zone.enabled)):
			continue
		var distance := CoverageModel.court_distance_meters(zone.center, landing_point)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null and not candidates.is_empty():
		nearest = candidates[0]
	return nearest


func _opponent_reception_coverage(opponent_team: Resource) -> Dictionary:
	var passers: Array[VolleyballPlayer] = []
	var zones := {}
	var outside_index := 0
	for player_resource in opponent_team.on_court_players():
		var player := player_resource as VolleyballPlayer
		if player.position_role not in ["Outside Hitter", "Libero"]:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player.id
		zone.zone_type = DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		zone.radius_meters = 3.2
		zone.priority = 2
		if player.position_role == "Libero":
			zone.center = Vector2(0.50, 0.13)
			## The libero's skill already influences the claim. A blanket priority
			## advantage made them cross the full court ahead of a nearby outside.
			zone.radius_meters = 2.7
		else:
			zone.center = Vector2(0.20 if outside_index == 0 else 0.80, 0.16)
			outside_index += 1
		passers.append(player)
		zones[player.id] = zone
	return {"players": passers, "zones": zones}


func _arrival_phrase(arrival: Dictionary, arrived: bool, support_count: int) -> String:
	if not arrived:
		return "No assigned player could arrive before the ball landed."
	return "Arrived with %.2f m to spare; %d nearby teammate%s supported the zone." % [
		float(arrival.get("reach_margin_meters", 0.0)), support_count,
		"" if support_count == 1 else "s",
	]


func _receiver(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	var best: VolleyballPlayer = null
	for slot_number in [5, 6, 1]:
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and (best == null or candidate.reception > best.reception):
			best = candidate
	return best


## `_best_positioned_defender()` used to score defenders on proximity plus
## anticipation and lateral speed. `CoverageCalculator.choose_claimant()`
## replaced it with zone-aware arrival evaluation and left this behind
## uncalled; two defender selectors is one too many.


func _player_by_id(players: Array[VolleyballPlayer], player_id: int) -> VolleyballPlayer:
	for player in players:
		if player.id == player_id:
			return player
	return null


func _rating(player: VolleyballPlayer, property_name: String) -> float:
	if player == null:
		return 0.5
	var raw_rating := float(player.get(property_name)) / 100.0
	return clampf(
		raw_rating * (1.0 - player.fatigue * 0.18) \
			* player.confidence_execution_scale() + player.current_form * 0.06,
		0.05, 1.0,
	)


func _power_rating(player: VolleyballPlayer, property_name: String) -> float:
	if property_name == "attack_power":
		return clampf(float(player.usable_attack_power()) / 100.0 \
			* (1.0 - player.fatigue * 0.18) * player.confidence_execution_scale() \
			+ player.current_form * 0.06, 0.05, 1.0)
	var base := _rating(player, property_name)
	var mass_bonus := clampf((player.mass_kg - 82.0) / 48.0, -0.50, 1.0) * 0.07
	return clampf(base + mass_bonus, 0.05, 1.0)


func _available_jump_rating(player: VolleyballPlayer) -> float:
	var maximum_jump := _rating(player, "jump_reach")
	var jump_access := lerpf(0.62, 1.0, _rating(player, "explosiveness"))
	return clampf(maximum_jump * jump_access, 0.05, 1.0)


func _body_reach_rating(player: VolleyballPlayer) -> float:
	var standing_reach := inverse_lerp(200.0, 275.0, player.standing_reach_cm())
	var wingspan := inverse_lerp(160.0, 225.0, player.wingspan_cm)
	return clampf(standing_reach * 0.68 + wingspan * 0.32, 0.05, 1.0)


func _quality_phrase(quality: float) -> String:
	if quality >= 0.72:
		return "Perfect pass; every attacker remains available."
	if quality >= 0.48:
		return "Playable pass with multiple options."
	if quality >= 0.25:
		return "The setter is pulled off the net."
	return "The offense cannot control the first contact."
