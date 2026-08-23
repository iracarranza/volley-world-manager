# 00 — Execution protocol

## Objective

Produce the complete rally-engine **first draft** from the pinned base with the smallest possible amount of new design work during implementation.

The agent is expected to reason locally about code, but not to reopen already settled product semantics.

The intended operating loop is:

```text
verify source state
→ read target authority
→ execute next work unit
→ compile / run fast correctness checks
→ repair ordinary implementation consequences
→ record non-blocking debt
→ continue
→ complete causal engine
→ run whole-engine certification
```

## 1. Start-of-run procedure

Before editing:

1. Verify current HEAD against the pinned base `6ce8f3b56e9e533ff575d184a124d26b02431fd5`.
2. If HEAD differs, compare it to the pinned base.
3. For every changed rally-relevant file:
   - classify the change as compatible, superseding, or conflicting with this packet;
   - update the source map mentally or in this packet if necessary;
   - preserve newer implementation truth when it advances the same target semantics.
4. Read all packet documents.
5. Read only the referenced design/review documents needed for the current work unit; do not spend the implementation window re-reading the whole project history.
6. Build an internal checklist from `03_DEPENDENCY_AND_WORK_UNITS.md` and execute it in dependency order.

## 2. Source-audit procedure for every changed authority

Before changing a function/type that owns rally state:

1. Find all direct callers.
2. Find all constructors of its returned/result type.
3. Find all reads of fields whose semantics will change.
4. Find tests/probes that assert those fields.
5. Find serializers/history/reporting/presentation consumers.
6. Classify every consumer:
   - **A — authoritative gameplay**
   - **B — downstream gameplay**
   - **C — diagnostics / probes / tests**
   - **D — presentation / history**
   - **E — legacy compatibility**
7. Migrate A and B to the new authority.
8. Reconcile C so it asserts the new authority rather than historical implementation shape.
9. D must consume simulation truth; it may not reconstruct missing gameplay facts.
10. E may survive only when explicitly required for a paired rollout or fallback. It must not remain production authority after the replacement is promoted.

Do not add a compatibility default merely because one forgotten caller broke. First classify the caller.

## 3. Local implementation discretion

The agent may decide without escalation:

- exact local variable names;
- whether a small repeated operation deserves a helper;
- signature plumbing required to carry already-authoritative state;
- where to place a helper when the ownership rule below determines the module class;
- ordinary type refinements;
- deletion of dead compatibility code after its paired-certification role is finished;
- tests required to preserve an already-stated invariant;
- diagnostics required to expose an already-stated fact;
- source-map corrections when the pinned implementation disproves a stale location.

Helper placement policy:

| responsibility | owner |
|---|---|
| shared physical contact | existing contact-physics module |
| platform T1–T3 | `PlatformContactModel` / existing shared platform resolver |
| free flight / interception | M5 free-flight/interception system |
| reach / traversal / movement time | existing movement/locomotion authority |
| action selection / intent | existing action/role/tactical layer |
| event classification | post-physical classification / resolver |
| diagnostics | tools/tests only |
| UI formatting | presentation only |

Never move simulation authority into UI, diagnostics, test fixtures or migration adapters.

## 4. Refactor policy

Prefer, in order:

1. correct or extend the existing authority;
2. thread its authoritative output to existing consumers;
3. migrate consumers;
4. retire superseded production authority;
5. keep temporary legacy machinery only when a live paired comparison still needs it.

Avoid:

- parallel resolvers for the same physical question;
- duplicate state fields with the same semantic meaning;
- compatibility fields quietly becoming gameplay authority;
- broad renames unrelated to causal correctness;
- new abstraction layers whose only purpose is to hide a migration mismatch;
- rewriting certified families from scratch.

## 5. Work cadence

### During construction

After each small work unit:

- parse/import;
- run the narrow deterministic or focused correctness check appropriate to that unit;
- fix parser/type/runtime/authority failures immediately;
- do **not** run large statistical censuses after every edit unless the work unit explicitly requires one.

After each major cluster:

- run the relevant focused probe(s);
- run enough of the suite to catch structural breakage;
- commit a coherent checkpoint.

### After causal construction is complete

Run:

- the full suite;
- all core authority probes;
- canonical side-out fixtures;
- tactical A/B probes;
- balance/rate observations.

Then cluster failures by upstream cause before repairing individual symptoms.

## 6. What “continue autonomously” means

Do not stop for:

- parser/type errors;
- broken callers;
- missing plumbing;
- stale tests whose asserted authority is explicitly superseded;
- ordinary null/optional handling where the semantic contract determines the correct behavior;
- documentation updates caused by implementation truth;
- diagnostic/probe plumbing;
- a non-blocking rate or distribution shift;
- a certification failure that does not violate an architectural invariant and does not block later construction, once M4 is closed.

Stop only under the rules in `06_FAILURE_TIME_POLICY.md`.

## 7. One special entry condition: M4 must close first

The current source already contains a development-certified physical reception path. The active implementation goal established:

```text
first-ball semantic reconciliation
→ short-leg timing correction
→ reception promotion
→ M6
```

Honor that dependency. Do not use first-draft mode as permission to jump around a known foundational timing/authority boundary.

Once physical reception has production authority and M4 is closed, later non-authority certification failures may be logged and deferred while the complete first-draft structure is built.

## 8. End-of-run deliverable

The implementation agent must leave:

1. a runnable causal first-draft engine;
2. coherent commits/checkpoints;
3. a `FIRST_DRAFT_DEBT.md` or equivalent ledger containing every knowingly deferred failure;
4. final suite/probe results;
5. a short mapping from each failed certification item to its likely owning subsystem;
6. no hidden relaxation of gates or acceptance criteria.
