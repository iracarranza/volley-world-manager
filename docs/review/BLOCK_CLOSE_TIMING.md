# Repair 1: timing the wall close

`docs/review/MOVEMENT_CONTRACT_GATE.md` named the block close as the largest
single untimed population: 137 of 137 `blocking` off-ball legs and 116 of 116
BLOCK contacts published a destination and no clock. Measured at `5a745d8`,
changed here.

## Why it was untimed, which is the interesting part

Not an oversight. Each of the three staging sites stamped
`{"intent": &"blocking", "progress": 0.0}` and one of them says why, in a comment
that has been standing since the split was made:

> `_uniform_intents` stays for the two blockers, whose staging is the block
> path's to describe.

The block path never described it. The four floor defenders staged *behind* the
wall in the same breath go through `_establish_shape`, which calls
`_travel_intent` and therefore publishes `traversal_seconds` and
`window_seconds`; the two in front were deferred to a describer that was never
written.

## What was done

`_wall_close_intent` -- three lines wrapping the same `_travel_intent` the four
behind the wall use, with `transition` rather than `lateral`. That mode is not a
new judgement either: `_establish_shape:9098-9102` already says the two who
"genuinely sprint on this ball are closing the wall" where it charges everyone
else laterally.

Applied at all three staging sites, each capturing the blocker's start *before*
the loop that writes the wall into `live_positions` -- three lines later that
start is the wall, which would have timed every close at zero.

**And one site was publishing nothing at all.** The home wall at
`rally_simulator.gd:5017` wrote `live_positions` for both blockers and published
no phase target, so the only home-block destination that ever reached playback
was the *pre-release* prediction on the opponent set event. The wall the side
actually forms was drawn nowhere; the blocker stood at a guess. It is now merged
into that same event's `home_phase_targets` -- same window, same flight, one key
-- rather than published on a second event, because two keys for one window is
the correct-then-clobbered shape this file has been bitten by repeatedly.

The continuation blockers were additionally mislabelled: `_defensive_intents`
stamped them `&"defending"`, so the wall on the third ball was not even in the
same population as the wall on the first.

## Measured

Against `OFFBALL_TIMING_BASELINE.md`, same probe, same seeds:

| | before | after |
|---|---:|---:|
| `blocking` legs | 137 | **388** |
| of those, timed | **0** | **388** |
| off-ball legs with no duration at all | 700 | **350** |
| legs drawn slower than the body moves | 781 | **345** |
| phase targets with no intent entry at all | 231 | **84** |

The `blocking` population trebles because two of the three sites were publishing
no `blocking` entry to count: the home wall published no target, and the
continuation wall was labelled `defending`.

`blocking` pace moves 0.67 → 1.26. Above 1.0 rather than on it, and that is the
known residual rather than a new error: `traversal_seconds` comes from
`_movement_time` and the probe's `natural_s` from
`ShadowMovementSystem.natural_traversal_time`, which are the two timing paths
`MovementTimingRatioCalibration` exists to measure. 1.26 sits inside its
`PERCEPTIBLE_LOW`/`PERCEPTIBLE_HIGH` band of 0.70-1.40.

**Outcomes are unchanged.** `run_rally_balance_probe.gd` over 700 rallies is
byte-identical to the pre-repair reading. `_travel_intent` reaches only
`_movement_time`, which routes to `_travel` for its duration and records nothing
-- the split that file's own comment describes.

**`completable`, `early` and `cannot_complete` did move**, and unlike change 5
that is correct here: this repair *adds published targets* -- the home wall was
in no map before -- so the population being averaged is not the same population.
Comparing those three columns across this change would be comparing two
different sets of legs.

## What it did not reach

The `BLOCK` contact row in the coverage audit is still all zeros on the leg
quartet, and that is a fair description of the event rather than a hole: a
blocker's travel happens during the *set* flight, which is the window this repair
timed, and the ATTACK→BLOCK window that the BLOCK event owns is about a tenth of a
second of jump, not travel.
