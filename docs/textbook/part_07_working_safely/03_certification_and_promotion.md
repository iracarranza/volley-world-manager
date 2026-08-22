# 03 — Certification and Production Promotion

Status: **VERIFIED PROJECT METHOD**

A subsystem can be correct in isolation and still be unsafe to make authoritative in ordinary play.

VWM therefore treats **implementation**, **certification**, and **production promotion** as separate decisions.

## The authority ladder

A common progression is:

```text
model/fixture exists
→ focused behavior certified
→ integration path certified
→ downstream semantics certified
→ production authority promoted
→ legacy authority retired
```

Skipping a step often creates a system that “works” only because surrounding code is still supplying the old answer.

## Isolated correctness

First prove the subsystem's own contract.

For platform/free-flight work, examples include:

- launch is physically valid;
- attribute leverage is monotonic;
- failed contact emits no ball;
- realized segment is a prefix;
- source launch is immutable.

This says nothing yet about whether `RallySimulator` uses the subsystem correctly.

## Integration certification

Next prove the real live boundary:

```text
actual live state
→ new system
→ output
→ existing downstream continuation
```

Constructed overpass fixtures are an example: they verify that actors are built from the authoritative live maps, contact #1 is recorded correctly and the resulting physical ball enters continuation without mutating the incoming launch.

## Downstream semantics matter

Promotion must consider every situation the new output can create.

Physical digs exposed legal overpasses. That meant “dig physics works” was not enough to enable production dig authority: the opponent needed governed first-contact behavior for that new ball state.

This is why milestones can overlap.

## Feature flag is not certification

A flag such as:

```text
ENABLE_PHYSICAL_PLATFORM_DIG
```

is a switch, not proof.

The flag should change only when the surrounding authority contract is complete. Code being present behind the flag does not imply production should enable it.

## Symmetry

When both teams use the same volleyball rules, integration should normally be certified from both sides.

Home/opponent code paths can differ structurally even when intended semantics match. A fixture passing for one side does not prove the mirrored path has correct orientation, lineup, possession or continuation.

If an asymmetry is intentional, document the reason.

## Certified families stay closed by default

Serve/set/attack/block have established structural certification.

A downstream defect near one of them is not enough reason to rewrite that family.

Reopen only if a controlled fixture demonstrates that the certified authority itself violates its contract.

This prevents development from repeatedly destabilizing already-understood systems.

## Correctness versus balance

During certification, outcome-rate changes are observations.

Do not respond to:

```text
new physical model → fewer digs
```

by immediately widening a cone or adding a bonus.

First establish:

- the new model receives truthful inputs;
- its own outputs are plausible;
- responsibility/continuation is correct;
- the measurement is trustworthy.

Balance/calibration is a separate authorized pass.

## Legacy retirement is part of promotion

A migration is not complete if new code runs but old code still determines the outcome.

Ask:

```text
Which system decides now?
Could the legacy path silently replace/override the result?
Is old metadata still being read as authority?
```

Once the new system owns the fact, remove or demote old authoritative machinery when safe. Otherwise two architectures remain coupled forever.

## Certification ledgers

Review docs should record:

- exact checkpoint/commit;
- scope of authority;
- focused fixtures/probes;
- full-suite result where relevant;
- observed live incidence;
- invariants proven;
- known remaining blocker;
- production flag/status.

A future maintainer should be able to answer “why is this enabled/disabled?” without reconstructing a chat conversation.

## STOP boundaries

Sometimes promotion reaches a genuine design boundary.

The current coverage-selection question is an example: physics supplies feasible keep-alive launches, but the game has not governed which continuation a covering player should prefer.

That is not a reason to fabricate a target and keep coding.

At a genuine boundary:

1. measure the feasible situation;
2. state the smallest unresolved semantic question;
3. present viable options/evidence;
4. stop until policy is decided.

## Promotion checklist

Before making a new path production-authoritative:

- [ ] isolated contract passes;
- [ ] real live inputs feed it;
- [ ] both sides/symmetry covered where applicable;
- [ ] bookkeeping/contact/possession correct;
- [ ] downstream legal states are governed;
- [ ] presentation is downstream only;
- [ ] no hidden replacement result/ball;
- [ ] source-state invariants hold;
- [ ] broad suite checked;
- [ ] design/review docs updated;
- [ ] old authority retired or explicitly bounded.

## Reading exercise

Using the current M4/M5 docs, identify separately:

- what is built;
- what is development-authoritative;
- what is live-integrated;
- what is production-enabled;
- what blocks the next promotion.

Do not use the word “done” until you can name the layer.

## Source trail

- `docs/design/RALLY_MILESTONES.md`
- `docs/review/FREE_FLIGHT_INTERCEPTION.md`
- `docs/review/OVERPASS_ACTION_HANDOFF.md`
- `docs/review/PLATFORM_AUTHORED_CALIBRATION.md`
- feature-flag/rollout code under `scripts/simulation/`

Next: practical debugging in Godot/GDScript—how to distinguish parser, runtime, scene-tree, data, and simulation-authority failures.