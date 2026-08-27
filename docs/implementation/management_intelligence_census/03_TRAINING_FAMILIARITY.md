# Training and Familiarity — Design to Implementation

## Settled design split

`TACTICS_AND_TRAINING.md` defines three different kinds of state:

- **Ratings** — capability; attribute training changes them.
- **Natural system-fit bands** — currently derived from ratings.
- **Learned preferences** — coordinates, tempos, loci, courses and block posture comfort; match training should change these.

The desired arithmetic is:

`effective comfort band = natural rating-derived band + learned training offset`

This separation is load-bearing. Training a system must not secretly increase underlying volleyball ability.

## Current implementation

### Attribute/position training — LIVE

`VolleyballPlayer` stores per-attribute training progress and position familiarity. `VolleyballFamiliaritySystem.train_position()` changes position familiarity with adaptability, positional similarity and suitability, and adds fatigue.

### Situation learning — LIVE

`situation_experience` plus `record_exposure()` represents learning from encountered volleyball situations.

### Match training / learned tactical preferences — ABSENT

The design record explicitly says no learned-preference state distinct from ratings currently exists. The match-training tab is/was a second route into attribute training rather than the intended system.

### Tactical planner — PARTIAL

The planner can express some declared tactical state, but the key designed function is missing: presets must decompose into concrete asks in the same space as learned preferences, then those asks must be scored against squad comfort.

## Natural grain

Do not create one universal `tactical_familiarity` field. The design already establishes that each trainable has a natural owner:

| Trainable | Natural grain |
|---|---|
| Hitting coordinate | per Voli, per lane |
| Tempo comfort | per hitter–setter relationship |
| Dig loci/courses | per rotation slot |
| Block posture | per blocking pair |

The implementation should preserve these different grains while avoiding combinatorial matrices where a base value + relationship modifier can express the same fiction.

## Play Designer integration

`TRAINING_PLAY_DESIGNER.md` adds a visual authoring surface, not a new state system.

A drawn demonstration must decompose into the same underlying asks described above. The looped ball animation is explanatory. It must not own trajectories, contacts, or deterministic future choices.

The highest-value future seam is therefore **not drawing paths**. It is implementing the learned-preference state and decomposition contract that a drawing can safely write.

## Match-learned drift

The design explicitly wants successful match behavior to share a channel with drilled preference where appropriate. A hitter repeatedly succeeding from a coordinate the manager did not request may drift toward it; the manager can later encourage or revert that learning.

This is not live as a complete training loop. `HitterPlacementModel.placement_memory` is cited by the design as the precedent, not proof that the manager-facing learned-preference model exists.

## Recommended implementation sequence

1. Define learned-preference data with explicit natural grain.
2. Layer learned offsets over rating-derived system-fit rather than replacing ratings.
3. Define preset -> concrete asks decomposition.
4. Define comfort/fit score per ask, not one opaque tactic number.
5. Make match training write the same learned-preference channels.
6. Connect match-earned placement/behavior drift deliberately where semantically identical.
7. Only then build Play Designer input over those channels.
8. Add designed-vs-observed route visualization after actual practice execution exists.

This sequence prevents an attractive drawing interface from becoming a second tactical authority.