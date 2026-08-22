# 01 — Data Models and Resources

Status: **VERIFIED**

VWM uses Godot `Resource` objects for most persistent game data and plain calculation/system classes for most logic.

A useful first distinction is:

```text
Node
→ exists in the running scene tree
→ lifecycle, children, signals, rendering/input possible

Resource
→ data object
→ can be saved/loaded/duplicated
→ does not need to live in the scene tree

RefCounted/system class
→ lightweight code object or static calculation module
```

This is why `VolleyballPlayer`, `RallyEvent`, `CareerState`, `Team`, fixtures and similar records are Resources, while many evaluators extend `RefCounted` and expose static functions.

## Why Resources fit game data

A player needs to exist whether or not a player-card screen is open. A career needs to survive scene changes. A `RallyEvent` needs to carry resolved information without becoming a visual Node.

Those are data-lifetime problems, not scene-tree problems.

Example:

```gdscript
class_name VolleyballPlayer
extends Resource

@export var display_name: String = "Player"
@export_range(1, 100) var reception: int = 50
```

`@export` tells Godot this property belongs to the Resource's editable/serializable interface. `@export_range` also gives the Inspector a constrained editor.

**GDScript reminder:** annotations beginning with `@` modify how Godot treats the following declaration. They are not function calls executed each frame.

## Model versus system

VWM generally tries to keep these roles separate:

```text
VolleyballPlayer
→ stores ratings/state

VolleyballTrainingSystem
→ changes ratings according to training rules

AttributeProfileSystem
→ calculates summaries/capability views

UI
→ displays the resulting data
```

If a `Resource` starts accumulating every calculation that can ever involve it, the model becomes difficult to reason about. If every system duplicates player data, sources of truth drift.

## Exported fields are not all ability

A Resource can contain several kinds of facts:

- identity: name, role, region;
- physical measurements: height, wingspan, mass;
- ability ratings: reception, set accuracy, block timing;
- temperament/choice tendencies: ego, aggression;
- temporary state: fatigue, form, match confidence;
- long-term progress: attribute ceilings, training fractions;
- relationships/experience: satisfaction, weeks observed, position familiarity.

Do not infer semantics from “it is a number.” Read the field's comment and its consumers.

## Dictionaries as extensible structured data

VWM uses `Dictionary` when the keys are naturally dynamic or when a compact serializable record is useful:

```gdscript
@export var attribute_ceilings: Dictionary = {}
@export var training_progress: Dictionary = {}
```

A Dictionary is similar to a map/hash/dict in other languages.

```gdscript
var ceiling := int(player.attribute_ceilings.get("reception", player.potential))
```

`.get(key, default)` reads a value without assuming the key exists.

The tradeoff is weaker compile-time checking. A misspelled Dictionary key can remain invisible until runtime, so central key vocabularies and tests matter.

## Arrays and typed arrays

You will see both:

```gdscript
var events: Array[Resource] = []
var traits: Array[String] = []
var fixtures: Array[Resource] = []
```

Typed arrays communicate what belongs inside and let Godot catch some invalid assignments.

## `to_dict()` and `from_dict()`

Persistent models commonly translate themselves to/from plain Dictionaries.

Conceptually:

```text
runtime Resource
→ `to_dict()`
→ JSON-safe/simple data
→ file

file data
→ parse Dictionary
→ `from_dict()`
→ runtime Resource
```

This creates an explicit migration seam. `CareerState.from_dict()` can recognize old values and map them into the current model instead of requiring every old save to already match today's class layout.

## Deep versus shallow copying

You will often see:

```gdscript
metadata.duplicate(true)
```

The `true` requests a deep duplicate of nested containers where supported. This matters when a snapshot must not share mutable Dictionaries/Arrays with the source.

A shallow copy can produce a subtle bug:

```text
snapshot looks independent
→ nested Dictionary is shared
→ later mutation changes both
```

Part IV returns to this for rally snapshots.

## Resource references can intentionally be shared

Not every field needs deep copying. A snapshot may safely share an immutable/static plan or lineup reference while duplicating mutable physical state.

The question is not “always duplicate.” It is:

> Can either side mutate this object in a way that would make the other object's state dishonest?

## Enums

Godot enums give names to integer values:

```gdscript
enum EventType {
    SERVE,
    RECEPTION,
    SET,
    ATTACK,
}
```

Use the name in code. The underlying integer is an implementation detail unless persistence/API compatibility explicitly depends on it.

VWM has examples where enum order mattered for in-memory/debug consumers and names mattered for persisted statistics. That is why changing an enum deserves source tracing rather than casual reordering.

## `String` versus `StringName`

`String` is normal text. `StringName` is an interned identifier optimized for repeated engine-facing names/keys.

You may see:

```gdscript
var possession: StringName = &""
```

The `&"home"` syntax creates a `StringName` literal.

You do not need to convert every String to StringName. Use the type already established by the subsystem unless there is a reason to change its contract.

## Inspector data versus generated runtime data

An exported field *can* be edited in the Inspector, but many VWM players/careers are generated in code rather than hand-authored as `.tres` files.

So the Inspector is a way Godot understands the property—not proof that the project normally authors the value manually.

When tracing a value, find its writer.

## Source-of-truth rule

A good data model gives each fact one authoritative home.

Examples:

```text
player height
→ VolleyballPlayer

career week
→ CareerState

rally physical actor state
→ RallyPlayerState / carried live state

button appearance
→ Theme/style system, NOT career model
```

If you find two independent stored versions of the same fact, investigate whether one is a cache, snapshot, estimate or stale duplicate.

## Reading exercise

Open `scripts/models/career_state.gd`.

Choose one field from each category:

- identity;
- calendar;
- staff/scouting;
- world/Sixnet;
- persistence helper.

For each, find where it is written and where it is displayed/consumed.

## Source trail

- `scripts/models/volleyball_player.gd`
- `scripts/models/career_state.gd`
- `scripts/models/team.gd`
- `scripts/models/rally_event.gd`
- `scripts/models/rally_state.gd`
- `scripts/models/`

Next: the player model itself—how ability, role, temperament and state are kept separate.