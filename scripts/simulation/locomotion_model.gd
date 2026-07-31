class_name LocomotionModel
extends RefCounted

## DRAFT -- not wired. Decomposes ground speed into its two physical factors.
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
## Note this reads `default_stride_length_m()` rather than the stored
## `stride_length_m`. The stored value is set from the *role's* base height
## during `apply_role_physical_defaults()` and never recomputed after
## `PlayerGenerator._apply_body_variation()` perturbs the real height, so it
## carries no per-player information today. See the locomotion design record.
static func stride_meters(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	if player == null:
		return 0.0
	var base := player.default_stride_length_m()
	return base * float(MODE_STRIDE_SCALE.get(mode, 1.0))


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
