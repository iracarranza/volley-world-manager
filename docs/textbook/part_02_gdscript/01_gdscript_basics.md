# P2-C1 — GDScript Basics

Status: **VERIFIED** language concepts; snippets marked **EXAMPLE**
Keywords: class_name, extends, preload, var, const, func, static typing
Primary sources: `scripts/models/rally_event.gd`; `scripts/simulation/coverage_calculator.gd`

## Reading the top of a script

```gdscript
class_name RallyEvent
extends Resource
```

`class_name` registers a reusable type. `extends` chooses the parent type and therefore the abilities the class begins with.

```gdscript
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
```

`const` cannot be reassigned. `preload` loads a known resource when the script is parsed, so a wrong path causes an early error.

## Variables and types

```gdscript
var rally_clock: float = 0.0
var live_positions: Dictionary = {}
```

The text after `:` is the expected type. Static typing helps Godot detect mistakes before the affected branch runs.

## Functions

```gdscript
func player_state(side: StringName, player_id: int) -> RallyPlayerState:
    return null
```

Inputs appear inside parentheses. The type after `->` is the return type. Indented lines form the body.

## Instance and static functions

An instance function uses one object's state:

```gdscript
state.advance_to(1.2)
```

A static function behaves like a named calculation:

```gdscript
var distance := CoverageCalculator.court_distance_meters(start, target)
```

## Beginner reading strategy

For any function, write down:

1. inputs;
2. state read;
3. calculations performed;
4. state changed;
5. return value;
6. callers.

This turns a long function into a manageable contract.
