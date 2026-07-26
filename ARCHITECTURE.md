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
  serve intent, normalized defender positions and player responsibility map.
- `scripts/models/defensive_assignment.gd`: one player's base, read, seam,
  short-ball, emergency, attack-coverage and second-contact responsibilities.
- `scripts/models/defensive_zone.gd`: a player's normalized zone center,
  metre-based responsibility radius, priority, activity and zone type.
- `scripts/simulation/coverage_calculator.gd`: pure court-distance, reaction,
  travel, reach and zone-claim calculations shared by reception and defense.
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
`TacticalCourt.set_lineup()` is also a hard reset boundary: changing rotation
clears its event, live positions, movement trails, tween targets and captions
before accepting the new lineup. `main.gd` applies the same reset to both court
surfaces after scoring and through the manual Reset Positions control.
For each rally event, the presenter derives normalized pre-contact and
post-contact movement phases. `main.gd` sequences those phases around the ball
flight, while `tactical_court.gd` owns interpolation, short trails, destination
markers and phase captions. Reception, setting, attacking, blocking and defense
therefore read differently without placing animation state in the simulator.
Support targets are derived for the full home unit around each event, so attack
coverage, setter support, block closing and floor-defense movement happen as a
coordinated presentation phase. Only normalized defensive-plan state—not these
temporary animated positions—is read by the simulator.

## Adaptation flow

Home attack and serve events carry compact tactical metadata. After the rally
is scored, `OpponentTeam.observe_rally()` counts exposed lanes, tempos and serve
targets and advances an adjustable adaptation strength. The next rally may use
that learned pattern as a bounded block bonus. Updating after resolution avoids
changing an outcome retroactively, and the adaptation state is serialized by
`GameManager`.

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

## Ball arrival and coverage

Serve and attack events receive an approximate flight time. Coverage converts
normalized court deltas into metres, subtracts an anticipation-derived reaction
delay, then derives travel from lateral speed, acceleration and fatigue. Basic
reach is added after travel. A contact is eligible only when the landing point
is inside both physical reach and the assigned tactical radius.

Among eligible players, zone priority, arrival margin, anticipation and contact
skill determine the claimant; other eligible players count as nearby support.
Equal-priority claimants with a narrow score margin create a seam conflict and
apply a reception penalty. Coaches can remove a player from reception, move the
zone center, change its radius or establish explicit priority without changing
the player's physical ratings.
The tactical radius therefore describes responsibility rather than granting
extra physical ability. Rally events retain landing, flight-time and arrival
metadata so explanations and future animation can show why a player did or did
not reach the ball.

## Block closing

Home blocking no longer selects the roster's highest-rated blocker globally.
The front-row player nearest the attack lane becomes primary. Other front-row
players are evaluated as possible assists using horizontal distance, reaction,
lateral speed, set tempo and set quality. Tactical commit choices alter the
available closing window rather than adding an unconditional quality bonus.

A sufficiently complete, high-quality contest may stuff the attack. More often,
partial contests produce a touch or funnel. A touch lowers effective attack
force, changes its landing point and increases flight time before
`CoverageCalculator` selects a floor defender; a funnel redirects the target
with a smaller control benefit. Opponent block touches can return to the home
court, where an explicitly assigned attack-cover player attempts to recycle the
ball before transition offense resumes. This keeps blocking, attack coverage
and floor defense connected instead of resolving them as binary checks.

## Body geometry and reception

`VolleyballPlayer` stores height, mass and wingspan and derives standing reach.
Position-based defaults migrate older saves without requiring an independent
standing-reach value. Mass applies a bounded power modifier and small movement
tradeoff. Wingspan affects base defensive reach; standing reach and wingspan
both contribute to block geometry.

Maximum `jump_reach` remains the player's ceiling. `explosiveness` determines
how much of that ceiling is available within the current contact window.
`reception` remains the compatibility/technique rating, while
`reception_balance` reduces edge-of-zone movement penalties and
`reception_stability` reduces high-pace penalties. The reusable penalty lives
in `CoverageCalculator` so serve reception and floor defense use the same
interpretation.

## Defensive movement and second contact

The presenter treats saved court positions as the base state. Reception,
blocking and floor-defense contacts animate through an attribute-derived read
position, the eventual contact position and a recovery step. Anticipation,
decision making and tactical discipline shape the first movement without
moving outcome authority out of the seeded simulator.

The normal setter owns contact two unless that player made first contact. In
that case, `RallySimulator` ranks the other five players using the saved primary
or secondary emergency-setter responsibility plus set accuracy, ball control
and decision making. The resulting set event identifies the first-contact
player and whether emergency ownership was activated.
