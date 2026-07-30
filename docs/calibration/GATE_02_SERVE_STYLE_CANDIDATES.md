# Gate 2 Review: Controlled Serve Styles and Timing Candidates

Review date: 2026-07-29

Status: **CONTROLLED FIXTURES COMPLETE; LEGACY DURATION RETAINED**

Gate 2 compares two shadow-only timing candidates across every supported
primary serve style:

- **legacy duration**: the duration already used by the live resolver;
- **signature duration**: distance divided by calculated contact speed, with
  the geometric path-length factor from `RallyKinematics`.

Neither candidate replaces the official claimant or rally result.

## Controlled fixture

Each style uses the same 120 seeds and a controlled proficiency of 75. A fresh
`GameManager` is created for each style so one fixture cannot change another.

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --samples=120 --start-seed=20000
```

The run requested 600 serves. It produced 585 eligible receptions, skipped 15
service errors, and produced zero malformed samples.

## Overall comparison

| Measurement | Legacy duration | Signature duration |
|---|---:|---:|
| Selected receiver reachable | 61.71% | 28.72% |
| Selected arrival margin, mean | +0.085 s | -0.125 s |

Changing the timing candidate changed the selected shadow claimant in only
2.56% of eligible samples. The large reachability change therefore mostly
removes actions from the same receiver rather than finding a better receiver.

## Results by serve style

| Style | Legacy reachable | Signature reachable | Legacy duration p10–p90 | Signature duration p10–p90 |
|---|---:|---:|---:|---:|
| Standing | 64.96% | 23.93% | 1.003–1.074 s | 0.741–0.852 s |
| Jump Topspin | 43.59% | 9.40% | 0.943–1.014 s | 0.699–0.792 s |
| Jump Float | 56.41% | 15.38% | 0.983–1.054 s | 0.735–0.846 s |
| Hybrid | 50.43% | 14.53% | 0.953–1.024 s | 0.717–0.818 s |
| Sky Ball | 93.16% | 80.34% | 1.183–1.254 s | 1.049–1.235 s |

These p10–p90 values are **regression reference bands from this controlled
fixture**. They are not claims about real-world volleyball measurements.

## Decision

Legacy duration remains the primary timing input for the next migration gate.
The reason is behavioral continuity: replacing it with the current calculated
contact speed would cut reception reachability by more than half and would make
Jump Topspin reception reachable in fewer than one in ten eligible samples.

The calculated `speed_mps` value should not remain an independent timing truth.
The next safe design is:

1. resolve duration through the existing balance model;
2. derive effective speed from distance, duration, and path factor;
3. retain spin, angle, stability, and action type as separate perception inputs;
4. compare the derived-speed signature with the current signature in shadow;
5. adjust duration intentionally only after option availability is reviewed.

This preserves the proposed information model without pretending that two
incompatible clocks are simultaneously authoritative.

## Visible proof

In debug builds, the 2D inspector now shows:

- legacy and implied duration;
- effective legacy speed;
- selected receiver and arrival margin for each timing candidate;
- whether the candidate changes the selected receiver.

## Gate limitation

Gate 2 covers serves only. It does not establish acceptable duration bands for
sets, attacks, blocks, or defensive contacts. Those actions require their own
controlled fixtures before sharing a live timing policy.
