class_name ScoutingSystem
extends RefCounted

## How well you know a voli, and what you are shown when you do not know them
## well.
##
## The scout's resource is **information confidence**, and the design rule from
## `CLUB_LIFE.md` is that a bad scout does not give you worse volis -- it gives
## you a blurrier roster. That is a more interesting failure than a stat penalty
## and it is the same mechanism hidden potential, unreliable self-report and
## thought bubbles all need, which is why it is built before the other three
## staff roles rather than alongside them.
##
## ## Three rules this has to obey, and one of them is not obvious
##
## **1. The fog is a view, never a copy.** Nothing here writes an estimate back
## onto a voli. `VolleyballPlayer` keeps the truth; every function below is a
## pure transformation of it. Storing the fogged value would give one fact two
## sources, and the copy would drift the moment a voli trained.
##
## **2. It is deterministic.** The estimate for a given voli, attribute and
## confidence is always the same number. Drawn randomly, a player could close and
## reopen the panel until the prospect looked good -- the estimate would be a
## slot machine rather than information, and no amount of tuning fixes that.
## Every number here is hashed from the voli's id and the attribute's name.
##
## **3. It is centred, and clamping breaks that.** A scout should be as likely to
## overrate as to underrate; a fog with a bias is a systematic lie and the whole
## population's apparent quality moves with your scout's rating. The trap is at
## the ends of the scale: adding a symmetric error to a voli at 96 and clamping
## to 100 throws away half the distribution and makes every elite prospect read
## low. `_fold` reflects off the bounds instead, which keeps the mean where it
## belongs. The suite measures this rather than trusting it.

const StaffMember := preload("res://scripts/models/staff_member.gd")

## How wide the scout's error is at zero confidence, in attribute points.
##
## At 22 a completely unknown prospect's reported figure sits within roughly a
## grade band of the truth most of the time and misses by two occasionally, which
## is the reading a scouting system wants: usually directionally right, sometimes
## badly wrong, never useless.
const MAX_ERROR_POINTS: float = 22.0

## Confidence for a voli in your own building, before tenure and before a scout.
##
## High, and it should be: you watch these people train every day. What a scout
## adds for your own squad is not *who they are* but *what they will become* --
## which is why the potential band below stays wider than the ability one at the
## same confidence.
const ROSTER_BASE_CONFIDENCE: float = 0.58

## Confidence for somebody you have never employed. Low enough that an unscouted
## market is genuinely a gamble.
const PROSPECT_BASE_CONFIDENCE: float = 0.08

## How much a perfect scout is worth, per side of that divide. Larger for
## prospects because that is the scout's actual job -- their contribution to a
## voli you already own is real but small, since you have your own eyes.
const SCOUT_PROSPECT_WEIGHT: float = 0.54
const SCOUT_ROSTER_WEIGHT: float = 0.16

## How long watching somebody takes to tell you what watching can tell you.
## A season and a half, and it saturates rather than continuing forever.
const OBSERVATION_WEEKS_TO_SATURATE: float = 26.0
const OBSERVATION_WEIGHT: float = 0.30

## Potential is a claim about a future that has not happened, so it is never as
## knowable as an attribute you can watch.
##
## Two terms, because a floor alone does not do the job. A floor only bites once
## uncertainty has fallen below it -- so a floor-only model made potential and
## ability *equally* knowable everywhere under about 0.78 confidence, which is
## most of the range and all of the range that matters for a prospect. The suite
## caught that. The scale widens the band at every confidence; the floor stops it
## reaching zero at the top.
##
## The scaled width deliberately exceeds `MAX_ERROR_POINTS` at low confidence:
## an unknown teenager's ceiling really can be wrong by more than any observable
## attribute, and `_fold` keeps the result on the scale regardless.
const POTENTIAL_UNCERTAINTY_SCALE: float = 1.30
const POTENTIAL_UNCERTAINTY_FLOOR: float = 0.22

## Above this you are told a number; below it you are told a range.
##
## Set where the band gets narrow enough that quoting a midpoint stops being
## misleading -- not at an arbitrary "high confidence" mark. At 0.80 the ability
## band is about 4 points wide, which rounds to one grade.
const PRECISE_REPORT_CONFIDENCE: float = 0.80


## How well this club knows this voli.
##
## `on_roster` is the big term and everything else adjusts it. Weeks observed
## saturates, so a voli who has been at the club three seasons is not meaningfully
## better known than one who has been there two.
static func confidence(
	on_roster: bool,
	weeks_observed: int,
	scout_rating: int,
) -> float:
	var scout := clampf(float(scout_rating) / 100.0, 0.0, 1.0)
	var watched := clampf(
		float(maxi(weeks_observed, 0)) / OBSERVATION_WEEKS_TO_SATURATE, 0.0, 1.0
	)
	var base := ROSTER_BASE_CONFIDENCE if on_roster else PROSPECT_BASE_CONFIDENCE
	var scout_weight := SCOUT_ROSTER_WEIGHT if on_roster else SCOUT_PROSPECT_WEIGHT
	return clampf(
		base + scout * scout_weight + watched * OBSERVATION_WEIGHT, 0.0, 1.0
	)


## The best scout you employ, or zero if you employ none.
##
## Takes the best rather than a sum: two mediocre scouts do not add up to a good
## one, and letting them would make hiring a numbers game instead of a choice.
static func scout_rating(staff: Array) -> int:
	var best := 0
	for entry in staff:
		var member := entry as VolleyballStaffMember
		if member != null and member.role == StaffMember.ROLE_SCOUT:
			best = maxi(best, member.rating)
	return best


## What the club believes one attribute to be.
##
## Deterministic in every argument, so the same voli read twice reads the same.
## `key` salts the hash, which is what stops a voli's whole profile being wrong
## in one direction -- a scout who overrates a hitter's power should not
## automatically overrate their passing by the same amount.
static func reported_value(
	true_value: float,
	confidence_level: float,
	player_id: int,
	key: String,
	is_potential: bool = false,
) -> float:
	var width := error_width(confidence_level, is_potential)
	if width <= 0.0001:
		return true_value
	## Triangular rather than uniform: two independent draws summed. A scout is
	## usually close and occasionally badly wrong, which a flat distribution does
	## not say -- under a uniform error, a miss by one point and a miss by twenty
	## are equally likely and the estimate reads as noise rather than a judgement.
	var first := _unit(player_id, key, 0x9E37)
	var second := _unit(player_id, key, 0x85EB)
	return _fold(true_value + (first + second - 1.0) * width)


## Half-width of the error at this confidence, in attribute points.
##
## Linear in confidence and exactly zero at 1.0 for an observable attribute --
## if you have complete information you are shown the number, with no residual
## fuzz to explain. Potential keeps a floor because no amount of watching tells
## you what somebody will become.
static func error_width(confidence_level: float, is_potential: bool = false) -> float:
	var known := clampf(confidence_level, 0.0, 1.0)
	var uncertainty := 1.0 - known
	if is_potential:
		uncertainty = maxf(
			uncertainty * POTENTIAL_UNCERTAINTY_SCALE, POTENTIAL_UNCERTAINTY_FLOOR
		)
	return MAX_ERROR_POINTS * uncertainty


## The range the club would quote, low to high, around its own estimate.
##
## Centred on the *reported* value rather than on the truth, because that is what
## an honest scout does: they tell you what they think and how sure they are, and
## a band drawn around the real answer would leak the real answer.
static func reported_band(
	true_value: float,
	confidence_level: float,
	player_id: int,
	key: String,
	is_potential: bool = false,
) -> Vector2:
	var reported := reported_value(
		true_value, confidence_level, player_id, key, is_potential
	)
	var width := error_width(confidence_level, is_potential)
	return Vector2(_fold(reported - width), _fold(reported + width))


## Whether this is knowable enough to quote as a figure rather than a range.
static func reports_precisely(confidence_level: float) -> bool:
	return confidence_level >= PRECISE_REPORT_CONFIDENCE


## How the club would describe its own certainty, for a caption.
static func confidence_summary(confidence_level: float) -> String:
	if confidence_level >= 0.90:
		return "Known"
	if confidence_level >= PRECISE_REPORT_CONFIDENCE:
		return "Well scouted"
	if confidence_level >= 0.55:
		return "Scouted"
	if confidence_level >= 0.30:
		return "Glimpsed"
	return "Unknown"


## A whole summary profile as the club sees it.
##
## Runs each category through the same estimate the individual attributes use, so
## the wheel and the numbers beside it cannot disagree about how much is known.
static func fogged_profile(
	profile: Dictionary,
	confidence_level: float,
	player_id: int,
	is_potential: bool = false,
) -> Dictionary:
	var fogged := {}
	for key in profile:
		fogged[key] = reported_value(
			float(profile[key]), confidence_level, player_id, str(key), is_potential
		)
	return fogged


## Reflect back inside 1-100 instead of clamping to it.
##
## Clamping is the obvious move and it silently biases the whole system: a voli
## at 96 with a symmetric error has half its distribution cut off and reads low
## every time, so elite prospects would be systematically underrated and the
## scout would look pessimistic rather than uncertain. Reflection preserves the
## mean. Looped, because a wide band on an extreme value can overshoot twice.
static func _fold(value: float) -> float:
	var folded := value
	for _pass in range(4):
		if folded > 100.0:
			folded = 200.0 - folded
		elif folded < 1.0:
			folded = 2.0 - folded
		else:
			return folded
	return clampf(folded, 1.0, 100.0)


## A stable 0-1 from a voli, an attribute and a salt.
##
## Hand-mixed rather than calling `String.hash()` so the fog is a property of
## this file and not of whatever the engine's hash happens to be this version.
## A scouting report that changed on an engine upgrade would be indistinguishable
## from a bug and impossible to reproduce.
static func _unit(player_id: int, key: String, salt: int) -> float:
	var accumulated := (player_id * 2654435761) ^ salt
	for index in range(key.length()):
		accumulated = ((accumulated << 5) + accumulated) + key.unicode_at(index)
		accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 15)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 1000003) / 1000003.0
