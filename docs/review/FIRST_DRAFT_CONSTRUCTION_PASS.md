# Rally first-draft construction pass — 2026-08-23

Status record for the construction pass ending at `570176d` on `claude/system-fit-serve-receive-von64k`.

This is a checkpoint, not a declaration that the first draft is complete. The pass closed M6, built the intended M7 machinery, repaired the one contact-authority break the census exposed, and reduced the remaining first-draft uncertainty to named actor-continuity debt.

## Work-unit result

| unit | result |
|---|---|
| A0–A2 / M4 | Already closed at `9e2b55d`; verified against current source, not replayed. |
| B0 | Runtime authority census complete: 600 rallies, 7 contact families, 9 canonical edges. |
| B1 serve | Closed on evidence; no production change required. |
| B2 set | Closed on evidence; no production change required. |
| B3 attack | Closed on evidence; no production change required. |
| B4 block | One authority break found and repaired. |
| B5 platform | Closed on evidence; shared platform authority retained. |
| B6 one-ball chain | Closed by authoritative launch identity/lineage. |
| C0 | Action-window census complete. |
| C1 | Existing recovery carry made externally visible. |
| C2 | Existing setter-transition machinery retained. |
| C3 | Existing hitter-approach machinery retained. |
| C4 | Existing blocker-preparation machinery retained. |
| C5 | Floor defence now establishes through traversal authority instead of appearing at target coordinates. |
| C6 | Traversal/window timing published; early arrivals wait rather than stretching travel time. |
| C7 | Existing continuous-event boundary machinery retained. |
| D0 | Whole-rally authority audit complete for constructed paths. |
| D1 | Duplicate/superseded ordinary contact authority audited and repaired where found. |
| D2 | Partially closed; remaining presentation reconstruction is FD-003 and depends on actor-continuity debt. |
| D3 | Integrated construction pass complete. |

## Commits

- `c1978e6` — correct stale M5 milestone row.
- `a2321af` — M6/M7 construction.
- `413eee5` — retake contact census on committed state.
- `570176d` — measured suite baseline.

## Certification at `570176d`

- Full suite: **2,139 PASS, 0 FAIL**.
- Focused certification: **57/57 PASS** across reception rollout (14), coverage rollout (16), overpass action (14), block authority (4), continuous action (9).
- Contact census: **9/9** canonical edges same authoritative ball; **9/9** same lineage; **0** backwards-time edges.
- Gated balance observations: dig `0.393`, stuff `0.115`, serve error `0.181`; all within their existing governed bands.

The aggregate suite count is not a historical performance target. Two checks were added and C5 changed sampled populations, so the PASS total is commit-local. Read the FAIL line and named gates, not a previous total.

## Substantive finding 1 — stale home block swing

The home block path intersected an attack trajectory that had already been superseded by the attack/block handoff.

Before repair:

- home touching blocks: `100 / 100` stale-authority cases in the focused probe;
- opponent touching blocks: `0 / 113`;
- the stale local also authored block time from the untruncated flight end, measured as much as `1.140 s` late.

Both symmetric paths already sliced a touched swing to the tape, but only the opponent path re-read the truncated result. The repair makes home re-read the same authoritative result. No volleyball decision changed and no magnitude was added.

## Substantive finding 2 — floor defence teleport

`_floor_phase_positions` produced a defensive shape that callers wrote directly into `live_positions`. Because `CoverageModel.choose_claimant` reaches from those positions, this was not merely presentation: the defence acquired gameplay coordinates without traversing to them.

C5 now establishes the shape through the same traversal authority used by other movement legs. Partial establishment remains partial.

Measured consequence, recorded rather than fitted:

- dig rate `0.387 -> 0.393`;
- contacts/rally `4.771 -> 4.796`;
- kill rate `0.661 -> 0.659`.

The teleport was relocation, not a simple defensive buff; walking from real positions slightly increased the measured dig rate.

## Remaining first-draft debt

The authoritative debt ledger remains `docs/implementation/rally_first_draft/FIRST_DRAFT_DEBT.md`.

### Movement / actor continuity

- **FD-001** — serve leg publishes no off-ball map for the other eleven volis.
- **FD-002** — attack-coverage leg publishes no off-ball phase map.
- **FD-004** — drawn receive formation and gameplay `live_positions` use different coordinates.

These are one upstream class: legs for which the resolver does not yet publish/advance the actor state presentation needs.

### Presentation

- **FD-003** — 46.4% aggregate of off-ball movement still requires presentation fallback. Re-measure only after the movement debt above changes; do not treat the aggregate as an independent gameplay fix.

> **Superseded after this record was written.** The 46.4% was an instrument
> artefact: the action-window census counted the serve's other eleven volis as
> invented, and a rally's first contact has no preceding interval for anybody to
> have moved in — both sides' serve-flight movement is published on the reception
> event. Corrected, the figure is **34.8%**. FD-001 is withdrawn on that evidence
> and FD-004 is closed and certified, which together made the first draft
> complete. See `docs/implementation/rally_first_draft/D3_FIRST_DRAFT_STATUS.md`
> and `C0_ACTION_WINDOW_CENSUS.md`. This file is left as the record of the pass
> ending at `570176d` rather than rewritten.

### Calibration

- **FD-005** — contacts/rally and kill/ace observations remain outside advisory targets. This is post-draft calibration/volleyball evaluation, not construction debt. No fitting was performed.

Ball/contact authority, causal timing, responsibility, attack/block interaction and home/opponent asymmetry are empty debt clusters at this checkpoint.

## Why FIRST_DRAFT_COMPLETE was not declared

The packet disallows knowingly retaining actor-state substitution in the canonical rally. Serve -> reception still has the same structural shape removed from floor defence: the receiving formation is drawn at coordinates gameplay does not physically occupy/reach from.

An attempted reception-time writeback was correctly rejected because the reception claim has already resolved by then; writing the formation there moves the receiver away from the ball they just contacted.

Smallest next investigation: determine whether `_receive_formation_map` already owns reception responsibility/reach geometry. If so, seed receiving-side `live_positions` from it before the serve begins so drawn and simulated receive geometry become one fact without rewriting post-contact history. If not, trace the actual pre-serve geometry authority and treat unification as an M4 semantic migration rather than protecting old rates.

After FD-001/FD-004 (and FD-002 if still first-draft-blocking) are resolved and actor-state substitution is gone, mark the causal first draft complete and execute M8 canonical side-out certification.

## Construction policy preserved

This pass introduced no new authored magnitude, widened no gate, fit no outcome rate, and did not restore endpoint/presentation authority. Ordinary implementation defects were repaired and work continued; certification/distribution observations were recorded as observations unless an existing explicit bound governed them.
