# 03 — Ball Contact and Authoritative Free Flight

Status: **VERIFIED / M5 IN PROGRESS**

One of the largest architectural changes in VWM is the shift from **event-to-event destination scripting** toward an authoritative outgoing launch.

The central rule is:

> A contact decides the ball's launch. The next player does not decide where that launch “must have gone.”

## Old mental model to avoid

A common sports-sim shortcut is:

```text
player A passes to setter B
→ choose B as recipient
→ draw a ball path ending at B
```

That makes the recipient part of ball physics. A shank cannot pass near another teammate, fall short, sail long or cross the net unless special cases are authored.

## Current physical model

The newer model is:

```text
contact state + chosen action
→ launch velocity
→ authoritative free flight
→ physical opportunities along flight
→ actual interceptor OR natural terminal
```

Intent can influence the selected launch, but intent is not the realized endpoint.

## `Vector3` launch velocity

Physical launch uses a 3D velocity:

```text
x = across court
 y = vertical
 z = along court
```

Gameplay court positions are often stored as normalized `Vector2`, so conversion through court dimensions is needed when moving between normalized court coordinates and metres.

**GDScript reminder:** `Vector3` is simply three floats plus vector operations (`length()`, `normalized()`, dot products, etc.). Its meaning comes from the coordinate convention the subsystem defines.

## `FreeFlightInterceptionSystem.from_launch()`

Given:

- contact court position;
- contact height;
- launch velocity;
- start time;
- flight ID;

`from_launch()` solves the unconstrained projectile flight until floor contact.

It stamps metadata including:

- `trajectory_role = authoritative_free_flight`;
- authoritative flight ID;
- launch velocity/speed/angle;
- gravity;
- natural end position/time/reason.

That record is the source flight.

## Free flight versus realized segment

If another player contacts the ball before the natural floor endpoint, the played path is a **prefix** of the same flight.

`realised_prefix()` derives that segment without mutating the source flight.

```text
SOURCE FREE FLIGHT
A ------------------------------ floor

ACTUAL PLAY
A -------- B contact
```

The fact that B touched the ball early does not retroactively change A's launch.

This gives VWM a strong certification invariant:

> source launch fields remain byte/semantically identical after downstream interception.

## Why flight IDs matter

The authoritative flight ID links a realized segment back to the launch it came from.

That makes it possible to test:

```text
segment.authoritative_flight_id == source.authoritative_flight_id
```

and compare launch metadata.

An ID is not physics itself; it is provenance.

## Ball position and velocity at time

The free-flight system can derive:

- `position_at_time()`;
- `height_at_time()`;
- `velocity_at_time()`.

Horizontal velocity stays constant in the shared projectile model; vertical velocity advances under gravity.

This means a later contact can consume the **actual incoming velocity at that instant**, rather than reconstructing incoming pace from two convenient endpoints.

## Natural terminal

A free flight may encounter:

- floor/out terminal;
- net interaction/crossing boundary;
- later player interception.

The physical system reports those facts; action policy determines what a team does when a playable situation exists.

A legal net crossing is especially important: it should not be treated as “the flight ended, therefore rally over.” It creates a situation for the other team.

## BallTrajectory and RallyBallState

`RallyBallState` stores the currently launched `BallTrajectory`, position, velocity, height, predicted landing information and last-touch/contact bookkeeping.

Its `update_at(simulation_time)` asks the trajectory where the ball is at that time.

`RallyBallState` is a state container; `FreeFlightInterceptionSystem` is one of the systems that constructs/query richer authoritative free-flight records during the current migration.

## Presentation curves are not authority

Older/display code can use Bezier/control points to make a path easy to draw. The physical free-flight code deliberately does not treat a display-only bend as gameplay truth.

VWM boundary:

```text
resolved launch / projectile
→ gameplay path
→ presentation may sample/draw it
```

not:

```text
pretty curve
→ physical opportunities
```

## Intended recipient is diagnostic/decision context

A platform contact may intend a setter/target anchor. That matters when selecting a launch inside the physical envelope.

After launch:

```text
intended setter misses
→ another teammate may intercept
→ or ball may hit floor/cross net
```

All are legitimate consequences.

## Why this unlocks emergent volleyball

Once the ball exists independently:

- shanks can be saved;
- intended recipients can miss;
- alternate teammates can take second contact;
- overpasses emerge from launch physics;
- free balls can fall unexpectedly;
- later action choices can be based on the actual situation.

Without free-flight authority, each of those requires a special outcome category.

## Safe modification

When changing ball-flight code, certify:

1. launch state is fully defined;
2. units are consistent;
3. free flight does not depend on recipient identity;
4. realized segments are exact prefixes;
5. later contacts do not mutate source launch;
6. display metadata is downstream;
7. terminal/crossing classification is derived from the flight.

## Source trail

- `scripts/simulation/free_flight_interception_system.gd`
- `scripts/simulation/ball_flight_model.gd`
- `scripts/models/ball_trajectory.gd`
- `scripts/models/rally_ball_state.gd`
- `docs/design/CONTACT_AND_BALL_FLIGHT.md`
- `docs/review/FREE_FLIGHT_INTERCEPTION.md`

Next: the moving bodies that may—or may not—reach that free flight.