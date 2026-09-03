# Off-ball authority: dig to set

## Scope

Phase One hole 4 in `OFFBALL_RESOLVER_AUTHORITY.md`: publish the side that has
just been dug on during every live `DIG→SET` flight, without changing rally
resolution. The pre-change measurements are on `9d07f7f`; the post-change
measurements are on the tree recorded by this commit.

## Missing authoritative fact

Classifying the 59 flights by the DIG actor's opposite side finds 39 where the
dug-on side names nobody and 20 where it names only three. Those three are the
existing pre-release blockers on opponent transition sets. The home transition
path has no opposing phase map at all. The direct mean is therefore 1.02/6,
not the fixed-side figure quoted by the spec.

## Resolution boundary

Both transition SET paths now publish the dug-on side's six-player re-forming
opinion for the resolved dig-flight duration. They reuse `_post_attack_phase_map`
and its existing floor shape; the most recent resolved ATTACK supplies the
hitter who is still recovering. These are uncommitted reach queries: they do
not mutate live positions, enter claimant search or charge exertion.

On the opponent SET path, the three existing pre-release blocker destinations
and `blocking` intents merge over that general re-form map. The specific wall
responsibility wins without erasing the other three players. Every surviving
target remains paired with its own `_travel_intent` record.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `9d07f7f` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 7.74 | 7.91 |
| `DIG→SET` flights | 59 | 59 |
| `DIG→SET` named / 12 | 6.12 | 11.10 |
| dug-on-side named / 6 | 1.02 | 6.00 |

The direct actor-side census has all 59 flights at 6/6 after the change. The
timing census grows from 4,105 to 4,258 published legs because these intents
join the measured population; `early` moves from 2,653 to 2,805,
`cannot_complete` from 1,452 to 1,453, and `too_short` from 2,031 to 2,088.
`untimed` remains 0.

The changed and exactly stashed balance-probe logs are byte-identical at SHA-256
`4a6316fe71e0d0164ee0ab23a36554796ddd87b330541a1dd7cbbf3668a0fcbe`.
The full suite reports 2 failures in 2,227 checks: the pre-existing strict-tempo
assertion and stacked-blockers assertion. There is no third failure.
