# Gate 4 Review: Reader Development and Receive Formations

Review date: 2026-07-29

Status: **CONTROLLED FIXTURE PASSED; SHADOW-ONLY**

Gate 4 tests whether player information attributes and tactical starting
positions create distinct reception options. It does not change the official
receiver, reception quality, or rally outcome.

## Controlled variables

The fixture compares three reader profiles:

- weak: 40 anticipation, court vision, decision-making, and composure;
- average: 65 in those four attributes;
- elite: 90 in those four attributes.

Reception technique, movement attributes, fatigue, serve proficiency, and
paired seeds remain fixed. Situation experience is cleared so learned
familiarity does not obscure the reader comparison.

Three serve-receive formations are tested:

- standard;
- compressed middle;
- split deep.

Every reader/formation cell receives all five supported serve styles.

## Reproduction command

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --reader-formations --samples=40 --start-seed=40000
```

The run produced 1,800 complete shadow receptions with zero malformed samples.

## Player-development result

| Reader tier | Destination error | Recognition delay | Confidence | Reachable |
|---|---:|---:|---:|---:|
| Weak | 0.781 m | 0.258 s | 0.412 | 43.17% |
| Average | 0.654 m | 0.191 s | 0.516 | 57.17% |
| Elite | 0.528 m | 0.123 s | 0.619 | 71.50% |

Destination error and recognition delay improve monotonically. Better readers
therefore receive more accurate information earlier, and that information
creates more reachable actions rather than only increasing a hidden success
percentage.

## Formation result

| Formation | Reachable | Official/shadow claimant agreement |
|---|---:|---:|
| Standard | 73.67% | 27.33% |
| Compressed middle | 58.83% | 53.83% |
| Split deep | 39.33% | 63.50% |

Formation produces a 34.33-percentage-point reachability spread. Starting
position therefore materially changes available actions.

Official/shadow agreement is diagnostic only. The official claimant is not a
ground-truth label, and lower agreement is not automatically worse. In
particular, improved readers may rank opportunities differently because the
legacy claimant model does not use the same perception evidence.

## Decision

The fixture supports proceeding to canonical derived-speed shadow reception and
repeated in-flight reads. It also identifies a future player-facing benefit:
training information attributes can visibly produce earlier movement, better
target corrections, and additional reachable reception choices.

Before live behavior changes:

1. use derived speed as the shadow reception signature;
2. evaluate multiple observation moments during one flight;
3. update player intent from each new estimate without resetting position;
4. resolve and compare the resulting contact quality;
5. retain a disabled feature flag until playback and balance checks pass.

These measurements describe this controlled game fixture, not real-world
volleyball performance standards.
