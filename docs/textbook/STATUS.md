# Current Implementation Status

Last reviewed: 2026-07-30

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
  timestamp can be off by up to a second against the continuous one.

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
2. **`set_release_interval` and `defensive_depth` are derived but unconsumed.**
   Both are computed and then read by nothing.

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

Do not enable production contact flags, rewrite the whole scheduler, or mirror
home attack logic onto the opponent side as a substitute. The gate sequence and
its current status are in the
[Fresh-Agent Handoff](FRESH_AGENT_HANDOFF.md#the-one-current-next-objective).

## Validation baseline

The current foundation validation reports 416 passing checks (401 as of Gate
49, plus playback-sequencing and approach-run regression checks, block
visualization geometry checks, and five checks for Gate 50's continuous
reachability timeline). Treat that number as a point-in-time result, not a
permanent guarantee. Run [VALIDATION.md](VALIDATION.md) to establish the
current result.
