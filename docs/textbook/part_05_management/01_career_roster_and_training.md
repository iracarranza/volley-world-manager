# P5-C1 — Career, Roster, and Training

Status: **VERIFIED**
Keywords: CareerManager, save, load, week, training, transfer, roster, fixtures
Primary sources: `scripts/managers/career_manager.gd`; `scripts/systems/training_system.gd`; `scripts/systems/player_generator.gd`; `scripts/models/career_state.gd`

## CareerManager

`CareerManager` owns the active career workflow. Its public functions include career creation, date and fixture lookup, weekly advancement, match preparation/completion, transfers, save/load, and save metadata listing.

This is stateful coordination. The manager calls systems and changes Resources, then emits signals so screens can refresh.

## Player generation

`VolleyballPlayerGenerator.generate_roster()` and `generate_market()` construct players using region and seed inputs. Seeded generation allows reproducible careers and test fixtures.

## Weekly training

`VolleyballTrainingSystem` describes activities and applies a selected activity across a week. Training can affect player attributes and related condition values. Inspect `ACTIVITIES` and `apply_week()` for exact current formulas; do not infer an effect from the activity's display name.

## Save data

Career saves use `user://`, Godot's per-user writable data location. It is not the project repository. A save format change must consider older saves and missing properties.

## Safe feature path

For a new training activity:

1. define the activity in the training system;
2. use actual VolleyballPlayer properties;
3. add focused test assertions;
4. ensure CareerManager can select and apply it;
5. ensure the relevant screen obtains names/descriptions from the system;
6. verify save/load preserves resulting player data.
