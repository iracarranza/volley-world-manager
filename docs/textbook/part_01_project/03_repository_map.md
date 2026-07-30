# P1-C3 — Repository Map

Status: **VERIFIED**
Keywords: folders, architecture, models, systems, managers, scenes, tests
Primary sources: repository directory structure

## Top-level map

```text
project.godot              Godot configuration and runtime entry
scenes/                    scene trees and their UI controllers
scripts/data/              constants and reference data
scripts/models/            Resource-based data contracts
scripts/systems/           mostly stateless gameplay calculations
scripts/managers/          stateful coordinators and workflows
scripts/simulation/        rally, coverage, movement, and legality logic
scripts/tactics/           play validation and tactical demand
tests/                     headless automated checks
docs/textbook/             this learning resource
```

## Choosing where code belongs

Ask what the file owns:

- “What facts exist?” → model.
- “How is a value calculated?” → system or simulation.
- “What persists across screens or weeks?” → manager.
- “What is drawn, clicked, or displayed?” → scene/component.
- “What constant data is shared?” → data.

For example, reception reach belongs in simulation. Drawing a reception zone belongs in a scene component. The player's reception attribute belongs in a model. Applying a week of training belongs in a system coordinated by a manager.

## Coupling rule

A model should not need a UI Node to function. If `RallyState` imported a match screen and moved sprites, it would become impossible to test the simulation without opening the interface.

## Practical search commands

```bash
rg --files scripts scenes tests
rg -n "class_name RallyState" scripts
rg -n "func resolve_active_rally" scripts scenes
rg -n "outgoing_trajectory" scripts scenes tests
```

`rg` means ripgrep. The first command lists files; the others find exact text with file names and line numbers.
