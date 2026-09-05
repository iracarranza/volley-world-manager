# P2-C2 — Resources, Nodes, and Signals

Status: **VERIFIED**
Keywords: Resource, Node, scene tree, signal, @export, reference semantics, duplicate, decoupling
Primary sources: `scripts/models/rally_result.gd`; `scripts/managers/career_manager.gd`; `scripts/managers/game_manager.gd`; `scenes/application.gd`

## Prerequisites

- [P2-C1 GDScript Basics](01_gdscript_basics.md) — `extends` tells you which of these two a script is
- [P1-C2 Godot Project and Runtime](../part_01_project/02_godot_project_and_runtime.md) — the four layers

## Learning goals

After this chapter you should be able to:

1. choose `Resource` or `Node` for a new class, using a question rather than a habit;
2. read an `@export` block as a data contract;
3. connect two parts of the project without hard-wiring them together;
4. predict when mutating a Resource will affect something you did not intend;
5. name the one direction dependencies are allowed to run.

## Vocabulary

| Term | Meaning |
|---|---|
| **`Resource`** | Structured data. Exists without a scene tree; testable headlessly. |
| **`Node`** | A participant in the running scene tree, with lifecycle callbacks. |
| **`@export`** | Marks a property as part of the saved, inspectable contract. |
| **Signal** | An announcement that something happened; senders do not know receivers. |
| **Reference semantics** | Two variables can point at the *same* Resource. |
| **`duplicate()`** | Makes a copy, so mutation does not leak. |

---

## 1. Resource

### 1.1 What it is, and the question it answers

A `Resource` is suited to structured game data. `RallyEvent`, `RallyResult`,
players, lineups, plans and the rally-state objects are all Resources. **They
can exist in headless tests without a visible scene**, which is the property the
entire `tests/` directory depends on.

> Use a Resource when the central question is: *what data, and data-local
> behaviour, describe this thing?*

### 1.2 Reading an `@export` block as a contract

```gdscript
class_name RallyResult
extends Resource

@export var events: Array[Resource] = []
@export var home_team_won: bool = false
@export var terminal_outcome: String = ""
@export var decisive_actor_id: int = -1
@export_range(0.0, 1.0) var reception_quality: float = 0.0
@export_range(0.0, 1.0) var set_quality: float = 0.0
@export var analysis: Dictionary = {}
```

Three things this tells you before you read a line of logic:

- **What a rally result *is*** — an event list plus an outcome plus graded
  qualities. Anything else must be derived.
- **What is bounded** — `@export_range(0.0, 1.0)` says a quality is a
  normalised fraction, not a percentage or a 0–100 rating.
- **Where the escape hatch is** — `analysis: Dictionary` is the untyped
  extension point, and therefore the place drift will accumulate. See
  [P2-C3 §3](03_collections_types_and_null.md).

### 1.3 Defaults are part of the contract

`decisive_actor_id: int = -1` uses `-1` as "nobody", because `0` is a valid
player id. When you add a field, choose a default that **cannot be mistaken for
a real value**. This is the same reasoning that makes `null` dangerous in
[P2-C3](03_collections_types_and_null.md).

---

## 2. Node

### 2.1 What it is, and the question it answers

A `Node` lives in the scene tree. Nodes receive lifecycle callbacks, can display
UI, process input, own children, and connect signals. Scene controller scripts
therefore extend Node-derived classes such as `Control` or `Node3D`.

> Use a Node when the central question is: *what participates in the running
> scene tree?*

### 2.2 The cost of choosing Node

Every `Node` you add is a thing a headless test cannot easily construct. That is
not a reason to avoid them — the interface must exist — but it is the reason
calculations must not live in them.

**Test:** if you cannot write a check for it in `tests/` without opening a
screen, it is in the wrong class.

---

## 3. Signals

### 3.1 Declaring and connecting

A signal announces that something happened:

```gdscript
signal career_changed
signal career_loaded
signal week_advanced(report: Dictionary)
signal transfer_pool_changed
```

Another object connects a callback. **The sender does not need to know every
receiver.** This keeps screens from becoming hard-wired to one another.

### 3.2 What the signal list tells you about a class

Read `CareerManager`'s four signals as a summary of what it owns: a career can
*change*, be *loaded*, *advance a week*, and its *transfer pool* can move. That
is the manager's whole public story.

Compare `GameManager`:

```gdscript
signal rotation_changed(rotation_number: int)
signal playbook_changed
signal roster_changed
```

Different concerns entirely — the live team, not the career. **Two autoloads,
two clearly separate vocabularies.** If you find yourself wanting to emit
`roster_changed` from `CareerManager`, the boundary is being crossed.

### 3.3 Payload, or no payload?

`week_advanced(report: Dictionary)` carries data; `career_changed` does not.

The rule: **carry a payload when the receiver would otherwise have to ask a
question it cannot answer.** A week's report is a summary of something that has
already finished and cannot be recomputed. A changed career can simply be read
back off the manager.

> **Anti-pattern.** A payload that duplicates readable state invites two sources
> of truth — the receiver's copy and the manager's — which then disagree.

---

## 4. Separation in practice

### 4.1 The correct direction

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

Two rules are visible here:

- **The training formula must not be inside the button callback.** It would be
  unreachable from a test.
- **The player Resource must not find a label and change its text.**
  Dependencies run one way.

### 4.2 The rule, stated once

> Presentation may read simulation. **Simulation must not read presentation.**

This is [P1-C3](../part_01_project/03_repository_map.md)'s coupling rule seen
from the language side. A `Resource` that imports a scene has broken it.

### 4.3 Why signals rather than direct calls

The manager cannot call `journal_screen.refresh()` — that would make the
simulation layer depend on a screen's existence, and the screen may not be open.
Emitting is the manager saying *this happened*, leaving whoever cares to react.

---

## 5. Reference semantics: the sharp edge

### 5.1 Resources are references

Two variables can point at the same Resource. Mutating through one changes what
the other sees.

```gdscript
var a := player_resource
var b := a
b.reception = 90        # a.reception is now 90 as well
```

### 5.2 When this bites

Before mutating a value that should be isolated, determine whether the caller
expects **shared state or a duplicate**. The dangerous cases:

- a "template" lineup edited per match;
- a default plan handed to several teams;
- a `const` table returned to a caller — see
  [P2-C1 §4.2](01_gdscript_basics.md), where `Dictionary(...)` copies for
  exactly this reason.

### 5.3 Copying

```gdscript
var isolated := original.duplicate(true)
```

`true` means **deep** — nested Resources are copied too. A shallow copy of a
lineup still shares its player references, which is usually right (you want the
same players) and occasionally catastrophic (you did not want the same *plan*).

> **Habit.** When you write `duplicate()`, write a comment saying which nested
> things you intended to share.

---

## 6. Choosing: a decision table

| The thing is… | Class | Directory |
|---|---|---|
| Saved career data | `Resource` | `scripts/models/` |
| A stateless calculation | `RefCounted`, static funcs | `scripts/systems/` |
| Long-lived workflow state | `Node` autoload | `scripts/managers/` |
| A full-screen interface | `Control` | `scenes/screens/` |
| A reusable widget or actor | `Control` / `Node3D` | `scenes/components/` |
| A shared vocabulary table | `RefCounted` | `scripts/domain/` |

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| Calculation inside a Node callback | Untestable headlessly |
| Resource that imports a scene | Coupling rule broken; tests cannot run |
| Signal payload duplicating readable state | Two sources of truth |
| Mutating a shared Resource | Distant, unrelated-looking corruption |
| Shallow `duplicate()` on a nested model | Copy shares what you meant to isolate |
| A third autoload "for convenience" | Long-lived state where a system belongs |

---

## 8. Check yourself

1. Why must `RallyResult` be a `Resource` and not a `Node`? *(Tests construct and inspect it with no scene tree.)*
2. What does `@export_range(0.0, 1.0)` tell you about `set_quality`? *(It is a normalised fraction, not a 0–100 rating.)*
3. Why is `decisive_actor_id` defaulted to `-1`? *(`0` is a valid player id, so the default must be impossible.)*
4. Should `week_advanced` carry its report? *(Yes — it summarises something finished that cannot be recomputed.)*
5. You duplicate a lineup and both copies change together. What went wrong? *(A shallow copy shared the nested Resource.)*

---

## Where this leads

- [P2-C3 Collections, Types and Null](03_collections_types_and_null.md) — the `analysis: Dictionary` escape hatch and its costs
- [P4-C2 Persistent Rally State](../part_04_match_engine/02_persistent_rally_state.md) — Resources modelling a whole evolving rally
- [P5-C1 Career, Roster and Training](../part_05_management/01_career_roster_and_training.md) — `CareerManager`'s signals in use
