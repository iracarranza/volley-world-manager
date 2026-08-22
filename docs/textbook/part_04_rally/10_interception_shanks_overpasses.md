# 10 — Interception, Shanks, Overpasses, and Continuation

Status: **VERIFIED CURRENT BOUNDARY — M5 IN PROGRESS**

M5 exists because a physical outgoing launch is only useful if the rest of the rally respects where that ball actually goes.

The core distinction is:

```text
intended recipient
≠ physical endpoint
≠ actual interceptor
```

## Same-side interception

After a controlled dig produces an authoritative free flight, `FreeFlightInterceptionSystem.opportunities()` searches the flight over time for each available actor.

A player can therefore contact a ball **en route** rather than only at its natural floor endpoint.

This fixes a structural limitation of endpoint-based second-contact logic: a shank can pass within reach of a teammate even though that teammate could never reach the eventual landing point.

## Opportunity search

The system:

1. determines the uncontrolled terminal/time range;
2. samples times along the flight;
3. asks the movement/contact system whether each actor can reach that ball position/height at that time;
4. refines the first reachable boundary numerically;
5. returns physical opportunity records.

If tactical intent anchors are supplied, it can search the feasible window for the opportunity closest to intent rather than blindly taking the first playable instant.

Selection among actors still belongs to rally responsibility/decision policy.

## Successful dig does not guarantee next contact

M5 development certification includes cases where:

- intended setter has no opportunity;
- another player intercepts;
- nobody intercepts and ball reaches floor;
- an overpass crosses legally.

That is precisely the point: the ball owns the consequence.

## Failed dig produces no ball

A failed physical platform contact must not emit a hidden replacement trajectory just so the rally can continue.

This gives a strong invariant:

```text
contact fails to create playable launch
→ no outgoing authoritative ball
```

## Net crossing

A free flight can reach the net plane. The system reports whether the ball:

- fails at the net;
- legally crosses;
- reaches another terminal.

A legal crossing does not itself decide what the opponent does.

At the current architecture it can become `crossed_net_unresolved`, which is handed to the overpass first-contact layer.

## Overpass semantics

The approved policy is:

> a legal overpass becomes the receiving side's ordinary first team contact.

Pipeline:

```text
authoritative incoming free flight
→ legal crossing
→ receiving actors from live state
→ physical control/attack opportunities
→ volleyball legality
→ action choice
→ execution
→ receiving contact #1
→ one outgoing ball
```

There is no overpass-specific outcome table.

## Current certified live boundary

As of the latest inspected active-branch handoff:

- constructed shared overpass action selection is certified;
- **control/emergency-control** is wired through both live unresolved-overpass exits;
- those branches build actors from authoritative live position/velocity/facing/recovery/commitment state;
- the generated outgoing physical ball enters existing continuation machinery;
- constructed live fixture proves one outgoing contact #1 and immutable incoming launch;
- ordinary-rally census still produced no natural overpass in 1,200 rallies, so the resolver change was byte-neutral there;
- `ENABLE_PHYSICAL_PLATFORM_DIG` remains false;
- the **attack** live continuation is the remaining open integration at this snapshot.

This is a good example of why constructed fixtures matter: zero natural incidence does not invalidate a legal branch.

## Overpass attack reuses ordinary attack machinery

`OverpassActionSystem.execute_attack()` calls the existing geometric attack resolver using actual hitter/contact/blocker/defender state.

The open work is not to invent attack physics. It is to map the resulting swing/ball into the same block → floor-defence → continuation/terminal handling used by normal attacks.

An overpass attack must not become an automatic kill merely because it is aggressive.

## Contact #1 bookkeeping

When persistent `RallyState` is used, `apply_first_contact()` advances to contact time, registers the receiving side's contact and launches the new ball.

Because possession changed at the net crossing, `register_contact()` resets contact number to 1.

Action type does not change that:

```text
controlled overpass contact = contact #1
attack on overpass          = contact #1
```

## Why overhead/set-like first contact is excluded

The current set resolver contains assumptions about second-contact hitter selection/intent/contact state.

Therefore a player who physically could use hands on first contact is **not** currently admitted by simply relabeling that action `SET`.

The honest choices are:

- generalize the contact form later; or
- leave it unavailable now.

The project chose the latter for M5.

## M5 exit condition

M5 can close when the project can demonstrate, across relevant live paths:

- launch independent of later interceptor;
- exact realized prefixes;
- truthful same-side interception/terminal;
- legal crossing into ordinary opponent first-contact action;
- live control + attack continuation symmetric/certified;
- no hidden replacement ball;
- no presentation reconstruction/launch mutation.

## Safe debugging

If an interception looks wrong, do not begin with outcome rates.

Trace:

```text
source launch
→ flight at candidate time
→ actor availability
→ movement/reach opportunity
→ claimant/choice
→ realised prefix
→ next launch
```

Check units and timestamps at every boundary.

## Source trail

- `scripts/simulation/free_flight_interception_system.gd`
- `scripts/simulation/overpass_action_system.gd`
- `scripts/simulation/rally_simulator.gd`
- `docs/review/FREE_FLIGHT_INTERCEPTION.md`
- `docs/review/OVERPASS_ACTION_HANDOFF.md`
- `docs/design/CONTACT_AND_BALL_FLIGHT.md`

Next: what M5 deliberately does *not* implement yet—the broader action space across contacts 1/2/3.