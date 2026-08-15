class_name BlockDeflectionModel
extends RefCounted

## Where a ball goes after it hits a wall, and how fast.
##
## Until now it went nowhere. `AttackResolutionModel.resolve` returned the
## moment a blocker touched the ball with `result["landing"]` still holding the
## **unimpeded** arc's landing -- the point the swing would have reached if the
## block had not been there. There was no deflection geometry anywhere in the
## engine: no direction off the hands, no landing, no pace. Everything
## downstream reconstructed it from two endpoints and a duration, which is why
## a blocked ball was drawn flying past the block to a place it never got to.
##
## The four kinds are already classified by `_block_contact` and they are four
## different events, not one event with a severity dial:
##
## | kind | what the hands did | where it goes | what it keeps |
## |---|---|---|---|
## | `stuff` | pressed over the top | straight down, hitter's side | most of its pace |
## | `recycle` | central hand, not fully pressed | up and back, hitter's side | very little |
## | `tool` | glanced off the outside hand | wide, past the sideline | a good share |
## | `touch` | fingertips under it | up and back, blockers' side | very little |
##
## A stuff is not a soft block turned up. The hands are over the ball and above
## it, so the ball is *redirected* rather than absorbed -- it comes down steeply
## and it comes down hard, which is the whole reason a stuff ends a rally
## instead of starting a scramble. A touch is the opposite trade on purpose:
## the pace is what the block is trying to take, so the floor behind it can
## play the ball.

## How much of the incoming speed survives each kind of contact.
##
## Ordered by how much of the ball's momentum the hands oppose rather than
## absorb. A stuff meets the ball with a braced arm travelling *into* it, so it
## keeps most of what it arrived with; a touch is a hand giving way under it.
const STUFF_PACE_KEPT: float = 0.72
const TOOL_PACE_KEPT: float = 0.60
const RECYCLE_PACE_KEPT: float = 0.12
## Rebased after attack pace moved into the 25-50 m/s band. At 0.28 an elite
## swing still left the fingertips at 15 m/s, enough to be rising above five
## metres when it reached the baseline; coverage then appeared underneath it.
## A soft block gives with the ball. Sixteen per cent preserves a playable pop
## while keeping even the hardest ordinary touch inside a defensive flight.
const TOUCH_PACE_KEPT: float = 0.16

## How steeply each kind leaves the hands, in degrees below horizontal.
##
## Negative is downward. A stuff is the steepest thing that happens in a rally
## short of the floor; a touch goes *up*, which is what makes it playable.
const STUFF_DESCENT_DEGREES: float = -62.0
const TOOL_DESCENT_DEGREES: float = -18.0
const RECYCLE_RISE_DEGREES: float = 18.0
const TOUCH_RISE_DEGREES: float = 26.0

## How far from the net a stuffed ball comes down, as a fraction of a half
## court, at the two ends of the pace range.
##
## Even a stuff driven hard lands close: the ball is going down more than it is
## going back. The range exists so that a stuff off a slow swing does not land
## in the same square as one off the hitter's best ball.
const STUFF_NEAR_FRACTION: float = 0.06
const STUFF_FAR_FRACTION: float = 0.22
## The swing speed at which a stuff reaches the far end of that range.
const STUFF_PACE_REFERENCE_MPS: float = 22.0

## How far past the sideline a tooled ball crosses. Out is out, but a drawn ball
## has to land somewhere, and a tool that lands 2 cm outside reads as a line
## call rather than as the hitter beating the block.
const TOOL_OUTSIDE_FRACTION: float = 0.14

## How far back into the blockers' court a touched ball drops.
##
## Deep enough that the floor defence has to move for it, which is the point of
## the kind existing: a touch that landed at the blockers' feet would be a stuff
## that had not committed.
const TOUCH_DEPTH_FRACTION: float = 0.34
## And how far the deflection carries across the court, at most.
const TOUCH_LATERAL_FRACTION: float = 0.12
## A coverable rebound stays in front of the attack line. The physical flight
## determines its ordinary depth; this cap prevents the hardest swing from
## turning a softened hand contact into a five-metre ricochet.
const RECYCLE_DEPTH_FRACTION: float = 0.28
const RECYCLE_LATERAL_FRACTION: float = 0.08
## A playable deflection is intercepted on a platform, not allowed to continue
## to the floor and then teleported back up into the defender's arms. This is
## the ordinary forearm height for the generated population; presentation uses
## the actual defender at the other end of the segment.
const PLAYABLE_CONTACT_HEIGHT_METERS: float = 0.98
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")


## The ball's flight after the wall, in normalised court coordinates.
##
## `crossing_x` is where it met the hands across the net, 0 to 1.
## `attacking_negative_y` is the hitter's direction of travel, so the hitter's
## own half is the one they are hitting *away* from.
##
## Returns `landing`, `speed_mps`, `vertical_angle_degrees` and `playable` --
## the last of which is the difference between a rally that continues and one
## that does not, and is a property of the deflection rather than of a table
## somewhere else.
static func deflect(
	kind: String,
	crossing_x: float,
	incoming_speed_mps: float,
	attacking_negative_y: bool,
	contact_height_meters: float = CourtConstants.NET_HEIGHT_METERS,
) -> Dictionary:
	var lane := clampf(crossing_x, 0.0, 1.0)
	## The half the ball came from. A stuff goes back into it; a touch and a
	## tool carry on across the net.
	var hitter_side := 1.0 if attacking_negative_y else -1.0
	match kind:
		"stuff":
			var speed := incoming_speed_mps * STUFF_PACE_KEPT
			var flight := BallFlightModel.solve_flight(
				speed, STUFF_DESCENT_DEGREES, contact_height_meters
			)
			var pace := clampf(
				incoming_speed_mps / STUFF_PACE_REFERENCE_MPS, 0.0, 1.0
			)
			## The old depth table and the outgoing speed/angle were three
			## independent descriptions of one ball. Prefer the physical range, but
			## retain the table as a generous safety bound for legacy-low speeds.
			var depth := minf(
				float(flight.range_meters) / CourtConstants.COURT_LENGTH_METERS,
				lerpf(STUFF_NEAR_FRACTION, STUFF_FAR_FRACTION, pace),
			)
			return {
				"landing": Vector2(
					lane, clampf(CourtConstants.NET_Y + hitter_side * depth, 0.0, 1.0)
				),
				"speed_mps": speed,
				"vertical_angle_degrees": STUFF_DESCENT_DEGREES,
				"duration_seconds": float(flight.duration_seconds),
				"apex_height_meters": float(flight.apex_height_meters),
				"vertical_speed_mps": float(flight.vertical_speed_mps),
				## A ball driven down at 60 degrees into the court you just swung
				## from is the one contact in this table nobody digs.
				"playable": false,
			}
		"tool":
			## Off whichever hand was nearer the edge, which is whichever
			## sideline the ball was already closer to.
			var outward := 1.0 if lane >= 0.5 else -1.0
			return {
				"landing": Vector2(
					clampf(
						lane + outward * TOOL_OUTSIDE_FRACTION + outward * 0.5,
						-0.4, 1.4,
					),
					clampf(CourtConstants.NET_Y - hitter_side * 0.18, 0.0, 1.0),
				),
				"speed_mps": incoming_speed_mps * TOOL_PACE_KEPT,
				"vertical_angle_degrees": TOOL_DESCENT_DEGREES,
				"playable": false,
			}
		"recycle":
			## Back onto the hitter's side, but with enough lift and pace removed
			## for the coverage shape to play it. This is deliberately not the
			## `touch` default below, which continues behind the blocking wall.
			var speed := incoming_speed_mps * RECYCLE_PACE_KEPT
			var flight := _playable_flight(
				speed, RECYCLE_RISE_DEGREES, contact_height_meters
			)
			var across := (lane - 0.5) * RECYCLE_LATERAL_FRACTION
			var depth := minf(
				float(flight.range_meters) / CourtConstants.COURT_LENGTH_METERS,
				RECYCLE_DEPTH_FRACTION,
			)
			return {
				"landing": Vector2(
					clampf(lane + across, 0.02, 0.98),
					clampf(
						CourtConstants.NET_Y + hitter_side * depth,
						0.0, 1.0,
					),
				),
				"speed_mps": speed,
				"vertical_angle_degrees": RECYCLE_RISE_DEGREES,
				"duration_seconds": float(flight.duration_seconds),
				"apex_height_meters": float(flight.apex_height_meters),
				"vertical_speed_mps": float(flight.vertical_speed_mps),
				"playable": true,
			}
		_:
			## A touch. Up off the hands and back into the court behind them,
			## with most of the pace gone -- which is exactly what the blockers
			## were trying to achieve and what their own floor is standing there
			## to collect.
			var speed := incoming_speed_mps * TOUCH_PACE_KEPT
			var flight := _playable_flight(
				speed, TOUCH_RISE_DEGREES, contact_height_meters
			)
			var across := (lane - 0.5) * TOUCH_LATERAL_FRACTION
			var depth := float(flight.range_meters) \
				/ CourtConstants.COURT_LENGTH_METERS
			return {
				"landing": Vector2(
					clampf(lane + across, 0.02, 0.98),
					clampf(
						CourtConstants.NET_Y - hitter_side * depth,
						0.0, 1.0,
					),
				),
				"speed_mps": speed,
				"vertical_angle_degrees": TOUCH_RISE_DEGREES,
				"duration_seconds": float(flight.duration_seconds),
				"apex_height_meters": float(flight.apex_height_meters),
				"vertical_speed_mps": float(flight.vertical_speed_mps),
				"playable": true,
			}


## The descending root at platform height. `solve_flight()` intentionally runs
## to the floor, which is right for a stuff and wrong for a ball somebody plays
## before it lands. Returning the contact-range and contact-time together keeps
## the defender, the endpoint, and the visible arc on the same flight.
static func _playable_flight(
	speed_mps: float,
	launch_angle_degrees: float,
	contact_height_meters: float,
) -> Dictionary:
	var speed := maxf(speed_mps, BallFlightModel.MIN_SPEED_MPS)
	var angle := clampf(
		launch_angle_degrees,
		BallFlightModel.MIN_LAUNCH_ANGLE_DEGREES,
		BallFlightModel.MAX_LAUNCH_ANGLE_DEGREES,
	)
	var radians := deg_to_rad(angle)
	var vertical := speed * sin(radians)
	var horizontal := speed * cos(radians)
	var height := maxf(contact_height_meters, PLAYABLE_CONTACT_HEIGHT_METERS)
	var drop := maxf(height - PLAYABLE_CONTACT_HEIGHT_METERS, 0.0)
	var gravity := BallFlightModel.DEFAULT_GRAVITY_MPS2
	var duration := (
		vertical + sqrt(vertical * vertical + 2.0 * gravity * drop)
	) / gravity
	duration = maxf(duration, BallFlightModel.MIN_FLIGHT_DURATION)
	var apex := height
	if vertical > 0.0:
		apex += vertical * vertical / (2.0 * gravity)
	return {
		"range_meters": maxf(horizontal * duration, 0.0),
		"duration_seconds": duration,
		"apex_height_meters": apex,
		"vertical_speed_mps": vertical,
		"horizontal_speed_mps": horizontal,
		"contact_height_meters": height,
		"end_height_meters": PLAYABLE_CONTACT_HEIGHT_METERS,
	}
