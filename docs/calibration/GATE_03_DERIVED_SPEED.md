# Gate 3 Review: Duration-Derived Contact Speed

Review date: 2026-07-29

Status: **SHADOW CANDIDATE VALIDATED; SAFE FOR FURTHER SHADOW INTEGRATION**

Gate 3 keeps the legacy flight duration and landing point unchanged. It derives
`speed_mps` from court distance, duration, and the geometric path factor. Spin,
angle, stability, and action type remain unchanged.

The derived signature is passed through the same familiarity, perception,
movement, and opportunity calculations as the existing independent-speed
signature. It cannot replace the official receiver or rally result.

## Reproduction command

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --derived-speed \
  --samples=120 --start-seed=30000
```

The controlled run requested 600 serves. It produced 590 eligible receptions,
skipped 10 service errors, covered all five serve styles, and produced zero
malformed samples.

## Comparison

| Measurement | Independent speed | Derived speed | Difference |
|---|---:|---:|---:|
| Mean speed | 19.04 m/s | 15.07 m/s | -3.96 m/s |
| Selected receiver reachable | 68.47% | 70.17% | +1.69 percentage points |
| Destination error, mean | 0.755 m | 0.738 m | -0.017 m |
| Recognition delay, mean | 0.215 s | 0.211 s | -0.004 s |

The selected shadow receiver changed in 0.34% of eligible samples.

## Interpretation

The independent speed was increasing novelty without agreeing with the flight's
actual duration. Replacing only that descriptor with the duration-derived speed
slightly improves player information while preserving almost every receiver
choice. It does not create the severe loss of available actions seen when the
entire flight duration was shortened in Gate 2.

These values describe the seeded controlled fixture. They are not real-world
volleyball measurements.

## Decision

The derived-speed signature is approved as the canonical **shadow** signature
for the next reception integration step. Live reception remains unchanged.

Before live activation:

1. repeat the comparison across different player attribute levels and court
   formations;
2. verify that progression in anticipation, court vision, and familiarity
   produces understandable information benefits;
3. add controlled timing evidence for sets, attacks, blocks, and defensive
   contacts;
4. define a feature flag and rollback path for any official claimant change.

## Visible proof

The debug 2D inspector now shows independent and derived speed, the receiver
selected by the derived-speed candidate, and whether that receiver differs from
the current shadow selection.
