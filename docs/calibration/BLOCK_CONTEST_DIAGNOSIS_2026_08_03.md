# The block contest: diagnosis

Date: 2026-08-03
Prompted by: `IDENTITY_AND_BLOCK_TEST_POWER_2026_08_03.md`, which found that a
single roster pairing's stuff rate ranges from 0.000 to 0.907 and left the
question of whether that is correct sensitivity or a broken contest.

It is a broken contest, in two independent ways. One is fixed here. The other
is a calibration decision, not a bug fix, and is left open deliberately.

## What the contest does

`_contest_block()` compares `contest = block_quality + execution_error` against
three absolute thresholds above the attack's quality:

| outcome | condition |
| --- | --- |
| stuff | `contest > attack + 0.22` **and** `primary_close >= 0.78` |
| touch | `contest > attack + 0.18` |
| funnel | `contest > attack + 0.10` |
| miss | otherwise |

## Finding 1: the `primary_close` gate is inert

Measured across two roster pairings, `primary_close` is at or above 0.78 in
**94% and 99%** of home block contests, with a median of 1.000 in both. It is
not discriminating anything. Whatever it was meant to express — that a stuff
requires a sealed lane — the block formation almost always satisfies it, so the
margin comparison is the only live gate.

Not changed here. Worth revisiting when someone looks at block formation,
because a condition that passes 99% of the time is either redundant or its
input is wrong.

## Finding 2: uniform noise made outcomes impossible, not merely unlikely

`_execution_error()` returned `rng.randf_range(-spread, spread)` — a uniform
draw with hard support boundaries — and every consumer compares the result
against a threshold. So whenever a contest's systematic margin sat further than
`spread` from its threshold, the outcome was not unlikely, it was **impossible**.

| pairing | contests | mean margin | vs 0.22 cutoff | stuffs |
| ---: | ---: | ---: | --- | ---: |
| 3 | 127 | +0.135 | 0.085 below | **0** |
| 5 | 144 | +0.322 | 0.102 above | 84 |

Blocker spread runs 0.039–0.13 (`base 0.13 × lerp(1.0, 0.30, reliability)`), so
pairing 3 sat outside its own noise band and recorded zero stuffs in 127
contests. Note the perverse consequence: *more reliable blockers have a narrower
spread*, so the better the player, the more deterministic — and the more
completely a small quality deficit locks them out.

**Fixed.** `_execution_error` now draws from a normal distribution matched on
standard deviation (a uniform's is its half-width over root three), clamped at
3.5 deviations. Ordinary contacts scatter exactly as much as before; only the
tails change, and nothing is flatly impossible any more.

Balance is unmoved: mean stuff rate across twelve pairings went 0.324 → 0.345,
inside the noise of a twelve-sample estimate, and the full suite is green.

**Be clear about what this did not do.** Pairing 3 still records zero stuffs.
At 2.9 deviations from the threshold the residual probability is about 0.002,
so 240 contests produce well under one expected stuff. The support is now
correct and the response is smooth, but the change is invisible at this sample
size. It is a precondition for calibration, not a substitute for it.

## Finding 3: the magnitude is wrong, and this is a design decision

Measured as a share of opposing attacks — the figure real volleyball reports —
across eight roster pairings, 150 rallies each:

| pairing | opponent attacks | stuffed | rate |
| ---: | ---: | ---: | ---: |
| 0 | 145 | 58 | 40.0% |
| 1 | 134 | 28 | 20.9% |
| 2 | 132 | 86 | 65.2% |
| 3 | 126 | 0 | 0.0% |
| 4 | 145 | 48 | 33.1% |
| 5 | 143 | 85 | 59.4% |
| 6 | 133 | 80 | 60.2% |
| 7 | 127 | 43 | 33.9% |

**Overall: 39.4% of opposing attacks are stuffed.**

For reference, elite real-world teams stuff roughly 8–12% of opposing attacks.
The engine is running about four times that, and the per-pairing range brackets
the realistic figure rather than centring on it.

Two things follow, and they are separable:

1. **The centre is too high.** Roughly a 4× overshoot.
2. **The spread is too wide.** A 0–65% range across random roster pairings
   means the systematic between-roster margin gap (~0.19) dwarfs the
   per-contest noise (σ ≈ 0.03–0.075), so a matchup decides the outcome and a
   squad's marginal improvement does not move it.

Fixing (1) is a threshold move. Fixing (2) means either compressing how much
roster quality translates into contest margin, or widening the response with a
deliberate temperature rather than relying on execution noise to provide it.

**Neither is done here, on purpose.** This world is not real volleyball — it has
alien managers and six body types — so "match the real figure" is an assumption
rather than an obvious truth, and recalibrating blocking visibly changes every
match: fewer blocks, more attacks landing, longer rallies, different scorelines.
That is a call for whoever owns the design, not a defect to be quietly patched.

The measurement tooling is in place either way: `_mean_stuff_block_rate()` in
the test runner gates the mean across pairings, and the sweep above is a few
lines to reproduce.
