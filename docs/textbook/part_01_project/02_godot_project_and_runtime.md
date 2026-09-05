# P1-C2 — Godot Project and Runtime

Status: **VERIFIED**
Keywords: project.godot, main scene, Autoload, scene tree, runtime, gl_compatibility, layering, runtime trace
Primary sources: `project.godot`; `scenes/application.tscn`; `scenes/application.gd`; `scripts/managers/game_manager.gd`; `scripts/managers/career_manager.gd`

## Prerequisites

- [P1-C1 What You Are Building](01_what_you_are_building.md) — the product this runtime serves

## Learning goals

After this chapter you should be able to:

1. read `project.godot` and name the entry point, the autoloads and the renderer;
2. explain what an **Autoload** is and why global access is not permission;
3. place a new piece of code in the correct architectural layer;
4. trace from a visible screen to the code that runs, without guessing.

## Vocabulary

| Term | Meaning |
|---|---|
| **Main scene** | The first scene Godot instantiates, set by `run/main_scene`. |
| **Autoload** | A script or scene created once at startup and reachable globally by name. |
| **Scene tree** | The live tree of nodes. Godot runs by walking it. |
| **`gl_compatibility`** | The rendering backend this project uses. |
| **Layer** | One of model / system / manager / scene, each with a different job. |
| **Runtime trace** | Following an actual call path instead of searching for a plausible function name. |

## 1. The project file

`project.godot` is the central configuration file. The lines that matter most:

```ini
config_version=5

[application]
config/name="Volley World Manager"
run/main_scene="res://scenes/application.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]
GameManager="*res://scripts/managers/game_manager.gd"
CareerManager="*res://scripts/managers/career_manager.gd"

[rendering]
renderer/rendering_method="gl_compatibility"
```

Four things to take from this:

- **The engine version is pinned by feature tag** — `"4.7"`. CI installs
  **4.7.2** specifically. Opening the project in an older Godot will not work
  cleanly.
- **The entry point is `scenes/application.tscn`.**
- **There are exactly two autoloads.** Two, not twelve — see §3.
- **The renderer is `gl_compatibility`.** This is why visual probes are run with
  `--rendering-method gl_compatibility`; it makes the tool match the game.

> Do not edit generated files inside `.godot/`. Godot recreates them. If that
> directory seems wrong, run `godot --headless --path . --import`.

## 2. The main scene is a navigation container

`scenes/application.gd` decides which full-screen interface is visible. Its
switching functions include `_show_title`, `_show_new_career`, `_show_journal`,
`_show_desk`, `_show_lock_in`, `_show_accommodation`, `_show_kitchen`,
`_show_encyclopedia` and `_show_match`, all routed through one `_show_only()`.

> **Names are load-bearing here.** There is no `_show_dashboard`. "Career
> dashboard" and "recruitment" are **dead names** — the manager's working
> knowledge lives in the *journal*. If you find either word in code or in a
> chapter, it is a leftover and should be corrected. See the names table in
> `CLAUDE.md`.

The application scene coordinates screens. **It must not contain volleyball
probability formulas.** A calculation that ends up here is unreachable from a
headless test, because reaching it requires a visible interface.

## 3. Autoloads: global access is not permission

`GameManager` and `CareerManager` are globally available because they are
configured as Autoloads. That is convenient and it is a trap: the easiest place
to put anything is the place everything can already see.

Use this separation:

| Layer | Owns | Example |
|---|---|---|
| **models** | facts | `VolleyballPlayer`, `RallyEvent` |
| **systems / simulation** | calculations | `CoverageCalculator`, `RallyMovementSystem` |
| **managers** | long-lived state and workflows | `CareerManager` (seasons, saves) |
| **scene scripts** | presentation and input translation | `journal_screen.gd` |

### The test that decides

Ask: **would this need to change if the interface were replaced?**

- Reception reach: no → simulation.
- Drawing a reception zone: yes → scene component.
- A player's reception attribute: no → model.
- Applying a week of training: no → system, coordinated by a manager.

A second test, for autoloads specifically: **could two of these exist at once?**
A career can — so career *data* is a model, and the manager only owns the
current one.

## 4. Reading the layer counts

The distribution tells you something about the project:

| Directory | Files | What that means |
|---|---|---|
| `scripts/simulation/` | 84 | The rally is the substance of the project |
| `scripts/data/` | 53 | Large amounts of authored reference data |
| `scripts/models/` | 37 | Many small typed contracts |
| `scripts/systems/` | 14 | Calculations, deliberately few |
| `scripts/domain/` | 4 | Shared vocabulary — attributes, body types |
| `scripts/managers/` | 2 | Exactly the two autoloads |

**Two managers and eighty-four simulation files is the shape you want.** If
`scripts/managers/` starts growing, something that should be a system has become
a workflow.

## 5. The runtime trace method

When you do not know what code runs:

1. identify the visible scene;
2. find its attached script in the `.tscn` file;
3. find the signal connection or callback for the user action;
4. follow each method call;
5. stop only when you reach the model mutation or calculation you care about.

This is more reliable than searching for a plausible function name and assuming
it is active. **This codebase contains superseded paths that still parse.** A
function can look exactly like the one that runs and never be called.

### Worked example

*"Where does the light/dark theme actually get applied?"*

Guessing would send you looking for `set_theme`. Tracing instead:

1. The visible scene is `application.tscn`.
2. Its script preloads `DarkTheme`, `LightTheme` and `UIStyleSystem`.
3. `UIStyleSystem` is a *system* — it decides what every `Control` **is** (its
   tier), rather than painting it.
4. The drawn treatments live in `scenes/components/`, and are added as children
   **at runtime** by the style pass.

The answer — "no `.tscn` references the treatment components" — is one you would
probably never reach by searching, because the thing you would search for is
absent by design.

## 6. Common mistakes

**Putting a calculation in `application.gd`.** It becomes untestable headlessly.

**Adding a third autoload for convenience.** Ask whether two could exist at once.

**Editing `.godot/`.** Regenerated; run `--import` instead.

**Searching for a function name and assuming it runs.** Trace the path.

**Using a retired name.** `dashboard`, `recruitment` — both dead.

## 7. Check yourself

1. Which file sets the first scene, and what is its value? *(`project.godot`; `res://scenes/application.tscn`.)*
2. Why are probes run with `--rendering-method gl_compatibility`? *(It is the project's renderer; the tool should match the game.)*
3. You want a "team chemistry" calculation. Which layer? *(A system — it would not change if the interface were replaced.)*
4. Why is two autoloads a good sign? *(Managers own long-lived state only; growth there means a system became a workflow.)*
5. A `.tscn` does not reference the component that draws its border. Bug? *(No — the style pass adds treatments as children at runtime.)*

## Where this leads

- [P1-C3 Repository Map](03_repository_map.md) — the full directory layout
- [P1-C4 Following a User Action](04_following_a_user_action.md) — the trace method applied end to end
- [P2-C2 Resources, Nodes and Signals](../part_02_gdscript/02_resources_nodes_and_signals.md) — what the tree is made of
