# Rally Event Quality Calculation Map

**Status:** Audit of which rally phases are attribute-driven vs. authoritative/stub.
**Date:** 2026-07-30

---

## Pragmatically Calculated Events (Attribute-Driven)

These events compute quality from player attributes, position, timing, and environmental factors. They feed into playback and downstream decisions.

### 1. SERVE

**Calculated:** Line 77–90 in `rally_simulator.gd`

**Quality factors:**
- `serve_power` (28%) — ball speed
- `serve_technique` (13%) — form consistency
- `serve_placement` (7%) — targeting accuracy
- `serve_consistency` (12%) — reliability
- `serve_aggression` (4%) — risk-taking
- `serve_style_proficiency` (8%) — proficiency with chosen style
- Random noise (±0.18)
- **Range:** 0.05–0.98

**Error chance (separate):**
- `serve_aggression` × 0.08 (increases error)
- `serve_consistency` × 0.055 (decreases error)
- `serve_style_proficiency` × 0.02 (decreases error)
- **Range:** 0.01–0.15

**What's NOT pragmatic:**
- Serve landing point is from team tendencies, not individual attributes
- Serve flight trajectory is fixed shape; only quality modulates speed/pressure
- Spin and velocity variation per style exist only as proficiency weights

---

### 2. RECEPTION

**Calculated:** Line 213–225 in `rally_simulator.gd`

**Quality factors:**
- `reception` (58%) — forearm pass baseline
- `ball_control` (24%) — touch consistency
- `−serve_quality` (−44%) — serve difficulty penalizes reception
- `reception_body_penalty()` (computed from position + timing + serve_quality)
- `arrival_margin` (±0.065, clamped ±0.16) — reaction time bonus/penalty
- `support_count` (×0.025, clamped +0.075 max) — nearby teammates help
- `serve_receive_bonus` — opponent team scouting adaptation
- Random noise (±0.12)
- **Range:** 0.0–1.0

**Base formula:**
```
reception_quality = clampf(
    reception * 0.58 + ball_control * 0.24
    − serve_quality * 0.44 + 0.27
    − body_penalty(position, timing)
    + margin_bonus + support_bonus + scouting_bonus
    + noise,
    0.0, 1.0
)
```

**If receiver didn't arrive:** Quality clamped to ≤ 0.12

**What's NOT pragmatic:**
- Pass trajectory (destination) is authoritative (where serve lands), not derived from player touch
- No pass height, arc, or dwell-time variation based on contact quality
- Reception attributes don't feed into setter perception (missing link)

---

### 3. SET (Tactical Decision & Contact)

**Calculated:** Line 480–490 in `rally_simulator.gd`

**Quality factors:**
- `set_accuracy` (primary)
- `set_balance` (secondary)
- `set_stability` (secondary)
- `hand_control` (tertiary)
- Reception quality (×0.28) — good pass makes setting easier
- `−tempo_demand` — fast tempo lowers quality
- `set_style_familiarity` — if setter has practiced the called tempo
- Random noise (±0.12)
- **Range:** 0.0–1.0

**Base formula:**
```
set_base = set_attributes_blended
    + reception_quality * 0.28
    − tempo_demand
    + familiarity_bonus
set_quality = clampf(set_base + noise, 0.0, 1.0)
```

**What's NOT pragmatic:**
- Set trajectory (height, distance, arc, disguise) is fixed/generic, not derived from setter choice or contact quality
- No set placement variance; all sets go to tactical target or fallback (predetermined)
- Set release timing (disguise) not modeled
- Setter doesn't perceive reception_quality; reads idealized ball flight instead

---

### 4. ATTACK

**Calculated:** Line 599–625 in `rally_simulator.gd`

**Quality factors (Gate 43 new):**
- `attack_power` (included in usable_attack_power calculation)
- `explosiveness`, `arm_speed`, `transition_speed`, `approach_timing`, mass (feed into usable_attack_power)
- `runup_quality` (from ApproachMechanicsSystem) (×0.24) — clean approach enables better attack
- `approach_fit` — alignment of approach to set direction
- Set quality (×0.25) — good set makes attack easier
- `−tempo_demand` — fast tempo (more vertical approach) reduces control
- Random noise (±0.16)
- **Range:** 0.0–1.0

**Base formula:**
```
attack_base = usable_attack_power
    + runup_quality * 0.24
    + approach_fit
    + set_quality * 0.25
    − tempo_demand
attack_quality = clampf(attack_base + noise, 0.0, 1.0)
```

**Gate 43 causal chain:**
1. Hitter perceives set arrival time and position
2. Duty assignment (transition setter, coverage hold, etc.) determines release time
3. Available prep time → approach trajectory (speed, alignment, lateral control)
4. Approach quality → jump multiplier and available attack families
5. Attack quality determined post-approach

**What's NOT pragmatic:**
- Attack angle/target selection is authoritative (predetermined or tactical assignment)
- Attack trajectory shape is fixed; only quality modulates landing accuracy
- Tooling, finesse, tip actions don't have separate quality calculations; all use attack_quality
- No attack power variance (ball exit velocity is deterministic from attack_quality, not attribute-driven)

---

### 5. BLOCK (Read Quality + Contact Skill)

**Block Read Quality:** Line 2672–2687 in `rally_simulator.gd`

**Quality factors:**
- `anticipation` (34%) — early read
- `court_vision` (25%) — positioning awareness
- `decision_making` (21%) — commitment speed
- `tactical_discipline` (20%) — following team plan
- `cue_clarity` — derived from set_quality, setter position, tempo
- Random noise (±0.08)
- **Range:** 0.0–1.0

**Cue clarity (what blockers can perceive):**
- `(1.0 - set_quality) * 0.18` — poor sets are easier to read
- `|setter_x - 0.5| * 0.16` — setter away from net center is clearer
- `tempo * 0.025` — faster tempo gives more cues

**Block Contact Skill:** Line 2716–2726 in `rally_simulator.gd`

**Quality factors:**
- `block_timing` (40%) — takeoff sync
- `_available_jump_rating()` (25%) — jump height access
- `_body_reach_rating()` (13%) — standing reach
- `anticipation` (8%) — reaction speed
- `close_fraction` (14%) — successful lateral approach
- **Range:** 0.05–0.98

**Block Close Fraction:** Line 2690–2713 in `rally_simulator.gd`

**Calculated from:**
- Current blocker position (live or tactical home)
- Attack target X position
- `anticipation` → reaction_delay (0.34 to 0.12 s)
- `lateral_speed` → movement speed (1.25 to 4.40 m/s)
- Mass → movement speed multiplier (1.05 to 0.91)
- Available time after reaction delay
- Distance to target
- **Output:** 0–1 (1.0 = fully positioned, 0.0 = no time to move)

**Total Block Quality:**
```
block_quality = (read_quality + contact_skill) * 0.5 (approximately)
    + contest_randomness (±0.14)
```

**What's NOT pragmatic:**
- Blocker doesn't form hypotheses or perceived observations (Gate 44 objective)
- No player-specific blocker observation model (no information boundary)
- Blocker position is tactical assignment, not observation-driven movement
- Block hand positioning, tool deflection angles not modeled
- No block coordination model (paired primary/assist dynamics)

---

### 6. FLOOR DEFENSE (Dig)

**Calculated:** Line 1198–1220 in `rally_simulator.gd`

**Quality factors:**
- `anticipation` (34%) — read of attack direction
- `reception` (28%) — passing baseline
- `dig_control` (16%) — overhead pass control
- `lateral_speed` (18%) — movement to ball
- `responsibility_fit` (computed) — defensive assignment alignment
- `arrival_margin` (±0.065, clamped) — time margin bonus/penalty
- `support_count` (×0.018, clamped) — nearby teammates
- `reception_body_penalty()` — position + timing penalty
- Tactical plan modifiers:
  - Short-ball posture (Compress Short ±0.08, ±0.035)
  - Defensive depth (Deep ±0.035, Shallow ±0.045)
- Random noise (±0.12)
- **Range:** 0.0–1.0

**Success criteria:**
- Defender must arrive (position within reach)
- `defense_quality > opponent_attack - 0.12`

**Base formula:**
```
defense_quality = anticipation * 0.34 + reception * 0.28
    + dig_control * 0.16 + lateral_speed * 0.18
    + responsibility_fit
    + arrival_margin_bonus
    + support_bonus
    − body_penalty
    + tactical_modifiers
    + noise
```

**What's NOT pragmatic:**
- Defensive position is tactical assignment (floor_phase_positions), not observation-driven
- No defensive observation system (what defender perceives about attack angle/trajectory)
- No multi-touch recovery (dig to set transition is assigned, not recovered)
- Support players don't contribute actively; only count affects bonus

---

## Stub/Authoritative Events (Still Missing Pragmatism)

### 1. Serve Landing Point

**Currently:** Team tendencies + opponent_team routing
**Should be:** Derived from serve_placement, serve_accuracy, player position, serve_style
**Gate estimate:** Future (serve simulation gate)

---

### 2. Set Trajectory Properties

**Currently:** Fixed; destination only (no height, arc, or release timing)
**Should derive from:**
- `tempo_control` → set height (fast = 2.0–2.2m, medium = 2.2–2.4m, slow = 2.6–3.0m)
- `set_distance` → lateral distance to hitter (chosen from tactical lanes)
- `set_disguise` → release timing delay relative to load
- `hand_control` → spin imparted
- Contact quality → variance in trajectory
**Gate estimate:** Reception-quality gate (future)

---

### 3. Attack Trajectory & Landing Precision

**Currently:** Fixed arc shape; attack_quality only affects landing radius
**Should derive from:**
- `attack_power` → ball exit velocity (12–25 m/s)
- `attack_accuracy` → landing zone variance (±0.3 to ±1.0 m depending on action)
- `shot_variety` → available angles (straight, crosscourt, seam)
- Approach angle + body alignment → actual attack angle
**Gate estimate:** Attack-detail gate (future)

---

### 4. Blocker Observation & Decision System

**Currently:** Blocker reads are authoritative; no observation model
**Should have (Gate 44):**
- `ShadowBlockSystem` producing player-specific observations
- `PlayerObservation` with perceived setter cues, set estimates, hitter approach cues
- `BlockerProgressionCalibration` testing read accuracy and commitment timing
- Blocker decision must use only perceived information
**Gate estimate:** Gate 44 (current)

---

### 5. Attack-to-Block Information Passing

**Currently:** Setter doesn't perceive pass quality; blockers don't perceive attack details
**Should add:**
- Setter receives degraded ball flight estimate based on reception_quality
- Blockers perceive hitter approach trajectory (not authoritative contact)
- Blockers perceive set trajectory (not authoritative destination)
- Blockers form hypotheses and update as information arrives
**Gate estimate:** Gates 44–47 (blocker slice)

---

### 6. Serve Variation (Velocity, Spin, Placement Accuracy)

**Currently:** Serve quality is monolithic; no per-serve-style velocity/spin model
**Should have:**
- `serve_velocity_mps` (12–24) derived from serve_power + style
- `serve_spin_rps` (0–50) derived from arm_speed + style
- `serve_placement_stdev` (±0.15 to ±0.5 m) derived from serve_accuracy
- Receiver perceives serve velocity and spin; impacts pass difficulty
**Gate estimate:** Future (serve simulation gate)

---

### 7. Fatigue Degradation (Type-Specific)

**Currently:** Flat fatigue (0–1); all attributes degrade by ~30%
**Should have:**
- `anaerobic_fatigue` (jump power)
- `aerobic_fatigue` (sustained movement)
- `neuromuscular_fatigue` (reaction time, decision latency)
- Each action type accumulates specific fatigue type
- Recovery rates differ by type (anaerobic fast, aerobic slow, neuro very slow)
**Gate estimate:** Future (fatigue-detail gate)

---

### 8. Pressure & Composure Under Stress

**Currently:** Composure attribute exists; unused in decision latency
**Should model:**
- `reaction_time_under_pressure_ms` (increases with score pressure, match stakes)
- `decision_latency_under_stress` (blocker hesitation, setter freeze)
- `stress_tolerance_factor` (degradation in high-pressure moments)
- Attribute `composure` should reduce these penalties
**Gate estimate:** Future (mental-performance gate)

---

## Quality Calculation Template

When adding new pragmatic calculations, follow this pattern:

```gdscript
var [event]_quality := clampf(
    player_attribute_1 * weight_1
    + player_attribute_2 * weight_2
    + environmental_factor * weight_3
    - opposing_factor * weight_4
    + upstream_event_quality * weight_5
    + position_fit_bonus
    + support_bonus
    + contextual_modifiers
    + rng.randf_range(-noise_floor, noise_ceiling),
    0.0, 1.0
)
```

**Constraints:**
1. Never use authoritative future information (contact player, exact outcome)
2. Use only information available to the observer at decision time
3. Attribute weights should sum to ~1.0 (before environmental factors)
4. Each weight should be justified in comments
5. Include noise to prevent deterministic clustering
6. Clamp final quality to (0, 1)

---

## Summary: What Exists vs. What's Missing

| Phase | Quality Calc | Trajectory | Observation | Gate |
|---|---|---|---|---|
| Serve | ✓ Pragmatic | ✓ Partial (speed only) | ✗ Stub | Future |
| Reception | ✓ Pragmatic | ✗ Authoritative | ✓ Partial (no pass quality feedback) | Future |
| Set | ✓ Pragmatic | ✗ Authoritative | ✗ Stub (doesn't see pass quality) | Future |
| Attack | ✓ Pragmatic (Gate 43) | ✗ Authoritative | ✗ Stub | Future |
| Block | ✓ Pragmatic (read + skill) | N/A | ✗ Missing (Gate 44) | 44 |
| Defense | ✓ Pragmatic | ✗ Authoritative | ✗ Stub | Future |

**Red flags (biggest gaps):**
1. **Blocker observation system missing entirely** (Gate 44)
2. **Setter doesn't perceive pass quality** (should be Gates 44–47 recovery)
3. **Attack and set trajectories are fixed** (should drive downstream perception)
4. **Serve landing is team-level, not player-driven** (breaks individual skill differentiation)
