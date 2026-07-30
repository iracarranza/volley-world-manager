# Gate 30: Development Live Reception

Review date: 2026-07-30

Status: **PASS IN DEVELOPMENT FIXTURE; PRODUCTION OFF**

The debug fixture can explicitly promote opponent serve to home reception.
Promotion makes canonical serve timing and the audited reception authoritative,
then applies:

- simulation time;
- receiver center position and velocity;
- reaching or diving body state, balance, commitment, and recovery;
- reception ownership and contact count; and
- the outgoing pass trajectory in `RallyBallState`.

The calculated pass destination and duration feed the existing setter
continuation. Setter contact and every later phase remain legacy-controlled.
Equal seeds reproduce equal receiver ownership, quality, and trajectory.
Ordinary `resolve_active_rally(seed)` calls do not request promotion and remain
on official reception.

## Batch verification

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=120 --start-seed=300000 --live-reception-rollout
```

The batch promoted all 44 eligible candidates (36.67%), fell back on all 76
ineligible candidates, recorded zero integration failures, zero unexpected
selections, zero deterministic mismatches, and retained a legacy home-set
continuation after every promoted reception.
