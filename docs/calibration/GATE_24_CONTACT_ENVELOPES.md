# Gate 24: Player Contact Envelopes and Vertical Setting

Review date: 2026-07-30

Status: **SHADOW PASS; OFFICIAL RALLY PATH UNCHANGED**

## Question

Can existing physical generation define horizontal and vertical contact access
without turning playback geometry into gameplay physics, and can setter growth
create standing- and jump-set options rather than only increasing quality?

## Contract

- `BallFlight.contact_height_meters` is authoritative calculated contact
  height at the destination. Playback apex values are never gameplay inputs.
- `ContactEnvelopeSystem` derives standing reach from height and wingspan.
- Wingspan, action, body state, balance, and stability define horizontal reach.
- Jump reach defines potential displacement. Explosiveness, readiness, fatigue,
  and time determine how much is available now.
- Jumping reserves takeoff time, reduces the time left for lateral travel, and
  records recovery time.
- Set accuracy, hand control, tempo control, set balance, and set stability
  determine execution after physical access.

All numeric mappings in `ContactEnvelopeSystem` are game-balance parameters.
They are not presented as measured biomechanics.

## Procedural bodies

Generated players now receive seeded correlated variation in height, mass, and
wingspan around their role template. Equal seeds reproduce equal bodies. The
model does not add a redundant `arm_reach_cm` field; `standing_reach_cm()` and
the contact-envelope calculation derive usable reach from existing dimensions.

## Paired fixture

Command:

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --samples=40 --start-seed=240000 \
  --setter-progression --summary-only
```

The fixture held serves and outgoing passes identical across developing,
established, and elite setter tiers. It produced 129 available responses per
tier with zero invalid samples and zero outgoing-flight mismatches.

| Setter tier | Reachable | Mean actions | Standing set | Jump set |
|---|---:|---:|---:|---:|
| Developing | 0.0% | 0.016 | 0.0% | 0.0% |
| Established | 2.3% | 0.279 | 3.1% | 7.8% |
| Elite | 28.7% | 1.341 | 11.6% | 37.2% |

Confidence, reachability, action count, controlled-set rate, and jump-set rate
were all nondecreasing. This verifies the design goal in shadow mode: improved
setters perceive more accurately and gain additional executable actions.

## Verification

The headless foundation suite passes 292 checks, including:

- authoritative contact-height serialization and perception;
- wingspan effects on lateral and overhead reach;
- standing versus jump set access;
- takeoff and recovery costs;
- explosiveness and jump-reach effects under a short deadline;
- balance, stability, and hand-control effects on execution quality;
- deterministic individualized procedural bodies; and
- unchanged official-event ownership through the disabled rollout boundary.

The next gate should tune the low developing-setter availability only after
reviewing visible shadow overlays. It must not compensate by inflating global
movement speed or by reading visual trajectory apex as simulation truth.
