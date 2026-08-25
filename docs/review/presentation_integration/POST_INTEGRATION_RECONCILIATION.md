# Post-integration reconciliation

Date: 2026-08-25.

## Integrated authority

- Accepted M8 continuity and documentation line.
- Canonical M9 implementation and packet only: 39/39 causal families,
  240/240 gates.
- Parallel presentation principles/specification, not its competing M9 packet or
  draft scene hierarchy.
- Gameplay-broadcast production path around the real `MatchScreen` and
  `RallyResult` playback.

The exact pre-merge, file-by-file disposition is
`PRESENTATION_COLLISION_AUDIT.md`.

## Rendered evidence

`tools/gameplay_broadcast.tscn` produced six frames from two real rallies at
1280×720: attack, block and dig in Pāwa Hitō and Taktikã. Inspection found:

- distinct court/venue treatments and opponent kit identity;
- live set/score/serve state in the top-left score bug;
- wrapped, unellipsized semantic commentary in the top-right;
- neutral announcer portraits separate from court players;
- bottom controls over runoff rather than playable action;
- captions matching the resolved attack/block/dig events;
- no presentation-authored contact, trajectory, score or tactical consequence.

The compact bottom diagnostic label can ellipsize its event/time suffix at
1280 px. It is instrumentation rather than semantic commentary and remains
presentation debt.

## Verification receipts

Measured on integrated gameplay commit
`29b993dbee34f4959ec6d99cf6f71564c539bb4d` with Godot
`4.7.1.stable.official.a13da4feb`:

- foundation suite: **2,186 / 2,186 PASS**;
- canonical M9: **240 / 240 PASS**, 39/39 causal families;
- real Match View capture: **6 / 6 frames written**;
- camera follow-name regression: **3 / 3 real actors named**, zero failures;
- `git diff --check`: clean.

The foundation run still emits the repository's known off-tree pose and shutdown
resource-leak diagnostics. They are not counted as test failures and are not
misreported as presentation regressions.

## Management-intelligence recensus

M9 supplies certified authored tactic and first-mediator seams. It does not add
the learned-preference state, ask decomposition, training writer, adaptation
population proof, scouting freshness/history or derived knowledge UI described
by the management-intelligence census. No management-intelligence feature was
implemented in this integration.

## Training Play Designer

The causal tactic seams are now suitable future compiler destinations, but all
four load-bearing prerequisites remain missing: learned-preference authority,
semantic ask schema, fit evaluator and shared training writer. The visual
designer remains deferred; drawings cannot become rally authority.

## Signature vocabulary

The presentation work does not claim the tiered vocabulary design. Current
signature model/surge rendering remains legacy implementation. A future
migration still needs to separate capability, possessed vocabulary,
manifestation and downstream VFX, with demonstration-gated knowledge handled
later.

## Explicit decisions/debt

- `block_intent`: live consumer, no production writer; owner undecided.
- `fallback_lane`: compatibility schema with no live gameplay read.
- management-intelligence phases 2–9: not authorized or implemented.
- tiered signature persistence/generation/development: undecided.
- bottom diagnostic label compaction: visual polish debt.
- branch-specific Godot 4.7.2 capture workflow: excluded; repository toolchain
  remains 4.7.1 until separately decided.
