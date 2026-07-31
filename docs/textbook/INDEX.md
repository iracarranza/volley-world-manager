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
| What is historical practice rather than current roadmap work? | [P6-C2](part_06_exercises/02_beginner_project_ladder.md) |

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
| `RallyMovementSystem.movement_profile` | Public rating-driven speed, acceleration, and turn-delay profile, shared by the stepper; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `RallyOpportunitySystem` | Shadow scheduling of receive-window opening and closure; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `RallyDecision` | Structured evidence for one selected shadow action; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `RallyDecisionSystem` | Comparison of open receiver choices and grading against ball truth; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `CoverageCalculator` | Arrival and claimant calculations; [P4-C3](part_04_match_engine/03_ball_time_movement_and_actions.md) |
| `TacticalCourt.set_visualization_layers` | Shared court-overlay visibility mask; [P4-C6](part_04_match_engine/06_adjusting_and_extending_live_systems.md) |
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
| Test output changes with the same seed | Look for unseeded randomness or mutable state outside the resolver; [P3-C2](part_03_workflow/02_debugging_testing_and_git.md) |
