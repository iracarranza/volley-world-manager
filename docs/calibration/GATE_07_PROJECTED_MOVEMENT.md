# Gate 7: Projected Movement Between Reads

Date: 2026-07-30

## Question

Does carrying a receiver's temporary position and velocity between perception
updates repair Gate 6's false stationary penalty without changing live rallies?

## Implementation

`RallyMovementSystem.project_toward()` advances a copied
`RallyPlayerState` for a specified interval. It uses court meters, the player's
current velocity, facing, acceleration, lateral speed, mass, and fatigue. It
returns the projected snapshot and diagnostics; it does not mutate the source.

For repeated serve reads, the temporary receiver now:

1. waits until the first actionable read;
2. moves toward that perceived destination;
3. carries position and velocity to the next observation;
4. redirects toward the corrected destination;
5. evaluates the final reception opportunity from that projected state.

The 2D debug court draws the projected player path in mint and the perceived
ball-target correction path in orange.

## Controlled result

Command:

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --projected-movement --samples=120 --start-seed=70000
```

This is a game fixture, not a claim about measured real-world volleyball.

| Measure | Result |
|---|---:|
| Requested samples | 600 |
| Eligible samples | 585 |
| Serve-error skips | 15 |
| Invalid traces | 0 |
| Existing single-read reachable | 69.40% |
| Repeated-read stationary reachable | 12.65% |
| Repeated-read projected reachable | 55.90% |
| Projected claimant change | 3.59% |
| Projected distance, mean | 0.093 m |
| Arrival-margin gain versus stationary, mean | +0.246 s |
| Destination-error delta, mean | -0.057 m |
| Confidence delta, mean | +0.045 |

The projected movement distance ranged from 0.000 m to 0.343 m. Arrival-margin
gain ranged from -0.045 s to +0.423 s; a small negative value is possible when
carried velocity points away from a corrected target.

## Gate decision

The projection model passes as a shadow foundation:

- it restores most actions lost by the stationary late-read calculation;
- it carries movement history instead of restarting a player;
- it preserves the original player and official rally outcome;
- it produces deterministic, inspectable paths.

It does **not** replace live reception. The repeated-read candidate still trails
the existing single-read candidate, and projection currently covers only the
serve-receive interval. The next gate should schedule movement intents and
opportunity windows in `RallyState`, still shadow-only, so choices can open and
close over time rather than being recomputed as isolated snapshots.
