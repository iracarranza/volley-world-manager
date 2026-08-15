class_name AttackCourseModel
extends RefCounted

## Which directions a hitter can actually swing, and how far the court extends
## along each of them.
##
## A course is a **bearing**, not a named zone, and this is the reason: a zone
## name is not portable between hitters. A left-pin hitter's cross-court and a
## right-pin hitter's cross-court are opposite directions, and their "line"
## shots hug opposite sidelines. Expressing the choice as a signed bearing from
## the hitter's own contact point makes that fall out of the geometry instead of
## needing a table per lane. The *label* is then derived from where the ball
## lands relative to the hitter, which is what `_attack_direction()` in the
## simulator already does correctly.
##
## The asymmetry this produces is the point. A hitter at x = 0.12 has 0.065 of
## court to their left and 0.825 to their right, so the bearings that stay
## in-bounds are heavily skewed one way; the mirror hitter is skewed the other.
## The current `swing_range` is a symmetric window in x and cannot express that.
##
## Bearings are measured in **metric space**, from the net normal, positive
## toward increasing x. Measuring in normalized coordinates would give a
## different angle than the ball actually flies, because the court is 9 m across
## and 18 m long -- a 45-degree line in normalized space is a 26-degree line on
## the floor.
##
## Purely horizontal. Nothing here knows about gravity, net height or contact
## height; `BallFlightModel` owns the vertical plane, and the two compose.

const CourtConstants := preload("res://scripts/data/court_constants.gd")

## Sideline and endline. The painted lines are normalized 0 and 1, which is
## where the renderer puts them, so legality is judged against those rather than
## against the inset the old targeting search aimed within.
const COURT_MIN_X: float = 0.0
const COURT_MAX_X: float = 1.0
## Below this the span is too thin to be a shot rather than a graze down the
## line, and treating it as available produced courses that clipped the corner
## of the court for twenty centimetres.
const MIN_USABLE_SPAN_METERS: float = 0.35

## How far off the net normal a ball can credibly be struck.
##
## The legal cone reaches past 85 degrees -- a ball travelling almost parallel
## to the net still clips court eventually -- but those are not shots. Left in,
## a course scorer picks them precisely *because* no blocker stands 80 degrees
## away, and the ball then needs twenty metres of travel just to cross the net.
## Nobody hits a volleyball sideways down the tape; this is the line between a
## sharp cross and a geometric artefact.
const MAX_COURSE_BEARING_DEGREES: float = 70.0


## Unit direction of a bearing, in metres, for a hitter attacking toward the
## given half.
static func direction_meters(
	bearing_degrees: float,
	attacking_negative_y: bool,
) -> Vector2:
	var radians := deg_to_rad(bearing_degrees)
	var forward := -1.0 if attacking_negative_y else 1.0
	return Vector2(sin(radians), forward * cos(radians))


## Where on the tape a ball struck from this contact on this bearing crosses.
##
## Purely the ground geometry -- the vertical question of whether it clears the
## tape at all belongs to the flight, and is asked separately.
##
## Shared because two callers need the same answer and reaching it twice is how
## the wall ended up standing somewhere the ball never went. The resolver asks
## it *after* the swing to place the intersection; a blocker asks it *before* the
## swing, off the approach line, to decide where to stand. A hitter contacting a
## metre off the net with a turned shoulder crosses the net a long way from where
## they jumped -- measured on live rallies, the median beaten wall was standing
## 2.1 m from the point the ball actually came through, which is six times its
## own half-width. No wall is wide enough to cover that; it was in the wrong
## place.
static func net_crossing_x(
	contact: Vector2,
	bearing_degrees: float,
	attacking_negative_y: bool,
) -> float:
	var direction := direction_meters(bearing_degrees, attacking_negative_y)
	if absf(direction.y) < 0.000001:
		return contact.x
	var to_net_meters := (CourtConstants.NET_Y - contact.y) \
		* CourtConstants.COURT_LENGTH_METERS
	var ground_to_net := to_net_meters / direction.y
	if ground_to_net < 0.0:
		ground_to_net = 0.0
	return contact.x \
		+ direction.x * ground_to_net / CourtConstants.COURT_WIDTH_METERS


## How much legal court lies along one bearing from one contact point.
##
## Returns the window of ground distances, in metres, over which a ball on this
## bearing would land in bounds -- `near_meters` where the ray crosses into the
## opponent's half, `far_meters` where it leaves the court over a sideline or
## the endline. A bearing that never enters the court, or that clips it for less
## than `MIN_USABLE_SPAN_METERS`, reports `reaches_court = false`.
##
## This is the antenna and sideline constraint. The net-height constraint is not
## here -- that is a vertical question and belongs to the flight.
static func court_span_for_bearing(
	contact: Vector2,
	bearing_degrees: float,
	attacking_negative_y: bool,
) -> Dictionary:
	var direction := direction_meters(bearing_degrees, attacking_negative_y)
	## The legal landing box, as metric offsets from the contact.
	var x_low := (COURT_MIN_X - contact.x) * CourtConstants.COURT_WIDTH_METERS
	var x_high := (COURT_MAX_X - contact.x) * CourtConstants.COURT_WIDTH_METERS
	var far_line := 0.0 if attacking_negative_y else 1.0
	var y_net := (CourtConstants.NET_Y - contact.y) * CourtConstants.COURT_LENGTH_METERS
	var y_end := (far_line - contact.y) * CourtConstants.COURT_LENGTH_METERS
	var y_low := minf(y_net, y_end)
	var y_high := maxf(y_net, y_end)

	var enter := 0.0
	var exit := INF
	var slab_x := _slab(direction.x, x_low, x_high)
	var slab_y := _slab(direction.y, y_low, y_high)
	if not bool(slab_x.hit) or not bool(slab_y.hit):
		return {"reaches_court": false, "near_meters": 0.0, "far_meters": 0.0}
	enter = maxf(enter, maxf(float(slab_x.enter), float(slab_y.enter)))
	exit = minf(float(slab_x.exit), float(slab_y.exit))
	if exit <= enter or exit - enter < MIN_USABLE_SPAN_METERS:
		return {"reaches_court": false, "near_meters": 0.0, "far_meters": 0.0}
	return {
		"reaches_court": true,
		"near_meters": enter,
		"far_meters": exit,
		"span_meters": exit - enter,
	}


## One axis of the slab test. A ray parallel to an axis either sits inside that
## axis's band for its whole length or misses entirely.
static func _slab(
	component: float,
	low: float,
	high: float,
) -> Dictionary:
	if absf(component) < 0.000001:
		if low <= 0.0 and high >= 0.0:
			return {"hit": true, "enter": 0.0, "exit": INF}
		return {"hit": false, "enter": 0.0, "exit": 0.0}
	var first := low / component
	var second := high / component
	return {
		"hit": true,
		"enter": minf(first, second),
		"exit": maxf(first, second),
	}


## What a hitter loses by turning the ball off the line they ran in on.
##
## `power_fraction` is what remains of their intended speed and
## `spread_multiplier` scales their aiming error, both worsening with the angle
## turned. A ball struck across the body is neither as hard nor as accurate as
## one struck through the approach.
##
## Provisional magnitudes -- Gate D calibrates them. What matters structurally
## is that the cost is a function of the *offset from the approach*, not of the
## absolute bearing, so the same shot is cheap for a hitter who ran at it and
## expensive for one who has to turn back across themselves.
## Lifted from 0.72 with the two floors in `AttackPowerModel`: see
## `CEILING_MIN_MPS`. Turning the ball across the body still costs pace and
## still costs far more accuracy, which is the part that makes the shot a
## choice; it was the compounding of four separate discounts that left a spike
## travelling at 12.6 m/s.
const ACROSS_BODY_POWER_FLOOR: float = 0.82
const ACROSS_BODY_SPREAD_CEILING: float = 2.10


static func swing_cost(
	offset_degrees: float,
	swing_range_degrees: float,
) -> Dictionary:
	var reach := maxf(swing_range_degrees, 0.0001)
	var strain := clampf(absf(offset_degrees) / reach, 0.0, 1.0)
	return {
		"within_repertoire": absf(offset_degrees) <= swing_range_degrees,
		"strain": strain,
		"power_fraction": lerpf(1.0, ACROSS_BODY_POWER_FLOOR, strain),
		"spread_multiplier": lerpf(1.0, ACROSS_BODY_SPREAD_CEILING, strain),
	}


## The line the hitter is already travelling, continued forward.
##
## Read off the run-up rather than assumed to be the net normal, so a hitter who
## approached from outside naturally swings across and has to turn back to hit
## down the line. `_approach_start_position()` already offsets a pin's run-up
## toward their own sideline, so the lean and its sign come out of geometry the
## engine had all along.
static func natural_bearing_from_approach(
	approach_start: Vector2,
	contact: Vector2,
	attacking_negative_y: bool,
) -> float:
	return bearing_to_point(approach_start, contact, attacking_negative_y)


## Every course this hitter could credibly swing, sampled across their
## repertoire cone and filtered to the ones that reach the floor in bounds.
##
## `swing_range_degrees` is the repertoire gate -- how far off their natural
## swing line this hitter can turn the ball. It replaces `swing_range`, which
## was a symmetric window in *x* and therefore offered a left-pin hitter the
## same reach toward a sideline 0.065 away as toward one 0.825 away.
static func available_courses(
	contact: Vector2,
	natural_bearing_degrees: float,
	swing_range_degrees: float,
	attacking_negative_y: bool,
	sample_count: int = 25,
) -> Array[Dictionary]:
	var courses: Array[Dictionary] = []
	var samples := maxi(sample_count, 2)
	var reach := maxf(swing_range_degrees, 0.0)
	for index in range(samples):
		var fraction := float(index) / float(samples - 1)
		var bearing := natural_bearing_degrees + lerpf(-reach, reach, fraction)
		if absf(bearing) > MAX_COURSE_BEARING_DEGREES:
			continue
		var span := court_span_for_bearing(contact, bearing, attacking_negative_y)
		if not bool(span.reaches_court):
			continue
		var offset := bearing - natural_bearing_degrees
		var cost := swing_cost(offset, reach)
		courses.append({
			"bearing_degrees": bearing,
			"near_meters": float(span.near_meters),
			"far_meters": float(span.far_meters),
			"span_meters": float(span.span_meters),
			"offset_degrees": offset,
			"power_fraction": float(cost.power_fraction),
			"spread_multiplier": float(cost.spread_multiplier),
			"strain": float(cost.strain),
		})
	return courses


## `available_courses` with the natural line read off the run-up instead of
## passed in. This is the entry point a hitter's decision layer uses.
static func courses_from_approach(
	contact: Vector2,
	approach_start: Vector2,
	swing_range_degrees: float,
	attacking_negative_y: bool,
	sample_count: int = 25,
) -> Array[Dictionary]:
	return available_courses(
		contact,
		natural_bearing_from_approach(
			approach_start, contact, attacking_negative_y
		),
		swing_range_degrees,
		attacking_negative_y,
		sample_count,
	)


## Where a ball on this bearing lands, at this ground distance, in court
## coordinates. The bridge back from the metric frame the physics works in.
static func landing_point(
	contact: Vector2,
	bearing_degrees: float,
	distance_meters: float,
	attacking_negative_y: bool,
) -> Vector2:
	var direction := direction_meters(bearing_degrees, attacking_negative_y)
	return Vector2(
		contact.x + direction.x * distance_meters
			/ CourtConstants.COURT_WIDTH_METERS,
		contact.y + direction.y * distance_meters
			/ CourtConstants.COURT_LENGTH_METERS,
	)


## The bearing that carries a ball from this contact to this point. Inverse of
## `landing_point`, for reading an existing target as a course.
static func bearing_to_point(
	contact: Vector2,
	target: Vector2,
	attacking_negative_y: bool,
) -> float:
	var across := (target.x - contact.x) * CourtConstants.COURT_WIDTH_METERS
	var along := (target.y - contact.y) * CourtConstants.COURT_LENGTH_METERS
	var forward := -along if attacking_negative_y else along
	return rad_to_deg(atan2(across, forward))
