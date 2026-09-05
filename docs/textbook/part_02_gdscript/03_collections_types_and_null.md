# P2-C3 — Collections, Types, and Null

Status: **VERIFIED** language concepts
Keywords: Array, Dictionary, typed array, null, casting, get, property access, schema drift, parser error
Primary sources: `scripts/models/rally_state.gd`; `scripts/simulation/rally_movement_system.gd`; `scripts/models/rally_result.gd`

## Prerequisites

- [P2-C1 GDScript Basics](01_gdscript_basics.md) — typing and inference
- [P2-C2 Resources, Nodes and Signals](02_resources_nodes_and_signals.md) — the `analysis: Dictionary` escape hatch this chapter is about

## Learning goals

After this chapter you should be able to:

1. choose between a typed Resource and a Dictionary, and justify it;
2. read a Dictionary key safely and know when you are allowed not to;
3. name every place `null` enters this codebase;
4. explain why casting is not validation;
5. diagnose a parser error from its message rather than by bisecting.

## Vocabulary

| Term | Meaning |
|---|---|
| **Typed array** | `Array[Foo]` — an array that rejects anything else. |
| **`Variant`** | "Any type." The absence of a constraint. |
| **Schema** | The set of keys a Dictionary is expected to carry. |
| **Schema drift** | Keys quietly diverging between writer and reader. |
| **Safe read** | `dict.get(key, default)` — cannot fail. |
| **Contract read** | `dict.key` — asserts the key exists. |
| **Cast** | `value as Type` — reinterprets, or yields `null`. |

---

## 1. Arrays

### 1.1 Ordered collections

An Array is an ordered collection. Typed arrays constrain their contents:

```gdscript
var opportunities: Array[ActionOpportunity] = []
```

Use arrays for ordered events, candidates, players, and scheduled moments.

### 1.2 Typed versus untyped

```gdscript
var a := []                        # untyped Array
var b: Array[ActionOpportunity] = []   # typed
```

The typed version rejects a wrong class **at the moment of insertion**, which is
where you want to find out. The untyped one accepts anything and fails later, in
a consumer, with a message about a missing property.

> **The inference trap.** `:= []` gives you an *untyped* array. If you want a
> typed one you must write the type explicitly. This is the single most common
> way a typed collection silently becomes untyped.

### 1.3 Positional indexing is a contract you did not write down

Reading `parts[2]` assumes position 2 means something. It does — until someone
inserts an element.

> **Worked failure.** `FaceExpressions.parts()` returned eyes then mouth, and the
> validator asserted `face_parts[2]` was the mouth. Pupils were later interleaved
> after each eye, so `parts()` began returning
> `[EyeL, PupilL, EyeR, PupilR, Mouth]`. Every positional assertion silently
> retargeted, and the "mouth" check began testing the right eye. **Nothing
> errored.** The fix was to key by name.

**Index positionally only when the length is fixed by a type you control.**

---

## 2. Dictionaries

### 2.1 Key-value collections

```gdscript
var positions := {player_id: court_position}
```

### 2.2 Safe reads and contract reads

Read uncertain keys safely:

```gdscript
var duration := float(metadata.get("movement_duration", 0.0))
```

Direct property-like access assumes the key exists:

```gdscript
var duration := metadata.movement_duration    # asserts
```

Use the second **only when the contract guarantees the key**. The distinction is
a communication: `.get(k, default)` says *this may be absent and here is what
that means*; `.key` says *its absence is a bug, fail loudly*.

> **Choose deliberately.** Wrapping everything in `.get()` with a plausible
> default is how a missing key becomes a wrong number instead of an error. A
> defaulted `0.0` that should have been a duration will not crash — it will
> produce a contact that takes no time.

### 2.3 The conversion wrappers

```gdscript
float(metadata.get("movement_duration", 0.0))
int(data.get("body_type", 0))
str(part.get("name", ""))
Dictionary(spec.get("torso", {}))
```

These are not noise. A Dictionary value is a `Variant`, so the wrapper both
converts and documents the expected type. `Dictionary(...)` additionally
**copies**, which is how [P2-C1 §4.2](01_gdscript_basics.md) prevents callers
mutating a constant.

---

## 3. Typed Resources versus Dictionaries

### 3.1 The rule

Use a **typed Resource** for important, long-lived concepts with a stable
schema. Use a **Dictionary** for flexible metadata or small local return
bundles.

The persistent rally work creates typed state models partly because a whole
evolving simulation is too important to hide behind speculative Dictionary keys.

### 3.2 What a Dictionary actually costs

| Property | Typed Resource | Dictionary |
|---|---|---|
| Typo in a field name | Parser error | Silent `null` or default |
| Field list discoverable | Yes, in the class | Only by reading writers |
| Renaming a field | Compiler finds callers | Manual search |
| Serialisation | Defined | Ad hoc |
| Cost of adding a field | Edit the class | Free — which is the problem |

**"Free to add a field" is the danger.** A Dictionary grows keys nobody removes,
written by one site and read by another that assumes a slightly different
schema.

### 3.3 Recognising drift

Symptoms, in the order you will meet them:

1. two `.get()` calls for the same concept with different key spellings;
2. a default that is never correct but is never hit "in practice";
3. a consumer reading a key no live writer sets.

The cure is to promote the bundle to a typed Resource. The cost of doing so
rises with every week you wait.

---

## 4. Null

### 4.1 What it means and where it comes from

`null` means no object. In this codebase it enters from:

- an empty lineup slot;
- a missing assignment;
- a failed player lookup;
- an unavailable candidate;
- a failed cast (§5);
- an optional parameter left at its default — for example
  `team_principles: Resource = null` in `RallySimulator.resolve`.

### 4.2 Checking before access

```gdscript
if player == null:
	return unavailable_result
var name := player.display_name
```

### 4.3 Designing null out

The better move, where you can, is to make absence impossible or unmistakable:

- return an **empty collection** instead of `null` — callers can iterate either
  way;
- use an **impossible sentinel**, like `decisive_actor_id = -1`
  ([P2-C2 §1.3](02_resources_nodes_and_signals.md));
- return a **result object** carrying a validity flag.

> **Why it matters here.** A rally resolves thousands of times in a test sweep.
> A `null` check that is merely *usually* right will surface as one failed run in
> two hundred, on a seed nobody can reproduce.

---

## 5. Casting

### 5.1 The syntax

```gdscript
var player := raw_value as VolleyballPlayer
```

### 5.2 Casting is not validation

If the value is not compatible, the result is `null` — it does not raise. So a
cast **converts an unknown type into an unknown-but-null-checkable value**, and
you still have to check.

```gdscript
var player := raw_value as VolleyballPlayer
if player == null:
	return   # the cast failed, or the value was already null — you cannot tell
```

Note what you cannot distinguish: a wrong type and an absent value both yield
`null`. If that distinction matters, test it before casting.

---

## 6. Parser errors: a diagnosis table

Run the headless scan after structural changes rather than waiting for the
affected screen to open:

```bash
godot --headless --path . --import
```

| Message or symptom | Usual cause | Fix |
|---|---|---|
| Inferred type too broad | `:=` where an explicit type was needed | Declare the type |
| Typed Array receives wrong class | `:= []` produced an untyped array | `: Array[Foo] = []` |
| Unexpected indent | Tabs and spaces mixed | Match the file — this project uses tabs |
| Unexpected token at line end | Missing `\` continuation | Add it |
| Cannot find `preload` path | Renamed or moved file | Fix the path |
| Property not found on static type | Field is on the Dictionary, not the class | `.get()` or add the field |
| ~200 unrelated errors after adding a class | Stale class cache | `--import` |
| `--check-only` flags `GameManager` undeclared | Autoloads are not visible to it | Not a real error |

The last two are worth memorising; both look catastrophic and neither is.

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| `:= []` for a typed collection | Wrong types accepted silently |
| `.get(k, 0.0)` for a required value | A missing key becomes a wrong number |
| Positional indexing into a grown array | Assertions silently retarget |
| Treating a cast as validation | `null` flows onward |
| Dictionary for a long-lived concept | Schema drift |
| Trusting `--check-only` on autoloads | Chasing a non-error |

---

## 8. Check yourself

1. `var xs := []` then `xs.append(some_string)` into what should be `Array[Foo]`. When do you find out? *(Later, in a consumer, as a missing-property error.)*
2. When is `metadata.duration` better than `metadata.get("duration", 0.0)`? *(When absence is a bug you want to fail loudly.)*
3. Why did the mouth assertion start testing an eye? *(Pupils were interleaved; positional indices retargeted silently.)*
4. A cast returns `null`. What are the two possible causes? *(Wrong type, or the value was already `null` — indistinguishable afterwards.)*
5. You add a `class_name` and get 200 errors across unrelated files. *(Stale class cache — run `--import`.)*

---

## Where this leads

- [P3-C2 Debugging, Testing and Git](../part_03_workflow/02_debugging_testing_and_git.md) — finding the non-determinism these mistakes cause
- [P4-C2 Persistent Rally State](../part_04_match_engine/02_persistent_rally_state.md) — why that work chose typed models over Dictionaries
- [P7-C1 The Voli Body](../part_07_art_and_assets/01_the_voli_body.md) — a system built entirely from Dictionary specs, and how it copes
