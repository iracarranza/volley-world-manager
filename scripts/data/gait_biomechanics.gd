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


## Every joint locomotion needs, for one instant of one stride.
##
## `speed_mps` decides the gait; `cycle` decides where in it. Handedness does not
## enter -- people do not run left- or right-handed.
static func resolve(cycle: float, speed_mps: float) -> Dictionary:
	var speed := maxf(speed_mps, 0.0)
	var run_blend := smoothstep(WALK_SPEED_MPS, RUN_SPEED_MPS, speed)
	## Separate from `run_blend`: this is how much gait there is at all, and it
	## goes to zero when standing so a stationary player's legs are straight
	## rather than frozen mid-stride.
	var gait_blend := smoothstep(IDLE_SPEED_MPS, WALK_SPEED_MPS, speed)
	var stance_share := lerpf(WALK_STANCE_SHARE, RUN_STANCE_SHARE, run_blend)
	var hip_amplitude := lerpf(WALK_HIP_DEGREES, RUN_HIP_DEGREES, run_blend)
	var stance_knee := lerpf(
		WALK_STANCE_KNEE_DEGREES, RUN_STANCE_KNEE_DEGREES, run_blend
	)
	var swing_knee := lerpf(
		WALK_SWING_KNEE_DEGREES, RUN_SWING_KNEE_DEGREES, run_blend
	)

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

	return {
		"gait_name": gait_name(speed),
		"run_blend": run_blend,
		"gait_blend": gait_blend,
		"right_hip_degrees": right.x * gait_blend,
		"right_knee_degrees": right.y * gait_blend,
		"left_hip_degrees": left.x * gait_blend,
		"left_knee_degrees": left.y * gait_blend,
		## Negated against the same side's hip: that is the counter-swing.
		"right_arm_degrees": -right.x * arm_scale * gait_blend,
		"left_arm_degrees": -left.x * arm_scale * gait_blend,
		"elbow_degrees": lerpf(
			WALK_ELBOW_DEGREES, RUN_ELBOW_DEGREES, run_blend
		) * gait_blend,
		"torso_pitch_radians": lerpf(
			WALK_TORSO_RADIANS, RUN_TORSO_RADIANS, run_blend
		) * gait_blend,
		"bob_meters": bob * gait_blend,
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
