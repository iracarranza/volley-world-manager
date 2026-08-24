class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const CoverageModel := preload("res://scripts/simulation/coverage_calculator.gd")

## How close two second-contact claims have to be before the ball is contested.
##
## A gap on the same 0-1 claim scale the chooser scores in, so it reads as "these
## two ranked within a tenth of each other" rather than as a distance or a time.
## Deliberately not measured yet: nothing has ever published a second-contact
## claim gap, so there is no distribution to cut. It is a starting value and the
## first thing to re-derive once the probe exists -- naming that here rather than
## letting a guessed constant pass as a fitted one.
const SECOND_CONTACT_SEAM_MARGIN: float = 0.10

## How close two bodies get before one has to go round the other.
##
## The widest torso in the game measures 0.715 m -- the figure the block's
## separation gate already asserts against, so this is that same body rather
## than a second opinion about how wide a voli is. Two of them need roughly that
## between their centres to pass, and inside it somebody swerves.
const OBSTRUCTION_CLEARANCE_M: float = 0.715

## How much wider a berth a grounded body gets than a standing one.
##
## A voli still getting up cannot step aside, so the whole of the avoiding falls
## to the mover; two upright volis each give way a little and meet in the middle.
## Unmeasured, and named as such: no obstruction frequency has ever been
## published, so there is no distribution to fit this against.
const OBSTRUCTION_GROUNDED_BERTH: float = 1.6
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const DefensivePlanModel := preload("res://scripts/models/defensive_plan.gd")
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const ShadowReceptionSystemModel := preload("res://scripts/simulation/shadow_reception_system.gd")
const RallyShadowComparisonModel := preload("res://scripts/simulation/rally_shadow_comparison.gd")
const RallyRolloutPolicyModel := preload("res://scripts/simulation/rally_rollout_policy.gd")
const RallyActionVocabularyModel := preload("res://scripts/simulation/rally_action_vocabulary.gd")
const CognitionCompilerModel := preload("res://scripts/simulation/cognition_compiler.gd")
const RallyFeatureFlagsModel := preload("res://scripts/simulation/rally_feature_flags.gd")
const PlatformContactModel := preload(
	"res://scripts/simulation/platform_contact_model.gd"
)
const FreeFlightInterceptionModel := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)
const OverpassActionModel := preload(
	"res://scripts/simulation/overpass_action_system.gd"
)
const GeometricAttackResolverModel := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
## What two volis on this side know about each other. Handed in by the manager
## before a rally rather than looked up, so the resolver stays a pure function of
## what it was given -- see the note on `rally_seed`.
const PairFamiliarityModel := preload("res://scripts/data/pair_familiarity.gd")
## How much a trusted hitter is worth to the setter's option score.
##
## Sized against `leadership_pull`, the other pull term here, which tops out at
## 0.18. A pair at the ceiling sits 76 points above the baseline, so 0.16 buys
## about 0.12 of score at full trust for a good setter -- comparable to the
## captain's pull and well below `base_quality`, whose spread across a roster is
## the better part of a point. The intent is that trust breaks a tie between
## comparable arms and never overrules a much better one.
const SETTER_TRUST_WEIGHT_LOW: float = 0.06
const SETTER_TRUST_WEIGHT_HIGH: float = 0.16

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
const HitterPlacementModel := preload(
	"res://scripts/simulation/hitter_placement_model.gd"
)
const SetPathReadModelRef := preload(
	"res://scripts/simulation/set_path_read_model.gd"
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
## How long a set has to be in the air before an assist blocker can bank the
## whole of their pre-set read.
##
## Anchored on the measured cost of a close, not on the length of a high ball.
## `primary_close_terms.required_seconds` runs 0.58-0.67 s across tempos 0-2 --
## that is what crossing to a lane actually takes -- so an assist needs about
## that much *post-set* time before anticipating the lane is worth committing
## to. Below it they are guessing and cannot recover if they guess wrong.
##
## Set at the high end of that band. Tried at 0.95 first, taken from the high
## ball's own flight, and it was far too severe: double blocks fell to 18% at
## tempo 1 and 24% at tempo 2, which deletes the ordinary read block rather than
## the one that should not have formed. Mean set flight for reference: 0.204 s
## at tempo 0, 0.392 at tempo 1, 0.426 at tempo 2, 1.006 at tempo 3.
const ASSIST_COMMIT_FLIGHT_SECONDS: float = 0.65

## What a wall that *committed* keeps when the ball comes quick.
##
## Bounding the assist by the set's flight alone produced zero double blocks at
## tempo 0 -- every rally, every wall, every roster. That is not a model of
## anything, it is a threshold driving a degenerate distribution, which is the
## same defect this engine keeps being caught by elsewhere. Committing to a lane
## before the set is exactly how a first-tempo ball gets doubled, and a blocker
## who reads early and adapts fast should sometimes be there too.
##
## So only the *reactive* share of the pre-set credit is bounded by the flight.
## The committed share survives whatever the tempo, because committing is a
## decision taken before the tempo is known. Its cost is already priced: a wall
## that commits and guesses wrong has moved away from where the ball went.
##
## Floor and span are set so the median wall -- commitment and read both near
## 0.5 -- keeps little, while a genuinely committed or fast-reading one keeps
## most of it.
const ASSIST_COMMIT_SIGNAL_FLOOR: float = 0.46
const ASSIST_COMMIT_SIGNAL_SPAN: float = 0.34

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
## How far past touching reach envelopes two blockers separate before the assist
## is worth nothing at all.
##
## Half a metre, which is about a ball's width plus the arm the hitter needs to
## get through it. Inside that the two are still a wall with a soft spot; past it
## they are two solo blockers who happen to be jumping at the same time.
const WALL_SEAM_OPEN_METERS: float = 0.50

## Search resolution for the serve's scan of the receiving half, and how the two
## terms of its score trade off. Sample points for a search, not a menu -- the
## chosen point is perturbed by the server's placement afterwards.
const SERVE_SCAN_COLUMNS: int = 11
const SERVE_SCAN_ROWS: int = 7
const SERVE_TARGET_NAMES: Array[String] = [
	"Zone 5", "Zone 1", "Short Middle", "Weak Passer",
]
## How many metres of drift from the requested zone one metre of daylight is
## worth. Below 1.0 the named zone leads and the seam only breaks ties within
## it, which is the intended reading: the bench picks the zone, the server picks
## the gap inside it.
const SERVE_SEAM_WEIGHT: float = 0.0
## How much credit open floor earns, by how much of it the server is willing to
## chase -- the timid end and the aggressive end of the same scale.
##
## Aggression belongs here rather than in a flat constant. A server told to sit
## on the zone hits the zone; one told to attack goes hunting for the seam, and
## the difference between those two is most of what serve aggression means.
##
## The ceiling is bounded because openness that nobody can cover is not a seam,
## it is the model handing out points. At 2.2 m -- roughly "no passer reaches
## this" -- an earlier cut of this walked the aim a metre and a half past the
## zone it was given and parked it behind the passing line on every serve.
const SERVE_SEAM_REWARD_TIMID_METERS: float = 0.7
const SERVE_SEAM_REWARD_BOLD_METERS: float = 1.8
## How many widths of a server's own placement scatter have to fit between the
## aim point and the nearest line before they will treat that floor as bankable.
##
## Two, for the same reason the net clearance margin is two: one is the margin
## that puts a sixth of your attempts over the line by construction.
const SERVE_SAFETY_SPREADS: float = 2.0
## How much short of a server's maximum carry the ball has to land before the
## distance stops costing them anything. Inside this the target fades rather than
## cutting off, because a ball at the edge of someone's range is not impossible,
## it is unreliable -- and unreliable is what this term is for.
const SERVE_CARRY_SLACK_METERS: float = 2.5
## How far from the zone the bench called the server will look for a gap.
##
## A metre and a half, which is about a passer's width plus a step. Without a
## bound the scan is free to answer a different question than it was asked: the
## openness reward keeps growing toward the corner while the drift penalty grows
## only linearly, so "Zone 5" resolved a metre deeper and half a metre wider than
## Zone 5 -- measured at y 0.88-0.93 against a baseline of 0.83-0.88. That is not
## finding the seam in a zone, it is picking a different zone, and the bench
## already made that call.
const SERVE_SEAM_SEARCH_RADIUS_METERS: float = 1.5

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
## The lowest controlled first contact that can keep a rally alive.
##
## This was 0.18 at both reception sites. On 1,200 paired serves, with the same
## serve byte-for-byte in every rotation, that hard edge turned two rotations of
## a weak outside into 55 and 45 aces while the other four produced 0, 1, 0 and
## 1. Replaying the recorded terms at 0.10 gives 31 and 23 without changing the
## receiving unit or erasing the weak passer: a poor contact reaches the setter
## as a poor ball and the offence must resolve it downstream instead of declaring
## every ball below 18% dead at first touch.
const RECEPTION_PLAYABLE_FLOOR: float = 0.10

## How much of a transition set the arriving ball can take away, and how much
## of a bad ball a commanding setter buys back. Recovery is what makes a
## setter's attributes matter most exactly when the ball is worst.
const TRANSITION_BALL_WEIGHT: float = 0.62
const TRANSITION_BALL_RECOVERY: float = 0.40

## What a ball off the block is worth relative to a clean one, at a fully formed
## wall. Without this a block touch recycled at full quality and a blocker was
## worth nothing unless they stuffed it outright.
const BLOCK_DEFLECTION_CARRY: float = 0.55
## How far below the top of the hands a ball has to be met before the wall stops
## it dead rather than deflecting it back into play, and where the two extremes
## land on the hitter's own side.
##
## `attack_resolution_model.gd` already cuts a stuff at its own depth band; this
## is the softer question of where the ones that stay alive come down. A ball off
## the fingertips keeps its pace and carries to `FAR_Y`; one buried under the
## hands drops near the tape at `NEAR_Y`. The interval is the one the scalar
## version drew uniformly over, now placed by the contact instead of by chance.
const BLOCK_DEFLECTION_STOP_METERS: float = 0.30
const BLOCK_DEFLECTION_NEAR_Y: float = 0.56
const BLOCK_DEFLECTION_FAR_Y: float = 0.74

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

## What this blocker means to do with their hands.
##
## Three sources, in the order a real decision has them:
##
## 1. **The instruction**, when the manager wrote one. `TacticSheet` stores a
##    per-voli block behaviour and "soft block" and "kill block" are two of its
##    four options -- this is their first consumer. A voli told what to do does
##    it, which is what an instruction is for.
## 2. **The read**, when nobody said. `AttemptJudgment.backs_off` asks whether a
##    player recognises that what they are attempting is beyond them, and a
##    blocker who is late, low or facing a swing they cannot beat is in exactly
##    that position. Recognising it and angling the hands back *is* the safer
##    option, so the same function that makes a setter take the high ball makes a
##    blocker take the soft block.
## 3. **Pressing**, otherwise. A blocker who is on the ball, or who has not
##    noticed they are not, goes for it.
##
## `deficit` is how far the swing is beyond this block, on the 0-to-0.4 scale
## `AttemptJudgment` documents: zero when the contest is winning, growing as the
## swing pulls ahead.
## Returns `{hands, call, followed}` rather than a bare string, so a rally record
## can say what was *asked* as well as what was done. An instruction nobody can
## see obeyed or ignored is not an instruction.
func _block_hands_intent(
	blocker: VolleyballPlayer,
	contest_margin: float,
	close_fraction: float,
	instruction: String = "",
) -> Dictionary:
	## **The call names an action; it does not perform one.** This used to be a
	## `match` that returned outright, which made every blocker obey identically
	## -- and it never fired anyway, because nothing wrote the key. Both halves
	## were wrong in the same direction: an instruction is something a voli
	## *adheres to*, in proportion to `tactical_discipline`, not something that
	## replaces them.
	##
	## Only the two hands behaviours map. `close line` and `close cross` are lane
	## instructions from the same clipboard page and say nothing about the hands;
	## treating them as a hands call would be inventing a call the manager did not
	## make.
	var call := ""
	match instruction:
		"soft block":
			call = "soft"
		"kill block":
			call = "kill"
	if blocker == null:
		return {"hands": "neutral", "call": call, "followed": false}
	## **Late and low, not behind on the contest.**
	##
	## The first version read the deficit off `contest - attack_quality`, and every
	## block in the game came out pressing: 224 of 224. That margin is the
	## *outcome* of the contest, decided after the fact and including the execution
	## roll -- a blocker in the air cannot feel it, and it sat at or above zero even
	## on swings the wall went on to miss.
	##
	## What a blocker can feel is whether they got there. `primary_close` is how
	## much of the travel to the ball they completed, and a blocker who is still
	## closing knows it in the air -- that is the moment the choice is actually
	## made. The contest margin still contributes, because a wall that is beaten on
	## height as well as position is further outside its capability, but it is the
	## smaller term rather than the only one.
	var short_of_the_ball := (1.0 - clampf(close_fraction, 0.0, 1.0)) \
		* BLOCK_CLOSE_DEFICIT_SHARE
	var beaten_on_the_contest := maxf(-contest_margin, 0.0)
	var deficit := clampf(
		short_of_the_ball + beaten_on_the_contest,
		0.0, AttemptJudgmentModel.OBVIOUS_DEFICIT,
	)
	## What this voli would do left alone: recognition and temperament, exactly as
	## `AttemptJudgment` splits them. `tactical_discipline` is deliberately absent
	## here -- it decides adherence below, never self-assessment.
	var own := "kill" if deficit <= 0.0 \
		else ("soft" if AttemptJudgmentModel.backs_off(blocker, deficit) else "kill")
	if call.is_empty() or call == own:
		## No call, or the call is what they were going to do anyway. Nothing for
		## discipline to act on, and it must not act: an attribute that moves a
		## voli when nobody asked them anything is temperament.
		return {"hands": own, "call": call, "followed": not call.is_empty()}
	## They disagree with the call. **The sign comes from `call`, not from the
	## attribute** -- discipline returns whatever was asked, so it pushes toward
	## soft under a soft call and toward kill under a kill call. An attribute that
	## always produced the same action would be temperament again, and the gate in
	## `test_runner.gd` fails if it is.
	##
	## `_identity_roll` rather than a fresh draw: it is the repeatable per-rally
	## channel the identity calls already use, so this adds no RNG stream and
	## nothing downstream reseeds.
	var follows := _identity_roll(
		"block-hands|%d" % blocker.id
	) < _rating(blocker, "tactical_discipline")
	return {"hands": call if follows else own, "call": call, "followed": follows}


## How a ball off the block flies. The angle is a squirt off the hands rather
## than a struck ball, so it hangs: four metres takes about 0.7s, which is what
## makes chasing one legible rather than teleportation. A stuff is the exception
## -- driven down, over in a fifth of a second, and the rally ends there.
## How much of a struck ball's pace a pair of hands takes out of it.
##
## Bounded well short of both ends on purpose. A block that absorbed nothing
## would return the spike at the spike's own speed, which is not a deflection but
## a mirror; one that absorbed nearly all of it would make every touched ball a
## free ball and remove the reason a hitter fears the wall. The band is what
## separates a blocker who kills the pace from one who merely gets a hand on it.
const BLOCK_ABSORB_SOFT: float = 0.42
const BLOCK_ABSORB_FIRM: float = 0.68

## What the hands are *trying to do*, which is a different axis from where the
## wall stands.
##
## `block_intent` -- Seal or Funnel -- is lateral: it decides which part of the
## hitter's cone the wall takes away. This is the other axis, and the sport has
## always had both: two blockers at the same height with the same timing produce
## different balls depending on whether they pressed over the tape to end it or
## angled back to keep it alive. It is not an attribute. It is a decision, and
## `AttemptJudgment` is the module that already models exactly this decision for
## the second and third contacts -- a setter backing off a quick, a hitter
## rolling instead of swinging. The block is the fourth contact that needs it and
## the only one that never asked.
##
## **Pressing is not simply better.** A kill block that comes off wins more
## rallies outright; one that is beaten hands the hitter a tool at full pace,
## because there is nothing behind hands that are already committed forward. A
## soft block gives up stuffs and converts the swing into a ball the defence can
## actually play. That trade is the whole reason the choice exists, and it is why
## this changes both the stuff margin and the absorption rather than only one.
const BLOCK_KILL_STUFF_BONUS: float = -0.045
const BLOCK_SOFT_STUFF_PENALTY: float = 0.075
## How much of the absorption band each intent commands. A soft block is the
## upper end of what hands can take off a ball; a kill block is the lower, since
## pressing forward means meeting the ball rather than giving with it.
## How much of the "am I beyond my capability" read a blocker takes from not
## having closed, against how much from being beaten on height. Weighted toward
## the close because that is the half a blocker knows in the air.
const BLOCK_CLOSE_DEFICIT_SHARE: float = 0.45
const BLOCK_KILL_ABSORB_SHARE: float = 0.30
const BLOCK_SOFT_ABSORB_SHARE: float = 1.25
## Nothing comes off the hands at nothing. Below this the ball is effectively
## dropping straight down, which is a stuff and has its own branch.
const MIN_DEFLECTION_MPS: float = 2.5

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
## What a transition second contact gets when the dug ball has no modelled
## flight. The literal 0.68 this replaces was the only contact window in the
## engine not derived from a ball; it survives as the fallback rather than being
## deleted, because a dig genuinely may not have an arc yet.
const DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS: float = 0.68

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
## teleporting the rally. The former 0.51 floor was only 18 cm from the tape --
## close enough that a regulation-size ball plus a reaching hand visually read
## as clipping it. 0.515 is 27 cm, and changes only this error tail; the intended
## front-row target remains centred at 54 cm.
const HOME_SET_DELIVERY_MIN_Y: float = 0.515
const HOME_SET_DELIVERY_MAX_Y: float = 0.80
const OPPONENT_PASS_DELIVERY_MIN_Y: float = 0.20
const OPPONENT_PASS_DELIVERY_MAX_Y: float = 0.49

## A set the hitter never contacts does not become a zero-quality spike. It
## continues past the hands and falls on the attacking side. These values shape
## only that short visible fall; the terminal outcome is still an attack error.
const MISSED_SET_DROP_SECONDS: float = 0.34
const MISSED_SET_DROP_DEPTH_METERS: float = 0.85
const MISSED_SET_DROP_LATERAL_METERS: float = 0.24
const MISSED_SET_DROP_VERTICAL_MPS: float = -2.4

## What a defender brings to a dig, as a fraction of an ideal one. Sums to 1.0
## so the result can be compared with an attack quality that is also a fraction
## of an ideal, which is the whole point of a contest between them.
## What a defender's eyes are worth against a hitter's arm.
##
## A contest, not a bonus: `court_vision - arm_speed` is signed, so an elite
## reader against a slow arm sees the shot early and a poor reader against a fast
## one is genuinely behind it. Sized against the read terms it joins -- the
## responsibility fit and the scouting bonus both work in hundredths -- so a full
## 100-vs-1 mismatch is worth about as much as being in exactly the right zone,
## and an ordinary pairing is worth nothing.
const DIG_VISION_READ_WEIGHT: float = 0.10

## What the wall in front of a defender tells them.
##
## **Funnelling has never bought the diggers anything, which is the whole point
## of funnelling.** A block told to funnel gives the line and channels the ball
## into the middle, so the defence behind it knows where to be -- and until now
## the intent moved only the wall's own position, so choosing it was a decision
## with no consequence for the six people it was made on behalf of.
##
## Sealing is worth less rather than nothing: holding the line still removes one
## option, it simply concedes the angle rather than narrowing it. A touched ball
## is worth the most of the three, because a defender is reading a ball that has
## already slowed and changed direction -- and the engine already pays them the
## extra flight time for it, so this is the read that goes with the time.
const FUNNEL_READ_BONUS: float = 0.075
## A sealed wall hides the ball and the hitter's last contact from defenders
## directly behind it. That lost vision is the price of trying to end the rally
## at the net, especially against tools and late soft shots.
const SEAL_READ_BONUS: float = -0.030
const TOUCHED_BALL_READ_BONUS: float = 0.090

## How much of a blocker's read a fast arm takes away.
##
## `arm_speed` was generated, trained, scouted, shown on the profile wheel and
## read by no simulation code at all -- it turned up in the inert-attribute audit
## and stayed there. This is one of its two consumers. Bounded well under the
## play-reading terms it sits beside, because the arm is the last cue a blocker
## gets and not the main one: they have already read the pass, the setter's body
## and the tempo by the time it matters.
const ARM_SPEED_READ_COST: float = 0.06

## How much of the tempo demand a fast arm pays off.
##
## The other consumer, and the one that makes the attribute matter to a middle in
## particular. `tempo_demand` is what a fast set costs the hitter, and it was a
## property of the *setter* alone -- their `tempo_control` decided how hard a
## quick was to run, and the person actually swinging at it had no say. Getting
## the arm through in time is most of what running a quick is.
const ARM_SPEED_TEMPO_RELIEF: float = 0.30

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
## **Measured against the distribution it cuts, and it is outside it.**
##
## Home pass quality runs p10 0.291, p25 0.350, p50 0.419, p75 0.494, p90 0.567
## (`tools/run_shot_downgrade_probe.gd`). A quick-call floor of 0.68 sits above
## the ninetieth percentile, so the quicken branch of `_tempo_call` fires
## essentially never -- while `OPPONENT_SLOW_CALL_PASS` at 0.38 sits between the
## first quartile and the median and fires on roughly a third of balls. The tempo
## call is therefore a one-way ratchet toward the slowest set in the game, which
## is most of why 91% of home swings are tempo 3.
##
## Not moved here, because it is shared with the opponent's path and their pass
## distribution is a different shape (p50 0.276 against the home side's 0.419) --
## one constant cut against two distributions is its own problem and wants its
## own measurement rather than a value tuned until the home side looks right.
const OPPONENT_QUICK_CALL_PASS: float = 0.68
const OPPONENT_SLOW_CALL_PASS: float = 0.38

## How good a pass has to be before the middle is a live option.
##
## Solved against the measured home pass distribution rather than chosen: 0.494
## is the p75, so a floor there makes the quick available on roughly the best
## quarter of balls. Real offences run a first-tempo ball on more than that, but
## a quarter is a mix rather than a special case, and it is a figure that can be
## raised once the middle's swing is calibrated instead of one that has to be
## walked back.
##
## Deliberately *not* 0.68. That is `OPPONENT_QUICK_CALL_PASS`, which sits above
## this distribution's ninetieth percentile -- see the note there.
const OFFENSE_QUICK_PASS_FLOOR: float = 0.494

## The three tempo gates, re-sited on the distributions they actually cut.
##
## Every one of them was set outside its own spread, which is why 91% of home
## swings came out at tempo 3 and `tempo_variation` and `transition_commitment`
## were attributes that changed nothing for the default identity.
##
##   quick call        pass quality p75 is 0.494 home, 0.486 opponent; the old
##                     0.68 sat above *both* p90s and never fired once
##   tempo variation   presets run 0.24-0.88 with Balanced on 0.50
##   commitment        blended presets run 0.225-0.843, three of six in 0.42-0.51
##
## Each is placed at or just below the median of its own table, so the default
## identity is inside every gate rather than outside all three.
const LIVE_QUICK_CALL_PASS: float = 0.49
const LIVE_TEMPO_VARIATION_FLOOR: float = 0.48
const LIVE_COMMITMENT_HIGH: float = 0.56
const LIVE_COMMITMENT_LOW: float = 0.44

## How far from neutral a blended commitment has to sit to pull the tempo every
## time it can.
##
## **The gates above were the right fix to the wrong shape.** Re-siting them
## inside their own distribution stopped them missing the default identity, and
## left them as *gates* -- so Pāwa Hitō at 0.841 and Xérvu at 0.644 both cleared
## `LIVE_COMMITMENT_HIGH` and received exactly the same instruction, and the
## region whose entire identity is relentless transition was indistinguishable
## from one whose identity is serving. Measured across 640 rallies each, their
## mean tempo came out 1.86 against 1.91 and their nearest-neighbour separation
## was the second-tightest in the league.
##
## Tempo is an integer 0-3, so a continuous input cannot become a fractional
## shift; it becomes a *probability* of the shift. The number is the largest
## deviation from neutral the regional table actually contains -- blended
## commitment runs 0.30 (Blôc du Larg) to 0.84 (Pāwa Hitō) around a neutral
## 0.50 -- so the two extremes act on every eligible set, Landavol at 0.50 acts
## on none, and everyone in between is graded rather than sorted.
const COMMITMENT_FULL_PULL: float = 0.34

## The most steps one variation call may rotate a tempo.
##
## Variation is a *rate* rather than a two-sided lean: 0 means a side runs the
## same tempo every time and 1 means it rotates whenever the pass allows, so it
## reads directly as the chance of rotating and needs no neutral point and no
## constant to scale it. What it does need is a reach, because a side that
## rotates constantly but only ever by one step is still predictable -- and
## being unpredictable is the whole of Spëddigh. The second step is available
## only in proportion to how far past neutral the axis sits.
const VARIATION_MAX_STEPS: int = 2

## How little time the second contact can have to spare before somebody else
## breaks for the ball as well. A margin this small means the setter is arriving
## on the ball rather than waiting for it, which on a real court is when a second
## voli starts running without being told to.
const CHASE_MARGIN_SECONDS: float = 0.18

## How much of the pre-set window the hitter is credited with.
##
## The blocker already gets `preset_window * preset_share`, 0.26 to 0.72 of it
## depending on their read -- and the hitter got nothing at all, despite both
## reading the same pass. That is why running quick *cost* the offence: measured
## across the six identities, kill rate fell monotonically with tempo shift,
## 0.3774 for the identity that slows sets down against 0.3239 for the one that
## speeds them up. A first-tempo ball squeezed the attacker and left the wall's
## head start untouched.
##
## Higher than the blocker's best share, and deliberately: a hitter knows the
## play and starts their approach off the pass, while a blocker cannot commit
## until the set is up and is guessing until then. The pre-set window is worth
## more to the person who already knows where they are going.
const HITTER_PRESET_SHARE: float = 0.82

## How far a set-distribution nudge can outrank raw attacking ability.
##
## Sized so it reorders candidates who are close and never overrides a clear
## difference: the scored terms span roughly 0-1, so five steps of 0.03 move a
## contender by at most 0.12 -- about a grade band. A bigger value would feed the
## worst hitter as often as the best, which is not distribution, it is noise.
const SET_SPREAD_STEP: float = 0.03

## How much a lane is worth avoiding once the other bench is sitting on it.
##
## Sized against `SET_SPREAD_STEP`'s ladder and the `shot_variety` term it
## competes with: big enough that a hitter with a repertoire will be moved off a
## read lane, small enough that a one-lane hitter still swings where they can.
const LANE_ANTICIPATED_PENALTY: float = 0.42

## What running the middle is worth over hitting a pin, on a ball where the quick
## is available.
##
## The middle beats the block by arriving before it, which no attribute on the
## hitter expresses -- so without a term for it a middle is priced as a hitter
## with a shorter approach and never gets set. With it the middle is one good
## option among several, which is what the position is.
const QUICK_OPTION_BONUS: float = 0.06
## How sharply the set goes to the best option rather than being shared out.
##
## Six, measured: it leaves the strongest front-row attacker taking a clear
## plurality while the others stay live. Raise it and the offence narrows toward
## the argmax this replaced; drop it toward one and the setter feeds a weak
## hitter as readily as a strong one.
const SET_DISTRIBUTION_SHARPNESS: float = 6.0

## What running the pipe is worth, and what the extra ground costs.
##
## Smaller than the quick's bonus because a pipe does not beat the block by
## arriving early -- it beats it by arriving somewhere the wall is not looking
## while two front-row hitters hold their attention. The travel term is scaled by
## `transition_speed`, which is the attribute for exactly this and had almost
## nowhere to express itself: a hitter who cannot get from defensive base to
## behind the attack line in the time the pass buys is not a pipe option, whoever
## else they are.
const PIPE_OPTION_BONUS: float = 0.05
const PIPE_TRAVEL_COST: float = 0.12

## A pipe is a second-tempo ball: faster than the high outside set it competes
## with, slower than the quick it runs behind.
const PIPE_TEMPO_CALL: int = 2

## A quick is a first-tempo ball by definition. Tempo 3 stays the default for
## everything else, which is the deliberate high-ball call and not a defect.
const QUICK_TEMPO_CALL: int = 1

## A shoot is the pin lane run at the quick's tempo -- a flat, fast ball to the
## antenna that arrives before the block can travel to it. Second tempo rather
## than first, because it has further to fly than a quick does.
const SHOOT_TEMPO_CALL: int = 2

## How much the attacker is favoured when swing and dig are equally good. A
## clean swing beats a set defence more often than not, so an even contest is
## not a coin flip.
## Measured, not assumed: with the block re-derived, 416 swings reached the
## floor and 82% of them came up. A clean swing beating a set defence should not
## be the exception, and at 0.09 an even contest was close to a coin flip on a
## scale where the two sides sit at parity.
##
## **How much better than the defence an attack has to be to beat it.**
##
## Named for what it is now rather than for what it was. As
## `DIG_ATTACKER_ADVANTAGE` it sat at +0.07, and read against `edge = defence -
## attack` that means the defence had to be *seven points better* just to draw
## level: at equal quality the attacker won. The design says the opposite --
## "a good defence beats a good offence, but a good defence loses to a much
## better offence" -- so the sign was wrong for the claim it was implementing,
## and the previous re-fit from 0.20 had moved its size without questioning its
## direction.
##
## Negative, so the defence holds when the two are level and keeps holding while
## it is up to this far behind. Above that the attack is through, and
## `_dig_outcome`'s grading then makes the rest of the margin count: a ball that
## clears the bar by a little is dug badly, one that clears it by a lot is a
## kill. That is the "much better" half, and it is a slope rather than a second
## threshold.
##
## Measured against the distribution it cuts: over 247 digs the margin runs
## -0.517 at the tenth percentile to +0.468 at the ninetieth, so a bar anywhere
## in that range moves a real share of contests rather than sitting off the end
## of it doing nothing.
##
## **Sized by what the statement actually claims, which is parity.** "A good
## defence beats a good offence" is a claim about *level* quality, not about the
## defence being handed a cushion. At -0.14 with the solo share raised alongside
## it, the dig rate came out at 0.630 against a 0.35-0.55 band and the kill rate
## fell to 0.382 -- a defence that wins comfortably, which is a different and
## worse claim. Just past zero is the whole of what was asked for.
const DIG_ATTACKER_ADVANTAGE: float = -0.04

## One defender is not a whole defence. The attacker picks where the ball goes;
## a defender covers the zone they were assigned. Without this the dig scale
## centred above the swing scale -- exactly the mismatch a solo block had at
## 0.78 -- and 470 swings produced 42 kills against 63 errors and 44 stuffs.
##
## **0.90 from 0.62, and this is the re-fit `docs/BACKLOG.md` has been waiting
## on.** The whole floor defence was fitted against attacks modelled as
## ground-to-ground lobs; a spike is struck downward at 16 to 30 m/s and arrives
## in about half the time, which is the correction the drawing landed. Fitted
## against the sport rather than against the previous number -- over 700 rallies,
## both serving sides, the three rates a real match has real values for:
##
##                     before   after   target
##     kill rate        0.628   0.481   0.45 - 0.50
##     dig rate         0.232   0.478   0.35 - 0.55
##     stuff rate       0.106   0.112   0.08 - 0.14
##
## `tools/run_rally_balance_probe.gd` is that reading and is the instrument to
## re-run before touching either of these again.
## **Raised from 0.90 with the ball's new pace.** One defender is still not a
## whole defence and this still says so; what changed underneath is that a spike
## now arrives at up to 28 m/s where it used to arrive at 18, and the floor
## defence was priced against the slower ball. Measured after the pace work, the
## two fastest speed bands were dug 12% and 11% of the time -- a hard swing had
## become close to undiggable, which is the opposite of a defence a viewer can
## be proud of. This is the flat buff that pays for the faster ball, sized at
## 0.93 rather than the 0.96 first tried: with the breakthrough bar moved as
## well, 0.96 double-counted the same correction and pushed the dig rate out of
## band on the other side.
const DIG_SOLO_SHARE: float = 0.93
const DIG_EXECUTION_NOISE: float = 0.10

## How hard a swing attempted outside the approach's capability bites. Mirrors
## `SetterCapabilitySystem.OVERREACH_SEVERITY` at the second contact: a hitter a
## long way past what their run-up gave them does not merely hit worse, they put
## the ball out.
const ATTACK_OVERREACH_SEVERITY: float = 1.60

## What a metre of dragged-back contact costs the swing.
##
## `_reachable_contact` spares a hitter who cannot make the ideal contact by
## moving the ball to them, and `ENABLE_CLAMPED_ARRIVAL_MARGIN` correctly stops
## billing them for lateness afterwards. But hitting from a metre further off the
## net is genuinely worse -- a flatter angle over the tape and a longer ball to
## the floor -- and with the lateness gone nothing charged that at all. Measured
## on the displacement fixture, a hitter dragged 0.74 m back came out marginally
## *better* for it.
##
## Sized against the term it replaces rather than chosen. The old lateness charge
## reached the swing through `swing_deficit * ATTACK_OVERREACH_SEVERITY`, and the
## arrival component of that deficit ran about 0.66 for a clamped opponent swing
## -- roughly a metre of drag for roughly a point of deficit. This is that same
## exchange rate expressed in the channel the cost actually belongs to.
const CLAMPED_CONTACT_SEVERITY: float = 0.22

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
## Target choice is match behavior but must not reroll every contact after the
## serve. Its stream is deterministic and separate from contact execution.
var serve_decision_rng := RandomNumberGenerator.new()
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
## M4's controlled-dig rollout is independent of the continuous-rally stack.
## A probe can open this contact alone without also promoting reception, setter,
## attack and block implementations and contaminating the comparison.
var platform_dig_development_open: bool = false
## Debug-only paired measurement can still run the retired ball beside the
## promoted one. This preserves the validation protocol after production opens;
## ordinary callers never set it and cannot disable production authority.
var platform_dig_development_force_legacy: bool = false
## Reception's own development-open, decoupled from the dig's so a probe can open
## physical reception without the dig's dev override reaching it (or vice versa).
## The legacy-force above is shared: forcing legacy forces it for every family.
var platform_reception_development_open: bool = false
## The opponent's defensive plan for this rally, built on first use.
var opponent_plan: Resource = null
var rally_clock: float = 0.0
var live_positions: Dictionary = {}
var opponent_live_positions: Dictionary = {}
## Every voli's position as of the last contact, so the next one can say where
## its actor started.
##
## M8 asks each boundary for `actor_start -> traversal -> contact`. The contact
## end is `body_contact_position`; the *start* is where that voli was when the
## previous contact happened, and it existed only inside whichever resolver
## branch had moved them. Snapshotting the live maps once per contact answers it
## uniformly and derives nothing: the leg for contact N is the interval between
## contact N-1 and contact N, so the position at N-1 is the start by definition.
var _positions_at_last_contact: Dictionary = {}
## The receiving side's own labels for its receive shape, captured where the
## shape is built.
##
## `_receive_formation_map` separates the passers from the front-row volis
## staging off the passing lanes from the setter, and its own note says the
## distinction exists so the cognition layer does not have to re-derive, from a
## coordinate, a fact the formation builder already had. The shape now lives in
## `live_positions` from rally initialization, so the labels have to be carried
## rather than recomputed -- recomputing them at the reception is what made the
## drawn formation a second representation in the first place.
var receive_formation_intents: Dictionary = {}
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
## Which way a body was set when it finished its last committed leg.
##
## The third of the three things a body carries, beside where it is and what it
## is carrying. Only a leg whose *form* establishes an orientation writes here --
## `movement_establishes_facing()` decides, so a shuffle or a block close leaves
## whatever was already set. A voli with no entry is seeded from their side's
## ready facing by `RallyStateBuilder`, which is what every actor got before this
## existed.
##
## **Expected inert for defenders, and that is not a failure.** Every defensive
## leg in the resolver is `"lateral"` and LATERAL preserves, so a defender cannot
## change their own orientation while the form comparison is blocked -- measured
## at 2 of 796 defensive contacts made by a body that had run. See
## `docs/review/ACTOR_CONTINUITY.md`.
var player_facing: Dictionary = {}
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
## And what that posture was read off, for the same reason.
var last_dig_reach_margin: float = 0.0
## What the rally's recoveries cost in condition, to be charged by the caller.
var recovery_fatigue_cost: Dictionary = {}
## What each player *did*, in condition, this rally.
##
## **Fatigue used to be charged by the rally rather than by the work.** Everyone
## on court paid `RALLY_FATIGUE_BASE` whether they had jumped six times or stood
## in position and watched, which makes conditioning a property of being selected
## rather than of playing. A middle who blocks every ball and a libero who never
## leaves the floor tired at exactly the same rate, and the one attribute meant
## to separate them -- `stamina` -- could only scale a number that was already
## the same for both.
##
## Booked here and charged by the match layer, exactly as `recovery_fatigue_cost`
## already is, and for the same reason: a resolver that writes to the roster it
## is resolving breaks replay determinism, and the gate catches it immediately.
var exertion_cost: Dictionary = {}
## What the manager drew on the clipboard, handed in before the resolve like
## `pair_familiarity` beside it. The resolver deliberately never sees the
## `VolleyballTeam`; it sees the sheet, which is the same boundary
## `defensive_plan` and `team_principles` already respect.
##
## Home only, and that asymmetry is honest rather than an omission: the sheet is
## the manager's own club's, and an opponent hands-call would have to be invented.
var tactic_sheet: Resource = null
var shadow_reception_trace: RallyTrace
var home_principles: Resource
var opponent_principles: Resource
var identity_effects: Dictionary = {}
var rally_seed: int = 0
## Whether this rally's setter can actually deliver a first-tempo ball, taken
## from their own shadow read rather than guessed from the pass.
##
## `ShadowSetterResponseSystem._set_options` has decided this all along -- gated
## on arrival balance, confidence and `tempo_control` -- and published it into
## evidence, the rollout audit and the progression calibration. Three consumers,
## none of them the rally. The setter decided whether to run a quick and the
## rally never asked.
var setter_can_run_quick: bool = false
## Which swing of this rally is being placed, so a hitter who swings twice does
## not ask for the identical coordinate both times.
var swing_index: int = 0
## The lane the other bench has learned to expect from this offence, so the
## offence can answer it. Empty until they have seen enough to have an opinion.
var opponent_anticipated_lane: String = ""
var previous_serves: Dictionary = {}
## Signed from the home side's perspective. Opponent decisions read the inverse.
var current_match_flow: float = 0.0
## The home squad's pair table, handed in rather than reached for.
##
## Empty is a valid state and means *nobody is tracking this* -- every pair reads
## at the baseline and the trust term contributes nothing, which is what the
## opponent's setter should get until opponents keep tables of their own.
var pair_familiarity: Dictionary = {}
## How settled this squad is, handed in on the same principle as the pair table
## above: the simulator does not reach for a `Team`, it is given the two numbers
## it needs. The defaults are `Team`'s own, so a caller that forgets gets an
## ordinary squad rather than a perfect or a broken one.
##
## Both, not one. Cohesion is whether they get on; tactical familiarity is
## whether they have drilled the overlap. A squad can have either without the
## other and the seam wants both.
var team_cohesion: float = 0.50
var team_tactical_familiarity: float = 0.35
var last_set_decision: Dictionary = {}
## Names available to player-facing narration, filled in as the rally reaches
## each contact.
##
## `RallyExplanations` substitutes these into headline, explanation and factor
## text. Threading them through the ~20 `factor()` call sites individually would
## have meant proving each name was in scope at each one; accumulating them here
## means a line can only name a role the rally has already resolved, which is
## the same constraint stated once.
##
## A per-call `values` dictionary merges *over* this, so a line about the
## opponent's hitter can override `hitter` without disturbing the home name the
## rest of the rally uses.
var narration: Dictionary = {}


func resolve(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	active_play: OffensivePlay,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int,
	development_continuous_reception: bool = false,
	development_physical_platform_dig: bool = false,
	team_principles: Resource = null,
	home_team_name: String = "",
	serve_context: Dictionary = {},
	match_flow: float = 0.0,
	development_legacy_platform_dig: bool = false,
	development_physical_reception: bool = false,
) -> Resource:
	rng.seed = seed_value
	rally_seed = seed_value
	serve_decision_rng.seed = hash("%d|serve-decision" % seed_value)
	previous_serves = serve_context.duplicate(true)
	current_match_flow = clampf(match_flow, -1.0, 1.0)
	## Commentary names both benches, and the simulator knew neither. The
	## opponent's name was reachable through `opponent_team` all along; the home
	## side's had to be passed, because the resolver deliberately never sees the
	## `VolleyballTeam` it is resolving for.
	narration = {
		"team": home_team_name if not home_team_name.is_empty() else "the home side",
		"opponent": str(opponent_team.team_name) \
			if opponent_team != null and "team_name" in opponent_team \
			else "the opposition",
	}
	geometric_swing_index = 0
	geometric_serves = {}
	geometric_development_open = development_continuous_reception
	platform_dig_development_open = development_physical_platform_dig
	platform_reception_development_open = development_physical_reception
	platform_dig_development_force_legacy = development_legacy_platform_dig \
		and OS.is_debug_build()
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
	setter_can_run_quick = false
	swing_index = 0
	last_set_decision = {}
	opponent_anticipated_lane = str(
		opponent_team.anticipated_lane()
	) if opponent_team != null else ""
	shadow_reception_trace = null
	## Nobody starts a rally on the floor.
	player_recovery = {}
	recovery_fatigue_cost = {}
	exertion_cost = {}
	receive_formation_intents = {}
	_positions_at_last_contact = {}
	live_positions = _initial_home_positions(
		lineup, defensive_plan, not home_serving, true,
		players if not home_serving else [], receive_formation_intents,
	)
	## Everyone starts the rally genuinely at rest -- this is the one moment the
	## old assumption was true.
	live_velocities = {}
	opponent_live_velocities = {}
	player_facing = {}
	opponent_live_positions = _initial_opponent_positions(
		opponent_team, home_serving, true, receive_formation_intents
	)
	var result: Resource = RallyResultModel.new()
	result.initial_home_positions = live_positions.duplicate(true)
	result.initial_opponent_positions = opponent_live_positions.duplicate(true)
	## The posture each side holds while the ball is on the other side.
	##
	## Computed by asking `_initial_*_positions` for the *defending* arrangement
	## regardless of who is actually serving, because that is exactly what a
	## floor-defence posture is. Reusing those functions rather than reaching
	## into the plan again keeps one answer to "where does this player stand" --
	## the alternative was a second derivation free to drift from the first.
	result.home_base_positions = _initial_home_positions(
		lineup, defensive_plan, false, false
	)
	result.opponent_base_positions = _initial_opponent_positions(
		opponent_team, false, false
	)
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
	narration["server"] = server_name
	var setter := _player_by_id(players, lineup.active_setter_id())
	if setter != null:
		narration["setter"] = setter.display_name
	## Weights are relative importance and are normalised by their own total, so
	## this is a genuine 0-1 quality rather than one capped at the coefficient
	## sum. They previously added to 0.72, which meant an opponent server with
	## every rating at 100 produced 0.72 -- and since reception subtracts
	## `serve_quality * 0.48`, the most dangerous serve in the game could apply
	## only 0.35 of pressure. The home formula already spans the full range
	## because its tactical risk term makes up the remainder.
	## The server's own appetite, then the bench's, on the same 0.70 scale the
	## home side uses. This read the player attribute alone, so an opponent whose
	## whole identity is the serve -- Xérvu at 0.92 -- served exactly like one who
	## never risks it, and `serve_aggression` was the single best-wired principle
	## in the resolver while being visible from only one side of the net.
	var opponent_risk := clampf(
		_rating(opponent_server, "serve_aggression")
			+ (float(opponent_principles.serve_aggression) - 0.5) * 0.70,
		0.0, 1.0,
	)
	var intended_target := str(opponent_team.tendencies.get("serve_target", "Zone 5"))
	var serve_decision := _serve_decision(
		"opponent", intended_target, opponent_server, opponent_risk
	)
	opponent_risk = float(serve_decision.risk)
	var usable_serve_pace := _usable_serve_pace(opponent_server)
	var opponent_serve_weighted := usable_serve_pace * 0.41 \
		+ _rating(opponent_server, "serve_placement") * 0.07 \
		+ _rating(opponent_server, "serve_consistency") * 0.12 \
		+ _rating(opponent_server, "serve_aggression") * 0.04 \
		+ _serve_style_proficiency(opponent_server) * 0.08
	var serve_quality := clampf(
		opponent_serve_weighted / OPPONENT_SERVE_WEIGHT_TOTAL
		+ (0.06 if str(serve_decision.mode) == "aggressive" else -0.015)
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
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
	## **Drawn and discarded.** The verdict this used to decide now comes off the
	## flight, but the draw stays where it was so every downstream consumer of
	## `rng` keeps the stream it had -- a serve pass that also reshuffled the
	## reception, the set and the swing would be unmeasurable. It decides
	## nothing; `_serve_error_chance` survives only to keep the shape of it.
	## Removing it is a separate, purely mechanical change.
	var _retired_serve_error_draw := \
		rng.randf() < _serve_error_chance(opponent_server, opponent_risk)
	var serve_aim := _serve_landing_point(
		str(serve_decision.target), opponent_server, players, lineup, true,
		_receive_formation_positions(lineup, players, false), opponent_serve_origin,
		serve_decision,
	)
	var canonical_serve := _canonical_serve(
		"geometric_serve_opponent", opponent_server,
		opponent_serve_origin, serve_aim, false, opponent_risk,
	)
	var serve_landing: Vector2 = canonical_serve.get("landing", serve_aim)
	var serve_error := bool(canonical_serve.get("error", true))
	var serve_spin: Dictionary = canonical_serve.get(
		"spin", _serve_spin(opponent_server)
	)
	var serve_time := float(canonical_serve.get("duration_seconds", 1.0))
	var serve_trajectory := _ball_trajectory(
		"serve", opponent_serve_origin, serve_landing, serve_time,
		float(canonical_serve.get("apex_rise_meters", 0.0)),
		-1.0, NAN, NAN,
		float(canonical_serve.get("contact_height_meters", NAN)),
		## **`end_height` stays NAN, and that is a ruling rather than a gap.**
		##
		## Publishing a real one was tried: `out_reason` already says whether this
		## serve stopped at the tape or reached the floor, so the flight's own
		## endpoint is a fact and not a choice. The suite refused it -- 60 of 120
		## serves -- and the refusal was correct. `end_height_meters` is not read
		## as this flight's endpoint. `BallFlight.from_trajectory` reads it as the
		## height of the **next contact**, and the comment inside
		## `_ball_trajectory` already names the conflict: *"Those are different
		## numbers and choosing between them is `CONTACT_AND_BALL_FLIGHT.md`'s
		## unresolved item 5, not something to settle as a side effect of owning
		## the launch."*
		##
		## So the 1.000 m default is a placeholder standing in for an unresolved
		## design question, not a bug to repair. See
		## `docs/review/BODY_CENTRE_SCOPE.md` section 6.
	)
	_stamp_launch_state(serve_trajectory, canonical_serve)
	## Where this server belongs once the ball is gone: their own defensive spot,
	## the same one every other opponent gets from `court_position`.
	_add_event(result, RallyEventModel.EventType.SERVE, opponent_server.id, server_name,
		opponent_serve_origin, serve_landing, not serve_error, serve_quality,
		"%s serve" % opponent_server.primary_serve_style if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.", {
			"side": "opponent", "target": str(serve_decision.target),
			"called_target": intended_target,
			"aim_point": serve_decision.aim_point,
			"serve_mode": serve_decision.mode,
			"changed_target": serve_decision.changed_target,
			"target_familiarity": serve_decision.target_familiarity,
			"target_radius_meters": serve_decision.target_radius_meters,
			"execution_accuracy": serve_decision.execution_accuracy,
			"server_id": opponent_server.id, "server_slot": 1,
			"serve_style": opponent_server.primary_serve_style,
			"flight_time": serve_time,
			"event_time": 0.0, "contact_time": serve_time,
			## What the ball did, from the one flight that decided all of it.
			## `serve_out_reason` is empty on a serve that stayed in; on one that
			## did not it names the line or the tape, which the old path could not
			## do because the verdict predated the ball.
			"serve_out_reason": canonical_serve.get("out_reason", ""),
			"net_clearance_meters": canonical_serve.get(
				"net_clearance_meters", 0.0
			),
			"launch_speed_mps": serve_trajectory.get("launch_speed_mps", 0.0),
			"launch_angle_degrees": serve_trajectory.get(
				"launch_angle_degrees", 0.0
			),
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

	## **Judged from the bodies, not the formation.** `origins` is optional and
	## this call omitted it, so every voli was measured from their zone centre --
	## which `evaluate_arrival` itself says is "true in a serve-receive formation
	## and true nowhere else". At serve time it is nearly true, and the cost was
	## invisible until something asked about *spacing*: measured over 590
	## contested receptions the nearest-teammate distance came back 2.99 m on
	## every single one, p05 through max, because it was the distance between two
	## fixed points on a formation diagram rather than between two volis.
	##
	## A constant input is a knob that cannot reach its own range, which is this
	## repository's most-repeated failure, and it would have made the crowding
	## term below unfireable while looking exactly as though it worked.
	var reception_origins := {}
	for reception_candidate in _lineup_players(players, lineup):
		if live_positions.has(reception_candidate.id):
			reception_origins[reception_candidate.id] = Vector2(
				live_positions[reception_candidate.id]
			)
	var reception_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		defensive_plan.zones_for(DefensiveZoneModel.ZoneType.SERVE_RECEIVE),
		serve_landing, serve_time, "reception", {}, reception_origins,
	)
	var receiver := reception_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = _nearest_reception_player(players, lineup, defensive_plan, serve_landing)
	if receiver != null:
		narration["receiver"] = receiver.display_name
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
		_seed_carried_body_states(live_state, rally_clock)
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
	## **A serve is the hardest ball in the game to read**, which is the whole
	## point of a float: eighteen metres of flight from a contact the passer
	## cannot see the hand on, and nothing in front of it to funnel the answer.
	var arrival: Dictionary = _read_adjusted_arrival(
		Dictionary(reception_claim.get("arrival", {})),
		_read_error_meters(
			## The spin the launch search *settled on*, not the whole of what this
			## server can put on a ball. They are different numbers -- the sweep
			## trades brush against range and usually keeps less than all of it --
			## and novelty, which is what makes a ball hard to track, is computed
			## from the rotation the ball actually carries.
			receiver, serve_trajectory, serve_spin,
			float(serve_trajectory.get("start_time", rally_clock)),
		),
	)
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
	var support_bonus := _support_term(
		support_count,
		float(reception_claim.get("nearest_teammate_meters", 1000.0)),
	)
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
	var reception_body_penalty := CoverageModel.reception_body_penalty(
		receiver, arrival, serve_quality
	)
	var reception_noise := rng.randf_range(-0.14, 0.14)
	result.reception_quality = clampf(reception_base - serve_quality * 0.48 \
		- opponent_risk_pressure \
		- reception_body_penalty \
		+ arrival_bonus + support_bonus - seam_penalty \
		+ reception_noise,
		0.0, 1.0)
	if using_live_reception:
		result.reception_quality = clampf(float(selected_live_reception.get(
			"quality", 0.0
		)), 0.0, 1.0)
	if not receiver_arrived:
		result.reception_quality = minf(result.reception_quality, 0.12)
	var reception_success: bool = receiver_arrived \
		and float(result.reception_quality) >= RECEPTION_PLAYABLE_FLOOR
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
		receiver, receiver_start, serve_landing, serve_time, "lateral",
		float(arrival.get("read_error_meters", 0.0)),
		## The contact family's own body-derived height, not the trajectory's
		## ambiguous endpoint height. A reception already computes this exact
		## quantity for the outgoing pass; using it here closes M3 without making
		## either meaning of `end_height_meters` authoritative by accident.
		GeometricAttackPromotionModel.pass_contact_height_meters(receiver),
		_incoming_ball_direction(
			serve_trajectory, serve_landing, opponent_serve_origin
		),
	)
	if not using_live_reception:
		## Short of the ball is where a beaten passer actually is, and it is what
		## the rest of the rally should reason from as well as what playback
		## should draw.
		live_positions[receiver.id] = receiver_reach
	var preferred_release: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id()) \
		if defensive_plan != null else Vector2(0.50, 0.60)
	var desired_pass_target: Vector2 = _desired_pass_target(preferred_release, serve_landing)
	var home_reception_setter := _player_by_id(players, lineup.active_setter_id())
	## Captured before the pass resolves, because the anchor is what this contact
	## was aimed at and the destination is where it went. Conflating them is how
	## an intent record comes to be unfalsifiable.
	var home_reception_intent := _platform_intent(
		"serve_reception", desired_pass_target, "release_seat",
		home_reception_setter,
		Vector2(live_positions.get(
			lineup.active_setter_id(), preferred_release
		)),
	)
	var reception_pass := _reception_pass_result(
		receiver, receiver_start, serve_landing, desired_pass_target,
		opponent_serve_origin, serve_quality, arrival,
		float(result.reception_quality), 0.51, 0.98, serve_trajectory,
		_player_by_id(players, lineup.active_setter_id()),
		home_reception_intent,
		_platform_body_velocity(
			receiver_start, receiver_reach, receiver_move_time, serve_time
		),
		float(serve_trajectory.get("end_time", rally_clock + serve_time)),
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
	## The side that just served, taking base while their serve is in the air.
	var opponent_serve_intents := {}
	var opponent_by_id := {}
	if opponent_team != null:
		for entry in opponent_team.on_court_players():
			var opponent_player := entry as VolleyballPlayer
			if opponent_player != null:
				opponent_by_id[opponent_player.id] = opponent_player
	var opponent_serve_transition := _serve_transition_map(
		opponent_team.current_lineup() if opponent_team != null else null,
		_opponent_defensive_plan(opponent_team) if opponent_team != null else null,
		true, serve_time, opponent_by_id, opponent_serve_intents,
	)
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		serve_landing, Vector2(reception_pass.destination), reception_success,
		result.reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s %s" % [
			roundi(float(result.reception_quality) * 100.0),
			_quality_phrase(float(result.reception_quality)),
			_arrival_phrase(arrival, receiver_arrived, support_count) \
			+ (" Equal-priority passers hesitated at the seam." if seam_conflict else ""),
		], {"side": "home", "landing": serve_landing,
			"platform_intent": home_reception_intent,
			## Where the home six stand to receive this serve.
			##
			## On the *reception* event rather than the serve, because playback
			## draws a leg as `event -> next_contact` and reads its targets off
			## `next_contact`. So these move people during the serve's flight,
			## which is when a side takes up its receive shape. Published on the
			## serve event they were never drawn at all -- nothing precedes the
			## first contact of a rally, so that leg does not exist. Measured
			## after the fact: 400 serves of 400 had no preceding flight.
			"home_phase_targets": _lineup_live_shape(lineup, live_positions),
			"home_phase_intents": receive_formation_intents,
			"opponent_phase_targets": opponent_serve_transition,
			"opponent_phase_intents": opponent_serve_intents,
			"planner_zone_center": Vector2(receiver_zone.center) \
				if receiver_zone != null else receiver_start,
			"planner_zone_radius_meters": float(receiver_zone.radius_meters) \
				if receiver_zone != null else 0.0,
			"planner_zone_priority": int(receiver_zone.priority) \
				if receiver_zone != null else 0,
			"flight_time": serve_time, "arrival": arrival,
			## Every additive reception-quality term, before clamping. A terminal
			## outcome can locate attrition at first contact; these terms explain
			## which input caused it without reproducing the formula in a probe.
			"reception_terms": {
				"base": reception_base,
				"serve_pressure": -serve_quality * 0.48,
				"risk_pressure": -opponent_risk_pressure,
				"body_penalty": -reception_body_penalty,
				"arrival_bonus": arrival_bonus,
				"support_bonus": support_bonus,
				"seam_penalty": -seam_penalty,
				"execution_noise": reception_noise,
				"unclamped_quality": reception_base - serve_quality * 0.48
					- opponent_risk_pressure - reception_body_penalty
					+ arrival_bonus + support_bonus - seam_penalty
					+ reception_noise,
				"final_quality": result.reception_quality,
				"success_threshold": RECEPTION_PLAYABLE_FLOOR,
				"receiver_arrived": receiver_arrived,
			},
			"support_count": support_count, "seam_conflict": seam_conflict,
			"claim_margin": float(reception_claim.get("claim_margin", 1.0)),
			## Who was nearest against who took it. See `choose_claimant`: this is
			## the pair that says whether reachability is creating responsibility
			## or only deciding whether it succeeds.
			"nearest_id": int(reception_claim.get("nearest_id", -1)),
			"nearest_distance_meters": float(reception_claim.get(
				"nearest_distance_meters", -1.0
			)),
			"winner_distance_meters": float(reception_claim.get(
				"winner_distance_meters", -1.0
			)),
			"reachable_count": int(reception_claim.get("reachable_count", 0)),
			"immediate_lock": bool(reception_claim.get("immediate_lock", false)),
			"immediate_owner_count": int(reception_claim.get("immediate_owner_count", 0)),
			"nearest_teammate_meters": float(reception_claim.get(
				"nearest_teammate_meters", -1.0
			)),
			"movement_start": receiver_start,
			"movement_target": receiver_reach,
			"movement_duration": receiver_move_time,
			"event_time": _contact_time(serve_trajectory, rally_clock),
			"incoming_trajectory": serve_trajectory,
			"outgoing_trajectory": pass_trajectory,
			"body_alignment": reception_pass.body_alignment,
			## What the second contact is going to be asked to reach. Published on
			## both sides so the gate can check the height a setter was read
			## against is the height this pass actually delivered -- the opponent
			## path recomputed it from a retired table for a year and nothing could
			## see the difference.
			"pass_apex_meters": reception_pass.get("pass_apex_meters", 0.0),
			"set_contact_height_meters": reception_pass.get(
				"set_contact_height_meters", 0.0
			),
			"platform_feasibility": reception_pass.platform_feasibility,
			"contact_posture": reception_pass.contact_posture,
			"reach_margin_meters": reception_pass.get("reach_margin_meters", 0.0),
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
	## The shared platform record, only when the physical reception launched one --
	## the legacy scatter carries none, so the key is absent and the event metadata
	## is unchanged with the flag off.
	if reception_pass.has("platform_contact"):
		(result.events[-1] as RallyEvent).metadata["platform_contact"] = \
			reception_pass.platform_contact
	if seam_conflict:
		result.key_factors.append(_factor("seam_conflict"))
	if not reception_success:
		## `ace` fires from both benches. The outcome is the same event; the
		## sentence is not, so the conceded side takes its own explanation key.
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		}, "ace_conceded")
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
		_seed_carried_body_states(attack_state, rally_clock)
	var setter_response := Dictionary(
		shadow_summary.get("shadow_setter_response", {})
	)
	## Physically executable rather than perceived: a setter who believes they can
	## run a quick and cannot is a setter who shanks it, and that is the failure
	## classifier's business, not the offence's menu.
	setter_can_run_quick = "quick_tempo_set" in Array(
		setter_response.get("selected_physically_executable_actions", [])
	)
	var shadow_attack := ShadowAttackSystemModel.evaluate(
		attack_state, setter_response, receiver.id, seed_value + 1700003,
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
	## When the reception published an authoritative free flight, the second
	## contact is chosen by physical interception -- the same M5 machinery the
	## transition set uses -- not by `_spatial_setter_choice` against the pass
	## destination. The intended setter is soft intent; the actual interceptor owns
	## contact two, may be an emergency setter, and consumes the realised prefix.
	## A pass no teammate can reach terminates truthfully (floor/net/out gives the
	## serving team the point; a legal crossing is the opponent's ordinary first
	## contact). Legacy feeds carry no free flight and keep the spatial choice, so
	## the flag-off path is unchanged.
	var physical_choice := {}
	if str(pass_trajectory.get("trajectory_role", "")) \
			== "authoritative_free_flight":
		physical_choice = _physical_second_contact_choice(
			pass_trajectory, home_second_contact.candidates,
			home_second_contact.starts, defensive_plan,
			lineup.active_setter_id(), receiver.id, setter, &"home",
			defensive_plan.setter_release_target(lineup.active_setter_id()),
			GeometricAttackPromotionModel.set_contact_height_meters(setter),
			float(serve_trajectory.get("duration", 0.0)),
		)
		_stamp_free_flight_resolution(result, physical_choice)
		if physical_choice.get("player") == null:
			var terminal_reason := str(Dictionary(physical_choice.get(
				"terminal", {}
			)).get("reason", "unresolved"))
			if terminal_reason == "crossed_net_unresolved":
				## The received ball crossed the net unplayed: the opponent makes
				## their ordinary first team contact, symmetric to every other exit.
				var opponent_overpass := _resolve_overpass_into_opponent(
					result, players, lineup, pass_trajectory, opponent_team,
					defensive_plan, 1, float(result.reception_quality), receiver,
				)
				if opponent_overpass != null:
					return opponent_overpass
				return _finish(result, "m5_unresolved_overpass", false, receiver.id, {
					"hitter": receiver.display_name,
				})
			## Nobody on the receiving side could set the pass: the point goes to
			## the serving side. No prior attack exists on a first ball, so the
			## credit falls back to a bare opponent point.
			var opponent_attacker := _latest_attack_credit(result, "opponent")
			return _finish(
				result, "opponent_kill", false, int(opponent_attacker.id),
				{"hitter": str(opponent_attacker.name)},
			)
	var set_contact := Vector2(physical_choice.get(
		"contact_position", reception_pass.destination
	))
	var second_contact_window := float(physical_choice.get(
		"contact_time", 0.0
	)) - float(pass_trajectory.get("start_time", 0.0)) \
		if not physical_choice.is_empty() \
		else float(pass_trajectory.get("duration", 0.68))
	var setter_choice := physical_choice if not physical_choice.is_empty() \
		else _spatial_setter_choice(
			home_second_contact.candidates, home_second_contact.starts,
			defensive_plan, lineup.active_setter_id(), receiver.id, setter,
			set_contact, second_contact_window,
			## The serve's own flight. A setter releases toward their target when
			## the ball is struck, not when the platform touches it -- the run they
			## have already made by the time the pass exists.
			float(serve_trajectory.get("duration", 0.0)),
			## Held for the short-leg timing reason recorded in `OUTSTANDING` §1;
			## only the legacy spatial arm reaches this.
			Vector2.ZERO,
		)
	## **The height this setter actually takes the ball at.** Under a physical
	## reception the pass has no authored endpoint, so the height is a property of
	## the interception rather than of the launch: `_stamp_free_flight_resolution`
	## has already published exactly this value onto the reception event, and the
	## capability read below has to consume the same one or the two describe
	## different contacts. The legacy arm keeps the pass's own delivered height.
	var delivered_set_contact_height := float(physical_choice.get(
		"contact_height_meters", NAN
	)) if not physical_choice.is_empty() \
		else float(reception_pass.get(
			"set_contact_height_meters",
			SetterCapabilityModel.pass_contact_height_meters(
				float(result.reception_quality), rng.randf()
			),
		))
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
	## Re-stated because an emergency second contact replaces the setter named
	## at the top of the rally, and the commentary should name whoever actually
	## took the ball.
	if setter != null:
		narration["setter"] = setter.display_name

	var follow_threshold := 0.22 + _rating(setter, "decision_making") * 0.35 \
		+ _rating(setter, "tactical_discipline") * 0.18
	result.play_was_followed = active_play != null \
		and result.reception_quality >= 0.42 \
		and rng.randf() < follow_threshold
	var assignment := _choose_assignment(
		active_play, result.play_was_followed, players, lineup, setter.id,
		setter, float(result.reception_quality), current_match_flow,
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
				active_play, false, players, lineup, setter.id,
				setter, float(result.reception_quality), current_match_flow,
			)
	var hitter := _player_by_id(players, assignment.player_id) if assignment != null else null
	if hitter == null or hitter.id == setter.id or not _can_enter_attack(hitter):
		hitter = _fallback_hitter(
			players, lineup, setter.id, float(result.reception_quality),
			setter, current_match_flow,
		)
		assignment = _fallback_assignment(hitter, lineup)
	if hitter != null:
		narration["hitter"] = hitter.display_name
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
	## The other four, while the pass is in the air.
	##
	## Computed here, where the hitter is finally known, and attached to the SET
	## event below -- because playback reads a leg's targets off the contact it
	## is flying *toward*, so the pass's flight is described by the set. Attached
	## to the reception event these moved people during the *serve*, which is the
	## one phase that already had a shape of its own.
	var home_transition_intents := {}
	var home_transition_targets := _transition_phase_map(
		players, lineup, receiver.id, setter.id,
		hitter.id if hitter != null else -1,
		set_contact, second_contact_window, setter_arrival_margin,
		home_transition_intents,
	)
	if active_play == null:
		result.key_factors.append(_factor("default_offense"))
	else:
		result.key_factors.append(_factor(
			"play_followed" if result.play_was_followed else "play_abandoned"
		))
	result.key_factors.append(_factor(
		"good_pass" if result.reception_quality >= 0.58 else "poor_pass"
	))
	## When this ball actually reaches the setter's hands: the interception the
	## flight was resolved to, or the authored pass's own landing when there was no
	## flight to intercept.
	var set_decision_moment := float(physical_choice.contact_time) \
		if not physical_choice.is_empty() \
		else _contact_time(pass_trajectory, rally_clock)
	_add_event(result, RallyEventModel.EventType.SET_DECISION, setter.id, setter.display_name,
		Vector2(0.50, 0.67), Vector2(0.50, 0.60), true,
		result.reception_quality,
		"Emergency setter decision" if emergency_setter else "Setter decision",
		"Stays with %s." % result.active_play_name if result.play_was_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."),
		{"side": "home", "emergency_setter": emergency_setter,
			"option_evaluation": last_set_decision.duplicate(true),
			"first_contact_id": receiver.id,
			## The decision is taken when the ball reaches the setter, and the
			## window runs from there.
			##
			## **Which moment that is depends on who ends the flight.** A legacy pass
			## is authored to land on the setter, so its `end_time` *is* the arrival.
			## A physical pass is not: its `end_time` is where the untouched ball
			## would have hit the floor, which is strictly later than the point a
			## body actually met it. Reading the flight's end there stamped the
			## decision after the set it precedes, and the causality floor spent 33
			## corrections putting it back -- the one remaining place where the
			## untouched endpoint still stood in for the interception.
			"event_time": set_decision_moment,
			"deadline": set_decision_moment + second_contact_window,
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
		## The height this contact actually happens at, not a second guess at it.
		## `SetterCapabilitySystem.pass_contact_height_meters` drew this from a
		## table against a random sail value -- a third model of a fact the pass
		## itself now computes from its own apex under gravity, and one whose floor
		## sat above every setter's forehead, so the underhand set it was meant to
		## produce could never happen. Resolved once above, so the legacy arm reads
		## the pass's delivered height and the physical arm reads the interception's.
		delivered_set_contact_height,
		setter_approach_quality,
	)
	var resolved_tempo := int(setter_capability.resolved_tempo)
	if bool(setter_capability.tempo_downgraded):
		assignment = _downgraded_assignment(assignment, resolved_tempo)
		result.key_factors.append(_factor("play_abandoned"))
	var tempo_demand := float(3 - resolved_tempo) * 0.055 \
		* lerpf(1.0, 0.65, _rating(setter, "tempo_control")) \
		* lerpf(1.0, 1.0 - ARM_SPEED_TEMPO_RELIEF, _rating(hitter, "arm_speed"))
	## The lane the setter is *aiming* at. `_set_geometry` reads this rather than
	## where the ball ends up, because difficulty is a property of the attempt.
	## The hitter says where, inside the lane the bench called; the setter tries
	## to put it there. `lane_target` remains the lane's centre and is what this
	## falls back to when there is no hitter to ask.
	var intended_set_target := HitterPlacementModel.preferred_point(
		hitter, assignment.lane, rally_seed, swing_index
	)
	var intended_hitter_body := SetPathReadModelRef.body_position(
		hitter, intended_set_target, true
	)
	swing_index += 1
	var set_target := intended_set_target
	var set_geometry := _set_geometry(
		setter, setter_start, set_contact, intended_set_target, preferred_release
	)
	var hitter_choice_start := Vector2(live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	))
	var ordinary_set_arc := _set_arc(
		setter, assignment.tempo, float(result.reception_quality),
		GeometricAttackPromotionModel.set_contact_height_meters(setter),
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		RallyKinematics.court_distance_meters(set_contact, intended_set_target),
	)
	var set_height_extra := _set_rescue_height_meters(
		_movement_time(hitter, hitter_choice_start, intended_hitter_body, "transition"),
		float(ordinary_set_arc.duration_seconds),
	)
	var set_height_difficulty := _set_height_difficulty(setter, set_height_extra)
	## One number carrying both the overreach and the reach cost, so the severity
	## of attempting something beyond a setter lives with the model that decides
	## what "beyond" means rather than being restated here.
	var capability_penalty := float(setter_capability.quality_penalty)
	var home_set_terms := _set_terms(
		setter, float(setter_capability.effective_pass_quality),
		tempo_demand, capability_penalty, setter_arrival_margin,
		float(set_geometry.difficulty) + set_height_difficulty,
		(Familiarity.execution_modifier(setter) - 1.0) * 0.16,
	)
	home_set_terms["height_difficulty"] = set_height_difficulty
	home_set_terms["rescue_height_meters"] = set_height_extra
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
		## Per lane, because the pipe has an attack line to respect and the pins
		## do not. Clamping the *intent* behind the line is not enough while the
		## delivery can scatter across it.
		CourtConstants.lane_delivery_min_y(
			assignment.lane, HOME_SET_DELIVERY_MIN_Y
		),
		HOME_SET_DELIVERY_MAX_Y,
		## How far this ball is being thrown, so a long set scatters like a long
		## set. Measured from the intent rather than from the delivered point,
		## which is the thing being computed.
		RallyKinematics.court_distance_meters(set_contact, intended_set_target),
		## And how high they are putting it. A rescue ball bought with height is
		## harder to place, which is the reason a side does not simply set
		## everything to the ceiling.
		float(ordinary_set_arc.apex_height_meters) + set_height_extra,
	)
	var set_angle := _set_launch_angle_degrees(
		setter, assignment.tempo, float(result.set_quality)
	)
	## Standing or off the floor, decided here because this is the first point
	## that knows both halves of it: the pass has an apex and the setter has an
	## arrival margin. `_reception_pass_result` has the apex but runs before the
	## chooser, so it cannot know how rushed this body is.
	var jump_set := _jump_set_decision(
		setter, float(reception_pass.get("pass_apex_meters", 0.0)),
		setter_arrival_margin,
		## The whole run, not the scrap the head start left: a setter who covered
		## six metres to get here is carrying speed into the plant whatever the
		## last stride looked like.
		RallyKinematics.court_distance_meters(
			Vector2(setter_choice.get("origin", setter_start)), set_contact
		),
		float(setter_choice.get("total_travel_seconds", setter_move_time)),
	)
	var set_release_height := GeometricAttackPromotionModel \
		.set_contact_height_meters(setter, bool(jump_set.jumping))
	var set_arc := _set_arc(
		setter, assignment.tempo, float(result.set_quality),
		## Bounded by where the ball actually got to. A setter cannot release
		## from above the pass's own apex whatever they do with their legs, and
		## this is the half of the clamp that was always right -- it was inert
		## only because the other half never moved.
		minf(set_release_height, maxf(
			float(reception_pass.get("pass_apex_meters", set_release_height)),
			0.01,
		)),
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		RallyKinematics.court_distance_meters(set_contact, set_target),
		set_height_extra,
	)
	## Pace, not shape. The flatter parabola a higher contact allows already
	## falls out of `_set_arc`; this is the kinetic half the geometry cannot
	## give, and it shortens the flight rather than changing where the ball goes.
	var natural_set_flight: float = float(set_arc.duration_seconds) \
		/ maxf(_set_pace_scale(setter, bool(jump_set.jumping)), 0.5)
	var home_tempo_timing := _hitter_led_set_timing(
		setter, hitter, assignment.tempo, assignment.lane,
		intended_set_target, false,
		natural_set_flight, float(result.set_quality), home_principles,
		_pair_fraction(setter.id, hitter.id), team_tactical_familiarity,
		"home-first-%d" % swing_index,
	)
	var set_flight_time := float(home_tempo_timing.delivered_flight_seconds)
	set_arc = _retimed_set_arc(
		set_arc, set_flight_time, set_release_height,
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
	)
	var release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var release_interval := _release_interval(release_profile, float(result.set_quality))
	## The instant the ball leaves the setter's hands. The set flight, the SET
	## event, and the hitter's approach window are all timed from this one value.
	##
	## **The two arms measure from different origins, and only one of them can add
	## a duration to `rally_clock`.** On the home first ball the clock is never
	## advanced to the reception -- the reception derives its own moment from the
	## serve's `end_time` instead -- so `rally_clock` sits behind the pass. The
	## legacy window is a duration measured from that same lagging origin, so the
	## sum stays self-consistent. A physical interception is not: its `contact_time`
	## is an absolute moment on the free flight's own timeline, and adding the
	## interval between two absolute moments back onto the lagging clock lands the
	## set *before* the reception that fed it -- which is what the causality floor
	## was correcting. Read the interception's own moment instead. The transition
	## paths reach the identical quantity by the other route, because there the
	## clock has already been advanced to the feeding contact.
	var set_contact_time := (
		float(physical_choice.contact_time) + release_interval
	) if not physical_choice.is_empty() \
		else rally_clock + second_contact_window + release_interval
	var set_trajectory := _ball_trajectory(
		"set", set_contact, set_target, set_flight_time,
		float(set_arc.apex_height_meters),
		set_contact_time, NAN, NAN,
		float(set_arc.get("release_height_meters", NAN)),
		float(set_arc.get("arrival_height_meters", NAN)),
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
			## **The leg this setter was actually timed on**, published on the same
			## terms the opponent first ball and the home continuation already
			## publish theirs. `movement_duration` under a physical interception is
			## the travel to the *body* contact -- a reach short of the ball -- and
			## it is charged against a setter who is already moving. An instrument
			## that reads the ball position and rebuilds the body at rest is
			## therefore comparing a different leg against a different assumption,
			## which is the whole of the movement-agreement residual on this path.
			## Both values come from the interception that was selected; the legacy
			## spatial arm falls back to the ball contact and a standing start,
			## exactly as before.
			"body_contact_position": Vector2(physical_choice.get(
				"body_contact_position", set_contact
			)),
			"movement_entry_velocity": Vector2(physical_choice.get(
				"entry_velocity_mps", Vector2.ZERO
			)),
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
	(result.events[-1] as RallyEvent).metadata["rescue_height_meters"] = set_height_extra
	(result.events[-1] as RallyEvent).metadata["height_difficulty"] = set_height_difficulty
	var set_event := result.events[-1] as RallyEvent
	_stamp_second_contact_claim(set_event, setter_choice)
	## The ball this set was struck against is the realised prefix that actually
	## reached the setter, not the full free flight to the floor -- the same
	## segment stamped onto the reception. This holds the reception-to-set chain by
	## identity; the legacy spatial arm carries no realised segment and keeps the
	## pass as stamped above.
	if set_event != null and not physical_choice.is_empty():
		var reception_realised := Dictionary(physical_choice.get(
			"realised_trajectory", {}
		))
		if not reception_realised.is_empty():
			set_event.metadata["incoming_trajectory"] = reception_realised
	## Which posture this set was released from, and why it was not the other
	## one. `reason` is diagnostic rather than narratable -- a rushed setter
	## should read as a setter with their feet on the floor, not as a caption --
	## but a jump set that never fires and a jump set that fires always look
	## identical without it, and one of those is the bug this replaces.
	if set_event != null:
		set_event.metadata["set_posture"] = "jump" if bool(jump_set.jumping) \
			else "standing"
		set_event.metadata["set_posture_reason"] = str(jump_set.reason)
		set_event.metadata["set_closing_speed_mps"] = float(
			jump_set.get("closing_speed_mps", 0.0)
		)
		set_event.metadata["set_release_height_meters"] = set_release_height
		set_event.metadata["set_pace_scale"] = _set_pace_scale(
			setter, bool(jump_set.jumping)
		)
		## Whether the ball went behind the setter. Orthogonal to the posture --
		## a back set can be jumped, stood or bumped -- and published beside it so
		## playback can draw the arch without re-deriving which way the setter was
		## facing from a ball that has already left.
		set_event.metadata["back_set"] = bool(set_geometry.back_set)
		set_event.metadata["behind_meters"] = float(set_geometry.behind_meters)
		set_event.metadata["tempo_coordination"] = home_tempo_timing.duplicate(true)
		set_event.metadata["tempo_relationship"] = str(
			home_tempo_timing.relationship
		)
		set_event.metadata["requested_tempo"] = int(assignment.tempo)
	if set_event != null and not home_transition_targets.is_empty():
		set_event.metadata["home_phase_targets"] = home_transition_targets
		set_event.metadata["home_phase_intents"] = home_transition_intents
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

	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	## Before preparation relocates it. The budget asks how far the hitter had to
	## come, and preparation's whole job is to move them -- reading `hitter_start`
	## afterwards would measure the distance they had left, not the distance they
	## faced.
	var hitter_standing_at := hitter_start
	var hitter_move_time := _movement_time(
		hitter, hitter_start, intended_hitter_body, "transition"
	)
	var hitter_arrival_margin := float(set_flight_time) - hitter_move_time
	var approach_preparation: Dictionary = {}
	var resolved_approach: Dictionary = {}
	var prepared_actor: RallyPlayerState = null
	var hitter_entry_velocity := Vector2.ZERO
	var hitter_full_approach_start := hitter_start
	var hitter_release_progress := 0.0
	var hitter_body_contact := intended_hitter_body
	var set_path_read: Dictionary = {}
	var set_path_contact: Dictionary = {}
	var hitter_movement_delay := float(home_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	if using_live_attack:
		hitter_start = Vector2(selected_live_attack.get(
			"source_position", hitter_start
		))
		hitter_release_progress = clampf(float(selected_live_attack.get(
			"achieved_release_progress",
			home_tempo_timing.get("release_progress", 0.0),
		)), 0.0, 1.0)
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
				## Before release this hitter knows the spot they requested, not
				## the setter's eventual delivery error.
				"target": intended_hitter_body,
			}
			approach_preparation = ApproachMechanicsModel.prepare_for_attack(
				attack_state, hitter_actor, assignment_data, receiver.id, rally_clock
			)
			prepared_actor = approach_preparation.get("actor") as RallyPlayerState
			approach_preparation.erase("actor")
			if prepared_actor != null:
				## The hitter owns the tempo. Preparation first gets them to the
				## runway; any time left before setter release is spent on the share
				## of the approach T1/T2 require. T3 deliberately spends none.
				hitter_full_approach_start = prepared_actor.position
				var ideal_mark := Vector2(approach_preparation.get(
					"approach_target_position", hitter_full_approach_start
				))
				var to_mark_seconds := _movement_time(
					hitter, hitter_standing_at, ideal_mark, "transition"
				)
				hitter_release_progress = ApproachMechanicsModel \
					.achieved_release_progress(
						home_tempo_timing,
						float(approach_preparation.get(
							"preparation_time_seconds", 0.0
						)),
						to_mark_seconds,
					)
	## Release belongs to the hitter. Once their actual footwork is known, the
	## setter recognises the time remaining in that individual approach and meets
	## it. The authored tempo survives as `requested_tempo`; it no longer causes a
	## ball whose hitter has not started to be labelled T2.
	home_tempo_timing = ApproachMechanicsModel.recognize_release_progress(
		home_tempo_timing, hitter_release_progress
	)
	var home_effective_tempo := ApproachMechanicsModel.achieved_tempo(
		home_tempo_timing, hitter_release_progress
	)
	if not using_live_attack:
		set_flight_time = float(home_tempo_timing.delivered_flight_seconds)
		set_arc = _retimed_set_arc(
			set_arc, set_flight_time, set_release_height,
			GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		)
	else:
		home_tempo_timing["delivered_flight_seconds"] = set_flight_time
	hitter_movement_delay = float(home_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	set_path_read = SetPathReadModelRef.evaluate(
		hitter, intended_set_target, set_target, set_flight_time,
		float(result.set_quality), _pair_fraction(setter.id, hitter.id),
		rally_seed, "home-first-%d" % swing_index, true,
	)
	var perceived_hitter_body := Vector2(set_path_read.get(
		"perceived_body_position", intended_hitter_body
	))
	var ideal_hitter_body := Vector2(set_path_read.get(
		"ideal_body_position",
		SetPathReadModelRef.body_position(hitter, set_target, true),
	))
	var contact_displacement := 0.0
	if not using_live_attack:
		if prepared_actor != null:
			resolved_approach = ApproachMechanicsModel.evaluate_takeoff(
				prepared_actor, perceived_hitter_body,
				float(home_tempo_timing.get(
					"runup_seconds", set_flight_time
				)),
			)
			hitter_start = ApproachMechanicsModel.release_position(
				hitter_full_approach_start, perceived_hitter_body,
				hitter_release_progress,
			)
			var approach_direction := (
				perceived_hitter_body - hitter_full_approach_start
			).normalized()
			var carried_speed := float(resolved_approach.get(
				"approach_speed_mps", 0.0
			)) * sqrt(hitter_release_progress)
			hitter_entry_velocity = approach_direction * carried_speed \
				if approach_direction.length_squared() > 0.0001 \
				else prepared_actor.velocity
			prepared_actor.apply_position(hitter_start, hitter_entry_velocity)
		var planned_hitter_leg := _travel(
			hitter, hitter_start, perceived_hitter_body, "transition", null,
			hitter_entry_velocity,
		)
		var planned_hitter_move_time := float(planned_hitter_leg.seconds)
		var hitter_contact_budget := maxf(
			float(set_flight_time) - hitter_movement_delay
				- float(home_tempo_timing.get(
					"takeoff_to_contact_seconds", 0.0
				)),
			0.0,
		)
		hitter_body_contact = _reachable_contact(
			hitter_start, perceived_hitter_body,
			planned_hitter_move_time, hitter_contact_budget,
		)
		hitter_arrival_margin = hitter_contact_budget \
			- planned_hitter_move_time
		contact_displacement = _clamp_displacement_meters(
			perceived_hitter_body, hitter_body_contact
		)
		var actual_hitter_leg := _travel(
			hitter, hitter_start, hitter_body_contact, "transition", null,
			hitter_entry_velocity,
		)
		hitter_move_time = float(actual_hitter_leg.seconds)
		live_velocities[hitter.id] = actual_hitter_leg.exit_velocity
		_commit_facing(hitter.id, actual_hitter_leg)
		if prepared_actor != null:
			resolved_approach = ApproachMechanicsModel.evaluate_takeoff(
				prepared_actor, hitter_body_contact, set_flight_time
			)
	else:
		hitter_body_contact = Vector2(selected_live_attack.get(
			"hitter_center_position", ideal_hitter_body
		))
	set_path_contact = SetPathReadModelRef.assess_contact(
		hitter, hitter_body_contact, ideal_hitter_body
	)
	var set_path_quality_multiplier := float(set_path_contact.get(
		"quality_multiplier", 1.0
	))
	var set_path_whiff := bool(set_path_contact.get("whiffed", false))
	home_tempo_timing["achieved_release_progress"] = hitter_release_progress
	home_tempo_timing["release_position"] = hitter_start
	home_tempo_timing["full_approach_start"] = hitter_full_approach_start
	home_tempo_timing["achieved_tempo"] = home_effective_tempo
	home_tempo_timing["achieved_relationship"] = \
		ApproachMechanicsModel.achieved_relationship(
			home_tempo_timing, hitter_release_progress
		)
	if home_effective_tempo <= 1:
		result.key_factors.append(_factor("fast_tempo"))
	## The set is a ball, not a favour the reachability clamp does for a late
	## hitter. It remains where the setter delivered it. The body stops where its
	## own budget and path read put it, and the gap is paid at contact above.
	_retarget_set_event(
		set_event, set_target, "set", float(set_flight_time),
		float(set_arc.apex_height_meters),
		set_contact_time,
		float(set_arc.get("release_height_meters", NAN)),
		float(set_arc.get("arrival_height_meters", NAN)),
	)
	if set_event != null:
		set_trajectory = Dictionary(
			set_event.metadata.get("outgoing_trajectory", set_trajectory)
		)
		set_event.detail = ("T%d set for %s · %d%% accuracy." % [
			home_effective_tempo, hitter.display_name,
			roundi(float(result.set_quality) * 100.0),
		]) + (" Called T%d; the setter matched the hitter's T%d rhythm." % [
			assignment.tempo, home_effective_tempo,
		] if int(assignment.tempo) != home_effective_tempo else "") \
			+ (" Emergency second-contact assignment activated."
				if emergency_setter else "") \
			+ (" Arrived %.2fs before contact." % setter_arrival_margin
				if setter_arrival_margin >= 0.0 else
				" Arrived %.2fs late; set control was reduced."
					% absf(setter_arrival_margin))
	## Read the run-up against the contact that will actually be struck. The
	## takeoff evaluation used to run inside the preparation branch above,
	## against the target the set aimed at; a clamped contact would then have
	## been scored on a runway nobody ran.
	if prepared_actor != null and resolved_approach.is_empty():
		resolved_approach = ApproachMechanicsModel.evaluate_takeoff(
			prepared_actor, hitter_body_contact, float(set_flight_time)
		)
	## Same staging leg as the setter's: the hitter should already be at
	## hitter_start (their staged approach mark) by the time this set's flight
	## finishes, not shown getting there and running the approach in one motion.
	var set_event_for_staging := result.events[-1] as RallyEvent
	if set_event_for_staging != null:
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
		var phase_targets: Dictionary = set_event_for_staging.metadata.get(
			"home_phase_targets", {}
		)
		phase_targets[hitter.id] = hitter_start
		set_event_for_staging.metadata["home_phase_targets"] = phase_targets
		var phase_intents: Dictionary = set_event_for_staging.metadata.get(
			"home_phase_intents", {}
		)
		phase_intents[hitter.id] = {
			"intent": &"preparing_attack", "progress": hitter_release_progress,
		}
		set_event_for_staging.metadata["home_phase_intents"] = phase_intents
		set_event_for_staging.metadata["tempo_coordination"] = \
			home_tempo_timing.duplicate(true)
		set_event_for_staging.metadata["tempo_relationship"] = str(
			home_tempo_timing.achieved_relationship
		)
		set_event_for_staging.metadata["achieved_tempo"] = int(
			home_tempo_timing.achieved_tempo
		)
		set_event_for_staging.metadata["set_path_read"] = \
			set_path_read.duplicate(true)
		set_event_for_staging.metadata["hitter_body_target"] = \
			perceived_hitter_body
	var approach_fit := _approach_execution_fit(hitter, resolved_approach)
	## The block this swing is actually hit into. Attack quality had no opposing
	## term at all: it summed roughly 1.5 of positive coefficients against
	## penalties that rarely reached 0.2, so it never fell below 0.310 against an
	## error threshold of 0.29 and the engine produced no attack errors. Hitting
	## into a sealed block is the risk that was missing, and the block's
	## formation is knowable before the contest is settled.
	var opponent_block_formation := _form_opponent_block(
		opponent_team, set_target.x, home_effective_tempo,
		float(result.set_quality), set_contact.x, set_flight_time,
		second_contact_window + release_interval, hitter, set_height_extra,
	)
	## Scouting sharpens a block that has already formed, so it belongs to the
	## formation. It used to be applied *after* the contest, with its own stuff
	## margin, its own close threshold and its own recycle rule -- a second copy
	## of the contest, on one side of the net only. Folding it into the
	## formation's quality leaves exactly one place a block outcome is decided.
	var block_adaptation := _opponent_block_adaptation_bonus(
		opponent_team, assignment.lane, home_effective_tempo
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
			set_height_extra,
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
	## And the ball they had to be spared to reach. See `CLAMPED_CONTACT_SEVERITY`.
	if contact_displacement > 0.0:
		result.attack_quality = clampf(
			float(result.attack_quality)
				- contact_displacement * CLAMPED_CONTACT_SEVERITY,
			0.0, 1.0,
		)
	## A read error is neither another setter-accuracy penalty nor a relocation of
	## the ball. It is the quality of the contact the hitter can make from the
	## body position they actually reached. A whiff therefore zeroes the swing;
	## a strained or off-axis contact continuously taxes it.
	result.attack_quality = clampf(
		float(result.attack_quality)
			* set_path_quality_multiplier,
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
			_approach_execution_fit(hitter, resolved_approach)
				* set_path_quality_multiplier,
			float(home_principles.decisiveness), 0.0,
			str(opponent_plan_for_wall.block_intent) \
				if opponent_plan_for_wall != null else "Balanced",
			hit_type,
		),
		"home",
	)
	shadow_reception_trace.summary = shadow_summary
	var geometric := _geometric_promotion(
		Dictionary(shadow_summary["geometric_attack"])
	)
	## The ball this hitter is actually standing under. It read the lane constant,
	## which was harmless while the lane *was* the target and is a different point
	## now that the hitter picks one and the setter misses it by some amount.
	var attack_choice := _choose_attack_target(
		hitter, set_target, hit_type, opponent_defenders,
	)
	if set_path_whiff:
		using_live_attack = false
	if using_live_attack:
		result.attack_quality = clampf(float(selected_live_attack.get(
			"quality", result.attack_quality
		)) * set_path_quality_multiplier, 0.0, 1.0)
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
	var attack_missed := set_path_whiff or _attack_missed(
		float(result.attack_quality), float(home_principles.decisiveness), hitter
	)
	if not geometric.is_empty():
		## A geometric swing is not aimed at a point and then scattered off it.
		## It is struck along a course at a speed and it lands where the ball
		## lands, so the error and the endpoint are the same fact and there is
		## nothing left for `_errant_attack_target` to invent. The lane's target
		## stays as `intended_attack_target`, which is what the record and the
		## opponent's read are actually about.
		attack_missed = set_path_whiff or bool(geometric.attack_missed)
		attack_target = Vector2(geometric.target)
	elif attack_missed:
		attack_target = _errant_attack_target(
			intended_attack_target, float(result.attack_quality)
		)
		## A promoted continuous attack describes the intended successful
		## contact. Once the official quality rules it an error, its persistent
		## endpoint cannot override the visible miss.
		using_live_attack = false
	if set_path_whiff:
		## No arm touched this ball. Keep it on the hitter's side and let it fall
		## past the mistimed takeoff instead of drawing a nominal spike into the
		## opponent court. The geometric wall timing is retained in metadata below:
		## blockers still react and jump to a swing cue that never arrives.
		attack_target = _missed_set_drop_target(set_target, true)
		using_live_attack = false
	## The portion before setter release was already run during the pass. The
	## incoming set therefore begins at the release position, not back at the
	## original runway mark (which made a nominal T2 visibly start after release).
	var approach_start := hitter_start
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
	var attack_spin := _swing_spin(
		hitter, Dictionary(shadow_summary.get("geometric_attack", {}))
	)
	var attack_arc := _swing_arc(
		Dictionary(shadow_summary.get("geometric_attack", {})),
		RallyKinematics.court_distance_meters(set_target, attack_target),
		GeometricAttackPromotionModel.contact_height_meters(
			hitter, float(resolved_approach.get("jump_multiplier", 1.0))
		),
		not geometric.is_empty()
			and attack_target.is_equal_approx(Vector2(geometric.target)),
		attack_spin,
	)
	var attack_flight := float(attack_arc.duration_seconds)
	var attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, attack_flight,
		float(attack_arc.apex_height_meters),
		rally_clock + set_flight_time,
		float(attack_arc.get("vertical_speed_mps", NAN)),
	)
	if set_path_whiff:
		attack_flight = MISSED_SET_DROP_SECONDS
		attack_trajectory = _missed_set_drop_trajectory(
			set_target, attack_target, rally_clock + set_flight_time
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
	var attack_detail := "Missed the delivered set entirely." if set_path_whiff \
		else "%s from %s at T%d · %d%% contact quality." % [
			hit_type, assignment.lane, home_effective_tempo,
			roundi(float(result.attack_quality) * 100.0),
		]
	attack_detail += " Arrived %.2fs before the ball." % hitter_arrival_margin \
		if hitter_arrival_margin >= 0.0 else \
		" Arrived %.2fs late and lost the approach window." \
			% absf(hitter_arrival_margin)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, result.attack_quality >= 0.25,
		result.attack_quality, "%s: %s" % [hitter.display_name, hit_type],
		attack_detail,
		{"side": "home", "lane": assignment.lane, "tempo": home_effective_tempo,
			"requested_tempo": int(assignment.tempo),
			"tempo_relationship": str(home_tempo_timing.achieved_relationship),
			"requested_tempo_relationship": str(home_tempo_timing.relationship),
			"achieved_tempo": int(home_tempo_timing.achieved_tempo),
			"tempo_coordination": home_tempo_timing.duplicate(true),
			## Step 2 of the tempo chain: what the set's flight gave this hitter
			## against what they needed. Published, not spent -- see
			## `_approach_budget`.
			"approach_budget": _approach_budget(
				hitter, hitter_standing_at, approach_preparation,
				perceived_hitter_body,
				float(set_flight_time), home_effective_tempo,
			),
			## Ball and body are separate coordinates. The ball remains at the
			## delivered set; movement and playback take the hitter to this point.
			"body_contact_position": hitter_body_contact,
			"ideal_body_contact_position": ideal_hitter_body,
			"perceived_body_contact_position": perceived_hitter_body,
			"set_path_read": set_path_read.duplicate(true),
			"set_path_contact": set_path_contact.duplicate(true),
			"set_path_outcome": str(set_path_contact.get("outcome", "clean")),
			"set_path_error_meters": float(set_path_contact.get(
				"error_meters", 0.0
			)),
			"set_path_whiff": set_path_whiff,
			"attack_type": hit_type, "attack_direction": attack_choice.direction,
			"intended_type": intended_hit_type,
			"swing_downgraded": swing_downgraded,
			"swing_deficit_terms": swing_deficit_terms,
			"swing_runup_quality": float(resolved_approach.get("runup_quality", 0.0)),
			"swing_in_system": bool(resolved_approach.get("approach_in_system", false)),
			"target_reason": attack_choice.reason,
			"intended_target": intended_attack_target,
			"geometric_outcome": str(geometric.get("outcome", "")),
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get("signature_actor_id", hitter.id)),
			"launch_cleared": bool(geometric.get("launch_cleared", true)),
			"launch_mode": str(geometric.get("launch_mode", "")),
			## The two quantities the block's outcome bands cut, on the event
			## rather than only in the shadow summary. `_geometric_swing_record`
			## is a developer surface nothing in production reads, so a band could
			## not be checked against its own distribution from a live rally --
			## which is how both of them came to be set without one.
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_deflection_landing": geometric.get("block_deflection_landing", null),
			"block_deflection_speed_mps": float(geometric.get("block_deflection_speed_mps", 0.0)),
			"block_deflection_playable": bool(geometric.get("block_deflection_playable", false)),
			"loft_apex_limited": bool(geometric.get("loft_apex_limited", false)),
			"net_distance_meters": float(geometric.get("net_distance_meters", 0.0)),
			"net_avoidance_demand": float(geometric.get("net_avoidance_demand", 0.0)),
			## How much of a wall this swing actually faced. `block_wall` drops any
			## blocker whose close fraction is under `WALL_JOIN_CLOSE`, so the size
			## of the wall is decided there and nowhere else -- and the resolver
			## reports "no wall" without saying who was dropped or how close they
			## were to arriving.
			"wall_size": int(geometric.get("wall_size", 0)),
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			## Absent rather than NaN when the wall was never touched.
			##
			## NaN is not equal to itself, so a metadata dictionary carrying one
			## can never compare equal to a byte-identical copy of itself -- which
			## broke the shadow-trace determinism check and the 2D court's trace
			## acceptance the moment these were added. Absence says "no contact"
			## more clearly than a sentinel does anyway.
			"block_depth_below_reach_meters": geometric.get(
				"block_depth_below_reach_meters", null
			),
			"block_edge_gap_meters": geometric.get("block_edge_gap_meters", null),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": attack_missed,
			"attack_effectiveness": attack_effectiveness,
			## What share of their ceiling the hitter swung at. The single channel
			## the bench's decisiveness reaches the ball through, on the event so a
			## probe can read its distribution from a live rally.
			"chosen_power_fraction": float(
				geometric.get("chosen_power_fraction", 0.0)
			),
			"movement_start": hitter_start,
			"approach_start_position": approach_start,
			"full_approach_start_position": hitter_full_approach_start,
			"movement_delay_seconds": hitter_movement_delay,
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
		"hitter_center_position", hitter_body_contact
	)) if using_live_attack else hitter_body_contact
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
		result.key_factors.append(_factor("opponent_adapted"))
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
	var hitter_point := bool(geometric.get("hitter_point", false))
	## A recycle comes back onto the hitter's half and belongs to attack coverage.
	## A geometric touch does the opposite: fingertips take pace off and send it
	## behind the wall, where the *blocking* side's floor defence plays it. These
	## were grouped together here even though `BlockDeflectionModel` gives them
	## opposite sides of the net; a failed home "coverage" attempt could therefore
	## award the opponent a stuff while the drawn ball landed in opponent court.
	var recycled := block_outcome == "recycle"
	var recycle_target := _attack_coverage_target(
		set_target, block_strength, geometric
	) if recycled else Vector2(set_target.x, 0.50)
	## Where the ball crossed, not where the hitter contacted it -- see
	## `_block_contact_point`. This is the swing's truncation and the
	## deflection's origin at once, so it is the §5 realised contact and both
	## legs have to meet at it.
	var net_contact := _block_contact_point(geometric, set_target.x, 0.50)
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
	var block_contacts_ball := blocked or recycled \
		or block_outcome in ["touch", "tool"]
	if block_contacts_ball:
		## Same shot as attack_trajectory above, re-sliced to where it actually
		## crosses the net rather than where it was originally headed -- same
		## launch angle, shorter distance, so duration/apex still fall out of
		## the geometry instead of being a separate hardcoded segment.
		var attack_to_block_arc := _truncated_arc(
			attack_arc,
			RallyKinematics.court_distance_meters(set_target, attack_target),
			RallyKinematics.court_distance_meters(set_target, net_contact),
		)
		attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, net_contact,
			float(attack_to_block_arc.duration_seconds),
			float(attack_to_block_arc.apex_height_meters),
			float(attack_event.metadata.get("event_time", rally_clock)),
			float(attack_to_block_arc.get("vertical_speed_mps", NAN)),
			float(attack_to_block_arc.get("swing_duration_seconds", NAN)),
			NAN, NAN,
			## The swing's own identity, carried through the re-slice. This is the
			## same launch met sooner, not a second ball built at the tape.
			str(attack_trajectory.get("authoritative_flight_id", "")),
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
	var opponent_floor_intents := {}
	var opponent_floor_stage := _establish_shape(
		_floor_phase_positions(
			opponent_team.current_lineup(), _opponent_defensive_plan(opponent_team),
			set_target.x,
			opponent_blocker.id if opponent_blocker != null else -1,
			assisting_blocker.id if assisting_blocker != null else -1,
			true, opponent_wall_x,
		),
		opponent_team.on_court_players(), opponent_live_positions,
		float(set_flight_time), opponent_floor_intents,
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
		## Two ideas in one map, so it is split rather than stamped: the two at
		## the net are blocking and everybody behind them is defending.
		var opponent_stage_intents := _uniform_intents(
			opponent_block_stage, &"defending"
		)
		## The four behind the wall took a real journey to get there, so their
		## uniform stamp is replaced by what the traversal actually cost them.
		## `_uniform_intents` stays for the two blockers, whose staging is the
		## block path's to describe.
		for raw_floor_id in opponent_floor_intents:
			opponent_stage_intents[int(raw_floor_id)] = \
				opponent_floor_intents[raw_floor_id]
		if opponent_blocker != null:
			opponent_stage_intents[opponent_blocker.id] = {
				"intent": &"blocking", "progress": 0.0,
			}
		if assisting_blocker != null:
			opponent_stage_intents[assisting_blocker.id] = {
				"intent": &"blocking", "progress": 0.0,
			}
		attack_event.metadata["opponent_phase_intents"] = opponent_stage_intents
	var post_block_target := recycle_target if recycled else attack_target
	if blocked:
		post_block_target = Vector2(set_target.x, 0.57)
	## Every geometric contact already owns its post-hand landing. Use it for the
	## event as well as the outgoing trajectory so the drawn ball, the next
	## defender and the resolver all begin from the same side of the net.
	if block_contacts_ball and not geometric.is_empty() \
			and geometric.get("block_deflection_landing", null) != null:
		post_block_target = Vector2(geometric.target)
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
		float(attack_arc.get("required_speed_mps", 0.0)), opponent_blocker,
		str(block_resolution.get("block_hands", "neutral")),
		attack_spin,
		Familiarity.read_modifier(
			opponent_blocker, [BallSpin.familiarity_tag(attack_spin)],
			float(opponent_team.scouting_confidence),
		),
		geometric.get("block_deflection_landing", null),
		float(geometric.get("block_deflection_speed_mps", 0.0)),
		float(geometric.get("block_deflection_vertical_angle_degrees", 0.0)),
		float(geometric.get("block_deflection_duration_seconds", 0.0)),
		bool(geometric.get("block_deflection_playable", false)),
	) if block_contacts_ball else {}
	## The trajectory builder applies the last physical effects (including spin),
	## so its endpoint supersedes every provisional target used to construct it.
	if block_contacts_ball and not opponent_block_trajectory.is_empty():
		post_block_target = _trajectory_endpoint(
			opponent_block_trajectory, post_block_target
		)
		if recycled:
			recycle_target = post_block_target
		elif block_outcome == "touch":
			attack_target = post_block_target
	## Last touch decides the point.  Sidespin is applied at the contact above,
	## after the geometric resolver's `stuff`/`touch` label was chosen.  If that
	## final, displayed endpoint is outside, the blocker's hands sent it there and
	## the attacking side wins regardless of the earlier label.
	if block_contacts_ball and _block_deflection_lands_out(opponent_block_trajectory):
		hitter_point = true
		block_outcome = "tool"
		blocked = false
		recycled = false
		post_block_target = _trajectory_endpoint(
			opponent_block_trajectory, post_block_target
		)
	## "Stuff" describes a ball pressed back onto the hitter's side. If the
	## completed trajectory instead rises behind the opponent wall, its geometry
	## is a playable touch and opponent floor defence owns the next contact.
	elif blocked and _block_deflection_lands_on_blocking_side(
		opponent_block_trajectory, "opponent"
	):
		block_outcome = "touch"
		blocked = false
		recycled = false
		post_block_target = _trajectory_endpoint(
			opponent_block_trajectory, post_block_target
		)
		attack_target = post_block_target
	## What this swing taught the hitter about where they were standing.  Wait
	## until the final deflection is known: an apparent stuff kicked out off the
	## hands is a successful placement, not a loss to teach them away from.
	var lost := blocked or bool(geometric.get("attack_missed", false))
	if hitter_point or lost:
		HitterPlacementModel.learn(
			hitter, assignment.lane, set_target, hitter_point
		)
	var opponent_block_segments: Array[Dictionary] = block_resolution.coverage_segments
	## The hand the ball met rather than the one that closed furthest. The
	## formation's primary still owns the wall -- the close percentages, the
	## coverage segments, the deflection -- and only the contact is attributed
	## to whoever `_block_contact` proved was in the ball's path.
	var contact_blocker := _block_contact_blocker(
		geometric, opponent_blocker, assisting_blocker
	)
	var opponent_blocker_id := contact_blocker.id if contact_blocker != null else -1
	var opponent_blocker_name := contact_blocker.display_name \
		if contact_blocker != null else "Open block"
	narration["opponent_blocker"] = opponent_blocker_name
	var home_cover_intents := {}
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker_id,
		opponent_blocker_name,
		_block_contact_point(geometric, set_target.x, 0.47),
		post_block_target, block_contacts_ball,
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane.%s" % [
			roundi(block_strength * 100.0),
			" Scouting anticipated this pattern." if adaptation_bonus >= 0.035 else "",
		], {"side": "opponent", "lane": assignment.lane,
			## The home side collapsing into cover behind their own hitter while
			## the spike is in the air. On the block event because that is the
			## contact this flight ends at.
			"home_phase_targets": _cover_phase_map(
				players, lineup, defensive_plan, hitter.id,
				set_target,
				float(Dictionary(attack_event.metadata.get(
					"outgoing_trajectory", {}
				)).get("duration", attack_flight)),
				false, home_cover_intents,
			),
			"home_phase_intents": home_cover_intents,
			"adaptation_bonus": adaptation_bonus, "outcome": block_outcome,
			## **What the wall was for, on the event that resolves it.**
			##
			## `block_intent` and `block_hands` are computed in `_contest_block`
			## and were being dropped at this seam -- measured at 0% and 65.4%
			## present across 246 block events. Without them a reader can only
			## see whether the ball got past, and "the ball got past" is not the
			## same question as "the block failed": a funnel that channels a
			## swing into a waiting digger did exactly what it meant to.
			"block_intent": str(block_resolution.get("block_intent", "Balanced")),
			"block_hands": str(block_resolution.get("block_hands", "neutral")),
			"block_hands_call": str(block_resolution.get("block_hands_call", "")),
			"block_hands_followed": bool(
				block_resolution.get("block_hands_followed", false)
			),
			## And *how* the wall was beaten, which the attack event already
			## carried and this one did not. Over the top is a reach problem and
			## around the edge is a read problem -- they want opposite fixes, and
			## only one of them is the blocker's misjudgement.
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			## Where the ball actually crossed the tape, which this event places
			## its contact at. Published on all three block sites so the two can
			## be checked against each other without re-running the resolver.
			"net_crossing_x": float(geometric.get("net_crossing_x", set_target.x)),
			## The intersection this contact *is* -- see `_block_contact_point`.
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_contact_actor_id": int(
				geometric.get("block_contact_actor_id", -1)
			),
			"block_contact_height_meters": geometric.get(
				"block_contact_height_meters", null
			),
			## And how high the ball was at the tape whether or not it was met,
			## so a beaten block is drawn where the ball went rather than where
			## the hands were.
			"ball_height_at_net_meters": geometric.get(
				"ball_height_at_net_meters", null
			),
			## The wall's reaches, beside the ball's height at the same moment.
			## Without both on one event "the ball cleared the hands" is not a
			## statement anything can check -- the reaches were on the ATTACK
			## event and the ball's height here, so a gate asserting the first
			## was reading an absent key and passing vacuously. Found by that
			## gate failing its own guard.
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			## The wall's primary and assist, which is what the event used to
			## credit. Published beside the contact so "the ball met a hand other
			## than the one that closed furthest" is a statement a reader can
			## check rather than a claim about code.
			"block_wall_primary_id": int(
				opponent_blocker.id if opponent_blocker != null else -1
			),
			"block_wall_assist_id": int(
				assisting_blocker.id if assisting_blocker != null else -1
			),
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get(
				"signature_actor_id", opponent_blocker_id
			)),
			"continuous_block": using_live_block,
			"deflection_target": post_block_target,
			"coverage_segments": opponent_block_segments,
			"primary_close": primary_close,
			"primary_close_terms": Dictionary(
				block_resolution.get("primary_close_terms", {})
			),
			"assist_close_terms": Dictionary(
				block_resolution.get("assist_close_terms", {})
			),
			"assist_close_attempted": float(
				block_resolution.get("assist_close_attempted", 0.0)
			),
			"preset_window_seconds": block_resolution.get("preset_window_seconds", 0.0),
			"preset_share": block_resolution.get("preset_share", 0.0),
			"set_flight_seconds": block_resolution.get("set_flight_seconds", 0.0),
			"block_tempo": block_resolution.get("tempo", -1),
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
	if hitter_point:
		## The other side chases the ball off their own hands before the point is
		## written down. See `_tool_pursuit_map`: they touched it, they have
		## touches left, and it is not out until it lands.
		if block_contacts_ball and opponent_team != null:
			var tool_intents := {}
			var tool_targets := _tool_pursuit_map(
				opponent_team.on_court_players(),
				opponent_team.current_lineup(),
				post_block_target,
				float(opponent_block_trajectory.get("duration", 0.30)),
				[
					opponent_blocker.id if opponent_blocker != null else -1,
					assisting_blocker.id if assisting_blocker != null else -1,
				],
				true, tool_intents,
			)
			var tool_event := result.events[-1] as RallyEvent
			if tool_event != null and not tool_targets.is_empty():
				tool_event.metadata["opponent_phase_targets"] = tool_targets
				tool_event.metadata["opponent_phase_intents"] = tool_intents
				## Reported rather than acted on, so whether a chase can ever save
				## the point gets decided from a distribution instead of a guess.
				tool_event.metadata["tool_pursuit_reached"] = float(
					tool_intents.values()[0]["progress"]
				)
		result.key_factors.append(_factor("attack_control"))
		## `EXPLANATIONS` has no bare `kill` -- only the called/improvised/default
		## triplet. Without this key the geometric hitter-point path fell through
		## to "The point was decided by the final contact." on every kill it
		## claimed, which is two of the four kill paths in the engine.
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": result.active_play_name,
		}, _kill_key(active_play, result))
	if blocked:
		result.key_factors.append(_factor("strong_block"))
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
			0.0,
			GeometricAttackPromotionModel.pass_contact_height_meters(coverer),
			_incoming_ball_direction(
				opponent_block_trajectory, recycle_target, attack_target
			),
		) if coverer != null else recycle_target
		var coverage_contact_state := _attack_coverage_contact_state(
			coverer, coverer_start, recycle_target,
			float(opponent_block_trajectory.get("duration", 0.24)),
		)
		if coverer != null:
			live_positions[coverer.id] = coverer_reach
		## Coverage happens when the blocked ball comes back down, which is the
		## end of the deflection's own arc. `rally_clock` here is still the set's
		## contact time -- earlier than the block itself -- so reading the
		## deflection's end is what stops the cover stamping before the touch it
		## covers.
		var coverage_contact_time := float(opponent_block_trajectory.get(
			"end_time", rally_clock + float(set_flight_time)
		))
		var home_coverage_second := _home_second_contact_candidates(players, lineup)
		var coverage_flight := _coverage_keep_alive_flight(
			coverer, recycle_target, opponent_block_trajectory,
			coverage_contact_state.get("arrival", {}),
			_platform_body_velocity(
				coverer_start, coverer_reach, coverer_move_time,
				float(opponent_block_trajectory.get("duration", 0.24)),
			),
			coverage_contact_time,
			home_coverage_second.candidates, home_coverage_second.starts,
			defensive_plan, lineup.active_setter_id(),
			defensive_plan.setter_release_target(lineup.active_setter_id()),
		)
		var coverage_pass_target := recycle_target + Vector2(0.04, -0.05)
		## `unset` recipient only on the legacy fabricated ball; the physical
		## keep-alive names the actor the second-contact policy chose. Either way
		## it is intent, never the endpoint.
		var coverage_intent: Dictionary = _platform_intent(
			"attack_coverage", coverage_pass_target, "contact_offset",
			null, coverage_pass_target,
		)
		var coverage_incoming := {}
		if not coverage_flight.is_empty():
			coverage_pass_target = Vector2(coverage_flight.destination)
			coverage_intent = coverage_flight.platform_intent
			coverage_incoming = coverage_flight.authoritative_free_flight
		var coverage_meta := {"side": "home", "coverage": "attack",
			"platform_intent": coverage_intent,
			"blocked_hitter_id": hitter.id,
			"movement_start": coverer_start,
			"movement_target": coverer_reach,
			"movement_duration": coverer_move_time,
			"arrival": coverage_contact_state.arrival,
			"contact_posture": coverage_contact_state.posture,
			"pass_contact_height_meters": coverage_contact_state.contact_height,
			"incoming_trajectory": opponent_block_trajectory,
			"event_time": coverage_contact_time}
		if not coverage_flight.is_empty():
			_merge_coverage_flight_metadata(coverage_meta, coverage_flight)
		_add_event(result, RallyEventModel.EventType.ATTACK_COVERAGE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Attack coverage",
			recycle_target, coverage_pass_target,
			coverage_success, coverage_quality,
			"%s covers the block touch" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% recycle control from the assigned attack-coverage shape." % roundi(
				coverage_quality * 100.0
			), coverage_meta)
		rally_clock = maxf(rally_clock, coverage_contact_time)
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		result.key_factors.append(_factor("attack_recycled"))
		## A ball that came off the block is not a clean one. The coverage
		## contact's own control is what the setter has to work with, and a
		## formed wall degrades it further -- which is the only channel a
		## blocker has to the result other than a stuff. When the physical path is
		## open the setter is now reached against the coverage ball's own flight;
		## the trailing arguments are the defaults otherwise, so the legacy call is
		## unchanged.
		return _resolve_home_continuation(
			result, players, lineup, coverer, coverage_pass_target,
			opponent_team, defensive_plan, 1,
			coverage_quality * lerpf(
				1.0, BLOCK_DEFLECTION_CARRY, clampf(block_strength, 0.0, 1.0)
			),
			float(coverage_flight.get("duration", 0.0)),
			float(opponent_block_trajectory.get("duration", 0.0)) \
				if not coverage_flight.is_empty() else 0.0,
			coverage_incoming,
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
	var visible_home_attack: Dictionary = attack_event.metadata.get(
		"outgoing_trajectory", attack_trajectory
	)
	## Once hands redirect the ball, the defender's post-touch chase owns only
	## that new flight. Crediting the hitter-to-block leg again let the resolver
	## call a 2.5 m chase reachable and playback then had to draw it in 0.22 s.
	var opponent_defense_time := maxf(float(
		opponent_block_trajectory.get("duration", 0.0)
	), BLOCK_DEFLECTION_MIN_SECONDS) \
		if not opponent_block_trajectory.is_empty() else float(
			visible_home_attack.get("duration", attack_flight)
		)
	var opponent_defense := _choose_opponent_defender(
		opponent_team, attack_target, opponent_defense_time,
		opponent_block_trajectory if not opponent_block_trajectory.is_empty()
			else visible_home_attack,
		attack_spin,
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
		read_modifier + floor_defense_bonus + opponent_posture_read
			+ _dig_read_bonus(opponent_defender, hitter, block_outcome),
		CoverageModel.reception_body_penalty(
			opponent_defender, Dictionary(opponent_defense.get("arrival", {})),
			attack_effectiveness,
		),
		int(opponent_defense.get("support_count", 0)),
	)
	## **The ball that actually arrives.** When the block got hands on it the
	## defender is playing the deflection, which is slower -- the same distinction
	## `opponent_defense_time` above already makes for the clock, made here for
	## the weight.
	## Published beside the pressure it is contested against, because a term
	## that decides a dig and cannot be read off the event is a term nobody can
	## attribute a dig to -- which is how three separate values on this branch
	## came to be spent invisibly.
	opponent_dig_terms["read_error_meters"] = float(
		Dictionary(opponent_defense.get("arrival", {})).get("read_error_meters", 0.0)
	)
	opponent_dig_terms["contested_against"] = _attack_pressure(
		attack_effectiveness,
		opponent_block_trajectory if not opponent_block_trajectory.is_empty()
			else attack_trajectory,
	)
	var defense_strength := float(opponent_dig_terms.quality)
	Familiarity.record_exposure(opponent_defender, read_tags)
	## Contested against the pressure the terms recorded, not the raw
	## effectiveness -- the two differ by the ball's pace, and handing the
	## contest one number while the record keeps another is how a term
	## comes to be published and never spent.
	var opponent_dig := _dig_outcome(
		opponent_defender, defense_strength,
		float(opponent_dig_terms.contested_against),
	)
	opponent_dig_terms["control"] = float(opponent_dig.control)
	opponent_dig_terms["edge"] = float(opponent_dig.edge)
	var dug: bool = bool(opponent_dig.dug)
	## What the setter behind this defender actually receives.
	var opponent_dig_control := float(opponent_dig.control)
	## A dig has a body cost too, and until now only a serve reception did -- so a
	## libero dug a swing off the floor and stood up unaffected, while the same
	## libero receiving a serve paid for it.
	var opponent_dig_recovery := _dig_recovery(
		opponent_defender, opponent_dig_terms, attack_effectiveness,
		opponent_block_trajectory if not opponent_block_trajectory.is_empty()
			else visible_home_attack,
		float(opponent_defense.distance_meters),
	)
	var opponent_pass_target := attack_target + Vector2(0.04, -0.03)
	## Intent names the release seat the setter is trying to reach. The legacy
	## pass below still aims at `opponent_pass_target`; publishing the honest
	## anchor must not smuggle a destination or trajectory change into slice 2.
	var opponent_dig_setter := opponent_team.setter() as VolleyballPlayer
	var opponent_dig_release := _opponent_setter_release_target(opponent_team)
	var opponent_dig_intent := _platform_intent(
		"controlled_dig", opponent_dig_release, "release_seat",
		opponent_dig_setter,
		Vector2(opponent_live_positions.get(
			opponent_dig_setter.id if opponent_dig_setter != null else -1,
			opponent_dig_release,
		)),
	)
	## When the ball actually reaches the defender, which is the end of the
	## swing's own arc. The transition that follows builds its second-contact
	## window from `rally_clock`, so the clock has to arrive here too -- left at
	## the set's contact time it would place the next set *before* this dig.
	var opponent_arriving_trajectory := opponent_block_trajectory \
		if not opponent_block_trajectory.is_empty() else visible_home_attack
	var opponent_dig_time := float(opponent_arriving_trajectory.get(
		"end_time", rally_clock + opponent_defense_time
	))
	var opponent_defender_reach := _reached_point(
		opponent_defender, Vector2(opponent_defense.start), attack_target,
		opponent_defense_time, "lateral",
		float(opponent_defense.get("read_error_meters", 0.0)),
		GeometricAttackPromotionModel.pass_contact_height_meters(opponent_defender),
		_incoming_ball_direction(
			opponent_arriving_trajectory, attack_target,
			Vector2(opponent_arriving_trajectory.get("start_position", attack_target)),
		),
	)
	## The ball that leaves this dig, resolved once, here. Only a successful dig
	## has an outgoing flight -- a defender who never controlled it did not pass
	## anything, and stamping a trajectory on a miss is exactly the event-truth
	## corruption that would make a beaten dig indistinguishable from a poor one.
	var opponent_dig_pass := {}
	if dug:
		opponent_dig_pass = _dig_pass_result(
			opponent_defender, attack_target, opponent_pass_target,
			opponent_dig_control,
			Dictionary(opponent_defense.get("arrival", {})),
			last_dig_posture, opponent_arriving_trajectory,
			float(opponent_defense.distance_meters),
			opponent_team.setter() as VolleyballPlayer, opponent_dig_time,
			_platform_body_velocity(
				Vector2(opponent_defense.start), opponent_defender_reach,
				float(opponent_defense.travel_time), opponent_defense_time,
			),
			opponent_dig_intent,
		)
		opponent_pass_target = Vector2(opponent_dig_pass.destination)
	## Where they actually ended up, not where the ball was. A defender who was
	## beaten to it starts the next phase short of it, which is the position the
	## rest of the rally should reason from.
	##
	## **Above the event, because the event reads it.** This sat below the
	## `_add_event` call, alone among the four floor-defence sites -- the home dig
	## and the transition dig both write the reach before appending. Nothing
	## between the two lines resolved anything, so the drift was invisible until
	## two published facts started reading `opponent_live_positions` at append
	## time: `body_contact_position` reported every opponent digger contacting
	## the ball from the spot they started at (13 of 13 diggers, mean travel to
	## the ball 1.97 m, mean travel to the published body 0.000 m), and
	## `opponent_phase_targets` below published a defensive shape in which the
	## digger had not moved while the caption said "after moving 1.8m".
	opponent_live_positions[opponent_defender.id] = opponent_defender_reach
	_add_event(result, RallyEventModel.EventType.DIG, opponent_defender.id,
		opponent_defender.display_name,
		attack_target, opponent_pass_target, dug,
		opponent_dig_control, "Defensive contact",
		"%s %s the %s attack after moving %.1fm.%s" % [
			opponent_defender.display_name, "controls" if dug else "cannot reach",
			str(attack_choice.direction), float(opponent_defense.distance_meters),
			" Scouting anticipated this lane." if floor_defense_bonus >= 0.035 else "",
		], {"side": "opponent", "dig_terms": opponent_dig_terms,
			"platform_intent": opponent_dig_intent,
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
			"incoming_trajectory": opponent_arriving_trajectory,
			## The shape this dig was claimed out of. The home dig event has
			## carried `home_phase_targets` all along and this one carried
			## nothing, so the two sides' defensive shapes could not be compared
			## -- only the distance each ended up covering, which is the result
			## rather than the reason. Without it the opponent's best-available
			## defender is unmeasurable and "their shape is worse" stays a guess.
			"opponent_phase_targets": opponent_live_positions.duplicate(true),
			"opponent_phase_intents": _uniform_intents(
				opponent_live_positions, &"defending"
			),
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
			"adaptation_bonus": floor_defense_bonus,
			## Published by the dig itself, so the ball the setter is resolved
			## against and the ball that gets drawn are the same object.
			"outgoing_trajectory": opponent_dig_pass.get("trajectory", {}),
			"pass_apex_meters": opponent_dig_pass.get("pass_apex_meters", 0.0),
			"pass_contact_height_meters": opponent_dig_pass.get(
				"pass_contact_height_meters", 0.0
			),
			"set_contact_height_meters": opponent_dig_pass.get(
				"set_contact_height_meters", 0.0
			),
			"pass_duration_seconds": opponent_dig_pass.get("duration", 0.0),
			"target_error_meters": opponent_dig_pass.get("target_error_meters", 0.0),
			"pass_spoil": opponent_dig_pass.get("spoil", 0.0),
			"platform_contact": opponent_dig_pass.get("platform_contact", {}),
		})
	_note_recovery(opponent_defender, opponent_dig_recovery, opponent_dig_time)
	rally_clock = maxf(rally_clock, opponent_dig_time)
	if dug:
		result.key_factors.append(_factor("strong_defense"))
		return _resolve_opponent_transition(
			result, players, lineup, hitter, opponent_pass_target,
			opponent_team, defensive_plan, 1, opponent_dig_control, false,
			opponent_defender.id,
			float(opponent_dig_pass.get("set_contact_height_meters", NAN)),
			float(opponent_dig_pass.get("pass_apex_meters", 0.0)),
			Dictionary(opponent_dig_pass.get("trajectory", {})),
			float(attack_trajectory.get("duration", 0.0)),
		)
	result.key_factors.append(_factor("attack_control"))
	return _finish(result, "kill", true, hitter.id, {
		"setter": setter.display_name,
		"hitter": hitter.display_name,
		"play": result.active_play_name,
	}, _kill_key(active_play, result))


func _resolve_home_serve(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
) -> Resource:
	var server := _best_home_server(players, lineup)
	if server != null:
		narration["server"] = server.display_name
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
	var target_name := str(
		defensive_plan.serve_target if defensive_plan != null else "Zone 5"
	)
	var serve_decision := _serve_decision("home", target_name, server, serve_risk)
	serve_risk = float(serve_decision.risk)
	var usable_serve_pace := _usable_serve_pace(server)
	var serve_quality := clampf(
		usable_serve_pace * 0.45
		+ _rating(server, "serve_placement") * 0.13
		+ _rating(server, "serve_consistency") * 0.14
		+ _serve_style_proficiency(server) * 0.13
		+ serve_risk * 0.15
		+ (float(home_principles.serve_aggression) - 0.5) * 0.14
		+ (0.06 if str(serve_decision.mode) == "aggressive" else -0.015)
		+ rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	## See the opponent serve: drawn to hold the RNG stream, and deciding nothing.
	var _retired_serve_error_draw := \
		rng.randf() < _serve_error_chance(server, serve_risk)
	var serve_aim := _serve_landing_point(
		str(serve_decision.target), server,
		opponent_team.players if opponent_team != null else [],
		opponent_team.current_lineup() if opponent_team != null else null,
		false,
		## The receiving side, which this call did not previously have in any
		## form -- it passed an empty roster and a null lineup, so a home serve
		## was aimed at one of four fixed dots with no idea who was under them.
		_receive_formation_positions(
			opponent_team.current_lineup(), opponent_team.players, true
		),
		CourtConstants.serve_origin(0.82, true),
		serve_decision,
	)
	var home_serve_origin := CourtConstants.serve_origin(0.82, true)
	## The same call the opponent makes, in the same order, off the same model.
	## Every asymmetry ever found in this engine was one side modelled fully and
	## the other as a parallel implementation, and the serve had two of them.
	var canonical_serve := _canonical_serve(
		"geometric_serve_home", server,
		home_serve_origin, serve_aim, true, serve_risk,
	)
	var opponent_landing: Vector2 = canonical_serve.get("landing", serve_aim)
	var serve_error := bool(canonical_serve.get("error", true))
	var serve_spin: Dictionary = canonical_serve.get("spin", _serve_spin(server))
	var serve_time := float(canonical_serve.get("duration_seconds", 1.0))
	## Named so the reception can carry it as its incoming ball, exactly as the
	## opponent-serve path already does.
	var serve_trajectory := _ball_trajectory(
		"serve", home_serve_origin, opponent_landing,
		serve_time, float(canonical_serve.get("apex_rise_meters", 0.0)),
		-1.0, NAN, NAN,
		float(canonical_serve.get("contact_height_meters", NAN)),
	)
	_stamp_launch_state(serve_trajectory, canonical_serve)
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
		], {"side": "home", "target": str(serve_decision.target),
			"called_target": target_name, "aim_point": serve_decision.aim_point,
			"serve_mode": serve_decision.mode,
			"changed_target": serve_decision.changed_target,
			"target_familiarity": serve_decision.target_familiarity,
			"target_radius_meters": serve_decision.target_radius_meters,
			"execution_accuracy": serve_decision.execution_accuracy,
			"flight_time": serve_time,
			"server_id": server.id, "server_slot": 1,
			"serve_style": server.primary_serve_style,
			"event_time": 0.0, "contact_time": serve_time,
			## See the opponent serve: what the ball did, from its own flight.
			"serve_out_reason": canonical_serve.get("out_reason", ""),
			"net_clearance_meters": canonical_serve.get(
				"net_clearance_meters", 0.0
			),
			"launch_speed_mps": serve_trajectory.get("launch_speed_mps", 0.0),
			"launch_angle_degrees": serve_trajectory.get(
				"launch_angle_degrees", 0.0
			),
			## Struck from behind the baseline, then onto the court over the
			## serve's own flight.
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
	var opponent_arrival: Dictionary = _read_adjusted_arrival(
		Dictionary(opponent_claim.get("arrival", {})),
		_read_error_meters(
			## The spin the launch search settled on. See the opponent's read.
			receiver, serve_trajectory, serve_spin,
			float(serve_trajectory.get("start_time", rally_clock)),
		),
	)
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
	var opponent_support_term := _support_term(
		support_count,
		float(opponent_claim.get("nearest_teammate_meters", 1000.0)),
	)
	var serve_receive_bonus := _opponent_serve_receive_adaptation_bonus(
		opponent_team, str(serve_decision.target)
	)
	## Quality describes execution; selected risk describes how much pace and
	## movement the serve attempts. Centre this at the legacy 0.50 call so the
	## Balanced calibration does not move merely because identities exist.
	var serve_risk_pressure := (serve_risk - 0.5) * 0.18 \
		+ (float(home_principles.serve_aggression) - 0.5) * 0.10
	var opponent_reception_base := _reception_skill(receiver) \
		if RallyFeatureFlagsModel.ENABLE_UNIFIED_RECEPTION_SKILL \
		else _rating(receiver, "reception") * 0.58 \
			+ _rating(receiver, "ball_control") * 0.24
	var opponent_body_penalty := CoverageModel.reception_body_penalty(
		receiver, opponent_arrival, serve_quality
	)
	var opponent_arrival_bonus := clampf(
		float(opponent_arrival.get("reach_margin_meters", -1.0)) * 0.07,
		-0.16, 0.12,
	)
	var opponent_reception_noise := rng.randf_range(-0.12, 0.12)
	var reception_quality := clampf(
		opponent_reception_base
		- serve_quality * 0.44
		- serve_risk_pressure
		- opponent_body_penalty
		+ opponent_arrival_bonus
		+ opponent_support_term
		+ serve_receive_bonus + opponent_reception_noise,
		0.0, 1.0,
	)
	if not receiver_arrived:
		reception_quality = minf(reception_quality, 0.12)
	result.reception_quality = reception_quality
	var reception_success := receiver_arrived \
		and reception_quality >= RECEPTION_PLAYABLE_FLOOR
	var opponent_receiver_reach := _reached_point(
		receiver, receiver_start, opponent_landing, serve_time, "lateral", 0.0,
		GeometricAttackPromotionModel.pass_contact_height_meters(receiver),
		_incoming_ball_direction(
			serve_trajectory, opponent_landing,
			CourtConstants.serve_origin(0.82, true),
		),
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
	var opponent_reception_setter := _opponent_setter(opponent_team)
	var opponent_reception_intent := _platform_intent(
		"serve_reception", opponent_setter_release, "release_seat",
		opponent_reception_setter,
		Vector2(opponent_live_positions.get(
			opponent_reception_setter.id if opponent_reception_setter != null else -1,
			opponent_setter_release,
		)),
	)
	var opponent_pass := _reception_pass_result(
		receiver, receiver_start, opponent_landing, opponent_setter_release,
		CourtConstants.serve_origin(0.82, true), serve_quality, opponent_arrival,
		reception_quality, 0.02, 0.49, serve_trajectory,
		_opponent_setter(opponent_team),
		opponent_reception_intent,
		_platform_body_velocity(
			receiver_start, opponent_receiver_reach, receiver_move_time, serve_time
		),
		float(serve_trajectory.get("end_time", rally_clock + serve_time)),
	)
	var opponent_pass_destination := Vector2(opponent_pass.destination)
	_note_recovery(receiver, str(opponent_pass.contact_recovery), rally_clock)
	var home_serve_intents := {}
	var home_by_id := {}
	for entry in players:
		var home_player := entry as VolleyballPlayer
		if home_player != null:
			home_by_id[home_player.id] = home_player
	var home_serve_transition := _serve_transition_map(
		lineup, defensive_plan, false, serve_time, home_by_id, home_serve_intents
	)
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		opponent_landing, opponent_pass_destination,
		reception_success,
		reception_quality, "%s receives" % receiver.display_name,
		"Opponent reception quality: %d%%. %s%s" % [
			roundi(reception_quality * 100.0),
			_arrival_phrase(opponent_arrival, receiver_arrived, support_count),
			" Scouting anticipated this target." if serve_receive_bonus >= 0.035 else "",
		], {"side": "opponent", "landing": opponent_landing,
			"platform_intent": opponent_reception_intent,
			## The other side's receive shape, on the same event and for the same
			## reason as the home one above.
			"opponent_phase_targets": _lineup_live_shape(
				opponent_team.current_lineup() if opponent_team != null else null,
				opponent_live_positions,
			),
			"opponent_phase_intents": receive_formation_intents,
			"home_phase_targets": home_serve_transition,
			"home_phase_intents": home_serve_intents,
			"flight_time": serve_time, "arrival": opponent_arrival,
			"reception_terms": {
				"base": opponent_reception_base,
				"serve_pressure": -serve_quality * 0.44,
				"risk_pressure": -serve_risk_pressure,
				"body_penalty": -opponent_body_penalty,
				"arrival_bonus": opponent_arrival_bonus,
				"support_bonus": opponent_support_term,
				"adaptation_bonus": serve_receive_bonus,
				"execution_noise": opponent_reception_noise,
				"unclamped_quality": opponent_reception_base
					- serve_quality * 0.44 - serve_risk_pressure
					- opponent_body_penalty + opponent_arrival_bonus
					+ opponent_support_term + serve_receive_bonus
					+ opponent_reception_noise,
				"final_quality": reception_quality,
				"success_threshold": RECEPTION_PLAYABLE_FLOOR,
				"receiver_arrived": receiver_arrived,
			},
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
			"pass_apex_meters": opponent_pass.get("pass_apex_meters", 0.0),
			"set_contact_height_meters": opponent_pass.get(
				"set_contact_height_meters", 0.0
			),
			"platform_feasibility": opponent_pass.platform_feasibility,
			"contact_posture": opponent_pass.contact_posture,
			"reach_margin_meters": opponent_pass.get("reach_margin_meters", 0.0),
			"contact_recovery": opponent_pass.contact_recovery,
			"contact_control": opponent_pass.get("contact_control", 0.5),
			"movement_alignment": opponent_pass.get("movement_alignment", 0.5),
			"incoming_force": opponent_pass.get("incoming_force", 0.0),
			"incoming_speed_mps": opponent_pass.get("incoming_speed_mps", 0.0),
			"setter_release_target": opponent_setter_release,
			"actual_pass_target": opponent_pass_destination})
	## The shared platform record, only when the physical reception launched one;
	## absent (and byte-neutral) on the legacy scatter.
	if opponent_pass.has("platform_contact"):
		(result.events[-1] as RallyEvent).metadata["platform_contact"] = \
			opponent_pass.platform_contact
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
		float(opponent_pass.get("set_contact_height_meters", NAN)),
		float(opponent_pass.get("pass_apex_meters", 0.0)),
		## **The pass this setter is actually taking.** Passed `{}` until now, so
		## `second_contact_window` fell through to the 0.68 literal and the
		## opponent's first-ball setter was timed against a constant while the
		## realized flight sat two lines above, already published on the
		## reception event as its `outgoing_trajectory`. The home first ball has
		## used `pass_trajectory.duration` since it existed; the dig callers into
		## this function already pass their own. This was the last feed on either
		## side still handing the second contact a number instead of a ball.
		Dictionary(opponent_pass.get("trajectory", {})),
		## The serve's own flight, which is exactly what the home first ball
		## passes. This side's setter has been running since the ball was struck
		## too, and until now was timed as though they had watched it land.
		serve_time,
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
	## How high the ball actually arrives at the setter's hands, when the contact
	## that fed them was modelled well enough to know. `_reception_pass_result`
	## has computed this from the pass's own apex under gravity since the bump
	## height work, and this path threw it away and re-drew the height from the
	## retired table instead -- so the one number that decides whether a setter
	## takes the ball standing, jumping, above their reach or off the platform
	## was, on this side of the net, a dice roll.
	##
	## NAN when the feeding contact has no height model, which today is every
	## dug ball on either side. The table stays as the fallback rather than
	## being deleted, because a dig genuinely has no apex yet.
	pass_contact_height_meters: float = NAN,
	## How high the ball this setter is taking actually got. The same question
	## the home side asks, and this side could not: without it the opponent
	## setter had no way to know whether the ball was worth leaving the floor
	## for, so every opponent set in the game was released standing.
	##
	## Zero means "no apex modelled", which is every dug ball on either side --
	## the same honest gap `pass_contact_height_meters` above already carries --
	## and a jump set is refused rather than guessed at.
	pass_apex_meters: float = 0.0,
	## **The actual ball, not a description of one.** Everything above is a
	## summary the caller extracted; this is the flight the feeding contact
	## published, and the setter is now reached against its own duration rather
	## than against `DEFAULT_SECOND_CONTACT_SECONDS`. Empty for the feeds that
	## still have no physical model -- see the fallback note at the window below.
	incoming_pass_trajectory: Dictionary = {},
	## **How long these volis have already been running when the pass is played**,
	## which on this side of the net was nothing at all.
	##
	## The home side has passed the feeding ball's own flight into
	## `_spatial_setter_choice` since that parameter existed -- the serve's for a
	## first ball, the swing's for a transition -- because a setter releases
	## toward their zone when the ball is *struck*, not when the platform touches
	## it. This path passed nothing, so every opponent second contact was timed
	## from a standing start.
	##
	## That was invisible while the designated setter's duty bonus was large
	## enough to win regardless. Once responsibility stopped being absolute the
	## two sides began answering identical physical situations differently: on a
	## stranded-setter fixture the home side kept the setter and the opponent
	## transferred the ball, with nothing between them but this argument. Gate
	## `HOME/OPPONENT SYMMETRY` in `tools/run_second_contact_probe.gd`.
	##
	## **Last in the list deliberately**, for the same reason
	## `incoming_pass_trajectory` above is: four callers pass this function
	## positionally, and inserting a parameter in the middle silently hands one
	## of them a float where a trajectory belongs.
	head_start_seconds: float = 0.0,
) -> Resource:
	var transition_penalty := float(exchange_number - 1) * 0.035
	## **How long the setter actually has.** This was the literal 0.68 that
	## `DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS` names, applied to every
	## continuation regardless of what the ball did -- so a floated dig and a
	## flat one gave the setter the same budget to reach the same point, and no
	## dig could ever make a setter late. A dug ball now states its own duration.
	var second_contact_window := float(incoming_pass_trajectory.get(
		"duration", DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS
	))
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
	var physical_choice := {}
	if str(incoming_pass_trajectory.get("trajectory_role", "")) \
			== "authoritative_free_flight":
		physical_choice = _physical_second_contact_choice(
			incoming_pass_trajectory,
			opponent_second_contact.candidates, opponent_second_contact.starts,
			opponent_plan_for_setter, int(opponent_team.setter_id),
			first_contact_player_id, opponent_setter, &"opponent",
			_opponent_setter_release_target(opponent_team),
			GeometricAttackPromotionModel.set_contact_height_meters(opponent_setter),
			head_start_seconds,
		)
		_stamp_free_flight_resolution(result, physical_choice)
		if physical_choice.get("player") == null:
			var terminal_reason := str(Dictionary(physical_choice.get(
				"terminal", {}
			)).get("reason", "unresolved"))
			if terminal_reason == "crossed_net_unresolved":
				## The opponent's ball crossed back: home makes the ordinary first
				## team contact. Falls through to the old terminal when the overpass
				## is not a control contact this checkpoint wires.
				var home_overpass := _resolve_overpass_into_home(
					result, incoming_pass_trajectory, players, lineup,
					opponent_team, defensive_plan, exchange_number, incoming_quality,
				)
				if home_overpass != null:
					return home_overpass
				return _finish(result, "m5_unresolved_overpass", true,
					first_contact_player_id, {})
			var home_attacker := _latest_attack_credit(result, "home")
			return _finish(
				result, "kill", true, int(home_attacker.id),
				{"hitter": str(home_attacker.name)},
			)
		opponent_setter_position = Vector2(physical_choice.contact_position)
		second_contact_window = float(physical_choice.contact_time) \
			- float(incoming_pass_trajectory.get("start_time", 0.0))
	var opponent_setter_choice := physical_choice \
		if not physical_choice.is_empty() \
		else _spatial_setter_choice(
			opponent_second_contact.candidates, opponent_second_contact.starts,
			opponent_plan_for_setter, int(opponent_team.setter_id),
			first_contact_player_id, opponent_setter,
			opponent_setter_position, second_contact_window,
			## The run these volis had already made. Zero until a caller supplies the
			## feeding ball's flight, which is today the serve-receive path only --
			## see the parameter's own note for which three callers still pass
			## nothing and why they were not changed on an unmeasured hunch.
			head_start_seconds,
		)
	if opponent_setter_choice.player != null:
		opponent_setter = opponent_setter_choice.player as VolleyballPlayer
	if opponent_setter == null:
		opponent_setter = opponent_team.setter() as VolleyballPlayer
	## **Consume the selection rather than rebuilding a second one.**
	##
	## These four values used to be reconstructed here from scratch: the start
	## re-read from `opponent_live_positions`, the route re-solved, the travel
	## re-timed on the `lateral` profile, and the margin measured against the
	## literal `DEFAULT_SECOND_CONTACT_SECONDS`. All four already existed on
	## `opponent_setter_choice`, computed from the state the voli was actually
	## selected on -- so the side effect was that selection and execution
	## described two different setters.
	##
	## Measured on one selection with both recipes applied to it: with the serve
	## flight as a head start the chooser had the setter standing **on** the ball
	## (0.000 m, margin +0.420 s) while this block had them 1.698 m away with a
	## margin of -0.287 s. Worse, that -0.287 was **identical at pass durations
	## of 0.42, 0.68, 0.95, 1.30 and 1.80 s**, because a constant cannot hear the
	## ball. The home side has measured the same quantity against
	## `second_contact_window` since it existed.
	##
	## The profile change from `lateral` to `transition` rides along and is not
	## cosmetic: it is the profile the chooser timed the decision on, so keeping
	## `lateral` here would be preserving the disagreement rather than the model.
	## An earlier note held the travel time back to avoid "a second change
	## wearing this one's name" -- correct then, when both recipes at least
	## started from the same position; the head start ended that.
	##
	## The fallbacks matter: `_spatial_setter_choice` can return a `player` that
	## is not `opponent_setter` after the two null-guards above, and consuming
	## another voli's run would be a worse error than rebuilding one. Guarded.
	var setter_choice_matches: bool = \
		opponent_setter_choice.get("player") == opponent_setter
	var setter_start: Vector2 = Vector2(opponent_setter_choice.start) \
		if setter_choice_matches \
		else Vector2(opponent_live_positions.get(
			opponent_setter.id,
			opponent_team.court_position(opponent_setter.id, "transition"),
		))
	var opponent_detour: Variant = opponent_setter_choice.get("navigation") \
		if setter_choice_matches \
		else _navigation_waypoint(
			opponent_setter, setter_start, opponent_setter_position,
			opponent_second_contact.starts,
		)
	## **A release is a run, so this leg is `transition`.**
	##
	## It was `lateral`, and it was the only setter movement in the engine that
	## was: `_spatial_setter_choice` -- the selector both sides and the shadow
	## systems go through -- resolves a release as `transition` at both of its
	## movement sites. This is the fallback taken when the second contact
	## transferred away from the designated setter, and what it computes is still
	## a *release*: the designated setter travelling from where they stand to the
	## setting position. Purpose decides the form, not distance. A setter opening
	## up and running to the ball is the same movement whether or not they end up
	## being the one who sets it.
	##
	## The policy's other half -- an established setter *adjusting* to a realized
	## pass is `lateral` -- has no site in the resolver today. There is one setter
	## movement, base to setting position. Recorded rather than given a site it
	## does not have. See `docs/review/HOME_WALL_FORMATION.md`.
	var setter_move_time: float = float(opponent_setter_choice.travel_time) \
		if setter_choice_matches \
		else _movement_time(
			opponent_setter, setter_start, opponent_setter_position, "transition",
			opponent_detour["corner"] if opponent_detour != null else null,
		)
	## The same quantity the home setter is scored on: how much of the pass
	## flight is left once they have reached the ball. A setter who arrives
	## early can load a jump set; one still scrambling takes it flat-footed --
	## and now, as on the home side, it is the realized pass that says how long
	## that flight was.
	var setter_arrival_margin := second_contact_window - setter_move_time
	var set_geometry := _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		Vector2(0.50, 0.48), Vector2(0.50, 0.48), 1.0,
	)
	## The other side's off-ball five, while their pass is in the air. Attached to
	## the SET event below for the same reason the home map is -- a leg's targets
	## live on the contact it flies toward.
	var opponent_transition_intents := {}
	var opponent_transition_targets := _opponent_transition_phase_map(
		opponent_team, first_contact_player_id, opponent_setter.id,
		## The realized pass's own flight, not the 0.68 literal. The other five
		## volis were being moved on a fixed budget while the ball they are
		## transitioning behind took whatever time it took.
		opponent_setter_position, second_contact_window,
		setter_arrival_margin, opponent_transition_intents,
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
	## Their bench's call, then their bench's identity on top of it -- the same
	## two steps the home side takes, in the same order. Without the second one
	## `tempo_variation` and `transition_commitment` were home-side attributes,
	## so a Spëddigh opponent ran Landavol's tempo.
	var opponent_tempo_call := _tempo_call(
		opponent_setter,
		clampi(
			int(opponent_team.tendencies.get("tempo", 2)) + _identity_tempo_shift(
				opponent_principles, incoming_quality, "opponent"
			), 0, 3,
		) if first_ball else TRANSITION_TEMPO_BASE,
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
	if physical_choice.has("contact_height_meters"):
		pass_contact_height_meters = float(physical_choice.contact_height_meters)
	var opponent_capability := SetterCapabilityModel.evaluate(
		opponent_setter, opponent_tempo_call, incoming_quality,
		pass_contact_height_meters if is_finite(pass_contact_height_meters) \
			else SetterCapabilityModel.pass_contact_height_meters(
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
	var estimated_set_flight_time: float = float(_set_arc(
		opponent_setter, opponent_tempo, opponent_set_quality,
		GeometricAttackPromotionModel.set_contact_height_meters(opponent_setter),
		## Against the setter's own reach rather than a hitter's, because who is
		## going to hit it is the question this estimate exists to answer. The real
		## flight is re-solved below against the hitter this picks.
		GeometricAttackPromotionModel.contact_height_meters(opponent_setter, 1.0),
		RallyKinematics.court_distance_meters(
			opponent_setter_position, Vector2(0.50, 0.48)
		),
	).duration_seconds)
	var attack_choice := _choose_opponent_attack(
		opponent_team, opponent_setter, opponent_set_quality,
		_home_target_hint(defensive_plan), estimated_set_flight_time,
	)
	var opponent_option_evaluation := Dictionary(attack_choice.get(
		"option_evaluation", {}
	)).duplicate(true)
	for internal_key in ["player", "start", "contact", "assignment"]:
		opponent_option_evaluation.erase(internal_key)
	var opponent_hitter := attack_choice.player as VolleyballPlayer
	## **This side's sets never missed.** The home set has scattered through
	## `_delivered_point` since delivery was modelled; the opponent's took
	## `attack_choice.contact` and landed on it exactly, every ball, so one
	## offence lived with a setter and the other with a machine. The same
	## asymmetry this file has now closed a dozen times, one path at a time.
	##
	## Applied before the reachability clamp below, deliberately: the setter
	## misses first and the hitter then has to get to wherever the ball actually
	## went, which is the order it happens in.
	var opponent_intended_contact: Vector2 = attack_choice.contact
	var opponent_intended_body := SetPathReadModelRef.body_position(
		opponent_hitter, opponent_intended_contact, false
	)
	var opponent_pair_familiarity := PairFamiliarityModel.BASELINE \
		/ PairFamiliarityModel.CEILING
	## **Per lane, not the general floor.** The first cut of this mirrored
	## `HOME_SET_DELIVERY_MIN_Y` and dropped `lane_delivery_min_y`, which exists
	## for exactly one reason: the pipe has an attack line to respect and the
	## pins do not. Six of 170 opponent back-row swings were struck in front of
	## the line -- the identical defect `court_constants.gd` records the home
	## side having, whose own note says a zone edge is not a legality guarantee
	## and the floor belongs on the delivered point.
	##
	## Mirrored about the net, so the home side's *minimum* y becomes this
	## side's *maximum*: further from the net is a smaller y on their half.
	## **Asked of the hitter's row, not the lane's name.** The first cut of this
	## read `lane_at_x`, and a lane cannot tell you this: the pipe is
	## distinguished by *depth*, so a centre-x ball reads as a quick whether it
	## sits at the net or behind the line. The floor stayed inert and the same
	## six of 170 back-row swings were struck in front of the line.
	##
	## The rule is about the body: a voli in a back-row slot must contact behind
	## their attack line wherever the ball is. `lane_delivery_min_y` already
	## encodes exactly that distance under the name "Pipe", which is the home
	## side's only back-row lane, so it is asked for it directly rather than
	## having the number restated here.
	var opponent_hitter_slot := int(opponent_team.current_lineup().slot_for_player(
		opponent_hitter.id
	)) if opponent_team.current_lineup() != null else -1
	var opponent_back_row := opponent_hitter_slot >= 1 \
		and not CourtConstants.is_front_row_slot(opponent_hitter_slot)
	var opponent_delivery_floor := CourtConstants.lane_delivery_min_y(
		"Pipe" if opponent_back_row else "Left Pin", HOME_SET_DELIVERY_MIN_Y
	)
	var opponent_contact: Vector2 = _delivered_point(
		opponent_intended_contact, opponent_set_quality,
		SET_DELIVERY_STDEV_WORST_M, SET_DELIVERY_STDEV_BEST_M,
		1.0 - HOME_SET_DELIVERY_MAX_Y, 1.0 - opponent_delivery_floor,
		RallyKinematics.court_distance_meters(
			opponent_setter_position, opponent_intended_contact
		),
		## **The whole climb, matching the other two paths.** This passed the
		## rescue height alone, so an ordinary opponent set reported a rise of
		## zero and paid nothing while an ordinary home set paid for its arc.
		##
		## The real arc is solved forty lines below, after the delivered point it
		## would need as an input, so the climb is estimated here against the
		## *intended* contact -- which is the right quantity anyway: a setter aims
		## at a height and the scatter is what they get, not the other way round.
		float(_set_arc(
			opponent_setter, opponent_tempo, opponent_set_quality,
			GeometricAttackPromotionModel.set_contact_height_meters(opponent_setter),
			GeometricAttackPromotionModel.contact_height_meters(opponent_hitter, 1.0),
			RallyKinematics.court_distance_meters(
				opponent_setter_position, opponent_intended_contact
			),
		).apex_height_meters) + float(attack_choice.get("rescue_height_meters", 0.0)),
	)
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
		opponent_contact, Vector2(0.50, 0.48), 1.0,
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
		opponent_contact, _opponent_setter_release_target(opponent_team), 1.0,
	)
	var opponent_set_height_extra := float(attack_choice.get(
		"rescue_height_meters", 0.0
	))
	var opponent_height_difficulty := _set_height_difficulty(
		opponent_setter, opponent_set_height_extra
	)
	var opponent_set_terms := _set_terms(
		opponent_setter, opponent_pass_quality, transition_penalty,
		opponent_capability_penalty, setter_arrival_margin,
		float(resolved_set_geometry.difficulty) + opponent_height_difficulty,
		(Familiarity.execution_modifier(opponent_setter) - 1.0) * 0.16,
	)
	opponent_set_terms["height_difficulty"] = opponent_height_difficulty
	opponent_set_terms["rescue_height_meters"] = opponent_set_height_extra
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
	## The same posture question the home side asks. This side released standing
	## on every ball in the game because nothing here ever passed `true`.
	var opponent_jump_set := _jump_set_decision(
		opponent_setter,
		pass_contact_height_meters if is_finite(pass_contact_height_meters) \
			else pass_apex_meters,
		setter_arrival_margin,
		RallyKinematics.court_distance_meters(
			Vector2(opponent_setter_choice.get("origin", setter_start)),
			opponent_setter_position,
		),
		float(opponent_setter_choice.get("total_travel_seconds", setter_move_time)),
	)
	if bool(physical_choice.get("requires_jump", false)):
		opponent_jump_set["jumping"] = true
		opponent_jump_set["reason"] = "required by physical interception"
	var opponent_release_height := pass_contact_height_meters \
		if not physical_choice.is_empty() \
		else GeometricAttackPromotionModel.set_contact_height_meters(
			opponent_setter, bool(opponent_jump_set.jumping)
		)
	var set_arc := _set_arc(
		opponent_setter, opponent_tempo, opponent_set_quality,
		opponent_release_height,
		GeometricAttackPromotionModel.contact_height_meters(opponent_hitter, 1.0),
		RallyKinematics.court_distance_meters(
			opponent_setter_position, opponent_contact
		),
		opponent_set_height_extra,
	)
	var opponent_natural_set_flight: float = float(set_arc.duration_seconds) \
		/ maxf(_set_pace_scale(opponent_setter, bool(opponent_jump_set.jumping)), 0.5)
	var opponent_tempo_timing := _hitter_led_set_timing(
		opponent_setter, opponent_hitter, opponent_tempo, opponent_lane,
		opponent_intended_contact, true, opponent_natural_set_flight,
		opponent_set_quality, opponent_principles,
		opponent_pair_familiarity,
		0.35, "opponent-%d" % exchange_number,
	)
	var set_flight_time := float(opponent_tempo_timing.delivered_flight_seconds)
	set_arc = _retimed_set_arc(
		set_arc, set_flight_time, opponent_release_height,
		GeometricAttackPromotionModel.contact_height_meters(opponent_hitter, 1.0),
	)
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
	## **The set begins where the setter actually touched the ball.**
	## `dig_position` is where the feeding contact was *aimed*; under a physical
	## interception `opponent_setter_position` is where a body actually met the
	## flight, and the two are different points. The event's own start position has
	## to be the second one, or the displayed contact, the published flight origin
	## and the setter's marker describe three different places. Identical to
	## `dig_position` on the legacy arm, where the setter is placed on the pass
	## destination by construction.
	_add_event(result, RallyEventModel.EventType.SET, opponent_setter.id,
		opponent_setter.display_name,
		opponent_setter_position, opponent_contact, true, opponent_set_quality,
		"Opponent transition set · exchange %d" % exchange_number,
		"Contact 2 of 3 · %d%% set quality." % roundi(opponent_set_quality * 100.0),
		{"side": "opponent",
			"set_path": "opponent_first_ball" if first_ball else "opponent_transition",
			"opponent_phase_targets": opponent_transition_targets,
			"opponent_phase_intents": opponent_transition_intents,
			"set_terms": opponent_set_terms,
			## The capability read this side has always computed and never
			## published, so the only path whose penalty could be decomposed was
			## the one that turned out not to have one.
			"setter_capability": opponent_capability.duplicate(true),
			"option_evaluation": opponent_option_evaluation,
			"setter_position": opponent_setter_position,
			"movement_start": setter_start, "movement_duration": setter_move_time,
			"body_contact_position": Vector2(physical_choice.get(
				"body_contact_position", opponent_setter_position
			)),
			"movement_entry_velocity": Vector2(physical_choice.get(
				"entry_velocity_mps", Vector2.ZERO
			)),
			## **Both were absent on this side and present on the other.**
			## `_stamp_second_contact_claim` deliberately leaves `arrival_margin`
			## to each call site because the live-setter override can move the
			## window after the choice was made -- and its note said every call
			## site stamps its own, which was true of the home paths and not of
			## this one. Measured: 0 of 310 opponent sets carried either key,
			## so no opponent second contact in the game could be audited for
			## how comfortably it arrived or for whether it was an emergency.
			"arrival_margin": setter_arrival_margin,
			"emergency_setter": opponent_setter.id != int(opponent_team.setter_id),
			"set_distance_meters": resolved_set_geometry.distance_meters,
			"set_angle_degrees": resolved_set_geometry.angle_degrees,
			"release_distance_meters": resolved_set_geometry.release_distance_meters,
			"body_orientation_fit": resolved_set_geometry.body_orientation_fit,
			"rescue_height_meters": opponent_set_height_extra,
			"height_difficulty": opponent_height_difficulty,
			"set_flight_time": set_flight_time,
			"event_time": opponent_set_contact_time,
			"outgoing_trajectory": _ball_trajectory(
				"opponent_set", opponent_setter_position, opponent_contact,
				set_flight_time, float(set_arc.apex_height_meters),
				opponent_set_contact_time, NAN, NAN,
				float(set_arc.get("release_height_meters", NAN)),
				float(set_arc.get("arrival_height_meters", NAN)),
			)})
	var opponent_set_event := result.events[-1] as RallyEvent
	_stamp_second_contact_claim(opponent_set_event, opponent_setter_choice)
	if opponent_set_event != null:
		opponent_set_event.metadata["set_posture"] = "jump" \
			if bool(opponent_jump_set.jumping) else "standing"
		opponent_set_event.metadata["set_posture_reason"] = str(
			opponent_jump_set.reason
		)
		opponent_set_event.metadata["set_closing_speed_mps"] = float(
			opponent_jump_set.get("closing_speed_mps", 0.0)
		)
		opponent_set_event.metadata["set_release_height_meters"] = \
			opponent_release_height
		## **The ball this set was resolved against.** Stamped so the chain from
		## a dig to its set can be proven by identity rather than by two
		## endpoints happening to be close. Empty for feeds that publish no
		## physical flight, which is what makes the remaining gaps countable.
		##
		## Under a physical interception the ball that reached this setter is the
		## **realised prefix**, not the full authoritative flight to the floor --
		## the very segment `_stamp_free_flight_resolution` wrote onto the feeding
		## contact as its outgoing ball. Report that same object here, so the
		## dig-to-set chain holds by identity and the setter's window is the
		## interception time it was actually resolved against, rather than the time
		## the untouched ball would have taken to land. Legacy and spatial feeds
		## carry no realised segment and fall through to the full flight unchanged.
		var opponent_set_incoming := Dictionary(
			opponent_setter_choice.get("realised_trajectory", {})
		)
		opponent_set_event.metadata["incoming_pass_trajectory"] = \
			opponent_set_incoming if not opponent_set_incoming.is_empty() \
			else incoming_pass_trajectory
		opponent_set_event.metadata["set_pace_scale"] = _set_pace_scale(
			opponent_setter, bool(opponent_jump_set.jumping)
		)
		opponent_set_event.metadata["back_set"] = bool(
			resolved_set_geometry.back_set
		)
		opponent_set_event.metadata["behind_meters"] = float(
			resolved_set_geometry.behind_meters
		)
		opponent_set_event.metadata["tempo_coordination"] = \
			opponent_tempo_timing.duplicate(true)
		opponent_set_event.metadata["tempo_relationship"] = str(
			opponent_tempo_timing.relationship
		)
		opponent_set_event.metadata["requested_tempo"] = opponent_tempo
		## Where they aimed, alongside where it went. The home set has published
		## both since delivery was modelled and this side published neither,
		## which is why nothing could measure an opponent setter's accuracy.
		opponent_set_event.metadata["intended_target"] = opponent_intended_contact
	_stamp_navigation(opponent_set_event, opponent_detour)
	opponent_live_positions[opponent_setter.id] = opponent_setter_position
	## This metadata is consumed while the incoming pass travels to the setter.
	## It may therefore contain a called/predicted commitment, but never the
	## hitter and lane selected later by the resolver.
	var pre_release_home_block := _pre_release_home_block_stage(
		players, lineup, defensive_plan, opponent_team
	)
	var pre_release_home_targets: Dictionary = pre_release_home_block.get(
		"targets", {}
	)
	if opponent_set_event != null:
		opponent_set_event.metadata["home_phase_targets"] = \
			pre_release_home_targets.duplicate(true)
		opponent_set_event.metadata["home_block_pre_release"] = Dictionary(
			pre_release_home_block.get("prediction", {})
		).duplicate(true)
	for raw_player_id in pre_release_home_targets:
		live_positions[int(raw_player_id)] = Vector2(
			pre_release_home_targets[raw_player_id]
		)
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
		opponent_hitter, opponent_set_height_extra,
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
	var home_block_read_tags: Array[String] = []
	var home_block_adaptation := 0.0
	var home_block_pressure := float(
		home_block_formation.get("primary_close", 0.0)
	) * BLOCK_PRIMARY_PRESSURE + float(
		home_block_formation.get("assist_close", 0.0)
	) * BLOCK_ASSIST_PRESSURE
	## Mirrors the home side's demand exactly: a faster tempo asks more of the
	## hitter, and a setter who commands tempo asks less of them.
	var opponent_tempo_demand := float(3 - clampi(opponent_tempo, 0, 3)) * 0.055 \
		* lerpf(
			1.0, 1.0 - ARM_SPEED_TEMPO_RELIEF,
			_rating(opponent_hitter, "arm_speed"),
		) \
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
			0.0, opponent_set_height_extra,
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
	_seed_carried_body_states(opponent_state, opponent_state.simulation_time)
	var opponent_hitter_actor := opponent_state.player_state(
		&"opponent", opponent_hitter.id
	)
	var opponent_standing_at := Vector2(attack_choice.start)
	if opponent_hitter_actor != null:
		opponent_hitter_actor.apply_position(
			opponent_standing_at,
			opponent_live_velocities.get(opponent_hitter.id, Vector2.ZERO),
		)
	var opponent_preparation := ApproachMechanicsModel.prepare_for_attack(
		opponent_state, opponent_hitter_actor,
		{
			"player_id": opponent_hitter.id,
			"lane": opponent_lane,
			"tempo": opponent_tempo,
			## Before release the hitter owns their requested spot. The delivered
			## miss is not authoritative movement information yet.
			"target": opponent_intended_body,
		},
		opponent_setter.id, opponent_set_contact_time, &"opponent",
	)
	var opponent_prepared := opponent_preparation.get("actor") as RallyPlayerState
	opponent_preparation.erase("actor")
	var opponent_approach_start := _approach_start_position(
		opponent_intended_body, Vector2(attack_choice.start), true
	)
	var opponent_full_approach_start := opponent_approach_start
	var opponent_release_progress := 0.0
	var opponent_entry_velocity := Vector2.ZERO
	var opponent_movement_delay := float(opponent_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	var opponent_approach: Dictionary = {}
	if opponent_prepared != null:
		opponent_full_approach_start = opponent_prepared.position
		var opponent_ideal_mark := Vector2(opponent_preparation.get(
			"approach_target_position", opponent_full_approach_start
		))
		var opponent_to_mark := _movement_time(
			opponent_hitter, opponent_standing_at, opponent_ideal_mark, "transition"
		)
		opponent_release_progress = ApproachMechanicsModel \
			.achieved_release_progress(
				opponent_tempo_timing,
				float(opponent_preparation.get("preparation_time_seconds", 0.0)),
				opponent_to_mark,
			)
	## Reclassify from the footwork that actually existed at release, then let
	## the setter meet the remaining time in that hitter's approach. This keeps a
	## visibly late-starting ball from retaining a tactical T2 label and clock.
	opponent_tempo_timing = ApproachMechanicsModel.recognize_release_progress(
		opponent_tempo_timing, opponent_release_progress
	)
	var opponent_effective_tempo := ApproachMechanicsModel.achieved_tempo(
		opponent_tempo_timing, opponent_release_progress
	)
	set_flight_time = float(opponent_tempo_timing.delivered_flight_seconds)
	set_arc = _retimed_set_arc(
		set_arc, set_flight_time, opponent_release_height,
		GeometricAttackPromotionModel.contact_height_meters(opponent_hitter, 1.0),
	)
	opponent_movement_delay = float(opponent_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	var opponent_set_path_read := SetPathReadModelRef.evaluate(
		opponent_hitter, opponent_intended_contact, opponent_contact,
		set_flight_time, opponent_set_quality, opponent_pair_familiarity,
		rally_seed, "opponent-%d" % exchange_number, false,
	)
	var opponent_perceived_body := Vector2(opponent_set_path_read.get(
		"perceived_body_position", opponent_intended_body
	))
	var opponent_ideal_body := Vector2(opponent_set_path_read.get(
		"ideal_body_position",
		SetPathReadModelRef.body_position(opponent_hitter, opponent_contact, false),
	))
	if opponent_prepared != null:
		opponent_approach = ApproachMechanicsModel.evaluate_takeoff(
			opponent_prepared, opponent_perceived_body,
			float(opponent_tempo_timing.get("runup_seconds", set_flight_time)),
		)
		opponent_approach_start = ApproachMechanicsModel.release_position(
			opponent_full_approach_start, opponent_perceived_body,
			opponent_release_progress,
		)
		var opponent_direction := (
			opponent_perceived_body - opponent_full_approach_start
		).normalized()
		var opponent_carried_speed := float(opponent_approach.get(
			"approach_speed_mps", 0.0
		)) * sqrt(opponent_release_progress)
		opponent_entry_velocity = opponent_direction * opponent_carried_speed \
			if opponent_direction.length_squared() > 0.0001 \
			else opponent_prepared.velocity
		opponent_prepared.apply_position(
			opponent_approach_start, opponent_entry_velocity
		)
	opponent_tempo_timing["achieved_release_progress"] = opponent_release_progress
	opponent_tempo_timing["release_position"] = opponent_approach_start
	opponent_tempo_timing["full_approach_start"] = opponent_full_approach_start
	opponent_tempo_timing["achieved_tempo"] = opponent_effective_tempo
	opponent_tempo_timing["achieved_relationship"] = \
		ApproachMechanicsModel.achieved_relationship(
			opponent_tempo_timing, opponent_release_progress
		)
	## The ball stays where the setter delivered it. The hitter commits to the
	## path they perceived and travels only as far as the clock permits.
	var opponent_planned_leg := _travel(
		opponent_hitter, opponent_approach_start, opponent_perceived_body,
		"transition", null, opponent_entry_velocity,
	)
	var opponent_planned_move_time := float(opponent_planned_leg.seconds)
	var opponent_contact_budget := maxf(
		set_flight_time - opponent_movement_delay
			- float(opponent_tempo_timing.get(
				"takeoff_to_contact_seconds", 0.0
			)),
		0.0,
	)
	var opponent_body_contact := _reachable_contact(
		opponent_approach_start, opponent_perceived_body,
		opponent_planned_move_time,
		opponent_contact_budget,
	)
	hitter_arrival_margin = opponent_contact_budget - opponent_planned_move_time
	var opponent_contact_displacement := _clamp_displacement_meters(
		opponent_perceived_body, opponent_body_contact
	)
	var opponent_leg := _travel(
		opponent_hitter, opponent_approach_start, opponent_body_contact,
		"transition", null, opponent_entry_velocity,
	)
	var opponent_move_time := float(opponent_leg.seconds)
	opponent_live_velocities[opponent_hitter.id] = opponent_leg.exit_velocity
	var opponent_set_path_contact := SetPathReadModelRef.assess_contact(
		opponent_hitter, opponent_body_contact, opponent_ideal_body
	)
	var opponent_path_quality_multiplier := float(
		opponent_set_path_contact.get("quality_multiplier", 1.0)
	)
	var opponent_set_path_whiff := bool(
		opponent_set_path_contact.get("whiffed", false)
	)
	if opponent_prepared != null:
		opponent_approach = ApproachMechanicsModel.evaluate_takeoff(
			opponent_prepared, opponent_body_contact, set_flight_time
		)
	## Release is the first point where the resolved lane may drive the wall.
	## Re-form from the pre-release prediction, using the achieved tempo and the
	## set clock the setter actually delivered. The ATTACK event below publishes
	## this target, so playback begins the close after the set cue rather than
	## during the incoming pass.
	home_block_formation = _form_home_block(
		players, lineup, defensive_plan, opponent_contact.x,
		opponent_effective_tempo, opponent_set_quality,
		opponent_setter_position.x, set_flight_time,
		opponent_second_contact_window + opponent_release_interval,
		opponent_hitter, opponent_set_height_extra,
		## The drift the pre-release call already applied. This is a re-formation
		## of the same wall with better information, not a second misread.
		Dictionary(home_block_formation.get("setter_pull", {})),
	)
	home_block_read_tags = [
		"attack:%s" % str(attack_choice.get("attack_type", "Attack"))
			.to_lower().replace(" ", "_"),
		"lane:%s" % opponent_lane.to_lower().replace(" ", "_"),
	]
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
	home_block_pressure = float(
		home_block_formation.get("primary_close", 0.0)
	) * BLOCK_PRIMARY_PRESSURE + float(
		home_block_formation.get("assist_close", 0.0)
	) * BLOCK_ASSIST_PRESSURE
	opponent_tempo_demand = float(
		3 - clampi(opponent_effective_tempo, 0, 3)
	) * 0.055 * lerpf(
		1.0, 1.0 - ARM_SPEED_TEMPO_RELIEF,
		_rating(opponent_hitter, "arm_speed"),
	) * lerpf(1.0, 0.65, _rating(opponent_setter, "tempo_control"))
	var home_wall_x := _wall_stage_x(
		opponent_hitter, opponent_contact, opponent_lane, false,
		float(home_block_formation.get("read_quality", 0.0)),
		str(defensive_plan.block_intent) if defensive_plan != null else "Balanced",
	)
	var home_wall_positions := _block_wall_positions(home_wall_x, false)
	var staged_home_primary := home_block_formation.get(
		"primary"
	) as VolleyballPlayer
	var staged_home_assist := home_block_formation.get(
		"assist"
	) as VolleyballPlayer
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
		float(set_arc.get("release_height_meters", NAN)),
		float(set_arc.get("arrival_height_meters", NAN)),
	)
	if opponent_set_event != null:
		opponent_set_event.metadata["set_flight_time"] = set_flight_time
		opponent_set_event.metadata["flight_time"] = set_flight_time
		opponent_set_event.metadata["set_path_read"] = \
			opponent_set_path_read.duplicate(true)
		opponent_set_event.metadata["hitter_body_target"] = \
			opponent_perceived_body
		opponent_set_event.metadata["tempo_coordination"] = \
			opponent_tempo_timing.duplicate(true)
		opponent_set_event.metadata["tempo_relationship"] = str(
			opponent_tempo_timing.achieved_relationship
		)
		opponent_set_event.metadata["achieved_tempo"] = opponent_effective_tempo
		opponent_set_event.detail = (
			"T%d set for %s · %d%% accuracy." % [
				opponent_effective_tempo, opponent_hitter.display_name,
				roundi(opponent_set_quality * 100.0),
			]
		) + (
			" Called T%d; the setter matched the hitter's T%d rhythm." % [
				opponent_tempo, opponent_effective_tempo,
			] if opponent_tempo != opponent_effective_tempo else ""
		)
	if opponent_prepared != null:
		opponent_approach = ApproachMechanicsModel.evaluate_takeoff(
			opponent_prepared, opponent_contact, set_flight_time
		)
	var opponent_attack_actions: Array[String] = \
		ApproachMechanicsModel.available_attack_families(
			opponent_hitter, opponent_approach, hitter_arrival_margin
		) if not opponent_approach.is_empty() else ([] as Array[String])
	## A run-up that never happened cannot lend its quality to the swing. This
	## is the same coupling Gate 43 gave the home side, and it now feeds the
	## same execution model rather than a bolt-on adjustment.
	var opponent_approach_fit := _approach_execution_fit(
		opponent_hitter, opponent_approach
	) if not opponent_approach.is_empty() else 0.5
	opponent_attack = clampf(
		_attack_execution(
			opponent_hitter, opponent_set_quality, opponent_approach_fit,
			hitter_arrival_margin, opponent_tempo_demand, home_block_pressure,
			## The same familiarity the home swing gets. Omitting it here was
			## worth nine kills to one once the attack started winning.
			Familiarity.attack_geometry(opponent_hitter, opponent_lane)
			+ (Familiarity.execution_modifier(opponent_hitter) - 1.0) * 0.14
			+ (float(opponent_approach.get("jump_multiplier", 1.0)) - 1.0) * 0.18,
			opponent_set_height_extra,
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
	## The same charge as the home swing's, so the clamp costs both sides the
	## same thing. Leaving it on one side is how the two halves of the net came
	## to be two different games in the first place.
	if opponent_contact_displacement > 0.0:
		opponent_attack = clampf(
			opponent_attack
				- opponent_contact_displacement * CLAMPED_CONTACT_SEVERITY,
			0.0, 1.0,
		)
	opponent_attack = clampf(
		opponent_attack * opponent_path_quality_multiplier, 0.0, 1.0
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
			(
				_approach_execution_fit(opponent_hitter, opponent_approach)
				if not opponent_approach.is_empty() else 0.5
			) * opponent_path_quality_multiplier,
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
			str(attack_choice.attack_type),
		),
		"opponent",
	)
	if shadow_reception_trace != null:
		shadow_reception_trace.summary["geometric_attack_opponent"] = opponent_record
	var geometric := _geometric_promotion(opponent_record)
	var opponent_attack_missed := opponent_set_path_whiff or (
		bool(geometric.get("attack_missed", false))
		if not geometric.is_empty() else
		_attack_missed(
			opponent_attack, float(opponent_principles.decisiveness), opponent_hitter
		)
	)
	if not geometric.is_empty():
		home_target = Vector2(geometric.target)
	if opponent_set_path_whiff:
		home_target = _missed_set_drop_target(opponent_contact, false)

	## Let playback walk the hitter to their approach mark during the set,
	## instead of teleporting them into a swing when the attack event begins.
	if opponent_set_event != null:
		opponent_set_event.metadata["staged_next_actor_id"] = opponent_hitter.id
		opponent_set_event.metadata["staged_next_position"] = opponent_approach_start
		var opponent_phase_targets: Dictionary = opponent_set_event.metadata.get(
			"opponent_phase_targets", {}
		)
		opponent_phase_targets[opponent_hitter.id] = opponent_approach_start
		opponent_set_event.metadata["opponent_phase_targets"] = \
			opponent_phase_targets
		var opponent_phase_intents: Dictionary = opponent_set_event.metadata.get(
			"opponent_phase_intents", {}
		)
		opponent_phase_intents[opponent_hitter.id] = {
			"intent": &"preparing_attack",
			"progress": opponent_release_progress,
		}
		opponent_set_event.metadata["opponent_phase_intents"] = \
			opponent_phase_intents
		opponent_set_event.metadata["tempo_coordination"] = \
			opponent_tempo_timing.duplicate(true)
		opponent_set_event.metadata["tempo_relationship"] = str(
			opponent_tempo_timing.achieved_relationship
		)
		opponent_set_event.metadata["achieved_tempo"] = int(
			opponent_tempo_timing.achieved_tempo
		)

	## The swing's shape is solved only now, so the run-up that just adjusted
	## `opponent_attack` also shapes the arc it produces.
	##
	## The net crossing, not the hitter's contact x. This point is the swing's
	## truncation *and* the deflection's origin, so it is the realised contact of
	## §5 and both legs have to meet at it. Placing it under the hitter put the
	## wall's contact wherever the hitter had been standing, which for any shot
	## that was not straight down the line is somewhere the ball never was.
	var opponent_net_contact := _block_contact_point(
		geometric, opponent_contact.x, 0.50
	)
	var opponent_attack_angle := _attack_launch_angle_degrees(
		opponent_hitter, str(attack_choice.attack_type), opponent_attack
	)
	## The full shot, to where it is actually aimed. `_contest_block()`
	## re-slices this to the net if the block touches it; truncating here
	## unconditionally made every opponent spike travel about three percent of
	## the court and the rest arrive as a "deflection".
	## **The record itself, not a copy fetched back out of the trace.**
	##
	## This read `_trace_summary()["geometric_attack_opponent"]` -- the same
	## dictionary, stored four lines above and retrieved here. Except the store is
	## conditional on `shadow_reception_trace`, and that is null on every path
	## that never built a trace, an opponent transition inside a home serve
	## foremost among them. On those rallies the retrieval came back empty, so the
	## swing lost its speed *and* its certified launch angle and was redrawn as a
	## generic driven spike.
	##
	## Measured by side, which is the split that found it: home swings carried the
	## angle on 15 of 16 lofts, opponent swings on 1 of 19 -- 18 lofted opponent
	## attacks drawn going *down* at a mean of -9 degrees, and 14 of them straight
	## into the net. `docs/BACKLOG.md`'s first failure mode, once more: a value
	## computed correctly and dropped before anything could use it.
	var opponent_attack_spin := _swing_spin(opponent_hitter, opponent_record)
	var opponent_attack_arc := _swing_arc(
		opponent_record,
		RallyKinematics.court_distance_meters(opponent_contact, home_target),
		GeometricAttackPromotionModel.contact_height_meters(
			opponent_hitter, 1.0
		),
		not geometric.is_empty()
			and home_target.is_equal_approx(Vector2(geometric.target)),
		opponent_attack_spin,
	)
	var opponent_attack_trajectory := _ball_trajectory(
		"attack", opponent_contact, home_target,
		float(opponent_attack_arc.duration_seconds),
		float(opponent_attack_arc.apex_height_meters),
		opponent_set_contact_time + set_flight_time,
		float(opponent_attack_arc.get("vertical_speed_mps", NAN)),
	)
	if opponent_set_path_whiff:
		opponent_attack_trajectory = _missed_set_drop_trajectory(
			opponent_contact, home_target,
			opponent_set_contact_time + set_flight_time,
		)
	var opponent_attack_detail := "Missed the delivered set entirely." \
		if opponent_set_path_whiff else \
		"Contact 3 of 3 · %s toward %s at %d%% quality." % [
			str(attack_choice.attack_type), str(attack_choice.direction),
			roundi(opponent_attack * 100.0),
		]
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id,
		opponent_hitter.display_name,
		opponent_contact, home_target,
		not opponent_attack_missed and opponent_attack >= 0.25, opponent_attack,
		"T%d opponent transition swing · exchange %d" % [
			opponent_effective_tempo, exchange_number,
		],
		opponent_attack_detail,
		{"side": "opponent", "lane_x": opponent_contact.x,
			"tempo": opponent_effective_tempo,
			"requested_tempo": opponent_tempo,
			"tempo_relationship": str(
				opponent_tempo_timing.achieved_relationship
			),
			"requested_tempo_relationship": str(
				opponent_tempo_timing.relationship
			),
			"achieved_tempo": int(opponent_tempo_timing.achieved_tempo),
			"tempo_coordination": opponent_tempo_timing.duplicate(true),
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
			"body_contact_position": opponent_body_contact,
			"ideal_body_contact_position": opponent_ideal_body,
			"perceived_body_contact_position": opponent_perceived_body,
			"set_path_read": opponent_set_path_read.duplicate(true),
			"set_path_contact": opponent_set_path_contact.duplicate(true),
			"set_path_outcome": str(opponent_set_path_contact.get(
				"outcome", "clean"
			)),
			"set_path_error_meters": float(opponent_set_path_contact.get(
				"error_meters", 0.0
			)),
			"set_path_whiff": opponent_set_path_whiff,
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
			"full_approach_start_position": opponent_full_approach_start,
			"movement_delay_seconds": opponent_movement_delay,
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
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get(
				"signature_actor_id", opponent_hitter.id
			)),
			"launch_cleared": bool(geometric.get("launch_cleared", true)),
			"launch_mode": str(geometric.get("launch_mode", "")),
			## The two quantities the block's outcome bands cut, on the event
			## rather than only in the shadow summary. `_geometric_swing_record`
			## is a developer surface nothing in production reads, so a band could
			## not be checked against its own distribution from a live rally --
			## which is how both of them came to be set without one.
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_deflection_landing": geometric.get("block_deflection_landing", null),
			"block_deflection_speed_mps": float(geometric.get("block_deflection_speed_mps", 0.0)),
			"block_deflection_playable": bool(geometric.get("block_deflection_playable", false)),
			## How much of a wall this swing actually faced. `block_wall` drops any
			## blocker whose close fraction is under `WALL_JOIN_CLOSE`, so the size
			## of the wall is decided there and nowhere else -- and the resolver
			## reports "no wall" without saying who was dropped or how close they
			## were to arriving.
			"wall_size": int(geometric.get("wall_size", 0)),
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			## **Answering the complaint immediately above.**
			##
			## `wall_size` says how many blockers joined; it does not say why the
			## others did not, and "nobody was assigned" wants the opposite fix from
			## "nobody arrived". The home wall reports no wall at all on roughly a
			## quarter of opponent swings while the opponent's wall never does, and
			## that asymmetry cannot be attributed from `wall_size` alone. These are
			## the formation's own terms, forwarded rather than recomputed, so they
			## cannot disagree with the wall that was actually built.
			"home_block_terms": {
				"front_blockers": int(home_block_formation.get("front_blocker_count", 0)),
				"primary_id": staged_home_primary.id if staged_home_primary != null else -1,
				"primary_close": float(home_block_formation.get("primary_close", 0.0)),
				"assist_close_attempted": float(home_block_formation.get(
					"assist_close_attempted", 0.0
				)),
				"primary_close_terms": Dictionary(home_block_formation.get(
					"primary_close_terms", {}
				)).duplicate(true),
				"read_quality": float(home_block_formation.get("read_quality", 0.0)),
				"preset_window_seconds": float(home_block_formation.get(
					"preset_window_seconds", 0.0
				)),
				"set_flight_seconds": float(home_block_formation.get(
					"set_flight_seconds", 0.0
				)),
			},
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			## Absent rather than NaN when the wall was never touched.
			##
			## NaN is not equal to itself, so a metadata dictionary carrying one
			## can never compare equal to a byte-identical copy of itself -- which
			## broke the shadow-trace determinism check and the 2D court's trace
			## acceptance the moment these were added. Absence says "no contact"
			## more clearly than a sentinel does anyway.
			"block_depth_below_reach_meters": geometric.get(
				"block_depth_below_reach_meters", null
			),
			"block_edge_gap_meters": geometric.get("block_edge_gap_meters", null),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": opponent_attack_missed,
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
			"movement_entry_velocity": opponent_entry_velocity,
			"outgoing_trajectory": opponent_attack_trajectory})
	## **The ball this swing was actually struck against.**
	##
	## Read straight off the SET event this path already published and retargeted,
	## so the identity is by construction rather than by two endpoints happening to
	## agree. The home first ball has carried it since it existed; this path and
	## the home continuation did not, so the one-ball chain could be audited on one
	## of the three attack paths and was silently unprovable on the other two.
	## Reporting only -- the swing was already resolved against `set_flight_time`
	## and this set's arc.
	var opponent_attack_event := result.events[-1] as RallyEvent
	if opponent_attack_event != null and opponent_set_event != null:
		opponent_attack_event.metadata["incoming_trajectory"] = Dictionary(
			opponent_set_event.metadata.get("outgoing_trajectory", {})
		)
	opponent_live_positions[opponent_hitter.id] = opponent_body_contact
	## The opponent could not miss a swing. Not "rarely" -- there was no branch
	## for it anywhere on this path, so every transition ball the opponent hit
	## either beat the block or was dug, and a home hitter who errs at the
	## sport's rate was being compared against an opponent who never errs at
	## all. That is the asymmetry the symmetry gate was written to find, and it
	## closes here because both sides now miss through the same ballistics.
	if opponent_attack_missed:
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
	var opponent_hitter_point := bool(geometric.get("hitter_point", false))
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
	## Under the hands, not under the hitter -- the mirror of the continuation
	## site's `block_event_end`.
	var home_block_target := Vector2(opponent_net_contact.x, 0.43) \
		if block_outcome == "stuff" else deflection_target
	## Same contract as the two home-attack block paths: only a block that
	## actually touches the ball shortens the shot or deflects it.
	var home_block_contacts := block_outcome in [
		"stuff", "touch", "tool", "recycle"
	]
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
		var to_block_arc := _truncated_arc(
			opponent_attack_arc,
			RallyKinematics.court_distance_meters(opponent_contact, home_target),
			RallyKinematics.court_distance_meters(
				opponent_start, opponent_net_contact
			),
		)
		opponent_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", opponent_start, opponent_net_contact,
			float(to_block_arc.duration_seconds),
			float(to_block_arc.apex_height_meters),
			float(opponent_flight.get("start_time", rally_clock)),
			float(to_block_arc.get("vertical_speed_mps", NAN)),
			float(to_block_arc.get("swing_duration_seconds", NAN)),
			NAN, NAN,
			## Same rule as the home side's re-slice: a prefix keeps the launch it
			## is a prefix of.
			str(opponent_flight.get("authoritative_flight_id", "")),
		)
	## **The swing the wall actually met, re-read after the truncation above.**
	##
	## The block event used to publish `opponent_attack_trajectory` -- the local
	## captured *before* that re-slice -- as both its incoming ball and the source
	## of its own timestamp. So on every home block that touched the ball, the
	## wall was recorded intersecting an arc the attack no longer had: measured at
	## 100 of 100 touching home blocks against 0 of 113 on the opponent side,
	## which is the tell that this is one path drifting from its twin rather than
	## a shared rule being wrong.
	##
	## The timestamp came with it. `_contact_time` is the flight's `end_time`, and
	## on an *untruncated* swing that is the moment the ball reaches the floor
	## behind the blockers -- so the hands were being stamped up to 1.140 s after
	## the ball they were supposedly touching had landed. `_swing_reaches_net`
	## exists for exactly this and its own note says why: reception, set and dig
	## happen when a flight finishes, a block happens partway through one.
	##
	## Read through the event rather than kept in a second local, because the
	## event's metadata *is* the published ball and a local copy is how the two
	## came apart in the first place.
	var opponent_swing_flight: Dictionary = opponent_attack_trajectory
	if opponent_attack_event != null:
		opponent_swing_flight = Dictionary(opponent_attack_event.metadata.get(
			"outgoing_trajectory", opponent_attack_trajectory
		))
	## Same correction as the home block's: the ball has to arrive before the
	## hands can touch it.
	var home_block_trajectory := _block_deflection_trajectory(
		opponent_net_contact, home_block_target, block_outcome == "stuff", 0.42,
		_swing_reaches_net(
			opponent_attack_trajectory, opponent_set_contact_time + set_flight_time
		),
		float(opponent_attack_arc.get("required_speed_mps", 0.0)), blocker,
		str(block_result.get("block_hands", "neutral")),
		opponent_attack_spin,
		## No confidence argument, matching the home side's other read at
		## `home_block_read_tags`: `scouting_confidence` is a field the opponent
		## team resource carries and the home one does not. That asymmetry is
		## real and predates this -- noted rather than papered over with a zero,
		## which would have read as "the home side has scouted nothing".
		Familiarity.read_modifier(
			blocker, [BallSpin.familiarity_tag(opponent_attack_spin)]
		),
		geometric.get("block_deflection_landing", null),
		float(geometric.get("block_deflection_speed_mps", 0.0)),
		float(geometric.get("block_deflection_vertical_angle_degrees", 0.0)),
		float(geometric.get("block_deflection_duration_seconds", 0.0)),
		bool(geometric.get("block_deflection_playable", false)),
	) if home_block_contacts else {}
	if home_block_contacts and not home_block_trajectory.is_empty():
		home_block_target = _trajectory_endpoint(
			home_block_trajectory, home_block_target
		)
		deflection_target = home_block_target
	if home_block_contacts and _block_deflection_lands_out(home_block_trajectory):
		opponent_hitter_point = true
		block_outcome = "tool"
		home_block_target = _trajectory_endpoint(
			home_block_trajectory, home_block_target
		)
		deflection_target = home_block_target
	elif block_outcome == "stuff" and _block_deflection_lands_on_blocking_side(
		home_block_trajectory, "home"
	):
		block_outcome = "touch"
		home_block_target = _trajectory_endpoint(
			home_block_trajectory, home_block_target
		)
		deflection_target = home_block_target
	var assist_text := ""
	if assisting_blocker != null:
		assist_text = " %s assisted at %d%% close." % [
			assisting_blocker.display_name,
			roundi(float(block_result.assist_close) * 100.0),
		]
	var blocker_id := blocker.id if blocker != null else -1
	var assisting_blocker_id := assisting_blocker.id \
		if assisting_blocker != null else -1
	## The hand the ball met, which is not always the hand that closed furthest.
	##
	## Kept apart from `blocker_id` deliberately: that one is the formation's
	## primary and is what excludes both bodies from the floor shape below, so
	## re-attributing it would put whichever blocker did not touch the ball into
	## a defensive position while they were still at the tape. The wall that
	## formed and the hand inside it that met the ball are two facts, and only
	## the second belongs on the contact.
	var contact_blocker := _block_contact_blocker(
		geometric, blocker, assisting_blocker
	)
	var home_floor_intents := {}
	var floor_phase_positions := _establish_shape(
		_home_floor_phase_positions(
			lineup, defensive_plan, opponent_contact.x,
			blocker_id, assisting_blocker_id, home_wall_x,
		),
		players, live_positions, float(set_flight_time), home_floor_intents,
	)
	for raw_player_id in floor_phase_positions:
		live_positions[int(raw_player_id)] = Vector2(
			floor_phase_positions[raw_player_id]
		)
	if opponent_attack_event != null:
		opponent_attack_event.metadata["home_phase_intents"] = \
			_defensive_intents(floor_phase_positions, home_floor_intents)
		opponent_attack_event.metadata["home_phase_targets"] = \
			floor_phase_positions.duplicate(true)
	var blocker_name := contact_blocker.display_name if contact_blocker != null \
		else "No assigned blocker"
	narration["blocker"] = blocker_name
	var opponent_cover_intents := {}
	_add_event(result, RallyEventModel.EventType.BLOCK,
		contact_blocker.id if contact_blocker != null else -1, blocker_name,
		## The proven crossing at the tape, a hair onto the blocking side. Same
		## point as `opponent_net_contact` above, which is where the swing was
		## truncated and where the deflection leaves from -- one contact, both
		## legs meeting at it.
		_block_contact_point(geometric, opponent_contact.x, 0.53),
		home_block_target,
		home_block_contacts, home_block,
		"%s · %s" % [blocker_name, block_outcome.capitalize()],
		"Primary close %d%%; block quality %d%%.%s" % [
			roundi(float(block_result.primary_close) * 100.0),
			roundi(home_block * 100.0), assist_text,
		], {"side": "home", "outcome": block_outcome,
			## And the opposite side's cover, mirrored -- the opponent collapsing
			## behind their own hitter while their spike is in the air.
			"opponent_phase_targets": _cover_phase_map(
				opponent_team.on_court_players(),
				opponent_team.current_lineup(),
				_opponent_defensive_plan(opponent_team),
				opponent_hitter.id if opponent_hitter != null else -1,
				opponent_contact,
				float(Dictionary(opponent_attack_event.metadata.get(
					"outgoing_trajectory", {}
				)).get(
					"duration",
					float(opponent_attack_trajectory.get("duration", 0.30)),
				)) if opponent_attack_event != null else float(
					opponent_attack_trajectory.get("duration", 0.30)
				),
				true, opponent_cover_intents,
			),
			"opponent_phase_intents": opponent_cover_intents,
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get("signature_actor_id", blocker_id)),
			"block_hands": str(block_result.get("block_hands", "neutral")),
			"block_hands_call": str(block_result.get("block_hands_call", "")),
			"block_hands_followed": bool(
				block_result.get("block_hands_followed", false)
			),
			## Alongside the hands, and for the same reason -- see the note on the
			## opponent block above. The plan's intent is what separates a funnel
			## that funnelled from a seal that was beaten.
			"block_intent": str(block_result.get("block_intent", "Balanced")),
			"contest_margin": float(block_result.get("contest_margin", 0.0)),
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			"net_height_over_block_meters": float(
				geometric.get("net_height_over_block_meters", 0.0)
			),
			"block_edge_miss_meters": float(
				geometric.get("block_edge_miss_meters", 0.0)
			),
			"net_crossing_x": float(geometric.get("net_crossing_x", 0.5)),
			## The intersection this contact *is*, published alongside the actor
			## and position built from it so the agreement is checkable from the
			## event rather than by re-running the resolver. `_block_contact`
			## proves all three; until now none of them left it.
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_contact_actor_id": int(
				geometric.get("block_contact_actor_id", -1)
			),
			"block_contact_height_meters": geometric.get(
				"block_contact_height_meters", null
			),
			## And how high the ball was at the tape whether or not it was met,
			## so a beaten block is drawn where the ball went rather than where
			## the hands were.
			"ball_height_at_net_meters": geometric.get(
				"ball_height_at_net_meters", null
			),
			## The wall's reaches, beside the ball's height at the same moment.
			## Without both on one event "the ball cleared the hands" is not a
			## statement anything can check -- the reaches were on the ATTACK
			## event and the ball's height here, so a gate asserting the first
			## was reading an absent key and passing vacuously. Found by that
			## gate failing its own guard.
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			## The wall's own two, beside the hand that met the ball -- see the
			## note at the first-ball block site.
			"block_wall_primary_id": blocker_id,
			"block_wall_assist_id": assisting_blocker_id,
			"adaptation_bonus": home_block_adaptation,
			"home_phase_targets": floor_phase_positions.duplicate(true),
			"home_phase_intents": _defensive_intents(
				floor_phase_positions, home_floor_intents
			),
			"primary_close": block_result.primary_close,
			"primary_close_terms": Dictionary(
				block_result.get("primary_close_terms", {})
			),
			"assist_close_terms": Dictionary(
				block_result.get("assist_close_terms", {})
			),
			"assist_close_attempted": float(
				block_result.get("assist_close_attempted", 0.0)
			),
			"preset_window_seconds": block_result.get("preset_window_seconds", 0.0),
			"preset_share": block_result.get("preset_share", 0.0),
			"set_flight_seconds": block_result.get("set_flight_seconds", 0.0),
			"block_tempo": block_result.get("tempo", -1),
			"assist_close": block_result.assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"primary_position": Vector2(home_wall_positions.primary_position),
			"assist_position": Vector2(home_wall_positions.assist_position),
			"deflection_target": deflection_target,
			"coverage_segments": block_result.coverage_segments,
			"setter_pull": block_result.setter_pull,
			"read_quality": block_result.read_quality,
			"opponent_setter_position": opponent_setter_position,
			"event_time": _swing_reaches_net(opponent_swing_flight, rally_clock),
			"incoming_trajectory": opponent_swing_flight,
			"outgoing_trajectory": home_block_trajectory})
	## The home blockers are in the air. Registered before the floor-defence
	## claim below reads `_recovery_time_penalties`, so a blocker who has just
	## jumped is not offered the next ball as a standing body.
	_note_block_airborne(
		Dictionary(geometric.get("block_jump_timing", {})),
		[blocker, assisting_blocker],
		_contact_time(opponent_attack_trajectory, rally_clock),
	)
	## The mirror of the home side's net-decided point: through the hands, off
	## them and out, or placed off them on purpose. Claimed before the touch and
	## funnel branches, which would otherwise hand the ball back to a home
	## defender who is not going to get it.
	if opponent_hitter_point:
		## Mirrored from the home first-ball path. Our hands sent it out, so it is
		## our touch and our chase.
		if home_block_contacts:
			var home_tool_intents := {}
			var home_tool_targets := _tool_pursuit_map(
				players, lineup, home_block_target,
				float(home_block_trajectory.get("duration", 0.30)),
				[blocker_id, int(block_result.get("assist_id", -1))],
				false, home_tool_intents,
			)
			var home_tool_event := result.events[-1] as RallyEvent
			if home_tool_event != null and not home_tool_targets.is_empty():
				home_tool_event.metadata["home_phase_targets"] = home_tool_targets
				home_tool_event.metadata["home_phase_intents"] = home_tool_intents
				home_tool_event.metadata["tool_pursuit_reached"] = float(
					home_tool_intents.values()[0]["progress"]
				)
		return _finish(result, "opponent_kill", false, -1, {
			"hitter": original_hitter.display_name,
		})
	if block_outcome == "stuff":
		return _finish(result, "counter_block", true, blocker_id, {
			"hitter": original_hitter.display_name,
			"blocker": blocker_name,
		})
	if block_outcome == "recycle":
		## A rebound onto the opponent's own court belongs to their attack
		## coverage, not to our floor defence. The old fall-through assigned the
		## endpoint on their half to a home digger, which is the same side/last-
		## touch mismatch that originally mis-scored the reported soft block.
		var opponent_coverage_plan := _opponent_defensive_plan(opponent_team)
		var coverage_result := _resolve_attack_coverage(
			opponent_team.on_court_players(), opponent_team.current_lineup(),
			opponent_coverage_plan, opponent_hitter, home_block_target,
			home_block, true,
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
		var coverer_start: Vector2 = opponent_live_positions.get(
			coverer.id, home_block_target
		) if coverer != null else home_block_target
		var coverage_time := float(home_block_trajectory.get("duration", 0.24))
		var coverer_move_time := _movement_time(
			coverer, coverer_start, home_block_target, "lateral"
		) if coverer != null else 4.0
		var coverer_reach := _reached_point(
			coverer, coverer_start, home_block_target, coverage_time, "lateral",
			0.0,
			GeometricAttackPromotionModel.pass_contact_height_meters(coverer),
			_incoming_ball_direction(
				home_block_trajectory, home_block_target, opponent_contact
			),
		) if coverer != null else home_block_target
		var coverage_contact_state := _attack_coverage_contact_state(
			coverer, coverer_start, home_block_target, coverage_time,
		)
		if coverer != null:
			opponent_live_positions[coverer.id] = coverer_reach
		var coverage_contact_time := float(home_block_trajectory.get(
			"end_time", rally_clock + coverage_time
		))
		var opponent_coverage_second := _opponent_second_contact_candidates(
			opponent_team
		)
		var coverage_flight := _coverage_keep_alive_flight(
			coverer, home_block_target, home_block_trajectory,
			coverage_contact_state.get("arrival", {}),
			_platform_body_velocity(
				coverer_start, coverer_reach, coverer_move_time, coverage_time,
			),
			coverage_contact_time,
			opponent_coverage_second.candidates, opponent_coverage_second.starts,
			opponent_coverage_plan, int(opponent_team.setter_id),
			_opponent_setter_release_target(opponent_team),
		)
		var coverage_pass_target := home_block_target + Vector2(0.04, 0.05)
		var coverage_intent: Dictionary = _platform_intent(
			"attack_coverage", coverage_pass_target, "contact_offset",
			null, coverage_pass_target,
		)
		var coverage_incoming := {}
		if not coverage_flight.is_empty():
			coverage_pass_target = Vector2(coverage_flight.destination)
			coverage_intent = coverage_flight.platform_intent
			coverage_incoming = coverage_flight.authoritative_free_flight
		var coverage_meta := {
			"side": "opponent", "coverage": "attack",
			"platform_intent": coverage_intent,
			"blocked_hitter_id": opponent_hitter.id,
			"movement_start": coverer_start,
			"movement_target": coverer_reach,
			"movement_duration": coverer_move_time,
			"arrival": coverage_contact_state.arrival,
			"contact_posture": coverage_contact_state.posture,
			"pass_contact_height_meters": coverage_contact_state.contact_height,
			"incoming_trajectory": home_block_trajectory,
			"event_time": coverage_contact_time,
		}
		if not coverage_flight.is_empty():
			_merge_coverage_flight_metadata(coverage_meta, coverage_flight)
		_add_event(
			result, RallyEventModel.EventType.ATTACK_COVERAGE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Opponent attack coverage",
			home_block_target, coverage_pass_target,
			coverage_success, coverage_quality,
			"%s covers the block rebound" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% control on opponent attack coverage." % roundi(
				coverage_quality * 100.0
			),
			coverage_meta,
		)
		rally_clock = maxf(rally_clock, coverage_contact_time)
		if not coverage_success:
			return _finish(result, "counter_block", true, blocker_id, {
				"hitter": original_hitter.display_name,
				"blocker": blocker_name,
			})
		result.key_factors.append(_factor("attack_recycled"))
		if exchange_number >= MAX_EXCHANGES:
			var opponent_safety_win := coverage_quality \
				+ rng.randf_range(-0.18, 0.18) > 0.60
			return _finish(
				result,
				"long_rally_loss" if opponent_safety_win else "long_rally_win",
				not opponent_safety_win,
				coverer.id if coverer != null else -1,
				{"hitter": original_hitter.display_name},
			)
		return _resolve_opponent_transition(
			result, players, lineup, opponent_hitter, coverage_pass_target,
			opponent_team, defensive_plan, exchange_number + 1,
			coverage_quality * lerpf(
				1.0, BLOCK_DEFLECTION_CARRY, clampf(home_block, 0.0, 1.0)
			),
			false, coverer.id if coverer != null else -1,
			NAN, 0.0, coverage_incoming,
		)
	if block_outcome == "touch":
		result.key_factors.append(_factor("block_touch"))
		opponent_attack = maxf(opponent_attack - 0.10 - home_block * 0.05, 0.12)
		home_target = deflection_target
	elif block_outcome == "funnel":
		result.key_factors.append(_factor("block_funnel"))
		opponent_attack = maxf(opponent_attack - 0.035, 0.12)
		## A funnel is a wall shaping the hitter's course without touching the
		## ball. The geometric target is already that shaped course; replacing it
		## with a made-up deflection point creates a contact that never happened.
		if geometric.is_empty():
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
	## **Measured, reverted, and the measurement is the finding.**
	##
	## Reading the drawn flight here was tried unconditionally in the same pass
	## that made the drawn flight physical, on the reasoning above -- the two
	## expressions are one fact computed twice, and the drawn one is now correct.
	## It is still one fact computed twice. But the drawn flight is no longer a
	## 0.74 s lob, it is a struck ball at 12 to 20 m/s, and handing the floor
	## defence that number produced, over 700 rallies:
	##
	##     opponent swings   681 -> 8
	##     home kill rate  0.85 -> 1.000
	##
	## Nobody digs anything, so no rally reaches a second exchange, so the
	## opponent never attacks. That is not the calibration moving; that is the
	## floor defence turning out to be *entirely* calibrated against attacks being
	## modelled as lobs, which nothing had measured before because the two numbers
	## had never been made to disagree this much.
	##
	## So the lofted classifier stays for now and the ball on screen is right,
	## which is the honest state: the drawing has been fixed and the defence has
	## not been re-fitted. Re-fitting it is tasks #62 to #64 -- the same
	## degeneracy `docs/BACKLOG.md` names as the limiter -- and it is a bigger
	## change than this one, not a line in it.
	## **Unconditional now, and the number that closed the dig asymmetry.**
	##
	## The paragraph above found the defect and the fix stayed behind
	## `ENABLE_UNIFIED_ATTACK_SHAPE` because turning it on collapsed the rally --
	## with the dig fitted where it was, giving the home defence the real flight
	## time meant nothing came up at all. That was never an argument that the two
	## solves should disagree; it was the dig being calibrated against a budget
	## only one side of the net received.
	##
	## Measured over 700 rallies with the dig re-fitted alongside it, this is what
	## the split was worth:
	##
	##     home dig rate       0.929 -> 0.693
	##     opponent dig rate   0.180 -> 0.307
	##     home kill rate      0.602 -> 0.531
	##     opponent kill rate  0.279 -> 0.415
	##
	## Five to one, on identical code, entirely because the home defence was
	## timing the ball off a lofted classifier while the opponent defence timed it
	## off the swing. What remains of the gap is an offence difference -- home
	## swings come out at 0.484 and opponent swings at 0.332 -- which is a
	## different claim and is what tasks #62 to #64 are still for.
	var visible_opponent_attack: Dictionary = opponent_attack_event.metadata.get(
		"outgoing_trajectory", opponent_attack_trajectory
	) if opponent_attack_event != null else opponent_attack_trajectory
	var attack_time := maxf(float(
		home_block_trajectory.get("duration", 0.0)
	), BLOCK_DEFLECTION_MIN_SECONDS) \
		if not home_block_trajectory.is_empty() else float(
			visible_opponent_attack.get("duration", 0.5)
		)
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
		floor_phase_positions,
		-1.0,
		## And which way each of them is set. A ball arriving behind a defender
		## costs them the turn their own locomotion prices.
		_ready_facings(floor_phase_positions.keys(), &"home"),
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
	## **After the fallback, not before it.** The claim answers on the true
	## landing point and this defender then pays for their own read of it -- and
	## a defender who nobody claimed the ball for is still a defender reading a
	## ball. Applied only to the claimed one, the two sides of the net were being
	## charged through different populations: `_choose_opponent_defender` adjusts
	## its fallback claimant and this did not.
	var defense_arrival: Dictionary = _read_adjusted_arrival(
		Dictionary(defense_claim.get("arrival", {})),
		_read_error_meters(
			defender,
			home_block_trajectory if not home_block_trajectory.is_empty()
				else opponent_attack_trajectory,
			opponent_attack_spin, rally_clock,
		),
	)
	defense_claim["arrival"] = defense_arrival
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
		posture_read + _dig_read_bonus(defender, opponent_hitter, block_outcome),
		CoverageModel.reception_body_penalty(
			defender, defense_arrival, opponent_attack
		),
		support_count,
	)
	## Published beside the pressure it is contested against, because a term
	## that decides a dig and cannot be read off the event is a term nobody can
	## attribute a dig to -- which is how three separate values on this branch
	## came to be spent invisibly.
	home_dig_terms["read_error_meters"] = float(
		Dictionary(defense_arrival).get("read_error_meters", 0.0)
	)
	home_dig_terms["contested_against"] = _attack_pressure(
		opponent_attack,
		home_block_trajectory if not home_block_trajectory.is_empty()
			else opponent_attack_trajectory,
	)
	var defense_quality := float(home_dig_terms.quality)
	## Never reaching the ball is already most of what the timing term says; this
	## keeps the hard floor the arrival model asserts separately.
	if not defender_arrived:
		defense_quality = minf(defense_quality, 0.10)
		home_dig_terms["unarrived_floor"] = true
	var home_dig := _dig_outcome(
		defender, defense_quality, float(home_dig_terms.contested_against)
	)
	home_dig_terms["control"] = float(home_dig.control)
	home_dig_terms["edge"] = float(home_dig.edge)
	var defense_success: bool = defender_arrived and bool(home_dig.dug)
	## A defender who never arrived did not scramble it either.
	var home_dig_control := float(home_dig.control) if defender_arrived else 0.0
	var home_dig_recovery := _dig_recovery(
		defender, home_dig_terms, opponent_attack,
		home_block_trajectory if not home_block_trajectory.is_empty()
			else visible_opponent_attack,
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
		defender, defender_start, home_target, attack_time, "lateral",
		float(defense_arrival.get("read_error_meters", 0.0)),
		GeometricAttackPromotionModel.pass_contact_height_meters(defender),
		_incoming_ball_direction(
			home_block_trajectory if not home_block_trajectory.is_empty()
				else visible_opponent_attack,
			home_target, Vector2(
				visible_opponent_attack.get("start_position", home_target)
			),
		),
	)
	live_positions[defender.id] = defender_reach
	var defense_pass_target := home_target + Vector2(0.03, -0.04)
	var home_dig_setter := _player_by_id(players, lineup.active_setter_id())
	var home_dig_release: Vector2 = defensive_plan.setter_release_target(
		lineup.active_setter_id()
	)
	var home_dig_intent := _platform_intent(
		"controlled_dig", home_dig_release, "release_seat",
		home_dig_setter,
		Vector2(live_positions.get(
			lineup.active_setter_id(), home_dig_release
		)),
	)
	## See the mirrored site on the home swing: the continuation's second-contact
	## window is measured from `rally_clock`, so the clock has to reach the dig.
	var home_arriving_trajectory := home_block_trajectory \
		if not home_block_trajectory.is_empty() else visible_opponent_attack
	var home_dig_time := float(home_arriving_trajectory.get(
		"end_time", rally_clock + attack_time
	))
	rally_clock = maxf(rally_clock, home_dig_time)
	var home_defense_intents := {}
	var home_by_id_for_defense := {}
	for entry in players:
		var defence_player := entry as VolleyballPlayer
		if defence_player != null:
			home_by_id_for_defense[defence_player.id] = defence_player
	var home_dig_pass := {}
	if defense_success:
		home_dig_pass = _dig_pass_result(
			defender, home_target, defense_pass_target, home_dig_control,
			defense_arrival, str(last_dig_posture), opponent_attack_trajectory,
			float(defense_arrival.get("distance_meters", 0.0)),
			_player_by_id(players, lineup.active_setter_id()), rally_clock,
			_platform_body_velocity(
				defender_start, defender_reach, defender_move_time, attack_time,
			),
			home_dig_intent,
			home_arriving_trajectory,
		)
		defense_pass_target = Vector2(home_dig_pass.destination)
	_add_event(result, RallyEventModel.EventType.DIG, defender.id, defender.display_name,
		home_target, defense_pass_target, defense_success,
		home_dig_control, "%s defends" % defender.display_name,
		"%d%% defensive contact against a %d%% attack. %s %s" % [
			roundi(home_dig_control * 100.0), roundi(opponent_attack * 100.0),
			_responsibility_phrase(defensive_plan, defender.id, attack_type),
			_arrival_phrase(defense_arrival, defender_arrived, support_count),
		], {"side": "home", "dig_terms": home_dig_terms,
			"platform_intent": home_dig_intent,
			"attack_type": attack_type,
			## The same pair the reception publishes: nearest against winner.
			"nearest_id": int(defense_claim.get("nearest_id", -1)),
			"nearest_distance_meters": float(defense_claim.get(
				"nearest_distance_meters", -1.0
			)),
			"winner_distance_meters": float(defense_claim.get(
				"winner_distance_meters", -1.0
			)),
			"reachable_count": int(defense_claim.get("reachable_count", 0)),
			"immediate_lock": bool(defense_claim.get("immediate_lock", false)),
			"immediate_owner_count": int(defense_claim.get("immediate_owner_count", 0)),
			"nearest_teammate_meters": float(defense_claim.get(
				"nearest_teammate_meters", -1.0
			)),
			"planner_floor_center": Vector2(floor_phase_positions.get(
				defender.id, defender_start
			)),
			"home_phase_targets": _deflection_adjust_map(
				floor_phase_positions, home_target, defender.id,
				## The deflection's own flight, not what is left of the clock.
				## `rally_clock` has already been advanced to the dig by the time
				## this dictionary is built, so subtracting it gave zero and every
				## defender was handed a window of the 0.12 s floor -- a lean of
				## five centimetres, which is a map that publishes and does not
				## move anybody. Measured that way: 0.05 m across 319 legs.
				float(home_block_trajectory.get("duration", 0.24)),
				false, home_by_id_for_defense, home_defense_intents,
			),
			"home_phase_intents": home_defense_intents,
			"responsibility_fit": responsibility_fit,
			"flight_time": attack_time, "arrival": defense_arrival,
			"incoming_trajectory": home_arriving_trajectory,
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
			## The ball this dig actually put up. Published here rather than
			## invented later, so the setter and the drawing share one object.
			"outgoing_trajectory": home_dig_pass.get("trajectory", {}),
			"pass_apex_meters": home_dig_pass.get("pass_apex_meters", 0.0),
			"pass_contact_height_meters": home_dig_pass.get(
				"pass_contact_height_meters", 0.0
			),
			"set_contact_height_meters": home_dig_pass.get(
				"set_contact_height_meters", 0.0
			),
			"pass_duration_seconds": home_dig_pass.get("duration", 0.0),
			"target_error_meters": home_dig_pass.get("target_error_meters", 0.0),
			"pass_spoil": home_dig_pass.get("spoil", 0.0),
			"platform_contact": home_dig_pass.get("platform_contact", {}),
			"reach_margin_meters": last_dig_reach_margin,
			"recovering_count": _recovering_count(rally_clock),
			"event_time": home_dig_time})
	_note_recovery(defender, home_dig_recovery, home_dig_time)
	result.key_factors.append(_factor(
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
		opponent_team, defensive_plan, exchange_number, home_dig_control,
		## The dig's own flight, which this parameter has been waiting for. It
		## was 0.0 with a note saying a dug ball had no modelled arc; it has one.
		float(home_dig_pass.get("duration", 0.0)),
		## The swing they just dug. The home side has been transitioning since
		## the ball was struck, not since it came off the platform, which is the
		## same head start the first ball takes from the serve.
		float(opponent_attack_trajectory.get("duration", 0.0)),
		Dictionary(home_dig_pass.get("trajectory", {})),
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
	## The dug ball's own flight, and how long the volis had been transitioning
	## before it was played. Both default to the old behaviour so a caller that
	## has not been given them is unchanged rather than silently worse.
	dig_flight_seconds: float = 0.0,
	transition_head_start_seconds: float = 0.0,
	## The dug ball itself, for the same reason the opponent path takes one: a
	## set has to be resolved against a flight, not against a duration lifted out
	## of one. **Last in the list deliberately** -- two callers pass this
	## function positionally, and inserting it in the middle silently handed one
	## of them a float where a trajectory belongs.
	incoming_pass_trajectory: Dictionary = {},
) -> Resource:
	var cont_second_contact := _home_second_contact_candidates(players, lineup)
	var setter := _second_contact_setter(
		cont_second_contact.candidates, defensive_plan,
		lineup.active_setter_id(), defender.id,
	)
	var physical_choice := {}
	if str(incoming_pass_trajectory.get("trajectory_role", "")) \
			== "authoritative_free_flight":
		physical_choice = _physical_second_contact_choice(
			incoming_pass_trajectory,
			cont_second_contact.candidates, cont_second_contact.starts,
			defensive_plan, lineup.active_setter_id(), defender.id, setter,
			&"home", defensive_plan.setter_release_target(
				lineup.active_setter_id()
			), GeometricAttackPromotionModel.set_contact_height_meters(setter),
			transition_head_start_seconds,
		)
		_stamp_free_flight_resolution(result, physical_choice)
		if physical_choice.get("player") == null:
			var terminal_reason := str(Dictionary(physical_choice.get(
				"terminal", {}
			)).get("reason", "unresolved"))
			if terminal_reason == "crossed_net_unresolved":
				## The home ball crossed over: the opponent makes the ordinary first
				## team contact. Symmetric to the home path; old terminal on fall-through.
				var opponent_overpass := _resolve_overpass_into_opponent(
					result, players, lineup, incoming_pass_trajectory, opponent_team,
					defensive_plan, exchange_number, incoming_quality, defender,
				)
				if opponent_overpass != null:
					return opponent_overpass
				return _finish(result, "m5_unresolved_overpass", false, defender.id, {
					"hitter": defender.display_name,
				})
			var opponent_attacker := _latest_attack_credit(result, "opponent")
			return _finish(
				result, "opponent_kill", false, int(opponent_attacker.id),
				{"hitter": str(opponent_attacker.name)},
			)
	# Preserve contact continuity: the transition set begins where the dig
	# actually finishes instead of teleporting the ball to center court.
	var set_contact := Vector2(physical_choice.get(
		"contact_position", dig_position
	))
	## **The hardcoded 0.68 the movement-agreement gate has been naming for
	## months.** It is the one window in the engine that was not derived from a
	## ball: the first-ball set takes the pass's own flight and this took a
	## constant, so a setter chasing a dug ball that hung for a second and one
	## chasing a flat one had exactly the same time. The constant stays as the
	## fallback for a dig with no modelled flight, which is what the zero
	## default above means.
	var second_contact_window := float(physical_choice.get(
		"contact_time", 0.0
	)) - float(incoming_pass_trajectory.get("start_time", 0.0)) \
		if not physical_choice.is_empty() \
		else (dig_flight_seconds if dig_flight_seconds > 0.0 \
			else DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS)
	var setter_choice := physical_choice if not physical_choice.is_empty() \
		else _spatial_setter_choice(
			cont_second_contact.candidates, cont_second_contact.starts,
			defensive_plan, lineup.active_setter_id(), defender.id, setter,
			set_contact, second_contact_window,
			## The opponent's attack flight. The home side has been transitioning out
			## of defence since the swing was struck, not since the dig came off the
			## platform -- the same head start the first ball gets from the serve.
			transition_head_start_seconds,
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
	var hitter := _fallback_hitter(
		players, lineup, setter.id, incoming_quality, setter, current_match_flow
	)
	if setter != null:
		narration["setter"] = setter.display_name
	if hitter != null:
		narration["hitter"] = hitter.display_name
	var assignment := _fallback_assignment(hitter, lineup)
	## The same read the opponent's setter makes, off the same base. This path
	## took `_fallback_assignment`'s literal 3 and never varied it, so a home
	## setter given a clean dig and the judgment to use it ran the same high
	## ball as one scrambling -- and the histogram's `tempo_demand` term of
	## 0.000 on this path was that constant showing up as a cost nobody paid.
	## Correct, then clobbered -- caught by counting the lanes against the tempos.
	##
	## `_fallback_assignment` gives a quick its first-tempo ball, and this line
	## then overwrote it with a transition call based on `TRANSITION_TEMPO_BASE`,
	## which is 3. The result was 74 quick *lanes* against 35 first-tempo balls:
	## a middle running a quick approach under a high ball, which is neither of
	## the two things it could have been.
	##
	## A quick is a first-tempo ball by definition -- that is what makes it a
	## quick -- so the tempo is not the transition setter's to call once the lane
	## has been chosen. Everything else still reads the dig.
	if assignment.lane not in ["Front Quick", "Right Quick"]:
		assignment.tempo = _tempo_call(
			setter, TRANSITION_TEMPO_BASE, incoming_quality
		)
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
	var realised_pass_contact_height := float(physical_choice.get(
		"contact_height_meters", NAN
	))
	if is_nan(realised_pass_contact_height):
		realised_pass_contact_height = SetterCapabilityModel.pass_contact_height_meters(
			incoming_quality, rng.randf()
		)
	var setter_capability := SetterCapabilityModel.evaluate(
		setter, assignment.tempo, incoming_quality,
		realised_pass_contact_height,
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
	var intended_set_target := HitterPlacementModel.preferred_point(
		hitter, assignment.lane, rally_seed, swing_index
	)
	var continuation_intended_body := SetPathReadModelRef.body_position(
		hitter, intended_set_target, true
	)
	swing_index += 1
	var cont_release_target: Vector2 = defensive_plan.setter_release_target(
		lineup.active_setter_id()
	) if defensive_plan != null else Vector2(0.50, 0.60)
	var cont_set_geometry := _set_geometry(
		setter, setter_start, set_contact, intended_set_target, cont_release_target
	)
	var cont_hitter_choice_start := Vector2(live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	))
	var ordinary_cont_arc := _set_arc(
		setter, assignment.tempo, incoming_quality,
		GeometricAttackPromotionModel.set_contact_height_meters(setter),
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		RallyKinematics.court_distance_meters(set_contact, intended_set_target),
	)
	var cont_set_height_extra := _set_rescue_height_meters(
		_movement_time(
			hitter, cont_hitter_choice_start, continuation_intended_body,
			"transition"
		),
		float(ordinary_cont_arc.duration_seconds),
	)
	var cont_height_difficulty := _set_height_difficulty(
		setter, cont_set_height_extra
	)
	## A transition set is harder than one off a served ball and the tempo it
	## runs costs something: `exchange_penalty` carries the first, the tempo
	## demand every other set pays carries the second.
	var cont_tempo_demand := float(3 - int(setter_capability.resolved_tempo)) \
		* lerpf(1.0, 1.0 - ARM_SPEED_TEMPO_RELIEF, _rating(hitter, "arm_speed")) \
		* 0.055 * lerpf(1.0, 0.65, _rating(setter, "tempo_control"))
	var cont_set_terms := _set_terms(
		setter, float(setter_capability.effective_pass_quality),
		exchange_penalty + cont_tempo_demand,
		float(setter_capability.quality_penalty), setter_arrival_margin,
		float(cont_set_geometry.difficulty) + cont_height_difficulty,
		(Familiarity.execution_modifier(setter) - 1.0) * 0.16,
	)
	cont_set_terms["height_difficulty"] = cont_height_difficulty
	cont_set_terms["rescue_height_meters"] = cont_set_height_extra
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
		CourtConstants.lane_delivery_min_y(
			assignment.lane, HOME_SET_DELIVERY_MIN_Y
		),
		HOME_SET_DELIVERY_MAX_Y,
		RallyKinematics.court_distance_meters(set_contact, intended_set_target),
		float(ordinary_cont_arc.apex_height_meters) + cont_set_height_extra,
	)
	## A dug ball has no modelled apex, so `_jump_set_decision` is asked with the
	## setter's own standing release: it can never say "under the hands" here,
	## and the answer turns entirely on whether they got there in time. That is
	## the right shape for a transition ball and it is stated rather than
	## implied -- when a dig grows an arc, this line is where it arrives.
	var cont_jump_set := _jump_set_decision(
		setter,
		realised_pass_contact_height,
		setter_arrival_margin,
		RallyKinematics.court_distance_meters(
			Vector2(setter_choice.get("origin", setter_start)), set_contact
		),
		float(setter_choice.get("total_travel_seconds", setter_move_time)),
	)
	if bool(physical_choice.get("requires_jump", false)):
		cont_jump_set["jumping"] = true
		cont_jump_set["reason"] = "required by physical interception"
	var cont_release_height := realised_pass_contact_height \
		if not physical_choice.is_empty() \
		else GeometricAttackPromotionModel.set_contact_height_meters(
			setter, bool(cont_jump_set.jumping)
		)
	var continuation_set_arc := _set_arc(
		setter, assignment.tempo, set_quality,
		cont_release_height,
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		RallyKinematics.court_distance_meters(set_contact, set_target),
		cont_set_height_extra,
	)
	var continuation_natural_flight: float = float(
		continuation_set_arc.duration_seconds
	) \
		/ maxf(_set_pace_scale(setter, bool(cont_jump_set.jumping)), 0.5)
	var cont_tempo_timing := _hitter_led_set_timing(
		setter, hitter, int(assignment.tempo), str(assignment.lane),
		intended_set_target, false, continuation_natural_flight, set_quality,
		home_principles, _pair_fraction(setter.id, hitter.id),
		team_tactical_familiarity, "home-continuation-%d" % exchange_number,
	)
	var continuation_flight_time := float(
		cont_tempo_timing.delivered_flight_seconds
	)
	continuation_set_arc = _retimed_set_arc(
		continuation_set_arc, continuation_flight_time, cont_release_height,
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
	)
	var cont_release_profile := setter.system_fit(VolleyballPlayer.SYSTEM_FIT_SET_RELEASE)
	var cont_release_interval := _release_interval(cont_release_profile, set_quality)
	## The transition set leaves the setter's hands once they have travelled to
	## the dig, taken the ball, and released it. Every later contact in this
	## continuation is timed from that instant, mirroring the main set path --
	## without it the set flight would start after the attack flight it feeds.
	var cont_set_contact_time := rally_clock + second_contact_window + cont_release_interval
	var continuation_intents := {}
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, set_quality >= 0.20, set_quality,
		("Emergency second-contact set" if emergency_setter else "Transition set") \
		+ " · exchange %d" % exchange_number,
		"Contact 2 of 3 after %s's dig · %d%% set quality." % [
			defender.display_name, roundi(set_quality * 100.0),
		], {"side": "home", "set_path": "home_transition",
			## The home off-ball four out of defence, on the same principle as the
			## first-ball path. Without this the transition set was the one home
			## flight nobody moved through -- the opponent's continuation had it
			## and ours did not, which is the asymmetry this file keeps having to
			## close one path at a time.
			"home_phase_targets": _transition_phase_map(
				players, lineup, defender.id, setter.id,
				hitter.id if hitter != null else -1,
				set_contact, continuation_flight_time, setter_arrival_margin,
				continuation_intents,
			),
			"home_phase_intents": continuation_intents,
			"set_terms": cont_set_terms,
			"setter_capability": setter_capability.duplicate(true),
			"set_distance_meters": cont_set_geometry.distance_meters,
			"set_angle_degrees": cont_set_geometry.angle_degrees,
			"release_distance_meters": cont_set_geometry.release_distance_meters,
			"body_orientation_fit": cont_set_geometry.body_orientation_fit,
			"rescue_height_meters": cont_set_height_extra,
			"height_difficulty": cont_height_difficulty,
			"emergency_setter": emergency_setter,
			"first_contact_id": defender.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"body_contact_position": Vector2(physical_choice.get(
				"body_contact_position", set_contact
			)),
			"movement_entry_velocity": Vector2(physical_choice.get(
				"entry_velocity_mps", Vector2.ZERO
			)),
			"arrival_margin": setter_arrival_margin,
			"flight_time": continuation_flight_time,
			"release_interval": cont_release_interval,
			"tempo_coordination": cont_tempo_timing.duplicate(true),
			"tempo_relationship": str(cont_tempo_timing.relationship),
			"requested_tempo": int(assignment.tempo),
			"intended_target": intended_set_target,
			"deadline": cont_set_contact_time,
			"event_time": cont_set_contact_time,
			"outgoing_trajectory": _ball_trajectory(
				"set", set_contact, set_target, continuation_flight_time,
				float(continuation_set_arc.apex_height_meters),
				cont_set_contact_time, NAN, NAN,
				float(continuation_set_arc.get("release_height_meters", NAN)),
				float(continuation_set_arc.get("arrival_height_meters", NAN)),
			)})
	## Lineage, as on the opponent side: the flight this set was resolved
	## against, so a probe can prove the chain instead of comparing endpoints.
	## Under a physical interception that flight is the realised prefix that
	## actually reached the setter -- the same segment stamped onto the feeding
	## contact -- not the full authoritative flight to the floor. Legacy feeds
	## carry no realised segment and fall through unchanged.
	if not result.events.is_empty():
		var cont_set_incoming := Dictionary(
			physical_choice.get("realised_trajectory", {})
		)
		result.events[-1].metadata["incoming_pass_trajectory"] = \
			cont_set_incoming if not cont_set_incoming.is_empty() \
			else incoming_pass_trajectory
	var cont_set_event := result.events[-1] as RallyEvent
	_stamp_second_contact_claim(cont_set_event, setter_choice)
	if cont_set_event != null:
		cont_set_event.metadata["set_posture"] = "jump" \
			if bool(cont_jump_set.jumping) else "standing"
		cont_set_event.metadata["set_posture_reason"] = str(cont_jump_set.reason)
		cont_set_event.metadata["set_closing_speed_mps"] = float(
			cont_jump_set.get("closing_speed_mps", 0.0)
		)
		cont_set_event.metadata["back_set"] = bool(cont_set_geometry.back_set)
		cont_set_event.metadata["behind_meters"] = float(
			cont_set_geometry.behind_meters
		)
		cont_set_event.metadata["set_release_height_meters"] = cont_release_height
		cont_set_event.metadata["set_pace_scale"] = _set_pace_scale(
			setter, bool(cont_jump_set.jumping)
		)
	live_positions[setter.id] = set_contact
	var hitter_standing_at: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	var hitter_start := hitter_standing_at
	var transition_state := RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, true,
		rng.seed + exchange_number * 1009,
	)
	transition_state.simulation_time = maxf(rally_clock - 0.55, 0.0)
	_seed_carried_body_states(transition_state, transition_state.simulation_time)
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
		"target": continuation_intended_body,
	}
	var transition_preparation := ApproachMechanicsModel.prepare_for_attack(
		transition_state, hitter_actor, continuation_assignment, defender.id,
		cont_set_contact_time,
	)
	var prepared_hitter := transition_preparation.get("actor") as RallyPlayerState
	transition_preparation.erase("actor")
	var continuation_full_approach_start := hitter_start
	var continuation_release_progress := 0.0
	var continuation_movement_delay := float(cont_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	var continuation_entry_velocity := Vector2.ZERO
	var continuation_approach: Dictionary = {}
	if prepared_hitter != null:
		continuation_full_approach_start = prepared_hitter.position
		var continuation_ideal_mark := Vector2(transition_preparation.get(
			"approach_target_position", continuation_full_approach_start
		))
		var continuation_to_mark := _movement_time(
			hitter, hitter_standing_at, continuation_ideal_mark, "transition"
		)
		continuation_release_progress = ApproachMechanicsModel \
			.achieved_release_progress(
				cont_tempo_timing,
				float(transition_preparation.get(
					"preparation_time_seconds", 0.0
				)),
				continuation_to_mark,
			)
	cont_tempo_timing = ApproachMechanicsModel.recognize_release_progress(
		cont_tempo_timing, continuation_release_progress
	)
	var continuation_effective_tempo := ApproachMechanicsModel.achieved_tempo(
		cont_tempo_timing, continuation_release_progress
	)
	continuation_flight_time = float(
		cont_tempo_timing.delivered_flight_seconds
	)
	continuation_set_arc = _retimed_set_arc(
		continuation_set_arc, continuation_flight_time, cont_release_height,
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
	)
	continuation_movement_delay = float(cont_tempo_timing.get(
		"approach_start_delay_seconds", 0.0
	))
	var continuation_set_path_read := SetPathReadModelRef.evaluate(
		hitter, intended_set_target, set_target, continuation_flight_time,
		set_quality, _pair_fraction(setter.id, hitter.id), rally_seed,
		"home-continuation-%d" % exchange_number, true,
	)
	var continuation_perceived_body := Vector2(
		continuation_set_path_read.get(
			"perceived_body_position", continuation_intended_body
		)
	)
	var continuation_ideal_body := Vector2(
		continuation_set_path_read.get(
			"ideal_body_position",
			SetPathReadModelRef.body_position(hitter, set_target, true),
		)
	)
	if prepared_hitter != null:
		continuation_approach = ApproachMechanicsModel.evaluate_takeoff(
			prepared_hitter, continuation_perceived_body,
			float(cont_tempo_timing.get(
				"runup_seconds", continuation_flight_time
			)),
		)
		hitter_start = ApproachMechanicsModel.release_position(
			continuation_full_approach_start, continuation_perceived_body,
			continuation_release_progress,
		)
		var continuation_direction := (
			continuation_perceived_body - continuation_full_approach_start
		).normalized()
		var continuation_carried_speed := float(continuation_approach.get(
			"approach_speed_mps", 0.0
		)) * sqrt(continuation_release_progress)
		continuation_entry_velocity = continuation_direction \
			* continuation_carried_speed \
			if continuation_direction.length_squared() > 0.0001 \
			else prepared_hitter.velocity
		prepared_hitter.apply_position(hitter_start, continuation_entry_velocity)
	cont_tempo_timing["achieved_release_progress"] = continuation_release_progress
	cont_tempo_timing["release_position"] = hitter_start
	cont_tempo_timing["full_approach_start"] = \
		continuation_full_approach_start
	cont_tempo_timing["achieved_tempo"] = continuation_effective_tempo
	cont_tempo_timing["achieved_relationship"] = \
		ApproachMechanicsModel.achieved_relationship(
			cont_tempo_timing, continuation_release_progress
		)
	var continuation_planned_leg := _travel(
		hitter, hitter_start, continuation_perceived_body, "transition", null,
		continuation_entry_velocity,
	)
	var continuation_planned_move_time := float(
		continuation_planned_leg.seconds
	)
	var continuation_contact_budget := maxf(
		continuation_flight_time - continuation_movement_delay
			- float(cont_tempo_timing.get(
				"takeoff_to_contact_seconds", 0.0
			)),
		0.0,
	)
	var continuation_body_contact := _reachable_contact(
		hitter_start, continuation_perceived_body,
		continuation_planned_move_time, continuation_contact_budget,
	)
	var hitter_arrival_margin := continuation_contact_budget \
		- continuation_planned_move_time
	var continuation_displacement := _clamp_displacement_meters(
		continuation_perceived_body, continuation_body_contact
	)
	var continuation_leg := _travel(
		hitter, hitter_start, continuation_body_contact, "transition", null,
		continuation_entry_velocity,
	)
	var hitter_move_time := float(continuation_leg.seconds)
	live_velocities[hitter.id] = continuation_leg.exit_velocity
	_commit_facing(hitter.id, continuation_leg)
	var continuation_set_path_contact := SetPathReadModelRef.assess_contact(
		hitter, continuation_body_contact, continuation_ideal_body
	)
	var continuation_path_quality_multiplier := float(
		continuation_set_path_contact.get("quality_multiplier", 1.0)
	)
	var continuation_set_path_whiff := bool(
		continuation_set_path_contact.get("whiffed", false)
	)
	var set_event_for_staging := result.events[-1] as RallyEvent
	_retarget_set_event(
		set_event_for_staging, set_target, "set", continuation_flight_time,
		float(continuation_set_arc.apex_height_meters), cont_set_contact_time,
		float(continuation_set_arc.get("release_height_meters", NAN)),
		float(continuation_set_arc.get("arrival_height_meters", NAN)),
	)
	if prepared_hitter != null:
		continuation_approach = ApproachMechanicsModel.evaluate_takeoff(
			prepared_hitter, continuation_body_contact,
			continuation_flight_time
		)
	if set_event_for_staging != null:
		set_event_for_staging.metadata["flight_time"] = continuation_flight_time
		set_event_for_staging.metadata["set_flight_time"] = \
			continuation_flight_time
		set_event_for_staging.metadata["set_path_read"] = \
			continuation_set_path_read.duplicate(true)
		set_event_for_staging.metadata["hitter_body_target"] = \
			continuation_perceived_body
		set_event_for_staging.metadata["staged_next_actor_id"] = hitter.id
		set_event_for_staging.metadata["staged_next_position"] = hitter_start
		var continuation_phase_targets: Dictionary = \
			set_event_for_staging.metadata.get("home_phase_targets", {})
		continuation_phase_targets[hitter.id] = hitter_start
		set_event_for_staging.metadata["home_phase_targets"] = \
			continuation_phase_targets
		var continuation_phase_intents: Dictionary = \
			set_event_for_staging.metadata.get("home_phase_intents", {})
		continuation_phase_intents[hitter.id] = {
			"intent": &"preparing_attack",
			"progress": continuation_release_progress,
		}
		set_event_for_staging.metadata["home_phase_intents"] = \
			continuation_phase_intents
		set_event_for_staging.metadata["tempo_coordination"] = \
			cont_tempo_timing.duplicate(true)
		set_event_for_staging.metadata["tempo_relationship"] = str(
			cont_tempo_timing.achieved_relationship
		)
		set_event_for_staging.metadata["achieved_tempo"] = int(
			cont_tempo_timing.achieved_tempo
		)
		set_event_for_staging.detail = (
			"T%d set for %s after %s's dig · %d%% accuracy." % [
				continuation_effective_tempo, hitter.display_name,
				defender.display_name, roundi(set_quality * 100.0),
			]
		) + (
			" Called T%d; the setter matched the hitter's T%d rhythm." % [
				int(assignment.tempo), continuation_effective_tempo,
			] if int(assignment.tempo) != continuation_effective_tempo else ""
		)
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
		opponent_team, set_target.x, continuation_effective_tempo, set_quality,
		set_contact.x, continuation_flight_time,
		second_contact_window + cont_release_interval, hitter,
		cont_set_height_extra,
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
			cont_set_height_extra,
		) + _execution_error(hitter, "attack_accuracy", ATTACK_EXECUTION_NOISE),
		0.0, 1.0,
	)
	var continuation_approach_start := hitter_start
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
	if continuation_displacement > 0.0:
		attack_quality = clampf(
			attack_quality - continuation_displacement * CLAMPED_CONTACT_SEVERITY,
			0.0, 1.0,
		)
	attack_quality = clampf(
		attack_quality * continuation_path_quality_multiplier, 0.0, 1.0
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
			_approach_execution_fit(hitter, continuation_approach)
				* continuation_path_quality_multiplier,
			float(home_principles.decisiveness), 0.0,
			str(cont_wall_plan.block_intent) if cont_wall_plan != null \
				else "Balanced",
			continuation_hit_type,
		),
		"transition",
	)
	if shadow_reception_trace != null:
		shadow_reception_trace.summary["geometric_attack_transition"] = transition_record
	var geometric := _geometric_promotion(transition_record)
	var intended_attack_target := attack_target
	var attack_missed := continuation_set_path_whiff or _attack_missed(
		attack_quality, float(home_principles.decisiveness), hitter
	)
	if not geometric.is_empty():
		attack_missed = continuation_set_path_whiff \
			or bool(geometric.attack_missed)
		attack_target = Vector2(geometric.target)
	elif attack_missed:
		attack_target = _errant_attack_target(intended_attack_target, attack_quality)
	if continuation_set_path_whiff:
		attack_target = _missed_set_drop_target(set_target, true)
	## One shot shape, used both for the full flight and -- if a block touches
	## it -- for the re-sliced leg to the net, so the two describe the same ball.
	var continuation_attack_angle := _attack_launch_angle_degrees(
		hitter, continuation_hit_type, attack_quality
	)
	## In hand, not looked up -- the same conditional store as the opponent
	## swing's, with the same consequence when no trace was built.
	var continuation_attack_spin := _swing_spin(hitter, transition_record)
	var continuation_attack_arc := _swing_arc(
		transition_record,
		RallyKinematics.court_distance_meters(set_target, attack_target),
		GeometricAttackPromotionModel.contact_height_meters(hitter, 1.0),
		not geometric.is_empty()
			and attack_target.is_equal_approx(Vector2(geometric.target)),
		continuation_attack_spin,
	)
	var continuation_attack_flight: float = float(continuation_attack_arc.duration_seconds)
	## Named rather than inlined into the event: the dig below reads this same
	## trajectory's `end_time` so the two contacts agree on when the ball landed.
	var continuation_attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, continuation_attack_flight,
		float(continuation_attack_arc.apex_height_meters),
		cont_set_contact_time + continuation_flight_time,
		float(continuation_attack_arc.get("vertical_speed_mps", NAN)),
	)
	if continuation_set_path_whiff:
		continuation_attack_flight = MISSED_SET_DROP_SECONDS
		continuation_attack_trajectory = _missed_set_drop_trajectory(
			set_target, attack_target,
			cont_set_contact_time + continuation_flight_time,
		)
	var continuation_attack_detail := "Missed the delivered set entirely." \
		if continuation_set_path_whiff else \
		"Contact 3 of 3 · %d%% attack quality." % roundi(
			attack_quality * 100.0
		)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target,
		not attack_missed and attack_quality >= 0.25, attack_quality,
		"T%d %s swing · exchange %d" % [
			continuation_effective_tempo, str(assignment.lane), exchange_number,
		],
		continuation_attack_detail,
		{"side": "home", "lane": assignment.lane,
			"tempo": continuation_effective_tempo,
			"requested_tempo": int(assignment.tempo),
			"tempo_relationship": str(cont_tempo_timing.achieved_relationship),
			"requested_tempo_relationship": str(cont_tempo_timing.relationship),
			"achieved_tempo": int(cont_tempo_timing.achieved_tempo),
			"tempo_coordination": cont_tempo_timing.duplicate(true),
			"body_contact_position": continuation_body_contact,
			"ideal_body_contact_position": continuation_ideal_body,
			"perceived_body_contact_position": continuation_perceived_body,
			"set_path_read": continuation_set_path_read.duplicate(true),
			"set_path_contact": continuation_set_path_contact.duplicate(true),
			"set_path_outcome": str(continuation_set_path_contact.get(
				"outcome", "clean"
			)),
			"set_path_error_meters": float(continuation_set_path_contact.get(
				"error_meters", 0.0
			)),
			"set_path_whiff": continuation_set_path_whiff,
			"attack_type": continuation_hit_type,
			"intended_type": continuation_intended_type,
			"swing_downgraded": continuation_downgraded,
			"intended_target": intended_attack_target,
			"geometric_outcome": str(geometric.get("outcome", "")),
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get("signature_actor_id", hitter.id)),
			"launch_cleared": bool(geometric.get("launch_cleared", true)),
			"launch_mode": str(geometric.get("launch_mode", "")),
			## The two quantities the block's outcome bands cut, on the event
			## rather than only in the shadow summary. `_geometric_swing_record`
			## is a developer surface nothing in production reads, so a band could
			## not be checked against its own distribution from a live rally --
			## which is how both of them came to be set without one.
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_deflection_landing": geometric.get("block_deflection_landing", null),
			"block_deflection_speed_mps": float(geometric.get("block_deflection_speed_mps", 0.0)),
			"block_deflection_playable": bool(geometric.get("block_deflection_playable", false)),
			## How much of a wall this swing actually faced. `block_wall` drops any
			## blocker whose close fraction is under `WALL_JOIN_CLOSE`, so the size
			## of the wall is decided there and nowhere else -- and the resolver
			## reports "no wall" without saying who was dropped or how close they
			## were to arriving.
			"wall_size": int(geometric.get("wall_size", 0)),
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
			## Absent rather than NaN when the wall was never touched.
			##
			## NaN is not equal to itself, so a metadata dictionary carrying one
			## can never compare equal to a byte-identical copy of itself -- which
			## broke the shadow-trace determinism check and the 2D court's trace
			## acceptance the moment these were added. Absence says "no contact"
			## more clearly than a sentinel does anyway.
			"block_depth_below_reach_meters": geometric.get(
				"block_depth_below_reach_meters", null
			),
			"block_edge_gap_meters": geometric.get("block_edge_gap_meters", null),
			"geometric_out_reason": str(geometric.get("out_reason", "")),
			"attack_missed": attack_missed,
			"movement_start": hitter_start,
			"approach_start_position": continuation_approach_start,
			"full_approach_start_position": continuation_full_approach_start,
			"movement_delay_seconds": continuation_movement_delay,
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
			"movement_entry_velocity": continuation_entry_velocity,
			"arrival_margin": hitter_arrival_margin,
			"set_flight_time": continuation_flight_time,
			"flight_time": continuation_attack_flight,
			"event_time": cont_set_contact_time + continuation_flight_time,
			"outgoing_trajectory": continuation_attack_trajectory})
	## **The ball this swing was actually struck against.**
	##
	## Read straight off the SET event this path already published and retargeted,
	## so the identity is by construction rather than by two endpoints happening to
	## agree. The home first ball has carried it since it existed; this path and
	## the opponent transition did not, so the one-ball chain could be audited on one
	## of the three attack paths and was silently unprovable on the other two.
	## Reporting only -- the swing was already resolved against `set_flight_time`
	## and this set's arc.
	var cont_swing_event := result.events[-1] as RallyEvent
	if cont_swing_event != null and cont_set_event != null:
		cont_swing_event.metadata["incoming_trajectory"] = Dictionary(
			cont_set_event.metadata.get("outgoing_trajectory", {})
		)
	live_positions[hitter.id] = continuation_body_contact
	## The continuation now owns a real timeline instead of stamping every
	## contact with the dig's clock: set contact, then the set flight, then the
	## attack. Later contacts read `rally_clock` and inherit it.
	rally_clock = cont_set_contact_time + continuation_flight_time
	if attack_missed:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	var opponent_blocker := block_result.primary as VolleyballPlayer
	if opponent_blocker != null:
		narration["opponent_blocker"] = opponent_blocker.display_name
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var primary_close := float(block_result.primary_close)
	var assist_close := float(block_result.assist_close)
	var block_quality := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	if not geometric.is_empty():
		block_outcome = str(geometric.block_outcome)
	var blocked := block_outcome == "stuff"
	var continuation_hitter_point := bool(geometric.get("hitter_point", false))
	## Same contract as the main attack path: a block only shortens the shot if
	## it actually touches it, and an untouched ball carries no deflection leg.
	## Without this the continuation attack flew its full arc *and* the block
	## emitted an overlapping path from the net, so the ball was described in
	## two places at once.
	var cont_block_contacts := blocked \
		or block_outcome in ["recycle", "touch", "tool"]
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
	var cont_floor_intents := {}
	var cont_floor_stage := _establish_shape(
		_floor_phase_positions(
			opponent_team.current_lineup(), _opponent_defensive_plan(opponent_team),
			set_target.x,
			opponent_blocker.id if opponent_blocker != null else -1,
			assisting_blocker.id if assisting_blocker != null else -1,
			true, cont_wall_x,
		),
		opponent_team.on_court_players(), opponent_live_positions,
		float(continuation_flight_time), cont_floor_intents,
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
		## This site published where the continuation defence stood and never why
		## or for how long, which the other two both did. Same map, same shape.
		(result.events[-1] as RallyEvent).metadata["opponent_phase_intents"] = \
			_defensive_intents(cont_block_stage, cont_floor_intents)
	## The proven crossing, matching the other two block sites -- see
	## `_block_contact_point`. Truncation and deflection origin at once, so this
	## is the §5 realised contact for the continuation swing.
	var cont_net_contact := _block_contact_point(geometric, set_target.x, 0.50)
	## A stuffed ball comes down under the hands that stuffed it, so this target
	## follows the contact rather than the hitter -- same reason as
	## `cont_net_contact` above. Overwritten by `_trajectory_endpoint` whenever a
	## deflection is drawn; it is the target that feeds that deflection.
	var block_event_end := Vector2(cont_net_contact.x, 0.50) if not blocked \
		else Vector2(cont_net_contact.x, 0.47)
	var continuation_visible_attack_trajectory := continuation_attack_trajectory
	if cont_block_contacts:
		var cont_attack_event: Resource = result.events[-1]
		var cont_to_block_arc := _truncated_arc(
			continuation_attack_arc,
			RallyKinematics.court_distance_meters(set_target, attack_target),
			RallyKinematics.court_distance_meters(set_target, cont_net_contact),
		)
		cont_attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
			"attack_to_block", set_target, cont_net_contact,
			float(cont_to_block_arc.duration_seconds),
			float(cont_to_block_arc.apex_height_meters),
			cont_set_contact_time + continuation_flight_time,
			float(cont_to_block_arc.get("vertical_speed_mps", NAN)),
			float(cont_to_block_arc.get("swing_duration_seconds", NAN)),
		)
		continuation_visible_attack_trajectory = Dictionary(
			cont_attack_event.metadata["outgoing_trajectory"]
		)
	var block_event_detail := "Primary close %d%%; block quality %d%%." % [
		roundi(primary_close * 100.0), roundi(block_quality * 100.0),
	]
	if assisting_blocker != null:
		block_event_detail += " %s assisted at %d%% close." % [
			assisting_blocker.display_name, roundi(assist_close * 100.0)
		]
	var cont_block_trajectory := _block_deflection_trajectory(
		cont_net_contact, block_event_end, blocked, 0.42,
		_swing_reaches_net(continuation_attack_trajectory, rally_clock),
		float(continuation_attack_arc.get("required_speed_mps", 0.0)),
		opponent_blocker,
		str(block_result.get("block_hands", "neutral")),
		## The continuation carries no spin state or familiarity of its own.
		{}, 0.0,
		geometric.get("block_deflection_landing", null),
		float(geometric.get("block_deflection_speed_mps", 0.0)),
		float(geometric.get("block_deflection_vertical_angle_degrees", 0.0)),
		float(geometric.get("block_deflection_duration_seconds", 0.0)),
		bool(geometric.get("block_deflection_playable", false)),
	) if cont_block_contacts else {}
	if cont_block_contacts and not cont_block_trajectory.is_empty():
		block_event_end = _trajectory_endpoint(
			cont_block_trajectory, block_event_end
		)
		if block_outcome == "touch":
			attack_target = block_event_end
	if cont_block_contacts and _block_deflection_lands_out(cont_block_trajectory):
		continuation_hitter_point = true
		block_outcome = "tool"
		blocked = false
		block_event_end = _trajectory_endpoint(
			cont_block_trajectory, block_event_end
		)
	elif blocked and _block_deflection_lands_on_blocking_side(
		cont_block_trajectory, "opponent"
	):
		block_outcome = "touch"
		blocked = false
		block_event_end = _trajectory_endpoint(
			cont_block_trajectory, block_event_end
		)
		attack_target = block_event_end
	var continuation_cover_intents := {}
	## The hand the ball met, on the same rule as the other two block sites.
	var cont_contact_blocker := _block_contact_blocker(
		geometric, opponent_blocker, assisting_blocker
	)
	_add_event(result, RallyEventModel.EventType.BLOCK,
		cont_contact_blocker.id if cont_contact_blocker != null else -1,
		cont_contact_blocker.display_name if cont_contact_blocker != null \
			else "Open block",
		_block_contact_point(geometric, set_target.x, 0.47),
		block_event_end, cont_block_contacts, block_quality,
		"Opponent block · exchange %d" % exchange_number,
		block_event_detail, {"side": "opponent", "outcome": block_outcome,
			"home_phase_targets": _cover_phase_map(
				players, lineup, defensive_plan, hitter.id, set_target,
				float(continuation_visible_attack_trajectory.get(
					"duration", continuation_attack_flight
				)),
				false, continuation_cover_intents,
			),
			"home_phase_intents": continuation_cover_intents,
			"signature_move": str(geometric.get("signature_move", "")),
			"signature_succeeded": bool(geometric.get("signature_succeeded", false)),
			"signature_charge": float(geometric.get("signature_charge", 0.0)),
			"signature_timing_quality": float(geometric.get(
				"signature_timing_quality", 0.0
			)),
			"signature_actor_id": int(geometric.get(
				"signature_actor_id", opponent_blocker.id \
					if opponent_blocker != null else -1
			)),
			"block_hands": str(block_result.get("block_hands", "neutral")),
			"block_hands_call": str(block_result.get("block_hands_call", "")),
			"block_hands_followed": bool(
				block_result.get("block_hands_followed", false)
			),
			## Where the ball crossed, and the intersection this contact is --
			## see `_block_contact_point`. Same three keys as the other two block
			## sites carry.
			"net_crossing_x": float(geometric.get("net_crossing_x", set_target.x)),
			"block_contact_kind": str(geometric.get("block_contact_kind", "")),
			"block_contact_actor_id": int(
				geometric.get("block_contact_actor_id", -1)
			),
			"block_contact_height_meters": geometric.get(
				"block_contact_height_meters", null
			),
			## And how high the ball was at the tape whether or not it was met,
			## so a beaten block is drawn where the ball went rather than where
			## the hands were.
			"ball_height_at_net_meters": geometric.get(
				"ball_height_at_net_meters", null
			),
			## The wall's reaches, beside the ball's height at the same moment.
			## Without both on one event "the ball cleared the hands" is not a
			## statement anything can check -- the reaches were on the ATTACK
			## event and the ball's height here, so a gate asserting the first
			## was reading an absent key and passing vacuously. Found by that
			## gate failing its own guard.
			"wall_reach_heights": geometric.get("wall_reach_heights", []),
			"block_wall_primary_id": int(
				opponent_blocker.id if opponent_blocker != null else -1
			),
			"block_wall_assist_id": int(
				assisting_blocker.id if assisting_blocker != null else -1
			),
			"block_intent": str(block_result.get("block_intent", "Balanced")),
			## When each blocker jumped, so playback can draw the apex where the
			## blocker actually put it. Without this the drawn jump was centred on
			## the contact for everybody, which makes a mistimed block look
			## perfectly timed -- the one thing `block_timing` is supposed to show.
			"block_jump_timing": geometric.get("block_jump_timing", {}),
			"block_miss_reason": str(geometric.get("block_miss_reason", "")),
		"primary_close": primary_close, "assist_close": assist_close,
		"primary_close_terms": Dictionary(
			block_result.get("primary_close_terms", {})
		),
		"assist_close_terms": Dictionary(
			block_result.get("assist_close_terms", {})
		),
		"assist_close_attempted": float(
			block_result.get("assist_close_attempted", 0.0)
		),
		"preset_window_seconds": block_result.get("preset_window_seconds", 0.0),
		"preset_share": block_result.get("preset_share", 0.0),
		"set_flight_seconds": block_result.get("set_flight_seconds", 0.0),
		"block_tempo": block_result.get("tempo", -1),
		"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
		"primary_position": Vector2(cont_wall.primary_position),
		"assist_position": Vector2(cont_wall.assist_position),
		"coverage_segments": block_result.coverage_segments,
		"setter_pull": block_result.setter_pull,
		"read_quality": block_result.read_quality,
		"event_time": _swing_reaches_net(
			continuation_visible_attack_trajectory, rally_clock
		),
		## The swing this block is contesting. The continuation block was the one
		## contact in the engine with no incoming arc at all, so playback had to
		## infer where the ball came from and the stamp above had nothing to derive
		## itself from.
		"incoming_trajectory": continuation_visible_attack_trajectory,
		"outgoing_trajectory": cont_block_trajectory})
	if continuation_hitter_point:
		## And on the continuation, where the same three outcomes end the same way.
		## Three paths reach a hitter's point at the net and leaving one of them
		## without a chase is how the dig asymmetry survived three passes.
		var cont_tool_event := result.events[-1] as RallyEvent
		if cont_block_contacts and opponent_team != null and cont_tool_event != null:
			var cont_tool_intents := {}
			var cont_tool_targets := _tool_pursuit_map(
				opponent_team.on_court_players(),
				opponent_team.current_lineup(),
				block_event_end,
				## Read back off the block event this path just wrote rather than
				## from a local: the continuation builds its deflection inline in
				## the metadata and never names it, and re-deriving it here would
				## be a second copy of one arc.
				float(Dictionary(cont_tool_event.metadata.get(
					"outgoing_trajectory", {}
				)).get("duration", 0.30)),
				[
					opponent_blocker.id if opponent_blocker != null else -1,
					assisting_blocker.id if assisting_blocker != null else -1,
				],
				true, cont_tool_intents,
			)
			if not cont_tool_targets.is_empty():
				cont_tool_event.metadata["opponent_phase_targets"] = cont_tool_targets
				cont_tool_event.metadata["opponent_phase_intents"] = cont_tool_intents
				cont_tool_event.metadata["tool_pursuit_reached"] = float(
					cont_tool_intents.values()[0]["progress"]
				)
		result.key_factors.append(_factor("attack_control"))
		## The continuation always runs the fallback assignment, so this is a
		## default-offense kill regardless of what play was called first ball --
		## the same reason the sibling path below already passes `kill_default`.
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": "Default T3 Outside",
		}, "kill_default")
	if blocked:
		return _finish(result, "blocked", false, hitter.id, {"hitter": hitter.display_name})
	if block_outcome == "recycle":
		## The same attack-coverage continuation as first ball. This path used to
		## fall through into opponent floor defence, so a ball visibly returned
		## to the home court was credited to the team that had just blocked it.
		var coverage_result := _resolve_attack_coverage(
			players, lineup, defensive_plan, hitter, block_event_end, block_quality
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
		var coverer_start: Vector2 = live_positions.get(
			coverer.id, block_event_end
		) if coverer != null else block_event_end
		var coverage_time := float(cont_block_trajectory.get("duration", 0.24))
		var coverer_move_time := _movement_time(
			coverer, coverer_start, block_event_end, "lateral"
		) if coverer != null else 4.0
		var coverer_reach := _reached_point(
			coverer, coverer_start, block_event_end, coverage_time, "lateral",
			0.0,
			GeometricAttackPromotionModel.pass_contact_height_meters(coverer),
			_incoming_ball_direction(
				cont_block_trajectory, block_event_end, attack_target
			),
		) if coverer != null else block_event_end
		var coverage_contact_state := _attack_coverage_contact_state(
			coverer, coverer_start, block_event_end, coverage_time,
		)
		if coverer != null:
			live_positions[coverer.id] = coverer_reach
		var coverage_contact_time := float(cont_block_trajectory.get(
			"end_time", rally_clock + coverage_time
		))
		var cont_coverage_second := _home_second_contact_candidates(players, lineup)
		var coverage_flight := _coverage_keep_alive_flight(
			coverer, block_event_end, cont_block_trajectory,
			coverage_contact_state.get("arrival", {}),
			_platform_body_velocity(
				coverer_start, coverer_reach, coverer_move_time, coverage_time,
			),
			coverage_contact_time,
			cont_coverage_second.candidates, cont_coverage_second.starts,
			defensive_plan, lineup.active_setter_id(),
			defensive_plan.setter_release_target(lineup.active_setter_id()),
		)
		var coverage_pass_target := block_event_end + Vector2(0.04, -0.05)
		var coverage_intent: Dictionary = _platform_intent(
			"attack_coverage", coverage_pass_target, "contact_offset",
			null, coverage_pass_target,
		)
		var coverage_incoming := {}
		if not coverage_flight.is_empty():
			coverage_pass_target = Vector2(coverage_flight.destination)
			coverage_intent = coverage_flight.platform_intent
			coverage_incoming = coverage_flight.authoritative_free_flight
		var coverage_meta := {
			"side": "home", "coverage": "attack",
			"platform_intent": coverage_intent,
			"blocked_hitter_id": hitter.id,
			"movement_start": coverer_start,
			"movement_target": coverer_reach,
			"movement_duration": coverer_move_time,
			"arrival": coverage_contact_state.arrival,
			"contact_posture": coverage_contact_state.posture,
			"pass_contact_height_meters": coverage_contact_state.contact_height,
			"incoming_trajectory": cont_block_trajectory,
			"event_time": coverage_contact_time,
		}
		if not coverage_flight.is_empty():
			_merge_coverage_flight_metadata(coverage_meta, coverage_flight)
		_add_event(
			result, RallyEventModel.EventType.ATTACK_COVERAGE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Attack coverage",
			block_event_end, coverage_pass_target,
			coverage_success, coverage_quality,
			"%s covers the block rebound" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% recycle control in exchange %d." % [
				roundi(coverage_quality * 100.0), exchange_number,
			],
			coverage_meta,
		)
		rally_clock = maxf(rally_clock, coverage_contact_time)
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		result.key_factors.append(_factor("attack_recycled"))
		if exchange_number >= MAX_EXCHANGES:
			var home_safety_win := coverage_quality \
				+ rng.randf_range(-0.18, 0.18) > 0.60
			return _finish(
				result,
				"long_rally_win" if home_safety_win else "long_rally_loss",
				home_safety_win,
				coverer.id if coverer != null else -1,
				{"hitter": hitter.display_name},
			)
		return _resolve_home_continuation(
			result, players, lineup, coverer, coverage_pass_target,
			opponent_team, defensive_plan, exchange_number + 1,
			coverage_quality * lerpf(
				1.0, BLOCK_DEFLECTION_CARRY, clampf(block_quality, 0.0, 1.0)
			),
			float(coverage_flight.get("duration", coverage_time)),
			float(continuation_visible_attack_trajectory.get("duration", 0.0)),
			coverage_incoming,
		)
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
	var cont_defense_time := maxf(float(
		cont_block_trajectory.get("duration", 0.0)
	), BLOCK_DEFLECTION_MIN_SECONDS) \
		if not cont_block_trajectory.is_empty() else float(
			continuation_visible_attack_trajectory.get(
				"duration", continuation_attack_flight
			)
		)
	var continuation_arriving_trajectory := cont_block_trajectory \
		if not cont_block_trajectory.is_empty() \
		else continuation_visible_attack_trajectory
	var cont_defense := _choose_opponent_defender(
		opponent_team, attack_target, cont_defense_time,
		continuation_arriving_trajectory, continuation_attack_spin,
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
		cont_read_modifier + cont_floor_bonus + cont_posture_read
			+ _dig_read_bonus(opponent_defender, hitter, block_outcome),
		CoverageModel.reception_body_penalty(
			opponent_defender, Dictionary(cont_defense.get("arrival", {})),
			attack_quality,
		),
		int(cont_defense.get("support_count", 0)),
	)
	## Published beside the pressure it is contested against, because a term
	## that decides a dig and cannot be read off the event is a term nobody can
	## attribute a dig to -- which is how three separate values on this branch
	## came to be spent invisibly.
	cont_dig_terms["read_error_meters"] = float(
		Dictionary(cont_defense.get("arrival", {})).get("read_error_meters", 0.0)
	)
	cont_dig_terms["contested_against"] = _attack_pressure(
		attack_quality, continuation_attack_trajectory
	)
	## A read is only worth having if something was recorded to read. The
	## first-ball dig logs its exposure here; this one never did, so the
	## familiarity term above would have stayed at its neutral value for the
	## whole match no matter how often the same hitter took the same lane.
	Familiarity.record_exposure(opponent_defender, cont_read_tags)
	var defense_quality := float(cont_dig_terms.quality)
	var cont_dig := _dig_outcome(
		opponent_defender, defense_quality,
		float(cont_dig_terms.contested_against),
	)
	cont_dig_terms["control"] = float(cont_dig.control)
	cont_dig_terms["edge"] = float(cont_dig.edge)
	var dug: bool = bool(cont_dig.dug)
	var cont_dig_control := float(cont_dig.control)
	var cont_dig_recovery := _dig_recovery(
		opponent_defender, cont_dig_terms, attack_quality,
		continuation_arriving_trajectory, float(cont_defense.distance_meters),
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
		cont_defense_time, "lateral",
		float(cont_defense.get("read_error_meters", 0.0)),
		GeometricAttackPromotionModel.pass_contact_height_meters(opponent_defender),
		_incoming_ball_direction(
			continuation_arriving_trajectory, attack_target,
			Vector2(continuation_arriving_trajectory.get(
				"start_position", attack_target
			)),
		),
	)
	if opponent_defender != null:
		opponent_live_positions[opponent_defender.id] = transition_defender_reach
	var cont_dig_time := float(continuation_arriving_trajectory.get(
		"end_time", rally_clock + cont_defense_time
	))
	rally_clock = maxf(rally_clock, cont_dig_time)
	var cont_desired_target := attack_target + Vector2(0.04, -0.03)
	var cont_dig_setter := opponent_team.setter() as VolleyballPlayer
	var cont_dig_release := _opponent_setter_release_target(opponent_team)
	var cont_dig_intent := _platform_intent(
		"controlled_dig", cont_dig_release, "release_seat",
		cont_dig_setter,
		Vector2(opponent_live_positions.get(
			cont_dig_setter.id if cont_dig_setter != null else -1,
			cont_dig_release,
		)),
	)
	var cont_dig_pass := {}
	if dug:
		cont_dig_pass = _dig_pass_result(
			opponent_defender, attack_target, cont_desired_target,
			cont_dig_control,
			## The arrival, which was `{}` -- so `reach_margin` defaulted to 0.0 and
			## `stretched` computed a constant 0.294 on every continuation dig,
			## whatever the defender actually did. `PLATFORM_CONTACT.md` section 4b
			## traced it and stopped; it is not a design question, because
			## `cont_defense` carries the arrival and the two lines above already
			## read it.
			##
			## Measured over 600 rallies before the repair: 9 resolved continuation
			## passes, reach margins spanning -0.160 to 1.866, and the stretch they
			## imply is **0.000 at the median** -- so 8 of the 9 were charged a
			## stretch penalty for a ball they reached comfortably. A term that
			## cannot vary is not a weak term; it is an absent one wearing a weight.
			Dictionary(cont_defense.get("arrival", {})),
			str(last_dig_posture),
			continuation_arriving_trajectory,
			transition_defender_start.distance_to(transition_defender_reach)
				* CourtConstants.COURT_WIDTH_METERS,
			opponent_team.setter() as VolleyballPlayer, cont_dig_time,
			_platform_body_velocity(
				transition_defender_start, transition_defender_reach,
				float(cont_defense.travel_time), cont_defense_time,
			),
			cont_dig_intent,
		)
		cont_desired_target = Vector2(cont_dig_pass.destination)
	_add_event(result, RallyEventModel.EventType.DIG, opponent_defender.id,
		opponent_defender.display_name, attack_target,
		cont_desired_target, dug, cont_dig_control,
		"Opponent dig · exchange %d" % exchange_number,
		"Contact 1 of 3 · %d%% control." % roundi(cont_dig_control * 100.0),
		{"side": "opponent",
			"platform_intent": cont_dig_intent,
			"incoming_trajectory": continuation_arriving_trajectory,
			"movement_start": transition_defender_start,
			"movement_target": transition_defender_reach,
			## The dig happens when the swing reaches the floor, which the
			## swing's own trajectory already states.
			"contact_recovery": cont_dig_recovery,
			"contact_control": last_dig_control,
			"incoming_force": last_dig_force,
			"incoming_speed_mps": last_dig_speed,
			"contact_posture": last_dig_posture,
			## The ball this dig actually put up. Published here rather than
			## invented later, so the setter and the drawing share one object.
			"outgoing_trajectory": cont_dig_pass.get("trajectory", {}),
			"pass_apex_meters": cont_dig_pass.get("pass_apex_meters", 0.0),
			"pass_contact_height_meters": cont_dig_pass.get(
				"pass_contact_height_meters", 0.0
			),
			"set_contact_height_meters": cont_dig_pass.get(
				"set_contact_height_meters", 0.0
			),
			"pass_duration_seconds": cont_dig_pass.get("duration", 0.0),
			"target_error_meters": cont_dig_pass.get("target_error_meters", 0.0),
			"pass_spoil": cont_dig_pass.get("spoil", 0.0),
			"platform_contact": cont_dig_pass.get("platform_contact", {}),
			"reach_margin_meters": last_dig_reach_margin,
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
		result, players, lineup, hitter, cont_desired_target,
		opponent_team, defensive_plan, exchange_number + 1, cont_dig_control,
		false, opponent_defender.id,
		float(cont_dig_pass.get("set_contact_height_meters", NAN)),
		float(cont_dig_pass.get("pass_apex_meters", 0.0)),
		Dictionary(cont_dig_pass.get("trajectory", {})),
		float(continuation_attack_trajectory.get("duration", 0.0)),
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
	## Who is going to swing, for the half of a blocker's read that is the arm
	## rather than the play. Optional so a caller that has not chosen a hitter yet
	## gets exactly the read this had before.
	hitter: VolleyballPlayer = null,
	set_height_extra_meters: float = 0.0,
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
		read_total += _blocker_read_quality(
			reader, tempo, set_quality, setter_x, hitter,
			set_height_extra_meters,
		)
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
	var commitment_principle := float(opponent_principles.block_commitment)
	close_time += (commitment_principle - 0.5) * 0.18
	var primary_terms := _blocker_close_terms(
		primary, lineup, attack_x, close_time
	)
	var primary_close := float(primary_terms.fraction)
	## The assist cannot have crossed the court before the setter touched it.
	##
	## Both blockers were handed the same budget, and that budget is mostly
	## *pre-set*: measured, the window ahead of the set runs 0.78-1.07 s and
	## barely moves with tempo, while the set's own flight runs 0.20-0.99 s. At
	## tempo 0 that is 79% of the closing time credited before the ball exists.
	##
	## For the primary that is fair, and deliberately untouched here. The primary
	## is by definition the blocker already nearest the attacked lane, so their
	## pre-set time is spent reading rather than travelling. The assist is the one
	## who has to cross a slot, and crediting them with having crossed it before
	## the lane was chosen is what made a first-tempo ball draw a double block
	## 37% of the time.
	##
	## Anticipation still pays -- `preset_share` is the read, and it stays. What
	## it now buys is bounded by whether there is time to *finish* the crossing
	## once the set confirms it. A high ball leaves the whole window usable; a
	## first-tempo ball leaves almost none, which is the entire reason a quick set
	## beats a double block, and the reason a zero ball has to be committed to
	## rather than read.
	var assist_reaction := clampf(
		maxf(set_flight_time, 0.0) / ASSIST_COMMIT_FLIGHT_SECONDS, 0.0, 1.0
	)
	## Only the *reactive* share is bounded by the flight. What the wall
	## already committed to survives whatever the tempo.
	var assist_usable_preset := lerpf(
		assist_reaction, 1.0,
		_assist_committed_share(commitment_principle, read_quality),
	)
	var assist_close_time := close_time \
		- maxf(preset_window_seconds, 0.0) * preset_share \
		* (1.0 - assist_usable_preset)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	var assist_net_x := 0.5
	## Kept whether or not the candidate survives the cut below. `assist_close`
	## is zeroed when the best available blocker could not get there, so its mean
	## silently mixes "nobody travelled" with "somebody travelled and failed" --
	## and those are the two readings the saturation question needs told apart.
	var assist_terms := {}
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var candidate_terms := _blocker_close_terms(
			candidate, lineup, attack_x, assist_close_time
		)
		var close_fraction := float(candidate_terms.fraction)
		if close_fraction > assist_close or assist_terms.is_empty():
			assist_terms = candidate_terms
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
			assist_net_x = float(candidate_terms.get("closed_net_x", 0.5))
	var assist_attempt: VolleyballPlayer = assist
	var assist_close_attempted := assist_close
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
		assist_net_x = 0.5
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	## Positions as well as skills: an assist that closed to the far side of the
	## tape is not the same wall as one that closed shoulder to shoulder.
	var block_quality := _block_wall_quality(
		primary_skill, assist_skill,
		float(primary_terms.get("closed_net_x", 0.5)), assist_net_x,
	)
	return {
		"primary": primary,
		"assist": assist,
		"assist_attempt": assist_attempt,
		"primary_close": primary_close,
		"assist_close": assist_close,
		## The reached positions, so the geometric wall stands where the blockers
		## closed to rather than where they began.
		"primary_net_x": float(primary_terms.get("closed_net_x", 0.5)),
		"assist_net_x": assist_net_x,
		## Itemised, the same way the home wall reports it.
		"primary_close_terms": primary_terms,
		"assist_close_terms": assist_terms,
		## The budget's two halves, kept apart. `available_time` alone cannot say
		## whether a blocker had time because the ball was slow or because they
		## were credited with the whole second contact before it happened, and
		## those are different problems with different fixes.
		"preset_window_seconds": maxf(preset_window_seconds, 0.0),
		"preset_share": preset_share,
		"set_flight_seconds": maxf(set_flight_time, 0.0),
		"tempo": tempo,
		## Before the 0.34 cut, so a wall with no second blocker is
		## distinguishable from a second blocker who did not arrive.
		"assist_close_attempted": assist_close_attempted,
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


## Where the ball met the tape, as the realised contact rather than a position
## assembled beside it.
##
## `CONTACT_AND_BALL_FLIGHT.md` §5: a realised contact is the single point where
## the incoming segment ends and the outgoing one begins, so it has to *be* the
## intersection that was proved. `AttackResolutionModel._block_contact` proves
## one -- height against reach, lateral against half width, timing folded into
## both -- and publishes the crossing it cut on. All three block events placed
## the contact at the **hitter's** contact x instead, which is where the wall was
## staged and not where the ball went: measured over 300 rallies, mean 0.278 m
## apart, worst 0.784 m, and wider than a blocker's own hand on 17.4% of the
## contacts that published both. See
## `docs/review/block_authority/BEFORE_block_contact_authority.txt`.
##
## `fallback_x` is that hitter contact, and it stays as the fallback for one
## reason: with `ENABLE_GEOMETRIC_ATTACK` shut there is no crossing to read, and
## the legacy contest stages the wall on the hitter's lane by construction, so
## the hitter's x is then the best available statement rather than a wrong one.
static func _block_contact_point(
	geometric: Dictionary, fallback_x: float, net_plane_y: float
) -> Vector2:
	return Vector2(
		clampf(float(geometric.get("net_crossing_x", fallback_x)), 0.0, 1.0),
		net_plane_y,
	)


## Whose hands, when the ball met any.
##
## The event named the formation's *primary* blocker -- the one who closed
## furthest -- and `_block_contact` picks by centrality, because the ball meets
## the surface in its path rather than the tallest or the best-closed one. Its
## own note records the cost of getting that wrong: 32% of two-blocker contacts
## credited to a less central hand than the ball met, which read as hitters
## finding the outside hand and made a second blocker easier to tool.
##
## Falls back to the primary when nothing was touched, because a beaten block is
## still an event about the blocker who went up, and there is no contact to take
## an actor from.
static func _block_contact_blocker(
	geometric: Dictionary,
	primary: VolleyballPlayer,
	assist: VolleyballPlayer,
) -> VolleyballPlayer:
	var proven := int(geometric.get("block_contact_actor_id", -1))
	if proven < 0:
		return primary
	if assist != null and assist.id == proven:
		return assist
	## Including the primary explicitly rather than falling through to it, so
	## that the one case this cannot serve -- a proven id belonging to neither
	## body this event holds -- is the same return as "no contact" and is caught
	## by the gate rather than hidden here. The event publishes
	## `block_contact_actor_id` alongside its actor for exactly that check.
	return primary


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
	## What the hands mean to do, decided before the bands are read because it
	## moves one of them. The margin is the block's own lead over the swing, which
	## is what a blocker in the air can feel.
	var hands_intent := _block_hands_intent(
		formation.get("primary") as VolleyballPlayer, contest - attack_quality,
		primary_close, str(formation.get("hands_instruction", "")),
	)
	var hands := str(hands_intent.hands)
	resolved["block_hands"] = hands
	resolved["block_hands_call"] = str(hands_intent.call)
	resolved["block_hands_followed"] = bool(hands_intent.followed)
	var hands_stuff_shift := 0.0
	match hands:
		"kill":
			hands_stuff_shift = BLOCK_KILL_STUFF_BONUS
		"soft":
			hands_stuff_shift = BLOCK_SOFT_STUFF_PENALTY
	var stuff_bar := attack_quality + BLOCK_STUFF_MARGIN \
		+ float(intent_shift.stuff) + hands_stuff_shift
	var outcome := "miss"
	if contest > stuff_bar and primary_close >= 0.78:
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


## Where a ball deflected off the wall comes down on the hitter's own side.
##
## It used to be drawn around the *set* target with a spread widened by a block
## quality scalar, which is the pre-geometric block API surviving into a world
## that knows where the hands are. The scalar and the coordinates were being
## published side by side in the same dictionary -- `_form_opponent_block`
## returns `primary_net_x`, `assist_net_x` *and* `quality` -- and this read the
## scalar.
##
## A deflection comes off the hands, so it leaves from where the ball met the
## tape, not from where the setter put the ball. And how far back it carries is
## a question about how solidly it was met: a ball taken well below the top of
## the hands is stopped and drops near the net, while one that grazes the top
## keeps most of its pace and travels. `block_depth_below_reach_meters` is
## exactly that quantity and is already forwarded here.
func _attack_coverage_target(
	set_target: Vector2,
	block_quality: float,
	geometric: Dictionary,
) -> Vector2:
	var depth: Variant = geometric.get("block_depth_below_reach_meters", null)
	if depth == null:
		## No geometry on this swing -- the legacy contest is still the official
		## resolver when the promotion flag is closed.
		var legacy_spread := lerpf(0.14, 0.05, clampf(block_quality, 0.0, 1.0))
		return Vector2(
			clampf(set_target.x + rng.randf_range(-legacy_spread, legacy_spread),
				0.08, 0.92),
			rng.randf_range(0.54, 0.70),
		)
	## 1 for a ball off the fingertips, 0 for one buried under the hands.
	var carry := 1.0 - clampf(
		float(depth) / BLOCK_DEFLECTION_STOP_METERS, 0.0, 1.0
	)
	## Sideways scatter for the same reason: a solid contact goes back the way it
	## came, a glancing one squirts off the hand. The range is the one the scalar
	## version used, now keyed to the contact rather than to a skill.
	var spread := lerpf(0.05, 0.14, carry)
	return Vector2(
		clampf(
			float(geometric.get("net_crossing_x", set_target.x))
				+ rng.randf_range(-spread, spread),
			0.08, 0.92,
		),
		lerpf(BLOCK_DEFLECTION_NEAR_Y, BLOCK_DEFLECTION_FAR_Y, carry),
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
	## **The run-up's clock is bounded by the run-up, not by the set.**
	##
	## The same cap `ApproachMechanicsSystem.evaluate_takeoff` applies, on the
	## path that actually serves the home side -- and the first attempt put it
	## only on the other one, which is why the displacement gates came back
	## bit-identical and proved nothing.
	##
	## A hitter given a 1.5 s high ball does not run for 1.5 s. They take three or
	## four steps and spend the rest standing at the back of their runway. Handing
	## the whole hang time to the run-up meant every extra second of set height
	## bought another second of running, so once sets were timed honestly no
	## hitter could be made late by anything.
	var run_up_window := minf(
		set_flight_seconds, ApproachMechanicsModel.APPROACH_RUNUP_SECONDS
	)
	return {
		"tempo": tempo,
		## The run-up's clock, which is the one the tempo chain is about.
		"available_seconds": run_up_window,
		## What the ball actually gave them, kept beside it: the difference between
		## these two is time spent waiting, and a reader who sees only the capped
		## figure would think a high ball and a quick arrived together.
		"set_flight_seconds": set_flight_seconds,
		"required_seconds": run_up,
		"deficit_seconds": run_up - run_up_window,
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


## One setter trying to meet one hitter's approach rhythm.
##
## The play's tempo remains the expected relationship; the hitter's actual
## runway supplies its duration. Team structure only takes agency at the extreme
## rigid end, while setter skill and pair familiarity decide how closely the
## release meets what this hitter normally does.
func _hitter_led_set_timing(
	setter: VolleyballPlayer,
	hitter: VolleyballPlayer,
	tempo: int,
	lane: String,
	set_target: Vector2,
	opponent_side: bool,
	natural_flight_seconds: float,
	set_quality: float,
	principles: Resource,
	pair_read: float,
	system_familiarity: float,
	salt: String,
) -> Dictionary:
	var body_target := SetPathReadModelRef.body_position(
		hitter, set_target, not opponent_side
	)
	var approach_start := ApproachMechanicsModel.approach_start_position(
		body_target, lane, &"opponent" if opponent_side else &"home",
		null, ApproachMechanicsModel.APPROACH_DEPTH, tempo,
	)
	var runup := _movement_time(
		hitter, approach_start, body_target, "transition"
	)
	var intent := ApproachMechanicsModel.tempo_intent(hitter, tempo, runup)
	intent["ideal_approach_start"] = approach_start
	intent["expected_ball_contact"] = set_target
	intent["expected_body_contact"] = body_target
	var variation := float(principles.tempo_variation) \
		if principles != null else 0.5
	var strictness := clampf(
		(1.0 - variation) * 0.55
			+ clampf(system_familiarity, 0.0, 1.0) * 0.30
			+ _rating(setter, "tactical_discipline") * 0.15,
		0.0, 1.0,
	)
	var stable := float(posmod(hash("%d|tempo|%d|%d|%s" % [
		rally_seed, setter.id if setter != null else -1,
		hitter.id if hitter != null else -1, salt,
	]), 2001)) / 1000.0 - 1.0
	return ApproachMechanicsModel.coordinate_tempo(
		intent, setter, pair_read, strictness,
		natural_flight_seconds, set_quality, stable,
	)


## Reconcile the set's published shape with the hitter-led clock. Presentation
## derives height from the two contacts and duration, so retaining the old apex
## after changing time would describe a second, impossible parabola.
static func _retimed_set_arc(
	arc: Dictionary,
	duration_seconds: float,
	release_height_meters: float,
	hitter_contact_height_meters: float,
) -> Dictionary:
	var retimed := arc.duplicate(true)
	var duration := maxf(duration_seconds, BallFlightModel.MIN_FLIGHT_DURATION)
	var apex := BallFlightModel.apex_between(
		release_height_meters, hitter_contact_height_meters, duration
	)
	retimed["duration_seconds"] = duration
	retimed["apex_absolute_meters"] = apex
	retimed["apex_height_meters"] = maxf(apex - release_height_meters, 0.0)
	return retimed


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


## Where an untouched set lands. It keeps travelling behind the hitter on the
## attacking side rather than being redrawn as a strike over the tape.
func _missed_set_drop_target(
	ball_contact: Vector2, attacking_negative_y: bool
) -> Vector2:
	var side_direction := 1.0 if attacking_negative_y else -1.0
	var lateral_sign := -1.0 if posmod(
		hash("%d|missed-set|%.4f" % [rally_seed, ball_contact.x]), 2
	) == 0 else 1.0
	var target := ball_contact + Vector2(
		lateral_sign * MISSED_SET_DROP_LATERAL_METERS
			/ CourtConstants.COURT_WIDTH_METERS,
		side_direction * MISSED_SET_DROP_DEPTH_METERS
			/ CourtConstants.COURT_LENGTH_METERS,
	)
	target.x = clampf(target.x, 0.02, 0.98)
	if attacking_negative_y:
		target.y = clampf(target.y, CourtConstants.NET_Y + 0.01, 0.98)
	else:
		target.y = clampf(target.y, 0.02, CourtConstants.NET_Y - 0.01)
	return target


func _missed_set_drop_trajectory(
	ball_contact: Vector2, landing: Vector2, start_time: float
) -> Dictionary:
	return _ball_trajectory(
		"missed_set", ball_contact, landing, MISSED_SET_DROP_SECONDS, 0.0,
		start_time, MISSED_SET_DROP_VERTICAL_MPS,
	)

## The same three numbers for a serve, and the same reasoning behind them.
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
	## The ball being read, and what was put on it. Optional so the callers that
	## have no flight in hand keep the perfect knowledge they always had rather
	## than silently getting a zero-error one; see `_read_error_meters`.
	incoming_trajectory: Dictionary = {},
	incoming_spin: Dictionary = {},
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
		opponent_live_positions, -1.0,
		_ready_facings(opponent_live_positions.keys(), &"opponent"),
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
	## The claim was made on where the ball is going; what it cost this defender
	## to be wrong about that is paid here, at the end of the journey.
	var read_error := _read_error_meters(
		claimant, incoming_trajectory, incoming_spin, rally_clock
	)
	arrival = _read_adjusted_arrival(arrival, read_error)
	return {
		"player": claimant,
		"claimed": claimed,
		"start": start,
		## The true journey, not the mistaken one. The read error is carried by
		## the adjusted `arrival` alone -- exactly as the home floor defence
		## carries it -- because adding it here as well charged this side twice
		## and opened a dig-rate gap of 0.231 against the home side's 0.100.
		## Two sides of one net have to be penalised through one mechanism.
		"distance_meters": fallback_margin,
		"travel_time": travel_time,
		"reach_margin_meters": float(
			arrival.get("reach_margin_meters", -fallback_margin)
		),
		"edge_ratio": float(arrival.get("edge_ratio", 1.2)),
		"support_count": int(claim.get("support_count", 0)),
		"read_error_meters": read_error,
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
	## How far short of the target this mover stops because they read the ball
	## somewhere else. Defensive call sites only -- see `_read_error_meters` --
	## and defaulted to nothing so the approach and coverage sites keep the exact
	## arrival they have always had.
	shortfall_meters: float = 0.0,
	## **Where the ball is met, and where it came from.** M3: a voli does not
	## stand on the ball, they get behind it and play it in front of their own
	## body. `VolleyballPlayer.contact_offset_meters` says how far in front, from
	## the shoulder anchor the body data already carries and this voli's own arm;
	## `incoming_direction` says which way "behind" is, in court space.
	##
	## Both default to nothing, and with either absent the arrival is exactly the
	## one every caller had before -- the same shape `entry_facing` used to land
	## before every caller was migrated. See `docs/review/BODY_CENTRE_SCOPE.md`.
	contact_height_meters: float = 0.0,
	incoming_direction: Vector2 = Vector2.ZERO,
) -> Vector2:
	## **Every journey in the game passes through here**, which is what makes this
	## the honest place to charge for one. Charged on the distance *asked for*
	## rather than the distance reached, because a defender who sprints and comes
	## up half a metre short has done the running either way -- and charging the
	## arrival would refund the hardest efforts in the sport.
	if mover != null:
		_charge_exertion(
			mover,
			RallyKinematics.court_distance_meters(start, target)
				* TRAVEL_COST_PER_METER
				* (SPRINT_COST_MULTIPLIER if mode != "lateral" else 1.0),
		)
	if mover == null or available_time <= 0.0:
		return start
	if _movement_time(mover, start, target, mode) <= available_time:
		## **The body has to agree with the verdict.**
		##
		## Promoting the read model made a defender's *arrival* worse without
		## making their *journey* shorter, so the simulator could score a dig
		## unreachable while playback still walked the defender onto the ball --
		## which is the exact defect `every defender beaten to the ball stops
		## short of it` was written to catch, and it caught it. A defender who
		## went to the wrong place is drawn at the wrong place.
		if shortfall_meters <= 0.0:
			return _body_behind_contact(
				mover, target, contact_height_meters, incoming_direction
			)
		var lane := target - start
		if lane.length_squared() < 0.000001:
			return target
		var lane_metres := CoverageModel.court_distance_meters(start, target)
		return start.lerp(target, clampf(
			1.0 - shortfall_meters / maxf(lane_metres, 0.01), 0.0, 1.0
		))
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


## **Where the body stands, given where the contact is.**
##
## M3's whole content in one place. A passer gets *behind* the ball -- further
## along its own line of travel -- and plays it in front of their platform, so
## the body sits `contact_offset_meters` beyond the contact point along the
## incoming direction. The offset is Pythagoras from the shoulder anchor
## `BodyTypeModels.UNIVERSAL_RATIOS` already authors and this voli's own arm, and
## it is zero above the shoulder and zero at the floor because the geometry says
## so rather than because a band was drawn.
##
## Returns the contact point unchanged when either input is absent, which is what
## keeps an un-migrated caller on exactly its old arrival.
func _body_behind_contact(
	mover: VolleyballPlayer,
	contact: Vector2,
	contact_height_meters: float,
	incoming_direction: Vector2,
) -> Vector2:
	if mover == null or contact_height_meters <= 0.0:
		return contact
	if incoming_direction.length_squared() < 0.000001:
		return contact
	var offset := mover.contact_offset_meters(contact_height_meters)
	if offset <= 0.0:
		return contact
	var heading := incoming_direction.normalized()
	## Metres out, court units back: the offset is a real distance and the court
	## is not square, so it cannot be added to a normalised position directly.
	return Vector2(
		clampf(contact.x + heading.x * offset / CourtConstants.COURT_WIDTH_METERS, 0.0, 1.0),
		clampf(contact.y + heading.y * offset / CourtConstants.COURT_LENGTH_METERS, 0.0, 1.0),
	)


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
		if candidate == null or not _can_enter_attack(candidate):
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
		var lane := CourtConstants.lane_at_x(candidate_contact.x)
		var decision_available := set_flight_time \
			+ DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS
		var rescue_height := _set_rescue_height_meters(
			candidate_travel, decision_available
		)
		var terms := _setter_option_terms(
			setter, candidate, set_quality, candidate_travel, decision_available,
			rescue_height, -quick_demand * (1.0 - set_quality), false,
			-current_match_flow, lane,
		)
		## Preserve one draw per candidate from the old evaluator, but make its
		## impact depend on the setter's judgment rather than giving every setter
		## the same +/-0.12 blindness.
		var option_noise := rng.randf_range(-0.12, 0.12) \
			* (1.0 - float(terms.judgment))
		var option_score := float(terms.score) + option_noise
		var option := terms.merged({
			"player": candidate, "start": candidate_start,
			"contact": candidate_contact, "travel_time": candidate_travel,
			"lateness": lateness, "score": option_score,
			"option_noise": option_noise,
		}, true)
		every_option.append(option)
		if lateness <= 0.0:
			reachable.append(option)
	## An entire side being on the floor is an emergency rather than an indexing
	## error. It should be practically unreachable in ordinary play; retain the
	## old best-hitter fallback only for that terminally depleted case.
	if every_option.is_empty():
		var emergency := opponent_team.best_hitter() as VolleyballPlayer
		var emergency_start: Vector2 = opponent_live_positions.get(
			emergency.id, opponent_team.court_position(emergency.id, "transition")
		)
		var emergency_contact := _opponent_attack_contact(opponent_team, emergency)
		every_option.append({
			"player": emergency,
			"start": emergency_start,
			"contact": emergency_contact,
			"travel_time": _movement_time(
				emergency, emergency_start, emergency_contact, "transition"
			),
			"lateness": 0.0,
			"score": -1.0,
			"recovery_emergency": true,
		})
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
		"rescue_height_meters": float(chosen.get("rescue_height_meters", 0.0)),
		"option_evaluation": chosen.duplicate(true),
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


## `stage_server` is false when the caller wants a *resting* arrangement rather
## than the opening snapshot. The serve-origin placement below is correct for the
## first frame of a rally and wrong for anywhere else -- a base posture that puts
## somebody behind the baseline would have them walk back off the court every
## time the ball crossed the net.
## **Where a side stands when the whistle goes.**
##
## FD-001 / FD-004. A receiving side used to be placed on the rotation grid --
## or on the plan's serve-receive zone where one existed -- while
## `_receive_formation_map` separately published, onto the reception event, the
## shape the six *actually take up* to receive: passers on their seams, front row
## off the passing lanes, setter at the release. Two answers to one physical
## question, and gameplay believed neither of the drawn one: the reception claim
## builds `reception_origins` out of `live_positions`, so a receiver read the
## serve from the rotation grid while a viewer watched them stand in formation.
##
## The formation is the answer. A receiving side is in its receive shape *before*
## the ball is struck -- that is what serve receive is -- so the shape belongs in
## the state the whistle starts from rather than in a map drawn afterwards. Now
## the same call seeds `live_positions`, `result.initial_home_positions` (which
## is what the 3D court spawns actors at) and the origin of every later traversal.
##
## `players` is needed only to pick the passers. Empty keeps the old rotation-grid
## behaviour, and `home_base_positions` deliberately passes nothing: a *defending*
## base is not a receive shape and asking for one there would have been the third
## representation rather than the removal of the second.
func _initial_home_positions(
	lineup: RotationLineup,
	defensive_plan: Resource,
	receiving: bool,
	stage_server: bool = true,
	players: Array = [],
	out_intents: Dictionary = {},
) -> Dictionary:
	var positions := {}
	var formation := {}
	if receiving and not players.is_empty():
		formation = _receive_formation_map(lineup, players, false, out_intents)
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
		if stage_server and not receiving and slot_number == 1:
			positions[player_id] = CourtConstants.serve_origin(position.x, true)
			continue
		if receiving and formation.has(player_id):
			position = Vector2(formation[player_id])
		if defensive_plan != null:
			if receiving:
				## **`enabled` is checked here now, and was not.**
				##
				## `_initial_opponent_positions` below has always required a zone to
				## be enabled before it moves anybody; this side took any zone that
				## existed. So a serve-receive zone the manager had switched off
				## still relocated a home receiver and never an opponent one --
				## the same shape of home/opponent drift the block's stale swing
				## turned out to be, found while tracing this one.
				##
				## An enabled zone still wins over the formation, and should: the
				## formation is the structural default and the zone is the manager
				## saying otherwise. That is one resolution, not two geometries.
				var zone: Resource = defensive_plan.zone_for(
					player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
				)
				if zone != null and bool(zone.enabled):
					position = Vector2(zone.center)
			else:
				position = defensive_plan.defender_position(player_id, position)
		positions[player_id] = position
	return positions


## `stage_server` as above: false asks for the resting arrangement, which must
## not park anybody behind their own baseline.
func _initial_opponent_positions(
	opponent_team: Resource,
	receiving: bool,
	stage_server: bool = true,
	out_intents: Dictionary = {},
) -> Dictionary:
	var positions := {}
	if opponent_team == null:
		return positions
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	var reception_zones: Dictionary = {}
	var formation := {}
	## The mirror of the home side's seeding above, and mirrored deliberately:
	## the defect being closed here is one representation of a fact existing in
	## two places, and giving the two sides different ways to take up a receive
	## shape would rebuild it sideways.
	if receiving:
		reception_zones = _opponent_reception_coverage(opponent_team).zones
		if opponent_lineup != null:
			formation = _receive_formation_map(
				opponent_lineup, opponent_team.players, true, out_intents
			)
	var serving_id := opponent_lineup.player_at_slot(1) \
		if stage_server and opponent_lineup != null and not receiving else -1
	for player_resource in opponent_team.on_court_players():
		var player := player_resource as VolleyballPlayer
		if player == null:
			continue
		var position: Vector2 = opponent_team.court_position(player.id, "defense")
		if formation.has(player.id):
			position = Vector2(formation[player.id])
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
	## **One region for the whole side, resolved once.** A kit belongs to a club,
	## and reading each player's own `club_region` would dress a squad whose data
	## has drifted -- a half-applied transfer, a generated voli nobody assigned --
	## in a different shirt per body. `side_region` takes the mode, so one
	## outlier cannot split a team.
	##
	## Only the home side carries one. The opposition wears the universal change
	## strip by direction, and plumbing a region here that nothing reads would be
	## a knob with no range, which this file has enough of already.
	var home_region := RegionalKits.side_region(players)
	for player in players:
		profiles[player.id] = _physical_playback_profile(player, home_region)
	if opponent_team != null:
		for player_resource in opponent_team.on_court_players():
			var player := player_resource as VolleyballPlayer
			if player != null:
				profiles[player.id] = _physical_playback_profile(player, "")
	return profiles


func _physical_playback_profile(
	player: VolleyballPlayer, club_region: String = ""
) -> Dictionary:
	return {
		"height_cm": player.height_cm,
		## Which club's strip this voli is drawn in. Empty for the opposition and
		## for every caller that has no club, which keeps the palette colours
		## those were drawn against.
		"club_region": club_region,
		"wingspan_cm": player.wingspan_cm,
		"stride_length_m": player.stride_length_m,
		## What this player is. Generation has assigned a body type since it
		## existed, and it reached height, mass, wingspan and six attribute
		## ceilings -- everything except the one place a player is actually
		## looked at.
		"body_type": player.body_type,
		## For the nametag, which used to read `name · 200 cm · R`. Height and
		## handedness are already visible -- one in how tall the body is drawn,
		## the other in which arm swings -- so the tag was spending both its
		## fields restating the picture and never saying who this is on the
		## court. Position is the one thing a body cannot show you.
		"position_code": player.primary_position,
		"standing_reach_meters": player.standing_reach_cm() / 100.0,
		"jumping_reach_meters": player.jumping_reach_cm() / 100.0,
		## How fast this body can actually be moved across the floor.
		##
		## Playback had no notion of a speed limit: it lerped every planned leg
		## across whatever window the ball happened to be in the air for. Measured
		## over 600 rallies that printed a p99 of 13.4 m/s and a worst case of
		## 57.1 m/s -- a 4.49 m transition drawn inside a 0.079 s attack-to-block
		## window. Bolt runs at 12.
		##
		## The same `LocomotionModel.maximum_speed` the engine times traversals
		## with, so the drawn pace and the simulated one come from one model rather
		## than from a constant invented in the view. `TRANSITION` because that is
		## the mode a player crossing the court between phases is in; fatigue is
		## already inside `cadence_hz`, so a tired voli is drawn tired.
		"transition_speed_mps": LocomotionModel.maximum_speed(
			player, RallyPlayerState.MovementMode.TRANSITION
		),
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
## Walk a side **into** a defensive shape instead of teleporting them into it.
##
## `_floor_phase_positions` below computes the shape the plan asks for -- zones,
## depth, seam, the wall's two shoulders -- and every one of its three callers
## then wrote that shape straight into the live position map. So the defence
## *arrived* in the diagram the instant the attacker swung, from wherever the
## previous phase had left them, across any distance, for free.
##
## The C0 action-window census counted the consequence exactly: of 1,350 volis
## placed on an `ATTACK` event, **none** had spent any time getting there. Every
## other journey in this file goes through `_reached_point`; the defensive base
## was the one that did not, which is why it was also the only one that always
## succeeded.
##
## This is gameplay and not drawing. The shape is handed to
## `CoverageModel.choose_claimant` as the defenders' real positions for the dig
## reach check, so a defender who had no time to get to their zone was still
## reaching from inside it.
##
## C5 states the rule in one sentence -- "the attack launch may change who
## ultimately owns the ball, but it does not create the defender's entire
## pre-swing position from scratch" -- and adds a second: partial establishment
## stays partial. `_reached_point` already does that. A defender who cannot cover
## the distance in the set's flight stops where the time ran out.
##
## **Nothing new is authored here.** The traversal authority, the cost per metre
## and the lateral mode are the ones every other off-ball leg already uses; the
## window is the set flight the defence genuinely has. What changes is that the
## journey is now taken rather than assumed, and defensive establishment is
## billed the exertion it always cost in the sport and never cost here.
func _establish_shape(
	shape: Dictionary,
	roster: Array,
	live: Dictionary,
	window_seconds: float,
	out_intents: Dictionary = {},
) -> Dictionary:
	var by_id := {}
	for entry in roster:
		var candidate := entry as VolleyballPlayer
		if candidate != null:
			by_id[candidate.id] = candidate
	var established := {}
	for raw_player_id in shape:
		var player_id := int(raw_player_id)
		var target := Vector2(shape[raw_player_id])
		var player := by_id.get(player_id, null) as VolleyballPlayer
		## No window and no body are both "we cannot say", and the honest answer
		## to that is the shape as asked for -- the behaviour every caller had.
		if player == null or window_seconds <= 0.0:
			established[player_id] = target
			continue
		var here: Vector2 = live.get(player_id, target)
		## Lateral, not a sprint. Taking a defensive base is a read and a shuffle;
		## the two volis who genuinely sprint on this ball are closing the wall,
		## and the block staging has already moved them before this runs -- so
		## their remaining distance here is nearly nothing and they are charged
		## nearly nothing.
		var reached := _reached_point(player, here, target, window_seconds, "lateral")
		established[player_id] = reached
		## **The shape's own label wins if it has one.**
		##
		## A defensive base has one reason and every voli in it shares it, so
		## `defending` is the whole story. A receive formation does not:
		## `_receive_formation_map` separates the passers from the front-row
		## volis staging off the passing lanes from the setter, and its own note
		## says the distinction exists so the cognition layer does not have to
		## re-derive from a coordinate a fact the formation builder already knew.
		## Stamping `defending` over that would throw it away to reuse a helper.
		var authored: Dictionary = out_intents.get(player_id, {})
		out_intents[player_id] = _travel_intent(
			player,
			StringName(authored.get("intent", &"defending")),
			here, target, reached, "lateral", window_seconds,
		)
	return established


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
	var quick_floor := OPPONENT_QUICK_CALL_PASS
	if RallyFeatureFlagsModel.ENABLE_LIVE_TEMPO_CALL:
		quick_floor = LIVE_QUICK_CALL_PASS
	if pass_quality >= quick_floor:
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
	opponent_plan.ensure_defaults(lineup, opponent_team.players)
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
	tempo: int = -1,
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
	## Tempo shortens it, when the caller knows which ball this is. A quick and a
	## high ball to the same point are not the same run-up, and this fallback had
	## the same single depth the shared model did.
	if tempo >= 0:
		approach_depth *= ApproachMechanicsModel.approach_depth_for_tempo(tempo) \
			/ ApproachMechanicsModel.APPROACH_DEPTH
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
	## The orientation this body is actually set in, independent of where it is
	## being asked to go. `Vector2.ZERO` means the caller does not track it.
	entry_facing: Vector2 = Vector2.ZERO,
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
	## **The route no longer chooses the orientation.**
	##
	## This used to read `actor.facing = opening.normalized()` -- face the way you
	## are going -- which made every movement in the engine perfectly prepared by
	## construction. `facing_fit` was 1.0 for every voli on every leg, so the turn
	## cost the locomotion model computes could never fire, and a defender caught
	## flat-footed with the ball behind them was timed as though they were already
	## squared to it.
	##
	## Zero means **unknown**, and `_movement_profile` leaves `facing_fit` at 1.0
	## for an unreadable facing -- so a caller that has nothing to say keeps
	## exactly the behaviour it had, and only a caller that actually knows the
	## body's orientation pays for it. That is what makes this safe to land before
	## every caller has been migrated.
	actor.facing = entry_facing
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


## What the home wall is allowed to know before the opposing setter releases.
##
## Playback plans an interval from the metadata on the *next* contact. That
## means `home_phase_targets` attached to an opponent SET are consumed while
## the pass is still travelling to the setter. Publishing the resolved hitter
## lane there lets the wall move to an answer the rally has not shown yet.
##
## A called commit is different: it is a prediction made from the rotation and
## the instruction. Commit Middle names its lane outright. Commit Pin chooses
## the strongest front-row pin in the visible opponent rotation. A read block
## simply establishes each blocker's own net base. None of these branches is
## handed the selected hitter, delivered set target, or eventual attack lane.
func _pre_release_home_block_stage(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	opponent_team: Resource,
) -> Dictionary:
	if lineup == null:
		return {"targets": {}, "prediction": {"source": "no_lineup"}}
	var blockers: Array[Dictionary] = []
	for player_id in lineup.front_row_player_ids():
		var blocker := _player_by_id(players, player_id)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if blocker == null or (assignment != null \
				and not bool(assignment.block_participation)):
			continue
		var slot_number := lineup.slot_for_player(player_id)
		blockers.append({
			"player_id": player_id,
			"base_x": CourtConstants.slot_position(slot_number).x,
		})
	var strategy := str(defensive_plan.block_strategy) \
		if defensive_plan != null else "Read Block"
	var committed := false
	var predicted_x := 0.5
	var predicted_player_id := -1
	var source := "read_base"
	if strategy == "Commit Middle":
		committed = true
		predicted_x = 0.5
		source = "called_commit_middle"
	elif strategy == "Commit Pin" and opponent_team != null:
		var opponent_lineup: Resource = opponent_team.current_lineup()
		var best_pin: VolleyballPlayer = null
		var best_pin_score := -INF
		if opponent_lineup != null:
			for opponent_id in opponent_lineup.front_row_player_ids():
				var candidate := opponent_team.player_by_id(opponent_id) \
					as VolleyballPlayer
				if candidate == null or str(candidate.position_code).begins_with("M"):
					continue
				var score := _power_rating(candidate, "attack_power") * 0.50 \
					+ _rating(candidate, "attack_accuracy") * 0.30 \
					+ _rating(candidate, "approach_timing") * 0.20
				if score > best_pin_score:
					best_pin_score = score
					best_pin = candidate
		if best_pin != null:
			committed = true
			predicted_player_id = best_pin.id
			predicted_x = _opponent_attack_contact(
				opponent_team, best_pin
			).x
			source = "called_commit_pin_rotation_read"
	var targets := {}
	var wall_positions := _block_wall_positions(predicted_x, false)
	var primary_id := -1
	var assist_id := -1
	if committed:
		var primary_distance := INF
		for blocker_data in blockers:
			var distance := absf(float(blocker_data.base_x) - predicted_x)
			if distance < primary_distance:
				primary_distance = distance
				primary_id = int(blocker_data.player_id)
		var assist_distance := INF
		for blocker_data in blockers:
			var blocker_id := int(blocker_data.player_id)
			if blocker_id == primary_id:
				continue
			var distance := absf(float(blocker_data.base_x) - predicted_x)
			if distance < assist_distance:
				assist_distance = distance
				assist_id = blocker_id
	for blocker_data in blockers:
		var blocker_id := int(blocker_data.player_id)
		var target_x := float(blocker_data.base_x)
		if committed and blocker_id == primary_id:
			target_x = float(Vector2(wall_positions.primary_position).x)
		elif committed and blocker_id == assist_id:
			target_x = float(Vector2(wall_positions.assist_position).x)
		targets[blocker_id] = Vector2(
			clampf(target_x, 0.05, 0.95),
			CourtConstants.NET_Y + BLOCK_NET_DEPTH,
		)
	return {
		"targets": targets,
		"prediction": {
			"strategy": strategy,
			"committed": committed,
			"source": source,
			"predicted_x": predicted_x if committed else null,
			"predicted_lane": CourtConstants.lane_at_x(predicted_x) \
				if committed else "",
			"predicted_player_id": predicted_player_id,
			"uses_resolved_hitter": false,
			"uses_resolved_lane": false,
		},
	}


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
## Whoever is running the opponent's offence this rotation.
##
## Beside `_opponent_setter_release_target`, which has always known how to find
## them and only ever returned where they stand.
static func _opponent_setter(opponent_team: Resource) -> VolleyballPlayer:
	if opponent_team == null:
		return null
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	if opponent_lineup == null:
		return null
	for raw_player in opponent_team.on_court_players():
		var player: VolleyballPlayer = raw_player as VolleyballPlayer
		if player != null and player.id == opponent_lineup.active_setter_id():
			return player
	return null


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


## The endpoint the court will draw for this flight.
static func _trajectory_endpoint(
	trajectory: Dictionary, fallback: Vector2 = Vector2(0.5, 0.5)
) -> Vector2:
	return Vector2(trajectory.get("end_position", fallback))


## Once the block is the last contact, the painted lines decide ownership.  In
## particular this is evaluated after sidespin kicks the trajectory, so a ball
## initially classified as a stuff cannot remain a blocker's point after their
## hands visibly send it outside.
static func _block_deflection_lands_out(trajectory: Dictionary) -> bool:
	return not trajectory.is_empty() \
		and not CourtConstants.is_normalized(_trajectory_endpoint(trajectory))


## Did the ball come down behind the wall rather than back on the hitter?
## Touches are playable there; stuffs are not. Kept side-explicit because this
## exact rule previously existed on only one of the two mirrored attack paths.
static func _block_deflection_lands_on_blocking_side(
	trajectory: Dictionary, blocking_side: String
) -> bool:
	if trajectory.is_empty():
		return false
	var endpoint := _trajectory_endpoint(trajectory)
	if not CourtConstants.is_normalized(endpoint):
		return false
	if blocking_side == "home":
		return endpoint.y > CourtConstants.NET_Y
	if blocking_side == "opponent":
		return endpoint.y < CourtConstants.NET_Y
	return false


## A ball coming off the block, timed by geometry rather than a constant.
##
## The three deflection segments each carried a hardcoded 0.18-0.30 s. A stuff
## driven straight down is that fast. A ball squirting up off the hands and
## travelling four metres is not -- and the defender chasing it was drawn
## covering that ground in a quarter of a second, about sixteen metres a
## second. A stuff keeps its constant, because the rally ends on it and nobody
## chases; every other deflection now solves the same arc every other flight in
## this file solves.
## **A ball comes off the hands at the pace it arrived, less what the hands took
## out of it.**
##
## The deflection used to derive its own speed from the distance to wherever the
## ball was going to land -- `solve_struck_arc` answers "how hard must this be hit
## to get there" -- so a 25 m/s spike and a 12 m/s roll came off the block at the
## same pace, and the blocker had nothing to do with it. Pace is the one thing a
## deflection is *made of*: it is not a shot anybody chose, it is a collision.
##
## So the speed is the incoming swing's, scaled by how much of it the blocker
## absorbs, and the flight time is then distance over that speed like every other
## struck ball in this file. Two consequences fall out without being written:
## a hard-driven ball reaches the defender sooner, and `_incoming_ball_force`
## reads the faster arc, which is what `CoverageModel.reception_body_penalty`
## spends `reception_stability` against. The pace-resistance half of this was
## already built and had nothing real to resist.
##
## **`block_timing` is a stand-in and should be replaced.** What belongs here is
## how well a blocker's hands absorb a ball, and no such attribute exists --
## `ball_control` is displayed as "Touch Control" but is the *receiver's* hands
## and is read by reception quality. `block_timing` is the nearest true thing: a
## blocker who meets the ball at full extension presents a firm angled surface and
## one who is already falling gives with it. That is a real part of the effect and
## not the whole of it.
func _block_deflection_trajectory(
	from_point: Vector2,
	to_point: Vector2,
	stuffed: bool,
	apex_hint: float,
	start_time: float,
	incoming_speed_mps: float = 0.0,
	blocker: VolleyballPlayer = null,
	## "kill", "soft" or "neutral" -- see `_block_hands_intent`.
	hands: String = "neutral",
	## **Where sidespin is spent.** A spinning ball does not come off a pair of
	## hands the way it went in -- it grabs and kicks, which is the whole reason a
	## hitter cuts across the ball and the reason a tool off the block is a shot
	## rather than an accident. `BallSpin` explains why the kick lives at contacts
	## and not in the flight: the drawn arc is already a curve, and a second
	## curving term would be two descriptions of one bend.
	spin_state: Dictionary = {},
	## How well this blocker knows this hitter's spin. The design's own
	## mitigation, and the reason scouting a hitter is worth the week.
	spin_familiarity: float = 0.0,
	## **What `BlockDeflectionModel` said this ball did.**
	##
	## The soft branch below has always solved its own flight properly -- pace
	## absorbed against block timing and the hands' intent, then
	## `struck_arc_from_speed`. The *stuff* branch did neither. It flew to
	## `post_block_target`, which is the attack's own target rather than
	## anywhere the ball was deflected to, and it took
	## `BLOCK_STUFF_FLIGHT_SECONDS` to get there -- a constant. That is the
	## reported suspicion in as many words: a preset amount of time for a block
	## touch rather than a time that falls out of the trajectory.
	##
	## Optional, so a caller with no deflection in hand keeps the flight it
	## always had rather than being handed a zero.
	deflection_landing: Variant = null,
	deflection_speed_mps: float = 0.0,
	deflection_vertical_angle_degrees: float = 0.0,
	deflection_duration_seconds: float = 0.0,
	deflection_playable: bool = false,
) -> Dictionary:
	var deflected := deflection_landing != null and (deflection_landing is Vector2) \
		and deflection_speed_mps > 0.01
	if deflected:
		to_point = Vector2(deflection_landing)
	var kick := BallSpin.contact_kick_meters(spin_state, spin_familiarity)
	if absf(kick) > 0.0001:
		## Court x is normalised on a nine-metre width, so a kick in metres has
		## to be divided back into the coordinate the target is expressed in.
		## Kept off the *net* coordinate deliberately: spin moves the ball across
		## the court, not up and down it.
		to_point = Vector2(
			clampf(to_point.x + kick / CourtConstants.COURT_WIDTH_METERS,
				-0.08, 1.08),
			to_point.y,
		)
	var distance := RallyKinematics.court_distance_meters(from_point, to_point)
	## Off a blocker's hands, which are above the tape, not off the floor.
	var contact_height := maxf(apex_hint, CourtConstants.NET_HEIGHT_METERS)
	## A promoted deflection owns one physical launch. Use it for every contact
	## kind, including a stuff: the downward vertical component is what makes a
	## stuff drop immediately instead of drawing a small upward hump first.
	if deflected:
		var physical_arc := RallyKinematics.struck_arc_from_speed(
			distance, deflection_speed_mps,
			deflection_vertical_angle_degrees, contact_height,
		)
		var physical_duration := deflection_duration_seconds \
			if deflection_duration_seconds > 0.0 \
			else float(physical_arc.duration_seconds)
		return _stamp_launch_contact_height(_ball_trajectory(
			"block_deflection", from_point, to_point,
			maxf(
				physical_duration,
				BLOCK_DEFLECTION_MIN_SECONDS,
			),
			float(physical_arc.apex_height_meters), start_time,
			## A playable endpoint is another player's hands. Its height and this
			## duration determine the visible arc; carrying a floor-flight launch
			## component would make presentation satisfy two incompatible paths
			## and create the familiar fly-up/teleport-down rebound.
			NAN if deflection_playable else float(physical_arc.get(
				"vertical_speed_mps", NAN
			)),
		), contact_height)
	if stuffed:
		return _stamp_launch_contact_height(_ball_trajectory(
			"block_deflection", from_point, to_point,
			BLOCK_STUFF_FLIGHT_SECONDS, apex_hint, start_time
		), contact_height)
	if incoming_speed_mps <= 0.0:
		## No swing speed to read -- the legacy solve, which at least always has
		## an answer.
		var solved := RallyKinematics.solve_struck_arc(
			distance, BLOCK_DEFLECTION_LAUNCH_ANGLE_DEGREES, contact_height,
		)
		return _stamp_launch_contact_height(_ball_trajectory(
			"block_deflection", from_point, to_point,
			maxf(float(solved.duration_seconds), BLOCK_DEFLECTION_MIN_SECONDS),
			maxf(float(solved.apex_height_meters), apex_hint),
			start_time,
		), contact_height)
	## Timing decides how much of the band a blocker commands; the hands decide
	## which end of it they are trying to reach. Both, because a well-timed kill
	## block and a well-timed soft block are the same pair of hands making
	## opposite choices, and the ball that comes off them is the difference.
	var absorbed := lerpf(
		BLOCK_ABSORB_SOFT, BLOCK_ABSORB_FIRM,
		_rating(blocker, "block_timing") if blocker != null else 0.5
	)
	match hands:
		"kill":
			absorbed *= BLOCK_KILL_ABSORB_SHARE
		"soft":
			absorbed = minf(absorbed * BLOCK_SOFT_ABSORB_SHARE, 0.88)
	var arc := RallyKinematics.struck_arc_from_speed(
		distance, maxf(incoming_speed_mps * (1.0 - absorbed), MIN_DEFLECTION_MPS),
		BLOCK_DEFLECTION_LAUNCH_ANGLE_DEGREES, contact_height,
	)
	return _stamp_launch_contact_height(_ball_trajectory(
		"block_deflection", from_point, to_point,
		maxf(float(arc.duration_seconds), BLOCK_DEFLECTION_MIN_SECONDS),
		maxf(float(arc.apex_height_meters), apex_hint),
		start_time,
		float(arc.get("vertical_speed_mps", NAN)),
	), contact_height)


## A block owns where its hands contacted the ball even when the next contact
## has not been chosen yet. Keep that fact beside the flight without rewriting
## `start_height_meters`: legacy presentation/gameplay still uses that field's
## existing contract. The next platform contact can pair this height with its own
## derived contact height and recover the arrival vertical without a new number.
func _stamp_launch_contact_height(
	trajectory: Dictionary, contact_height_meters: float
) -> Dictionary:
	trajectory["launch_contact_height_meters"] = contact_height_meters
	return trajectory


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
## How far the reachability clamp had to drag the contact, in metres.
##
## The other half of `_clamped_arrival_margin`, and it was missing. Sparing a
## hitter the lateness is correct -- they are not late to a contact that was
## moved to them -- but hitting from further off the net is *worse*, and nothing
## charged them for it. Measured on the displacement fixture: a hitter dragged
## 0.74 m back off the tape came out with attack quality 0.247 -> 0.252, very
## slightly *better* for having been displaced across the court.
##
## So the clamp had removed a consequence rather than relocating it. This is the
## consequence, in the channel it actually belongs to.
## The part of the pre-set window the hitter gets to run in.
##
## Reads `preparation_time_seconds`, which the approach model already computes
## and already publishes -- it was simply never spent by anything. A value that
## exists, is correct, and reaches no consumer is the commonest defect in this
## engine and this is one more instance of it.
static func _hitter_preset_credit(preparation: Dictionary) -> float:
	if not RallyFeatureFlagsModel.ENABLE_HITTER_PRESET_WINDOW:
		return 0.0
	return maxf(
		float(preparation.get("preparation_time_seconds", 0.0)), 0.0
	) * HITTER_PRESET_SHARE


static func _clamp_displacement_meters(before: Vector2, after: Vector2) -> float:
	if not RallyFeatureFlagsModel.ENABLE_CLAMPED_ARRIVAL_MARGIN:
		return 0.0
	return RallyKinematics.court_distance_meters(before, after)


static func _clamped_arrival_margin(margin_before_clamp: float) -> float:
	if not RallyFeatureFlagsModel.ENABLE_CLAMPED_ARRIVAL_MARGIN:
		return margin_before_clamp
	## Exact against `_reachable_contact`'s own arithmetic: it either returns the
	## intended contact untouched, leaving a non-negative margin alone, or scales
	## the route so arrival lands on the ball. It shares that function's
	## constant-speed approximation of the route and adds no second one.
	return maxf(margin_before_clamp, 0.0)


## Land and time the set where the swing now happens.
##
## The set event is emitted before the hitter's route is known, so a clamped
## contact would otherwise leave the ball drawn to one point and struck at
## another. Tempo recognition can also revise the flight after seeing how far
## through the hitter's approach release actually occurred, so this must rebuild
## the trajectory even when the endpoint did not move. Returning early on an
## equal endpoint left the event carrying the pre-recognition duration while the
## attack was timed from the revised one: one set, two clocks.
func _retarget_set_event(
	set_event: RallyEvent,
	contact: Vector2,
	kind: String,
	flight_time: float,
	apex_height: float,
	release_time: float,
	## The heights `_set_arc` solved this flight between. NAN keeps the old
	## 1.0 m default, which is what every caller used to get; every caller now
	## has the arc in scope and passes them.
	release_height: float = NAN,
	arrival_height: float = NAN,
) -> void:
	if set_event == null:
		return
	set_event.end_position = contact
	set_event.metadata["outgoing_trajectory"] = _ball_trajectory(
		kind, set_event.start_position, contact, flight_time, apex_height,
		release_time, NAN, NAN, release_height, arrival_height,
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


## The flight a swing actually produced.
##
## `_geometric_swing` resolves every attack in the game -- it picks a course,
## chooses a power from `AttackPowerModel`, solves the driven root off the
## hitter's real contact height and checks the ball clears the tape -- and then
## hands back `speed_mps`, `vertical_angle_degrees` and `contact_height_meters`.
## Every one of those three was dropped on the floor, and the drawn attack was
## rebuilt from `solve_launch_arc`: a ball lobbed *upward* at eight to twelve
## degrees from ground level to ground level.
##
## The consequence was not subtle once it was measured. A spike is struck
## downward -- `DRIVEN_REFERENCE_ANGLE_DEGREES` is minus fifteen and always has
## been -- so re-deriving it as an upward lob forced the solver to pick a speed
## slow enough that the lob would still land in the court, around 6.6 m/s against
## the 16-30 m/s the power model works in. This is the first failure mode in
## `docs/BACKLOG.md`, exactly: a value computed correctly, dropped before
## anything could use it, and re-derived worse downstream.
##
## The fallback is not the old lob. A swing with no geometric record still gets
## the driven reference angle and the speed that shape needs, because a spike
## drawn as a lob is wrong whether or not the resolver had an opinion about it.
## The shadow trace's summary, or an empty one.
##
## `shadow_reception_trace` is null on the paths that never built a trace -- an
## opponent transition inside a home serve is one -- and reading `.summary` off
## it was a crash the moment anything outside the reception pipeline wanted a
## geometric record. Which is now every attack.
func _trace_summary() -> Dictionary:
	if shadow_reception_trace == null:
		return {}
	return Dictionary(shadow_reception_trace.summary)


## **The speed is carried; the angle is re-solved.** The record's
## `vertical_angle_degrees` belongs to the landing point the *geometric* resolver
## chose, and the drawn event goes to the legacy `attack_target`, which is not
## always the same spot. Carrying an angle across that gap draws real nonsense --
## a lofted 70-degree roll re-aimed at a short target solved to a two-second
## flight and put the ball nine metres in the air, which is what the first version
## of this function did and what the tape column in `run_ball_flight_probe`
## caught. Speed is a property of the swing and travels; angle is a property of
## the swing *plus its target* and does not.
func _swing_arc(
	record: Dictionary,
	distance_meters: float,
	contact_height_meters: float,
	## Whether the ball is being drawn to the landing point this record chose. Only
	## then is the record's launch angle the angle for this distance.
	reached_resolved_target: bool = false,
	## What the hitter put on the ball. Topspin is a downward force for the whole
	## flight, which is a change of gravity and nothing else -- see `BallSpin`.
	## Absent, the ball flies under plain gravity as it always did.
	spin_state: Dictionary = {},
) -> Dictionary:
	var height := maxf(float(record.get(
		"contact_height_meters", contact_height_meters
	)), 0.1)
	var power := GeometricAttackResolverModel.AttackPowerModel
	var speed := float(record.get("speed_mps", 0.0))
	if not bool(record.get("available", false)) or speed <= 0.0:
		## An ordinary hitter driving the ball. Deliberately *not*
		## `required_speed_mps`, which asks the least force that reaches the target
		## at the reference angle -- a question with no answer beyond about twelve
		## metres, where it returns the speed floor and a ball drawn at 0.1 m/s.
		speed = power.available_ceiling_mps(0.5, 1.0, 1.0) * power.DRIVE_INTENT
	## **The resolver's own angle, when the ball is going where the resolver sent
	## it.**
	##
	## `GeometricAttackResolver` does not pick the driven root and stop. It
	## searches for an angle that *clears the tape* -- `_height_at_net` and
	## `NET_SPEED_RELIEF_STEPS` exist for nothing else -- and re-solving here threw
	## that constraint away, so a back-row swing came out at an angle that
	## physically cannot get over the net from four metres back. Measured, 50 of
	## 181 attack-to-block flights crossed below net height.
	##
	## Carrying it is only sound because the two targets turn out to already be
	## one: every attack site assigns `attack_target = geometric.target` *before*
	## solving this arc, so the distance below and the angle in the record describe
	## the same shot. The earlier attempt that drew two-second flights nine metres
	## up carried the angle onto the *to-block leg*, whose distance is the short
	## hop to the net rather than the shot's own range -- a different defect with
	## the same symptom, and the reason this takes a flag rather than always
	## trusting the record.
	## **And upward-struck balls too.** This condition used to read
	## `vertical_angle_degrees <= 0.0`, on the grounds that carrying the angle
	## unconditionally moved the mean height of an untouched attack at the tape
	## from 2.69 m to 5.19 m -- a lofted angle gets over the tape by going a long
	## way up, and the flat-spike report this thread came from was never about
	## roll shots.
	##
	## That is §0 twice over. A bound was placed on the drawing to hold down a
	## number the *resolver* had chosen, and it was placed exactly across the
	## branch it was needed for. `_feasible_launch` reaches for a lofted root only
	## when no driven one clears -- lofting *is* the clearance -- so excluding
	## lofted deliveries threw the angle away on precisely the swings that had no
	## other way over. Measured on 205 attacks met by a block: all 26 lofted
	## swings were certified over the tape by the resolver, all 26 were drawn at
	## a mean of -18.4 degrees, and 23 of the 26 were drawn *through the net*.
	## Against 16 of 171 on the driven branch, which is a different defect.
	##
	## The 5.19 m is not evidence against carrying it. It is the resolver saying
	## these hitters are rolling the ball over a formed block from the back row,
	## which is a claim about the swing that the drawing does not get a vote on.
	## If that number is wrong the fix belongs in the clearance search, where the
	## shot is chosen; drawing a flat spike on top of a lofted solve does not make
	## the swing flatter, it makes the picture disagree with the rally.
	var gravity := BallSpin.gravity_for(spin_state)
	if reached_resolved_target and bool(record.get("available", false)) \
			and record.has("vertical_angle_degrees"):
		return RallyKinematics.struck_arc_from_speed(
			distance_meters, speed,
			float(record.vertical_angle_degrees), height, gravity,
		)
	var solved := BallFlightModel.solve_angle_for_range(
		speed, distance_meters, height, gravity
	)
	var angle := power.DRIVEN_REFERENCE_ANGLE_DEGREES
	if bool(solved.get("driven_found", false)):
		angle = float(solved.driven_angle_degrees)
	else:
		## Struck too softly to carry that far at any angle. The swing still
		## happened and the ball still has to be drawn arriving, so it is re-priced
		## at the least force that reaches. Landing short is a real outcome and a
		## real one to model, but it is the resolver's to declare -- not something
		## the drawing gets to invent by stalling the ball in midair.
		var reach := BallFlightModel.minimum_speed_to_reach(
			distance_meters, height, gravity
		)
		speed = maxf(speed, float(reach.speed_mps))
		angle = float(reach.launch_angle_degrees)
	return RallyKinematics.struck_arc_from_speed(
		distance_meters, speed, angle, height, gravity
	)


## The same swing, drawn only as far as the block.
##
## Not a new solve. Re-solving against the *distance to the net* asks "what shot
## lands at the tape", so the re-sliced leg was aimed at the block rather than
## through it. Truncating a flight must not change its shape, only where it
## stops, so the leg keeps the parent swing's launch and takes the share of its
## duration the shorter distance is worth.
##
## `swing_duration_seconds` is the parent's own flight time, carried so a reader
## can still ask how far through the *swing* something happened. The block's
## timing gate needs exactly that: it measures when the hands met the ball
## against the flight they contested, and once this leg ends at the tape by
## construction, measuring against the leg answers 1.0 every time.
func _truncated_arc(
	parent: Dictionary, full_distance: float, short_distance: float
) -> Dictionary:
	var share := clampf(short_distance / maxf(full_distance, 0.0001), 0.0, 1.0)
	var truncated := parent.duplicate(true)
	var full_duration := float(parent.get("duration_seconds", 0.5))
	truncated["duration_seconds"] = maxf(full_duration * share, 0.02)
	truncated["swing_duration_seconds"] = full_duration
	return truncated




func _ball_trajectory(
	kind: String,
	start: Vector2,
	end: Vector2,
	flight_time: float,
	apex_height: float,
	start_timestamp: float = -1.0,
	## How fast the ball was going *up* when it left the contact, signed, and how
	## long the whole swing lasts when this is only part of one. Optional: only
	## the struck flights supply them.
	launch_vertical_mps: float = NAN,
	swing_duration_seconds: float = NAN,
	## **Where the ball actually was, vertically, at each end of this flight.**
	##
	## `BallTrajectory.create` has taken these since it was written and no caller
	## ever passed them, so every published trajectory in the game carried the
	## 1.0 m defaults. That was invisible because `apex_height_meters` is a
	## *relative rise* -- a documented contract with its own gate -- and because
	## presentation rebuilds the real heights from body profiles before drawing.
	##
	## It stopped being invisible the moment anything asked the trajectory itself:
	## `height_at_progress`, `height_at_time` and `earliest_contact_time` all
	## derive from these two fields, so on seed 20010's dig the record answered
	## 1.000 m at the far end where the ball really arrives at 2.190 -- a metre
	## and a fifth of fiction, in the exact methods a future interception resolver
	## has to trust.
	##
	## NAN means "this writer does not know", which is honest and keeps the old
	## default. `height_source` records which it was so the gap stays countable.
	start_height: float = NAN,
	end_height: float = NAN,
	## **Which launch this flight belongs to.**
	##
	## The B0 census found four families -- serve, set, attack and block --
	## publishing balls with no identity on them at all. Every edge between them
	## still handed over the right ball, but the strongest thing a certification
	## could say was "the same *shape* arrived", and P3's matrix asks each edge
	## for "same launch lineage". Two geometrically identical records are
	## indistinguishable from one record passed along, which is precisely the
	## substitution a one-ball chain exists to rule out.
	##
	## Empty mints a new identity: this contact is a new launch. A **re-slice of
	## an existing launch** -- the swing truncated to the tape when a block
	## touches it -- passes the source's id instead, because it is a prefix of
	## that launch and not a second one. That is the whole distinction, and it is
	## stated by the caller rather than inferred from coincident floats.
	flight_id: String = "",
) -> Dictionary:
	var timestamp := rally_clock if start_timestamp < 0.0 else start_timestamp
	var direction := end - start
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var curve_amount := clampf(direction.length() * 0.08, 0.0, 0.035)
	var control := start.lerp(end, 0.5) + perpendicular * curve_amount
	var start_known := not is_nan(start_height)
	var end_known := not is_nan(end_height)
	var trajectory: Resource = BallTrajectoryModel.create(
		kind, start, control, end, timestamp, flight_time, apex_height,
		start_height if start_known else 1.0,
		end_height if end_known else 1.0,
	)
	var data: Dictionary = trajectory.to_dict()
	## **Three states, not two, because the serve genuinely has three.** Its
	## launch height is now known exactly; its *ending* height is the open
	## question -- `end_height_meters` is read by `BallFlight.from_trajectory` as
	## the height of the **next contact**, while the serve's own flight solves to
	## the floor. Those are different numbers and choosing between them is
	## `CONTACT_AND_BALL_FLIGHT.md`'s unresolved item 5, not something to settle
	## as a side effect of owning the launch. Publishing the half that is known
	## and marking the half that is not keeps the gap countable, which is the
	## whole reason this marker exists.
	var height_source := "default"
	if start_known and end_known:
		height_source = "resolved"
	elif start_known:
		height_source = "start_resolved"
	data["height_source"] = height_source
	## RallyKinematics solves vertical displacement above launch level. Preserve
	## that contract explicitly; legacy `apex_height_meters` is retained because
	## calibration reads it for the duration/rise invariant.
	data["apex_rise_meters"] = apex_height
	data["height_contract"] = "relative_rise"
	if not is_nan(launch_vertical_mps):
		data["launch_vertical_mps"] = launch_vertical_mps
	if not is_nan(swing_duration_seconds):
		data["swing_duration_seconds"] = swing_duration_seconds
	## The id and **not** `trajectory_role`.
	##
	## `authoritative_free_flight` is M5's word for a flight M5 resolved, and
	## `FreeFlightInterceptionModel.opportunities` and `realised_prefix` both
	## refuse to act on anything that does not carry it. Stamping it here would
	## let a serve or a set arc walk into the interception system, which is a
	## second physical authority arriving through a label -- the exact thing this
	## identity is being added to make detectable.
	data["authoritative_flight_id"] = flight_id if not flight_id.is_empty() \
		else "%d:%s:%.6f:%.4f,%.4f" % [
			rally_seed, kind, timestamp, start.x, start.y,
		]
	return data


## Put the launch state on the published flight, so nothing has to rebuild it.
##
## **`BallPresentation.launch_speed_mps` reconstructs launch speed from the two
## endpoint heights and the duration**, which makes it a property of wherever the
## flight was cut rather than of the contact that made it -- the §3 violation the
## spec names, and it is read by `_read_error_meters`, which is gameplay. A ball
## dug at six metres left the hand at the same speed as one that reached the
## floor, and a record that cannot say so will keep being asked to guess.
##
## Only the serve carries this today. Every other family still reconstructs, and
## `_read_error_meters` still falls back to the reconstruction for them, so the
## marker is also the migration's own to-do list.
func _stamp_launch_state(trajectory: Dictionary, resolved: Dictionary) -> void:
	var launch: Dictionary = resolved.get("launch", {})
	if launch.is_empty():
		return
	trajectory["launch_speed_mps"] = float(launch.get("speed_mps", 0.0))
	trajectory["launch_angle_degrees"] = float(launch.get("angle_degrees", 0.0))
	trajectory["launch_bearing_degrees"] = float(launch.get("bearing_degrees", 0.0))
	trajectory["launch_horizontal_mps"] = float(
		launch.get("horizontal_speed_mps", 0.0)
	)
	trajectory["launch_vertical_mps"] = float(launch.get("vertical_speed_mps", 0.0))
	trajectory["launch_gravity_mps2"] = float(launch.get("gravity_mps2", 0.0))
	trajectory["launch_source"] = "resolver"


## The marker a platform-contact intent field carries when there is genuinely no
## intent to state, rather than an intent whose policy is missing.
##
## A string, deliberately, so it cannot be read as a number by anything that
## forgets to check. A sentinel float would be indistinguishable from an anchor
## that happens to sit at the default, which is `docs/FAILURE_MODES.md` section 0
## in one line.
const PLATFORM_INTENT_UNSET: String = "unset"


## What a platform contact was *for*, published beside what it did.
##
## `PLATFORM_CONTACT.md` section 11, slice 1, plus the two source markers section
## 13.10 asks for. **Nothing reads any of it.** The slice's own acceptance
## criterion is that rallies come back byte-identical, and publishing it inert is
## the point: it makes countable, for the first time, how many platform contacts
## in this engine have any stated intent at all.
##
## The three shapes are not a stylistic choice and section 3a is the reasoning.
## The target and the height have derived *anchors* and no derived widths; the
## arrival has a derived *floor* and no derived ceiling. A uniform representation
## would have had to invent whatever the uniformity demanded and the data does not
## supply -- four of five bounds, by section 3a's own count.
##
## `anchor_source` separates a manager-set release seat, which is steerable, from
## a fixed contact offset. Receptions and controlled digs state the former;
## coverage still has only the latter because it has no recipient or pass intent.
func _platform_intent(
	purpose: String,
	target_anchor: Vector2,
	anchor_source: String,
	## Who the ball is aimed at. **Intent and nothing else** -- it may not
	## terminate a flight and it may not pick the second contact, because the
	## actual second-contact actor differs from the designated setter on about
	## 22.8% of successful digs. It exists so that aiming can be wrong.
	recipient: VolleyballPlayer,
	## Where the recipient is now, from whichever live map owns their side. Passed
	## rather than looked up, because the two sides keep separate maps and a
	## helper that guessed which one would be right half the time.
	recipient_position: Vector2,
) -> Dictionary:
	var record := {
		"purpose": purpose,
		"target_anchor": target_anchor,
		"anchor_source": anchor_source,
		"intended_recipient_id": recipient.id if recipient != null else -1,
		"height_anchor_meters": PLATFORM_INTENT_UNSET,
		"arrival_floor_seconds": PLATFORM_INTENT_UNSET,
		## Honest current value. Nothing supplies a tactical preference yet, and
		## publishing the field with an absence marker is what stops the schema
		## changing when tactics arrive: the marker takes a new value, the record
		## does not grow a new shape.
		"preference_source": "none",
	}
	if recipient == null:
		return record
	## Both class C -- computed from models that already exist, reading neither the
	## dig's apex band nor its outgoing trajectory.
	record["height_anchor_meters"] = \
		GeometricAttackPromotionModel.set_contact_height_meters(recipient, false)
	record["arrival_floor_seconds"] = _movement_time(
		recipient, recipient_position, target_anchor, "transition"
	)
	return record


func _desired_pass_target(release_target: Vector2, reception_contact: Vector2) -> Vector2:
	# A distant passer aims slightly higher/off the net to reduce overpass risk;
	# nearby passers can safely feed the setter's release point more directly.
	var distance_meters := Vector2(
		(reception_contact.x - release_target.x) * 9.0,
		(reception_contact.y - release_target.y) * 18.0,
	).length()
	var safety_offset := clampf((distance_meters - 4.0) * 0.006, 0.0, 0.045)
	return Vector2(release_target.x, clampf(release_target.y + safety_offset, 0.55, 0.70))


## How far along the net a delivery has to travel the wrong way before it is a
## back set rather than a front set squared slightly off.
##
## Half a metre, which is inside a setter's own shoulder width and well below the
## gap between the release seat and either antenna -- so the flag reports the
## side of the body the ball left on, not the noise in where the setter happened
## to stand.
const BACK_SET_MIN_METERS: float = 0.50


func _set_geometry(
	setter: VolleyballPlayer,
	setter_start: Vector2,
	contact: Vector2,
	target: Vector2,
	release_target: Vector2,
	## Which way along the net this setter squares up, as the sign of x.
	##
	## A setter faces their outside hitter and delivers everything else relative
	## to that -- so "behind the setter" is a fact about the body, not about the
	## court, and it cannot be read off the target alone. Home's outside is the
	## Left Pin at low x, hence the default; the opponent attacks the other way
	## down the same axis, so their own left is high x and they pass +1.
	square_up_sign: float = -1.0,
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
	## Which side of the setter's own body the ball left on. Signed so that
	## positive is *behind* them whichever way they square up, which is what makes
	## this one flag work for both sides of the net.
	var behind_meters := (target.x - contact.x) * 9.0 * -square_up_sign
	return {
		"distance_meters": distance_meters,
		"angle_degrees": angle_degrees,
		"release_distance_meters": release_distance,
		"body_orientation_fit": orientation_fit,
		"behind_meters": behind_meters,
		"back_set": behind_meters > BACK_SET_MIN_METERS,
		"set_balance": balance,
		"set_stability": stability,
		"net_distance_meters": net_distance_meters,
		"difficulty": difficulty,
	}


## How high a pass goes above the platform that played it, from a shank to a
## perfect one.
##
## The floor is a ball that barely clears the passer -- it still reaches a
## setter's hands on nobody, which is exactly the point: a low rise off a 0.9 m
## platform apexes under every setter's standing reach in the game, and the
## second contact has to be taken underhand. The ceiling is the textbook high
## pass that hangs above the setter and lets the whole offence organise
## underneath it.
##
## **Raised, because the ceiling was under the setter's own jump.** The band was
## 1.05-2.90 m and measured over 1,052 passes it produced apexes of 2.42-3.31 m
## about a 2.89 m median. A setter's jump-set contact is
## `lerp(standing_reach, jumping_reach, 0.58)`, which is about 2.83 m for a
## 1.90 m body -- so the *median* pass peaked six centimetres above the point a
## setter would meet it in the air, and the bottom of the band peaked below it.
## There was no ball in the game high enough to be worth leaving the floor for,
## which is both why the jump set could never be the standard and why the pass
## read as too low to jump to.
##
## The new band apexes roughly 2.35-4.70 m about a 3.4 m median, which puts the
## ordinary pass comfortably above a jump-set contact and the good one well
## above it. The floor deliberately stays under the standing release: a bad pass
## must still be a bad pass.
const PASS_APEX_RISE_MIN_METERS: float = 1.45
const PASS_APEX_RISE_MAX_METERS: float = 3.80
## Below this execution the platform is not controlling the ball, so it goes up
## rather than forward, by up to this much more.
const SHANK_EXECUTION: float = 0.18
const SHANK_EXTRA_RISE_METERS: float = 1.60


## The ball that physically leaves a successful floor dig.
##
## **Before this, a dug ball had no flight.** The dig event carried a destination
## and nothing else -- no apex, no duration, no contact height -- and the two
## transition resolvers filled the hole with constants: a 0.68 s second-contact
## window for setter reachability, and a table-drawn contact height. Both were
## labelled as gaps in place; `_resolve_opponent_transition` still says
## "NAN when the feeding contact has no height model, which today is every dug
## ball on either side". This is that model. The display trajectory that
## `_ensure_event_trajectories` used to invent afterwards was never the ball the
## setter had been resolved against, so the drawn flight and the simulated one
## were two different balls that happened to share an endpoint.
##
## **Reuses the reception primitives, not the reception helper.**
## `_reception_pass_result` computes exactly this physics -- contact height,
## apex, set-contact height, `BallFlightModel.duration_for_apex` -- but takes a
## serve origin and a serve force and is calibrated against reception platform
## feasibility. A dig is not a reception: it is played off a swing, from a
## posture, at a reach margin, and often while falling. So the primitives are
## shared and the geometry is its own.
##
## **No new random draw.** Everything below is derived from what the dig already
## resolved: its control, its posture, its reach margin, how far the defender
## travelled and how fast the ball was coming. The dig contest has already
## consumed its randomness; a second roll here would make the same dig produce
## two different balls.
func _dig_pass_result(
	digger: VolleyballPlayer,
	contact_position: Vector2,
	desired_target: Vector2,
	dig_control: float,
	arrival: Dictionary,
	posture: String,
	incoming_trajectory: Dictionary,
	movement_distance_meters: float,
	setter: VolleyballPlayer,
	contact_time: float,
	body_velocity_mps: Vector2 = Vector2.ZERO,
	platform_intent: Dictionary = {},
	physical_incoming_trajectory: Dictionary = {},
) -> Dictionary:
	if _physical_platform_dig_enabled():
		var physical := _physical_platform_dig_result(
			digger, contact_position,
			physical_incoming_trajectory \
				if not physical_incoming_trajectory.is_empty() \
				else incoming_trajectory,
			arrival,
			body_velocity_mps, platform_intent, contact_time,
		)
		if not physical.is_empty():
			return physical
	var control := clampf(dig_control, 0.0, 1.0)
	## **What the dig could not absorb goes somewhere.** Three things spoil a
	## platform, and the dig already measured all of them: arriving late (a
	## negative reach margin means reaching, not planted), being off-axis, and
	## having crossed ground to get there. They are combined rather than picked
	## between because a scrambling dig is usually all three at once.
	var reach_margin := float(arrival.get("reach_margin_meters", 0.0))
	var stretched := clampf((0.25 - reach_margin) / 0.85, 0.0, 1.0)
	var posture_penalty := 0.0
	match posture:
		"off-axis": posture_penalty = 0.35
		"reaching": posture_penalty = 0.55
		"emergency", "fall": posture_penalty = 0.80
	var travel := clampf(movement_distance_meters / 3.2, 0.0, 1.0)
	var spoil := clampf(
		(1.0 - control) * 0.55 + stretched * 0.20
		+ posture_penalty * 0.17 + travel * 0.08,
		0.0, 1.0,
	)
	## **Drift is a direction, not a radius.** A spoiled platform sends the ball
	## on along the line it was already travelling -- off the arms rather than
	## off the target -- so the error is biased downrange of the incoming ball
	## instead of scattered around the setter. That is what makes a bad dig go
	## over the net or into the antenna rather than randomly sideways.
	var incoming_direction := Vector2.ZERO
	## `start_position`, which is what `BallTrajectory.to_dict()` publishes. The
	## first draft read "start", found nothing, and fell back to the contact
	## point -- so the incoming direction was zero and every dig, however
	## spoiled, landed exactly on its target. The probe caught it as a
	## destination error of 0.000 at the median.
	var incoming_start := Vector2(
		incoming_trajectory.get("start_position", contact_position)
	)
	if incoming_start.distance_to(contact_position) > 0.01:
		incoming_direction = (contact_position - incoming_start).normalized()
	var desired_vector := desired_target - contact_position
	var lateral := Vector2(-incoming_direction.y, incoming_direction.x)
	var destination := desired_target \
		+ incoming_direction * spoil * 0.20 \
		+ lateral * (spoil * 0.11 * (1.0 if int(digger.id) % 2 == 0 else -1.0))
	destination.x = clampf(destination.x, 0.04, 0.96)
	destination.y = clampf(destination.y, 0.04, 0.96)
	## Height, from the same two model calls a reception makes. A clean dig is
	## played up to a setter; a spoiled one stays flat, which is what takes the
	## options away rather than a penalty applied to them later.
	var pass_contact_height := GeometricAttackPromotionModel \
		.pass_contact_height_meters(digger)
	var pass_apex := pass_contact_height + lerpf(1.35, 3.05, 1.0 - spoil)
	var set_contact_height := minf(
		pass_apex,
		GeometricAttackPromotionModel.set_contact_height_meters(setter) \
			if setter != null else pass_apex,
	)
	var flight_time := BallFlightModel.duration_for_apex(
		pass_contact_height, set_contact_height, pass_apex
	)
	## The rise stays the published apex, per the `relative_rise` contract; the
	## two absolute heights are what the record was missing.
	var trajectory := _ball_trajectory(
		"dig", contact_position, destination, flight_time,
		maxf(pass_apex - pass_contact_height, 0.0), contact_time,
		NAN, NAN, pass_contact_height, set_contact_height,
	)
	return {
		"trajectory": trajectory,
		"destination": destination,
		"duration": flight_time,
		"pass_apex_meters": pass_apex,
		"pass_contact_height_meters": pass_contact_height,
		"set_contact_height_meters": set_contact_height,
		"target_error_meters": destination.distance_to(desired_target)
			* CourtConstants.COURT_WIDTH_METERS,
		"spoil": spoil,
		"incoming_speed_mps": _incoming_ball_speed(incoming_trajectory),
	}


## M4 slice 3's one promoted context. Success/ownership has already been
## resolved before this function is called; this stage owns only the physical
## ball a successful forearm contact produces. The model cannot see `DIG`, the
## terminal outcome or the old control/spoil bands.
func _physical_platform_dig_result(
	digger: VolleyballPlayer,
	contact_position: Vector2,
	incoming_trajectory: Dictionary,
	arrival: Dictionary,
	body_velocity_mps: Vector2,
	platform_intent: Dictionary,
	contact_time: float,
	## The platform family this contact belongs to, used only to label the flight
	## and keep the deterministic seed streams distinct. The physics is identical
	## across families -- this is the shared resolver, not a per-family fork.
	contact_family: String = "dig",
) -> Dictionary:
	if digger == null:
		return {}
	## **The ball's height, where the incoming flight can state it.**
	##
	## This was the passer's own platform height for every platform family, and
	## the reception's site says why in its own words: the trajectory's endpoint
	## height was "ambiguous", so the body's number was used rather than make
	## either meaning of `end_height_meters` authoritative by accident. That
	## ambiguity is resolved -- the serve's published flight terminates at the
	## pass, and a flight that resolves its start and publishes its launch states
	## its far end -- so the deferral has expired and the ball can be read
	## directly.
	##
	## The body stays as the fallback for a flight that resolves neither end, and
	## for the degenerate case where the derivation lands at or below the floor:
	## `PlatformContactModel` refuses a contact at zero height, and a ball that
	## reached the floor is a ball nobody passed.
	var contact_height := GeometricAttackPromotionModel \
		.pass_contact_height_meters(digger)
	var ball_height := realised_flight_end_height(incoming_trajectory)
	if not is_nan(ball_height) and ball_height > 0.0:
		contact_height = ball_height
	var incoming := PlatformContactModel.incoming_velocity_at_contact(
		incoming_trajectory, contact_height
	)
	if not bool(incoming.get("available", false)):
		return {}
	var target_value: Variant = platform_intent.get("target_anchor", null)
	var height_value: Variant = platform_intent.get("height_anchor_meters", null)
	if not target_value is Vector2 \
			or not (height_value is float or height_value is int):
		return {}
	var stability := (
		_rating(digger, "reception_balance")
		+ _rating(digger, "reception_stability")
	) * 0.5
	var technique := (
		_rating(digger, "reception") + _rating(digger, "ball_control")
	) * 0.5
	var severity := clampf(float(arrival.get("edge_ratio", 0.0)), 0.0, 1.0)
	var shadow := PlatformContactModel.evaluate({
		"incoming_velocity_mps": incoming.velocity_mps,
		"contact_position": contact_position,
		"contact_height_meters": contact_height,
		"body_velocity_mps": body_velocity_mps,
		"circumstance_severity": severity,
		"stability_ability": stability,
		"technique_ability": technique,
		"intent_target_anchor": target_value,
		"intent_height_anchor_meters": height_value,
		"intent_arrival_floor_seconds": float(platform_intent.get(
			"arrival_floor_seconds", 0.0
		)),
		## Separate deterministic stream: opening the rollout cannot resequence
		## any perception, contest or tactical draw around this contact.
		"seed": hash("%d|platform-%s|%d|%.6f" % [
			rally_seed, contact_family, digger.id, contact_time,
		]),
	})
	if not bool(shadow.get("selection_available", false)) \
			or not shadow.has("realised_velocity_mps"):
		return {}
	var realised: Dictionary = shadow.realised
	var apex_height := maxf(
		float(realised.apex_height_meters), contact_height
	)
	var launch_velocity := Vector3(shadow.realised_velocity_mps)
	## M5: the platform contact owns a launch, so the unconstrained projectile
	## owns its endpoint. The target plane remains a diagnostic about intent; it
	## is not promoted into the next voli's hands. A later physical interception
	## may realize a prefix of this exact record without rewriting the launch.
	var trajectory := FreeFlightInterceptionModel.from_launch(
		contact_family, contact_position, contact_height, launch_velocity,
		contact_time,
		"%d:%s:%d:%.6f" % [rally_seed, contact_family, digger.id, contact_time],
	)
	if trajectory.is_empty():
		return {}
	var destination := Vector2(trajectory.end_position)
	var duration := float(trajectory.duration)
	return {
		"trajectory": trajectory,
		"authoritative_free_flight": trajectory,
		"destination": destination,
		"duration": duration,
		"pass_apex_meters": apex_height,
		"pass_contact_height_meters": contact_height,
		## There is no setter contact yet. M5 supplies this only after a body
		## actually intercepts the free flight.
		"set_contact_height_meters": NAN,
		"target_error_meters": float(realised.horizontal_error_meters),
		"incoming_speed_mps": float(incoming.speed_mps),
		"platform_contact": {
			"source": "shared_physical_platform",
			"incoming_source": str(incoming.get("source", "missing")),
			"maximum_outgoing_speed_mps": float(
				shadow.maximum_outgoing_speed_mps
			),
			"redirection_half_angle_degrees": float(
				shadow.redirection_half_angle_degrees
			),
			"selected_velocity_mps": Vector3(shadow.selected_velocity_mps),
			"realised_velocity_mps": launch_velocity,
			"execution_error_degrees": float(shadow.execution_error_degrees),
			"intent_satisfiable": bool(shadow.intent_satisfiable),
			"binding_constraint": str(shadow.binding_constraint),
			"circumstance_severity": severity,
			"reaches_target_plane": bool(realised.reaches_target_plane),
			"target_plane_position": Vector2(realised.target_plane_position),
			"target_plane_time_seconds": float(
				realised.target_plane_time_seconds
			),
			"target_plane_height_meters": float(
				realised.target_plane_height_meters
			),
		},
	}


func _physical_platform_dig_enabled() -> bool:
	return not platform_dig_development_force_legacy \
		and (RallyFeatureFlagsModel.ENABLE_PHYSICAL_PLATFORM_DIG \
		or (
			platform_dig_development_open and OS.is_debug_build()
			and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_PLATFORM_DIG_OVERRIDE
		))


## Reception's own production gate, independent of the dig. It is deliberately
## NOT wired to the dig's development-open field: until the home first-ball
## reception->set path carries an M5 interception branch, enabling physical
## reception there produces a setter aimed at the free flight's floor endpoint, so
## coupling it to the dig's dev override would break every dev-override probe
## (the dig rollout among them) before the retrofit lands. A decoupled
## `development_physical_reception` override is added with the home retrofit, for
## the paired reception census; production stays legacy until this const flips.
func _physical_platform_reception_enabled() -> bool:
	return not platform_dig_development_force_legacy \
		and (RallyFeatureFlagsModel.ENABLE_PHYSICAL_RECEPTION \
		or (
			platform_reception_development_open and OS.is_debug_build()
			and RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_PLATFORM_DIG_OVERRIDE
		))


## The keep-alive ball a successful attack-coverage contact launches.
##
## **Coverage owns no recipient policy of its own.** The intended target is
## exactly the actor the existing second-contact policy names --
## `_second_contact_setter`, the one selector every dig and transition already
## goes through -- with the coverer excluded as its `first_contact_player_id`, so
## a coverer is never named their own recipient and an unavailable designated
## setter falls to that selector's existing emergency-setter branch. Coverage
## adds no ranking, no weight and no coefficient here; it reuses the policy whole.
##
## From that intent this is the shared physical platform contact and nothing
## bespoke: the authoritative incoming ball, the coverer's own body/contact
## state, and the T1--T3 model produce one authoritative free flight. The launch
## selects nothing about who touches the ball next -- M5 interception decides that
## against the flight, so the intended actor may miss, a teammate may intercept,
## or the ball may floor, sail or cross the net untouched.
##
## Returns `{}` when the physical platform path is closed (the same flag and
## development override `_dig_pass_result` gates on), when the policy can name no
## available second-contact actor besides the coverer, or when the model declines
## the contact. The caller then keeps its legacy fabricated trajectory, so
## production is byte-unchanged until the flag opens.
func _coverage_keep_alive_flight(
	coverer: VolleyballPlayer,
	contact_position: Vector2,
	incoming_trajectory: Dictionary,
	arrival: Dictionary,
	body_velocity_mps: Vector2,
	contact_time: float,
	candidates: Array[VolleyballPlayer],
	starts: Dictionary,
	plan: Resource,
	designated_setter_id: int,
	release_seat: Vector2,
) -> Dictionary:
	if not _physical_platform_dig_enabled() or coverer == null:
		return {}
	var intent_actor := _second_contact_setter(
		candidates, plan, designated_setter_id, coverer.id
	)
	if intent_actor == null:
		return {}
	## The aim point is the team's own set-up seat -- the same anchor the dig and
	## the downstream M5 second-contact chooser both target -- so the keep-alive
	## and the set it feeds converge on one point rather than two. Height and the
	## arrival floor track the named actor, which is where the soft intent lives.
	var recipient_position := Vector2(starts.get(intent_actor.id, release_seat))
	var intent := _platform_intent(
		"attack_coverage", release_seat, "release_seat",
		intent_actor, recipient_position,
	)
	var physical := _physical_platform_dig_result(
		coverer, contact_position, incoming_trajectory,
		arrival, body_velocity_mps, intent, contact_time,
	)
	if physical.is_empty():
		return {}
	physical["platform_intent"] = intent
	return physical


## Stamp a coverage event with the physical keep-alive's own ball, the same keys
## the DIG event carries, so the setter and the drawing share one object instead
## of the coverage contact inventing a second flight afterwards.
func _merge_coverage_flight_metadata(meta: Dictionary, flight: Dictionary) -> void:
	meta["outgoing_trajectory"] = flight.get("trajectory", {})
	meta["platform_contact"] = flight.get("platform_contact", {})
	meta["pass_apex_meters"] = flight.get("pass_apex_meters", 0.0)
	meta["pass_contact_height_meters"] = flight.get(
		"pass_contact_height_meters", 0.0
	)
	meta["set_contact_height_meters"] = flight.get("set_contact_height_meters", 0.0)
	meta["pass_duration_seconds"] = flight.get("duration", 0.0)
	meta["target_error_meters"] = flight.get("target_error_meters", 0.0)


## Body velocity is a derived journey, in the same court frame as the incoming
## ball. Required movement can end before the ball arrives; a settled body then
## contributes no fictional extra travel merely because the flight continued.
func _platform_body_velocity(
	start: Vector2,
	contact: Vector2,
	required_seconds: float,
	available_seconds: float,
) -> Vector2:
	var duration := available_seconds
	if required_seconds > 0.0 and available_seconds > 0.0:
		duration = minf(required_seconds, available_seconds)
	if duration <= 0.0001:
		return Vector2.ZERO
	return Vector2(
		(contact.x - start.x) * CourtConstants.COURT_WIDTH_METERS / duration,
		(contact.y - start.y) * CourtConstants.COURT_LENGTH_METERS / duration,
	)


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
	## Who is going to take this ball, because how high they can reach is half of
	## what decides the pass's hang time -- and, when the pass is bad enough,
	## whether they get hands on it at all.
	setter: VolleyballPlayer = null,
	## The soft intent this reception is aimed at (the designated setter's release
	## seat), the receiver's own body velocity through the contact, and when the
	## serve reaches them. Supplied so the physical branch can launch one
	## authoritative ball through the shared resolver; empty/zero leaves the legacy
	## scatter untouched, which is what keeps the flag-off path byte-identical.
	platform_intent: Dictionary = {},
	body_velocity_mps: Vector2 = Vector2.ZERO,
	contact_time: float = 0.0,
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
	## **How high the ball was put up, and therefore how long the setter has.**
	##
	## The flight time was `0.38 + distance / lerp(5.2, 8.4, execution)` clamped
	## into 0.42..1.25 -- a horizontal speed dressed as a duration, in which a good
	## pass got to the setter *faster* than a bad one. That is backwards. A good
	## pass is a high one; height is the entire currency of a second contact,
	## because it is the only thing that buys the setter time to arrive, square up
	## and choose, and buys the hitters time to find their run-ups behind it.
	##
	## So the pass is now described the way a coach describes it -- how high it
	## went -- and the hang time falls out of gravity. The apex band is the one
	## that was already here as `lerpf(1.1, 2.8, execution)`, which was passed to
	## the trajectory as an apex, thrown away by the drawing, and read by nothing:
	## a value computed correctly and dropped, which is this engine's commonest
	## defect and was hiding the fix to this one.
	var pass_contact_height := GeometricAttackPromotionModel \
		.pass_contact_height_meters(receiver)
	var pass_apex := pass_contact_height + lerpf(
		PASS_APEX_RISE_MIN_METERS, PASS_APEX_RISE_MAX_METERS, execution
	)
	## A shanked ball is not a low ball -- it is an uncontrolled one, and off a
	## flailing platform it goes *up*. Drawn that way as well as timed that way,
	## which is what "looks like an uncontrolled high contact" means.
	if execution < SHANK_EXECUTION:
		pass_apex += lerpf(
			SHANK_EXTRA_RISE_METERS, 0.0, execution / SHANK_EXECUTION
		)
	## The setter takes the ball as high as they can reach and as high as it got.
	## Both halves matter: a tall setter cannot play a ball above its own apex,
	## and a pass that never rises to hand height has to be bumped.
	var set_contact_height := minf(
		pass_apex,
		GeometricAttackPromotionModel.set_contact_height_meters(setter) \
			if setter != null else pass_apex,
	)
	var flight_time := BallFlightModel.duration_for_apex(
		pass_contact_height, set_contact_height, pass_apex
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
	var reception_result := {
		"destination": destination,
		"body_alignment": body_alignment,
		"platform_feasibility": platform_feasibility,
		"contact_posture": posture,
		## **The term the posture was decided by, carried out with it.**
		##
		## Measured over 300 rallies: 50 of 464 floor contacts published a reach
		## margin and 414 did not, and the 50 were all one path -- the opponent's
		## defence. So the rig's `reaching` pose looked unreachable when the
		## classifier was fine; what was missing was the input, on nine contacts
		## in ten. Where the margin *is* present, `reaching` fires on 62% of
		## contacts. A pose is not dead because its threshold is wrong when the
		## number it reads never arrives.
		"reach_margin_meters": reach_margin,
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
		## Same repair as the dig: the rise stays the published apex and the two
		## absolute heights, which this model has computed all along, now reach
		## the record instead of stopping at the event metadata.
		"trajectory": _ball_trajectory(
			"reception_pass", contact_position, destination,
			flight_time, maxf(pass_apex - pass_contact_height, 0.0), rally_clock,
			NAN, NAN, pass_contact_height, set_contact_height
		),
		## The three numbers the second contact needs, stated rather than
		## re-derived. `set_contact_height_meters` is what `SetterCapabilitySystem`
		## reads to decide whether this is a hands set, a jump set or a ball the
		## setter has to dig up off their platform.
		"pass_apex_meters": pass_apex,
		"pass_contact_height_meters": pass_contact_height,
		"set_contact_height_meters": set_contact_height,
	}
	## Physical reception overlays one authoritative launch on the legacy result.
	## The receiver-state fields above (recovery, posture, feasibility, alignment)
	## are what the contact did to the passer and stay as measured; only the
	## outgoing ball is replaced, and the free flight is handed to M5 for the
	## actual second contact. `set_contact_height_meters` becomes NaN because there
	## is no setter contact yet -- M5 supplies it once a body intercepts.
	if _physical_platform_reception_enabled() and not platform_intent.is_empty():
		var physical := _physical_platform_dig_result(
			receiver, contact_position, incoming_trajectory, arrival,
			body_velocity_mps, platform_intent, contact_time, "reception",
		)
		if not physical.is_empty():
			reception_result["trajectory"] = physical.trajectory
			reception_result["authoritative_free_flight"] = \
				physical.authoritative_free_flight
			reception_result["destination"] = physical.destination
			reception_result["pass_apex_meters"] = physical.pass_apex_meters
			reception_result["pass_contact_height_meters"] = \
				physical.pass_contact_height_meters
			reception_result["set_contact_height_meters"] = \
				physical.set_contact_height_meters
			reception_result["platform_contact"] = physical.platform_contact
			reception_result["target_error_meters"] = physical.get(
				"target_error_meters", 0.0
			)
	return reception_result


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

## Where each pose begins, as a *shortfall* against the posture's own norm.
##
## `shortfall = 1 - control / expected`, so zero is a contact that scored exactly
## what its posture usually does and positive numbers are how far short it fell.
## Normalising by posture first is what makes one scale work across a table that
## spans an order of magnitude -- a reaching contact scoring 0.105 against a norm
## of 0.08 is a *good* contact and lands at -0.31, which is where it belongs.
##
## Measured over 252 contacts, the shortfall distribution runs:
##
##     p50 0.087   p75 0.187   p80 0.207   p85 0.236
##     p90 0.260   p95 0.342   p97 0.363   p99 0.461
##
## The bands below are read off that. They replace a single `poor` flag set at
## `RECOVERY_POOR_SHARE`, which sat at **p75** -- so the worst quarter of every
## contact qualified for a severe pose, and three of them were drawn from that
## quarter. Twenty-two per cent of all contacts ended up on the floor, and
## `blown_away` was landing on contacts whose control was 0.444 against an
## average of 0.475. The pose said catastrophe and the contact was ordinary.
##
## Ordered thresholds on one scale also make severity monotone by construction.
## The old branches could not be: `knee` was gated on posture and `blown_away` on
## force, so they selected different populations and `blown_away` ended up
## producing *better* passes (mean 0.301) than `knee` (0.208) -- the worst thing
## that can happen to a defender being, on average, better than the second worst.
const RECOVERY_KNEE_SHORTFALL: float = 0.207
const RECOVERY_FALL_SHORTFALL: float = 0.300
## Deliberately equal to the fall band, not stricter than it.
##
## Set at p95 of the shortfall it produced exactly one blown-away contact in
## 252 -- the band emptying out, which is the failure the previous version of
## this file already hit from the other direction. Being driven off the ball is
## not a *worse contact* than falling; it is the same badly-handled ball
## arriving heavy. So the two share a threshold and the force gate is what
## separates them: go down when you mishandle it, get knocked off it when the
## ball was also too fast for you.
const RECOVERY_BLOWN_SHORTFALL: float = 0.300

## How far a voli's own poise moves those bands, either way.
##
## Footing and balance used to be `or`-ed in as outright verdicts -- below 0.34
## and you fell, whatever the contact did. That is a player constant deciding a
## contact outcome, and it is the shape that lets a defender be drawn falling
## over on a ball they passed perfectly. They shift where the bands sit instead,
## so poise still matters and still cannot manufacture a catastrophe out of a
## good contact.
const RECOVERY_POISE_SWING: float = 0.06

## How hard the ball has to arrive to drive an average voli off it.
##
## Re-measured and moved. This was 0.78, described as "the top tenth of arcs" --
## and against the contacts that actually reach a defender it is **p68**, so a
## third of every ball arriving qualified as heavy. Combined with a `poor` gate
## that was also loose, seven per cent of all contacts were being drawn as
## blown away. 0.894 is p75 of the same distribution, which with the shortfall
## bands narrowed leaves this band genuinely rare rather than merely uncommon.
##
## **One gate, not two.** The band originally asked for a *dire* contact as well
## as a heavy ball, and measured that turned out to be self-defeating: the
## contacts with the worst control are the ones the defender had to stretch for,
## and a defender stretching is explicitly not being blown away. Requiring both
## made the band structurally empty -- 0 of 1,078 contacts. What actually happens
## is a defender standing in the right place taking something too fast for them,
## so the force does the work and a poor contact is the qualifier.
const RECOVERY_HEAVY_FORCE: float = 0.86

## How far a voli's own anchoring moves that threshold, either way.
##
## Half the old 0.44, because the base moved and the swing was never re-checked
## against it. At 0.44 around 0.894 a well-anchored voli needed 1.11 to be
## driven off a ball, and force is capped at 1.0 -- so the band was unreachable
## for exactly the players it was meant to distinguish. 0.24 around 0.86 spans
## 0.74 to 0.98, which stays inside the scale at both ends.
const RECOVERY_ANCHOR_SWING: float = 0.24

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

## What a jump costs in condition, and what a metre of court costs.
##
## **Jumping is the expensive thing a volleyball player does**, and by some
## distance: it is a maximal effort of the whole leg, repeated, and it is what
## empties a middle blocker across five sets while a libero who covers more
## ground is still fresh. So a jump is worth roughly forty metres of walking, and
## the two are separated rather than blended into one per-rally figure.
##
## The pair is anchored on the match rather than picked: a starter plays on the
## order of two hundred rallies in a five-setter, jumps on perhaps half of the
## ones they are involved in, and covers a few metres on most. `RECOVERY_FATIGUE_COST`
## below is the third channel and was already priced this way -- a trip to the
## floor is more than a jump, because getting up is work the jump does not have.
##
## `JUMP_EFFORT_COST` is the full-effort figure. A jump set or a soft block reads
## as a fraction of it via the effort each contact actually used, so a side that
## runs everything at full stretch pays for that and a side that plays within
## itself does not.
## Both anchored on the measured match rather than guessed. At the first values
## tried (0.0022 and 0.00005) a five-set match left the most-worked starter at
## 0.531 -- inside `laboured` and short of `spent`, so the error channel the
## design exists to deliver could never fire. Scaled by the ratio that measurement
## demanded, which puts a worked starter into `spent` late in a fifth set and
## leaves the median one labouring. The ratio between them is unchanged, because
## the ratio is the design and only the scale was wrong.
const JUMP_EFFORT_COST: float = 0.0048
const TRAVEL_COST_PER_METER: float = 0.00011
## And what a *sprint* costs over a walk, per metre. An approach or a scramble is
## an acceleration, not a stroll, and the design asks explicitly for that
## separation: "explosive actions like sprinting or diving should also consume
## stamina, and moving around in general should sap stamina gradually".
const SPRINT_COST_MULTIPLIER: float = 3.4

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


## Court-space direction in which the ball reaches a contact. The trajectory's
## launch point is authoritative when present; `fallback_start` is an already-
## resolved origin held by the call site, never a guessed bearing. M3 consumes
## only this direction, so no speed, endpoint-height or presentation quantity is
## smuggled into body placement with it.
func _incoming_ball_direction(
	trajectory: Dictionary,
	contact_position: Vector2,
	fallback_start: Vector2,
) -> Vector2:
	var start := Vector2(trajectory.get("start_position", fallback_start))
	var travel := contact_position - start
	return travel.normalized() if travel.length_squared() > 0.000001 else Vector2.ZERO


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
	last_dig_reach_margin = float(dig_terms.get("reach_margin_meters", 0.0))
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
	## How far short of its own posture's norm this contact fell.
	##
	## One number, and the posture is already inside it. That is what lets a
	## single set of ordered bands cut a table whose entries span an order of
	## magnitude -- and what stops a reaching contact, which normally scores
	## 0.105 against a norm of 0.08, from being read as a disaster because 0.105
	## is a small number.
	var expected := float(POSTURE_EXPECTED_CONTROL.get(posture, 0.54))
	var shortfall := 1.0 - control / maxf(expected, 0.001)

	## Poise moves the bands; it does not decide.
	##
	## Footing and balance used to be `or`-ed in as verdicts of their own, so a
	## voli below either threshold was drawn going down on *every* contact
	## regardless of how well they played it. Here they shift where the bands sit
	## by at most `RECOVERY_POISE_SWING` either way: a defender with poor poise
	## goes down on a contact a steady one survives, and neither of them goes
	## down on a good one.
	var poise := (_recovery_footing(receiver) + _recovery_balance(receiver)) * 0.5
	var shift := (0.5 - poise) * 2.0 * RECOVERY_POISE_SWING

	## Ordered, worst first, on one scale -- so a worse contact can never land in
	## a gentler pose than a better one. The old branches selected different
	## populations through different gates and were not ordered at all:
	## `blown_away` came out better on average than `knee`.
	##
	## Being driven off the ball keeps its extra requirement, because it is the
	## one state that is not simply about handling it badly -- a defender is
	## blown away by a ball that was too heavy for them, and without the force
	## gate this band would just be "the worst contacts", which is `fall`.
	## The anchor still sets how heavy is heavy for this particular voli.
	## The anchor swing has to keep the whole band inside the scale it reads.
	##
	## At 0.44 around a 0.894 base, a well-anchored voli needed 1.11 -- and force
	## is capped at 1.0, so no ball in the game could ever knock them off. A
	## threshold outside its own distribution, arrived at by moving the base
	## without re-checking what the swing did to the top of the range.
	var force_needed := RECOVERY_HEAVY_FORCE \
		+ (_recovery_anchor(receiver) - 0.5) * RECOVERY_ANCHOR_SWING
	if shortfall >= RECOVERY_BLOWN_SHORTFALL - shift \
			and incoming_force >= force_needed \
			and posture != "reaching":
		## A defender already stretched for a ball is not standing in front of
		## it, so there is nothing to be driven off. Stated as a gate rather than
		## left to the arithmetic: it held only by accident once the force
		## threshold moved, and an accident is not a model.
		return "blown_away"
	if shortfall >= RECOVERY_FALL_SHORTFALL - shift:
		return "fall"
	if shortfall >= RECOVERY_KNEE_SHORTFALL - shift:
		return "knee"
	return "platform"


## Record what a contact cost the player who made it, and charge it.
##
## Two costs, and they are different in kind. The *delay* is spent inside this
## rally -- it is why a defender who dug off the floor is not the one covering
## the next ball -- and the *fatigue* is spent across the match. Both are booked
## here so no call site can take the pose without the price.
## **What a body is still carrying when a new phase state is built.**
##
## `RallyStateBuilder` makes every actor at rest, BALANCED and IDLE, and the
## resolver rebuilds a phase state several times per rally. So a blocker who had
## just landed, or a defender still getting up off the floor, arrived in the next
## phase as though nothing had happened -- the debt was still charged against
## their *clock* through `_recovery_time_penalties`, but the body the contact
## envelope looked at was fresh.
##
## `player_recovery` has carried both the debt and a **name** for it since it was
## written (`"airborne"` from a block jump, `"fall"`, `"knee"`, `"blown_away"`,
## `"platform"` from a floor contact). Nothing ever read the name back. This does,
## and nothing else: no new state, no new value, no new relation. A voli who owes
## nothing at this moment is left exactly as the builder made them.
##
## This is what `ContactEnvelopeSystem`'s AIRBORNE takeoff exclusion and the
## claimant's usable-time requirement were both waiting on -- two certified
## repairs that could not fire because the state they test never survived a leg.
## See `docs/review/ACTOR_CONTINUITY.md`.
## Records the orientation a committed leg left a body in, when its form
## establishes one at all. A `"transition"` or `"approach"` leg opens the body up
## and the route becomes the orientation; every other form preserves what was
## already there, so nothing is written and nothing is overwritten.
func _commit_facing(player_id: int, leg: Dictionary) -> void:
	var exit_velocity := Vector2(leg.get("exit_velocity", Vector2.ZERO))
	if exit_velocity.length_squared() <= 0.0001:
		return
	player_facing[player_id] = exit_velocity.normalized()


func _seed_carried_body_states(state: RallyState, at_time: float) -> void:
	if state == null:
		return
	for actor in state.all_player_states():
		## Orientation first, and independently of the recovery debt below: a
		## body that owes nothing still finished its last leg facing somewhere.
		if player_facing.has(actor.player_id):
			actor.facing = Vector2(player_facing[actor.player_id])
		var record: Dictionary = player_recovery.get(actor.player_id, {})
		if record.is_empty():
			continue
		var ready_at := float(record.get("ready_at", 0.0))
		if ready_at <= at_time:
			continue
		actor.recovery_until = maxf(actor.recovery_until, ready_at)
		## A body still owing a block jump has not landed; every other debt is a
		## body getting back up. The distinction is the one `player_recovery`
		## already draws, not a new one.
		actor.body_state = RallyPlayerState.BodyState.AIRBORNE \
			if str(record.get("state", "")) == "airborne" \
			else RallyPlayerState.BodyState.RECOVERING
		## Recovery preserves whatever orientation the last real movement
		## established, which is what the moving-orientation policy says it does.
		actor.movement_mode = RallyPlayerState.MovementMode.RECOVERY


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



## How long each blocker is still off the floor when the ball comes down.
##
## **A blocker who has just jumped was competing for the next ball as though
## they were standing ready.** `_note_recovery` is called at exactly five sites,
## all of them platform contacts -- a reception or a dig -- so nothing in the
## engine ever recorded that a body is airborne. `_recovery_time_penalties` is
## handed to `CoverageModel.choose_claimant` for the floor defence, and for a
## front-row blocker it was always empty: the claim search gave them the ball's
## whole flight to reach it, starting from a body two feet in the air.
##
## Measured over 300 rallies: **0 of 151 defensive contacts** happened with any
## body registered unavailable. After this, 72 of 155.
##
## Nothing here is invented. `block_jump_timing` already publishes each blocker's
## `hang_seconds` and whether they went up late, and `BlockJumpModel.jump_timeline`
## already turns that into a landing instant -- `hang_seconds` itself is
## `2 * sqrt(2 * leap / g)`, ballistics rather than a tuned number. All of it was
## consumed only by playback, so the engine drew the jump correctly and then
## forgot about it when deciding who could reach the next ball.
##
## Written straight into `player_recovery` rather than through `_note_recovery`,
## because that function looks its delay up in `RECOVERY_DELAY_SECONDS` by name
## and the four states there are floor recoveries -- knee, fall, blown away.
## Adding a fifth would be inventing a duration for something the jump model
## already measures. The record shape is the one `_recovery_time_penalties` and
## `_recovery_debt` read, so the existing mechanism carries it unchanged.
##
## An airborne blocker is not "recovering" the way a dug-out defender is. The
## state is named so that stays legible, and it deliberately takes no fatigue
## cost: `RECOVERY_FATIGUE_COST` prices hitting the floor, and the jump is
## already charged elsewhere.
func _note_block_airborne(
	timing: Dictionary, blockers: Array, contact_time: float
) -> void:
	for blocker in blockers:
		var body: VolleyballPlayer = blocker as VolleyballPlayer
		if body == null or not timing.has(body.id):
			continue
		var entry: Dictionary = timing[body.id]
		var hang := float(entry.get("hang_seconds", 0.0))
		if hang <= 0.0:
			continue
		var error := absf(float(entry.get("timing_error_seconds", 0.0)))
		var peak := contact_time + (error if bool(entry.get("late", false)) else -error)
		var landing := peak + hang * 0.5
		var owed := landing - contact_time
		if owed <= 0.0:
			continue
		## Never shorten a debt this voli already owes. A blocker who was still
		## getting up from the previous ball and jumped anyway keeps the longer
		## of the two, rather than having the jump wipe the floor recovery.
		var existing := float(
			Dictionary(player_recovery.get(body.id, {})).get("ready_at", 0.0)
		)
		if existing >= landing:
			continue
		player_recovery[body.id] = {
			"state": "airborne",
			"ready_at": landing,
			"delay": owed,
		}


## Which way each of these bodies is set, for the claim search.
##
## **Side-relative and toward the net**, which is where a voli waiting for the
## other team's attack stands -- and it is mirrored, because the two sides face
## opposite ways down the same axis. Not toward the ball: preparation must not
## gain information from the action it is about to be tested against.
##
## This is the *standing* case, and it is the honest one for a defender who has
## not moved since the rally reset them. A defender who has chased a ball has no
## established post-movement orientation anywhere in this engine -- see
## `docs/review/READY_ORIENTATION.md` for why that transition is the boundary
## this pass stops at, and why guessing it here would be inventing a turn model.
func _ready_facings(player_ids: Array, side: StringName) -> Dictionary:
	var facings := {}
	for raw_id in player_ids:
		facings[int(raw_id)] = RallyPlayerState.side_relative_ready_facing(side)
	return facings

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


## A player who is still in a contact-recovery state cannot begin an attack
## approach.  The recovery was already charged to second-contact and defensive
## claim clocks; hitter selection was the hole, which let the same receiver be
## drawn on a knee or blown backwards and then instantly become the selected
## attacker.  Selection reads the state at the decision cue, so a player who is
## up before a later exchange naturally returns to the pool.
func _can_enter_attack(player: VolleyballPlayer, at_time: float = NAN) -> bool:
	if player == null:
		return false
	var decision_time := rally_clock if is_nan(at_time) else at_time
	return _recovery_debt(player.id, decision_time) <= 0.0


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
## Where this voli has to run to get round the bodies in their way, or `null`
## when the line is clear. The corner comes back with the body that caused it
## and how far short of clearance they were, so the bend can be drawn against
## the thing it bends around instead of appearing from nowhere.
##
## **A collision is not a decision.** The first version of this charged a flat
## delay before the claim, so a badly obstructed setter simply lost the ball to
## somebody clearer -- which is a setter choosing not to go, and a setter
## choosing not to go is not a collision. It was also invisible: a number added
## to a number, with nothing for playback to draw.
##
## What actually happens is that the voli still goes and their route bends. A
## back-row setter runs round the passer who stepped in short; a middle loses
## their approach to a libero on the floor behind them; two volis crossing the
## same ground each give way a little. So this returns the corner they have to
## turn, `_movement_time` times the staged route through it, and the cost falls
## out of the geometry rather than being asserted.
##
## The corner is the closest point on the line, pushed sideways until the
## obstructing body clears -- away from them, so the detour goes round rather
## than through. Worst obstruction only: a voli threading two bodies takes the
## wider berth, and stacking every detour would bend a path into a spiral for
## a court that has five other people on it.
## `bodies` is the caller's own side, id to position. It is deliberately not
## `live_positions`: that dictionary is the home side only and holds just the
## players who have already moved this rally, so the opponent's setter was
## being tested against bodies on the far half of the net -- never within
## clearance, so the whole thing was inert over there. The second-contact
## candidate `starts` are side-correct and cover all six, so they are what gets
## passed in.
## How much room this mover leaves *this* teammate, as a multiple of a torso.
##
## Two volis who have run this overlap a hundred times pass close: each knows
## which way the other will break, so neither swings wide. Two who have not both
## hedge, and hedging is a wider berth and therefore a longer route -- which is
## the cost of poor cohesion expressed as geometry rather than as a penalty
## added to a number.
##
## Ego is the other half and it acts on the *mover*: a voli who does not expect
## to be moved for holds their line and cuts close, and the give-way is somebody
## else's problem. That is not a virtue. It is why a squad of high-ego volis
## produces the collisions this model is for, and it is measured on the mover
## alone because the obstructing body is not making a decision here -- they are
## standing somewhere.
## **Centred, not lerped between two ends.** The first version was
## `lerp(1.30, 0.80, settled)`, which hands an ordinary squad 1.12 -- so the
## knob did not separate squads, it widened every berth in the game by 12% and
## called that cohesion. The movement-agreement gate caught it: SET already
## carries a documented residual at its lower bound and a systematically longer
## second-contact route tipped it.
##
## So this is a deviation from 1.0 about a stated neutral. A default squad
## (`Team` ships 0.50 cohesion and 0.35 familiarity, and an unknown pair reads
## `BASELINE` 24 of 100) computes `settled` = 0.361, which sits slightly wide of
## neutral on purpose: a squad that has not played together should hedge a
## little.
##
## The swing is deliberately modest and deliberately measured rather than felt.
## It is not yet known whether +/-8% of a torso changes anything a player would
## notice -- `tools/obstruction_probe.tscn` is what says so, and the value stays
## small until it does.
const BERTH_NEUTRAL_SETTLED: float = 0.50
const BERTH_COHESION_SWING: float = 0.16
## **Sized against the cohesion swing, after being six times it.** This was 0.18
## next to a 0.16 *total* span, so a high-ego voli cut 18% closer than an
## ordinary one while the entire cohesion axis moved 8% -- the temperament
## dominated the thing it was supposed to modulate, and the fatigue gate caught
## it: with this function stubbed out the suite passed, with it live peak
## fatigue over 24 weeks fell from above 0.15 to 0.10. Every detour in the game
## was being resized by one attribute.
##
## It is the same mistake as `SECOND_CONTACT_EGO_PULL`, made twice in one
## change: a magnitude asserted in prose and never checked against the terms
## beside it.
const BERTH_EGO_RELIEF: float = 0.06


## `PairFamiliarityModel` counts to `CEILING`, which is 100, and everything on
## this page works in fractions.
##
## Written without this, both cohesion knobs read a pair table entry of 24.0 as
## a 0-1 weight, so `clampf(0.28 + 8.4, 0.0, 1.0)` pinned them at 1.0 for every
## pair on the court. Cohesion had no effect whatever, in either direction, and
## the code looked exactly as though it did -- the §0 failure, in the same
## commit that adds the knob it disables. Caught by a fatigue gate, not by
## reading it.
func _pair_fraction(first_id: int, second_id: int) -> float:
	return clampf(
		PairFamiliarityModel.of(pair_familiarity, first_id, second_id)
			/ PairFamiliarityModel.CEILING,
		0.0, 1.0,
	)


func _berth_scale(mover: VolleyballPlayer, other_id: int) -> float:
	if mover == null:
		return 1.0
	var settled := clampf(
		(team_cohesion + team_tactical_familiarity) * 0.5 * 0.65
			+ _pair_fraction(mover.id, other_id) * 0.35,
		0.0, 1.0,
	)
	var ego_lean := (float(mover.ego) - 50.0) / 50.0 * BERTH_EGO_RELIEF
	return clampf(
		1.0 + (BERTH_NEUTRAL_SETTLED - settled) * BERTH_COHESION_SWING - ego_lean,
		0.72, 1.24,
	)


func _navigation_waypoint(
	mover: VolleyballPlayer, start: Vector2, target: Vector2, bodies: Dictionary
) -> Variant:
	if mover == null or start.is_equal_approx(target):
		return null
	var worst_shortfall := 0.0
	var corner: Variant = null
	## Who, and where they were standing. Not a reason to be narrated -- an
	## obstruction should read as two bodies nearly touching and one of them
	## going round, never as a caption saying so. It is here because playback
	## cannot draw the near miss without knowing which body it was, and because
	## a route that bends away from nothing is unfalsifiable.
	var blame := -1
	var blame_position := Vector2.ZERO
	for other_id in bodies:
		if int(other_id) == mover.id:
			continue
		var here := Vector2(bodies[other_id])
		var closest := Geometry2D.get_closest_point_to_segment(here, start, target)
		var offset := RallyKinematics.court_delta_meters(here, closest)
		var gap := offset.length()
		if gap >= OBSTRUCTION_CLEARANCE_M:
			continue
		## A body already on the floor is given a wider berth than one standing:
		## they cannot shift, so the whole of the avoiding is the mover's to do.
		var clearance := OBSTRUCTION_CLEARANCE_M * _berth_scale(mover, int(other_id))
		if float(player_recovery.get(int(other_id), {}).get("delay", 0.0)) > 0.0:
			clearance *= OBSTRUCTION_GROUNDED_BERTH
		var shortfall := clearance - gap
		if shortfall <= worst_shortfall:
			continue
		worst_shortfall = shortfall
		blame = int(other_id)
		blame_position = here
		## Straight out from the obstruction through the point on the path
		## nearest it, which is the shortest way past. Degenerate only when a body
		## is exactly on the line, and then any side will do -- the path's own
		## normal is the one that stays deterministic.
		var direction := offset.normalized() if gap > 0.001 else Vector2(
			-(target - start).normalized().y, (target - start).normalized().x
		)
		corner = closest + Vector2(
			direction.x * shortfall / CourtConstants.COURT_WIDTH_METERS,
			direction.y * shortfall / CourtConstants.COURT_LENGTH_METERS,
		)
	if corner == null:
		return null
	return {
		"corner": corner, "obstructed_by": blame,
		"obstruction_position": blame_position,
		"shortfall_meters": worst_shortfall,
	}


## Puts the second-contact claim onto the event that resulted from it.
##
## `_spatial_setter_choice` computes the reach margin, the claim gap, the seam
## and the corner the setter had to turn, and until this existed exactly one of
## them -- the travel time -- left the function. The rest were computed and
## dropped at the seam, which is the fault this file has now made four times.
##
## `navigation_waypoint` is the one with a drawn consequence: both playback
## paths already stage a corner for a hitter's approach, and a setter running
## round the passer who stepped in short is the same shape of leg.
##
## Skipped wholesale when the live setter replaced the chosen body, because
## then every field describes somebody who did not take the ball.
func _stamp_second_contact_claim(event: RallyEvent, choice: Dictionary) -> void:
	if event == null or choice.is_empty():
		return
	var chosen := choice.get("player") as VolleyballPlayer
	if chosen == null or int(event.actor_id) != chosen.id:
		return
	## `arrival_margin` is deliberately not on this list: every call site already
	## stamps its own, computed after the live-setter override may have moved
	## the contact window, and the chooser's is the pre-override figure.
	for key in [
		"reach_margin_meters", "claim_margin", "seam_conflict", "contested_by",
		"claimant_count",
	]:
		if choice.has(key):
			event.metadata[key] = choice[key]
	_stamp_navigation(event, choice.get("navigation"))


## The corner, the body it goes round, and where that body was standing.
##
## `obstructed_by` is diagnostic and drawable, not narratable: an obstruction
## should read as two volis nearly touching and one of them going round, never
## as a caption saying somebody was in the way. Playback needs the identity to
## draw the near miss at all, and a route that bends away from nothing is
## unfalsifiable without it.
func _stamp_navigation(event: RallyEvent, navigation: Variant) -> void:
	if event == null or navigation == null:
		return
	var data := Dictionary(navigation)
	event.metadata["navigation_waypoint"] = Vector2(data["corner"])
	event.metadata["obstructed_by"] = int(data.get("obstructed_by", -1))
	event.metadata["obstruction_position"] = Vector2(
		data.get("obstruction_position", Vector2.ZERO)
	)
	event.metadata["obstruction_shortfall_meters"] = float(
		data.get("shortfall_meters", 0.0)
	)


## How much this voli calls for a ball nobody has been assigned.
##
## Legs and duty decide most of a second contact and they are the two terms
## above this one. What they cannot express is that a loose ball between two
## bodies is settled by who *shouts* -- and three separate temperaments answer
## that differently:
##
## - **ego** is the one that takes a ball it has no business taking. It is the
##   unwillingness to be talked off a decision, so it belongs here rather than
##   in a duty weight: duty is what the sheet says and ego is what happens when
##   nobody consults the sheet.
## - **leadership** is the mirror image, and it is why it is worth half as much.
##   Both make a voli likelier to end up with the ball, but leadership does it
##   by the others *clearing out*, which is a good outcome, and ego does it by
##   the others being overruled, which is often not.
## - **aggression** barely belongs and is here small and deliberate: a second
##   ball is not a terminal contact, so the voli who wants to end rallies has
##   only a slight pull toward being the one who touches it. If this term grows
##   it is a sign the second contact is being modelled as an attack.
##
## Sized against `duty_bonus` -- but **this paragraph used to state that spread
## wrongly and the constants below were sized against the wrong number.** It
## read "+0.46 for the designated setter and -0.24 for no duty at all -- a
## spread of 0.70", which takes the designated-setter term as if it were the
## whole of that voli's duty. It is not: it is added *on top of* whatever the
## plan already gave them, so the real extreme is +0.80 -- the plan's own
## "Primary emergency setter" (+0.34) plus the designated-setter term (+0.46) --
## and the real spread is **1.04**. Measured, not reasoned:
## `tools/run_second_contact_probe.gd` and `docs/review/SECOND_CONTACT_AUDIT.md`.
##
## The constants are left where they are. 0.09 against 1.04 is still well under
## the tenth the paragraph below claims, so the sizing conclusion survives its
## own arithmetic being wrong -- which is worth saying plainly rather than
## quietly correcting, because it was luck and not judgement.
##
## **The first sizing said a tenth and was a third.** 0.14 + 0.07 + 0.04 reaches
## 0.25 for a voli at the top of all three, which is enough to hand a second
## ball to somebody with no duty at all, and the fatigue gate caught it: matches
## resolved differently enough that peak fatigue over 24 weeks fell from above
## 0.15 to 0.10. Stating a magnitude in a comment is not the same as having it,
## and the arithmetic was never done. These reach 0.09 together, which is the
## tenth the paragraph claims: it decides a coin flip and never overrules the
## sheet.
##
## Cohesion is *not* here on purpose. A confident squad does not produce a voli
## who wants the ball more; it produces one who yields cleanly when somebody
## else has it. That is the seam, and it is handled there.
const SECOND_CONTACT_EGO_PULL: float = 0.050
const SECOND_CONTACT_LEADERSHIP_PULL: float = 0.025
const SECOND_CONTACT_AGGRESSION_PULL: float = 0.015


func _second_contact_temperament(candidate: VolleyballPlayer) -> float:
	if candidate == null:
		return 0.0
	## Centred on 50, so an ordinary voli contributes nothing and the term is a
	## deviation rather than a bonus everyone collects. A knob that only ever
	## adds is a knob that has moved the baseline instead of separating players.
	return (float(candidate.ego) - 50.0) / 50.0 * SECOND_CONTACT_EGO_PULL \
		+ (float(candidate.leadership) - 50.0) / 50.0 * SECOND_CONTACT_LEADERSHIP_PULL \
		+ (float(candidate.aggression) - 50.0) / 50.0 * SECOND_CONTACT_AGGRESSION_PULL


## The existing second-contact decision policy, separated from the endpoint
## search so M5 can apply the same attributes and tactical responsibilities to
## physically discovered interception opportunities. This extraction changes no
## weight and introduces no new preference.
func _second_contact_duty_bonus(
	candidate: VolleyballPlayer,
	defensive_plan: Resource,
	designated_setter_id: int,
	preferred_setter: VolleyballPlayer,
) -> float:
	if candidate == null:
		return -1000.0
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
		duty_bonus = 0.46
	elif candidate == preferred_setter:
		duty_bonus += 0.20
	return duty_bonus


func _second_contact_claim_score(
	candidate: VolleyballPlayer,
	arrival_margin: float,
	defensive_plan: Resource,
	designated_setter_id: int,
	preferred_setter: VolleyballPlayer,
) -> float:
	if candidate == null:
		return -1000.0
	var arrival_score := clampf(arrival_margin / 1.2, -1.0, 1.0)
	return arrival_score * 0.52 \
		+ _rating(candidate, "set_accuracy") * 0.28 \
		+ _rating(candidate, "decision_making") * 0.12 \
		+ _second_contact_duty_bonus(
			candidate, defensive_plan, designated_setter_id, preferred_setter
		) \
		+ _second_contact_temperament(candidate)


## What a teammate nearby is worth, which is not always positive.
##
## **Two volis in one space were being scored as double coverage.** The term
## this replaces was `min(count * 0.025, 0.075)` -- a count of reachable
## teammates, with no distance in it at all, added as a bonus. A teammate five
## metres away and one thirty centimetres away contributed identically, and the
## crowded case contributed *more* because crowding puts more bodies in reach.
##
## Cover is a band, not a monotone. A teammate too far away is not covering this
## ball; one on top of you is worse than nobody, because at that spacing you get
## platform interference, a blocked sightline, a foot in your step and a moment
## of who-has-it. The peak sits where a second body can chase a deflection
## without being inside your swing.
##
## Sized so the harm can exceed the help. A bonus that bottoms out at zero would
## make stacking *neutral*, and neutral is still not a reason to stop doing it
## -- the handoff's point is that bad spacing has to cost something a manager
## can see. The floor is deliberately deeper than the ceiling is high.
##
## Distances are unmeasured as thresholds: nothing had ever published defender
## spacing, which is why the old term could go this long without anyone
## noticing it had no distance in it. `tools/responsibility_probe.gd` prints the
## distribution now, and these want cutting from it rather than from taste.
const SUPPORT_CROWDING_METERS: float = 1.05
const SUPPORT_PEAK_METERS: float = 2.40
const SUPPORT_FADE_METERS: float = 5.00
const SUPPORT_HELP_CEILING: float = 0.075
const SUPPORT_CROWDING_FLOOR: float = -0.140


func _support_term(support_count: int, nearest_teammate_meters: float) -> float:
	if support_count <= 0:
		return 0.0
	var spacing := nearest_teammate_meters
	if spacing >= SUPPORT_FADE_METERS:
		## Reachable, but not near enough to be doing anything about this ball.
		return 0.0
	if spacing <= SUPPORT_CROWDING_METERS:
		## Inside each other. Worst at zero and easing to neutral at the edge of
		## the crowding band, so a voli at 1.04 m is not treated the same as one
		## standing on the claimant's feet.
		return lerpf(
			SUPPORT_CROWDING_FLOOR, 0.0,
			clampf(spacing / maxf(SUPPORT_CROWDING_METERS, 0.01), 0.0, 1.0),
		)
	## Useful cover, strongest at the peak and fading out to nothing. The count
	## still matters a little -- three teammates covering is better than one --
	## but it is capped hard, because the second body does most of the work and
	## the fourth does almost none.
	var closeness := 1.0 - clampf(
		absf(spacing - SUPPORT_PEAK_METERS)
			/ maxf(SUPPORT_FADE_METERS - SUPPORT_PEAK_METERS, 0.01),
		0.0, 1.0,
	)
	return SUPPORT_HELP_CEILING * closeness \
		* minf(float(support_count) / 2.0, 1.0)


## M5's launch-time body state. Positions, velocity, facing and recovery are all
## carried facts. The pre-contact release is the same transition head start the
## legacy chooser already used, but it runs toward the intent's release seat --
## a fact available before the dig -- rather than toward the realised ball.
func _second_contact_actor_states(
	candidates: Array[VolleyballPlayer],
	starts: Dictionary,
	side: StringName,
	expected_area: Vector2,
	head_start_seconds: float,
	launch_time: float,
) -> Array[RallyPlayerState]:
	var actors: Array[RallyPlayerState] = []
	var velocities: Dictionary = opponent_live_velocities \
		if side == &"opponent" else live_velocities
	for candidate in candidates:
		if candidate == null:
			continue
		var start := Vector2(starts.get(candidate.id, expected_area))
		var actor := RallyPlayerState.create(candidate, side, -1, start)
		actor.velocity = Vector2(velocities.get(candidate.id, Vector2.ZERO))
		actor.facing = Vector2(player_facing.get(
			candidate.id, RallyPlayerState.side_relative_ready_facing(side)
		))
		var recovery: Dictionary = player_recovery.get(candidate.id, {})
		var recovery_delay := float(recovery.get("delay", 0.0))
		var running := maxf(head_start_seconds - recovery_delay, 0.0)
		if running > 0.0 and expected_area != Vector2.ZERO:
			var projected := RallyMovementSystemModel.project_toward(
				actor, expected_area, running,
				RallyPlayerState.MovementMode.TRANSITION,
			)
			var projected_actor := projected.get("actor") as RallyPlayerState
			if projected_actor != null:
				actor = projected_actor
		var ready_at := float(recovery.get("ready_at", 0.0))
		if ready_at > launch_time:
			actor.recovery_until = ready_at
			actor.committed_until = maxf(actor.committed_until, ready_at)
			actor.body_state = RallyPlayerState.BodyState.AIRBORNE \
				if str(recovery.get("state", "")) == "airborne" \
				else RallyPlayerState.BodyState.RECOVERING
			actor.movement_mode = RallyPlayerState.MovementMode.RECOVERY
		actors.append(actor)
	return actors


## The receiving side's shared action-choice contest on a ball that crossed the
## net unresolved -- an overpass. Builds the whole receiving six as actors from
## the authoritative live maps (position/velocity/facing/recovery/commitment via
## the existing `_second_contact_actor_states` recipe, never presentation) and
## asks `OverpassActionSystem.choose()` which physically and legally feasible
## action wins. Returns the choice dict, or `{}` when nothing is feasible.
##
## The legacy resolver drives no persistent `RallyState`, so the wrappers use
## `choose()`/`execute_control()`/`execute_attack()` (which need none) and hand the
## generated free flight to the existing transition machinery, rather than
## `apply_first_contact()`, which is built for the live-integrator `RallyState`.
func _overpass_choice(
	free_flight: Dictionary,
	receiving_players: Array,
	receiving_side: StringName,
	lineup: RotationLineup,
	principles: Resource,
) -> Dictionary:
	if lineup == null:
		return {}
	## The whole receiving six, at their live positions when the ball crosses.
	## `OverpassActionSystem` applies its own eligibility and rotation legality;
	## this only has to present every actor with authoritative state.
	var typed: Array[VolleyballPlayer] = []
	var starts := {}
	var positions: Dictionary = opponent_live_positions \
		if receiving_side == &"opponent" else live_positions
	for entry in receiving_players:
		var player := entry as VolleyballPlayer
		if player == null:
			continue
		typed.append(player)
		starts[player.id] = Vector2(positions.get(
			player.id, Vector2(free_flight.get("start_position", Vector2.ZERO))
		))
	## `expected_area = Vector2.ZERO` disables the pre-contact projection: an
	## overpass is reacted to from where the body actually is, not walked toward a
	## known seat, because nobody called this ball to anyone.
	var launch_time := float(free_flight.get("start_time", rally_clock))
	var actors := _second_contact_actor_states(
		typed, starts, receiving_side, Vector2.ZERO, 0.0, launch_time
	)
	return OverpassActionModel.choose(
		free_flight, actors, lineup, receiving_side, principles
	)


## Execute a chosen controlled/emergency first contact. The intent is the
## receiving side's own release anchors, all class C -- the same seat and contact
## height every reception and dig already use. `arrival_floor_seconds` is the
## setter's own journey to the seat; slack means the ball is not rushed. Returns
## `{}` when the platform model cannot realise a launch.
func _overpass_execute_control(
	choice: Dictionary,
	setter: VolleyballPlayer,
	setter_release_seat: Vector2,
	setter_position: Vector2,
) -> Dictionary:
	if setter == null:
		return {}
	var intent := {
		"target_anchor": setter_release_seat,
		"height_anchor_meters": GeometricAttackPromotionModel \
			.set_contact_height_meters(setter),
		"arrival_floor_seconds": _movement_time(
			setter, setter_position, setter_release_seat, "transition"
		),
	}
	## Derived, not drawn from `rng`: perturbing the rally RNG here would move every
	## downstream draw on a path that is meant to be inert until it fires.
	var seed_value := rally_seed + 90_000 + int(choice.get("player_id", 0))
	var execution := OverpassActionModel.execute_control(choice, intent, seed_value)
	if not bool(execution.get("available", false)):
		return {}
	execution["contact_position"] = Vector2(choice.get(
		"contact_position", setter_release_seat
	))
	execution["contact_time"] = float(choice.get("contact_time", 0.0))
	execution["realised_trajectory"] = choice.get("realised_trajectory", {})
	execution["platform_intent"] = intent
	return execution


## Backwards-compatible composition used by the focused live-wiring gate: choose,
## then execute the control half. `{}` when the contest picks an attack or nothing
## is feasible.
func _overpass_control_contact(
	free_flight: Dictionary,
	receiving_players: Array,
	receiving_side: StringName,
	lineup: RotationLineup,
	principles: Resource,
	setter: VolleyballPlayer,
	setter_release_seat: Vector2,
	setter_position: Vector2,
) -> Dictionary:
	var choice := _overpass_choice(
		free_flight, receiving_players, receiving_side, lineup, principles
	)
	if not bool(choice.get("available", false)) \
			or str(choice.get("action", "")) == "attack":
		return {}
	return _overpass_execute_control(
		choice, setter, setter_release_seat, setter_position
	)


## Home receives an overpass (the ball crossed back to the home court). Runs the
## shared contest and either plays the first team contact into the home
## transition (control) or swings and hands the ball to the opponent defence
## (attack), or returns `null` so the caller keeps its terminal. `null` also
## covers the exchange cap: an overpass is a net crossing, and resolving it past
## `MAX_EXCHANGES` would run a contact beyond the rally's own bound.
func _resolve_overpass_into_home(
	result: Resource,
	free_flight: Dictionary,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
	incoming_quality: float,
) -> Resource:
	if exchange_number >= MAX_EXCHANGES or defensive_plan == null:
		return null
	var choice := _overpass_choice(
		free_flight, players, &"home", lineup, home_principles
	)
	if not bool(choice.get("available", false)):
		return null
	var actor := _player_by_id(players, int(choice.get("player_id", -1)))
	if actor == null:
		return null
	if str(choice.get("action", "")) == "attack":
		return _resolve_overpass_attack(
			result, choice, free_flight, actor, &"home", players, lineup,
			opponent_team, defensive_plan, exchange_number, incoming_quality,
		)
	var setter := _player_by_id(players, lineup.active_setter_id())
	if setter == null:
		return null
	var seat: Vector2 = defensive_plan.setter_release_target(
		lineup.active_setter_id()
	)
	var contact := _overpass_execute_control(
		choice, setter, seat, Vector2(live_positions.get(setter.id, seat))
	)
	var generated: Dictionary = contact.get("outgoing_trajectory", {})
	if contact.is_empty() or generated.is_empty():
		return null
	var contact_pos := Vector2(contact.get("contact_position", seat))
	live_positions[actor.id] = contact_pos
	_add_event(
		result, RallyEventModel.EventType.RECEPTION, actor.id, actor.display_name,
		Vector2(free_flight.get("start_position", contact_pos)), contact_pos,
		true, incoming_quality, "%s plays the overpass" % actor.display_name,
		"Home first contact on a ball that crossed the net.",
		_overpass_event_metadata(&"home", contact),
	)
	return _resolve_home_continuation(
		result, players, lineup, actor, contact_pos, opponent_team,
		defensive_plan, exchange_number + 1, incoming_quality, 0.0, 0.0, generated,
	)


## Opponent receives an overpass (the ball crossed to the opponent court).
## Symmetric to the home path.
func _resolve_overpass_into_opponent(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	free_flight: Dictionary,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
	incoming_quality: float,
	original_hitter: VolleyballPlayer,
) -> Resource:
	if exchange_number >= MAX_EXCHANGES or opponent_team == null:
		return null
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	if opponent_lineup == null:
		return null
	var choice := _overpass_choice(
		free_flight, opponent_team.on_court_players(), &"opponent",
		opponent_lineup, opponent_principles
	)
	if not bool(choice.get("available", false)):
		return null
	var actor_id := int(choice.get("player_id", -1))
	var actor: VolleyballPlayer = null
	for entry in opponent_team.on_court_players():
		var candidate := entry as VolleyballPlayer
		if candidate != null and candidate.id == actor_id:
			actor = candidate
			break
	if actor == null:
		return null
	if str(choice.get("action", "")) == "attack":
		return _resolve_overpass_attack(
			result, choice, free_flight, actor, &"opponent", players, lineup,
			opponent_team, defensive_plan, exchange_number, incoming_quality,
		)
	var setter := _opponent_setter(opponent_team)
	if setter == null:
		return null
	var seat := _opponent_setter_release_target(opponent_team)
	var contact := _overpass_execute_control(
		choice, setter, seat, Vector2(opponent_live_positions.get(setter.id, seat))
	)
	var generated: Dictionary = contact.get("outgoing_trajectory", {})
	if contact.is_empty() or generated.is_empty():
		return null
	var contact_pos := Vector2(contact.get("contact_position", seat))
	opponent_live_positions[actor.id] = contact_pos
	_add_event(
		result, RallyEventModel.EventType.RECEPTION, actor.id, actor.display_name,
		Vector2(free_flight.get("start_position", contact_pos)), contact_pos,
		true, incoming_quality, "%s plays the overpass" % actor.display_name,
		"Opponent first contact on a ball that crossed the net.",
		_overpass_event_metadata(&"opponent", contact),
	)
	return _resolve_opponent_transition(
		result, players, lineup, original_hitter, contact_pos, opponent_team,
		defensive_plan, exchange_number + 1, incoming_quality, false, actor.id,
		NAN, 0.0, generated, 0.0,
	)


## The attack half of the overpass contest. The receiving side swings on the
## first ball; the outgoing swing is an authoritative free flight, and the
## DEFENDING side meets it through the same first-contact mechanism -- a dig or
## an emergency play, or a kill when nobody can reach it. No pre-formed block is
## modelled: a direct attack off a first contact gives the block no set to form
## against, and forming one would require the `tempo`/`set_quality`/setter inputs
## `_form_*_block` needs and an overpass has none of -- see
## `OVERPASS_ACTION_HANDOFF.md`. `blockers = []` accordingly, and "opportunity is
## not an automatic kill" holds because an in-play swing is routed to the defence.
func _resolve_overpass_attack(
	result: Resource,
	choice: Dictionary,
	free_flight: Dictionary,
	attacker: VolleyballPlayer,
	attacking_side: StringName,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
	incoming_quality: float,
) -> Resource:
	var defending_home := attacking_side == &"opponent"
	var defence_map: Dictionary = live_positions if defending_home \
		else opponent_live_positions
	var defending_positions: Array = []
	for value in defence_map.values():
		defending_positions.append(Vector2(value))
	## The attacker's own live position, read from the map for the side they are
	## actually on -- `defence_map` above is the *defending* side's.
	##
	## The previous fallback was `attacker.position`, which could never return
	## anything: a `VolleyballPlayer` is a Resource carrying attributes and has
	## never had a `position`. Two failures, not one. `Dictionary.get` evaluates
	## its default eagerly, so that access ran on *every* call and pushed an error
	## even when `choice` carried a perfectly good contact position; and on the
	## path it was written for it produced `Vector2(null)`, putting a first-ball
	## overpass swing in the corner of the court instead of under the attacker.
	## A fallback that cannot reach its own stated range, failing silently in the
	## one case it exists for.
	var attack_map: Dictionary = opponent_live_positions if defending_home \
		else live_positions
	var attacker_at := Vector2(0.5, 0.5) if attacker == null \
		else Vector2(attack_map.get(attacker.id, Vector2(0.5, 0.5)))
	var contact_pos := Vector2(choice.get("contact_position", attacker_at))
	## The wall the defence can actually form against a *no-set* first-contact
	## attack. Its geometry comes only from live inputs: the attack lane
	## (`contact_pos.x`) and the closure window, which is the incoming overpass
	## flight -- the time the front row had to close. `preset_window_seconds = 0.0`
	## is a true statement (there was no set to pre-read), and `tempo`/`set_quality`
	## are neutral read-cue defaults for a contact that had no set to grade. When
	## no blocker can close in the window, `block_wall` returns an empty wall --
	## no *viable* block, correctly, rather than a skipped one. See
	## `OVERPASS_ACTION_HANDOFF.md`.
	var window := maxf(
		float(choice.get("contact_time", 0.0))
			- float(free_flight.get("start_time", 0.0)),
		0.05,
	)
	var formation: Dictionary
	var wall: Array = []
	if defending_home:
		formation = _form_home_block(
			players, lineup, defensive_plan, contact_pos.x, 1, 0.5,
			contact_pos.x, window, 0.0, attacker, 0.0, {"overpass": true},
		)
		wall = GeometricAttackPromotionModel.block_wall(
			formation, _home_block_fallbacks(players, lineup), live_positions,
			"Balanced", 0.0,
		)
	else:
		formation = _form_opponent_block(
			opponent_team, contact_pos.x, 1, 0.5, contact_pos.x, window, 0.0,
			attacker, 0.0,
		)
		wall = GeometricAttackPromotionModel.block_wall(
			formation, _opponent_block_fallbacks(opponent_team),
			opponent_live_positions, "Balanced", 0.0,
		)
	var attacking_principles: Resource = home_principles \
		if attacking_side == &"home" else opponent_principles
	var decisiveness := 0.5
	if attacking_principles != null:
		var raw: Variant = attacking_principles.get("decisiveness")
		decisiveness = 0.5 if raw == null else clampf(float(raw), 0.0, 1.0)
	var seed_value := rally_seed + 91_000 + int(choice.get("player_id", 0))
	var execution := OverpassActionModel.execute_attack(
		choice, wall, defending_positions, decisiveness, 0.0, seed_value
	)
	if not bool(execution.get("available", false)):
		return null
	var swing: Dictionary = execution.get("swing", {})
	var outgoing: Dictionary = execution.get("outgoing_trajectory", {})
	if outgoing.is_empty():
		return null
	var landing := Vector2(swing.get("landing", contact_pos))
	var outcome := str(swing.get("outcome", "in"))
	var errored := outcome in ["net", "out"]
	_add_event(
		result, RallyEventModel.EventType.ATTACK, attacker.id, attacker.display_name,
		contact_pos, landing, not errored, float(choice.get("score", 0.5)),
		"%s attacks the overpass" % attacker.display_name,
		"First-contact attack on a ball that crossed the net.",
		{
			"side": str(attacking_side), "overpass": true,
			"team_contact_number": 1, "outgoing_trajectory": outgoing,
			"swing_outcome": outcome, "first_contact_action": "attack",
			"block_wall_size": wall.size(),
		},
	)
	## The block resolved the contest inside `resolve_swing` from the real wall.
	## `net`/`out` is the attacker's error; a `stuff` is the defence's point; a
	## `tool`/`high_hands`/`block_crush` beat the hands for the attacker's point.
	if errored:
		return _finish(
			result, "attack_error" if attacking_side == &"home" \
				else "opponent_attack_error",
			attacking_side == &"opponent", attacker.id,
			{"hitter": attacker.display_name},
		)
	if outcome in ["stuff", "monster_block"]:
		if attacking_side == &"home":
			return _finish(
				result, "blocked", false, attacker.id,
				{"hitter": attacker.display_name},
			)
		var blocker := formation.get("primary") as VolleyballPlayer
		return _finish(
			result, "counter_block", true,
			blocker.id if blocker != null else attacker.id,
			{"hitter": attacker.display_name},
		)
	if outcome in ["tool", "block_crush", "high_hands"]:
		return _finish(
			result, "kill" if attacking_side == &"home" else "opponent_kill",
			attacking_side == &"home", attacker.id,
			{"hitter": attacker.display_name},
		)
	## In play (clean cross or a soft touch/deflection): the defending side plays
	## the crossed swing as its own first contact. A returned rally means they
	## controlled it; `null` means nobody could -- the swing lands, the attacker's
	## point. (A block deflection back to the attacking side -- a recycle -- is not
	## modelled as attacker coverage here; that is coverage/M6 scope, and it falls
	## to the same kill fallback, over-crediting the attacker on a rare sub-case.)
	var defence: Resource = null
	if attacking_side == &"home":
		defence = _resolve_overpass_into_opponent(
			result, players, lineup, outgoing, opponent_team, defensive_plan,
			exchange_number + 1, 0.6, attacker,
		)
	else:
		defence = _resolve_overpass_into_home(
			result, outgoing, players, lineup, opponent_team, defensive_plan,
			exchange_number + 1, 0.6,
		)
	if defence != null:
		return defence
	return _finish(
		result, "kill" if attacking_side == &"home" else "opponent_kill",
		attacking_side == &"home", attacker.id, {"hitter": attacker.display_name},
	)


## The first-contact event's metadata, in the shape a continuation and playback
## already read. `team_contact_number = 1` because crossing the net is a change
## of possession; `overpass = true` marks the contact for the census.
func _overpass_event_metadata(side: StringName, contact: Dictionary) -> Dictionary:
	return {
		"side": str(side),
		"overpass": true,
		"team_contact_number": 1,
		"outgoing_trajectory": contact.get("outgoing_trajectory", {}),
		"realised_trajectory": contact.get("realised_trajectory", {}),
		"platform_intent": contact.get("platform_intent", {}),
		"platform_contact": contact.get("platform_contact", {}),
		"first_contact_action": str(contact.get("action", "")),
	}


## Apply the existing second-contact responsibility policy to physically
## discovered opportunities. Physics decides who can meet which point of the
## flight; tactics and attributes decide which viable claimant takes it.
func _physical_second_contact_choice(
	free_flight: Dictionary,
	candidates: Array[VolleyballPlayer],
	starts: Dictionary,
	defensive_plan: Resource,
	designated_setter_id: int,
	first_contact_player_id: int,
	preferred_setter: VolleyballPlayer,
	side: StringName,
	expected_area: Vector2,
	expected_height_meters: float,
	head_start_seconds: float,
) -> Dictionary:
	var actors := _second_contact_actor_states(
		candidates, starts, side, expected_area, head_start_seconds,
		float(free_flight.get("start_time", rally_clock)),
	)
	var physical := FreeFlightInterceptionModel.opportunities(
		free_flight, actors, &"set", true, [first_contact_player_id],
		expected_area, expected_height_meters,
	)
	if not bool(physical.get("available", false)):
		return physical
	var available: Dictionary = physical.get("opportunities", {})
	var best := {}
	var best_score := -1000.0
	var claimants: Array = []
	for raw_id in available:
		var opportunity: Dictionary = available[raw_id]
		var candidate := opportunity.get("player") as VolleyballPlayer
		if candidate == null:
			continue
		var score := _second_contact_claim_score(
			candidate, float(opportunity.get("arrival_margin", 0.0)),
			defensive_plan, designated_setter_id, preferred_setter,
		)
		claimants.append({"id": candidate.id, "score": score})
		if score > best_score:
			best_score = score
			best = opportunity.duplicate(true)
			best["score"] = score
	claimants.sort_custom(func(a, b) -> bool: return float(a.score) > float(b.score))
	best["claimant_count"] = claimants.size()
	best["seam_conflict"] = false
	if claimants.size() >= 2:
		var gap := float(claimants[0].score) - float(claimants[1].score)
		best["claim_margin"] = gap
		best["seam_conflict"] = gap < _seam_margin(
			_player_by_id(candidates, int(claimants[0].id)),
			_player_by_id(candidates, int(claimants[1].id)),
		)
		best["contested_by"] = int(claimants[1].id)
	best["terminal"] = physical.get("terminal", {})
	best["authoritative_free_flight"] = free_flight
	best["intended_setter_had_opportunity"] = available.has(
		designated_setter_id
	)
	if not best.is_empty() and best.has("contact_time"):
		best["realised_trajectory"] = FreeFlightInterceptionModel.realised_prefix(
			free_flight, float(best.contact_time)
		)
	return best


func _stamp_free_flight_resolution(
	result: Resource,
	choice: Dictionary,
) -> void:
	if result == null or result.events.is_empty() or choice.is_empty():
		return
	var feeding_event := result.events[-1] as RallyEvent
	if feeding_event == null:
		return
	var free_flight: Dictionary = choice.get("authoritative_free_flight", {})
	if free_flight.is_empty():
		return
	feeding_event.metadata["authoritative_free_flight"] = free_flight
	feeding_event.metadata["free_flight_terminal"] = choice.get("terminal", {})
	feeding_event.metadata["intended_setter_had_opportunity"] = bool(
		choice.get("intended_setter_had_opportunity", false)
	)
	var realised: Dictionary = choice.get("realised_trajectory", {})
	if not realised.is_empty():
		feeding_event.metadata["outgoing_trajectory"] = realised
		feeding_event.metadata["pass_duration_seconds"] = float(
			realised.get("duration", 0.0)
		)
		feeding_event.metadata["set_contact_height_meters"] = float(
			choice.get("contact_height_meters", NAN)
		)
		feeding_event.end_position = Vector2(choice.get(
			"contact_position", feeding_event.end_position
		))
		## A contact that publishes where its ball was actually played to keeps that
		## field in step with the endpoint above: under a physical launch the pass
		## has no authored destination, so "where it went" is the interception, not
		## the floor the untouched flight would have reached. Written only when the
		## key already exists, so the families that never published one keep their
		## metadata shape exactly.
		if feeding_event.metadata.has("actual_pass_target"):
			feeding_event.metadata["actual_pass_target"] = feeding_event.end_position
		feeding_event.metadata["realised_interceptor_id"] = int(choice.get(
			"player_id", -1
		))
		feeding_event.metadata["free_flight_resolution"] = "intercepted"
		return
	var terminal: Dictionary = choice.get("terminal", {})
	var terminal_time := float(terminal.get(
		"time", free_flight.get("end_time", free_flight.get("start_time", 0.0))
	))
	var terminal_segment := FreeFlightInterceptionModel.realised_prefix(
		free_flight, terminal_time
	)
	if not terminal_segment.is_empty():
		feeding_event.metadata["outgoing_trajectory"] = terminal_segment
		feeding_event.end_position = Vector2(terminal.get(
			"position", feeding_event.end_position
		))
		if feeding_event.metadata.has("actual_pass_target"):
			feeding_event.metadata["actual_pass_target"] = feeding_event.end_position
	feeding_event.metadata["free_flight_resolution"] = str(terminal.get(
		"reason", "unresolved"
	))


func _spatial_setter_choice(
	candidates: Array[VolleyballPlayer],
	starts: Dictionary,
	defensive_plan: Resource,
	designated_setter_id: int,
	first_contact_player_id: int,
	preferred_setter: VolleyballPlayer,
	target: Vector2,
	available_time: float,
	## **How long these volis have already been running when the pass is
	## played.** Zero is the old behaviour and is a lie the engine told itself
	## everywhere: every second contact was timed from a standing start at the
	## instant the platform touched the ball, as though the setter had spent the
	## whole serve flight watching.
	##
	## Measured before this existed, the setter's arrival margin ran a median
	## -0.37 s with a p95 of -0.03 s -- 95% of setters arriving late to their own
	## ball, which is not a hard game, it is a missing head start. It also made
	## the jump set unreachable, since loading a hop needs margin nobody had.
	##
	## Spent as *distance already covered*, not as time added to the window. A
	## setter did not get two seconds to react to a pass that had not happened;
	## they got a head start toward the place the ball was always going, and the
	## pass then tells them how much of the last adjustment they still owe.
	head_start_seconds: float = 0.0,
	## **Where the setter is running while the head start runs, which is not
	## where the ball turns out to go.**
	##
	## The first cut advanced every candidate toward `target` -- the resolved
	## pass destination -- during the serve flight, which is a coordinate that
	## does not exist yet. A setter releasing on serve contact knows the serve's
	## trajectory, the likely receiver and the zone they are supposed to set
	## from; they do not know where the platform will actually put the ball.
	## Running them at the answer is precognition, and it makes the head start a
	## free arrival rather than a real one.
	##
	## `Vector2.ZERO` means "no expectation published", and then the head start
	## is spent toward the target as before -- kept only so a caller that has not
	## been given a zone is unchanged rather than silently frozen.
	expected_area: Vector2 = Vector2.ZERO,
) -> Dictionary:
	var best := {"player": preferred_setter, "start": target, "travel_time": 4.0}
	var best_score := -1000.0
	var claimants: Array = []
	for candidate in candidates:
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var start: Vector2 = starts.get(candidate.id, target)
		## Where the run had already got to. A voli still on the floor spends
		## their head start getting up rather than moving, which is what the
		## recovery delay subtracted here says -- and it is why the same head
		## start is worth nothing to somebody who has just dug the ball.
		var running := maxf(
			head_start_seconds
				- float(player_recovery.get(candidate.id, {}).get("delay", 0.0)),
			0.0,
		)
		var origin := start
		if running > 0.0:
			## Toward the expectation, then the rest of the run is the correction
			## the real ball demands -- which is what a setter's second stride
			## actually is.
			start = _reached_point(
				candidate, start,
				expected_area if expected_area != Vector2.ZERO else target,
				running, "transition",
			)
		## Getting up comes out of the same budget as getting there. A voli still
		## on the floor is not a candidate to set the next ball, and this is what
		## says so -- without it the emergency setter search would happily pick
		## someone lying down because they were standing in the right place.
		##
		## **Somebody was standing in the way.** Travel time was a straight line
		## across an empty floor, so a setter who ran into the passer stepping in
		## short arrived exactly as fast as one with a clear run. The route bends
		## round them now and the cost is the bend, not a charge -- see
		## `_navigation_waypoint`, and note that `_movement_time` already staged a
		## corner correctly, carrying speed through it rather than restarting.
		var detour: Variant = _navigation_waypoint(candidate, start, target, starts)
		var travel_time := _movement_time(
			candidate, start, target, "transition",
			detour["corner"] if detour != null else null,
		) + float(player_recovery.get(candidate.id, {}).get("delay", 0.0)) \
			* _recovery_debt(candidate.id, rally_clock)
		## **How confidently, not merely whether.**
		##
		## The physical half now comes from the same `evaluate_arrival` the first
		## contact uses, judged from where this body actually is rather than from a
		## formation slot -- so a second contact reports a reach margin in metres
		## the way a reception always has. The duty weighting below stays local,
		## because a serve receive and a second ball genuinely do rank
		## responsibility differently and one shared chooser would have to pretend
		## otherwise.
		##
		## No zone: there is no second-contact zone type, and a null one used to
		## exclude a candidate outright. Admitted with no responsibility credit
		## instead, which is the same correction `assigned_reach` already carries
		## -- legs decide who can get there, the assignment decides who should.
		var arrival: Dictionary = CoverageModel.evaluate_arrival(
			candidate, null, target, maxf(available_time, 0.02),
			"set_accuracy", start, 0.0,
		)
		var reach_margin := float(arrival.get("reach_margin_meters", 0.0))
		## **The active setter's responsibility replaces the plan's, it does not
		## stack on it.** `Primary emergency setter` and `Secondary emergency
		## setter` describe who covers *when the normal setter cannot take the
		## second contact*. They are a fallback hierarchy, and reading them as an
		## extra bonus for the normal setter is a category error: it made the
		## setter's own authority depend on which slot the rotation had put them
		## in, because the plan writes those duties per slot.
		##
		## `+=` totalled +0.80 in slot 2 (where the plan's own primary emergency
		## duty lives), +0.64 in slot 1 and +0.22 in the other four -- a swing of
		## 0.58 that no design document asks for. And the top of that range was
		## exactly pathological: +0.80 against a no-duty -0.24 is a gap of 1.04,
		## while `arrival_score` below is clamped to [-1, 1] and weighted 0.52, so
		## the whole authority the legs have is **also 1.04**. Two spans of
		## identical width, so in that one rotation the legs could tie
		## responsibility and never beat it. Measured: a stranded setter kept a
		## ball a team-mate was standing on in rotation 2 and lost it in all five
		## others, on identical geometry.
		##
		## `=` gives the setter a flat +0.46 in every rotation. That is still
		## above the plan's primary emergency duty (+0.34), so responsibility
		## stays strongly first -- and 0.46 against -0.24 is 0.70, inside the
		## legs' 1.04, so an impossible claim can now yield. The policy this
		## implements: **strong first responsibility, not absolute.**
		##
		## Note this branch is unreachable for a setter who played the first
		## contact -- they are excluded from `candidates` above -- so the fallback
		## hierarchy among the remaining five is untouched by the change.
		## `docs/review/SECOND_CONTACT_TRANSFER.md`;
		## `tools/run_second_contact_probe.gd` gates 1-6.
		var score := _second_contact_claim_score(
			candidate, available_time - travel_time, defensive_plan,
			designated_setter_id, preferred_setter,
		)
		if score > best_score:
			best_score = score
			best = {
				"player": candidate, "start": start, "travel_time": travel_time,
				## Where the run *began*, before the head start advanced it, and
				## how long the whole run took. Anything asking "did this voli
				## have to travel into the ball" needs both: the leg left after
				## the head start is a scrap, and the average speed over a scrap
				## is not the speed the body is carrying when it arrives.
				"origin": origin,
				"total_travel_seconds": travel_time + running,
				## Published so a caller can tell a setter who arrived with time
				## to spare from one who barely got there, which is the whole of
				## what "confidently" means here and was not expressible before.
				"reach_margin_meters": reach_margin,
				"arrival_margin": available_time - travel_time,
				## The corner they had to turn, so playback bends the run rather
				## than drawing a straight line through somebody -- and the body
				## it goes round, so the bend is drawn against its cause.
				"navigation": detour,
				"reachable": bool(arrival.get("reachable", false)),
			}
		if bool(arrival.get("reachable", false)):
			claimants.append({"id": candidate.id, "score": score})
	## **Two volis who both think it is theirs.** The first contact has called
	## this a seam conflict since it was written; the second never had the
	## concept, so a setter and a libero converging on the same ball were
	## indistinguishable from a setter taking it alone.
	claimants.sort_custom(func(a, b) -> bool: return float(a.score) > float(b.score))
	## **A sentinel inside the range of real values is not a sentinel.** The
	## no-rival case used to publish `claim_margin = 1.0`, and real gaps run up
	## to 1.201 -- so the distribution the seam threshold acts on was mostly a
	## stand-in that could not be told apart from a genuine wide gap. Measured
	## over 1,520 second contacts: median 1.000, p05 1.000. More than half were
	## the stand-in, which is why `SECOND_CONTACT_SEAM_MARGIN` fired zero times.
	##
	## Uncontested now publishes no gap at all. `claimant_count` says which case
	## it was, so "nobody else could reach it" stays distinguishable from "one
	## other could, and was well behind".
	best["claimant_count"] = claimants.size()
	best["seam_conflict"] = false
	if claimants.size() >= 2:
		var gap := float(claimants[0].score) - float(claimants[1].score)
		best["claim_margin"] = gap
		## **A seam is a failure to delegate, so cohesion is the width of it.**
		##
		## The gap is how far apart two volis' claims are; the threshold is how
		## small a gap this squad can still resolve without both going or neither.
		## A side that has played together reads the same ball the same way and
		## one of them clears out early -- so the window in which they collide is
		## narrow. A side that has not hedges, and a gap that a settled squad
		## would have delegated cleanly becomes two people calling for it.
		##
		## Leadership is the other half and it applies to the *leader of the two*:
		## somebody the room follows shuts a seam that two equals would argue
		## over. Read off whichever claimant leads, not the winner, because a
		## captain deferring is still a captain resolving it.
		best["seam_conflict"] = gap < _seam_margin(
			_player_by_id(candidates, int(claimants[0].id)),
			_player_by_id(candidates, int(claimants[1].id)),
		)
		best["contested_by"] = int(claimants[1].id)
	return best


## How wide the window is in which two volis both think the ball is theirs.
##
## `SECOND_CONTACT_SEAM_MARGIN` is the middle of the range rather than the whole
## of it -- it is what a squad at 0.5 cohesion with two ordinary volis gets.
## Measured over 1,520 second contacts before this existed: the fixed 0.10 fired
## zero times against a real claim-gap distribution starting at p05 0.142, which
## is a threshold sitting outside its own distribution, so a *constant* here was
## never going to be the answer whatever value it took.
##
## The spread is deliberately wide for that reason: at zero cohesion between two
## volis nobody follows it reaches 0.10 * 2.2 = 0.22, which is above the p05 of
## the distribution, and at full cohesion it falls to 0.10 * 0.4 = 0.04, well
## below it. A knob that cannot reach its own range is the failure this
## repository keeps making; this one is built to span it and then be measured.
const SEAM_COHESION_SPAN: Vector2 = Vector2(2.2, 0.4)
const SEAM_LEADERSHIP_RELIEF: float = 0.35


func _seam_margin(first: VolleyballPlayer, second: VolleyballPlayer) -> float:
	## Averaged rather than multiplied, so a new squad who get on is not as bad
	## as a squad who neither drill nor speak.
	var cohesion := clampf(
		(team_cohesion + team_tactical_familiarity) * 0.5, 0.0, 1.0
	)
	## And then *these two specifically*. A squad average says how the room is;
	## `pair_familiarity` says whether these two have played this overlap before,
	## which is the thing that actually decides whether one of them clears out.
	## Weighted below the squad figure because a pair table is sparse early and a
	## missing pair must not read as a hostile one -- `PairFamiliarityModel.of`
	## returns the baseline for an unknown pair, not zero.
	if first != null and second != null:
		cohesion = clampf(
			cohesion * 0.65 + _pair_fraction(first.id, second.id) * 0.35, 0.0, 1.0
		)
	var scale := lerpf(SEAM_COHESION_SPAN.x, SEAM_COHESION_SPAN.y, cohesion)
	var lead := 0.0
	if first != null and second != null:
		lead = maxf(float(first.leadership), float(second.leadership)) / 100.0
	return SECOND_CONTACT_SEAM_MARGIN * scale \
		* lerpf(1.0, 1.0 - SEAM_LEADERSHIP_RELIEF, lead)


## The designated setter, unless they took the first contact -- then whoever the
## plan nominated to cover for them.
##
## **This does not decide who sets.** Every caller hands the answer straight to
## `_spatial_setter_choice` as `preferred_setter`, where it is worth +0.20 in a
## re-score that reads live positions, the realized pass's own duration, the
## head start and recovery debt. So this function contributes a *preference* and
## a null-fallback, and nothing else -- which is the right shape, because it
## takes no position and no clock and could not honestly decide reachability.
##
## Worth knowing before reading the numbers below: they are **not** the duty
## weights `_spatial_setter_choice` uses. The same four duty strings are scored
## +0.42 / +0.24 / -0.10 / -0.22 here and +0.34 / +0.18 / -0.16 / -0.24 there,
## and `ShadowSetterResponseSystem._duty_priority` uses a third table that ranks
## "Stay available to attack" *below* "No second-contact duty" -- the opposite
## order to both of these. Three tables for one concept, in one leg. Recorded in
## `docs/review/SECOND_CONTACT_AUDIT.md` §4 rather than unified here, because
## picking which table is canonical is a tactical decision, not a tidy-up.
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
	players: Array,
	lineup: RotationLineup,
	defensive_plan: Resource,
	blocked_hitter: VolleyballPlayer,
	target: Vector2,
	block_quality: float,
	opponent_side: bool = false,
) -> Dictionary:
	var best: VolleyballPlayer
	var best_score := -1000.0
	var by_id := {}
	for raw_player in players:
		var listed := raw_player as VolleyballPlayer
		if listed != null:
			by_id[listed.id] = listed
	for slot_number in range(1, 7):
		var candidate := by_id.get(
			int(lineup.player_at_slot(slot_number)), null
		) as VolleyballPlayer
		if candidate == null or candidate.id == blocked_hitter.id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.attack_coverage_responsibility) \
			if assignment != null else "Cover nearest attacker"
		var start := CourtConstants.slot_position(slot_number)
		if opponent_side:
			start.y = 1.0 - start.y
		elif defensive_plan != null:
			start = defensive_plan.defender_position(candidate.id, start)
		start = (
			opponent_live_positions if opponent_side else live_positions
		).get(candidate.id, start)
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


## M4 slice 4: state the body/contact facts an attack-coverage touch already
## implies. This does not select its outgoing ball and does not alter the legacy
## success contest. Arrival comes from the shared movement/reach evaluator;
## posture is classified on the same continuous facts used by a floor dig.
func _attack_coverage_contact_state(
	coverer: VolleyballPlayer,
	start: Vector2,
	contact: Vector2,
	ball_time_seconds: float,
) -> Dictionary:
	if coverer == null:
		return {"arrival": {}, "posture": "missing", "contact_height": 0.0}
	var arrival := CoverageModel.evaluate_arrival(
		coverer, null, contact, ball_time_seconds, "reception",
		start, 0.0,
	)
	var posture := "planted"
	if float(arrival.get("reach_margin_meters", 0.0)) < 0.0:
		posture = "reaching"
	elif float(arrival.get("distance_meters", 0.0)) > POSTURE_DIG_MOVING_METERS:
		posture = "moving"
	return {
		"arrival": arrival,
		"posture": posture,
		"contact_height": GeometricAttackPromotionModel \
			.pass_contact_height_meters(coverer),
	}


func _finish_serve_error(result: Resource, server_name: String) -> Resource:
	## Their error, our point -- the mirror of the home `serve_error` path.
	return _finish(
		result, "serve_error", true, -1, {"server": server_name},
		"opponent_serve_error",
	)


## Which of the three kill explanations a finished swing earns.
##
## Was inline at one of the four kill sites and absent from the other three, so
## the two geometric hitter-point paths asked `EXPLANATIONS` for a `kill` key
## that does not exist.
static func _kill_key(active_play: OffensivePlay, result: Resource) -> String:
	if active_play == null:
		return "kill_default"
	return "kill_called" if bool(result.play_was_followed) else "kill_improvised"


## A factor line with the rally's names filled in.
##
## Factor lines carry placeholders now, and `ExplanationText.factor` cannot
## reach `narration` on its own -- it is a static on a data script with no
## simulator to ask.
func _factor(key: String) -> String:
	return ExplanationText.factor(key, narration)


## A physical dig can put a real ball up that nobody reaches. The point is still
## credited to the attack that forced that unplayable contact, never to the
## defender whose platform launched it. Read the event lineage rather than
## threading another identity through every continuation call.
func _latest_attack_credit(result: Resource, side: String) -> Dictionary:
	if result != null:
		for index in range(result.events.size() - 1, -1, -1):
			var event := result.events[index] as RallyEvent
			if event != null \
					and event.event_type == RallyEventModel.EventType.ATTACK \
					and str(event.metadata.get("side", "")) == side:
				return {"id": event.actor_id, "name": event.actor_name}
	return {"id": -1, "name": "the attacker"}


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
	result.exertion_fatigue = exertion_cost.duplicate()
	var chosen_key := explanation_key if not explanation_key.is_empty() else outcome
	## The caller's names win over the accumulated ones: an opponent's hitter is
	## passed explicitly precisely because `narration["hitter"]` holds ours.
	var filled := narration.duplicate()
	filled.merge(values, true)
	result.explanation = ExplanationText.explanation(chosen_key, filled)
	result.headline = ExplanationText.headline(outcome, filled)
	var end_position := Vector2(0.5, 0.90) if home_won else Vector2(0.5, 0.12)
	_add_event(result, RallyEventModel.EventType.POINT, decisive_actor_id,
		"Home" if home_won else "Opponent", end_position, end_position,
		home_won, 1.0, result.headline, result.explanation)
	result.analysis = _build_rally_analysis(result)
	for serve_key in geometric_serves:
		result.analysis[serve_key] = geometric_serves[serve_key]
	result.analysis["team_identity"] = str(home_principles.preset_name)
	result.analysis["team_principles"] = home_principles.to_dict()
	result.analysis["identity_effects"] = identity_effects.duplicate(true)
	if shadow_reception_trace != null:
		var existing_rollout: Dictionary = _trace_summary().get(
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
	## Cognition is compiled last, and after the timeline, because every cue is
	## an interval on the physical clock `_finalize_rally_timeline` stamps. Built
	## before it, a cue would be positioned against event times that were about to
	## move -- the same ordering mistake that put the drawn ball and the played
	## ball in different places, one contact apart.
	##
	## The vocabulary runs first so a cue may read the name of the action it is
	## reacting to rather than re-deriving it, which is the whole reason the
	## vocabulary is a shared tag and not a caption string.
	RallyActionVocabularyModel.annotate(result)
	result.cognition_cues.assign(CognitionCompilerModel.compile(result))
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


## **Where the ball was when each contact was made, carried forward once.**
##
## `CONTACT_AND_BALL_FLIGHT.md` §5: a realised contact is one point, so the
## incoming segment's far end *is* the contact's height. Every family that
## publishes a resolved flight already states that far end; nothing read it, and
## presentation fell back to a body measurement -- a reach, a platform, a hip --
## which is a fact about the player standing in for a fact about the ball.
##
## This is a copy, not a computation. It reads the incoming leg's own
## `end_height_meters` and only when that leg says it knows
## (`height_source == "resolved"`), so a family whose writer never resolved its
## heights is left alone rather than given a number invented here. That is the
## difference between propagating authority and minting a second one.
##
## The block is skipped because it already publishes its own, proved by the
## intersection test rather than inherited from the incoming flight -- and on a
## beaten block there is no contact for this to be the height of. See
## `docs/review/BLOCK_REALISED_CONTACT.md`.
## Where a published flight ends, in absolute metres, from the flight itself.
##
## Two ways a flight can say, and no third. A writer that resolved both ends
## states it (`height_source == "resolved"`). A writer that resolved its start
## and published its launch has said it implicitly, and integrating that launch
## across the flight's own duration reads it out -- that is evaluating the
## flight, not extrapolating past it, because the duration is the flight's.
##
## `NAN` for a flight that resolved neither, which is honest: the 1.0 m default
## `BallTrajectory.create` falls back to is not a height anybody measured.
static func realised_flight_end_height(trajectory: Dictionary) -> float:
	var source := str(trajectory.get("height_source", "default"))
	if source == "resolved":
		return float(trajectory.get("end_height_meters", NAN))
	if source == "start_resolved" and trajectory.has("launch_vertical_mps"):
		var flown := maxf(float(trajectory.get(
			"physical_duration_seconds",
			float(trajectory.get("duration", 0.0)),
		)), 0.0)
		return float(trajectory.get("start_height_meters", 1.0)) \
			+ float(trajectory["launch_vertical_mps"]) * flown \
			- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * flown * flown
	return NAN


func _stamp_realised_contact_heights(result: Resource) -> void:
	if result == null:
		return
	var previous: RallyEvent = null
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null \
				or int(event.event_type) == RallyEventModel.EventType.POINT:
			continue
		if previous != null \
				and int(event.event_type) != RallyEventModel.EventType.BLOCK:
			## **Only when the incoming flight actually ends at this contact.**
			##
			## `height_source == "resolved"` is that test, and it is a narrower
			## one than it looks. A set is solved *between* two heights, so its
			## far end is the contact that receives it and the two are one point.
			## A serve is not: it publishes the whole flight to where the ball
			## would land, and the reception happens partway along it, so the
			## serve leaves `end_height_meters` unresolved and this correctly
			## declines to speak for the pass.
			##
			## The contact's own outgoing launch height was tried as a second
			## source and rejected on measurement: on the reception it equals the
			## body proxy to three decimals (`|launch - body| = 0.000` over 162
			## legs), so it is the platform wearing a flight's clothes rather
			## than an independent statement about the ball. Preferring it moved
			## no reception seam and widened the opponent set's from 42 breaks to
			## 63. See `docs/review/CONTACT_HEIGHT_CHAIN.md`.
			var incoming: Dictionary = previous.metadata.get(
				"outgoing_trajectory", {}
			)
			var source := str(incoming.get("height_source", "default"))
			if source == "resolved":
				event.metadata["ball_contact_height_meters"] = float(
					incoming.get("end_height_meters", 1.0)
				)
				event.metadata["ball_contact_height_source"] = \
					"incoming_realised_segment"
			elif source == "start_resolved" \
					and incoming.has("launch_vertical_mps"):
				## Same derivation the platform resolver now uses, so the height
				## a contact is *resolved* at and the height it is *drawn* at are
				## one function rather than two that agree by inspection.
				## **A flight that knows where it started and how it left can say
				## where it finished.**
				##
				## The serve is the family this exists for. It resolves its own
				## contact height and its launch and leaves its far end unstated,
				## which read as "the serve cannot say where the pass was" -- and
				## the measurement says otherwise: the serve flight's published
				## end time and the reception's own stamp agree, so the flight is
				## already terminated at the pass rather than running on to the
				## floor. Integrating its launch across its own duration is
				## therefore evaluating the flight *at the contact*, not
				## extrapolating past one.
				##
				## Not a second physics. This is the same integration
				## `BallPresentation` performs to draw the leg, moved to the side
				## of the boundary that owns the fact -- which is the whole of §5.
				event.metadata["ball_contact_height_meters"] = maxf(
					realised_flight_end_height(incoming), 0.0
				)
				event.metadata["ball_contact_height_source"] = \
					"incoming_launch_integrated"
		## **`outgoing.start == C` is the third term and it is not closed here.**
		##
		## Writing the contact height back onto this event's own flight was tried
		## and does nothing: every family that reaches this point publishes a
		## launch, and a launch was solved *from* the start height it shipped
		## with. Overwriting only the height would leave a flight disagreeing with
		## its own length, which is a worse record than an honest gap.
		##
		## What the gap is, exactly: the reception's arc is solved from the
		## platform's height, so once its contact says the ball's height instead,
		## the arc departs from somewhere the contact no longer claims -- 0.29 to
		## 0.42 m, and it appears as a set seam. That disagreement is not created
		## here. It was always in the record and the platform proxy was hiding it
		## on both ends at once. Closing it means re-solving the pass from the
		## ball's height, which moves `pass_apex_meters` and therefore the set
		## clamp, and is simulation work rather than a seam repair. See
		## `docs/review/CONTACT_HEIGHT_CHAIN.md`.
		previous = event


func _finalize_rally_timeline(result: Resource) -> void:
	_ensure_event_trajectories(result)
	## After the trajectories exist and before the timeline is finalised: this
	## reads flights and writes only heights, so it cannot move a contact in time.
	_stamp_realised_contact_heights(result)
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
			## Both defensive contacts, because this is about how long a body
			## takes over a ball it is digging up off the floor, and coverage is
			## that too -- just at a metre rather than at six.
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, \
			RallyEventModel.EventType.ATTACK_COVERAGE:
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
				## **A successful floor dig no longer arrives here.** It publishes
				## its own `outgoing_trajectory` at the contact, so the `continue`
				## at the top of this loop already skipped it. What reaches this
				## arm is a *failed* dig -- a ball nobody controlled -- and the
				## flight drawn for it is display only, which is correct: there is
				## no physical pass to model because no pass happened.
				##
				## **Coverage has to be listed or it silently loses its ball.**
				## The default arm below is `continue`, not a fallback -- an
				## unlisted type gets no `outgoing_trajectory` at all and the ball
				## teleports out of the contact. Splitting the enum without this
				## line would have deleted the flight from every one of the 38
				## coverage contacts in 700 rallies.
				RallyEventModel.EventType.DIG, \
				RallyEventModel.EventType.ATTACK_COVERAGE: flight_time = 0.58
				_: continue
		var apex := 0.5
		match int(event.event_type):
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, \
			RallyEventModel.EventType.ATTACK_COVERAGE:
				apex = 1.8
			RallyEventModel.EventType.SET:
				apex = 2.4
		event.metadata["outgoing_trajectory"] = _ball_trajectory(
			event.type_name().to_lower(), start, end, flight_time, apex,
			float(event.metadata.get("event_time", 0.0))
		)


## Book condition spent by one player, from any channel.
##
## Every charge in the rally funnels through one adder so the total is one number
## and the match layer has one thing to charge. Costs are recorded against the
## player id rather than the player, because the two sides' rosters are different
## objects and the id is what `RallyResult` can carry.
func _charge_exertion(player: VolleyballPlayer, amount: float) -> void:
	if player == null or amount <= 0.0:
		return
	## Surcharged by how blown they already are, which is what makes windedness a
	## feedback term rather than a within-rally cosmetic: the twenty-contact
	## exchange that empties a defender is also the exchange that ages them.
	## Applied before the charge is added so a player is never surcharged by work
	## they have not done yet.
	exertion_cost[player.id] = float(exertion_cost.get(player.id, 0.0)) \
		+ amount * FatigueModel.winded_surcharge(_winded_fraction(player))


## How blown this player is *right now*, inside this rally.
##
## Read straight off the exertion already booked this rally, which is the same
## number the match layer will charge as fatigue -- so windedness needs no state
## of its own and cannot drift out of step with the work that caused it. It
## resets when `exertion_cost` does, at the serve, which is exactly the clock a
## rally-scale quantity should keep.
func _winded_fraction(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return FatigueModel.winded_fraction(
		float(exertion_cost.get(player.id, 0.0)),
		float(player.stamina) / 100.0,
	)


## What this contact cost the legs, if it left the floor at all.
##
## An attack and a block are always jumps. A set is one only when the setter
## actually left the floor -- `setter_capability.reach_state` already says, and a
## bump set from the deck should cost nothing extra. A serve is one only for the
## jump styles, which `GeometricAttackPromotion.serve_effort_for_style` already
## prices and which is reused here rather than re-deciding with a `contains`
## test, since that disagreement has been made before.
func _charge_jump(actor_id: int, event_type: int, metadata: Dictionary) -> void:
	if actor_id < 0:
		return
	var effort := 0.0
	match event_type:
		RallyEventModel.EventType.ATTACK:
			effort = float(metadata.get("jump_multiplier", 1.0))
		RallyEventModel.EventType.BLOCK:
			effort = 1.0
		RallyEventModel.EventType.SET:
			var capability: Dictionary = metadata.get("setter_capability", {})
			effort = 1.0 if str(capability.get("reach_state", "standing")) \
				in ["jump", "beyond_reach"] else 0.0
		RallyEventModel.EventType.SERVE:
			effort = GeometricAttackPromotionModel.serve_effort_for_style(
				str(metadata.get("serve_style", "Standing"))
			)
	if effort <= 0.0:
		return
	exertion_cost[actor_id] = float(exertion_cost.get(actor_id, 0.0)) \
		+ JUMP_EFFORT_COST * clampf(effort, 0.0, 1.4)
	## The assisting blocker jumped too, and was charged for nothing until now.
	var assist_id := int(metadata.get("assist_id", -1))
	if assist_id >= 0 and event_type == RallyEventModel.EventType.BLOCK:
		exertion_cost[assist_id] = float(exertion_cost.get(assist_id, 0.0)) \
			+ JUMP_EFFORT_COST


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
	## **Every jump in the game passes through here too.** Charging at the sites
	## that jump would mean finding all of them -- the attack, the block, the
	## assisting block, the jump set, the jump serve, on both sides, in first-ball
	## and transition variants -- and missing one silently. One place that sees
	## every contact is one place that can price them, and the effort each contact
	## used is already on the event's own metadata.
	_charge_jump(actor_id, event_type, metadata)
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
	## **What every body on court still owes, on the contact that samples it.**
	##
	## M7 / C1, and D2's "expose enough authoritative state for playback and
	## history to draw it". `player_recovery` has carried contact consequences
	## across phase boundaries since `ACTOR_CONTINUITY.md` certified the plumbing,
	## and `_recovery_time_penalties` hands it to the second-contact and defensive
	## claim clocks -- so it is already gameplay authority. It was simply never
	## *published*. Nothing outside this file could see that the voli who just dug
	## the ball is still getting up, which meant a probe asking C1's question --
	## does a contact leave debt the next leg still owes -- had no channel to read
	## and returned zero for the whole engine.
	##
	## Published from `_add_event` for the same reason the jump is charged here:
	## one place sees every contact, and a per-site publication is a list with one
	## site missing from it.
	##
	## Written onto the event's own copy rather than into `metadata`, which is the
	## caller's dictionary and in several places is reused for the next event.
	var recovery_owed := _recovery_time_penalties(rally_clock)
	if not recovery_owed.is_empty():
		event.metadata["recovery_debt"] = recovery_owed
	## **Where the body that made this contact was standing.**
	##
	## M8 asks every boundary for `actor_start -> traversal -> contact(position,
	## time)`, and the contact position was published by two families of seven:
	## SET and ATTACK, on both sides. Serve, reception, block, dig and coverage
	## published only where the *ball* was -- a reception event's
	## `start_position` is the serve's landing point, which is a fact about the
	## ball and says nothing about the passer.
	##
	## Nothing is derived here. At the moment a contact event is appended the
	## actor's live position *is* their contact position: every family writes it
	## before appending -- `live_positions[receiver.id] = receiver_reach`,
	## the hitter's from the attack integration, the setter's from theirs. This
	## publishes the state that already exists rather than reconstructing it, and
	## it defers to a family that stated a more precise one of its own.
	if not event.metadata.has("body_contact_position"):
		if live_positions.has(actor_id):
			event.metadata["body_contact_position"] = Vector2(live_positions[actor_id])
		elif opponent_live_positions.has(actor_id):
			event.metadata["body_contact_position"] = Vector2(
				opponent_live_positions[actor_id]
			)
	## And where that body started the leg it just finished -- see
	## `_positions_at_last_contact`. On a rally's first contact there is no
	## previous one, so the field is honestly absent rather than filled with the
	## contact position, which would report every server as having travelled
	## nowhere and be indistinguishable from a server who really had.
	if _positions_at_last_contact.has(actor_id):
		event.metadata["actor_leg_start"] = Vector2(
			_positions_at_last_contact[actor_id]
		)
	for player_id in live_positions:
		_positions_at_last_contact[int(player_id)] = Vector2(live_positions[player_id])
	for player_id in opponent_live_positions:
		_positions_at_last_contact[int(player_id)] = Vector2(
			opponent_live_positions[player_id]
		)
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


## One option score for either setter. Execution, feasibility, the forming read,
## the called instruction, and emotional context stay visible as separate terms
## so a SET_DECISION event can explain why the ball went where it did.
func _setter_option_terms(
	setter: VolleyballPlayer,
	hitter: VolleyballPlayer,
	set_quality: float,
	travel_time: float,
	available_time: float,
	rescue_height_meters: float,
	instruction_bias: float,
	lane_is_read: bool,
	flow_for_team: float,
	lane: String,
) -> Dictionary:
	var base_quality := _power_rating(hitter, "attack_power") * 0.44 \
		+ _rating(hitter, "attack_accuracy") * 0.34 \
		+ _rating(hitter, "approach_timing") * 0.22
	var judgment := clampf(
		_rating(setter, "decision_making") * 0.42
			+ _rating(setter, "court_vision") * 0.33
			+ _rating(setter, "composure") * 0.25,
		0.0, 1.0,
	)
	var lateness := maxf(travel_time - available_time, 0.0)
	## Good setters correctly discount a rescue ball. Poor ones can underrate the
	## problem, represented by the smaller perceived share and larger stable
	## misread below rather than by changing the hitter's real movement.
	var feasibility_cost := clampf(lateness / 0.80, 0.0, 1.0) \
		* lerpf(0.28, 0.72, judgment)
	var height_cost := _set_height_difficulty(setter, rescue_height_meters) \
		* lerpf(0.35, 1.0, judgment)
	var read_penalty := 0.0
	if lane_is_read:
		var disguise := _rating(setter, "set_disguise")
		var unpredictability := _rating(setter, "unpredictability")
		read_penalty = LANE_ANTICIPATED_PENALTY * lerpf(
			1.0, 0.32, disguise * 0.55 + unpredictability * 0.45
		)
	var desperation := clampf(
		maxf(-flow_for_team, 0.0) * 0.62
			+ maxf(-float(setter.match_confidence), 0.0) * 0.38,
		0.0, 1.0,
	)
	var leadership_pull := desperation * float(hitter.leadership) / 100.0 * 0.18
	## **How well this setter knows this hitter.**
	##
	## The one term here that is about a *pair* rather than about either voli
	## alone. A setter goes to the hitter whose run they can feel, and stays away
	## from the one whose timing they are still guessing at -- which is why
	## bringing in a better arm does not immediately make them the first option.
	##
	## Read through the setter's own judgement, as everything else here is: a
	## good setter's preference for a trusted hitter is a *read*, and a poor
	## one's is a habit. Centred on the baseline so an untracked pair -- a
	## friendly, an opponent whose table nobody keeps -- scores neutral rather
	## than as strangers.
	var trust := (
		PairFamiliarityModel.of(pair_familiarity, int(setter.id), int(hitter.id))
		- PairFamiliarityModel.BASELINE
	) / 100.0
	var trust_pull := trust * lerpf(
		SETTER_TRUST_WEIGHT_LOW, SETTER_TRUST_WEIGHT_HIGH, judgment
	)
	var noise_key := "%d|%d|%d|%s" % [
		rally_seed, setter.id, hitter.id, lane,
	]
	var stable_noise := float(posmod(hash(noise_key), 2001)) / 1000.0 - 1.0
	var misread := stable_noise * (1.0 - judgment) * 0.22
	var score := base_quality + set_quality * 0.10 + instruction_bias \
		+ leadership_pull + trust_pull + misread \
		- feasibility_cost - height_cost - read_penalty
	return {
		"player_id": hitter.id,
		"lane": lane,
		"score": score,
		"base_quality": base_quality,
		"judgment": judgment,
		"travel_time": travel_time,
		"available_time": available_time,
		"lateness": lateness,
		"rescue_height_meters": rescue_height_meters,
		"feasibility_cost": feasibility_cost,
		"height_cost": height_cost,
		"read_penalty": read_penalty,
		"instruction_bias": instruction_bias,
		"leadership_pull": leadership_pull,
		"trust_pull": trust_pull,
		"misread": misread,
	}


func _natural_hitter_lane(
	hitter: VolleyballPlayer, lineup: RotationLineup
) -> String:
	var slot_number := lineup.slot_for_player(hitter.id)
	if slot_number >= 1 and not CourtConstants.is_front_row_slot(slot_number):
		return "Pipe"
	var position := CourtConstants.slot_position(slot_number)
	if hitter.position_role == "Middle Blocker":
		return "Front Quick" if position.x <= 0.5 else "Right Quick"
	return "Left Pin" if position.x <= 0.5 else "Right Pin"


## Extra apex needed to keep a displaced hitter's contact reachable. The ball
## buys time rather than granting impossible movement; the costs of buying that
## time are charged to the set, block read, and eventual swing.
static func _set_rescue_height_meters(
	travel_time: float, ordinary_flight_time: float
) -> float:
	return clampf(maxf(travel_time - ordinary_flight_time, 0.0) * 1.35, 0.0, 1.80)


static func _set_height_difficulty(
	setter: VolleyballPlayer, rescue_height_meters: float
) -> float:
	if setter == null:
		return rescue_height_meters * 0.08
	var height_control := (
		float(setter.set_accuracy) * 0.45
			+ float(setter.hand_control) * 0.35
			+ float(setter.tempo_control) * 0.20
	) / 100.0
	return rescue_height_meters * lerpf(0.11, 0.045, height_control)


func _choose_assignment(
	play: OffensivePlay,
	follow_play: bool,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
	setter: VolleyballPlayer = null,
	pass_quality: float = 0.5,
	flow_for_team: float = 0.0,
) -> HitterAssignment:
	if play == null or play.assignments.is_empty():
		return null
	if follow_play and setter == null:
		var primary := play.assignment_for_player(play.primary_hitter_id)
		var primary_player := _player_by_id(players, primary.player_id) \
			if primary != null else null
		if primary != null and not primary.is_decoy \
				and primary.player_id != excluded_player_id \
				and _can_enter_attack(primary_player):
			return primary
	var candidates: Array[HitterAssignment] = []
	for assignment in play.assignments:
		var assigned_player := _player_by_id(players, assignment.player_id)
		if not assignment.is_decoy \
				and assignment.player_id != excluded_player_id \
				and _can_enter_attack(assigned_player) \
				and lineup.slot_for_player(assignment.player_id) >= 0:
			candidates.append(assignment)
	if candidates.is_empty():
		return null
	if setter != null:
		var evaluated: Array[Dictionary] = []
		for assignment in candidates:
			var contender := _player_by_id(players, assignment.player_id)
			if contender == null:
				continue
			var target := HitterPlacementModel.preferred_point(
				contender, assignment.lane, rally_seed, contender.id
			)
			var start := Vector2(live_positions.get(
				contender.id,
				CourtConstants.slot_position(lineup.slot_for_player(contender.id)),
			))
			var provisional_arc := _set_arc(
				setter, assignment.tempo, pass_quality,
				GeometricAttackPromotionModel.set_contact_height_meters(setter),
				GeometricAttackPromotionModel.contact_height_meters(contender, 1.0),
				RallyKinematics.court_distance_meters(
					Vector2(0.5, 0.60), target
				),
			)
			var available := float(provisional_arc.duration_seconds)
			var travel := _movement_time(contender, start, target, "transition")
			var rescue_height := _set_rescue_height_meters(travel, available)
			var terms := _setter_option_terms(
				setter, contender, pass_quality, travel, available,
				rescue_height,
				0.20 if follow_play and assignment.player_id == play.primary_hitter_id \
					else 0.0,
				assignment.lane == opponent_anticipated_lane,
				flow_for_team,
				assignment.lane,
			)
			terms["assignment"] = assignment
			evaluated.append(terms)
		if not evaluated.is_empty():
			evaluated.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.score) > float(b.score)
			)
			var option_summaries: Array[Dictionary] = []
			for option in evaluated:
				var option_summary := option.duplicate(true)
				option_summary.erase("assignment")
				option_summaries.append(option_summary)
			last_set_decision = {
				"chosen_player_id": int(evaluated[0].player_id),
				"chosen_lane": str(evaluated[0].lane),
				"options": option_summaries,
			}
			return evaluated[0].assignment as HitterAssignment
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
	adjusted.tempo = clampi(
		adjusted.tempo
			+ _identity_tempo_shift(home_principles, reception_quality, "home"),
		0, 3,
	)
	return adjusted


## How far a side's identity moves the tempo it called, in steps.
##
## **One function, both sides**, for the reason `_tempo_call` gives above: this
## was home-only, so an opponent ran the same tempo the whole match whatever
## their bench believed. Of the twenty-four principle reads in this resolver,
## twenty-two were `home_principles` -- an opponent Spëddigh played exactly like
## an opponent Blôc du Larg, which makes a regional identity a decoration on the
## team you happen to manage.
##
## Lower tempo is quicker: 0 is the first-tempo ball, 3 the high one.
func _identity_tempo_shift(
	side_principles: Resource,
	reception_quality: float,
	side: String,
) -> int:
	if side_principles == null:
		return 0
	var tempo_shift := 0
	var commitment := lerpf(
		float(side_principles.decisiveness),
		float(side_principles.transition_commitment),
		0.45,
	)
	if RallyFeatureFlagsModel.ENABLE_LIVE_TEMPO_CALL:
		## **How hard, not whether.** See `COMMITMENT_FULL_PULL`: the pull is how
		## far this side sits from neutral, as a share of the furthest any
		## identity sits, and it is spent as the chance of taking the step rather
		## than as the step itself.
		var pull := clampf(
			(commitment - 0.5) / COMMITMENT_FULL_PULL, -1.0, 1.0
		)
		if _identity_roll("%s|commit" % side) < absf(pull):
			tempo_shift += -1 if pull > 0.0 else 1
	else:
		if commitment >= 0.66:
			tempo_shift -= 1
		elif commitment <= 0.34:
			tempo_shift += 1
	var variation := clampf(float(side_principles.tempo_variation), 0.0, 1.0)
	if reception_quality >= 0.48:
		if RallyFeatureFlagsModel.ENABLE_LIVE_TEMPO_CALL:
			## The axis *is* the rate, so it is read as one. A side rotates this
			## often, in a direction the pass does not predict, and reaches a
			## second step only in proportion to how far past neutral it sits --
			## which is the difference between varying and being unreadable.
			if _identity_roll("%s|vary" % side) < variation:
				var steps := 1
				if _identity_roll("%s|vary2" % side) < (variation - 0.5) * 2.0:
					steps = VARIATION_MAX_STEPS
				tempo_shift += steps \
					if _identity_roll("%s|varydir" % side) < 0.5 else -steps
		elif variation >= 0.66:
			tempo_shift += [-1, 0, 1][posmod(rally_seed, 3)]
	return tempo_shift


## A repeatable 0-1 draw for an identity call, keyed to this rally and swing.
##
## Deliberately hashed rather than taken from `rng`. Every seeded fixture in the
## suite depends on the resolver's random stream being consumed in the same
## order, so adding draws to it would move outcomes that have nothing to do with
## identity and the diff would be unreadable. This is the pattern
## `_read_error_meters` already uses for the same reason.
func _identity_roll(channel: String) -> float:
	return float(posmod(
		hash("%d|%s|%d" % [rally_seed, channel, swing_index]), 100003
	)) / 100003.0


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


## How hard the ball itself is to handle, on top of how well it was struck.
##
## **The swing barely participated in its own contest.** Measured over 299 digs,
## attack effectiveness spans 0.356 to 0.557 between the tenth and ninetieth
## percentile -- a range of 0.20 -- while the defender's quality spans 0.125 to
## 0.923, a range of 0.80. So the outcome was four times more a fact about where
## the defender was standing than about the attack, and a hammer and a roll shot
## with the same execution score were the same problem to dig. That is the
## mechanical reason a powerful hit does not feel powerful.
##
## **Pace, and only as a contact difficulty.** A faster ball is already harder to
## dig through a channel that exists and works: it arrives sooner, the reach
## margin shrinks, and `_defense_terms`' timing factor falls with it -- measured,
## the dig rate runs 0.70 in the slowest speed band against 0.34 in the fastest.
## Adding pace to *arrival* again would price the same difficulty twice, which is
## the mistake `DIG_ATTACKER_ADVANTAGE` was re-fitted to undo.
##
## What is genuinely unpriced is the other half: a ball struck at thirty metres a
## second is harder to keep on the court *once you are there*, off a platform
## that has to absorb it. That is about the contact, not the journey, and nothing
## in the dig contest knew it. `_contact_recovery_state` reads `incoming_force`
## to decide whether a defender is knocked over, and that was the only place in
## the game where the weight of the ball meant anything at all.
##
## Applied at the dig rather than folded into `_attack_effectiveness`, because
## the block's contest is a timing and geometry problem where pace is not the
## question, and the two consumers should not be handed one number that means
## two things.
func _attack_pressure(
	effectiveness: float, incoming_trajectory: Dictionary
) -> float:
	if incoming_trajectory.is_empty():
		return clampf(effectiveness, 0.0, 1.0)
	return clampf(
		effectiveness * BallPresentation.pace_pressure_multiplier(
			BallPresentation.launch_speed_mps(incoming_trajectory)
		),
		0.0, 1.0,
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


## Who swings when no play was called -- which, on the calibration fixture, is
## every single ball.
##
## `pass_quality` below zero means "not supplied", which keeps every existing
## caller on the old behaviour without a second function.
func _fallback_hitter(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int = -1,
	pass_quality: float = -1.0,
	setter: VolleyballPlayer = null,
	flow_for_team: float = 0.0,
) -> VolleyballPlayer:
	## The middle, on a pass that allows one.
	##
	## This function has only ever looked for Outside Hitters, falling through to
	## "any front-row body" if there were none -- so a front-row middle was never
	## chosen while an outside hitter existed, which is always. Measured over 185
	## home swings: Left Pin 34, Right Pin 151, and not one quick or pipe in the
	## sample. The home offence was two hitters and a high ball.
	##
	## Gated on the pass because a quick is not a shot you can run off a bad one,
	## which is the whole reason the middle is a *conditional* option rather than
	## simply another name in the list.
	## Whether a quick is on at all. The middle is *eligible* on this ball, not
	## entitled to it.
	##
	## This used to return the front-row middle outright the moment the pass
	## allowed one, ahead of the scored selection below -- so a good pass meant the
	## middle, every time, and the scoring only ever ran on balls nobody could run
	## a quick off. With the fixture squad given real attributes that produced
	## Front Quick 0.716 of 74 swings: the monoculture moved lanes rather than
	## breaking up, which is what a bypass does to a decision.
	var quick_is_on := RallyFeatureFlagsModel.ENABLE_HOME_MIDDLE_OFFENSE \
		and pass_quality >= OFFENSE_QUICK_PASS_FLOOR
	## Every front-row attacker, scored -- not "the outside hitter, and if there
	## is more than one, whichever stands nearer a pin".
	##
	## That rule is deterministic in the rotation, so it returned the same voli
	## every rally and the opposite never swung at all. Measured over 194 home
	## attacks it produced Front Quick 84, Right Pin 110 and **Left Pin zero** --
	## a two-lane offence, which no amount of tempo variety can widen.
	##
	## Scored on the swing they would actually take, so a strong opposite gets the
	## ball ahead of a weak outside and the lane follows from who was chosen rather
	## than deciding who is chosen.
	if RallyFeatureFlagsModel.ENABLE_HOME_MIDDLE_OFFENSE:
		var scored: Array[Dictionary] = []
		for slot_number in range(1, 7):
			var contender := _player_by_id(players, lineup.player_at_slot(slot_number))
			if contender == null or contender.id == excluded_player_id \
					or not _can_enter_attack(contender) \
					or contender.position_role == "Libero" \
					or not lineup.is_attack_eligible(contender.id):
				continue
			var front_row := CourtConstants.is_front_row_slot(slot_number)
			var is_middle := front_row \
				and contender.position_role == "Middle Blocker"
			## A middle with no quick to run is a hitter with no shot: they cannot
			## be set a high ball outside, so they leave the pool rather than being
			## fed something they do not hit.
			if is_middle and not quick_is_on:
				continue
			## The back row swings too, on a ball that allows it.
			##
			## This loop skipped every back-row slot, so the pipe was unreachable by
			## any code path on this side of the net -- five lanes in
			## `CourtConstants.LANES`, four the offence could produce, and the one it
			## could not is the one that occupies the middle blocker and stops a
			## front-row-only offence being read three-wide. Everything else it needs
			## already existed: `LANE_X`, a `lane_target` behind the attack line, the
			## "Pipe attack" hit type, an approach profile, and a play validator that
			## has always required back-row hitters to use this lane.
			##
			## Gated on the same pass the quick is, and for the same reason: a hitter
			## running from four metres back needs the ball where they expected it.
			## A middle blocker in the back row is not a pipe hitter -- they are
			## resting, and in this squad they are usually about to be substituted.
			if not front_row:
				if not RallyFeatureFlagsModel.ENABLE_HOME_PIPE_OFFENSE \
						or not quick_is_on \
						or contender.position_role == "Middle Blocker":
					continue
			var score := _power_rating(contender, "attack_power") * 0.46 \
				+ _rating(contender, "attack_accuracy") * 0.34 \
				+ _rating(contender, "approach_timing") * 0.20
			## What a quick is worth when it is on: fast, in front of a wall that
			## has not formed, and the reason to run one at all. Priced rather than
			## privileged, so a strong pin still out-scores a weak middle.
			if is_middle:
				score += QUICK_OPTION_BONUS
			## And the pipe is worth something for the same reason, with the extra
			## metres of run priced against it: it arrives on a wall watching two
			## front-row hitters, but the hitter has further to travel and less of
			## the set to read.
			elif not front_row:
				score += PIPE_OPTION_BONUS \
					- (1.0 - _rating(contender, "transition_speed")) \
						* PIPE_TRAVEL_COST
			## And spread the ball, because ability alone is still one lane.
			##
			## Ranking on the swing picked the best attacker every rally, which moved
			## the whole offence from Right Pin to Left Pin and left it just as narrow.
			## A setter who always feeds their best hitter is a setter the block reads
			## in one rotation, and distribution is the thing that stops that.
			##
			## **Deliberately a placeholder, and worth naming as one.** The real term
			## is a setter decision against what the opponent is anticipating --
			## `OpponentTeam.anticipated_lane()` and `Familiarity` already track it and
			## are write-only against the home side today. This is a deterministic
			## per-rally spread standing in for that until it is wired: it consumes no
			## random draw, so it re-sequences nothing, and it is small enough that a
			## clearly better hitter still gets the ball.
			var lane := _natural_hitter_lane(contender, lineup)
			if setter != null:
				var target := HitterPlacementModel.preferred_point(
					contender, lane, rally_seed, contender.id
				)
				var start := Vector2(live_positions.get(
					contender.id, CourtConstants.slot_position(slot_number)
				))
				var tempo := QUICK_TEMPO_CALL if is_middle else (
					PIPE_TEMPO_CALL if not front_row else 3
				)
				var provisional_arc := _set_arc(
					setter, tempo, pass_quality,
					GeometricAttackPromotionModel.set_contact_height_meters(setter),
					GeometricAttackPromotionModel.contact_height_meters(contender, 1.0),
					RallyKinematics.court_distance_meters(Vector2(0.5, 0.60), target),
				)
				var available := float(provisional_arc.duration_seconds)
				var travel := _movement_time(contender, start, target, "transition")
				var terms := _setter_option_terms(
					setter, contender, pass_quality, travel, available,
					_set_rescue_height_meters(travel, available), 0.0,
					lane == opponent_anticipated_lane, flow_for_team, lane,
				)
				score += float(terms.score) - float(terms.base_quality)
				scored.append(terms.merged({
					"player": contender, "score": maxf(score, 0.02),
				}, true))
			else:
				scored.append({"player": contender, "score": maxf(score, 0.02)})
		if not scored.is_empty():
			var selected := _distributed_choice(scored)
			var scored_summaries: Array[Dictionary] = []
			for option in scored:
				var option_summary := option.duplicate(true)
				option_summary.erase("player")
				scored_summaries.append(option_summary)
			last_set_decision = {
				"chosen_player_id": selected.id,
				"chosen_lane": _natural_hitter_lane(selected, lineup),
				"options": scored_summaries,
			}
			return selected
	var outside_candidates: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and candidate.id != excluded_player_id \
				and _can_enter_attack(candidate) \
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
		if player != null and player.id != excluded_player_id \
				and _can_enter_attack(player):
			return player
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null and player.id != excluded_player_id \
				and _can_enter_attack(player) \
				and lineup.is_attack_eligible(player.id) \
				and player.position_role != "Libero":
			return player
	return null


## `_best_blocker()` used to pick a blocker by `block_timing + jump_reach`.
## It has had no callers since blocking moved to `ShadowBlockSystem` and the
## coordinated form-then-contest path, which reads the whole front row rather
## than crowning one player. Removed rather than kept as a second, cruder
## answer to a question the block system now owns.

## What the clipboard told this blocker to do with their hands, or "".
##
## Returns empty for every reason it can: no sheet handed in, no lineup, a voli
## not in the rotation, or a slot the manager left blank. An absent instruction
## is a real state and must read as one -- it is what every block in the game had
## until now.
func _hands_instruction_for(
	blocker: VolleyballPlayer, lineup: RotationLineup
) -> String:
	if tactic_sheet == null or blocker == null or lineup == null:
		return ""
	var slot := lineup.slot_for_player(blocker.id)
	if slot <= 0:
		return ""
	return str(tactic_sheet.behaviour_of(slot, "Block"))



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
	opponent_hitter: VolleyballPlayer = null,
	set_height_extra_meters: float = 0.0,
	## **The drift this wall has already been given, if any.**
	##
	## This former runs *twice* per opponent transition -- once before the set is
	## released and once re-formed with the achieved tempo -- and it used to
	## write the setter pull into `live_positions` on both. The second call then
	## read the already-pulled position as its start and pulled again from it, so
	## one misread moved the same body twice. Measured over the matched block-band
	## population that was 92 of the 134 swings the home wall failed to form on.
	##
	## Passing the first call's result in says "this drift already happened".
	## The body keeps whatever live displacement it genuinely has, the reported
	## magnitude stays the one that was actually applied, and nothing here decides
	## whether the pull *should* mutate a body at all -- that is the block-symmetry
	## question task #63 owns, and it stays open. See
	## `docs/review/HOME_WALL_FORMATION.md`.
	applied_setter_pull: Dictionary = {},
) -> Dictionary:
	var front_blockers: Array[VolleyballPlayer] = []
	var re_forming := not applied_setter_pull.is_empty()
	var setter_pull := applied_setter_pull.duplicate() if re_forming else {}
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		var assignment: Resource = defensive_plan.assignment_for(player_id) \
			if defensive_plan != null else null
		if player != null and (assignment == null or bool(assignment.block_participation)):
			front_blockers.append(player)
			if re_forming:
				continue
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
		read_total += _blocker_read_quality(
			reader, tempo, set_quality, opponent_setter_x, opponent_hitter,
			set_height_extra_meters,
		)
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
	var commitment_principle := float(home_principles.block_commitment)
	var identity_commitment_seconds := (commitment_principle - 0.5) * 0.18
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
	var primary_terms := _blocker_close_terms(
		primary, lineup, attack_x, close_time
	)
	var primary_close := float(primary_terms.fraction)
	## The assist cannot have crossed the court before the setter touched it.
	##
	## Both blockers were handed the same budget, and that budget is mostly
	## *pre-set*: measured, the window ahead of the set runs 0.78-1.07 s and
	## barely moves with tempo, while the set's own flight runs 0.20-0.99 s. At
	## tempo 0 that is 79% of the closing time credited before the ball exists.
	##
	## For the primary that is fair, and deliberately untouched here. The primary
	## is by definition the blocker already nearest the attacked lane, so their
	## pre-set time is spent reading rather than travelling. The assist is the one
	## who has to cross a slot, and crediting them with having crossed it before
	## the lane was chosen is what made a first-tempo ball draw a double block
	## 37% of the time.
	##
	## Anticipation still pays -- `preset_share` is the read, and it stays. What
	## it now buys is bounded by whether there is time to *finish* the crossing
	## once the set confirms it. A high ball leaves the whole window usable; a
	## first-tempo ball leaves almost none, which is the entire reason a quick set
	## beats a double block, and the reason a zero ball has to be committed to
	## rather than read.
	var assist_reaction := clampf(
		maxf(set_flight_time, 0.0) / ASSIST_COMMIT_FLIGHT_SECONDS, 0.0, 1.0
	)
	## Only the *reactive* share is bounded by the flight. What the wall
	## already committed to survives whatever the tempo.
	var assist_usable_preset := lerpf(
		assist_reaction, 1.0,
		_assist_committed_share(commitment_principle, read_quality),
	)
	var assist_close_time := close_time \
		- maxf(preset_window_seconds, 0.0) * preset_share \
		* (1.0 - assist_usable_preset)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	var assist_net_x := 0.5
	## Kept whether or not the candidate survives the cut below. `assist_close`
	## is zeroed when the best available blocker could not get there, so its mean
	## silently mixes "nobody travelled" with "somebody travelled and failed" --
	## and those are the two readings the saturation question needs told apart.
	var assist_terms := {}
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var candidate_terms := _blocker_close_terms(
			candidate, lineup, attack_x, assist_close_time
		)
		var close_fraction := float(candidate_terms.fraction)
		if close_fraction > assist_close or assist_terms.is_empty():
			assist_terms = candidate_terms
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
			assist_net_x = float(candidate_terms.get("closed_net_x", 0.5))
	var assist_attempt: VolleyballPlayer = assist
	var assist_close_attempted := assist_close
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
		assist_net_x = 0.5
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	## Positions as well as skills: an assist that closed to the far side of the
	## tape is not the same wall as one that closed shoulder to shoulder.
	var block_quality := _block_wall_quality(
		primary_skill, assist_skill,
		float(primary_terms.get("closed_net_x", 0.5)), assist_net_x,
	)
	return {
		"primary": primary,
		"assist": assist,
		"assist_attempt": assist_attempt,
		"primary_close": primary_close,
		"assist_close": assist_close,
		## **The manager's call, finally reaching the court.** `TacticSheet` has
		## stored a per-slot block behaviour since it was written, and
		## `_block_hands_intent` has had a branch for it since it was written, and
		## nothing has ever carried a value between them. Keyed by slot because
		## that is how the sheet is keyed -- a plan is a shape the club plays, and
		## it outlives whoever stands in position four.
		##
		## Home only. The sheet belongs to the manager's own club, so an opponent
		## hands-call would have to be invented, and this pass does not invent one.
		"hands_instruction": _hands_instruction_for(primary, lineup),
		## The reached positions, so the geometric wall stands where the blockers
		## closed to rather than where they began.
		"primary_net_x": float(primary_terms.get("closed_net_x", 0.5)),
		"assist_net_x": assist_net_x,
		## The itemised close, so a binary output can be attributed to whichever
		## of its inputs is bimodal.
		"primary_close_terms": primary_terms,
		"assist_close_terms": assist_terms,
		## The budget's two halves, kept apart. `available_time` alone cannot say
		## whether a blocker had time because the ball was slow or because they
		## were credited with the whole second contact before it happened, and
		## those are different problems with different fixes.
		"preset_window_seconds": maxf(preset_window_seconds, 0.0),
		"preset_share": preset_share,
		"set_flight_seconds": maxf(set_flight_time, 0.0),
		"tempo": tempo,
		## Before the 0.34 cut, so a wall with no second blocker is
		## distinguishable from a second blocker who did not arrive.
		"assist_close_attempted": assist_close_attempted,
		"quality": block_quality,
		"outcome": "miss",
		"coverage_segments": _home_block_segments(
			attack_x, primary, primary_close, assist, assist_close
		),
		"setter_pull": setter_pull,
		"read_quality": read_quality,
		## How many front-row bodies the plan actually offered this wall. Zero and
		## "nobody arrived" are different defects with opposite fixes, and until this
		## was forwarded the rally record could not tell them apart -- see the
		## `home_block_terms` publication on the opponent ATTACK event.
		"front_blocker_count": front_blockers.size(),
	}


## **A blocker reads the arm, and a fast arm gives them less of it to read.**
##
## `hitter` is new and optional. Everything above it is a read of the *play* --
## the pass, the setter's body, the tempo -- which is what a blocker has before
## the ball leaves the setter's hands. What they have after that is the swing,
## and the swing is over faster for some hitters than others: a middle who gets
## the arm through in a blink shows a blocker almost nothing, while a slow big
## windup announces the shot in time to move on it.
##
## Centred on the population rather than applied as a flat multiplier, so an
## ordinary arm changes nothing and the trait cuts both ways. A slow arm is a
## real weakness here and not merely the absence of a strength -- which is the
## same correction `AttackPowerModel.choose_power` had to make to `aggression`.
func _blocker_read_quality(
	blocker: VolleyballPlayer,
	tempo: int,
	set_quality: float,
	opponent_setter_x: float,
	hitter: VolleyballPlayer = null,
	set_height_extra_meters: float = 0.0,
) -> float:
	var cue_clarity := (1.0 - set_quality) * 0.18 \
		+ absf(opponent_setter_x - 0.5) * 0.16 \
		+ float(clampi(tempo, 0, 3)) * 0.025 \
		+ clampf(set_height_extra_meters, 0.0, 1.8) * 0.075
	if hitter != null:
		cue_clarity -= ARM_SPEED_READ_COST \
			* (_rating(hitter, "arm_speed") - 0.5) * 2.0
	return clampf(
		_rating(blocker, "anticipation") * 0.34
		+ _rating(blocker, "court_vision") * 0.25
		+ _rating(blocker, "decision_making") * 0.21
		+ _rating(blocker, "tactical_discipline") * 0.20
		+ cue_clarity - rng.randf_range(0.0, 0.08), 0.0, 1.0
	)


## What a defender can tell about a swing before it happens.
##
## Three reads, all of them things a real defender is actually doing, and none of
## them previously modelled:
##
## - **The arm, against their own eyes.** `court_vision` was read by the attack's
##   own resolver and by the blocker above and by nothing on the floor, so a
##   libero's vision decided nothing about digging. Here it is contested directly
##   against the hitter's `arm_speed`: seeing the shot early is worth exactly as
##   much as the hitter's arm is slow.
## - **The wall in front of them.** A funnelling block is *telling* the defence
##   where the ball is going -- that is the entire point of choosing to funnel,
##   and until now choosing it bought the diggers behind it nothing at all. A
##   sealing block buys less, because holding the line concedes the angle rather
##   than narrowing it.
## - **A hand on the ball.** A touched ball is slower and has changed direction,
##   which is harder in one way and much easier in another; the engine already
##   pays the defender the extra flight time and this is the read that goes with
##   it.
##
## Returns a signed adjustment to `read_bonus`, so a defender facing a fast arm
## with no wall in front of them is *worse* off than the neutral case rather than
## merely not better off.
func _dig_read_bonus(
	defender: VolleyballPlayer,
	hitter: VolleyballPlayer,
	block_outcome: String,
) -> float:
	var bonus := 0.0
	if defender != null and hitter != null:
		bonus += DIG_VISION_READ_WEIGHT * (
			_rating(defender, "court_vision") - _rating(hitter, "arm_speed")
		)
	match block_outcome:
		"funnel":
			bonus += FUNNEL_READ_BONUS
		"touch":
			bonus += TOUCHED_BALL_READ_BONUS
		"seal":
			bonus += SEAL_READ_BONUS
	return bonus


func _blocker_close_fraction(
	blocker: VolleyballPlayer,
	lineup: RotationLineup,
	attack_x: float,
	available_time: float,
) -> float:
	return float(_blocker_close_terms(
		blocker, lineup, attack_x, available_time
	).fraction)


## The same close, itemised.
##
## Kept as the single implementation with `_blocker_close_fraction()` reading its
## `fraction`, rather than a parallel diagnostic -- a second copy of this
## arithmetic could drift from the one the wall is built from, and then a probe
## would report a close no blocker ever had.
##
## Worth having because the close came out **binary**: measured across 56 home
## blocks every percentile was either 0.000 or 1.000, on a formula whose ramp is
## 0.45 s wide and perfectly capable of returning anything between. Something in
## its inputs is bimodal and the total cannot say which.
func _blocker_close_terms(
	blocker: VolleyballPlayer,
	lineup: RotationLineup,
	attack_x: float,
	available_time: float,
) -> Dictionary:
	if blocker == null:
		return {
			"fraction": 0.0, "required_seconds": 0.0, "usable_time": 0.0,
			"deficit_seconds": 0.0, "lane_delta": 0.0, "footwork_meters": 0.0,
			"reaction_delay": 0.0, "available_time": available_time,
		}
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
	## the stride, cadence or limb-turnover work reached blocking at all.
	##
	## `&"home"` for an opponent blocker too, and that is now a claim rather than
	## an oversight: `create()` derives the ready facing from the side, so the two
	## sides are set at `(0, -1)` and `(0, +1)`. A close runs *along* the net, so
	## the route is +/-x and the dot product with either facing is zero --
	## `facing_fit` is 0.5 for both sides and the turn cost is identical. It stops
	## being irrelevant the moment a close is given any component toward the net,
	## which is why it is written down here instead of left to be rediscovered.
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
	var deficit := required_seconds - usable_time
	var fraction := clampf(
		1.0 - maxf(deficit, 0.0) / BLOCK_CLOSE_FAILURE_SECONDS, 0.0, 1.0
	)
	return {
		"fraction": fraction,
		## Where this blocker actually ended up, in normalised court x.
		##
		## `footwork_x` is where they were *going*; the fraction says how much of
		## that they got, so the reached position is the two together. Until this
		## was returned it was computed and discarded, and the geometric wall
		## asked `live_positions` instead -- which is where the blocker *started*.
		## So the block closed in the timing model and stood still in the geometry
		## model, and the wall was drawn at the blocker's rotation slot rather than
		## at the lane they had just travelled to. Measured on Front Quick, whose
		## lane sits at x 0.400 against a middle blocker's slot near 0.5, that is a
		## 0.9 m gap -- wider than any half-width the wall could plausibly have, so
		## every such ball classified as beating the block "around". It is why
		## doubling `BLOCKER_HALF_WIDTH_METERS` converted four balls out of
		## fifty-eight: the wall was never within reach of the ball to begin with.
		"closed_net_x": lerpf(start_x, footwork_x, fraction),
		"required_seconds": required_seconds,
		"usable_time": usable_time,
		"deficit_seconds": deficit,
		## How far along the net the blocker had to travel, before and after the
		## arms are credited. If the deficit is bimodal this is why: a three-slot
		## front row offers "already there" or "a whole slot away" and nothing in
		## between.
		"lane_delta": lane_delta,
		"footwork_meters": absf(footwork_x - start_x) * CourtConstants.COURT_WIDTH_METERS,
		"reaction_delay": reaction_delay,
		"available_time": available_time,
		## **Where this blocker was standing, against where their rotation puts
		## them.** The two walls are built from different starting geometry -- the
		## home former reads `live_positions` and the opponent former reads the
		## rotation slot -- and no published term said so, which made a close
		## deficit impossible to attribute to displacement rather than to time.
		## See `docs/review/HOME_WALL_FORMATION.md`.
		"start_x": start_x,
		"slot_x": CourtConstants.slot_position(slot_number).x,
	}


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
	set_height_extra_meters: float = 0.0,
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
	) * (
		## Very high rescue balls arrive steeply and make the hitter wait under a
		## readable contact. Height helps arrival; it is not free swing quality.
		1.0 - clampf(set_height_extra_meters * 0.075, 0.0, 0.16)
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
	attack_type: String = "",
) -> Dictionary:
	if hitter == null:
		return {}
	geometric_rng.seed = hash("%d|geometric|%d|%d" % [
		rally_seed, hitter.id, geometric_swing_index
	])
	geometric_swing_index += 1
	var wall := GeometricAttackPromotionModel.block_wall(
		formation, blocking_fallbacks, blocking_live, block_intent, -flow_for_team
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
		attack_type,
	)
	## Collision geometry contains only hands that reached the wall. Playback
	## needs every jump attempt, including a late closer and the wall reacting to
	## a swing that ultimately misses. Keep those two facts deliberately separate.
	swing["block_jump_timing"] = \
		GeometricAttackPromotionModel.block_jump_timing(formation)
	## The two inputs a sweep cannot supply for itself. Gate D contacted at full
	## jumping reach because it had no approach to ask; a rally does, and whether
	## that difference explains the net rate is the first question the shadow was
	## wired to answer.
	swing["contact_height_meters"] = height
	swing["jump_multiplier"] = jump_multiplier
	swing["wall_size"] = wall.size()
	## **What each blocker actually reached, not how many closed.**
	##
	## `block_wall` admits a blocker on their close fraction alone and then
	## scales `reach_height_m` by the jump they got, so a blocker who read late
	## and never left the floor sits in the array at standing reach and counts
	## toward `wall_size` exactly as much as a middle with their hands over the
	## tape. Every consumer of `wall_size` has been reading "bodies near the
	## lane" while believing it read "wall in the way". Published so the two can
	## be told apart.
	var reaches: Array[float] = []
	for blocker in wall:
		reaches.append(float(blocker.get("reach_height_m", 0.0)))
	swing["wall_reach_heights"] = reaches
	return swing


## **The serve. One of them, forward.**
##
## This used to be `_geometric_serve_record`, a shadow: it resolved the serve
## properly, wrote what it found onto `result.analysis`, and was then ignored
## while the official ball was fitted backwards to a landing point a coin flip
## had already chosen. The audit in `docs/design/CONTACT_AND_BALL_FLIGHT.md`
## found the two disagreed by 2.89x on horizontal pace and concluded that
## neither was the authority: production asked *"what launch puts the ball where
## I already decided it lands?"* and the shadow asked *"what does this server's
## ball do?"* -- two different questions, so the gap was never arithmetic.
##
## The order here is the one the audit asked for and it is the whole of the
## change:
##
##     aim -> launch search -> execution error -> flight -> landing -> verdict
##
## `_errant_serve_landing` is gone with the rest of the inverse path. A serve
## misses now because the ball it was hit as missed, and which way it missed --
## into the tape, long, wide, outside the antenna -- is read off the same flight
## that decides everything else about it.
func _canonical_serve(
	key: String,
	server: VolleyballPlayer,
	contact: Vector2,
	## Where the server is *trying* to put it. Intent, not a guaranteed landing:
	## nothing below is permitted to move this point to make a verdict true.
	aim: Vector2,
	attacking_negative_y: bool,
	tactical_risk: float,
) -> Dictionary:
	if server == null:
		return {}
	geometric_rng.seed = hash("%d|serve|%s|%d" % [rally_seed, key, server.id])
	var contact_height := GeometricAttackPromotionModel.serve_contact_height_meters(
		server,
		GeometricAttackPromotionModel.serve_effort_for_style(
			str(server.primary_serve_style)
		),
	)
	var serve: Dictionary = GeometricAttackResolverModel.resolve_serve(
		server, contact, contact_height,
		aim, attacking_negative_y, tactical_risk,
		GeometricAttackPromotionModel.serve_draws(geometric_rng),
		_serve_spin(server),
	)
	if not bool(serve.get("available", false)):
		return {}
	var resolution: Dictionary = serve.get("resolution", {})
	var launch: Dictionary = serve.get("launch", {})
	var landing := Vector2(serve.landing)
	var horizontal := maxf(
		float(launch.get("horizontal_speed_mps", 0.0)),
		BallFlightModel.MIN_SPEED_MPS,
	)
	## **The drawn segment ends where the ball ended, and the launch does not
	## care.** A serve into the tape stops at the tape; a serve that lands flies
	## its whole range. Both take their duration from the same horizontal speed,
	## so truncating one cannot change the pace it left the hand at -- which is
	## exactly what reconstructing speed from two endpoints and a duration had
	## been doing.
	var duration := maxf(
		RallyKinematics.court_distance_meters(contact, landing) / horizontal,
		RallyKinematics.MIN_FLIGHT_DURATION,
	)
	var flight: Dictionary = serve.get("flight", {})
	## Relative rise above the contact, which is the published contract for every
	## trajectory in the engine. `solve_flight` reports the apex absolutely.
	var apex_rise := maxf(
		float(flight.get("apex_height_meters", contact_height)) - contact_height,
		0.0,
	)
	geometric_serves[key] = {
		"outcome": str(serve.outcome),
		"out_reason": str(serve.get("out_reason", "")),
		"speed_mps": float(serve.speed_mps),
		"bearing_degrees": float(serve.bearing_degrees),
		"launch_mode": str(serve.launch_mode),
		"landing": landing,
		"net_clearance_meters": float(resolution.get("net_clearance_meters", 0.0)),
		## Marked so a reader of `result.analysis` can tell this is the ball that
		## was played, not the ball that would have been. It was a shadow for
		## eleven gates and the key names have not changed.
		"authority": "canonical",
	}
	return {
		"landing": landing,
		"outcome": str(serve.outcome),
		"out_reason": str(serve.get("out_reason", "")),
		"error": str(serve.outcome) != "in",
		"duration_seconds": duration,
		"apex_rise_meters": apex_rise,
		"contact_height_meters": contact_height,
		"net_clearance_meters": float(resolution.get("net_clearance_meters", 0.0)),
		"launch": launch,
		"spin": Dictionary(serve.get("spin", {})),
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
		## How much of their own ceiling the hitter decided to use. The number the
		## bench's decisiveness instruction actually moves -- published so the
		## distribution it occupies can be read off a live rally rather than
		## guessed at from the constants that build it.
		"chosen_power_fraction": float(
			Dictionary(swing.get("power", {})).get("chosen_fraction", 0.0)
		),
		"shot_spread_multiplier": float(swing.get(
			"shot_spread_multiplier", 1.0
		)),
		"contact_height_meters": float(swing.get("contact_height_meters", 0.0)),
		"jump_multiplier": float(swing.get("jump_multiplier", 1.0)),
		## Whether the resolver found an angle that gets over the tape, and which
		## branch of its search found it. Both were computed on every swing and
		## dropped here, so nothing downstream could tell a ball drawn into the net
		## because the hitter had no shot from one drawn into the net because the
		## drawing lost the answer. `run_ball_flight_probe` asks exactly that.
		"launch_cleared": bool(swing.get("launch_cleared", true)),
		"launch_mode": str(swing.get("launch_mode", "")),
		"wall_size": int(swing.get("wall_size", 0)),
		## And what each of them reached, which is the difference between a wall
		## and two people standing near one. Forwarded here rather than left in
		## the record because this projection is all promotion sees -- the third
		## time a key has been dropped at exactly this line.
		"wall_reach_heights": swing.get("wall_reach_heights", []),
		"block_jump_timing": swing.get("block_jump_timing", {}),
		"vertical_angle_degrees": float(delivered.get("vertical_angle_degrees", 0.0)),
		"block_kind": str(
			Dictionary(swing.get("resolution", {}).get("block", {})).get("kind", "")
		),
		## Why the wall was beaten, when it was. This record is the only thing
		## promotion sees -- a key the resolver states but the curator drops is a
		## key nothing downstream can read, however faithfully the layers below
		## carry it.
		"block_miss_reason": str(swing.get("block_miss_reason", "")),
		"block_depth_below_reach_meters": swing.get(
			"block_depth_below_reach_meters", null
		),
		"block_edge_gap_meters": swing.get("block_edge_gap_meters", null),
		"block_contact_kind": str(swing.get("block_contact_kind", "")),
		"block_contact_actor_id": int(swing.get("block_contact_actor_id", -1)),
		"block_contact_height_meters": swing.get(
			"block_contact_height_meters", null
		),
		"ball_height_at_net_meters": swing.get("ball_height_at_net_meters", null),
		"block_deflection_landing": swing.get("block_deflection_landing", null),
		"block_deflection_speed_mps": float(swing.get("block_deflection_speed_mps", 0.0)),
		"block_deflection_vertical_angle_degrees": float(swing.get(
			"block_deflection_vertical_angle_degrees", 0.0
		)),
		"block_deflection_duration_seconds": float(swing.get(
			"block_deflection_duration_seconds", 0.0
		)),
		"block_deflection_playable": bool(swing.get("block_deflection_playable", false)),
		"loft_apex_limited": bool(swing.get("loft_apex_limited", false)),
		"net_distance_meters": float(swing.get("net_distance_meters", 0.0)),
		"net_avoidance_demand": float(swing.get("net_avoidance_demand", 0.0)),
		"net_avoidance_spread_multiplier": float(swing.get(
			"net_avoidance_spread_multiplier", 1.0
		)),
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
##   monster_block             a charged apex contact put it down
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
	## Preserve a tool as a tool.  Collapsing it to `touch` made the event record
	## say the wall had kept alive a ball whose trajectory visibly ended outside,
	## even though the terminal result happened to award the hitter correctly.
	## `block_crush` stays a contact too, but it goes through rather than out.
	var block_outcome := "miss"
	if outcome in ["stuff", "monster_block"]:
		block_outcome = "stuff"
	elif outcome == "recycle":
		block_outcome = "recycle"
	elif outcome in ["touch", "block_crush"]:
		block_outcome = "touch"
	elif outcome in ["tool", "high_hands"]:
		block_outcome = "tool"
	elif outcome == "in" and _was_funnelled(record):
		block_outcome = "funnel"
	return {
		"outcome": outcome,
		"block_outcome": block_outcome,
		"attack_missed": terminal == "attack_error",
		"hitter_point": terminal == "kill",
		"target": Vector2(record.get("landing", Vector2(0.5, 0.25))),
		"quality": clampf(float(record.get("quality", 0.0)), 0.0, 1.0),
		"speed_mps": float(record.get("speed_mps", 0.0)),
		"launch_angle_degrees": float(record.get("vertical_angle_degrees", 0.0)),
		"chosen_power_fraction": float(record.get("chosen_power_fraction", 0.0)),
		"shot_spread_multiplier": float(record.get(
			"shot_spread_multiplier", 1.0
		)),
		"out_reason": str(record.get("out_reason", "")),
		## The resolver's own verdict on whether this swing could clear the tape,
		## and which branch of its search answered. Carried the whole way to the
		## event because the question it settles -- is a ball drawn into the net a
		## hitter with no shot, or a drawing that lost the answer -- cannot be
		## asked anywhere else.
		"launch_cleared": bool(record.get("launch_cleared", true)),
		"launch_mode": str(record.get("launch_mode", "")),
		## Why the wall was beaten, when it was. Over the top is a reach problem
		## and around the edge is a positioning one; they want opposite fixes and
		## the outcome alone cannot tell them apart.
		"block_miss_reason": str(record.get("block_miss_reason", "")),
		"block_depth_below_reach_meters": record.get(
			"block_depth_below_reach_meters", null
		),
		"block_edge_gap_meters": record.get("block_edge_gap_meters", null),
		"block_contact_kind": str(record.get("block_contact_kind", "")),
		## The contact itself: who met the ball and how high it was. Forwarded so
		## the BLOCK event can be built from the intersection that was proved
		## rather than from the formation that was assembled before the swing.
		"block_contact_actor_id": int(record.get("block_contact_actor_id", -1)),
		"block_contact_height_meters": record.get(
			"block_contact_height_meters", null
		),
		"ball_height_at_net_meters": record.get(
			"ball_height_at_net_meters", null
		),
		"block_deflection_landing": record.get("block_deflection_landing", null),
		"block_deflection_speed_mps": float(record.get("block_deflection_speed_mps", 0.0)),
		"block_deflection_vertical_angle_degrees": float(record.get(
			"block_deflection_vertical_angle_degrees", 0.0
		)),
		"block_deflection_duration_seconds": float(record.get(
			"block_deflection_duration_seconds", 0.0
		)),
		"block_deflection_playable": bool(record.get("block_deflection_playable", false)),
		"loft_apex_limited": bool(record.get("loft_apex_limited", false)),
		"net_distance_meters": float(record.get("net_distance_meters", 0.0)),
		"net_avoidance_demand": float(record.get("net_avoidance_demand", 0.0)),
		"net_avoidance_spread_multiplier": float(record.get(
			"net_avoidance_spread_multiplier", 1.0
		)),
		## How many blockers were in the wall this swing met.
		##
		## `block_wall` drops any blocker whose close fraction is below
		## `WALL_JOIN_CLOSE`, so this is the only figure that says whether "no
		## wall" means nobody was assigned or nobody arrived -- and those want
		## opposite fixes. It was in the record and this curator did not forward
		## it, which is the same dropped-key shape that hid `block_miss_reason`
		## for as long.
		"wall_size": int(record.get("wall_size", 0)),
		"wall_reach_heights": record.get("wall_reach_heights", []),
		"block_jump_timing": record.get("block_jump_timing", {}),
		"net_height_over_block_meters": float(
			record.get("net_height_over_block_meters", 0.0)
		),
		"block_edge_miss_meters": float(record.get("block_edge_miss_meters", 0.0)),
		"net_crossing_x": float(record.get("net_crossing_x", 0.5)),
		"signature_move": str(
			Dictionary(record.get("narrative", {})).get("attempted_move", "")
		),
		"signature_succeeded": bool(
			Dictionary(record.get("narrative", {})).get("move_succeeded", false)
		),
		"signature_charge": float(
			Dictionary(record.get("narrative", {})).get("signature_charge", 0.0)
		),
		"signature_actor_id": int(
			Dictionary(record.get("narrative", {})).get("signature_actor_id", -1)
		),
		"signature_timing_quality": float(
			Dictionary(record.get("narrative", {})).get("signature_timing_quality", 0.0)
		),
	}


## Did the wall *shape* this swing, though it never touched it?
##
## `_contest_block` has four bands and this promotion had three words. Every
## would-be funnel became a `miss`, so a wall that squeezed a hitter into the one
## lane the defence was standing in was recorded identically to one beaten by
## three metres -- and the `Funnel` block intent, which is a tactical choice the
## manager makes on the clipboard, had no outcome that could express it working.
##
## That is §0 in a shape worth naming: not a threshold outside its distribution,
## but a **band whose value a downstream mapping could not say**. It computed
## correctly and was discarded one function later, silently, for as long as
## geometric promotion has been on.
##
## ## Two conditions, both geometric
##
## **The ball went past an edge**, not over the top. Measured: of 140 beaten
## blocks, the 56 hit `over` have an edge miss of 0.00 m to ten decimal places --
## a ball that cleared the hands never went past them. Cutting the whole beaten
## population would put a threshold inside a spike at zero and call every
## over-the-top swing a funnel.
##
## **And it went past narrowly.** The 65 blocks with a lateral escape spread from
## 0.02 m to over a metre, median 0.42. A funnel is the narrow end: the hitter
## had to squeeze the ball past the hand rather than sail it wide.
##
## The cut is `BLOCKER_HALF_WIDTH_METERS` -- the ball crossed closer to the hand
## than the hand is wide. That is a physical statement rather than a number
## chosen to hit a rate, and it uses a constant the wall is already built from,
## so a wider blocker funnels more without a second dial being invented.
##
## Measured at that cut: about 7% of blocks, which sits between the stuff band's
## 10.2% and the touch band's 27.6% rather than swamping either.
func _was_funnelled(record: Dictionary) -> bool:
	if not str(record.get("block_miss_reason", "")).contains("around"):
		return false
	var escape = record.get("block_edge_miss_meters", null)
	if escape == null:
		return false
	return absf(float(escape)) <= GeometricAttackPromotionModel.BLOCKER_HALF_WIDTH_METERS



## **How much a team's commitment moves the bar a swing has to clear.**
##
## `decisiveness` reached the attack twice and neither touched error.
## `_attack_effectiveness` scales quality by 0.85-1.15 but `attack_missed` reads
## the *unmultiplied* figure, deliberately -- commitment prices what a ball does
## after it lands in. That left `_identity_hit_type`, which substitutes a roll or
## a tip on a ball a cautious side does not like, as the only path to error.
##
## Measured over 200 rallies per identity with the resolver confirmed reading
## `decisiveness = 0.18`, that substitution fired **0.0% of the time** while the
## same function's committed branch converted 43 tempo swings into power swings.
## Its trigger needs set quality under 0.48 and home first-ball set quality now
## sits at 0.708, so the branch went out of reach by the offence improving rather
## than by a bad constant.
##
## A property that depends on how often a bad ball happens is a property that
## disappears when a team gets good at not producing bad balls. So commitment
## moves the bar continuously instead: a side that swings at everything asks more
## of each swing than a side that picks its moments, whatever the ball was.
##
## Sized against the curve it shifts rather than guessed. The response width is
## 0.12, so a full swing of the axis moves the threshold by half a width -- large
## enough to separate two identities in a 48-sample directional check, small
## enough that it cannot swamp execution, which is still what decides the shot.
##
## **This is live only on the non-geometric fallback, and that is not enough.**
## Three lines after the home call site, `attack_missed = bool(geometric
## .attack_missed)` overwrites it whenever a geometric swing resolved -- which is
## the ordinary path. So the shift below is computed and discarded on almost
## every attack in the game, and the identity calibration came back **byte
## identical** after it was added: 0.0843 against 0.0806, the same four decimals
## as before.
##
## Failure mode #1, walked into while fixing a dead branch. Recorded here rather
## than quietly left, because the parameter is correct where it is reached and
## the real repair is one level down: a geometric swing lands in or out from its
## own course and speed, so commitment has to move something the resolver reads
## -- the swing's aim tolerance or its speed -- rather than a threshold applied
## afterwards. See `docs/BACKLOG.md`.
const ATTACK_COMMITMENT_ERROR_SHIFT: float = 0.06


func _attack_missed(
	attack_quality: float,
	decisiveness: float = 0.5,
	hitter: VolleyballPlayer = null,
) -> bool:
	var threshold := ATTACK_ERROR_THRESHOLD \
		+ (clampf(decisiveness, 0.0, 1.0) - 0.5) * 2.0 \
		* ATTACK_COMMITMENT_ERROR_SHIFT
	var response := 1.0 / (1.0 + exp(
		(clampf(attack_quality, 0.0, 1.0) - threshold)
			/ ATTACK_ERROR_RESPONSE_WIDTH
	))
	var miss_chance := lerpf(ATTACK_ERROR_FLOOR, ATTACK_ERROR_CEILING, response)
	## **Both error channels, because a swing can go wrong either way.** A spent
	## hitter is beaten to the ball's own timing -- late off the floor, reaching
	## at a set that has already dropped -- which is forced; and separately swings
	## long at nothing, which is not. `attack_quality` already carries the
	## attribute loss, so adding these is not double-charging the same tiredness:
	## it is the mistake the degraded attributes do not produce on their own,
	## which is the whole reason the spent stage exists as a channel.
	if hitter != null:
		miss_chance += FatigueModel.forced_error_bias(hitter.fatigue) \
			+ FatigueModel.unforced_error_bias(hitter.fatigue)
	return rng.randf() < clampf(miss_chance, 0.0, 0.85)


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
	## And the spent stage on top, as its own term rather than through the
	## attributes. A serve is the one contact in the game with no opponent on it,
	## so a serve missed by an exhausted server is the purest unforced error there
	## is -- which is exactly why it is the *unforced* channel that is added here
	## and not the forced one.
	return clampf(
		SERVE_ERROR_CEILING * demand * (1.0 - control)
			+ FatigueModel.unforced_error_bias(server.fatigue),
		0.005, 0.45,
	)


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
## How far a ball misses the point it was aimed at, and how much further a long
## one misses.
##
## **Scatter did not know how far the ball was going.** One standard deviation
## from set quality, applied identically to a 1.5 m back-set and a 9 m ball to
## the far pin. Measured over 1,216 sets before this: drift ran 0.26 m at 3-6 m
## and 0.40 m beyond 6 m, and *0.34 m under 3 m* -- worse at short range than at
## medium, which is backwards for anything thrown. What that non-monotonicity
## actually shows is that distance was never an input; the buckets differ only
## because short sets are attempted in worse situations.
##
## An angular error is the shape that fixes it. A setter releases the ball a few
## degrees off, and a few degrees is centimetres near the net and half a metre
## across the court -- so the deviation grows with the throw rather than being
## a fixed radius the whole offence lives inside.
##
## The existing quality band stays and is now the *angular* term. The reference
## distance is where the two agree, chosen as the measured median set so that
## the population's middle is unchanged and only its tails move.
const SET_DELIVERY_REFERENCE_METERS: float = 3.63
## How much of the error is angular rather than fixed. A release is not purely
## a rotation -- a mishandled ball leaves the hands wrong at any range -- so the
## fixed share stays and this is what rides on distance.
const SET_DELIVERY_ANGULAR_SHARE: float = 0.70

## How high the ball climbs before accuracy starts paying for it, in metres
## above the release, and how fast it pays.
##
## **A ball you put up is a ball you stop steering.** Distance was the only
## thing scatter knew about, and height is the other half of the same geometry:
## every extra metre of climb is more time in the air with nothing acting on the
## ball but gravity and whatever the release got wrong, and the release error is
## amplified over a longer arc rather than being carried straight to the target.
##
## The reference is roughly a normal set's climb, so an ordinary ball pays
## nothing and this describes the tail: the rescue set put up to buy a hitter
## time, the high outside ball, the emergency bump that goes to the ceiling.
## Those are exactly the balls that should be harder to place, and the reason
## a team does not simply set everything high.
##
## The slope is deliberately gentle. It is unmeasured -- nothing has published
## accuracy against ball height, because until now nothing varied the height --
## so this is a starting value, and `tools/pass_and_set_probe.tscn` prints the
## distribution the tuning will need.
const DELIVERY_HEIGHT_REFERENCE_METERS: float = 1.10
const DELIVERY_HEIGHT_PENALTY_PER_METER: float = 0.22


func _delivered_point(
	intended: Vector2,
	quality: float,
	worst_stdev_meters: float,
	best_stdev_meters: float,
	min_y: float,
	max_y: float,
	## Zero means "no distance known", which keeps every caller that has not been
	## given one on exactly the behaviour it had -- the reference ratio is 1.0.
	distance_meters: float = 0.0,
	## **How far the ball climbs above the release**, not its absolute apex and
	## not only the rescue portion.
	##
	## Named in full because the first cut got it wrong on one path of three:
	## home and transition passed `arc.apex_height_meters + rescue`, which is the
	## whole climb, and the opponent passed the rescue alone -- so an ordinary
	## opponent set had a rise of zero and paid no height penalty at all, while
	## an ordinary home set paid for its entire arc. One number, three callers,
	## two meanings, and the asymmetry ran the way this file's asymmetries always
	## run. `_set_arc` returns `apex_height_meters` already relative to the
	## release, which is what makes the sum correct and what made the omission
	## invisible.
	rise_above_release_meters: float = 0.0,
) -> Vector2:
	var stdev_meters := lerpf(
		worst_stdev_meters, best_stdev_meters, clampf(quality, 0.0, 1.0)
	)
	if distance_meters > 0.0:
		var reach := distance_meters / SET_DELIVERY_REFERENCE_METERS
		stdev_meters *= lerpf(
			1.0, reach, clampf(SET_DELIVERY_ANGULAR_SHARE, 0.0, 1.0)
		)
	## And every metre the ball is put up above an ordinary arc.
	if rise_above_release_meters > DELIVERY_HEIGHT_REFERENCE_METERS:
		stdev_meters *= 1.0 + (
			rise_above_release_meters - DELIVERY_HEIGHT_REFERENCE_METERS
		) * DELIVERY_HEIGHT_PENALTY_PER_METER
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
## How badly this defender misreads where the ball is going, in metres.
##
## **`BallReadSystem` was built for exactly this and wired to nothing live.**
## Four shadow systems call it; the rally called it nowhere, so
## `choose_claimant` was handed the ball's *true* landing point and every
## defender in the game went to precisely the right spot. `anticipation` bought a
## shorter reaction delay and a better claim score -- getting there sooner, and
## being more likely to be the one who goes -- but never a *worse place to go*,
## because there was no such thing.
##
## The estimate's own terms are the ones the report asked for: reading ability,
## familiarity with this ball, how much of the flight has been watched, and the
## flight's novelty -- and novelty is `BallContactSignature.baseline_novelty()`,
## which weights topspin at 0.17, sidespin at 0.18 and instability at 0.16. So a
## float serve and a heavily spun ball are harder to track by construction rather
## than by a special case, and a ball watched all the way from the far endline is
## easier than a spike from four metres.
##
## Returned as a *distance* rather than as a point, because that is what the
## arrival terms need and because the direction of a read error is not something
## any consumer downstream can act on: a defender who is 40 cm out is 40 cm out
## whichever way. The point itself stays available on the estimate for playback
## if it is ever wanted.
## How far into a flight a defender commits to where they think it is going.
##
## Not the whole of it: a defender who watched the ball all the way to the floor
## would know exactly where it landed and have no time left to use the knowledge.
## Rather more than half, because the last of the information arrives late and a
## defender is still adjusting into the final step.
const READ_COMMIT_SHARE: float = 0.62


func _read_error_meters(
	defender: VolleyballPlayer,
	trajectory: Dictionary,
	spin_state: Dictionary,
	_observation_time: float,
) -> float:
	if defender == null or trajectory.is_empty():
		return 0.0
	var signature := BallContactSignature.create(
		&"flight",
		## **The pace the ball actually left the contact at, when the record
		## knows it.**
		##
		## `BallPresentation.launch_speed_mps` derives speed from the start
		## height, the *chosen endpoint* height and the duration, so a flight cut
		## short somewhere else comes back slower -- presentation deciding a
		## gameplay physical value, which §7 of the spec forbids and which this is
		## the one live instance of. Worse, every published trajectory carried
		## 1.0 m at both ends, so its vertical term was exactly zero for every
		## ball in the game and the "speed" a defender read was pure horizontal.
		##
		## The serve now publishes its own launch state and this reads it. The
		## other families still reconstruct, and will until each owns its launch
		## in turn; the fallback is what makes that a migration rather than a
		## rewrite.
		float(trajectory.get(
			"launch_speed_mps", BallPresentation.launch_speed_mps(trajectory)
		)),
		0.0,
		0.0,
		float(spin_state.get("topspin_rps", 0.0)),
		float(spin_state.get("sidespin_rps", 0.0)),
		float(spin_state.get("flight_stability", 1.0)),
	)
	var start_time := float(trajectory.get("start_time", 0.0))
	var flight := BallFlight.create(
		Vector2(trajectory.get("start_position", Vector2.ZERO)),
		Vector2(trajectory.get("end_position", Vector2.ZERO)),
		start_time,
		float(trajectory.get("duration", 0.5)),
		signature,
		float(trajectory.get("end_height_meters", 1.0)),
	)
	## **Measured from the flight's own clock, not the rally's.**
	##
	## `observation_progress` is how much of the ball a defender has watched, and
	## passing `rally_clock` made that depend on where in the code the question
	## was asked: the home floor defence reaches its claim with the clock already
	## advanced into the swing, while the opponent's is still sitting at the set's
	## contact. Same model, same ball, two different amounts of information --
	## measured, the two sides' dig rates opened from a gap of 0.100 to 0.231 and
	## neither of the two wiring asymmetries I fixed first was the cause.
	##
	## Anchored on the flight instead, every defender gets the same share of the
	## same ball, and the term means what it says.
	var estimate: Resource = BallReadSystem.estimate(
		flight, defender,
		Familiarity.read_modifier(defender, ["flight"]),
		start_time + float(trajectory.get("duration", 0.5)) * READ_COMMIT_SHARE,
		hash("%d|read|%d" % [rally_seed, defender.id]),
	)
	return CoverageModel.court_distance_meters(
		estimate.true_destination, estimate.perceived_destination
	)


## The arrival a defender actually has, once they have gone to the wrong place.
##
## `choose_claimant` answers against the true landing point, and that stays: the
## call is a team decision -- somebody shouts "mine" -- and it is made on where
## the ball is going, not on one player's private guess. What is individual is
## *where that player then goes*, and the cost of being wrong is paid at the end
## of the journey with no time left to fix it.
##
## So the error is added to the distance rather than moving the target: the
## defender covers what they meant to cover and is then short by their own read
## error, which is exactly the quantity `reach_margin` measures and exactly what
## the `reaching` posture is classified from. A defender with reach to spare
## absorbs it and stays planted; one who was already at full stretch does not.
func _read_adjusted_arrival(
	arrival: Dictionary, read_error_meters: float
) -> Dictionary:
	if arrival.is_empty() or read_error_meters <= 0.0:
		return arrival
	var adjusted := arrival.duplicate(true)
	adjusted["distance_meters"] = float(
		arrival.get("distance_meters", 0.0)
	) + read_error_meters
	adjusted["reach_margin_meters"] = float(
		arrival.get("reach_margin_meters", 0.0)
	) - read_error_meters
	adjusted["edge_ratio"] = float(adjusted.distance_meters) / maxf(
		float(arrival.get("assigned_reach_meters", 0.1)), 0.1
	)
	adjusted["read_error_meters"] = read_error_meters
	return adjusted


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
## Whether the ball was dug, **and how well**, from the same number.
##
## `_dig_contest` returned a bool and threw the margin away. Measured over 299
## digs that made the contest a step function: the execution noise is +/-0.10
## against a margin spanning 0.79, so two of every five digs were certain
## failures, two were certain successes, and one band in the middle sat at 0.80.
## Worse, the DEFENSE event recorded `defense_strength` -- the defender's own
## terms -- as its quality, so a dig that survived by a hundredth and one that
## was never in doubt were written down identically, and the setter behind them
## received the same ball.
##
## Which is the half the design was missing. A hit that clears the defence
## outright is a kill and always was; a hit that *nearly* clears it should still
## hurt -- the defender gets a platform on it and the ball goes somewhere,
## rather than to their setter. That is what makes a powerful attack worth
## making against a defence good enough to keep it up, and it is the whole of
## "the margin multiplies its effectiveness".
##
## `control` is graded from the threshold rather than from zero, so the span and
## the bar cannot drift apart: whatever `DIG_ATTACKER_ADVANTAGE` becomes, a dig
## sitting exactly on it is still a scramble and one `DIG_COMFORT_SPAN` above it
## is still clean. The span is 0.40 because the measured margin runs -0.397 to
## +0.476 between the tenth and ninetieth percentile, so it covers the half of
## that range a surviving defender actually occupies.
const DIG_COMFORT_SPAN: float = 0.40
## What is left of a dig that only just happened. Not zero: the defender did
## touch it and the ball is still up, which is the difference between a scramble
## and a kill.
const DIG_SCRAMBLE_CONTROL: float = 0.35


func _dig_outcome(
	defender: VolleyballPlayer,
	defense_quality: float,
	attack_pressure: float,
) -> Dictionary:
	var edge := defense_quality - attack_pressure + _execution_error(
		defender, "dig_control", DIG_EXECUTION_NOISE
	)
	var comfort := clampf(inverse_lerp(
		DIG_ATTACKER_ADVANTAGE, DIG_ATTACKER_ADVANTAGE + DIG_COMFORT_SPAN, edge
	), 0.0, 1.0)
	return {
		## Identical to the boolean this replaced: `defense + noise > attack +
		## advantage` is `edge > advantage` rearranged, so the outcome does not
		## move until `DIG_ATTACKER_ADVANTAGE` is deliberately changed.
		"dug": edge > DIG_ATTACKER_ADVANTAGE,
		"edge": edge,
		"control": defense_quality * lerpf(DIG_SCRAMBLE_CONTROL, 1.0, comfort),
	}


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
func _block_wall_quality(
	primary_skill: float,
	assist_skill: float,
	primary_net_x: float,
	assist_net_x: float,
) -> float:
	var solo := clampf(primary_skill, 0.0, 1.0) * BLOCK_SOLO_SHARE
	## What the assist is worth depends on whether it arrived beside the primary
	## or somewhere else along the tape.
	##
	## This took two skill numbers and no positions, which is the same history as
	## the coverage target above: the wall became two placed pairs of hands at
	## resolution and stayed two scalars here. Two blockers standing 40 cm apart
	## and two standing a metre and a half apart returned the same number, and
	## the second of those is not a wall -- it is a seam with a person on either
	## side of it. Both formations publish the closed positions in the same
	## dictionary as this figure.
	return clampf(
		solo + (1.0 - solo) * clampf(assist_skill, 0.0, 1.0)
			* BLOCK_ASSIST_SHARE * _wall_join_fraction(primary_net_x, assist_net_x),
		0.05, 0.98,
	)


## How much of a joined wall these two blockers actually make, 1 for shoulder to
## shoulder and 0 for far enough apart that the ball goes between them.
##
## Sealed while their reach envelopes still overlap, opening linearly from there.
## The widths are the geometric resolver's own, so the seam this opens is the
## same seam that model will find the ball going through.
func _wall_join_fraction(primary_net_x: float, assist_net_x: float) -> float:
	var gap := absf(primary_net_x - assist_net_x) \
		* CourtConstants.COURT_WIDTH_METERS
	var sealed_within := 2.0 * GeometricAttackPromotionModel.BLOCKER_HALF_WIDTH_METERS
	return clampf(
		1.0 - (gap - sealed_within) / WALL_SEAM_OPEN_METERS, 0.0, 1.0
	)


## How much of this wall's pre-set movement was a decision rather than a
## reaction.
##
## A blocker who committed keeps their head start whatever the tempo -- that is
## what committing *is*, and it is the only way a first-tempo ball ever draws
## two blockers. What a quick set takes away is the ability to *react*: to read
## the set, change your mind, and still arrive in time.
##
## Both walls read the same two inputs, so neither bench gets a block philosophy
## the other lacks. The home wall's explicit Commit Pin / Commit Middle call
## shifts its closing time separately and on top of this.
func _assist_committed_share(commitment: float, read_quality: float) -> float:
	var commitment_signal := clampf(commitment, 0.0, 1.0) * 0.5 \
		+ clampf(read_quality, 0.0, 1.0) * 0.5
	return clampf(
		(commitment_signal - ASSIST_COMMIT_SIGNAL_FLOOR)
			/ ASSIST_COMMIT_SIGNAL_SPAN,
		0.0, 1.0,
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


## The lane and tempo for a swing nobody called a play for.
##
## The lane used to be decided by which half of the court the hitter happened to
## stand in, which can only ever produce a pin -- and `_hit_type` reads
## "Quick attack" off the *lane*, never off the tempo, so no amount of tempo
## variation could have produced one. A middle assigned a pin is a middle
## running a pin approach, which is not what a middle does and not what the
## block has to solve.
##
## The tempo 3 default is deliberate and stays: a set nobody called is a safe
## high ball. What changes is that a quick is now a lane a middle can be given,
## and a quick is a first-tempo ball by definition.
func _fallback_assignment(
	hitter: VolleyballPlayer,
	lineup: RotationLineup,
) -> HitterAssignment:
	var assignment := HitterAssignment.new()
	assignment.player_id = hitter.id
	assignment.start_position = CourtConstants.slot_position(
		lineup.slot_for_player(hitter.id)
	)
	var slot_number := lineup.slot_for_player(hitter.id)
	var left_side := assignment.start_position.x <= 0.5
	## A back-row swing is a pipe and nothing else. `PlayValidator` has said so
	## since the plays were written -- "back-row hitters must use the Pipe lane" --
	## and this is the fallback offence finally agreeing with it.
	if RallyFeatureFlagsModel.ENABLE_HOME_PIPE_OFFENSE \
			and slot_number >= 1 and not CourtConstants.is_front_row_slot(slot_number):
		assignment.lane = "Pipe"
		assignment.tempo = PIPE_TEMPO_CALL
		return assignment
	var is_middle := hitter.position_role == "Middle Blocker" \
		and CourtConstants.is_front_row_slot(slot_number)
	if not RallyFeatureFlagsModel.ENABLE_HOME_MIDDLE_OFFENSE:
		assignment.lane = "Left Pin" if left_side else "Right Pin"
		assignment.tempo = 3
		return assignment

	## The lane a hitter *can* be set, rather than the one their rotation slot
	## implies.
	##
	## This was `"Left Pin" if x <= 0.5 else "Right Pin"` -- a lookup on where the
	## chosen hitter happened to be standing, with no decision anywhere in it. Four
	## lanes were reachable in principle and two in practice: measured over 67 home
	## swings, Right Pin 0.821 and Front Quick 0.179, with Left Pin, Right Quick
	## and Pipe at zero. Lane and tempo were bound together on the same lookup, so
	## `_apply_identity_tempo` could only ever redistribute tempo *within* a lane
	## it had no say in -- which is why 55 of 55 Right Pin swings came out at tempo
	## 3 and every attribute meant to create variety measured as inert.
	##
	## A hitter gets their natural lane and one they can be moved to. The middle
	## runs the quick in front of the setter or slides behind it; a pin hitter can
	## be brought inside on a shoot. Both alternatives are quick balls, so both are
	## gated on the setter being able to deliver one -- which the setter has been
	## deciding in shadow all along.
	var natural := ("Front Quick" if left_side else "Right Quick") if is_middle \
		else ("Left Pin" if left_side else "Right Pin")
	## A middle's alternative is the other side of the setter -- the slide. A pin
	## hitter's is not a different lane at all: it is their *own* lane run fast,
	## which is a shoot. Sending an outside hitter to the middle to "run a quick"
	## was the wrong model of the same idea, and it moved a hitter across the
	## court to do something they can do where they stand.
	var lanes: Array[Dictionary] = [{"lane": natural, "tempo": -1}]
	if setter_can_run_quick:
		if is_middle:
			var slide := "Right Quick" if left_side else "Front Quick"
			if slide != natural:
				lanes.append({"lane": slide, "tempo": -1})
		else:
			lanes.append({"lane": natural, "tempo": SHOOT_TEMPO_CALL})

	var best_lane := natural
	var best_tempo := -1
	var best_score := -1.0e9
	for index in range(lanes.size()):
		var lane := str(lanes[index]["lane"])
		var option_tempo := int(lanes[index]["tempo"])
		## Their own lane is what they rehearse; being moved off it is a thing
		## only a hitter with a repertoire can be asked to do.
		## Their own lane at their own tempo is what they rehearse. Being moved
		## across the court, or asked to run their lane fast, are both things only
		## a hitter with a repertoire can be asked to do.
		var score := 1.0 if lane == natural and option_tempo < 0 \
			else _rating(hitter, "shot_variety")
		## And not into the one the other bench has learned to expect.
		##
		## `OpponentTeam.anticipated_lane()` is already read twice in this file --
		## both times to *reward the block* for having read the lane. The offence
		## could be punished for repeating itself and had no way to stop.
		if opponent_anticipated_lane != "" and lane == opponent_anticipated_lane:
			score -= LANE_ANTICIPATED_PENALTY
		## The same seed-derived spread the hitter choice uses: no random draw, so
		## nothing downstream re-sequences.
		score += float(posmod(rally_seed + hitter.id * 17 + index * 7, 5)) \
			* SET_SPREAD_STEP
		if score > best_score:
			best_score = score
			best_lane = lane
			best_tempo = option_tempo
	assignment.lane = best_lane
	if best_tempo >= 0:
		## A shoot: the pin, run at a tempo that beats the wall forming on it.
		assignment.tempo = best_tempo
		return assignment
	var quick_lane := best_lane in ["Front Quick", "Right Quick"]
	## Otherwise tempo follows the lane, because a quick is a first-tempo ball by
	## definition and a pin ball off this offence is a high one.
	assignment.tempo = QUICK_TEMPO_CALL if quick_lane else 3
	return assignment


## One of these hitters, in proportion to how good an option they are.
##
## An argmax was the wrong shape here and the measurements said so twice. The
## scores this ranks are close together -- four front-row attackers land inside
## about a tenth of each other -- so picking the maximum makes the offence a step
## function of its own constants: moving `QUICK_OPTION_BONUS` from 0.14 to 0.06,
## six hundredths, took Front Quick from 0.568 to 0.176 and Left Pin from 0.203
## to 0.595. A distribution that flips on a constant that small is not measuring
## the constant, it is measuring which side of a tie it fell.
##
## `SET_SPREAD_STEP` was a deterministic stand-in for this and its own comment
## called itself a placeholder. This replaces it. A setter distributes: the best
## option gets the ball most often and everybody else gets it sometimes, which is
## also the only thing that stops a block reading one rotation.
##
## Sharpness rather than a flat share, so the gap between hitters still matters.
## It consumes one draw, which re-sequences the rally -- an accepted cost, since
## the alternative is an offence decided by rounding.
func _distributed_choice(scored: Array[Dictionary]) -> VolleyballPlayer:
	var total := 0.0
	var weights: Array[float] = []
	for entry in scored:
		var weight := pow(float(entry.score), SET_DISTRIBUTION_SHARPNESS)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return scored[0].player as VolleyballPlayer
	var roll := rng.randf() * total
	for index in range(scored.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return scored[index].player as VolleyballPlayer
	return scored[scored.size() - 1].player as VolleyballPlayer


## The front-row middle, if there is one who is not already committed elsewhere.
func _front_row_middle(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	excluded_player_id: int,
) -> VolleyballPlayer:
	for slot_number in range(1, 7):
		if not CourtConstants.is_front_row_slot(slot_number):
			continue
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and candidate.id != excluded_player_id \
				and _can_enter_attack(candidate) \
				and candidate.position_role == "Middle Blocker" \
				and lineup.is_attack_eligible(candidate.id):
			return candidate
	return null


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
	receivers: Array[Vector2] = [],
	serve_origin: Vector2 = Vector2(0.5, 0.5),
	decision: Dictionary = {},
) -> Vector2:
	var home_y := 0.84 if landing_on_home_side else 0.16
	var short_y := 0.67 if landing_on_home_side else 0.33
	var intended := Vector2(0.20, home_y)
	## What the bench asked for. This stays a named call, because choosing a zone
	## is the manager's decision and not something to be solved away.
	var seam_weight := SERVE_SEAM_WEIGHT
	match target_name:
		"Zone 1":
			intended = Vector2(0.80, home_y)
		"Short Middle":
			intended = Vector2(0.50, short_y)
		"Weak Passer":
			intended = _weak_passer_target(home_players, lineup, landing_on_home_side)
			## The one intent that is aimed at a person rather than at a gap, so
			## it must not then be pulled off them toward the nearest seam.
			seam_weight = 0.0
		_:
			intended = Vector2(0.20, home_y)
	## Placement determines how specific the chosen target is before execution
	## error is applied. A low-placement server aims at a broad part of the zone;
	## an elite one identifies a seam-sized point. This is intentionally separate
	## from whether the contact actually reaches that point.
	var placement := _rating(server, "serve_placement")
	var target_radius_meters := lerpf(1.80, 0.22, placement)
	var selected_point := Vector2(
		intended.x + serve_decision_rng.randf_range(
			-target_radius_meters / CourtConstants.COURT_WIDTH_METERS,
			target_radius_meters / CourtConstants.COURT_WIDTH_METERS,
		),
		intended.y + serve_decision_rng.randf_range(
			-target_radius_meters / CourtConstants.COURT_LENGTH_METERS,
			target_radius_meters / CourtConstants.COURT_LENGTH_METERS,
		),
	)
	var previous_aim := Vector2(decision.get("previous_aim", Vector2(-1.0, -1.0)))
	if bool(decision.get("repeat_target", false)) and previous_aim.x >= 0.0:
		selected_point = selected_point.lerp(
			previous_aim, _rating(server, "serve_consistency")
		)
	intended = selected_point
	if str(decision.get("mode", "targeted")) == "aggressive":
		seam_weight = lerpf(0.35, 0.90, placement)
	## Where the zone actually is, given who is standing in the way.
	##
	## The four anchors above used to *be* the answer: a serve landed on one of
	## four fixed dots regardless of how the receiving side had lined up, while
	## reception resolved against a real seam formation with per-passer arrival
	## margins and body penalties. The receive was geometry at resolution and a
	## menu of four points at selection, and nothing made the two agree -- the
	## home serve did not even take the receivers as an argument, and was called
	## with an empty array.
	##
	## The named zone still decides roughly where the ball goes. Within that, the
	## serve now finds the gap: a passer standing on Zone 5 makes Zone 5 a worse
	## place to serve than the seam beside it, which is the entire reason a
	## server looks at the other side before they toss.
	intended = _open_serve_point(
		intended, receivers, landing_on_home_side, seam_weight,
		server, serve_origin,
	)
	var accuracy := float(decision.get(
		"execution_accuracy", _rating(server, "serve_placement")
	))
	var deviation := lerpf(0.105, 0.018, accuracy)
	var min_y := 0.54 if landing_on_home_side else 0.04
	var max_y := 0.96 if landing_on_home_side else 0.46
	decision["aim_point"] = intended
	decision["target_radius_meters"] = target_radius_meters
	return Vector2(
		clampf(intended.x + rng.randf_range(-deviation, deviation), 0.06, 0.94),
		clampf(intended.y + rng.randf_range(-deviation * 0.65, deviation * 0.65), min_y, max_y),
	)


## Decide what kind of serve is attempted before resolving its contact.
func _serve_decision(
	side: String,
	called_target: String,
	server: VolleyballPlayer,
	tactical_risk: float,
) -> Dictionary:
	var aggression_roll := serve_decision_rng.randf()
	var change_roll := serve_decision_rng.randf()
	var target_roll := serve_decision_rng.randf()
	var history_key := "%s:%d" % [side, server.id]
	var previous: Dictionary = Dictionary(previous_serves.get(history_key, {}))
	var previous_target := str(previous.get("target", ""))
	var selected_target := called_target \
		if called_target in SERVE_TARGET_NAMES else "Zone 5"
	var change_chance := _rating(server, "serve_variation") * 0.72
	var changed_target := not previous_target.is_empty() \
		and change_roll < change_chance
	if changed_target:
		var alternatives: Array[String] = []
		for target in SERVE_TARGET_NAMES:
			if target != previous_target:
				alternatives.append(target)
		selected_target = alternatives[mini(
			int(floor(target_roll * float(alternatives.size()))),
			alternatives.size() - 1,
		)]
	var aggression_chance := clampf(
		_rating(server, "serve_aggression") * 0.68
			+ clampf(tactical_risk, 0.0, 1.0) * 0.32,
		0.0, 1.0,
	)
	var mode := "aggressive" if aggression_roll < aggression_chance else "targeted"
	var target_familiarity := Familiarity.familiarity(
		server, ["serve_target:%s" % selected_target]
	)
	var learned_control := 0.30 + target_familiarity * 0.70
	var execution_accuracy := learned_control * 0.58 \
		+ _rating(server, "serve_consistency") * 0.30 \
		+ _rating(server, "serve_technique") * 0.12
	if changed_target:
		execution_accuracy -= (1.0 - _rating(server, "serve_consistency")) * 0.24
	elif not previous_target.is_empty():
		execution_accuracy += _rating(server, "serve_consistency") * 0.08
	var effective_risk := clampf(tactical_risk, 0.0, 1.0)
	if mode == "aggressive":
		effective_risk = maxf(effective_risk, aggression_chance)
	else:
		effective_risk *= 0.72
	return {
		"called_target": called_target,
		"target": selected_target,
		"mode": mode,
		"risk": effective_risk,
		"changed_target": changed_target,
		"repeat_target": not previous_target.is_empty()
			and selected_target == previous_target,
		"previous_aim": previous.get("aim_point", Vector2(-1.0, -1.0)),
		"target_familiarity": target_familiarity,
		"execution_accuracy": clampf(execution_accuracy, 0.05, 0.98),
		"target_radius_meters": 0.0,
		"aim_point": Vector2.ZERO,
	}


## Power sets the pace ceiling. Technique determines how much of that ceiling
## survives contact; it cannot create pace a server does not physically have.
func _usable_serve_pace(server: VolleyballPlayer) -> float:
	if server == null:
		return 0.0
	return _power_rating(server, "serve_power") * lerpf(
		0.52, 1.0, _rating(server, "serve_technique")
	)


## The best point to serve near a requested zone, given where the passers are
## *and* what this server can actually hit.
##
## Three terms. How far the ball lands from the nearest passer and how far it
## strays from the zone the bench asked for are both in metres, so they trade off
## without a fudge factor. The third is the one that keeps this honest: the open
## floor is only worth what the server can bank.
##
## Without it this function is an argmax over openness, and openness is maximised
## exactly where the ball is nearly out -- so it replaced four hardcoded dots
## with one computed dot in the deep corner, chosen identically on every serve by
## every server. That is worse than the menu it replaced, because at least the
## menu's dots were inside the court on purpose.
##
## `confidence` is the share of this server's own error distribution that still
## lands in, times whether the ball carries that far at all. It is not a rule
## that gates zones by attribute -- it is the arithmetic of a spread against a
## line, and the gating falls out: a server whose placement scatters 1.5 m has
## no business aiming 0.4 m off the sideline, so for them the corner scores as
## the empty floor it is, and they take the anchor. A server who scatters 25 cm
## gets to attack it. Nobody is told which; they are priced.
func _open_serve_point(
	anchor: Vector2,
	receivers: Array[Vector2],
	landing_on_home_side: bool,
	seam_weight: float,
	server: VolleyballPlayer,
	serve_origin: Vector2,
) -> Vector2:
	if receivers.is_empty() or seam_weight <= 0.0 or server == null:
		return anchor
	var min_y := 0.54 if landing_on_home_side else 0.04
	var max_y := 0.96 if landing_on_home_side else 0.46
	## The same spread the landing point is perturbed by below, read here so the
	## server aims against the error they are about to make.
	var spread := lerpf(0.105, 0.018, _rating(server, "serve_placement"))
	## And the same speed the geometric serve is struck at.
	var reach_meters := _serve_carry_meters(server)
	## How far this server is willing to chase a gap.
	var reward_cap := lerpf(
		SERVE_SEAM_REWARD_TIMID_METERS, SERVE_SEAM_REWARD_BOLD_METERS,
		_rating(server, "serve_aggression"),
	)
	var best := anchor
	var best_score := -1.0e9
	for column in range(SERVE_SCAN_COLUMNS):
		var x := lerpf(
			0.08, 0.92, float(column) / float(SERVE_SCAN_COLUMNS - 1)
		)
		for row in range(SERVE_SCAN_ROWS):
			var candidate := Vector2(x, lerpf(
				min_y, max_y, float(row) / float(SERVE_SCAN_ROWS - 1)
			))
			var drift := CoverageModel.court_distance_meters(anchor, candidate)
			if drift > SERVE_SEAM_SEARCH_RADIUS_METERS:
				continue
			var nearest := 99.0
			for receiver in receivers:
				nearest = minf(
					nearest,
					CoverageModel.court_distance_meters(receiver, candidate),
				)
			var score := seam_weight \
				* minf(nearest, reward_cap) \
				* _serve_confidence(
					candidate, spread, reach_meters, serve_origin,
					landing_on_home_side,
				) - drift
			if score > best_score:
				best_score = score
				best = candidate
	return best


## How much of a serve aimed here this server keeps on the court, near enough.
##
## Two independent ways to fail, multiplied: scattering over a line, and not
## carrying that far in the first place.
func _serve_confidence(
	candidate: Vector2,
	spread: float,
	reach_meters: float,
	serve_origin: Vector2,
	landing_on_home_side: bool,
) -> float:
	## Distance to the nearest line the ball can go over, in metres. The two axes
	## are not the same scale, so neither are the two margins.
	var side_margin := minf(candidate.x, 1.0 - candidate.x) \
		* CourtConstants.COURT_WIDTH_METERS
	var end_margin := ((1.0 - candidate.y) if landing_on_home_side else candidate.y) \
		* CourtConstants.COURT_LENGTH_METERS
	var margin := minf(side_margin, end_margin)
	## The spread arrives on each axis at that axis' own scale; take the worse.
	var scatter := maxf(
		spread * CourtConstants.COURT_WIDTH_METERS,
		spread * 0.65 * CourtConstants.COURT_LENGTH_METERS,
	)
	var inside := clampf(
		margin / maxf(scatter * SERVE_SAFETY_SPREADS, 0.001), 0.0, 1.0
	)
	if reach_meters <= 0.0:
		return inside
	var carry := CoverageModel.court_distance_meters(serve_origin, candidate)
	return inside * clampf(
		(reach_meters - carry) / SERVE_CARRY_SLACK_METERS + 1.0, 0.0, 1.0
	)


## What this hitter puts on this ball.
##
## `hand_control` rather than `attack_accuracy` is the technique term, because
## the attribute glossary already defines it as "fine manipulation of height,
## spin, and touch" -- the rating that exists for exactly this and was read by
## nothing that struck a ball.
##
## The across-body strain comes from the swing record's own `offset_degrees`,
## which is how far the hitter had to turn off their approach. That is not a
## proxy for cutting across the ball, it *is* cutting across the ball, and it is
## already computed for every swing to price the shot's accuracy.
func _swing_spin(hitter: VolleyballPlayer, record: Dictionary) -> Dictionary:
	if hitter == null:
		return {}
	return BallSpin.from_swing(
		_rating(hitter, "attack_power"),
		_rating(hitter, "hand_control"),
		clampf(absf(float(record.get("offset_degrees", 0.0))) / 35.0, 0.0, 1.0),
		str(hitter.dominant_hand) != "Left",
	)


## And what this server does, which is a choice of shot rather than a by-product.
func _serve_spin(server: VolleyballPlayer) -> Dictionary:
	if server == null:
		return {}
	return BallSpin.from_serve(
		str(server.primary_serve_style),
		_rating(server, "serve_power"),
		_rating(server, "serve_technique"),
		str(server.dominant_hand) != "Left",
	)


## How far this server's ball travels before it lands, at the flat end of their
## repertoire. The ceiling and the angle are the geometric serve's own, so the
## floor a server cannot serve past here is the floor they cannot serve past
## there.
func _serve_carry_meters(server: VolleyballPlayer) -> float:
	var speed := GeometricAttackResolverModel.AttackPowerModel \
		.serve_ceiling_mps(_rating(server, "serve_power")) \
		* lerpf(0.82, 1.0, _rating(server, "serve_technique"))
	var flight: Dictionary = RallyKinematicsModel.BallFlightModel.solve_flight(
		speed, _serve_launch_angle_degrees(server, 0.6),
		GeometricAttackPromotionModel.serve_contact_height_meters(
			server,
			GeometricAttackPromotionModel.serve_effort_for_style(
				str(server.primary_serve_style)
			),
		),
	)
	return float(flight.range_meters)


## Where the passers stand when the ball is struck, for the side about to
## receive it. The same formation the reception resolves against.
##
## The passers only -- not all six. `serve_receive_formation` returns a position
## for every slot, including the setter and the front row parked at the net on
## their staging marks, and scoring against all six sends the serve away from
## people who were never going to pass it and into the corners. That cost 44
## reception and setter gates on the first run: a serve aimed at nobody is also a
## serve nobody receives.
func _receive_formation_positions(
	lineup: RotationLineup,
	players: Array,
	opponent_side: bool,
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if lineup == null:
		return positions
	var setter_slot := lineup.slot_for_player(lineup.active_setter_id())
	if setter_slot < 1:
		return positions
	var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])
	var passer_slots := CourtConstants.roster_serve_receive_passer_slots(
		lineup, players, passer_count
	)
	var formation := CourtConstants.serve_receive_formation(
		setter_slot, CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, -1,
		opponent_side, passer_slots,
	)
	for slot_number in passer_slots:
		if formation.has(slot_number):
			positions.append(Vector2(formation[slot_number]))
	return positions


## Where every voli on the receiving side stands to take a serve, by player id.
##
## **The formation was already being built and five sixths of it thrown away.**
## `_receive_formation_positions` above asks `CourtConstants` for the whole
## six-slot shape and then keeps only the passers, because all it needed was
## somewhere to aim the serve. Everyone else's position was computed, discarded,
## and then not drawn -- which is why serve receive publishes phase targets for
## 0 of 400 serves and a court of twelve stands still through the phase a viewer
## watches most closely.
##
## Nothing here is invented. It is the same call, kept whole.
## The six on court, where they actually are.
##
## Published on the reception event in place of a recomputed
## `_receive_formation_map`. The shape is seeded into `live_positions` at rally
## initialization now, so asking the formation builder again at reception time
## would be computing a second copy of state that already exists -- and it would
## be *wrong* for one voli, the receiver, who has since moved to the ball.
func _lineup_live_shape(lineup: RotationLineup, live: Dictionary) -> Dictionary:
	var shape := {}
	if lineup == null:
		return shape
	for slot_number in range(1, 7):
		var player_id := int(lineup.player_at_slot(slot_number))
		if live.has(player_id):
			shape[player_id] = Vector2(live[player_id])
	return shape


func _receive_formation_map(
	lineup: RotationLineup,
	players: Array,
	opponent_side: bool,
	## Filled with `{player_id: {intent, progress}}` when supplied.
	##
	## **Why a phase map has to say why.** `CourtConstants.serve_receive_formation`
	## already sorts the six into three kinds -- the passers it assigns to seams,
	## the front-row volis it stages off the passing lanes, and everybody else it
	## drops on the short-coverage mark -- and this function then flattens all
	## three into coordinates and forgets which was which. That distinction is
	## precisely `receiving` against `preparing_attack` against `covering`, so the
	## cognition layer would otherwise have to re-derive, from a position, a fact
	## the formation builder had already established.
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if lineup == null:
		return targets
	var setter_slot := lineup.slot_for_player(lineup.active_setter_id())
	if setter_slot < 1:
		return targets
	var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])
	var passer_slots := CourtConstants.roster_serve_receive_passer_slots(
		lineup, players, passer_count
	)
	var formation := CourtConstants.serve_receive_formation(
		setter_slot, CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, -1,
		opponent_side, passer_slots,
	)
	for slot_number in formation:
		var slot := int(slot_number)
		var player_id := int(lineup.player_at_slot(slot))
		if player_id < 0:
			continue
		targets[player_id] = Vector2(formation[slot_number])
		var intent := &"covering"
		if slot == setter_slot:
			intent = &"setting"
		elif passer_slots.has(slot):
			intent = &"receiving"
		elif CourtConstants.is_front_row_slot(slot):
			intent = &"preparing_attack"
		out_intents[player_id] = {"intent": intent, "progress": 0.0}
	return targets


## Where the four volis who are neither passing nor setting go while the pass is
## in the air.
##
## This is the leg the report was about: a shanked serve receive, and a court of
## twelve standing still watching it. They stood still because playback refuses
## to invent movement and the resolver had published an opinion about exactly two
## people -- the passer, and whoever was taking the second ball.
##
## Nothing here is new physics, and deliberately so. Each voli is given the
## target their phase already implies: a front-row voli releases to the approach
## mark `_approach_start_position` would put them on for the lane
## `_fallback_assignment` says is theirs, a back-row voli goes to base. Then
## `_reached_point` -- the same function that times every other journey in the
## game, and the same one that charges for it -- decides how much of that they
## actually cover in the time the pass is in the air. Most honest answers are
## "not all of it", which is the information a viewer needs.
##
## **The three people this must not touch are the three it already has an
## authority for**, and forgetting one of them is measurable. The receiver and
## the second contact are obvious. The hitter is not: their release to the
## approach mark is already staged on the SET event, and moving them here as well
## meant `ApproachMechanicsModel.prepare_for_attack` ran from a position the
## approach had already been walked to. It halved the leg without halving the
## time allotted for it, and the ATTACK phase's timing ratio went 1.0912 ->
## 1.2111 -- a phase the movement-timing gate asserts to two decimal places.
##
## The chase is the one judgement call, and it is derived rather than authored.
## `setter_arrival_margin` is the time the second contact has to spare; when that
## is gone, the pass is one nobody planned for, and the nearest other voli breaks
## for the ball. Whether they are *allowed* to play it is a separate question and
## is not answered here -- see `docs/design/OFF_BALL_MOVEMENT.md`, "Not in scope".
## What is answered is whether a shanked pass looks contested or conceded.
func _transition_phase_map(
	players: Array,
	lineup: RotationLineup,
	receiver_id: int,
	setter_id: int,
	hitter_id: int,
	set_contact: Vector2,
	window_seconds: float,
	setter_margin: float,
	## `{player_id: {intent, progress}}`, filled alongside the coordinates. The
	## three branches below are already the three intents; this stops the
	## cognition layer having to guess a reason back out of a position.
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if lineup == null or window_seconds <= 0.0:
		return targets
	var off_ball: Array[VolleyballPlayer] = []
	for entry in players:
		var player := entry as VolleyballPlayer
		if player == null or player.id == receiver_id or player.id == setter_id \
				or player.id == hitter_id:
			continue
		if lineup.slot_for_player(player.id) >= 1:
			off_ball.append(player)
	var chase_id := -1
	if setter_margin < CHASE_MARGIN_SECONDS:
		var closest := 1.0e9
		for player in off_ball:
			var from: Vector2 = live_positions.get(
				player.id,
				CourtConstants.slot_position(lineup.slot_for_player(player.id)),
			)
			var gap := RallyKinematics.court_distance_meters(from, set_contact)
			if gap < closest:
				closest = gap
				chase_id = player.id
	for player in off_ball:
		var slot := lineup.slot_for_player(player.id)
		var here: Vector2 = live_positions.get(
			player.id, CourtConstants.slot_position(slot)
		)
		var intent := set_contact
		var mode := "transition"
		if player.id != chase_id:
			if CourtConstants.is_front_row_slot(slot):
				intent = _approach_start_position(
					CourtConstants.lane_target(
						str(_fallback_assignment(player, lineup).lane)
					),
					here, false,
				)
			else:
				## Base, not the ball. A back-row voli who is not chasing is
				## shuffling into defensive position, which is a short move at
				## ordinary effort -- charging it as a sprint would bill four
				## volis a sprint every rally for standing about.
				intent = CourtConstants.slot_position(slot)
				mode = "lateral"
		var reached := _reached_point(player, here, intent, window_seconds, mode)
		targets[player.id] = reached
		out_intents[player.id] = _travel_intent(
			player,
			&"receiving" if player.id == chase_id \
				else (&"preparing_attack" if mode == "transition" else &"defending"),
			here, intent, reached, mode, window_seconds,
		)
		## The resolver has to believe what playback draws. Leaving these out of
		## `live_positions` would put the drawn court and the simulated court in
		## different places from the second contact onward, which is the defect
		## every staging comment in this file exists because of.
		live_positions[player.id] = reached
	return targets


## The same idea for the other side of the net, at the fidelity that side has.
##
## **This is deliberately coarser than `_transition_phase_map` and the difference
## is worth stating rather than hiding.** The home five are sent to approach
## marks because the home offence has already named a lane and a tempo by the
## time that map is written. Here the hitter is not chosen until eighty lines
## below, so each opponent is sent to their own model's transition base --
## `court_position(id, "transition")`, which is that team's own opinion about
## where the player stands in transition and not a number invented here. It is a
## smaller movement than the home side's and it is honest about being one.
##
## The chase is the same, and is the half that matters: when the second contact
## has no time to spare, the nearest other voli goes too.
func _opponent_transition_phase_map(
	opponent_team: Resource,
	first_contact_id: int,
	setter_id: int,
	set_contact: Vector2,
	window_seconds: float,
	setter_margin: float,
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if opponent_team == null or window_seconds <= 0.0:
		return targets
	var off_ball: Array[VolleyballPlayer] = []
	for entry in opponent_team.on_court_players():
		var player := entry as VolleyballPlayer
		if player == null or player.id == first_contact_id or player.id == setter_id:
			continue
		off_ball.append(player)
	var chase_id := -1
	if setter_margin < CHASE_MARGIN_SECONDS:
		var closest := 1.0e9
		for player in off_ball:
			var from: Vector2 = opponent_live_positions.get(
				player.id, opponent_team.court_position(player.id, "transition")
			)
			var gap := RallyKinematics.court_distance_meters(from, set_contact)
			if gap < closest:
				closest = gap
				chase_id = player.id
	for player in off_ball:
		var here: Vector2 = opponent_live_positions.get(
			player.id, opponent_team.court_position(player.id, "transition")
		)
		var intent := set_contact if player.id == chase_id \
			else Vector2(opponent_team.court_position(player.id, "transition"))
		var reached := _reached_point(
			player, here, intent, window_seconds,
			"transition" if player.id == chase_id else "lateral",
		)
		targets[player.id] = reached
		out_intents[player.id] = _travel_intent(
			player,
			&"receiving" if player.id == chase_id else &"defending",
			here, intent, reached,
			"transition" if player.id == chase_id else "lateral",
			window_seconds,
		)
		opponent_live_positions[player.id] = reached
	return targets


## Where the attacking side goes while their own spike is in the air.
##
## **The intentions were already written down and never read.** Every
## `DefensiveAssignment` carries an `attack_coverage_responsibility` -- one of
## *cover nearest attacker*, *cover assigned hitter*, *take second contact* or
## *release for transition* -- and until now the only thing that read it was
## `_resolve_attack_coverage`, to pick the single voli who plays a recycled ball.
## The other four had a stated intention and nowhere to stand.
##
## So nothing is invented here either. Each voli goes where their own
## responsibility means, and `_reached_point` decides how much of it they cover.
## An attack flight is short -- often under a quarter of a second -- so most of
## these answers are "barely moved", which is the correct picture: cover is a
## collapse you commit to before the ball is struck, and a viewer should see who
## committed and who released.
##
## `release_for_transition` is the interesting one, and it is why this reads as
## volleyball rather than as everyone converging: the voli the tactic told to
## leave goes the *other* way, off the net, to be available to swing next.
func _cover_phase_map(
	players: Array,
	lineup: RotationLineup,
	defensive_plan: Resource,
	hitter_id: int,
	contact: Vector2,
	window_seconds: float,
	opponent_side: bool,
	## The reason each voli went where they went. `attack_coverage_responsibility`
	## is *already* a stated intention -- it is the one place in the tactic sheet
	## where a voli is told what to do when a ball is struck -- and until this
	## parameter existed it was read, turned into a coordinate, and dropped.
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if lineup == null or window_seconds <= 0.0:
		return targets
	## Two rings behind the hitter, on their own side of the net. Tight cover
	## takes the ball that drops straight off the block; the deeper ring takes
	## the one that comes back with pace.
	var tight_depth := 0.60 if not opponent_side else 0.40
	var deep_depth := 0.72 if not opponent_side else 0.28
	var base_depth := 0.84 if not opponent_side else 0.16
	## Looked up here rather than through `_player_by_id`, which is typed
	## `Array[VolleyballPlayer]` -- the opponent's roster arrives as
	## `Array[Resource]` from `on_court_players()`, and one shared function
	## serving both sides is the point of this map existing once.
	var by_id := {}
	for entry in players:
		var candidate := entry as VolleyballPlayer
		if candidate != null:
			by_id[candidate.id] = candidate
	var tight_taken := false
	for slot_number in range(1, 7):
		var player := by_id.get(
			int(lineup.player_at_slot(slot_number)), null
		) as VolleyballPlayer
		if player == null or player.id == hitter_id:
			continue
		var here: Vector2 = (
			opponent_live_positions if opponent_side else live_positions
		).get(player.id, CourtConstants.slot_position(slot_number))
		var assignment: Resource = defensive_plan.assignment_for(player.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.attack_coverage_responsibility) \
			if assignment != null else "Cover nearest attacker"
		var intent := here
		var mode := "lateral"
		match responsibility:
			"Release for transition":
				## Off the net, not toward it. This voli is preparing to hit.
				intent = Vector2(
					CourtConstants.slot_position(slot_number).x, base_depth
				)
				mode = "transition"
			"Take second contact":
				intent = Vector2(0.50, tight_depth)
			_:
				## The first voli to claim it takes the tight ring, everyone else
				## fills the deeper one -- so two people do not stand on the same
				## square metre behind the hitter.
				intent = Vector2(
					clampf(contact.x + (0.0 if not tight_taken else 0.16), 0.06, 0.94),
					tight_depth if not tight_taken else deep_depth,
				)
				tight_taken = true
				mode = "transition"
		var reached := _reached_point(player, here, intent, window_seconds, mode)
		targets[player.id] = reached
		var cue_intent := &"covering"
		match responsibility:
			"Release for transition":
				cue_intent = &"preparing_attack"
			"Take second contact":
				cue_intent = &"setting"
		out_intents[player.id] = _travel_intent(
			player, cue_intent, here, intent, reached, mode, window_seconds
		)
		if opponent_side:
			opponent_live_positions[player.id] = reached
		else:
			live_positions[player.id] = reached
	return targets


## How much of an intended journey a voli actually covered, 0 to 1.
##
## The progress a cogniticon fills with, and it is deliberately *distance
## covered* rather than any judgement about whether covering it was enough. A
## voli who commits to a cover mark and gets a third of the way there fills a
## third of their glyph; whether a third was sufficient is the rally's business
## and not the icon's. See `PlayerCognitionCue.progress`.
##
## A journey of no length is complete by definition -- a voli already standing on
## their mark has nothing left to do, and reporting that as zero progress would
## draw an empty glyph on the one voli who is entirely ready.
## One intent for a whole published map, where the map is already one idea.
##
## `_floor_phase_positions` places a defensive shape and the wall staging places
## a wall -- neither has a per-voli branch to preserve, so they do not need the
## `out_intents` treatment the travel maps got. They need saying out loud, which
## is different and cheaper.
##
## Progress is deliberately absent: these are placements rather than journeys,
## and a progress bar on a voli who was simply put somewhere would be a number
## with nothing behind it.
## A defensive shape's intents: the journeys that were taken, over a `defending`
## stamp for anyone the shape placed without one.
##
## Two different facts wearing one name is what `_uniform_intents` was becoming
## here. A voli walked into their zone has a traversal and an arrival; a voli the
## wall staging put on the net does not, because a different path owns their
## movement. Overlaying keeps both honest rather than averaging them into a
## progress bar with nothing behind it.
static func _defensive_intents(
	targets: Dictionary, journeys: Dictionary
) -> Dictionary:
	var intents := _uniform_intents(targets, &"defending")
	for raw_player_id in journeys:
		intents[int(raw_player_id)] = journeys[raw_player_id]
	return intents


static func _uniform_intents(targets: Dictionary, intent: StringName) -> Dictionary:
	var intents := {}
	for player_id in targets:
		intents[int(player_id)] = {"intent": intent, "progress": 0.0}
	return intents


## Where the side that just served goes while their own serve is in the air.
##
## **They were going nowhere, because nothing published them.** The receive
## formation covers the six receiving; the other six -- the team that struck the
## ball -- had no phase map on this leg at all, so the half of the court that
## just served stood still through the phase a viewer watches most closely.
## Measured before this existed, a serve's flight moved 2.50 volis of twelve and
## most of that was the passer adjusting.
##
## What they do is not invented either: after a serve you take base defence, and
## `_floor_phase_positions` is the side's own defensive shape. The attack
## coordinate is centre because nobody has set yet -- the shape a team takes
## before they know where the ball is going is exactly the neutral one -- and no
## blocker is named for the same reason.
##
## The server is included deliberately. They strike from behind the baseline and
## have to walk in, and that walk is the single most visible piece of movement on
## the leg.
## The floor closing toward where the ball actually went.
##
## **The one leg that published targets and moved nobody.** The defensive shape
## is computed once, applied on the opponent's attack event, and then republished
## verbatim on the block and on the dig -- so by the time the ball comes off the
## block every defender is already standing on their target and the flight from
## the block to the dig moved 0.00 metres across 329 legs. A phase map whose
## positions are already occupied is a knob that cannot reach its own range.
##
## A block touch changes where the ball is going, and the floor answers it. Not
## by converging on the ball -- five defenders piling onto one dig is not
## volleyball -- but by leaning toward the new line, which is what closing a seam
## looks like. The lean is capped so the shape stays a shape.
##
## The defender playing it is excluded; they already carry their own
## `movement_target`, and moving them twice is the defect the hitter taught.
const DEFLECTION_LEAN: float = 0.28

## The blocking side going after a ball that came off their own hands.
##
## **A tool is not a ball nobody may touch.** Three geometric outcomes end at the
## net in the hitter's favour -- through the hands, off the hands and out, and
## placed off them deliberately -- and all three claimed the point before the
## recycle branch could see them, so the defending six stood still while a ball
## they had just touched dropped. That is wrong on the rules as well as on the
## screen: the deflection is the *blocking* team's contact, they have two touches
## left, and a ball is not out until it lands, so chasing it past the sideline is
## an ordinary play rather than an impossible one.
##
## What this publishes is the chase. Whether the chase can ever *save* the point
## is a separate question with a separate cost -- a ball played from outside the
## court arrives at a set and an attack whose geometry assumes an in-court
## origin -- so this reports the arrival margin rather than acting on it, and the
## conversion waits on a measurement of how often it would fire.
##
## The blockers themselves are excluded. They are at the net with their hands
## above it and the ball has gone behind them; the people who chase are the ones
## already facing the right way.
func _tool_pursuit_map(
	players: Array,
	lineup: RotationLineup,
	landing: Vector2,
	window_seconds: float,
	exclude_ids: Array,
	opponent_side: bool,
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if lineup == null or window_seconds <= 0.0:
		return targets
	var by_id := {}
	for entry in players:
		var candidate := entry as VolleyballPlayer
		if candidate != null:
			by_id[candidate.id] = candidate
	var live: Dictionary = opponent_live_positions if opponent_side else live_positions
	var chaser: VolleyballPlayer = null
	var chaser_gap := 1.0e9
	for slot_number in range(1, 7):
		var player := by_id.get(int(lineup.player_at_slot(slot_number)), null) \
			as VolleyballPlayer
		if player == null or exclude_ids.has(player.id):
			continue
		var from: Vector2 = live.get(player.id, CourtConstants.slot_position(slot_number))
		var gap := RallyKinematics.court_distance_meters(from, landing)
		if gap < chaser_gap:
			chaser_gap = gap
			chaser = player
	if chaser == null:
		return targets
	var here: Vector2 = live.get(chaser.id, landing)
	var reached := _reached_point(chaser, here, landing, window_seconds, "transition")
	targets[chaser.id] = reached
	out_intents[chaser.id] = _travel_intent(
		chaser, &"defending", here, landing, reached, "transition", window_seconds
	)
	live[chaser.id] = reached
	return targets


func _deflection_adjust_map(
	floor_positions: Dictionary,
	dig_position: Vector2,
	defender_id: int,
	window_seconds: float,
	opponent_side: bool,
	players_by_id: Dictionary,
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if window_seconds <= 0.0:
		return targets
	var live: Dictionary = opponent_live_positions if opponent_side else live_positions
	for raw_player_id in floor_positions:
		var player_id := int(raw_player_id)
		if player_id == defender_id:
			continue
		var player := players_by_id.get(player_id, null) as VolleyballPlayer
		if player == null:
			continue
		var here: Vector2 = live.get(player_id, Vector2(floor_positions[raw_player_id]))
		var intended := here.lerp(dig_position, DEFLECTION_LEAN)
		var reached := _reached_point(player, here, intended, window_seconds, "lateral")
		targets[player_id] = reached
		out_intents[player_id] = _travel_intent(
			player, &"defending", here, intended, reached, "lateral", window_seconds
		)
		live[player_id] = reached
	return targets


func _serve_transition_map(
	lineup: RotationLineup,
	defensive_plan: Resource,
	opponent_side: bool,
	window_seconds: float,
	players_by_id: Dictionary,
	out_intents: Dictionary = {},
) -> Dictionary:
	var targets := {}
	if lineup == null or window_seconds <= 0.0:
		return targets
	var shape := _floor_phase_positions(
		lineup, defensive_plan, 0.5, -1, -1, opponent_side
	)
	var live: Dictionary = opponent_live_positions if opponent_side else live_positions
	for raw_player_id in shape:
		var player_id := int(raw_player_id)
		var player := players_by_id.get(player_id, null) as VolleyballPlayer
		if player == null:
			continue
		var intended := Vector2(shape[raw_player_id])
		var here: Vector2 = live.get(player_id, intended)
		## Lateral, not a sprint. Taking base after your own serve is a jog at
		## most, and charging it as a sprint would bill six volis a sprint every
		## single rally -- which the fatigue model would then faithfully believe.
		var reached := _reached_point(player, here, intended, window_seconds, "lateral")
		targets[player_id] = reached
		out_intents[player_id] = _travel_intent(
			player, &"defending", here, intended, reached, "lateral", window_seconds
		)
		live[player_id] = reached
	return targets


func _travel_fraction(from: Vector2, intended: Vector2, reached: Vector2) -> float:
	var asked := RallyKinematics.court_distance_meters(from, intended)
	if asked <= 0.01:
		return 1.0
	return clampf(
		RallyKinematics.court_distance_meters(from, reached) / asked, 0.0, 1.0
	)


## One off-ball journey, published with **when it ended** and not only where.
##
## M7 / C6. Every phase map in this file published a destination and a fraction
## covered, and nothing at all about time. So a voli who crossed two metres in
## 0.31 s of a 1.14 s window and then stood waiting was indistinguishable, in
## everything downstream, from one who spent the whole window walking -- and
## playback, given a start, an end and a window, draws the second. The C0 census
## counted it: **0 of 8,125** placed volis carried a duration.
##
## The resolver has always known the answer. `_reached_point` computes
## `_movement_time` to decide whether the target is reachable at all, then throws
## the number away and returns a position. Asking the same authority for the time
## to where the voli *actually got* costs one more call and invents nothing: no
## new speed, no new relation, no window-filling.
##
## `traversal_seconds` is the journey. `window_seconds` is how long the ball gave
## them. A voli with `traversal < window` arrived early and the remainder is
## theirs to stand in, which is the physical fact C6 asks for -- stated here so
## that anything drawing them has it, rather than left for presentation to
## assume. `arrival_progress` is that ratio precomputed, because "did they arrive
## early" is the question every consumer actually has and deriving it from two
## fields is where an off-by-one lives.
##
## A journey that was cut short comes back with `traversal == window`, by
## construction: `_reached_point` bisects to exactly the point the window buys,
## so the time to that point is the window. That is correct and not a special
## case -- a voli who ran out of time did not arrive early.
func _travel_intent(
	mover: VolleyballPlayer,
	intent: StringName,
	from: Vector2,
	intended: Vector2,
	reached: Vector2,
	mode: String,
	window_seconds: float,
) -> Dictionary:
	var traversal := 0.0
	if mover != null:
		traversal = minf(
			_movement_time(mover, from, reached, mode), maxf(window_seconds, 0.0)
		)
	return {
		"intent": intent,
		"progress": _travel_fraction(from, intended, reached),
		"traversal_seconds": traversal,
		"window_seconds": maxf(window_seconds, 0.0),
		"arrival_progress": clampf(
			traversal / maxf(window_seconds, 0.0001), 0.0, 1.0
		),
	}


func _weak_passer_target(
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	if lineup != null and not home_players.is_empty():
		var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
			CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
		]["passer_count"])
		var passer_slots := CourtConstants.roster_serve_receive_passer_slots(
			lineup, home_players, passer_count
		)
		var formation := CourtConstants.serve_receive_formation(
			lineup.slot_for_player(lineup.active_setter_id()),
			CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION,
			-1, not landing_on_home_side, passer_slots,
		)
		var weakest_slot := -1
		var weakest_score := INF
		for slot_number in passer_slots:
			var candidate: VolleyballPlayer = null
			var candidate_id := int(lineup.player_at_slot(slot_number))
			for raw_player in home_players:
				var roster_player := raw_player as VolleyballPlayer
				if roster_player != null and roster_player.id == candidate_id:
					candidate = roster_player
					break
			if candidate == null:
				continue
			var score := _reception_skill(candidate)
			if score < weakest_score:
				weakest_score = score
				weakest_slot = slot_number
		if weakest_slot >= 1 and formation.has(weakest_slot):
			return Vector2(formation[weakest_slot])
	return Vector2(0.22, 0.84) if landing_on_home_side else Vector2(0.78, 0.16)


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
##
## **Kept, and no longer the input to the set's flight.** A launch angle is the
## wrong free variable for a set and it took a physical solve to see why. A set
## has to *rise* about a metre from the setter's hands into the hitter's, and at
## the shallow angles this table calls a quick -- six to ten degrees -- the only
## ball that climbs a metre over four metres of court is one hit at 26 m/s. The
## solver said so, honestly, and the drawn quick came out at 0.16 s. A coach does
## not describe a set by its launch angle in any case; they describe it by how
## high it goes, which is what `_set_apex_meters` below now supplies.
##
## This still feeds `path_length_factor` and the signature the reception carries,
## which want an angle and are unaffected by the change.
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


## How high a set goes above the hands that will hit it, by tempo.
##
## The set's real free variable, and the one every coach and every player already
## uses: a first-tempo quick is delivered flat to a hitter already in the air, a
## high ball climbs two metres above them to buy the outside every fraction of a
## second it can. Everything else about the flight -- its speed, its hang time,
## the window the hitter runs in -- falls out of this and the two contact heights,
## through `BallFlightModel.duration_for_apex`.
##
## Stated as clearance *above the hitter's contact* rather than as an absolute
## height, because that is the quantity that stays meaningful when the hitter
## changes. A 1.72 m setter feeding a 2.06 m opposite and the same setter feeding
## a 1.85 m libero on an overpass are putting the ball in very different places
## above the floor and the same place above the hands.
const SET_CLEARANCE_BY_TEMPO: Array[float] = [0.15, 0.60, 1.30, 2.20]
## What a setter's touch is worth: a good one delivers the tempo that was called,
## a poor one drifts toward the safe high ball nobody asked for.
const SET_CLEARANCE_DRIFT: float = 0.55


func _set_apex_meters(
	setter: VolleyballPlayer,
	tempo: int,
	set_quality: float,
	hitter_contact_height_meters: float,
	rescue_height_meters: float = 0.0,
) -> float:
	var clearance := SET_CLEARANCE_BY_TEMPO[clampi(tempo, 0, 3)]
	## A miss goes up, never down. Under-setting a quick puts the ball below the
	## hitter's hands, which is not a lower set -- it is a ball nobody can hit,
	## and the set quality this same contact produced is where that is already
	## priced.
	var touch := (_rating(setter, "tempo_control") + _rating(setter, "hand_control")) * 0.5
	var drift := SET_CLEARANCE_DRIFT * (1.0 - clampf(touch, 0.0, 1.0)) \
		* (1.0 - clampf(set_quality, 0.0, 1.0))
	return hitter_contact_height_meters + clearance + drift \
		+ maxf(rescue_height_meters, 0.0)


## The flight of a set, timed by how high it was put up.
##
## Behind `ENABLE_SET_HEIGHT_TIMING`, which is now on after the approach and
## floor-defense calibration recorded beside the flag. Real hang times are about
## triple the legacy launch-angle times, so this must not be toggled independently
## of the timing and balance gates named there.
## The ball has to be up there, and you have to have got there in time.
##
## Every set in this game was a standing set. `set_contact_height_meters` takes
## a `jumping` flag, `JUMP_SET_EFFORT` prices the hop, `SetterCapability` prices
## the penalty and `shadow_setter_response_system` lists `jump_set` as an
## option -- and the live path called the function with the default and never
## asked. That made the pass apex inert too: contact was
## `min(pass_apex, standing_reach * 0.97)` and the reach was always the smaller,
## so a 3.16 m pass and a 2.42 m pass were played from exactly the same height.
## Measured over 1,052 passes, apex ran 2.42-3.31 m and *every* one of them was
## truncated to the setter's standing hands.
##
## Three conditions, and the point is that they can each fail alone:
##
## - **The ball got high enough.** You cannot jump to meet a ball that never
##   rose to where you would be. A pass below the standing release is played
##   underhand and this is what says so.
## - **There was time to load.** Measured, the budget between the pass being
##   played and the ball leaving the hands runs p05 1.12 s to p95 2.64 s about a
##   1.67 s median -- so a rushed setter is common rather than exotic, and the
##   hop is the first thing they lose.
## - **The body can do it under pressure.** Balance and stability, not leap:
##   a setter jumping is not trying to get high, they are trying to arrive
##   square and release from a moving platform.
const JUMP_SET_LOAD_SECONDS: float = 0.34
const JUMP_SET_COMPOSURE_FLOOR: float = 0.30
## The fastest a setter can still be travelling and plant a stable jump, in
## metres per second.
##
## About a brisk walk. Above it the body is being carried into the ball and the
## hop becomes a forward leap, which is the thing a jump set is not -- the whole
## value of leaving the floor is releasing from a platform that is not moving.
##
## Unmeasured, and named as such: nothing has published a setter's closing speed
## at the moment of contact, so this is a starting value and the probe comes
## before the tuning. It is deliberately generous rather than strict, because a
## rule that refuses every jump is indistinguishable from not having one.
const JUMP_SET_STABLE_APPROACH_MPS: float = 1.9


func _jump_set_decision(
	setter: VolleyballPlayer,
	pass_apex_meters: float,
	arrival_margin: float,
	## How far the setter still had to travel to the ball, in metres, and how
	## long they had to do it in.
	##
	## **A jump you have to travel into is not a jump set, it is a lunge.** The
	## first cut asked only whether there was time to load, which admits a setter
	## sprinting into the ball and leaping forward off the last stride -- and a
	## setter in that position may as well stay down, because the whole value of
	## the hop is releasing from a stable platform above the hands. Time alone
	## cannot express it: a long run finished early and a short run finished
	## early look identical to a margin.
	travel_meters: float = 0.0,
	travel_seconds: float = 0.0,
) -> Dictionary:
	if setter == null:
		return {"jumping": false, "reason": "no setter", "closing_speed_mps": 0.0}
	## What they are still carrying when they get there. A body arriving at speed
	## plants forward; a body that arrived and stopped plants under itself.
	##
	## **Returned, because `JUMP_SET_STABLE_APPROACH_MPS` calls itself unmeasured
	## and nothing published the quantity it acts on.** A threshold whose
	## distribution has never been seen is the failure `FAILURE_MODES.md` §0
	## names; this is the half that makes it auditable from the rally record
	## rather than only from a fixture.
	var closing_speed := travel_meters / maxf(travel_seconds, 0.01) \
		if travel_meters > 0.0 and travel_seconds > 0.0 else 0.0
	var standing := GeometricAttackPromotionModel.set_contact_height_meters(setter)
	var airborne := GeometricAttackPromotionModel.set_contact_height_meters(
		setter, true
	)
	var poise := (_rating(setter, "set_balance") + _rating(setter, "set_stability")) \
		* 0.5
	## A high pass with a rushed setter and a low pass with all the time in the
	## world both come out standing, and they are different failures. Named so
	## the probe can tell them apart before anything here is tuned.
	if pass_apex_meters < standing:
		return {
			"jumping": false, "reason": "under the hands",
			"standing_height": standing, "airborne_height": airborne,
			"closing_speed_mps": closing_speed,
		}
	if arrival_margin < JUMP_SET_LOAD_SECONDS:
		return {
			"jumping": false, "reason": "no time to load",
			"standing_height": standing, "airborne_height": airborne,
			"closing_speed_mps": closing_speed,
		}
	## Still moving when the ball arrives. The margin can be generous and the
	## approach still be wrong: a setter who covered six metres and got there
	## with time to spare is travelling when they plant, and jumping off that is
	## a leap forward rather than a set.
	if closing_speed > JUMP_SET_STABLE_APPROACH_MPS:
		return {
			"jumping": false, "reason": "arriving too fast to plant",
			"standing_height": standing, "airborne_height": airborne,
			"closing_speed_mps": closing_speed,
		}
	if poise < JUMP_SET_COMPOSURE_FLOOR:
		return {
			"jumping": false, "reason": "cannot release off the floor",
			"standing_height": standing, "airborne_height": airborne,
			"closing_speed_mps": closing_speed,
		}
	return {
		"jumping": true, "reason": "jump set",
		"standing_height": standing, "airborne_height": airborne,
		"closing_speed_mps": closing_speed,
	}


## What a set's pace comes from, as a multiple of the baseline.
##
## Two halves, and the geometric one is already free: `_set_arc` solves the
## flight from the release height, so a higher contact flattens the parabola to
## the same destination without anything here asking it to. What is missing is
## the kinetic half -- the jump puts the body's momentum into the ball, and a
## setter who stays on the floor has to find the same pace out of the arm alone.
##
## So a standing set is not merely lower, it is *slower unless the arm is
## strong*. `arm_speed` is the nearest thing this engine has to arm strength and
## it is already generated, rated and trained; adding an eighth attribute for
## the one contact that needs it would be a worse answer than reading the one
## that already means "how hard this body can move a ball with the arm".
##
## Centred so an ordinary arm standing is 1.0 and the jump is the bonus, rather
## than penalising every standing set and calling the jump neutral.
const JUMP_SET_PACE_BONUS: float = 0.12
const STANDING_SET_ARM_SWING: float = 0.16


func _set_pace_scale(setter: VolleyballPlayer, jumping: bool) -> float:
	if setter == null:
		return 1.0
	if jumping:
		return 1.0 + JUMP_SET_PACE_BONUS
	return 1.0 + (_rating(setter, "arm_speed") - 0.5) * 2.0 * STANDING_SET_ARM_SWING


func _set_arc(
	setter: VolleyballPlayer,
	tempo: int,
	set_quality: float,
	release_height_meters: float,
	hitter_contact_height_meters: float,
	distance_meters: float,
	rescue_height_meters: float = 0.0,
) -> Dictionary:
	var angle := _set_launch_angle_degrees(setter, tempo, set_quality)
	if not RallyFeatureFlagsModel.ENABLE_SET_HEIGHT_TIMING:
		var level := RallyKinematics.solve_launch_arc(distance_meters, angle)
		level["apex_absolute_meters"] = release_height_meters \
			+ float(level.apex_height_meters)
		## The two heights this arc was solved between, returned rather than
		## consumed. See the note on the timed branch below; the same reasoning
		## applies here, where `solve_launch_arc` is a ground-to-ground solver and
		## the release height is the only absolute either end has.
		level["release_height_meters"] = release_height_meters
		level["arrival_height_meters"] = hitter_contact_height_meters
		return level
	var apex := _set_apex_meters(
		setter, tempo, set_quality, hitter_contact_height_meters,
		rescue_height_meters,
	)
	return {
		"duration_seconds": BallFlightModel.duration_for_apex(
			release_height_meters, hitter_contact_height_meters, apex
		),
		"apex_height_meters": maxf(apex - release_height_meters, 0.0),
		"apex_absolute_meters": apex,
		"launch_angle_degrees": angle,
		## **Where this ball starts and where it arrives, in absolute metres.**
		##
		## `duration_for_apex` is solved *between* these two and then neither left
		## the function, so every set published a trajectory carrying
		## `BallTrajectory`'s 1.0 m default at both ends -- measured at 159 of 159
		## set flights, `height_source == "default"`. The set is the seam where
		## the chain breaks: it consumes a reception flight whose heights are
		## resolved and hands the attack one that has forgotten them, so every
		## family downstream reads a body proxy for want of a number that was in
		## scope here all along. See
		## `docs/review/contact_authority/BEFORE_contact_authority_census.txt`.
		##
		## Not a second opinion about where the ball goes: the duration above is
		## the time to fall from `apex` to `arrival_height_meters`, so a flight
		## drawn to any other far end disagrees with its own length.
		"release_height_meters": release_height_meters,
		"arrival_height_meters": hitter_contact_height_meters,
	}


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
	if opponent_team == null or opponent_team.current_lineup() == null:
		return {"players": passers, "zones": zones}
	var lineup: RotationLineup = opponent_team.current_lineup()
	var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])
	var passer_slots := CourtConstants.roster_serve_receive_passer_slots(
		lineup, opponent_team.players, passer_count
	)
	var formation := CourtConstants.serve_receive_formation(
		lineup.slot_for_player(lineup.active_setter_id()),
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, -1, true, passer_slots,
	)
	for slot_number in passer_slots:
		var player := opponent_team.player_at_slot(slot_number) as VolleyballPlayer
		if player == null:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player.id
		zone.zone_type = DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		zone.radius_meters = 3.2
		zone.priority = 2
		zone.center = Vector2(formation.get(
			slot_number, opponent_team.court_position(player.id, "serve_receive")
		))
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
	## **Two clocks, and work rate fights both.** `effective_fatigue` is the match
	## clock read through this player's willingness to keep working; the winded
	## term is the rally clock, and it only touches the same range attributes the
	## `laboured` stage does, because a blown player reads the play exactly as
	## well as they did thirty seconds ago and simply cannot get there.
	var work_rate := float(player.work_rate) / 100.0
	var scale := FatigueModel.attribute_scale(
		FatigueModel.effective_fatigue(player.fatigue, work_rate), property_name
	)
	if FatigueModel.is_range_attribute(property_name):
		scale *= FatigueModel.winded_scale(_winded_fraction(player), work_rate)
	return clampf(
		raw_rating * scale * player.confidence_execution_scale() \
			+ player.current_form * 0.06,
		0.05, 1.0,
	)


func _power_rating(player: VolleyballPlayer, property_name: String) -> float:
	if property_name == "attack_power":
		## Power is a range quality even though its name is not on the list: it is
		## bought with the approach and the jump, both of which the laboured stage
		## takes. A tired hitter who still picks the right shot and cannot hit it
		## hard is the same player as the one who still reads the ball and cannot
		## reach it.
		var work_rate := float(player.work_rate) / 100.0
		var effective := FatigueModel.effective_fatigue(player.fatigue, work_rate)
		return clampf(float(player.usable_attack_power()) / 100.0 \
			* FatigueModel.broad_scale(effective) \
			* FatigueModel.range_scale(effective) \
			* FatigueModel.winded_scale(_winded_fraction(player), work_rate) \
			* player.confidence_execution_scale() \
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
