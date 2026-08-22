# Search Index

Use editor search (`Cmd+Shift+F` / `Ctrl+Shift+F`) on this file. Start from the question closest to yours, then follow the chapter's **Source trail** into live code.

## Starting / learning

| Question | Read |
|---|---|
| I know programming but not Godot; where do I start? | [Godot Editor](part_01_foundations/02_using_the_godot_editor.md) → [GDScript](part_01_foundations/03_gdscript_for_vwm.md) → [Object Model](part_01_foundations/04_godot_object_model.md) |
| How is the repository organized? | [Project and Repository](part_01_foundations/01_project_and_repository.md) |
| How do I follow an unfamiliar feature through the code? | [Tracing Code Through VWM](part_01_foundations/05_tracing_code_through_vwm.md) |
| How do I make a safe first change? | [Making a First Safe Change](part_01_foundations/06_first_safe_change.md) |
| What is current vs historical? | [STATUS](STATUS.md), [Legacy Material](LEGACY.md) |
| How do I eventually extend a system myself? | [Safely Extending an Existing System](part_07_working_safely/05_extending_existing_system.md) |

## Godot / GDScript

| Search term / question | Read |
|---|---|
| `var`, `const`, `=`, `:=`, types, functions, loops, `match` | [GDScript for VWM](part_01_foundations/03_gdscript_for_vwm.md) |
| `class_name`, `extends`, inheritance | [GDScript](part_01_foundations/03_gdscript_for_vwm.md), [Object Model](part_01_foundations/04_godot_object_model.md) |
| Node vs Resource vs RefCounted | [Object Model](part_01_foundations/04_godot_object_model.md), [Data Models](part_03_data/01_data_models_and_resources.md) |
| `.gd`, `.tscn`, `.tres`, `res://`, `user://` | [Godot Editor](part_01_foundations/02_using_the_godot_editor.md), [Object Model](part_01_foundations/04_godot_object_model.md) |
| `preload`, `load`, `instantiate` | [GDScript](part_01_foundations/03_gdscript_for_vwm.md), [Sticker Bake](part_02_interface/05_voli_sticker_bake.md) |
| `signal`, `.emit()`, `.connect()` | [Object Model](part_01_foundations/04_godot_object_model.md), [Tracing Code](part_01_foundations/05_tracing_code_through_vwm.md) |
| `await`, process frame, deferred calls | [GDScript](part_01_foundations/03_gdscript_for_vwm.md), [Visual Probes](part_02_interface/07_visual_probes_and_validation.md) |
| `@export`, `@export_range`, Inspector properties | [Data Models](part_03_data/01_data_models_and_resources.md) |
| Dictionary / Array / Variant / casts | [GDScript](part_01_foundations/03_gdscript_for_vwm.md), [Data Models](part_03_data/01_data_models_and_resources.md) |
| Autoload / `/root/CareerManager` | [Career Persistence](part_03_data/06_career_state_and_persistence.md) |
| Remote Scene Tree | [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |

## UI / visual architecture

| Question | Read |
|---|---|
| How does a VWM button get its appearance and action? | [Controls, Buttons, Themes](part_02_interface/01_controls_buttons_and_themes.md) |
| Why did changing a Button child break its click area? | [Buttons/Themes](part_02_interface/01_controls_buttons_and_themes.md), [Paper Components](part_02_interface/03_paper_components.md) |
| How are screens created/swapped? | [Screens, Controls, Layout](part_02_interface/02_screens_controls_and_layout.md) |
| Why do some screens not appear in the Local Scene Tree? | [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| What does `VolleyballScreenShell` do? | [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| How do paper windows/cards/tabs work? | [Paper Components](part_02_interface/03_paper_components.md) |
| How does the desk work? | [Desk and Diegetic UI](part_02_interface/04_desk_and_diegetic_ui.md) |
| How are voli stickers made? | [Voli Sticker Bake](part_02_interface/05_voli_sticker_bake.md) |
| Why does sticker baking use SubViewport/Camera3D/await/cache? | [Voli Sticker Bake](part_02_interface/05_voli_sticker_bake.md) |
| How do shaders, halftone, paper fibre and ink layers fit together? | [Shaders, Ink, Paper](part_02_interface/06_shaders_ink_paper_surfaces.md) |
| How do I test a pose/UI look without playing a career? | [Visual Probes](part_02_interface/07_visual_probes_and_validation.md) |

## Player / data / career

| Question | Read |
|---|---|
| What does `VolleyballPlayer` store? | [Players, Attributes, Roles](part_03_data/02_players_attributes_and_roles.md) |
| Ability vs temperament vs state vs reputation? | [Players, Attributes, Roles](part_03_data/02_players_attributes_and_roles.md) |
| How do body type, height, wingspan and contact reach relate? | [Body Types and Measurements](part_03_data/03_body_types_and_measurements.md) |
| How are players generated? | [Generation, Potential, Development](part_03_data/04_generation_potential_development.md) |
| What is potential vs per-attribute ceiling? | [Generation, Potential, Development](part_03_data/04_generation_potential_development.md) |
| How do regional identities affect players/clubs? | [Regions, Clubs, Identity](part_03_data/05_regions_clubs_and_identity.md) |
| How are careers saved and migrated? | [Career State and Persistence](part_03_data/06_career_state_and_persistence.md) |
| Why is world population a sidecar/lazy loaded? | [Career State and Persistence](part_03_data/06_career_state_and_persistence.md) |

## Rally architecture

| Question | Read |
|---|---|
| Explain one current rally end-to-end | [One Rally End to End](part_04_rally/01_one_rally_end_to_end.md) |
| What does `RallySimulator` own today? | [RallySimulator / Events / State](part_04_rally/02_rally_simulator_events_state.md) |
| RallyEvent vs RallyState? | [RallySimulator / Events / State](part_04_rally/02_rally_simulator_events_state.md) |
| Why is intended recipient not the ball endpoint? | [Ball Contact and Free Flight](part_04_rally/03_ball_contact_and_free_flight.md) |
| What is an authoritative free flight / realised prefix? | [Ball Contact and Free Flight](part_04_rally/03_ball_contact_and_free_flight.md) |
| How do player facing/recovery/body state persist? | [Player State / Movement / Continuity](part_04_rally/04_player_state_movement_continuity.md) |
| Why was `readiness` removed? | [Player State / Movement / Continuity](part_04_rally/04_player_state_movement_continuity.md) |
| Who takes a ball when multiple players can reach it? | [Perception, Responsibility, Action Choice](part_04_rally/05_perception_responsibility_action_choice.md) |
| Physical feasibility vs responsibility vs legality? | [Perception/Choice](part_04_rally/05_perception_responsibility_action_choice.md), [Physical Feasibility](part_04_rally/06_physical_feasibility_contact_geometry.md) |
| How do serve/set/attack fit the architecture? | [Serve, Set, Attack](part_04_rally/07_serve_set_attack.md) |
| How is a block different from a team contact? | [Blocking and Ball Interaction](part_04_rally/08_blocking_and_ball_interaction.md) |
| What are T1/T2/T3? | [Platform Contacts T1–T3](part_04_rally/09_platform_contacts_t1_t3.md) |
| Are T1–T3 measured biomechanics? | No; explicit authored game abstractions. See [Platform Contacts T1–T3](part_04_rally/09_platform_contacts_t1_t3.md). |
| How do shanks/interceptions work? | [Interception, Shanks, Overpasses](part_04_rally/10_interception_shanks_overpasses.md) |
| How do overpasses work/current status? | [Interception, Shanks, Overpasses](part_04_rally/10_interception_shanks_overpasses.md), [STATUS](STATUS.md) |
| Attack/set/control on contact 1/2/3? | [Action Choice Across Contacts](part_04_rally/11_action_choice_across_contacts.md) |
| Jousts / net rebounds / setter dumps? | [Action Choice Across Contacts](part_04_rally/11_action_choice_across_contacts.md) — future M6/M7 unless current source says otherwise. |
| What do M0–M10 mean? | [Rally Roadmap](part_04_rally/12_m0_m10_roadmap.md) |

## Rally history / why the code looks this way

| Question | Read |
|---|---|
| Why was the old phase resolver limiting? | [Original Phase Resolver](part_05_rally_history/01_original_phase_resolver.md) |
| What were shadow systems/Gates for? | [Shadow Systems and Rollout](part_05_rally_history/02_shadow_systems_and_rollout.md) |
| What were the major migrations? | [Major Rally Migrations](part_05_rally_history/03_major_rally_migrations.md) |
| Why does the project measure rejected hypotheses? | [Measurement and Failed Hypotheses](part_05_rally_history/04_measurement_and_failed_hypotheses.md) |

## Management

| Question | Read |
|---|---|
| How does the career loop progress? | [Career Loop](part_06_management/01_career_loop.md) |
| How do scouting/recruitment/transfer pool fit together? | [Roster and Recruitment](part_06_management/02_roster_recruitment.md) |
| How does training actually change players? | [Training and Development](part_06_management/03_training_and_development.md) |
| Housing/food/staff/desk systems? | [Club Operations](part_06_management/04_club_operations_and_desk.md) |
| How does a management decision reach a rally? | [Management to Match](part_06_management/05_management_to_match.md) |

## Working safely

| Question | Read |
|---|---|
| What test/probe should I write? | [Tests, Fixtures, Probes](part_07_working_safely/01_tests_fixtures_and_probes.md) |
| Derived vs measured vs authored constants? | [Derived / Measured / Authored](part_07_working_safely/02_derived_measured_authored.md) |
| When can a development path become production authority? | [Certification and Promotion](part_07_working_safely/03_certification_and_promotion.md) |
| How do I debug GDScript/Godot errors? | [Debugging Godot/GDScript](part_07_working_safely/04_debugging_godot_gdscript.md) |
| How do I add a new feature without parallel architecture? | [Extending Existing Systems](part_07_working_safely/05_extending_existing_system.md) |

# Key symbols

| Symbol / file | Meaning / first useful chapter |
|---|---|
| `scenes/application.gd` | top-level screen routing/lazy construction; [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| `VolleyballUIStyleSystem` | recursive medium/theme/material styling; [Paper Components](part_02_interface/03_paper_components.md) |
| `VolleyballScreenShell` | shared full-screen page anatomy; [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| `MenuCard` | clickable card component; [Buttons/Themes](part_02_interface/01_controls_buttons_and_themes.md) |
| `UIVoliSticker` | off-screen 3D→2D sticker baker/cache; [Sticker Bake](part_02_interface/05_voli_sticker_bake.md) |
| `VolleyballPlayer` | persistent player profile Resource; [Players/Attributes](part_03_data/02_players_attributes_and_roles.md) |
| `VolleyballPlayerGenerator` | attribute-first roster/world generation; [Generation](part_03_data/04_generation_potential_development.md) |
| `VolleyballCareerState` | durable career Resource; [Career Persistence](part_03_data/06_career_state_and_persistence.md) |
| `CareerManager` | career orchestration/autoload; [Career Persistence](part_03_data/06_career_state_and_persistence.md) |
| `VolleyballTrainingSystem` | weekly regimen/development application; [Training](part_06_management/03_training_and_development.md) |
| `RallySimulator` | current top-level rally orchestrator; [RallySimulator](part_04_rally/02_rally_simulator_events_state.md) |
| `RallyEvent` | resolved action record for playback/statistics; [RallySimulator](part_04_rally/02_rally_simulator_events_state.md) |
| `RallyState` | compact rally state model/snapshot; [RallySimulator](part_04_rally/02_rally_simulator_events_state.md) |
| `RallyPlayerState` | transient actor physical/intent state; [Player State](part_04_rally/04_player_state_movement_continuity.md) |
| `RallyBallState` | current ball trajectory/state; [Ball Flight](part_04_rally/03_ball_contact_and_free_flight.md) |
| `ActionOpportunity` | timed physical action opportunity; [Physical Feasibility](part_04_rally/06_physical_feasibility_contact_geometry.md) |
| `RallyMovementSystem` | movement/reach opportunity calculations; [Player State](part_04_rally/04_player_state_movement_continuity.md) |
| `ApproachMechanicsSystem` | attack preparation/takeoff availability; [Serve/Set/Attack](part_04_rally/07_serve_set_attack.md) |
| `PlatformContactModel` | shared T1–T3 forearm-contact physics; [Platform Contacts](part_04_rally/09_platform_contacts_t1_t3.md) |
| `FreeFlightInterceptionSystem` | authoritative launch/free-flight/interception queries; [Ball Flight](part_04_rally/03_ball_contact_and_free_flight.md) |
| `OverpassActionSystem` | receiving-side ordinary first-contact contest after legal crossing; [Overpasses](part_04_rally/10_interception_shanks_overpasses.md) |

# Common errors / symptoms

| Symptom | First check |
|---|---|
| Parser Error | [Debugging Godot/GDScript](part_07_working_safely/04_debugging_godot_gdscript.md) |
| Attempt to call function on null instance | trace construction/lookup/cast; [Debugging](part_07_working_safely/04_debugging_godot_gdscript.md) |
| Invalid get/index/property | object property vs Dictionary key/value type; [Debugging](part_07_working_safely/04_debugging_godot_gdscript.md) |
| UI child ignores my position | parent Container likely owns layout; [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| Code-built screen missing from Local scene | inspect Remote Scene Tree; [Screens/Layout](part_02_interface/02_screens_controls_and_layout.md) |
| Button looks wrong but works | Theme/StyleBox/style system; [Buttons/Themes](part_02_interface/01_controls_buttons_and_themes.md) |
| Sticker changes not visible | cache/fingerprint/runtime bake; [Sticker Bake](part_02_interface/05_voli_sticker_bake.md) |
| Value resets after reload | persistence owner + `to_dict/from_dict`; [Career Persistence](part_03_data/06_career_state_and_persistence.md) |
| New rally code exists but ordinary match unchanged | integration/authority boundary; [Certification](part_07_working_safely/03_certification_and_promotion.md) |
| Ball teleports / recipient defines path | trace authoritative launch/free flight; [Ball Flight](part_04_rally/03_ball_contact_and_free_flight.md) |
| Outcome rate changed after correctness fix | diagnose mechanism before tuning; [Measurement](part_05_rally_history/04_measurement_and_failed_hypotheses.md) |
| Test count changed | count alone is not acceptance; [Tests/Probes](part_07_working_safely/01_tests_fixtures_and_probes.md) |
