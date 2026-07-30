# Gate 6: Repeated In-Flight Reads

Date: 2026-07-30

## Question

Can a player update a serve estimate several times during flight, with later
observations becoming more accurate, without changing the live rally result?

## Implementation

`BallReadSystem.estimate_sequence()` samples one authoritative `BallFlight` at
12%, 32%, and 52% progress. All samples use the same seed. This keeps the
player's underlying error direction deterministic while accumulated information
reduces the error magnitude.

`ShadowReceptionSystem` records, for every eligible receiver:

- observation and decision time;
- perceived destination and arrival;
- recognition time, novelty, confidence, and error;
- stationary-position reachability at that observation;
- correction distance from the preceding estimate.

The 2D debug court draws the selected receiver's estimate sequence as an orange
correction trail. The developer text compares the existing single read with the
three-read candidate.

## Controlled result

Command:

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --repeated-reads --samples=120 --start-seed=60000
```

This is a game fixture, not real-world volleyball evidence.

| Measure | Result |
|---|---:|
| Requested samples | 600 |
| Eligible samples | 590 |
| Serve-error skips | 10 |
| Invalid traces | 0 |
| Single-read reachable | 72.54% |
| Repeated-read stationary reachable | 18.47% |
| Repeated-read claimant change | 0.85% |
| Destination-error delta, mean | -0.058 m |
| Confidence delta, mean | +0.045 |
| Total correction distance, mean | 0.078 m |

The selected-candidate error delta ranged from -0.208 m to +0.452 m, and the
confidence delta from -0.043 to +0.126. The rare inverse values occur when the
candidate identity changes; within one player's deterministic sequence, later
observations reduce error and increase confidence, which is covered by tests.

## Gate decision

Repeated perception is valid as shadow evidence. It is **not ready for live
selection**. Re-evaluating a late observation from an unchanged starting
position discards movement that should already be underway, producing the large
reachability drop above.

The next gate must project persistent movement between observations and let a
new read redirect that movement. Until then:

- the official legacy receiver remains unchanged;
- the canonical single-read shadow claimant remains unchanged;
- repeated-read reachability must be labelled stationary, not a live outcome.
