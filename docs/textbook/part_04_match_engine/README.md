# Part 4 — The Match and Rally Engine

The substance of the project: how a rally is decided today, what is replacing
that, and how to change either without breaking the other.

This is the longest part, and the one where the **status labels matter most**.
Two rally models coexist — a live phase resolver and a partially built
persistent one — and confusing them is the most expensive mistake available in
this codebase.

1. [Current Rally Pipeline](01_current_rally_pipeline.md) — what actually runs,
   and the structural limit of a phase model
2. [Persistent Rally State](02_persistent_rally_state.md) — the models being
   built, and why tactical home is an intention
3. [Ball Time, Movement, and Actions](03_ball_time_movement_and_actions.md) —
   deadlines, opportunities, perception, and the continuity contract
4. [Tactics, Information, and Progression](04_tactics_information_and_progression.md)
   — capability gates, hidden truth, and instructions as preferences
5. [Migration Plan and Visible Proof](05_migration_and_visible_proof.md) — the
   slices, the audits, and what counts as evidence
6. [Adjusting and Extending Live Systems](06_adjusting_and_extending_live_systems.md)
   — practical recipes for the parts that are live now

## Prerequisites

- [Part 1](../part_01_project/README.md), [Part 2](../part_02_gdscript/README.md)
  and especially [Part 3](../part_03_workflow/README.md)

## The distinction to hold throughout

| | Decides | Records | Draws |
|---|---|---|---|
| `RallySimulator` | ✓ | | |
| `RallyEvent` / `RallyResult` | | ✓ | |
| Playback / 3D view | | | ✓ |

Every serious bug in this part is one of these three doing another's job.

## Where this leads

- [Part 5 — Career and Player Development](../part_05_management/README.md)
- [Part 7 — Art, 3D Assets and the Drawn World](../part_07_art_and_assets/README.md)
