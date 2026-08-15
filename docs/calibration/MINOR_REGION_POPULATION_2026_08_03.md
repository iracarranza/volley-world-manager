# Minor region population requirements

Date: 2026-08-03
Measured at: `36d5fe4`
Method: `WorldPopulation.generate(7777, size)` at 4,000 / 6,000 / 8,000 /
12,000 / 16,000, with tier and positional affinity live.

## The question

Both of us assumed the minor tier would need a larger world. The reasoning
looked sound: Zaitgaist raises about 60 players spread across 31 age cohorts
and five positions, which is under one player per position per cohort.

## The answer: no bump is needed

**Every minor region already fields a starting seven and a 14-player squad at
the current 4,000.**

| region | raised | pro-age (21-34) | S/OH/MB/OP/L | seven? | squad of 14? |
| --- | ---: | ---: | --- | --- | --- |
| Tãul ys Feynt | 123 | 70 | 15/30/4/9/12 | yes | yes |
| Lo-ong Ralī | 111 | 59 | 9/20/4/4/22 | yes | yes |
| Bompaçao | 126 | 75 | 11/29/11/4/20 | yes | yes |
| Rhėn Tempaol | 137 | 74 | 14/23/27/6/4 | yes | yes |
| Kutré Lyn | 103 | 60 | 12/30/9/6/3 | yes | yes |
| Zaitgaist | 66 | 37 | 5/12/12/3/5 | yes | yes |

The cohort-spread reasoning was wrong because it divided by all 31 ages. Only
the pro band matters at any given moment, and 37-75 players is comfortably
enough for positional coverage.

Note the positional skew is visible in the raw counts and behaving: Lo-ong Ralī
has 22 liberos against 4 middles, Rhėn Tempaol 27 middles against 4 liberos.

## Visibility is also already fine

| world size | minor share of world | minor share of the 120-player market | minor CA>=75, pro age | best minor CA |
| ---: | ---: | ---: | ---: | ---: |
| 4,000 | 17.2% | 15.0% | 18 | 90 |
| 8,000 | 17.0% | 17.5% | 44 | 86 |
| 12,000 | 16.8% | 18.3% | 44 | 87 |

Minor regions hold a stable ~17% of the world at every size and surface in the
transfer market at roughly their share, so they are neither invisible nor
over-represented. The best minor-raised player is CA 86-90 regardless of size —
the tier produces a genuine standout without a larger world.

## What a bump would actually buy

One thing, and it is not viability: the count of genuinely good minor players
(CA >= 75, pro age) rises from 18 to 44 between 4,000 and 8,000, then **stops**
— 12,000 gives the same 44.

So if the world is enlarged for other reasons — scouting depth generally,
richer transfer markets — **8,000 is the knee of the curve** and there is no
case for going past it on this evidence. Note that `scales_with_population` is
deliberately false for the generational tier, so doubling the world changes the
*shape* of the talent distribution (more journeymen, same eight generational
players), not merely its volume. That is working as designed and is why the
best minor CA does not climb with size.

## Recommendation

**Do not raise `DEFAULT_POPULATION_SIZE` for the minor regions.** They do not
need it. Raise it only if scouting depth is wanted for its own sake, and stop
at 8,000 if so.

This also removes the stated blocker on making minor regions playable later:
the constraint was assumed to be squad viability, and squad viability already
holds. Whatever makes them playable is UI and career-setup work, not
population.
