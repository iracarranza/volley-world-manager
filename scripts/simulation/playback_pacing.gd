class_name PlaybackPacing
extends RefCounted

## How long the rally is *drawn* for, given how long it physically took.
##
## ## Why this is not in `main.gd`
##
## It was, and a gate that wanted to assert against it had to `preload` the main
## screen -- which cannot compile under `godot --script`, because autoloads do
## not exist there. Pacing is a model concern that a screen consumes, not a
## screen concern; put here, both the screen and the suite read the same numbers
## and neither has to copy them.
##
## ## What this replaced
##
## Two hand-written clamps in the playback loop: `[0.28, 2.60]` on a ball leg and
## `[0.55, 2.60]` on a contact. `tools/playback_timing_probe.tscn` measured what
## they act on, over 240 rallies and 2,116 events:
##
## | | p05 | p50 | p95 | max | clamp rewrote |
## |---|---|---|---|---|---|
## | ball legs, n=1506 | 0.03 | 1.06 | 1.51 | 31.00 | 20.7% |
## | contacts, n=610 | 0.10 | 0.12 | 0.24 | 0.24 | **100.0%** |
##
## The contact floor of 0.55 sits *above the maximum of its own distribution*.
## That is not a clamp, it is a constant with a `clampf` written round it, and
## playback had therefore never once drawn a contact at its simulated length.
##
## Being slower than life was never the fault -- a 0.12-second contact has to be
## stretched to be seen at all. Being slower **unevenly** was: a contact
## stretched 4.6x beside a flight stretched not at all destroys every ratio
## between two events, which is why a blocker outlived the contact its jump was
## built around. Nothing about the jump model was wrong.

## One factor for the whole rally, so every ratio survives and only the overall
## rate is a presentation choice. Chosen to keep a rally about the length it was
## before, so this change is about evenness and not about pace.
const READABILITY_SCALE: float = 1.8

## Below this a tween is one or two frames and reads as a jump rather than a
## movement. A limit of the display, not of the model -- and it sits below the
## 5th percentile of both measured distributions, so it stays a rounding rule
## rather than becoming another constant in disguise.
const MINIMUM_PHASE_SECONDS: float = 0.06

## Nothing a rally does physically lasts this long: the measured 95th percentile
## of a ball leg is 1.51 seconds and the longest plausible is nearer three.
##
## **It reports rather than absorbs.** The old ceiling of 2.60 silently swallowed
## two legs over four seconds -- one of them 31 -- which is how a defect that
## large stayed invisible for as long as it did. Playback still has to remain
## watchable, so the value is capped, but the cap says so.
const IMPLAUSIBLE_SECONDS: float = 6.0


## Physical seconds as drawn seconds, at the one rate the rally is paced at.
static func watchable(physical_seconds: float, what: String = "action") -> float:
	var seconds := maxf(physical_seconds, 0.0)
	if seconds > IMPLAUSIBLE_SECONDS:
		push_warning(
			"playback: a %s lasts %.2f physical seconds, which no rally action does"
				% [what, seconds]
		)
		seconds = IMPLAUSIBLE_SECONDS
	return maxf(seconds * READABILITY_SCALE, MINIMUM_PHASE_SECONDS)


## How long the ball is drawn at a contact with no following contact.
##
## Every other event hands its flight to the next contact and the leg is drawn
## between the two. The last one has nobody to hand it to, so its ball is drawn
## on the terminal event's own turn -- and it was drawn for the *contact's*
## length, around 0.12 seconds, while the flight it depicts runs all the way to
## the floor. That is a rally resolving with the ball still in the air.
##
## **The resolver is not at fault and needs no new event.** The last contact
## genuinely happens before the ball lands; there is simply no contact *at* the
## landing to stamp. A first version of the gate for this asserted on the
## resolver's stamps and failed 7 rallies in 160 for exactly that reason -- it
## measured the data when the invariant belongs to the drawing, which is §0
## wearing a different hat.
static func terminal_ball_seconds(
	outgoing_trajectory: Dictionary,
	has_next_contact: bool,
	contact_seconds: float,
) -> float:
	if outgoing_trajectory.is_empty() or has_next_contact:
		return contact_seconds
	return maxf(
		float(outgoing_trajectory.get("duration", contact_seconds)), contact_seconds
	)
