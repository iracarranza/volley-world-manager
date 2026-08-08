class_name SetBiomechanics
extends RefCounted

## A set as a push from the floor, not as a shape made with the hands.
##
## The inline version had the right idea and half the timeline: shoulders opening
## from 96 to 132 and elbows from 98 to 22 across a `release` that reached 1.0
## **at contact** and stayed there. So the preparation was drawn and the delivery
## was not -- past phase 0 the setter held the finish position for the whole
## outgoing flight, hands stopped where the ball had been. And the legs were
## never touched at all, which left whatever the gait had last written on them:
## a setter standing straight-legged while their arms did the work.
##
## ## What a set actually is
##
## A setter does not push a ball with their arms. They get under it, load the
## legs, and *extend* -- ankles, knees, hips, shoulders, elbows, wrists, in that
## order and ending with the fingers. The arms are the last and smallest part of
## it. What the eye reads as a good set is the whole body finishing tall and
## travelling toward the target, and what it reads as a bad one is arms alone.
##
## Three things therefore have to survive past phase 0, and none of them did:
##
##   * the elbows keep opening, finishing near straight
##   * the legs keep extending, and the body rises with them
##   * the hands finish high and *out*, toward where the ball went
##
## ## The hands are together, because the ball is between them
##
## Kept from the version this replaces, along with the sign it took two attempts
## to get right: rolling an arm about +Z carries its hand toward +x, so the left
## arm takes `+flare` to converge and the right `-flare`. Reversed, a set is drawn
## as a player holding nothing. The forearms converge for the preparation *and*
## the push, and only the recovery opens them, once the ball has gone.
##
## ## Phase convention
##
## Signed, contact at 0, matching the other pose modules:
##
##   -1.0  moving to the ball, hands not yet up
##    0.0  the ball is in the hands
##   +1.0  recovered, watching the attack
##
## Pure and deterministic, and testable without a scene.

## Where each stage begins on the signed timeline.
##
## A setter is under the ball early -- the hands are up long before the contact,
## which is most of what separates a setter from someone catching a ball -- so
## the gather occupies the bulk of the approach and the push is short.
const GATHER_START: float = -0.72
const GATHER_END: float = -0.16
const PUSH_END: float = 0.16
const EXTEND_END: float = 0.40
const RECOVER_END: float = 0.88

## The shoulders. 96 at the gather puts the upper arms out and slightly forward
## with the hands at the forehead; the push carries them up and the extension
## finishes them above and in front, which is where a released set leaves the
## hands.
const SHOULDER_READY_DEGREES: float = 30.0
const SHOULDER_GATHER_DEGREES: float = 96.0
const SHOULDER_CONTACT_DEGREES: float = 124.0
const SHOULDER_EXTEND_DEGREES: float = 152.0

## The elbow is what tells a set from a block. Both put the hands above the head;
## only one keeps the arms bent. At 98 the forearms stand vertical beside the
## head, which is the shape a setter waits in, and opening toward 4 is the push
## itself -- the joint that does the work, rather than the shoulder swinging the
## whole arm through the ball.
const ELBOW_GATHER_DEGREES: float = 98.0
const ELBOW_CONTACT_DEGREES: float = 46.0
const ELBOW_EXTEND_DEGREES: float = 8.0
const ELBOW_REST_DEGREES: float = 17.0

## Hand convergence, in degrees of roll. Positive brings a hand toward the
## centreline -- see the note above about the sign.
const FLARE_GATHER_DEGREES: float = 21.0
const FLARE_CONTACT_DEGREES: float = 15.0
const FLARE_RECOVER_DEGREES: float = -20.0

## Trunk pitch, radians, negative forward. A setter gathers with a slight forward
## fold and finishes leaning *back* a little as the chest opens under the
## extension -- which is what stops the finish reading as a lunge at the ball.
const TORSO_GATHER_RADIANS: float = -0.12
const TORSO_EXTEND_RADIANS: float = 0.07
const TORSO_REST_RADIANS: float = -0.04

## How far the setter comes **off the floor** at the finish, in metres.
##
## Only the rise, and deliberately not the dip. The dip is already paid for: the
## knee folds to -46 in the gather and `_ground_the_feet` turns that fold into a
## body drop of about 0.10 m so the shoes stay on the ground. Adding a second
## explicit crouch on top would lower the body a second time and put the feet
## through the floor -- which is exactly the defect the dig had, and it is worth
## saying out loud that this module nearly repeated it.
##
## The rise is different in kind. A setter finishing a good ball comes up onto
## the toes and travels toward the target, so this genuinely is elevation and not
## a fold, and it is the one part of the vertical motion that has to be added
## rather than derived.
const EXTEND_RISE_METRES: float = 0.05

## The legs. Loaded under the ball, driven straight through the push, and the
## heels leaving the floor is what carries a good set forward -- drawn here as
## the knees passing through near-straight rather than stopping at the contact.
const KNEE_READY_DEGREES: float = -12.0
const KNEE_GATHER_DEGREES: float = -46.0
const KNEE_EXTEND_DEGREES: float = -4.0
## The feet split slightly, right foot forward, which is the stance a setter
## takes so the push travels toward the antenna rather than straight up.
const HIP_SPLIT_DEGREES: float = 11.0


## Eased 0-1 progress through a window, clamped outside it.
##
## Its own copy of the easing the other pose modules use, by the same reasoning:
## a shared convention rather than a shared dependency.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


## Every joint of a set at one instant.
##
## `hand` is +1 for a right-hander and -1 for a left-hander and mirrors only the
## foot split. A set is a symmetric action; nothing else in it has a handedness.
static func resolve(phase: float, hand: float = 1.0) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var gather := window(p, GATHER_START, GATHER_END)
	## Runs *through* contact rather than up to it. This is the correction the
	## whole module exists for: a push that finishes at phase 0 is a push the
	## viewer never sees, because the ball leaves at the moment it completes.
	var push := window(p, GATHER_END, PUSH_END)
	var extend := window(p, 0.0, EXTEND_END)
	var recover := window(p, EXTEND_END, RECOVER_END)

	var shoulder := lerpf(SHOULDER_READY_DEGREES, SHOULDER_GATHER_DEGREES, gather)
	shoulder = lerpf(shoulder, SHOULDER_CONTACT_DEGREES, push)
	shoulder = lerpf(shoulder, SHOULDER_EXTEND_DEGREES, extend)
	shoulder = lerpf(shoulder, SHOULDER_READY_DEGREES, recover)

	var elbow := lerpf(ELBOW_REST_DEGREES, ELBOW_GATHER_DEGREES, gather)
	elbow = lerpf(elbow, ELBOW_CONTACT_DEGREES, push)
	elbow = lerpf(elbow, ELBOW_EXTEND_DEGREES, extend)
	elbow = lerpf(elbow, ELBOW_REST_DEGREES, recover)

	var flare := lerpf(4.0, FLARE_GATHER_DEGREES, gather)
	flare = lerpf(flare, FLARE_CONTACT_DEGREES, push)
	## Opening the hands is the *recovery*, not the extension. Keyed off the tail
	## of the action rather than the tail of the push, which -- once the push
	## reached past contact -- would have spread them while the ball was still in
	## them.
	flare = lerpf(flare, FLARE_RECOVER_DEGREES, recover)

	var torso := lerpf(TORSO_REST_RADIANS, TORSO_GATHER_RADIANS, gather)
	torso = lerpf(torso, TORSO_EXTEND_RADIANS, extend)
	torso = lerpf(torso, TORSO_REST_RADIANS, recover)

	## The legs lead. The drive starts before the hands move and finishes after
	## them, which is the ordering that makes a set look pushed rather than
	## thrown -- and is why `drive` opens earlier than `push` and closes later.
	var drive := window(p, GATHER_END - 0.06, EXTEND_END)
	var knee := lerpf(KNEE_READY_DEGREES, KNEE_GATHER_DEGREES, gather)
	knee = lerpf(knee, KNEE_EXTEND_DEGREES, drive)
	knee = lerpf(knee, KNEE_READY_DEGREES, recover)

	var rise := lerpf(0.0, EXTEND_RISE_METRES, drive)
	rise = lerpf(rise, 0.0, recover)

	return {
		"shoulder_degrees": shoulder,
		"elbow_degrees": elbow,
		"flare_degrees": flare,
		"torso_pitch_radians": torso,
		"knee_degrees": knee,
		"hip_split_degrees": HIP_SPLIT_DEGREES * hand,
		"rise_metres": rise,
	}
