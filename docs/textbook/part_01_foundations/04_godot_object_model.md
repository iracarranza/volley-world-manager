# 4 — Godot's Object Model: Nodes, Scenes, Resources, and Signals

Status: **FOUNDATION / GODOT MODEL**

Most confusion in a Godot codebase comes from mixing up four related things:

```text
class definition
saved resource/scene
runtime instance
object lifetime/ownership
```

VWM uses all four heavily. This chapter builds the mental model needed to follow them.

## A Node is a runtime object that can live in the SceneTree

Many visible or active Godot objects inherit from `Node`:

```gdscript
class_name UIVoliSticker
extends Node
```

A Node can have child Nodes. When attached beneath another Node, it becomes part of the SceneTree.

That matters because tree membership gives access to engine behavior such as processing, notifications, signals, and `get_tree()`.

A newly constructed Node is not automatically in the tree:

```gdscript
var camera := Camera3D.new()
```

At this point the camera object exists, but it is not yet a child of anything.

```gdscript
_viewport.add_child(camera)
```

now attaches it beneath `_viewport`.

**Godot reminder**

The SceneTree is the hierarchy of active runtime Nodes. The **Scene dock** in the editor shows the authored tree of the scene you are editing; the actual running tree may contain additional nodes created by scripts.

## A scene is a saved hierarchy that can be instantiated

A `.tscn` file is a Godot scene resource.

For example:

```text
scenes/components/player_actor_3d.tscn
```

contains a saved hierarchy/configuration for a player actor.

Loading the scene does not create a live player:

```gdscript
const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
```

The loaded object is a `PackedScene` resource: a reusable description of how to create that hierarchy.

To make a runtime copy:

```gdscript
var actor := ACTOR_SCENE.instantiate() as PlayerActor3D
```

Then, if it needs to participate in a runtime tree:

```gdscript
_viewport.add_child(actor)
```

So the lifecycle is:

```text
.tscn on disk
→ PackedScene resource
→ instantiate()
→ runtime Nodes
→ add_child()
→ active in a SceneTree
```

This distinction is crucial when debugging "why did changing the scene not change this instance?" or "why can't I find this node in the editor?"

## A Resource is reusable data, not a scene-tree object

Godot `Resource` objects are designed to store reusable data/configuration. They do not need to live in the SceneTree.

VWM themes are a clear example:

```text
scenes/themes/light_theme.tres
scenes/themes/dark_theme.tres
```

Those files describe Theme resources. They can contain StyleBoxes, font assignments, colors, and other data used by many controls.

A resource often answers:

> What reusable data/configuration does this system consume?

A Node often answers:

> What active object is participating in the running scene?

The boundary is not "visual vs nonvisual". Some Resources describe visual data; some Nodes perform invisible coordination.

## `RefCounted` objects are lightweight runtime objects

Not every runtime object needs a Node.

`UIVoliSticker` contains an internal class:

```gdscript
class Sticker extends RefCounted:
    var texture: ImageTexture
    var contours: Array = []
    var aspect: float = 1.0
```

A `Sticker` is data produced by the bake pipeline. It does not need processing, children, or a place in the SceneTree, so making it a Node would add unnecessary lifecycle complexity.

`RefCounted` objects are automatically kept alive while references to them exist and released when no references remain.

Later simulation chapters will show the same general principle: use the lightest object form that honestly represents the thing.

## Scripts can define classes

A `.gd` file can attach behavior to a Node/Resource or define a reusable named class.

```gdscript
class_name UIVoliSticker
extends Node
```

means this script defines a globally named class called `UIVoliSticker`, based on `Node`.

Then another script can use the class name as a type without manually loading the script each time.

`extends` is inheritance. If `UIVoliSticker` extends `Node`, it receives Node behavior and adds its own.

When reading a class, always inspect the parent type. It tells you what lifecycle/API is inherited before the first line of custom code runs.

## Scene composition vs inheritance

Godot projects use two different reuse mechanisms that can look similar when new:

```text
inheritance:
PlayerActor3D extends Node3D

composition:
MatchCourt3D contains PlayerActor3D children
```

Inheritance means "is a kind of."

Composition means "contains/uses."

VWM generally benefits when large systems are composed from narrower pieces instead of one inheritance hierarchy owning every responsibility.

## Signals decouple event notification

Suppose the sticker baker finishes work. It could directly know every screen that might care, but that would tightly couple the baker to its consumers.

Instead it exposes:

```gdscript
signal sticker_ready(key: String)
```

and later emits:

```gdscript
sticker_ready.emit(key)
```

Another object can connect a callback to that signal.

Conceptually:

```text
baker
→ announces "sticker_ready"
→ any connected listener reacts
```

The sender does not need to know which screen/component is listening.

Signals are particularly common in UI architecture because controls naturally announce user actions (`pressed`, value changes, selection changes) to code that owns the response.

## Direct calls are still useful

Signals are not automatically better than function calls.

Use a direct call when one object clearly needs another object's result:

```gdscript
var sticker := baker.sticker(key)
```

A signal is useful when the relationship is "announce that something happened."

A function call is useful when the relationship is "please do this / give me this result."

This distinction will make UI code much easier to read.

## Shared resources and mutation

Resources can be shared by multiple consumers. That is powerful and dangerous.

If two controls reference the same StyleBox resource and code mutates that StyleBox at runtime, both may appear to change because both reference the same object.

This is one reason you will sometimes see code duplicate a Resource before changing it.

The larger programming concept is **reference semantics**: two variables can refer to the same underlying object.

Later chapters will revisit this in simulation tests, where shared mutable state can make a seeded second run differ from the first even though the RNG seed is identical.

## Lifecycle matters

Node code often assumes the object is in a valid runtime state.

Godot lifecycle methods you will encounter include:

```gdscript
func _ready() -> void:
    ...

func _process(delta: float) -> void:
    ...
```

`_ready()` is called after a Node enters the SceneTree and its children are ready.

`_process()` may run every rendered frame when processing is enabled.

VWM also creates nodes only for temporary work, disables rendering when idle, and frees/replaces objects. That means lifetime mistakes can produce detached-node/resource-leak warnings or calls against objects no longer valid.

Do not treat those as abstract engine trivia. They tell you that your mental model of **who owns this object and how long it should live** may be wrong.

## Scene-owned vs script-created: a practical trace

The sticker baker is useful because it mixes both:

```text
UIVoliSticker script instance
    ↓ creates
SubViewport
    ↓ contains
PlayerActor3D instance ← instantiated from .tscn
Camera3D                ← created with Camera3D.new()
DirectionalLight3D      ← created with .new()
```

The player actor comes from an authored scene. The viewport/camera/lights are built in code.

If you inspect only `player_actor_3d.tscn`, you will not understand the whole bake setup. If you inspect only `voli_sticker.gd`, you will not see the internal authored hierarchy of the player scene.

This is normal Godot architecture: source understanding often requires both scene and script inspection.

## The source-of-truth question

For any value, ask:

```text
Was it authored in a scene/resource?
Was it exported from script and edited in Inspector?
Was it derived by code?
Was it changed at runtime?
Is this object shared or unique to this instance?
```

Those questions prevent many false diagnoses.

For example, a rendered color may originate in a Theme resource, then be overridden by component code, then transformed by a shader. "The Inspector says this hex" does not automatically mean the player sees that hex on screen.

## Practice

Read this simplified pattern:

```gdscript
const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

func _ensure_rig() -> void:
    _viewport = SubViewport.new()
    add_child(_viewport)

    _actor = ACTOR_SCENE.instantiate() as PlayerActor3D
    _viewport.add_child(_actor)
```

You should now be able to say:

- `ACTOR_SCENE` is a preloaded scene resource, not a player instance;
- `_viewport` is a runtime Node created directly from a class;
- `_actor` is a runtime hierarchy instantiated from a saved scene;
- both must be attached to Nodes before participating in the relevant SceneTree;
- `_actor` is specifically expected to be a `PlayerActor3D`.

That is enough object-model literacy to begin the interface chapters.