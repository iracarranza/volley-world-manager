# P6-C1 — Guided Exercises

Status: **EXERCISES**
Keywords: beginner, practice, source tracing, test, movement, opportunity, rendering, validation
Primary sources: varies by exercise

## Prerequisites

Each exercise names its own. As a whole, Part 6 assumes
[Part 1](../part_01_project/README.md) and [Part 3](../part_03_workflow/README.md).

## How to use this chapter

**Do one exercise at a time and commit only after validation.**

Each exercise states what it teaches, what to read first, roughly how long it
takes, and how you know you are done. The success criteria are deliberately
falsifiable — "it works" is not one of them.

| Exercise | Teaches | Difficulty | Reads |
|---|---|---|---|
| 1 | Navigation | ● | P1-C4 |
| 2 | Result contracts | ●● | P1-C4, P2-C2 |
| 3 | Persistent foundation | ●● | P4-C2, P4-C3 |
| 4 | Progression as options | ●●● | P4-C3, P5-C2 |
| 5 | Continuity invariants | ●●● | P4-C2, P3-C2 |
| 6 | Evidence maintenance | ● | P3-C1 |
| 7 | Reading a spec | ●● | P7-C1 |
| 8 | Measured thresholds | ●● | P7-C2 |
| 9 | Verifying by rendering | ●●● | P7-C1, P7-C5 |

---

## 1. Runtime treasure hunt

**Teaches:** navigation without changing code. **Difficulty:** ●

1. Find the main scene path.
2. Find both Autoload definitions.
3. Trace the rally button to `RallySimulator.resolve`.
4. Find where the returned events are played.
5. Write the source path **and symbol** for each step.

**Success:** your path matches
[P1-C4 §1](../part_01_project/04_following_a_user_action.md).

> **Hint.** Do not search for function names you expect to exist. Start from the
> scene and follow connections — this codebase contains superseded paths that
> still parse.

---

## 2. Add a harmless analysis field

**Teaches:** result contracts. **Difficulty:** ●●

Add one diagnostic value to rally analysis — for example the count of events
containing `movement_duration`. **Do not change rally outcomes.**

**Success:**

- a focused test checks the value;
- existing tests pass;
- parser scan succeeds;
- playback is unchanged.

> **Hint.** Measure the suite *before* you start
> ([P3-C1 §4](../part_03_workflow/01_safe_change_workflow.md)). This is a change
> that should move the count by exactly the checks you write.

---

## 3. Inspect reception opportunities

**Teaches:** the persistent foundation, without wiring it into live play.
**Difficulty:** ●●

Construct a `RallyState` in a test, launch a serve, call
`generate_reception_opportunities`, and print each player's arrival margin and
feasibility.

**Success:** moving a player farther from the destination makes their
opportunity **no better**, all other inputs fixed.

> **Note the phrasing.** "No better" rather than "worse" — a player already out
> of range does not become more out of range. Assertions should not claim more
> than the model does.

---

## 4. Attribute threshold experiment

**Teaches:** how growth creates options rather than percentages.
**Difficulty:** ●●●

Clone a test player's setup, change **only** lateral speed, and compare
opportunity results. Find a position where one version is late and the other is
viable.

**Success:** the difference appears in an **explicit opportunity field**, not
only in prose.

> **Why this is the important exercise.** You are reproducing the design test
> from [P5-C2 §6](../part_05_management/02_development_to_match_options.md). If
> you cannot find such a position, that is a finding worth reporting, not a
> failed exercise.

---

## 5. Continuity assertion

**Teaches:** preventing teleports. **Difficulty:** ●●●

Write a test asserting that after applying movement, the next estimate begins at
the **updated player-state position** rather than tactical home.

**Success:** the test would fail if a reset were inserted between actions.

> **Verify the success criterion literally.** Insert a reset, watch the test
> fail, then remove it. A regression test you have never seen fail may assert
> nothing — [P3-C2 §6.2](../part_03_workflow/02_debugging_testing_and_git.md).

---

## 6. Documentation truth check

**Teaches:** evidence maintenance. **Difficulty:** ●

Pick five claims in this book. Locate each source and symbol. If any is stale,
update the chapter, the evidence ledger and the source manifest.

Then run the validator:

```bash
godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

**Success:** the validator passes, and you can name what you changed.

> This exercise has caught real errors. Two symbols in this book —
> `_show_dashboard` and `generate_market` — named functions that did not exist,
> one of them a deliberately retired name.

---

## 7. Read a body spec

**Teaches:** reading a `Dictionary` spec and predicting its mesh.
**Difficulty:** ●● **Reads:** [P7-C1](../part_07_art_and_assets/01_the_voli_body.md)

Open `scripts/data/body_type_models.gd` and find the `Tomato` and `Stalk` torso
specs. Without rendering anything:

1. state which is wider and by how much;
2. state which is taller;
3. predict which reads as squat and which as upright;
4. find each one's `depth_scale` and say what it does to the cross-section.

Then render the vegi plate and check yourself:

```bash
godot --path . res://tools/voli_portfolio.tscn
```

**Success:** your predictions match the plate, or you can explain precisely why
they did not.

---

## 8. Verify a kit threshold by hand

**Teaches:** that a threshold is only meaningful against a measured
distribution. **Difficulty:** ●● **Reads:** [P7-C2](../part_07_art_and_assets/02_kits_colour_and_marks.md)

1. Pick any three kits from `RegionalKits.KITS`.
2. Compute each one's contrast against the floor colour
   `Color(0.7451, 0.5098, 0.3725)` using
   `(lighter + 0.05) / (darker + 0.05)` on luminances.
3. Confirm each clears `1.6`.
4. Now invent a mid-tan and compute its score.

**Success:** your midtone lands near `1.1`, and you can explain why the gate was
originally shipped at `3:1` and failed twelve of fourteen real kits.

---

## 9. Change a body and prove it

**Teaches:** the full visual validation ladder. **Difficulty:** ●●●
**Reads:** [P7-C1](../part_07_art_and_assets/01_the_voli_body.md), [P7-C5](../part_07_art_and_assets/05_rendering_probes_and_validation.md)

Add one **extra** to a body — a brow, a rib, a collar — using the extras array.

1. Run the validator; confirm it still passes.
2. Render the portfolio and find your part.
3. Render again at a **different angle** and confirm it still reads.
4. Revert.

**Success:** you can state which of those steps a probe could have replaced and
which it could not.

> **The point of step 4.** The exercise is the verification, not the part. Most
> of what you learn here is how easy it is to believe a stale PNG.

---

## 10. Where to go next

- [P6-C2 Beginner Project Ladder](02_beginner_project_ladder.md) — the migration
  reconstructed as a teaching sequence
- [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md) — the actual next task, when
  you are ready to do real work
