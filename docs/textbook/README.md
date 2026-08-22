# Volley World Manager Architecture Textbook

Book ID: `VWM-TEXTBOOK`

Audience: a programmer who may have **zero prior Godot or GDScript experience**, but wants to become capable of reading, debugging, modifying, and eventually extending Volley World Manager without needing another person or AI to translate the codebase first.

This is not a generic Godot course and not a dump of project notes. It teaches Godot, GDScript, and software architecture **through the systems that actually exist in VWM**.

## Learning rule

The book uses **causal learning**:

> explain a language/engine concept when its purpose becomes visible in a real VWM system; use it again later with shorter reminders; gradually remove the scaffolding as the reader becomes fluent.

A chapter about buttons therefore teaches the relevant parts of `Control`, themes, signals, and callbacks while tracing a real VWM button. A chapter about voli stickers teaches `SubViewport`, `await`, scene instantiation, image readback, and caching while following the actual sticker bake. A rally chapter teaches state, Resources, typed functions, static systems, vectors, and mutation while following the actual rally.

Do **not** front-load ten generic Godot definitions before the reader can see why they matter. Do **not** assume a term is permanently remembered because it was defined once. Important recurring ideas get brief textbook-style reminders.

## What this book should let you do

With time and source inspection, a reader should be able to:

- navigate the Godot editor and locate the scene/resource/script behind a feature;
- read ordinary GDScript syntax and function signatures without translation;
- distinguish a scene from a runtime instance, a Node from a Resource, and presentation from simulation authority;
- trace a UI action, management action, or rally decision across files;
- recognize where state is created, mutated, carried, serialized, or reconstructed;
- make a bounded change and know which tests/probes should prove it;
- understand why important VWM systems have their present architecture;
- extend an existing system without casually bypassing its authority boundaries.

## Truth labels

- **VERIFIED** — directly supported by current source and/or a named certification.
- **PARTIALLY IMPLEMENTED** — real code exists but does not yet own the complete live path.
- **PROPOSED** — design direction, not current runtime behavior.
- **EXAMPLE** — teaching code; not necessarily source copied verbatim.
- **HISTORICAL** — explains an earlier architecture or migration step.
- **DEPRECATED** — still present but intentionally not part of current development.
- **UNVERIFIED** — claim requiring fresh inspection or measurement.

Current behavior must be checked against source and the canonical design/review docs. Historical gate notes are evidence, not automatic present-day authority.

## Reading order — v2

### Part I — Reading and Writing VWM

1. What VWM is and how the repository is organized
2. Using the Godot editor
3. GDScript: the language needed to read VWM
4. Godot's object model: Nodes, scenes, Resources, signals, and runtime instances
5. Tracing code through the project
6. Making a first safe change

### Part II — Interface and Visual Architecture

7. Screens, Controls, and layout
8. Buttons, themes, and interaction states
9. Paper windows, cards, tabs, and reusable components
10. The desk and diegetic UI architecture
11. Voli stickers: 3D rig → off-screen render → 2D bake
12. Shaders, ink, paper, and surface effects
13. Visual probes and render validation

### Part III — Game Data and Players

14. Data models and Resources
15. Players, attributes, and roles
16. Body types and physical measurements
17. Generation, potential, and development
18. Regions, clubs, and tactical identity
19. Career state, managers, saving, and persistence

### Part IV — Rally Architecture

20. One rally from serve to terminal ball
21. `RallySimulator`, event records, and authoritative state
22. Ball contact and authoritative free flight
23. Player state, movement, and continuity
24. Perception, responsibility, and action choice
25. Physical feasibility and contact geometry
26. Serve, set, and attack
27. Blocking and ball interaction
28. Platform contacts and T1–T3
29. Interception, shanks, overpasses, and continuation
30. Action choice across team contacts
31. The M0–M10 rally roadmap

### Part V — How the Rally Engine Got Here

32. The original phase resolver
33. Shadow systems and guarded development rollout
34. Major `RallySimulator` migrations
35. Measurement, failed hypotheses, and removed models

### Part VI — Management Systems

36. Career loop
37. Roster and recruitment
38. Training and development
39. Club operations and desk systems
40. How management decisions reach match behavior

### Part VII — Working on VWM Safely

41. Tests, deterministic fixtures, and probes
42. Derived vs measured vs authored values
43. Certification and production promotion
44. Debugging Godot and GDScript
45. Safely extending an existing system

### Reference

- current implementation status
- glossary
- source/symbol index
- player attribute ledger
- event/calculation taxonomy
- validation commands
- historical handoffs/session notes

## Chapter style

A technical chapter should normally flow from **purpose → actual system → concepts encountered → source trace → architectural reasoning → modification/debugging guidance**. Beginner explanations belong inline where they become useful rather than as mandatory mini-sections.

The first appearance of an important GDScript/Godot construct may be explained closely. Later appearances get short reminders. Eventually the construct is used normally. Real VWM code should therefore become progressively less annotated as the book advances.

Small recurring callouts are encouraged:

- **Godot reminder** — engine/editor concept worth recalling.
- **GDScript reminder** — syntax/language construct worth recalling.
- **VWM boundary** — project-specific authority or dependency that must not be confused with neighboring code.

## Migration status

The older `part_01_project` through `part_06_exercises` chapters remain in the repository during the v2 rewrite so useful material is not destroyed before it is migrated. They describe an earlier architecture and should not automatically be treated as current truth.

The canonical current rally status is `docs/design/RALLY_MILESTONES.md`; the action-space target is `docs/design/RALLY_ACTION_SPACE.md`.

For active coding-agent handoff, use the current project/review documents rather than the old textbook `FRESH_AGENT_HANDOFF.md` until that reference section is rebuilt.