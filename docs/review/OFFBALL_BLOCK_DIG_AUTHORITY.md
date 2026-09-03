# Off-ball authority: block to dig

## Scope

Phase One hole 1 in `OFFBALL_RESOLVER_AUTHORITY.md`: publish the twelve-player
opinion for live `BLOCK→DIG` flights without changing rally resolution. The
pre-change measurements are on `ed73d91`; the post-change measurements are on
the tree recorded by this commit.

## Missing authoritative facts

Three contact paths produced this flight. The home-defence path already used
`_deflection_adjust_map` for its five non-claimants. The mirrored first-ball dig
published a static, untimed snapshot, the continuation dig published no phase
map, and none of the three published what the attacking six did after the
swing.

The candidate causes for the 6.66 unnamed volis were: an unrepresented
defensive scramble, an unrepresented attacking-side recovery, missing
continuation metadata, or the coverage probe reading the wrong event. Walking
consecutive contacts separated them: the DIG event is the record playback reads
for the preceding `BLOCK→DIG` flight, and its two phase maps contained exactly
those omissions.

## Resolution boundary

The defending five now reuse the existing deflection lean and the resolved
deflection-flight duration. The attacking six resolve toward the existing floor
shape over that same duration; the hitter holds their resolved contact position
with a `recovering` intent while the other five carry `defending`. Every target
is paired with `_travel_intent`, including its own traversal and window.
The closed cognition-cue vocabulary now names the two Phase One-authorized
intents, `chasing` and `recovering`; renderer fallbacks remain unchanged.

These are Phase One publication queries. They do not mutate `live_positions`,
enter claimant search, or charge exertion. The first implementation did charge
the queried journeys through `_reached_point`; the balance gate caught the
result immediately: contacts per rally moved 4.636→4.640 and kill rate
0.526→0.519. Separating an uncommitted reach query from a committed journey
restored the exact baseline without changing the reach calculation.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `ed73d91` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 6.89 | 7.55 |
| `BLOCK→DIG` flights | 174 | 174 |
| `BLOCK→DIG` named / 12 | 5.34 | 12.00 |
| home named / 6 | 3.14 | 6.00 |
| opponent named / 6 | 2.20 | 6.00 |

The timing population grows because the resolver now names more legs; this is
expected rather than hidden.

| measure | `ed73d91` | this commit |
|---|---:|---:|
| timed | 3,223 | 4,203 |
| untimed | 0 | 0 |
| early | 2,371 | 2,682 |
| cannot complete | 852 | 1,521 |

The balance probe is byte-identical across the changed tree and the same tree
with the Phase One files stashed. Both outputs have SHA-256
`09a486f470a35931021f690d06e9074a2a7624421499abfc8598ad0598aa18d5`.

## Gates

- Coverage: 7.55 overall; `BLOCK→DIG` is 12.00/12.
- Timing: 4,203 timed, 0 untimed.
- Balance: byte-identical over 700 rallies.
- Suite: 2 of 2,224 checks fail; both are the documented tempo assertion and
  stacked-blocker baseline failures.

The spec's 175 flights and 5.31 starting coverage were measured at `6ae238e`.
The requested `ed73d91` base produces 174 and 5.34; the priority and missing
roles are unchanged, so the spec's implementation conclusion still holds.
