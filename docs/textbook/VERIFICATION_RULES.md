# Verification Rules

These rules keep the textbook useful without allowing confident prose, old Gate notes, or source-code existence to become false project facts.

## Rule 1 — `VERIFIED` requires current evidence

A VERIFIED implementation claim should be traceable to current source and, where authority/promotion matters, the current design/review certification.

Prefer stable identifiers:

- project-relative file path;
- class/function/signal/property name;
- named review/certification document;
- commit/checkpoint where status depends on it.

Avoid depending on line numbers in prose; they drift quickly.

## Rule 2 — existence ≠ activation ≠ production authority

Keep these separate:

```text
code exists
→ can be called/tested

integrated
→ real runtime path reaches it

production-authoritative
→ ordinary gameplay actually uses its result
```

A class, test and feature flag can all exist while ordinary rallies still use another authority.

## Rule 3 — implementation status needs a layer

Avoid vague `DONE` for migrating systems. State whether something is:

- constructed;
- shadow/diagnostic;
- development-authoritative;
- live-integrated;
- production-enabled;
- legacy-retired.

Milestone status is governed by the canonical roadmap/review evidence, not by file existence.

## Rule 4 — future design must say `PROPOSED`

Future action vocabulary, roadmap work, illustrative architecture and teaching examples must not read as current runtime behavior.

If a section mixes current and future concepts, label the boundary explicitly.

## Rule 5 — historical evidence stays historical

Gate/calibration/session documents can prove how a system evolved, but an old `NEXT`, old rollout flag state or old “current architecture” paragraph does not override newer source/review docs.

Part V and [LEGACY.md](LEGACY.md) exist so history can teach without becoming current authority.

## Rule 6 — source code outranks stale textbook prose; design authority governs semantics

If textbook prose contradicts live source, inspect the source and tests/review evidence, then fix the textbook.

Do **not** change working gameplay merely to make old prose true.

For questions of intended policy/semantics—not merely what code happens to do—check the current owning design document/review ruling as well.

## Rule 7 — presentation cannot prove simulation authority

A rendered trajectory, player pose, sticker, card, caption or debug overlay may correctly display a fact. It does not thereby own that fact.

To claim simulation behavior, trace back to the simulation/model/system that produced the data.

## Rule 8 — tests prove only their assertions

A passing test does not automatically prove:

- visual quality;
- complete live integration;
- production promotion;
- realism;
- balance;
- behavior of a branch the fixture never reaches.

Read the assertions and fixture conditions.

## Rule 9 — counts/rates require instrument context

A suite check count or outcome frequency is not self-explanatory.

Record:

- sample/fixture;
- seed handling;
- units;
- branch incidence;
- what was counted/classified;
- whether state/caches were reset.

Outcome deltas during correctness migration are observations unless a calibration/balance pass explicitly makes them acceptance targets.

## Rule 10 — units come from the producer

Do not label a number by what the surrounding concept sounds like. Trace the field/function that produced it.

An angular execution model may produce a downstream spatial-error measurement in metres; both are valid but different.

## Rule 11 — use exact project vocabulary

Similar names are not interchangeable:

```text
intent target ≠ actual interceptor
free flight ≠ realised segment
tactical home ≠ current position
RallyEvent ≠ RallyState
contact number ≠ action type
coverage ≠ floor defence
```

Use the terms defined by their current source/design contracts.

## Rule 12 — uncertainty is allowed

Use **UNVERIFIED** when current evidence has not been inspected. Use **PARTIALLY IMPLEMENTED** when code is real but the path is incomplete.

A stated unknown is more useful than an invented completion.

# Evidence precedence

For a current architecture question, prefer roughly:

1. current live source + focused tests/probes;
2. current canonical design/review/certification docs;
3. current textbook Part IV/VI/reference snapshot;
4. historical Gate/review material;
5. old textbook/session summaries.

This is not a rule that source accidents define intended design; when source and current policy disagree, report the discrepancy rather than silently choosing one.

# Machine-readable maintenance

- `source_manifest.json` lists high-value textbook files and source symbols for existence checks.
- `tools/validate_textbook.gd` checks that those files/symbol strings still exist.
- [VALIDATION.md](VALIDATION.md) explains the broader manual/runtime checks that the manifest cannot perform.
