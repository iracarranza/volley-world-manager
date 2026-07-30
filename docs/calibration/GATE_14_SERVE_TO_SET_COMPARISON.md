# Gate 14: Full Serve-to-Set Comparison

Date: 2026-07-30

## Question

How does the completed shadow serve→reception→setter-response path differ from
the official legacy serve→reception→set path?

## Reproduction

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --serve-to-set --summary-only \
  --samples=120 --start-seed=140000
```

## Result

The fixture requested 600 serves. There were 595 eligible receptions, 221 full
comparisons, and zero invalid traces.

| Measure | Result |
|---|---:|
| Official path complete, given comparison | 100.00% |
| Receiver agreement | 73.30% |
| Setter agreement | 96.83% |
| Mean pass destination difference | 1.117 m |
| Mean shadow minus legacy pass duration | -0.212 s |
| Mean shadow set choices | 1.158 |

The comparison does not declare either path correct merely because it exists.
The one-meter destination difference and shorter shadow duration are migration
risks that must remain visible during rollout.

## Gate decision

Gate 14 passes as a comparison gate. `RallyShadowComparison` reads completed
official events and detached shadow evidence without mutating either. Gate 15
may add a disabled source-selection boundary, but must continue selecting the
official path in every case.
