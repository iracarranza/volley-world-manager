# P2-C2 — Resources, Nodes, and Signals

Status: **VERIFIED**
Keywords: Resource, Node, scene, signal, model, UI separation
Primary sources: `scripts/models/rally_result.gd`; `scripts/managers/career_manager.gd`; `scenes/application.gd`

## Resource

A `Resource` is suited to structured game data. `RallyEvent`, `RallyResult`, players, lineups, plans, and the new rally-state objects are Resources. They can exist in headless tests without a visible scene.

Use a Resource when the central question is “what data and data-local behavior describe this thing?”

## Node

A `Node` lives in the scene tree. Nodes receive lifecycle callbacks, can display UI, process input, own children, and connect signals. Scene controller scripts therefore extend Node-derived classes such as `Control`.

Use a Node when the central question is “what participates in the running scene tree?”

## Signal

A signal announces that something happened:

```gdscript
signal week_advanced(report: Dictionary)
```

Another object connects a callback. The sender does not need to know every receiver. This keeps screens from becoming hard-wired to one another.

## Separation example

Correct direction:

```text
Button press → scene callback → CareerManager.advance_week()
                         ↓
             TrainingSystem.apply_week(...)
                         ↓
                 player Resources change
                         ↓
              manager emits a signal
                         ↓
                   UI refreshes
```

The training formula should not be hidden inside the button callback. The player Resource should not search for a label and change its text.

## Duplication warning

Resources are reference objects. Two variables can point to the same Resource. Before mutating a value that should be isolated, determine whether the caller expects shared state or a duplicate.
