# Gate 22: Setter Development and Available Actions

Review date: 2026-07-30

Status: **PASS; SHADOW ONLY**

## Purpose

Prove that setter development gives the player more information and more
usable second-contact actions, rather than merely increasing a hidden success
percentage.

## Paired-fixture rule

The legal server, serve style, seed, receiver, receive formation, player body,
fatigue, pass origin, pass destination, and pass duration are held fixed.
Only attributes used to read, reach, and control second contact vary:

- anticipation, court vision, decision making, and composure;
- acceleration and transition speed;
- set accuracy, ball control, tempo control, and tactical discipline.

The tiers are developing (40), established (65), and elite (90).

## Reproduction

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=8 --start-seed=220000 --setter-progression
```

## Measured result

The paired outgoing-flight mismatch count was zero. Each tier had the same 11
usable passes.

| Tier | Confidence | Reachable | Mean actions | Controlled set | Quick set |
|---|---:|---:|---:|---:|---:|
| Developing | 0.465 | 0% | 0.73 | 0% | 0% |
| Established | 0.568 | 9.1% | 1.09 | 9.1% | 0% |
| Elite | 0.670 | 45.5% | 2.82 | 90.9% | 90.9% |

All measured progression checks were nondecreasing, and elite setters had
strictly more actions than developing setters. This gate demonstrates the
design goal directly: improvement exposes controlled and quick-tempo choices.
It does not tune the reachability threshold reserved for later collaboration.
