# Volley World Manager

A volleyball management sim in Godot 4. The simulation is the point: numbers
come from models, not from dials, and the interface is a hand-kept journal
rather than a dashboard.

## Run the tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

937 checks. **Two are expected to fail** and are long-standing and unrelated to
current work -- `Allotted duration and the movement model agree for every phase
type` and `defensive attack lowers both error risk and terminal pressure across
six career seeds`. Anything beyond those two is a regression you caused.

After adding or renaming a `class_name`, re-import before the suite will see it:

```bash
godot --headless --path . --import
```

`--check-only` reports autoload identifiers (`GameManager`, `CareerManager`) as
undeclared. That is not a real error.

## Read before you change things

**`docs/FAILURE_MODES.md` first, and its §0 screen in particular.** Every entry
is a mistake actually made in this repository, most of them more than once. The
recurring one is worth stating here: *a value measured with the wrong
instrument, or a knob that cannot reach its own stated range.* Before shipping a
threshold, measure the distribution it acts on. A threshold outside its
distribution does nothing, and does nothing silently.

Then, by subject:

| Working on | Read |
|---|---|
| Tactics, training, drills, the planner | `docs/design/TACTICS_AND_TRAINING.md` |
| The title screen | `docs/design/TITLE_SCREEN.md` |
| Anything visual | `docs/design/UI_VISUAL_SYSTEM.md` and `UI_VISUAL_SYSTEM_CONSTRAINTS.md` |
| Setter choice, who swings | `docs/design/SETTER_DECISION.md` |
| Tempo, set height, approach | `docs/design/TEMPO_AND_APPROACH.md` |
| Movement, gait, traversal time | `docs/design/LOCOMOTION_AND_GENERATION.md`, `MOVEMENT_FLUIDITY_DRAFT.md` |
| Ball flight | `docs/design/BALL_LAUNCH_KINEMATICS.md` |
| Player generation, bodies | `docs/design/ATTRIBUTE_FIRST_GENERATION.md`, `BODY_TYPES.md` |
| Setting, regions, naming | `docs/world/` |
| What is designed but unbuilt | `docs/BACKLOG.md` |

`docs/textbook/` is the reference layer -- `EVIDENCE.md` and
`GLOSSARY.md` are the two worth knowing exist.

## Names

The interface is a desk with objects on it. Use these names in code, comments
and conversation; they are not decorative and the old ones have been renamed
away.

| Object | Screen |
|---|---|
| The journal -- the club | `scenes/screens/journal_screen.gd` |
| Training clipboard -- tactics and drills | `scenes/screens/training_screen.gd` |
| Scouting folders | `scenes/screens/scouting_screen.gd` |
| The planner -- the daily schedule | `scenes/screens/schedule_screen.gd` |
| Match centre | `scenes/screens/match_screen.gd` |
| The desk -- the menu | *not built yet* |

"Career dashboard" and "recruitment" are dead names. A player is a **voli**.

## Conventions

- **Full-screen pages are built on `VolleyballScreenShell`** -- backdrop,
  ribbon, card. A page built from a bare `MarginContainer` gets no background,
  which is invisible in the dark theme and unreadable in the light one.
- **A medium is a whole material, not a border.** `UIStyleSystem` carries a
  `ui_medium` down the tree and each one owns the *substrate, the stock, the
  divisions and the hand* together. Changing only the edge is what made the
  clipboard read as the journal with a different outline.

  | medium | substrate | divisions | who made the marks |
  |---|---|---|---|
  | `sewn` -- the journal | halftone, warm cream, per-patch tint | running stitch | everything, by hand |
  | `form` -- the clipboard | flat stock, cooler, unscreened | printed hairlines, square corners, faint grid | only the annotation: marker, red pen, highlighter |
  | `drawn` -- default | halftone, pen edge | broad-nib pen | by hand |

  The title screen is exempt from all of it because it is not an object on the
  desk but the **room the desk is in**. See `docs/design/TITLE_SCREEN.md`.
- **Comments say why, not what.** The house style explains the decision and,
  where a previous version was wrong, what it got wrong and how that was
  measured.
- **Themes are `Mikasa` (dark) and `Molten` (light)** everywhere they are named.
- Godot gotchas that have cost time before: `_`-prefixed parameters mean
  explicitly unused; `%-22s` padding only aligns in a monospace font and this
  interface is not set in one; `MOUSE_FILTER_IGNORE` on children keeps a row one
  click target; a `Control` under a `Container` has its rect recomputed every
  layout pass and will fight a `Tween`.
