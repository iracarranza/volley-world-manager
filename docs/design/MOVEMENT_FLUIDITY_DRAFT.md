# Movement Fluidity: Draft Implementation

Review date: 2026-07-31

Status: **DRAFT; MODULE VERIFIED BUT NOT WIRED**

This is not a gate. It proposes changing how player motion is expressed
throughout the engine, which touches the persistent movement model every
completed gate sits on. It is therefore drafted, tested in isolation, and left
unwired so that adopting it is a separate, deliberate decision.

`scripts/simulation/movement_continuity_draft.gd` exists and is exercised by
five checks in `_test_movement_continuity_draft`. Nothing calls it.

## The three defects

**1. Motion is piecewise-linear.** `TacticalCourt._set_playback_progress()`
drives players with `start.lerp(target, value)`. A player therefore leaves rest
already at full speed, holds exactly that speed the whole way, and stops dead on
arrival. No acceleration exists anywhere in the visual model.

**2. The waypoint split is a fixed constant.** With an approach waypoint the
phase is cut at `waypoint_share = 0.46` regardless of geometry:

```gdscript
var staged_position := start.lerp(waypoint, value / waypoint_share) \
    if value <= waypoint_share \
    else waypoint.lerp(target, (value - waypoint_share) / (1.0 - waypoint_share))
```

If the waypoint sits 80% of the way along the route, the player crawls to it
across the first 46% of the phase and then sprints the remaining 20% of the
distance in 54% of the time. The timing contradicts the geometry.

**3. Direction changes instantaneously.** At `value == 0.46` the velocity vector
flips from the first leg's direction to the second's in a single frame. This is
the most visible defect and the one no real player produces.

There is a fourth, structural issue behind all three: **every phase begins and
ends at rest**, because each phase is an independent tween. A hitter who is
already moving when their responsibility releases is redrawn as stationary at
the start of the next phase.

## What the draft changes

Same inputs (start, optional waypoint, target, duration) plus two new ones:
`entry_speed` and `exit_speed`.

**Timing follows arc length.** The route is converted to a polyline with a
cumulative distance table, and progress is computed in distance rather than in
per-leg fractions. The waypoint is reached when the player has actually covered
the distance to it. The 0.46 constant disappears.

**The corner is rounded.** Instead of pivoting on the waypoint, the path enters
and leaves a quadratic Bezier whose control point is the waypoint, with a blend
radius of `CORNER_BLEND` (0.35) times the shorter leg. The Bezier's tangent at
its endpoints equals the adjoining straight legs' directions, so direction is
continuous through the corner. The curve is sampled at `ARC_SAMPLES` (24)
segments, which keeps the residual per-segment direction step near two degrees.

**Speed is a cubic Hermite on distance.** With `s(0)=0`, `s(T)=L`, `s'(0)=v_in`,
and `s'(T)=v_out`:

```
s(u) = (u³ - 2u² + u)·v_in·T + (3u² - 2u³)·L + (u³ - u²)·v_out·T
```

From rest to rest this is a smooth ease-in-out. With carried speed it matches
both endpoints exactly, which is what lets one phase hand its velocity to the
next. Endpoint speeds are clamped to `3L/T` (`MONOTONIC_SPEED_LIMIT`) because
above that a cubic Hermite stops being monotonic and the player would visibly
reverse mid-phase to satisfy its endpoints.

The module is pure: no `RallyState`, no mutation, no RNG. That is deliberate --
it means playback and the resolver can share it without disagreeing, which is
the whole point of doing this once rather than twice.

## Adoption in three phases

Each phase is independently shippable. They are ordered by increasing risk, and
**the first two do not change any rally outcome**.

### Phase 1 -- playback only (no simulation change, no seed movement)

Replace the body of `TacticalCourt._set_playback_progress()` with
`sample_progress()` against a path built from the same
`unit_movement_starts` / `unit_movement_waypoints` / `unit_movement_targets`
already populated today, with `entry_speed` and `exit_speed` left at zero.

Every rally outcome, event, and seed is untouched -- this changes only where a
marker is drawn between two already-resolved endpoints. It fixes defects 1, 2
and 3 visually and is safe to ship on its own.

### Phase 2 -- carried speed across phases (still no outcome change)

Record each phase's exit speed on the event metadata and feed it as the next
phase's `entry_speed`. Players stop restarting from rest between phases. Still
purely presentational; the resolved positions at phase boundaries are unchanged,
only the speed profile between them.

This is where the user-visible complaint about hitters "already moving after the
first contact" is genuinely answered, because a hitter whose previous phase
ended with velocity now visibly carries it.

### Phase 3 -- continuous release timing (changes outcomes; will move seeds)

The real change, and the one to do alone. Today
`ApproachMechanicsSystem.prepare_for_attack()` computes a single `release_time`
from perceived responsibility, and the hitter's motion is one
start-waypoint-target triple resolved per event. Phase 3 replaces the discrete
release with continuous availability: a player begins transitioning the moment
their responsibility is perceptibly finished, sampled against the ball clock
rather than at phase boundaries.

**This will change rally outcomes and move seeds across the entire suite.**
Fixed-seed fixtures throughout the gate record -- Gate 42's promoted attack at
seed 300062, Gate 49's promoted block on the same seed, and every calibration
sweep -- will need re-selection, exactly as Gate 42's seed already had to be
re-chosen once when serve-receive assignment changed.

Do not start Phase 3 in the same change as anything else, and do not start it
without re-running every calibration record in `docs/calibration/`.

## Open questions to settle before Phase 3

1. **Where does acceleration come from?** The draft takes speeds as inputs and
   says nothing about how fast a player can change them. `acceleration`,
   `transition_speed`, and `explosiveness` already exist as ratings; the
   monotonic-progression invariant means a better-rated player must not lose
   options, so the mapping needs a progression fixture of its own.
2. **Does the information boundary hold?** A continuously-releasing player is
   reacting to something. Whatever that something is must be perceived, not
   authoritative -- the same boundary Gates 31 to 47 defend. A player who begins
   transitioning at the instant the ball's true destination is fixed would be
   reading truth.
3. **What happens to `ActionOpportunityWindow`?** Windows are currently opened
   and closed at scheduled moments. Continuous movement makes reachability a
   function of time rather than a per-window verdict, and the two models need
   reconciling rather than coexisting.
