# Volley World Manager: Beginner Developer Textbook

Book ID: `VWM-TEXTBOOK`
Audience: a beginner with intuitive Godot experience and minimal programming experience
Repository: `https://github.com/iracarranza/volley-world-manager`

This book explains the project that actually exists. It also explains the persistent rally architecture currently being built, but it never presents unfinished work as live gameplay.

## How to use this book

1. A developer or coding model continuing active work should start with
   [FRESH_AGENT_HANDOFF.md](FRESH_AGENT_HANDOFF.md).
2. A beginner reading from the beginning should start with
   [Part 1](part_01_project/01_what_you_are_building.md).
3. Keep [INDEX.md](INDEX.md) open when searching for a feature, error, class, or method.
4. Use [GLOSSARY.md](GLOSSARY.md) whenever a term is unfamiliar.
5. Read the status label at the top of every chapter.
6. Follow source links and inspect the named class or function before changing code.
7. Run the checks in [VALIDATION.md](VALIDATION.md) after making changes.

### Reading paths

You do not have to read all of it, and which parts you need depends on what you
are doing:

| If you are… | Read |
|---|---|
| Entirely new to the project | Parts 1 → 2 → 3, then stop and do [P6-C1](part_06_exercises/01_guided_exercises.md) exercises 1–2 |
| Changing rally behaviour | Part 3, then Part 4 |
| Changing a career, roster or training feature | Part 3, then Part 5 |
| Changing anything a viewer sees | Part 3, then Part 7 |
| Continuing the migration | [FRESH_AGENT_HANDOFF.md](FRESH_AGENT_HANDOFF.md), then P4-C5 |
| Looking up one fact | [INDEX.md](INDEX.md) or [GLOSSARY.md](GLOSSARY.md) |

**Part 3 appears in every row.** It is short, and everything else assumes it.

### If you change the book

Run the validator, which checks that every source file and symbol the book
names still exists:

```bash
godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

It will not tell you whether an explanation is *correct* — only whether the
things it points at are real. Both kinds of error have happened here.

## How a chapter is organised

Every numbered chapter follows the same shape, so you can navigate one you have
never opened:

| Element | What it is for |
|---|---|
| **Status / Keywords / Primary sources** | What is verified, and which files back it |
| **Prerequisites** | What to read first |
| **Learning goals** | What you should be able to *do* afterwards |
| **Vocabulary** | Terms defined once, before they are used |
| **Numbered sections** (`1`, `2`, …) | One concept each |
| **Numbered subsections** (`1.1`, `1.2`, …) | One specific, lookup-able thing each |
| **Common mistakes** | Usually drawn from mistakes actually made here |
| **Check yourself** | Questions with answers |
| **Where this leads** | Forward references |

Sections and subsections are numbered so they can be cited: "P2-C3 §4.3" is a
precise address. Use them in commit messages and code comments.

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
- [Part 7 — Art, 3D Assets and the Drawn World](part_07_art_and_assets/README.md)

## Important current boundary

The live `RallySimulator` still computes a complete rally phase by phase and
emits `RallyEvent` resources. Persistent reception, setter, and attack contacts
have audited, guarded, development-only promotion paths, but all production
rollout flags remain off. Gate 43's approach mechanics are active in ordinary
home attack and counterattack calculation. Blocking remains legacy-controlled
and is the next perception migration slice.

The Match Center also offers a presentation-only 3D replay of the last point.
It consumes the same rally snapshots and trajectory evidence as 2D playback;
simulation and tactical editing remain authoritative elsewhere.
