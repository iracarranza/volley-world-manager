# Gate 42: Development Live Attack

Review date: 2026-07-30

Status: **PASS IN DEVELOPMENT FIXTURE; PRODUCTION OFF**

After promoted reception and setter contacts, the development fixture may
promote one audited attack. Promotion applies the setter's perceived hitter
choice, the hitter's repeated set reads, approach movement, resolved center and
velocity, body state, balance, third contact, recovery, perceived shot target,
and outgoing attack trajectory to persistent rally state.

Blocking, floor defense, and every later phase remain legacy-controlled. Equal
seeds reproduce equal hitter ownership, action, contact time, contact position,
and target. Ordinary match resolution never requests attack promotion.

## Batch verification

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=120 --start-seed=300450 --live-attack-rollout
```

The natural-lineup batch promoted the one candidate that passed all three
contact audits (seed 300469), fell back on the other 119, and recorded zero
unexpected selections, integration failures, or deterministic mismatches. The
legacy opponent block followed the promoted attack. Compounded eligibility is
kept visible rather than inflated with global movement or reach bonuses.
