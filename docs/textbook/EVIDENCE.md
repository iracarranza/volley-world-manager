# Evidence Ledger

This ledger connects important statements to stable source locations.

| Claim | Status | Source file | Symbol or property |
|---|---|---|---|
| Application starts from the application scene | VERIFIED | `project.godot` | `run/main_scene` |
| Game and career state are globally available | VERIFIED | `project.godot` | `[autoload]` |
| UI navigation begins in one application controller | VERIFIED | `scenes/application.gd` | `_ready`, `_show_title`, `_show_dashboard`, `_show_match` |
| Live rallies enter the current simulator through GameManager | VERIFIED | `scripts/managers/game_manager.gd` | `resolve_active_rally` |
| Current simulator returns an event-based result | VERIFIED | `scripts/simulation/rally_simulator.gd` | `resolve`, `_add_event`, `_finish` |
| Event playback data has actor, positions, quality, text, and metadata | VERIFIED | `scripts/models/rally_event.gd` | `RallyEvent` exported properties |
| A result records events and outcome analysis | VERIFIED | `scripts/models/rally_result.gd` | `RallyResult` exported properties |
| Persistent player state exists | PARTIALLY IMPLEMENTED | `scripts/models/rally_player_state.gd` | `RallyPlayerState` |
| Persistent ball state exists | PARTIALLY IMPLEMENTED | `scripts/models/rally_ball_state.gd` | `RallyBallState` |
| Future moments can be ordered | PARTIALLY IMPLEMENTED | `scripts/simulation/rally_scheduler.gd` | `schedule`, `next`, `schedule_ball_flight` |
| Movement can generate reception opportunities and advance a copied actor without mutating live state | PARTIALLY IMPLEMENTED | `scripts/simulation/rally_movement_system.gd` | `generate_reception_opportunities`, `project_toward` |
| Ball contacts have normalized speed, angle, spin, and stability descriptors | PARTIALLY IMPLEMENTED | `scripts/models/ball_contact_signature.gd` | `BallContactSignature`, `baseline_novelty` |
| Calculated flight truth is separate from visual trajectory and player perception | PARTIALLY IMPLEMENTED | `scripts/models/ball_flight.gd` | `BallFlight` |
| Players can hold bounded perceived destinations and arrival times | PARTIALLY IMPLEMENTED | `scripts/models/ball_flight_estimate.gd` | `BallFlightEstimate` |
| Deterministic player reading can convert a flight into one estimate or an ordered in-flight sequence | PARTIALLY IMPLEMENTED | `scripts/simulation/ball_read_system.gd` | `estimate`, `estimate_sequence` |
| Shadow reception compares persistent opportunity ranking with the official legacy claimant | PARTIALLY IMPLEMENTED | `scripts/simulation/shadow_reception_system.gd` | `evaluate` |
| Shadow calculations produce structured developer evidence | PARTIALLY IMPLEMENTED | `scripts/models/rally_trace.gd` | `RallyTrace`, `to_dict` |
| Debug builds draw true and perceived reception targets on the 2D court | VERIFIED DEBUG TOOL | `scenes/components/tactical_court.gd`; `scenes/main/main.gd` | `set_shadow_reception_trace`, `_draw_shadow_reception_trace`, `_show_shadow_reception_debug` |
| Court distance, diagnostic flight duration, and effective speed share one unit conversion | VERIFIED SHADOW TOOL | `scripts/simulation/rally_kinematics.gd` | `court_distance_meters`, `flight_duration`, `timing_diagnostics` |
| Batch calibration reports measured distributions without changing rally outcomes | VERIFIED SHADOW TOOL | `scripts/simulation/rally_calibration_report.gd`; `tools/run_rally_calibration.gd` | `add_shadow_trace`, `build_summary` |
| Paired fixtures cover Standing, Jump Topspin, Jump Float, Hybrid, and Sky Ball at equal proficiency | VERIFIED SHADOW TOOL | `scripts/simulation/serve_style_calibration.gd` | `SERVE_STYLES`, `run` |
| Shadow reception compares receiver availability under legacy and signature-implied duration | PARTIALLY IMPLEMENTED | `scripts/simulation/shadow_reception_system.gd` | `timing_candidates`, `signature_candidate` |
| Shadow reception can derive speed from authoritative distance and duration and compare its perception effects | PARTIALLY IMPLEMENTED | `scripts/simulation/shadow_reception_system.gd`; `scripts/simulation/rally_calibration_report.gd` | `speed_candidates`, `derived_speed_candidate`, `derived_speed_reachable_rate` |
| Controlled fixtures isolate reader attributes and receive formation while keeping paired serves fixed | VERIFIED SHADOW TOOL | `scripts/simulation/reception_progression_calibration.gd` | `READER_TIERS`, `FORMATIONS`, `run` |
| Calculated signature speed is canonical in shadow reception and duration is derived from distance and speed | VERIFIED SHADOW TOOL | `scripts/simulation/shadow_reception_system.gd`; `docs/calibration/GATE_20_CANONICAL_SERVE_TIMING.md` | `canonical_signature_source`, `canonical_timing_diagnostics` |
| Repeated reads expose corrections and improved within-player information, but stationary late-read reachability is not a live rule | VERIFIED SHADOW TOOL | `scripts/simulation/shadow_reception_system.gd`; `docs/calibration/GATE_06_REPEATED_READS.md` | `repeated_read_candidate`, `perception_candidates` |
| Repeated reads can redirect a temporary moving receiver while preserving official state | VERIFIED SHADOW TOOL | `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/shadow_reception_system.gd`; `docs/calibration/GATE_07_PROJECTED_MOVEMENT.md` | `project_toward`, `projected_position`, `projection_model` |
| Receive actions have explicit opening and closing windows scheduled in an isolated rally snapshot | VERIFIED SHADOW TOOL | `scripts/models/action_opportunity_window.gd`; `scripts/simulation/rally_opportunity_system.gd`; `docs/calibration/GATE_08_OPPORTUNITY_WINDOWS.md` | `ActionOpportunityWindow`, `evaluate_reception_timeline`, `opportunity_closed_early_rate` |
| A shadow policy can select among open receivers and grade the perceived contact against ball truth | VERIFIED SHADOW TOOL | `scripts/models/rally_decision.gd`; `scripts/simulation/rally_decision_system.gd`; `docs/calibration/GATE_09_SHADOW_RECEPTION_DECISIONS.md` | `RallyDecision`, `select_shadow_reception`, `shadow_contact_success_given_decision_rate` |
| A developed reception profile produces longer windows, more choices, and better contact outcomes under paired serves | VERIFIED SHADOW TOOL | `scripts/simulation/reception_decision_progression_calibration.gd`; `docs/calibration/GATE_10_PLAYER_OPTIONS_AND_PROGRESSION.md` | `PLAYER_TIERS`, `progression`, `quick_release_available_rate` |
| Setter ownership can transfer from tactical intent to a stronger reachable action window with a recorded reason | VERIFIED SHADOW TOOL | `scripts/simulation/setter_handoff_calibration.gd`; `docs/calibration/GATE_21_SETTER_HANDOFF_AUDIT.md` | `FIXTURES`, `forced_late_handoff_valid_rate`, `handoff_reasons` |
| Setter development increases read confidence and unlocks controlled and quick-tempo actions under identical passes | VERIFIED SHADOW TOOL | `scripts/simulation/setter_progression_calibration.gd`; `docs/calibration/GATE_22_SETTER_PROGRESSION.md` | `SETTER_TIERS`, `progression`, `by_setter_tier` |
| Reach failures are decomposed into time, distance, movement capacity, contact reach, and directional-velocity error before tuning | VERIFIED SHADOW TOOL | `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/rally_calibration_report.gd`; `docs/calibration/GATE_23_REACH_DECOMPOSITION.md` | `center_distance_deficit_meters`, `reach_counterfactuals` |
| CareerManager owns career save and weekly flow | VERIFIED | `scripts/managers/career_manager.gd` | `create_career`, `advance_week`, `save_career`, `load_career` |
| Weekly training changes players | VERIFIED | `scripts/systems/training_system.gd` | `apply_week` |
| Player generation is region- and seed-aware | VERIFIED | `scripts/systems/player_generator.gd` | `generate_roster`, `generate_market` |
| 2D match playback is present | VERIFIED | `scenes/main/main.gd` | `_play_rally` |
| 3D work is paused | PROJECT DECISION | User direction | Not a source-code fact |
