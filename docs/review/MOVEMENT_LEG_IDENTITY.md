# Repair 4: one journey, one name, across an intermediate contact

Gate criterion eight -- *whether a movement continues across an intermediate
contact* -- was the one the gate said genuinely wanted a consolidated record.
`DIG_BUDGET_AND_WINDOW.md` then measured it: a floor defender's chase begins at
the hitter's contact and is drawn in the window that begins at the block, and the
difference is a mean 0.2058 s of swing spent before the net.

**It wanted one field, not a record.**

## The contract addition

Two keys, both derived in `_stamp_physical_times` where `physical_time` is known,
so the leg's start and the clock playback reads cannot drift apart:

```text
movement_start_time  = physical_time - movement_available_seconds
movement_leg_id      = "<actor_id>@<start_time, 3dp>"
```

Neither is a decision. The budget is what the resolver already spent on the
journey, so subtracting it from the contact is the journey's start by definition,
and the id is that start plus the body it belongs to. Published wherever a budget
is -- RECEPTION, DIG, ATTACK_COVERAGE -- and absent elsewhere rather than faked.

## What playback does with them

`_issue_early_legs` looks one contact past the one this window ends on. If that
contact's leg *starts inside this window*, the actor is put on it now, with
`delay_seconds` equal to the difference of two published times, and the
resolver's own endpoint and duration unchanged. When the leg's own window
arrives, `_legs_issued_early` says the body is already on that journey and the
remaining duration is drawn from wherever it visibly got to.

`_legs_issued_early` is a `Dictionary` of `player_id -> leg_id`. That is the whole
of the journey identity the gate asked for.

**One override rule needed a judgement and it is recorded here.** A phase target
the resolver named for this window normally outranks an early leg. The floor
defender behind a block is the exception: `home_phase_targets` on the BLOCK event
is `floor_phase_positions.duplicate(true)`, a *snapshot* of the shape they took
during the set flight, so it is a hold rather than a journey. A hold within
`BASE_RETURN_DEADBAND_METERS` of where the body already stands yields to the
chase the same body is about to make; a real phase journey does not.

## Measured

`tools/probe_movement_plan.gd`, reading the real `MatchScreen`, 40 rallies:

| | |
|---|---:|
| windows whose following contact publishes a leg start | 9 |
| of those, starting inside this window | 8 |
| legs issued early | **8** |
| legs continued in the window that owns their contact | **8** |
| **legs issued early more than once** | **0** |

Issued once, continued once, never twice. The handoff's "movement consumed
exactly once" is now a counted property rather than an argument.

Two suite checks hold it: every budgeted leg is named and starts exactly its
budget before its contact, and no two journeys in one rally share a name.

**Outcomes are unchanged.** The balance probe over 700 rallies is byte-identical.

## Why only 9 windows, when 159 of 175 digs overrun

Both numbers are right and they count different things. 159 of 175 is *dig pairs
whose budget exceeds their window*. 9 is *windows in which that journey's start
falls*, and a leg can only be issued early where an earlier drawn window exists
to issue it in. The ATTACK→BLOCK window is real -- mean 0.140 s, 217 of 254 above
5 ms -- but the DIG is not always the contact that follows the BLOCK, and a
window of zero length is skipped by playback before any plan is built.

So the mechanism covers the cases it can reach and the remainder are journeys
whose earlier stretch has no drawn window at all. Those are still drawn
compressed, and `playback_leg_overspeed` still counts them: 30 in 40 rallies.
That is the honest state and it is a smaller, better-located problem than "the
budget and the window disagree".
