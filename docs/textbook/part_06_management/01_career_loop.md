# 01 — The Career Loop

Status: **VERIFIED**

VWM's career loop connects a persistent club/world to individual matches.

At a high level:

```text
career/desk state
→ schedule / training / scouting / roster decisions
→ lock in team/tactics
→ resolve match/rallies
→ update player/team/career state
→ advance calendar/world
→ new decisions
```

The important architecture is that each subsystem owns its own state while `CareerManager` coordinates the long-lived sequence.

## Day and week

The career now tracks a day within an absolute week.

`advance_day()`:

- refuses to skip an unhandled training-day decision;
- advances within the week;
- when the week ends, invokes weekly advancement and returns to Monday.

The week remains the unit for accumulated training/application; the day provides a player-facing calendar for appointments.

## Fixtures

`CareerState.fixtures` stores the schedule and `CareerManager.next_fixture()` returns the first incomplete fixture.

The manager/UI can therefore ask “what is next?” without maintaining a separate screen-only pointer.

`active_fixture_id` identifies the fixture currently being played/committed to.

## Lock-in is an explicit decision boundary

The application does not jump directly from journal/fixture selection into the match. The lock-in screen exists because roster/selection is meaningful only if committing to a six is a visible act.

This is an example of UI structure reflecting game semantics rather than adding an extra confirmation modal for its own sake.

## Matches consume persistent player/team data

When a match begins, the managed team/player Resources already carry:

- permanent ability;
- role/familiarity;
- fatigue/form/confidence state;
- tactical team principles/familiarity/cohesion;
- lineup/selection.

The match engine reads those facts; it should not create a second career version of the player.

After the match, longer-term state such as fatigue/confidence/statistics can be updated through the managers/models that own it.

## Weekly advancement is orchestration

A week can involve:

- recovery;
- scheduled training regimens;
- position/familiarity progress;
- staff/world/scouting changes;
- fixtures/competition state;
- aging/season boundaries;
- finances or club-life systems.

`CareerManager` coordinates those systems rather than implementing every calculation inline.

When extending weekly logic, prefer:

```text
CareerManager asks System X to update
```

rather than growing one enormous `advance_week()` with every mechanic encoded directly.

## Reports make long-running systems inspectable

Operations such as training return structured Dictionaries describing what happened.

This lets:

- UI explain the result;
- tests assert consequences;
- debugging inspect the week;

without making the UI recalculate the simulation.

## Calendar blockers are game decisions

`training_day_is_today()` prevents advancing past an unresolved manager session. This is more than UI navigation: the calendar itself recognizes that a meaningful obligation is pending.

That is how diegetic time should work:

```text
world state says appointment exists
→ UI gives player a way to resolve it
```

not:

```text
UI button happens to be disabled today
```

## Autoload managers and scene independence

Because `CareerManager` and `GameManager` live at `/root`, a screen can be destroyed/recreated without losing the career.

This is why UI navigation and save state can remain separate.

**Godot reminder:** scenes are not your whole program state. Autoloads and Resources can outlive individual screen Nodes.

## Determinism and world generation

Career creation derives seeded generation from career/region/type information, then creates starting roster/world/market/competition state.

Once generated, the world persists. The transfer market should be a view into real generated people rather than rerolling unrelated candidates every time a screen opens.

## The management fantasy

The broader product goal is that player/world facts should create meaningful long-term judgement:

> see what an athlete could become before everyone else does, develop the club/team around that judgement, then see the consequences in volleyball.

This only works if match behavior actually consumes the attributes/tactics the management layer develops.

Part VI ends by tracing that connection explicitly.

## Safe extension: a new weekly mechanic

For a new long-term system:

1. choose the durable owner (CareerState, player, team, staff, world sidecar);
2. implement calculation in an appropriate system class;
3. choose when CareerManager invokes it;
4. return/report useful consequences;
5. add save migration if new state persists;
6. expose manager action through UI without moving the calculation into the screen;
7. test advancement across save/reload.

## Source trail

- `scripts/managers/career_manager.gd`
- `scripts/models/career_state.gd`
- `scripts/managers/game_manager.gd`
- fixture/match-state models
- `scenes/application.gd`
- `scenes/screens/lock_in_screen.gd`

Next: how the world population becomes scouting information, a shortlist/offer, and eventually a managed-roster player.