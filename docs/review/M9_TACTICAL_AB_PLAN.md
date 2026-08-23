# M9 tactical A/B certification

Status: **next rally milestone; measurement plan**

M8 structurally certifies one canonical side-out. M9 asks a different question:

> When the manager changes an instruction while roster, rotation, seed and all unrelated state are held constant, does the rally change first in the intended decision / actor state / physical geometry — and only then in downstream outcomes?

This is **not** a balance pass. Point rate, kill rate, ace rate and tactical win rate are observations unless an existing authority explicitly supplies a bound.

## Certification chain

For each A/B pair:

```text
manager call
→ interpreted decision / target
→ actor movement or contact geometry
→ realised ball / next situation
→ outcome (observe only)
```

A tactic does not pass M9 merely because a coefficient or terminal percentage changes. It should produce a volleyball-literate difference that could in principle be seen with outcome labels hidden.

## Controlled fixture rules

- same hand-authored vertical-slice roster;
- same rotation;
- same serving side;
- same seed for A and B;
- one tactical field changed at a time;
- search seeds by a stated event-shape rule when a particular contact is required; never select a seed because one variant wins;
- read resolver-published positions, intents, decisions and trajectories; never reconstruct a tactical effect from presentation;
- no new tuning magnitude and no gate widening.

## M9-A — spatial instructions first

These already have explicit manager-facing state and direct physical/geometry consumers, so they can be certified without inventing policy.

### A1 Serve target: Zone 5 ↔ Zone 1

Hold server, seed and risk constant.

Expected chain:

```text
DefensivePlan.serve_target
→ SERVE.called_target / selected target / aim_point
→ authoritative serve flight
→ realised landing / receiver situation
```

Gate the instruction and intermediate aim direction. Observe landing and reception differences. Do not gate ace rate.

### A2 Defensive depth: Shallow ↔ Deep

Use a seed where the opponent reaches an attack and the home side publishes its defensive shape.

Expected chain:

```text
DefensivePlan.defensive_depth
→ _floor_phase_positions
→ _establish_shape traversal
→ home_phase_targets + home_phase_intents
→ realised defender body state before the attack/dig
```

Deep should move the intended home defensive shape farther from the net than Shallow. The important fact is that M7 movement authority traverses toward the changed shape rather than the plan teleporting bodies into it.

### A3 Block/defence relationship: Defend Line ↔ Defend Cross

Use the same opponent attack in both variants.

Expected chain:

```text
DefensivePlan.block_defense_relationship
→ defensive coverage focus
→ floor target x distribution
→ if the block touches/funnels: deflection target
→ realised floor problem
```

The first gate is changed defensive geometry. A touched-ball comparison is a second fixture because not every matched seed contains a block touch.

## M9-B — intent/action instructions

After M9-A establishes the spatial pipeline, certify instructions whose effect depends on a decision or contact opportunity rather than a guaranteed coordinate shift.

### B1 Block intent: Seal ↔ Funnel

Existing authority already distinguishes the intent bands and publishes `block_intent`; current code also contains a downstream defensive read of funnel intent. Certify with a seed searched for a genuine block interaction.

Do not require one variant to win. Require:

- the called intent reaches the block contest;
- the contact classification / wall shaping can differ for the same physical opportunity;
- a funnelled/touched ball hands a materially different realised problem to floor defence rather than adding a hidden dig-quality bonus.

### B2 Block hands instruction

`TacticSheet` now reaches the home block through the per-slot Block behaviour and the block event publishes call/followed/realised hands. Certify instruction → judgement → realised hand intent on a controlled block opportunity. A voli may refuse/fail to follow the instruction; that is part of the system, not a failed tactic pipeline.

## M9-C — offensive decision instructions

Only after identifying which current manager-facing offensive controls are production authority. Do not treat team identity/principle coefficients as substitutes for a tactical instruction merely because they move attack rates.

Candidate questions include setter release location, called play / hitter allocation, and tempo/lane instructions. Each needs the same call → interpretation → movement/decision → ball chain.

## Exit condition

M9 is complete when representative manager instructions from serve, block/floor defence and offence have deterministic A/B fixtures proving that the instruction changes the intended causal pathway before outcomes, and when any instruction exposed in the manager UI but inert in the production resolver is either connected or explicitly logged as non-production debt.

The next implementation instrument should begin with M9-A because it can be read-only and should expose whether the current plan fields still reach authoritative state after the M6/M7 consolidation.
