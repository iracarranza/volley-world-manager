# Gate 20: Canonical Serve Timing

Review date: 2026-07-30

Status: **PASS WITH BALANCE OBSERVATION; SHADOW ONLY**

## Question

When calculated serve speed and a legacy animation duration disagree, which
value controls the shadow rally clock?

## Current contract

`ShadowReceptionSystem` treats the calculated `BallContactSignature.speed_mps`
as authoritative. `RallyKinematics.flight_duration()` derives flight duration
from court distance, path factor, and that speed. The resulting `BallFlight`
is the truth used for reads, movement, opportunities, and selection.

The legacy recorded duration is retained only as comparison evidence. It does
not silently replace the calculated speed.

Search keys:

- `calculated_speed_derived_duration`
- `canonical_timing_diagnostics`
- `legacy_timing_consistency_rate`
- `canonical_timing_consistency_rate`

## Reproduction

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=120 --start-seed=120000 \
  --all-serve-styles --setter-response --summary-only
```

The 600-fixture run produced 585 eligible serves and zero malformed samples.
Canonical speed/duration consistency passed. Only 83 serves (14.19%) produced
a successful outgoing shadow pass, and the report warned that the selected
receiver was late on more than half the measured serves.

## Interpretation

The timing contract is repaired. The low pass rate is an exposed balance
result, not a parser or metadata error. Adjusting receiver preparation and
reach is deliberately deferred so those values can be calibrated with the
developer rather than disguised by two competing clocks.

Official rally events and outcomes remain unchanged.
