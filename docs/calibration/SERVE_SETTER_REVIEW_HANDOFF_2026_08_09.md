# Serve, setter and block-strategy review handoff

Review date: 2026-08-09

Review target: uncommitted working tree on
`claude/system-fit-serve-receive-von64k`, based on
`ad3de20f86d6e30ebdfc24eac8695263275e5be7`.

Status: **implemented and foundation-suite green; coefficients and several
decision-path asymmetries remain reviewable.** This is not an empirical claim
that the formulas are uniquely correct.

## Scope

The working tree adds four related behaviors:

1. Serve choice and execution now use power, technique, placement,
   consistency, aggression, variation, prior-serve state and named-target
   familiarity.
2. Setter choice now prices hitter quality, displacement, rescue height,
   opponent anticipation, instruction, judgment and pressure.
3. Extra set height now costs set accuracy, improves blocker read and reduces
   swing quality while still buying flight time.
4. Funnel and seal now have distinct floor-defense meanings, and every raw
   player attribute has a tooltip.

Primary code:

- `scripts/simulation/rally_simulator.gd`
- `scripts/models/match_state.gd`
- `scripts/managers/game_manager.gd`
- `scripts/systems/attribute_profile_system.gd`
- `scenes/screens/journal_screen.gd`
- `tests/test_runner.gd`

The title-screen and light/dark-theme edits in the same worktree predate this
change and are not part of this review.

## Reading the numbers

Unless stated otherwise, `_rating(player, attribute)` is not raw `attribute /
100`. It applies fatigue, confidence and current form, then clamps to
`[0.05, 1.0]`:

```text
rating = clamp(
    raw / 100 * (1 - fatigue * 0.18) * confidence_execution_scale
    + current_form * 0.06,
    0.05,
    1.0
)
```

`_power_rating` adds a mass term for serve power:

```text
mass_bonus = clamp((mass_kg - 82) / 48, -0.50, 1.0) * 0.07
serve_power_rating = clamp(rating(serve_power) + mass_bonus, 0.05, 1.0)
```

**Disclaimer:** every coefficient below is a gameplay heuristic fitted against
existing gates and fixture populations. None is a biomechanics result, an
observational volleyball regression or a generally valid probability model.
Claude should contest a coefficient by measuring its live input distribution
and downstream aggregate, not by replacing it with another plausible constant.
This is the core requirement of `docs/FAILURE_MODES.md` sections 0, 2, 3 and 5.

## Serve calculation

### Choice

The decision uses a private `serve_decision_rng`, seeded from
`hash("<rally seed>|serve-decision")`, so its three decision draws do not
re-sequence the shared rally RNG.

```text
change_chance = serve_variation * 0.72
aggression_chance = clamp(serve_aggression * 0.68 + tactical_risk * 0.32)
mode = aggressive when aggression_roll < aggression_chance
```

On a variation-triggered change, one of the other three named targets is chosen
uniformly. The four names are Zone 5, Zone 1, Short Middle and Weak Passer.

Aggressive mode raises effective risk to at least `aggression_chance`. Targeted
mode multiplies tactical risk by `0.72`.

**Disclaimers:**

- Variation changes the named target, not serve style, pace or depth within a
  target. The tooltip is broader than the current consumer.
- The manager's called target is a starting point, not an invariant; variation
  may override it. Whether a player attribute should override a direct tactical
  instruction is a design question.
- `changed_target` is currently keyed to the variation roll. If the manager
  changes the called target between serves without that roll, the actual target
  can change while metadata says it did not, avoiding the change-accuracy
  penalty. This is a known semantic edge for review, not a defended behavior.
- The history is one prior serve per side/server. It does not model streak
  length, alternating patterns, target/style combinations or confidence in a
  sequence.

### Familiarity and accuracy

An officially recorded serve adds one exposure to
`serve_target:<named target>`. Adaptability scales the exposure:

```text
experience_gain = 0.65 + (raw_adaptability / 100) * 0.90
target_familiarity = 1 - exp(-experience / 18)
learned_control = 0.30 + target_familiarity * 0.70
execution_accuracy =
    learned_control * 0.58
    + serve_consistency * 0.30
    + serve_technique * 0.12
```

Changing target subtracts `(1 - consistency) * 0.24`. Repeating a target adds
`consistency * 0.08`. The final result is clamped to `[0.05, 0.98]`.

**Disclaimers:**

- Familiarity is intentionally the largest accuracy input, per the design
  request, but the `58%` share and exponential scale `18` were not calibrated
  against real serve charts.
- Familiarity is attached to one of four labels, not an exact coordinate. A
  server familiar with deep Zone 5 receives the same familiarity for a nearby
  short or seam aim still carrying that label.
- Adaptability affects how quickly serve familiarity grows because this reuses
  the generic familiarity system. That coupling was inherited, not separately
  justified for serving.
- Consistency enters accuracy, repeat/change adjustment, serve quality and serve
  error control. Technique enters accuracy, usable pace and error control. This
  repeated influence may be legitimate compounding or double-counting; only a
  sensitivity sweep can distinguish it.
- Preview resolutions do not write familiarity or history. Only
  `GameManager.record_rally` advances them, preserving replay determinism.

### Aim and landing

Placement first defines the specificity of the aim:

```text
target_radius_m = lerp(1.80, 0.22, serve_placement)
```

A point is sampled uniformly in an axis-aligned square around the named anchor.
On a repeated target it is blended toward the prior exact aim by
`serve_consistency`. This is then distinct from execution scatter:

```text
x_deviation = lerp(0.105, 0.018, execution_accuracy)
y_deviation = x_deviation * 0.65
```

Those deviations are normalized-court units, not metres. The landing is finally
clamped inside the receiving half unless a separate serve-error verdict moves
it out through `_errant_serve_landing`.

Aggressive serves scan an 11 by 7 grid within 1.5 m of the anchor. Candidate
score is:

```text
seam_weight * min(nearest_passer_distance, aggression_reward_cap)
    * in_bounds_and_carry_confidence
    - distance_from_called_anchor
```

`aggression_reward_cap` interpolates from `0.7 m` to `1.8 m`. Targeted serves
use `SERVE_SEAM_WEIGHT = 0`, so they stay at the selected target point; Weak
Passer also suppresses seam movement.

**Disclaimers:**

- Uniform square sampling is not a radial error distribution. Corners are
  overrepresented relative to a Gaussian or circular target model.
- Placement affects target radius and also contributes directly to serve
  quality. It additionally controls the confidence used by aggressive seam
  search. This is another possible multi-count.
- Landing clamp means execution scatter itself cannot create an error. Error is
  decided independently before `_errant_serve_landing`; visual landing and
  verdict agree, but error direction does not emerge from the same distribution
  as successful placement.
- The passer scan uses default serve-receive formation positions, not necessarily
  every custom or transient position that the live reception resolver will use.
- The `Weak Passer` fallback on the opponent side remains a fixed coordinate
  when no home roster/lineup is supplied; confirm that current opponent roster
  plumbing covers every live path before trusting this tactical call.

### Pace, quality and errors

Usable pace is:

```text
usable_serve_pace = power_rating * lerp(0.52, 1.00, serve_technique)
```

Home serve quality is:

```text
clamp(
    usable_pace * 0.45
    + placement * 0.13
    + consistency * 0.14
    + style_proficiency * 0.13
    + effective_risk * 0.15
    + (team_serve_aggression - 0.5) * 0.14
    + mode_adjustment
    + uniform(-0.14, 0.14),
    0.05,
    0.98
)
```

Opponent quality uses a different legacy scale:

```text
clamp(
    (usable_pace * 0.41 + placement * 0.07 + consistency * 0.12
     + serve_aggression * 0.04 + style_proficiency * 0.08) / 0.72
    + mode_adjustment
    + uniform(-0.18, 0.18),
    0.05,
    0.98
)
```

`mode_adjustment` is `+0.06` aggressive or `-0.015` targeted.

Error chance is shared:

```text
control = consistency * 0.45 + technique * 0.30 + style * 0.25
demand = 0.42 + effective_risk * 0.58 * 0.60
               + serve_aggression * 0.58 * 0.40
error = clamp(0.52 * demand * (1 - control), 0.005, 0.45)
```

**Disclaimers:**

- Power determines the intended pace ceiling but the official serve-quality
  number is not metres per second. Geometric ballistics separately derive
  physical range and flight.
- Mass affects serve pace through `_power_rating`; the tooltip currently says
  Serve Power is the maximum pace without exposing that mass modifier.
- Home and opponent quality formulas remain asymmetric in weights and noise.
  Shared choice/error logic does not make serve execution fully symmetric.
- Aggression can affect mode, effective risk, home team identity, quality,
  error demand and seam search. This is intentional breadth, but its aggregate
  sensitivity has not been decomposed into independent contributions.

## Setter option calculation

The shared vocabulary in `_setter_option_terms` is:

```text
base_quality = attack_power * 0.44
             + attack_accuracy * 0.34
             + approach_timing * 0.22

judgment = decision_making * 0.42
         + court_vision * 0.33
         + composure * 0.25

lateness = max(travel_time - available_time, 0)
feasibility_cost = clamp(lateness / 0.80, 0, 1)
                 * lerp(0.28, 0.72, judgment)

height_control = (set_accuracy * 0.45
                + hand_control * 0.35
                + tempo_control * 0.20)
height_difficulty = rescue_height_m * lerp(0.11, 0.045, height_control)
perceived_height_cost = height_difficulty * lerp(0.35, 1.00, judgment)

read_penalty = 0.42 * lerp(
    1.00,
    0.32,
    set_disguise * 0.55 + unpredictability * 0.45
)

desperation = clamp(
    max(-team_flow, 0) * 0.62
    + max(-setter_match_confidence, 0) * 0.38,
    0,
    1
)
leadership_pull = desperation * hitter_leadership * 0.18

stable_misread = hash(seed, setter, hitter, lane) mapped to [-1, 1]
               * (1 - judgment) * 0.22

score = base_quality + set_quality * 0.10 + instruction_bias
      + leadership_pull + stable_misread
      - feasibility_cost - perceived_height_cost - read_penalty
```

`read_penalty` is zero unless that lane is currently anticipated.

**Disclaimers:**

- High judgment makes the setter perceive more of a real feasibility/height
  problem; it does not directly improve the hitter. That is deliberate, but the
  linear perception ramps are invented rather than observed.
- `height_control` is calculated from raw attributes divided by 100, not
  `_rating`, so fatigue, form and match confidence affect most option terms but
  not the setter's perceived control of extra height.
- `stable_misread` is deterministic pseudo-noise, not a model of a specific
  mistaken read. It depends on Godot's `hash` behavior and may not be portable
  across engine versions without verification.
- Hitter `match_confidence` is not in option quality. Only team flow and setter
  confidence drive desperation, and only hitter leadership receives the pull.
  This implements "find the leader under pressure," not the whole requested
  morale/momentum decision.
- Match flow is descriptive state that affects this decision, despite its model
  comment saying it is not a hidden ability bonus "by itself." This is an
  explicit decision weight, not an execution multiplier.
- Pressure is not currently scaled by score leverage, set number, timeout state
  or elimination context. A two-point negative flow early and late is treated
  the same.
- Base quality excludes tooling, finesse, shot variety, matchup and the actual
  formed block. Lane anticipation is only a coarse read penalty.

### Selection is not actually one identical path

The shared term dictionary does not imply shared selection behavior:

- A saved home play sorts option scores and takes the argmax. Its primary call
  receives `+0.20` instruction bias when the play is followed.
- Home fallback offense starts with a different `0.46 / 0.34 / 0.20` hitter
  score, adds quick/pipe terms, then selects with weight `score^6` and one shared
  RNG draw.
- Opponent offense takes an argmax after adding
  `uniform(-0.12, 0.12) * (1 - judgment)` per candidate.
- Opponent calls currently pass `lane_is_read = false`; home calls can price
  `opponent_anticipated_lane`.
- Tempo is mostly inherited from a saved assignment or derived from role/lane.
  The new model does not yet perform a unified joint hitter-and-tempo search.

This is likely the largest point Claude may contest. The design document says
"one function, both sides" and "which hitter and at what tempo." What shipped is
one explanatory vocabulary used inside three selection paths. Do not describe
it as full selection symmetry without resolving or intentionally documenting
these differences.

Available-time treatment also differs. Home saved/fallback evaluation uses the
provisional set flight. Opponent evaluation adds
`DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS` (`0.42 + 0.68`
seconds). This was added to remove a measured one-sided double charge, but it is
still an apparent formula asymmetry. Trace when each side's hitter transition
clock starts before making them textually identical; copying one number to the
other path could recreate `FAILURE_MODES.md` section 15's stale-timing defect.

## Rescue-set calculation

Extra height is inferred from time deficit:

```text
rescue_height_m = clamp(
    max(travel_time - ordinary_set_flight_time, 0) * 1.35,
    0,
    1.80
)
```

With `ENABLE_SET_HEIGHT_TIMING = true`, the set apex is:

```text
hitter_contact_height
+ clearance_by_tempo[0.15, 0.60, 1.30, 2.20]
+ touch/quality drift
+ rescue_height_m
```

`BallFlightModel.duration_for_apex` turns that apex into hang time. The rescue
height has three explicit prices:

1. Set quality subtracts `height_difficulty` through `_set_terms`.
2. Blocker cue clarity adds `clamp(rescue_height_m, 0, 1.8) * 0.075`.
3. Swing opportunity multiplies by
   `1 - clamp(rescue_height_m * 0.075, 0, 0.16)`.

Set quality itself is:

```text
capability = set_accuracy * 0.34 + hand_control * 0.22
           + tempo_control * 0.16 + ball_control * 0.15
           + composure * 0.13
usable_ball = pass_quality + (1 - pass_quality) * capability * 0.40
arrival = clamp(arrival_margin * 0.18, -0.42, 0.08)
quality = clamp(
    capability * (1 - 0.62 * (1 - usable_ball))
    - tempo_demand - capability_penalty - geometry_difficulty
    + arrival + familiarity_bonus,
    0,
    1
)
```

Height difficulty is added to geometry difficulty before this subtraction.
Execution error is then added with a spread governed by set accuracy and
composure.

**Disclaimers:**

- `1.35 metres per missing second`, the `1.80 m` cap and all three price slopes
  are tuned abstractions. They were selected for monotonic behavior and current
  balance, not derived from set trajectories or contact-angle data.
- The model can be circular: provisional ordinary flight estimates rescue
  height, rescue height changes actual flight, and the hitter may then have more
  time than the original deficit required. It does not iterate to a fixed point.
- Option choice predicts from a provisional contact and arc; actual delivery is
  recomputed later. This is intentionally an estimate available to the setter,
  but it also risks `FAILURE_MODES.md` sections 4 and 15 if downstream geometry
  changes without refreshing the decision inputs.
- The attack price treats every extra-high set as harder in the same linear way.
  It does not separately model steep descent, waiting timing, loss of approach
  rhythm or hitter-specific high-ball skill.
- The blocker receives a direct cue bonus before physical close. Verify the
  resulting read distribution rather than assuming "higher is more readable"
  reaches block outcomes after all downstream clamps.
- The set-height feature flag is currently on. The old comment claiming it was
  off was corrected in this change. Its own flag comment records the calibration
  that allowed it to open.

## Funnel and seal

The current floor-read adjustments are:

```text
funnel: +0.075
seal:   -0.030
touch:  +0.090
```

Funnel is interpreted as deliberately leaving a course for the assigned floor
defender. Seal is interpreted as prioritizing block contact while hiding the
hitter and final ball cue from defenders behind the wall. Existing block
outcomes already produce more partial contacts under seal and fewer deflections
under funnel; the previous gate asserted the inverse and was corrected.

**Disclaimers:**

- These are direct read adjustments, not visibility geometry. Every defender
  receives the same strategy constant regardless of whether the wall actually
  occludes their sightline.
- "Seal" and "funnel" also affect block contest bands elsewhere. The read bonus
  is not the complete strategy implementation.
- Tooling and feints are not explicitly interacted with seal in this change,
  despite the design rationale. Any claim that seal is now measurably more
  vulnerable to those skills requires a dedicated gate.
- The constants are small signed offsets against a larger dig model. Their live
  distribution and terminal outcome sensitivity should be printed before they
  are tuned, per failure modes 2 and 14.

## Attribute presentation

`ATTRIBUTE_TOOLTIPS` now covers every member of
`VolleyballPlayer.ABILITY_ATTRIBUTES`, and the test fails when a displayed raw
attribute lacks a description. `ball_control` is displayed as Touch Control and
is described as keeping receptions or defensive contacts playable.

Finesse and Shot Variety remain generated, displayed and calculated technical
attributes. Their removal was attempted and reverted because role
specialisation collapsed in seeded generation. The measured before/after values
and unresolved generator mechanism are in `docs/BACKLOG.md`, under "Removing
finesse and shot variety collapses role specialisation."

**Disclaimer:** retaining them is a regression-avoidance decision, not a final
taxonomy decision. The likely generation coupling has not been identified. Do
not derive them from mental attributes until the role-tier normalization is
instrumented and the specialization gates remain green.

## State and determinism

`VolleyballMatchState.serve_history` serializes the last official serve by
`<side>:<server id>`. `resolve_active_rally` receives a deep copy. Resolution
does not mutate match state; `record_rally` writes history and familiarity only
after an official result is accepted.

The setter stable misread and serve decision stream avoid adding conditional
draws to the shared RNG. Home fallback distribution and opponent option noise do
consume shared draws and therefore intentionally resequence downstream outcomes
relative to the base commit.

**Disclaimer:** deterministic for an identical build and state does not prove
cross-version replay stability. Both private seed derivation and stable setter
misread use Godot `hash`; save/replay compatibility should be tested before an
engine upgrade.

## Verification performed

- Headless foundation suite: `PASS: 1013 volleyball foundation checks`.
- `./tools/validate_ui_bindings.sh`: pass.
- `git diff --check`: pass before this documentation edit.
- `tools/run_setter_distribution.gd`: star set share rose monotonically as its
  quality bonus rose: `0.092`, `0.131`, `0.154`, `0.175` at `+0`, `+10`, `+20`,
  `+30`.

A temporary same-seed balance probe compared this working tree with the base
tree. It reported opponent swing quality improving from `0.332` to `0.345`, home
swing quality moving from `0.484` to `0.478`, and swing balance moving from
`0.766` to `0.792`. It also reported a remaining home/opponent floor-defense
split.

**Measurement disclaimer:** that comparison used an uncommitted temporary probe
script which was deleted. The numbers are directional evidence, not a
reproducible calibration artifact, and they do not meet this repository's own
handoff standard. Claude should rerun the committed
`tools/run_rally_balance_probe.gd` at the exact review commit and record sample
size, denominators, median and tails before accepting or rejecting balance.

The foundation suite exits zero but Godot still reports existing ObjectDB and
resource leak warnings at process exit. They were not investigated as part of
this change.

## Failure-mode audit requested from Claude

Use `docs/FAILURE_MODES.md` as the checklist. The most relevant challenges are:

1. **Sections 2 and 3:** print distributions for target familiarity, execution
   accuracy, rescue height, option-score gaps, blocker cue clarity and final dig
   read. Current tests mostly establish monotonicity, not population placement.
2. **Section 4:** audit provisional versus delivered set geometry and the three
   home/opponent option paths for duplicate sources of travel and available time.
3. **Section 5:** decompose aggregate sensitivity for consistency, technique,
   placement and aggression because each enters more than one serve stage.
4. **Sections 6 and 9:** use production rally paths and verify denominators. Do
   not infer live balance from isolated helper calls alone.
5. **Section 8:** check repeated preview, save/load and replay determinism,
   including consecutive official serves by the same server.
6. **Section 11:** ensure gates have headroom. The setter-displacement and serve
   tests currently prove direction, not a sport-level outcome band.
7. **Sections 14 and 15:** inspect `SET_DECISION`, `SET`, `ATTACK`, `BLOCK` and
   `DEFENSE` event metadata to prove each new value reaches the terminal consumer
   after actual target delivery and reachable-contact correction.
8. **Section 16:** bound any derived distance/time ratios introduced by rescue
   height and verify playback does not imply impossible movement.

The review should distinguish three conclusions: a code defect, a coefficient
that lacks calibration evidence, and a design disagreement. They require
different responses and should not be collapsed into "the model is wrong."
