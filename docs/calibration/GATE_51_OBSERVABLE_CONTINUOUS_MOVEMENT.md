# Gate 51: Observable Continuous Movement

Review date: 2026-07-31

Status: **PASS; SHADOW-ONLY; DEBUG OVERLAY**

Gate 50 built the continuous reachability read and reported it as a number in a
calibration sweep. A number is not something you can tune against. This gate
carries that read all the way onto the 2D court, so the continuously-sampled
traversal can be looked at beside the discrete windows it is compared with, and
planner positions and tactics can be adjusted while watching what actually
changes.

Building the overlay immediately paid for itself: the first real rally drawn
came back "never reachable" on every receiver, which is what exposed the two
defects corrected in
[Gate 50](GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md#correction-the-first-published-numbers-for-this-gate-were-wrong).
The calibration sweep had reported 100% agreement and never flagged them.
That is the argument for making a model observable rather than only measured.

## Transport

`RallyOpportunitySystem` already returned the full continuous sample set.
`ShadowReceptionSystem._repeated_read_candidate()` now forwards a **bounded**
version of it, plus the window scalars, up into the shadow summary that reaches
`RallyResult.analysis["shadow_reception"]`:

- `continuous_trail` -- at most `CONTINUOUS_TRAIL_MAX_POINTS` (24) points of
  `{time, position, reachable}`
- `continuous_ever_reachable`, `continuous_opened_at`, `continuous_closed_at`
- `continuous_open_delta_seconds`

The full-fidelity sample array stays inside `opportunity_timeline` for
calibration. Only the decimated trail travels, because this candidate is built
on **every** rally and a 30 Hz sample set per inter-read gap is far more
dictionaries than a debug overlay needs to carry around.

Decimation keeps every point where reachability flips, unconditionally. Those
are the only samples carrying information the scalars do not already report --
they are where the window actually opens and closes. Everything else is thinned
evenly, so a long traversal costs no more to transport than a short one.

## The overlay

`TacticalCourt` gains `SHADOW_LAYER_CONTINUOUS` (bit 64), included in
`SHADOW_LAYER_DEFAULT` -- the point of building it was to be able to look at
it -- and exposed in the main screen's **Visuals -> Continuous reachability**
toggle alongside the existing shadow layers.

`_draw_continuous_reachability()` draws, for the receiver whose repeated-read
candidate was selected:

- the integrated traversal as a polyline, each segment coloured by whether the
  receiver could still make the contact at that instant (green reachable, red
  not);
- a ring and vertical tick at the instant reachability opens;
- a label reading `continuous +0.09s vs reads`, the signed gap between the
  continuous open time and the discrete window's, or `never in reach`.

The distance between that ring and the discrete overlay's green "opened" arc
*is* the timing error the three-read model carries, drawn to scale on the court
rather than reported as a table row.

## Scope

- Debug overlay only. Normal match playback still clears shadow diagnostics;
  the dedicated shadow debug fixture must request them, exactly as before.
- No rally outcome changes. Nothing in `RallySimulator.resolve()`'s official
  path is touched, and the discrete window fields are unchanged.
- Reception only, following Gate 50's scope for the same reason.
- Still no feature flag, rollout audit, or live integrator for movement.
  Making movement resolver-owned remains a later gate.

## Verification

Added to `_test_gate_fifty_continuous_reachability_timeline`:

- the continuous trail reaches `RallyResult.analysis` non-empty, within the
  decimation cap, with `{time, position, reachable}` on every point and
  monotonically ordered times.

The two Gate 50 correction checks (window-open timestamp, perceived deadline)
live in the same test and were each driven to failure before their fix.

Full suite: 419 checks passing (416 as of Gate 50).
