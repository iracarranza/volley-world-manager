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

## Candidate-gate result

Opening the existing unassigned-player argument changes none of the 700 paired
rallies. Both arms report contacts/rally 4.636, kill 0.526, dig 0.512, stuff
0.097 and serve error 0.194, with identical side splits and counts.

The reason is structural: `DefensivePlan.ensure_defaults` creates an enabled
floor-defence zone for every player in all six rotation slots. Both floor claim
sites already pass all six players, phase-established origins and those six
zones to `CoverageCalculator.choose_claimant`. The proposed unassigned-player
gate therefore adds zero candidates. This contradicts the implementation
spec's premise that Phase Two still needs to let those positions be claimed.
