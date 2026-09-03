# Off-ball authority: reception to set decision

## Scope

Phase One hole 6 in `OFFBALL_RESOLVER_AUTHORITY.md`: publish all twelve reads
during the live `RECEPTION→SET_DECISION` flight without changing rally
resolution. The pre-change measurements are on `efbf820`; the post-change
measurements are on the tree recorded by this commit.

## Measurement before mechanism

The 114 pass windows span 0.243118–1.203025 seconds. Their 10th, 50th and 90th
percentiles are 0.788173, 1.066482 and 1.131482 seconds. This is not a
stationary sub-tenth interval.

The SET_DECISION publishes no phase targets or intents before this change. The
following SET publishes four home transition entries on 110 flights and five
on four flights, and all 460 entries carry `window_seconds` drawn from the pass
distribution above—not the 0.217530–0.513378 second release interval in which
playback consumes them. The movement exists and its clock is authoritative; it
is attached one record late.

The receiving-side receiver is the remaining positional omission. The
transition builder excludes the contact actor, and unlike the opponent path the
home first-ball path never republishes that actor's resolved recovery position.

## Resolution boundary

The existing receiving-side transition and hitter-staging entries move from the
SET to SET_DECISION, and the receiver receives the same zero-distance
`recovering` intent used by the opposite path. The setter is the decision actor,
so those five entries plus the actor cover the receiving six.

The opposing side's already-resolved setter read also moves from the SET to
SET_DECISION and is recalculated against the pass window. The later SET retains
six timed intents per side with no targets: both teams hold the positions they
resolved during the pass while the setter releases the ball. Playback skips
its pass-staging shortcut when the preceding record is SET_DECISION, so it does
not reissue a completed journey.

No live simulation position, claimant search, exertion charge, outcome or ball
trajectory changes.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `efbf820` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 8.30 | 9.08 |
| `RECEPTION→SET_DECISION` flights | 114 | 114 |
| `RECEPTION→SET_DECISION` named / 12 | 1.00 | 12.00 |
| `SET_DECISION→SET` named / 12 | 11.04 | 12.00 |

All 114 pass flights resolve at 12/12. All 114 release flights publish six
intent-only holds per side and no phase targets.

Across the 1,460 live-ball flights (excluding the 296 deliberately deferred
`→POINT` tails), phase-one coverage is now 10.78/12. Across all 1,756 drawn
flights it is 9.08/12.

The timing census remains exactly 4,511 measured moving legs. Moving the same
journeys onto their published pass clocks changes `early` from 3,058 to 3,248,
`cannot_complete` from 1,453 to 1,263, and `too_short` from 2,087 to 2,167.
`untimed` remains 0. The intent-only release holds are not moving legs.

The changed and exactly stashed balance-probe logs are byte-identical at SHA-256
`4a6316fe71e0d0164ee0ab23a36554796ddd87b330541a1dd7cbbf3668a0fcbe`.
The full suite reports 2 failures in 2,229 checks: the pre-existing strict-tempo
assertion and stacked-blockers assertion. There is no third failure.
