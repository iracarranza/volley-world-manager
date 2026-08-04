# Gate E: what the geometric attack does when a rally feeds it

Date: 2026-08-04
Occasion: the geometric attack now runs in shadow on every home first-ball
swing. This is the first time the Gate B–D models have seen inputs a rally
produced rather than inputs a sweep produced, and three of the differences
matter.

## What is wired

`GeometricAttackPromotion` translates a rally into the resolver's inputs and
the resolver's answer back into the rally's outcome vocabulary. The home
first-ball attack path calls it on every swing and records the result at
`analysis.shadow_reception.summary.geometric_attack`. Nothing downstream reads
it. `ENABLE_GEOMETRIC_ATTACK` is still false and no attack outcome changes.

The draws come from `geometric_rng`, a stream of its own seeded from the rally
seed and the swing index. This is the load-bearing detail of the whole gate:
the shadow runs on every swing whether or not it is promoted, so drawing from
the rally's own generator would advance the stream and change every rally in
the game. The suite passing unchanged at 753 checks immediately after wiring
is the evidence that it does not.

## The block contest survives contact with a rally

Gate D swept the models in isolation and landed the terminal stuff rate at
12.5% against a 12% target. Measured on live rallies, through a real
`_form_opponent_block` formation with real close fractions converted to hand
widths, stuff is **11.9%** of resolved swings (51 of 428).

That is the number this gate most expected to move, and it did not. The close
fraction to half-width mapping — a blocker below `WALL_JOIN_CLOSE` is not in
the wall, a partial close seals proportionally less net — reproduces the swept
contest rather than replacing it.

## Three findings

### 1. A uniform draw where three named tiers belong (fixed)

`choose_power` reads `intent_fraction` as how much of the available ceiling the
swing asks for, and its meaningful values are the three named constants:
`DRIVE_INTENT` 0.90, `CONTROL_INTENT` 0.66, `OFF_SPEED_INTENT` 0.36. The first
wiring handed it `rng.randf()`.

That looks like randomness and is not. A uniform on 0–1 averages 0.5, which sits
*below* control, so the mean swing in the game was softer than a deliberately
controlled ball:

| | before | after |
| --- | ---: | ---: |
| mean contact speed | 9.84 m/s | 13.70 m/s |
| median | 8.54 m/s | 14.01 m/s |
| p90 | 17.97 m/s | 21.46 m/s |

Fixed by drawing a tier — drive 62%, control 26%, off-speed 12% — weighted
toward driving the ball, because that is what a hitter does with a set they can
attack. Choosing the tier from what the hitter *reads* (off-speed into a formed
block, drive into a gap) is the correct version and belongs with the resolver's
own read; the weighted draw is a placeholder that is at least in the right part
of the range.

Even after the fix the median sits at 14 m/s against a sport that spikes at
20–30. Contact speed is still low and this is not finished.

### 2. The error rate is more than double the sport's

| outcome | share of 398 resolved swings |
| --- | ---: |
| in | 43.0% |
| net | 23.6% |
| touch | 14.6% |
| tool | 8.5% |
| stuff | 5.8% |
| out | 4.3% |
| high hands | 0.3% |

`net` plus `out` is **27.9%**. Real volleyball attack error is 10–15%, and
nearly all of this excess is balls into the tape rather than balls long or wide.
Raising the intent tiers made it worse (20.1% → 27.9%), which is consistent:
harder swings leave less margin over the net.

The likely cause is a difference between the sweep and the rally that the sweep
could not see. `AttackGeometryCalibration` contacts at `jumping_reach_cm()`
minus 10 cm with no approach term. A rally applies the approach's
`jump_multiplier`, so a hitter who never reached their mark contacts *lower*
than any sample in the sweep, and a ball struck downward from a lower contact
clears 2.43 m by less. That is a hypothesis with an obvious test — re-run the
Gate D sweep with the live distribution of `jump_multiplier` instead of 1.0 —
and it is the next thing to do on this gate.

### 3. The course scan is not choosing

Only **33 of 398** swings (8.3%) left the natural approach line. Every other
swing recorded `offset_degrees` of exactly 0.0.

This is the same shape as the recurring defect in this engine — correct
mechanism, input that does not discriminate — that produced set quality
compressed below 0.50, `block_commitment` spanning 0.33, an approach angle a
third of the sport's, and a blocker out-reaching the hitter by 6 cm. The scan
evaluates 17 bearings and scores each on perceived openness minus strain, but
with a block that is frequently not formed and a defence read at coarse
resolution, openness comes out flat across the cone and `STRAIN_AVERSION` then
decides everything — and strain is minimised at the natural line by
construction.

A hitter who always hits where their approach points has no shot selection,
which is the thing this whole rework exists to give them. Promoting the
geometric attack before this is resolved would replace a legacy attack that
picks targets with a geometric one that does not.

## What this means for promotion

Promotion is deliberately not taken in this gate. Findings 2 and 3 are both
reasons a promoted geometric attack would play *worse* than the legacy one
despite being the better model: a 28% error rate would swamp the rally, and a
hitter with no course selection would make every rally read the same.

The order from here:

1. Re-run the Gate D sweep with the live `jump_multiplier` distribution and
   settle whether contact height explains the net rate.
2. Make openness discriminate across the cone, so the scan chooses.
3. Wire the shadow into the remaining attack paths (opponent first-ball,
   transition, and both serve paths) and confirm the mix holds on all of them.
4. Then open `ENABLE_GEOMETRIC_ATTACK` behind the development override and
   compare terminal outcome distributions against the legacy path.

The symmetry gate repaired in
`ATTACK_SIDE_SYMMETRY_2026_08_03.md` is the instrument for step 4. It measures
a real six-point home tilt today, and the geometric attack replacing three
separately-written attack paths with one shared resolver is the most plausible
way that tilt goes away — which makes it a genuine prediction this gate can be
held to rather than a hope.
