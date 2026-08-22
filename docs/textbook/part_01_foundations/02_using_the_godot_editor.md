# 2 — Using the Godot Editor

Status: **FOUNDATION / PROJECT-ORIENTED**

You do not need to become an expert in every Godot panel before working on VWM. You do need to know what the editor is showing you, where source/resources live, and when something exists only at runtime.

## The four editor areas you will use constantly

When a Godot project is open, four areas matter most for reading VWM:

- **FileSystem** — the project's files under `res://`;
- **Scene** — the currently opened scene's node tree;
- **Inspector** — editable properties for the selected node/resource;
- **Script editor** — `.gd` source code.

These are views onto different kinds of project information. The FileSystem is not the Scene tree, and the Scene tree is not the runtime tree.

### Example: inspecting a theme

In the FileSystem you can navigate to:

```text
scenes
→ themes
→ light_theme.tres
```

A `.tres` file is a serialized Godot **Resource**. Selecting/opening it lets the Inspector expose the resource's fields. VWM's theme contains style data for controls such as buttons, line edits, panels, and scrollbars.

You can also open the `.tres` as text because Godot's text resource format is human-readable. That is often useful when you want to search exact style names or compare a diff.

### Example: inspecting a scene

Open:

```text
scenes/components/player_actor_3d.tscn
```

The Scene dock shows the nodes authored in that scene. Selecting a node shows its properties in the Inspector.

A scene is best thought of as a **saved object hierarchy template**. When code calls `instantiate()`, Godot creates a runtime copy of that hierarchy.

## Authored tree vs runtime tree

This distinction matters constantly in VWM.

Some objects are visible in a `.tscn` before the game runs. Others are created entirely in GDScript.

For example, `UIVoliSticker` creates its own `SubViewport`, `Camera3D`, lights, and player actor in code. You will not find that complete bake hierarchy sitting in a `.tscn` waiting to be selected.

The code does something conceptually like:

```gdscript
_viewport = SubViewport.new()
add_child(_viewport)

_camera = Camera3D.new()
_viewport.add_child(_camera)
```

**Godot reminder — `new()` and `add_child()`**

`new()` constructs an object of that class. For a Node, construction alone does not put it into the running SceneTree. `add_child()` attaches it beneath another Node so it participates in that tree.

This means a common search failure is:

> "I can see this Camera3D in code, so where is it in the scene file?"

Answer: it may only exist after the script runs.

## Scenes and scripts are attached, not interchangeable

A `.tscn` scene may have a script attached to one of its nodes. The scene describes the hierarchy/properties; the script describes behavior.

A useful mental model:

```text
scene (.tscn)
= saved arrangement of Godot objects

script (.gd)
= behavior/class definition

resource (.tres)
= reusable serialized data/configuration
```

There are exceptions and more advanced cases, but this model is enough to navigate most VWM code.

## Inspector vs source code

Godot often lets you author the same kind of information in different places.

A property might be:

- written directly in a `.tscn`;
- edited through the Inspector and serialized into that `.tscn`;
- exposed by a script using `@export` and edited through the Inspector;
- assigned at runtime entirely in code.

So when you see a surprising value in-game, do not assume it lives where you first expect.

Later chapters will teach a practical source-of-truth question:

> Is this value authored in the scene/resource, exported from a script, derived by code, or overwritten at runtime?

## Running scenes and tools

VWM has many probe/preview `.tscn` files under `tools/`. These are often small scenes built specifically to visualize or measure one system.

In Godot, a scene can be run directly rather than launching the whole game. That is useful for things like pose previews or contact probes because the instrument has fewer unrelated systems around it.

The exact buttons/shortcuts may vary slightly by Godot version and editor layout, so the textbook focuses on the stable concepts:

```text
open scene
→ inspect nodes/resources
→ run relevant scene/project
→ watch Output/errors
→ compare result against source/probe expectation
```

## Output and errors

When something appears to do nothing, check the editor's output/debugger before assuming the logic never ran.

GDScript can fail at several stages:

- **parse/load time** — script cannot be interpreted;
- **runtime** — code loaded, but a value/path/object assumption failed;
- **visual/runtime timing** — logic ran but frame/render ordering produced an unexpected image.

One real VWM venue probe failed because GDScript could not infer a type from an expression. The process looked idle, which initially resembled a slow render rather than a source error. The lesson is not merely "fix the type": check the engine's error output before building a theory from missing visuals.

## A useful editor workflow for this textbook

When a chapter names a file:

1. locate it in the FileSystem;
2. open the scene/resource/script;
3. if it is a scene, inspect the Scene tree;
4. select relevant nodes/resources and inspect their fields;
5. open the attached/related script;
6. use repository/editor search to find callers or symbol names;
7. only then make a change.

You are trying to connect three representations:

```text
what the textbook says
↕
what the source says
↕
what Godot actually shows/runs
```

## What to retain

You should leave this chapter knowing:

- where project files appear;
- what the Scene and Inspector are showing;
- that scenes are saved hierarchies/templates;
- that runtime nodes may be created only from code;
- that `.gd`, `.tscn`, and `.tres` have different roles;
- that Inspector values and runtime values are not automatically the same source of truth;
- that the Output/debugger is part of ordinary source reading, not only crisis debugging.

Later UI, rendering, and rally chapters will repeatedly point back to these ideas rather than assuming they were memorized once.