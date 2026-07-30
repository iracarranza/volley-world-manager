# P4-C1 — Current Rally Pipeline

Status: **VERIFIED**
Keywords: RallySimulator, RallyEvent, RallyResult, event pipeline, live_positions, playback
Primary sources: `scripts/simulation/rally_simulator.gd`; `scripts/models/rally_event.gd`; `scripts/models/rally_result.gd`; `scenes/main/main.gd`

## What runs today

`RallySimulator.resolve()` initializes a seeded random generator, a rally clock, and home `live_positions`. It then follows branches for serve, reception, setting, attack, block, defense, and continuation. Each resolved action is recorded with `_add_event()`. `_finish()` adds the point outcome and final analysis.

The simulator performs meaningful spatial work:

- court positions are normalized;
- coverage selects claimants;
- movement time depends on distance and player ratings;
- passes produce destinations and trajectories;
- setters and hitters have arrival margins;
- blocking uses read, close, reach, and coverage;
- tactics and familiarity modify some decisions.

It is therefore not merely a random table.

## Its structural limitation

The function still knows the next volleyball phase in advance. It explicitly calls reception logic after serve, set logic after reception, and so on. `live_positions` is updated for some actors, but there is no single authoritative simulation loop that asks, at each future moment, “what actions are now possible from the complete state?”

That makes continuity fragile. A continuation branch can choose simplified locations or fallbacks that do not fully arise from the preceding ball state.

## Events are records, not state

`RallyEvent` records what playback needs. Its positions and metadata describe an action, but the list does not automatically answer where every non-acting player is at an arbitrary time.

`RallyResult` summarizes the completed rally. Neither model should be forced to become the authoritative physical simulation state.

## Playback boundary

`Main._play_rally()` consumes the event list for the 2D court. Playback should interpolate the resolved positions and trajectories. It should not reset players in a way that changes what the simulator believes happened.

3D match code may still be invoked elsewhere, but it is paused by current project direction.

## Current-versus-proposed comparison

| Current live resolver | Proposed persistent resolver |
|---|---|
| phase function chooses next phase | scheduler chooses next moment |
| selected actors update positions | all relevant actors carry state |
| events are created during branching | state resolution emits events afterward |
| availability is checked inside phase logic | opportunities are explicit values |
| tactical home may become a fallback position | tactical home is a movement intention |
