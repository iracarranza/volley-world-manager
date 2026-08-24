# M9 — Tactical Causal Map

This is a source census, not a design wish-list. Fill from the current post-M8 implementation before changing simulation behavior.

## Required row schema

| Instruction | Player-selectable source | Stored as | Live consumer | Decision changed | Physical consequence | Class | Evidence/probe |
|---|---|---|---|---|---|---|---|

For each row trace exact symbols/files. Do not infer causality from naming.

## Census procedure

1. Enumerate all controls/options exposed by the current tactics UI and any fixture/match tactical sheet.
2. Resolve each option to the persisted/runtime key consumed by the rally.
3. Search all reads of that key.
4. Separate diagnostics/presentation reads from simulation reads.
5. For each simulation read, identify the first decision it changes.
6. Follow that decision until an authoritative physical state differs: responsibility, target, movement, feasible action, launch, block geometry, defensive geometry, etc.
7. Classify only after the complete chain is known.

## Proof standard

Preferred proof is paired deterministic/constructed state:

`same source state + same RNG + tactic A` versus `same source state + same RNG + tactic B`.

The first intended divergence must occur at the tactic's governed decision boundary. Later trajectory/contact/outcome divergence is consequence, not the tactic's authority itself.

Examples of acceptable causal shapes (names are illustrative until source census confirms them):

- serve target A↔B → intended serve target/aim differs → authoritative launch/landing geometry differs → reception situation differs;
- line↔cross defensive responsibility → actor responsibility/starting or movement solution differs → protected/reachable space differs;
- block seal↔funnel → block intent/geometry differs → physically different interaction/deflection opportunity → floor-defence situation differs.

Unacceptable proof:

- option persisted;
- event metadata differs but action does not;
- commentary/diagnostic changes;
- aggregate win/kill/dig rate changes without locating the causal boundary;
- tactic directly biases terminal outcome.

## Census status

`UNKNOWN` until re-taken against the M8-complete integration commit. Existing `scripts/tactics/` currently contains validation/demand infrastructure; this directory alone is not the full tactic authority and must not be treated as the census.
