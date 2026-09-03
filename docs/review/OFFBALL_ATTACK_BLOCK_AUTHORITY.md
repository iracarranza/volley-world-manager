# Off-ball authority: attack to block

## Scope

Phase One hole 2 in `OFFBALL_RESOLVER_AUTHORITY.md`: publish the attacking
side's complete opinion for live `ATTACK→BLOCK` flights without changing rally
resolution. The pre-change measurements are on `1a00781`; the post-change
measurements are on the tree recorded by this commit.

## Missing authoritative fact

Walking the 216 flights at `1a00781` by the ATTACK actor's actual side showed
that `_cover_phase_map` named exactly five attacking volis every time. It
already published each non-hitter's resolved cover responsibility, target and
timed intent. The omitted voli was always the hitter: 106 outside hitters, 100
opposites and 10 middles.

This contradicts the spec's “about three of six.” Its 2.80 unnamed figure was
the probe's fixed opponent-side aggregate across attacks by both teams, not the
attacking side. The implementation spec is corrected in this commit.

## Resolution boundary

The hitter now carries a `recovering` intent at their already-resolved attack
position for the existing attack-flight duration. The paired target is the same
resolved point, so this publishes a zero-distance recovery rather than moving,
snapping or re-resolving the hitter. The other five continue to use the existing
`attack_coverage_responsibility` paths.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `1a00781` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 7.55 | 7.68 |
| `ATTACK→BLOCK` flights | 216 | 216 |
| `ATTACK→BLOCK` named / 12 | 8.32 | 9.32 |
| attacking-side named / 6 | 5.00 | 6.00 |

Publishing the intermediate zero-distance recovery also gives the timing probe
the hitter's correct live starting point. Consequently 99 later legs that had
been measured from a stale pre-attack point become shorter than its 0.05 m
floor. The denominator falls rather than hiding those false distances.

| measure | `1a00781` | this commit |
|---|---:|---:|
| timed | 4,203 | 4,104 |
| untimed | 0 | 0 |
| too short to classify | 1,658 | 1,943 |
| early | 2,682 | 2,652 |
| cannot complete | 1,521 | 1,452 |

The balance probe is byte-identical across the changed tree and the same tree
with the Hole 2 files stashed. Both outputs have SHA-256
`09a486f470a35931021f690d06e9074a2a7624421499abfc8598ad0598aa18d5`.

## Gates

- Coverage: 7.68 overall; the attacking side is 6.00/6 on `ATTACK→BLOCK`.
- Timing: 4,104 timed, 0 untimed.
- Balance: byte-identical over 700 rallies.
- Suite: 2 of 2,225 checks fail; both are the documented tempo assertion and
  stacked-blocker baseline failures.
