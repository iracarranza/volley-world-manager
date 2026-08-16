class_name AttackPowerModel
extends RefCounted

## How hard a hitter decides to swing.
##
## Power is a choice, made the same way a course is: the hitter asks how hard
## they can reasonably hit *here*, and answers with their own temperament. It is
## not a property of the shot type -- a cut shot can be driven or floated, and
## the old `attack_type` table could not say so because it bundled power and
## angle onto one axis.
##
## Three drivers, each producing a different, nameable failure:
##
## - **decision making** judges how much power the intent actually needs. A good
##   reader hits with just enough to push the ball to the endline; a poor one
##   misjudges it in either direction.
## - **aggression** biases the choice upward. A hitter who backs themselves
##   swings big more often than the situation calls for, and sails long.
## - **composure**, against the block in front of them, biases it downward. A
##   hitter who does not fancy it decelerates into the wall and leaves the ball
##   sitting up.
##
## The point of separating them is that over-hitting and under-hitting are
## *different mistakes made by different players*, where a single quality roll
## produces both indistinguishably.
##
## Pure and deterministic. Judgment error arrives as a caller-supplied value
## rather than drawn here, so seeded replay stays the simulator's business.
##
## `aggression` is `VolleyballPlayer.aggression` on a 0-1 scale -- see
## `aggression_from()`, which folds in the team's instruction, because how much
## a hitter wants to end the rally and how much the bench has told them to are
## different things that both move the same dial.
##
## It read `ego` until the two were separated. Every word in this file already
## said aggression: over-hitting, backing the swing, going for the terminal
## ball. Ego is how hard a decision is to *change*, which this model never asks.

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

## Ball speed a hitter can generate, from no attacking power to elite. The top
## of this is a hard-driven international spike; the bottom is a player who
## cannot put anything on it.
##
## **Raised from 16-30 because the ceiling is not what the ball gets.** Measured
## over 340 uncontested spikes, the median left the hand at 12.6 m/s -- against
## 25-37 for a real one, and against 7.7 for a set and 8.1 for a bump. A spike
## was 1.6 times the pace of a set, which is the mechanical reason it read as
## slow, and a deep one took 0.800 s to reach the floor.
##
## The ceiling was never the problem on its own: `available_ceiling_mps` spends
## it through an approach factor and an across-body factor, and `choose_power`
## then takes a fraction of what is left, so four multipliers around 0.8 each
## compounded 30 m/s down to 12.6. Both of those floors were lifted with this,
## because raising only the top of the range would have been a knob that cannot
## reach its own stated value.
##
## **Raised a second time, by a fifth, and the reason is the same one.** After the
## first raise the drawn median was 14.4 m/s over 525 attacks and 15.6 over 400
## serves -- still against the 25-37 this comment cites for a real spike, because
## the compounding discounts below eat most of what the ceiling grants. Both ends
## move together again, and both attacks and serves move with them: the serve's
## pace comes through `available_ceiling_mps` too, with `serve_power` in place of
## `attack_power`, so this is one constant for the pair.
##
## Stated as an outcome rather than an input, because the input has been raised
## before and the outcome barely followed: the contract is that the *drawn*
## medians rise about a fifth, and `tools/` measures them.
const CEILING_MIN_MPS: float = 28.8
const CEILING_MAX_MPS: float = 50.4

## And the serve's own, which is deliberately *not* the attack's.
##
## **A serve cannot be made faster by raising this, and pushing it tries to make
## the serve worse.** Both used to share the constants above. Raising those by a
## fifth moved the drawn attack median 14.4 -> 16.7 m/s and left the drawn serve
## median exactly where it was, because the serve's relief sweep takes pace off
## until the ball both clears the tape and lands in -- so the extra was granted
## and immediately spent. (That sweep lived in `rally_simulator._serve_arc` when
## this was measured; it is now `GeometricAttackResolver._serve_launch`, and its
## floor is derived rather than the 0.55 it was then.) Worse, at the higher figure *both* a timid and an
## aggressive serve exceeded what the geometry could deliver and were relieved to
## the same feasible ball, which collapsed the distinction
## `_test_the_serve_flies_the_same_ball_as_the_spike` exists to hold: risk has to
## arrive at the ball as speed, and it stopped doing so.
##
## The two shots have genuinely different envelopes. A spike is struck downward
## from above the tape over about seven metres; a serve is struck from nine
## metres behind the baseline over seventeen, and has to clear a net in between.
## Sharing one ceiling only ever worked while neither was near its limit.
##
## Held at the pre-raise values, which the relief loop can still deliver. Making
## serves genuinely faster is a spin problem rather than a power one -- a
## topspin ball falls harder than gravity and can therefore be launched faster
## and still drop in, which is what `GeometricAttackResolver._serve_launch`
## already documents.
const SERVE_CEILING_MIN_MPS: float = 24.0
const SERVE_CEILING_MAX_MPS: float = 42.0


## The ceiling for a serve, which shares this function's shape and not its
## constants.
static func serve_ceiling_mps(serve_power_rating: float) -> float:
	return lerpf(
		SERVE_CEILING_MIN_MPS, SERVE_CEILING_MAX_MPS,
		clampf(serve_power_rating, 0.0, 1.0),
	)

## The reference angle a driven attack is struck at. Used to price "how much
## power does it take to reach that far" -- a flatter ball needs more.
const DRIVEN_REFERENCE_ANGLE_DEGREES: float = -15.0

## How far temperament moves the choice, as a fraction of the required power.
## An aggressive hitter over-swings by up to a fifth; a hitter with no composure
## loses up to a quarter of their swing to a fully formed block. Provisional --
## Gate D calibrates them.
const AGGRESSION_BIAS: float = 0.20
const INTIMIDATION_BIAS: float = 0.25
## How badly a poor reader misjudges the power an intent needs.
const JUDGMENT_ERROR_SPREAD: float = 0.28
## Nobody swings at nothing, and nobody exceeds what their approach left them.
const MIN_POWER_FRACTION: float = 0.25

## What each kind of shot is meant to be, as a share of the hitter's ceiling.
## These are the intent anchors -- a drive is a drive whether it is aimed four
## metres in or nine, which is what keeps power independent of the course.
## **Rebalanced against the ceiling raise so only the hard swing got harder.**
##
## The raise above multiplies every intent, and that is not identity-neutral. A
## drive that goes 20% faster also goes out more often, so a physical attack
## trades kills for errors; a control ball 20% faster simply moves into the band
## that is too quick to dig and still lands in. Measured over 144 career seeds
## after the flat raise, a defensive attack came out with *both* a lower error
## rate (0.1401 against 0.1734) and a higher kill rate (0.5640 against 0.5548) --
## strictly dominant, and the loss of the trade
## `_test_team_identity_directional_outcomes` exists to hold.
##
## Tripling the sample from 48 confirmed it rather than settling it: the gap grew
## from 0.0056 to 0.0092, which is a property that has gone rather than a
## measurement that was too coarse.
##
## So control and off-speed are divided by the same 1.2 the ceiling gained, which
## leaves their struck speed where it was and gives the whole raise to the drive.
## That is also what was actually asked for -- a spike reading as a joust rather
## than a strike is a complaint about the hard swing, not about a roll shot.
const DRIVE_INTENT: float = 0.90
const CONTROL_INTENT: float = 0.55
const OFF_SPEED_INTENT: float = 0.30


## What this hitter can produce on this swing.
##
## `attack_power` sets the ceiling and the approach spends it: a hitter who
## arrives badly, or who is turning the ball across their body, cannot hit it as
## hard as one running through it. `swing_power_fraction` comes from
## `AttackCourseModel.swing_cost()`.
static func available_ceiling_mps(
	attack_power_rating: float,
	approach_quality: float,
	swing_power_fraction: float,
) -> float:
	var ceiling := lerpf(
		CEILING_MIN_MPS, CEILING_MAX_MPS, clampf(attack_power_rating, 0.0, 1.0)
	)
	## An approach only ever takes power away; arriving perfectly is what the
	## ceiling already assumes.
	##
	## The floor was 0.70, which cost a badly-arriving hitter nearly a third of
	## their pace before anything else had spent any. Stacked with the across-body
	## floor and the chosen fraction it was one of four compounding discounts, and
	## the product not any one of them was what made a spike slow.
	var approach_scale := lerpf(0.84, 1.0, clampf(approach_quality, 0.0, 1.0))
	return ceiling * approach_scale * clampf(swing_power_fraction, 0.1, 1.0)


## The speed needed to drive a ball this far from this height.
##
## Priced at the driven reference angle rather than the most efficient one,
## because a hitter aiming for the endline is not lobbing it there. Returns the
## speed a perfect judge of the situation would choose.
static func required_speed_mps(
	target_distance_meters: float,
	contact_height_meters: float,
) -> float:
	return BallFlightModel.minimum_speed_for_range(
		target_distance_meters,
		DRIVEN_REFERENCE_ANGLE_DEGREES,
		contact_height_meters,
	)


## How hard the hitter actually decides to swing.
##
## `judgment_error` is a signed, roughly unit-scaled value the caller draws --
## normal, not uniform, so a good reader's misjudgement is rare rather than
## bounded. `block_presence` is 0 for an open net and 1 for a fully formed wall.
##
## Returns the chosen speed alongside the pieces that produced it, so the reason
## a swing was over- or under-hit is readable in the rally record rather than
## only visible as a worse number.
static func choose_power(
	ceiling_mps: float,
	intent_fraction: float,
	target_distance_meters: float,
	contact_height_meters: float,
	aggression: float,
	composure: float,
	decision_making: float,
	block_presence: float,
	judgment_error: float,
) -> Dictionary:
	var ceiling := maxf(ceiling_mps, BallFlightModel.MIN_SPEED_MPS)
	## Anchored on what the shot is *meant to be*, not on the least force that
	## reaches the target.
	##
	## The first version anchored on the distance -- and a hitter aiming four
	## metres in therefore swung at a third of their power, which is not a shot
	## anybody plays. An attacker drives the ball and uses the *angle* to control
	## where it lands; power is chosen for its own sake, because a hard ball is
	## harder to dig. Anchoring on distance quietly re-coupled the two axes this
	## whole model exists to separate, so a cut shot could not be hit hard and
	## soft -- the very example the design is built around.
	var base_fraction := clampf(intent_fraction, 0.0, 1.0)
	var required := required_speed_mps(
		target_distance_meters, contact_height_meters
	)

	## Backing yourself: swing bigger than the situation asks.
	##
	## Centred on 0.5, so an ordinary hitter takes the shot the situation calls
	## for and the trait cuts both ways. Read as a plain multiplier it made 0.5
	## a permanent over-swing, and left a timid hitter merely *not* over-swinging
	## rather than actually holding something back -- which is not the same
	## player and not the same mistake.
	var eagerness := AGGRESSION_BIAS * (clampf(aggression, 0.0, 1.0) - 0.5) * 2.0
	## Decelerating into the wall. Only a formed block intimidates, and only a
	## hitter short of composure is intimidated by it.
	var intimidation := INTIMIDATION_BIAS \
		* clampf(block_presence, 0.0, 1.0) \
		* (1.0 - clampf(composure, 0.0, 1.0))
	## Misjudging what the shot needs. A good reader lands on the required
	## power; a poor one is wrong in either direction.
	var misjudgement := JUDGMENT_ERROR_SPREAD \
		* (1.0 - clampf(decision_making, 0.0, 1.0)) * judgment_error

	var chosen_fraction := clampf(
		base_fraction + eagerness - intimidation + misjudgement,
		MIN_POWER_FRACTION, 1.0,
	)
	var speed := chosen_fraction * ceiling
	## Reachability is now a *consequence* of the swing rather than its anchor.
	## A hitter who chose too little for the distance they aimed at lands short,
	## which is a real thing that happens and is worth naming.
	var reachable := speed >= required
	return {
		"speed_mps": speed,
		"ceiling_mps": ceiling,
		"required_speed_mps": required,
		"required_fraction": required / ceiling,
		"intent_fraction": base_fraction,
		"chosen_fraction": chosen_fraction,
		"reachable": reachable,
		"eagerness": eagerness,
		"intimidation": intimidation,
		"misjudgement": misjudgement,
		## Why this swing came out the way it did, for the rally record and for
		## the action vocabulary, which wants over- and under-hitting named
		## separately rather than both reported as "attack error".
		"bias": _bias_label(eagerness - intimidation + misjudgement),
	}


## What a swing at the top of your range costs you in accuracy.
##
## **The channel the bench's instruction was missing.** Decisiveness reaches the
## ball through `aggression_from` -> `choose_power` -> speed, and speed only ever
## helps a ball stay in: a faster swing is flatter, clears the tape more easily
## and reaches its target without having to be lofted. So the game said a
## Physical identity made *fewer* attack errors than a Defensive one -- measured,
## 0.0642 against 0.0868, the wrong way round -- and the design claim that
## committing to a swing is a risk had nothing anywhere to make it true.
## `chosen_fraction` was published by `choose_power` and read only for a label.
##
## The anchor and both bounds sit inside the distribution they act on, measured
## over 657 live home swings across three identities:
##
##     identity      p10     p50     p90     mean
##     Physical    0.466   0.860   1.000    0.800
##     Balanced    0.365   0.764   0.929    0.715
##     Defensive   0.299   0.676   0.843    0.637
##
## So `CONTROLLED` is the median swing in the game -- an ordinary attack pays
## nothing -- `HELD_BACK` is the tenth percentile of the softest identity, and
## the ceiling applies at a swing with nothing left over. A bound outside that
## range would do nothing, and would do nothing silently.
const COMMITMENT_CONTROLLED_FRACTION: float = 0.72
## Smaller than `ACROSS_BODY_SPREAD_CEILING` (2.10) on purpose: swinging at your
## own limit is a smaller disruption than swinging across your own body.
const COMMITMENT_SPREAD_CEILING: float = 1.60


## **A cost above the controlled swing, and no bonus below it.**
##
## The first version also gave a held-back swing an accuracy *bonus*, sliding to
## 0.78 at the tenth percentile. It reads as symmetric and it is not: it handed
## the Defensive identity both halves of the claim at once, and measured, that
## overshot into the opposite failure -- Defensive came out with a *higher* kill
## rate than Physical, 0.5383 against 0.5321, which is the same gate broken from
## the other side.
##
## Dropping it is also the more honest model. Swinging softer does not make a
## hitter a better aimer than their own attack accuracy; it just stops spending
## accuracy they have. So the ordinary swing pays nothing and the committed one
## pays, which is the whole of what the design claims.
static func commitment_spread_multiplier(chosen_fraction: float) -> float:
	return lerpf(1.0, COMMITMENT_SPREAD_CEILING, clampf(inverse_lerp(
		COMMITMENT_CONTROLLED_FRACTION, 1.0, clampf(chosen_fraction, 0.0, 1.0)
	), 0.0, 1.0))


## The dial `choose_power` reads, from the player's own temperament and the
## instruction they were given.
##
## `aggression` is who the player is; `team_decisiveness` is what the bench
## asked for;
## `tactical_discipline` is how much they do as asked. A disciplined player
## converges on the instruction, an undisciplined one plays their own game --
## which is what makes a low-discipline star both a weapon and a liability
## rather than simply worse.
static func aggression_from(
	aggression_rating: float,
	team_decisiveness: float,
	tactical_discipline: float,
) -> float:
	return clampf(
		lerpf(
			clampf(aggression_rating, 0.0, 1.0),
			clampf(team_decisiveness, 0.0, 1.0),
			clampf(tactical_discipline, 0.0, 1.0),
		),
		0.0, 1.0,
	)


## Temperament only. Whether the swing then reaches is a *consequence*, reported
## separately by `reachable` -- folding it in here overwrote the reason a hitter
## held back with the fact that holding back left them short, and a rally record
## wants to say both.
static func _bias_label(net_bias: float) -> String:
	if net_bias > 0.06:
		return "over-swung"
	if net_bias < -0.06:
		return "held back"
	return "measured"
