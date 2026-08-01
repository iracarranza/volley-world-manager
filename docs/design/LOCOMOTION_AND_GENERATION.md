# Locomotion Granularity, Timing Disagreement, and Role-First Generation

Review date: 2026-08-01

Status: **PHYSIQUE AND TURNOVER WIRED; THE SPEED-CURVE REPLACEMENT IS NOT**

Findings 1 and 2 below are now fixed. Finding 3 -- replacing the single speed
curve with stride x cadence outright -- remains deliberately unwired, and the
reason is recorded in "What was wired, and what was not" at the end of this
document. Read that section before changing `MODE_STRIDE_SCALE`.

## 1. The two timing paths, measured

`RallySimulator._movement_time()` decides how long a traversal is allotted, and
therefore when contacts happen. `RallyMovementSystem.project_toward()` decides
how far a player gets in a given time, and is what every reachability and
arrival-margin decision rests on. They are separate formulas and nothing had
ever compared them.

Over 235 real traversals across 40 seeds, the ratio of the model's natural time
to the resolver's allotted time:

| | ratio |
|---|---|
| mean | 1.028 |
| median | 1.088 |
| minimum | 0.557 |
| maximum | 1.246 |
| outside 0.70-1.40 | 15.3% |

By phase type:

| Phase | samples | mean ratio |
|---|---|---|
| RECEPTION | 35 | 1.153 |
| SET | 78 | 1.093 |
| DEFENSE | 47 | 1.109 |
| **ATTACK** | 75 | **0.852** |

The headline is not the average -- it is that **the disagreement is systematic
and signed by phase type**. Receptions, sets, and digs all need *more* time than
they are given, so playback compresses them and players are drawn roughly 10%
faster than the model says they move. Attacks need *less*, so hitters are drawn
roughly 15% slower. The two errors point in opposite directions, which is why
the overall mean looks harmless at 1.028 and is not.

About one phase in seven falls outside a band that would read as wrong, and the
worst case is drawn at 56% of the model's pace -- visible slow motion.

This is the compromise 2D playback currently absorbs. It is also step 4's
target: with one timing model the ratio is 1.0 by construction.

## 2. Stride carried no per-player information (fixed)

**Fixed.** `generate_roster()` now recomputes `stride_length_m` from the
player's real height immediately after `_apply_body_variation()`, and
`LocomotionGranularityCalibration` reports a `stale_stride_rate` of 0.0 where it
previously reported 75%. The rest of this section is the original diagnosis,
kept because it explains what the attribute is for.

`VolleyballPlayer.stride_length_m` is documented as correlating with height but
being scouted independently. In practice it does neither, because of an ordering
bug in generation:

```gdscript
player.apply_role_physical_defaults()   # sets stride from the ROLE's base height
_apply_body_variation(player, rng)      # then perturbs height_cm by up to ±8cm
```

Stride is computed before the height it depends on is finalised, and never
recomputed. Measured across 60 generated players, **75% carry a stride that
disagrees with their own height**, and stride varies only by role -- five
distinct values in the whole game.

The consequence reaches further than movement. Stride feeds
`SYSTEM_FIT_APPROACH_DISTANCE`, so ideal approach distance is currently
role-uniform: a 196 cm middle and a 180 cm middle are given the same ideal
run-up.

Fixing the order is a one-line change. It is listed here rather than done
because it shifts every generated roster and therefore every seeded fixture.

## 3. Can stride and cadence be the granulated form of speed?

Ground speed is stride length times cadence. The engine currently produces top
speed from one curve, `lerpf(1.35, 5.25, speed_rating)`, and distinguishes
movement modes only by which rating it feeds in.

Rather than guess mode multipliers, the calibration **inverts** the existing
model: given the speed it produces and a realistic cadence, what stride does it
imply? Across 60 players and four modes:

| Mode | mean implied stride | plausible range | within range |
|---|---|---|---|
| LATERAL | 1.011 m | 0.45-1.00 | **35.0%** |
| BLOCK_CLOSE | 1.011 m | 0.45-1.10 | 98.3% |
| APPROACH | 1.006 m | 0.55-1.30 | 100% |
| TRANSITION | 1.006 m | 0.90-2.00 | 98.3% |

The implied stride is **the same ~1.0 m in every mode**, which is what a single
shared curve necessarily produces. That is fine for an approach and defensible
for a transition run. It is not fine for a lateral shuffle: only 35% of implied
lateral strides are physically plausible, which means the engine currently lets
players shuffle sideways at close to running stride length.

**Verdict: yes, and it corrects a real inconsistency rather than merely
re-expressing one.** But it is not drop-in. Decomposed speeds diverge sharply
from current ones:

| Mode | current | decomposed |
|---|---|---|
| LATERAL | 3.72 | 2.46 |
| BLOCK_CLOSE | 3.72 | 2.61 |
| APPROACH | 3.68 | 3.06 |
| TRANSITION | 3.68 | 5.81 |

Lateral movement drops by a third; transition rises by more than half. That is a
rebalance of defensive range against transition speed, not a refactor. The mode
scale constants in `LocomotionModel.MODE_STRIDE_SCALE` are a first estimate and
would need calibrating against desired outcomes, not against the current curve.

## 4. What this would do to the existing calibrations

An earlier note in this project said a stride model "will break the monotonicity
assertions." That was too strong, and the real risk is more subtle.

**The direct assertions mostly survive.** No progression tier varies height,
mass, or stride -- they set ratings only (`_apply_tier` in the attack, setter,
and reception calibrations). Raising a speed rating still raises cadence, so
speed still improves monotonically, and `true_reach_monotonic` and friends keep
holding.

**The real hazard is a silent leak, not a failure.**
`BlockerProgressionCalibration` pins `lateral_speed`, `acceleration`, and
`transition_speed` to `FIXED_MOVEMENT_RATING` specifically so that reading
attributes are isolated:

```gdscript
## Held fixed intentionally -- see FIXED_MOVEMENT_RATING.
player.lateral_speed = FIXED_MOVEMENT_RATING
```

That pin controls *ratings*. It cannot pin *physique*. If stride entered the
movement profile, per-player height variation -- measured at 0.147 m of stride
spread across a roster -- would flow into blocker movement despite the pin, and
tier differences would partly reflect roster height rather than reading skill.
The assertions would still pass. They would just no longer mean what they say,
which is worse than failing.

**Checked when stride was wired: the leak does not materialise, for a reason
worth stating.** `run()` builds a fresh `GameManager` and calls
`seed_vertical_slice_data()` inside the loop for *every* tier, so all three
tiers face the byte-identical opponent roster and therefore identical heights,
masses, and strides. Physique is held constant across the comparison by
construction rather than by the pin, so it cannot differentiate the tiers. What
does change is the absolute reachability baseline, which is the separate,
expected recalibration noted below -- not a contaminated comparison. The hazard
would return the moment a tier is given its own generated roster, and this
paragraph is the reason not to do that.

**The genuine monotonicity break arrives only if stride becomes tier-varying or
trainable.** Then a longer stride raises top speed and lowers turnover, so a
"better" attribute produces worse short-adjustment reach. That is the documented
tradeoff case the invariant explicitly allows, and it needs its own progression
fixture asserting the tradeoff rather than asserting improvement.

**Separately, any change to `movement_profile()` re-baselines absolute reach.**
Reachability rates recorded across the gate history were measured against the
current curve. That is a recalibration, not a regression, but it must be
expected rather than discovered.

## 5. Role-first generation

Generation currently runs role-first: `apply_role_physical_defaults()` sets
height, mass, wingspan, explosiveness, and reception attributes *from*
`position_role`, and variation is applied afterwards. Role is an essence that
produces a body.

There is a good argument for inverting this -- generate attributes with their
own internal correlations, then assign roles by fit -- and it is stronger here
than a general preference for realism, because **the project's stated product
fantasy depends on it**:

> See what an athlete could become before anyone else does.

Role-first generation makes that discovery impossible in principle. If a middle
blocker is 192 cm *because* they are a middle blocker, then "tall" and "middle"
are the same fact and there is nothing to notice. The interesting management
moment -- a tall outside whose physique suits the middle, a setter with a
libero's reflexes -- cannot occur when the role wrote the body.

Attribute-first generation would also dissolve the stride bug in section 2 by
construction: with no role-derived physique step, stride would derive from the
height the player actually has.

The full specification, including the talent-budget model, the separate physique
stream, consumable potential, and region cluster biases, is in
[Attribute-First Generation](ATTRIBUTE_FIRST_GENERATION.md).

Three things need care before attempting it:

1. **Role currently modifies physics, not just labels.**
   `POSITION_APPROACH_STEP_MODIFIER` and `POSITION_APPROACH_TOLERANCE_MODIFIER`
   key off `position_role`. If role becomes a derived assignment, those
   modifiers become circular -- attributes determine role determines approach
   mechanics determines fit. They would need to key off attributes directly.
2. **Natural role and assigned role should be separate fields.** The music
   analogy is exact: a player may be best suited to one role, assigned another,
   and personally suited to a third. The `SystemFitProfile` machinery already
   models "how well does this player fit this system" and is the natural home
   for "how well does this player fit this role."
3. **It moves every seed in the project.** Generation feeds every fixture. This
   is the same blast radius as step 4 and should not share a change with it.

## What was wired, and what was not

Two of the three factors above are now consumed by
`RallyMovementSystem.movement_profile()`, which is the single chokepoint every
movement decision passes through -- `project_toward()`, `traversal_seconds()`,
`estimate_movement()`, the stepper, reachability, and arrival margins all read
it. The third, replacing the speed curve itself, is not.

### Wired: stride as the physique term

`LocomotionModel.stride_factor(player, mode)` returns a multiplier centred on
1.0, computed from the player's stride against `REFERENCE_STRIDE_M` (the stride
of a 193 cm player, the roster's central height) and scaled by a per-mode
sensitivity: a transition run is close to pure leg length (1.00), a lateral
shuffle mostly turnover (0.35).

This closes an asymmetry that had been in the engine from the start. Height
raised mass, mass lowered top speed, and nothing anywhere gave any of it back --
so being tall was a flat penalty in movement, and the region physique work made
the taller regions strictly worse at moving. Measured before the change, Pāwa
Hitō was the tallest region *and the slowest laterally*. Stride is the term real
biomechanics supplies in return.

Two players with identical ratings, differing only in build:

| Build | stride | transition | lateral |
|---|---|---|---|
| 180 cm / 68 kg | 0.774 m | 3.533 | **3.699** |
| 195 cm / 79 kg | 0.839 m | 3.716 | 3.691 |
| 210 cm / 90 kg | 0.903 m | **3.881** | 3.677 |

The crossover is the point. The tall player is about 10% faster in a straight
line and slightly slower sideways; the short player is the reverse. That is the
middle-blocker/libero distinction the single curve could not express at all.

### Wired: cadence as the frequency of direction change

`direction_change_delay` was `lerpf(0.20, 0.02, facing_fit)` -- pure geometry.
A libero with 95 lateral speed and a middle blocker with 20 reversed direction
in exactly the same 0.200 s. Turnover is literally the frequency at which a
player can change where they are going, so
`LocomotionModel.direction_change_seconds()` now scales that geometric cost by
the player's cadence against a reference:

| lateral speed | cadence | full reversal costs |
|---|---|---|
| 20 | 2.80 Hz | 0.243 s |
| 50 | 3.40 Hz | 0.200 s |
| 95 | 4.30 Hz | 0.158 s |

### Neither moved the population's mean

Both terms are centred on an average body and an average rating, so they change
who is fast without changing how fast the sport is:

| Mode | mean before | mean after | shift |
|---|---|---|---|
| LATERAL | 3.3675 | 3.3754 | +0.23% |
| TRANSITION | 2.9807 | 3.0012 | +0.69% |
| APPROACH | 2.9807 | 2.9971 | +0.55% |
| BLOCK_CLOSE | 3.3675 | 3.3776 | +0.30% |

That is the property that made this safe to wire without reopening the gate
record: no existing reachability, arrival-margin, or progression calibration is
rebalanced, because the average player moves as they always did.

### Not wired: replacing the speed curve

Swapping `lerpf(1.35, 5.25, rating)` for `stride_meters() * cadence_hz()`
outright would rebalance the game rather than re-express it, and the obstacle is
arithmetic rather than taste.

The existing curve spans a **3.89x** ratio from the worst mover to the best.
Human cadence spans about 1.8x, and stride varies only a few percent across a
roster of athletes. No plausible pair of physical factors multiplies out to
3.89x, which means something in the current curve is not physical -- and it is
the floor. A professional moving at 1.35 m/s is walking; no rating should
describe that.

Adopting the decomposition wholesale moves mean transition speed from about 2.9
to about 5.2 m/s and mean lateral speed from about 3.3 down to about 2.3 -- in
opposite directions, per mode. Every reachability and arrival-margin number in
the gate record rests on those speeds.

So that change is a deliberate rebalance and belongs in its own commit, with its
own before-and-after sweep, exactly as the movement-fluidity record demands of
step 4. It is the remaining half of this work, not an oversight.

### Two defects this exposed

**`estimate_movement()` was a second copy of the profile.** It restated the
speed curve, mass penalty, fatigue factor, facing fit, and turn delay inline, so
wiring stride into `_movement_profile()` alone would have left the two silently
disagreeing about how fast the same player moves. It now calls
`_movement_profile()`. This is the same defect class as the generator's
duplicated role tiers, found the same way.

**The stepper assumed a fixed turn floor.** `ShadowMovementSystem` hard-coded
`ALIGNED_TURN_DELAY = 0.02` and handed exactly that back to each step so the
slice moved for its full duration. Once the aligned cost became a function of
the player's cadence, that constant was wrong by up to 30% per step, thirty
times a second -- which would have quietly broken the exact agreement between
stepped and closed-form traversal that `MovementIntegrationCalibration` proves
at 100%. The stepper now measures the aligned charge from the same profile
instead of assuming it, and that calibration still reports exact agreement.
