# 03 — Dependency graph and work units through M6

This is the main construction spine. Execute in order unless a work unit explicitly allows parallel work.

## 1. Dependency graph

```text
A0  First-ball realised-state semantic reconciliation
 ↓
A1  Short-leg movement/timing correctness
 ↓
A2  Physical reception production promotion
 ↓
════════════════════════ M4 CLOSED
 ↓
B0  M6 contact-authority census
 ↓
B1  Serve consistency audit ─────┐
B2  Set consistency audit ───────┤
B3  Attack consistency audit ────┼─ may be audited independently after B0
B4  Block consistency audit ─────┤
B5  Platform-family closure ─────┘
 ↓
B6  Cross-family one-ball-chain / authority cleanup
 ↓
════════════════════════ M6 FIRST-DRAFT COMPLETE
 ↓
C/D work in 05_CONTINUOUS_ACTION_AND_INTEGRATION.md
```

M4 is a hard prerequisite because the active development sequence already made reception closeout foundational. M6 is primarily an **audit + convergence pass**, not permission to rebuild contact families already certified.

---

# Cluster A — close M4

## A0 — First-ball realised-state semantic reconciliation

### Purpose

Remove the remaining first-ball assumptions that treat the reception's intended/authored destination as the setter's realised contact state.

### Preconditions

Already true at the pinned base:

- physical reception launch exists behind its own gate;
- the shared T1–T3 resolver owns that launch;
- home first-ball physical reception routes through M5;
- opponent physical reception routes through the transition M5 path;
- SET can receive the realised intercepted prefix;
- development paired rollout passes its authority invariants.

### Current obsolete assumptions to reconcile

1. first-ball delivered-height assertions read the reception result's legacy `set_contact_height_meters` even when M5 owns the actual interception height;
2. setter endpoint assertions assume the generated reception destination equals setter contact position.

### Target

For a physical reception:

```text
actual second contact actor
actual contact position
actual contact height
actual contact time
incoming SET trajectory
```

all derive from the **M5 realised interception and realised prefix**.

The intended/designated setter remains soft intent. The planned pass/release target remains legitimate planning state but not realised authority.

### Required transformations

1. Audit all reads/assertions of first-ball pass destination, set-contact height and setter position.
2. Classify each read as planning/perception vs realised gameplay/reporting.
3. Preserve planning/perception uses.
4. Migrate realised gameplay/reporting to M5 interception fields.
5. Make SET incoming trajectory use the realised prefix whenever the feed is a physical interception.
6. Keep legacy reception behavior unchanged with physical reception disabled.
7. Update tests so they assert the realised physical fact rather than the obsolete endpoint identity.

### Must not

- fill the physical reception's legacy height field with a fabricated value merely to satisfy an old assertion;
- move the setter onto the pass endpoint;
- reconstruct an interception from presentation geometry;
- change T1–T3.

### Fast checks

- physical-off path unchanged;
- paired reception launch/prefix/alternate-interceptor invariants remain closed;
- first-ball SET reports the same realised segment that ended at its actual second contact;
- actual contact height/position/time are finite when an interception occurs.

### Done when

The production-on failure set no longer contains the delivered-height or setter-endpoint legacy semantic assertions. Remaining failures are timing/causality failures owned by A1 or unrelated defects.

---

## A1 — Short-leg movement/timing correctness

### Purpose

Resolve the known mismatch exposed when physical reception turns the setter's remaining journey into a short leg.

This is a movement-model/instrument consistency problem, not a reception-physics problem.

### Governing rule

The movement-agreement gate must be **satisfied, not widened**.

### Required diagnostic order

Before changing any magnitude, determine whether the mismatch is caused by:

1. timeline origin mismatch;
2. head-start distance already covered being counted again or omitted;
3. reaction/start delay accounted by one side of the comparison but not the other;
4. standing-start / turn delay already present in the movement model but absent from allotted duration;
5. stepped integration vs analytic comparison using unlike definitions;
6. interception time being measured from launch in one path and from phase start in another;
7. phase-boundary bookkeeping;
8. the gate comparing total window to traversal time instead of the same physical interval;
9. playback/slack logic contaminating a simulation-time comparison.

### Important current semantics

- head start = distance already covered before the remaining leg, not extra time;
- setters should release toward the plan's release target before they know the realised pass endpoint;
- an early arrival should finish its traversal and wait rather than have movement stretched to fill the ball flight;
- real interception time is authoritative once the ball is intercepted.

### Required transformations

1. Instrument the gate enough to print/record both quantities being compared and their component terms for short and ordinary legs.
2. Construct deterministic cases covering:
   - nearly zero remaining distance;
   - short perceptible leg;
   - ordinary setter traversal;
   - head-start case;
   - alternate interceptor if relevant.
3. Identify the first term where the two models cease describing the same interval.
4. Correct accounting/derivation using existing movement authority.
5. Re-run the movement-agreement gate unchanged.
6. Inspect the related causality-floor and blocker-recognition failures individually. Fix them if they are downstream consequences of corrected timing; do not mask them merely because their count falls.

### STOP condition specific to A1

If, after ruling out accounting/instrument mismatches, the movement model genuinely lacks a required relation whose value is not already governed — for example a new authored short-leg acceleration/turn magnitude — stop and return:

- exact equation/path needing the value;
- existing authoritative quantities available;
- measured discrepancy distribution;
- why no existing relation can derive it;
- smallest policy/magnitude decision required.

### Must not

- widen the movement-agreement tolerance;
- add a reception-specific movement constant;
- slow/loft reception balls to make setters reach them;
- alter T1–T3 to satisfy movement timing;
- fit movement to side-out or reception outcomes.

### Done when

- movement-agreement passes unchanged for the physical-reception production path;
- causality-floor corrections caused by the same timing inconsistency are absent or separately explained;
- blocker recognition moments remain causally ordered;
- no new authored magnitude was smuggled in.

---

## A2 — Physical reception production promotion

### Purpose

Make physical reception the production authority and close M4.

### Required sequence

1. Re-run the physical reception paired rollout with A0/A1 changes.
2. Confirm launch immutability, realised-prefix identity, alternate interception, intended misses, T1–T3 bounds, both serving sides and truthful terminals.
3. Run the full suite with production reception off.
4. Flip `ENABLE_PHYSICAL_RECEPTION = true`.
5. Run the full suite with production reception on.
6. Confirm no explicit acceptance-bound failure remains.
7. Confirm dig/coverage/overpass probes remain closed.
8. Update M4 status/docs to DONE.
9. Keep legacy reception machinery only if a live paired comparison still needs it; otherwise mark it for B6 retirement.

### Promotion rule

Outcome/rate movement by itself is an observation, not a blocker.

### Done when

Production ordinary reception owns:

```text
incoming serve
→ receiver physical contact
→ one shared platform launch
→ free flight
→ M5 realised interaction
→ actual second-contact state / truthful terminal
```

and the legacy first-ball endpoint no longer owns production physics.

---

# Cluster B — M6 all-contact consistency

## B0 — Contact-authority census

### Purpose

Build one current table before editing any certified family.

For every ordinary contact/interaction family record:

- incoming authoritative ball source;
- responsibility/action chooser;
- physical feasibility authority;
- execution authority;
- outgoing launch authority;
- free-flight authority;
- actual-next-contact authority;
- classification/reporting authority;
- any legacy/shadow/parallel path;
- current production flag/state.

Families at minimum:

- serve;
- reception;
- set;
- attack;
- block touch / block interaction;
- controlled dig;
- coverage;
- overpass/free-ball first contact if it has distinct routing.

### Rule

A family being different tactically does not authorize a different ownership model.

### Done when

Every ordinary ball contact can be placed in the canonical rubric and every duplicate opinion about a physical fact is named.

---

## B1 — Serve consistency audit

### Existing disposition

Serve is a **certified forward contact**. Do not rewrite it absent controlled evidence of an authority violation.

### Required audit

Verify production order remains:

```text
aim / intent
→ feasible launch selection
→ execution error
→ one launch
→ physical flight
→ net/landing/in-out truth
→ reception read / classification
```

Check specifically:

- no pre-rolled serve verdict manufactures the landing;
- launch state is independent of later receiver;
- receiver read consumes physical launch/flight rather than presentation reconstruction;
- only one production serve launch exists;
- any preserved old error draw or compatibility artifact has no outcome authority.

### Action

If all hold: record CLOSED and do not refactor for style.

If one fails: repair only the demonstrated authority break and certify the boundary.

---

## B2 — Set consistency audit

### Existing disposition

Set is **structurally certified**, not a candidate for a ground-up rewrite.

### Required audit

Verify:

1. incoming ball is the realised trajectory/state of the previous physical contact;
2. setter actor/position/height/time are actual realised state;
3. set choice/tempo/target are intent/decision;
4. setter feasibility/posture is evaluated from body + ball state;
5. one outgoing set ball is produced;
6. attacker options consume that ball rather than an independent set endpoint;
7. opponent, first-ball and transition set paths obey equivalent authority even if presentation/posture fidelity still differs.

### Known current debts to classify, not blindly fix

- opponent/transition set posture gaps;
- unmeasured set-posture pace terms;
- historical duplicate/estimated set-quality paths.

M6 fixes these only if they represent **two authorities or stale derivation**. Pure fidelity/calibration debt may remain for later repair.

---

## B3 — Attack consistency audit

### Existing disposition

Attack is **structurally certified** and geometric attack is already the production outcome authority at the pinned base. Reopen only on proof.

### Required audit

Verify:

```text
set / hitter state
→ attack decision/course/power intent
→ approach/contact feasibility
→ execution
→ one attack launch
→ block interaction + flight
→ physical landing/terminal truth
→ classification
```

Check:

- hit type is decided before downstream derivations that depend on it, or those derivations are recomputed when hit type changes;
- no legacy quality/outcome scalar independently authors a second landing/trajectory;
- home and opponent paths consume the same category of physical facts even where decision logic differs;
- attack event/history refers to the actual launch and realised segment.

Known source comments about stale `hit_type` derivations and delivered-set quality are audit leads, not permission to retune attack outcomes.

---

## B4 — Block consistency audit

### Existing disposition

Block is **structurally certified as an interaction**.

### Required audit

Verify:

1. blockers read/prepare from available pre-contact information;
2. actual blocker body/hand/wall state determines whether/how the attack interacts;
3. a block touch changes the same authoritative ball rather than spawning a hidden replacement outcome ball;
4. the post-block outgoing state, if touched, is one authoritative continuation;
5. floor/coverage systems consume the realised blocked ball;
6. `block_intent`, hand choice and defensive relationship remain intent/state, not terminal verdict authors.

Course-change poses, hand visualization and other presentation fidelity are not M6 authority blockers unless they reveal a simulation state that does not exist.

---

## B5 — Platform-family closure

After A2, verify all three platform contexts use one physical model:

- reception;
- controlled dig;
- attack coverage.

Audit that family labels/context do not choose different T1–T3 coefficients, and that all successful physical contacts feed M5 rather than designated endpoints.

Failures/contacts with no playable outgoing contact must not publish a successful replacement ball merely to preserve a rally.

---

## B6 — Cross-family one-ball chain and authority cleanup

### Purpose

Close M6 by testing the transitions **between** families, where duplicate authority usually hides.

Audit canonical edges:

```text
serve → reception
reception → set
set → attack
attack → block/no-block
block → coverage/dig/terminal
attack/no-touch → dig/terminal
dig → set
coverage → set/transition
overpass → ordinary receiving first contact
```

For each edge assert:

1. downstream incoming ball is the realised upstream ball by identity/launch lineage;
2. contact time is causally after the realised preceding segment;
3. actual actor is physically/legal eligible;
4. source launch remains immutable;
5. no consumer reconstructs the ball from an outcome label or intended endpoint.

### Legacy cleanup

After equivalent physical authority is production-certified:

- remove dead endpoint-authoring branches;
- remove compatibility fields that no remaining live paired probe needs;
- keep historical probes only where they still test a current invariant;
- preserve useful legacy comparison machinery only if explicitly labelled development-only and incapable of production authority.

### M6 done when

Every ordinary contact family can be described by the same ownership rubric, the cross-family one-ball chain holds, and no known production path contains two independent physical answers to the same contact/flight fact.
