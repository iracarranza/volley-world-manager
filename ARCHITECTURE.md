# Volley World Manager Architecture

## Current boundaries

- `scripts/models`: persistent typed volleyball and tactical data.
- `scripts/tactics`: pure validation and tactical-demand calculations.
- `scripts/simulation`: seeded discrete rally resolution. It does not use scene
  nodes, timers or animation state.
- `scenes/components/tactical_court.gd`: presentation and input only. It draws
  normalized tactical data and never determines whether a contact succeeds.
- `scripts/managers/game_manager.gd`: owns the demo roster, rotations, saved
  plays, active plays, match state, rally-resolution entry point and serialization.
- `scripts/data/rally_explanations.gd`: all current player-facing rally result
  templates and factor captions.
- `scripts/models/defensive_plan.gd`: per-rotation block intent, floor system,
  serve intent and normalized defender positions.
- `scripts/models/opponent_team.gd`: opponent roster, real player attributes,
  tendencies and scouting confidence.
- `scenes/main/main.gd`: presentation coordinator. It requests a completed
  result from the manager, then controls event playback speed and skipping.

## Data flow

```text
Court/editor input
→ OffensivePlay draft
→ PlayValidator
→ GameManager playbook
→ active play
→ RallySimulator
→ RallyResult event timeline
→ TacticalCourt animation
→ post-rally explanation
→ VolleyballMatchState scoring/rotation/history
```

Court coordinates stored in models are normalized from `0.0` to `1.0`.
Conversion to pixels belongs exclusively to the court presentation component.
The court presenter letterboxes those coordinates inside a centered 9:18
rectangle; unused horizontal width belongs to coaching UI, not court geometry.
The same presenter can rotate that coordinate space into an 18:9 landscape
board without changing saved tactics or simulation data.

## Match and tactical surfaces

`main.tscn` now has two presentation surfaces backed by the same state:

- A read-only landscape match preview that receives rally playback.
- A dedicated popup tactical workspace containing the existing interactive
  court and coaching editor.

The workspace node is reparented into the popup at runtime. This avoids a second
copy of editor logic and makes the change straightforward to revert.
The simulator completes the result before the first animation begins, so visual
timing cannot change a point.
The court presenter maintains temporary live marker positions during playback.
Those positions are discarded before the next rally and never feed back into
simulation probability.
For each rally event, the presenter derives normalized pre-contact and
post-contact movement phases. `main.gd` sequences those phases around the ball
flight, while `tactical_court.gd` owns interpolation, short trails, destination
markers and phase captions. Reception, setting, attacking, blocking and defense
therefore read differently without placing animation state in the simulator.

## Theme ownership

- `scenes/themes/light_theme.tres`: Molten-inspired white, green and red.
- `scenes/themes/dark_theme.tres`: Mikasa-inspired blue, black and yellow.
- `main.gd` changes the active Control theme and procedural court palette
together.

## Match flow

`RallySimulator` resolves one rally without knowing the score. `GameManager`
then passes the completed result into `VolleyballMatchState`. Match state owns
points, sets, service possession, side-out rotation and rally history. Main may
automatically request another rally, but it cannot change a resolved result.
Each possession observes a three-contact event structure and may alternate up
to four exchanges before a deterministic safety resolution.

Defensive plans and opponent profiles are simulation inputs. The rally
simulator reads them but never edits them. Defender dragging remains a court
presentation concern and is converted back into normalized plan coordinates.
