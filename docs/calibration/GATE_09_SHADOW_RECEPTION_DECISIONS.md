# Gate 9: Shadow Reception Decisions and Contacts

Date: 2026-07-30

## Question

Can the simulator compare simultaneously open receiver windows, choose a
perceived action, and grade that action against ball truth without replacing the
official reception event?

## Implementation

Gate 9 adds `RallyDecision` and `RallyDecisionSystem`.

At the final scheduled read, the policy considers only receivers whose perceived
opportunity window remains open. It ranks them using:

- expected contact quality;
- confidence in the ball read;
- tactical responsibility priority;
- physical feasibility;
- arrival margin.

It reports ambiguity and teammate conflict when leading options are close. The
selected perceived action is then graded against the authoritative landing
position and arrival time. Perception can therefore produce a reasonable choice
that still fails against the true ball.

Possible contact choices currently include:

- `emergency_keep_alive`;
- `safe_center_pass`;
- `quick_release_pass`, available only with sufficient time, balance,
  confidence, ball control, and decision-making.

The resulting shadow contact records actor, action, quality, success, true
arrival margin, perception error, and intended outgoing target. It does not add
or replace a `RallyEvent`.

## Controlled result

Command:

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --shadow-decisions --samples=120 --start-seed=90000
```

This is a game fixture, not real-world volleyball evidence.

| Measure | Result |
|---|---:|
| Requested samples | 600 |
| Eligible samples | 595 |
| Serve-error skips | 5 |
| Invalid traces | 0 |
| Shadow decision made | 56.13% |
| Successful shadow contact, all eligible | 42.35% |
| Successful contact given decision | 75.45% |
| Teammate conflict | 1.34% |
| Legacy agreement given decision | 79.64% |
| Receiver options, mean | 0.575 |
| Contact choices, mean across all eligible | 1.123 |
| Contact quality, mean across all eligible | 0.407 |

All 334 shadow decisions selected `safe_center_pass`. Decision cases exposed two
contact choices (safe and emergency), but the default controlled fixture did not
unlock `quick_release_pass`.

## Gate decision

The decision/contact separation passes as a shadow architecture:

- perceived choices are ranked independently from physical truth;
- overlapping responsibility is measurable;
- contact failure can arise from true reach and perception error;
- official rally events remain unchanged.

It is not ready for live activation. The next gate must run controlled player
progression fixtures and verify that stronger reading, movement, control, and
decision attributes actually unlock more contact choices and better information.
The unobserved quick-release branch must not be presented as validated gameplay.
