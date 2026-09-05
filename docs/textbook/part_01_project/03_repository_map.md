# P1-C3 — Repository Map

Status: **VERIFIED**
Keywords: folders, architecture, models, systems, managers, simulation, domain, tools, docs, coupling
Primary sources: repository directory structure; `docs/DESIGN_AUTHORITY_INDEX.md`

## Prerequisites

- [P1-C2 Godot Project and Runtime](02_godot_project_and_runtime.md) — the four architectural layers

## Learning goals

After this chapter you should be able to:

1. name every top-level directory and what it owns;
2. decide where a new file belongs, using a test rather than a hunch;
3. explain the coupling rule and what it protects;
4. find any symbol quickly;
5. know which `docs/` subdirectory answers which kind of question.

## Vocabulary

| Term | Meaning |
|---|---|
| **Domain** | Shared vocabulary both simulation and presentation read — attributes, body types. |
| **Tool** | A script under `tools/`: a probe, a validator or a render harness. Not shipped. |
| **Artifact** | A committed output — a rendered sheet, a proof image. |
| **Coupling** | Whether one file needs another to exist in order to function. |
| **Design record** | A document under `docs/design/` explaining *why* a system is shaped as it is. |

## 1. Top-level map

```text
project.godot              Godot configuration and runtime entry
scenes/                    scene trees and their controllers
  components/  (105)       reusable widgets, actors, drawn treatments
  screens/     (37)        full-screen interfaces
  themes/      (9)         .tres theme resources
  main/        (3)         the match host scene
scripts/
  simulation/  (84)        rally, coverage, movement, legality, biomechanics
  data/        (53)        constants and authored reference data
  models/      (37)        Resource-based data contracts
  systems/     (14)        mostly stateless gameplay calculations
  domain/      (4)         shared vocabulary: attributes, body types
  managers/    (2)         stateful coordinators; the two autoloads
  tactics/     (2)         play validation and tactical demand
  world/       (1)         world generation entry
tools/         (296 .gd,   probes, validators and render harnesses
				59 .tscn)  — not shipped, but not throwaway either
tests/                     headless automated checks
artifacts/                 committed rendered outputs and proofs
assets/                    fonts, VFX sources
docs/                      design records, reviews, calibration, this book
```

> **Correction worth noting.** An earlier version of this map described `tools/`
> as "throwaway scenes for looking at a change." It is nothing of the kind:
> **296 scripts and 59 scene harnesses**, several of which are preloaded by
> runtime code because they own reviewed geometry. Treat `tools/` as a
> first-class part of the project. See
> [P7-C5](../part_07_art_and_assets/05_rendering_probes_and_validation.md).

## 2. The `docs/` subdirectories

Knowing which one to open saves more time than any search:

| Directory | Answers |
|---|---|
| `docs/design/` | *Why is this system shaped this way?* |
| `docs/review/` | *What was measured, and what did an earlier version get wrong?* |
| `docs/calibration/` | *What did the numbered gates prove?* |
| `docs/architecture/` | *How do the large pieces fit together?* |
| `docs/implementation/` | *How was a specific slice built?* |
| `docs/simulation/` | *What are the rally's own rules?* |
| `docs/world/` | *Setting, regions, naming.* |
| `docs/textbook/` | *How do I learn all of this?* — this book |

Two files at the root of `docs/` are worth knowing by name:
**`FAILURE_MODES.md`**, which records mistakes actually made here, and
**`BACKLOG.md`**, which records what is designed but unbuilt.

## 3. Where the interface lives

Presentation is deliberately split three ways, and knowing which of the three a
change belongs in is most of the work:

```text
scripts/data/ui_palette.gd          colour tokens, one source of truth
scripts/systems/ui_style_system.gd  decides what every Control *is* (its tier)
scenes/components/*.gd              draws the treatments a tier implies
scenes/themes/*.tres                padding, fonts, colours copied from the palette
```

### 3.1 The four files a visual change could belong in

The table above is the decision. Most mistakes here are putting a colour in a
theme resource (where it becomes a second source of truth) instead of in
`ui_palette.gd`.

### 3.2 The treatments, and why you cannot find them

The drawn components include `ink_outline.gd` (the sewn seam and the nib, plus
the highlighter), `tape_measure.gd` (the section menu), `paper_window.gd`
(scroll regions), `paper_tabs.gd` (tab rows) and `star_sticker.gd`.

**None of them is referenced from a `.tscn`.** The style pass adds them as
children at runtime, so a new screen gets the treatment without knowing they
exist. This is the single most surprising fact about the interface layer, and it
is why searching a scene file for a border you can see will find nothing. See
[`UI_VISUAL_SYSTEM.md`](../../design/UI_VISUAL_SYSTEM.md).

## 4. Choosing where code belongs

Ask what the file owns:

- "What facts exist?" → **model**
- "How is a value calculated?" → **system** or **simulation**
- "What persists across screens or weeks?" → **manager**
- "What is drawn, clicked, or displayed?" → **scene / component**
- "What constant data is shared?" → **data**
- "What vocabulary do several layers share?" → **domain**

### 4.1 Worked example: a new "fatigue resistance" concept

Four pieces, four homes:

1. The **attribute name** joins the shared vocabulary → `scripts/domain/attribute_registry.gd`.
2. The **per-region baseline** is authored data → `scripts/data/`.
3. The **effect on a rally** is a calculation → `scripts/simulation/`.
4. The **display on a page** is presentation → `scenes/components/`.

Putting all four in one file is the most common structural mistake in this
codebase, and it is invisible until someone needs one piece without the others.

### 4.2 The `domain/` test

`scripts/domain/` is small (4 files) and should stay small. A file belongs there
only if **both** simulation and presentation must agree about it.
`body_type_gameplay.gd` qualifies: the simulator reads the metrics and the
renderer reads the type list. A colour does not qualify — nothing in the
simulation reads it.

## 5. The coupling rule

> A model should not need a UI Node to function.

If `RallyState` imported a match screen and moved sprites, it would become
impossible to test the simulation without opening the interface. Every headless
check in `tests/` depends on this rule holding.

The rule has a direction. Presentation may read simulation; **simulation must
not read presentation.** When you find yourself wanting to break it, you have
usually discovered that a value is on the wrong side of the line — see
`RegionalKits`, which exists precisely so kit colours are *not* on `regions.gd`.

## 6. Practical search commands

```bash
rg --files scripts scenes tests          # list files
rg -n "class_name RallyState" scripts    # find a definition
rg -n "func resolve_active_rally" scripts scenes
rg -n "outgoing_trajectory" scripts scenes tests
```

### 6.1 Two habits worth forming

`rg` is ripgrep.

- **Search for the definition, not the mention.** `class_name X` and `func X`
  find one line each; the bare name finds fifty.
- **Include `tests/`.** A test often documents intended behaviour more precisely
  than the implementation does.

## 7. Common mistakes

**Putting authored data in a simulation file.** It makes the numbers
unreviewable and the file long.

**Growing `scripts/managers/`.** Two autoloads is the design.

**Adding to `scripts/domain/` for convenience.** Both sides must need it.

**Treating `tools/` as scratch.** Runtime code preloads some of it.

**Searching a `.tscn` for a runtime-added component.** It is not there.

## 8. Check yourself

1. A new formula for block timing. Where? *(`scripts/simulation/`.)*
2. A table of region names and taglines. Where? *(`scripts/data/`.)*
3. Why can't `RallyState` reference a screen? *(Headless tests could not run.)*
4. You cannot find the code drawing a page's border in its `.tscn`. Why? *(The style pass adds treatments at runtime.)*
5. Which `docs/` subdirectory records what an earlier version got wrong? *(`docs/review/`.)*

## Where this leads

- [P1-C4 Following a User Action](04_following_a_user_action.md) — these layers in motion
- [P3-C1 Safe Change Workflow](../part_03_workflow/01_safe_change_workflow.md) — how to change one safely
- [P7-C5 Rendering, Probes and Validation](../part_07_art_and_assets/05_rendering_probes_and_validation.md) — what `tools/` actually contains
