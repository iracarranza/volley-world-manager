# 02 — Shadow Systems and Guarded Rollout

Status: **HISTORICAL METHOD, STILL RELEVANT**

A shadow system calculates what a proposed architecture *would* do without letting it decide the official rally.

VWM used shadow → audit → guarded selection → development promotion extensively during the earlier persistent-rally migration.

## Why shadow first

Changing a rally resolver can alter thousands of outcomes at once. If the new system immediately becomes authoritative, it is hard to tell whether differences come from:

- intended semantics;
- a state-construction bug;
- missing information;
- a unit mismatch;
- a bad calibration;
- an integration mistake.

Shadow mode lets the project ask:

> Given the exact same rally circumstances, what would the new system say?

while preserving the baseline result.

## The gate pattern

Historical reception/set/attack/block migrations often followed a structure like:

```text
foundation/state
→ shadow candidate
→ measurement/progression calibration
→ audit
→ rollout policy
→ development-only live integrator
```

The numbered Gates in `docs/calibration/` record these checkpoints.

They are valuable evidence and history, but current runtime authority must be checked against current source/docs.

## Shadow must be information-honest

A shadow system is not useful if it cheats because “it doesn't affect outcomes anyway.”

For example, blocker perception work deliberately limited shadow blockers to cues they could actually observe before the attack resolved, then graded their decision against truth afterward.

Otherwise the shadow candidate would look unrealistically good and later promotion would fail.

## `RallyTrace` and comparison records

Diagnostic records can store:

- candidate decisions;
- timing margins;
- reasons for rejection;
- legacy/new fingerprints;
- disagreement classifications.

These are **evidence**, not authority.

A trace may say “new system would choose player 7.” It must not secretly mutate the rally simply because a debug overlay wants to show that candidate.

## Guarded rollout

A rollout policy provides one explicit boundary where the resolver can choose legacy versus new source under controlled conditions.

This is better than scattering feature-flag checks through every calculation.

Conceptually:

```text
legacy candidate
new audited candidate
→ rollout policy
→ one authoritative source
```

## Development-only promotion

The older migration used flags allowing explicit debug/development fixtures to exercise the new path without enabling ordinary production rallies.

This allowed tests to verify the *integration*, not only the isolated calculation.

A candidate can be mathematically correct but still fail when:

- event metadata is incomplete;
- contact count is wrong;
- downstream code expects legacy fields;
- state is reconstructed incorrectly.

## Why current M4/M5 work looks different

The current platform/free-flight migration inherits the same certification discipline but is not simply continuing the old numbered gate sequence.

Recent work tends to use:

```text
controlled fixture / probe
→ design/review authority
→ development path
→ live integration
→ production promotion decision
```

Do not force every new milestone into an obsolete feature-flag/gate abstraction just because that pattern existed before.

## Feature flags are not design authority

A Boolean flag tells you which path can run. It does not tell you whether that path *should* be enabled.

Promotion requires evidence that downstream semantics are complete.

That is why `ENABLE_PHYSICAL_PLATFORM_DIG` remains false even though development physical-dig/free-flight behavior is substantially built: the production boundary includes downstream overpass/continuation correctness.

## Byte-neutral changes

A shadow or rare-branch integration can be **byte-neutral** over ordinary seeded rallies while still being meaningful.

Current overpass control wiring, for example, fired 0 times in a 1,200-rally ordinary census. The full suite matched with and without the resolver change, while a constructed fixture proved the novel path.

This is a valid certification shape:

```text
ordinary baseline unchanged because branch absent
+
constructed fixture proves branch when present
```

## When shadowing is no longer useful

Do not keep a certified system in permanent shadow merely because comparison is comfortable.

Once authority is governed and integration proven, parallel legacy/new paths become maintenance debt.

The roadmap explicitly includes **legacy retirement** as progress.

## Reading historical gate docs

When opening a Gate document, identify:

- date/commit;
- what was authoritative at that time;
- what candidate was being measured;
- which invariants were proven;
- what remained blocked;
- whether later milestones superseded the boundary.

Never copy an old “NEXT” section into current work without checking newer review docs.

## Source trail

- `docs/calibration/` Gate documents
- old textbook `part_04_match_engine/05_migration_and_visible_proof.md`
- rollout/audit/integrator classes under `scripts/simulation/`
- current `docs/design/RALLY_MILESTONES.md`

Next: a chronological map of the major migrations that turned the phase resolver into the architecture described in Part IV.