# Movement Fluidity

Review date: 2026-07-31

Status: **STEPS 1-4 COMPLETE; ONE MOVEMENT MODEL**

The goal is for playback to be a byproduct of the simulator: the drawing layer
should sample what the simulator computed, never invent anything, and therefore
be innately accurate without visual tuning. Ball flight already works this way --
`BallTrajectory` is a real function of time and playback merely samples it.
Player movement does not: the simulator emits endpoints and playback guesses the
path between them.

Steps 1 through 4 are built. Playback samples the movement model rather than
interpolating, and the resolver and that model now share one clock.

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

That is a byproduct of the simulator in the sense that matters: the motion comes
from `RallyMovementSystem`'s ratings-derived kinematics, and playback
contributes no constants of its own.

**The compromise step 3 carried has since been removed.** It renormalised the
model's traversal onto the resolver's duration because the two disagreed. Step 4
made them agree, so that renormalisation is now an identity in practice and
survives only as a guarantee that playback ends exactly on the resolved
endpoint.

## Step 4, done: one movement model

`RallySimulator._movement_time()` carried its own formula -- a constant-velocity
trip plus a flat startup penalty, with no fatigue and a distance-scaled turn
cost. It now calls `RallyMovementSystem.traversal_seconds()`, the closed-form
inverse of `project_toward()`, so one model answers both *how far in a given
time* and *how long for a given distance*.

Measured across 40 seeds, before and after:

| | before | after |
|---|---|---|
| mean ratio | 1.028 | 1.008 |
| median | 1.088 | 1.007 |
| range | 0.557 - 1.246 | 0.969 - 1.043 |
| outside 0.70-1.40 | 15.3% | 0.0% |
| RECEPTION | 1.153 | 1.010 |
| SET | 1.093 | 1.007 |
| DEFENSE | 1.109 | 1.011 |
| ATTACK | 0.852 | 1.007 |

The residual ~1% is discretisation, not disagreement: the sweep measures the
stepped integrator while the resolver uses the closed form. A regression check
asserts the two land within one step of each other.

**A second defect surfaced while closing the gap.** Attacks did not converge
with the others; pointing `_movement_time()` at the shared model moved them from
0.852 to 0.794, the wrong way. The cause was not the timing model at all.
`ApproachMechanicsSystem.prepare_for_attack()` relocates `hitter_start` to the
staging mark *after* `hitter_move_time` was computed, so the attack event
recorded a staged start paired with the unstaged duration -- and playback drew
the hitter covering the short leg at the long leg's pace. Both the duration and
the arrival margin are now recomputed once staging is known, over the real
staged route via `traversal_seconds()`'s waypoint form. This is the same class
of bug as the stale stride: a value computed before its input was final.

## Step 4 follow-up: staged preparation drawn one leg early

Unifying timing exposed a sequencing defect distinct from timing itself.
Playback draws each player's motion as one animated leg per `RallyEvent`, keyed
to *that event's* actor. A player who is not yet the actor -- the setter while
the serve is still in flight, the hitter while the set is still in flight --
was drawn with a generic side-lerp support target instead of toward the
position the resolver had already staged them for. The correction only became
visible once they *became* the actor: the setter appeared to run backwards
during serve receive before snapping onto the real line to `set_contact`, and
the hitter's approach-mark relocation and their approach run were drawn as one
combined motion starting only after the set went up, because the waypoint to
`approach_start_position` was never reachable before that leg began.

The resolver already computes both staging positions before it needs them --
`setter_start` from `_spatial_setter_choice()`, and the hitter's staged
`hitter_start` from `ApproachMechanicsSystem.prepare_for_attack()` -- it simply
had nowhere to put them early enough for playback to use. Both call sites (the
serve-receive attack and the transition/continuation attack) now stamp
`staged_next_actor_id` / `staged_next_position` onto the *preceding* event
(`RECEPTION` for the setter, `SET` for the hitter). `TacticalCourt._unit_support_targets()`
honors that hint ahead of the generic side lerp, so the preparatory leg carries
the player to exactly where the following leg's `movement_start` expects them.
Verified against seed 1001: the `RECEPTION` event's staged position for the
setter now equals the `SET` event's `movement_start` exactly, and the `SET`
event's staged position for the hitter equals the `ATTACK` event's
`movement_start` exactly -- both legs now hand off with zero correction.

## Step 4 follow-up: the approach run was silently falling back to a raw lerp

Fixing the handoff above exposed a second, independent defect in the leg it
handed off *into*. The hitter's approach run to contact was still drawn
unevenly -- accelerating oddly rather than running the model's real curve --
and the cause was structural, not cosmetic.

`ApproachMechanicsSystem.prepare_for_attack()` reports `approach_start_position`
as wherever the hitter's preparation window actually left them, by deliberate
design (its own comment: "playback must render where the hitter physically
ended up, not where they were trying to get to"). That means the value is
always identical to `hitter_start` -- the same point the approach leg already
starts from, not a distinct corner partway to contact.

`TacticalCourt._integrate_phase_path()` fed that value through to
`ShadowMovementSystem.integrate()` as a real waypoint regardless. The stepper's
first move is toward the waypoint; when the waypoint *is* the start, that first
direction is a zero-length vector, and the loop's `if direction == Vector2.ZERO:
break` fires on step one. The traversal aborts with a single-point trail,
`_build_movement_paths()` discards it, and playback falls back to
`start.lerp(target, value)` -- the exact straight, unaccelerated interpolation
steps 1 through 4 were built to retire, reintroduced silently for every normal
attack's approach run, because the fallback path has no error to surface.

The fix treats a waypoint coincident with its own leg's start as absent:
`_integrate_phase_path()` now checks `start.distance_to(waypoint) <= 0.0005`
before deciding whether there is a real corner, so a degenerate waypoint drops
the leg to `MovementMode.TRANSITION` and the stepper moves toward the actual
target from its first sample. A genuine waypoint -- one that differs from the
leg's start, such as the live-attack path's fallback through
`_approach_start_position()` -- is unaffected. A regression check
(`tests/test_runner.gd`) sets `unit_movement_waypoints` equal to
`unit_movement_starts` directly and asserts the sampled path still reaches 20+
points and both resolved endpoints; reverting the fix fails that check with a
one-point aborted trail.

## Playback loop follow-up: a contact event replayed its own arrival

Attack and block resolve fractions of a second apart in the resolver, but
playback drew them as two visibly sequential beats. The cause was in
`_play_rally()` (`scenes/main/main.gd`), not in the timing values: an event
consumed as another event's `next_contact` (e.g. `BLOCK` following `ATTACK`'s
own ball-flight leg) already had its mover fully arrive and make contact
during that leg. When the loop then reached that same event on its own turn,
`has_movement` was still true, so it replayed the *entire* approach --
`movement_phase_targets()` pre-positioning, a contact-window pause, then the
contact flash -- a second time for a mover who was already there. That second,
redundant beat is what read as "the block happens after the attack" instead of
landing with it.

The loop now remembers which event a spatial transition just delivered its
mover to (`arrived_via_transition`). On that event's own turn, its pre-contact
`movement_phase_targets()` is skipped -- no second approach, no repositioning
-- while the contact-window pause and any post-contact recovery movement are
unaffected. This generalizes past attack/block: any contact event that
followed a preceding spatial transition gets the same treatment, since the
redundant-arrival pattern was universal, not attack/block-specific.
This is the stopgap called for in the open question above, not the general
fix -- the general fix is the continuous clock described there.

## Remaining

Movement is now one model, but it is still *resolver-allotted* rather than
resolver-integrated: `_movement_time()` answers how long a traversal takes and
the phase is built around that answer, rather than players being stepped
continuously against a rally clock. Going further would mean scheduling
`RallyMoment.Kind.MOVEMENT_UPDATE`, which remains declared and unused. That is a
scheduler change, not a movement change, and is not required for playback to be
faithful.

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
