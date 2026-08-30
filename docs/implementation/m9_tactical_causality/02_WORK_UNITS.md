# M9 work units

**Disposition: complete.** The checklist below is retained as the implementation sequence. Executable evidence is `tools/run_m9_tactical_causality.gd`; results are under `artifacts/m9-tactical-causality/`.

Work units are ordered to improve evidence before behaviour. Every implementation PR must name the census rows it changes and must stay inside the M8 boundary.

## M9-0 — freeze the executable census

- Encode every option and store field from `01_TACTIC_CAUSAL_MAP.md` in a read-only audit instrument.
- Fail when a UI option disappears, appears without a census row, or serializes to an unrecognised value.
- Emit machine-readable rows: control, option, store path, consumer symbol, classification and certification ID.
- Do not instantiate presentation scenes as authority.

**Done:** census and current classifications match source; unknown option is a hard failure.

## M9-1 — persistence and handoff proof

- Round-trip each play, lineup, defensive plan and tactic sheet through career save/load.
- At `resolve_active_rally()`, capture a read-only input manifest (IDs/values only) before calling the resolver.
- Prove rotation changes select the corresponding play and defensive plan and preserve authored custom receive shapes.
- Never let the manifest mutate resources or feed an alternate resolver.

**Done:** exact authored value reaches the resolver snapshot after reload for every match tactic.

## M9-2 — attribution publication

- For each existing causal consumer, expose a stable decision term in authoritative trace metadata: requested value, effective value, adhered/overridden, mediator, physical target/term.
- Prefer existing decision events and metadata; do not add commentary inference.
- Required domains: serve, receiver claim, setter choice/release, attack option/tempo/lane, block formation/hands, floor claim, emergency setter, coverage/transition.

**Done:** every causal row can point to an authoritative event field before looking at point outcome.

## M9-3 — close offensive metadata gaps

Decide, with design approval, one of two explicit outcomes per field:

- make assignment priority, Secondary, authored start and fallback lane causally distinct through existing decision/physical seams; or
- remove/rename the selectable promise and migrate stored data.

Do not manufacture a bonus merely to make a field “causal.” Secondary must mean a documented fallback order; authored starts must respect live position and §5 continuous action rather than teleporting a body.

**Done:** no offensive field remains partial/stored-only without an accepted removal decision.

## M9-4 — close defensive vocabulary gaps

- Map every seam/base/short-ball label to an explicit decision and geometric consequence, or reduce the UI vocabulary to what the resolver actually distinguishes.
- Wire emergency-responsibility labels into the already-authoritative pursuit/emergency-setter/coverage decisions, without duplicating those decisions.
- Expose `block_intent` only if product design confirms it is a manager choice; otherwise keep it out of the player-selectable census.

**Done:** option-level A/B certification exists for every remaining label.

## M9-5 — reconcile Clipboard and Match board

- Establish one canonical tactical vocabulary/adaptor. Clipboard instructions must compile into existing plan/play inputs or be clearly labelled training-only.
- Implement Attack and Floor behaviour consumers only through existing setter/attack/coverage decisions.
- Define `close line/cross` as formation geometry, separate from `soft/kill block` hands intent.
- Give placement coordinates and net priorities a documented consumer or remove the match-affecting promise.
- Keep drill zone and generic drill activities explicitly training-only.

**Done:** no duplicate instruction with conflicting stores, and each Clipboard option declares Match, Training, or both.

## M9-6 — matched certification suite

Build deterministic paired trials described in `03_CERTIFICATION.md`, then run distributional sweeps only after structural gates pass. Certification instruments must call normal `GameManager`/resolver entry seams with snapshots, not reproduce simulator formulas.

## M9-7 — UX receipts and documentation

- Show requested/effective/overridden language only from authoritative attribution.
- Avoid prose that tells the player how to interpret an unverified outcome.
- Update the census totals and handoff with actual test/artifact paths.

## Parallelism

M9-0/1 can proceed independently of presentation work. M9-2 can be split by serve/reception, offence, block and floor domains, but changes touching `rally_simulator.gd` require M8-owner coordination. M9-3/4/5 require design decisions before implementation. M9-6 harness work can begin against current causal rows without changing simulation.

## Completion receipts

- M9-0: 39-row executable vocabulary/source census; unknown/missing vocabulary and zero populations fail.
- M9-1: typed round trips for play, lineup, plan, assignment, zones and sheet; sheet is included in `Team` save data; immutable handoff manifest added.
- M9-2: serve called/effective risk, attack tactical decision, block geometry/hands and floor target attribution are published at authoritative events/results; existing causal telemetry remains in place.
- M9-3: priority/Secondary feed feasible option ordering; authored start feeds physically bounded approach intent. `fallback_lane` is correctly excluded as non-selectable latent schema.
- M9-4: every base/seam/short/emergency label is distinct at a shared decision/geometry seam.
- M9-5: identity-safe shared adapter consumes all 13 behaviours, placement and four priorities. Drill zone remains explicitly training-only.
- M9-6: structural, live symmetric, negative, interaction and M8 invariant gates run through the normal manager/resolver handoff.
- M9-7: final causal summary, interaction matrix and before/after/certification JSON are present.
