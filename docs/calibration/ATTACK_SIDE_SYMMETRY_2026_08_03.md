# The side of the net is worth about six points of attack share

Date: 2026-08-03
Occasion: removing `leadership` from the ability set turned
`"neither side's attack wins appreciably more than the other's"` red. The
leadership change is not the cause. The gate was measuring noise, and
measuring it properly surfaced a real asymmetry underneath.

## How it was found

Removing an entry from `ABILITY_ATTRIBUTES` changes the number of draws in
`_apply_attributes`, which shifts the shared generation stream and rerolls
every player. That is the same hazard recorded in
`IDENTITY_AND_BLOCK_TEST_POWER_2026_08_03.md`, and it is unavoidable here
because the attribute genuinely leaves the ability set.

The gate asserted `|home_attack_share - 0.5| <= 0.12` on a single generated
roster pairing at seed 900006. Swept across forty consecutive base seeds,
80 rallies each:

| | value |
| --- | ---: |
| min | 0.054 |
| max | 1.000 |
| mean, unmodified tree | 0.639 |
| mean, with leadership removed | 0.674 |
| seeds landing inside the 0.12 bound | 10 of 40 |

The two means differ by 0.035 against a per-seed standard deviation of about
0.24, so at forty samples the standard error is 0.038 — the leadership change
is not distinguishable from no change at all. What the sweep does show is that
a single pairing decides the number: the spread is nearly the full range, and
the gate passed on `main` only because seed 900006 happened to sit at 0.088.

The comment on the gate instructed that the seed be "re-swept whenever
generation changes rather than weakening the symmetry bound." That procedure
re-fits the gate to noise after every change. A gate that is re-fitted until it
passes cannot fail, and therefore cannot detect the asymmetry it exists to
detect.

## Separating the side from the rosters

Home squads were seeded from one region of the seed space and away squads from
another (`base_seed` and `base_seed + 5000`), so a systematic strength
difference between those two neighborhoods would read as a side effect. Running
each pairing a second time with the two squads exchanged separates them:

| | pooled share | decided points |
| --- | ---: | ---: |
| squad set A at home | 0.647 | 829 |
| squad set B at home (swapped) | 0.559 | 709 |

The share did not flip to 0.353 when the squads were exchanged, so most of the
excess follows the side rather than the rosters. Decomposed: a side effect of
about 0.60 and a roster-strength difference of about 0.04 favouring set A.

Measuring the side directly — every squad playing equal rallies as home and as
away, and equal rallies serving and receiving, so roster strength and serve
advantage both cancel by construction:

| spacing | rally seeds | side share | n |
| --- | --- | ---: | ---: |
| 1000 | 5000+ | 0.5609 | 1510 |
| 1 | 5000+ | 0.5632 | 1170 |
| 1000 | 900006+ | 0.5929 | 1658 |

Three configurations, 0.56–0.59, standard error about 0.013 at these sample
sizes. The home side's attack wins roughly **56–59%** of attack-decided points
against an identically generated opponent under fully balanced conditions.

## What changed in the gate

`_pooled_home_attack_share(pairings, rallies_per_condition)` replaces the
single-seed read. Ten pairings, each played in both squad assignments and both
serving assignments, 40 rallies per condition — 1600 rallies, about eight
seconds, roughly 800 attack-decided points. Win counts are pooled rather than
averaged as per-pairing ratios, so a pairing that resolves few decided points
does not carry the same weight as one that resolves many.

**The 0.12 bound is unchanged.** It did not need loosening; the measurement
needed fixing. It measures **0.558**, which is 3.3 sigma above 0.5 and 3.5
sigma below the 0.62 ceiling. Because the seeds are fixed the gate is
deterministic, so that margin is sensitivity rather than flakiness: any change
that worsens the tilt by another four points fires it.

## The real finding underneath

There is a genuine home-side attack advantage of about six points, and it has
been invisible for the whole life of this gate because the gate was being
re-fitted to noise. It belongs to the same family the gate's own comment
enumerates — the approach-start side flip, staged-versus-unstaged movement,
three copies of the block contest, tempo demand, the overreach penalty,
familiarity, the target scan, the missing opponent first-ball set path — every
one of which was the home team modelled fully and the opponent modelled as a
simplified parallel implementation.

This is not fixed here, and the gate does not treat 0.558 as correct. It is
recorded as an open defect: something in the attack path still favours the home
side by six points once rosters and serve are controlled for. The Gate E
resolver substitution replaces all three attack paths with one shared
`GeometricAttackResolver.resolve_swing()` call, which is the natural place for
a single implementation to eliminate whatever remains of the parallel one — and
this gate, now that it measures the side rather than the pairing, is what will
say whether it did.
