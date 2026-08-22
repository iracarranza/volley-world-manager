# 3 — GDScript: The Language Needed to Read VWM

Status: **FOUNDATION / LANGUAGE SPINE**

This chapter is not a complete GDScript manual. It gives you the grammar needed to start reading VWM source, then later chapters deepen that knowledge through real systems.

If you already know another programming language, focus less on "what is a variable?" and more on **how GDScript expresses familiar ideas**.

## Read code as relationships

Consider a simplified VWM-style function:

```gdscript
func choose_actor(state: RallyState, player_id: String) -> RallyPlayerState:
    var actor := state.actor_for(player_id)
    if actor == null:
        return null
    return actor
```

Before worrying about implementation, read the signature:

```text
function: choose_actor
inputs:
  state      RallyState
  player_id  String
returns:
  RallyPlayerState
```

That already tells you an architectural fact: this function receives state rather than owning the entire rally itself.

## `func`, arguments, and return types

GDScript declares a function with `func`:

```gdscript
func sticker(key: String) -> Sticker:
    return _baked.get(key, null) as Sticker
```

This real pattern from `UIVoliSticker` says:

- function name: `sticker`;
- required argument: `key`;
- `key` must be a `String`;
- the function intends to return a `Sticker`;
- `return` exits the function and provides its result.

The `-> Sticker` portion is a return-type annotation.

VWM uses typed signatures heavily because they make system boundaries easier to inspect and let Godot catch some invalid uses earlier.

## Variables: `var`, `const`, `=`, and `:=`

Mutable variables use `var`:

```gdscript
var _working: bool = false
```

A value intended not to be reassigned uses `const`:

```gdscript
const BAKE_SIZE := Vector2i(256, 320)
```

`=` assigns a value. `:=` asks GDScript to infer the variable's type from the right side.

```gdscript
var count: int = 3
var count := 3
```

Both produce an integer variable; the second relies on inference.

Inference is convenient but not magic. If Godot cannot determine one stable type from an expression, `:=` can produce a parser/type-inference error. VWM has encountered this in real tools.

## Members and locals

A variable declared at class scope is **member state**:

```gdscript
var _queue: Array[Dictionary] = []
var _working: bool = false
```

Those values survive across method calls for that object instance.

A variable declared inside a function is local to that call:

```gdscript
func sticker(key: String) -> Sticker:
    var result := _baked.get(key, null)
    return result as Sticker
```

When reading unfamiliar code, ask:

> Is this value temporary for this calculation, or is it persistent object state?

That question matters especially in the rally engine, where accidental persistent mutation can break deterministic tests.

## Basic values and types

Common GDScript types you will see in VWM include:

```text
bool       true / false
int        whole numbers
float      decimal numbers
String     text
Vector2    x/y values
Vector3    x/y/z values
Array      ordered collection
Dictionary key/value collection
```

Godot vector types are especially important because VWM constantly represents positions, velocities, directions, and offsets.

For example:

```gdscript
var velocity := Vector3(-0.26, 5.50, -3.73)
```

is one 3D vector, not three unrelated variables.

Later rally chapters explain how VWM interprets the coordinate axes; for now, learn to recognize vector construction and property access.

## Property access and method calls

The dot has two common meanings when reading VWM:

```gdscript
actor.position
actor.can_take_off()
```

The first accesses a property/value on `actor`.

The second calls a function/method on `actor`.

A method call's parentheses matter. `actor.can_take_off` refers to the callable member; `actor.can_take_off()` actually invokes it.

## `null`

`null` means "no object/value here."

A common VWM guard looks like:

```gdscript
var actor := state.actor_for(player_id)
if actor == null:
    return null
```

This is an **early return**: if the required actor does not exist, stop before later code tries to use it.

Null errors are common in object-oriented Godot code because a lookup, node path, resource, or optional result may legitimately return nothing.

## Conditions

GDScript conditionals are indentation-based:

```gdscript
if actor == null:
    return null
elif actor.is_recovering:
    return null
else:
    return actor
```

Boolean operators are written as words:

```gdscript
and
or
not
```

For example:

```gdscript
if actor != null and not actor.is_recovering:
    return actor
```

VWM often uses early returns instead of deeply nested conditionals because feasibility/legality checks naturally eliminate candidates one condition at a time.

## Loops

A `for` loop iterates a collection:

```gdscript
for pending in _queue:
    if str(pending.get("key", "")) == key:
        return
```

This real sticker pattern asks each queued request whether it already has the requested key.

A `while` loop continues while a condition remains true:

```gdscript
while not _queue.is_empty():
    var request := _queue.pop_front()
```

Read loops by identifying:

1. the collection/condition;
2. what changes each iteration;
3. what can stop or skip the loop.

## Arrays and Dictionaries

An `Array` is ordered:

```gdscript
var players := [setter, middle, libero]
```

A `Dictionary` maps keys to values:

```gdscript
var request := {
    "key": key,
    "event_type": event_type,
    "profile": profile,
}
```

VWM uses Dictionaries frequently for flexible metadata and diagnostic records.

Useful Dictionary operations include:

```gdscript
request.get("key", "")
request.has("key")
request["key"]
```

The `.get()` form can provide a fallback. Direct bracket access expects the key to exist and may fail when it does not.

**VWM boundary**

Flexible Dictionaries are convenient, but important authoritative state increasingly uses typed objects because spelling a metadata key correctly is weaker than having a real property/type contract.

## Classes, inheritance, and `class_name`

A VWM script may begin:

```gdscript
class_name UIVoliSticker
extends Node
```

`class_name` registers a named GDScript class that other scripts can refer to by name.

`extends Node` means the class inherits Godot's `Node` behavior.

Inheritance answers:

> What kind of object is this, and what behavior does it already receive from its parent class?

Later chapters distinguish Node subclasses from Resources and RefCounted calculation/data objects.

## Static functions

Some VWM systems expose calculations as static functions:

```gdscript
static func evaluate(actor: RallyPlayerState, ball: BallFlight) -> Result:
    ...
```

A static function belongs to the class rather than requiring one persistent object instance.

This shape is useful when a system should behave like:

```text
inputs
→ deterministic calculation
→ result
```

rather than storing hidden mutable state between calls.

So when you see:

```gdscript
ContactEnvelopeSystem.evaluate(actor, ball)
```

read it as a calculation provided by the `ContactEnvelopeSystem` class itself.

## `preload()`, `instantiate()`, and casts

A common Godot pattern is:

```gdscript
const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
var actor := ACTOR_SCENE.instantiate() as PlayerActor3D
```

The steps are:

```text
preload scene resource
→ instantiate runtime scene object
→ tell GDScript the expected specific type
```

`as PlayerActor3D` is a cast. It helps the language/editor understand the more specific object type expected here.

Do not confuse loading a scene with creating an instance of that scene.

## Signals

Godot signals are event notifications.

`UIVoliSticker` declares:

```gdscript
signal sticker_ready(key: String)
```

Later, code can emit that signal when a bake finishes:

```gdscript
sticker_ready.emit(key)
```

Another object may have connected a callback to that signal.

The important architecture idea is that the sender can announce:

> "this happened"

without needing to directly call every consumer that cares.

You will see signals heavily in UI code.

## `await`

GDScript can suspend a function until an asynchronous event occurs:

```gdscript
await get_tree().process_frame
```

In the sticker baker, frame waiting matters because the script changes a 3D rig, lets Godot render it, and only then reads the resulting image.

Without the wait, the code may read the previous frame rather than the pose it just requested.

This is a good example of why syntax should be learned causally: `await` is not merely "an async keyword" here. It is part of the render pipeline's correctness.

## Default arguments

Functions can provide optional defaults:

```gdscript
func request(
    key: String,
    profile: Dictionary,
    yaw_degrees: float = 0.0,
    headshot: bool = false
) -> void:
```

A caller must provide `key` and `profile`, but may omit `yaw_degrees` and `headshot`.

When tracing a call, defaults matter because a behavior may come from the function definition rather than being visible at the call site.

## `-> void`

`void` means the function does not return a meaningful value:

```gdscript
func clear() -> void:
    _baked.clear()
    _queue.clear()
    stickers_reset.emit()
```

It still performs work by mutating member state and emitting a signal.

This distinction becomes important later:

```text
function returning a calculated value
vs
function changing existing state
```

Both are ordinary, but the second has wider consequences and deserves more care in deterministic simulation code.

## Read unfamiliar code in this order

When you open a VWM function, try:

1. read the signature;
2. identify member state vs local values;
3. mark early exits;
4. identify calls to other classes/systems;
5. identify mutations;
6. identify the return/result;
7. search the callers.

Do not begin by understanding every helper recursively.

## Practice: read before the explanation

From `UIVoliSticker.request()`, the important shape is:

```gdscript
if _baked.has(key):
    return
for pending in _queue:
    if str(pending.get("key", "")) == key:
        return
_queue.append({...})
if not _working:
    _pump()
```

Try to answer:

- Which two checks prevent duplicate work?
- Which variable is persistent member state?
- What causes processing to start?
- Does this function wait for the sticker to finish before returning?

The answers are visible from syntax alone once the constructs above are familiar:

- cache lookup and queue scan prevent duplication;
- `_working`, `_queue`, and `_baked` are persistent members;
- `_pump()` starts when no worker is active;
- `request()` itself queues work; completion is announced later through a signal.

That is the reading skill the rest of the textbook will keep developing.