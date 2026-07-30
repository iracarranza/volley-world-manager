# Volley World Manager: Beginner Developer Textbook

Book ID: `VWM-TEXTBOOK`
Audience: a beginner with intuitive Godot experience and minimal programming experience
Project root: `/Users/iracarranza/volley-world-manager`

This book explains the project that actually exists. It also explains the persistent rally architecture currently being built, but it never presents unfinished work as live gameplay.

## How to use this book

1. Start with [Part 1](part_01_project/01_what_you_are_building.md).
2. Keep [INDEX.md](INDEX.md) open when searching for a feature, error, class, or method.
3. Use [GLOSSARY.md](GLOSSARY.md) whenever a term is unfamiliar.
4. Read the status label at the top of every chapter.
5. Follow source links and inspect the named class or function before changing code.
6. Run the checks in [VALIDATION.md](VALIDATION.md) after making changes.

## Truth labels

- **VERIFIED:** directly supported by a named source file and symbol.
- **PARTIALLY IMPLEMENTED:** code and tests exist, but the feature is not fully connected to live play.
- **PROPOSED:** a design direction, not current behavior.
- **EXAMPLE:** teaching code that may not belong in the project unchanged.
- **DEPRECATED:** still present, but intentionally not part of current development.
- **UNVERIFIED:** a claim that still requires inspection or testing.

See [VERIFICATION_RULES.md](VERIFICATION_RULES.md) for the rules behind these labels.

## Parts

- [Part 1 — The Project](part_01_project/README.md)
- [Part 2 — GDScript for This Codebase](part_02_gdscript/README.md)
- [Part 3 — A Safe Development Workflow](part_03_workflow/README.md)
- [Part 4 — The Match and Rally Engine](part_04_match_engine/README.md)
- [Part 5 — Career and Player Development](part_05_management/README.md)
- [Part 6 — Guided Exercises](part_06_exercises/README.md)

## Important current boundary

The live `RallySimulator` still computes a complete rally and emits a sequence of `RallyEvent` resources. The newer `RallyState`, `RallyPlayerState`, `RallyBallState`, `RallyScheduler`, and `RallyMovementSystem` form a tested foundation for a persistent simulation, but they are not yet the resolver used by match play.

Opponent-serve rallies now also run a deterministic shadow reception comparison.
It records how the persistent perception and movement model would rank receivers,
but the legacy receiver remains authoritative.

The 3D match code still exists, but current development is focused on simulation and 2D playback. Treat 3D work as paused.
