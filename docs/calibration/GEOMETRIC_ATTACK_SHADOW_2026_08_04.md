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

All three are fixed below. They are recorded as they were found, hypothesis and
all, because the wrong hypothesis in finding 2 is what led to the measurement
that found the real cause.

### 1. A uniform draw where three named tiers belong

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

## Both open findings, resolved

### The tape was not a constraint on shot selection

The jump-multiplier hypothesis above was **wrong**, and measuring it is what
found the real cause. Live `jump_multiplier` is 0.999 / 1.010 / 1.038 at p10 /
median / p90 -- the approach is not costing anyone their contact height.

What the same measurement did show is a vertical launch angle running to
**-53.5 degrees at p10**. The tape is checked in `AttackResolutionModel`, in
*resolution*, and nowhere in *decision*: the course scan reads the block and the
floor, the power model reads the target distance, and nothing between them knows
there is a net. So a hitter could pick a short cut shot whose driven solution is
a dive into the tape, swing at it, and have the resolver dutifully report "net".
The decision layer was offering shots that are not physically available.

`_feasible_launch` makes the net a constraint on the choice. For a fixed speed a
longer target range means a flatter driven solution and more height at the net,
so the search is monotone: start where the hitter aimed, push the target deeper
until it clears by `NET_CLEARANCE_MARGIN_METERS`. If nothing driven clears, lift
it -- the roll shot off a tight set. If nothing clears at all, the swing happens
anyway and will probably be in the net, which is correct: a hitter under a bad
set does hit the tape, and that is now the only path that produces one.

Net contact fell from **23.6% to 4.5%**.

### The gap was not visible to the scan

Only 33 of 398 swings left the natural approach line. The cause was not tie
saturation, as guessed -- it was the opposite. Probing openness across a
17-bearing cone against a formed two-man block:

| bearing offset | block clearance | floor clearance | openness | score |
| ---: | ---: | ---: | ---: | ---: |
| -45.0 | +0.19 m | 3.12 m | 0.048 | -0.302 |
| -22.5 | +0.04 m | 1.57 m | 0.009 | -0.166 |
| 0.0 (natural) | **-0.11 m** | 1.54 m | **0.000** | **0.000** |
| +22.5 | -0.31 m | 2.20 m | 0.000 | -0.175 |
| +45.0 | +0.06 m | 1.31 m | 0.015 | -0.335 |

Two defects, visible in the same table. Block clearance spans **-0.31 to +0.19
metres** and was normalised against `OPENNESS_SATURATION_M = 4.0` -- a scale an
order of magnitude too large for the quantity, so every block score came out at
0.05 or less. And openness was clamped at zero, so the natural line, which sends
the ball *into* sealed net at -0.11 m, scored exactly the same 0.000 as a lane
that grazes past. With openness flat at zero the score reduced to
`-strain x STRAIN_AVERSION`, which is maximised at strain zero -- the natural
line, by construction. The scan was not choosing badly; it had nothing to choose
on.

Fixed by giving block clearance its own scale (`BLOCK_OPENNESS_SATURATION_M`,
0.70 m -- clearing the outside hand by 70 cm is a fully open shot) and letting
openness go negative, so a ball into the hands scores below one past them.

That inverted the balance: openness now spans -1 to 1 where it spanned 0.05, and
`STRAIN_AVERSION = 0.35` stopped being a tie-break and became irrelevant. 89% of
swings went to the sharpest available cut. Re-derived against the design targets
on live rallies:

| STRAIN_AVERSION | off natural line | attack error | block involvement | stuff |
| ---: | ---: | ---: | ---: | ---: |
| 0.35 | 89.2% | 26.6% | 20.1% | 5.3% |
| 0.60 | 73.1% | 21.6% | 24.6% | 6.3% |
| 0.85 | 51.0% | 14.6% | 32.4% | 8.0% |
| **1.10** | **30.7%** | **10.6%** | **36.2%** | **9.0%** |
| 1.40 | 15.3% | 6.8% | 41.5% | 11.6% |

1.10 is where attack error and block involvement are both inside their bands
with shot selection still alive. 1.40 reaches the 12% stuff target, but only by
dropping errors below the sport and pulling selection back toward the natural
line -- buying one target by spending two. Stuff at 9.0% against a 12% target is
the residual, and it is the honest cost of the trade.

## All five ball paths measured

### The transition swing was not uncontested -- the call was misplaced

The previous revision of this document recorded a transition swing facing no
block at all, 0.0% block involvement and 96.2% in. That was wrong, and the error
was mine rather than the engine's: `_resolve_home_continuation` resolves its
block *after* it scores the swing, so the shadow call placed beside the swing
handed the resolver an empty formation. A misplaced call read as an absent
mechanism.

Moved to after `_resolve_opponent_block`, the transition swing is contested.
What that path genuinely does not do -- and the other two do -- is feed the
block back into `_attack_execution` as pressure. That asymmetry is real and
stays open; it is a missing term, not a missing block.

| path | n | attack error | block involvement | stuff | in |
| --- | ---: | ---: | ---: | ---: | ---: |
| home first ball | 724 | 8.7% | 43.1% | 16.3% | 48.2% |
| transition | 75 | 9.3% | 16.0% | 4.0% | 74.7% |
| opponent first ball | 13 | 23.1% | 23.1% | 7.7% | 53.8% |

A transition block being weaker than a first-ball block is right -- it forms off
a dig with no setter to read. The opponent first-ball path is rare in these
fixtures and n=13 says nothing yet.

**A caution on all of these numbers.** Measured over four roster pairings the
home path reads 8.7% error and 16.3% stuff; over three it read 10.6% and 9.0%.
The pairing-to-pairing spread is large enough that the `STRAIN_AVERSION` table
above is a guide to the *shape* of the trade, not a precise measurement of any
row. This is the same lesson as `ATTACK_SIDE_SYMMETRY_2026_08_03.md`, and the
same remedy applies: any figure worth acting on needs pairings averaged, not one
lucky fixture.

### The serve

`resolve_serve` composes the same pieces with two of them removed: no approach,
so no natural line and no repertoire cone -- a server picks a spot and hits it --
and no block, so the only things between contact and the floor are the tape and
the lines.

The property that decides everything: **a serve must be launched upward.** From
a 2.6 m contact a flat ball is about 1.5 m high when it reaches the net, so the
driven root cannot clear the tape and every serve takes the lofted one. On the
lofted branch range is steeply sensitive to launch angle, so vertical execution
error converts directly into balls long -- which is why a serve cannot carry a
spike's execution spread:

| SERVE_SPREAD_MULTIPLIER | home | opponent | combined |
| ---: | ---: | ---: | ---: |
| 1.00 | 32.8% | 32.2% | 32.5% |
| **0.70** | **15.6%** | **10.6%** | **13.1%** |
| 0.45 | 3.9% | 0.0% | 1.9% |

0.70 lands inside the sport's 8-15%. 0.45 produces a serve that essentially
cannot miss. A serve is struck from a standstill off a self-toss with no set to
read and no block to beat -- the one contact in the sport rehearsed in isolation
-- so carrying less scatter than a swing is right, and the multiplier is where
that belief gets a number.

Worth noting on its own: at full spread the two sides measured 32.8% and 32.2%,
and at 0.70 they measure 15.6% and 10.6%. One resolver, two sides, no divergence
that is not sampling -- which is the first direct evidence for the prediction
this gate is being held to.

## What this means for promotion

Promotion is still not taken, but the reasons have changed. Findings 2 and 3
were both reasons a promoted geometric attack would have played *worse* than the
legacy one despite being the better model -- a 28% error rate would have swamped
the rally, and a hitter with no course selection would have made every rally read
the same. Both are resolved: attack error sits at 10.6% inside the sport's band,
and 30.7% of swings now leave the natural line.

Coverage is now complete: three attack paths and two serve paths all resolve
through the shared geometry in shadow, and every rate they produce is inside or
adjacent to its design band. What is left before the flip is not more wiring.

The order from here:

1. Feed the transition block back into `_attack_execution` as pressure, the one
   term that path is still missing.
2. Re-derive `STRAIN_AVERSION` over averaged pairings rather than the three the
   table above used, now that the spread between samples is known to be wide.
3. Then open `ENABLE_GEOMETRIC_ATTACK` behind the development override and
   compare terminal outcome distributions against the legacy path.

The symmetry gate repaired in `ATTACK_SIDE_SYMMETRY_2026_08_03.md` is the
instrument for step 3. It measures a real six-point home tilt today, and the
geometric attack replacing three separately-written attack paths with one shared
resolver is the most plausible way that tilt goes away -- which makes it a
genuine prediction this gate can be held to rather than a hope.
