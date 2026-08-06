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
tools/preview/             throwaway scenes for looking at a change
tests/                     headless automated checks
docs/textbook/             this learning resource
docs/design/               design records for systems that were reasoned about
```

## Where the interface lives

Presentation is deliberately split three ways, and knowing which of the three a
change belongs in is most of the work:

```text
scripts/data/ui_palette.gd          colour tokens, one source of truth
scripts/systems/ui_style_system.gd  decides what every Control *is* (its tier)
scenes/components/*.gd              draws the treatments a tier implies
scenes/themes/*.tres                padding, fonts, colours copied from the palette
```

The drawn components are `ink_outline.gd` (the sewn seam and the nib, plus the
highlighter), `tape_measure.gd` (the section menu), `paper_window.gd` (scroll
regions), `paper_tabs.gd` (tab rows) and `star_sticker.gd`. None of them is
referenced from a `.tscn` — the style pass adds them as children at runtime, so
a new screen gets the treatment without knowing they exist. See
[UI_VISUAL_SYSTEM.md](../../design/UI_VISUAL_SYSTEM.md).

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
