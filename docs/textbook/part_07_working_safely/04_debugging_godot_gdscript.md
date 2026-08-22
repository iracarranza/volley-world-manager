# 04 — Debugging Godot and GDScript

Status: **VERIFIED PRACTICE**

Debugging VWM gets easier when you classify the failure before changing code.

A useful first split is:

```text
source will not load
runtime object/state is wrong
scene/layout/rendering is wrong
simulation authority/semantics are wrong
measurement tool is wrong
```

These problems can look similar from the player's point of view but require different instruments.

## Parser errors

A parser error means Godot could not turn the script into executable code.

Common causes:

- indentation/syntax mistake;
- malformed multiline expression;
- type inference cannot determine a value;
- invalid annotation/type;
- dependency script failed to parse first.

Start with the **first relevant error and source line**. Later errors may be consequences of the first file failing to load.

## Type inference and `:=`

`:=` asks GDScript to infer a static type from the right-hand expression.

This is convenient:

```gdscript
var actor := RallyPlayerState.new()
```

But inference can fail or become less clear around dynamic Dictionaries/Variants.

In those cases, be explicit:

```gdscript
var actor: RallyPlayerState = value as RallyPlayerState
var row: Dictionary = data.get("row", {})
```

The goal is not maximum annotation. It is making the contract unambiguous where the runtime value is broad.

## Null-instance errors

A message like “attempt to call function on a null instance” means the reference you expected to hold an object is `null`.

Trace where the reference came from:

```text
get_node/get_node_or_null
Dictionary.get
array lookup
cast with `as`
factory/create function
resource load
```

Do not merely add `if value != null` unless null is an honest state. If the object is required, find why construction/lookup failed.

## Invalid property/key access

GDScript mixes strongly named object properties with dynamic Dictionary keys.

Examples:

```gdscript
player.reception
row.get("reception", 0)
```

A misspelled object property may be caught earlier; a Dictionary key can silently return a default.

When debugging dynamic records, inspect the actual keys/value types rather than trusting the expected schema.

## Casting with `as`

```gdscript
var player := value as VolleyballPlayer
```

returns the typed object when compatible and can yield `null` when it is not.

So a cast can turn “wrong object type” into a later null error. Check the cast boundary when a typed reference unexpectedly disappears.

## Scene-tree problems

Typical Godot UI/runtime issues include:

- node path changed;
- dynamically created Node not yet in tree;
- child order changed draw order;
- signal connected twice/not connected;
- node freed while a callback/tween still references it;
- Local scene tree differs from Remote runtime tree.

Use the **Remote** tree while the game is running. It shows the actual instantiated hierarchy, including code-created screens and components.

## Lifecycle timing

Common callbacks:

```text
_init
→ object construction

_enter_tree
→ node joins SceneTree

_ready
→ node and children are ready

_process(delta)
→ every rendered frame

_physics_process(delta)
→ fixed physics cadence
```

VWM also uses `call_deferred()` and `await get_tree().process_frame` when work must happen after layout/render state exists.

A value being “correct one frame later” is often a lifecycle/layout problem, not a reason to add arbitrary delays.

## Signals

If clicking does nothing:

1. verify the Button/control receives input;
2. find the signal `.emit()` or built-in `pressed` signal;
3. find `.connect()`;
4. confirm connection happens once and object still exists;
5. put a breakpoint/temporary print at producer and consumer;
6. inspect whether the callback exits early.

Do not move the action directly into the button just because a connection is broken.

## UI layout debugging

For a Control with bad size/position inspect:

- parent Container;
- anchors/offsets;
- `custom_minimum_size`;
- size flags;
- theme content margins;
- text wrapping/minimum size;
- visibility;
- whether code changes these after `_ready()`.

Remember: a Container can overwrite manual child positions.

## Rendering/shader debugging

Separate geometry from material:

1. temporarily disable/remove shader/material;
2. inspect underlying Control/mesh bounds;
3. verify theme/palette input;
4. inspect shader uniforms;
5. compare light/dark theme;
6. compare window sizes;
7. check caches/baked textures.

A stale sticker cache can make correct new pose code appear ineffective.

## Simulation debugging: trace the first wrong fact

If a rally result looks impossible, do not start at the terminal label.

Trace backward:

```text
terminal result
← outgoing ball / interaction
← contact execution
← selected action
← feasible opportunities
← live actor/ball state
```

Find the **earliest factual divergence**.

If the ball launch is already wrong, changing floor-defence logic cannot repair authority.

## Seeded debugging

Capture/reuse the seed and fixture state whenever possible.

A probabilistic bug that cannot be replayed is expensive to reason about. A deterministic fixture lets you inspect the same branch repeatedly while changing one cause.

Be careful: seeded RNG alone does not guarantee deterministic replay if player/career state mutates between runs.

## Printing is useful when structured

Temporary debug output should name fields/units:

```text
player=17 contact_t=1.328s reach_margin=0.22m available=true
```

not:

```text
17 1.328 .22 true
```

For repeated/large investigations, build a probe or structured trace instead of accumulating prints inside production logic.

## Breakpoints and debugger

Godot's script editor supports breakpoints and variable inspection. Use them for a narrow runtime path, especially UI signals/lifecycle.

For large simulation sweeps, headless deterministic probes are usually more efficient than stepping every rally frame.

Choose the instrument for the scale.

## Warning noise

A noisy project makes real regressions hard to see. But do not “fix” unrelated warnings destructively while working on another branch/task.

Record known unrelated warnings and keep focused diffs. Clean them in an owned change when appropriate.

## A debugging worksheet

For a stubborn issue, write:

```text
SYMPTOM:

FIRST KNOWN CORRECT FACT:

FIRST KNOWN WRONG FACT:

OWNER OF THAT FACT:

REPRO/FIXTURE:

EXPECTED INVARIANT:

ACTUAL:
```

This forces the investigation out of vague “the rally feels wrong” territory.

## Reading exercise

Choose one historical defect from a review doc. Classify it as parser/runtime/state/layout/authority/instrument failure and explain why the eventual fix belonged at that layer.

## Source trail

- Godot Output/Debugger/Remote SceneTree
- `tests/test_runner.gd`
- `tools/`
- `docs/review/`
- `docs/design/MEASUREMENT_CONFOUNDS.md`

Next: putting all of this together to extend an existing VWM system without creating a parallel architecture.