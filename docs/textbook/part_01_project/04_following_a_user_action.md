# P1-C4 — Following “Resolve Rally”

Status: **VERIFIED**
Keywords: call path, resolve rally, event playback, GameManager, RallySimulator
Primary sources: `scenes/main/main.gd`; `scripts/managers/game_manager.gd`; `scripts/simulation/rally_simulator.gd`

## The call path

The central path is:

```text
user activates rally control
    ↓
Main._resolve_rally()
    ↓
GameManager.resolve_active_rally(seed)
    ↓
RallySimulator.resolve(...)
    ↓
RallyResult containing RallyEvent resources
    ↓
Main._play_rally(result, ...)
    ↓
2D tactical court playback and result recording
```

This trace tells you where a change belongs. A wrong outcome begins in simulation. A correct outcome drawn incorrectly is a playback problem. A missing player or plan may originate in GameManager state.

## Simulation contract

`RallySimulator.resolve` accepts players, lineup, active offensive play, opponent team, defensive plan, serving side, and seed. It returns a Resource used as a `RallyResult`.

The result contains events. Each event contains an actor, event type, start/end positions, success, quality, text, and metadata. Playback depends especially on exact metadata contracts such as `outgoing_trajectory`.

## Why this matters

Changing playback to “fix” a simulation error can make the screen look right while analysis and results remain wrong. Changing simulation to “fix” a drawing transform can corrupt correct outcomes. Always identify which side of the contract failed.

## Exercise

Search for `_resolve_rally`, `resolve_active_rally`, `func resolve(`, and `_play_rally`. Write the file name of each result. If the chain differs from this chapter, update the chapter and evidence ledger.
