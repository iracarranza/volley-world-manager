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
## `aggression` is `VolleyballPlayer.ego` on a 0-1 scale -- see
## `aggression_from()`, which folds in the team's instruction, because how much
## a hitter backs themselves and how much the bench has told them to are
## different things that both move the same dial.

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

## Ball speed a hitter can generate, from no attacking power to elite. The top
## of this is a hard-driven international spike; the bottom is a player who
## cannot put anything on it.
const CEILING_MIN_MPS: float = 16.0
const CEILING_MAX_MPS: float = 30.0

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
const DRIVE_INTENT: float = 0.90
const CONTROL_INTENT: float = 0.66
const OFF_SPEED_INTENT: float = 0.36


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
	var approach_scale := lerpf(0.70, 1.0, clampf(approach_quality, 0.0, 1.0))
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


## The dial `choose_power` reads, from the player's own temperament and the
## instruction they were given.
##
## `ego` is who the player is; `team_decisiveness` is what the bench asked for;
## `tactical_discipline` is how much they do as asked. A disciplined player
## converges on the instruction, an undisciplined one plays their own game --
## which is what makes a low-discipline star both a weapon and a liability
## rather than simply worse.
static func aggression_from(
	ego_rating: float,
	team_decisiveness: float,
	tactical_discipline: float,
) -> float:
	return clampf(
		lerpf(
			clampf(ego_rating, 0.0, 1.0),
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
