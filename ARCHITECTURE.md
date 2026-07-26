# Volley World Manager Architecture

## Current boundaries

- `scenes/application.tscn`: application router. It switches between title,
  new-career, career dashboard and the existing Match Center without moving
  simulation state into UI nodes.
- `scripts/managers/career_manager.gd`: owns the active career, save-slot I/O,
  calendar advancement, weekly training selection, fixtures, transfer pool and
  the boundary into/out of a match.
- `scripts/models`: persistent typed volleyball and tactical data.
- `scripts/tactics`: pure validation and tactical-demand calculations.
- `scripts/simulation`: seeded discrete rally resolution. It does not use scene
  nodes, timers or animation state.
- `scenes/components/tactical_court.gd`: presentation and input only. It draws
  normalized tactical data and never determines whether a contact succeeds.
- `scripts/managers/game_manager.gd`: coordinates the managed team, players,
  rotations, saved
  plays, active plays, match state, rally-resolution entry point and serialization.
- `scripts/models/team.gd`: owns roster registration, captain/libero roles,
  roster limits, identity, tactical familiarity and position depth charts. It
  does not own tactical positions.
- `scripts/models/career_state.gd`: career identity, organization type, region,
  time, resources, fixtures, transfer pool, training focus and match format.
- `scripts/models/match_format.gd`: best-of-set rules, regular/deciding targets
  and required winning margin. `MatchState` consumes it instead of hardcoding
  best-of-five rules.
- `scripts/systems/player_generator.gd`: deterministic region- and
  organization-aware roster/market generation.
- `scripts/systems/training_system.gd`: stateless definitions and weekly
  effects for volleyball training and recovery.
- `scripts/systems/attribute_profile_system.gd`: stateless detailed/summative
  player profiles, D-S grading and serve-style proficiency calculations.
- `scripts/systems/familiarity_system.gd`: stateless position suitability,
  cross-training, handed geometry, sparse situation exposure and read preparation.
- `scripts/models/match_statistics.gd`: derives persistent team and player
  contact totals from authoritative rally events.
- `scripts/data/rally_explanations.gd`: all current player-facing rally result
  templates and factor captions.
- `scripts/models/defensive_plan.gd`: per-rotation block intent, functional
  floor preset, serve intent, normalized defender positions, setter release
  targets and player responsibility map.
- `scripts/models/defensive_assignment.gd`: one player's base, read, seam,
  short-ball, emergency, attack-coverage and second-contact responsibilities.
- `scripts/models/defensive_zone.gd`: a player's normalized zone center,
  metre-based responsibility radius, priority, activity and zone type.
- `scripts/models/ball_trajectory.gd`: one authoritative contact-to-contact
  quadratic ball path, including normalized endpoints, flight timing and apex.
- `scripts/simulation/coverage_calculator.gd`: pure court-distance, reaction,
  travel, reach and zone-claim calculations shared by reception and defense.
- `scripts/simulation/rotation_legality.gd`: pure serve-contact overlap bounds
  derived from same-row neighbors and each front/back counterpart.
- `scripts/models/opponent_team.gd`: opponent roster, six rotation sheets,
  current on-court personnel, real player attributes, tendencies and scouting
  confidence.
- `scenes/main/main.gd`: presentation coordinator. It requests a completed
  result from the manager, then controls event playback speed and skipping.

## Data flow

```text
Title save selection / New Career form
→ CareerManager + CareerState
→ deterministic VolleyballPlayer generation
→ GameManager managed Team / rotations / tactics
→ Career Dashboard calendar, roster, training, recruitment and fixtures
→ CareerManager.prepare_fixture()
→ configured VolleyballMatchState + existing Match Center
→ completed result / statistics / reputation
→ Career Dashboard + versioned save slot
```

The career layer is deliberately above the match layer. `CareerManager` may
configure or serialize `GameManager`, but rally simulation never reads calendar,
transfer UI or save-slot state.

## Match data flow

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
→ VolleyballMatchState scoring/rotation/history/statistics
```

`VolleyballTeam` owns who is registered and their long-term roles.
`RotationLineup` owns who occupies each match position. Before rally resolution,
`GameManager.match_roster_errors()` checks team registration, lineup legality
and player availability; injured or suspended starters cannot enter a rally.

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
The Match Center preview receives a deep snapshot of the lineup, active play and
defensive plan when a point begins. It retains that completed-point context
while the player edits future tactics. Replay reuses the stored `RallyResult`
without invoking `GameManager.record_rally()` again.
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

Serve-reception editing separately visualizes rotational legality. Selecting a
player derives their current legal rectangle from the other five reception
positions: 4–3–2 and 5–6–1 retain left-to-right order, while 4/5, 3/6 and 2/1
retain front/back order. This overlay guides positioning but does not alter the
physical coverage calculation.

## Block closing

Home blocking no longer selects the roster's highest-rated blocker globally.
The front-row player nearest the attack lane becomes primary. Other front-row
players are evaluated as possible assists using horizontal distance, reaction,
lateral speed, set tempo and set quality. Tactical commit choices alter the
available closing window rather than adding an unconditional quality bonus.
Opponent transition derives a setter position from pass location and quality.
Before reading the hitter lane, each home blocker's starting X position is
pulled toward that setter by a bounded weight inversely proportional to tactical
discipline and anticipation. The subsequent read window is independently graded
from anticipation, court vision, decision-making and discipline plus the
clarity of the set cues. Physical closing still uses lateral speed, reach and
the remaining time, keeping mental recognition separate from execution.

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

Reception resolves a desired pass vector separately from the receiver's actual
output. Movement direction, time available to settle, zone-edge pressure and
incoming force establish body alignment and contact posture. Reception,
ball control, balance and stability establish platform feasibility; technique
then limits the redirection error cone. The resulting destination is stored on
the event and becomes the setter's real chase target rather than descriptive
text layered over a perfect pass.

## Contact trajectories

Every playable ball contact exposes an `outgoing_trajectory`. The simulator
owns its start, control point, destination, time window, velocity and apex; the
court presenter only samples that path. Attacks that meet a block terminate at
the net and the block begins a separate deflection trajectory, so the rendered
ball cannot pass through a contact before the corresponding event occurs.

During playback, the outgoing ball flight and the next player's movement run
concurrently. This creates continuous-looking rally movement while preserving
the seeded, discrete-event outcome model. A future 2.5D presenter can project
the same normalized trajectories without moving physics authority into scene
nodes or frame callbacks.

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

Setting ownership is derived from the rotation rather than the player's roster
label. A 5-1 always activates its sole designated setter. A 6-2 activates the
designated setter currently in the back row and leaves the front-row designated
setter attack-eligible. Emergency setters remain a separate broken-play path.
The active setter's saved release target shapes the preferred reception vector;
the simulator then grades the real set from its contact distance, direction,
body orientation and displacement from that release region.
Set options are never hard-locked by reception quality. Fast or awkward sets
remain attempts, but distance, release displacement and body orientation become
more punitive when the setter has weak setting balance, setting stability or
set accuracy.
During Serve Receive, the court renders that target as an independent draggable
handle connected to the active setter. Click-release opens contextual
instructions as a local `TacticalCourt` child rather than a popup-window child;
this prevents window layout from expanding the card into an invisible
screen-wide input layer. Exceeding the
drag threshold edits spatial state without creating a modal popup mid-drag.

Floor systems are presets, not outcome bonuses disguised as labels. Applying
Perimeter, Middle-Up or Rotation Defense writes positions, radii and claim
priorities into the editable plan. Later edits preserve those concrete values
and mark the preset modified. Depth, short-ball posture and the block-defense
relationship apply bounded tradeoffs during floor contact and funnel resolution.

## Spatial rally clock

`RallySimulator` initializes authoritative home-player positions from the saved
serve-receive shape on side-out and the saved defensive shape while serving.
Reception, setting, approach, blocking, floor defense and attack coverage update
those live positions rather than repeatedly reading static slot coordinates.

Movement time converts court distance to metres and applies acceleration,
lateral or transition speed, mass and fatigue. Contact windows create explicit
arrival margins: a late setter loses control or yields to an emergency setter;
a late hitter loses approach quality and may miss the attack entirely. Every
rally event is finalized onto a monotonic clock with `event_time`,
`event_duration`, and applicable movement/deadline metadata. Presentation reads
those values but does not determine the outcome.

Block events expose one spatial net segment per arriving blocker. Segment width
uses wingspan and close fraction; redness uses completeness. The renderer keeps
the uncovered net white and paints only the simulated coverage.

## Opponent spatial offense and rally analysis

`OpponentTeam` exposes schematic phase positions and an eligible-hitter pool.
Opponent transition selects an actual hitter, derives a lane-specific contact,
and grades the target-specific set before choosing a power swing, quick, roll
shot or emergency tip. Floor targets include line, seam, cross-court and short
space. Home attacks use the same spatial idea against the opponent shape.

Opponent floor defense compares player position, movement time, anticipation
and reception instead of always using the roster's strongest defender. Rally
events retain attacker direction, movement, arrival, set geometry and blocker
read metadata. `RallyResult.analysis` reduces that event stream into concise
post-rally diagnostics; it is presentation data derived from the authoritative
events, not a second outcome model.

`TacticalCourt` owns a separate, optional opponent presentation layer. Match
Center enables it from `OpponentTeam`; the tactics editor leaves it disabled.
This keeps opponent icons visible and animatable without adding opponent IDs to
the editable home `RotationLineup` or allowing opponent markers to receive home
drag/input behavior.
