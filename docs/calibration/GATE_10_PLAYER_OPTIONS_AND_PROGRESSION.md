# Gate 10: Player Development Creates More Options

Date: 2026-07-30

## Question

Does improving a receiver create earlier information, longer opportunity
windows, more contact choices, and better contact outcomes under paired serves?

## Controlled fixture

Three complete reception profiles were tested:

- developing: 40;
- established: 65;
- elite: 90.

Each rating was applied to anticipation, court vision, decision-making,
composure, acceleration, lateral speed, transition speed, reception, ball
control, reception balance, and reception stability. Fatigue was zero and
situation experience was cleared.

Each tier used the same three formations, five serve styles, serve proficiency,
player bodies, and paired seed range. This isolates the combined gameplay effect
of developing the reception profile; it does not isolate any one attribute.

## Reproduction

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --decision-progression --samples=40 --start-seed=100000
```

The run requested 1,800 cases. There were 1,755 eligible receptions, 45 serve
errors, and zero invalid traces. These are game-fixture measurements, not
real-world volleyball standards.

## Results by player tier

| Measure | Developing | Established | Elite |
|---|---:|---:|---:|
| Read confidence | 0.448 | 0.553 | 0.658 |
| Destination error | 0.751 m | 0.619 m | 0.480 m |
| Receive window opened | 36.92% | 64.96% | 90.43% |
| Mean open duration | 0.255 s | 0.514 s | 0.810 s |
| Shadow decision made | 30.60% | 57.26% | 86.84% |
| Contact choices, mean | 1.299 | 1.585 | 2.485 |
| Quick release available | 0.00% | 1.20% | 61.71% |
| Contact success | 11.28% | 41.71% | 76.07% |
| Mean contact quality | 0.199 | 0.436 | 0.710 |

Decision rate, contact success, window duration, and contact-choice count all
improved monotonically across the three tiers.

## Formation remains relevant

| Formation | Decision made | Contact success | Contact choices |
|---|---:|---:|---:|
| Standard | 76.41% | 63.08% | 2.058 |
| Compressed middle | 53.68% | 37.44% | 1.720 |
| Split deep | 44.62% | 28.55% | 1.591 |

Player growth does not erase tactical positioning. The same developed players
still receive different options from different starting formations.

## Gate decision

The central design objective is verified in shadow mode: improvement gives a
player more information, more time, more available choices, and better results.
It is no longer only a hidden percentage bonus.

Live activation is still deferred. The next gate should turn a successful
shadow contact into an authoritative outgoing `BallFlight` candidate and verify
contact-to-flight continuity. Only after that should a disabled feature flag
compare complete serve-to-reception playback against the legacy event.
