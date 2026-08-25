# M9 tactical causality — scope and authority

## Purpose

M9 makes every **player-selectable tactical instruction** auditable from the control that authors it to an observable, authoritative consequence. The implementation is now complete; this packet records the authority, causal map and certification. It does not rebalance tactics.

A tactic is in census when the shipped UI lets a manager select, drag, toggle, or set it and it purports to affect a match or tactical training. Debug-only rotation selection, playback speed/layers, camera/view/phase selectors, opponent adaptation developer controls, roster selection and substitutions are not tactics. Team principles are a separate identity system. `DefensivePlan.block_intent` is a live simulator input but has no runtime writer, so it is latent compatibility state rather than a player-selectable tactic.

## Authority boundary

Claude's M8/§5 rally implementation remains authoritative for contacts, ball flights, event order, physical time, live body position, reachability, decisions and outcomes. M9 may pass existing authored inputs into that authority, publish attribution terms, and add matched certification instruments. It must not:

- replace or reconstruct a resolver decision;
- change contact, trajectory, movement, timing, reachability or outcome semantics;
- introduce a second tactical resolver in UI, playback, render or test code;
- tune rally rates while wiring causality;
- treat a staged tableau as evidence of gameplay causality.

The storage authority is `Team.tactic_sheet`, the rotation lineups, saved offensive plays/active play IDs, and per-rotation defensive plans. `GameManager.resolve_active_rally()` is the handoff seam: it snapshots those resources into `RallySimulator.resolve()`. Tests must compare resolver-published facts from identical initial state and seeds.

## Classification contract

| Class | Required evidence |
|---|---|
| **causal** | UI writes durable state; the live resolver (or, for explicitly training-only controls, the training session model) consumes it; it changes a decision or physical term; the effect can be observed in authoritative output. |
| **partial** | Some chain exists, but an option/phase, persistence leg, resolver path, or attributable physical consequence is missing. |
| **stored-only** | UI value persists, but no gameplay/training authority consumes that value. |
| **dead** | A selectable-looking control does not durably author the intended value, or the authored value has no reachable downstream path. |

“Code mentions the field” is insufficient. Presentation, summaries, preview drawings and commentary are not consequences. A numerical outcome difference alone is also insufficient without a decision/physical mediator.

## Anti-fabrication rule

The census does not create product semantics. A selectable instruction may become causal only when existing UI language, design authority, or an established volleyball decision defines what it governs. If no such authority exists, the truthful resolution is an explicit product decision or removal/disablement of false agency—not a new simulation branch invented to improve the census. Latent, unowned fields remain outside the selectable census and are recorded as debt.

## Observation and regression rule

After structural causality, measure contacts per rally, serve error/ace, reception quality, kill, block touch/stuff, dig, rally length, side-out, and existing balance/swing observations. These are observations unless an already-existing explicit acceptance bound makes one a gate; M9 never fits rates to preserve historical values. Regression evidence is the actual population and invariant result from the canonical M8 authority, side-out, movement/continuity, and full-suite instruments. A changed aggregate check count alone is not evidence.

## Final headline

The corrected reachable census is 39 families: 28 causal, 8 partial and 3 stored-only before implementation; 39 causal afterward. The original packet accidentally preserved a total of 39 while counting two non-selectable schema values (`fallback_lane`, derived `secondary_hitter_id`) and missing/squashing real independent selectors. The executable rows in `artifacts/m9-tactical-causality/` supersede that stale accounting.

All Match-board and Clipboard values now reach typed state, an explicit pre-resolution decision/positioning seam, and existing M8 physical authority. Drill zone remains intentionally training-only. `block_intent` remains live-but-unowned compatibility state; `fallback_lane` is serialized/validated but unread compatibility schema. Neither is selectable or an M9 census row. Clipboard phase/view remain editor lenses and are deliberately excluded from the resolver manifest.

## Audit method

The census was produced by tracing UI population and handlers in `scenes/main/main.gd` and `scenes/screens/training_screen.gd`, authoring in `scenes/components/worksheet.gd`, resource serialization, `GameManager.resolve_active_rally()`, exact field reads across `scripts/simulation/`, and authoritative event/metadata publication. `tools/run_m9_tactical_causality.gd` now executes that inventory, typed round trips, negative controls, pure first-mediator contrasts, live home/opponent activation and population guards. Read-only commands are recorded in `04_HANDOFF.md`.
