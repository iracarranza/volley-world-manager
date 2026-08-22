# 12 — The M0–M10 Rally Roadmap

Status: **VERIFIED SNAPSHOT; CANONICAL STATUS LIVES IN DESIGN DOC**

The milestone roadmap is an ordering/dependency tool, not a second implementation.

Always check `docs/design/RALLY_MILESTONES.md` and the latest review handoff for exact current status. This chapter explains **what each milestone means**.

## Governing fidelity target

The project uses this practical standard:

> I can watch a normal rally and argue about the volleyball decision instead of arguing about whether the athlete could physically have been there.

That is why early milestones focus on causal physical/ownership foundations before tactical balance tuning.

## M0 — authoritative rally skeleton — DONE

Purpose: one causal rally chain exists from serve through continuation without parallel hidden replacement-ball architecture.

This established the skeleton later migrations could improve rather than creating a second simulator beside it.

## M1 — responsibility / defensive ownership — DONE

Purpose: responsibility is explicit and subordinate to feasibility; transfer/fallback and recovery debt are represented.

Key lesson:

```text
assignment
≠ guaranteed ownership
```

## M2 — physical preparation state — DONE, one locomotion relation deferred

Purpose: body facing/preparation is real state; fake `readiness` removed.

Movement form determines whether orientation changes. A more detailed defensive form/turn-speed relationship remains deferred rather than invented.

## M3 — body centre vs contact geometry — DONE

Purpose: the player's centre no longer has to sit on the ball to make a platform contact.

Contact height + shoulder/arm geometry derive body offset.

## M4 — physical platform contact — IN PROGRESS

Purpose: reception/dig/coverage forearm contacts share T1–T3 physics rather than event-family outcome bands.

Current broad state:

- intent publication: done;
- shared physical envelope/T1–T3: done;
- controlled-dig development rollout: built;
- coverage incoming/body/contact state: done;
- production promotion + legacy retirement: open;
- coverage keep-alive selection policy: known genuine blocker after M5 integration.

## M5 — authoritative free flight / interception — IN PROGRESS

Purpose: outgoing launch exists independently of future recipient/interceptor.

Development same-side dig free flight/interception is certified.

At the latest inspected active branch:

- overpass ordinary-first-contact policy/chooser is built;
- live **control** continuation is wired at both unresolved-overpass exits and certified with a constructed fixture;
- live **attack** continuation remains the open integration;
- physical platform dig production flag remains off.

When control+attack live continuation is symmetric/certified with no launch mutation/hidden ball, M5 can be reassessed for closure.

## Why M4 and M5 overlap

Milestone numbers are not hard walls.

Truthful platform contact exposed a downstream problem: a shanked physical launch needs free-flight/interception authority before production can safely use it.

So:

```text
M4 contact physics
↔ M5 downstream ball authority
```

The overlap is a dependency, not a planning mistake.

## Known next boundary — coverage selection

Coverage already has truthful physical input and a feasible T1–T3 envelope.

What is missing is the player's decision objective:

> among feasible keep-alive launches, what should a covering player value?

This must not be answered with a hidden fixed apex/forced setter/coverage-only physics band.

It is a decision-policy question and should be resolved from volleyball semantics + measured feasible choices.

## M6 — all-contact consistency + action semantics — PLANNED

Purpose:

- audit every contact/interaction against the same causal rubric;
- separate team-contact number from action type;
- support/generalize set/attack/control options across contacts;
- make block-touch continuation ordinary;
- handle joust/net rebound authority;
- apply legality consistently.

Certified serve/set/attack/block systems should be reused unless the audit demonstrates a real authority break.

## M7 — continuous per-voli actions / late commitment — PLANNED

Purpose: action/movement state persists and overlaps ball flight.

Examples:

- setter releases/moves during first ball;
- hitter begins approach before set contact;
- blocker read develops while approach/set cues unfold;
- early arrivals wait;
- preparation can preserve several plausible actions until commitment.

This is where deception can become information-bounded rather than a hidden bonus.

## M8 — canonical side-out certification — PLANNED

Purpose: a normal neutral side-out should look convincing without debug captions.

This is an integrated visual/volleyball test of all previous foundations.

## M9 — tactical A/B certification — PLANNED

Purpose: manager instructions create visible predicted differences through player interpretation/choice/feasibility—not direct outcome coefficients.

Examples should be interpretable as volleyball:

```text
more aggressive transition principle
→ different viable choices/commitments
→ different rallies
```

rather than “+8% kills.”

## M10 — presentation / legibility cleanup — PLANNED

Purpose: presentation reports the certified simulation cleanly.

Remaining pose/cognition/screen readability work belongs here when it is genuinely presentation-only.

Presentation must not invent facts to make an unresolved simulator look finished.

## Progress can be measured in more than milestone numbers

Useful secondary progress metrics:

### Authority migration

```text
measured/shadow
→ development rollout
→ live production authority
```

### Pre-authored endpoints remaining

How often does code still say:

```text
next event should happen here
→ construct ball to make it happen
```

rather than launch → flight → actual situation?

### Live-path certification

Does a system work only in an isolated fixture, or does the ordinary resolver reach it and continue honestly?

### Legacy retirement

Has the old apex/spoil/endpoint/phase authority actually stopped deciding outcomes, or is new code still merely observing it?

## Maintenance rule

When a milestone changes:

1. update canonical `RALLY_MILESTONES.md`;
2. link the review/certification proving the status;
3. advance to first genuine dependency;
4. keep detailed measurements in review docs;
5. do not reopen closed work because a nearby outcome changed.

## Source trail

- `docs/design/RALLY_MILESTONES.md`
- `docs/design/VOLLEYBALL_FIDELITY.md`
- `docs/design/RALLY_ACTION_SPACE.md`
- current `docs/review/` certification/handoff docs

Part V now steps backward deliberately: it explains **how this architecture was reached** so historical shadow/gate code can teach rather than confuse current authority.