# Current Implementation Status

Last reviewed: 2026-08-01

Fresh developers and coding models should begin with
[FRESH_AGENT_HANDOFF.md](FRESH_AGENT_HANDOFF.md). It is the authoritative
continuation contract; this page is the detailed implementation ledger.

This page is the quickest defense against confusing source-code existence with active gameplay behavior.

## Verified and active

- `scenes/application.tscn` is the configured main scene.
- `GameManager` and `CareerManager` are Autoloads configured in `project.godot`.
- Career creation, save/load, weekly advancement, training, transfers, fixtures, and match entry have implementations in `CareerManager`.
- `GameManager.resolve_active_rally()` calls `RallySimulator.resolve()`.
- `RallySimulator` currently computes the rally and returns a `RallyResult` containing ordered `RallyEvent` resources.
- The main match screen has 2D tactical playback code in `scenes/main/main.gd`.
- The match dashboard keeps the full current event visible and contains prior
  events and post-point analysis in independent scrollable regions.
- Serve-receive planner centers drive starting positions and claimant arrival
  geometry; reception events retain the responsible planner-zone evidence.
- The main-screen Visuals menu independently controls ball paths, player paths,
  tactical guides, coverage zones, and contact overlays on both 2D courts.
- Normal match playback clears shadow timing and contact-envelope diagnostics;
  the dedicated debug fixture must explicitly request them.
- Saved floor-defense geometry now produces an instruction-aware phase shape
  behind the resolved block and drives floor claimant arrival calculations.
- Attack events carry approach-start waypoints, and 2D playback stages hitters
  before animating their approach run to contact.
- The automated test runner currently contains checks for the persistent-state foundation.
- Opponent serves run a shadow reception comparison and attach it to
  `RallyResult.analysis["shadow_reception"]`; it cannot replace the official
  legacy claimant.
- Debug builds display shadow candidates, perceived targets, the true target,
  arrival margins, and agreement status on the 2D tactical court.
- Gate 1 timing diagnostics compare calculated contact speed with the legacy
  trajectory duration. They are shadow-only and do not rebalance live rallies.
- `tools/run_rally_calibration.gd` produces batch distributions for timing,
  perception, reachability, and claimant agreement.
- Controlled Gate 2 fixtures can evaluate every supported serve style with
  paired seeds and equalized style proficiency. Legacy and signature-implied
  timing remain shadow candidates rather than live rules.
- Gate 3 compares the existing independent contact speed with a speed derived
  from legacy duration. It measures perception and action-selection changes
  without changing official reception behavior.
- Gate 4 uses paired fixtures to compare weak, average, and elite readers in
  standard, compressed-middle, and split-deep serve-receive formations.
- Gate 5's temporary duration-derived-speed decision is historical and was
  superseded by Gate 20.
- Gate 6 records three deterministic observations during a serve and exposes
  the receiver's target-correction trail. Its stationary late-read reachability
  is diagnostic only; Gate 7 subsequently supplied persistent projected movement.
- Gate 7 carries a copied receiver position and velocity between those reads.
  This restores most stationary-model reachability while leaving official
  rallies and live player state unchanged.
- Gate 8 schedules receive intents and explicit opportunity windows in a copied
  rally state. Windows can open, close after a correction, or remain available
  until ball arrival; none choose the official receiver yet.
- Gate 9 selects a shadow receiver from open windows and grades the perceived
  contact against ball truth. The controlled fixture validates safe and
  emergency choices; Gate 10 subsequently exercised quick-release passing.
- Gate 10 verifies with paired fixtures that developing, established, and elite
  reception profiles receive progressively longer windows, more contact
  choices, and better outcomes. Elite profiles exercise quick-release passing.
- Gate 11 turns successful shadow contacts into calculated outgoing
  `BallFlight` candidates. A 600-serve fixture produced 265 candidates with
  100% contact-position, contact-time, destination, and speed-duration
  continuity. Official rally events remain unchanged.
- Gate 12 lets the setter prepare during the serve, read the pass three times,
  redirect movement, and receive emergency or controlled set options. The
  first timing model failed at 0% reachability; accepted calibration retains
  late setters as emergency contacts instead of hiding them.
- Gate 13 adapts the successful shadow pass and setter response into detached
  `RallyEvent` resources. All measured candidates satisfy the existing
  `outgoing_trajectory` contract; none enter the official event list.
- Gate 14 compares the completed shadow and official serve-to-set paths.
  Receiver ownership agrees 73.30%, setter ownership 96.83%, while pass targets
  differ by 1.117 m on average. These migration differences remain visible.
- Gate 15 adds a centralized disabled rollout boundary. Across 600 fixtures the
  flag remained off, official events were selected 100%, and event identity was
  preserved 100%. Its historical no-activation contract was superseded by Gate
  29; the default flag remains off and preserves the same official selection.
- Gate 20 makes calculated serve speed authoritative in shadow reception and
  derives flight duration from distance and speed. Legacy duration remains
  audit evidence. This exposed a low 14.19% outgoing-pass rate for later
  receiver-preparation calibration; it did not change official outcomes.
- Gate 21 audits retained ownership, setter-first-contact emergency intent, and
  forced late-setter handoffs. Every measured forced handoff selected a valid
  stronger candidate and recorded why ownership changed.
- Gate 22 holds the serve and pass fixed while varying setter attributes.
  Developing, established, and elite tiers show increasing confidence,
  reachability, controlled sets, quick sets, and available action count.
- Gate 23 decomposes receiver and setter reach into remaining time, target
  distance, movement capacity, contact reach, and directional-velocity error.
  Counterfactual tables are read-only; gameplay values remain unchanged.
- Gate 24 defines action- and body-state-specific horizontal and vertical
  contact envelopes.
- Gate 25 draws the selected setter's horizontal envelope, true contact
  displacement, and standing/jump height evidence in debug overlays. The
  values remain shadow-only and do not tune or replace official outcomes.
- Gate 26 classifies second-contact failures from measured timing, perception,
  movement, horizontal, vertical, takeoff, and body-state evidence.
- Gate 27 adds a pass-stability setting window and a narrow reaching posture.
  Setter progression remains monotonic without changing global movement speed.
- Gate 28 certifies reception candidates and names every fallback reason.
- Gate 29 implements the guarded selection branch while leaving the production
  feature flag disabled.
- Gate 30 promotes canonical serve timing and one reception contact only in an
  explicitly requested development fixture.
- Gate 31 defines a setter-scoped `PlayerObservation` that excludes
  authoritative flight and contact truth from decision inputs.
- Gate 32 removes authoritative arrival margin from setter ownership scoring;
  true opportunity data is now resolver and diagnostic evidence only.
- Gate 33 revalidates monotonic setter progression after the information-boundary
  change without adding universal movement or reach bonuses.
- Gate 34 audits setter ownership, observation purity, action feasibility,
  contact continuity, state immutability, and deterministic identity.
- Gate 35 adds a guarded setter rollout branch with its production flag off.
- Gate 36 promotes one audited setter contact after a promoted reception in an
  explicitly requested development fixture.
- Gate 37 generates legal hitter approach opportunities and action-specific
  attack jump envelopes from persistent state.
- Gate 38 lets setters rank perceived hitter windows and lets hitters target
  noisy observed defenders rather than exact coordinates or `DefensivePlan`.
- Gate 39 proves monotonic confidence, reachability, action count, and executable
  attack progression across developing, established, and elite hitters.
- Gate 40 audits attack legality, information boundaries, physical execution,
  trajectory continuity, state immutability, and deterministic identity.
- Gate 41 adds a guarded attack rollout branch with its production flag off.
- Gate 42 promotes one audited attack after promoted reception and setter
  contacts in an explicitly requested development fixture. Blocking and later
  phases remain legacy-controlled.
- Gate 43 makes transition preparation causal in normal home attack resolution.
  Perceived responsibility and tactical duties set release time; the resulting
  runway changes approach speed, lateral control, usable jump height, attack
  quality, and the actions physically available at third contact.
- Gate 44 gives every opponent front-row blocker an independent, decision-safe
  observation of the shadow attack (perceived setter cues, a progressive set
  read, a degraded hitter-approach cue, known rotation, and the called block
  strategy) and a commitment chosen from that perception alone. It never
  promotes into the official `BLOCK` event; it is evaluated as shadow evidence
  alongside `shadow_attack` on every rally.
- Gate 45 adds a coordination pass. Blockers observe teammates' visible body
  cues -- the direction a teammate appears to drive and whether they look
  committed -- and may join a closing zone owner, step up to an uncovered zone,
  leave a zone the ball is not coming to, re-engage when nobody committed, or
  decline a crowded seam. Primary and assist are resolved from those
  coordinated commitments; Gate 44 had ranked them by nearness to the
  authoritative contact, which scored a guess rather than describing a block.
  `block_engagement_distance` is consumed here as the commitment threshold's
  system-fit easing.
- Gate 46 calibrates blocker outcomes across three reading tiers and four set
  difficulties: misread rate, hesitation rate, and solo-versus-coordinated
  closes, with coverage flags asserting the sweep actually contains each
  outcome it rates.
- Gate 47 turns the block audit into a promotion boundary: teammate-cue
  privacy, movement feasibility, contact-envelope reach including takeoff time
  and height, role consistency, plus an extractable candidate and deterministic
  fingerprint.
- Gate 48 adds the guarded block selection boundary with its production flag
  off. `RallyRolloutPolicy.select_block_source()` takes the shadow summary and
  the *opponent* lineup, calls `BlockRolloutAudit.evaluate()`, and records the
  verdict under `shadow_summary["block_rollout"]` with the candidate erased.
  Unlike the three earlier selectors it reports `activation_implemented` false
  and can never select a candidate even with the flag forced on, because no
  block integrator exists yet. Official block events are byte-identical across
  fixed seeds.
- Gate 49 promotes one audited block contact in an explicitly requested
  development fixture, closing the block slice. `LiveBlockIntegrator` applies
  the touch, blocker body states, and outgoing deflection; promotion requires a
  promoted attack ahead of it, since the shadow block reads the shadow attack.
  A block touch does not consume one of the blocking team's three contacts, and
  a promoted block cannot miss because the audit certified reach first.
  Coverage and everything after remain the legacy continuation.
- Gate 50 schedules `RallyMoment.Kind.MOVEMENT_UPDATE` for the first time,
  inside `RallyOpportunitySystem.evaluate_reception_timeline()`, and
  continuously samples reachability across each inter-read gap via the
  already-proven `ShadowMovementSystem` stepper. It is shadow-only: the
  function's existing discrete windows are unmodified, and the comparison is
  purely additive evidence. The two models never disagree on whether a
  receiver is ever reachable, but the discrete read-only model's window-open
  timestamp is off by up to about 0.22s against the continuous one.
- Gate 51 carries that continuous read onto the 2D court as a toggleable
  shadow overlay layer, so the sampled traversal can be looked at beside the
  discrete windows rather than only measured. Drawing it immediately exposed
  two defects in Gate 50 (a receive commitment that zeroed its own available
  time, and an authoritative rather than perceived deadline); both are fixed
  and Gate 50's published numbers were corrected.
- `VolleyballPlayerGenerator` builds **per-attribute ceilings**, not one scalar.
  Each attribute's ceiling is the player's general talent shifted by role tier,
  region specialty, and an innate deviation that is usually small and
  occasionally extreme (6% standout, 6% deficiency, magnitude 14-30). That last
  term is what allows a teenager with a freakish leap and nothing else, or a
  veteran with one glaring hole. Measured: 5.5% of attribute slots sit more than
  22 points above the player's own mean and 3.9% more than 22 below.
- **`potential` is derived from those ceilings**, not rolled and then
  approximated. It is the ability score the player would display with every
  attribute at its ceiling, computed with the same weighting
  `current_ability_score()` uses -- so current ability is the same function of
  strictly smaller numbers and cannot exceed it. The bound is exact by
  construction; the `_ability_score_offset()` correction this replaces is gone.
  Measured over 1,320 generated players: zero exceed their potential.
- **Age produces a differently-shaped player, not a better or worse one.** Power
  and turnover peak at `PHYSICAL_PEAK_AGE` (24) and fade afterwards, while
  reading keeps improving for as long as a player keeps playing. Mean physical
  rating runs 64.7 at 16, peaks near 69.7 at 19-20, and falls to 55.5 by 30;
  mean mental runs 42.3 at 16 to 66.4 at 31, **crossing over at 29**. A gifted
  teenager and a settled veteran are therefore both worth picking, which is what
  the academy premise requires.
- The same `_attribute_reserve()` covers two different causes and says so: for a
  young player the gap to their ceiling is undevelopment, for an old player in a
  physical attribute it is decline.
- Role tiers create observable specialisation: setters have markedly higher
  `set_accuracy` than liberos, and liberos markedly higher `reception` than
  `set_accuracy`. The primary tier is read from
  `VolleyballPlayer.POSITION_WEIGHTS` rather than restated in the generator, so
  generation and `current_ability_score()` cannot disagree about what a role is
  for; only the secondary tier is generator-specific.
- Region specialty lists give each of the four regions a +8 bonus on five
  thematically consistent attributes (Pāwa Hitō: attack/block; Spëddigh: floor
  defence and lateral speed; Bloc du Larg: blocking, ball control, and mental
  discipline; Landavol: mental and setting). Region physique biases shift
  height, mass, and wingspan before individual variation so Pāwa Hitō rosters
  are measurably taller than Landavol rosters.
- `stride_length_m` is recalculated from the player's actual post-variation
  height, eliminating the stale-stride defect the locomotion calibration had
  recorded (`stale_stride_rate` is now 0.0).
- **Attacks are aimed at the open floor, not at a table.**
  `_choose_home_attack_target()` scanned five hardcoded coordinates, so every
  attack in the game landed on one of five spots regardless of where the defence
  stood. The floor is now scanned continuously, scored by distance to the
  nearest actual defender, how well the depth suits the shot family, and how far
  the hitter must swing off their approach line; the winner is then displaced by
  an aiming error that shrinks with `attack_accuracy`. Measured over 342 home
  attacks: 306 distinct landing points across 8 of 24 court cells.
- **Only a block that touches the ball shortens or deflects the shot.** All
  three block sites re-sliced the attack's flight to end at the net
  unconditionally. Because a hitter contacts the ball about 3% of the court from
  the net, the spike was drawn barely moving and the rest of the distance
  arrived as a "deflection" -- which read as the ball teleporting onto whoever
  dug it. An untouched ball now keeps its full arc and the block emits no
  deflection leg, where previously two overlapping paths described the same
  ball. Playback also no longer fabricates trajectories: it had been rebuilding
  the attack's first leg itself, producing a path with no timing on it. Measured
  over ~300 attack-to-block pairs: zero chain breaks.
- **The opponent setter releases onto clear floor.** Their serve-receive release
  was the hardcoded court centre `(0.50, 0.34)`, which put the setter marker
  inside whoever covered the middle and had them setting from a spot no setter
  takes. They now use `CourtConstants.setter_serve_receive_position()` mirrored
  -- the same function the home side uses -- so the release tracks the rotation.
- **2D playback shows height and hand posture.** A top-down court has no
  natural way to express elevation, which is why spikes and blocks read as flat
  slides. `TacticalCourt._draw_player_body()` separates the floor shadow from
  the marker: the shadow stays down and spreads while the marker lifts and grows,
  and that separation is what reads as height. Elevation comes from the resolved
  event and is never invented by the view -- a hitter's `jump_multiplier`, so a
  poor run-up visibly converts to less height; both blockers on a block; and the
  setter's own `reach_state` for a jump set, including the straining posture for
  a ball past their reach. Two small marks orbit the marker toward the contact
  being made, so a swing and a dig are distinguishable at this zoom. Both sides
  draw through the one helper. The lift spans the ball flight *preceding* the
  contact as well as the contact itself, because reading only `playback_event`
  showed it for the contact event alone -- which barely registered even at half
  speed, since during a ball flight `playback_event` is the ball's event rather
  than the upcoming contact.
- **A double block is drawn as a wall.** `RallySimulator._block_wall_positions()`
  records where the two blockers actually stand -- pressed to the net on their
  own side, the assist closing inward from centre -- on every block event.
  Playback had been reading each blocker's individual defensive position, which
  for a block resolves both onto the attack lane and drew them stacked on one
  another. Measured over 245 block events (116 doubles): none stacked.
- The planning court now receives the opponent team. Without it `show_opponents`
  stayed false, so no opponent markers were drawn and the block rectangle had
  nothing to anchor to.
- **Opponent hitters now have a causal approach (Gate 43 mirrored).**
  `_resolve_opponent_transition()` builds an opponent-side rally state, runs
  `ApproachMechanicsSystem.prepare_for_attack(..., &"opponent")`, and feeds the
  resulting run-up into attack quality, the swing's launch arc, and the attack
  families physically available. Two things had depended on its absence: the
  shadow block (Gates 44-49) read a hitter-approach cue with almost nothing
  behind it on the opponent side, and 2D playback had no staged run-up to draw,
  which is why opponent spikes were unreadable. The opponent SET event now
  stamps `staged_next_actor_id`/`staged_next_position`, so playback walks the
  hitter to their mark during the set instead of teleporting them into a swing.
  Measured over 80 opponent attacks: every one carries a resolved approach and a
  non-empty attack-family list, and every preceding set stages the hitter.
- **Approach orientation is explicit rather than inherited.**
  `approach_start_position()` takes a side, because a hitter approaches the net
  from behind it and "behind" is +y for home and -y for the opponent; the home
  offset would have placed an opponent's mark across the net in home territory.
  `prepare_for_attack()` also gates the `home_plan` duty lookup on side. That
  lookup is keyed by player id and contains only home players, so it worked for
  opponents purely because the two id ranges (1-8 and 101-107) happen not to
  overlap -- an assumption nothing enforced.
- **Setter attributes decide how an action turns out, not whether it is
  allowed.** `SetterCapabilitySystem` is consulted on every official second
  contact and its read is attached to the SET event. Nothing is filtered away:
  a setter may attempt a tempo beyond their command or reach for a ball above
  their jump, and the penalty scales with how far outside they went. A first
  implementation removed uncommandable tempos from the option list; that turns a
  limit into a rule and takes the decision away from the player. Three families:
  - *Technical command over tempo.* A fast set demands more command
    (`tempo_control`/`hand_control`/`composure`) than a slow one, and a poor
    pass raises the demand further. Attempting past command costs quality in
    proportion to the shortfall.
  - *Judgment.* `decision_making`/`tactical_discipline`/`composure` decide
    whether the setter recognises an overreach and takes the safer ball. A
    disciplined setter with weak hands backs off to a tempo they can run; a
    reckless one with the same hands tries the quick set and produces a poor
    ball. Both are legitimate and the record shows which happened.
  - *Pass recovery.* Command buys back part of what a bad pass costs, so skill
    matters most exactly when the pass is worst: the elite-to-weak gap in
    effective pass quality runs 0.000 off a perfect pass and 0.218 off a 0.15
    pass.
- **Reach is derived from three independent things**, combined in exactly one
  place, `VolleyballPlayer.jumping_reach_cm()`: standing height, arm length, and
  leap. The `jump_reach` attribute is leap capacity despite its name, which is
  retained only because saves carry it. A 182 cm player with a real jump
  out-reaches a 200 cm player who cannot get off the floor.
- **Reach is not fixed per action.** How much run-up a player could afford
  changes how much of their leap is available, so a setter who arrives early
  takes a short approach into a jump set and buys the height a sailing pass
  demands, while one still scrambling takes it flat-footed and loses the same
  ball. Arrival margin supplies that approach quality; for the same 200 cm
  setter the ceiling runs 2.64 m flat-footed to 2.86 m loaded.
- **The tempo gate is live but rarely exercised in ordinary play**: the default
  offence calls only T3, which every setter can command. It takes effect as soon
  as a called play asks for a quick set.
- **Ground speed is now stride x cadence, not a lookup curve.**
  `RallyMovementSystem.movement_profile()` -- the single chokepoint every
  reachability, arrival-margin, traversal, and playback decision reads -- derives
  top speed from how far a step carries this player in this mode and how often
  they take one. The retired `lerpf(1.35, 5.25, rating)` curve spanned a 3.89x
  ratio from worst mover to best, which no pair of human factors can produce
  (turnover spans about 1.8x), and its floor described a professional walking at
  1.35 m/s. Both stride and cadence carry per-mode tables, because a defensive
  shuffle is short steps at high frequency and a transition run is long steps at
  moderate frequency; giving cadence that second dimension is what made the
  decomposition fit at all.
- This was a deliberate **rebalance**, not a refactor: lateral -24.0%,
  transition +42.7%, approach +2.8%, block close -19.3%. Defenders cover roughly
  a quarter less ground sideways while transition running is roughly 40% faster,
  so the gate record's absolute reachability numbers are re-baselined. Every
  implied stride now lands inside the range humans use for that movement, where
  the lateral mode previously satisfied it only 35% of the time.
- The rating span collapsed from 3.89x to about 1.67x, so **raw speed is no
  longer where player differentiation lives**. Differentiation has to come from
  reach, timing, and which actions a player's attributes make available.
- Long limbs cost turnover (`LocomotionModel.limb_turnover_factor()`), which is
  what keeps archetypes apart. Without it, stride multiplies into every mode and
  the tallest player is fastest everywhere including sideways, which erases the
  libero. With it, at identical ratings a 181 cm build is 12% quicker laterally
  while a 208 cm build is faster in a straight line. Turn cost also scales with
  cadence -- previously pure geometry, so a libero reversed exactly as slowly as
  a middle blocker. See
  [Locomotion](../design/LOCOMOTION_AND_GENERATION.md).

## Partially implemented

The following classes exist and have tests but are not yet one universal,
production-authoritative rally loop. Some already contribute to shadow,
development, or bounded normal-match slices as described above:

- `RallyState`
- `RallyPlayerState`
- `RallyBallState`
- `RallyMoment`
- `ActionOpportunity`
- `ActionOpportunityWindow`
- `RallyDecision`
- `RallyStateBuilder`
- `RallyScheduler`
- `RallyMovementSystem`
- `ApproachMechanicsSystem` beyond the current home-attack slice
- `RallyOpportunitySystem`
- `RallyContactSystem`
- `ShadowSetterResponseSystem`
- `RallyPlaybackAdapter`
- `RallyShadowComparison`
- `RallyFeatureFlags`
- `RallyRolloutPolicy`
- `RallyDecisionSystem`
- `BallContactSignature`
- `BallFlight`
- `BallFlightEstimate`
- `BallReadSystem`
- `RallyTrace`
- `ShadowReceptionSystem`
- `RallyKinematics`
- `RallyCalibrationReport`
- `ServeStyleCalibration`
- `PlayerObservation` beyond reception, setter, and attack slices

`ReceptionRolloutAudit`, `SetterRolloutAudit`, `AttackRolloutAudit`,
`LiveReceptionIntegrator`, `LiveSetterIntegrator`, and `LiveAttackIntegrator`
are active at the development rollout boundary. The normal match path still
selects official reception, setter, and attack behavior because all three
production flags are disabled.

Their purpose is to support a rally in which current position, velocity, ball flight, time, player intent, and availability continuously constrain future actions.

The ball-reading foundation now distinguishes authoritative flight facts from a
player-specific perceived destination and arrival time. Its current familiarity
input is a temporary normalized value; learned signature clusters and live-rally
integration have not been implemented.

## Paused

3D match playback code remains in the repository. It is not the current development priority. Do not use 3D behavior as the acceptance test for simulation changes unless that scope is explicitly resumed.

## Proposed next integration

Migrate one contact at a time. Opponent serve through home block now has a
guarded development-only vertical slice, and the whole block slice is complete
(Gates 44 through 49): observation, coordination, calibration, candidate audit,
production-off rollout policy, and a development-only promoted contact. Gate 50
opened a new slice -- continuous, resolver-integrated movement -- and is
shadow-only on reception's reachability windows; no rollout, audit, flag, or
promotion exists yet for it.

Two structural gaps are the strongest candidates for the next slice, and both
now limit the block work that was just completed:

1. **The opponent attack path never calls `ApproachMechanicsSystem`.** Home
   hitters have a causal approach (Gate 43); opponent hitters do not. The
   shadow block therefore reads a hitter-approach cue with less behind it than
   the home side would give it. Mirroring Gate 43 onto the opponent attack
   would make that cue real.
2. **`set_release_interval` is now consumed.** The main home set path and the
   continuation set path both query the setter's `SYSTEM_FIT_SET_RELEASE`
   profile through `RallySimulator._release_interval()` and advance the rally
   clock by `second_contact_window + release_interval`, widening the hitter's
   approach window by the setter's handling time. Both halves of the profile
   are used: `ideal_value` is the setter's natural rhythm and `tolerance` is
   how far off it they can work, so a clean ball goes out at the fast edge of
   their band and a mishandled one at the slow edge. The spread is therefore
   the player's, not a tuned constant. `defensive_depth` is also consumed -- it
   adjusts `defense_quality` and floor-defense positioning in
   `rally_simulator.gd`; the stale "read by nothing" claim was an error.

   Wiring this exposed a timing defect in the defence-to-counterattack
   continuation, which had never advanced its rally clock: every contact there
   carried the dig's timestamp, so the transition attack began at the same
   instant as the set that fed it. Adding a release interval to the set alone
   then pushed the set to start *after* its own attack. The continuation now
   advances the clock the way the main path does -- set contact, set flight,
   attack -- and the two trajectories meet at exactly one contact time.

Separately, movement fluidity's playback slice (steps 1 through 3) is
complete outside the gate sequence. `ShadowMovementSystem` integrates movement
at a fixed step, `MovementIntegrationCalibration` proves that stepping
reproduces `RallyMovementSystem.project_toward()` exactly at 15, 30, and 60 Hz,
and `TacticalCourt` now samples that traversal instead of interpolating
between endpoints. Three view-layer inventions are gone: the fixed `0.46`
waypoint share, the straight-line lerp, and the tween's `EASE_IN_OUT`, which
had been warping every phase -- including the ball -- with a curve nothing in
the simulation chose. No rally outcome changes. Step 4, in which movement
becomes resolver-owned and authoritative for reachability, is the one that
moves seeds -- Gate 50 is its first, shadow-only slice (reception reachability
only; no rollout, audit, flag, or promotion). See
[Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md) and
[Gate 50](../calibration/GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md).

Separately, serve, set, and attack flight duration and apex height are no
longer hardcoded tables. `RallyKinematics.solve_launch_arc()` derives both
from real court distance and a launch angle (shot shape/tempo intent) via
standard projectile motion; the launch angle is the only free input, and
speed/duration/apex are always outputs. This is the first change in the
project's session history to alter the official `RallySimulator.resolve()`
path on purpose. See
[Force-Derived Ball Flight Timing](../design/BALL_LAUNCH_KINEMATICS.md).

Do not enable production contact flags, rewrite the whole scheduler, or mirror
home attack logic onto the opponent side as a substitute. The gate sequence and
its current status are in the
[Fresh-Agent Handoff](FRESH_AGENT_HANDOFF.md#the-one-current-next-objective).

## Validation baseline

The current foundation validation reports 471 passing checks (424 as of Gate
51, plus four for `set_release_interval` consumption, four for attribute-first
generation, six added when reviewing that work, and seven for stride-and-cadence
locomotion: speed being a genuine product with distinct per-mode ranges, an
athletic floor and a humanly possible rating span, a taller player running
faster, a shorter one keeping the lateral edge, long limbs costing more turnover
in footwork than in a run, turnover shortening a reversal, and
`estimate_movement()` agreeing with `movement_profile()`). Treat
that number as a point-in-time result, not a permanent guarantee. Run
[VALIDATION.md](VALIDATION.md) to establish the current result.
