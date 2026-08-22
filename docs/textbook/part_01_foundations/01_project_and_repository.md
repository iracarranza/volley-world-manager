# 1 — What VWM Is and How the Repository Is Organized

Status: **VERIFIED ORIENTATION**

Volley World Manager is a Godot project with three broad technical layers:

```text
management/game data
        ↓
match + rally simulation
        ↓
presentation / interface
```

Those layers communicate, but they should not substitute for one another. A UI widget may display a player's attribute; it should not become the place where that attribute is calculated. A rally event may describe a contact for playback; it should not become the source of truth for whether the contact was physically possible.

That separation is one of the most important ideas in the codebase.

## Start with paths, not file names in isolation

Godot refers to project files with paths beginning `res://`. `res://` means **the root of the current Godot project**.

So:

```gdscript
preload("res://scenes/components/player_actor_3d.tscn")
```

means "load `scenes/components/player_actor_3d.tscn` from this project."

**GDScript reminder — `preload()`**

`preload()` resolves a project resource when the script is loaded. You will see it often for scripts and scenes that a system knows it will need.

## The main repository areas

### `scenes/`

This is where much of the visible Godot application lives.

Important subareas include:

- `scenes/application.gd` / `.tscn` — top-level application/navigation shell;
- `scenes/screens/` — larger user-facing screens;
- `scenes/components/` — reusable interface and visual components;
- `scenes/themes/` — shared Godot Theme resources and shaders.

A useful first distinction:

```text
.gd    = GDScript source
.tscn  = text-form Godot scene
.tres  = text-form Godot resource
```

Those are related but not interchangeable. A `.tscn` may reference one or more `.gd` scripts. A `.tres` usually stores reusable data/configuration such as a Theme.

### `scripts/models/`

Models describe data objects used by systems. Rally examples include `RallyEvent`, `RallyResult`, player/ball state objects, flights, decisions, and opportunities.

A model generally answers:

> What information exists, and how is it represented?

It should not automatically be assumed to own the decision that produced the information.

### `scripts/simulation/`

This is the center of the rally engine. It contains `RallySimulator` plus specialized systems for movement, contact, perception, decisions, ball flight, rollout/certification, and related mechanics.

The rally code is intentionally moving away from "event name decides what happens next" toward:

```text
state
→ perception / responsibility / intent
→ physical feasibility
→ action choice
→ execution
→ outgoing ball
→ actual continuation
```

See `docs/design/RALLY_MILESTONES.md` for the current migration status rather than relying on historical gate documents.

### `scripts/systems/`

Broader game systems live here, including training and generation systems.

This folder is a useful reminder that not every system belongs inside `RallySimulator`. If a calculation has a clear domain and can be reused/tested independently, it often deserves its own system.

### `scripts/managers/`

Managers coordinate longer-lived game state and workflows such as career progression. A manager often owns lifecycle/state rather than one isolated calculation.

### `tools/`

VWM uses tools heavily. These include deterministic probes, visual previews, audits, calibration scenes, and documentation checks.

A probe is not "extra" code in this project. It is often the instrument that tells you whether a simulation or rendering claim is true.

### `docs/design/`, `docs/review/`, and `docs/textbook/`

These serve different purposes:

- `docs/design/` — intended/current design authority;
- `docs/review/` — measured evidence, certification, diagnosis, and implementation review;
- `docs/textbook/` — explanation for a human learning the project.

A textbook chapter should point to the authority/evidence rather than silently becoming a third source of truth.

## One useful mental map

When you encounter a feature, ask four questions:

```text
1. DATA: what object represents it?
2. DECISION: what system decides it?
3. AUTHORITY: what object/system owns the resulting truth?
4. PRESENTATION: what scene/component displays it?
```

For a rally contact, for example, a displayed `RallyEvent` is often the **presentation record**, not the physical authority that decided the outgoing ball.

For a button, the `Button` node is the visible input, a signal/callback carries the action, and some manager/system usually owns the actual game-state change.

## How to trace something unfamiliar

Suppose you want to understand voli stickers.

Start with the user-visible noun and search the repository for likely names. You find:

```text
scenes/components/voli_sticker.gd
```

Read the class declaration and public functions first. Then search for calls to those functions. This lets you build a graph:

```text
caller
→ public method
→ internal work
→ produced object/data
→ consumer
```

Do not begin by reading every line of a 30,000-character script from top to bottom.

## What to learn from this chapter

You do not need to memorize the repository tree. You need to know how to orient yourself:

- `scenes` = Godot-facing presentation/application structure;
- `models` = represented data;
- `simulation` = rally logic and physical/decision systems;
- `systems` = broader reusable game systems;
- `managers` = longer-lived workflow/state coordination;
- `tools` = measurement and inspection;
- `docs/design` = design authority;
- `docs/review` = evidence/certification.

The rest of the textbook repeatedly returns to this map until locating a system becomes routine.