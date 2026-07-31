# Gate 46: Blocker Progression and Wrong-Read Calibration

Review date: 2026-07-31

Status: **PASS; SHADOW ONLY**

`BlockerProgressionCalibration.run()` sweeps three reading tiers across four set
difficulties and reports whether stronger readers actually read better without
becoming better athletes.

## Why the sweep needed set difficulties

Gate 44's version measured only confidence, recognition timing, and movement
neutrality on the ordinary vertical-slice fixture. That fixture is a stable,
slow set to a pin, and it is read correctly by essentially everyone: it produced
a wrong-read rate of exactly zero at every tier. A monotonic comparison over an
all-zero column is vacuous -- it passes whatever the system does.

The scenarios now sweep difficulty deliberately:

| Scenario | Destination | Stability | Purpose |
|---|---|---|---|
| `readable_pin` | 0.82 | 0.92 | The easy baseline; nearly everyone reads it |
| `quick_middle` | 0.50 | 0.55 | Short window, moderate novelty |
| `deceptive_pin` | 0.18 | 0.22 | Unstable and spinning, but deep inside a zone |
| `boundary_seam` | 0.36 | 0.20 | Sits a hair inside the middle/left boundary |

`boundary_seam` is the scenario that produces misreads, and the reason is worth
recording. A set landing deep inside a zone survives a large perception error
without changing which zone a blocker *names* -- `deceptive_pin` is the hardest
set in the sweep to perceive accurately and still yields a zero wrong-read rate,
because a 0.6 m error on a ball at x=0.18 is still comfortably "left". Only a
set near a zone boundary converts a small perception error into a different
named zone. That is also where real blockers misread, so the fixture and the
sport agree.

## What the sweep asserts

Movement attributes (`lateral_speed`, `acceleration`, `transition_speed`) and
`block_timing` are pinned identical across tiers, so only reading varies.
`block_timing` is pinned specifically because it feeds the
`block_engagement_distance` profile that now eases the commitment threshold --
leaving it free would let a tier change the bar through a second channel.

- `confidence_monotonic` -- later-read confidence rises with reading tier.
- `earlier_recognition_monotonic` -- recognition delay measured from set release
  falls with reading tier.
- `movement_speed_tier_independent` -- mean maximum speed is identical across
  all three tiers to within 0.001 m/s.
- `wrong_read_monotonic` -- misread rate does not rise with reading tier.
- `hesitation_monotonic` -- hesitation rate does not rise with reading tier.

## The coverage guard

Every rate above is paired with a coverage flag asserting the sweep actually
contains the outcome being rated: `wrong_reads_observed`,
`hesitation_observed`, `solo_closes_observed`, `coordinated_closes_observed`,
and `coordination_revisions_observed`. These exist because both a zero
wrong-read column and a structurally unreachable `hesitated` flag passed their
monotonic checks silently before being caught. A monotonic assertion over
nothing is not evidence, and the coverage flags are what make the progression
flags mean something.

## Representative result

At 24 samples per tier per scenario, misreads concentrate in `boundary_seam`
exactly as intended -- 22.2% for developing readers against 16.7% for elite --
while every other scenario stays at zero. Hesitation appears only for developing
readers. Mean maximum speed is bit-identical across tiers.
