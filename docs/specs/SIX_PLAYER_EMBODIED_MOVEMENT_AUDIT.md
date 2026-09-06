# Six-Player Embodied Movement Audit

## Status

Execution spec. Audit-first. This pass follows the authoritative rally-movement work through P15.

## Goal

Determine whether VWM's production rally simulation already behaves as **six embodied volleyball players sharing one court**, rather than six independently valid movement solves.

The authoritative-movement work established that production playback no longer owns a competing movement model and that published movement is the drawing truth. This pass asks:

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
14. player attributes, skill, body morphology, personality/assertiveness insofar as they already affect the above;
15. the remaining closed-form reachability vs authoritative movement-integrator split;
16. **any other discovered variable that can materially affect where a player can be, when they can get there, how they can move there, what physical state they arrive in, or whether multiple players can jointly occupy their trajectories.**

The list is a minimum search surface, not an exhaustive ontology. Search beyond it whenever production evidence exposes another relevant factor, interaction, state, override, constraint, or movement class.

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

A field existing in an event/path/actor is not evidence that it constrains physical movement. Example: `facing` being published and drawn does not prove that beginning oriented away from a target costs time or changes reachability.

---

## Audit doctrine: aggressive search, controlled evidence

The named factors and examples in this spec are **floors, not ceilings**. The audit must continue until the production movement search reaches practical saturation: no materially distinct movement context or newly discovered physical variable remains unexamined.

### Production causality over names

Trace actual production causality:

`input/state -> decision -> reachability -> movement solve -> committed state -> subsequent action -> playback`

Do not infer implementation from identifiers, comments, data structures, intended architecture, or isolated helpers. A concept is physically causal only if changing it can change a production physical result through a demonstrated call/data path.

### Confounder discipline

Controlled comparisons must not silently differ in variables capable of changing the result. At minimum consider and either hold constant, stratify, or explicitly report differences in:

- player identity and all relevant attributes;
- body type/morphology/reach where represented;
- role, rotation and tactical assignment;
- starting position and target position;
- target distance and geometry;
- incoming velocity magnitude and vector;
- exit velocity inherited from prior movement;
- facing/orientation;
- body/action/recovery state;
- action history and previous contact;
- available movement time/deadline;
- ball flight/contact timing and geometry;
- true vs perceived/predicted information;
- claimant/receiver selection;
- teammate positions, velocities, paths and action states;
- opponent positions/states where they influence production decisions;
- exertion/fatigue/readiness if used;
- side of court, coordinate transforms and units;
- seed and RNG consumption/order;
- timestep/integration horizon;
- phase/action-specific clamps, fallbacks, overrides and metadata priority.

This list is also non-exhaustive. When another confounder is discovered, add it to the review and control for it thereafter.

Where perfect isolation is impossible because production logic couples variables, use matched scenarios, stratification, paired seeds, targeted instrumentation, or a minimal deterministic harness that invokes the same production machinery. State the residual confounding explicitly.

### Main effects and interactions

Do not stop after proving isolated main effects. Test interactions where physical meaning depends on context, especially:

- velocity × target direction;
- velocity magnitude × reversal angle;
- facing × travel direction;
- facing × incoming velocity;
- body state × movement direction;
- recovery × deadline;
- attributes × acceleration/braking/turning;
- tactical start position × subsequent reachability;
- teammate occupancy × route geometry;
- multiple simultaneous teammate trajectories;
- truncation × incoming momentum;
- off-court pursuit × environment geometry.

If repo discoveries reveal other plausible interactions, test them.

### Context coverage

Do not generalize from one movement class. Exercise normal, difficult, truncated, emergency and adversarial cases across at least:

- serve/serve-receive movement;
- receive transition;
- setter chase;
- set/contact positioning;
- hitter transition and approach;
- block close;
- block landing and transition;
- defence/dig pursuit;
- attack coverage;
- continuation/rebase;
- emergency second contacts;
- off-court pursuit;
- long-rally/chained transitions;
- any other distinct production movement class discovered.

Stratify findings when different action classes use different mechanics.

### Stress boundaries, not averages only

Use broad seeded populations plus deliberately constructed adversarial counterfactuals. Report distributions, tails, worst cases and context breakdowns where aggregate averages could hide conditional defects. Increase sample size when rare movement classes are insufficiently exercised. Preserve reproducible seeds/scenarios for important failures.

For each apparent defect, attempt to **falsify it** before concluding. For each apparent invariant, stress its boundary conditions before calling it sound. When results have multiple plausible causes, design a discriminating test rather than choosing the most convenient explanation.

### Hidden failure surfaces to search explicitly

Search for, but do not limit the audit to:

- hidden state resets;
- stale state carried across phases;
- clamps and silent normalization;
- fallbacks and legacy branches;
- duplicated formulas/authorities;
- event construction/order dependence;
- metadata written then overwritten later in the same event;
- coordinate/unit conversion errors;
- timestep dependence;
- interpolation artifacts;
- side/team asymmetry;
- RNG coupling caused by instrumentation or alternate paths;
- emergency-only/truncation-only code;
- target sources that compete for the same player;
- path state that is published but not committed, or committed but not consumed;
- physically meaningful variables preserved to rendering but discarded by reachability;
- movement decisions using true information while another layer claims perceived information.

Instrument first. Do not repair a finding merely because the fix appears obvious. Establish causal evidence, prevalence, severity and the earliest responsible layer before recommending implementation.

---

## Non-negotiables

- Preserve the P1-P15 authoritative movement boundary: **simulation-owned movement -> authoritative path/state -> consumers**.
- No production playback re-solve, endpoint snap, facing cheat, target drift, or actor-derived competing movement truth.
- Do not duplicate an existing system under a new name.
- Measure production behavior, not only isolated helper behavior.
- Controlled tests must isolate variables or explicitly account for residual confounding.
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
3. Confirm production baseline still has zero playback corrections, zero movement-contract violations, no production movement reconstruction, and deterministic repeated probes.
4. Record representative resolve cost and existing balance probe values for later comparison.
5. Identify the exact authoritative movement type and all production consumers.

If P15 invariants no longer hold, **STOP** and explain the regression before proceeding.

Deliverable: baseline section in `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md`.

---

# A1 — Build the causal inventory

For every in-scope or discovered factor, trace:

`definition/source -> resolver decision/use -> movement/reachability input -> authoritative path/state -> consumer consequence`

Produce a matrix with at least:

| factor | source/data | production call sites | affects decision? | affects reachability/path? | presentation only? | evidence |
|---|---|---|---|---|---|---|

Audit at minimum position; incoming/exit velocity; acceleration/deceleration; turn/reversal cost; facing/orientation; body state; recovery/ready-at; tactical phase positions/targets; ball read/perceived state; anticipation/prediction; claimant selection; coordination/communication equivalents; relevant player attributes/body morphology; personality/assertiveness equivalents; teammate positions/paths; court/net/environment constraints; and every additional physically relevant factor discovered.

For systems that exist but do not reach physical movement, state the exact boundary where their information is discarded.

### Gate A1

Do not implement missing behavior during this phase. If an apparently missing factor is already implemented elsewhere, update the audit rather than adding another version.

---

# A2 — Physical-state continuity audit

Determine whether action N's physical result constrains action N+1.

Trace representative production sequences including serve receive -> transition; dig -> recovery/next defence; block -> landing -> transition; attack -> landing/recovery -> defence; setter chase -> set -> coverage/defence; truncated approach; emergency second contact -> continuation; coverage -> next set/attack; and discovered chained contexts.

For each, determine whether the next solve receives the actual prior position, velocity vector, facing/orientation, body/action state, recovery/ready-at state, and any relevant exertion/fatigue/morphology state production uses. Record where state is preserved, reset, approximated, reconstructed or ignored.

The existence of `exit_velocity`, `facing`, `body_state` or equivalent data is insufficient: prove downstream consumption.

---

# A3 — Controlled locomotion counterfactuals

Construct deterministic tests using the **production movement/reachability machinery**, not a new model. Apply the confounder doctrine above.

## A3.1 Direction / momentum

At minimum compare already moving toward target, stationary/balanced, perpendicular motion, moving away, and high-speed motion away. Then vary incoming speed, movement-target angle, target distance, deadline, braking distance, partial reversals, successive redirections, truncated legs and state inherited from the prior action.

Measure time to target, distance achieved at fixed deadline, reached/not reached, velocity history, braking/reversal interval, peak acceleration/deceleration where available, and resulting exit state.

Determine whether physically equivalent states behave equivalently and physically different states remain meaningfully different.

## A3.2 Facing/orientation

Separate every distinct concept production uses: travel heading, body/torso facing, volleyball-facing requirement, path-facing metadata, rendered facing, turn/pre-alignment state, or equivalents.

Vary orientation while controlling other state, then test orientation × incoming velocity × target direction interactions. Determine whether orientation changes physical reachability/time/path, only path metadata, only rendering, or nothing.

Explicitly answer whether facing is a biomechanical locomotion constraint, a tactical state, a presentation state, or different things at different layers.

## A3.3 Body/action state

Where supported compare equivalent movement beginning balanced, moving, reaching, airborne/landing, diving and recovering. Include realistic chained entry states from actual preceding actions, not only synthetic enum changes.

Measure physical availability, delay, trajectory, reached distance, reachability and exit state.

## A3.4 Player attributes / morphology

Discover **every** variable capable of affecting locomotion or reachability; do not limit testing to attributes named here. Use controlled low/typical/high values where meaningful. Distinguish effects on movement speed, acceleration, braking, turning, reach/contact geometry, recovery and tactical selection.

Test interactions where formulas combine attributes. Identify declared/relevant variables that do not actually affect production movement.

### Gate A3

If a factor is presentation-only or data-only, record that finding. Do not automatically implement physical consequences.

---

# A4 — Tactical-origin audit

Map why each player's physical start/destination exists throughout representative rallies:

`serve -> receive formation -> pass -> setter chase / hitter transition -> set -> attack formation / defensive base -> attack -> dig/coverage -> transition -> continuation`

For every player target classify its origin: rotation/formation, tactical/role-relative rule, ball/contact geometry, perception/prediction, claimant/coordination decision, fixed coordinate, phase-map/staging heuristic, legacy fallback, or other discovered source.

Answer whether tactical positioning becomes the actual physical starting state of the next action; whether any positions are drawn but not committed; whether destinations are physically constrained after tactical selection or treated as guaranteed; and whether target sources compete for the same player in one event/phase.

Do not redesign tactical sophistication unless a position is internally contradictory or bypasses physical movement.

---

# A5 — Existing perception / coordination / personality integration

Inventory and prove production causality for perceived vs true ball state, anticipation/prediction, claimant selection, seam/overlap responsibility, communication/coordination, role priority, skill-based claiming/yielding, personality/assertiveness/mentality, and any related systems discovered.

For each: identify inputs; decision altered; whether that decision changes who moves/where/when; whether authoritative movement preserves the consequence; and whether it has therefore already participated in seeded whole-rally movement tests.

Include indirect causal effects. Do not infer behavior from attribute names. Demonstrate call paths or controlled scenario differences.

Known example to verify, not assume: perception machinery exists, while prior work found preparation timing still using true rather than perceived arrival. This pass does not fix that timing defect.

---

# A6 — Six-player spatial-conflict audit

Use authoritative paths and timestamps on a shared rally clock. Audit **all simultaneous same-team pairs**, plus 3+ player conflict clusters where pairwise analysis indicates shared traffic.

Measure minimum center separation, time of closest approach, relative velocity, approach angle, crossing-time separation, duration below candidate clearance thresholds, stationary obstruction, converging pursuit, same-target pursuit, crossing/following traffic, landing-zone conflicts, target/path traversal through occupied positions, and substantial overlap under documented body-size assumptions.

Do not silently choose a collision radius. Use repo body/contact dimensions if they exist; otherwise report sensitivity over a small plausible range and label assumptions.

Classify path crossings that are temporally separated, close/plausible traffic, likely obstruction requiring route/priority response, substantial simultaneous overlap, and intentional contact if represented.

Break down by action, phase, role, rotation, severity and contact/non-contact player status. Include setter/middle traffic, hitter approaches, receive seams, defensive scramble, coverage, block close/landing, emergency pursuit and all other contexts discovered.

### Gate A6

If broad stress finds no meaningful simultaneous conflicts, do not invent avoidance. If conflicts exist, quantify frequency, severity and causal context before proposing a fix.

---

# A7 — Court/environment traversal audit

Distinguish legal off-court pursuit from invalid traversal. Audit sidelines/endlines, legal pursuit outside bounds, net plane, net posts/physical post region, referee stand/other represented obstacles, crossing under/through the net, landing space, and teammate/opponent space constraints where rules/geometry require them.

Do not clamp players to `[0,1]` merely because they leave the court. Identify impossible traversal separately from legitimate out-of-bounds movement.

---

# A8 — Reachability-model unification audit

P15 reconciled committed state to the authoritative integrated landing but left two internal answers to reachability: closed-form `_movement_time` / `_reached_point` and stepped authoritative integration.

Stress the disagreement rather than merely reproducing its aggregate rate. Across broad production samples and adversarial cases:

1. count reached/not-reached agreement/disagreement;
2. measure landing/time disagreement distributions and tails;
3. stratify by distance, incoming velocity magnitude/direction, reversal angle, facing if relevant, body/recovery state, attributes/morphology, action type and available time;
4. identify every input each model consumes or ignores;
5. identify every production decision still using the closed-form answer;
6. identify every downstream consequence;
7. search for conditions maximizing divergence;
8. test timestep/integration-horizon sensitivity where relevant.

Answer whether the authoritative integrator can become the sole production reachability authority and what semantic/outcome changes that would cause.

Preferred end state if evidence supports it:

`current embodied state + intended target + deadline -> one movement solve -> reachability + path + landing + exit state`

Do not implement unification during the audit unless trivial, behaviorally obvious and necessary to make measurement truthful. Otherwise specify the smallest follow-up pass.

---

## A8 amendment, from the audit

**Measured correction.** This section assumed the closed-form/integrated split
shows up as disagreement about *reachability* — reached versus not-reached,
landing and time. Measured on controlled legal geometry (60 rows: distances
1–8 m, entry speeds 0–6 m/s, entry angles 0/90/180°) the two models agree to
**0.000 m**. Distance, entry speed and entry angle are therefore falsified as the
cause of the 46-leg production disagreement recorded in
`AUTHORITATIVE_RALLY_MOVEMENT.md` D1.

Two real divergences were found instead, and neither is about arrival:

1. **Exit state.** Whenever the body reaches its target, the closed form reports
   an exit speed of 4.2–5.2 m/s and the integrated path reports 0.000. They agree
   exactly when the body does *not* arrive. `live_velocities` stores the closed
   form while the drawn body follows the integrator.
2. **Off-court legality.** The integrator clamps a body to the court; the closed
   form times a journey to a target beyond it.

A follow-up pass should stress waypointed two-leg traversals and mode
differences, which remain the untested candidates for the production 46.

See `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md` A8 and A8b.

---

# A9 — Synthesis and minimum follow-up plan

Produce a final matrix:

| factor | current status | causal in production? | physically causal? | contexts tested | interactions/confounders | defect? | severity | recommended action |
|---|---|---|---|---|---|---|---|---|

Separate findings into:

### A. Physical locomotion defects
Examples: momentum reset, reversal has no cost, body state ignored, competing reachability model.

### B. Six-player spatial-coherence defects
Examples: simultaneous teammate overlap, impossible route through another body, route requiring coordination-aware detour.

### C. Tactical/behavioral inputs that already work
Preserve them.

### D. Tactical/perception/coordination quality issues outside this pass
Document without absorbing them into physical movement implementation.

### E. Uncertain / under-exercised findings
State exactly what evidence is missing and what test would resolve it. Do not silently promote uncertainty to absence or correctness.

Recommend the **minimum evidence-backed implementation sequence** required to make existing movement physically coherent. If teammate conflicts require intervention, prefer volleyball-appropriate semantics such as `upstream claim/route priority -> yielding/reroute/hesitation -> authoritative physical movement` rather than generic rigid-body bounce/slide unless evidence supports otherwise.

---

# Validation requirements

Audit/instrumentation must preserve deterministic seeded resolution, P15 zero-correction baseline, no playback movement reconstruction, authoritative time/position/velocity/facing contract, ball/contact continuity, existing tactical/perception/claim behavior unless deliberately isolated, and suite baseline.

Run targeted controlled tests, interaction tests, broad seeded whole-rally probes, deliberately adversarial cases, spatial-conflict stress across multiple seed bands, existing correction/continuity audit and full suite. Repeat probes to verify determinism.

Record instrumentation runtime separately from production resolve cost. Do not make production performance claims from debug instrumentation runs.

Aggregate results are insufficient when conditional defects are plausible. Report sample counts by context, distributions/tails/worst cases, and reproducible seeds for important failures.

---

# Deliverables

1. `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md` containing causal inventory, controlled and interaction counterfactuals, tactical-origin map, perception/coordination integration, spatial-conflict measurements, environment findings, reachability split, confounders/uncertainties, and minimum follow-up recommendation.
2. Deterministic audit/probe tools where necessary; retain useful regression instruments.
3. Tests for invariants that should never regress.
4. No production behavior change unless required by an explicit gate or necessary to make the audit truthful; document any such change separately.
5. Update this spec/review when repo discoveries make its assumptions incomplete or wrong.

---

# DONE

The audit is DONE only when:

- every listed **and materially discovered** physical factor is classified by actual production causality, not file/name presence;
- incoming position/velocity/facing/body/recovery continuity is traced across representative action transitions;
- direction/reversal, facing, body-state, attributes/morphology and relevant interactions are measured;
- tactical target origins are mapped without redesigning tactics;
- existing perception/claim/coordination/personality effects on movement scenarios are identified and proven or shown absent;
- simultaneous teammate trajectories are stress-tested in space **and time**, including 3+ player clusters where relevant;
- legal off-court movement is distinguished from impossible environment traversal;
- the closed-form vs integrated reachability split is stressed, measured and all production consumers identified;
- confounders are controlled, stratified or explicitly documented for material conclusions;
- apparent defects have been challenged with discriminating/falsification tests;
- rare and boundary contexts have enough exercise to support conclusions or are explicitly marked uncertain;
- P15 authoritative-movement invariants still hold;
- full suite state, determinism, balance controls and performance controls are recorded;
- the wider search has reached practical saturation: no materially distinct production movement context or newly discovered physical variable remains unaudited;
- the next implementation pass is narrowed to evidence-backed physical defects only.

Do not claim a factor is solved because data for it exists. Do not claim it is absent because no obviously named system exists. Do not generalize a passing result beyond the contexts and interactions actually tested. Prove causal role and physical consequence.