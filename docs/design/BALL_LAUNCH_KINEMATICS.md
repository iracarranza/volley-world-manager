# Force-Derived Ball Flight Timing

Review date: 2026-07-31

Status: **LIVE; OFFICIAL RESOLUTION PATH CHANGED**

## What was wrong

Every ball action's flight duration in `RallySimulator` was a hand-tuned
formula or lookup table with no connection to the distance the ball actually
travels:

- `SET_FLIGHT_TIME_BY_TEMPO` -- a 4-entry array indexed by `assignment.tempo`.
  A quick set to an adjacent lane and a quick set the length of the court took
  identically 0.34 seconds.
- `_serve_flight_time(server, serve_quality)` -- power, quality, and style
  only. A serve to the nearest zone and a serve to the deepest corner took the
  same time.
- `_attack_flight_time(attack_quality, attack_type)` -- quality and type only.

Apex height was then a `lerp` of that duration's position in the table, not
anything physical. None of these numbers were force: they were durations
picked to look right, with speed and shape never entering the calculation.
This is what the user meant by "in-rally kinematic actions should never be
hard coded" -- duration was always an *input*, never something the resolver
derived.

## The model

Standard projectile motion, launched and landing at equal height, no drag.
Given real court distance `R` (`RallyKinematics.court_distance_meters`,
already meters -- the court is regulation 9m x 18m) and a launch angle `θ`:

```
v = sqrt(R * g / sin(2θ))       -- required launch speed
T = sqrt(2 * R * tan(θ) / g)    -- flight duration
h = (R / 4) * tan(θ)            -- apex height
```

with `g = 9.8` (real gravity; no invented "feel" constant needed once `θ` is
sanely bounded -- see below). Implemented once, generically, as
`RallyKinematics.solve_launch_arc(distance_meters, launch_angle_degrees,
gravity_mps2)`.

**`θ` is the only free input.** Speed is always exactly what the geometry
requires to land on the known target at that angle and distance -- that *is*
"attempt to use an appropriate amount of force," not a separate dial.
Duration and apex are outputs, never chosen.

This algebra was independently verified twice (once by the author, once
externally) before implementation, and cross-checked against a third,
different parameterization (fixed-duration velocity-solving, standard in true
3D engines) that was deliberately rejected -- see "Why not solve for velocity
from a fixed duration" below.

## Where `θ` comes from: shot shape, not force, is the tunable

`θ` represents *intended tempo/shot shape*, not force directly -- force
follows from shape and distance. Each action maps its existing decision
input to a base angle range, narrows it by rating, and jitters it by contact
quality, in three new functions in `rally_simulator.gd`:

- `_set_launch_angle_degrees(setter, tempo, quality)`: base range by
  `assignment.tempo` (0="quick" 6-10°, 1: 12-18°, 2: 25-35°, 3="high ball"
  45-55°). `tempo` is already the real tactical input -- chosen by the called
  offensive play, never hardcoded -- this function only changes what a tempo
  *means physically*.
- `_serve_launch_angle_degrees(server, quality)`: base range by
  `primary_serve_style` (Jump Topspin 10-16°, Hybrid 12-18°, Jump Float
  14-20°, Standing 16-24°, Sky Ball 55-65°).
- `_attack_launch_angle_degrees(hitter, attack_type, quality)`: base range by
  hit/attack type (Quick attack 5-8°, Power swing 6-10°, Pipe/Line/Seam attack
  8-14°, High-ball swing 10-16°, Controlled roll/Roll shot 20-30°, Emergency
  tip/Short tip 22-32°). Covers both the home-side `_hit_type()` vocabulary and
  the opponent-side `_opponent_attack_type()` vocabulary, since both feed the
  same trajectory construction.

All three share `_jittered_launch_angle(min, max, skill, quality)`: a higher
rating shifts the intended angle toward the flatter, harder-to-defend end of
the range (better technique reliably executes a faster, lower shot); lower
contact quality jitters the *actual* angle away from what was intended, still
clamped inside the same safe range. Skill decides what to attempt; quality
decides how well it was executed -- a materially deeper use of "quality" than
a disconnected duration table.

## Why the angle must be clamped, and to what

Unclamped, the model has two real failure modes: `θ → 90°` sends `tan(θ) →
∞`, and this game's actual distances make even moderate-looking angles
absurd:

| R (m) | θ | T (s) | h (m) |
|---|---|---|---|
| 9 | 80° | 3.23 | 12.76 |
| 9 | 55° | 1.62 | 3.21 |
| 3 | 55° | 0.94 | 1.07 |
| 9 | 8° | 0.51 | 0.32 |
| 3 | 8° | 0.29 | 0.11 |

80° breaks down completely at 9m. `RallyKinematics.MIN_LAUNCH_ANGLE_DEGREES`
(2°) and `MAX_LAUNCH_ANGLE_DEGREES` (75°) are a hard, defensive floor/ceiling
inside `solve_launch_arc()` itself -- every per-action range above sits well
inside it, so no caller needs to reason about the clamp, but nothing can
escape it even if one did.

Downward/driven attacks are represented as a small **positive** `θ` near the
floor (flat, fast, minimal apex) -- never a negative angle. There is no real
launch/landing height asymmetry modeled in this 2D court-position engine
(serve, set, and attack contacts all happen at the same implicit height) for a
negative angle to represent; a driven spike is simply the flattest end of the
same domain a quick set lives in, not a different domain.

## Why not solve for velocity from a fixed duration

The standard alternative (used in most 3D games): parameterize by known
start/end 3D positions and a *chosen* flight duration `T`, then solve
`v_y = [(y_1 - y_0) + ½gT²] / T` for whatever vertical velocity makes that
land in that time. This is numerically robust -- no domain errors, handles
asymmetric heights -- and was seriously considered.

It was rejected because it takes `T` as an input. Something still has to
supply that duration, and the only way to do so here is to pick it -- which
is `SET_FLIGHT_TIME_BY_TEMPO` again, laundered through a fancier equation.
The `θ`-based model's duration is an *output*; adopting the alternative would
have quietly restored exactly the hardcoding this change exists to remove.

3D replay now applies the hybrid presentation boundary without replacing this
solver. The resolver exposes its result explicitly as `apex_rise_meters` and
keeps duration force-derived. `MatchScreen._display_trajectory()` combines
that rise with snapshotted player standing/jump reach to construct absolute
launch, contact and apex heights for rendering. Event-specific vertical
emphasis makes the compressed stationary camera readable, but never changes
`T`, horizontal geometry, contact ownership or outcomes.

## Scope

**In scope, this change:** every deliberately-chosen serve, set, and attack
trajectory, both sides, including the transition/continuation paths. Two
pre-existing gaps were closed as a side effect of touching these sites: the
home serve and both continuation (set and attack) events previously built no
explicit `outgoing_trajectory` at all and silently fell through to
`_ensure_event_trajectories()`'s own hardcoded fallback (0.72s/0.5 apex for
serve, 0.42s/0.5 apex for attack) -- these now build their own trajectory
explicitly, like every other site.

**Out of scope, deliberately:**
- Block deflection and reactive dig/coverage-pass trajectories keep their
  short hardcoded durations. `solve_launch_arc()` is general enough to extend
  to them later, but a reactive touch is not a deliberately chosen shot shape,
  and that's a different problem than this one.
- Authoritative asymmetric-height projectile resolution and net-collision
  physics remain out of scope. Current absolute heights are presentation data.
- Opponent attack's `ApproachMechanicsSystem` mirror (Gate 43) and
  `set_release_interval` wiring are unrelated pre-existing gaps, untouched
  here.

## Verification

`_test_ball_kinematics_force_derived` in `tests/test_runner.gd`:

1. `solve_launch_arc` matches the hand-verified formula exactly at two spot
   checks (flat 9m/8°, lofted 9m/55°) -- not merely self-consistent with
   whatever the implementation happens to compute.
2. The core claim: the same launch angle at two different distances produces
   measurably different duration *and* apex (>1.5x at 3m vs. 8m) -- the
   behavior that was previously entirely absent.
3. No angle (including deliberately out-of-domain input) or distance
   (including 0 and 40m) produces NaN, Inf, or a non-positive duration.
4. An algebraic invariant that eliminates `θ` between the duration and apex
   formulas -- `T = sqrt(8h/g)` -- holds for every serve/set/attack
   `outgoing_trajectory` across 8 real seeded rallies. This is the strongest
   check: it proves the *resolver's actual output* satisfies the physics,
   not just that the primitive function does when called in isolation.

Full suite: 424 checks passing (419 before this change). This is the first
change in this project's session history to alter the official
`RallySimulator.resolve()` path on purpose -- every prior gate was
shadow-only or purely visual. No existing test pinned an old hardcoded
duration value, so none needed correcting.
