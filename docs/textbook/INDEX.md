# Search Index

Use editor search (`Cmd+Shift+F` or `Ctrl+Shift+F`) on this file. Entries include ordinary language, code symbols, and common error phrases.

## Questions

| Search phrase | Read |
|---|---|
| I am a fresh coding model or developer; where do I start? | [Fresh-Agent Handoff](FRESH_AGENT_HANDOFF.md) |
| What is this game? | [P1-C1](part_01_project/01_what_you_are_building.md) |
| Where does the game start? | [P1-C2](part_01_project/02_godot_project_and_runtime.md) |
| Where should a new file go? | [P1-C3](part_01_project/03_repository_map.md) |
| What happens when I click Resolve Rally? | [P1-C4](part_01_project/04_following_a_user_action.md) |
| What is `class_name`? | [P2-C1](part_02_gdscript/01_gdscript_basics.md) |
| Resource versus Node | [P2-C2](part_02_gdscript/02_resources_nodes_and_signals.md) |
| Array, Dictionary, Variant, typing | [P2-C3](part_02_gdscript/03_collections_types_and_null.md) |
| How do I make a safe change? | [P3-C1](part_03_workflow/01_safe_change_workflow.md) |
| How do I debug or test? | [P3-C2](part_03_workflow/02_debugging_testing_and_git.md) |
| How does the current rally simulator work? | [P4-C1](part_04_match_engine/01_current_rally_pipeline.md) |
| What is the proposed persistent simulation? | [P4-C2](part_04_match_engine/02_persistent_rally_state.md) |
| How do ball time and movement interact? | [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| How should tactics, information, and growth connect? | [P4-C4](part_04_match_engine/04_tactics_information_and_progression.md) |
| How do I adjust playback, planner geometry, or visualizers? | [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| How do I implement a new tactical or rally system? | [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| How do careers, rosters, and training work? | [P5-C1](part_05_management/01_career_roster_and_training.md) |
| What are development projects and latent-role projections? | [P5-C2](part_05_management/02_development_to_match_options.md) |
| What should I build next? | [Fresh-Agent Handoff](FRESH_AGENT_HANDOFF.md#the-one-current-next-objective) |
| How does continuous movement fit the information boundary and opportunity windows? | [Gate 50](../calibration/GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md) |
| How do I see continuous movement on the court and tune against it? | [Gate 51](../calibration/GATE_51_OBSERVABLE_CONTINUOUS_MOVEMENT.md) |
| Why does a serve/set/attack take the time it does? | [Force-Derived Ball Flight Timing](../design/BALL_LAUNCH_KINEMATICS.md) |
| What is historical practice rather than current roadmap work? | [P6-C2](part_06_exercises/02_beginner_project_ladder.md) |
| How is a voli's body built, and how do I change one? | [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| How do I add a kit for a region? | [P7-C2](part_07_art_and_assets/02_kits_colour_and_marks.md) |
| Why is my kit failing the contrast check? | [P7-C2](part_07_art_and_assets/02_kits_colour_and_marks.md) |
| How do I add a venue, and where may geometry stand? | [P7-C3](part_07_art_and_assets/03_the_court_and_venue.md) |
| How big is the court, and which axis is which? | [P7-C3](part_07_art_and_assets/03_the_court_and_venue.md) |
| How do faces and expressions work? | [P7-C4](part_07_art_and_assets/04_faces_and_expressions.md) |
| How do I render, probe, or prove a visual change? | [P7-C5](part_07_art_and_assets/05_rendering_probes_and_validation.md) |
| Where do rendered PNGs go? | [P7-C5](part_07_art_and_assets/05_rendering_probes_and_validation.md) |

## Symbols

| Symbol | Meaning and chapter |
|---|---|
| `GameManager.resolve_active_rally` | Entry into live rally resolution; [P1-C4](part_01_project/04_following_a_user_action.md) |
| `RallySimulator.resolve` | Current whole-rally resolver; [P4-C1](part_04_match_engine/01_current_rally_pipeline.md) |
| `RallyFeatureFlags` | Production-off and explicit development rollout switches; [Fresh-Agent Handoff](FRESH_AGENT_HANDOFF.md#what-is-authoritative-today) |
| `RallyEvent` | Playback record of an action; [P4-C1](part_04_match_engine/01_current_rally_pipeline.md) |
| `RallyResult` | Completed rally result; [P4-C1](part_04_match_engine/01_current_rally_pipeline.md) |
| `RallyState` | Persistent rally snapshot foundation; [P4-C2](part_04_match_engine/02_persistent_rally_state.md) |
| `RallyPlayerState` | One player's location, velocity, intent, and availability; [P4-C2](part_04_match_engine/02_persistent_rally_state.md) |
| `RallyBallState` | Ball flight and ownership state; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `BallContactSignature` | Calculated speed, angles, signed spin, and stability; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `BallFlight` | Authoritative destination and arrival time; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `BallFlightEstimate` | One player's perceived destination and timing; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `BallReadSystem` | Deterministic conversion from flight truth to player perception; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `ShadowReceptionSystem` | Non-authoritative comparison of persistent and legacy reception ownership; [P4-C5](part_04_match_engine/05_migration_and_visible_proof.md) |
| `RallyTrace` | Structured diagnostic evidence that does not determine outcomes; [P4-C5](part_04_match_engine/05_migration_and_visible_proof.md) |
| `RallyMoment` | Scheduled future simulation moment; [P4-C2](part_04_match_engine/02_persistent_rally_state.md) |
| `ActionOpportunity` | A possible action with timing and feasibility; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `ActionOpportunityWindow` | The interval during which a projected action remains available; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `RallyMovementSystem` | Movement estimates and reception opportunities; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `ApproachMechanicsSystem` | Responsibility release, approach staging, takeoff physics, and attack availability; [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| `ShadowBlockSystem` | Gate 44 attack-to-block observation: per-blocker decision-safe hypotheses and commitments, resolved against truth only afterward; [Gate 44](../calibration/GATE_44_SHADOW_BLOCK_HYPOTHESES.md) |
| `ShadowBlockSystem._coordinate_blocker` | Gate 45 coordination pass: revising a commitment from teammates' visible body cues; [Gate 45](../calibration/GATE_45_BLOCK_COORDINATION.md) |
| `BlockerProgressionCalibration` | Gate 46 reading-tier sweep over set difficulties: misread, hesitation, and coordinated-close rates; [Gate 46](../calibration/GATE_46_BLOCKER_CALIBRATION.md) |
| `BlockRolloutAudit` | Gate 47 block promotion boundary: information purity, teammate-cue privacy, movement, contact envelope, role consistency; [Gate 47](../calibration/GATE_47_BLOCK_CANDIDATE_AUDIT.md) |
| `RallyRolloutPolicy.select_block_source` | Gate 48 guarded block selection boundary; production flag off; [Gate 48](../calibration/GATE_48_BLOCK_ROLLOUT_POLICY.md) |
| `LiveBlockIntegrator` | Gate 49 development-only promoted block contact and deflection flight; a block touch consumes no contact; [Gate 49](../calibration/GATE_49_DEVELOPMENT_LIVE_BLOCK.md) |
| `ShadowMovementSystem` | Fixed-step movement integration producing sampled traversals; consumed by 2D playback; [Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md) |
| `TacticalCourt._build_movement_paths` | Builds each player's phase traversal from the movement model so playback samples rather than interpolates; [Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md) |
| `MovementIntegrationCalibration` | Proves stepped integration reproduces `project_toward` exactly, and that the sweep can fail; [Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md) |
| `RallyMovementSystem.traversal_seconds` | Closed-form inverse of `project_toward`; the single answer to how long a traversal takes; [Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md) |
| `RallyKinematics.solve_launch_arc` | Derives serve/set/attack flight duration and apex height from real distance and a launch angle via projectile motion; the launch angle is the only free input; [Force-Derived Ball Flight Timing](../design/BALL_LAUNCH_KINEMATICS.md) |
| `_set_launch_angle_degrees` / `_serve_launch_angle_degrees` / `_attack_launch_angle_degrees` | Map tempo/style/attack-type to a shot-shape angle range, shifted by rating and jittered by quality; [Force-Derived Ball Flight Timing](../design/BALL_LAUNCH_KINEMATICS.md) |
| `RallyMovementSystem.movement_profile` | Public rating-driven speed, acceleration, and turn-delay profile, shared by the stepper; the single source every movement decision reads; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `LocomotionModel.stride_factor` | Physique term in top speed: longer legs cover more ground per step, so height stops being a pure movement penalty; centred on 1.0 so the population mean is unchanged; [Locomotion](../design/LOCOMOTION_AND_GENERATION.md) |
| `LocomotionModel.direction_change_seconds` | Turn cost scaled by cadence -- turnover is the frequency at which a player can change where they are going; [Locomotion](../design/LOCOMOTION_AND_GENERATION.md) |
| `RallyOpportunitySystem` | Shadow scheduling of receive-window opening and closure; now also schedules `RallyMoment.Kind.MOVEMENT_UPDATE` per Gate 50; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md); [Gate 50](../calibration/GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md) |
| `RallyMoment.Kind.MOVEMENT_UPDATE` | Continuous reachability sampling across an inter-read gap, shadow-only; [Gate 50](../calibration/GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md) |
| `ContinuousReachabilityCalibration` | Measures discrete-vs-continuous reachability timing disagreement across seeded fixtures; [Gate 50](../calibration/GATE_50_CONTINUOUS_REACHABILITY_TIMELINE.md) |
| `TacticalCourt._draw_continuous_reachability` | Draws the continuously sampled traversal, coloured by reachability, beside the discrete windows; [Gate 51](../calibration/GATE_51_OBSERVABLE_CONTINUOUS_MOVEMENT.md) |
| `SHADOW_LAYER_CONTINUOUS` | Shadow overlay toggle for the continuous reachability trail; [Gate 51](../calibration/GATE_51_OBSERVABLE_CONTINUOUS_MOVEMENT.md) |
| `RallyDecision` | Structured evidence for one selected shadow action; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `RallyDecisionSystem` | Comparison of open receiver choices and grading against ball truth; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `CoverageCalculator` | Arrival and claimant calculations; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `TacticalCourt.set_visualization_layers` | Shared court-overlay visibility mask; [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| `BodyTypeModels.silhouette` | Builds one voli's complete body spec from type, id and choices; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| `BodyTypeModels.build_mesh` | Dispatches a spec `Dictionary` to a mesh primitive; an unknown `shape` silently yields a capsule; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| `BodyTypeModels.produce_for` | Deterministic produce from player id; never consumes generation RNG; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| `BodyTypeGameplay.BODY_TYPES` | The six morphologies the simulation can read; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| `PlayerActor3D.configure` | Entry point that dresses and builds one voli from a `physical_profile`; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| `RegionalKits.kit_for` | The home strip for a region; presentation data, deliberately off `regions.gd`; [P7-C2](part_07_art_and_assets/02_kits_colour_and_marks.md) |
| `RegionalKits.BUILD` | Shirt construction per region — what survives grayscale; [P7-C2](part_07_art_and_assets/02_kits_colour_and_marks.md) |
| `MatchCourt3D.CAMERA_PRESETS` | Broadcast, end line and high tactical, all inside the tightest venue's envelope; [P7-C3](part_07_art_and_assets/03_the_court_and_venue.md) |
| `FREE_ZONE_SIDE` / `FREE_ZONE_END` | Where a building may start: 9.5 m and 17.0 m from centre; [P7-C3](part_07_art_and_assets/03_the_court_and_venue.md) |
| `FaceExpressions.GRID` | Eye state x mouth shape -> expression name; the single source of which faces exist; [P7-C4](part_07_art_and_assets/04_faces_and_expressions.md) |
| `CogniticonMotion` | Pure-function mark motion in real seconds; no node, no state, no frame delta; [P7-C4](part_07_art_and_assets/04_faces_and_expressions.md) |
| `CareerManager` | Stateful career lifecycle; [P5-C1](part_05_management/01_career_roster_and_training.md) |
| `VolleyballTrainingSystem` | Weekly player changes; [P5-C1](part_05_management/01_career_roster_and_training.md) |

## Common errors

| Error or symptom | First check |
|---|---|
| `Parser Error` | [P2-C3](part_02_gdscript/03_collections_types_and_null.md), then run the editor scan in [VALIDATION.md](VALIDATION.md) |
| `Invalid get index` | Confirm the Dictionary key or Resource property exists; [P2-C3](part_02_gdscript/03_collections_types_and_null.md) |
| `Attempt to call function on a null instance` | Trace where the player, lineup, or plan can be null; [P2-C3](part_02_gdscript/03_collections_types_and_null.md) |
| Ball teleports or starts at the wrong point | Inspect `outgoing_trajectory` and event continuity; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| Player appears to reset unexpectedly | Compare simulator state with playback-only position resets; [P4-C1](part_04_match_engine/01_current_rally_pipeline.md) |
| Long rally text moves or enlarges the dashboard | Keep history and analysis in non-fitting scrollable `RichTextLabel` nodes; [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| Planner marker moves but the rally does not change | Trace the model value into a seeded event decision; [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
| New persistent code does not change a live rally | It is not wired into `RallySimulator.resolve`; [STATUS.md](STATUS.md) |
| A new body part appears as a rod or capsule | The `shape` key is misspelled; unknown shapes fall through to the default; [P7-C1](part_07_art_and_assets/01_the_voli_body.md) |
| A kit fails "separates from the court floor" | Contrast against the floor is below 1.6; darken the kit, do not lower the gate; [P7-C2](part_07_art_and_assets/02_kits_colour_and_marks.md) |
| A render produced no new image | On macOS, drop `xvfb-run`; then check the PNG's timestamp; [P7-C5](part_07_art_and_assets/05_rendering_probes_and_validation.md) |
| Roughly 200 script errors after adding a class | Stale class cache; run `--import`; [P7-C5](part_07_art_and_assets/05_rendering_probes_and_validation.md) |
| Test output changes with the same seed | Look for unseeded randomness or mutable state outside the resolver; [P3-C2](part_03_workflow/02_debugging_testing_and_git.md) |
