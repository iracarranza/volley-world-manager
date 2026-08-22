# 06 — Making a First Safe Change

Status: **VERIFIED METHOD**

A safe change is not “a small diff.” It is a change whose **authority, expected consequence, and proof** you understand.

VWM has many systems where a one-line edit can alter thousands of rallies. Conversely, a large UI refactor may change no game state at all. Size is not the same as risk.

## The development loop

Use this loop until it becomes automatic:

```text
inspect
→ identify owner
→ predict consequence
→ make the smallest coherent change
→ run focused proof
→ run broader regression checks
→ inspect the diff
→ update docs if authority changed
```

The important step is **predict consequence before editing**. If you cannot state what should change and what should remain invariant, you do not yet have a testable change.

## Begin from the owner

Suppose a card's padding is wrong.

Do not immediately add margins to the screen that happens to contain it. Trace the component/theme ownership first:

```text
screen
→ MenuCard
→ shared Theme/StyleBox
```

If every card is wrong, the shared style is probably the owner. If one card is wrong because its content wraps, the component/layout logic may own it.

The same rule applies to simulation:

```text
wrong physical feasibility
≠ fix outcome label

wrong ball path
≠ fix playback curve
```

Change the layer that owns the fact.

## Inspect `git status` first

Before modifying a checkout:

```bash
git status --short
```

Existing modifications may belong to another task. Do not reset, clean, overwrite, or “fix” them merely because they are unrelated to yours.

**Git reminder:** a working tree can contain uncommitted work that GitHub cannot show you. A remote branch being clean does not prove the local checkout is clean.

## Make a prediction

A useful prediction contains both change and non-change.

Example UI prediction:

> Increasing the shared button content margin should move button text inward on every themed button; it should not change which signal is emitted when pressed.

Example simulation prediction:

> Repairing a state-continuity copy should cause the constructed compromised-player fixture to carry the state into the next phase; ordinary rally outcomes should remain unchanged if upstream recovery already excluded the player.

This is much stronger than “the test should pass.”

## Prefer semantic tests over counts

A test count changing from 2160 to 2164 may simply mean four assertions were added. It says nothing by itself about correctness.

Ask what the checks prove:

- source launch remained immutable;
- one contact was recorded;
- unavailable actor was excluded;
- theme change invalidated stale sticker palette;
- save/load reconstructed the same career field.

VWM often uses deterministic constructed fixtures because rare but legal states may occur 0 times in a thousand ordinary rallies. Lack of natural incidence is not proof that a branch is unnecessary.

## Focused proof first

Run the smallest instrument that directly exercises your boundary.

Examples in this repository include:

- targeted headless probes under `tools/`;
- preview scenes for visual systems;
- focused methods in `tests/test_runner.gd`;
- deterministic calibration scripts.

Only after focused proof passes should you spend time interpreting the full suite.

## Full-suite failures need diagnosis

A broad test failure after your change may be:

1. a real regression;
2. an expected assertion that needs updating because authority intentionally changed;
3. a pre-existing warning/failure;
4. a flaky or stateful probe;
5. a test instrument whose assumption is now stale.

Do not weaken a gate merely to restore green output.

For simulation work especially:

```text
failed test
→ diagnose semantic disagreement
→ repair code OR repair stale test

NOT
failed test
→ widen tolerance until green
```

## GDScript errors: fix the first real parser/runtime error

Godot errors can cascade. A malformed line may cause later files to appear broken because their dependency never loaded.

Common categories:

- **Parser Error** — source could not be parsed.
- **Invalid access / get index** — you assumed a property/key exists when it does not.
- **Null instance** — the object-producing path returned `null`.
- **Type mismatch/inference failure** — the declared or inferred type is incompatible.

Read the first relevant error and its source location before reacting to everything printed after it.

## Inspect the diff as a reader

Before considering a change complete, read its diff without mentally supplying your intention.

Ask:

- Is every changed line needed?
- Did a refactor accidentally change policy?
- Did I duplicate an existing constant or threshold?
- Is a comment now false?
- Did I alter a source-of-truth boundary?
- Did I modify generated/cache/output files that should not be committed?

A diff is the version of your work another maintainer receives.

## When to update design documentation

Update design/review docs when the change alters:

- what system is authoritative;
- a milestone status;
- a public data contract;
- a governed policy;
- an explicitly authored/calibrated value;
- a certification boundary.

Do not turn every bugfix into a new design doctrine.

## A safe first exercise

Choose one read-only/UI-facing task, for example:

> Add a temporary label to a local preview scene showing the current theme name.

Before coding, identify:

- which preview owns the display;
- where theme state comes from;
- why the label must not become a new source of theme truth;
- how to remove it cleanly afterward.

Then run the scene, inspect the diff, and revert the exercise if it is not meant for production.

The value is the loop, not the feature.

## The VWM standard

For consequential work, the project increasingly uses:

```text
controlled fixture
→ measurement
→ explicit authority/policy decision
→ implementation
→ focused certification
→ broad regression
→ documentation
```

Later Part VII explains this in depth. For now, remember the central rule:

> **Do not make the simulator or UI say the answer you wanted. Change the owning mechanism and prove that the answer follows.**

## Next

Part II applies these foundations to the interface: screens, Controls, reusable paper components, sticker rendering, shaders, and visual probes.