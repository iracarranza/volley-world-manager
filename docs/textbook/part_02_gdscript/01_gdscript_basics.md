# P2-C1 — GDScript Basics

Status: **VERIFIED** language concepts; snippets marked **EXAMPLE**
Keywords: class_name, extends, preload, var, const, func, static typing, inference, contract
Primary sources: `scripts/models/rally_event.gd`; `scripts/simulation/coverage_calculator.gd`; `scripts/domain/attribute_registry.gd`

## Prerequisites

- [P1-C3 Repository Map](../part_01_project/03_repository_map.md) — you will read real files from `scripts/models/` and `scripts/simulation/`

## Learning goals

After this chapter you should be able to:

1. read the first three lines of any script in this project and say what it is;
2. choose between `var`, `const`, and `preload` correctly;
3. write a typed function signature and explain what each part guarantees;
4. tell an instance function from a static one, and know which this codebase prefers;
5. reduce an unfamiliar function to a **contract** you can reason about.

## Vocabulary

| Term | Meaning |
|---|---|
| **`class_name`** | Registers a script as a globally named type. |
| **`extends`** | Chooses the parent type, and therefore the abilities the class starts with. |
| **`preload`** | Loads a resource at parse time. A wrong path fails immediately. |
| **`const`** | A name that cannot be reassigned. |
| **Static typing** | Declaring a type so Godot can check it before the code runs. |
| **Inference (`:=`)** | Letting Godot deduce the type from the assigned value. |
| **Static function** | A function on the class, not on an instance. A named calculation. |
| **Contract** | What a function takes, reads, changes, and returns. |

---

## 1. Reading the top of a script

The first lines tell you what kind of thing you are looking at. Learn to read
them before anything else.

### 1.1 `class_name` and `extends`

```gdscript
class_name RallyEvent
extends Resource
```

`class_name` registers a reusable type — after this, any script can say
`RallyEvent` without a `preload`. `extends` chooses the parent, and therefore
what the class can already do.

**The parent tells you the layer.** From [P1-C3](../part_01_project/03_repository_map.md):

| `extends` | What it is | Lives in |
|---|---|---|
| `Resource` | Data, testable headlessly | `scripts/models/` |
| `RefCounted` | A calculation holder, no scene tree | `scripts/systems/`, `scripts/domain/` |
| `Node`, `Control`, `Node3D` | Something in the running scene | `scenes/` |
| `SceneTree` | A standalone script entry point | `tools/` |

> **Diagnostic.** A file in `scripts/models/` that `extends Node` is
> mis-filed — it has just become untestable without a scene.

### 1.2 `const` and `preload`

```gdscript
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
```

`const` cannot be reassigned. `preload` loads a known resource **when the script
is parsed**, so a wrong path causes an early, loud error rather than a late,
quiet one.

Use `preload` when the path is fixed and known. Use `load` only when the path is
computed at runtime — which is rare here and worth a comment when it happens.

### 1.3 When you need neither

If a script has `class_name`, you do **not** need to `preload` it. Both appear
in this codebase; the `preload` form is used where a script has no `class_name`,
or to avoid a cyclic dependency.

> **Worked case.** `tools/run_venue_probe.gd` deliberately does *not* preload the
> court scene, storing a path string instead, because `MatchCourt3D` preloads the
> probe's script. Two `preload`s pointing at each other is a circular resource
> dependency and will not load. See [P7-C3](../part_07_art_and_assets/03_the_court_and_venue.md).

---

## 2. Values: variables, constants and types

### 2.1 Declaring with an explicit type

```gdscript
var rally_clock: float = 0.0
var live_positions: Dictionary = {}
```

The text after `:` is the expected type. Static typing lets Godot detect
mistakes **before the affected branch runs** — which matters enormously in a
codebase where a branch may only execute in one rally out of two hundred.

### 2.2 Declaring with inference

```gdscript
var distance := CoverageCalculator.court_distance_meters(start, target)
```

`:=` infers the type from the value. It is still statically typed — it is not
`Variant`. Prefer it when the type is obvious from the right-hand side, and
prefer an explicit type when it is not.

### 2.3 Choosing between them

| Situation | Use | Why |
|---|---|---|
| Value makes the type obvious | `:=` | Shorter, still checked |
| Empty collection | `var x: Array[Foo] = []` | `:= []` infers untyped `Array` |
| Number that must be float | `var x: float = 0.0` | `:= 0` infers `int` |
| Function parameter | Always explicit | Signatures are documentation |

> **The `int`/`float` trap.** `var ratio := 0` is an `int`. Assigning `0.5` to it
> later truncates to `0`, silently. When a value is a measurement, write
> `: float`.

---

## 3. Functions

### 3.1 Anatomy of a signature

```gdscript
func player_state(side: StringName, player_id: int) -> RallyPlayerState:
	return null
```

- inputs appear inside parentheses, each with a type;
- the type after `->` is the return type;
- indented lines form the body.

**A signature is a claim.** `-> RallyPlayerState` promises the caller gets that
type or `null` — see [P2-C3](03_collections_types_and_null.md) for why `null` is
always in the set.

### 3.2 Instance versus static

An **instance** function uses one object's state:

```gdscript
state.advance_to(1.2)
```

A **static** function behaves like a named calculation:

```gdscript
var distance := CoverageCalculator.court_distance_meters(start, target)
```

### 3.3 Why this codebase prefers static

Look at how the motion modules describe themselves:

> "Nothing here touches a node, holds state, or reads a frame delta."

Three reasons are given in `cogniticon_motion.gd`, and they generalise to most
calculation code here:

1. it produces the same answer at any playback speed;
2. it introduces no second clock to disagree with the first;
3. **a pure function can be gated headlessly**, which is how every claim in this
   repository is checked.

> **Rule of thumb.** If a function does not need `self`, make it `static`. You
> have just made it testable without constructing anything.

---

## 4. Reading an unfamiliar function

### 4.1 The six-question contract

For any function, write down:

1. inputs;
2. state read;
3. calculations performed;
4. state changed;
5. return value;
6. callers.

This turns a long function into a manageable contract. Questions 2 and 4 are the
ones people skip, and they are the ones that find bugs — a function that reads
state not in its parameters is not reproducible, and one that changes state it
did not declare is where determinism goes to die.

### 4.2 Worked example

```gdscript
static func attribute_modifiers(body_type: String) -> Dictionary:
	return Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))
```

1. **Inputs:** one `String`.
2. **State read:** the `BODY_TYPE_ATTRIBUTES` constant.
3. **Calculation:** a keyed lookup with an empty-dictionary default.
4. **State changed:** none — and note `Dictionary(...)` copies, so the caller
   cannot mutate the constant.
5. **Returns:** a `Dictionary`, never `null`.
6. **Callers:** `rg -n "attribute_modifiers" scripts`.

That copy in step 4 is the whole reason to read carefully. Without it, a caller
could mutate a `const` table and corrupt every subsequent player.

### 4.3 Applying it to a long function

`RallySimulator.resolve` is thousands of lines. The contract still works — you
answer question 1 from the signature ([P1-C4](../part_01_project/04_following_a_user_action.md) §2),
question 5 from the return type, and defer 2–4 until you have a specific
question. **You do not have to understand a function to reason about it.**

---

## 5. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `:= 0` for a measurement | Value truncates to `0` | `: float = 0.0` |
| `:= []` for a typed list | Wrong class accepted silently | `: Array[Foo] = []` |
| Instance function that ignores `self` | Needs an object to test | Make it `static` |
| `load` where `preload` would do | Path errors surface late | `preload` |
| Mutual `preload` | Script fails to load | Store a path string on one side |
| Returning a `const` collection | Callers mutate shared data | Copy on return |

---

## 6. Check yourself

1. A file in `scripts/models/` says `extends Node`. What has gone wrong? *(It is untestable headlessly; models extend `Resource`.)*
2. `var count := 0` then `count = 2.5`. What is `count`? *(`2` — inferred `int`, truncated.)*
3. When is `load` correct instead of `preload`? *(Only when the path is computed at runtime.)*
4. Why does `attribute_modifiers` wrap its result in `Dictionary(...)`? *(To copy, so callers cannot mutate the constant.)*
5. Which of the six contract questions catches non-determinism? *(2 and 4 — state read and state changed.)*

---

## Where this leads

- [P2-C2 Resources, Nodes and Signals](02_resources_nodes_and_signals.md) — the two base types and how they communicate
- [P2-C3 Collections, Types and Null](03_collections_types_and_null.md) — where the parser errors actually come from
- [P3-C1 Safe Change Workflow](../part_03_workflow/01_safe_change_workflow.md) — using the contract method to make a change safely
