# Granular Attribute Breakdown: From Vague to Physical

**Status:** Proposal for refactoring high-level attributes into measurable physical actions.
**Scope:** Identify remaining summative attributes and break them into observable motion/biomechanics.
**Date:** 2026-07-30

---

## What's Already Granulated (Gate 43 Standard)

The current system decompose athletic ratings into physical measurements. Examples:

### Movement (ApproachMechanicsSystem)
- `lateral_speed` (1–100) → maximum approach speed (1.35–5.25 m/s)
- `acceleration` (1–100) → acceleration slope (2.2–6.8 m/s²)
- `approach_timing` (1–100) + `lateral_speed` + alignment → runway quality (0–1)
- Runway quality → jump multiplier (0.90–1.08x) and balance multiplier (0.58–1.04x)
- Gate 43 result: **release time → approach trajectory → available jump height and action menu**

### Reach & Vertical (ContactEnvelopeSystem)
- `height_cm`, `wingspan_cm` → standing reach (calculated: cm × 1.215 + span_adjusted)
- `jump_reach` (1–100) → jump displacement (0.12–0.78 m)
- `explosiveness` (1–100) → takeoff time (0.13–0.34 s, readiness-adjusted)
- Body state (BALANCED, MOVING, REACHING, DIVING, AIRBORNE) → posture factor (0.55–1.22x)
- `action_balance` (blended from action-specific attributes) → vertical pressure tolerance
- Gate 43 result: **maximum contact height = standing reach + (jump displacement × multipliers)**

### Recovery (ContactEnvelopeSystem)
- Post-jump recovery time = lerp(0.36, 0.18, action_balance)
- Action balance includes approach quality, balance, and body state
- Gate 43 result: **better approach = faster recovery from jump**

---

## Still Vague: Attributes Awaiting Granulation

These are collapsed into single 1–100 ratings but could be decomposed into measurable sub-actions.

### 1. Reception & Dig (`reception`, `reception_balance`, `reception_stability`)

**Current state:**
- `reception` (1–100) → used in role baseline (`baseline_defensive_range`)
- `reception_balance` (1–100) → action_balance blending for receive actions
- `reception_stability` (1–100) → action_balance blending + horizontal reach modifier

**What's missing (granulation proposal):**
- **Platform geometry:** forearm contact point relative to body (distance from feet, height above ankles, angle to vertical)
  - Poor reception: contact far from body, high variance
  - Elite reception: contact consistent, 30–45 cm from body center
  - *Measurement:* `reception_platform_distance_cm` (20–45) — affects reachable window

- **Contact dwell time:** how long the ball rests on the platform
  - Poor contact: ball bounces, dwell ≈ 0.08 s
  - Good contact: smooth transfer, dwell ≈ 0.12 s
  - *Measurement:* `contact_dwell_time_seconds` — affects pass accuracy

- **Pass trajectory:** height and arc of outgoing pass
  - Current: no trajectory model; just "reachable" or not
  - Proposed: `pass_apex_height_cm` (100–180) and `pass_arc_radians` (0.4–1.2)
  - *Measurement:* blends `reception` (height control) + `reception_balance` (consistency)

- **Multi-touch recovery:** steps after first contact before stability
  - Poor: 3–4 shuffle steps, slow
  - Elite: 1–2 adjustment steps, quick
  - *Measurement:* `post_contact_recovery_steps` (1–4) — derived from `reception_stability`

**Integration:** Feed `pass_trajectory` into setter perception (perceived_ball_destination is more accurate with better passes).

---

### 2. Setting (`set_accuracy`, `set_balance`, `set_stability`, `tempo_control`)

**Current state:**
- Blended into action_balance for hand contact evaluation
- No trajectory or tempo variation

**What's missing (granulation proposal):**
- **Set height:** target contact point for the hitter
  - Fast tempo: 2.0–2.2 m (hitter has little adjustment time)
  - Medium tempo: 2.2–2.4 m (balanced)
  - High set: 2.6–3.0 m (more time but less height advantage)
  - *Measurement:* `set_height_meters` (2.0–3.0) — derived from `tempo_control` + setter decision

- **Set distance (arc):** how far laterally the set travels
  - Short-line: 0.8–1.2 m (pin setter)
  - Middle: 1.8–2.2 m (pipe)
  - Back: 2.8–3.2 m (back-row hitter)
  - *Measurement:* `set_distance_meters` — setter chooses from available lane options

- **Disguise & release:** how long into the set motion the setter commits
  - Poor disguise: commits immediately, blocker reads it
  - Elite disguise: fakes across court, commits late
  - *Measurement:* `set_release_delay_ms` (0–250) — before peak extension
  - *Impact:* blocker perceived_action confidence decreases

- **Set accuracy (precision):** variance around the intended target
  - Poor: σ ≈ ±0.30 m horizontal
  - Elite: σ ≈ ±0.08 m horizontal
  - *Measurement:* `set_accuracy_stdev_meters` — affects hitter approach alignment

- **Contact stability:** hand contact steadiness (finger control, hand shape)
  - Poor: ball leaves with spin/rotation (harder to read contact point)
  - Elite: clean contact, minimal spin
  - *Measurement:* `set_contact_rotation` (radians/s) — feeds blocker read

**Integration:** Set height, distance, and release delay flow into blocker perceived_ball_destination and confidence. Set accuracy affects hitter's approach alignment.

---

### 3. Attack (`attack_power`, `attack_accuracy`, `tooling`)

**Current state (Gate 43):**
- `attack_power` (1–100) → used in ability score, role weighting
- Actual attack damage/placement is NOT currently simulated (resolver returns generic outcome)
- Action menu: ["controlled_roll", "tip", "placed_attack", "power_attack", "tool_block"]

**What's missing (granulation proposal):**
- **Ball exit velocity:** function of approach quality, arm speed, explosiveness
  - Current: `usable_attack_power()` blends attack_power (25%), mass (10%), explosiveness (18%), transition_speed (12%), arm_speed (20%), approach_timing (15%)
  - *Issue:* only affects ability score, not actual impact velocity
  - *Measurement:* `ball_exit_velocity_mps` (12–25) — derived from usable_attack_power + approach profile

- **Attack angle:** direction relative to hitter-to-blocker vector
  - Straight shot: 0° (down the net)
  - Crosscourt: 30–45° (risky, harder block)
  - Diagonal (seam): 15–20° (between blockers)
  - *Measurement:* `attack_angle_degrees` — hitter chooses based on block read and approach quality

- **Accuracy variance:** expected landing zone radius around target
  - Power attacks: high variance (±1.0 m)
  - Placed attacks: low variance (±0.3 m)
  - Tips: tiny variance (±0.15 m)
  - *Measurement:* `shot_target_stdev_meters` — action-dependent, influenced by `attack_accuracy`

- **Tooling contact point:** hitting the block intentionally
  - Requires clean approach and high arm reach
  - Contact height relative to block top: +0–10 cm
  - *Measurement:* `tooling_deflection_angle_degrees` (25–45) — how much block redirects the ball

**Integration:** Attack properties feed into opponent block perception (perceived ball velocity, trajectory). Accuracy variance affects actual landing position (resolver uses this for scoring).

---

### 4. Blocking (`block_timing`, `anticipation`)

**Current state:**
- `block_timing` (1–100) → action_balance for block actions
- No blocker read model, observation, or decision system yet (Gate 44 objective)
- Block outcome is authoritative resolver result

**What's missing (granulation proposal — Gate 44 focus):**
- **Reaction time:** blocker recognition latency from hitter commitment
  - Poor: 0.35–0.40 s (recognizes late, can't close)
  - Elite: 0.15–0.20 s (reads early, closes decisively)
  - *Measurement:* `block_read_latency_ms` (150–400) — derived from `anticipation` + `block_timing`
  - *Impact:* Gate 44 will expose this to blocker observation

- **Close speed:** how fast blocker transitions from read to block close
  - Poor: 1.2–1.5 m/s lateral movement
  - Elite: 2.0–2.4 m/s lateral movement
  - *Measurement:* `block_close_speed_mps` (1.2–2.4) — derived from `lateral_speed` + `block_timing`
  - *Impact:* affects blocker arrival time at the block

- **Hand positioning:** how well blocker angles hands across net
  - Poor: hands parallel to net, ball redirects off
  - Elite: hands angled to tooling deflections, redirects up
  - *Measurement:* `block_hand_angle_factor` (0.6–1.0) — affects tool block interception

- **Coordination (paired block):** timing between primary and assist blocker
  - Solo close: faster (one person) but narrower
  - Paired close: slower (two people) but wider coverage
  - *Measurement:* `block_close_gap_meters` (0.1–0.5) — depends on partner coordination

**Integration:** Gate 44 will feed these into blocker observation and decision-making. ShadowBlockSystem will compute perceived close feasibility from these properties.

---

### 5. Serve Mechanics (`serve_power`, `serve_accuracy`, `serve_variation`, `primary_serve_style`, `serve_style_proficiencies`)

**Current state:**
- Serve is not simulated; match just starts with serve result
- `primary_serve_style` and proficiencies exist but have no behavioral impact

**What's missing (granulation proposal — future gate):**
- **Serve velocity:** function of serve power and serve style
  - Float serve: 12–16 m/s (easier control)
  - Topspin jump: 18–22 m/s (more power, curl)
  - Float jump: 20–24 m/s (fastest, hardest control)
  - *Measurement:* `serve_velocity_mps` (12–24) — depends on `serve_power` + style

- **Spin rate:** rotation (RPS) imparted by serve
  - Float (no spin): ~0 RPS
  - Topspin: 20–50 RPS (dips late, hard to pass)
  - Float (jump): 2–8 RPS (knuckleball, unpredictable)
  - *Measurement:* `serve_spin_rps` (0–50) — depends on style + `arm_speed`

- **Serve placement accuracy:** landing zone variance
  - Short serve: ±0.3 m (hard to control)
  - Deep serve: ±0.5 m (less accurate)
  - Elite placement: ±0.15 m
  - *Measurement:* `serve_placement_stdev_meters` — inverse of `serve_accuracy`

- **Serve consistency:** reliability under pressure
  - Poor: success rate drops 20% under stress
  - Elite: success rate stable across matches
  - *Measurement:* `serve_consistency_under_pressure` (0.7–1.0) — derived from `serve_consistency` + `composure`

**Integration:** Would feed into receiver perception (read the spin, anticipate landing). Receiver decision-making changes based on serve type/speed/spin.

---

### 6. Mental Attributes (Reaction Time, Decision Latency)

**Current state:**
- `anticipation`, `decision_making`, `composure` (1–100) exist but are only used in ability scoring and some role weightings
- No reaction time or decision latency simulation

**What's missing (granulation proposal):**
- **Baseline reaction time:** sensorimotor latency from stimulus to motion start
  - Poor: 0.30–0.35 s (slow recognition, late commitment)
  - Elite: 0.12–0.18 s (quick recognition, early decision)
  - *Measurement:* `base_reaction_time_ms` (120–350) — inverse of `anticipation`
  - *Impact:* Gate 44 blocker observation latency; setter decision speed

- **Decision latency under pressure:** additional delay when multiple options exist
  - Poor: +100–150 ms (freezes, can't choose)
  - Elite: +20–40 ms (commits quickly)
  - *Measurement:* `decision_latency_under_pressure_ms` — derived from `decision_making` + `composure`
  - *Impact:* affects how quickly player commits to an action

- **Confidence decay:** how long it takes to doubt a read and change strategy
  - Poor: high flip-flop (changes mind 2–3 times)
  - Elite: commits once, high confidence
  - *Measurement:* `read_confidence_decay_time_ms` (200–1000) — how long perceived observation is trusted

- **Stress tolerance:** performance degradation under game pressure
  - Poor: attributes effectively drop 15–25% under high pressure
  - Elite: no degradation
  - *Measurement:* `stress_tolerance_factor` (0.75–1.0) — multiplier during critical moments

**Integration:** Gate 44+ will use these in blocker decision loops (hesitation, re-read, commitment time). Setter decision latency affects set tempo options.

---

### 7. Fatigue Mechanics

**Current state:**
- `fatigue` (0.0–1.0) → multiplies speed (1.0 - fatigue * 0.30) and jump access (1.0 - fatigue * 0.35)
- Generic 30–35% degradation across all actions

**What's missing (granulation proposal):**
- **Fatigue type:** different energetic systems degrade separately
  - Anaerobic fatigue: affects explosiveness, jump height (leg power)
  - Aerobic fatigue: affects sustained movement speed
  - Neuromuscular fatigue: affects decision latency, reaction time
  - *Measurement:* Separate `anaerobic_fatigue` (0–1), `aerobic_fatigue` (0–1), `neuro_fatigue` (0–1)

- **Action-specific fatigue accumulation:**
  - Jumping (block, attack, set): increases anaerobic fatigue
  - Sustained lateral movement: increases aerobic fatigue
  - Mental pressure (hard reads, decisions): increases neuromuscular fatigue
  - *Measurement:* Each action accumulates fatigue differently per type

- **Recovery rate:** how fast each fatigue type recovers
  - Anaerobic: fast (5–10 s rest recovers 50%)
  - Aerobic: slow (30+ s sustained low-intensity recovers 50%)
  - Neuro: very slow (2+ minute break recovers 50%)
  - *Measurement:* `recovery_rate_per_second` per fatigue type

- **Fatigue-specific degradation:**
  - Anaerobic ↑ → jump_reach, explosiveness drop
  - Aerobic ↑ → lateral_speed, transition_speed drop
  - Neuro ↑ → reaction_time, decision_latency increase
  - *Measurement:* Targeted multipliers per fatigue type

**Integration:** Match simulation would track fatigue accumulation per player per rally. Extended rallies with repeated jumps would see anaerobic spike but aerobic stability. Recovery time between rallies would use per-type recovery rates.

---

### 8. Position-Specific Mechanics

#### Setting (`set_accuracy`, `set_balance`, `set_stability`, `hand_control`)

**Granulated (already done):**
- Action balance for set reachability

**Remaining:**
- Set arc/trajectory (see Setting section above)
- Release timing and disguise
- Hand shape consistency

#### Hitting (`approach_timing`, `attack_accuracy`)

**Granulated (Gate 43):**
- Approach mechanics system fully decomposes approach timing into speed, alignment, runway completion, jump multiplier

**Remaining:**
- Attack velocity and angle (see Attack section above)
- Shot accuracy variance

#### Blocking (`block_timing`)

**Granulated (Gate 44 objective):**
- Reaction time, close speed, hand positioning, coordination

---

### 9. Serve-Receive Formation (`reception`, `reception_balance`)

**Current state:**
- Players are assigned to zones
- No model of how well they cover the zone (coverage geometry exists but is not attribute-driven)

**What's missing:**
- **Zone coverage efficiency:** how much of the assigned zone is effectively covered
  - Poor: 60% coverage (gaps in corners)
  - Elite: 90% coverage (tight positioning)
  - *Measurement:* `coverage_efficiency` (0.6–0.95) — derived from `reception`, `lateral_speed`, `anticipation`
  - *Impact:* affects probability of unreturnable serves

- **Read positioning:** how early the passer recognizes serve direction and pre-moves
  - Poor: no pre-move, reacts after serve leaves hand
  - Elite: moves during serve toss, cuts reaction time 0.2 s
  - *Measurement:* `serve_read_pre_move_time_ms` (0–200) — derived from `anticipation` + `decision_making`

---

## Summary Table: Vague → Granular Mappings

| Vague Attribute | Granulation Proposal | Derived From | Use Case |
|---|---|---|---|
| `lateral_speed` | speed_mps, acceleration, close_speed_mps | (already done) | Movement, blocking |
| `reception` | platform_distance, contact_dwell, pass_arc | (new) | Pass accuracy to setter |
| `set_accuracy` | set_height, set_distance, set_accuracy_stdev | (new) | Hitter approach alignment, blocker read |
| `set_balance` + `set_stability` | set_release_delay, contact_rotation | (new) | Blocker disguise read |
| `tempo_control` | set_height_meters | (new) | Hitter decision time |
| `attack_power` | ball_exit_velocity_mps | usable_attack_power | Opponent defense |
| `attack_accuracy` | shot_target_stdev_meters | (new) | Kill probability |
| `tooling` | tooling_deflection_angle | (new) | Block redirect |
| `anticipation` | reaction_time_ms, read_latency_ms | (new) | Blocker decision speed |
| `block_timing` | block_close_speed_mps, block_hand_angle | (new, Gate 44) | Block close success |
| `composure` | decision_latency_under_pressure, stress_tolerance | (new) | Mental pressure |
| `fatigue` | anaerobic_fatigue, aerobic_fatigue, neuro_fatigue | (new) | Type-specific degradation |
| `serve_power` + style | serve_velocity_mps, serve_spin_rps | (new, future) | Receiver challenge |

---

## Implementation Priority

### Immediate (supports Gate 44)
1. **Reaction time** (`anticipation` → `block_read_latency_ms`) — critical for blocker observation
2. **Block close speed** (`block_timing` + `lateral_speed` → `block_close_speed_mps`) — blocker movement feasibility
3. **Decision latency** (`decision_making` + `composure` → latency_ms) — blocker hesitation modeling

### Medium-term (Gate 44+ refinement)
4. **Setting trajectory** (`set_accuracy`, `tempo_control` → set height, distance, arc) — hitter approach impact
5. **Attack velocity** (`usable_attack_power` → ball exit speed) — block reading difficulty
6. **Reception trajectory** (`reception` → pass height, arc) — setter opportunity window

### Long-term (opponent-side systems, serve simulation)
7. **Fatigue breakdown** (anaerobic, aerobic, neuro) — extended-rally performance
8. **Serve mechanics** (velocity, spin, placement accuracy) — receiver challenge
9. **Mental latency under pressure** (stress tolerance, confidence decay) — clutch moments

---

## Integration Pattern

Each granulation should:
1. **Define the sub-attribute** (e.g., `block_close_speed_mps`)
2. **Derive it from one or more existing attributes** using lerp or formula
3. **Feed it into a specific decision or feasibility check** (e.g., blocker can close if arrival margin > 0)
4. **Update tests and calibration docs** to verify the new measurement behaves as intended

Example (block close speed):
```gdscript
var block_close_speed := lerpf(
    1.2, 2.4,  # slow to fast
    float(player.lateral_speed) * 0.6 + float(player.block_timing) * 0.4
) / 100.0
```

This is then used in `ShadowBlockSystem` (Gate 44) to compute whether a blocker can reach a lateral position in time.
