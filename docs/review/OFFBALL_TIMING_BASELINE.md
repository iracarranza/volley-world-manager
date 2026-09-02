# Gate 0: what the ten off-ball volis are doing with their time

`docs/implementation/SIMULATION_PLAYBACK_AUTHORITY_HANDOFF.md` requires a
before-figure for off-ball movement *before* change 5, because those players
currently publish no independent duration and a change with no predecessor
produces a delta nobody can read. This is that figure.

Measured at `e8ef68f` by `tools/run_offball_timing_baseline.gd`, over **300
rallies** (seeds 61000-61149, both serving sides), **3,397 off-ball legs**.

## The finding that changes what change 5 is

**79% of off-ball legs already publish their own duration, and nothing reads it.**

`_travel_intent` (`rally_simulator.gd:15798`) builds each entry of a
`*_phase_intents` map as

```text
intent, progress, traversal_seconds, window_seconds, arrival_progress
```

where `traversal_seconds` is `min(_movement_time(from -> reached), window)` --
the leg's own time, already clamped to the budget it was truncated against.
Seven call sites use it. `_uniform_intents` (`:15670`) builds the other kind:
`{intent, progress: 0.0}`, and nothing else.

Neither reaches playback. `match_screen._apply_explicit_targets` passes only the
*targets* map to `_set_plan_target`, which writes `{start, target, protected}`
with no `seconds`, so `_pace_plan` gives every one of these legs
`max(metres / transition_speed, active_window)` -- the ball's flight, whatever
the distance.

So change 5 is not one change but two, and they are very differently sized:

| | legs | share |
|---|---:|---:|
| duration published, unread by playback | 2,697 | **79%** |
| no duration published at all | 700 | 21% |

The first is a presentation change against a fact that already exists. Only the
second needs a new simulation fact.

## Baseline

`natural_s` is `ShadowMovementSystem.natural_traversal_time` -- the same
instrument `MovementTimingRatioCalibration` uses. `drawn_s` is what
`_pace_plan` produces today. `pace_ratio` is `natural / drawn`, on the same
convention as that calibration: **1.0 means drawn at the model's own pace, below
1.0 means drawn slower than the body moves, above 1.0 means drawn faster than it
can.** `completable` is the distance the model actually covers inside the window,
integrated, over the distance asked for.

| family | n | dist m | window s | natural s | drawn s | pace | completable | early | can't finish | timed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| covering | 1238 | 2.33 | 0.876 | 0.866 | 0.894 | 1.48 | 0.76 | 836 | 402 | 1238 |
| defending | 1288 | 0.90 | 0.857 | 0.510 | 0.860 | 0.82 | 0.91 | 1071 | 217 | 1288 |
| preparing_attack | 355 | 2.24 | 0.822 | 0.900 | 0.857 | 1.45 | 0.56 | 125 | 230 | 128 |
| unnamed | 336 | 1.72 | 1.125 | 0.792 | 1.128 | 0.73 | 0.97 | 300 | 36 | **0** |
| blocking | 137 | 2.15 | 1.346 | 0.891 | 1.346 | 0.67 | 1.00 | 137 | 0 | **0** |
| receiving | 43 | 1.67 | 1.068 | 0.764 | 1.068 | 0.87 | 0.87 | 35 | 8 | 43 |

Totals: **1,844 of 3,397 (54%) drawn slower than the model moves**; **893 (26%)
cannot complete the leg inside the window at all**; 87 unreachable; 1,623 legs
under 5 cm, excluded as saying nothing about pace.

Read across the rows, three separate things are wrong and they are not the same
thing:

- **`blocking` is stretched, uniformly.** Every one of 137 closes at 0.67 of the
  model's pace, every one completes, and not one publishes a duration. A blocker
  who could close in 0.89 s is drawn taking 1.35 s because that is how long the
  set is in the air. This is the purest case of the defect and, for the same
  reason, the one change 5 cannot reach: with no duration published there is
  nothing for playback to read.
- **`preparing_attack` is compressed *and* short.** Drawn at 1.45x the pace the
  body can manage and still arriving 56% of the way. 227 of its 355 legs publish
  no duration. A hitter is being hurried toward a mark they then do not reach.
- **`covering` and `defending` are close to pace in the mean and wrong in the
  tails.** 402 of 1,238 coverers and 217 of 1,288 defenders cannot finish. Their
  duration *is* published; playback simply does not read it.

## Two things this figure does not say

**Entry velocity is taken as zero.** Off-ball legs publish no
`movement_entry_velocity`, so `natural_s` is a standing start. Real carried speed
shortens it, which makes the 26% "cannot complete" an **upper bound** and the 54%
"stretched" a **lower** one. Both move the same way when the bias is removed, so
the qualitative reading holds; the exact figures will shift.

**2,651 legs were excluded as `unknown_start`.** Playback begins each leg from
`live_positions`, and because current pacing always fills the window that is the
previous window's target -- so a player's *first* appearance in any phase map has
no start this probe can know. Guessing it would have been the cheapest way to
double the sample and the fastest way to make it meaningless.

## What this gate is for

Re-run this probe after change 5 with the same seeds. The comparison to make is
not "did the numbers improve" but:

- `pace_ratio` should move toward 1.0 **for the timed families and only those**,
  because only they have a duration for playback to read;
- `completable` should be **unchanged**, because it is a property of the movement
  model and the window, and change 5 touches neither;
- `cannot_complete` counts should be unchanged for the same reason -- what
  changes is whether an unfinishable leg is *drawn* as unfinished or silently
  stretched until it fits.

A change that moves `completable` has moved the simulation, which change 5 is not
supposed to do.

### The first version of that prediction was wrong, and its own table said so

It read "`pace_ratio` should move toward 1.0 for `blocking` and `covering`."
`blocking` is the family with **0 of 137 timed** -- the column is in the table two
sections up -- so it is precisely the one that cannot move. Measured after change
5: `covering` 1.48 → 1.03, `defending` 0.82 → 0.94, `receiving` 0.87 → 1.00, and
`blocking` 0.67 → **0.67**, unchanged, as it had to be.

Recorded rather than quietly corrected, because a prediction that contradicts the
evidence printed beside it is the same failure as a stale baseline: it reads
plausibly and nobody rechecks it against the table it came from.
