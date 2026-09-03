# Off-ball claimant Phase Two baseline

## Boundary

Phase Two does not add another claimant algorithm. Both floor-defence branches
already call `CoverageCalculator.choose_claimant` with all six on-court players
and their resolved live positions. The existing `unassigned_reach_meters = -1`
argument excludes any body without an enabled floor-defence zone before scores
are compared.

The rollout therefore opens that candidate gate behind
`ENABLE_OFFBALL_POSITION_CLAIMANTS`, defaulting closed. A debug-only development
override exists solely so the same seeds can be measured with the gate shut and
open. This commit adds no consumer and therefore changes no rally outcome.

At this commit's default-closed 700-rally baseline: contacts/rally 4.636, kill
rate 0.526, dig rate 0.512, stuff rate 0.097 and serve-error rate 0.194. The
governed bands are green; contacts and kill rate are the advisory gaps Phase Two
is expected to move.

## First-pass prediction

Before measurement, the expected effect remains the implementation spec's:
more emergency floor contacts, more contacts per rally, a higher dig rate and a
lower kill rate. No rate will be tuned in the mechanism commit.
