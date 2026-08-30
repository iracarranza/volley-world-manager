# Are the creation vignettes any good as diagnostics?

Fifteen situations -- Q1's three answers plus the twelve of Q2 to Q5 -- resolved
through the rally simulator and measured by `tools/situation_grid.tscn`, which
asks the same questions of every contact whatever kind of contact it is. About
sixty rows. The question this answers is not "do the vignettes look right" but
whether widening the situation set finds defects that a narrower one cannot.

## Yes, and the mechanism is specific

**Broadening the set surfaced six outliers the three Q1 rows could not have
contained**, because Q1 never includes an opponent transition attack, a home
block against an opponent swing, or a second reception. The rows that do not
look like their neighbours:

| situation | contact | what stands out |
|---|---|---|
| `defense/floor` | BLOCK 1 | reach **2.08 m**, lag **-2.37 s** |
| `transition/*` | RECEPTION 106 | reach **5.79 m**, share **46-48%** |
| `transition/*` | SET 5 | reach **3.04 m** |
| `defense/floor` | DIG 102 | share **0%** |
| `broken/*` | RECEPTION **8** | an actor id that is on neither roster |
| `good_ball/quick` | DIG 103 | reach 1.41 m |

Two of those are worth naming as classes rather than instances. A **lag of
-2.37 s** is not a body in the wrong place; it is the drawn ball arriving at a
contact point two and a third seconds before the rally says the contact happened,
which no still frame and no per-rally viewing would ever catch. And **actor 8**
does not exist -- the home roster is 1 to 6 and the opponent 101 to 106 -- so a
resolved rally is publishing a contact by nobody. That one is a simulator
finding that arrived through a presentation instrument, which is the strongest
possible argument for the approach.

## The comparability worry did not materialise, mostly

The stated risk of breadth was that thirty situations would each differ from
their neighbours for legitimate reasons and outlier-spotting would stop working.
For `reach` it held up: across all fifteen situations the bulk of rows sit
between 0.18 and 0.95 m, which is a body's own radius, and the six exceptions
stand out immediately. Widening the set did not widen the normal band.

`lag` behaved similarly -- most rows within ±0.5 s, with -2.37 unmistakable.

## The ceiling column stopped working, and that is the honest cost

`peak deg/s` flags past 2,500, and at three situations it discriminated: two
serves came in near 1,000 and did not flag. At fifteen situations **it flags
roughly nine rows in ten**. A column that fires on ninety per cent of its rows
carries no information, however correct each individual firing is.

That is not the threshold being wrong. Snaps genuinely cluster at contacts --
`probe_platform_release` measures the same thing directly, a 108-degree
single-frame turn on every passer in every situation. The column is reporting a
real and pervasive defect, and *because* it is pervasive it can no longer point
at anything in particular. A detector for something universal is a constant.

The repair is to make it relative rather than absolute -- each row against the
distribution of its own column, so the question becomes "which contact snaps
worse than contacts normally do" instead of "which contact snaps". Until the
underlying seam is fixed, the absolute version should be read as a single global
fact and not as a per-row signal.

## What the vignettes are good for, and what they are not

**Good for:** anything that is visible only by comparison. Omissions, which show
as a small `share` beside large ones. Discrepancies between the resolved rally
and the drawn one, which is the whole of the `lag` column. Impossible states
like a contact by an actor who does not exist. None of these needs a prior
hypothesis, which is what separates the grid from the suite -- 2,163 checks and
not one of them can assert about a frame that was never drawn.

**Not good for:** anything universal, per the ceiling column above. And not good
for judging whether a vignette *teaches* its distinction, which is a different
question the grid is silent on and which the acceptance contracts answer badly:
all twelve Q2-Q5 vignettes score 100, and moving `transition_commitment` or
`decisiveness` across its whole range produces a byte-identical rally. Three
answers, one rally, full marks. The grid did not catch that either -- comparing
the three answers against each other did.

So there are two instruments here and they find different things. The grid
compares *contacts* and finds physical defects. Comparing a question's answers
against each other compares *rallies* and finds inert inputs. Neither subsumes
the other, and the acceptance score finds nothing at all.

## Cost

A resolved vignette is cheap: most hit their contract on the first or second
seed, so the 720-seed budget is patience and not spend. Filming fifteen of them
at 0.1 engine time scale under software GL is about twenty-five minutes, which
is a background job rather than an interactive loop. Caching resolved fixtures
to disk, keyed on a fingerprint of the simulator sources the way
`voli_sticker.FINGERPRINT_SOURCES` already keys baked headshots, would make the
resolve step free and leave only the filming.
