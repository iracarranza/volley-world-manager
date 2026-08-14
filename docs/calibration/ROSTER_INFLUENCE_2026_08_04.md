# How much a roster is worth

Every gate in this arc has been measured with the roster held constant, because
one pairing's block rate swings across the whole range and drowns anything else.
This measures the quantity that was being held constant.

## The instrument

`REGION_SPECIALTY` grants a flat bonus on each region's named attributes, and
Landavol's list is deliberately empty -- "the one region where it isn't won by
size". That makes it a designed zero baseline, and every other region a known
attribute delta rather than a random draw. `apply_generated_attributes` now takes
a region so a sweep can vary the delta instead of only the seed.

Each region plays as home against a Landavol opponent, six roster pairings, both
serving assignments, 120 rallies per condition -- about 610 blocks and 550 digs
per cell, for a noise floor near 0.012.

## What it says

| region | stuff @8 | stuff @16 | dig @8 | dig @16 | kill share @8 | @16 |
|---|---|---|---|---|---|---|
| Landavol (baseline) | 0.090 | 0.090 | 0.276 | 0.276 | 0.479 | 0.479 |
| Blôc du Larg | 0.121 | 0.140 | 0.334 | 0.376 | 0.528 | 0.554 |
| Ĭspayk | 0.100 | 0.120 | 0.289 | 0.299 | 0.498 | 0.514 |
| Lo-ong Ralī | 0.090 | 0.090 | 0.297 | 0.314 | 0.492 | 0.497 |
| Xérvu (serving) | 0.096 | 0.102 | 0.262 | 0.293 | 0.471 | 0.497 |

**The response is near-linear.** Doubling the bonus gives about 1.7x the effect
across every region and every outcome. No wall, no runaway. The remaining
sublinearity is most likely the top of the attribute distribution clipping at
100: at a bonus of 16 a specialist sits around 84-87, so the tail is already
compressing, and that is the thing to check before any further increase rather
than assuming linearity continues.

**The engine was not hypersensitive to rosters, which is what this gate was
opened to prove.** The 0.000-0.907 stuff-rate range recorded elsewhere is
whole-roster *seed* variance -- draws where one roster's entire attribute set
lands strong -- not the response to a controlled delta. Those are different
quantities and conflating them produced the wrong prediction.

**Xérvu is the result worth trusting most.** A serving region with no defensive
bonus at all gains stuff and dig indirectly, because better serves produce worse
opponent reception and easier blocks. Nothing told the engine to do that; it
falls out of the chain. It is also the noise-floor control, and it moves further
than noise, which is how we know the chain is real.

## What it found that was not the question

Two regional identities do not do what their names say, because the attributes
they were given are not the attributes the models weight.

**The digging region is worse at digging than the blocking region.**
`_defense_execution` weights `reception` and `anticipation` heavily and
`dig_control` lightly. Lo-ong Ralī's specialty is `stamina`, `dig_control`,
`reception_stability` -- one lightly weighted attribute and two that barely enter
a dig. It gains 3.8 points of dig rate at a bonus of 16. Blôc du Larg, whose
`anticipation` sits at a heavy weight, gains 10.0.

**And the blocking region is really a general defensive region**, for the same
reason: its dig gain exceeds its stuff gain.

One part of this is correct and worth preserving. Blôc du Larg and Ĭspayk carry
identical `block_timing` and differ by two points of stuff rate, because
`_blocker_read_quality` reads `anticipation` and `court_vision`. A coherent
blocking tradition beating a bonus that merely contains a blocking attribute is
exactly the behaviour these regions exist to produce.

There are two ways to close the mismatch and they are different decisions, not
two spellings of one. Moving the *attributes* to match the fiction is cheap,
touches only content, and keeps the region names meaningful. Moving the *weights*
to match the attributes is defensible on its own terms -- an attribute called
`dig_control` arguably should dominate a dig -- but it rebalances every dig in
the engine and reopens calibration that several gates have just settled. Either
wants its own sweep: under the current weights, Bompaçao's `reception`,
`reception_balance`, `ball_control` package would likely become the strongest
defensive region in the game, and nobody designed it to be.


## The attributes moved to the fiction

`anticipation` is the most cross-cutting attribute in the engine -- 0.30 of dig
capability, 0.34 of a blocker's read, 0.10 of their contact -- and the blocking
tradition held it while the digging tradition did not. One swap each way:

- **Blôc du Larg** `block_timing, ball_control, court_vision, anticipation`
  -> `block_timing, jump_reach, court_vision, tactical_discipline`
- **Lo-ong Ralī** `stamina, dig_control, reception_stability`
  -> `stamina, dig_control, anticipation`

| region | stuff before | after | dig before | after |
|---|---|---|---|---|
| Blôc du Larg | 0.140 | 0.144 | 0.376 | 0.307 |
| Lo-ong Ralī | 0.090 | 0.119 | 0.314 | 0.383 |

Blôc du Larg's advantage over baseline is now +5.4 stuff and +3.1 dig, where it
was +5.0 and +10.0. Lo-ong Ralī's is +10.7 dig, where it was +3.8. The blocking
region blocks, the digging region digs, and neither does the other's job better
than they do.

Dropping `anticipation` did not cost Blôc du Larg any blocking: `jump_reach` at
0.29 of contact skill and `tactical_discipline` at 0.20 of the read more than
covered it. Two constraints were kept rather than broken -- `reception` is the
heaviest dig attribute and the obvious thing to hand Lo-ong Ralī, but it is
Bompaçao's claim and the minor tier exists to fill gaps no major region takes;
and minor regions get three attributes, so this is a swap and not an addition.

## Two things this leaves open

**`anticipation` still leaks, in the other direction now.** Lo-ong Ralī gains
2.9 points of stuff rate it has no business gaining, because the attribute sits
in the blocker's read as well as the dig. That is a third of Blôc du Larg's
advantage rather than three times it, so the ordering is right and the leak is
tolerable -- but the clean fix is splitting the attribute, not moving it again.

**Defensive identity now out-earns attacking identity.** Lo-ong Ralī takes 55.0%
of attack exchanges against Ĭspayk's 51.4%, so a digging tradition wins more
rallies than an attacking one. Digging well extends rallies and extended rallies
are won, which is not wrong in itself, but it means a career would reward
defensive rosters over offensive ones. Nothing here measured whether that
ordering is intended.
