# Gate 8: Scheduled Opportunity Windows

Date: 2026-07-30

## Question

Can projected reads create explicit periods when reception is available—and
show when that option closes—inside an isolated shadow rally state?

## Implementation

Gate 8 adds `ActionOpportunityWindow` and `RallyOpportunitySystem`.

For each eligible receiver, the system:

1. snapshots `RallyState` and its player and ball states;
2. schedules the three perception moments and the ball-arrival deadline;
3. advances only the snapshot through those moments;
4. updates the receiver's projected position, velocity, and receive intent;
5. opens a window when the projected action becomes reachable;
6. closes it when a later correction makes the action late or the ball arrives.

Each window records its opening and closing reason, duration, best arrival
margin, and supporting read samples. The source-state position, velocity, and
clock are checked after scheduling to verify isolation.

The 2D developer overlay draws green rings where a window opens and red rings
where it closes. The inspector reports window count, total open time, intent
corrections, and early closure.

## Controlled result

Command:

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --opportunity-windows --samples=120 --start-seed=80000
```

This is a game fixture, not real-world volleyball evidence.

| Measure | Result |
|---|---:|
| Requested samples | 600 |
| Eligible samples | 585 |
| Serve-error skips | 15 |
| Invalid traces | 0 |
| A receive window opened | 65.98% |
| Window closed before contact | 14.53% |
| Reachable on final projected read | 51.45% |
| Projected claimant changed | 2.91% |
| Window count, mean | 0.660 |
| Total open duration, mean | 0.471 s |
| Intent corrections | 2 per eligible receiver |

Among all eligible samples, the median total open duration was 0.744 s and the
maximum was 1.052 s. Zero-duration samples are receivers whose window never
opened.

## Gate decision

The scheduled-window foundation passes in shadow mode. It demonstrates a fact
the legacy resolver cannot express: an action may be available after an early
read but disappear after later information changes movement requirements.

It is not ready to choose the official receiver. The next gate needs a decision
policy that compares simultaneously open windows, tactical responsibility,
confidence, expected contact quality, and conflict between teammates. That
policy should select a shadow action and produce a shadow reception contact,
while the legacy event remains authoritative.
