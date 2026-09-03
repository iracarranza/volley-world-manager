# Off-ball authority: set decision to set

## Scope

Phase One hole 5 in `OFFBALL_RESOLVER_AUTHORITY.md`: publish the opposing side's
read while the home setter controls and releases the second ball, without
changing rally resolution. The pre-change measurements are on `47121c8`; the
post-change measurements are on the tree recorded by this commit.

## Measurement before mechanism

The 114 live `SET_DECISION→SET` flights span 0.217530–0.513378 seconds. Their
10th, 50th and 90th percentiles are 0.243497, 0.276706 and 0.399594 seconds.
The window is exactly the resolved set release interval and is not the
sub-tenth interval the implementation spec proposed as the likely case.

All 114 opposing sides publish zero targets and zero intents before this
change. The missing authoritative fact is not new geometry: `_form_opponent_block`
already derives each participating front-row blocker's pull toward the setter
and credits the pass-to-release interval to the wall. It retained only the
distance, not the position playback needs.

## Resolution boundary

The block resolver now retains that already-derived pull position. The SET
record publishes each front-row read as a reachability-bounded `blocking`
target with its paired `_travel_intent`. The other on-court opponents receive a
timed `watching` intent and no target: the resolver knows they hold their ground
but has not resolved a destination for them before the set leaves the hands.

Playback treats an intent-only record as authoritative stillness, so it does
not substitute `_apply_cheat_steps`. The coverage instrument likewise counts
either half of the phase contract as an opinion; existing target/intention pairs
are unaffected by that correction.

## Measurements

The coverage probe uses 400 rallies, seeds 61000–61199 with both serving sides.

| measure | `47121c8` | this commit |
|---|---:|---:|
| drawn flights | 1,756 | 1,756 |
| all-flight `mean_named_of_12` | 7.91 | 8.30 |
| `SET_DECISION→SET` flights | 114 | 114 |
| `SET_DECISION→SET` named / 12 | 5.04 | 11.04 |
| opposing-side opinions / 6 | 0.00 | 6.00 |

Every sampled flight publishes three blocker targets and all six intent records.
The timing census grows from 4,258 to 4,511 measured moving legs; `early` moves
from 2,805 to 3,058, `cannot_complete` remains 1,453, and `too_short` moves from
2,088 to 2,087 as the probe carries the newly published blocker endpoints into
later legs. Intent-only holds are deliberately not moving legs. `untimed`
remains 0.

The changed and exactly stashed balance-probe logs are byte-identical at SHA-256
`4a6316fe71e0d0164ee0ab23a36554796ddd87b330541a1dd7cbbf3668a0fcbe`.
The full suite reports 2 failures in 2,228 checks: the pre-existing strict-tempo
assertion and stacked-blockers assertion. There is no third failure.
