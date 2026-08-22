# 06 — Physical Feasibility and Contact Geometry

Status: **VERIFIED**

VWM's physical layer answers a deliberately limited set of questions:

```text
Can this athlete get to the contact in time?
Can their current body state make the contact?
What broad outgoing ball is physically possible?
```

It is not intended to be a full rigid-body biomechanics simulator.

## `ActionOpportunity`

Movement/contact systems represent possible actions with explicit timing and geometry rather than with a Boolean “reachable.”

An opportunity can carry facts such as:

- contact time;
- contact position/height;
- body travel/contact position;
- reach margin;
- arrival balance/feasibility;
- whether a jump is required;
- action type.

A later chooser can then compare viable opportunities without recalculating physics differently for each tactical policy.

## Arrival is not contact

A body need not move its centre to the ball. The contact point may be offset by arm/reach geometry.

M3 made this explicit for platform contacts:

```text
ball contact point
← arm reach offset →
body centre
```

This prevents the simulation from treating every successful reception/dig as the player's torso occupying the exact ball coordinate.

## Movement time + reach

`FreeFlightInterceptionSystem` samples/refines times along a flight and asks `RallyMovementSystem.evaluate_opportunity()` whether an actor can make a contact at that position/time/height.

The physical query combines:

```text
where body starts
+ how body can move
+ time available
+ body/contact reach
+ jump availability if allowed
+ recovery/commitment availability
```

This is much richer than endpoint-distance checks.

## Numerical constants versus physical constants

The free-flight search uses values such as sample count and bisection/refinement steps.

Those are **numerical resolution** parameters. Their job is to find a boundary accurately, not describe volleyball.

They must not be tuned to achieve a desired dig/kill rate.

This distinction appears repeatedly in VWM:

```text
numerical parameter
→ accuracy/performance of calculation

physical/game abstraction
→ model of world behavior

balance/policy value
→ choice/preferences/economy
```

Do not mix them.

## Availability is independent of reach overlap

An actor who is still committed/recovering can geometrically overlap the ball and still be unavailable.

This is why `FreeFlightInterceptionSystem` checks `actor.is_available(at_time)` before publishing an opportunity.

Physical feasibility is the intersection of several facts, not one distance test.

## Contact envelope versus execution

For platform play, the shared model first defines a **feasible envelope**: pace ceiling and reachable redirection directions.

Then intent selection chooses a desired launch *inside* that space, and technique error produces a realized launch that is projected back into the feasible envelope.

So poor execution cannot create a ball the body was physically incapable of producing.

The same architectural pattern can generalize to other contacts:

```text
feasible set
→ chosen target/action
→ execution variation constrained by feasible set
```

## Body state and balance

A stretched/moving/recovering body can have a narrower or worse-quality contact than a planted balanced one.

The physical system should consume body/contact state already derived by movement, not infer “difficult” from an outcome label.

For example:

```text
bad dig result
→ should be consequence of difficult contact/execution

NOT
DIG_SHANK category
→ invent difficult physics afterward
```

## Contact height belongs to the contact

A platform contact needs the actual height where the athlete meets the ball. An attack needs its swing contact height. A block has its own reach/contact relation.

Endpoint/default display height is not a substitute.

This is especially important when deriving incoming vertical velocity: projectile state depends on actual contact time/height.

## Rules are adjacent, not physics

Back-row/libero restrictions do not change whether a player's hand can physically reach the ball. They change whether a particular action is **legal**.

Keep:

```text
physical feasibility
rules legality
```

as separate filters that both must pass.

## Derived values before authored values

When a missing relation can be derived from existing geometry/units, prefer that derivation.

Examples from the current architecture:

- body/contact offset from shoulder + arm length + contact height;
- projectile velocity at a contact time from launch + gravity;
- net crossing from the same flight;
- movement-facing change from movement form rather than an arbitrary angle threshold.

If a magnitude cannot be derived/measured and the design truly needs it, name the authoring/calibration boundary explicitly instead of hiding it inside a formula.

## Safe physical change

For any new feasibility relation:

1. state the physical question in words;
2. list inputs and units;
3. determine what is already measured/derived;
4. isolate any authored abstraction;
5. prove monotonic/edge behavior with constructed fixtures;
6. keep event/result labels out of the physical relation;
7. measure live consequence only after correctness is established.

## Reading exercise

Follow one `FreeFlightInterceptionSystem._opportunity_at()` call into `RallyMovementSystem.evaluate_opportunity()`.

Write down:

- what comes from the ball;
- what comes from the actor;
- what comes from action type;
- what is a numerical search detail;
- what is returned to decision policy.

## Source trail

- `scripts/models/action_opportunity.gd`
- `scripts/models/action_opportunity_window.gd`
- `scripts/simulation/rally_movement_system.gd`
- `scripts/simulation/contact_envelope_system.gd`
- `scripts/simulation/free_flight_interception_system.gd`
- `scripts/models/rally_player_state.gd`
- `docs/review/BODY_CENTRE_SCOPE.md`

Next: how the already-certified serve, set and attack families fit this causal pipeline.