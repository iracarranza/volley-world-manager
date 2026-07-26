# Volleyball Management Simulator — Confirmed Design Handoff

## Purpose

This document consolidates the major features and design directions confirmed for the volleyball management simulator. Treat these as the current project vision and architectural constraints unless later project files explicitly supersede them.

---

# 1. Core Game Vision

The game is a deep volleyball management and tactical simulation. The player acts primarily as a head coach and roster architect rather than directly controlling athletes.

The game should emphasize:

- contextual player value rather than one universal overall rating
- tactical identity and system fit
- specialized and flawed players becoming legitimate core players
- rotation-specific strategy
- readable, explainable rally outcomes
- coaching influence without removing player autonomy
- emergent match stories generated from simulation rather than scripted sequences

The intended value model is:

```text
Player profile
× Tactical system
× Rotation
× Teammate fit
× Opponent matchup
× Scouting
× Current rally state
```

A lower-rated player should frequently be the correct starter when they uniquely enable a tactic, stabilize a rotation, create a matchup problem, or complement the rest of the lineup.

---

# 2. Fictional Volleyball World

The game should not use real countries directly. It should use fictional volleyball cultures and regions inspired by the structural approach of games such as Polytopia, Pokémon, Splatoon, and Ace Attorney.

Each region should feel like a culture first and a volleyball reference second.

Confirmed naming direction:

- phonetically simple names
- visually distinctive spellings
- region-specific orthographic conventions
- indirect volleyball wordplay rather than obvious substitutions

Examples already favored:

- Landavol
- Spëddigh
- Pāwa Hitō
- Bloc du Larg

Regions should express different coaching philosophies rather than biological stereotypes.

Recommended world hierarchy:

```text
Region
↓
Academies
↓
Coaches
↓
Players
```

Academies and coaches should eventually matter more than region alone. Two academies from the same region may produce very different player types.

---

# 3. Player Design Philosophy

## 3.1 No universal best player

Avoid a design where players simply seek the highest CA, PA, or safest all-around profile.

The player pool should support:

- extreme specialists
- flawed stars
- role-limited tactical weapons
- players who are elite in only one phase
- players whose value depends strongly on lineup and rotation context

Examples:

- a towering opposite with poor mobility and limited shot variety
- an undersized setter with elite vision and tempo control
- a libero with exceptional reading but weak emergency setting
- a middle who contributes little offensively but transforms the block
- a serving specialist with limited six-rotation value
- a low-power attacker with elite placement and decision-making

## 3.2 Strengths should not be flattened into overall ratings

Player performance should emerge from separate physical, technical, mental, tactical, and behavioral attributes.

Useful dimensions include:

- standing reach
- jump reach
- acceleration
- lateral speed
- transition speed
- stamina
- arm speed
- power
- timing
- ball control
- set accuracy
- attack accuracy
- shot variety
- court vision
- anticipation
- decision-making
- composure
- consistency
- tactical discipline
- improvisation

## 3.3 Traits and tendencies

Traits should unlock behaviors or strongly alter decision weights rather than merely granting flat stat bonuses.

Examples:

- Uses Block
- Loves Deep Corner
- Challenges Triple Blocks
- Avoids Line
- Late Wrist Snap
- Elite Jump Server
- Back-Row Specialist
- Attacks Early in Transition
- Prefers High Hands
- Setter Dump Threat

Traits should affect what the player attempts, how often they attempt it, and under what conditions.

---

# 4. Tactical Identity

The player should be able to create a recognizable team philosophy.

Potential identities include:

- fast-tempo offense
- high-ball offense
- middle-centric offense
- pipe-heavy offense
- spread offense
- defensive transition team
- blocking-focused team
- serving-pressure team
- low-error control team

Tactical systems should multiply or suppress player strengths rather than applying simple additive bonuses.

The roster should gradually evolve around the system, but the system should also be adaptable to the roster.

---

# 5. Offensive System

## 5.1 Rotation-specific playbooks

The coach can create and assign offensive plays for specific rotations.

Playbooks may distinguish between:

- serve receive
- transition
- out-of-system offense
- end-game situations
- emergency offense

Each rotation may have:

- primary play
- secondary play
- fallback play
- emergency high-ball option

## 5.2 Play structure

A play should define intent rather than force an outcome.

A play may include:

- assigned hitter lanes
- attacker starting points
- approach paths
- set targets
- set tempo
- set distance from setter
- decoy responsibilities
- expected blockers manipulated
- primary and secondary options
- fallback rules based on pass quality

## 5.3 Net lanes

Hitters can be assigned to different horizontal lanes across the net.

Possible lane concepts include:

- left pin
- inside-left
- front quick
- setter-front gap
- right quick
- inside-right
- right pin
- pipe lane
- back-right lane

Lane assignments should create congestion, spacing, decoy, and blocking implications.

## 5.4 Set tempo and distance

Sets can vary by:

- tempo
- horizontal distance from setter
- vertical height
- release timing
- target contact window

Faster tempo and greater distance should increase technical and physical demands.

More complex attacks should also increase mental and tactical demand.

Examples:

- a fast, long-distance shoot set requires elite setter precision and attacker timing
- a slow high ball is technically safer but gives the block more time
- combination plays increase decision and synchronization demands

## 5.5 Coach calls versus setter autonomy

The coach can call a play before a rally, but the call is a request rather than a guarantee.

The setter evaluates:

- reception quality
- pass distance from net
- attacker availability
- blocker positioning
- current rotation
- trust and chemistry
- scouting information
- tactical risk

The setter may abandon the called play when it becomes impossible or suboptimal.

Elite setters should improvise more effectively.

---

# 6. Offensive Rally Calculation

Every attack should be resolved as a chain of constrained decisions.

## 6.1 Arrival and approach

Determine whether the attacker reaches the intended approach and contact window.

Influences include:

- transition speed
- anticipation
- acceleration
- approach timing
- congestion
- fatigue
- set tempo
- distance traveled

## 6.2 Potential versus actual contact height

Players should have a potential contact point, but actual contact height varies by rally.

Actual contact height may be reduced by:

- mistimed approach
- poor set placement
- late transition
- fatigue
- congestion
- emergency adjustments
- off-balance takeoff

## 6.3 Attack geometry

From the actual contact point, calculate the attacker's legal and viable attack cone.

Relevant variables include:

- contact height
- contact position relative to net
- attacker distance from net
- blocker distance from net
- block height
- block width
- block penetration
- net clearance
- available court width
- available court depth

The attacker's viable options should emerge from geometry rather than from a single attack rating.

## 6.4 Candidate targets

The simulation does not need infinitely sampled angles. It can evaluate a curated set of candidate outcomes.

Examples:

- sharp cross
- deep cross
- seam
- line
- deep line
- high hands
- outside-hand tool
- inside-hand tool
- deep middle
- short roll
- tip
- recycle

Invalid or impossible options are removed before decision scoring.

## 6.5 Attack decision

The attacker scores or weights available options using:

- geometry
- expected point value
- open court
- block position
- defender depth
- opponent tendencies
- scouting
- player vision
- player decision-making
- traits
- tendencies
- coach instructions
- game state
- controlled randomness

Players should not always choose the mathematically optimal action. Better decision-makers should choose strong options more consistently.

---

# 7. Blocking and Defense

## 7.1 Blocking geometry

Blocks should be represented as coverage envelopes rather than a single block rating.

Each blocker contributes:

- height
- width
- penetration
- lateral closing speed
- timing
- hand control

The combined block removes sections of the attacker's viable cone.

## 7.2 Defensive positioning

Defensive instructions should include both width and depth.

Each defender has:

- base horizontal responsibility
- base depth
- permitted adjustment freedom
- read responsibility
- tip responsibility
- seam responsibility

Depth should be scouted and presented to the player on the tactical board.

## 7.3 Defensive reaction

Defenders should not know the attack destination instantly.

The defensive sequence is:

```text
Base position
↓
Read attacker and set
↓
Estimate destination
↓
Move
↓
Commit
↓
Attempt contact
```

Reaction quality depends on:

- scouting
- anticipation
- vision
- tactical discipline
- reaction time
- movement speed
- block information
- attack speed

Reachability can be estimated using available reaction time, acceleration, running speed, and dive extension.

---

# 8. Rally Simulation Architecture

The rally should use a discrete event model rather than continuous full-physics simulation.

Suggested event chain:

```text
Serve resolution
↓
Reception resolution
↓
Setter decision
↓
Attack approach
↓
Attack decision
↓
Block and defense resolution
↓
Continuation or point end
```

The match simulation should be separate from visual presentation.

Recommended architecture:

```text
Tactical layer
↓
Rally simulation layer
↓
Presentation layer
```

The presentation layer should never determine the rally result.

Simulation may calculate one or two contacts ahead while animations play.

---

# 9. Tactical UI

## 9.1 Core design goal

The tactical UI should resemble a living coaching board rather than a spreadsheet-heavy menu.

The player should be able to understand:

- where every athlete begins
- where they intend to move
- which attack lane they occupy
- the tempo of each set
- the intended first and second options
- defensive width and depth
- block assignments
- which parts of the plan are risky or unavailable

## 9.2 Court board

Use an interactive top-down or angled court.

Display players as draggable markers.

Each marker may show:

- name or number
- position
- rotation slot
- current role
- readiness or fatigue
- specialty icon

The board should support separate offensive and defensive views.

## 9.3 Offensive play editor

The player can create a play by selecting a rotation and configuring:

- reception formation
- setter starting point
- hitter starting points
- hitter destination lanes
- approach paths
- set target
- tempo
- primary option
- secondary option
- decoy assignments
- fallback play

Recommended interactions:

- drag player markers to starting positions
- drag path handles to define movement
- select a hitter and click a net lane
- choose tempo from a compact scale
- draw or select the intended set path
- reorder primary and secondary targets
- preview the play as a short looping animation

## 9.4 Tempo presentation

Tempo should be shown visually, not only numerically.

Possible presentation:

- set-path line thickness or animation speed
- compact labels such as T0, T1, T2, T3
- timing bands on an approach timeline
- warning indicators when player timing is marginal

## 9.5 Risk and demand feedback

The tactical UI should explain why a play is difficult.

Display separate demand categories:

- technical demand
- physical demand
- tactical/mental demand
- synchronization demand

Example feedback:

```text
Long shoot to left pin
Technical demand: High
Physical demand: Moderate
Tactical demand: High
Primary risk: Setter accuracy under poor reception
```

The UI should show which players satisfy or fail key requirements without reducing the entire decision to one overall compatibility score.

## 9.6 Defensive board

The defensive editor should display:

- blocker starting positions
- blocking assignments
- line or cross priorities
- seam responsibility
- defender horizontal zones
- defender depth
- tip coverage
- permitted read freedom

Depth should be represented directly on court through draggable markers or depth bands.

## 9.7 Scouting overlays

Scouting information can be overlaid on the court.

Potential overlays:

- attack heat maps
- likely set distribution
- hitter target tendencies
- defender starting depth
- block closing tendencies
- serve target patterns
- rotation-specific weak zones

Scouting quality should determine precision. Poor scouting may show broad tendencies rather than exact percentages.

## 9.8 In-match tactical controls

Before a rally, the player may call:

- a saved offensive play
- a defensive scheme
- a serving target
- a blocking emphasis
- a risk level

The coach should not manually choose every athlete's exact action after the rally begins.

In-match UI should remain fast and compact. Recommended structure:

- current rotation indicator
- one-click saved play buttons
- current defensive scheme
- serve target selector
- short tactical notes
- timeout and substitution controls

## 9.9 Tactical explainability

After a rally, the player should be able to inspect why the outcome occurred.

Possible replay overlays:

- intended versus actual contact point
- set error
- attacker viable cone
- block coverage
- defender starting depth
- chosen target
- reaction delay
- outcome probability breakdown

This information should be optional so normal play remains uncluttered.

## 9.10 UI hierarchy

Recommended tactical screens:

```text
Tactics
├── Rotation Overview
├── Offensive Plays
├── Defensive Schemes
├── Serve Plan
├── Blocking Assignments
├── Scouting Overlay
└── Match Review
```

---

# 10. Match Presentation Without External Assets

The first visual prototype can be built entirely from Godot primitives.

Recommended style:

- circles or capsules for players
- small sphere or circle for the ball
- simple court lines
- shadows for floor position
- motion trails
- attack cones
- block envelopes
- defensive zones
- movement arrows

The style should resemble:

- an animated coaching board
- tabletop miniatures
- broadcast tactical graphics

Reusable procedural motion types may include:

- idle
- move
- approach
- jump
- land
- set
- attack
- block
- dig
- dive

Animations should be synchronized around contact timestamps.

Example:

```text
0.00 serve contact
0.62 reception
1.31 setter contact
1.68 attacker takeoff
2.02 attack contact
2.31 defensive contact
```

Use tweens, curves, transforms, squash/stretch, shadows, and impact effects. Avoid letting physics determine whether contacts succeed.

---

# 11. Performance Expectations

This simulation is feasible in real time.

The geometry and decision calculations are simple enough to resolve during existing animation windows.

Avoid:

- literal continuous ball aerodynamics
- excessive per-frame raycasts
- evaluating infinite attack angles
- recalculating full-team strategy every frame
- excessive temporary object creation
- always-on detailed debug logging

Use:

- event-based calculations
- candidate target evaluation
- mathematical block and reach envelopes
- pre-resolved trajectories
- lightweight replay records

Watched matches should have no perceptible calculation downtime.

---

# 12. Core Player-Value Safeguards

To prevent the game from becoming a CA/PA optimization exercise:

1. Do not expose one definitive overall rating as the primary evaluation tool.
2. Make role value depend on rotation and tactical context.
3. Let extreme attributes unlock unique plays and behaviors.
4. Make weaknesses meaningful but coverable through teammates and tactics.
5. Make opponent matchups change player value.
6. Make chemistry and trust affect timing, tempo, and decision freedom.
7. Ensure generalists are flexible but rarely dominant at every task.
8. Allow specialists to become stars when the team is designed around them.
9. Make scouting describe behavior and fit, not just talent level.
10. Evaluate players through projected role impact rather than a universal ranking.

Desired roster stories include:

- the giant opposite who forces triple blocks
- the setter who elevates average hitters
- the libero who changes the entire defensive structure
- the middle who closes one side of the net
- the jump server who wins rotations despite limited all-around value
- the low-power attacker who consistently finds uncovered floor

---

# 13. Implementation Guidance for Codex

Before changing code:

1. Inspect the existing Godot project structure.
2. Preserve functional systems rather than replacing them wholesale.
3. Separate tactical definitions, rally calculations, and presentation.
4. Prefer typed GDScript classes or Resources for persistent tactical data.
5. Prefer pure functions for geometry and scoring calculations where practical.
6. Keep simulation logic independent from scene nodes.
7. Add systems incrementally and maintain testable intermediate states.

Recommended initial implementation order:

1. Define court coordinates and rotation data.
2. Define player physical and tactical attributes.
3. Create typed offensive play definitions.
4. Create the tactical court editor prototype.
5. Implement serve → pass → set → attack as discrete events.
6. Add contact-point and block-envelope calculations.
7. Add candidate attack target scoring.
8. Add defensive depth and reachability.
9. Connect simulation output to primitive-shape animation.
10. Add scouting and rally explanation overlays.

Do not begin with realistic 3D character animation or full continuous physics.

---

# 14. Immediate Codex Task Suggestion

Inspect the current Godot codebase and write an implementation plan for the confirmed tactical and rally systems in this document. Do not implement the entire simulation in one pass.

The plan should:

- identify reusable current systems
- propose new typed Resources/classes
- define ownership boundaries between tactics, simulation, and presentation
- identify the smallest playable vertical slice
- list scene and script changes
- flag architecture risks
- preserve existing working functionality

The smallest vertical slice should allow:

1. selecting one rotation
2. assigning hitter lanes and set tempos
3. saving one offensive play
4. calling that play before a rally
5. resolving serve, reception, set, attack, block, and defense
6. displaying the rally with primitive shapes
7. reviewing a concise explanation of why the attack succeeded or failed
