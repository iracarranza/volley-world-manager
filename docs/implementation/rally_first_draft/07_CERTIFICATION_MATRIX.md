# 07 — Probes, tests, gates and post-draft certification matrix

This file defines how evidence relates to construction.

## 1. Four different things

Do not collapse these categories.

### Probe

Measures/exposes behavior. May print distributions or counts without deciding pass/fail.

Examples:

- alternate interceptor count;
- setter arrival-margin distribution;
- dig rate;
- action start/arrival times.

### Invariant/test

Asserts something that must be true for the stated architecture.

Examples:

- one contact → one authoritative launch;
- realised segment is a prefix of the same launch;
- source launch does not mutate;
- event causality is monotonic.

### Gate

Policy saying a feature/milestone may not become production authority until specified invariants/evidence close.

A gate may aggregate tests/probes. It is not itself another physics model.

### Observation/calibration metric

Describes resulting behavior/rates. It blocks only where an existing authority explicitly supplies an acceptance bound.

---

## 2. Certification stages

```text
P0 parse/smoke
→ P1 unit/deterministic authority fixtures
→ P2 migration paired probes (where legacy comparison still matters)
→ P3 M6 cross-family one-ball certification
→ P4 M7 continuous-action certification
→ FIRST-DRAFT CONSTRUCTION COMPLETE
→ P5 M8 canonical side-out certification
→ P6 M9 tactical A/B certification
→ P7 balance/distribution census
→ repair/calibration cycles
```

---

# P0 — Parse / smoke

Run frequently during construction.

Required:

- Godot parse/import succeeds;
- ordinary rally resolve does not crash;
- at least representative home/opponent serve paths resolve;
- no newly introduced invalid/null authoritative state reaches a required consumer.

P0 failure is F0 and blocks later work.

---

# P1 — Deterministic authority fixtures

These should be small and cheap enough to run throughout work.

Permanent target invariants:

## Contact/ball

- one contact publishes no more than one authoritative outgoing launch;
- authoritative launch fields are immutable after publication;
- realised segment shares launch identity with its source free flight;
- realised segment never extends beyond its free flight;
- actual contact point/height/time are internally consistent;
- terminal truth follows physical flight/interactions.

## Interception

- intended recipient can differ from actual interceptor;
- intended recipient can receive no opportunity;
- an alternate legal teammate can intercept;
- no legal same-side interception → truthful floor/crossing terminal;
- legal crossing → receiving side ordinary first-contact path.

## State continuity

- one actor per player per phase/state snapshot;
- recovery/body state survives when still owed;
- clean actor remains clean;
- carried state reaches physical feasibility systems;
- facing persists unless an establishing movement form changes it;
- after M7, action/movement state at contact equals the state produced by prior elapsed action.

## Time

- event/contact times are causally ordered;
- a realised segment ends at its actual contact time;
- no causality-floor repair is required for correctly derived ordinary events;
- movement-agreement compares the same physical interval.

---

# P2 — M4 migration certification

This remains blocking for A2.

Use the existing paired physical-reception protocol, including `tools/run_reception_rollout_probe.gd` at the pinned base.

Required physical-reception invariants include the already-certified set:

- every physical successful reception owns exactly one launch;
- zero launch mutations;
- zero realised-prefix failures;
- zero one-ball chain breaks;
- intended setter independent of interceptor;
- alternate interceptors possible;
- intended misses possible;
- T1–T3 physical bounds hold;
- both serving sides exercised;
- floor/net/crossing terminals truthful.

Also run existing dig/coverage/free-flight/overpass probes to prove A0/A1 did not reopen those families.

### M4 promotion gate

Physical reception may become production authority only when:

1. A0 semantic reconciliation closes;
2. movement-agreement passes unchanged;
3. causality/blocker timing failures attributable to the short-leg inconsistency close or are separately proven unrelated;
4. paired authority invariants pass;
5. no existing explicit acceptance-bound assertion fails due to an unresolved correctness issue.

Outcome distribution movement alone is not a blocker.

---

# P3 — M6 cross-family certification

After B1–B6, create or extend a compact cross-family matrix.

| edge | required identity/truth |
|---|---|
| serve → reception | receiver reads/contacts the serve's actual flight |
| reception → set | set consumes M5 realised first-ball segment/contact |
| set → attack | attack timing/options consume the actual set ball |
| attack → block | block intersects actual attack launch/path |
| block → coverage/dig | next system consumes actual post-block ball |
| attack → dig | defender reacts to actual attack ball |
| dig → set | set consumes dig realised interception prefix |
| coverage → set | continuation consumes coverage realised prefix |
| overpass → first contact | receiving side consumes crossed authoritative ball |

For each edge assert:

- same launch lineage;
- causal times;
- actual actor legality/feasibility;
- no synthetic endpoint replacement;
- classification after physical truth.

### M6 closure criterion

No known ordinary production edge has two independent physical authorities.

A family may remain imperfect in calibration/fidelity and still close M6 if its ownership chain is unambiguous.

---

# P4 — M7 continuous-action certification

This stage proves the continuous-action **architecture**, not visual polish.

Use deterministic scenarios where possible.

## Previous contacter

- contact consequence/recovery survives into next leg;
- previous contacter yields when policy requires;
- clearing movement actually changes later starting state.

## Setter

- release begins before physical reception is completed where appropriate;
- pre-contact movement targets expected release state, not future realised pass endpoint;
- realised interception determines remaining second-contact opportunity;
- transition setter gets real preceding-ball time rather than a hardcoded window where authoritative duration exists.

## Hitter

- approach/release begins before attack contact;
- chosen hitter contact state reflects time spent approaching;
- unchosen hitters do not complete synthetic attacks;
- an unreachable/late approach remains late rather than snapping.

## Block

- recognition/close begins before attack contact;
- blockers can have distinct recognition moments;
- attack intersects realised wall state;
- late block remains physically late;
- landing recovery persists afterward.

## Floor defence

- defenders establish from actual starting positions before swing;
- attack read begins from those realised positions;
- partial establishment remains partial.

## Early arrival

- traversal finishes at traversal duration, not available-window end;
- actor waits/holds after arrival;
- playback plan, if inspected, does not re-stretch the movement.

### M7 closure criterion

On a canonical side-out trace, required player actions overlap preceding ball phases and every contact samples the state those actions produced.

---

# First-draft construction checkpoint

At this point:

- M4 is production-closed;
- M6 authority consistency is complete;
- M7 action continuity exists;
- ordinary rallies are runnable;
- known failures are inventoried.

Now switch from construction to evaluation.

---

# P5 — M8 canonical side-out certification

Use controlled, hand-authored, neutral rosters. Do not rely on career generation/extreme morphology to demonstrate ordinary volleyball.

Target sequence:

```text
medium float serve
→ three-person reception
→ setter transition
→ several plausible attack options
→ block read/form
→ floor defence establishes
→ attack
→ kill / block / dig
→ transition if playable
```

Evaluate two layers.

## Structural/diagnostic layer

For each phase capture:

- actor positions before contact;
- action intentions and start times;
- available/traversal times;
- actual contact actor/position/height/time;
- incoming/outgoing launch lineage;
- blocker/defender state before swing;
- transition state after playable defence.

## Visual volleyball-literate layer

With debug text/captions off, the sequence should support answering:

- who is receiving/protected;
- whose ball it is;
- where setter is releasing;
- which attackers are available/approaching;
- who read/committed/closed on block;
- which defensive spaces are owned;
- whether late players are visibly late;
- whether previous contacter clears and transition reforms.

A visual failure can be simulation or presentation. Localize before changing simulation.

### M8 output

M8 may produce a defect list. It does not require first-draft construction to be retroactively reopened unless a defect proves missing/contradictory architecture.

---

# P6 — M9 tactical A/B certification

A tactical instruction is certified when it changes the predicted **causal mechanism**, not merely a hidden scalar or terminal rate.

For each tactic under test:

1. state predicted intermediate changes before running;
2. hold neutral rosters/seeds/conditions where practical;
3. measure the intermediate mechanism;
4. measure downstream consequences separately.

Examples of intermediate mechanisms:

- serve target/aim selection;
- receiving responsibility/shape;
- setter option/tempo choice;
- hitter release/course decision;
- block commit/funnel relationship;
- defensive base/coverage movement.

Do not add/tune tactical weights merely to force terminal A/B significance.

---

# P7 — Balance / distribution census

Run after structural certification so outcome rates describe the intended engine rather than a mixture of old/new authority.

Collect at minimum existing project metrics such as:

- serving-side symmetry / point share;
- serve errors/aces;
- reception quality/success;
- set posture/quality/tempo distributions;
- attack mix and kill/error/block rates;
- dig/coverage rates;
- swings/contacts per rally;
- transition frequency;
- alternate-interception/miss populations;
- movement/arrival-margin distributions.

Interpretation rule:

- explicit pre-existing bound → gate;
- otherwise → observation requiring volleyball/design review before calibration.

---

## 3. What can eventually be retired

Migration probes comparing legacy vs physical behavior can be retired after:

1. legacy production authority is removed;
2. no active rollout depends on the comparison;
3. the important semantic invariants have permanent regression coverage.

Example lifecycle:

```text
paired rollout probe
→ proves migration
→ production promotion
→ legacy path retired
→ permanent one-launch/prefix/interception invariants remain
```

Do not let the permanent suite become a museum of obsolete implementation comparisons.

## 4. What may never be “circumvented” silently

A future agent may replace a test/probe with better evidence, but must not silently remove:

- one-ball authority;
- launch immutability;
- causal event order;
- actual-vs-intended separation;
- legal/physical feasibility;
- realised-prefix truth;
- actor-state continuity required by M7;
- explicit accepted gates.

If the evidence mechanism changes, record the replacement invariant and why it is equivalent or stronger.
