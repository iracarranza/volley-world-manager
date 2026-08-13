class_name BlockJumpModel
extends RefCounted

## Where in their jump a blocker is when the ball arrives.
##
## The block contest has always been a height comparison against a wall that is
## simply *there* -- `ball_height_at_net` against `reach_height_m`, with the reach
## a flat `BLOCKER_REACH_EFFORT` fraction of every blocker's leap. That constant
## stands for two different things at once:
##
##   - a block jump is taken from a standstill or a shuffle rather than a full
##     approach, so it is genuinely lower than a hitter's. Biomechanical, real,
##     and roughly the same for everybody.
##   - the blocker is somewhere on the way up or the way down when the ball
##     actually gets there. Timing, and not the same for everybody at all.
##
## Rolling the second into the first means `block_timing` -- an attribute every
## player carries -- decides nothing about whether a block stuffs, and that a
## blocker who peaks early is modelled as identical to one who peaks on the ball.
##
## Timing is the term that separates a stuff from a tool. Hands at full extension
## and not yet falling meet the ball with a surface angled down into the court.
## Hands on the way down present the same surface tilted back and a shrinking
## height, which is what the ball deflects off and out. So this returns both the
## height available *and* whether the arms are still going up, and the contact
## reads them separately.
##
## Deterministic, and deliberately drawing no random numbers. Every term comes
## from the blocker's attributes, their read and how far they had to travel --
## all of which already vary rally to rally. Adding a draw here would re-sequence
## every seeded outcome downstream of it for no gain in fidelity.

## Read from the physics module rather than redeclared. This file having its own
## 9.81 while two others had 9.8 -- and the ball-flight test a fourth copy -- is
## how one physical constant came to have two values in four places.
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const GRAVITY_MPS2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2

## How much of an approach jump a block jump gets, before timing is considered.
##
## The purely biomechanical half of the old `BLOCKER_REACH_EFFORT`: a blocker
## leaves the ground from a standstill or a two-step shuffle, without the
## horizontal momentum a hitter converts. Set so that the *population mean* of
## the phase this model returns reproduces the 0.62 that Gate D calibrated, which
## keeps the aggregate wall strength where it was measured and lets the new term
## do only what it should -- separate good timing from bad, rather than quietly
## making every block stronger or weaker.
## Solved, not chosen: 0.80 * (0.62 / 0.650), where 0.650 is the mean phase this
## model produced at 0.80 against live read and close distributions. Measured
## against a uniform close draw it read 0.622 and looked already correct, which
## is why the probe now samples close the way rallies actually deliver it.
const STANDING_JUMP_FRACTION: float = 0.763

## How far off the ball a blocker's peak lands, in seconds, at the extremes of
## `block_timing`.
##
## A block jump off a 0.55 m leap hangs about 0.67 s, and the window in which a
## blocker is within 90% of their peak height is roughly 0.21 s of that. So a
## tenth of a second is the difference between a wall and a screen, which is why
## coaches talk about it the way they do. The best of these sits comfortably
## inside that window and the worst sits outside it.
const TIMING_ERROR_BEST_SECONDS: float = 0.045
const TIMING_ERROR_WORST_SECONDS: float = 0.240

## How much a bad read and an unfinished close widen the timing error.
##
## Both are already modelled and both genuinely wreck jump timing: a blocker who
## did not read the set is reacting to the ball rather than anticipating it, and
## one still moving laterally is jumping off a foot that is not planted. They
## widen the error rather than setting it, so a well-timed blocker who is late
## and unset is still better than a poorly-timed one in the same trouble.
const MISREAD_ERROR_PENALTY: float = 0.085
const UNCLOSED_ERROR_PENALTY: float = 0.070

## How near the apex still counts as being at it.
##
## A blocker within this fraction of their peak height is locked out and level,
## which is the state the sport calls a good block. Off a 0.55 m leap that window
## is about 0.21 s of a 0.67 s hang, so it is generous in fractions and unforgiving
## in seconds -- which is why coaches talk about block timing the way they do.
const APEX_WINDOW: float = 0.90

## Below this close fraction a mistimed blocker is *late* rather than early.
##
## Which way a mistimed block misses is not a coin flip and should not need a
## draw. A blocker who is set and reading jumps with what they see -- the hitter's
## approach and arm swing -- and the hitter is the one who can hold, slow down or
## go off-speed, so a set blocker who is wrong is almost always early. A blocker
## who is still travelling laterally has not planted yet and goes up behind the
## ball.
##
## The rate this produces is inherited rather than fitted: close fractions run
## p10 0.475, p25 0.785, p50 1.00 across live rallies, so a threshold at the
## quartile makes roughly a quarter of mistimed blocks late ones. That is the
## distribution deciding the split, not a constant chosen to land on it.
const LATE_CLOSE_THRESHOLD: float = 0.80

## What falling hands are worth against level ones, all else equal.
##
## The one place the arm's direction is priced. Kept here rather than at the
## contact so that `effectiveness` is a single centred quantity: a threshold
## scaled once by height and again by direction moves its own population mean
## twice, and then nothing downstream is measuring what it says it is.
const DESCENDING_EFFECTIVENESS: float = 0.72

## The effectiveness at which a blocker meets exactly the constants Gate D
## calibrated. Thresholds are scaled by effectiveness *relative to this*, so only
## the spread either side of it is new.
##
## **Not the population mean, and it is worth being clear about why.** The mean
## measures 0.676 (`tools/run_block_jump_probe.gd`), and setting this there leaves
## the stuff rate at 16.2% against the 12.0% the flat constant produced. Centring
## on the arithmetic mean only preserves an aggregate when the mapping to it is
## linear, and this one is not: depth below the hands is dense just under the
## threshold, so lowering it converts many touches into stuffs while raising it by
## as much converts far fewer back. Solved against the rate it has to preserve, it
## sits at 0.900, which returns 12.2% -- the Gate D target -- with block
## involvement unmoved at 43.3%.
##
## Two earlier attempts are recorded because both looked right and were not.
## Scaling straight off raw timing gave 18.9%; dividing by the relative
## effectiveness rather than scaling linearly gave 15.8% and was convex and
## unbounded below into the bargain. Either would have shipped a stronger wall
## under the name of adding a timing term, and no later sweep could have
## separated the two.
const REFERENCE_EFFECTIVENESS: float = 0.900


## How long this blocker is off the ground, in seconds, for a given leap.
##
## Straight ballistics: up and down again from a standing start.
static func hang_seconds(leap_meters: float) -> float:
	return 2.0 * sqrt(maxf(leap_meters, 0.0) * 2.0 / GRAVITY_MPS2)


## When this jump happens, in rally seconds, around the contact it was made for.
##
## **The renderers had no such thing, and that is the whole of why blockers
## hang.** Playback drove a blocker's height off `playback_progress` -- a 0-to-1
## fraction of whatever leg was being drawn -- so their hang time was however
## long that leg lasted. Against a 1.2-second flight a blocker was airborne for
## 1.2 seconds off a jump that physically lasts about 0.67. The uneven playback
## clamps made that worse and were never the mechanism.
##
## A jump is `hang` seconds long and its apex is `error` seconds from the ball.
## Which side of the ball the apex falls on is not a coin flip: a blocker who is
## set and reading is early, because the hitter is the one who can hold or go
## off-speed, and a blocker still travelling laterally goes up behind it. That is
## the same split `resolve` makes, so `late` is its `arm_state == "rising"`.
static func jump_timeline(
	contact_time: float,
	leap_meters: float,
	error_seconds: float = 0.0,
	late: bool = false,
) -> Dictionary:
	var hang := hang_seconds(leap_meters)
	var peak := contact_time + (
		absf(error_seconds) if late else -absf(error_seconds)
	)
	return {
		"takeoff": peak - hang * 0.5,
		"peak": peak,
		"landing": peak + hang * 0.5,
		"hang_seconds": hang,
	}


## How far off the floor this jump is at a moment, 0 at the feet and 1 at the
## apex.
##
## The same parabola `resolve` reads for height at the ball, sampled by time
## rather than by a timing error -- so the drawn body and the contested height
## are two views of one jump instead of two models that happen to agree.
static func elevation_at(moment: float, timeline: Dictionary) -> float:
	var hang := float(timeline.get("hang_seconds", 0.0))
	if hang <= 0.0001:
		return 0.0
	var offset := (moment - float(timeline["peak"])) / (hang * 0.5)
	if absf(offset) >= 1.0:
		return 0.0
	return 1.0 - offset * offset


## The blocker's jump, as the contact needs to read it.
##
## `timing_rating`, `read_quality` and `close_fraction` are all 0-1. Returns the
## fraction of their leap available at the ball (`phase`), whether the arms are
## still rising (`rising`), and how cleanly the two lined up (`timing_quality`),
## which is what separates a stuff from a deflection.
static func resolve(
	leap_meters: float,
	timing_rating: float,
	read_quality: float,
	close_fraction: float,
) -> Dictionary:
	var hang := hang_seconds(leap_meters)
	if hang <= 0.0001:
		return {
			"phase": 0.0, "rising": false, "timing_quality": 0.0,
			"timing_error_seconds": 0.0, "hang_seconds": 0.0,
		}
	var error := lerpf(
		TIMING_ERROR_WORST_SECONDS, TIMING_ERROR_BEST_SECONDS,
		clampf(timing_rating, 0.0, 1.0),
	)
	error += MISREAD_ERROR_PENALTY * (1.0 - clampf(read_quality, 0.0, 1.0))
	error += UNCLOSED_ERROR_PENALTY * (1.0 - clampf(close_fraction, 0.0, 1.0))

	## Height on a ballistic arc, as a fraction of the peak, `error` seconds away
	## from the top of it. Zero at takeoff and landing, one at the apex.
	var half_hang := hang * 0.5
	var offset := clampf(error / half_hang, 0.0, 1.0)
	var arc := 1.0 - offset * offset

	## Three states, not two, because they do three different things to the ball.
	##
	##   extended    locked out and level. The surface is angled down into the
	##               court and this is what puts a ball on the floor.
	##   descending  extended but already falling. The same surface tilted back
	##               off a height that is shrinking as the ball reaches it, which
	##               is what a hitter tools.
	##   rising      extended, and the ball arrives before the apex. Still a good
	##               block: the arms are locked out and the surface is not tilting
	##               back, it is simply not as high as it will get. The height cost
	##               is already paid through `phase`, so nothing further is charged
	##               here -- what makes a block bad is falling, not being early in
	##               the flight.
	##
	## A two-way rising/not split collapses the last two together and charges a
	## late blocker the tool penalty that belongs to an early one.
	var state := "extended"
	if arc < APEX_WINDOW:
		state = "rising" if close_fraction < LATE_CLOSE_THRESHOLD else "descending"

	## One scalar for how well this jump is working, so the contact has a single
	## thing to centre on. Height at the ball and the direction the arms are
	## travelling are separate facts about the jump but they act on the outcome
	## together, and scaling a threshold by each of them in turn silently moves the
	## population mean twice.
	var effectiveness := arc * (
		DESCENDING_EFFECTIVENESS if state == "descending" else 1.0
	)

	return {
		## What the wall can actually reach with, as a fraction of the leap.
		"phase": clampf(STANDING_JUMP_FRACTION * arc, 0.0, 1.0),
		"arm_state": state,
		"effectiveness": effectiveness,
		## How close to the apex they met it, 0-1. The contact reads this rather
		## than the raw seconds so the scale means the same thing for a tall
		## blocker with a long hang and a short one with a brief one.
		"timing_quality": arc,
		"timing_error_seconds": error,
		"hang_seconds": hang,
	}
