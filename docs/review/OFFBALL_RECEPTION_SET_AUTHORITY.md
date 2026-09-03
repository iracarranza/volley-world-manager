# Off-ball authority: reception to set

## Scope

Phase One hole 3 in `OFFBALL_RESOLVER_AUTHORITY.md`: complete the receiving
side's opinion for live `RECEPTION→SET` flights without changing rally
resolution. The pre-change measurements are on `8d6f8d5`; the post-change
measurements are on the tree recorded by this commit.

## Missing authoritative fact

Directly classifying each flight by its RECEPTION actor finds 128 flights: 122
name five of the receiving six and six already name all six. The recurrent
omission is the receiver—36 liberos and 86 outsides. The ordinary first-ball
path uses `_opponent_transition_phase_map`, which deliberately excluded the
first contact while correctly publishing the other four transition journeys;
the SET actor supplies the sixth name.

This contradicts the spec's 2.98 unnamed receiving-side claim. That number was
the probe's fixed home-side aggregate across both directions. The implementation
spec is corrected in this commit.

## Resolution boundary

On an opponent reception, the receiver now carries `recovering` at the
already-resolved platform position for the pass's resolved flight duration.
The event family, rather than the `first_ball` branch, is authoritative: this
also covers two overpass receptions that continue through the transition path.
The target and all three points passed to `_travel_intent` are that same point,
so the record states recovery without moving the body or entering claimant
search. The one home-side flight was already complete because its receiver is
also the staged hitter. The same later hitter-staging pass correctly replaces
`recovering` with a timed `preparing_attack` journey when an opponent receiver
is selected for contact three. Transition balls out of digs remain untouched
for Hole 4.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `8d6f8d5` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 7.68 | 7.74 |
| `RECEPTION→SET` flights | 128 | 128 |
| `RECEPTION→SET` named / 12 | 8.02 | 8.98 |
| receiving-side named / 6 | 5.05 | 6.00 |

Most new records are zero-distance in resolver state and move below the timing
probe's 0.05 m classification floor. One overpass is classified from that
probe's reconstructed prior playback position.

| measure | `8d6f8d5` | this commit |
|---|---:|---:|
| timed | 4,104 | 4,105 |
| untimed | 0 | 0 |
| too short to classify | 1,943 | 2,031 |
| early | 2,652 | 2,653 |
| cannot complete | 1,452 | 1,452 |

The balance probe is byte-identical across the changed tree and the same tree
with the Hole 3 files stashed. Both outputs have SHA-256
`09a486f470a35931021f690d06e9074a2a7624421499abfc8598ad0598aa18d5`.

## Gates

- Coverage: 7.74 overall; the receiving side is 6.00/6 on `RECEPTION→SET`.
- Timing: 4,105 timed, 0 untimed.
- Balance: byte-identical over 700 rallies.
- Suite: 2 of 2,226 checks fail; both are the documented tempo assertion and
  stacked-blocker baseline failures.
