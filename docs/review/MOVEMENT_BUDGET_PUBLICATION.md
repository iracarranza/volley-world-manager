# Change 1: publishing the budget an arrival was truncated against

`docs/implementation/SIMULATION_PLAYBACK_AUTHORITY_HANDOFF.md` change 1. Measured
at `b24cfdf`, changed here.

## What was wrong

`movement_duration` times the journey to the **ball**. `movement_target` is as
far as the body got inside the time available. Playback paired one journey's
distance with the other journey's clock, and drew a beaten digger crossing
0.59 m in 0.978 s -- 0.60 m/s, against the 2.05 m/s shuffle the same numbers
imply for the full trip. See `RALLY_MOVEMENT_TIMELINE_VERIFICATION.md`.

## What was not done, and why

**`movement_duration` was not re-timed to `movement_target`.** It is not a
presentation number. `_platform_body_velocity` divides the contact displacement
by `min(movement_duration, available)` and feeds the result into
`_reception_pass_result`, so re-timing it moves a resolved contact.
`MovementTimingRatioCalibration` divides a modelled traversal by it against
measured per-family bands, and that file's own docstring records the
mirror-image mistake -- RECEPTION 0.9952 → 0.7802, DIG 0.9977 → 0.6491, when the
*numerator's* destination moved and the denominator did not -- and refuses to
redraw the bands for it. Moving the denominator's destination earns that entry.

## What was done

Eight contact sites already hold the budget they truncate against and now publish
it as `movement_available_seconds`:

| site | budget |
|---|---|
| home reception, opponent reception | `reception_window` |
| home floor dig | `attack_time` |
| opponent floor dig | `opponent_defense_time` |
| continuation transition dig | `cont_defense_time` |
| recycle coverage | `recycle_coverage_time` (hoisted from an inline expression) |
| home and opponent attack coverage | `coverage_time` |

The two remaining `movement_target` publishers are the server's walk-in base,
which is not truncated and correctly publishes no budget.

`match_screen._pace_plan` clamps the authored duration to it:

```text
seconds = max(metres / speed, min(movement_duration, budget))
```

Families publishing no budget are unchanged, exactly.

## Proof

**Simulation outcomes are unchanged.** `tools/run_rally_balance_probe.gd`, 700
rallies, run on this tree and then again with the two files stashed:
**byte-identical on all nineteen figures**, kill 0.526, dig 0.512, stuff 0.097,
serve error 0.194, ace 0.099, swing balance 0.957. Running one probe twice is the
only comparison worth making here; a figure quoted from an earlier pass would
have been taken on a different tree.

**Calibration is unchanged by construction.** `movement_duration` is untouched,
and `MovementTimingRatioCalibration` reads only it. No test exercises `_pace_plan`
or the new key.

**The leg now reaches its endpoint by its deadline.**
`tools/run_contact_leg_pacing.gd` reproduces both pacing rules from published
metadata over 300 rallies (seeds 61000-61149):

| family | n | truncated | old s | new s | old m/s | new m/s | old fits | new fits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SERVE→RECEPTION | 209 | 40 | 0.872 | 0.825 | 1.61 | 1.69 | 169 | **209** |
| SERVE→RECEPTION (failed) | 32 | 2 | 0.709 | 0.695 | 1.37 | 1.40 | 30 | **32** |
| BLOCK→ATTACK_COVERAGE | 5 | 1 | 0.585 | 0.585 | 1.54 | 1.54 | 4 | **5** |
| BLOCK→DIG | 44 | 6 | 0.741 | 0.720 | 1.01 | 1.04 | 23 | 23 |
| BLOCK→DIG (failed) | 65 | 62 | 0.988 | 0.480 | **0.64** | **1.08** | 0 | 3 |

**An untruncated player may now arrive early and stand.** 169 of 209 receptions
and 38 of 44 successful digs finish before their deadline. The old rule could not
express that: with no budget, `_pace_plan` fell back to the whole window.

## What it did not close, which is the interesting half

**Reception and coverage close completely; the dig only halves.**

The reason is visible in the same table's last two columns, once the budget is
printed beside the window playback actually has:

| family | mean budget s | mean window s | budget > window |
|---|---:|---:|---:|
| SERVE→RECEPTION | 1.184 | 1.184 | **0 of 209** |
| BLOCK→ATTACK_COVERAGE | 0.683 | 0.683 | **0 of 5** |
| BLOCK→DIG | 0.964 | 0.713 | 35 of 44 |
| BLOCK→DIG (failed) | 0.483 | 0.368 | **62 of 65** |

The reception's budget and playback's window are the *same number*, so clamping
lands the leg exactly. The dig's are not. `attack_time` is
`max(home_block_trajectory.duration, BLOCK_DEFLECTION_MIN_SECONDS)` with the
floor at 0.22 s, while `physical_time` places the dig at the end of the
deflection flight itself. Where the floor binds, the resolver gives the defender
more time than the record says the ball was in the air, and the leg is drawn over
a deadline that arrives after the contact.

**Left standing rather than fixed here**, on the handoff's own discipline:
`BLOCK_DEFLECTION_MIN_SECONDS` is a calibration constant, moving it would change
resolved contacts, and this change is required to be outcome-neutral. Clamping
the drawn leg to the *window* instead would hide the disagreement, and the
handoff explicitly requires that a player may still be in motion at the next
contact. Classified per the handoff's step 7 as **authority contract incomplete**
-- one journey with two budgets -- and carried into change 4, where the
instrumentation to gate it already exists.

The digger is nevertheless drawn at 1.08 m/s where they were drawn at 0.64, and
3 of 65 beaten diggers now arrive where they were 0 of 65.
