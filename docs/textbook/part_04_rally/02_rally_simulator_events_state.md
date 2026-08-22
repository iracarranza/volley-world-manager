# 02 — RallySimulator, Event Records, and Authoritative State

Status: **VERIFIED / CURRENT HYBRID ARCHITECTURE**

`RallySimulator` is still the orchestration center of ordinary rally resolution. The important nuance is that VWM is **mid-migration**: some physical/state systems are modernized and certified, while the top-level resolver still contains explicit phase/continuation branches.

Do not simplify this into either “everything is legacy” or “a fully continuous scheduler owns the whole rally.” Neither is true yet.

## What `RallySimulator` does

At a high level it coordinates:

```text
serve
→ first contact
→ second contact
→ attack
→ block / floor defence
→ dig / continuation
→ repeat or terminal point
```

It carries live player-position/recovery maps, invokes specialized systems, creates `RallyEvent` records, advances rally time and chooses the appropriate continuation branch.

The roadmap is progressively moving more of the *facts inside those branches* into shared causal state/physics.

## `RallyEvent` is a record

`RallyEvent extends Resource` and stores fields such as:

- event type;
- actors;
- start/end positions;
- quality/success;
- headline/detail;
- metadata.

An event answers:

> What resolved action should later consumers know about?

It is used by playback/statistics/analysis, but it is not the ball or player's body itself.

VWM boundary:

```text
simulation resolves fact
→ RallyEvent records fact
→ playback reads event
```

not:

```text
playback-friendly event endpoint
→ decides what physically happened
```

## Event names can hide semantic differences

The code history includes a useful example: floor `DIG` and `ATTACK_COVERAGE` had once shared a `DEFENSE` event label. That made downstream statistics conflate two very different situations.

Separating event vocabulary matters because events are an explanation/API layer. But changing the event label alone does not create different physics.

## `RallyState`

`RallyState` is a compact persistent-state model containing:

```text
simulation_time
possession
contact_number
home/opponent RallyPlayerState dictionaries
RallyBallState
lineups/plans
active play
logs/events
```

Its methods demonstrate what state mutation looks like explicitly:

```gdscript
func register_contact(side: StringName, player_id: int) -> void:
    if side != possession:
        possession = side
        contact_number = 1
    else:
        contact_number += 1
```

This is important for newer systems such as overpass first-contact handling: crossing to the other team changes possession and the next legal team contact is contact #1 regardless of whether that contact is control or attack.

## Why the live resolver still has parallel data structures

The ordinary resolver predates full `RallyState` authority and still carries structures such as live positions, velocities and recovery maps directly.

Newer integrations often **construct `RallyPlayerState` views from those authoritative live maps** at a boundary rather than reconstructing players from presentation data.

That is transitional plumbing, but it obeys the central rule:

> build the modern physical query from the live simulation's current facts, not from what the renderer happened to draw.

## Snapshots

`RallyState.snapshot()` and `RallyPlayerState.snapshot()` create copied state useful for comparison/inspection.

A snapshot should preserve the state as it existed without subsequent mutation leaking backward.

This is why mutable nested dictionaries/actors need explicit copies while some immutable/reference-like configuration can remain shared.

## Phase branch versus physical authority

A branch such as “after dig, resolve transition” can still be structurally phase-based while the outgoing ball inside it is authoritative free flight.

These are different dimensions of migration:

```text
rally sequencing architecture
vs
physical fact ownership inside each transition
```

M4/M5 are currently advancing the second aggressively. M7 later addresses true overlapping per-player action timelines.

## How to read RallySimulator without drowning

Do not read the file top-to-bottom.

Trace one boundary:

```text
incoming trajectory
→ claimant/action selection
→ contact execution
→ outgoing trajectory
→ continuation call
```

Then identify:

- which values came from live state;
- which specialized system made the decision;
- which function mutates bookkeeping;
- where the event is recorded;
- where the next branch begins.

Search function names/callers rather than scrolling.

## Authority checklist

When you encounter a value in `RallySimulator`, ask:

1. Is this current simulation truth, an intent, an estimate, or presentation metadata?
2. Who produced it?
3. Is it being copied across a boundary or recomputed?
4. Does a later branch mutate the source record?
5. Could the same fact be represented twice?

This catches most hidden-authority mistakes.

## Current overpass example

At the current certified boundary, a physically legal overpass can be evaluated as the opponent's ordinary first contact. The **control** branch is live-wired at both unresolved-overpass exits and then handed to existing continuation machinery. The attack branch is still being integrated/certified.

This is a good example of hybrid architecture: a modern action chooser/physical free-flight system feeds an older top-level continuation path without letting that continuation rewrite the source launch.

## Source trail

- `scripts/simulation/rally_simulator.gd`
- `scripts/models/rally_event.gd`
- `scripts/models/rally_result.gd`
- `scripts/models/rally_state.gd`
- `scripts/models/rally_player_state.gd`
- `scripts/models/rally_ball_state.gd`
- `docs/design/RALLY_MILESTONES.md`

Next: the ball itself—why a launch is now a physical record independent of who eventually reaches it.