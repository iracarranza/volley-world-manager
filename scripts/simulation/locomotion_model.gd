class_name LocomotionModel
extends RefCounted

## Decomposes ground speed into its two physical factors.
##
## Partly wired. `stride_factor()` and `direction_change_seconds()` are consumed
## by `RallyMovementSystem.movement_profile()`; they carry physique and turnover
## into live movement while leaving the population's mean speed where the
## existing curve put it, so no calibration is silently rebalanced. The full
## replacement of that curve by `maximum_speed()` below is *not* wired -- see
## "Why the whole curve is not replaced yet" at the bottom of this file.
##
## `RallyMovementSystem.movement_profile()` currently produces top speed from a
## single curve, `lerpf(1.35, 5.25, speed_rating)`, scaled by mass and fatigue.
## That number is really the product of two independent things:
##
##     ground speed = stride length (metres per step) x cadence (steps per second)
##
## Splitting them is not cosmetic. It gives the engine three properties the
## single curve cannot express:
##
## 1. **Per-mode ranges.** A lateral shuffle and a transition sprint are not the
##    same movement with a different rating; they have genuinely different
##    stride lengths. Today both draw from one 1.35-5.25 m/s range and differ
##    only in which rating is fed in.
## 2. **Physique enters locomotion honestly.** Height already *hurts* movement
##    through the mass penalty and contributes nothing back. Stride is the
##    compensating term real biomechanics provides.
## 3. **A real tradeoff.** Long stride buys top speed but costs turnover, so it
##    is worse for short adjustments and direction changes. Short stride is the
##    reverse. That is the difference between a middle blocker and a libero, and
##    the current model cannot represent it at all.
##
## `LocomotionGranularityCalibration` measures whether this can reproduce the
## existing speed curve before anything is changed.

## Realistic human turnover. Sprinters reach roughly 4.5-5 Hz; court movement
## sits below that because steps are rarely free.
const CADENCE_MINIMUM_HZ: float = 2.40
const CADENCE_MAXIMUM_HZ: float = 4.40

## Stride length per movement mode, relative to the player's approach stride --
## which is what `VolleyballPlayer.stride_length_m` already measures. A running
## transition stride is roughly twice an approach step; a lateral shuffle is
## shorter than one.
const MODE_STRIDE_SCALE := {
	RallyPlayerState.MovementMode.APPROACH: 1.00,
	RallyPlayerState.MovementMode.TRANSITION: 1.90,
	RallyPlayerState.MovementMode.LATERAL: 0.80,
	RallyPlayerState.MovementMode.BLOCK_CLOSE: 0.85,
	RallyPlayerState.MovementMode.RECOVERY: 0.90,
	RallyPlayerState.MovementMode.IDLE: 0.90,
}


## The stride this player actually uses in this mode, in metres.
##
## This reads the stored `stride_length_m`. That value used to be stale -- set
## from the *role's* base height and never recomputed after generation perturbed
## the real height -- so this function had to fall back on
## `default_stride_length_m()` to get any per-player signal at all. Generation
## now refreshes it, so the stored attribute is authoritative and can diverge
## from height on purpose: two players of equal height may carry genuinely
## different footwork, which is the whole reason it is a separate attribute.
static func stride_meters(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	if player == null:
		return 0.0
	return player.stride_length_m * float(MODE_STRIDE_SCALE.get(mode, 1.0))


## Steps per second. Turnover is what the speed rating really describes; fatigue
## degrades it because tired legs stop turning over before they stop reaching.
static func cadence_hz(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	if player == null:
		return 0.0
	var rating := _speed_rating(player, mode)
	var fatigue_factor := 1.0 - player.fatigue * 0.30
	return lerpf(CADENCE_MINIMUM_HZ, CADENCE_MAXIMUM_HZ, rating) * fatigue_factor


static func maximum_speed(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	return stride_meters(player, mode) * cadence_hz(player, mode)


## Inverts the relationship: given a speed the existing model produces, what
## stride would this player need at their cadence to achieve it? This is how the
## calibration checks whether the decomposition is physically plausible without
## anyone hand-tuning a multiplier first.
static func implied_stride_meters(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
	observed_speed: float,
) -> float:
	var cadence := cadence_hz(player, mode)
	return observed_speed / cadence if cadence > 0.01 else 0.0


## Stride of a player at the roster's central height, in metres. Everything
## below is expressed relative to this so that an average-sized player is
## unaffected and the population's mean speed is exactly where the existing
## curve put it. Physique changes who is faster than whom, not how fast
## volleyball is.
const REFERENCE_HEIGHT_CM: float = 193.0
const REFERENCE_STRIDE_M: float = 0.8299  ## REFERENCE_HEIGHT_CM / 100 * 0.43

## How much of a mode's speed actually comes from leg length. A transition run
## is close to pure stride; a lateral shuffle is mostly turnover, which is why a
## short libero is not punished for being short when moving sideways. Blocking
## footwork sits between the two.
const MODE_STRIDE_SENSITIVITY := {
	RallyPlayerState.MovementMode.APPROACH: 0.80,
	RallyPlayerState.MovementMode.TRANSITION: 1.00,
	RallyPlayerState.MovementMode.LATERAL: 0.35,
	RallyPlayerState.MovementMode.BLOCK_CLOSE: 0.45,
	RallyPlayerState.MovementMode.RECOVERY: 0.70,
	RallyPlayerState.MovementMode.IDLE: 0.70,
}

## Bounds on the physique term, so an outlier body cannot dominate ratings.
const MINIMUM_STRIDE_FACTOR: float = 0.86
const MAXIMUM_STRIDE_FACTOR: float = 1.14


## Speed multiplier this player's build earns in this mode, centred on 1.0.
##
## Height has until now been a pure cost in movement: it raises mass, mass
## lowers top speed, and nothing gave any of it back. That is not a tradeoff,
## just a penalty, and it made the taller regions strictly worse at moving. This
## is the compensating term -- longer legs cover more ground per step -- and it
## is deliberately weakest in the lateral mode, where turnover dominates and a
## big frame genuinely is a liability.
static func stride_factor(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	if player == null:
		return 1.0
	var sensitivity := float(MODE_STRIDE_SENSITIVITY.get(mode, 0.70))
	var ratio := player.stride_length_m / REFERENCE_STRIDE_M
	return clampf(
		1.0 + (ratio - 1.0) * sensitivity,
		MINIMUM_STRIDE_FACTOR, MAXIMUM_STRIDE_FACTOR,
	)


## Cadence of a player at the middle of the rating scale, in steps per second.
const REFERENCE_CADENCE_HZ: float = (CADENCE_MINIMUM_HZ + CADENCE_MAXIMUM_HZ) * 0.5

## Bounds on the turnover term for the same reason as the stride bounds.
const MINIMUM_TURN_FACTOR: float = 0.72
const MAXIMUM_TURN_FACTOR: float = 1.30


## How long this player spends changing direction, given how badly their current
## facing fits where they now need to go.
##
## Cadence is what makes this a player property rather than pure geometry. A
## direction change costs roughly a step to plant and redirect, so an athlete
## who turns their legs over faster pays less for it -- turnover is, literally,
## the frequency at which a player can change where they are going. Before this,
## `direction_change_delay` was derived from the facing dot product alone, and a
## libero reversed exactly as slowly as a middle blocker.
static func direction_change_seconds(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
	facing_fit: float,
	slow_delay: float,
	quick_delay: float,
) -> float:
	var geometric := lerpf(slow_delay, quick_delay, clampf(facing_fit, 0.0, 1.0))
	if player == null:
		return geometric
	var cadence := cadence_hz(player, mode)
	if cadence <= 0.01:
		return geometric
	return geometric * clampf(
		REFERENCE_CADENCE_HZ / cadence, MINIMUM_TURN_FACTOR, MAXIMUM_TURN_FACTOR
	)


static func _speed_rating(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	match mode:
		RallyPlayerState.MovementMode.LATERAL, RallyPlayerState.MovementMode.BLOCK_CLOSE:
			return clampf(float(player.lateral_speed) / 100.0, 0.0, 1.0)
		RallyPlayerState.MovementMode.APPROACH, RallyPlayerState.MovementMode.TRANSITION:
			return clampf(float(player.transition_speed) / 100.0, 0.0, 1.0)
	return clampf(float(player.transition_speed) / 100.0, 0.0, 1.0)


## Why the whole curve is not replaced yet
##
## `maximum_speed()` above is the honest decomposition, and swapping it directly
## for `lerpf(1.35, 5.25, rating)` would rebalance the entire game rather than
## re-express it. The reason is arithmetic, not taste.
##
## The existing curve spans a 3.89x ratio from the worst mover to the best.
## Human cadence spans about 1.8x, and stride varies only a few percent across a
## roster of athletes, so no plausible pair of factors multiplies out to 3.89x.
## Something in the current curve is therefore not physical: its floor. A
## professional moving at 1.35 m/s is walking, and no rating should describe
## that.
##
## Measured on generated rosters, adopting the decomposition wholesale moves
## mean transition speed from about 2.9 m/s to about 5.2 m/s and mean lateral
## speed from about 3.3 m/s down to about 2.3 m/s -- in opposite directions, per
## mode. Every reachability, arrival-margin, and opportunity number in the gate
## record is built on those speeds.
##
## That is a deliberate rebalance and belongs in its own change, with its own
## before-and-after sweep, exactly as the movement-fluidity record demands of
## step 4. What is wired today is only the part that adds information without
## moving the mean: who is fast, not how fast the sport is.
