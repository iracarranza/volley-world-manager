# 05 — Safely Extending an Existing System

Status: **VERIFIED METHOD**

The hardest maintenance task is rarely writing a function. It is adding behavior without accidentally creating a second architecture beside the first.

This chapter is the practical end-state of the book: how to approach an unfamiliar VWM change yourself.

## Start with the behavior, not the file

Suppose the goal is:

> add setter dumps.

Do not begin by searching for a convenient place to insert `if setter_dump`.

Translate the feature into system questions:

```text
When is the action legal?
When is it physically feasible?
What information does the setter have?
How is it chosen against setting?
Which existing contact physics can execute it?
Where does the outgoing ball go next?
How is it presented/classified?
```

Now the likely owners become visible.

## Find the nearest existing architecture

Most new features should reuse an existing path.

Examples:

```text
new clickable card
→ existing Control/theme/component patterns

new persistent career field
→ Resource + to_dict/from_dict migration

new platform context
→ shared PlatformContactModel

new attack opportunity
→ existing attack resolver/contact flight

new visual pose
→ simulation/event state → PlayerActor3D presentation
```

Prefer extension over parallel implementation.

## Write an authority map

Before coding, write the pipeline in one line.

For a rally action:

```text
state/perception
→ action availability
→ choice
→ contact execution
→ outgoing ball
→ continuation
→ event/presentation
```

For a management system:

```text
manager input
→ durable state
→ system update
→ report/UI
→ downstream match/training consumer
```

Mark which existing function/class owns each arrow.

Anything you cannot place is a likely design question.

## Separate plumbing from policy

Plumbing connects already-governed semantics:

- forwarding an authoritative trajectory;
- mapping an existing resolver result into existing continuation;
- copying carried body state;
- serializing a new already-defined field.

Policy decides meaning:

- which keep-alive launch coverage should prefer;
- whether a tactical instruction prioritizes one action family;
- how a new contract/service changes player state.

Do not stop ordinary plumbing because it looks unfamiliar. Do not silently invent policy because the plumbing needs an answer.

## Reuse physical mechanisms, not result labels

If a future “attack on two” is physically an ordinary attack from an unusual contact number, reuse attack feasibility/execution.

Do not add a bespoke `SECOND_BALL_ATTACK_POWER_MULTIPLIER` unless a real physical/design relation requires one.

Likewise, a new UI surface should reuse the style/component vocabulary rather than copying colours/margins into a new screen.

## Add state at the right lifetime

Ask how long the fact exists.

```text
one function call
→ local variable

one rally
→ RallyState / RallyPlayerState / event evidence

one match
→ match/team/player match state

career
→ player/team/CareerState/staff/world persistence

presentation only
→ UI Node/component state
```

Putting a career fact in a screen or a one-contact fact on `VolleyballPlayer` creates lifecycle bugs.

## Design APIs around semantic inputs

Prefer:

```gdscript
resolve_contact(actor, incoming_ball, intent)
```

conceptually over:

```gdscript
resolve_contact(is_good_pass, force_shank, desired_outcome)
```

The first API exposes causes; the second exposes the result the caller wants.

When you find yourself passing outcome labels downward into physics, reconsider the boundary.

## Preserve information boundaries

A decision can only use facts the actor/system should know at that time.

Do not let:

- blocker choice read final attack target before commitment;
- player movement target read the resolved pass endpoint before perception;
- scouting UI read exact hidden potential when confidence is low;
- presentation reconstruction feed physical state.

A convenient field is not automatically legal information.

## Add the smallest new vocabulary

Do not create a new class/enum/constant for every feature name.

Ask whether the new behavior is:

- a new semantic action;
- a new physical contact form;
- a new decision preference;
- a new state;
- merely a new presentation/classification label.

A “pancake” might initially be an emergency-contact presentation form using existing keep-alive semantics. A joust likely requires genuinely new interaction authority. Those deserve different architectural weight.

## Build the fixture before broad tuning

Create a deterministic case where the new feature clearly should appear.

For a setter dump:

```text
setter at net
ball reachable on contact #2
legal front-row state
set option also feasible
known blocker/defence positions
```

Then prove:

- dump can be offered;
- illegal/unreachable dump is excluded;
- chosen dump uses ordinary attack/ball continuation;
- contact number remains correct;
- setting remains available where it should.

Only later ask how often dumps occur in normal matches.

## Audit downstream consumers

A new output can expose assumptions far away.

Physical digs exposed overpasses. A new action-on-two may expose code that assumes every second contact emits `SET`. A new event type may break saved statistics keyed by event names.

Search consumers of:

- event type;
- contact number;
- trajectory metadata;
- player role;
- serialization keys;
- UI switch/match statements.

This is why “implementation complete” and “integration complete” differ.

## Keep docs proportional to authority

When you add:

- implementation detail → comments/tests may be enough;
- new public data contract → update relevant architecture chapter/reference;
- new design policy → update design authority doc;
- certified promotion → update roadmap/review ledger.

Do not create duplicate documents that each become an independent source of truth.

## Know when to stop

A good maintainer can distinguish:

```text
I need to understand existing code
→ investigate and continue

I found a bug/test failure
→ diagnose and continue

I need to choose between materially different game semantics
→ policy decision

I need a new unmeasured physical magnitude
→ calibration/authoring boundary
```

The last two are genuine reasons to stop and make the decision explicit.

## A complete extension worksheet

Before a consequential feature, fill this out:

```text
GOAL:

CURRENT OWNER/PATH:

NEW SEMANTIC FACT:

STATE LIFETIME:

LEGALITY:

PHYSICAL FEASIBILITY:

DECISION/POLICY:

EXECUTION MECHANISM:

OUTGOING/RESULTING STATE:

DOWNSTREAM CONSUMERS:

PRESENTATION:

FOCUSED FIXTURE:

INVARIANTS:

BROAD REGRESSION:

DOC AUTHORITY TO UPDATE:
```

If several boxes cannot be answered from current code/design, investigate before editing.

## Graduation exercise

Choose a bounded real backlog item that is **not** currently being changed by another branch.

Without asking an AI to write the solution:

1. trace the current system;
2. identify the owner;
3. write the authority map/fixture/invariants;
4. implement a small change;
5. run focused + broad checks;
6. inspect the diff;
7. explain why the change belongs where you put it.

Use AI afterward as a reviewer if useful. The point is that the architecture is now legible enough for you to form and test your own model first.

## Final principle

Across UI, management and rally simulation, the same maintenance rule recurs:

> **Represent the cause in the layer that owns it, then let downstream systems derive and display the consequence.**

That is the shortest description of VWM's current architectural direction.

## Source trail

Return to whichever subsystem chapter owns the feature, then inspect current source + design/review authority before coding.