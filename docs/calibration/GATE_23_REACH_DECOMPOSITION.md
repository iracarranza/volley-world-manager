# Gate 23: Reach Decomposition and Counterfactuals

Review date: 2026-07-30

Status: **SUPERSEDED BY GATE 24**

Gate 23 preserved the zero-reach baseline long enough to measure the missing
distance. Gate 24 replaces that temporary assumption with player-specific
contact envelopes while keeping the entire path shadow-only.

## Purpose

Separate timing, movement, target distance, and contact reach before changing
any balance constant. The shadow model still requires the player's center to
reach the exact contact point. `contact_reach_meters` therefore remains zero.

## Recorded fields

Every evaluated opportunity now records:

- available time and target distance;
- modeled movement capacity and remaining center-distance deficit;
- maximum speed, acceleration, and direction-change delay;
- modeled speed versus useful directional speed;
- contact reach, currently zero.

Receiver and setter traces also record initial distance, first-decision delay,
time remaining after recognition, and final true arrival margin.

## Reproduction

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=120 --start-seed=120000 \
  --all-serve-styles --setter-response --summary-only
```

## Measured decomposition

Across 585 eligible serves, the selected receiver had:

- 0.219 s mean first-decision delay;
- 0.626 s remaining after the first decision;
- 0.405 s remaining after the final read;
- 0.760 m final target distance;
- 0.327 m modeled final movement capacity;
- 0.487 m mean remaining center-distance deficit;
- 0.0 m contact reach.

Across 83 outgoing passes, the selected setter had:

- 0.293 s remaining after the final read;
- 1.184 m final target distance;
- 0.764 m modeled final movement capacity;
- 0.466 m mean remaining center-distance deficit;
- 0.0 m contact reach.

The review found that `estimate_movement()` credited total velocity as forward
velocity. It now uses the velocity component aimed toward the new target. The
diagnostic records the discarded sideways/opposite component: 0.188 m/s for
receivers and 0.472 m/s for setters on average. This correction reduced shadow
outgoing-pass availability to 10.1% and setter reachability to 22.0%, exposing
the stricter truthful baseline before balance tuning.

## Read-only counterfactuals

| Added contact reach | Receiver reach | Setter reach |
|---:|---:|---:|
| 0.00 m | 20.7% | 22.0% |
| 0.30 m | 48.4% | 40.7% |
| 0.60 m | 82.7% | 66.1% |
| 0.90 m | 88.4% | 78.3% |
| 1.20 m | 88.9% | 100% |

| Added time | Receiver reach | Setter reach |
|---:|---:|---:|
| 0.00 s | 20.7% | 22.0% |
| 0.05 s | 28.0% | 28.8% |
| 0.10 s | 34.0% | 44.1% |
| 0.15 s | 45.6% | 57.6% |
| 0.20 s | 56.8% | 66.1% |

These tables do not alter reachability. They show that a conservative 0.30 m
contact allowance approaches 40–50% without inflating player speed, while a
0.60 m universal allowance would make reception dramatically easier. The next
decision should define action- and body-state-specific contact reach rather
than applying a universal movement bonus.
