# Current Implementation Status

Last reviewed: 2026-07-30

This page is the quickest defense against confusing source-code existence with active gameplay behavior.

## Verified and active

- `scenes/application.tscn` is the configured main scene.
- `GameManager` and `CareerManager` are Autoloads configured in `project.godot`.
- Career creation, save/load, weekly advancement, training, transfers, fixtures, and match entry have implementations in `CareerManager`.
- `GameManager.resolve_active_rally()` calls `RallySimulator.resolve()`.
- `RallySimulator` currently computes the rally and returns a `RallyResult` containing ordered `RallyEvent` resources.
- The main match screen has 2D tactical playback code in `scenes/main/main.gd`.
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
  is diagnostic only; persistent projected movement is the next required gate.
- Gate 7 carries a copied receiver position and velocity between those reads.
  This restores most stationary-model reachability while leaving official
  rallies and live player state unchanged.
- Gate 8 schedules receive intents and explicit opportunity windows in a copied
  rally state. Windows can open, close after a correction, or remain available
  until ball arrival; none choose the official receiver yet.
- Gate 9 selects a shadow receiver from open windows and grades the perceived
  contact against ball truth. The controlled fixture validates safe and
  emergency choices but has not yet exercised quick-release passing.
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
  explicitly requested development fixture. Attack and later phases remain
  legacy-controlled.

## Partially implemented

The following classes exist and have tests, but do not yet drive live rally resolution:

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
- `PlayerObservation` beyond the setter slice

`SetterFailureClassifier`, `ReceptionRolloutAudit`, `SetterRolloutAudit`,
`LiveReceptionIntegrator`, and `LiveSetterIntegrator` are active at the
development rollout boundary. The normal match path still selects official
reception and setter behavior because both production flags are disabled.

Their purpose is to support a rally in which current position, velocity, ball flight, time, player intent, and availability continuously constrain future actions.

The ball-reading foundation now distinguishes authoritative flight facts from a
player-specific perceived destination and arrival time. Its current familiarity
input is a temporary normalized value; learned signature clusters and live-rally
integration have not been implemented.

## Paused

3D match playback code remains in the repository. It is not the current development priority. Do not use 3D behavior as the acceptance test for simulation changes unless that scope is explicitly resumed.

## Proposed next integration

Migrate one contact at a time. Opponent serve through home setter contact now
has a guarded development-only vertical slice. The next slice is set to attack:

1. Generate approach opportunities from persistent hitter state.
2. Give the hitter a player-specific observation of the set and defense.
3. Select an action from perceived information only.
4. Resolve the chosen contact against authoritative ball and player state.
5. Audit and compare fixed-seed behavior before adding a guarded rollout.

## Validation baseline

The current foundation validation reports 313 passing checks. Treat that number
as a point-in-time result, not a permanent guarantee. Run
[VALIDATION.md](VALIDATION.md) to establish the current result.
