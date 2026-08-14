# Volley World Manager

A volleyball management sim in Godot 4. The simulation is the point: numbers
come from models, not from dials, and the interface is a hand-kept journal
rather than a dashboard.

## Run the tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Current branch baseline, verified 2026-08-14 on `7d9ffa0`: **1,851 checks
pass**. Treat any test failure as a regression.

The count itself is not the signal and should not be read as one -- sampling
tests emit a variable number of checks, and this line sat at 1,048 for four days
while the real figure climbed past 1,800, which is the failure mode a stale
baseline has: it is quoted, believed, and never rechecked. **Read the FAIL
line.** A number here is only worth the commit it was measured on, which is why
one is now named.

The slowest gate in the suite is `_test_world_aging`, which runs twenty seasons
of the world and counts what survives. It is the only check that will notice a
generation change leaking talent, and it is worth knowing it exists before
changing anything in `player_generator.gd` -- it has caught a one-line ceiling
bug that 1,047 other checks did not.

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
| The match centre, the whiteboard | `docs/design/THE_TACTICAL_WHITEBOARD.md` |
| Cogniticons, what a voli is showing | `docs/design/COGNITICONS.md` |
| Anything visual | `docs/design/UI_VISUAL_SYSTEM.md` and `UI_VISUAL_SYSTEM_CONSTRAINTS.md` |
| Setter choice, who swings | `docs/design/SETTER_DECISION.md` |
| Tempo, set height, approach | `docs/design/TEMPO_AND_APPROACH.md` |
| Movement, gait, traversal time | `docs/design/LOCOMOTION_AND_GENERATION.md`, `MOVEMENT_FLUIDITY_DRAFT.md` |
| What the other ten players are doing | `docs/design/OFF_BALL_MOVEMENT.md` |
| Clubs, transfers, why the roster matters | `docs/design/CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` |
| Traits and what they may touch | `docs/design/TRAITS.md` |
| Scouts, uncertainty, what a report means | `docs/design/SCOUTING.md` |
| The team wheel, functional contribution | `docs/design/TEAM_ATTRIBUTE_WHEEL.md` |
| Accommodations, food, lodging | `docs/design/ACCOMMODATIONS_AND_CARE.md` |
| Who the manager is | `docs/design/CHARACTER_CREATION.md` |
| Regions, principles, what makes a team feel like itself | `docs/design/REGIONAL_IDENTITY_OVER_A_MATCH.md`, `REGIONAL_DIFFERENTIATION_SPEC.md` |
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
| The scouting board -- cork, pinned | `scenes/screens/scouting_screen.gd` |
| The planner -- the daily schedule | `scenes/screens/schedule_screen.gd` |
| Match centre | `scenes/screens/match_screen.gd` |
| The housing folder -- where the squad lives | `scenes/screens/accommodation_screen.gd` |
| The kitchen -- the block and the paste on it | `scenes/screens/kitchen_screen.gd` |
| The desk -- the home state, not a menu | `scenes/screens/desk_screen.gd` |
| The phone -- a call cutting in | `scenes/components/call_intrusion.gd` |

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
  | `board` -- the match centre | melamine, cool, a wiped smear, no screen | marker rules edge to edge; magnets, not borders | all of it, in four markers, minutes ago |
  | `card` -- the housing folder | manila, buff, a fibre fleck one pixel across | a fold and three cut edges -- no border at all | pencil, and only on hover |
  | `pinned` -- the scouting board | no surface at all: separate scraps on cork | none -- air and shadow, never a line | a pin per item, and biro on the slips |

  **`card` was built for scouting and is now housing's.** A folder is a container
  for *one subject*; a board is a surface where things accumulate and relate.
  Scouting is the second -- connections, unsolicited discoveries, a shortlist
  compared against itself -- and housing is emphatically the first. Each metaphor
  had been attached to the system whose information shape it did not fit. See
  `docs/design/THE_DESK_AND_THE_PHONE.md` §0.

  `pinned` shares its cork with the training clipboard, which is the fourth
  chance this codebase has had to make two objects out of one material. The
  separation is structural, not tonal: a clipboard is mostly *sheet* with a
  margin of cork and one steel clamp; the board is mostly *board*, with many
  tilted scraps and a pin each. `UICorkBoard.clamped` is the one flag that
  switches between them, and `UIPinnedSlip`'s header carries the table.

  `card` is the only medium whose texture is the **material** rather than
  something done to it: a halftone is a reproduction, a form and a board are
  manufactured featureless, and manila is unbleached pulp with the fibre still
  in it. It is also the only one with no line around a surface -- see
  `UICreasedEdge`. Its stock multiplier in Mikasa is large (`3.75, 1.275, 0.586`)
  because getting to buff from a blue ground takes most of the blue out, and that
  multiplier tints a `Button`'s own lettering, which is why `_uncolour_text`
  exists. `docs/design/SCOUTING.md` §Medium.

  `board` is drafted but unbuilt; see `docs/design/THE_TACTICAL_WHITEBOARD.md`.
  Its display face is **Yatra One**, not Cherry Bomb One, and it shares exactly
  one property with `form` -- no halftone -- so building it off `MEDIUM_FORM`
  will reproduce the defect in the row above it.

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
