# Volley World Manager Architecture Textbook

Book ID: `VWM-TEXTBOOK`

Audience: a programmer who may have **zero prior Godot or GDScript experience**, but wants to become capable of reading, debugging, modifying, and eventually extending Volley World Manager without needing another person or AI to translate the codebase first.

This is not a generic Godot course and not a dump of project notes. It teaches Godot, GDScript, and software architecture **through systems that actually exist in VWM**.

## Learning rule

The book uses **causal learning**:

> explain a language/engine concept when its purpose becomes visible in a real VWM system; use it again later with shorter reminders; gradually remove the scaffolding as the reader becomes fluent.

Important concepts therefore recur naturally. The first important appearance may explain syntax closely; later chapters remind you briefly; eventually normal project code is used without translation.

See [EDITORIAL_STANDARD.md](EDITORIAL_STANDARD.md) for the authoring standard.

## What this book should let you do

With time and source inspection, you should be able to:

- navigate Godot and locate the scene/resource/script behind a feature;
- read ordinary GDScript and function signatures without translation;
- distinguish scenes, runtime Nodes, Resources, models, systems, managers and presentation;
- trace UI, management and rally behavior across files;
- recognize where state is created, mutated, carried, serialized or reconstructed;
- make bounded changes and design the fixture/probe that should prove them;
- understand why important VWM systems have their present architecture;
- extend an existing system without bypassing its authority boundaries.

## Truth labels

- **VERIFIED** — directly supported by current source and/or named certification.
- **PARTIALLY IMPLEMENTED** — real code exists but does not own the complete path.
- **PROPOSED** — design direction, not current runtime behavior.
- **EXAMPLE** — teaching code; not necessarily verbatim production source.
- **HISTORICAL** — earlier architecture/migration evidence.
- **DEPRECATED** — still present but intentionally not current development.
- **UNVERIFIED** — requires fresh source inspection or measurement.

Current behavior must be checked against source and canonical design/review docs. Historical Gate notes are evidence, not present-day authority.

# Contents

## Part I — Reading and Writing VWM

1. [What VWM Is and How the Repository Is Organized](part_01_foundations/01_project_and_repository.md)
2. [Using the Godot Editor](part_01_foundations/02_using_the_godot_editor.md)
3. [GDScript: The Language Needed to Read VWM](part_01_foundations/03_gdscript_for_vwm.md)
4. [Godot's Object Model](part_01_foundations/04_godot_object_model.md)
5. [Tracing Code Through VWM](part_01_foundations/05_tracing_code_through_vwm.md)
6. [Making a First Safe Change](part_01_foundations/06_first_safe_change.md)

## Part II — Interface and Visual Architecture

7. [Controls, Buttons, Themes, and Interaction States](part_02_interface/01_controls_buttons_and_themes.md)
8. [Screens, Controls, and Layout](part_02_interface/02_screens_controls_and_layout.md)
9. [Paper Windows, Cards, Tabs, and Reusable Components](part_02_interface/03_paper_components.md)
10. [The Desk and Diegetic UI](part_02_interface/04_desk_and_diegetic_ui.md)
11. [Voli Stickers: 3D Rig → 2D Bake](part_02_interface/05_voli_sticker_bake.md)
12. [Shaders, Ink, Paper, and Surface Effects](part_02_interface/06_shaders_ink_paper_surfaces.md)
13. [Visual Probes and Render Validation](part_02_interface/07_visual_probes_and_validation.md)

## Part III — Game Data and Players

14. [Data Models and Resources](part_03_data/01_data_models_and_resources.md)
15. [Players, Attributes, and Roles](part_03_data/02_players_attributes_and_roles.md)
16. [Body Types and Physical Measurements](part_03_data/03_body_types_and_measurements.md)
17. [Generation, Potential, and Development](part_03_data/04_generation_potential_development.md)
18. [Regions, Clubs, and Tactical Identity](part_03_data/05_regions_clubs_and_identity.md)
19. [Career State, Managers, Saving, and Persistence](part_03_data/06_career_state_and_persistence.md)

## Part IV — Current Rally Architecture

20. [One Rally from Serve to Terminal Ball](part_04_rally/01_one_rally_end_to_end.md)
21. [RallySimulator, Event Records, and Authoritative State](part_04_rally/02_rally_simulator_events_state.md)
22. [Ball Contact and Authoritative Free Flight](part_04_rally/03_ball_contact_and_free_flight.md)
23. [Player State, Movement, and Continuity](part_04_rally/04_player_state_movement_continuity.md)
24. [Perception, Responsibility, and Action Choice](part_04_rally/05_perception_responsibility_action_choice.md)
25. [Physical Feasibility and Contact Geometry](part_04_rally/06_physical_feasibility_contact_geometry.md)
26. [Serve, Set, and Attack](part_04_rally/07_serve_set_attack.md)
27. [Blocking and Ball Interaction](part_04_rally/08_blocking_and_ball_interaction.md)
28. [Platform Contacts and T1–T3](part_04_rally/09_platform_contacts_t1_t3.md)
29. [Interception, Shanks, Overpasses, and Continuation](part_04_rally/10_interception_shanks_overpasses.md)
30. [Action Choice Across Team Contacts](part_04_rally/11_action_choice_across_contacts.md)
31. [The M0–M10 Rally Roadmap](part_04_rally/12_m0_m10_roadmap.md)

## Part V — How the Rally Engine Got Here

32. [The Original Phase Resolver](part_05_rally_history/01_original_phase_resolver.md)
33. [Shadow Systems and Guarded Rollout](part_05_rally_history/02_shadow_systems_and_rollout.md)
34. [Major RallySimulator Migrations](part_05_rally_history/03_major_rally_migrations.md)
35. [Measurement, Failed Hypotheses, and Removed Models](part_05_rally_history/04_measurement_and_failed_hypotheses.md)

## Part VI — Management Systems

36. [The Career Loop](part_06_management/01_career_loop.md)
37. [Roster, Scouting, Recruitment, and Offers](part_06_management/02_roster_recruitment.md)
38. [Training and Development](part_06_management/03_training_and_development.md)
39. [Club Operations and the Desk](part_06_management/04_club_operations_and_desk.md)
40. [How Management Decisions Reach Match Behavior](part_06_management/05_management_to_match.md)

## Part VII — Working on VWM Safely

41. [Tests, Deterministic Fixtures, and Probes](part_07_working_safely/01_tests_fixtures_and_probes.md)
42. [Derived vs Measured vs Authored Values](part_07_working_safely/02_derived_measured_authored.md)
43. [Certification and Production Promotion](part_07_working_safely/03_certification_and_promotion.md)
44. [Debugging Godot and GDScript](part_07_working_safely/04_debugging_godot_gdscript.md)
45. [Safely Extending an Existing System](part_07_working_safely/05_extending_existing_system.md)

# Reference

- [Current textbook/project status](STATUS.md)
- [Search index](INDEX.md)
- [Glossary](GLOSSARY.md)
- [Verification rules](VERIFICATION_RULES.md)
- [Validation](VALIDATION.md)
- [Player attributes ledger](PLAYER_ATTRIBUTES_LEDGER.md)
- [Event calculation taxonomy](EVENT_CALCULATION_TAXONOMY.md)
- [Granular attribute breakdown](GRANULAR_ATTRIBUTE_BREAKDOWN.md)
- [Rally event quality calculation map](RALLY_EVENT_QUALITY_CALCULATION_MAP.md)
- [Historical / older textbook material](LEGACY.md)

## Current-authority boundary

For rally work, the canonical phase index is `docs/design/RALLY_MILESTONES.md`; future action semantics are in `docs/design/RALLY_ACTION_SPACE.md`; detailed proof belongs in `docs/review/`.

For a fast answer to “what owns this now?”, start with [STATUS.md](STATUS.md), then the relevant Part IV/VI chapter, then inspect live source.

## Legacy material

The earlier `part_01_project` through `part_06_exercises` directories are retained as historical teaching material. They describe an earlier project/rally architecture and are **not** the recommended reading path. See [LEGACY.md](LEGACY.md).
