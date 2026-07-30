# Gate 1 Review: Rally Kinematics and Shadow Calibration

Review date: 2026-07-29

Status: **IMPLEMENTED IN SHADOW MODE; HOLD LIVE REBALANCING**

This gate adds measurement and shared unit conversion. It does not change the
official receiver, rally winner, contact quality, or legacy flight duration.

## What was added

1. `RallyKinematics` is the shared source for normalized-court-to-meter
   conversion, diagnostic flight duration, effective speed, and timing checks.
2. Every eligible shadow reception now records distance, calculated contact
   speed, legacy duration, implied duration, effective legacy speed, relative
   error, and tolerance status.
3. `RallyCalibrationReport` aggregates claimant agreement, reachability,
   perception, timing, and per-serve-style distributions.
4. `tools/run_rally_calibration.gd` runs a repeatable headless batch.
5. The debug 2D inspector displays legacy versus implied timing and marks a
   mismatch without changing playback behavior.

## Reproduction command

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=300 --start-seed=1000
```

## Measured result

The first 300-rally run produced 290 eligible reception samples and 10 service
errors with no reception to evaluate. No eligible sample had malformed timing
evidence.

| Measurement | Result |
|---|---:|
| Legacy/shadow claimant agreement | 89.66% |
| Shadow-selected receiver reachable | 52.76% |
| Timing within 25% tolerance | 5.52% |
| Calculated serve speed, mean | 20.80 m/s |
| Legacy effective speed, mean | 15.73 m/s |
| Legacy duration, mean | 0.983 s |
| Implied duration, mean | 0.744 s |
| Relative duration error, mean | 32.26% |
| Selected receiver destination error, mean | 0.782 m |
| Selected receiver recognition delay, mean | 0.226 s |
| Selected receiver arrival margin, median | +0.015 s |

Only `topspin_serve` appeared because the current seeded opponent's legal server
uses that primary style. This run cannot support comparisons between serve
styles.

## Gate decision

Gate 1 is complete as an instrumentation and evidence gate. Live timing changes
are **not approved** yet. The calculated signature speed and legacy flight time
represent incompatible scales in most samples. Choosing either one as correct
without further calibration would be unsupported.

Before Gate 2 activates any behavior:

1. run controlled fixtures for every serve style;
2. decide whether contact speed or legacy duration is the primary balance input;
3. define acceptable timing bands by action type;
4. measure receiver reachability after each candidate calibration;
5. keep the current resolver authoritative until those distributions are
   reviewed.

## Known unrelated validation issue

The Godot test process still reports ObjectDB/resource cleanup warnings at exit.
All 214 assertions pass; the warnings remain unresolved and should not be
mistaken for Gate 1 timing failures.
