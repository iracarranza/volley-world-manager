# 06 — Failure handling and five-hour implementation policy

This file changes **workflow**, not simulation semantics.

The goal of the first-draft run is causal completeness with visible debt, not five hours spent forcing one historical assertion green.

## 1. Failure classes

Every failure encountered during implementation must be classified before it is acted on.

### F0 — parser / type / runtime construction failure

Examples:

- project does not parse;
- invalid signature/caller after a migration;
- null state where the target contract requires state;
- ordinary rally crashes.

Action: **fix immediately**.

These prevent later work from being meaningful.

---

### F1 — core authority/invariant violation

Examples:

- one contact creates two authoritative balls;
- launch changes after creation;
- downstream set consumes a synthetic endpoint instead of realised interception;
- next contact occurs before the prior realised segment ends;
- actual actor is physically/legal impossible;
- presentation/diagnostic data feeds gameplay;
- phase reset erases actor state required for the next contact.

Action: **fix before proceeding past the owning work unit**.

Do not defer an architectural contradiction into the debt ledger.

---

### F2 — obsolete historical assertion after an explicit authority move

Example:

- a test requires setter contact at the authored pass endpoint after M5 interception became authority.

Action:

1. state the assertion in semantic language;
2. prove from this packet/existing authority that the old assertion is obsolete;
3. replace it with the equivalent invariant under the new authority;
4. continue.

Do not make old behavior happen merely to preserve the test shape.

---

### F3 — ordinary implementation consequence

Examples:

- caller needs the new realised-state field threaded through;
- diagnostic expects old metadata;
- event/history record needs the new trajectory identity;
- helper placement or type plumbing breaks a focused test.

Action: **fix and continue**.

This is normal migration work, not a STOP.

---

### F4 — certification failure that does not prove missing architecture

Examples after M4 closes:

- symmetry bound fails while both sides now run complete causal paths;
- a rare fixture exposes incorrect timing magnitude inside a built path;
- tactical A/B direction is weaker than expected;
- a movement distribution is implausible but the continuous movement architecture exists;
- an existing balance gate fails due to newly exposed upstream truth.

Action during construction: **record, localize, continue if it does not block later work**.

Action during post-draft certification: repair by upstream cause priority.

Important: a named gate is not “ignored.” It remains failed in the ledger. First-draft mode only changes whether the failure blocks construction of unrelated downstream architecture.

---

### F5 — observational distribution movement

Examples:

- dig rate changes;
- rally length changes;
- alternate-interceptor frequency changes;
- jump-set frequency changes;
- a branch becomes more/less common;
- variable sampling changes suite check count.

Action: **measure and record** unless an existing explicit acceptance bound governs it.

Do not fit physical/decision constants to restore the old distribution.

---

### F6 — genuine missing semantics or authored magnitude

Examples:

- the required physical model needs a new turn/acceleration relation not present in any authority;
- two legal volleyball behaviors are possible and the packet/existing specs do not choose between them;
- the engine requires a new calibration endpoint whose value cannot be derived from existing state.

Action: **STOP**.

Return only the smallest exact decision needed:

- owning path/equation;
- why current authority is insufficient;
- existing quantities available;
- measured evidence if applicable;
- minimal options/decision.

Do not invent the value/semantics to keep the autonomous run alive.

---

## 2. Special rule before M4 closure

A0/A1/A2 remain blocking.

Do not classify the short-leg movement-agreement failure as F4 merely to move to M6. The active implementation sequence explicitly requires it to be resolved first.

After A2 closes physical reception in production, the broader first-draft defer-and-continue policy applies.

---

## 3. Five-hour window strategy

A five-hour coding-agent window should prioritize implementation throughput.

Suggested budget, not a simulation rule:

```text
0:00–0:25  verify HEAD, read packet, build checklist, inspect A0/A1 current source
0:25–1:25  close M4 A0–A2
1:25–2:35  M6 census + contact-family audits + cross-family cleanup
2:35–4:10  M7 continuous action work / integration
4:10–4:35  whole-rally integration cleanup + parser/runtime stabilization
4:35–4:55  full suite + core probes + canonical fixture pass
4:55–5:00  debt ledger / checkpoint / concise report
```

This is a planning heuristic. If M4 legitimately hits F6, stop there rather than consuming the window on speculative work.

## 4. Per-failure timebox after M4

During first-draft construction, if one **non-F0/F1** failure consumes roughly 15–20 minutes without yielding a clear upstream diagnosis:

1. record it in `FIRST_DRAFT_DEBT.md`;
2. record reproduction command/fixture;
3. identify likely owner;
4. note whether later construction depends on it;
5. continue if independent.

Do not use the timebox to abandon an F1 authority violation.

## 5. Debt ledger format

Create/update `docs/implementation/rally_first_draft/FIRST_DRAFT_DEBT.md` during the implementation run.

Recommended entry:

```text
## FD-### — short name

Class: F4 / F5 / etc.
Subsystem:
First observed at commit:
Reproduction:
Expected semantic invariant:
Observed:
Likely owner:
Blocks later construction: yes/no
Why deferred:
Next diagnostic/repair:
```

Never record a known F1 contradiction as “later tuning.”

## 6. Failure clustering after construction

Do not repair the final suite in file/test order.

Cluster by likely upstream cause:

1. ball/contact authority;
2. event/causality timing;
3. movement/actor continuity;
4. responsibility/selection;
5. attack/block physical interaction;
6. asymmetry between home/opponent paths;
7. tactical wiring;
8. presentation/reporting only;
9. calibration/balance.

One upstream correction may close many downstream assertions. Prefer that to symptom patches.

## 7. Gate modification policy

A gate may change only under one of these cases:

### Valid semantic migration

The gate asserted a fact whose authority explicitly moved.

Example:

```text
OLD: setter position == intended pass endpoint
NEW: setter position == realised interception point
```

Replace the assertion. This is not gate widening.

### Valid instrument correction

The gate compares unlike quantities or measures the wrong channel. Correct the instrument so it measures the same stated semantic property.

Do not choose the correction because it makes current output pass.

### Not valid

- widening tolerance because the new engine fails;
- shrinking sample until a failure disappears;
- changing fixture inputs to avoid the failing branch;
- deleting the check with no replacement invariant;
- special-casing the fixture in production code.

## 8. RNG/determinism discipline

When paired before/after measurements depend on RNG:

- preserve draw order unless the change explicitly requires a new stochastic decision;
- if draw order must change, state it and do not attribute downstream deltas solely to the semantic change;
- reset mutable match/player state between deterministic repetitions when the probe claims determinism;
- do not quote a determinism rate from a probe known to reuse mutable state incorrectly.

## 9. Check-count discipline

Variable number of assertions/checks is not itself a regression.

Report:

- failures;
- changed sample population;
- why check count changed if material.

Do not optimize the implementation to recover an old check count.

## 10. Stop report format

If the autonomous run hits F6, return:

```text
STOP: <smallest unresolved question>

Path:
Existing authority:
Missing authority:
Evidence:
Why derivation is insufficient:
Smallest decision needed:
Options, if genuinely discrete:
Work already completed and certified:
```

Do not bury the decision in a long status report.
