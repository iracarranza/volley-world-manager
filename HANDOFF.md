# Current Implementation Handoff

## Playable now

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
- Track points, sets, service possession, side-out rotation and rally history.
- Rotate both teams through six rotation-specific lineups. Port Azure carries a
  seven-player roster so its libero can replace a back-row middle without
  removing the second middle from front-row rotations.
- Accumulate persistent team and player match statistics from rally events,
  with kills, blocks, aces and digs summarized in Match Center.
- Open Team & Roster from the header to inspect registered players, current
  court/bench status, captain and libero roles, availability, age, experience,
  potential, morale, fatigue and the initial positional depth chart.
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

## Implemented underneath

- Typed player, rotation, hitter-assignment, offensive-play, rally-event,
  rally-result and ball-trajectory Resources, plus typed per-player defensive
  assignments and coverage zones.
- Normalized court coordinates.
- Rotation and play validation.
- Playbook and active-play-per-rotation serialization.
- Pure seeded `RallySimulator`; presentation never determines outcomes.
- Centralized player-facing rally text in `scripts/data/rally_explanations.gd`.
- 141 passing headless foundation checks and UI-binding validation, including a
  seeded ceiling on terminal home stuff-block frequency.

## Intentionally not implemented yet

- Opponent substitutions, opponent timeouts and a second-libero ruleset.
- Unlimited continuation contacts; rallies intentionally use a four-exchange
  safety bound to prevent pathological simulation loops.

The next pass should deepen roster editing, calendar and training while opponent
substitutions and tactical counter-adjustments can remain match-engine follow-up.
Marker movement is intentionally schematic; future 2.5D
work can replace the presenter without changing rally outcomes.
