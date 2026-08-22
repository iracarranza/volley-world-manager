# 06 — Career State, Managers, Saving, and Persistence

Status: **VERIFIED**

The career layer separates **state** from **orchestration**:

```text
VolleyballCareerState (Resource)
→ what must persist

CareerManager (autoload Node)
→ creates/loads/saves/advances and coordinates systems
```

That distinction is one of the most useful patterns in the project.

## CareerState is the durable record

`VolleyballCareerState` stores long-lived facts including:

- save/career/organization identity;
- manager identity and appearance;
- region and club identity;
- week/day/calendar and training-session state;
- finances/reputation;
- training regimens;
- scouting marks and staff;
- fixtures/active fixture;
- housing/food/familiarity data;
- Sixnet/world state;
- references/IDs into the world population.

If a fact must survive closing and reopening the game, it generally needs a path into this durable model or another explicitly persisted store.

## CareerManager is a Node because it coordinates runtime work

`CareerManager` extends `Node` and is available as an autoload. `Application` retrieves it from:

```gdscript
get_node("/root/CareerManager")
```

**Godot reminder:** an autoload is created by Godot at application startup and placed under `/root`. It is a practical way to keep a manager/service alive across screen/scene changes.

The manager performs actions such as:

- career creation;
- advancing day/week;
- applying training;
- loading/saving;
- constructing/maintaining transfer/world pools;
- coordinating fixtures/world systems;
- emitting change signals.

It should not become the place every individual model calculation lives.

## Creating a career is dependency assembly

`create_career()` constructs a `CareerState`, creates a Team, generates the starting roster, configures principles/familiarity, creates fixtures/staff/world population/market state, then saves and emits change signals.

Conceptually:

```text
player choices
→ CareerState identity
→ Team/principles
→ generated roster
→ world/competition/staff
→ GameManager managed team
→ saved career
```

This is a good place to look when asking “what must exist for a new save to be valid?”

## Signals keep screens from owning state

`CareerManager` exposes signals such as:

```gdscript
signal career_changed
signal career_loaded
signal week_advanced(report: Dictionary)
signal transfer_pool_changed
```

A screen can refresh when state changes without becoming the state owner.

This is the same event pattern introduced in the UI chapters, but at a longer-lived layer.

## Daily clock versus weekly work

The career calendar advances by day so appointments/training days have a place in time, while training development is still applied at weekly granularity.

This is a useful modeling distinction:

```text
day
→ player-facing schedule / appointment position

week
→ accumulated training/development application
```

Do not assume adding a finer UI clock requires recalculating every system at that granularity.

## Save conversion is explicit

`CareerState.to_dict()` writes a Dictionary representation. `from_dict()` reconstructs current Resources and performs migrations/defaults for older data.

Examples of migration behavior include:

- older organization-type values mapping into current established/founded semantics;
- missing staff becoming a valid empty staff list;
- legacy world/region-power data seeding newer separated fields;
- older inlined transfer players still loading while current saves use IDs into the world population.

This is why deleting an “old-looking” field/parser branch can break existing saves even when new careers do not use it.

## `user://` is writable persistent storage

Career saves live under a path such as:

```text
user://careers
```

`user://` is Godot's platform-specific writable application-data directory. Unlike `res://`, it is appropriate for saves, settings and caches.

Do not write runtime save data into the project resource directory.

## Large data can be split from frequently written data

The world population is large and changes much less often than the core career file. `CareerManager` stores/loads it as a sidecar and loads it lazily on first use.

This solves two separate problems:

```text
career file
→ small/frequently rewritten / immediately needed

world population sidecar
→ large / rarely needed on journal startup
```

A save model does not have to be one monolithic JSON object.

## Lazy world loading

The `world_population` property getter checks whether the sidecar is loaded and reads it only when something such as scouting/transfers actually needs it.

This is the same architectural idea as lazy UI screen creation: **do expensive work at the first meaningful consumer**, not merely because the program started.

## Persistence bugs are often ownership bugs

A common symptom is:

> “this value works until I reload.”

Trace:

1. where the runtime value is written;
2. whether it belongs in CareerState/player/another persisted object;
3. whether `to_dict()` includes it;
4. whether `from_dict()` reconstructs it;
5. whether the manager overwrites it with a default after loading.

Do not solve persistence by creating a second hidden settings file unless the fact truly belongs there.

## Save migrations should be one-way interpretations

When loading older data, prefer:

```text
old representation
→ interpret into current model
```

rather than spreading `if old_save` branches throughout gameplay code.

The rest of the application should ideally receive a current `CareerState` regardless of save age.

## Safe extension: adding persistent state

For a new persistent field:

1. define it with a sensible default;
2. decide which Resource owns it;
3. write it in `to_dict()`;
4. load/sanitize it in `from_dict()`;
5. decide the legacy default/migration;
6. test save → reload → equality/behavior;
7. update UI/system consumers;
8. avoid serializing duplicate copies of large shared objects.

## Reading exercise

Choose `scouting_marks`, `training_regimens`, or `manager_appearance`.

Trace:

```text
screen/action
→ CareerManager mutation
→ CareerState field
→ to_dict
→ saved data
→ from_dict
→ screen/system after reload
```

Then identify what happens for a save created before that field existed.

## Source trail

- `scripts/models/career_state.gd`
- `scripts/managers/career_manager.gd`
- `project.godot` autoload section
- `scenes/application.gd`
- player/team/fixture `to_dict()` / `from_dict()` implementations

Part IV moves into the most technically complex part of the project: the rally simulation and its current physical-authority migration.