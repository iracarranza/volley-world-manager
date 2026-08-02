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

## Fallback turnover band, used only for a mode with no entry below.
const CADENCE_MINIMUM_HZ: float = 2.40
const CADENCE_MAXIMUM_HZ: float = 4.40

## Stride length per movement mode, relative to the player's approach stride --
## which is what `VolleyballPlayer.stride_length_m` already measures.
const MODE_STRIDE_SCALE := {
	RallyPlayerState.MovementMode.APPROACH: 1.00,
	RallyPlayerState.MovementMode.TRANSITION: 1.55,
	RallyPlayerState.MovementMode.LATERAL: 0.78,
	RallyPlayerState.MovementMode.BLOCK_CLOSE: 0.85,
	RallyPlayerState.MovementMode.RECOVERY: 1.10,
	RallyPlayerState.MovementMode.IDLE: 0.90,
}

## Turnover band per mode, in steps per second, from worst to best mover.
##
## Cadence is mode-specific for the same reason stride is, and leaving it global
## was the flaw that made the decomposition look impossible. A defensive shuffle
## is *short steps at high frequency*; a transition run is *long steps at
## moderate frequency*. One shared band forced a shuffle to turn over no faster
## than a sprint, so the only way to reach a plausible shuffle speed was to give
## it a near-running stride -- which is precisely the implausibility
## `LocomotionGranularityCalibration` was reporting.
const MODE_CADENCE_BAND := {
	RallyPlayerState.MovementMode.APPROACH: [3.00, 4.80],
	RallyPlayerState.MovementMode.TRANSITION: [2.60, 4.40],
	RallyPlayerState.MovementMode.LATERAL: [3.00, 5.00],
	RallyPlayerState.MovementMode.BLOCK_CLOSE: [3.00, 4.80],
	RallyPlayerState.MovementMode.RECOVERY: [2.40, 3.80],
	RallyPlayerState.MovementMode.IDLE: [2.40, 3.80],
}

## Reference build, and how strongly long limbs cost turnover in each mode.
##
## This is the coupling that makes stride a *tradeoff* rather than a free gift.
## A long limb is a heavier lever: it covers more ground per step but cannot be
## swung, planted, and re-planted as often. Without this, stride multiplies into
## every mode linearly and a tall player is simply faster everywhere, which
## erases the libero and hands the sport to whoever is biggest.
##
## The cost is mode-specific because it physically is: rapid direction-changing
## footwork re-accelerates the limb many times a second, where steady running
## swings it near its natural period. An exponent above 1.0 means turnover loses
## more than stride gains, so the shorter player is faster in that mode.
##
## Net height exponent per mode is `1 - cost`:
##   LATERAL -0.35 (short wins), BLOCK_CLOSE -0.10 (near neutral),
##   APPROACH +0.40, TRANSITION +0.65 (tall wins).
const REFERENCE_STRIDE_M: float = 0.8299  ## a 193 cm player, the roster centre
const MODE_LIMB_TURNOVER_COST := {
	RallyPlayerState.MovementMode.APPROACH: 0.60,
	RallyPlayerState.MovementMode.TRANSITION: 0.35,
	RallyPlayerState.MovementMode.LATERAL: 1.35,
	RallyPlayerState.MovementMode.BLOCK_CLOSE: 1.10,
	RallyPlayerState.MovementMode.RECOVERY: 0.80,
	RallyPlayerState.MovementMode.IDLE: 0.80,
}


## How much this player's build slows their turnover in this mode, centred on
## 1.0 for a reference-sized athlete.
static func limb_turnover_factor(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	if player == null or player.stride_length_m <= 0.01:
		return 1.0
	return pow(
		REFERENCE_STRIDE_M / player.stride_length_m,
		float(MODE_LIMB_TURNOVER_COST.get(mode, 0.80)),
	)


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
	var band := cadence_band(mode)
	var rating := _speed_rating(player, mode)
	var fatigue_factor := 1.0 - player.fatigue * 0.30
	return lerpf(float(band[0]), float(band[1]), rating) \
		* fatigue_factor * limb_turnover_factor(player, mode)


static func cadence_band(mode: RallyPlayerState.MovementMode) -> Array:
	return Array(MODE_CADENCE_BAND.get(
		mode, [CADENCE_MINIMUM_HZ, CADENCE_MAXIMUM_HZ]
	))


## Turnover of a mid-scale mover in this mode. Turn cost is expressed against
## this so that an average player is charged the geometric cost unmodified in
## every mode, rather than a shuffle looking permanently quick against a
## running reference.
static func reference_cadence_hz(mode: RallyPlayerState.MovementMode) -> float:
	var band := cadence_band(mode)
	return (float(band[0]) + float(band[1])) * 0.5


static func maximum_speed(
	player: VolleyballPlayer,
	mode: RallyPlayerState.MovementMode,
) -> float:
	return stride_meters(player, mode) * cadence_hz(player, mode)


## The pre-decomposition speed curve, kept in one place instead of three.
##
## `maximum_speed()` above is the model the rally movement system now uses.
## Two other systems were never migrated to it and still run the old
## `lerpf(floor, ceiling, rating)` curve: `ApproachMechanicsSystem` for the
## attack run-up, and `CoverageCalculator` for defensive reach. Both had their
## own inline copy of this arithmetic *and* their own copy of the mass and
## fatigue scaling, with two different ceilings (5.25 and 4.65) and no note
## anywhere saying why they differed.
##
## Consolidating them here changes no behaviour -- each caller keeps its own
## ceiling -- but it turns three scattered copies into one function with the
## divergence stated out loud, so migrating them later is a single edit rather
## than an archaeology exercise. The ceilings genuinely disagree with
## `maximum_speed()`, which reads 3.96 m/s for a maximal approach against this
## curve's 5.25 and 3.25 m/s laterally against 4.65; unifying them is a
## deliberate rebalance, not a cleanup, so it is not done here.
const LEGACY_SPEED_FLOOR_MPS: float = 1.35
const LEGACY_APPROACH_CEILING_MPS: float = 5.25
const LEGACY_COVERAGE_CEILING_MPS: float = 4.65


static func mass_factor(player: VolleyballPlayer) -> float:
	return lerpf(1.06, 0.90, clampf((player.mass_kg - 55.0) / 60.0, 0.0, 1.0))


static func fatigue_factor(player: VolleyballPlayer) -> float:
	return 1.0 - player.fatigue * 0.30


static func legacy_maximum_speed(
	player: VolleyballPlayer,
	speed_rating: float,
	ceiling_mps: float,
) -> float:
	return lerpf(LEGACY_SPEED_FLOOR_MPS, ceiling_mps, speed_rating) \
		* mass_factor(player) * fatigue_factor(player)


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


## Bounds on the turnover term, so an outlier cannot dominate the turn cost.
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
		reference_cadence_hz(mode) / cadence,
		MINIMUM_TURN_FACTOR, MAXIMUM_TURN_FACTOR,
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
