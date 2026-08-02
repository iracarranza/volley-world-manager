# Player Attributes Ledger

**Status:** Comprehensive inventory of all tracked player data.
**Last updated:** 2026-07-30

---

## Part 1: Career / Roster Attributes

These are **persistent, long-term properties** tied to a `VolleyballPlayer` resource and loaded from save files. They change through training, development, and progression systems, not during individual rallies.

### Identification & Status

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `id` | int | -1 or valid ID | Unique identifier for save/load |
| `display_name` | string | any | UI display name |
| `position_role` | string | "Setter", "Outside Hitter", "Middle Blocker", "Opposite", "Libero" | Current lineup role |
| `position_code` | string | e.g. "OH", "S", "MB" | Shorthand position code |
| `availability` | enum | "Available", "Resting", "Injured", "Suspended" | Match availability state |

### Lifecycle

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `age` | int | 15–45 | Years old |
| `professional_experience` | int | 0–25 | Years in professional play |
| `potential` | int | 1–100 | Career ceiling rating (for scouting) |
| `morale` | float | 0.0–1.0 | Psychological state (affects form) |

### Physical Base Traits

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `height_cm` | float | 150–220 | Standing height in centimeters |
| `mass_kg` | float | 50–130 | Body mass in kilograms |
| `wingspan_cm` | float | 150–235 | Arm span in centimeters |
| `dominant_hand` | enum | "Right", "Left" | Throwing/hitting hand |

**Derived:** `standing_reach_cm()` = `height_cm * 1.215 + (wingspan_cm - height_cm) * 0.32`

### Physical Ability Ratings

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `acceleration` | int | 1–100 | Explosive start speed (0 to top speed in <1s) |
| `lateral_speed` | int | 1–100 | Side-to-side movement velocity |
| `transition_speed` | int | 1–100 | Front-back movement velocity |
| `jump_reach` | int | 1–100 | Maximum reach while jumping |
| `explosiveness` | int | 1–100 | Power generation in jumps and movements |
| `stamina` | int | 1–100 | Fatigue resistance over a match |
| `arm_speed` | int | 1–100 | Hand/arm velocity independent of body |

### Technical: Serving

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `serve_power` | int | 1–100 | Ball velocity (deprecated; split into style-specific) |
| `serve_accuracy` | int | 1–100 | Landing consistency (deprecated baseline) |
| `serve_technique` | int | 1–100 | Motion consistency and form |
| `serve_placement` | int | 1–100 | Ability to target zones intentionally |
| `serve_consistency` | int | 1–100 | Repeat reliability of power/placement |
| `serve_aggression` | int | 1–100 | Willingness to hit hard vs. safe serves |
| `serve_variation` | int | 1–100 | Deception / variety in serve types |
| `primary_serve_style` | enum | "Standing", "Jump Topspin", "Jump Float", "Hybrid", "Sky Ball" | Default serve type |
| `serve_style_proficiencies` | dict | style → 1–100 score | Per-style rating override |

### Technical: Reception & Dig

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `reception` | int | 1–100 | Pass success (forearm pass accuracy/control) |
| `reception_balance` | int | 1–100 | Stability on first contact (role defaults apply) |
| `reception_stability` | int | 1–100 | Multi-contact recovery after first ball |
| `ball_control` | int | 1–100 | General ball touch and feel (floor defense) |
| `dig_control` | int | 1–100 | Defensive overhead pass quality |

### Technical: Setting

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `set_accuracy` | int | 1–100 | Set placement precision |
| `set_balance` | int | 1–100 | Stability while setting (initial balance) |
| `set_stability` | int | 1–100 | Multi-contact setting recovery |
| `tempo_control` | int | 1–100 | Early/tight set execution |
| `set_disguise` | int | 1–100 | Deception in set direction/height |
| `hand_control` | int | 1–100 | Fine finger control and release |

### Technical: Attack

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `attack_power` | int | 1–100 | Hit velocity (base; derived by `usable_attack_power()`) |
| `attack_accuracy` | int | 1–100 | Targeting precision on kills/dumps |
| `approach_timing` | int | 1–100 | Runway completion and takeoff sync |
| `tooling` | int | 1–100 | Ability to hit off block intentionally |
| `feinting` | int | 1–100 | Fake-out / change-of-pace shots |
| `finesse` | int | 1–100 | Soft/placement shots and short-range control |
| `shot_variety` | int | 1–100 | Available attack action diversity |

### Technical: Blocking

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `block_timing` | int | 1–100 | Takeoff sync with hitter; block close readiness |

### Mental / Tactical

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `court_vision` | int | 1–100 | Field awareness and anticipation of opportunities |
| `anticipation` | int | 1–100 | Read-ahead of opponent intent |
| `decision_making` | int | 1–100 | Speed and quality of shot/action selection |
| `composure` | int | 1–100 | Pressure resistance and clutch performance |
| `tactical_discipline` | int | 1–100 | Adherence to game plan |
| `improvisation` | int | 1–100 | Ability to adapt outside the plan |
| `adaptability` | int | 1–100 | Speed of adjustment to opponent or role change |

### Development & Progress

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `fatigue` | float | 0.0–1.0 | Current match fatigue (degrades capabilities) |
| `current_form` | float | -1.0–1.0 | Temporary performance modifier (hot/cold streak) |
| `traits` | array[string] | any | Special ability tags (e.g., "clutch_performer", "left_hand_hitter") |
| `primary_position` | string | any | Career primary role (may differ from `position_role` in rotation) |
| `natural_positions` | array[string] | any | Positions player can play competently |
| `position_familiarity` | dict | position → 1–100 score | Role-specific comfort/experience |
| `situation_experience` | dict | situation → count | Career play history (e.g., "critical_sets", "tournament_finals") |
| `position_training_target` | string | any | Development goal position (active coaching) |

### Score Calculations

**`current_ability_score()`** — Blends role-weighted attributes (75%) with full ability average (25%).

**`usable_attack_power()`** — Derived from `attack_power` (25%), normalized mass (10%), explosiveness (18%), transition_speed (12%), arm_speed (20%), approach_timing (15%).

**`baseline_defensive_range()`** — Derived from acceleration (22%), lateral_speed (24%), anticipation (22%), standing reach (14%), ball_control (8%), stamina (10%).

---

## Part 2: Rally-Time Player State

These properties change **during each rally** and are stored in `RallyPlayerState`. They capture the player's position, motion, commitment, and readiness at each moment.

### Position & Movement

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `position` | Vector2 | (0,0) to (1,1) | Current court location (normalized 2D) |
| `velocity` | Vector2 | any | Current movement vector (units per second) |
| `facing` | Vector2 | normalized | Direction player is facing / looking (auto-updated from velocity) |

### Team & Role Binding

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `player_id` | int | valid ID | Reference to career `VolleyballPlayer` |
| `team_side` | StringName | &"home" or &"opponent" | Which team |
| `rotation_slot` | int | 0–5 | Position in current lineup (also the zone number) |

### Movement Intent & Commitment

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `movement_mode` | enum | IDLE, LATERAL, TRANSITION, APPROACH, BLOCK_CLOSE, RECOVERY | Current motor mode |
| `intent` | StringName | &"idle", &"move_to", &"serve", &"receive", etc. | Declared action intent |
| `intent_target` | Vector2 | (0,0) to (1,1) | Target destination (for LATERAL, TRANSITION, APPROACH) |
| `committed_until` | float | ≥ 0 | Time when current action commitment ends (can't change intent before this) |

### Body & Balance

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `body_state` | enum | BALANCED, MOVING, REACHING, DIVING, AIRBORNE, RECOVERING | Current physical posture |
| `balance` | float | 0.0–1.0 | Stability / readiness to move (1.0 = fully stable, decreases while moving) |
| `readiness` | float | 0.0–1.0 | Reaction speed multiplier (fatigue and prior action recovery reduce this) |

### Contact & Recovery

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `last_contact_time` | float | -1.0 or valid time | When this player last touched the ball (-1 if never) |
| `recovery_until` | float | ≥ 0 | Time after which player is available again (after diving, jumping, etc.) |

### Tactical Assignment

| Attribute | Type | Range | Purpose |
|---|---|---|---|
| `tactical_home` | Vector2 | (0,0) to (1,1) | Desired default position (set by coach, not forced) |
| `responsibility_priority` | int | 1–∞ | Priority tier for the next action (lower wins contention) |

### State Snapshot Methods

**`snapshot()`** — Deep copy of all state except the career `player` profile (immutable reference).

**`is_available(at_time)`** — Returns true if `at_time >= committed_until AND at_time >= recovery_until`.

---

## Part 3: Observable Player State

These properties form the **decision-safe view** (`PlayerObservation`) exposed to AI decision-making, perception, and candidate evaluation systems. Authoritative contact truth, exact outcomes, and resolver-only facts are **never included** here.

### Identity & Timing

| Attribute | Type | Purpose |
|---|---|---|
| `observer_id` | int | Who sees this observation (player ID) |
| `side` | StringName | Which side the observer is on (&"home" or &"opponent") |
| `observed_at` | float | Rally time when observation was made |
| `recognition_time` | float | Latency from ball contact to recognition |

### Perceived Ball & Contact

| Attribute | Type | Purpose |
|---|---|---|
| `perceived_ball_destination` | Vector2 | Estimated landing zone or target point |
| `perceived_ball_arrival_time` | float | Expected contact/arrival time |
| `perceived_contact_height_meters` | float | Estimated contact point height |
| `confidence` | float | 0–1: certainty in the perception |

### Feasibility & Opportunity

| Attribute | Type | Purpose |
|---|---|---|
| `perceived_reachable` | bool | Can this observer reach the ball? |
| `perceived_arrival_margin` | float | Time before/after optimal contact window (negative = too late) |
| `perceived_physical_feasibility` | float | 0–1: likelihood action is physically executable |
| `perceived_expected_quality` | Vector2 | (min_quality, max_quality) range estimate |

### Action & Decision Space

| Attribute | Type | Purpose |
|---|---|---|
| `perceived_action` | StringName | Role action: &"receive", &"set", &"attack", &"block" |
| `perceived_actions` | Array[String] | Available action variants (e.g., ["controlled", "placed", "power", "tip"]) |

### Situation Context

| Attribute | Type | Purpose |
|---|---|---|
| `responsibility` | String | Assigned duty (e.g., "primary_receiver", "slide_setter") |
| `responsibility_priority` | float | 0–1: priority weight vs. other observers |
| `perceived_target` | Vector2 | Target location for attack/set (if applicable) |
| `perceived_teammates` | Array[Dictionary] | Simplified view of teammate positions/states (no authoritative data) |
| `perceived_opponents` | Array[Dictionary] | Simplified view of opponent positions/reads (no exact contact data) |
| `tactical_context` | Dictionary | Coach-supplied instructions, reading cues, coverage state (decision-safe keys only) |

### Decision Fingerprinting

**`decision_fingerprint()`** — Deterministic hash of observation for regression testing. Changes only if perceived inputs change, never if authoritative truth changes.

**`to_decision_dict()`** — Subset used for selection scoring: `perceived_expected_quality`, `perceived_arrival_margin`, `confidence`, `responsibility_priority`.

**`selection_score()`** — Weighted blend: quality_center (34%) + confidence (22%) + responsibility_priority (24%) + margin_score (20%).

---

## Part 4: Attributes Modified by Gate 43 (Causal Attack Preparation)

Gate 43 made hitter **release time** and **approach trajectory** causal. These rally-time consequences now flow from tactical state:

### During Attack Preparation

1. Hitter perceives end-of-responsibility time from duty assignment (e.g., "transition setter is done, I release now").
2. Remaining time budget = `set_contact_time - release_time`.
3. From `RallyPlayerState.position`, `velocity`, and time budget, `ApproachMechanicsSystem` computes:
   - Run-up distance and direction
   - Acceleration phase length
   - Approach speed (scalar)
   - Lateral control during approach
   - Final position and velocity at takeoff

4. These outputs feed `ContactEnvelopeSystem` and `ShadowAttackSystem`:
   - **Approach speed** scales available jump height (faster approach = higher jump, but less control).
   - **Lateral control** affects reach width and balance.
   - **Alignment** (run direction vs. set trajectory) determines available attack families.
   - **Takeoff position** determines angle of attack relative to block.

5. **Result:** Better decision-making and recovery time → better release → better approach → higher jump and more attack options. Worse reads → late release → truncated approach → lower jump and fewer actions.

No authoritative contact truth is used in this decision loop. Post-contact, the resolver audits whether the chosen action fits the computed takeoff profile.

---

## Part 5: Attribute Categories by Role (Defaults)

Players have **role-weighted position profiles**:

| Position | Key Weighted Attributes |
|---|---|
| **Setter** | set_accuracy, set_balance, set_stability, tempo_control, set_disguise, hand_control, court_vision, decision_making |
| **Outside Hitter** | attack_power, attack_accuracy, approach_timing, tooling, finesse, shot_variety, reception, reception_balance |
| **Middle Blocker** | block_timing, jump_reach, explosiveness, lateral_speed, attack_power, approach_timing, anticipation |
| **Opposite** | attack_power, attack_accuracy, jump_reach, approach_timing, tooling, shot_variety, block_timing, serve_power |
| **Libero** | reception, reception_balance, reception_stability, dig_control, ball_control, anticipation, lateral_speed, decision_making |

Role defaults also apply physical trait defaults (e.g., Setters default to 188 cm height, Liberos to 178 cm).

---

## Part 6: Non-Player State

The following are **not player attributes** but are tracked per rally:

| Entity | Type | Contains | Purpose |
|---|---|---|---|
| `RallyState` | global state | phase, ball, all players, score, time | Authoritative rally truth |
| `RallyBallState` | ball model | position, velocity, spin, phase | Current ball physics |
| `RallyEvent` | history record | contact player, action chosen, outcome, evidence | Resolved event for playback |
| `BallFlightEstimate` | perception model | perceived_destination, confidence, arrival_time | Player's ball read (fed into `PlayerObservation`) |
| `ActionOpportunity` | feasibility model | reachable, arrival_margin, physical_feasibility | Computed contact window (fed into `PlayerObservation`) |

---

## Summary by Information Barrier

**Authoritative truth (resolver only):**
- Actual ball contact player, time, position, height
- Actual final attack direction and zone
- Actual block close success/failure
- Game score (resolved after rally)

**Player observation (decision-safe):**
- Perceived ball trajectory and arrival
- Feasibility estimates
- Availability of action variants
- Tactical duty and priority
- Teammate/opponent perceived state (no exact future truth)

**Cannot appear in decisions:**
- Keys prefixed `true_` or `authoritative_`
- Resolver-only computed results
- Future contact outcomes before they are resolved
