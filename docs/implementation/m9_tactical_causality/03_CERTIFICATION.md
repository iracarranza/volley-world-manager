# M9 certification

**Status: executable gates green.** Run `godot --headless --path . --script res://tools/run_m9_tactical_causality.gd`. The runner writes `artifacts/m9-tactical-causality/certification.json` plus stable before/after censuses. The human-readable result is `docs/review/m9_tactical_causality/CERTIFICATION_SUMMARY.md`.

## Principle

Certification proves **causal mediation**, not merely correlation. Each test holds roster, opponent, rotation, match state, feature flags and seed fixed; changes exactly one authored tactic; resolves through the normal gameplay handoff; and compares authoritative decisions/positions/trajectories. Presentation and commentary are never evidence.

Certification also does not invent semantics. A selectable instruction without an established governing meaning must receive a product/design decision or be removed/disabled as false agency. A latent field with no player writer cannot pass merely because a diagnostic fixture can set it.

## Gate stack

### C0 — inventory

Every reachable player option has exactly one census entry and classification. Serialized enums/strings and UI options agree. Unknown, renamed and orphaned values fail.

### C1 — round trip

For every option: author through the same model method as UI, save, reload, and assert exact typed value in the correct rotation/team resource. Assert no adjacent tactic changed.

### C2 — handoff

Intercept the immutable input manifest immediately before `RallySimulator.resolve()`. Assert selected rotation, called play, lineup/system, defensive plan and tactic sheet values equal the reloaded store.

### C3 — consumer activation

The authoritative trace must publish the relevant requested value and identify its consumer decision. A field that only appears in a generic input dump fails this gate.

### C4 — physical mediator

The paired trace differs at the first intended mediator, not at an earlier unrelated fact:

| Domain | Required first mediator |
|---|---|
| Serve target/risk | serve decision aim/risk, then outgoing trajectory/error judgment |
| Receive geometry | claimant/intent target/arrival margin |
| Setter release/system | setter identity or release movement/contact target |
| Offensive lane/tempo/order | setter option/selection, approach target/timing, set trajectory |
| Block | participation/commitment/closing target/hands intent |
| Floor/transition | defender/pursuer/emergency-setter choice, intent target and arrival |
| Training-only | generated drill activity/focus and resulting training input |

### C5 — invariants

Both arms must retain legal rotations, monotonic event times, contact/ball lineage, one outgoing ball per contact where required, published body contact positions, and §5 continuous movement. A tactic test that passes by breaking an M8 invariant fails.

### C6 — option contrast

Use paired or multi-arm seeds chosen for an opportunity where the instruction can apply. Required contrasts include every UI option, not just extremes. Report activation denominator separately from effect denominator. “No opportunity” is skipped evidence, never “no effect.”

### C7 — distribution sanity

After structural proof, run a common-seed population. Report activation, adherence/override, first-mediator delta and downstream result with confidence intervals. This is a detection gate for inert/saturated/inverted controls, not a calibration mandate. M9 does not tune rates.

## Observation set

After causal certification, record before→after contacts/rally, serve error/ace, reception quality, kill, block touch/stuff, dig, rally length, side-out and existing swing/balance readings where instruments exist. These figures are observations unless an existing explicit acceptance bound makes one a gate. Do not calibrate M9 magnitudes to reproduce the baseline.

## Regression set

Run the canonical contact and block authority instruments, canonical side-out, relevant movement/continuous-action and playback diagnostics, and the full foundation suite. Record populations, FAIL lines and invariant results. Check-count movement alone is not regression evidence.

## Required certification matrix

- All five lanes; all four tempos; Primary/Secondary/Option/Decoy and priority.
- Both setting systems with legal second-setter identities.
- Four serve targets and at least low/neutral/high serve risk.
- Receive and floor centre, radius, priority and enabled toggles.
- Three block strategies, participation on/off, every seam option.
- Three floor systems, three depth states, two short-ball postures, three block–defence relationships.
- Every base, short-ball, emergency, coverage and second-contact label; all numeric priorities/toggles.
- All 13 Clipboard behaviours, four net zones/priorities, and representative placements.

## Negative controls

- Playback speed, camera mode, commentary placement and renderer must leave resolver input/output byte-equivalent.
- Clipboard phase/view must not affect a rally.
- A tactic for a player not on court must not alter live decisions.
- An instruction with no opportunity must publish non-activation, not fabricate a consequence.
- Reloaded and unreloaded runs must match.

## Classification exit rules

- Promote **partial/stored-only → causal** only when C0–C6 pass.
- Mark **dead** when the control cannot reach durable state or its downstream seam is unreachable; do not retain “partial” indefinitely.
- Removal is valid completion when product language stops promising an effect and old saves migrate safely.
- Any M8 invariant regression blocks the entire M9 packet regardless of tactical contrast.

## Artifacts

Each certification run writes a compact JSON/JSONL manifest containing revision, Godot version, test ID, seeds, input delta, activation, requested/effective instruction, first mediator, invariant results and event references. Human summaries link that artifact; screenshots are optional presentation review and never certification.

The final instrument emits revision/Godot identity, all census rows and counts, per-gate populations, live home/opponent seeds and activation counts, first-mediator names, negative controls, invariant results and failures. A `population == 0` gate cannot pass.
