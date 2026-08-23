# Long-horizon and deepened-corpus findings

Run: 2026-08-16, on `8f5827e`. **Measurement only — nothing changed.**

Two instruments that already existed and had never had their output recorded,
plus one committed probe deepened fourfold. All three cost wall-clock and nothing
else, which is the whole reason to run them.

---

## 1. The world does not leak talent over eighty seasons

`tools/long_world_probe.tscn` runs `SEASONS` seasons across independently seeded
worlds and asserts nothing, deliberately: nobody had looked this far out, and
inventing a threshold for a distribution nobody has seen is the mistake this
repository keeps a document about. `PROBE_HANDOFF.md` lists it; no results were
recorded anywhere.

`CLAUDE.md` says `_test_world_aging` "is the only check that will notice a
generation change leaking talent" — over twenty seasons. This is eighty.

**24 worlds × 80 seasons × 900 players:**

| season | size | mean age | mean peak | p90 peak | max peak | elite (≥80) |
|---|---|---|---|---|---|---|
| 10 | 897 | 23.19 | 71.55 | 80.00 | 98.00 | 116.33 |
| 20 | 897 | 23.19 | 71.59 | 80.00 | 97.96 | 117.17 |
| 30 | 897 | 23.19 | 71.73 | 80.04 | 98.00 | **123.46** |
| 40 | 897 | 23.19 | 71.59 | 80.00 | 97.88 | 114.92 |
| 50 | 897 | 23.19 | 71.65 | 80.00 | 97.83 | 115.42 |
| 60 | 897 | 23.19 | 71.65 | 80.04 | 98.00 | 116.25 |
| 70 | 897 | 23.19 | 71.63 | 80.00 | 97.88 | 116.21 |
| 80 | 897 | 23.19 | 71.71 | 80.00 | 97.92 | 117.04 |

**Population and mean age are in exact steady state** — 897 and 23.19 at every
sample point, to the precision printed. Mean peak potential wanders inside 0.2 of
a point with no trend across eight decades. There is no leak, and no inflation
either.

### The six-world run said otherwise, and was wrong

Run first at the probe's committed `WORLDS = 6`, the elite count read 118.17,
119.67, 123.17, 119.33, 120.50, 118.17, **110.33**, 112.00 — an apparent 7%
decline over the last two decades, which is exactly the shape of a slow talent
leak and exactly what somebody would then go and "fix".

At 24 worlds it is flat. **The decline was noise in six samples**, and the cost of
believing it would have been a tuning pass against nothing. Widening the run was
four times the wall-clock and no thought at all, which is the correct trade
whenever a trend is about to be acted on.

### One excursion that is not noise

Season 30 reads **123.46 elite against a ~116 baseline**, and the six-world run
read 123.17 at the same season. An excursion that survives quadrupling the sample
*and lands on the same season* is not sampling error.

The likely mechanism is in `world_population.gd`: `golden_cohorts()` seeds
generational talent by birth year, and the `generational` tier is explicitly
`scales_with_population: false` — eight per world regardless of size — so a
golden birth year produces a bump that moves through the population as a wave and
peaks when that cohort reaches its own peak age.

**Whether that wave is intended at this amplitude is a design question**, and it
is invisible at the ten-season sampling this probe uses. Settling it needs
`SAMPLE_EVERY = 2` and nothing else. Not run here: it is a distribution nobody has
looked at, and this document exists to say so rather than to guess.

---

## 2. `ATTACK_COVERAGE`: every figure holds at four times the sample

`tools/run_coverage_census.gd` deepened from 1,400 rallies to **5,000**.

| | at 1,400 rallies | at 5,000 rallies |
|---|---|---|
| successful coverage contacts | 60 | **234** |
| fabricated after the rally | 60 of 60 | **234 of 234** |
| published duration | 0.58 exactly | 0.58 exactly |
| published apex | 1.8 exactly | 1.8 exactly |
| target offset | 0.5763 m exactly | 0.5763 m exactly |
| next contact is a SET | 60 of 60 | 234 of 234 |
| gap to that SET, median | 1.1148 s | 1.1158 s |

Four published quantities, **each identical on all 234 contacts** — not a
distribution with a tight peak, a constant. And the gap's 5th percentile is
0.927 s against a 0.58 s drawn flight, so the ball is drawn landing more than
half a second early on *essentially every coverage contact in the game*, not
merely at the median.

New at this depth: coverage falls to the home side about three times as often,
172 against 62. Unexplained, and probably downstream of the block-touch asymmetry
the dig work already measured at 22.9% against 6.5%.

`CONTACT_AND_BALL_FLIGHT.md` has been updated to the deeper figures.

---

## What this was worth

Three results, no decisions, no risk:

- an eighty-season stability claim the project did not have, and could not have
  had from a twenty-season gate;
- a false trend caught before anyone tuned against it;
- a real, repeatable cohort excursion nobody had seen, with the next measurement
  named.

The coverage numbers did not move, which is its own result: a claim measured at
n=60 and re-measured at n=234 without moving is a claim worth quoting.
