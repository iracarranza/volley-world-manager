class_name BlockPhaseModel
extends RefCounted

## What a blocker is doing at the net, as five states rather than two.
##
## Playback has a wall that is either up or not, and four separate reports come
## out of that one gap:
##
## - the blocker has no idle pose, so a front-row voli waiting to read the set
##   stands like a back-row one
## - blockers appear not to jump on swings the resolver says they contested
## - they hang in the air after the jump
## - and they translate sideways *while airborne* into a dig they should not be
##   making
##
## None of those is a simulation fault. `run_wall_reach_probe.gd` established
## the resolver's side is right -- every blocker in every wall has hands above
## the tape on 709 of 710 swings. The whole gap is in the drawing, and the
## drawing is missing the states.
##
## | state | what the body is doing | what it may do |
## |---|---|---|
## | `waiting` | hands up at the net, reading | move freely along the net |
## | `loading` | countermovement, weight down | still moving, committing |
## | `up` | rising to the ball | **nothing lateral** |
## | `committed` | at the top, hands over | **nothing lateral** |
## | `landing` | coming down, absorbing | recovering the ability to move |
##
## The two `nothing lateral` rows are the whole of the mid-air shuffle report. A
## body in the air travels on the momentum it left the floor with; it does not
## choose a new direction. Stating it as a property of the *state* rather than
## as a special case at the one call site that showed the bug is what keeps it
## fixed when the next call site is written.

## How long a block jump lasts, floor to floor, in seconds.
##
## **This is the hang.** The wall goes up during the set's flight and holds
## across the attack's, so the hold was as long as the attack's flight happened
## to be -- right for a fast swing and, on a slow roll shot, a blocker standing
## in the air for a second and a half. A jump is not a duration the ball gets to
## choose. It is a body's own, and a blocker whose read was early comes *down*
## before the ball arrives, which is a real volleyball event and is what the
## drawing should show instead of a hover.
const JUMP_SECONDS: float = 0.78
## Of that, the share spent going up. A jump is quicker to the top than back
## from it, because the way down is a landing being absorbed rather than a fall.
const RISE_SHARE: float = 0.42
## And the countermovement before it leaves the floor.
const LOAD_SECONDS: float = 0.22


## Which state a blocker is in, `seconds` into their jump.
##
## Negative seconds are before the jump: the load, and before that the wait.
static func state(seconds: float) -> String:
	if seconds < -LOAD_SECONDS:
		return "waiting"
	if seconds < 0.0:
		return "loading"
	if seconds >= JUMP_SECONDS:
		return "waiting"
	var rise := JUMP_SECONDS * RISE_SHARE
	if seconds < rise:
		return "up"
	## The top is brief and the way down is not, so `committed` is the moment
	## around the apex rather than half the jump.
	if seconds < rise + JUMP_SECONDS * 0.18:
		return "committed"
	return "landing"


## Whether a blocker in this state may be moved sideways along the net.
##
## False exactly while they are off the floor. This is the rule the mid-air
## shuffle broke, and it is one line because it is one fact.
static func may_translate(state_name: String) -> bool:
	return state_name != "up" and state_name != "committed"


## How far into the jump a blocker is when the ball reaches them, given how long
## the ball took to arrive after the wall committed.
##
## Clamped to the jump's own length rather than to the window's, which is the
## hang fix stated as arithmetic: past `JUMP_SECONDS` the blocker is back on the
## floor whatever the ball is doing.
static func jump_seconds_elapsed(
	seconds_since_takeoff: float
) -> float:
	return clampf(seconds_since_takeoff, -LOAD_SECONDS * 2.0, JUMP_SECONDS)
