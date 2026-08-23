# M4 controlled-dig intent: the setter release seat is now the stated anchor

Run: 2026-08-17, from `935fcac`. Instrument:
`tools/run_platform_intent_census.gd`.

## Change

All three production controlled-dig paths now publish the existing team setter
release target as `platform_intent.target_anchor`, with
`anchor_source = "release_seat"`:

- opponent floor dig in `RallySimulator.resolve`;
- home floor dig in `_resolve_opponent_transition`;
- opponent continuation dig in `_resolve_home_continuation`.

The intended recipient remains the setter already named by each path. No new
target, offset, height, duration, weighting, or movement rule was introduced.

This is intent metadata only. Each call still passes its pre-existing
contact-local `opponent_pass_target`, `defense_pass_target`, or
`cont_desired_target` into `_dig_pass_result`. That resolver still owns the
legacy destination and outgoing trajectory.

## Paired-seed behavior delta

The same 600-rally census was run immediately before and after the change, seeds
23000-23299 with each serving side:

| measure | before | after | delta |
|---|---:|---:|---:|
| rallies | 600 | 600 | 0 |
| home points | 290 | 290 | 0 |
| events | 3,887 | 3,887 | 0 |
| controlled-dig contacts | 277 | 277 | 0 |
| controlled-dig release-seat anchors | 0 | 277 | +277 |

Every terminal outcome is byte-for-byte equal: ace 9, attack error 54, blocked
26, counter-block 30, kill 159, opponent attack error 46, opponent kill 160,
serve error 116.

The repaired intent-anchor gap is 0.000 m for all 277 controlled digs. As the
control that the ball was not silently moved, the 87 successful digs still
realize legacy destinations 0.924-8.378 m from the release seat (median 4.310 m,
mean 4.555 m). That gap is the still-open transfer/selection work, not an intent
metadata defect.

## Gate

The old characterization that every dig "aims a stride from itself" has been
replaced. The suite now requires every controlled-dig intent to use its own
team's actual setter-release target, not merely to carry the `release_seat`
label.

This checkpoint does not authorize changing `_dig_pass_result`, copying current
apex bands into a physical model, or treating the intended setter as the actual
second-contact interceptor.
