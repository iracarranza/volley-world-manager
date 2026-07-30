# Gate 12: Setter Response to the Pass

Date: 2026-07-30

## Question

Can second-contact players prepare during the serve, read the outgoing pass,
correct their movement, and gain explicit set options without changing the
official rally?

## Implementation

`ShadowSetterResponseSystem` receives the Gate 11 outgoing `BallFlight` and a
copied `RallyState`.

1. The preferred setter releases toward the saved setter target while the
   serve is still in flight.
2. Eligible non-passers read the outgoing pass at 15%, 40%, and 65% progress.
3. Each read can redirect projected movement.
4. `ActionOpportunityWindow` records when a set is perceived as reachable.
5. Available actions can include `emergency_bump_set`, `controlled_set`, and
   `quick_tempo_set`.
6. The selected response is graded against the authoritative pass destination
   and arrival time.

All projections use snapshots. Source player positions and official
`RallyEvent` data remain unchanged.

## Failed first attempt

The first implementation began setter movement only after reception contact.
Across 217 successful passes, authoritative setter reachability was 0% and the
mean arrival margin was -1.31 seconds. That result failed the gate.

Adding pre-contact setter release increased mean selected movement from 0.04 m
to 2.79 m, but the original pass fixture was still too fast. Gate 11 pass speed
was then recalibrated and revalidated rather than relaxing reachability rules.

## Reproduction

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --setter-response --summary-only \
  --samples=120 --start-seed=120000
```

## Accepted result

The batch requested 600 serves across five styles. There were 585 eligible
receptions, 15 serve errors, and zero invalid traces. Of those receptions, 217
produced successful outgoing passes and setter responses.

| Measure | Result |
|---|---:|
| Setter response rate, all eligible serves | 37.09% |
| Preferred setter selected, given response | 100.00% |
| Authoritatively reachable, given response | 19.35% |
| Mean second-contact choices | 1.22 |
| Mean read confidence | 0.544 |
| Mean opportunity-window duration | 0.227 s |
| Mean projected movement | 3.17 m |
| Mean authoritative arrival margin | -0.113 s |

`Authoritatively reachable` is the balanced-set threshold. Late cases can
still expose an emergency set, which is why mean action count is above one even
though most selected setters do not reach a balanced contact window.

## Gate decision

Gate 12 passes in shadow mode. The outgoing pass now changes player movement
and the resulting movement changes second-contact actions. The negative mean
margin is retained as balance evidence; it must not be silently converted into
a perfect set. Gate 13 should adapt this continuous evidence into developer-only
playback data without replacing official events.
