# Scripted rally architecture map

The scripted-rally driver is an **intent adapter**, not a simulator. It may
select the actors and destinations passed to `RallySimulator`, but it must not
integrate a ball, move a player, or manufacture a contact. `RallySimulator`
remains the owner of contact resolution and `BallFlightModel` remains the owner
of flight geometry.

## Production ownership

| Concern | Existing owner | Scripted seam |
| --- | --- | --- |
| Court coordinates | `CourtConstants` and resolver-normalized `Vector2` values | Input is normalized once during validation. |
| Action vocabulary | `RallyEvent.EventType` / `RallyActionVocabulary` | Authored names map to existing event classes; they do not create new classes. |
| Contact quality | `RallySimulator` contact resolvers, including `_set_terms()` | The driver removes only `_execution_error()` variance. An explicit `quality_override` may replace the final quality for a single probe. |
| Ball flight | `BallFlightModel` and trajectories emitted by `RallySimulator` | Every authored contact consumes the previous recorded endpoint and supplies intent for the next production flight. |
| Player movement | `RallyMovementSystem`, phase maps, and the simulator's live positions | Waypoints are requests. Reachability is resolved by production movement; an unreachable waypoint is a refusal, never a snap. |
| Playback and record | `RallyResult`, `RallyEvent`, and playback adapters | The saved record is audited, not reconstructed from the fixture. |

## Boundary invariants

1. There are exactly twelve distinct roster identities and exactly one initial
   normalized court position for each.
2. Contact times are strictly increasing. Movement intervals may overlap them,
   but a waypoint is not itself a contact.
3. A target is either an existing voli id or one normalized court coordinate.
4. Each contact declares `contact_height_m`.
5. An incoming recorded trajectory must end at the same coordinate and time at
   which the outgoing trajectory begins. A saved-sequence seam census checks
   records rather than trusting fixture input.
6. Invalid or physically impossible intent returns a reason string. It is not
   repaired by changing the actor, action, target, or contact time.

`ScriptedRallyDriver.validate()` implements the schema half of this boundary.
Physical feasibility belongs at the production resolver seam and must return its
reason before any partial result is published.

