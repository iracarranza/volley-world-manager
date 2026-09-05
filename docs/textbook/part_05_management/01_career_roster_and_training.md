# P5-C1 — Career, Roster, and Training

Status: **VERIFIED**
Keywords: CareerManager, save, load, week, day, training activity, block, fatigue, transfer, seeded generation
Primary sources: `scripts/managers/career_manager.gd`; `scripts/systems/training_system.gd`; `scripts/systems/player_generator.gd`; `scripts/models/career_state.gd`

## Prerequisites

- [P1-C2 §3](../part_01_project/02_godot_project_and_runtime.md) — why there are exactly two autoloads
- [P2-C2 §3](../part_02_gdscript/02_resources_nodes_and_signals.md) — `CareerManager`'s signals

## Learning goals

After this chapter you should be able to:

1. describe what `CareerManager` owns and what it delegates;
2. read an entry in `ACTIVITIES` and predict a week's effect;
3. explain why generation is seeded, and what that buys;
4. say where saves live and what a format change must consider;
5. add a training activity using the safe path.

## Vocabulary

| Term | Meaning |
|---|---|
| **Career** | One playthrough: a club, a calendar, a roster, a save. |
| **Activity** | A named training focus with attributes, costs and a description. |
| **Block** | A unit of weekly training capacity an activity consumes. |
| **Regimen** | An active per-player training assignment. |
| **Seeded generation** | Player creation driven by a seed, so it reproduces. |
| **`user://`** | Godot's per-user writable location. Where saves go. |

---

## 1. CareerManager

### 1.1 What it owns

`CareerManager` owns the active career workflow. Its public functions cover
career creation, date and fixture lookup, daily and weekly advancement, training
focus, match preparation and completion, transfers, save/load, and save metadata
listing — `create_career()`, `advance_day()`, `advance_week()`,
`set_training_focus()`, `next_fixture()`, `active_regimens()` among them.

### 1.2 What it delegates

> This is **stateful coordination**. The manager calls systems and changes
> Resources, then emits signals so screens can refresh.

The pattern to notice: `advance_week()` does not contain training formulas. It
calls `VolleyballTrainingSystem`, which is static and testable on its own. The
manager owns *when*; the system owns *what*.

> **Diagnostic.** A formula appearing in `career_manager.gd` is a system
> escaping into a manager — see [P1-C3 §4](../part_01_project/03_repository_map.md).

### 1.3 Days and weeks are different

Both `advance_day()` and `advance_week()` exist. The calendar is not merely a
week counter; `training_day_is_today()` and `hold_drill_session()` show that
some things happen on days within a week. Do not assume a single time step.

---

## 2. Player generation

### 2.1 The entry points

`VolleyballPlayerGenerator.generate_roster()` and `generate_prospect()`
construct players using region and seed inputs.

### 2.2 Why seeded

Seeded generation allows **reproducible careers and test fixtures**. A bug in a
generated player can be re-created; a balance measurement can be repeated.

### 2.3 The shared stream, and why it matters

The generation RNG is a *shared stream*. Drawing an extra value from it shifts
every player generated afterwards — which is why presentation code derives its
choices instead of rolling them. `BodyTypeModels.produce_for()` hashes the
player id for exactly this reason; see
[P7-C1 §2](../part_07_art_and_assets/01_the_voli_body.md).

> **Rule.** Never add an RNG draw to generation without understanding that you
> have changed every subsequent player.

### 2.4 The check that guards it

`_test_world_aging` runs twenty seasons and counts what survives. It is the only
check that will notice a generation change leaking talent, and it has caught a
one-line ceiling bug a thousand other checks did not. **Run the full suite after
touching `player_generator.gd`.**

---

## 3. Weekly training

### 3.1 The activity table

`VolleyballTrainingSystem.ACTIVITIES` is the authored table. One entry:

```gdscript
"Serve Receive": {
	"blocks": 2,
	"attributes": ["reception", "reception_balance", "reception_stability",
		"dig_control", "work_rate"],
	"fatigue": 0.055, "satisfaction": 0.005,
	"familiarity": 0.02, "cohesion": 0.01,
	"description": "Train platform control, movement balance and stability under pace."
},
```

Read it as five separate claims:

| Field | Meaning |
|---|---|
| `blocks` | Weekly capacity consumed |
| `attributes` | Which ratings can move |
| `fatigue` | Physical cost |
| `satisfaction` | Morale effect — can be negative or zero |
| `familiarity` / `cohesion` | Team-level knowledge gains |
| `description` | User-facing text; **not** the specification |

### 3.2 The costs are the design

Notice that `Team Practice` gains the most `cohesion` (0.03) and the least
`fatigue` (0.05) but trains only three attributes, while `Serving` trains six
and gains almost no cohesion. **An activity is a trade, not an upgrade.**

### 3.3 Do not infer from the name

> Inspect `ACTIVITIES` and `apply_week()` for exact current formulas; **do not
> infer an effect from the activity's display name.**

`description` is written for the user. It is a summary, it can drift from the
table beside it, and it has no authority.

---

## 4. Save data

### 4.1 Where it lives

Career saves use `user://`, Godot's per-user writable data location. **It is not
the project repository** — deleting your working tree does not delete saves, and
a save from an older build is still there.

On macOS this resolves under
`~/Library/Application Support/Godot/app_userdata/Volley World Manager/`, the
same place renders land ([P7-C5 §2](../part_07_art_and_assets/05_rendering_probes_and_validation.md)).

### 4.2 What a format change must consider

Older saves and **missing properties**. A load path must supply a default for
every field added since, and that default must be chosen the way
[P2-C2 §1.3](../part_02_gdscript/02_resources_nodes_and_signals.md) describes —
impossible to mistake for a real value.

### 4.3 A worked precedent

`VolleyballPlayer.from_dict()` reads `body_type` with a default of `"Vegi"`, and
then rewrites the retired value `"Homi"` to `"Vegi"`. Both halves are needed:
the default handles saves written *before* the field existed, the rewrite
handles saves written before it was *renamed*. A load path usually needs both
kinds of care.

---

## 5. Safe feature path: a new training activity

1. define the activity in the training system;
2. use **actual** `VolleyballPlayer` properties — check
   `attribute_registry.gd`, do not guess a name;
3. add focused test assertions;
4. ensure `CareerManager` can select and apply it;
5. ensure the relevant screen obtains names and descriptions **from the
   system**, not from a duplicated list;
6. verify save/load preserves resulting player data;
7. run the full suite, because of §2.4.

> Step 5 is the one that produces the classic bug: a screen with its own copy of
> the activity list, which silently omits the new one.

---

## 6. Common mistakes

| Mistake | Consequence |
|---|---|
| A training formula inside `CareerManager` | A system escaped into a manager; untestable alone |
| Trusting `description` over the table | The text is a summary and may drift |
| Adding an RNG draw to generation | Every subsequently generated player changes |
| A screen holding its own activity list | New activities silently missing |
| A save default that looks like a real value | Old saves load as plausible nonsense |
| Assuming one time step | Days and weeks both exist |

---

## 7. Check yourself

1. Where do training formulas live, and where must they not? *(`VolleyballTrainingSystem`; not `CareerManager`.)*
2. Why is generation seeded? *(Reproducible careers and test fixtures.)*
3. You add one RNG draw in generation. What have you changed? *(Every player generated after that point.)*
4. `description` says an activity trains blocking; `attributes` does not list a blocking rating. Which wins? *(The table. The description has no authority.)*
5. Which single check is most likely to catch a generation regression? *(`_test_world_aging` — twenty seasons.)*

---

## Where this leads

- [P5-C2 Connecting Development to Match Options](02_development_to_match_options.md) — making all of this visible on court
- [P4-C4 Tactics, Information and Progression](../part_04_match_engine/04_tactics_information_and_progression.md) — the match side of the same loop
