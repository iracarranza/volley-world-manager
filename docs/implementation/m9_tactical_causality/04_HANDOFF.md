# M9 handoff

## Current disposition

M9 is implemented and certified. The corrected census is 39 reachable player-selectable families: 28 causal, 8 partial and 3 stored-only before; 39 causal after. No contact, trajectory or outcome authority was replaced and no calibration target was fitted.

Highest-value repairs were shared seams: Team save ownership for the Clipboard, identity-safe routing between tray/player/rotation namespaces, an immutable pre-resolve receipt, and one shared pre-resolution intent adapter used by both teams. Clipboard attack/floor/placement/priorities and every defensive vocabulary label now reach authoritative match decisions/positions.

## Exact implementation seams

1. **Authoring:** `scenes/main/main.gd`, `scenes/screens/training_screen.gd`, `scenes/components/worksheet.gd`.
2. **Durable models:** `scripts/models/offensive_play.gd`, `hitter_assignment.gd`, `rotation_lineup.gd`, `defensive_plan.gd`, `defensive_assignment.gd`, `defensive_zone.gd`, `tactic_sheet.gd`, and their parent Team/career serialization.
3. **Snapshot handoff:** `scripts/managers/game_manager.gd::resolve_active_rally()`.
4. **Authority:** existing decisions and movement/contact paths under `scripts/simulation/`, especially setter option selection, coverage claims, block formation/hands, pursuit and continuous movement.
5. **Evidence:** authoritative rally events/metadata and deterministic test tools—not tactical court drawings, broadcast scenes or commentary.

Any work at seam 4 must be coordinated with the M8 owner. Prefer adapters and attribution around existing decisions. Never copy a formula into a test/render tool.

## Resolved design decisions

- Secondary is the named fallback behind Primary; assignment priority orders other feasible options.
- Authored attack start is a requested approach mark passed through continuous `project_toward`, never an origin teleport.
- `fallback_lane` is serialized and syntax-validated but has no runtime writer or live read; it remains compatibility-only schema outside the census.
- Seam/base/short labels map to explicit, distinct geometry; emergency labels add bounded preferences to existing second-contact/coverage selectors.
- Clipboard composes with Match-board state at decision/positioning seams; it does not replace plan/play resources.
- close line/cross are wall-formation calls; soft/kill are hands calls.
- `block_intent` is a live-but-unowned compatibility term. Saves/tests can set it and the resolver consumes it, but production has no writer and stays Balanced. It is ownership debt, not a manager dropdown task.

## Implementation result

See `docs/review/m9_tactical_causality/CERTIFICATION_SUMMARY.md` for all 39 final chains, `INTERACTION_MATRIX.md` for precedence/conflicts, `LATENT_FIELD_AUDIT.md` for the two excluded fields, and `FINAL_COMMITTED_STATE_REPORT.md` for exact committed-state regression and observations.

## Read-only audit commands used

```bash
find .. -name AGENTS.md -print
rg -n -i "tactic|strategy|rotation|serve target|block scheme|defense" scripts scenes docs tests
rg -n "class_name (Tactical|Defensive|Rotation|Play)|current_defensive_plan|active_play|serve_target|serve_risk|block_strategy|floor_system|setting_system|second_setter|responsibil|coverage|tempo" scripts scenes/main/main.gd
rg -n "\\.FIELD\\b|\\bFIELD\\b" scripts/simulation scripts/models scripts/managers/game_manager.gd
rg -n "zone_for\\(|zones_for\\(|setter_release_target\\(|defender_position\\(|fallback_lane|secondary_hitter_id|assignment\\.priority" scripts/simulation
rg -n "tactic_sheet|TacticSheet|zone_priorities|placements|behaviour_of\\(|behaviours_for\\(|drill_zone" scenes scripts
```

`FIELD` was iterated across every serialized offensive, lineup, defensive-plan, defensive-assignment and zone field. The audit found no applicable `AGENTS.md`. Implementation also necessarily changes the typed models, GameManager handoff, existing simulation decision seams, one pure adapter, the dedicated tool, and M9 artifacts/review docs. Concurrent presentation files remain excluded.

## Verification performed / final run requirements

- Project import/parse: green with repository Godot 4.7.1.
- M9 C0–C6 executable instrument: green, with live both-side population for all 13 Clipboard behaviours and adversarial negative/interaction checks.
- Typed career/team, rotation/play/plan/assignment/zone/sheet round trips: green.
- Canonical M8 authority populations, before→after observations and the full suite are recorded in `docs/review/m9_tactical_causality/FINAL_COMMITTED_STATE_REPORT.md`; any gated failure blocks closure.

## Handoff completion checklist

- [x] Scope and authority frozen.
- [x] Every current player-selectable tactic family censused end to end.
- [x] Current classification and option-level gaps recorded.
- [x] Work units and certification gates specified.
- [x] Exact protected implementation seams named.
- [x] M9 code implemented through existing pre-resolution decision seams.
- [x] M9 certification artifacts generated under `artifacts/m9-tactical-causality/`.
- [x] Final all-row summary and interaction matrix written under `docs/review/m9_tactical_causality/`.
