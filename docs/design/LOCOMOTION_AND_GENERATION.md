# Locomotion Granularity, Timing Disagreement, and Role-First Generation

Review date: 2026-07-31

Status: **MEASURED; NOTHING WIRED**

Three related findings, all read-only. `LocomotionModel`,
`LocomotionGranularityCalibration`, and `MovementTimingRatioCalibration` exist
and are exercised by the suite; none of them changes an outcome.

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

## 2. Stride carries no per-player information today

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
