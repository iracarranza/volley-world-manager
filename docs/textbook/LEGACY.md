# Legacy Textbook Material

Status: **HISTORICAL**

The directories below belong to the first textbook structure and are retained because they contain useful explanations, exercises, and migration history:

- `part_01_project/`
- `part_02_gdscript/`
- `part_03_workflow/`
- `part_04_match_engine/`
- `part_05_management/`
- `part_06_exercises/`

They were written against an earlier VWM architecture, especially the Gate/shadow persistent-rally migration. Some statements about what is "current", "proposed", feature-flagged, or next are now stale.

## How to use them

Use legacy chapters for:

- historical context;
- beginner exercises;
- explanations of systems that have not materially changed;
- understanding how the current architecture evolved.

Do **not** use them as current authority for:

- rally milestone status;
- which rollout path is live;
- current source symbols without verification;
- current next objective.

For current learning, start at [README.md](README.md). For current rally behavior, use Part IV plus `docs/design/RALLY_MILESTONES.md` and current `docs/review/` handoffs.

## Historical root files

`CHAT_SESSION_SUMMARY_2026_07_30.md` is a historical conversation/project snapshot.

The old Gate-era material referenced by `docs/calibration/` remains useful evidence but should be read as dated certification history unless a current design/review document explicitly cites it as still authoritative.

## Why not delete the old book?

Removing it would throw away useful reasoning and exercises. Keeping it without this boundary would create two competing textbooks. The v2 structure solves that by making the old material an archive/reference layer rather than the main reading path.