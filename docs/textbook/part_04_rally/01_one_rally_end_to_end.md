# 20 — One Rally from Serve to Terminal Ball

Status: **CURRENT ARCHITECTURE OVERVIEW**

A rally in VWM is no longer best understood as a fixed script that says:

```text
serve
→ receive
→ set
→ attack
→ block
→ dig
```

That sequence is still the common volleyball pattern, but the architecture is moving toward something more general:

```text
ball exists
↓
players perceive / become responsible
↓
legal + physically feasible actions are identified
↓
player/tactical choice selects among them
↓
attributes determine execution quality
↓
contact produces one authoritative outgoing ball
↓
that ball flies independently
↓
whoever can actually intercept it becomes the next possible contact
```

The difference is important. The simulator should not decide that "the setter receives the dig" and then manufacture a trajectory ending at the setter. It should produce the dig's outgoing ball and let the next contact emerge from where that ball actually travels.

## The current migration position

The canonical roadmap is `docs/design/RALLY_MILESTONES.md`.

At the current checkpoint:

- M0–M3 are closed;
- M4 physical platform contact is partly promoted and still open;
- M5 authoritative free-flight/interception is built in development and being integrated into live continuations;
- coverage selection remains the next known policy boundary;
- M6 will audit action semantics across all contact numbers/families.

So this chapter teaches the **architectural direction and current authority boundary**, not an imaginary finished M10 simulator.

## Two things exist at once: state and event records

One of the easiest mistakes is to treat a `RallyEvent` as "the rally itself."

It is not.

`RallyEvent` is a Godot `Resource` that records information about an action for consumers such as playback, statistics, and diagnostics:

```gdscript
class_name RallyEvent
extends Resource

@export var event_type: EventType
@export var actor_id: int
@export var start_position: Vector2
@export var end_position: Vector2
@export var success: bool
@export var quality: float
@export var metadata: Dictionary
```

**Godot reminder — Resource**

A `Resource` is a reusable/data-oriented Godot object that does not need to live in the SceneTree. That makes it a good shape for a record describing what happened.

But "record describing what happened" is different from "object whose fields decide what is physically possible next."

That distinction is central to the current rally rewrite.

## `RallyState` carries authoritative simulation information

The newer rally architecture uses `RallyState` as a typed container for live simulation state:

```gdscript
class_name RallyState
extends RefCounted

var simulation_time: float = 0.0
var possession: StringName = &""
var rally_over: bool = false

var home_players: Dictionary = {}
var opponent_players: Dictionary = {}
var ball := RallyBallState.new()

var contact_number: int = 0
```

A `RallyState` can answer questions an event record cannot:

- what time is it in the rally?
- which side currently has possession?
- what is the ball doing now?
- what is each player's current state?
- how many team contacts have occurred in the current possession?

**GDScript reminder — `RefCounted`**

`RallyState` does not need to be a Node in the SceneTree. It is runtime simulation data, so a lightweight `RefCounted` object is appropriate.

## Contact counting is state, not an event-name rule

`RallyState.register_contact()` currently implements a simple important rule:

```gdscript
func register_contact(side: StringName, player_id: int) -> void:
    if side != possession:
        possession = side
        contact_number = 1
    else:
        contact_number += 1
```

Read the function causally:

```text
new side touches ball
→ possession changes
→ this is contact 1 for that possession

same side touches again
→ increment contact number
```

The contact number describes **where the team is in its legal sequence**.

It should not permanently mean:

```text
1 = reception
2 = set
3 = attack
```

The newer action-space design explicitly separates those ideas. A first contact can sometimes be an attack; a second can be a dump/attack; a third can be a controlled return.

See `docs/design/RALLY_ACTION_SPACE.md`.

## Time advances with the ball

`RallyState.advance_to()` updates simulation time and then advances the ball:

```gdscript
func advance_to(new_time: float) -> void:
    simulation_time = maxf(new_time, simulation_time)
    ball.update_at(simulation_time)
```

This short function contains a major design principle:

> rally time should move forward, and ball state should be evaluated at that same authoritative time.

The broader roadmap describes ball travel time as the master clock around which player movement, reads, arrivals, and contacts must fit.

A player cannot be allowed to "arrive because the next event needs them there" if the available ball flight does not give them enough physical time.

## A contact should produce a ball before it produces the next event

The current target relation is:

```text
incoming ball
+ body/contact state
+ selected action
+ execution quality
→ outgoing launch
→ authoritative free flight
```

Only then should the simulator ask:

```text
who can intercept this?
what legal actions are available there?
what does that player choose?
```

This is why M4 and M5 overlap.

Once a physical dig was allowed to produce its own launch, some balls no longer arrived neatly at the intended setter. That was not a bug to tune away; it exposed the need for M5 to let free flight determine the actual next opportunity.

## Intended recipient is intent, not physical truth

A player may try to pass toward a setter.

That intended recipient is useful information:

```text
what did the player mean to do?
```

But it cannot answer:

```text
who actually contacted the ball next?
```

The newer free-flight work has already certified cases where:

- the intended setter cannot reach the ball;
- another teammate intercepts it en route;
- nobody controls it and it reaches the floor;
- the source launch remains unchanged regardless of the later interceptor.

That is the architectural shift from a scripted event chain to a causal rally.

## Physics and decision have different jobs

A compact VWM rule is:

```text
attributes + tactics
→ perception / responsibility / intent / action choice

ball + body state
→ physical feasibility

attributes
→ execution quality inside feasible space

contact physics
→ outgoing ball

free flight / interaction
→ what actually happens next
```

Do not blur these layers.

Examples:

- physics may say a player **cannot** attack this ball from their current body state;
- tactics may make an eligible player **prefer** a controlled contact over an attack;
- technique may change how accurately the selected action is executed;
- the resulting launch may still be intercepted by a different teammate/opponent.

## Platform contact shows the architecture most clearly

M4's shared platform model has three relations:

```text
T1 — outgoing speed / pace transfer
T2 — physically reachable redirection envelope
T3 — selected-to-realized angular execution error
```

These are shared physical relations, not separate "reception physics" and "dig physics."

The contact family/context supplies body state, intent, and circumstance; the shared model constrains what launch is possible.

This is a concrete example of a reusable simulation system replacing event-name-specific outcome bands.

## Overpasses show why action type cannot be hard-wired

A physical platform contact can send the ball across the net.

Under the approved design, that overpass becomes the opponent's ordinary **first team contact**.

The receiving side may have multiple feasible actions:

```text
attack
controlled first contact
emergency first contact
```

There is no hard rule that says "overpass means reception" or "overpass means automatic attack."

Instead:

```text
legal + physically feasible actions
→ player/tactical contest
→ chosen action
```

This is the first production-facing proof of the broader M6 idea that **contact number is context, not action type**.

## `RallyEvent` still matters

Moving authority into state/physics does not make events useless.

Events are how the resolved simulation can explain itself to other layers:

```text
authoritative simulation
→ RallyEvent record
→ playback / history / statistics / explanation
```

That direction matters.

The dangerous reversal would be:

```text
playback-friendly event fields
→ treated as physical truth
→ simulation forced to match presentation
```

VWM has repeatedly removed or fenced off that kind of accidental presentation authority.

## Snapshots and copying

`RallyState.snapshot()` creates a copy of important rally state, including snapshots of player state and ball state.

This is useful when a system needs a stable record of a moment without continuing to mutate the same object.

Notice the difference between:

```gdscript
copy.events = events.duplicate()
copy.decision_log = decision_log.duplicate(true)
```

The `true` requests a deeper duplicate for nested data in the decision log.

**GDScript reminder — references and mutation**

Objects/collections may be shared by reference. If you think you made a historical snapshot but actually kept references to mutable nested objects, later changes can rewrite your "past." Deep vs shallow copying therefore matters in diagnostics and deterministic simulation.

## The current resolver is still transitional

Do not over-read the existence of `RallyState` and assume the whole match already runs as one pristine event-agnostic scheduler.

The current `RallySimulator` still contains substantial phase-oriented orchestration, and some phase states are reconstructed. Recent continuity work made critical body/recovery/facing state survive those boundaries honestly rather than being silently reset.

This is why the roadmap distinguishes:

```text
M0–M5 causal authority work
from
M7 continuous per-voli actions across event boundaries
```

The project is progressively removing false boundaries rather than pretending they are already gone.

## How to trace a rally yourself

When reading source, do not start by trying to understand the entire `rally_simulator.gd` file.

Pick one ball transition, for example:

```text
successful controlled dig
→ outgoing platform launch
→ free flight
→ interception
```

Then trace:

1. where the dig/contact intent is published;
2. where physical feasibility and launch are resolved;
3. what object represents the outgoing ball/flight;
4. what system searches for interception;
5. what state changes when the next player contacts it;
6. what `RallyEvent` is emitted afterward.

That method scales much better than reading the resolver linearly.

## A diagnostic question set

Whenever a rally result looks wrong, ask:

```text
Was the wrong player made responsible?
Was an impossible action considered feasible?
Was the right action chosen but executed poorly?
Was the outgoing launch wrong?
Was the flight correct but intercepted incorrectly?
Was simulation correct and only playback wrong?
```

Those are different bug classes.

The architecture is designed specifically so they can be distinguished.

## What to retain

The central model for the rest of Part IV is:

```text
state is authority
intent is not outcome
contact creates a ball
ball flight exists independently
actual interception creates the next opportunity
events record what happened for consumers
```

The next chapters unpack each of those statements into concrete VWM classes and functions.