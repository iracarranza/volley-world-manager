class_name AttackReadModel
extends RefCounted

## What the hitter believes is open, and how open it actually is.
##
## Two separate jobs, deliberately kept apart.
##
## **Perception** degrades the truth. A poor reader does not get handed the
## right answer and then flip a coin about using it -- which is what
## `_choose_attack_target()` does today, picking either the scan's best target
## or a fixed fallback down their own line. That produces two behaviours and no
## middle: perfect play or a stock mistake, never a plausible misread. Here the
## *inputs* are blurred instead, so a hitter commits confidently to a picture
## that is slightly wrong and is wrong in a way that looks like volleyball.
##
## **Scoring** rates a course against a picture. The current scan never looks at
## the block at all -- it ranks candidate floor points by distance to the
## nearest defender, so a hitter picks where defenders are not while ignoring
## the wall directly in front of them. Openness here is the lesser of the two:
## the gap past the block at the net, and the gap from the defence at the floor.
##
## Blockers are described as `{net_x, reach_height_m, half_width_m}` -- where
## they are along the net in normalized x, how high they get, and how much lane
## their hands actually seal. Positions are normalized court coordinates;
## distances that matter physically are metres.

const CourtConstants := preload("res://scripts/data/court_constants.gd")
const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

## How badly a poor reader misplaces what they are looking at. A blocker seen
## half a metre from where they are is an ordinary misread; the reach error is
## smaller because height is easier to judge than lateral position at speed.
const BLOCKER_POSITION_ERROR_M: float = 0.55
const BLOCKER_REACH_ERROR_M: float = 0.22
const DEFENDER_POSITION_ERROR_M: float = 1.30

## Openness past this is a free swing; nothing is gained by being further from
## a defender than a defender can travel in the time available anyway.
const OPENNESS_SATURATION_M: float = 4.0


## The block as this hitter sees it.
##
## `reading` is their court vision and decision making, 0-1. `draws` are signed
## unit-scaled values supplied by the caller -- two per blocker, position then
## reach -- so seeded replay stays the simulator's business.
static func perceived_blockers(
	blockers: Array,
	reading: float,
	draws: Array,
) -> Array[Dictionary]:
	var blur := 1.0 - clampf(reading, 0.0, 1.0)
	var seen: Array[Dictionary] = []
	for index in range(blockers.size()):
		var actual: Dictionary = blockers[index]
		var position_draw := float(draws[index * 2]) if draws.size() > index * 2 else 0.0
		var reach_draw := float(draws[index * 2 + 1]) if draws.size() > index * 2 + 1 else 0.0
		seen.append({
			"net_x": clampf(
				float(actual.get("net_x", 0.5))
					+ position_draw * blur * BLOCKER_POSITION_ERROR_M
						/ CourtConstants.COURT_WIDTH_METERS,
				0.0, 1.0,
			),
			"reach_height_m": maxf(
				float(actual.get("reach_height_m", 3.0))
					+ reach_draw * blur * BLOCKER_REACH_ERROR_M,
				0.0,
			),
			## Not blurred. How much lane a pair of hands seals is a fact about
			## the block's shape rather than something a hitter reads off it in
			## the air, and blurring it would double-count the position error.
			"half_width_m": float(actual.get("half_width_m", 0.45)),
		})
	return seen


## The floor defence as this hitter sees it, in normalized court coordinates.
static func perceived_defenders(
	defenders: Array,
	reading: float,
	draws: Array,
) -> Array[Vector2]:
	var blur := 1.0 - clampf(reading, 0.0, 1.0)
	var seen: Array[Vector2] = []
	for index in range(defenders.size()):
		var actual: Vector2 = defenders[index]
		var x_draw := float(draws[index * 2]) if draws.size() > index * 2 else 0.0
		var y_draw := float(draws[index * 2 + 1]) if draws.size() > index * 2 + 1 else 0.0
		seen.append(Vector2(
			clampf(
				actual.x + x_draw * blur * DEFENDER_POSITION_ERROR_M
					/ CourtConstants.COURT_WIDTH_METERS,
				0.0, 1.0,
			),
			clampf(
				actual.y + y_draw * blur * DEFENDER_POSITION_ERROR_M
					/ CourtConstants.COURT_LENGTH_METERS,
				0.0, 1.0,
			),
		))
	return seen


## Where a course crosses the plane of the net, in normalized x.
##
## This is the question the block actually poses. A course is not "blocked"
## because a blocker is near the hitter or near the landing point -- it is
## blocked because the ball passes through the piece of net that blocker's hands
## are occupying.
static func net_crossing_x(
	contact: Vector2,
	bearing_degrees: float,
	attacking_negative_y: bool,
) -> float:
	var direction := AttackCourseModel.direction_meters(
		bearing_degrees, attacking_negative_y
	)
	if absf(direction.y) < 0.000001:
		return contact.x
	var along_to_net := (CourtConstants.NET_Y - contact.y) \
		* CourtConstants.COURT_LENGTH_METERS
	var travel := along_to_net / direction.y
	if travel < 0.0:
		return contact.x
	return contact.x + direction.x * travel / CourtConstants.COURT_WIDTH_METERS


## How much room a course has past the block, in metres of lane.
##
## Negative means the ball passes through sealed net. `flight` is optional: with
## it, a blocker the ball clears overhead stops mattering, which is what lets a
## high contact beat a short block rather than merely a wide one.
static func block_clearance_meters(
	contact: Vector2,
	bearing_degrees: float,
	blockers: Array,
	attacking_negative_y: bool,
	flight: Dictionary = {},
) -> float:
	if blockers.is_empty():
		return OPENNESS_SATURATION_M
	var crossing := net_crossing_x(contact, bearing_degrees, attacking_negative_y)
	var ball_height := -1.0
	if not flight.is_empty():
		var to_net := absf(
			(CourtConstants.NET_Y - contact.y) * CourtConstants.COURT_LENGTH_METERS
		)
		var direction := AttackCourseModel.direction_meters(
			bearing_degrees, attacking_negative_y
		)
		var ground := to_net / maxf(absf(direction.y), 0.0001)
		ball_height = BallFlightModel.height_at_distance(flight, ground)
	var clearance := OPENNESS_SATURATION_M
	for blocker in blockers:
		var reach := float(blocker.get("reach_height_m", 3.0))
		## Struck over the top of them: this blocker is not in this shot.
		if ball_height >= 0.0 and ball_height > reach:
			continue
		var gap := absf(crossing - float(blocker.get("net_x", 0.5))) \
			* CourtConstants.COURT_WIDTH_METERS \
			- float(blocker.get("half_width_m", 0.45))
		clearance = minf(clearance, gap)
	return clampf(clearance, -OPENNESS_SATURATION_M, OPENNESS_SATURATION_M)


## How far the nearest defender is from where the ball would land, in metres.
static func floor_clearance_meters(landing: Vector2, defenders: Array) -> float:
	if defenders.is_empty():
		return OPENNESS_SATURATION_M
	var nearest := OPENNESS_SATURATION_M
	for defender in defenders:
		nearest = minf(nearest, Vector2(
			(landing.x - (defender as Vector2).x) * CourtConstants.COURT_WIDTH_METERS,
			(landing.y - (defender as Vector2).y) * CourtConstants.COURT_LENGTH_METERS,
		).length())
	return clampf(nearest, 0.0, OPENNESS_SATURATION_M)


## How good a course looks, 0-1, against the picture the hitter believes.
##
## The two clearances are combined as a minimum rather than a sum, because a
## shot is only as good as its worst obstacle: threading the block into a
## waiting libero is not half a good shot, and neither is an open floor behind a
## sealed wall.
static func course_openness(
	contact: Vector2,
	bearing_degrees: float,
	landing: Vector2,
	blockers: Array,
	defenders: Array,
	attacking_negative_y: bool,
	flight: Dictionary = {},
) -> Dictionary:
	var past_block := block_clearance_meters(
		contact, bearing_degrees, blockers, attacking_negative_y, flight
	)
	var past_floor := floor_clearance_meters(landing, defenders)
	var block_score := clampf(past_block / OPENNESS_SATURATION_M, -1.0, 1.0)
	var floor_score := clampf(past_floor / OPENNESS_SATURATION_M, 0.0, 1.0)
	return {
		"block_clearance_meters": past_block,
		"floor_clearance_meters": past_floor,
		"into_the_block": past_block < 0.0,
		"openness": clampf(minf(block_score, floor_score), 0.0, 1.0),
	}
