# Event Calculation Taxonomy: Decision vs. Attribute vs. Observable

**Status:** Refined architecture separating strategic decisions, physical execution, and observable measurement.
**Date:** 2026-07-30

---

## Core Principle

Not all event properties should be treated the same way:

1. **Attribute-Driven:** Physical capabilities (speed, reach, power) — player attributes determine what's *possible*
2. **Decision Quality:** Strategic choices (target, timing, strategy) — deserve their own quality score based on *soundness of choice*
3. **Observable/Measured:** Physical outcomes (velocity, angle, position) — must be tracked and visible for playback/diagnosis

**Example:** An attack.
- **Attribute-driven:** Approach quality, arm speed, explosiveness → determines jump height and available force
- **Decision quality:** Target selection → is the chosen lane open, is the angle exploitable?
- **Observable:** Ball exit velocity, attack angle, landing position → must be visible in 2D playback

---

## Attack (Hitter)

### Current Problem
`attack_quality` conflates approach setup, target selection, and execution. All bundled into a single 0–1 score.

### Proposed Breakdown

#### 1. **Approach Quality** (ATTRIBUTE-DRIVEN) ✓ Already Done (Gate 43)
- Comes from `ApproachMechanicsSystem.evaluate_takeoff()`
- Output: `runup_quality` (0–1), `jump_multiplier`, `lateral_control`, `available_attack_families`
- Feeds into: jump height, available action types
- **This is correct.** Keep as-is.

#### 2. **Target Selection Quality** (DECISION QUALITY) ← **NEW**
- Input: Current block geometry, hitter's perceived blocker positions, set quality, available_attack_families
- Decision: Which attack family? Within family, which lane (line, angle, seam)?
- Quality score: Is the chosen target actually open? How exploitable is it?
- Formula:
  ```
  target_selection_quality =
      block_coverage_gap_factor          # how much space is there?
      + blocker_positioning_exploitability  # can approach angle beat block?
      - block_skill_vs_hitter_skill      # are these blockers better readers?
      + set_quality * 0.15               # good sets give better targeting options
  ```
- Output: `target_selection_quality` (0–1), chosen `attack_lane`, chosen `attack_family`
- Feeds into: Whether the attack succeeds (even if execution is perfect, bad target = low success chance)

#### 3. **Execution Quality** (ATTRIBUTE-DRIVEN) ← **REVISED**
- Input: Chosen family/lane, approach quality, hand control, arm speed, explosiveness
- Separate quality for EACH action type:
  - `power_attack_execution_quality` — must use full arm speed and approach
  - `placed_attack_execution_quality` — requires hand_control and set_quality
  - `tip_execution_quality` — requires finesse and lateral_control from approach
  - `tool_block_execution_quality` — requires tooling attribute and precise reach angle
- Formula (example for power):
  ```
  power_execution_quality =
      approach_quality * 0.28
      + explosiveness / 100.0 * 0.20
      + arm_speed / 100.0 * 0.18
      + attack_power / 100.0 * 0.22
      + set_quality * 0.12
  ```
- Output: Per-action quality score
- Feeds into: Ball exit velocity, landing accuracy

#### 4. **Ball Exit Velocity** (MEASURED OBSERVABLE) ← **NEW**
- Calculated from execution_quality + attack_power
- Formula:
  ```
  ball_exit_velocity_mps = lerp(12.0, 25.0, execution_quality)
      * lerp(0.85, 1.15, (attack_power - 50.0) / 50.0)
  ```
- Output: m/s (not a quality; an actual measurement)
- Feeds into: Block difficulty, trajectory calculations, 2D playback
- **Critical for 2D playback:** Show velocity vector on contact

#### 5. **Attack Angle** (MEASURED OBSERVABLE) ← **NEW**
- Derived from: Hitter position, approach direction, chosen lane, set trajectory
- Formula:
  ```
  attack_angle = atan2(
      attack_target.x - hitter_position.x,
      attack_target.y - hitter_position.y
  )
      + approach_lateral_control * 0.1 (fine adjustment from body alignment)
  ```
- Output: Radians (not a quality; an actual angle)
- Feeds into: Block read difficulty, 2D playback trajectory display
- **Critical for 2D playback:** Show attack vector on contact

#### 6. **Attack Success** (OUTCOME) ← **Revised to use above**
- Formula:
  ```
  attack_success = target_selection_quality * 0.35
      + execution_quality * 0.25
      + (1.0 - block_contact_quality) * 0.40
  ```
- **Why this works:** A bad target fails even with perfect execution. Poor execution fails even with open court. Good block can save bad attack.

### What Changes
- Remove monolithic `attack_quality`
- Add `target_selection_quality`, `execution_quality` (per-action)
- Add `ball_exit_velocity_mps`, `attack_angle` as observables
- Success depends on all three factors

---

## Set (Setter)

### Current Problem
`set_quality` is a single score. Doesn't capture that different sets require different execution, and decision (what type/tempo to deliver) is separate from execution (how well delivered).

### Proposed Breakdown

#### 1. **Reception Quality** (ATTRIBUTE-DRIVEN) ✓ Already Done
- Output: `reception_quality` (0–1)
- **Problem:** Setter doesn't see this. Should feed into available options.

#### 2. **Set Type Decision** (DECISION QUALITY) ← **NEW**
- Input: Reception quality, tempo_demand from play, blockers' positioning, hitter's approach options
- Decision: Deliver fast tempo (2.0–2.2m high), medium (2.2–2.4m), or slow (2.6–3.0m)?
- Quality score: Is the chosen tempo optimal for the situation?
- Formula:
  ```
  tempo_decision_quality =
      clampf(
          (1.0 - reception_quality) * 0.40  # poor passes demand slower tempo
          + block_coverage_factor * 0.30    # tight block needs fast tempo to beat reads
          + hitter_readiness_factor * 0.30, # ready hitters can use fast tempo
          0.0, 1.0
      )
  ```
- Output: `tempo_decision_quality` (0–1), chosen `set_height_meters` (2.0–3.0)
- **Also decide:** Set lane (predetermined by assignment), set direction (front, back, pipe)

#### 3. **Set Delivery Execution** (ATTRIBUTE-DRIVEN) ← **REVISED**
- Input: Chosen height, chosen direction, setter attributes, reception quality
- Separate quality scores:
  - `front_set_execution_quality` — requires set_accuracy, set_balance
  - `back_set_execution_quality` — requires set_accuracy, set_balance, spatial awareness
  - `pipe_set_execution_quality` — requires tempo_control, hand_control
- Formula (example front):
  ```
  front_execution_quality =
      set_accuracy / 100.0 * 0.38
      + set_balance / 100.0 * 0.25
      + set_stability / 100.0 * 0.20
      + hand_control / 100.0 * 0.17
      + (1.0 - reception_quality) * -0.10  # harder pass = harder to place
  ```
- Output: Per-direction quality score
- Feeds into: Set trajectory accuracy, perceived ball destination

#### 4. **Set Trajectory** (MEASURED OBSERVABLE) ← **LANDED 2026-08-03**
> Implemented as `_delivered_point()` in `rally_simulator.gd`, at the spread
> stated below, for the first-ball set, the transition set and the opponent's
> reception. The landing position is real; the *flight* is still the existing
> `solve_launch_arc` shape rather than a simulated one, which is deliberate —
> own-side contacts have no boundary to test against. `intended_target` is now
> carried on SET events so aim and result read separately. Scatter is normal
> rather than uniform. See `docs/BACKLOG.md` §8.
- Calculated from delivery_execution_quality and chosen height
- Base arc shape (parabola) determined by `set_height_meters` and distance
- Variance around nominal landing:
  ```
  set_accuracy_stdev_meters = lerp(0.40, 0.08, execution_quality)
  actual_landing = intended_landing + randomness(stdev)
  ```
- Output: Ball trajectory (position over time), landing position
- Feeds into: Hitter perception, 2D playback trajectory display
- **Critical for 2D playback:** Show parabolic arc and landing zone

#### 5. **Set Release Timing** (MEASURED OBSERVABLE, decision-influenced) ← **NEW**
- Setter decision: Reveal intent early (easier for blocker to read) or late (hard to read, rushed)?
- Formula:
  ```
  release_delay_ms = choose_delay(tempo_decision_quality, blockers_skill)
      # Early release (0 ms) if defense is weak and tempo_decision is confident
      # Late release (200+ ms) if defense is strong
  ```
- Output: Release timing (milliseconds before peak extension)
- Feeds into: Blocker read difficulty (late release = harder to read, but more rushed for hitter)
- **Critical for Gate 44:** Blockers perceive release timing and use it to refine reads

#### 6. **Set Success** (OUTCOME)
- Formula:
  ```
  set_success = tempo_decision_quality * 0.25
      + execution_quality * 0.35
      + (1.0 - blocker_read_quality) * 0.40  # good sets get blocked less often
  ```

### What Changes
- Remove monolithic `set_quality`
- Add `tempo_decision_quality`, `execution_quality` (per-direction)
- Add `set_height_meters`, `set_trajectory`, `release_timing_ms` as observables
- Setter perception now includes reception_quality to inform decisions

---

## Block (Blocker)

### Current Problem
`block_contact_skill` and `block_read_quality` exist, but **blocking strategy is not modeled**. Blocker has no decision between hold/read vs. commit vs. assist. Hand positioning is not observable.

### Proposed Breakdown

#### 1. **Read Quality** (ATTRIBUTE-DRIVEN) ✓ Already Done
- Input: Anticipation, court_vision, decision_making, tactical_discipline, +cue_clarity
- Output: `read_quality` (0–1), blocker has formed hypothesis about attack
- **Problem:** No observation system yet (Gate 44)

#### 2. **Blocking Strategy Decision** (DECISION QUALITY) ← **NEW**
- Gate 44 blocker observation produces perceived attack direction, trajectory estimate, hitter approach cues
- Decision: Commit (close on hitter's probable angle), hold/read (stay back, react to deflection), assist (help primary), soft block (let ball through to back row)?
- Quality score: Is the strategy sound given the perceived information?
- Formula:
  ```
  strategy_decision_quality =
      if perceived_blocker_skill > perceived_hitter_skill:
          # Strong blocker: commit more aggressively
          strategy_quality = hold_vs_commit_fit(perceived_attack_angle)
      else:
          # Weak blocker: read more, commit less
          strategy_quality = help_vs_commit_fit()
  ```
- Output: `strategy_decision_quality` (0–1), chosen `block_strategy` (COMMIT_LEFT, COMMIT_RIGHT, HOLD, ASSIST, SOFT)
- **Also decide:** Which blockers (primary, assist) and where to position hands
- Feeds into: Blocker hand positioning, effectiveness of block

#### 3. **Hand Positioning** (MEASURED OBSERVABLE) ← **NEW**
- Strategy decision determines target location; physical attributes determine execution
- Formula:
  ```
  hand_position_x = strategy_target_x
      + lateral_control_from_close_speed * 0.05  # can fine-tune position during close
      + block_timing_accuracy * 0.03  # timing affects final reach
  ```
- Output: Hand center X position (in court coordinates)
- Feeds into: Block reach envelope, tool block deflection angle
- **Critical for 2D playback:** Show hand positions and reach zone at contact

#### 4. **Block Hand Angle** (MEASURED OBSERVABLE) ← **NEW**
- Blocker hand orientation relative to net
- Formula:
  ```
  hand_angle_degrees = 0.0  # perpendicular to net
      + clampf(perceived_attack_angle, -30, 30) * 0.4  # anticipate deflection
      + tooling_read_factor * 0.2  # if expecting tooling, angle hands inward
  ```
- Output: Radians (not a quality; an actual hand angle)
- Feeds into: Block deflection angle (if contact happens), tool block success
- **Critical for 2D playback:** Show hand orientation relative to net

#### 5. **Block Contact Feasibility** (MEASURED OBSERVABLE) ← **Existing, keep**
- Current: `close_fraction`, `contact_reach`, vertical margin
- This is good; it's the physical measurement of "can this blocker actually reach?"

#### 6. **Block Result Quality** (OUTCOME) ← **Revised**
- Formula:
  ```
  block_result_quality = strategy_decision_quality * 0.30
      + (block_contact_skill weighted by hand positioning) * 0.35
      + (1.0 - attack_execution_quality) * 0.35  # worse attack is easier to block
  ```
- If `close_fraction < 0.4`: No contact possible; result_quality capped at perceived_reach_limit
- If contact possible: result_quality determines block success vs. deflection vs. tooling

### What Changes
- Add `strategy_decision_quality`, chosen `block_strategy`
- Add `hand_position_x`, `hand_angle_degrees` as observables
- Gate 44 will produce blocker observation → strategy decision
- Block success now depends on sound strategy, not just raw skill

---

## Floor Defense (Dig)

### Current Problem
`defense_quality` is monolithic. Doesn't separate read/anticipation from positioning strategy from execution.

### Proposed Breakdown

#### 1. **Read Quality** (ATTRIBUTE-DRIVEN)
- Input: Anticipation, attack_type cues, block geometry
- Output: Does defender recognize attack is coming, what direction?
- **Existing:** Partially done in `_blocker_read_quality` pattern

#### 2. **Positioning Strategy Decision** (DECISION QUALITY) ← **NEW**
- Input: Perceived attack angle, known hitter tendencies, defensive plan
- Decision: Stay in assigned zone, cheat toward strong hitter, shift deep for tips?
- Quality score: Is the position choice sound?
- Formula:
  ```
  positioning_decision_quality =
      (plan_fit) * 0.40
      + (attack_read_quality) * 0.35
      + (hitter_tendency_match) * 0.25
  ```
- Output: `positioning_decision_quality` (0–1), `chosen_position` (court coordinates)
- Feeds into: Actual defensive position at contact moment

#### 3. **Movement Execution** (ATTRIBUTE-DRIVEN)
- Input: Chosen position, current position, available time, lateral_speed, anticipation
- Formula (existing):
  ```
  movement_quality = distance_fit + time_fit + speed_fit
  ```
- Output: Whether defender arrives in time, movement_quality (0–1)

#### 4. **Contact Execution** (ATTRIBUTE-DRIVEN) ← **REVISED**
- Input: Attack incoming, defender in position, contact height/angle
- Separate quality by action:
  - `overhead_dig_quality` — requires dig_control, reception
  - `platform_pass_quality` — requires reception, reception_balance
  - `diving_dig_quality` — requires dig_control, recovery (very low quality if diving)
- Formula (example overhead):
  ```
  overhead_dig_quality =
      dig_control / 100.0 * 0.40
      + reception / 100.0 * 0.30
      + approach_quality * 0.15  # approach from running affects balance
      + body_state_factor * 0.15  # BALANCED > MOVING > DIVING
  ```
- Output: Contact quality per action type
- Feeds into: Pass trajectory accuracy

#### 5. **Pass Trajectory** (MEASURED OBSERVABLE) ← **LANDED 2026-08-03**
> The home passer already resolved a real destination in
> `_reception_pass_result`, including the height term below; its scatter is now
> normal rather than uniform. The opponent's passer delivered to the setter's
> release position exactly, every time, however badly the ball was passed — it
> now uses `_delivered_point()` at the spread stated here. See
> `docs/BACKLOG.md` §8.
- Calculated from contact_execution_quality, similar to reception
- Formula:
  ```
  pass_height_meters = lerp(1.2, 2.8, contact_quality)
  pass_accuracy_stdev = lerp(0.50, 0.10, contact_quality)
  ```
- Output: Ball trajectory, landing position
- Feeds into: Setter perception
- **Critical for 2D playback:** Show outgoing pass arc and quality

#### 6. **Defense Success** (OUTCOME)
- Formula:
  ```
  defense_success = positioning_decision_quality * 0.25
      + movement_quality * 0.20
      + contact_quality * 0.30
      + (1.0 - attack_quality) * 0.25  # easier to dig bad attacks
  ```

### What Changes
- Separate `positioning_decision_quality` from movement execution
- Add `pass_trajectory`, `pass_height_meters` as observables
- Defense success depends on smart positioning, not just speed

---

## Summary: Updated Taxonomy

| Phase | Decision Quality | Execution Quality | Observable Output |
|---|---|---|---|
| **Attack** | Target selection (lane open?) | Per-action execution (power vs. placement) | Ball velocity (m/s), attack angle (rad), landing position |
| **Set** | Tempo decision (fast vs. slow) | Per-direction execution (front vs. back) | Set height (m), trajectory arc, release timing (ms) |
| **Block** | Strategy decision (commit vs. hold) | Hand positioning, hand angle | Hand position (x), hand angle (rad), reach envelope |
| **Defense** | Positioning decision (where to stand) | Movement + contact execution | Pass height (m), pass trajectory, landing position |

---

## Implementation Notes

### For Event Records
Each `RallyEvent` should capture:
- **Decision quality:** Was the strategic choice sound? (0–1)
- **Execution quality:** Was it performed well? (0–1)
- **Observable:** Measured physical property (velocity, angle, position)
- **Outcome:** Did it succeed? (success bool, evidence)

### For 2D Playback
The 2D view should display:
- Ball: position, velocity vector, trajectory arc
- Players: position, body state (balanced/moving/diving/airborne)
- Blockers: hand positions, hand angle relative to net
- Setters: release point relative to peak extension
- Hitters: approach direction, contact height
- Attack/pass arcs: parabolic trajectory from contact to landing

### For Observation Systems (Gate 44+)
- Blocker sees: Set arc (not exact landing), hitter approach direction (not exact contact point), other blocker positions
- Setter sees: Pass arc (not exact landing), reception quality (degraded if pass was poor)
- Hitter sees: Block geometry (not exact reaction), set trajectory (with variance), blocker commitment timing

### For Calibration
- Decision quality should be tested: Does a good strategy choice lead to better outcomes even with mediocre execution?
- Execution quality should be tested: Do better attributes lead to better observable outputs (ball velocity, trajectory accuracy)?
- Observable outputs should be tested: Do they match physical expectations (faster hitters = faster balls, better diggers = higher passes)?
