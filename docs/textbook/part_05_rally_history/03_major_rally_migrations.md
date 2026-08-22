# 03 — Major RallySimulator Migrations

Status: **HISTORICAL OVERVIEW**

The current rally architecture did not arrive in one rewrite. Several migrations each removed a different form of hidden authority.

This chapter is a map; use the linked review docs for exact evidence.

## 1. Persistent state foundations

Early gate work introduced explicit models such as:

- `RallyState`;
- `RallyPlayerState`;
- `RallyBallState`;
- `ActionOpportunity`;
- scheduling/decision/trace structures.

The immediate goal was not to replace the whole live resolver, but to create a vocabulary capable of representing continuous state honestly.

## 2. Perception and responsibility

Reception work separated:

```text
ball truth
→ player read
→ physical candidate
→ responsibility/choice
```

This broke the assumption that one quality formula should simultaneously decide who reads the ball, who can reach it and who takes it.

Later short-ball work refined ownership further so nominal assignment could yield when control was not physically usable.

## 3. Force/geometry-derived flight timing

Serve/set/attack flight timing moved away from independent duration tables toward projectile relationships based on distance/launch shape.

This reduced contradictions among duration, apex, speed and geometry.

It also made ball time a more meaningful clock for movement.

## 4. Locomotion and continuous reachability

Movement evolved from a single rating-to-speed curve toward stride/cadence/mass/mode relationships and stepped/observable reachability work.

The important architectural move was not “more realistic speed.” It was making:

```text
movement projection
and
movement timing
```

answer from the same model.

## 5. Attack preparation

Hitter approach became a causal preparation state influencing takeoff/attack availability/quality rather than a decorative animation before a preselected swing.

This established the broader principle that actions begin before contact.

M7 will extend that principle across the whole rally timeline.

## 6. Block perception/coordination

Block Gates 44–49 moved blocker behavior toward information-bounded reads, teammate cues, coordinated commitments and development-only integration.

The lasting lesson is that defenders should commit from cues available **before** attack truth, not react to the finalized target.

## 7. Physical preparation orientation

M2 replaced simplistic velocity-facing/readiness assumptions with explicit movement-form orientation and real body states.

A shuffle can preserve square orientation; an approach/transition run can establish route-facing.

An unmeasured defensive opening-cost/top-speed relation was deferred instead of guessed.

## 8. Actor continuity

Recovery/body/facing state was made to survive phase reconstruction.

This repaired the split where the rally clock knew a blocker was recovering but the next phase's newly built actor did not.

## 9. Body centre vs contact point

M3 derived platform body offset from contact height and body reach geometry.

The athlete no longer needed to stand on the ball coordinate to touch it.

## 10. Shared platform contact physics

M4 introduced the T1–T3 platform model:

```text
incoming ball + body
→ feasible pace/direction envelope
→ intent selection
→ technique execution
→ outgoing launch
```

Reception/dig/coverage now share the physical relation rather than carrying event-family physics bands.

## 11. Free-flight/interception authority

M5 promoted the idea that an outgoing launch exists independently of the hoped-for next recipient.

This enabled:

- setter misses;
- alternate interception;
- uncontrolled floor terminal;
- physical overpass.

The current live integration is completing opponent first-contact semantics for those overpasses.

## 12. Action-space generalization

The overpass contest is the first live-facing proof that team contact #1 can select different action types.

M6 will generalize this idea across contacts/interactions; M7 adds continuous/late commitment; M9 proves tactical expression.

## How to reason about a migration

Each migration usually removes one shortcut:

| shortcut | replacement |
|---|---|
| result category authors ball | contact authors launch |
| recipient authors endpoint | flight authors opportunities |
| phase reset authors body | carried actor state |
| display position authors physics | simulation state feeds display |
| assignment overrides reach | feasibility constrains responsibility |
| contact number authors action | legal/physical action choice |

This table is a useful audit checklist for future systems.

## What not to conclude

The chronology does **not** mean every old mechanism is invalid.

Some systems were audited and certified; some remain temporarily authoritative because their replacement dependency is unfinished. The current roadmap decides what is open.

Likewise an outcome distribution changing after a correctness migration does not prove the new system needs tuning. First determine whether the old distribution came from the shortcut that was just removed.

## Source trail

- `docs/design/RALLY_MILESTONES.md`
- `docs/review/` M1–M5 review chain
- `docs/calibration/` historical gate chain
- `docs/design/CONTACT_AND_BALL_FLIGHT.md`
- `docs/design/PLATFORM_CONTACT.md`

Next: the project's measurement culture—especially how wrong hypotheses and removed abstractions are used as evidence rather than hidden.