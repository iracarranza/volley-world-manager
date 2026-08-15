# Attack-side symmetry: ratchet re-baselined, 2026-08-04

`TUNING_SYMMETRY_CEILING` moved from 0.135 to 0.150. This file is the reason,
written because the gate's own comment says widening it is the defect the
arrangement exists to prevent — so the bar for doing it is showing that the old
number was not a measurement of the engine.

## What the old baseline actually measured

`_resolve_home_serve` never advanced `rally_clock`. The opponent-serve path
always had. So on every home-served rally — half of them — the serve, the
reception and the set all derived their moment from a clock still at zero.

`opponent_state.simulation_time` is derived from `rally_clock`. It was therefore
pinned at zero for the opponent's entire transition on those rallies, and their
approach was prepared against a clock that had not started.

0.135 was the engine's asymmetry *minus* whatever that was worth to the
opponent. The gate was ratcheting against an artifact, and the artifact was on
the opponent's side of the ledger.

## What starting the clock costs

Measured with `tools/run_serving_side_split.gd`, four pairings of ninety
rallies, tempo pinned so tactics do not confound the sides:

| cell | before | after | n |
| --- | --- | --- | --- |
| opponent attack quality, home-served | 0.462 | 0.440 | 280 |
| opponent attack quality, opponent-served | 0.363 | 0.363 | 27 |
| home attack quality, opponent-served | 0.428 | 0.428 | 381 |

The opponent-served columns are bit-identical, which is the control: nothing
outside the home-serve path changed, and nothing outside it moved. The whole
effect is ~0.02 of opponent attack quality on the rallies whose clock was
broken — an advantage being removed, not a home side being flattered.

Pooled, `home_share` goes 0.601 → 0.614 and the ratchet's own statistic goes
0.135 → 0.146.

## Second defects that were looked for and do not exist

- `LiveAttackIntegrator.validate` rejects a candidate whose `contact_time`
  precedes `simulation_time`, which would have been a plausible cause. It only
  runs on the home-*receive* path and is unreachable on a home-served rally.
- `generate_reception_opportunities` passes `simulation_time` to
  `earliest_contact_time` as an absolute clock with a relative `(0.15, 1.40)`
  window, not as a duration budget, so moving the clock does not shrink it.

## One alarm that was wrong

A 42% drop in the *home* side's attack quality on home-served rallies was
reported as evidence of a second defect. It was eight attacks. Home serves, so
the opponent receives and swings first and most of those rallies end before the
home side gets a swing; that cell cannot hold a rate. The tool now prints
denominators. See `docs/design/MEASUREMENT_CONFOUNDS.md`.

## What this does not license

This is not a finding that 0.146 is acceptable. `SHIPPING_SYMMETRY_BOUND` is
unchanged at 0.12 and is still not met — the gate reports that verdict every
run. `attack_error` (0.237) and `dig` (0.200) remain the two largest open
asymmetries and are the reason the tilt exists.

The ratchet is re-anchored to a clock that runs, and resumes its job of refusing
the next four points of drift. The next change that pushes past 0.150 owes the
same evidence: either the baseline was wrong, or the change is.
