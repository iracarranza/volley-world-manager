class_name BallSpin
extends RefCounted

## What a hitter puts on the ball, and what that does to it.
##
## **Most of this already existed and none of it was connected.**
## `BallContactSignature` has carried `topspin_rps` and `sidespin_rps` since the
## shadow systems were built, `Familiarity` already learns tags, and every
## function in `BallFlightModel` already takes gravity as a parameter. What was
## missing is the middle: nothing in a live rally ever *produced* a spin, and the
## model's own docstring said the numbers "do not drive aerodynamic physics".
## So the game had a vocabulary for spin, a memory for spin, and a flight solver
## ready to be told about spin, and a ball that never span.
##
## Two properties, per the design:
##
##   `axis`      -1 to +1. The extremes are pure sidespin, left and right; zero
##               is pure topspin. A right-handed hitter swinging through the ball
##               naturally cuts across it toward their left, which puts the axis
##               positive, and a left-hander's sits negative -- so handedness is
##               a *bias* on a continuum rather than a category, and a hitter who
##               can hit the seam either way is a hitter with a small bias.
##   `rate_rps`  how fast it is turning. Applied by the hitter: power supplies it
##               and technique converts it, which is why a strong hitter with
##               poor hands puts pace on the ball and not much else.
##
## The two derived components are what the rest of the game already speaks:
## `topspin_rps` is the part of the spin about the horizontal axis and
## `sidespin_rps` the part about the vertical one, so a signature built from
## this drops straight into the familiarity machinery without a translation
## layer.
##
## **Why topspin belongs in the flight and sidespin does not.** Topspin acts
## over the whole flight -- the Magnus force is downward the entire time, so it
## shows up as the ball falling harder than gravity, which is exactly a change of
## gravity and nothing more. Sidespin over a flight is a curve, and this engine
## draws a quadratic Bezier whose control point is already the curve; adding a
## second curving term would be two descriptions of one bend. What sidespin
## genuinely does that nothing else models is *kick off a contact* -- off a
## blocker's hands, off a platform -- and that is where it is spent here.

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

## Revolutions per second, from a ball nobody has put anything on to the top of
## what a hitter can impart. `BallContactSignature` clamps at 30 and treats 18 as
## fully novel topspin, so this range sits inside the scale the rest of the game
## already reads rather than beside it.
const MAX_RATE_RPS: float = 22.0
## A float serve is not "low spin", it is *no* spin -- that is the entire point
## of the shot, because a ball with no gyroscopic stability wanders. Above this
## it is a slow topspin serve instead, which is a different and much easier ball.
const FLOAT_RATE_RPS: float = 0.75

## How much heavier gravity gets, per revolution per second of topspin.
##
## **This stands in for the whole aerodynamic package, not for Magnus alone.**
## `BallFlightModel` has neither drag nor spin, and its own note explains why
## that is tolerable: a spike is struck *downward*, so its range is dominated by
## the launch angle and a drag term would buy little. That argument does not
## survive contact with a serve. A serve is struck upward from nine metres behind
## the line, and something has to bring it down inside eighteen -- on a real
## court that something is drag and topspin together, and a volleyball is light
## and large enough that both are strong.
##
## So the anchor is the shot the feature exists to make possible, worked
## backwards rather than guessed. A 25 m/s serve launched at five degrees covers
## 17.45 m of ground in 0.70 s, and to fall 2.9 m in that time it has to be
## pulled down at about 18 m/s squared. A real jump-topspin serve turns at
## roughly 10 revolutions per second, so the coefficient that makes that serve
## exist is about 0.8 -- and a serve of that pace does exist, which is the
## evidence the number is answerable to.
##
## Named for topspin rather than for drag because topspin is what a *player*
## controls and what the design asks to be modelled. A float serve, having no
## rotation, correctly gets none of this and is correspondingly hard to keep in
## -- which is true of real float serves and is why they are hit softer.
##
## **Raised from 0.78, and deliberately raised here rather than by adding drag.**
## A drag term would be a global invisible force slowing every ball by an amount
## nobody can see, attributable to no player and moved by no decision -- the
## precise shape of system this project does not want. This coefficient does the
## same physical job through a channel a player owns: spin is chosen, `serve
## technique` converts it, and the ball visibly dives. Pace on a serve is
## therefore *earned* rather than granted, and a server who cannot spin the ball
## cannot hit one hard and keep it in.
const TOPSPIN_GRAVITY_PER_RPS: float = 1.02
## And the bound. Past this the ball is diving in a way no viewer reads as a
## volleyball, whatever the arithmetic says.
const MAX_SPIN_GRAVITY_MPS2: float = 26.0

## How far a fully side-spinning ball kicks off a contact, in metres of court.
## Measured against the thing it has to matter for: a blocker's hands are about
## 0.45 m across, so a deflection has to be a decent fraction of that to change
## whether the ball comes off the wall in or out.
const SIDESPIN_KICK_METERS: float = 0.62
## What a defender who has seen this spin before takes off the kick. Never all of
## it -- reading a ball is not catching it -- and this is the mitigation the
## design asks for: spin beats you less once you know the hitter.
const FAMILIARITY_KICK_RELIEF: float = 0.55


## The spin a swing produces.
##
## `power` and `technique` are 0-1 ratings. Power sets how much spin is available
## and technique decides how much of it survives contact -- the same division
## `_usable_serve_pace` already makes for pace, kept deliberately parallel so a
## reader does not have to learn two stories about the same two attributes.
##
## `across_body` is the swing's own strain, 0 for a ball struck through the
## approach and 1 for one turned right back across the hitter. Cutting across the
## ball is what *creates* sidespin, so the axis is not a fixed property of a
## hitter's handedness -- it is where their hand went, with handedness deciding
## which way the natural swing already leans.
static func from_swing(
	power: float,
	technique: float,
	across_body: float,
	right_handed: bool,
) -> Dictionary:
	var rate := MAX_RATE_RPS \
		* clampf(power, 0.0, 1.0) \
		* lerpf(0.45, 1.0, clampf(technique, 0.0, 1.0))
	## The natural lean, then the swing on top of it. A hitter striking through
	## the ball is mostly topspin; the more they have to turn, the more of the
	## spin goes sideways.
	var handed := 1.0 if right_handed else -1.0
	return spin(handed * clampf(across_body, 0.0, 1.0), rate)


## The spin a serve produces, which is a choice of shot rather than a by-product.
##
## A topspin serve and a float serve are opposite intentions: one is trying to
## put as much rotation on the ball as possible so it dives and stays in, and the
## other is trying to put *none* on it so it does not. Technique decides how well
## either is executed, but it decides different things -- how much topspin is
## available, or whether the float actually floats.
static func from_serve(
	style: String,
	power: float,
	technique: float,
	right_handed: bool,
) -> Dictionary:
	var control := clampf(technique, 0.0, 1.0)
	if style.to_lower().contains("float"):
		## A missed float is not a float: the hand catches the ball slightly off
		## centre and it comes out with enough rotation to fly straight, which is
		## the easiest serve in the game to pass. Technique is the chance of
		## getting it right, and the failure has to be a *real* ball rather than
		## a flag, so it comes out as a slow topspin serve.
		return spin(0.0, lerpf(FLOAT_RATE_RPS * 4.0, 0.0, control))
	## **Pace on a serve is bought with spin, and this is where that is priced.**
	## Worked out from the flight rather than picked: a 25 m/s serve only stays
	## inside the endline if it is falling at about 26 m/s squared, which at
	## `TOPSPIN_GRAVITY_PER_RPS` needs roughly 21 revolutions per second -- so an
	## elite topspin server has to reach the top of this range and a mediocre one
	## must serve slower or serve it out. `_serve_arc`'s relief sweep then does
	## exactly that on its own, without a rule anywhere saying so.
	##
	## That is the shape the design asked for: serve technique *is* available
	## topspin, and available topspin is what a hard serve is made of.
	var handed := 1.0 if right_handed else -1.0
	return spin(
		handed * 0.18,
		MAX_RATE_RPS
			* lerpf(0.42, 1.0, clampf(power, 0.0, 1.0))
			* lerpf(0.48, 1.0, control),
	)


## The two components, from the axis and the rate.
##
## Kept as one function so the decomposition is stated once. Everything else in
## the game reads `topspin_rps` and `sidespin_rps`; nothing else should have an
## opinion about how they relate to the axis.
static func spin(axis: float, rate_rps: float) -> Dictionary:
	var clamped_axis := clampf(axis, -1.0, 1.0)
	var rate := clampf(rate_rps, 0.0, MAX_RATE_RPS)
	return {
		"axis": clamped_axis,
		"rate_rps": rate,
		"topspin_rps": rate * (1.0 - absf(clamped_axis)),
		"sidespin_rps": rate * clamped_axis,
		## A ball with no rotation has nothing holding its attitude, so it wanders
		## -- which is what a float serve is for and why it is hard to read. The
		## rest of the game already consumes `flight_stability`; this is the first
		## thing that produces a value other than 1.0.
		"flight_stability": clampf(
			inverse_lerp(0.0, FLOAT_RATE_RPS * 2.0, rate), 0.25, 1.0
		),
	}


## What this ball falls under, in metres per second squared.
##
## The whole of topspin's contribution to the flight. Every solver in
## `BallFlightModel` already takes gravity as its last parameter and every one of
## them defaulted it, so this needed no new physics -- only somebody to pass it.
static func gravity_for(spin_state: Dictionary) -> float:
	return minf(
		BallFlightModel.DEFAULT_GRAVITY_MPS2
			+ TOPSPIN_GRAVITY_PER_RPS
				* maxf(float(spin_state.get("topspin_rps", 0.0)), 0.0),
		MAX_SPIN_GRAVITY_MPS2,
	)


## How far sideways the ball comes off a contact, in metres of court.
##
## Signed, so a renderer and a resolver agree on which way it went. `familiarity`
## is 0 for a defender who has never seen this hitter's spin and 1 for one who
## has seen it many times -- the mitigation the design asks for, and the reason
## scouting a hitter is worth doing.
static func contact_kick_meters(
	spin_state: Dictionary, familiarity: float
) -> float:
	return SIDESPIN_KICK_METERS \
		* clampf(float(spin_state.get("sidespin_rps", 0.0)) / MAX_RATE_RPS,
			-1.0, 1.0) \
		* (1.0 - FAMILIARITY_KICK_RELIEF * clampf(familiarity, 0.0, 1.0))


## The band a spin falls in, for a familiarity tag.
##
## Bands rather than the raw figure because familiarity is about recognising *a
## kind of ball*, and a defender who has read 11.2 rps of sidespin has learned
## something about 11.8 as well. Three revolutions per second is about the
## finest distinction worth claiming a player can draw mid-rally.
static func familiarity_tag(spin_state: Dictionary) -> String:
	return "spin:%d" % int(round(
		float(spin_state.get("sidespin_rps", 0.0)) / 3.0
	))
