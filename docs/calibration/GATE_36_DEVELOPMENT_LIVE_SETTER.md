# Gate 36: Development Live Setter

Review date: 2026-07-30

Status: **PASS IN DEVELOPMENT FIXTURE; PRODUCTION OFF**

After an audited live reception, the development fixture may promote one
audited setter contact. Promotion applies the selected owner, resolved center
position and velocity, body state, balance, recovery, simulation time, second
contact count, and outgoing set trajectory to persistent rally state.

Set destination, quality, hitter choice, attack, and every later phase remain
legacy-controlled. Equal seeds reproduce equal owner, action, contact position,
contact time, and observation fingerprint. Ordinary match resolution never
requests this promotion.

## Batch verification

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=120 --start-seed=300000 --live-setter-rollout
```

The natural-lineup batch promoted all 3 eligible candidates (2.50%), fell back
on all 117 ineligible candidates, recorded zero unexpected selections, zero
integration failures, zero deterministic mismatches, and retained a legacy
home attack after every promotion. All 44 observed setter responses passed the
observation-boundary check. Low natural eligibility remains visible rather than
being hidden with a universal movement or reach increase.
