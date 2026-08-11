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
## The three kinds are already classified by `_block_contact` and they are three
## different events, not one event with a severity dial:
##
## | kind | what the hands did | where it goes | what it keeps |
## |---|---|---|---|
## | `stuff` | pressed over the top | straight down, hitter's side | most of its pace |
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
const TOUCH_PACE_KEPT: float = 0.28

## How steeply each kind leaves the hands, in degrees below horizontal.
##
## Negative is downward. A stuff is the steepest thing that happens in a rally
## short of the floor; a touch goes *up*, which is what makes it playable.
const STUFF_DESCENT_DEGREES: float = -62.0
const TOOL_DESCENT_DEGREES: float = -18.0
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
) -> Dictionary:
	var lane := clampf(crossing_x, 0.0, 1.0)
	## The half the ball came from. A stuff goes back into it; a touch and a
	## tool carry on across the net.
	var hitter_side := 1.0 if attacking_negative_y else -1.0
	match kind:
		"stuff":
			var pace := clampf(
				incoming_speed_mps / STUFF_PACE_REFERENCE_MPS, 0.0, 1.0
			)
			var depth := lerpf(STUFF_NEAR_FRACTION, STUFF_FAR_FRACTION, pace)
			return {
				"landing": Vector2(
					lane, clampf(CourtConstants.NET_Y + hitter_side * depth, 0.0, 1.0)
				),
				"speed_mps": incoming_speed_mps * STUFF_PACE_KEPT,
				"vertical_angle_degrees": STUFF_DESCENT_DEGREES,
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
		_:
			## A touch. Up off the hands and back into the court behind them,
			## with most of the pace gone -- which is exactly what the blockers
			## were trying to achieve and what their own floor is standing there
			## to collect.
			var across := (lane - 0.5) * TOUCH_LATERAL_FRACTION
			return {
				"landing": Vector2(
					clampf(lane + across, 0.02, 0.98),
					clampf(
						CourtConstants.NET_Y - hitter_side * TOUCH_DEPTH_FRACTION,
						0.0, 1.0,
					),
				),
				"speed_mps": incoming_speed_mps * TOUCH_PACE_KEPT,
				"vertical_angle_degrees": TOUCH_RISE_DEGREES,
				"playable": true,
			}
