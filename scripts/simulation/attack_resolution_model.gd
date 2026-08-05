class_name AttackResolutionModel
extends RefCounted

## What the ball actually did, from the swing that was actually made.
##
## Gate C. This is the piece that makes the whole exercise worth it: outcome,
## geometry and the drawn arc stop being three computations that have to be kept
## in agreement by hand and become one. The rally does not roll for in or out
## and then relocate the ball to match -- the ball flies, and where it ends up
## *is* the verdict.
##
## Everything is read off one flight, in this order, because that is the order
## the ball meets them:
##
## 1. **the tape** -- below net height at the net plane, it does not get across
## 2. **the antennae** -- crossing outside the sidelines is out of bounds in the
##    air, before anything downstream matters
## 3. **the block** -- hands that are up, in the lane, and above the ball
## 4. **the floor** -- in or out, and which line it crossed
##
## Nothing here rolls a die. Every branch is a comparison against a number the
## swing produced, which is what allows an attack error to be *shown* -- the
## ball is long because it was struck too flat and too hard, and playback draws
## exactly that.

const CourtConstants := preload("res://scripts/data/court_constants.gd")
const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const AttackReadModel := preload("res://scripts/simulation/attack_read_model.gd")
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const BlockJumpModel := preload("res://scripts/simulation/block_jump_model.gd")

## Where on the hands the ball met them, which decides what comes off.
##
## `reach_height_m` is the highest a blocker can touch, so a ball arriving well
## *below* it is one they are pressing down on with penetrating hands -- that is
## the stuff. A ball arriving just under it is fingertips, and deflects up into
## a playable touch. A ball clipping the last few centimetres of the outside
## hand goes out of play and is the hitter's point, not the blocker's.
##
## Calibrated in Gate D. A hand and forearm above the tape present roughly half
## a metre of surface, so this is the line between pressing down on a ball and
## getting a piece of one on the way past. It went 0.25 -> 0.15 when a test
## found 0.25 was calling mid-palm contact a fingertip graze, then settled at
## 0.21 in the Gate D sweep. It is the constant that separates the block being
## *involved* from the block *ending* the rally, and the design wants a lot of
## the first and little of the second.
##
## `TOOL_EDGE_MARGIN` narrowed 0.12 -> 0.08 in the same pass. It is a share of
## the sealed lane, so when the lane narrowed a fixed 0.12 turned a third of
## every block into an edge contact and tools stopped being rare.
const TOOL_EDGE_MARGIN_METERS: float = 0.08
const STUFF_DEPTH_METERS: float = 0.21
## How the two geometric thresholds bend with the blocker's jump timing.
##
## `STUFF_DEPTH_METERS` is how far below the hands a ball has to cross before the
## block puts it down rather than merely slowing it, and it was a single figure
## for every blocker in every state. A blocker meeting the ball at the apex needs
## less of it -- their hands are locked out and angled over -- so the requirement
## scales down to `TIMING_STUFF_DEPTH_SPAN` of itself at perfect timing.
##
## Hands on the way down are the case the sport punishes hardest, so they are
## charged twice: the depth needed for a stuff goes back up, and the outside edge
## they can be tooled off widens, because a dropping hand's effective edge is
## inside where the hand actually is.
## How much a blocker's jump timing is worth against the depth their hands need.
##
## The design dial this whole model exists to expose: at zero, timing changes
## nothing and the block is the height comparison it has always been; at one, a
## blocker at half the reference effectiveness needs half again the depth to put
## a ball down. It is set against the measured stuff rate rather than picked,
## because what a calibration is entitled to decide is how much a term matters --
## not to quietly move the aggregate while claiming to add a term.
const TIMING_STUFF_SENSITIVITY: float = 1.0

## Only the tool widening lives here now. How much height and arm direction are
## worth is the jump's business, and `BlockJumpModel` returns them combined as one
## centred `effectiveness` so this threshold is scaled exactly once.
const TIMING_DESCENDING_TOOL_WIDENING: float = 1.45

## How far onto the hitter's own side a netted ball drops. Normalized, ~0.2 m.
const NETTED_DROP_OFFSET: float = 0.012


static func resolve(
	contact: Vector2,
	contact_height_meters: float,
	bearing_degrees: float,
	vertical_angle_degrees: float,
	speed_mps: float,
	blockers: Array,
	attacking_negative_y: bool,
) -> Dictionary:
	var flight := BallFlightModel.solve_flight(
		speed_mps, vertical_angle_degrees, contact_height_meters
	)
	var direction := AttackCourseModel.direction_meters(
		bearing_degrees, attacking_negative_y
	)
	var result := {
		"flight": flight,
		"bearing_degrees": bearing_degrees,
		"landing": contact,
		"net_crossing_x": contact.x,
		"net_clearance_meters": 0.0,
		"block": {},
		"out_reason": "",
		"outcome": "in",
	}

	## --- 1. The tape -------------------------------------------------------
	var to_net_meters := (CourtConstants.NET_Y - contact.y) \
		* CourtConstants.COURT_LENGTH_METERS
	var ground_to_net := 0.0
	if absf(direction.y) > 0.000001:
		ground_to_net = to_net_meters / direction.y
	if ground_to_net < 0.0:
		ground_to_net = 0.0
	var height_at_net := BallFlightModel.height_at_distance(flight, ground_to_net)
	## The same geometry a blocker uses to decide where to stand, asked from the
	## other end. Shared so the wall and the ball cannot be placed by two
	## different formulas.
	var crossing_x := AttackCourseModel.net_crossing_x(
		contact, bearing_degrees, attacking_negative_y
	)
	result["net_crossing_x"] = crossing_x
	result["net_clearance_meters"] = height_at_net - CourtConstants.NET_HEIGHT_METERS
	result["landing"] = AttackCourseModel.landing_point(
		contact, bearing_degrees, float(flight.range_meters), attacking_negative_y
	)
	if float(flight.range_meters) < ground_to_net \
			or height_at_net < CourtConstants.NET_HEIGHT_METERS:
		result["outcome"] = "net"
		result["out_reason"] = "net"
		## A ball stopped by the tape drops on the side it was struck from, not
		## wherever the unimpeded arc would have carried it. The hitter's own
		## half is the one the ball came *from*, which is the far side of the net
		## from the direction of travel.
		var own_side_y := CourtConstants.NET_Y \
			+ (NETTED_DROP_OFFSET if attacking_negative_y else -NETTED_DROP_OFFSET)
		result["landing"] = Vector2(clampf(crossing_x, 0.02, 0.98), own_side_y)
		return result

	## --- 2. The antennae ---------------------------------------------------
	if crossing_x < 0.0 or crossing_x > 1.0:
		result["outcome"] = "out"
		result["out_reason"] = "antenna"
		return result

	## --- 3. The block ------------------------------------------------------
	var block_miss: Dictionary = {}
	var contacted := _block_contact(
		crossing_x, height_at_net, blockers, block_miss
	)
	if not contacted.is_empty():
		result["block"] = contacted
		result["outcome"] = "blocked"
		return result
	result["block_miss_reason"] = str(block_miss.get("reason", ""))
	result["net_height_over_block_meters"] = height_at_net - _tallest_reach(blockers)
	## How far past the nearest hand the ball crossed, in metres. A wall beaten by
	## a hand's width is a width problem; one beaten by a metre is standing in the
	## wrong place, and widening it would only be a bound stretched to swallow a
	## distribution it was never cutting.
	result["block_edge_miss_meters"] = float(
		block_miss.get("edge_miss_meters", 0.0)
	)

	## --- 4. The floor ------------------------------------------------------
	var landing: Vector2 = result["landing"]
	var far_line := 0.0 if attacking_negative_y else 1.0
	var beyond_endline := landing.y < far_line if attacking_negative_y \
		else landing.y > far_line
	var outside_sideline := landing.x < 0.0 or landing.x > 1.0
	if outside_sideline or beyond_endline:
		result["outcome"] = "out"
		result["out_reason"] = "wide" if outside_sideline else "long"
	return result


## The highest hand in the wall, or zero if there is no wall.
static func _tallest_reach(blockers: Array) -> float:
	var tallest := 0.0
	for blocker in blockers:
		tallest = maxf(tallest, float(blocker.get("reach_height_m", 0.0)))
	return tallest


## Which blocker the ball met, and what that means.
##
## Returns an empty dictionary when nothing touched it -- either because every
## blocker was short of it or because it passed outside their hands.
static func _block_contact(
	crossing_x: float,
	height_at_net: float,
	blockers: Array,
	## Filled with why nothing touched the ball, when nothing did, and by how far.
	## Whether a wall was beaten *over* or *around* is the difference between a
	## reach problem and a positioning one, and the two want opposite fixes.
	miss_detail: Dictionary = {},
) -> Dictionary:
	var over := false
	var around := false
	## The closest any hand came, over all blockers, as a negative gap in metres.
	var nearest_edge_miss := -INF
	for blocker in blockers:
		var reach := float(blocker.get("reach_height_m", 3.0))
		if height_at_net > reach:
			over = true
			continue
		var half_width := float(blocker.get("half_width_m", 0.45))
		var lateral := absf(crossing_x - float(blocker.get("net_x", 0.5))) \
			* CourtConstants.COURT_WIDTH_METERS
		var edge_gap := half_width - lateral
		if edge_gap < 0.0:
			around = true
			nearest_edge_miss = maxf(nearest_edge_miss, edge_gap)
			continue
		var depth_below := reach - height_at_net
		## Timing, which is what actually separates a stuff from a tool.
		##
		## Depth below the hands and distance from the outside edge are both
		## geometry, and geometry alone says a blocker who peaked half a second
		## early does the same thing to the ball as one who met it at full
		## extension. They do not. Arms still rising into a locked-out position
		## present a surface angled down into the court; arms already falling
		## present the same surface tilted back off a height that is shrinking as
		## the ball reaches it, and that is what a hitter tools.
		##
		## So the two geometric thresholds bend around the timing rather than
		## being replaced by it. A blocker who met the ball at the apex stuffs on
		## less depth than one who did not, and a blocker whose hands are on the
		## way down is tooled from further inside their own edge -- the effective
		## edge of a dropping hand is not where the hand is.
		var stuff_depth := STUFF_DEPTH_METERS
		var tool_margin := TOOL_EDGE_MARGIN_METERS
		if blocker.get("block_effectiveness", null) != null:
			## Centred on the population, so a blocker timing the ball the way the
			## average blocker times it meets exactly the constants Gate D
			## calibrated and only the spread either side is new. Scaling straight
			## off the raw timing instead took stuff from 12.0% to 18.9% while
			## involvement did not move -- adding timing and rebalancing the wall
			## at the same time, which no later sweep could have separated.
			var relative := clampf(
				float(blocker.get("block_effectiveness", 0.0)), 0.05, 2.0
			) / BlockJumpModel.REFERENCE_EFFECTIVENESS
			## Better timing asks less depth of the ball, because the hands are
			## higher and angled over it rather than tilted back off it.
			##
			## Linear in the deviation rather than reciprocal. Dividing by the
			## relative effectiveness is convex and unbounded below, so it does
			## not centre where its mean says it should -- a blocker at half the
			## reference got twice the threshold while one at double got only
			## half off, and the stuff rate came out at 15.8% against the 12.0%
			## the flat constant produced. This is exactly `STUFF_DEPTH_METERS` at
			## the reference and symmetric either side of it.
			stuff_depth = STUFF_DEPTH_METERS * maxf(
				1.0 + TIMING_STUFF_SENSITIVITY * (1.0 - relative), 0.15
			)
			## And a dropping hand is tooled from further inside its own edge,
			## because its effective edge is not where the hand is. Only the
			## falling case: hands still on the way up are extended and angled
			## over, merely lower than they will get, and that height is already
			## priced into the reach.
			if str(blocker.get("arm_state", "extended")) == "descending":
				tool_margin *= TIMING_DESCENDING_TOOL_WIDENING
		var kind := "touch"
		if edge_gap < tool_margin:
			## Off the outside hand and away. This one is the hitter's point.
			kind = "tool"
		elif depth_below > stuff_depth:
			kind = "stuff"
		return {
			"kind": kind,
			"blocker": blocker,
			"height_at_net_meters": height_at_net,
			"depth_below_reach_meters": depth_below,
			"edge_gap_meters": edge_gap,
		}
	if blockers.is_empty():
		miss_detail["reason"] = "no wall"
	elif over and around:
		miss_detail["reason"] = "over and around"
	elif over:
		miss_detail["reason"] = "over"
	elif around:
		miss_detail["reason"] = "around"
	if is_finite(nearest_edge_miss):
		miss_detail["edge_miss_meters"] = nearest_edge_miss
	return {}
