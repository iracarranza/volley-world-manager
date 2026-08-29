class_name StanceTransition
extends RefCounted

## Getting into a stance, and getting out of one.
##
## Two things on this rig change a body instantly, and they are the same thing
## seen twice:
##
## - **`ready_stance` is read fresh every frame.** `match_court_3d.gd` assigns
##   it and `set_pose` reads `ReadyStance.joints(...)` on the next frame, so a
##   middle dropping off the net goes from hands-up to a defender's crouch
##   between two frames. Nothing tweens it because nothing holds the previous
##   one.
## - **A floor recovery ends by running out of phase.** `_recovery_clock` is a
##   *phase*, so the moment playback stops drawing a voli as the contact actor
##   the recovery stops advancing and the body snaps to whatever the gait says.
##   Photographed: `pose_recover_roll` at 0.86 is upright with the arms still
##   out sideways, and `pose_recover_knee` never rises at all -- its `down`
##   term is monotonic and has no counterpart.
##
## - **A contact pose ends the frame it stops being drawn.** `set_pose` writes
##   the gait and then the action's own module over the top when
##   `is_contact_actor`; the frame that flag flips, the joints go from the
##   module's values to the gait's with nothing between. Measured on two filmed
##   rallies: both arms turning an identical 96.9 degrees in one frame at a SET,
##   and a tail of such turns in *every* leg of both rallies. See
##   `docs/review/POSE_TRANSITIONS.md`.
## - **The head has a clamp and no rate.** `HEAD_YAW_LIMIT_DEGREES` bounds how
##   far a neck turns off the body, which is a statement about anatomy and a
##   correct one. Nothing bounds how *fast*, so when a target crosses directly
##   behind a voli the look goes from one limit to the other in a frame: the
##   filmed rallies show exactly 124.0 degrees, which is twice the clamp, on
##   five separate legs and both sides. The clamp itself became the snap.
##
## All four are "this body is not in the stance it should be in, and has to get
## there". So there is one mechanism, with four entry points that differ only in
## how long they take: a fifth of a second to change what you are ready for, a
## second to get off the floor.
##
## Pure and deterministic, like the other pose modules.

## ## How long
##
## **Derived from the distance between the two stances rather than tabulated.**
##
## A table of pair durations is nine numbers for three stances and sixteen for
## four, and every one of them is a thing to get wrong quietly. The distance
## between two joint sets is already the answer to "how much has to change", and
## it is a number this file can compute -- so adding a fourth stance gets a
## sensible duration without anybody choosing one.
##
## The distance is in degrees, summed over the joints that carry a stance, with
## the trunk converted so a radian of lean counts like the tens of degrees it
## actually is.
const STANCE_MIN_SECONDS: float = 0.14
const STANCE_MAX_SECONDS: float = 0.42
const STANCE_SECONDS_PER_DEGREE: float = 0.0022

## The same number, read the other way round: **455 degrees a second is how fast
## a joint on this rig is allowed to travel.**
##
## `STANCE_SECONDS_PER_DEGREE` has always been a rate in disguise -- seconds per
## degree is the reciprocal of degrees per second -- and naming it as one is
## what lets the two new entry points share it instead of each acquiring a
## magnitude of their own. The figure is plausible in both directions it is now
## used: a limb repositioning between two poses covers a few hundred degrees a
## second, and a neck in a large gaze shift peaks in the same band, well under
## the roughly 1500 deg/s a shoulder reaches at the top of a spike. Nothing here
## was tuned; a constant already in the file was given its second reading.
const MAX_JOINT_DEGREES_PER_SECOND: float = 1.0 / STANCE_SECONDS_PER_DEGREE

## **Dropping into a stance is faster than coming out of one.**
##
## An athlete snaps into a defensive posture -- that is the whole point of the
## word "ready" -- and unwinds out of it lazily, because nothing is asking them
## to hurry. Applied as a scale on the duration rather than as a second table,
## and keyed on whether the *target* is the more loaded of the two, which the
## knee already says.
const LOADING_SCALE: float = 0.72
const UNLOADING_SCALE: float = 1.25

## How long it takes to get back on your feet, in seconds.
##
## **These are the simulator's own numbers**, not a second opinion about them.
## `RallySimulator.RECOVERY_DELAY_SECONDS` already prices what each state costs a
## defender before they are a defender again -- a knee is most of a contact, a
## fall is a contact and the transition after it, being blown away is the rest of
## the exchange -- and a drawn recovery that takes a different length of time
## than the priced one is a body that stands up before or after the rally says it
## did.
##
## Copied rather than imported because the dependency would run the wrong way: a
## pose module must not reach into the simulator. A suite check holds the two
## tables equal, which is the same device the codebase uses wherever a value has
## to live in two places.
const FLOOR_SECONDS := {
	"knee": 0.55,
	"fall": 0.95,
	"blown_away": 1.35,
}

## The joints a stance is made of. Named so `distance` and `blend` cannot
## disagree about what they are walking, and so a stance that grows a joint gets
## it in both places at once.
const STANCE_KEYS: Array[String] = [
	"hip_degrees", "knee_degrees", "abduction_degrees",
	"arm_degrees", "elbow_degrees",
]
## The trunk, kept separate because it is in radians and everything else is in
## degrees. Summing the two without this is how a lean worth 20 degrees counts
## as a third of one.
const TORSO_KEY: String = "torso_radians"


## How far apart two stances are, in degrees.
static func distance(from_joints: Dictionary, to_joints: Dictionary) -> float:
	var total := 0.0
	for key in STANCE_KEYS:
		total += absf(
			float(to_joints.get(key, 0.0)) - float(from_joints.get(key, 0.0))
		)
	total += absf(rad_to_deg(
		float(to_joints.get(TORSO_KEY, 0.0))
			- float(from_joints.get(TORSO_KEY, 0.0))
	))
	return total


## How long this change of stance should take.
static func seconds_between(
	from_joints: Dictionary, to_joints: Dictionary
) -> float:
	var span := distance(from_joints, to_joints)
	var scale := LOADING_SCALE if float(to_joints.get("knee_degrees", 0.0)) \
		< float(from_joints.get("knee_degrees", 0.0)) else UNLOADING_SCALE
	return clampf(
		span * STANCE_SECONDS_PER_DEGREE * scale,
		STANCE_MIN_SECONDS, STANCE_MAX_SECONDS,
	)


## How long getting up off the floor should take. Zero for a recovery that never
## went down, which is the common case and must cost nothing.
static func floor_seconds(recovery: String) -> float:
	return float(FLOOR_SECONDS.get(recovery, 0.0))


## The rig's joints, in the shape `PlayerActor3D._capture_joints` hands over.
##
## A separate list from `STANCE_KEYS` because it is a different object: a stance
## is five scalars describing what a body is *ready for*, and this is the posed
## rig itself, eight joints of three axes each. Sharing one list would force one
## of them to lie about its own shape.
const POSE_KEYS: Array[String] = [
	"left_arm", "right_arm", "left_elbow", "right_elbow",
	"left_leg", "right_leg", "left_knee", "right_knee",
]


## How far apart two posed rigs are, in degrees.
##
## **The largest single joint, not the sum**, which is where this parts company
## with `distance` above and deliberately so. Summing twenty-four axes puts every
## real pose change past `STANCE_MAX_SECONDS`, so the clamp would decide every
## duration and the derivation would be a constant wearing a formula. The
## largest-moving joint is also the honest question: a transition has to last
## long enough for the *fastest* thing in it to move at a speed a body can, and
## the joints behind it arrive early, which is what they do anyway.
static func pose_distance(
	from_joints: Dictionary, to_joints: Dictionary
) -> float:
	var worst := 0.0
	for key in POSE_KEYS:
		var was := Vector3(from_joints.get(key, Vector3.ZERO))
		var now := Vector3(to_joints.get(key, Vector3.ZERO))
		worst = maxf(worst, maxf(maxf(
			absf(now.x - was.x), absf(now.y - was.y)), absf(now.z - was.z)))
	return worst


## How long a change of pose should take.
##
## `loading` is the same asymmetry `seconds_between` applies and for the same
## reason -- you snap into an action and unwind out of it -- but keyed on the
## caller's own knowledge of which way it is going rather than on the knee,
## because a contact pose has no equivalent read: a block and a dig both fold
## the knee and mean opposite things by it.
static func pose_seconds(
	from_joints: Dictionary, to_joints: Dictionary, loading: bool
) -> float:
	var seconds := pose_distance(from_joints, to_joints) \
		/ MAX_JOINT_DEGREES_PER_SECOND
	if loading:
		## **Entering an action is bounded, not merely scaled**, and it is the
		## only one of the four transitions with a deadline: the contact happens
		## at a fixed instant in its window, and a body still easing into its
		## swing arrives at that instant in the wrong shape. The ceiling is the
		## floor of the other three, which is as long as this may safely be.
		##
		## Little is being given up. The approach *is* the transition into a
		## contact and the action's own module owns it from phase zero, so what
		## is left for this to cover is the discontinuity at the seam and not the
		## movement either side of it.
		return minf(seconds * LOADING_SCALE, STANCE_MIN_SECONDS)
	return clampf(
		seconds * UNLOADING_SCALE, STANCE_MIN_SECONDS, STANCE_MAX_SECONDS
	)


## One step of a turn that is allowed to take time, in radians.
##
## A rate limit rather than a smoothing filter, because most of what the head
## does is already right: it tracks a ball that moves slowly and the limit never
## binds, so 78 per cent of the frames in the filmed rallies are untouched by
## this. What it catches is the case a filter would blur along with everything
## else -- a target crossing behind the body, where the clamped angle jumps the
## full width of the neck at once.
##
## `angle_difference` rather than plain subtraction so a turn across the wrap
## boundary goes the short way round, which is also the way a neck goes.
static func turned(current: float, target: float, delta: float) -> float:
	var step := deg_to_rad(MAX_JOINT_DEGREES_PER_SECOND) * maxf(delta, 0.0)
	var gap := angle_difference(current, target)
	if absf(gap) <= step:
		return target
	return current + signf(gap) * step


## The settle curve.
##
## Ease-out rather than ease-in-out: a body arriving in a stance decelerates
## into it, and the acceleration at the start already happened -- it is the
## decision that caused the change. An ease-in on the front of that reads as
## hesitation, which is the opposite of what a ready stance means.
##
## Named `settle` and not `ease`, because `ease` is a GDScript global taking two
## arguments and a static method that shadows it fails to parse at every call
## site *except* its own file.
static func settle(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.4)


## One stance partway into another.
##
## Returns a joint set of the same shape, so the caller hands it to
## `GaitBiomechanics.resolve` exactly where it used to hand a named stance. That
## is the whole reason this is a blend of *stances* rather than a blend of the
## posed rig: the gait interpolates out of its ready stance already, and a
## transition that fought it further down would be two systems moving the same
## joints.
static func blend(
	from_joints: Dictionary, to_joints: Dictionary, progress: float
) -> Dictionary:
	var t := settle(progress)
	var out := {}
	for key in STANCE_KEYS:
		out[key] = lerpf(
			float(from_joints.get(key, 0.0)), float(to_joints.get(key, 0.0)), t
		)
	out[TORSO_KEY] = lerpf(
		float(from_joints.get(TORSO_KEY, 0.0)),
		float(to_joints.get(TORSO_KEY, 0.0)), t
	)
	return out
