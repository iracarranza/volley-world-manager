# P2-C3 — Collections, Types, and Null

Status: **VERIFIED** language concepts
Keywords: Array, Dictionary, typed array, null, casting, get, property access
Primary sources: `scripts/models/rally_state.gd`; `scripts/simulation/rally_movement_system.gd`

## Arrays

An Array is an ordered collection. Typed arrays constrain their contents:

```gdscript
var opportunities: Array[ActionOpportunity] = []
```

Use arrays for ordered events, candidates, players, and scheduled moments.

## Dictionaries

A Dictionary maps keys to values:

```gdscript
var positions := {player_id: court_position}
```

Read uncertain keys safely:

```gdscript
var duration := float(metadata.get("movement_duration", 0.0))
```

Direct property-like access such as `metadata.movement_duration` assumes the key exists. Use it only when the contract guarantees the key.

## Typed Resources versus Dictionaries

Use a typed Resource for important, long-lived concepts with a stable schema. Use a Dictionary for flexible metadata or small local return bundles. The persistent rally work creates typed state models partly because a whole evolving simulation is too important to hide behind speculative Dictionary keys.

## Null

`null` means no object. Common sources include an empty lineup slot, missing assignment, failed player lookup, or unavailable candidate.

Check before property access:

```gdscript
if player == null:
    return unavailable_result
var name := player.display_name
```

## Casting

```gdscript
var player := raw_value as VolleyballPlayer
```

If the value is not compatible, the result can be null. Casting is not validation.

## Common parser problems

- inferred type is too broad for a strict assignment;
- a typed Array receives the wrong class;
- indentation is inconsistent;
- a multiline expression lacks a continuation;
- a preload path is wrong;
- a property name does not exist on the static type.

Run the headless editor scan after structural changes rather than waiting for the affected screen to open.
