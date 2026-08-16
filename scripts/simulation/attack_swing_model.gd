class_name AttackSwingModel
extends RefCounted

## What the hitter actually did, given what they meant to do.
##
## Intent arrives as three numbers -- a course, a launch angle, a speed -- and
## leaves as the same three, moved. The moving happens on three **independent
## channels**, and that independence is the whole point: each one fails in a
## different, separately nameable way, where `_attack_missed()` today rolls one
## logistic on a quality scalar and produces all of them indistinguishably as
## "attack error".
##
## - **power** comes off soft. Asymmetric on purpose: you mishit a ball and it
##   dribbles far more often than you accidentally hit it harder than you meant
##   to. Reads as *dropped short*.
## - **vertical angle** leaves flatter or steeper than aimed. Reads as *sailed
##   long*, or *into the net*.
## - **bearing** misses the course itself. Reads as *pulled wide* -- or into a
##   blocker the hitter was trying to avoid, which is how a tool happens.
##
## All three widen together with `spread_multiplier` from
## `AttackCourseModel.swing_cost()`, so a ball struck across the body is less
## accurate in every respect rather than only slower.
##
## Pure and deterministic. The three draws are signed, roughly unit-scaled
## values the caller supplies -- normal, not uniform, so a good hitter's miss is
## a rare tail rather than a hard bound.

## Angular error at no accuracy and at elite accuracy, in degrees. Bearing runs
## wider than vertical because a hitter has far more freedom to miss sideways
## than they do to miss up: the swing plane constrains one and not the other.
const BEARING_SPREAD_WORST_DEGREES: float = 7.5
const BEARING_SPREAD_BEST_DEGREES: float = 1.6
const VERTICAL_SPREAD_WORST_DEGREES: float = 5.0
const VERTICAL_SPREAD_BEST_DEGREES: float = 1.1

## Power delivery, as a fraction of intent. The shortfall side is roughly three
## times the overshoot side, which is what makes "mishit" the common failure and
## "caught it too well" the rare one.
const POWER_SHORTFALL: float = 0.26
const POWER_OVERSHOOT: float = 0.09


## How far off the intended launch angle this swing can be expected to land, in
## degrees, one standard deviation.
##
## Shared so a hitter can *aim* against the same spread they will be judged by.
## `deliver` computed this privately, so nothing upstream could ask how much air
## a swing needed -- and the margin a hitter aimed for was a flat constant however
## far the ball had to fly to reach the tape.
static func vertical_spread_degrees(
	accuracy: float,
	spread_multiplier: float,
) -> float:
	return lerpf(
		VERTICAL_SPREAD_WORST_DEGREES, VERTICAL_SPREAD_BEST_DEGREES,
		clampf(accuracy, 0.0, 1.0),
	) * maxf(spread_multiplier, 0.0)


## How far off the intended bearing this swing can be expected to land, in
## degrees, one standard deviation.
##
## The horizontal twin of `vertical_spread_degrees`, and it exists for a reason
## the vertical one does not. A bearing error does not only move where the ball
## lands -- it changes how far the ball has to fly to reach the tape at all, and
## a shot swung a few degrees flatter across the court crosses far more ground
## getting there. A hitter budgeting only for vertical error is budgeting for
## half of what can put the ball in the net.
static func bearing_spread_degrees(
	accuracy: float,
	spread_multiplier: float,
) -> float:
	return lerpf(
		BEARING_SPREAD_WORST_DEGREES, BEARING_SPREAD_BEST_DEGREES,
		clampf(accuracy, 0.0, 1.0),
	) * maxf(spread_multiplier, 0.0)


## How much of their own execution a hitter has today.
##
## **The hitter's only channel that the chain does not gate.** An attack's
## quality is a product of the pass, the set, the tempo the setter could run, the
## approach that pass left time for, and the wall in front of them -- five
## fractions under one, four of which belong to somebody else. Measured, that
## compresses attack effectiveness into 0.41 between the tenth and ninetieth
## percentile against 0.83 for the defender it is contested with, and it caps
## what an outstanding hitter can reach: 465 swings and 20 clear 0.60.
##
## Confidence and flow are the two terms that are genuinely *theirs*. Both were
## already computed, already passed into `resolve_swing`, and both were read for
## nothing but whether a signature move fired -- so the game had a model of a
## hitter's state and spent it only on the rule-of-cool layer.
##
## Applied to the spread rather than to the power, because that is what "a great
## hitter makes something out of nothing" actually means. They do not hit a bad
## set harder; they hit it *more precisely*, finding a line off a ball that
## should not have one. Precision is the thing a product of five links cannot
## give them and their own state can.
##
## Both inputs are signed, -1 to +1, zero being neutral -- so an ordinary hitter
## in an ordinary match pays and gains nothing, and the term cuts both ways. A
## rattled hitter against the run of play is genuinely worse than their rating,
## which is the other half of the claim and the half that makes momentum matter.
const FORM_SPREAD_BEST: float = 0.68
const FORM_SPREAD_WORST: float = 1.42
## Confidence outweighs flow because one is the player and the other is the
## room. A hitter who backs themselves scores through a bad night for the team;
## the reverse is rarer.
const FORM_CONFIDENCE_SHARE: float = 0.62


## How much wider a swing's cone gets because there is a wall in front of it.
##
## **The block was not an input to a hitter's aim, and it should be the main
## one.** Reported from playback: volis swing out while the blockers stand there
## not jumping, because they can already see it is going out. A misswing at an
## open net is an unforced error and should be rare even from a poor hitter;
## missing is mostly what pressure produces.
##
## Measured over 600 rallies, 705 swings: 15.6% of all attacks went out, and the
## rate was no lower against nothing than against two -- 38.5% against a single
## blocker on 39 swings, 14.3% against two on 666. The only reason those buckets
## differ is that they contain different swings, because `deliver` builds its
## cone from the hitter's accuracy and a form multiplier and nothing else. The
## receive channel is present -- reception quality reaches the swing through the
## set -- and the block channel simply was not there.
##
## Centred on a **double block**, deliberately. 94% of swings in the game face
## two, so anchoring the neutral point there means the overall error rate barely
## moves while the case that reads wrong on screen -- an open net -- gets the
## tight cone it should always have had. This narrows more balls than it widens.
##
## `seal` is how well the wall actually closed, 0 to 1. A wall that is up but
## split is not the same pressure as one with no gap in it, and a hitter reads
## the difference; passing it as a separate term is what stops "a block exists"
## and "a block is a problem" collapsing into one number.
const OPEN_NET_SPREAD: float = 0.55
const SINGLE_BLOCK_SPREAD: float = 0.78
const DOUBLE_BLOCK_SPREAD: float = 1.0
const TRIPLE_BLOCK_SPREAD: float = 1.22
## What a perfectly sealed wall adds over a badly split one of the same size.
const SEAL_SPREAD_RANGE: float = 0.18


static func block_spread_multiplier(wall_size: int, seal: float) -> float:
	var size_term := OPEN_NET_SPREAD
	match maxi(wall_size, 0):
		1:
			size_term = SINGLE_BLOCK_SPREAD
		2:
			size_term = DOUBLE_BLOCK_SPREAD
		_:
			if wall_size >= 3:
				size_term = TRIPLE_BLOCK_SPREAD
	if wall_size <= 0:
		## Nothing to seal, so the seal term has nothing to say and must not be
		## allowed to widen an open net by being passed a stale value.
		return size_term
	return size_term * lerpf(
		1.0 - SEAL_SPREAD_RANGE * 0.5, 1.0 + SEAL_SPREAD_RANGE * 0.5,
		clampf(seal, 0.0, 1.0),
	)


static func form_spread_multiplier(
	match_confidence: float, flow_for_team: float
) -> float:
	var form := clampf(match_confidence, -1.0, 1.0) * FORM_CONFIDENCE_SHARE \
		+ clampf(flow_for_team, -1.0, 1.0) * (1.0 - FORM_CONFIDENCE_SHARE)
	## Mapped from -1..+1 onto worst..best through the midpoint, so zero is
	## exactly 1.0 and neither end is reachable by one term alone.
	return lerpf(FORM_SPREAD_WORST, FORM_SPREAD_BEST, (form + 1.0) * 0.5)


## How much of the intended pace one sigma of power error moves, as a fraction.
##
## **Extracted so a planner can read it before the draw.** It was inline in
## `deliver`, which meant the only way to know how much pace a contact might lose
## was to take the loss -- so a launch search could plan around its own angular
## spread, which it is handed, and not around its power spread, which it was not.
## Measured on the serve, that gap is the dominant net-error channel: a
## power-shortfall draw beyond one sigma put 0.81 of live serves into the tape
## against 0.16 for an equally bad vertical draw.
##
## `overshooting` selects the side, because the two are deliberately asymmetric
## -- shortfall is about three times overshoot, which is what makes "mishit" the
## common failure and "caught it too well" the rare one. A planner asks for the
## shortfall side; `deliver` asks for whichever side the draw landed on. One
## definition, so the reserve a contact is planned with cannot drift from the
## error it is then judged by -- the same reason `deliver` computes its angular
## spreads through the functions the hitter aimed against.
static func power_error_scale(
	accuracy: float, spread_multiplier: float, overshooting: bool
) -> float:
	return lerpf(
		POWER_SHORTFALL, POWER_OVERSHOOT, 1.0 if overshooting else 0.0
	) * (1.0 - clampf(accuracy, 0.0, 1.0) * 0.55) * maxf(spread_multiplier, 0.0)


static func deliver(
	intended_bearing_degrees: float,
	intended_vertical_angle_degrees: float,
	intended_speed_mps: float,
	accuracy: float,
	spread_multiplier: float,
	bearing_draw: float,
	vertical_draw: float,
	power_draw: float,
) -> Dictionary:
	var precision := clampf(accuracy, 0.0, 1.0)
	var widen := maxf(spread_multiplier, 0.0)
	## Through the same two functions the hitter aimed against, so the spread a
	## swing is judged by cannot drift from the spread it was planned around.
	var bearing_spread := bearing_spread_degrees(precision, widen)
	var vertical_spread := vertical_spread_degrees(precision, widen)

	var bearing_error := bearing_draw * bearing_spread
	var vertical_error := vertical_draw * vertical_spread
	## The asymmetry. A negative draw takes the full shortfall; a positive one
	## only ever adds a little.
	var power_scale := power_error_scale(precision, widen, power_draw > 0.0)
	var power_error := power_draw * power_scale

	return {
		"bearing_degrees": intended_bearing_degrees + bearing_error,
		"vertical_angle_degrees": intended_vertical_angle_degrees + vertical_error,
		"speed_mps": maxf(intended_speed_mps * (1.0 + power_error), 0.1),
		"bearing_error_degrees": bearing_error,
		"vertical_error_degrees": vertical_error,
		"power_error_fraction": power_error,
		## Which channel moved this ball furthest from its intent, normalised by
		## each channel's own spread so they are comparable. This is what names
		## the miss: the same "attack error" today becomes a hitter who pulled it
		## wide, one who sailed it long, and one who never got hold of it.
		"dominant_channel": _dominant_channel(
			bearing_error, bearing_spread,
			vertical_error, vertical_spread,
			power_error, power_scale,
		),
	}


static func _dominant_channel(
	bearing_error: float,
	bearing_spread: float,
	vertical_error: float,
	vertical_spread: float,
	power_error: float,
	power_scale: float,
) -> String:
	var bearing_share := absf(bearing_error) / maxf(bearing_spread, 0.0001)
	var vertical_share := absf(vertical_error) / maxf(vertical_spread, 0.0001)
	var power_share := absf(power_error) / maxf(power_scale, 0.0001)
	if bearing_share >= vertical_share and bearing_share >= power_share:
		return "bearing"
	if vertical_share >= power_share:
		return "vertical"
	return "power"
