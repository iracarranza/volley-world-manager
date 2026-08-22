# 05 — Tracing Code Through VWM

Status: **VERIFIED METHOD / EXAMPLES REQUIRE SOURCE CHECK**

A large project becomes manageable when you stop trying to understand *files* and start tracing **one fact or action across boundaries**.

In VWM, most useful traces look like this:

```text
player input or simulation fact
→ object that owns it
→ function that changes it
→ downstream consumer
→ visible/resulting effect
```

The skill is not memorising the repository. It is learning how to ask the code a narrow question.

## Start from a concrete question

Good tracing questions:

- What happens when I click a desk card?
- Where does a player's `reception_stability` rating affect a dig?
- How does a theme change reach a button?
- Where does a first contact become contact number 1?
- Why did a sticker use the wrong pose?

Bad first questions:

- How does `rally_simulator.gd` work?
- What does the entire UI do?

Those are too large. Reduce them until one value, call, signal, or object can be followed.

## Trace a UI action

`scenes/application.gd` is a useful example because it is a router between screens. In `_ready()` it connects signals such as:

```gdscript
journal.training_requested.connect(_show_training)
journal.scouting_requested.connect(_show_scouting)
```

**GDScript reminder:** `object.signal.connect(function)` means “when this object emits this signal, call this function.” The signal producer does not need to know how navigation works.

A typical trace is therefore:

```text
Button pressed
→ screen emits `training_requested`
→ Application receives signal
→ `_show_training()`
→ lazy screen creation if necessary
→ `_show_only()`
→ screen becomes visible
```

Do not stop at the signal name. Search for both:

```text
signal training_requested
training_requested.emit
```

Then search for `.connect(` on the same signal.

This lets you find producer, message, and consumer.

## Trace a model field

Suppose you want to understand `VolleyballPlayer.reception_stability`.

Start at its declaration in `scripts/models/volleyball_player.gd`:

```gdscript
@export_range(1, 100) var reception_stability: int = 50
```

That tells you:

- the owner is `VolleyballPlayer`;
- the value is integer-like ability data;
- Godot exposes it to the Inspector when this Resource is edited;
- valid authored range is 1–100.

Now search the repository for `reception_stability`.

Classify each result instead of treating all matches equally:

| use | question |
|---|---|
| generation | how is the value created? |
| training | how can it change? |
| simulation | what decisions/physics read it? |
| UI | how is it shown? |
| tests/probes | what behavior is expected? |
| docs | why was it designed this way? |

This is a **data-flow trace**.

## Trace a function boundary

Function signatures are architectural maps.

If you see:

```gdscript
func player_state(side: StringName, player_id: int) -> RallyPlayerState:
```

read it as:

```text
INPUT
side        StringName
player_id   int

OUTPUT
RallyPlayerState
```

Then ask:

1. who calls this?
2. what assumptions do callers make about the returned object?
3. can it return `null` despite the declared return type?
4. does the function mutate anything?

A function that takes complete inputs and returns a value is usually easier to reason about than one that quietly reads global state.

## Trace state mutation

For simulation work, always separate **reading state** from **changing state**.

`RallyState.register_contact()` mutates possession/contact bookkeeping:

```gdscript
if side != possession:
    possession = side
    contact_number = 1
else:
    contact_number += 1
```

That is very different from a helper that merely calculates whether a contact is feasible.

When tracking a bug, search for every assignment to the suspicious field:

```text
contact_number =
contact_number +=
possession =
```

The writer is usually more important than the reader.

## Trace authority, not just calls

VWM deliberately contains diagnostic/shadow/presentation systems alongside authoritative ones.

So after finding a function, ask:

> Does this code decide what happens, or only observe/display what another system decided?

Examples:

- a `RallyEvent` records a resolved action for playback; it is not the physical world itself;
- a sticker bake reads a player pose; it must not change rally feasibility;
- a probe measures outcomes; it should not choose them;
- an intended recipient can guide a decision without defining the ball's actual endpoint.

This distinction prevents a common maintenance error: changing the nearest-looking consumer instead of the owner of the behavior.

## Use the Godot editor and text search together

The Godot editor is strongest for scene structure and local script relationships. Repository-wide text search is stronger for architecture.

Use Godot when asking:

- Which script is attached to this node?
- Which children exist in this scene?
- What theme/resource is assigned?
- Is this signal connected in the scene?

Use repository search when asking:

- Who calls this function?
- Who writes this field?
- Where is this constant used?
- Where is this event interpreted?

Do not force one tool to answer both kinds of question.

## A repeatable tracing routine

When unfamiliar code breaks:

1. State one observable symptom.
2. Identify the closest authoritative object/value.
3. Find its declaration.
4. Find every writer.
5. Find the consumer producing the symptom.
6. Draw the smallest call/data chain connecting them.
7. Locate an existing test/probe for that boundary.
8. Only then change code.

A useful scratch trace might be only:

```text
VoliSticker.request
→ _queue
→ _pump
→ _bake
→ PlayerActor3D.set_pose
→ SubViewport image
→ Sticker cache
→ worksheet draw
```

That is enough to navigate thousands of lines without reading them all.

## Reading exercise

Open `scenes/application.gd` and trace one route from the journal to another screen. Find:

- the emitted signal;
- the connection;
- the `_show_*` function;
- the `_ensure_*` lazy-construction function if one exists;
- `_adopt_screen()`;
- `_show_only()` / `_swap_to()`.

Then explain in one paragraph why a newly created screen must receive both the current theme pass and the 3D palette pass.

## Next

Chapter 06 applies this method to a bounded change and introduces the basic development loop: inspect → change → prove → document.