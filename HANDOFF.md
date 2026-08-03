# Current Implementation Handoff

## Playable now

- Start at a dedicated two-column title screen with New Career, Load Career,
  Options and Exit. Load opens the save browser; Options persists the Midnight
  Court or Daylight Gym color theme.
- Create a career through a four-stage questionnaire: choose one of the eight
  fictional regions, establish a Club or Academy, select a preset or build a
  named custom identity from seven principle tags, then name the career and
  organization. The compact flat-color presentation follows the friendly,
  toy-like visual direction in `docs/world/STYLE_AND_SETTING.md`.
- Generate starting rosters deterministically from career name, region and
  organization type. Regions modify names and physical/technical/mental
  tendencies; clubs begin with ten senior players and stronger finances, while
  academies begin with twelve younger, higher-potential players.
- Navigate a career dashboard with reusable summary cards and dedicated Home,
  Roster, Team, Transfers/Recruitment and Competition screens.
- Inspect individual player identity, availability, age, experience, satisfaction,
  reputation, match confidence, fatigue, position-weighted ability, potential,
  measurements and every raw attribute from the Roster screen. View a seven-axis
  Player Profile derived from six symmetric seven-axis detailed wheels: Attacking,
  Defensive, Setting & Ball Control, Physical, Serving and Mental & Tactical.
  The compact roster wheel is always the labeled Player Profile; selecting it
  opens the full-screen Attribute Lab, where the six detailed wheels are chosen.
  Status/dynamics, key attributes, serving repertoire, traits and biography live
  in a separate full-screen Player Dossier so the main roster preserves readable
  identity and complete-attribute views in both roster-rail states. Every wheel
  vertex uses D-S presentation grades and contributor-name tooltips;
  usable power and baseline defensive range remain derived rather than duplicate stats.
- Generate a five-style serving repertoire for every player: Standing, Jump
  Topspin, Jump Float, Hybrid and Sky Ball. The primary style and its proficiency
  derive from power, technique, placement, consistency, aggression, variation
  and supporting physical/mental attributes, then influence rally pressure,
  error risk, placement, server selection, event text and flight time.
- Track handedness, rare functional weak-hand/ambidextrous traits, adaptability,
  natural positions, current position, familiarity with all five positions and
  sparse experience with meaningful rally situations. Players can be assigned
  individual cross-training, gain familiarity each week and be deployed once
  emergency-ready; unfamiliarity affects tactical execution rather than raw skills.
- Calculate position suitability from actual attributes and derived reach rather
  than height restrictions. Exceptional wingspan, jump capacity and explosiveness
  can therefore make an unconventional libero-to-middle/opposite conversion viable.
- Review team identity, tactical familiarity, cohesion, captain/libero hierarchy and the
  position depth chart. Team identities now persist seven configurable principles:
  decisiveness, pin focus, tempo variation, emotional expression, serve aggression,
  transition commitment and block commitment. Presets alter serve risk, attack
  distribution, selected tempo, swing choice and confidence volatility without
  modifying player ratings; identical seeded first matches produce different
  scorelines when only the identity changes. Regional alignment grants stronger
  starting familiarity and cohesion; departure from tradition is harder to
  integrate but lowers opponent scouting confidence and in-match adaptation.
  Directional identity checks run across six independent career-name seeds,
  rather than treating one deterministic save as a population. Select one of seven weekly training focuses with visible
  attribute, fatigue, satisfaction, cohesion and familiarity effects.
- Advance a 48-week calendar using four-week months and four seasons. Training
  applies before fixtures; a due unplayed fixture blocks further advancement.
- Browse a deterministic regional transfer pool, inspect candidates and costs,
  currently expanded to 120 generated players for attribute-variance testing.
  Prototype roster mutation is intentionally free: add or return players, assign
  trained positions, and move them between a six-player court unit, libero slot
  and bench; complete starter changes rebuild all six rotation sheets.
- Delete a selected career save from the title screen through a confirmation dialog.
- Review scheduled fixtures and results. The opening fixture is in week two so
  the player makes at least one training decision before entering Match Center.
- Play career matches under a data-driven best-of-three format with every set
  to 25 and a two-point margin, then return results and reputation changes to
  the career dashboard.
- Save careers as versioned JSON containing lightweight load-screen metadata,
  career state and the complete underlying team/match/tactics serialization.

- Select any of six rotations.
- Inspect all six player markers and rotation slots on a primitive court.
- Select eligible hitters directly on the court.
- Read player markers by volleyball position (`S`, `OH1`, `OH2`, `M1`, `M2`,
  `OP`, `L`) rather than name initials.
- Drag a hitter marker to a legal lane and finalize tempo/responsibility in a
  contextual popup beside the court marker. The side editor remains available.
- Assign front-row lanes or the back-row Pipe lane.
- Select set tempo T0–T3.
- Mark assignments as primary, secondary, option or decoy.
- Preview approach paths, tempo labels and separate tactical demand categories.
- Name and save an offensive play.
- Filter saved plays by rotation and set a persistent active play. The first saved
  play for each rotation becomes its default; players only intervene to change it.
- Resolve rallies without a saved play by using a safe T3 set to the front-row
  outside hitter at the nearest pin.
- Run a seeded rally resolved as serve, reception, setter decision, set, attack,
  block, defense and point events. Terminal failures naturally shorten the chain.
- Watch the result on the tactical court using primitive ball paths, actor
  highlights and a block envelope, with 0.5×/1×/2× playback and skip.
- Treat the tactical court as the editable top-down planning view. The future
  match presentation is intended to become a separate FM-style stationary-camera
  3D playback scene driven by the same rally events.
- Watch home markers move toward reception, setting, approach, blocking and
  defensive contact positions while events play.
- Watch the ball follow continuous contact-to-contact trajectories while the
  next player moves into position, including separate attack-to-block and
  block-deflection paths at the net.
- Complete event-specific movement phases before drawing the associated ball
  flight: read/receive, setter transition/set position, transition/approach,
  read/block close and read/defensive move or dive.
- Show short movement trails, the current destination and a concise phase
  caption, then animate landing/recovery after the contact when relevant.
- Read a post-rally result with the decisive outcome, tactical explanation,
  key factors and reception/set/attack quality percentages.
- Inspect contact-level playback details including receiver, reception quality,
  attack type, contact quality, block lane and block close quality.
- Continue through repeated three-contact possessions, emergency T3 outside
  balls and transition attacks until a point or four-exchange safety limit.
- Track points, sets, service possession, side-out rotation, signed match flow,
  player confidence and rally history. Composure, leadership and cohesion shape
  confidence response without turning flow into a direct hidden ability bonus.
- Rotate both teams through six rotation-specific lineups. Port Azure carries a
  seven-player roster so its libero can replace a back-row middle without
  removing the second middle from front-row rotations.
- Accumulate persistent team and player match statistics from rally events,
  with kills, blocks, aces and digs summarized in Match Center.
- Open Team & Roster from the header to inspect registered players, current
  court/bench status, captain and libero roles, availability, age, experience,
  potential, satisfaction, reputation, confidence, fatigue and the initial positional depth chart.
- Change captain and libero designations through roster-safe manager actions.
  Registration APIs reject duplicate or over-limit additions and prevent a
  player still used by a rotation sheet from being removed.
- Prevent rally resolution when the selected rotation contains an unregistered,
  missing, injured or suspended player.
- Enable automatic rallies, optionally pausing after aces, blocks and set ends.
- Scale themes and controls up with windows larger than the 1280×720 baseline.
- Use a taller court without the redundant name/position lineup key.
- Draw the complete court at its regulation 9 m × 18 m top-down ratio, with the
  wider coaching panel using the recovered horizontal space.
- Keep rally playback, speed, automatic flow and timeout controls in a fixed
  gameplay bar rather than burying them in the detailed scrolling panel.
- Use a compact landscape tactical preview on the Match Center. Clicking the
  preview opens the existing editor in a large FM-style popup workspace.
- Dim the Match Center behind the tactical workspace with an opaque modal
  underlay.
- Keep hitter assignment nested inside the tactical workspace so assigning or
  dismissing it does not close the full board.
- Animate the same rally events on the match preview and full tactical board.
- Freeze the Match Center court to the lineup, active play and defensive
  formation actually used when the point began. Later tactical edits do not
  rewrite the completed point's view.
- Replay the previous point from its stored `RallyResult` without recording the
  score, fatigue, adaptation or match history a second time.
- Clear transient marker positions, trails and the previous ball event whenever
  a rally ends or a lineup/rotation is loaded. A fixed Reset Positions button
  restores both court surfaces without changing saved tactics.
- Apply changes and return to the Match Center without duplicating tactical or
  simulation state.
- Switch the coaching board between offense and per-rotation defense.
- Open Serve Receive, Blocking or Floor Defense as separate defensive-plan
  submenus. Unrelated controls remain hidden so the editor does not require the
  player to scroll through every defensive phase.
- Open player-specific defensive controls from the selected court marker while
  retaining team presets and phase selection in the side panel. Back-row
  players expose no blocking instructions; front-row floor participation is an
  editable coverage toggle.
- Distinguish a marker click from a drag before opening instructions. The small
  phase-specific panel attaches diagonally beside the selected marker without
  becoming a modal layer or interrupting subsequent player movement.
- Size that icon-adjacent panel directly from its visible controls, using only
  compact margins and no reserved whitespace for controls from other phases.
- Parent the instruction card to `TacticalCourt` at runtime so it cannot expand
  to the tactical window. Close it explicitly, by clicking empty court space,
  or automatically by starting a player drag.
- Apply Perimeter, Middle-Up and Rotation Defense as functional position/zone
  presets, then customize the resulting plan as a modified preset.
- Edit Attack Coverage and Transition separately from Floor Defense, including
  block-rebound priority and emergency setting.
- In Serve Receive, drag an independent `S→` release destination rather than
  the setter marker.
  A solid setter-to-target line and midpoint arrow keep the direction visible
  while the setter and preferred setting destination remain separate state.
- Choose a 5-1 or 6-2 setting system. A 6-2 derives its active setter from the
  designated back-row player and keeps the front-row setter attack-eligible.
- Grade passes against the intended release region and grade sets using actual
  distance, direction, body orientation, tempo and displacement from the ideal
  release point.
- Keep quick attacks available after poor receptions rather than hard-locking
  them. Setting balance and stability mitigate moving, poorly oriented, long or
  tight attempts; technique determines how successfully the setter executes.
- Switch between floor-defense and serve-reception views, drag each player's
  independent zone center, and save block strategy, floor system, serve target
  and serve risk.
- Select any defender and explicitly assign base structure, seam, short-ball,
  emergency and attack-coverage responsibilities. Players read the developing
  play automatically through anticipation, decision making and tactical
  discipline rather than a coach-selected visual cue.
- Assign primary or secondary emergency setters. When the regular setter makes
  first contact, the best available assigned player owns contact two; the rally
  event and playback explanation identify the emergency setter.
- Animate home defense through base position, attribute-informed read,
  contact and recovery states before the ball advances to the next event.
- Resolve rallies on a shared spatial clock. Saved starting positions now affect
  setter travel, emergency second-contact ownership, hitter approach arrival,
  block closing, floor defense, attack coverage and transition offense.
- Scale marker playback duration from calculated movement time. Rally captions
  expose simulation timestamps and explain early or late setter/hitter arrival.
- Draw the net white by default, then paint only occupied block sections from
  pale red to dark red according to each blocker's coverage completeness.
- See each player's compact structural responsibility directly on the defensive
  court.
- Use separate saved serve-reception and floor-defense zones with an editable
  center, radius, priority and enabled state for every player. Both views show
  translucent metre-scaled overlays; reception summarizes active and hidden
  passers as an explicit formation.
- Select a serve-receive marker to see its legal position at serve contact.
  Dotted lines connect the relevant same-row neighbors and front/back
  counterpart; the derived legal region changes with the other five positions
  and turns into an overlap warning when the selected player is illegal.
- Resolve serve placement before choosing a receiver. Outside hitters, liberos
  and any other enabled passer claim balls using zone priority only if their
  reaction, speed, acceleration, fatigue and reach allow them to arrive.
  Equal-priority overlaps can create a penalized seam conflict.
- Resolve reception as an actual redirected vector. Body alignment, movement
  posture, settling time, edge pressure, pace, balance, stability, reception
  technique and ball control determine platform feasibility and pass error;
  the setter must chase the generated destination.
- Resolve home floor contacts with the same physical arrival model, including
  approximate attack flight time and nearby coverage support.
- Form home blocks through a nearest-player primary and travel-limited assist.
  Pin players lead pin blocks; middles only assist when anticipation, lateral
  speed and set timing allow them to close.
- Distinguish terminal stuff blocks from touches, funnels and misses. Touches
  alter the ball target, reduce attack force and add floor-defense reaction time
  instead of awarding an immediate point. Opponent block touches invoke saved
  attack-coverage responsibility and can be controlled into a new home attack.
- Model height, mass and wingspan for every generated demo player, with standing
  reach derived from height and wingspan. Mass raises attainable serve/attack
  power slightly while applying a small movement-speed tradeoff; wingspan
  affects defensive and blocking reach.
- Use explosiveness to determine how much maximum jump reach is available in a
  contact window. Reception balance protects moving contacts near a zone edge,
  while reception stability protects against high ball speed.
- Show a temporary physical-debug profile whenever a home player marker is
  selected, including body measurements, derived standing reach, movement,
  jump, stamina, balance and stability.
- Scout and play against a seven-player, rotation-ready Port Azure VC profile with individual
  serving, setting, attacking, blocking and defensive attributes.
- Use actual opponent names and attributes during rally resolution.
- Keep all six opponent position markers visible on the Match Center court.
  The active opponent marker follows its simulated contact during playback;
  opponent markers are read-only and never enter the home tactics editor state.
- Select opponent attackers from eligible pin and middle options instead of
  routing every transition to the highest-rated hitter. Attack selection now
  considers aptitude, set quality, approach demand and targetable floor space.
- Resolve line, seam, cross-court, roll-shot and emergency-tip targets against
  spatial defenders. Opponent defenders are selected by travel and arrival,
  not by a global best-defender lookup.
- Place the opponent setter along the net from pass location and set quality.
  That position pulls less disciplined or anticipatory home blockers slightly
  before they close to the actual hitter lane.
- Grade opponent sets from distance, angle, body orientation and setter balance
  and stability. Home blockers read those cues through anticipation, vision,
  decisions and discipline before their physical closing calculation.
- Review an after-rally analysis showing attack mix, target directions, longest
  movement, tightest arrival margin and average blocker-read quality.
- Let the opponent learn repeated home attack lanes, set tempos and serve
  targets. Learned patterns improve its block formation gradually, persist in
  saves and are summarized in the scouting panel.
- Adjust the opponent adaptation rate from the defensive panel for balancing.
- Take timeouts, confirm rotation-wide substitutions, undo the latest change,
  monitor average fatigue and short-term form, and view recent rally outcomes.
- Use rotation sheets that automatically replace the back-row middle with the
  libero while preventing front-row libero placement and attack assignment.
- Toggle between Molten Light and Mikasa Dark themes.
- Add 0.1× rally playback as the slowest available speed option.

## Implemented underneath

- Typed player, rotation, hitter-assignment, offensive-play, rally-event,
  rally-result and ball-trajectory Resources, plus typed per-player defensive
  assignments and coverage zones.
- Normalized court coordinates.
- Rotation and play validation.
- Playbook and active-play-per-rotation serialization.
- Pure seeded `RallySimulator`; presentation never determines outcomes.
- Centralized player-facing rally text in `scripts/data/rally_explanations.gd`.
- 185 passing headless foundation checks and UI-binding validation, including a
  seeded ceiling on terminal home stuff-block frequency.

## Intentionally not implemented yet

- Contracts, transfer negotiation and competing offers; current recruitment is
  an explicit fixed-cost vertical slice.
- Full leagues and standings; the career currently supplies a three-fixture
  regional series.
- Injuries generated by training, coaching staff and multi-session weekly
  scheduling. Availability is enforced, but those causes remain future layers.
- Opponent substitutions, opponent timeouts and a second-libero ruleset.
- Unlimited continuation contacts; rallies intentionally use a four-exchange
  safety bound to prevent pathological simulation loops.

The next pass should deepen calendar competition, multi-session training and
player development feedback while opponent substitutions and tactical
counter-adjustments can remain match-engine follow-up. The separate 3D replay
is available from Match Center through View 3D. It reuses the completed rally
event stream and player snapshots; it does not replace the tactical board or
participate in simulation.

## Running the tests on a fresh checkout

The headless test runner needs Godot's global class cache to know about every
`class_name` in the project. That cache lives in `.godot/` and is **not** in
version control, so a fresh clone -- or a `git checkout` that crosses a commit
which added a new `class_name` -- fails with parse errors that look like broken
code:

```
SCRIPT ERROR: Parse Error: Identifier "TeamPrinciples" not declared in the current scope.
```

The class is declared correctly; the cache simply has not seen it. Run an import
pass once, then the suite:

```
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
```

Only the import is needed, and only after the set of `class_name` declarations
changes. It is quick and safe to run whenever the runner reports a parse error
naming a class you can see on disk.

## Working with two agents on this repo

Two agents work on this project: one with direct access to the developer's
machine, one in a remote container. Neither can see the other's working tree.
Every coordination failure so far has come from the same root cause -- acting on
a *report* of work rather than on the work itself -- so the protocol is short
and all of it is about shared ground truth.

**Push before handing off.** Staged, stashed or merely-committed-locally work is
invisible to the other agent, and to the developer's ability to compare. Three
separate hand-offs stalled on this. If it is worth reporting, push it first;
a branch costs nothing and is reversible.

**Findings go in `docs/calibration/`, not only in chat.** A number in a chat
message cannot be verified, reproduced, or found again next week. A dated report
in this directory travels with the code. Follow the existing convention: state
the **tool**, the **commit measured at**, the **sample size**, and the method.
`TEAM_IDENTITY_BASELINE_2026_08_02.md` and
`ATTACK_ERROR_DIAGNOSTIC_2026_08_03.md` are the pattern.

**Diagnostics belong in `tools/`, not in throwaway scripts.** If the other agent
cannot re-run the measurement, they have to take the number on trust -- and
several taken on trust this week were wrong. A committed tool turns "I measured
0.34" into something either agent can check in one command.

**Verify claims about code against the code.** Both agents have confidently
reported things about the other's work that were untrue: that a feature had been
dropped when it had only been renamed; that two branches contained duplicate
patches when `git cherry` showed neither did. Reading the file is cheap. The
retraction is not.

**State what you have not verified.** A design written against a tree you cannot
see is still useful, but it must say so at the top, or its constants get treated
as current and copied forward.
