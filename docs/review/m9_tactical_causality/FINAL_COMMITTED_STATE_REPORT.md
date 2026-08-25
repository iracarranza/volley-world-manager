# M9 final committed-state certification report

## Identity and scope

- Accepted M8 baseline: `8bd62f028fcebbbfb1dd81fc949b645a9070c5eb`.
- Canonical M9 implementation measured: `78eb4614fa12057581919c571dc3081cb9e242ea` on `chatgpt/m9-tactical-causality`.
- Engine: Godot `4.7.1.stable.official.a13da4feb`.
- Presentation branch packet was not merged. `chatgpt/m9-tactical-ab` was audited and left unmerged.

The report commit itself adds documentation, corrected comments and receipts only;
it changes no executable gameplay. All gameplay and probe results below were
taken from clean committed trees at the two SHAs above. Canonical M9 was also
rerun at `78eb461` after its receipt commit: 240/240 causal gates and
2,178/2,178 foundation checks passed.

## M9 certification

`tools/run_m9_tactical_causality.gd` passed **240 gates**:

- C0 inventory: 39 unique reachable selectable families, complete source vocabulary.
- C1 typed round trips: every option across play, lineup, plan, assignment, zones, sheet and Team save ownership.
- C2 immutable pre-resolve handoff and editor-lens exclusions.
- C3/C4 consumer activation and first physical mediator.
- C5 M8 event/flight invariants on every live Clipboard trial.
- C6 all-option contrasts, interaction composition, both-side symmetry and negative controls.
- C7 populations: attack line/cross `n≥9`, close-line/cross wall `n≥8`, matched floor targets `n=72`, discipline/adherence `n=200`.

Classification moved from **28 CAUSAL / 8 PARTIAL / 3 STORED_ONLY / 0 DEAD / 0 AMBIGUOUS** to **39 CAUSAL / 0 / 0 / 0 / 0**. Zero population cannot pass. `block_intent` and `fallback_lane` are not among the 39 selectable families; their exact dispositions are in `LATENT_FIELD_AUDIT.md`.

## M8 authority regression

| Instrument | M8 `8bd62f0` | M9 `78eb461` | Result |
|---|---:|---:|---|
| Canonical side-out | 7 boundaries; 0 lineage/order/duplicate/body/reconstruction failures | same seven invariant gates; 0 failures | PASS |
| Block authority, 600 rallies | home 213 blocks/93 touching; opponent 217/103; 0 stale, 0 late | home 216/94; opponent 217/100; 0 stale, 0 late | PASS |
| Continuous action, 400 rallies | 4,393 journeys; 60 ran out; 0 stretched | 4,488 journeys; 60 ran out; 0 stretched | PASS |
| Full foundation suite | 2,178 / 0 | 2,178 / 0 | PASS |

The contact-authority census is diagnostic rather than a single pass counter. All attack and set families remain authoritative with zero breaks; block families remain authoritative by their own contact proof with zero breaks. The known body-proxy `ATTACK_COVERAGE/home` sample moved from 10 legs/1 >0.05 m gap to 11/2; worst gap stayed 0.085 m. This is not hidden as a green check and does not alter M8 contact/height ownership.

Playback continuity is likewise observational: 825→828 legs, total seam-height jumps 58→58, contacted block seams 0 breaks in both revisions, and balls passing an untouched wall 55→55 known discontinuities. Untouched balls not drawn to floor moved 64→73. The three small opponent `SET` seam diagnostics remain present (mean 0.032→0.031 m). These are existing presentation/terminal-flight debts, not tactical resolver authority and not fitted away.

## Before→after volleyball observations

Common-seed `tools/run_rally_balance_probe.gd`, 700 rallies per revision across both serving sides:

| Observation | M8 | M9 | Delta |
|---|---:|---:|---:|
| Contacts/rally | 4.814 | 4.801 | -0.013 |
| Kill rate | 0.630 | 0.623 | -0.007 |
| Swing balance (opponent/home) | 0.888 | 0.902 | +0.014 |
| Dig rate | 0.415 | 0.410 | -0.005 |
| Block touch rate | 0.830 | 0.822 | -0.008 |
| Stuff rate | 0.106 | 0.106 | 0.000 |
| Ace rate | 0.010 | 0.010 | 0.000 |
| Serve error rate | 0.181 | 0.181 | 0.000 |
| Reception quality mean | 0.434 | 0.434 | 0.000 |

Common-seed readiness observation, 80 rallies: side-out 0.50→0.55; attack attempts 74→73; terminal attacks 72→72; attack error 0.2703→0.2603; block touch 0.2432→0.2466; stuff 0.0541→0.0411; mean contacts 4.9875→4.9625. The denominator gate passed in both revisions.

These are observations, not acceptance targets. No M9 magnitude was fitted to historical kill, dig, stuff, side-out, rally-length or win-rate values. Machine-readable values are in `artifacts/m9-tactical-causality/committed_state_observations.json`.

## Ownership and anti-fabrication findings

- `block_intent`: save-restorable and materially consumed, but no production writer exists and runtime stays `Balanced`. Misleading coach/clipboard prose is corrected. It remains live-but-unowned debt; no dropdown or new Voli subsystem was invented.
- `fallback_lane`: serialized and syntax-validated, but has no UI/runtime writer and no live simulator read. The shadow helper of the same name is unrelated. It remains compatibility-only schema.
- Every promoted census row has an established selectable meaning and a decision/physical mediator; the census does not use either latent field to reach 39/39.

## `m9-tactical-ab`

Not merged. Its four-option probe is narrower than canonical certification, its branch carries unrelated pre-M8 changes/deletions, and its workflow changes PR policy while pinning Godot 4.7.2. See `M9_TACTICAL_AB_DISPOSITION.md`.

## Remaining debt outside M9

- Product/design must assign or retire `block_intent` ownership before any non-default production policy exists.
- Save-schema cleanup may eventually remove `fallback_lane` after migration analysis.
- Balance/readiness figures above remain tuning observations, not M9 defects by themselves.
- Known playback terminal-flight/body-proxy diagnostics and Godot shutdown leak warnings remain outside tactical causality.
- Repository-wide CI policy and a 4.7.1→4.7.2 toolchain decision remain separate work.

No human product decision blocks canonical M9 integration: both latent fields are truthfully excluded and recorded rather than fabricated.
