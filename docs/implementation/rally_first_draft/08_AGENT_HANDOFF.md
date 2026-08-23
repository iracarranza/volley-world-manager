# 08 — Coding-agent handoff

This is the entry point for Claude Code, Codex or another repo-capable implementation agent after the specification packet has been made available on the implementation branch.

## Short goal prompt

```text
/goal

Complete the rally-engine first draft from the current repo state.

Implementation authority:
`docs/implementation/rally_first_draft/`

Read the complete packet before editing. Verify current HEAD against the packet's pinned base and reconcile only material source-map drift.

Execute the dependency/work-unit order exactly:
M4 reception closeout → M6 contact consistency → M7 continuous per-voli actions → whole-engine integration → post-draft certification.

The packet owns target semantics, authority, existing authored relations, migration procedure, failure classes and certification policy.

Implementation mode:
- inspect callers/types/legacy coupling using the packet procedure
- fix parser/type/runtime/plumbing/stale-test consequences and continue
- do not redesign closed contact families without controlled evidence of authority failure
- no outcome-rate fitting
- no gate widening
- no new authored gameplay magnitude unless already authorized
- after M4 closes, log non-authority certification failures in FIRST_DRAFT_DEBT and continue when independent
- use focused checks during construction; run broad certification after causal first-draft completion
- commit/push coherent checkpoints

STOP only under the packet's F6 rule: required semantics or a required authored magnitude are genuinely absent after existing derivations/authority have been exhausted.

At completion return:
1. first-draft construction status by work unit
2. commits
3. full suite/core probe results
4. remaining debt clustered by upstream owner
5. exact next certification/repair priority
```

## What the agent should not do before coding

Do not write a new high-level rally design memo.

Do not restate the packet as a plan and wait for approval.

Do not ask whether to proceed from one work unit to the next when the dependency is already explicit.

Do not spend the opening hour rediscovering the whole historical rally architecture. Verify the mapped current seams, then implement.

## Expected checkpoint sequence

A productive run will usually leave checkpoints around:

```text
1. A0 semantic reconciliation
2. A1 short-leg timing correctness
3. A2 physical reception production / M4 close
4. B0–B6 M6 audit and convergence
5. C0–C3 continuity through setter/hitter
6. C4–C7 block/defence/phase continuity
7. D0–D3 integrated first draft
8. post-draft certification/debt report
```

Commit boundaries may combine adjacent work when the change is one coherent causal slice. Do not split merely to match numbering.

## Required implementation report

The final report should be concise and evidence-oriented.

Recommended shape:

```text
FIRST-DRAFT STATUS
A0 PASS / ...
A1 PASS / ...
...
D3 PASS / ...

PRODUCTION AUTHORITY
- reception: ...
- contact families: ...
- continuous actors: ...

CERTIFICATION
- suite: X/Y
- authority probes: ...
- M8: ...
- M9: ...

OPEN DEBT
F4/F5 items grouped by upstream owner

STOP/DECISION
none
```

If stopped under F6, do not emit a general implementation report first. Lead with the smallest exact missing decision.

## Using this packet from a newer branch

If substantial rally work landed after the pinned base:

1. compare HEAD to `6ce8f3b56e9e533ff575d184a124d26b02431fd5`;
2. mark already-completed work units complete when newer source genuinely satisfies their target and invariants;
3. do not replay migrations just because the packet describes them;
4. update the source map when filenames/functions moved;
5. continue from the earliest unmet semantic dependency.

This makes the packet an implementation specification rather than a script tied forever to one commit.

## Success criterion for the autonomous run

The desired result is **not** “every number looks good.”

It is:

> A complete, runnable causal first draft in which remaining problems can be investigated as failures of implemented systems rather than as intentionally missing architecture.
