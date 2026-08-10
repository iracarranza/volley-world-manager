class_name GaitBiomechanics
extends RefCounted

## Walking and running as one model, separated by where the body is highest.
##
## The rig's locomotion was a single sine driving the hips, with the arms
## counter-swinging at 46% of it, the knees zeroed every frame, and the vertical
## bob a fixed 3.5 cm. That is a walk, at one speed, forever -- so a libero
## sprinting for a dig and a setter strolling back to their seat moved their legs
## through identical arcs at identical amplitude, and neither ever bent a knee.
##
## ## What actually separates a walk from a run
##
## Not cadence, and not stride length -- those are matters of degree and both
## gaits span a wide range of them. The structural difference is **where the
## centre of mass sits through the step**:
##
##   *Walk* -- an inverted pendulum. The body vaults *over* a near-straight
##   stance leg, so the hips are **highest at midstance** and lowest during the
##   double-support phase when both feet are down. There is always a foot on the
##   floor.
##
##   *Run* -- a spring. The stance leg compresses under the load and rebounds, so
##   the hips are **lowest at midstance** and highest during the flight phase
##   when neither foot is down.
##
## That is a half-cycle inversion of the same oscillation, which is why this is
## one continuous model with a `run_blend` rather than two code paths with a
## transition to hand-tune between them. The phase shift falls out as `PI *
## run_blend` on the vertical term, and every other difference -- stance share,
## knee fold, arm carriage, trunk lean -- is an interpolation between two ends.
##
## ## Phase convention
##
## `cycle` is in **strides**, and its fractional part is the position within one.
## A stride is both legs: the right foot strikes at 0.0 and the left at 0.5.
## Callers advance it by distance travelled over stride length, so the gait is
## driven by ground covered rather than by wall-clock -- a player who stops mid
## step stops mid step instead of continuing to pedal.
##
## Pure and deterministic, like `SpikeBiomechanics`, for the same reason: pose
## work that cannot be checked without eyes on a screen does not get checked.

## Where the blend between the two gaits runs, in metres per second.
##
## The lower bound is a stroll and the upper an honest sprint. Real humans
## transition abruptly near 2 m/s rather than blending; this blends because a
## discontinuity in a *drawn* gait reads as a glitch, and because the simulator's
## speeds move continuously through the boundary many times a rally.
const WALK_SPEED_MPS: float = 1.5
const RUN_SPEED_MPS: float = 4.4

## Below this the actor is standing, and the cycle should not advance at all.
const IDLE_SPEED_MPS: float = 0.25

## What fraction of the stride each foot spends on the ground.
##
## Over half in a walk -- the overlap is the double-support phase, and it is what
## makes a walk a walk. Under half in a run: the shortfall is the flight phase,
## when nobody is touching the floor.
const WALK_STANCE_SHARE: float = 0.62
const RUN_STANCE_SHARE: float = 0.36

## How far the thigh swings either side of vertical.
const WALK_HIP_DEGREES: float = 20.0
const RUN_HIP_DEGREES: float = 39.0

## The yield: how far the knee folds under load at midstance. Nearly straight in
## a walk, which is exactly what lets the body vault over it; deeply compressed
## in a run, which is the spring.
##
## Negative, because every knee on this rig folds backward.
const WALK_STANCE_KNEE_DEGREES: float = -8.0
const RUN_STANCE_KNEE_DEGREES: float = -34.0

## The fold: how far the heel comes up under the body during the swing. This is
## the single most legible difference at a glance -- a runner's heel comes near
## their backside and a walker's barely leaves the floor.
const WALK_SWING_KNEE_DEGREES: float = -54.0
const RUN_SWING_KNEE_DEGREES: float = -114.0

## Where in the swing the knee is most folded. Early rather than halfway: the leg
## folds fast to shorten the pendulum, then unfolds slowly to reach for the
## ground. Below 1.0 skews the peak earlier.
##
## Applied to a *smoothstepped* progress rather than to progress itself, and that
## detail is load-bearing. A raw `pow(p, 0.72)` has an infinite derivative at
## p = 0, which sits exactly on toe-off -- so the knee left the ground with
## unbounded angular speed. Measured at a 5.2 m/s sprint it peaked at 18,700
## degrees per second, against 2,800 for the fastest joint in a spike, and would
## have read as the shin flicking out from under the runner once per step.
## Smoothstep is flat at both ends, so composing through it makes the rate finite
## at toe-off while leaving the peak where it belongs, a little before halfway.
const SWING_PEAK_SKEW: float = 0.72

## Arm swing amplitude, and how bent the elbow is carried.
##
## The elbow is the tell. A walker's arms hang nearly straight and swing from the
## shoulder; a runner's are locked near a right angle and drive front-to-back.
## Getting this wrong is why a fast walk and a slow run look identical.
const WALK_ARM_DEGREES: float = 10.0
const RUN_ARM_DEGREES: float = 33.0
const WALK_ELBOW_DEGREES: float = 20.0
const RUN_ELBOW_DEGREES: float = 82.0

## Forward trunk lean. Negative is forward on this rig, matching
## `SpikeBiomechanics.TORSO_PLANT_RADIANS`.
const WALK_TORSO_RADIANS: float = -0.025
const RUN_TORSO_RADIANS: float = -0.16

## How far the hips travel vertically over the stride, in metres.
const WALK_BOB_METERS: float = 0.028
const RUN_BOB_METERS: float = 0.082

## ## The ready stance
##
## **What a stationary voli should be doing, which is not standing.** `gait_blend`
## scales every joint toward zero as speed falls, and zero on this rig is a
## person standing straight up with their arms at their sides. That is the pose
## six of the twelve players on court hold for most of a rally, and it is the
## single least volleyball thing in the game -- nobody on a court ever stands
## like that, because the whole point of the sport between contacts is being
## ready to move.
##
## So the floor is a stance rather than a rest position: knees bent, hips back,
## weight forward, hands up. The gait interpolates *out of* it as speed rises
## rather than out of nothing, which also means a player decelerating settles
## into a stance instead of straightening up.
## **A stance is wide and low, not a lean.** The first version bent the knees and
## pitched the trunk forward and left the feet where standing had put them, which
## reads as someone peering at something rather than someone about to move. What
## makes a ready position a ready position is the base: feet outside the
## shoulders, weight between them, hips dropped so the legs are already loaded.
## Without the width the crouch has nowhere to go and the voli looks folded.
const READY_HIP_DEGREES: float = 16.0
const READY_KNEE_DEGREES: float = -54.0
## How far each leg is carried out from under the hip. Bounded well inside
## `PlayerActor3D.HIP_ABDUCTION_LIMIT_DEGREES` (42), because this is a stance a
## voli holds for a whole rally rather than the extreme of a dig.
const READY_ABDUCTION_DEGREES: float = 15.0
const READY_ARM_DEGREES: float = -30.0
const READY_ELBOW_DEGREES: float = 54.0
const READY_TORSO_RADIANS: float = -0.30

## ## Travelling somewhere other than forwards
##
## A gait driven by distance alone can only describe running *at* something. Half
## of what a volleyball player does on the floor is neither: a defender opens and
## backpedals to cover deep, a passer shuffles along the line without ever
## crossing their feet, and both look nothing like a jog.
##
## Both are expressed as scalings of the same stride rather than as separate
## animations, because they are: a backpedal is a short-stepped run with the
## trunk upright, and a shuffle is a run whose hips barely swing because the feet
## are forbidden to pass each other. Blending keeps a player who turns while
## moving continuous through the change, which two clips could not.
const BACKPEDAL_HIP_SCALE: float = 0.62
const BACKPEDAL_KNEE_SCALE: float = 1.15
## Backpedalling puts the chest *up*, not down: the trunk counterweights behind
## the hips and the eyes stay on the ball. Positive is backward on this rig.
const BACKPEDAL_TORSO_RADIANS: float = 0.12
## A shuffle's feet never cross, so the thighs barely swing -- almost all of the
## motion is the pelvis sliding sideways over bent knees.
const SHUFFLE_HIP_SCALE: float = 0.28
const SHUFFLE_KNEE_SCALE: float = 1.30
const SHUFFLE_BOB_SCALE: float = 0.35
const SHUFFLE_ARM_SCALE: float = 0.40
## How much of the ready stance's width survives into a shuffle. Most of it: a
## player sliding along the net never lets their feet come together, which is
## the difference between a shuffle and a skip.
const SHUFFLE_STANCE_SHARE: float = 0.75


## Every joint locomotion needs, for one instant of one stride.
##
## `speed_mps` decides the gait; `cycle` decides where in it. Handedness does not
## enter -- people do not run left- or right-handed.
static func resolve(
	cycle: float,
	speed_mps: float,
	## Which way the voli is travelling *relative to the way they are facing*, in
	## radians. Zero is straight ahead, PI is a backpedal, and plus or minus a
	## right angle is a lateral shuffle. Defaulted so every existing caller keeps
	## the forward gait it already had.
	travel_heading_radians: float = 0.0,
) -> Dictionary:
	var speed := maxf(speed_mps, 0.0)
	## Decomposed rather than branched on, so a defender opening from a shuffle
	## into a backpedal passes through the blend instead of snapping between two
	## clips.
	var backward := clampf(-cos(travel_heading_radians), 0.0, 1.0)
	var sideways := clampf(absf(sin(travel_heading_radians)), 0.0, 1.0)
	var run_blend := smoothstep(WALK_SPEED_MPS, RUN_SPEED_MPS, speed)
	## Separate from `run_blend`: this is how much gait there is at all, and it
	## goes to zero when standing so a stationary player's legs are straight
	## rather than frozen mid-stride.
	var gait_blend := smoothstep(IDLE_SPEED_MPS, WALK_SPEED_MPS, speed)
	var stance_share := lerpf(WALK_STANCE_SHARE, RUN_STANCE_SHARE, run_blend)
	## Shorter steps going backwards, and barely any thigh swing going sideways.
	var stride_scale := lerpf(1.0, BACKPEDAL_HIP_SCALE, backward) \
		* lerpf(1.0, SHUFFLE_HIP_SCALE, sideways)
	## And deeper knees in both, which is the same fact from the other side: a
	## body that cannot lengthen its stride stays low instead.
	var knee_scale := lerpf(1.0, BACKPEDAL_KNEE_SCALE, backward) \
		* lerpf(1.0, SHUFFLE_KNEE_SCALE, sideways)
	var hip_amplitude := lerpf(
		WALK_HIP_DEGREES, RUN_HIP_DEGREES, run_blend
	) * stride_scale
	var stance_knee := lerpf(
		WALK_STANCE_KNEE_DEGREES, RUN_STANCE_KNEE_DEGREES, run_blend
	) * knee_scale
	var swing_knee := lerpf(
		WALK_SWING_KNEE_DEGREES, RUN_SWING_KNEE_DEGREES, run_blend
	) * knee_scale

	var right := _leg(
		fposmod(cycle, 1.0), stance_share, hip_amplitude, stance_knee, swing_knee
	)
	## Half a stride out of phase, which is what makes it a pair of legs rather
	## than a hop.
	var left := _leg(
		fposmod(cycle + 0.5, 1.0),
		stance_share, hip_amplitude, stance_knee, swing_knee
	)

	## Arms counter the legs on the same side -- right arm back as the right leg
	## comes forward -- which is what cancels the rotation the legs put into the
	## trunk. Scaled to their own amplitude rather than to a fraction of the
	## hip's, because the ratio between them is not constant across gaits: a
	## runner's arms work proportionally harder than a walker's.
	var arm_amplitude := lerpf(WALK_ARM_DEGREES, RUN_ARM_DEGREES, run_blend)
	var arm_scale := arm_amplitude / maxf(hip_amplitude, 0.001)

	## Two rises and two falls per stride in both gaits. Only the *phase* differs,
	## and it differs by exactly half a cycle -- the walk is highest over the
	## planted leg, the run is lowest there and highest in the air between steps.
	var midstance := stance_share * 0.5
	var bob := cos(TAU * 2.0 * (cycle - midstance) + PI * run_blend) \
		* lerpf(WALK_BOB_METERS, RUN_BOB_METERS, run_blend)

	## Arms quieten in a shuffle: they are held out for balance rather than
	## driving, which is most of what tells a shuffle from a run at a glance.
	var arm_swing := arm_scale * lerpf(1.0, SHUFFLE_ARM_SCALE, sideways)
	## The trunk. Forward in a run, *back* in a backpedal, and near square in a
	## shuffle -- a player sliding along the line is not leaning anywhere.
	var torso := lerpf(
		lerpf(WALK_TORSO_RADIANS, RUN_TORSO_RADIANS, run_blend),
		BACKPEDAL_TORSO_RADIANS, backward,
	) * lerpf(1.0, 0.5, sideways)

	## **Interpolated out of the ready stance, not out of zero.**
	##
	## Every joint used to be scaled by `gait_blend`, so a stationary voli got
	## zeros -- straight legs, level shoulders, arms hanging. Six players hold
	## that for most of a rally. Blending from the stance instead means standing
	## still *is* a pose, and a player decelerating settles into it rather than
	## straightening up as they arrive.
	return {
		"gait_name": gait_name(speed),
		"run_blend": run_blend,
		"gait_blend": gait_blend,
		"backpedal_blend": backward,
		"shuffle_blend": sideways,
		"right_hip_degrees": lerpf(READY_HIP_DEGREES, right.x, gait_blend),
		"right_knee_degrees": lerpf(READY_KNEE_DEGREES, right.y, gait_blend),
		"left_hip_degrees": lerpf(READY_HIP_DEGREES, left.x, gait_blend),
		"left_knee_degrees": lerpf(READY_KNEE_DEGREES, left.y, gait_blend),
		## Negated against the same side's hip: that is the counter-swing. Both
		## arms rest at the same carriage, which is what makes the stance a stance
		## rather than a stride caught mid-swing.
		"right_arm_degrees": lerpf(
			READY_ARM_DEGREES, -right.x * arm_swing, gait_blend
		),
		"left_arm_degrees": lerpf(
			READY_ARM_DEGREES, -left.x * arm_swing, gait_blend
		),
		"elbow_degrees": lerpf(
			READY_ELBOW_DEGREES,
			lerpf(WALK_ELBOW_DEGREES, RUN_ELBOW_DEGREES, run_blend),
			gait_blend,
		),
		"torso_pitch_radians": lerpf(READY_TORSO_RADIANS, torso, gait_blend),
		## Feet outside the shoulders when set, closing as the stride takes over --
		## you cannot run with your legs abducted, and a shuffle keeps some of it
		## because a shuffle never brings the feet together either.
		"abduction_degrees": lerpf(
			READY_ABDUCTION_DEGREES,
			READY_ABDUCTION_DEGREES * SHUFFLE_STANCE_SHARE * sideways,
			gait_blend,
		),
		## Nothing bobs standing still, so this one really does go to zero.
		"bob_meters": bob * gait_blend * lerpf(1.0, SHUFFLE_BOB_SCALE, sideways),
	}


## One leg's hip and knee at a point in its own cycle, as `(hip, knee)`.
##
## `leg_phase` runs 0 at foot strike through `stance_share` at toe-off to 1 at
## the next strike.
static func _leg(
	leg_phase: float,
	stance_share: float,
	hip_amplitude: float,
	stance_knee: float,
	swing_knee: float,
) -> Vector2:
	var share := clampf(stance_share, 0.05, 0.95)
	var in_stance := leg_phase < share
	## Remapped so stance always fills the first half and swing the second,
	## whatever share of the stride each actually takes. Without this the hip
	## would have to be two different curves for the two gaits; with it, one
	## cosine covers both and the asymmetry lives entirely in the remapping.
	var normalized := 0.5 * leg_phase / share if in_stance \
		else 0.5 + 0.5 * (leg_phase - share) / (1.0 - share)
	## +amplitude at strike (thigh forward, reaching), through -amplitude at
	## toe-off (thigh trailing), and back.
	var hip := hip_amplitude * cos(normalized * TAU)
	var knee := 0.0
	if in_stance:
		## The yield, deepest at midstance and gone at both ends -- the foot
		## meets the ground on a straightening leg and leaves it on one.
		knee = stance_knee * sin(leg_phase / share * PI)
	else:
		## The fold, skewed early: the leg shortens fast to clear the ground and
		## unfolds slowly to reach for the next strike.
		var progress := (leg_phase - share) / (1.0 - share)
		knee = swing_knee * sin(
			pow(smoothstep(0.0, 1.0, progress), SWING_PEAK_SKEW) * PI
		)
	return Vector2(hip, knee)


## What to call this speed, so a diagnostic can say "run" instead of printing a
## blend factor.
static func gait_name(speed_mps: float) -> String:
	if speed_mps < IDLE_SPEED_MPS:
		return "stand"
	if speed_mps < WALK_SPEED_MPS:
		return "walk"
	if speed_mps < RUN_SPEED_MPS:
		return "stride"
	return "run"
