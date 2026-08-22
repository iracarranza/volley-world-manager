# Fresh-Agent / Fresh-Developer Handoff

Status: **ORIENTATION ONLY — NOT CURRENT DEVELOPMENT AUTHORITY**

Last rebuilt: 2026-08-22.

The original version of this file was an August-1 Gate-era coding-agent handoff. That role now belongs to the repository's **current design/review handoff documents and live source**, because rally work changes too quickly for the textbook to be the task queue.

## If you are a human learning the project

Start with:

1. [README.md](README.md)
2. [Part I — Reading and Writing VWM](part_01_foundations/README.md)
3. the subsystem part you care about;
4. [INDEX.md](INDEX.md) when tracing a question/symbol;
5. [Part VII](part_07_working_safely/README.md) before consequential changes.

## If you are a coding agent/developer continuing active work

Do **not** infer the next implementation task from this textbook.

Instead:

1. inspect `git status --short` and current branch/HEAD;
2. read the repository's current top-level handoff/instruction docs if present;
3. read `docs/design/RALLY_MILESTONES.md` for rally phase status;
4. read the most recent relevant file in `docs/review/` (for the current M5 boundary, `OVERPASS_ACTION_HANDOFF.md` at the time of this rebuild);
5. verify every claimed boundary against live source before behavior changes;
6. run the focused/broad checks in [VALIDATION.md](VALIDATION.md).

Existing unrelated working-tree changes belong to the checkout/user. Preserve them unless explicitly authorized otherwise.

## Stable architectural objective

The rally engine is moving toward:

```text
attributes + tactics
→ perception / responsibility / intent / choice

ball + body + rules
→ legal / physical feasibility

attributes
→ execution quality

contact
→ one authoritative outgoing ball

free flight / interaction
→ actual next situation

RallyEvent / presentation afterward
```

The management architecture should similarly connect manager decisions through durable player/team/world state into mechanisms the match engine actually consumes.

## Stable authority rules

- playback/presentation must not author simulation facts;
- intended recipient does not define physical endpoint;
- physics defines feasibility; tactics/attributes define attempts/execution;
- contact number is context, not action type;
- outcome-rate tuning is separate from correctness migration;
- certified contact families stay closed absent controlled authority failure;
- a feature flag or existing class does not prove production activation;
- a genuine missing design policy/calibration magnitude should be named rather than guessed.

## Current snapshot pointer

See [STATUS.md](STATUS.md) for the textbook's last audited snapshot. If that conflicts with a newer current-branch review/handoff, the newer verified source/review authority wins and this snapshot should be updated.

## Historical handoff

The old detailed Gate-era handoff was intentionally replaced rather than preserved as “authoritative” prose. The earlier textbook/Gate material remains accessible through [LEGACY.md](LEGACY.md) and repository history for anyone studying how the architecture evolved.