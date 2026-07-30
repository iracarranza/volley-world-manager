# Verification Rules

These rules are designed to make the book useful without allowing confident-sounding guesses to become project facts.

## Rule 1: Every implementation claim needs evidence

A **VERIFIED** claim must name at least one project-relative source file and a stable symbol such as a class, method, signal, or exported property. Line numbers are avoided because ordinary edits make them stale.

## Rule 2: Existence is not activation

A class can exist and pass unit tests without being used by the running game. To claim a feature is active, trace a call path from a scene, signal, Autoload, or other runtime entry point to that class.

## Rule 3: Proposed code must say `PROPOSED`

Architectural diagrams, future sequencing, and teaching examples are not descriptions of current runtime behavior unless their surrounding section is marked **VERIFIED**.

## Rule 4: Source code outranks prose

If this book disagrees with the repository, inspect tests and runtime behavior, then update the book. Do not modify working code merely to make old documentation correct.

## Rule 5: Tests prove only their assertions

A passing test does not prove visual quality, fun, realism, or complete feature integration. Read the test to learn exactly what it checks.

## Rule 6: Use exact project vocabulary

Search for exact names such as `outgoing_trajectory`, `movement_duration`, and `resolve_active_rally`. Similar-sounding names are not interchangeable contracts.

## Rule 7: Record uncertainty

Use **UNVERIFIED** when evidence has not been inspected. Turning “I do not know yet” into a search task is safer than filling a gap with an assumption.

## Evidence maintenance

- [EVIDENCE.md](EVIDENCE.md) records high-value claims and their source symbols.
- `source_manifest.json` is a machine-readable list used by the validator.
- Run the validator after renaming or moving documented code.
