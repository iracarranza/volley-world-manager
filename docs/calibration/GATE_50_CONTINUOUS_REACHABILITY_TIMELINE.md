# Gate 50: Continuous Reachability Timeline

Review date: 2026-07-31

Status: **PASS; SHADOW-ONLY; NO ROLLOUT, NO FLAG, NO PROMOTION**

Movement fluidity steps 1 through 4 made 2D playback sample the engine's real
kinematic model and unified the two timing paths that used to disagree. What
remained open, named explicitly in `docs/design/MOVEMENT_FLUIDITY_DRAFT.md`:
movement is still *resolver-allotted* rather than *resolver-integrated* --
reachability is defined only at Gate 6's three scheduled perception reads plus
the contact deadline, and nothing is evaluated between them.
`RallyMoment.Kind.MOVEMENT_UPDATE` was declared and never scheduled anywhere.

Gate 50 schedules it, for the first time, inside
`RallyOpportunitySystem.evaluate_reception_timeline()` -- the only place in the
codebase that already runs a `RallyMoment` priority queue over a live
`RallyState` snapshot. It changes nothing about what the discrete model
decides; it adds a second, continuous answer to the same question and reports
where the two disagree.

## The information boundary holds by construction, not by discipline

A `MOVEMENT_UPDATE` tick reads exactly one thing: `actor.intent_target`, which
the immediately preceding `PERCEPTION` moment already set from `sample.
perceived_destination` -- itself already a whitelisted, perception-only field
per Gate 31/32's `PlayerObservation` contract. `evaluate_reception_timeline()`
never receives the authoritative `BallFlight` or a `BallFlightEstimate`'s
`true_*` fields at all; it only ever sees pre-built `read_moments` dictionaries.
There is structurally nothing to leak, because truth was never in scope to
begin with -- this is stronger than a rule the tick obeys, it is a rule the
function's own parameters make impossible to violate.

## What MOVEMENT_UPDATE actually does

One `MOVEMENT_UPDATE` moment is scheduled per inter-read gap, at the same
instant as the read that opens it (`PERCEPTION`'s `Kind` value sorts before
`MOVEMENT_UPDATE`'s at equal times, so it always dequeues immediately after).
Consuming it calls `ShadowMovementSystem.integrate()` for the gap's full
length -- the same stepper `MovementIntegrationCalibration` already proved
reproduces `RallyMovementSystem.project_toward()` exactly at 15/30/60 Hz -- and
evaluates `RallyMovementSystem.evaluate_opportunity()` at every sampled point
along the returned trail. `actor` itself is never mutated by this pass; the
discrete computation the function already performed is unaffected.

This is deliberately *not* a literal one-`RallyMoment`-per-physics-step
scheduler. Calling `integrate()` fresh at true frame-rate ticks would re-derive
`direction_change_delay` from scratch each call and reintroduce the exact
composability bug `ShadowMovementSystem`'s own header warns about. One
`MOVEMENT_UPDATE` per gap, which internally samples continuously via the
already-proven stepper, gets the real per-tick physics without re-litigating
it.

## Measured result

`ContinuousReachabilityCalibration.run()` sweeps 10 seeded rally states across
4 target offsets and 3 available-time budgets (720 samples), building each
scenario's discrete reads the same way `ShadowReceptionSystem` does --
carrying a projected actor forward through `project_toward()` between reads --
so the discrete side of the comparison is the production formula, not a
synthetic stand-in.

| Metric | Result |
|---|---|
| Ever-reachable agreement (discrete vs. continuous) | 100% |
| Mean window-open timing delta | 0.51 s |
| Worst window-open timing delta | 1.02 s |
| Source state left unmutated | 100% |

The two models never disagree on *whether* a receiver is ever reachable. They
disagree substantially on *when*: the discrete model can report a window
opening up to a full second later (or earlier) than the actor's real,
continuously-integrated position first crosses into reach. That gap is exactly
the timing error a three-read-per-rally model carries by construction, made
visible for the first time rather than assumed away.

**Known coverage gap in this sweep.** Every scenario uses one fixed target per
read set; against a fixed target, distance closes monotonically and
reachability never flips back to false once achieved, so both models always
close their window at the contact deadline and `close_delta` is 0 in all 240
cases where a window closed. Proving whether *closing* timing disagrees the
same way `opening` timing does needs a scenario where the perceived
destination itself corrects mid-flight -- a real Gate 7 case this sweep does
not yet construct. Flagged rather than left silent.

## Scope

- No feature flag, no rollout audit, no live integrator, no change to any
  official `RallyEvent` or rally outcome. `evaluate_reception_timeline()`'s
  existing discrete return fields are byte-identical to before this gate;
  everything new is additive (`continuous_samples`,
  `continuous_ever_reachable`, `continuous_opened_at`, `continuous_closed_at`,
  `discrete_vs_continuous_open_delta`, `discrete_vs_continuous_close_delta`).
- Reception only. `RallyScheduler`/`ActionOpportunityWindow` exist only on
  this path today; setter, hitter, and opponent continuous movement follow
  the same dependency order every other persistent-state capability in this
  project has (reception before setter before attack before block) and are
  later gates, not this one.
- `RallyMovementSystem.traversal_seconds()` / `_movement_time()` (the
  resolver-allotted-duration path `RallySimulator.resolve()` actually uses) is
  untouched. This gate proves reachability *reconciles*; making movement
  itself resolver-owned is contingent on that proof and comes later, mirroring
  how Gates 44-47 (shadow + audit) preceded Gates 48-49 (flag + promotion).

## Verification

`_test_gate_fifty_continuous_reachability_timeline` in `tests/test_runner.gd`:

1. exactly one `MOVEMENT_UPDATE` timeline entry per inter-read gap (2 reads ->
   2 entries), and `continuous_samples` is non-trivially populated;
2. an information-boundary fingerprint: launching a real serve trajectory onto
   `state.ball` between two otherwise-identical calls -- changing
   authoritative truth while holding `read_moments` fixed -- produces
   byte-identical `continuous_samples`;
3. the continuous read finds the same actor reachable the discrete windows
   do, on a realistic short correction (the kinematics-driven check, not a
   hand-set flag);
4. the discrete-vs-continuous delta fields, when present, are bounded real
   numbers rather than degenerate.

A pre-existing check (`_test_shadow_reception_trace`) asserted the timeline's
entry count was exactly 4 (3 reads + 1 deadline); it is now 7 (+1
`MOVEMENT_UPDATE` per gap), updated rather than deleted, since the count
changing is this gate's whole point.

Full suite: 416 checks passing (411 before this gate).
