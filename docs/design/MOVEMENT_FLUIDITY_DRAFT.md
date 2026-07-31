# Movement Fluidity

Review date: 2026-07-31

Status: **STEPS 1-3 COMPLETE; PLAYBACK NOW SAMPLES THE MOVEMENT MODEL**

The goal is for playback to be a byproduct of the simulator: the drawing layer
should sample what the simulator computed, never invent anything, and therefore
be innately accurate without visual tuning. Ball flight already works this way --
`BallTrajectory` is a real function of time and playback merely samples it.
Player movement does not: the simulator emits endpoints and playback guesses the
path between them.

Steps 1 and 2 are now built. Nothing is wired into the resolver or playback, and
no rally outcome changes.

## What was wrong

`TacticalCourt._set_playback_progress()` drives players with
`start.lerp(target, value)`, so a player leaves rest at full speed, holds it,
and stops dead. With an approach waypoint it splits the phase at a hard-coded
`waypoint_share = 0.46` regardless of geometry, and flips direction instantly at
that instant.

None of those three numbers are simulator data. They are view-layer inventions
filling a gap the simulator left open, which is exactly what makes playback feel
like it needs tuning.

## The correction to the first draft

The first version of this document proposed a closed-form replacement
(`MovementContinuityDraft`: cubic Hermite speed curve, Bezier-rounded corner).
**That module has been deleted.** It was written before finding that
`RallyMovementSystem.project_toward()` already is a proper kinematic step
function:

- it reads `actor.velocity.dot(direction)` as its starting speed, so carried
  velocity was already handled;
- `maximum_speed`, `acceleration`, and `direction_change_delay` all come from
  `movement_profile()`, derived from player ratings, mass, and fatigue;
- it operates on `actor.snapshot()` and returns a full `RallyPlayerState` with
  position and velocity applied -- its output is its own input type.

The Hermite curve was a geometric imitation, tuned by hand, of physics the
engine already computed from ratings. The corner rounding likewise: because
`forward_speed` is a dot product against the new heading, a player who re-aims
automatically sheds the off-axis component of their speed and must re-accelerate.
The curve and its speed dip are **emergent from the existing model**, not
something to author.

## What is built

**`ShadowMovementSystem.integrate()`** loops `project_toward()` at a fixed step
over a snapshot and records the sampled trail. Two adaptations were required,
and both are physical rather than cosmetic.

**1. The turn cost is a per-call constant.** `project_toward()` subtracts
`direction_change_delay` (0.02-0.20 s) from *every call's* duration. That is
correct when a call covers a whole phase and catastrophic when it covers 33 ms:
a naive loop charges a player up to 0.20 s of turning thirty times a second, and
they barely move. The delay is therefore paid **once**, from the actor's true
starting facing; each subsequent step aligns facing with travel so the charge
collapses to its 0.02 s floor, which is added back to the requested step so the
effective moved time is exactly the step.

This is the single most important finding here. `project_toward()` is a
phase-scale projector, and it is not composable at small steps without this
compensation.

**2. Arrival zeroes velocity.** Correct for arriving at a contact, wrong for a
waypoint, which is passed through. On reaching a waypoint the travel velocity is
preserved and the next step's dot product sheds what does not carry over.

**`MovementIntegrationCalibration.run()`** answers the question that has to be
settled before trails could ever become authoritative: does stepping land where
the engine's existing projection lands? Every reachability, arrival-margin, and
opportunity decision is built on `project_toward()`. If stepping disagreed,
adopting trails would silently move all of them.

## Measured results

Over 576 comparisons per step size, harvested from real seeded rally states
(real ratings, masses, fatigue, geometry):

| Step | Mean disagreement | Worst | Reach agreement |
|---|---|---|---|
| 60 Hz | 0.0000 m | 0.0000 m | 100% |
| 30 Hz | 0.0000 m | 0.0000 m | 100% |
| 15 Hz | 0.0000 m | 0.0000 m | 100% |

Exact, at every step size. That is the expected result rather than a lucky one:
constant-acceleration kinematics compose exactly across sub-intervals, so a
faithful stepper *should* reproduce the single-call projection to floating-point
noise. Trails are a refinement of the existing model, not a replacement, and the
whole existing calibration record survives adoption.

**The sweep was proved able to fail.** With the turn-delay compensation removed,
the same sweep reports:

| Step | Mean disagreement | Worst | Within tolerance |
|---|---|---|---|
| 60 Hz | 1.1336 m | 3.0092 m | 10.4% |
| 30 Hz | 0.9212 m | 2.4316 m | 11.5% |
| 15 Hz | 0.5090 m | 1.2824 m | 21.9% |

Note the error *grows as the step shrinks* -- the signature of a per-call cost
being charged more often. Without this check the naive loop would have shipped
players arriving up to three metres short, and it would have looked like a
tuning problem rather than a composition bug.

**The fixed waypoint share is gone by construction.** On an approach with a late
waypoint, integration reaches it at **time fraction 0.844**, because that is
when the player physically arrives. The playback tween would have pivoted at
0.46. Measured speeds across that corner run 0.150 -> 1.393 m/s with no stall:
the player carries through it rather than stopping.

## Step 3, done: playback samples instead of interpolating

`TacticalCourt._set_playback_progress()` no longer interpolates. At phase start,
`_build_movement_paths()` integrates each moving player's traversal through
`ShadowMovementSystem` and stores the sampled points; `_set_playback_progress()`
then samples that. The `0.46` waypoint share is gone, and so is the
straight-line lerp.

**Three view-layer inventions were removed, not replaced with better ones.**

1. The fixed `waypoint_share = 0.46`. A waypoint is now reached when the player
   has covered the distance to it. On the fixture geometry that lands past 0.55
   of the phase, and on the earlier probe at 0.844.
2. The straight-line interpolation between endpoints, replaced by the
   rating-driven traversal.
3. **The tween's `TRANS_QUAD` / `EASE_IN_OUT`.** This one was not in the
   original list and is the subtler defect. The tween eased the *progress value
   itself*, so it warped every phase with a curve nothing in the simulation
   chose -- and it silently contradicted the ball work that had just made serves
   and spikes constant-speed, because the ease was still bending them. The tween
   is now `TRANS_LINEAR`. Acceleration comes from the traversal; ball flight,
   being a function of time, advances at a constant rate.

**Transport: none.** The original plan was to ship trails through
`RallyEvent.metadata`. That turned out to be the wrong shape, because the
simulator only knows the *actor's* movement -- the supporting players' targets
are derived by `_unit_support_targets()` inside playback, so the resolver has
nothing to ship for them. Rather than run two different code paths, playback
invokes the same shared, rating-driven model for every moving player. No
metadata, no serialization cost, no record-rate decision.

That is still a byproduct of the simulator in the sense that matters: the motion
comes from `RallyMovementSystem`'s ratings-derived kinematics, and playback
contributes no constants of its own. It is not yet the stronger form where the
resolver computes motion and playback purely consumes it. That arrives with step
4, when movement becomes resolver-owned.

**One honest compromise.** `RallySimulator._movement_time()` and
`RallyMovementSystem.project_toward()` are different code paths and disagree on
how long a traversal naturally takes. Playback must honour the resolved
endpoints and the resolved duration or it would contradict the event it is
drawing, so the integrated traversal is renormalised onto the phase: the
*shape* is the model's, the *rate* is the resolver's. Reconciling those two
timing paths is part of step 4.

## Remaining step

**Step 4 -- movement becomes resolver-owned and authoritative for
reachability.** Audit, guarded boundary, development promotion, in the shape
Gates 47-49 used. This is the step that moves seeds, and the exact-agreement
result above is the evidence it can be attempted at all. It also subsumes the
renormalisation compromise, because there would be one timing model rather than
two.

## Open questions before step 4

1. **Does the information boundary hold?** A continuously-moving player is
   reacting to something, and that something must be perceived rather than
   authoritative -- the boundary Gates 31 to 47 defend. A player who begins
   transitioning at the instant the ball's true destination is fixed is reading
   truth.
2. **What happens to `ActionOpportunityWindow`?** Windows open and close at
   scheduled moments. Continuous movement makes reachability a function of time,
   and the two models need reconciling rather than coexisting.
3. **Where does `RallyMoment.Kind.MOVEMENT_UPDATE` fit?** It is declared and
   referenced nowhere else in the codebase. It is the natural scheduler hook for
   step 4, and it is still empty.
