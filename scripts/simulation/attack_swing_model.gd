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
	var power_scale := lerpf(
		POWER_SHORTFALL, POWER_OVERSHOOT, 1.0 if power_draw > 0.0 else 0.0
	) * (1.0 - precision * 0.55) * widen
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
