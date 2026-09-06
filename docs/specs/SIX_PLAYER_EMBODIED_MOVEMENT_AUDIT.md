# Six-Player Embodied Movement Audit

## Status

Execution spec. Audit-first. This pass follows the authoritative rally-movement work through P15.

## Goal

Determine whether VWM's production rally simulation already behaves as **six embodied volleyball players sharing one court**, rather than six independently valid movement solves.

The authoritative-movement work established that production playback no longer owns a competing movement model and that published movement is the drawing truth. This pass asks the next question:

> Given what each player already knows/decides, where their body currently is, how it is moving and oriented, what action state it is in, and where teammates/environment are, does production movement preserve the physical consequences of that state?

This is primarily an **audit and causal-trace pass**. Do not add systems because a concept appears absent by name. Prove what exists, where it is used, and whether it has causal effect first.

Repo truth wins over this document's assumptions.

---

## Scope boundary

### In scope

Audit the production causal chain for:

1. position;
2. velocity / momentum;
3. acceleration / deceleration;
4. movement direction and reversal;
5. facing / body orientation;
6. body/action state: balanced, moving, reaching, airborne, landing, diving, recovering, or production equivalents;
7. recovery constraints;
8. route geometry;
9. teammate occupancy / obstruction / overlap;
10. court and environmental geometry relevant to traversal;
11. tactical positioning insofar as it supplies physical starting positions or destinations;
12. perception / anticipation insofar as it changes movement scenarios or destinations;
13. claim / coordination / communication logic insofar as it chooses which player moves or yields;
14. player attributes, skill, personality/assertiveness insofar as they already affect the above;
15. the remaining closed-form reachability vs authoritative movement-integrator split.

### Out of scope unless a gate below proves otherwise

Do **not** redesign:

- tactical intelligence;
- perception quality;
- anticipation logic;
- communication;
- claim priority;
- personality/assertiveness;
- skill-based yielding;
- reception preparation timing;
- animation biomechanics;
- generalized navigation/physics;
- scheduler architecture;
- match balance merely to restore a threshold.

Existing systems in those areas are inputs to preserve and trace, not invitations to rewrite them.

### Critical distinction

For every concept distinguish:

1. **absent**;
2. **represented as data only**;
3. **used for tactical/behavioral decisions**;
4. **used by physical reachability/movement**;
5. **used only by presentation**.

A field existing in an event/path/actor is not evidence that it constrains physical movement.

Example: `facing` being published and drawn does not prove that beginning oriented away from a target costs time or changes reachability.

---

## Non-negotiables

- Preserve the P1-P15 authoritative movement boundary: **simulation-owned movement -> authoritative path/state -> consumers**.
- No production playback re-solve, endpoint snap, facing cheat, target drift, or actor-derived competing movement truth.
- Do not duplicate an existing system under a new name.
- Measure production behavior, not only isolated helper behavior.
- Controlled tests must isolate one variable where practical.
- Multi-player conflict requires **space + time**. Crossing path lines at different times is not a collision.
- Do not solve teammate obstruction by generic bounce/slide behavior without evidence that this is the minimum volleyball-appropriate model.
- Do not treat tactical target quality as a locomotion defect.
- Do not hide contradictions to protect existing balance figures. Measure outcome drift if a later required physical fix changes outcomes.
- Preserve determinism/seeding.

---

# A0 — Establish production baseline

Before changing production behavior:

1. Record branch/commit and current suite state.
2. Re-run the faithful P15 correction/continuity instrument.
3. Confirm production baseline still has:
   - zero playback corrections;
   - zero movement-contract violations;
   - no production movement reconstruction;
   - deterministic repeated probes.
4. Record representative resolve cost and existing balance probe values for later comparison.
5. Identify the exact authoritative movement type and all production consumers.

If P15 invariants no longer hold, **STOP** and explain the regression before proceeding.

Deliverable: baseline section in `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md`.

---

# A1 — Build the causal inventory

For every in-scope factor, trace:

`definition/source -> resolver decision/use -> movement/reachability input -> authoritative path/state -> consumer consequence`

Produce a matrix with at least:

| factor | source/data | production call sites | affects decision? | affects reachability/path? | presentation only? | evidence |
|---|---|---|---|---|---|---|

Audit at minimum:

- position;
- incoming velocity;
- exit velocity;
- acceleration;
- deceleration;
- turn/reversal cost;
- facing/orientation;
- body state;
- recovery/ready-at;
- tactical phase positions/targets;
- ball read/perceived state;
- anticipation/prediction inputs;
- claimant/receiver selection;
- coordination/communication equivalents;
- relevant player attributes;
- personality/assertiveness equivalents if any;
- teammate positions/paths;
- court bounds/net/environment constraints.

Search broadly. Names are not contracts. Follow actual production calls.

For systems that exist but do not reach physical movement, state the exact boundary where their information is discarded.

### Gate A1

Do not implement missing behavior during this phase.

If an apparently missing factor is already implemented elsewhere, update the audit rather than adding another version.

---

# A2 — Physical-state continuity audit

Determine whether action N's physical result constrains action N+1.

Trace representative production sequences including:

- serve receive -> transition;
- dig -> recovery / next defensive movement;
- block -> landing -> transition;
- attack -> landing/recovery -> defence;
- setter chase -> set -> coverage/defence;
- approach truncated by set/contact timing;
- emergency second contact -> continuation;
- coverage -> next set/attack phase.

For each, determine whether the next solve receives the actual prior:

- position;
- velocity vector, not merely speed;
- facing/orientation;
- body/action state;
- recovery/ready-at state;
- relevant exertion/fatigue state if production movement uses it.

Record where state is preserved, reset, approximated, reconstructed, or ignored.

The existence of `exit_velocity`, `facing`, or `body_state` in a structure is insufficient: prove downstream consumption.

---

# A3 — Controlled locomotion counterfactuals

Construct deterministic tests using the **production movement/reachability machinery**, not a new model.

Hold player, destination, distance and available time constant where possible. Vary only the tested initial state.

## A3.1 Direction / momentum

Compare at minimum:

1. already moving toward target;
2. stationary/balanced;
3. moving perpendicular to target;
4. moving away from target;
5. high-speed movement away from target.

Measure:

- time to target;
- distance achieved at fixed deadline;
- reached/not reached;
- velocity history;
- braking/reversal interval if represented;
- peak acceleration/deceleration if available.

Expected invariant: conditions requiring greater braking/redirection must not be physically equivalent to already moving toward the target.

Do not hard-code an expected ranking if repo mechanics legitimately model a more nuanced case; explain it.

## A3.2 Facing/orientation

Same player/target/state; vary initial facing relative to travel target/required volleyball orientation.

Determine whether orientation:

- changes physical reachability/time/path;
- changes only path-facing metadata;
- changes only rendered body orientation;
- is ignored.

Explicitly answer whether `facing` is a biomechanical locomotion constraint or presentation state in current production.

## A3.3 Body/action state

Where supported, compare equivalent movement beginning from:

- balanced;
- moving;
- reaching;
- airborne/landing;
- diving;
- recovering.

Measure whether these states produce physically different availability or movement.

## A3.4 Player attributes

Hold scenario constant and vary only attributes production movement claims to use: e.g. speed/agility/explosiveness/work rate or actual repo equivalents.

Prove that attribute differences causally affect movement/reachability as intended and identify any declared movement attributes that currently do not.

### Gate A3

If a factor is presentation-only or data-only, record that as a finding. Do not automatically implement physical consequences yet.

---

# A4 — Tactical-origin audit

Map why each player's physical start/destination exists throughout representative rallies.

Trace at minimum:

`serve -> receive formation -> pass -> setter chase / hitter transition -> set -> attack formation / defensive base -> attack -> dig/coverage -> transition -> continuation`

For every player target encountered, classify its origin:

- rotation/formation;
- tactical/role-relative rule;
- ball/contact geometry;
- perception/prediction;
- claimant/coordination decision;
- fixed coordinate;
- phase-map/staging heuristic;
- legacy fallback;
- other.

Answer:

1. Does tactical positioning become the **actual physical starting state** of the next action?
2. Are any tactical positions drawn but not committed to resolver state? P15 removed known examples; verify no equivalent remains.
3. Are destinations physically constrained after tactical logic chooses them, or treated as guaranteed endpoints?
4. Are any target sources competing for the same player in the same event/phase?

Do not judge or redesign tactical sophistication unless a position is internally contradictory or bypasses physical movement.

---

# A5 — Existing perception / coordination / personality integration

This phase is inventory + causality only.

Determine what production already does for:

- perceived vs true ball state;
- anticipation/prediction;
- receiver/defender claimant selection;
- seam/overlap responsibility;
- communication/coordination if represented;
- role priority;
- skill-based claim/yield behavior;
- personality/assertiveness or mentality effects if represented.

For each existing system answer:

1. What inputs does it use?
2. What decision does it alter?
3. Does that decision change who moves, where they move, or when?
4. Does authoritative movement preserve the consequence?
5. Has it therefore already been part of seeded whole-rally movement tests?

Do not infer behavior from attribute names. Demonstrate causal call paths or controlled seed/scenario differences.

Known example to verify, not assume: perception machinery exists, while prior work found preparation timing still using true rather than perceived arrival. This pass does not fix that timing defect.

---

# A6 — Six-player spatial-conflict audit

Use authoritative paths and their timestamps to measure whether teammates can be jointly embodied.

For representative and stress-seeded rallies, sample all six teammates' trajectories on a common rally clock.

For each same-team pair measure:

- minimum center-to-center separation;
- time of minimum separation;
- relative velocity at closest approach;
- whether path lines cross at materially different times;
- duration below candidate body-clearance thresholds;
- whether bodies substantially overlap under a documented conservative body-radius assumption;
- action/phase/roles involved;
- whether one player's target or path traverses another player's occupied position.

Do not silently choose a gameplay collision radius and implement it. If the repo already has body/contact dimensions, use and cite them. Otherwise report results over a small sensitivity range and label it an audit assumption.

Classify conflicts:

1. path crossing, temporally separated — valid;
2. close but plausible traffic;
3. likely obstruction requiring route/priority response;
4. substantial simultaneous body overlap — physically impossible;
5. intentional contact if any such mechanic already exists.

Break down conflicts by volleyball context, e.g.:

- setter chase vs middle transition;
- hitter approach lanes;
- receive seams;
- defensive scramble;
- coverage;
- block close / landing traffic;
- emergency pursuit.

### Gate A6

If no meaningful simultaneous conflicts exist across a broad stress population, do not invent collision avoidance. Document the result.

If conflicts exist, quantify frequency/severity before proposing a fix.

---

# A7 — Court/environment traversal audit

P15 observed player traces outside sidelines. Distinguish legal pursuit from invalid traversal.

Audit whether production movement understands or ignores:

- sidelines/endlines as non-obstructing boundaries;
- legal off-court pursuit;
- net plane;
- net posts / physical post region if represented;
- referee stand/other obstacles if represented in simulation rather than visuals;
- crossing under/through the net;
- teammate/opponent court-space constraints where rules/geometry require them.

Do not clamp players to court bounds merely because they leave `[0,1]` coordinates. Off-court pursuit is valid volleyball.

Identify impossible traversal separately from legitimate out-of-bounds movement.

---

# A8 — Reachability-model unification audit

P15 reconciled commit state to the authoritative integrated landing but left two internal answers to the same question:

- closed-form `_movement_time` / `_reached_point` reachability;
- stepped authoritative movement integration.

Characterize this split precisely.

Across broad production samples:

1. count agreement/disagreement on reached/not reached;
2. measure landing/time disagreement;
3. break down by distance, incoming velocity, direction change, player attributes, action type and available time;
4. identify whether the closed form ignores any state the integrator uses;
5. identify every production decision still using the closed-form answer;
6. identify every downstream consequence of disagreement.

Answer whether one can become the sole production reachability authority without a major rewrite.

Preferred architectural end state, if evidence supports it:

`current embodied state + intended target + deadline -> one movement solve -> reachability + path + landing + exit state`

Do **not** implement the unification during the audit unless the implementation is trivial, behaviorally obvious, and necessary to complete measurement. Otherwise specify the smallest follow-up pass.

---

# A9 — Synthesis and minimum follow-up plan

Produce a final matrix for every audited factor:

| factor | current status | causal in production? | physically causal? | defect? | severity | recommended action |
|---|---|---|---|---|---|---|

Separate findings into four categories:

### A. Physical locomotion defects
Examples: momentum reset, reversal has no cost, body state ignored, competing reachability model.

### B. Six-player spatial-coherence defects
Examples: simultaneous teammate overlap, impossible route through another body, route needs coordination-aware detour.

### C. Tactical/behavioral inputs that already work
Preserve them. Do not rewrite merely because this audit encountered them.

### D. Tactical/perception/coordination quality issues outside this pass
Document without absorbing them into physical movement implementation.

Recommend the **minimum** next implementation scope required to make existing movement physically coherent.

If teammate conflicts require intervention, prefer volleyball-appropriate semantics:

`upstream claim/route priority -> yielding/reroute/hesitation -> authoritative physical movement`

rather than generic rigid-body bounce/slide, unless repo evidence supports otherwise.

---

# Validation requirements

Audit and any incidental instrumentation must preserve:

- deterministic seeded resolution;
- P15 zero-correction production baseline;
- no playback movement reconstruction;
- authoritative time/position/velocity/facing contract;
- ball/contact continuity;
- existing tactical/perception/claim behavior unless deliberately isolated in a test;
- suite baseline.

Run:

1. targeted unit/contract tests for controlled counterfactuals;
2. broad seeded whole-rally probes;
3. spatial-conflict stress across multiple seed bands;
4. existing movement correction/continuity audit;
5. full suite before completion.

Record runtime cost of instrumentation separately from production resolve cost.

Do not make performance claims from debug instrumentation runs alone.

---

# Deliverables

1. `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md`
   - causal inventory;
   - controlled counterfactual results;
   - tactical-origin map;
   - perception/coordination integration findings;
   - teammate spatial-conflict measurements;
   - environment findings;
   - reachability split measurements;
   - minimum follow-up recommendation.
2. Deterministic audit/probe tools where necessary. Keep them if they are useful regression instruments.
3. Tests for any invariant discovered that should never regress.
4. No production behavior change unless required by an explicit gate or necessary to make the audit truthful; document any such change separately.

---

# DONE

This audit is DONE only when:

- every listed physical factor is classified by actual production causality, not file/name presence;
- incoming position/velocity/facing/body/recovery continuity is traced across representative action transitions;
- direction/reversal, facing, body-state and attribute counterfactuals are measured;
- tactical target origins are mapped without redesigning tactics;
- existing perception/claim/coordination/personality effects on movement scenarios are identified and proven or shown absent;
- simultaneous teammate trajectories are stress-tested in space **and time**;
- legal off-court movement is distinguished from impossible environment traversal;
- the closed-form vs integrated reachability split is measured and all production consumers identified;
- P15 authoritative-movement invariants still hold;
- full suite state and determinism are recorded;
- the next implementation pass is narrowed to evidence-backed physical defects only.

Do not claim a factor is solved because data for it exists. Do not claim it is absent because no obviously named system exists. Prove its causal role.