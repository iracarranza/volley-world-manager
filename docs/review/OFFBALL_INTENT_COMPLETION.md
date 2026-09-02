# Repair 3: every off-ball leg now says how long it took

`docs/review/MOVEMENT_CONTRACT_GATE.md` named two off-ball holes: 231 phase
targets carrying no intent entry at all, and a population of intents carrying an
intent name and no clock. Measured at `56c214c`, changed here.

## Where the 231 came from: one map

`rally_simulator.gd:4765` published `pre_release_home_targets` as
`home_phase_targets` and no `home_phase_intents` -- the only phase map in the
file to publish a destination with no companion. It is now timed against
`second_contact_window`, which is the pass flight the comment above that block
already says the map is consumed during.

**231 → 0.**

## Where the untimed intents came from: three staging sites and a re-stamp

After repair 1 closed the wall closes, 227 untimed legs remained and every one of
them was `preparing_attack`. Three sites stamped the hitter's staging leg by hand:

| site | leg |
|---|---|
| home first ball, `:2401` | `hitter_standing_at → hitter_start` |
| opponent first ball, `:5313` | `opponent_standing_at → opponent_approach_start` |
| home continuation, `:6900` | `hitter_standing_at → hitter_start` |

All three had both endpoints in scope, and the home one captures its start
several hundred lines earlier with a comment saying why -- "before preparation
relocates it. The budget asks how far the hitter had to come" -- for exactly this
journey. They now go through `_travel_intent` against the pass flight.

A fourth site was re-stamping rather than untimed. `receive_formation_intents` is
built once at the start of the rally, when `{progress: 0.0}` is exactly right
because nobody has moved, and then **republished on the reception event**, by
which point the bodies have travelled a mean 2.24 m and the stamp still says they
have not. `_shape_intents` rebuilds it against `_positions_at_last_contact` --
the resolver's own record of where each body began the leg it just finished.

## Measured

`tools/run_offball_timing_baseline.gd`, same probe, same seeds, against the
Gate 0 baseline:

| | Gate 0 | after repair 1 | after repair 3 |
|---|---:|---:|---:|
| off-ball legs with no duration | 700 | 350 | **0** |
| legs drawn slower than the body moves | 1,844 | 345 | **176** |
| phase targets with no intent at all | 231 | 84 | **0** |
| intents with no `traversal_seconds` | 1,364 | 1,279 | **307** |

`preparing_attack` pace 1.45 → 0.96; every family now sits between 0.96 and 1.24
where the range was 0.67 to 1.48.

**Outcomes are unchanged.** The balance probe over 700 rallies is byte-identical
to the pre-repair reading, three times over -- once after each of the three edits
in this repair.

## One key changed meaning, and it was put back

`_travel_intent` publishes `progress` as the fraction of the asked journey
covered. The three hitter-staging sites were publishing *release* progress under
that name -- a different quantity, and the only entries in the maps that did.

Unifying them looked like a tidy-up and would have been a regression:
`run_intent_progress_probe.gd` reads `progress` as the cogniticon fill, and
`_travel_intent` would have handed it a constant 1.0, because the resolver stages
a hitter *onto* their mark rather than short of it. So `progress` keeps the
release progress it has always carried and the travel fraction is published
beside it as `travel_progress`.

Checked rather than reasoned: the intent distribution after the change still
reads `preparing_attack` 85.0% non-zero, mean 0.79. `blocking` and `receiving`
did move -- both from a constant 0.0 to a real fraction -- which is the point of
repairs 1 and 3 rather than a side effect of them.

## What is left

307 intents still carry no `traversal_seconds`, and they are not journeys. They
come from `_uniform_intents` at `:3678`, where the opponent dig event snapshots
`opponent_live_positions` wholesale -- a map of where everyone already is. The
off-ball probe classifies them as `too_short` and they are: timing a zero-length
leg would publish a number that means nothing.
