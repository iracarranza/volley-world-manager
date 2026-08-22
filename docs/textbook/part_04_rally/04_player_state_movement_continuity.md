# 04 — Player State, Movement, and Continuity

Status: **VERIFIED / CONTINUITY FOUNDATION PROMOTED**

A believable rally requires the same athlete to remain the same physical actor across contacts.

VWM represents that actor with `RallyPlayerState`:

```text
player identity
position / velocity / facing
movement mode
body state / balance
intent + target
commitment / recovery times
tactical home / responsibility
```

## Movement mode is not body state

`MovementMode` describes the form of movement:

- IDLE
- LATERAL
- TRANSITION
- APPROACH
- BLOCK_CLOSE
- RECOVERY

`BodyState` describes physical condition:

- BALANCED
- MOVING
- REACHING
- DIVING
- AIRBORNE
- RECOVERING

Those axes answer different questions. A player can be in a recovery movement process because their body is recovering; an approach movement can lead to an airborne state.

Avoid replacing both with one vague `ready` number.

## `readiness` was removed

The class comments document that a former `readiness` field was initialized to 1.0 and never meaningfully written.

Rather than invent semantics to justify it, the field was deleted and its supposed consequences were expressed through real state already present:

- airborne/diving/recovering can gate actions;
- balance affects reach/contact;
- approach quality affects takeoff.

This is a good architecture lesson: unused abstraction is not automatically a missing mechanic.

## Facing means preparation orientation

`facing` is explicitly the direction the feet/hips are set—not gaze, target or current route.

Ready facing is mirrored by side so both teams initially face the net.

The architecture avoids “face the live ball automatically,” because that would give the body information/preparation it has not earned.

## Movement form decides whether facing changes

`movement_establishes_facing()` returns true for APPROACH and TRANSITION, which are opened-up running forms.

Lateral shuffle/block close can preserve orientation while moving sideways.

So `apply_position()` updates facing from velocity only when the current movement mode says the movement physically establishes a new orientation.

This replaced a naïve `facing = velocity` rule that made backpedalling defenders face away from play.

## Availability is temporal

`is_available(at_time)` checks:

```gdscript
at_time >= committed_until and at_time >= recovery_until
```

A player can stand geometrically near a ball and still be unable to act because their body is committed/recovering.

This separation was important in overpass fixtures: standing reach overlap alone must not publish an opportunity for an unavailable actor.

## Movement is time, not distance alone

`RallyMovementSystem` and `LocomotionModel` calculate traversal from player-specific movement profiles rather than teleporting anyone who is “close enough.”

Movement can include:

- acceleration/top speed relationships;
- direction-change cost;
- movement mode;
- body/contact reach;
- time available before ball contact.

The exact model remains simplified; what matters architecturally is that time and physical state constrain opportunity.

## Tactical home is an intent destination

`RallyPlayerState.tactical_home` is not a command to reset the actor to a formation coordinate after every phase.

It is a desired destination/reference.

```text
home assignment
→ movement intent
→ body travels if time allows
```

not:

```text
new phase
→ body teleports home
```

## The actor-continuity defect

Earlier, `RallySimulator` rebuilt fresh phase state from live positions/velocities while recovery/body information existed elsewhere. A blocker could therefore physically be landing/recovering in the rally clock but appear fresh to a later contact envelope.

The continuity repair seeded new phase actor states from carried recovery/body information.

Certification showed the state actually fired in ordinary rallies while outcomes remained unchanged where upstream recovery exclusion had already prevented action.

This is a classic correctness migration:

> fix the model even when the immediate scoreline does not move.

## Snapshot semantics

`RallyPlayerState.snapshot()` copies physical/intent/recovery state while keeping the underlying `VolleyballPlayer` profile reference.

That is sensible because the rally-state actor is the transient physical wrapper; the player Resource is the career/profile identity.

## Continuous action is not finished

Continuity across phase boundaries is not yet the same as fully continuous overlapping action.

M7 later aims for:

- setters moving while first contact is still flying;
- hitters beginning approaches before set release;
- blockers/defenders establishing while reads evolve;
- early arrivals waiting instead of movement being stretched to fill flight time.

Current continuity is the prerequisite that makes that possible.

## Safe modification

If adding a new physical state:

1. decide whether it is movement form, body condition, intent, or timing debt;
2. define who writes it;
3. ensure it survives every phase reconstruction/snapshot that should carry it;
4. identify which action/physics systems consume it;
5. add a fixture where the state changes feasibility;
6. test that unrelated actors do not inherit it.

## Reading exercise

Trace `recovery_until` from the moment a player becomes compromised through the next phase's actor construction and an opportunity query.

Then trace `facing` the same way. Explain why “carried correctly but currently inert in a particular defensive path” is not the same as a continuity bug.

## Source trail

- `scripts/models/rally_player_state.gd`
- `scripts/simulation/rally_movement_system.gd`
- `scripts/simulation/locomotion_model.gd`
- `scripts/simulation/rally_simulator.gd`
- `docs/review/ACTOR_CONTINUITY.md`
- `docs/review/MOVING_ORIENTATION.md`
- `docs/review/READINESS_REMOVAL.md`

Next: once several bodies could reach the ball, how perception/responsibility and action choice decide who actually tries.