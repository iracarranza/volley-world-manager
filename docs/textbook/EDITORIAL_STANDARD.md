# Textbook editorial standard

Status: **AUTHORING RULE**

This file governs the v2 architecture textbook.

## Reader model

Assume the reader:

- understands programming ideas in general;
- may have no practical experience with Godot's editor;
- may have no retained GDScript knowledge;
- wants enough fluency to continue VWM independently with source inspection and testing.

Do not write for a total programming beginner. Do not write for an experienced Godot developer either.

## Causal learning

Introduce a Godot/GDScript concept when the reader can immediately see why VWM needs it.

Bad order:

```text
learn Node
learn Control
learn Theme
learn Resource
learn StyleBox
then finally inspect a VWM button
```

Preferred order:

```text
VWM button needs a visual state
→ Godot Button is a Control
→ its Theme supplies a StyleBox for normal/hover/pressed
→ pressed emits a signal
→ a connected callback performs the game action
```

The explanation can still define every unfamiliar term, but the system remains the spine.

## Repetition and fading scaffolds

Treat recurring concepts the way a good textbook does:

1. **First important appearance** — explain closely enough that the code can be read.
2. **Later appearance** — give a one- or two-sentence reminder where useful.
3. **Established concept** — use normally unless this use is unusual.

Example first appearance:

```gdscript
const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
```

Explain `const`, `:=`, `preload()`, `res://`, and why the loaded object is a scene resource.

Later:

> Recall that `preload()` resolves a project resource when the script is loaded; here the resource is another script rather than a scene.

Do not annotate every token forever.

## GDScript curriculum underneath the book

The language curriculum is distributed through real systems, but the book must collectively teach enough to read and extend VWM.

Essential constructs include:

- `var`, `const`, `=`, `:=`;
- primitive types plus `String`, `Vector2`, `Vector3`;
- `Array`, `Dictionary`, typed collections, `null`;
- `if` / `elif` / `else`, loops, `match`, Boolean operators;
- functions, arguments, defaults, return values and return types;
- classes, instances, properties, methods, `class_name`, `extends`;
- static functions and why VWM calculation systems often use them;
- `preload`, `load`, `instantiate`, `as`, `is`;
- `@export`, signals, `emit`, signal connections;
- `await`, frame timing, `get_tree()`;
- Nodes, Resources, RefCounted objects and lifetime differences;
- enums, Callables, seeded RNG, mutation/reference behavior.

The book must also teach non-keyword concepts that are crucial for reading architecture:

- class vs instance;
- resource definition vs runtime object;
- local variable vs persistent member state;
- pure calculation vs mutation;
- event/signal vs direct call;
- serialization and snapshots;
- ownership/authority boundaries;
- source of truth vs derived/presentation data.

## Function signatures are maps

Teach readers to extract architecture from signatures.

For example:

```gdscript
func request(
    key: String,
    event_type: int,
    elevation: float,
    profile: Dictionary,
    yaw_degrees: float = 0.0
) -> void:
```

The reader should learn to identify required inputs, optional inputs, types, defaults, return type, and then search callers/consumers to understand the boundary.

## Godot editor orientation in context

When useful, tell the reader where the discussed object appears in Godot:

```text
FileSystem → scenes/themes/light_theme.tres
Inspector → Button → Styles → Normal
```

Also state when something **cannot** be found pre-authored in the editor because it is created at runtime. This distinction prevents wasted searching.

Do not turn every paragraph into UI directions. Include them where they answer a likely "where is this?" question.

## Architecture before trivia

A chapter should leave the reader able to answer:

1. What is this system for?
2. What information enters it?
3. What does it own?
4. What does it produce?
5. Which files/symbols implement it?
6. What neighboring layer must it not impersonate?
7. How would I trace or safely change it?

Syntax details support those questions; they do not replace them.

## Real code, progressively less translated

Early chapters may translate short excerpts almost line-by-line. Middle chapters explain unfamiliar constructs but expect ordinary syntax fluency. Later chapters should show normal VWM functions and expect the reader to trace them with only architecture-specific guidance.

The intended progression is:

```text
read expressions
→ read functions and objects
→ read Godot architecture
→ trace state across files
→ understand simulation/data/UI boundaries
→ make bounded changes
→ extend systems independently
```

## Error literacy

Use real project failures when possible. The reader should learn to distinguish at least:

- parser/type-inference errors;
- invalid property/index access;
- null-instance failures;
- scene/resource/instance confusion;
- Node lifetime and detached/freed-node issues;
- asynchronous/frame-order mistakes;
- mutation leaking between seeded tests;
- presentation evidence being mistaken for gameplay authority.

Explain the diagnosis method, not merely the fix.

## Historical material

Do not present an old gate, shadow system, or migration step as current architecture merely because its code/document still exists.

Historical chapters should answer **why the current design exists**. Current chapters answer **what owns behavior now**.

## Exercises

Prefer source-reading tasks over toy programs.

Good:

> Read `UIVoliSticker.request()` before the explanation. What prevents a duplicate bake request, which members persist between calls, and what starts `_pump()`?

Good:

> Trace a new field added to `RallyPlayerState`: where must it be initialized, carried between phases, snapshotted, and certified?

Avoid unrelated calculator/to-do-list exercises unless they teach a language construct that cannot reasonably be introduced through VWM itself.
