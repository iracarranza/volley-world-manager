# 01 — The Original Phase Resolver

Status: **HISTORICAL**

Understanding the old resolver is useful because much of today's migration work exists to remove specific limitations without throwing away a functioning game.

## Phase-first structure

The original `RallySimulator.resolve()` effectively knew the expected volleyball sequence in advance:

```text
serve
→ reception
→ set
→ attack
→ block/defence
→ continuation
```

Each phase selected actors, calculated quality/outcome, emitted an event and handed a simplified result to the next phase.

This produced playable volleyball quickly, but it created a structural bias:

> the next event was often known before the physical state that should have produced it.

## Why that matters

If a reception resolver first decides “setter receives this pass,” it is tempting to construct a trajectory ending at the setter.

Then:

- intended recipient becomes physical endpoint;
- en-route interceptions do not exist;
- a shank must be a named outcome category;
- an overpass needs a special branch;
- bodies can be reset between phases because only the next actor matters.

The simulator can still produce plausible statistics while the causal story is wrong.

## `live_positions` was an important intermediate step

The resolver did not remain purely table-based. It gained increasingly meaningful spatial state: live positions, movement timing, coverage, setter/hitter arrival, block geometry and continuation.

That is why the current project did **not** replace `RallySimulator` wholesale.

There was already valuable, tested volleyball logic inside it.

The migration strategy became:

```text
identify one authority boundary
→ build truthful shared state/system
→ compare against legacy
→ certify
→ promote carefully
```

rather than rewrite everything and lose behavioral evidence.

## Events were overloaded as convenient state

Because `RallyEvent` already contained positions/trajectory metadata for playback, it was easy for later code to treat those fields as simulation truth.

That blurred:

```text
resolved record for presentation
vs
persistent physical state
```

The newer architecture makes that boundary explicit.

## Endpoint semantics were overloaded

Fields such as trajectory destination/end height historically carried several meanings:

- where display should draw the next contact;
- where the intended recipient was;
- where a projectile would physically terminate;
- what height the next action expected.

Those meanings are not interchangeable.

The contact/free-flight work is partly a long process of splitting them into honest facts.

## Phase resets hid continuity

If each phase rebuilds its actors from selected positions, a blocker who is airborne/recovering can become fresh on the next phase unless recovery/body state is explicitly carried.

That is the defect later fixed by actor continuity work.

Again, the clock could be correct while the body was not.

## Category-first outcomes

Older platform paths often had outcome categories/bands that produced a destination/apex appropriate for the category.

That is useful for rapid game design, but it reverses the desired architecture:

```text
old tendency:
attributes → result category → trajectory decoration

current target:
attributes/tactics → intent/execution
ball+body → feasibility
contact → outgoing ball
trajectory/interactions → result category
```

## Why preserve this history

The old architecture is not simply “bad code.” It solved an earlier problem:

- make a management game's rally loop work;
- expose meaningful attributes/tactics;
- generate complete playable points;
- provide presentation records.

Its limitations became visible only as fidelity requirements increased.

This is useful maintenance context: do not judge an old abstraction without understanding which stage of the project needed it.

## Recognizing legacy authority today

When auditing current code, look for patterns such as:

```text
outcome label chosen before physical ball
recipient passed as trajectory endpoint
phase starts by resetting bodies to tactical coordinates
presentation metadata reconstructed into gameplay input
family-specific apex/destination band
```

These patterns are not automatically bugs—the surrounding system may still be the certified authority—but they are signs to inspect against the roadmap.

## Reading exercise

Open the old textbook chapter `part_04_match_engine/01_current_rally_pipeline.md` and compare it with current Part IV.

Identify which claims are now:

- still structurally true;
- superseded by actor continuity;
- superseded by M4 platform physics;
- superseded by M5 free-flight/interception;
- still future M7 work.

That comparison is itself a map of the project's evolution.

## Source trail

- `scripts/simulation/rally_simulator.gd`
- old textbook `part_04_match_engine/`
- `docs/review/FORWARD_WALK_ATTACK_CHAIN.md`
- `docs/design/CONTACT_AND_BALL_FLIGHT.md`

Next: how shadow systems allowed new architecture to be measured beside the live resolver before it was trusted with outcomes.