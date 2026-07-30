# P6-C1 — Guided Exercises

Status: **EXERCISES**
Keywords: beginner, practice, source tracing, test, movement, opportunity
Primary sources: varies by exercise

Do one exercise at a time and commit only after validation.

## Exercise 1: Runtime treasure hunt

Goal: learn navigation without changing code.

1. Find the main scene path.
2. Find both Autoload definitions.
3. Trace the rally button to `RallySimulator.resolve`.
4. Find where the returned events are played.
5. Write the source path and symbol for each step.

Success: your path matches [P1-C4](../part_01_project/04_following_a_user_action.md).

## Exercise 2: Add a harmless analysis field

Goal: practice result contracts.

Add one diagnostic value to rally analysis, such as the count of events containing `movement_duration`. Do not change rally outcomes.

Success:

- a focused test checks the value;
- existing tests pass;
- parser scan succeeds;
- playback is unchanged.

## Exercise 3: Inspect reception opportunities

Goal: understand the persistent foundation without wiring it into live play.

Construct a `RallyState` in a test, launch a serve, call `generate_reception_opportunities`, and print each player's arrival margin and feasibility.

Success: moving a player farther from the destination makes their opportunity no better, assuming all other inputs remain fixed.

## Exercise 4: Attribute threshold experiment

Goal: see how growth could create options.

Clone a test player's setup, change only lateral speed, and compare opportunity results. Find a position where one version is late and the other is viable.

Success: the difference appears in an explicit opportunity field, not only in prose.

## Exercise 5: Continuity assertion

Goal: prevent teleports.

Write a test asserting that after applying movement, the next estimate begins at the updated player-state position rather than tactical home.

Success: the test would fail if a reset were inserted between actions.

## Exercise 6: Documentation truth check

Goal: learn evidence maintenance.

Pick five claims in this book. Locate each source and symbol. If any is stale, update the chapter, evidence ledger, and source manifest.
