# 05 — Perception, Responsibility, and Action Choice

Status: **VERIFIED ARCHITECTURE / SOME ACTION SPACE DEFERRED**

A ball can be physically reachable by several players. Reachability alone should not decide volleyball responsibility, and responsibility alone should not override physics.

VWM separates these questions:

```text
what does the player/team perceive?
→ who is responsible / should claim?
→ what actions are legal and physically feasible?
→ which feasible action is chosen?
```

## Perception is not truth

Systems such as `BallReadSystem` can build a player's estimate of ball destination/timing from authoritative flight truth plus information quality.

The simulation can therefore contain both:

```text
true ball state
player's estimate of ball state
```

without changing the real ball to match the estimate.

This is the same pattern used in scouting: truth exists; an observer receives bounded knowledge.

## Responsibility is not nearest-player wins

The short-ball responsibility work established an ordering principle:

```text
assignment/responsibility
→ physically feasible controlled contact
→ relationship/tie-break among viable claimants
```

Proximity informs feasibility, but does not automatically purchase ownership.

A nominal receiver who cannot make a usable contact may transfer responsibility; a nearby teammate should not be locked out by a fictional assignment.

## Immediate control requires usable time

One defect came from an “immediate control” lock that could claim a ball even when the nominal player had no positive usable time to make the contact.

The repair required `available_time > 0.0` rather than inventing another distance/quality threshold.

That is a good example of a semantic gate:

> if there is no time, the action is not available.

## Decision systems operate after feasibility

`RallyDecisionSystem` increasingly owns shared action-choice logic such as ordinary first-contact availability.

This means a system can compare options without redefining whether the body can physically perform them.

General target architecture:

```text
attributes + tactics + perception
→ preference / intent / decision

ball + body + rules
→ feasible action set

choice among intersection
```

## Overpass is the clearest current example

`OverpassActionSystem.choose()` takes:

- authoritative free flight;
- current `RallyPlayerState` actors;
- lineup/side;
- team principles.

It asks `FreeFlightInterceptionSystem` separately for control and attack opportunities after a legal net crossing, applies attack legality, then ranks candidates from existing physical/ability/judgment/tactical information.

There is **no fixed “attack always beats control” rule**.

This is important because the action type emerges from the situation/player/team rather than from an `OVERPASS` event label.

## Legal feasibility is separate again

An actor can physically reach an attacking contact but be legally ineligible for that attack because of rotation/role restrictions.

So action availability is:

```text
physical opportunity
∩ volleyball legality
```

Only legal+physical candidates reach the decision ranking.

## Tactical principles affect attempts, not physics

Team principles such as decisiveness/transition commitment can make an attack more or less attractive in an overpass contest.

They should not widen the player's reach or platform redirection cone.

This is one of VWM's key architecture invariants:

> physics says what can happen; attributes/tactics say what players try and how well they execute it.

## Contact number is context

A current first-contact overpass can be attacked or controlled. This proves that:

```text
team_contact_number == 1
≠ action must be RECEPTION
```

The ordinary receive → set → attack sequence should eventually be common because it is good volleyball, not because event number hard-codes the action.

The full generalization belongs to M6/M7; do not assume every future action is implemented now.

## Responsibility and choice can use different vocabularies

“Who should take this ball?” and “what should that player do with it?” are separate decisions.

A system may first identify a claimant and then choose between feasible contact forms—or a shared action contest may jointly rank actor+action candidates where that better represents the situation.

Do not force every decision into one universal weighted chooser merely for consistency. Share the facts/semantics that are truly common.

## Avoid policy hidden inside physics helpers

A physical system should not contain rules such as:

```text
if overpass: prefer attack
if coverage: pop toward setter
```

Those are volleyball decision policies.

Likewise a decision system should not declare an impossible launch feasible because a tactic strongly wants it.

## Safe extension: new action

For a future setter dump or set-on-one:

1. define legality;
2. define which physical contact form can execute it;
3. expose feasibility from current ball/body state;
4. define what information the player has when choosing;
5. add it to the relevant action-choice layer;
6. execute through shared contact physics;
7. let outgoing ball determine consequence;
8. classify afterward.

Do not add `if action == DUMP: chance_to_score = 0.35` as the core mechanic.

## Reading exercise

Read `OverpassActionSystem.choose()` and separate each operation into:

- physical query;
- legality;
- perception/ability/tactical scoring;
- deterministic tie-break;
- source-flight bookkeeping.

Then explain why `execute_control()` and `execute_attack()` are separate from `choose()`.

## Source trail

- `scripts/simulation/rally_decision_system.gd`
- `scripts/simulation/ball_read_system.gd`
- `scripts/simulation/free_flight_interception_system.gd`
- `scripts/simulation/overpass_action_system.gd`
- `docs/review/SHORT_BALL_RESPONSIBILITY.md`
- `docs/design/RALLY_ACTION_SPACE.md`

Next: the physical envelope itself—how body/contact geometry says whether a chosen action can happen.