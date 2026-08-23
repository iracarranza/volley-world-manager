# D3 — first-draft construction status

The packet's own definition, quoted so the claim below is measured against it
and not against something easier:

> A complete, runnable causal first draft in which remaining problems can be
> investigated as failures of implemented systems rather than as intentionally
> missing architecture.

## Work-unit status

| unit | status | evidence |
|---|---|---|
| A0–A2 · M4 reception closeout | **already closed, not replayed** | `ENABLE_PHYSICAL_RECEPTION = true` at `9e2b55d`; `RALLY_MILESTONES.md` M4 **DONE**. The packet pins `6ce8f3b`, one commit earlier. |
| B0 · contact-authority census | **done** | `run_contact_authority_census.gd`, 600 rallies, 2,862 contacts, seven families, nine edges |
| B1 · serve | **closed, no change** | retired error draw has no reader; every fact from `_canonical_serve` |
| B2 · set | **closed, no change** | 517 of 517 sets consume a realised prefix by launch identity |
| B3 · attack | **closed, no change** | `551e29e` audited in scope; no second landing authority found |
| B4 · block | **one break repaired** | 100 of 100 touching home blocks met a superseded swing, up to 1.140 s late; both sides now 0 |
| B5 · platform closure | **closed** | one `PlatformContactModel.evaluate` call site, three families, no per-family coefficients |
| B6 · cross-family chain | **closed by identity** | all nine edges 100% same-launch after `authoritative_flight_id` reached serve/set/attack/block |
| C0 · action-window audit | **done** | `run_action_window_census.gd`; 45.9% of voli-legs were presentation's invention, 0 of 8,125 carried a duration |
| C1 · previous contacter clears | **built; now visible** | recovery debt published from `_add_event`; 273 contacts in 400 rallies carry it |
| C2 · setter transition overlap | **already built** | the hardcoded 0.68 window is now the real interception time; the transition setter takes the same head start the first ball takes from the serve |
| C3 · hitter approach overlap | **already built** | 335 sets publish a hitter approach start before the attack |
| C4 · block read/close | **already built** | 1,087 blocker journeys with real durations before contact |
| C5 · floor defence establishes | **built this pass** | `_establish_shape` walks all three defensive shapes instead of teleporting into them |
| C6 · early arrivals wait | **built this pass** | 4,130 of 4,184 journeys arrive early with 0.433 s mean slack; **0** stretched |
| C7 · phase boundaries sample state | **already built** | `ACTOR_CONTINUITY.md`; recovery/body/facing carried across phase rebuilds |
| D0 · integration walk | **done** | `run_first_draft_walk.gd` prints one rally end to end with launch lineage at every boundary |
| D1 · superseded event-window cleanup | **audited, nothing to remove** | see B6's legacy note: all three surviving legacy paths still serve live paired protocols |
| D2 · history/presentation audit | **partially closed** | traversal times and recovery debt now published; 46.4% of off-ball movement is still presentation's invention (FD-003) |
| D3 · checkpoint | **this file** | |

## Production authority

- **reception, controlled dig, attack coverage** — one shared `PlatformContactModel`, T1–T3 at the six authored magnitudes, all three feeding M5.
- **serve** — `_canonical_serve` forward launch search; the old pre-rolled error draw survives only to hold RNG order and has no reader.
- **set** — realised prefix in, one set ball out, on all three paths.
- **attack** — geometric attack, production on all three attack paths.
- **block** — one interaction on one ball; after this pass, on the *actual* ball.
- **continuous actors** — position, velocity, facing and recovery carried across
  phase rebuilds; off-ball journeys now carry their own duration and arrival.

## Certification

- **full suite** — see the commit message for the figure on the commit that
  landed it; no assertion fails.
- **`run_contact_authority_census.gd`** — 9 of 9 edges same-ball, 9 of 9
  same-lineage, 0 backwards in time.
- **`run_block_authority_probe.gd`** — PASS, 4 gates, both sides 0/0.
- **`run_continuous_action_probe.gd`** — PASS, 9 gates.
- **`run_rally_balance_probe.gd`** — dig 0.393, stuff 0.115, serve error 0.181,
  all inside their bands; contacts 4.796 and kill 0.659 outside their *advisory*
  targets, unchanged in character from the M4 promotion and not fitted.

### P2 — the platform families, re-certified after M6 and M7

The packet requires the existing paired probes to be re-run "to prove A0/A1 did
not reopen those families". A0/A1 were not touched here, but B4, B6, C5 and C6
all changed things those families sit downstream of, so the same requirement
applies to this pass. All three arms PASS, unchanged:

- **`run_reception_rollout_probe.gd`** — 14 gates, 2,800 rallies. 1,117
  successful physical receptions, 1,117 owning the shared launch, 0 fabricated,
  0 launch mutations, 0 prefix failures, 0 chain breaks, 0 bound violations. 32
  alternate interceptors and 164 intended misses, so the intended setter is
  still soft intent. Both serving sides exercised (568 / 549).
- **`run_coverage_rollout_probe.gd`** — 16 gates, including the one that matters
  most for B5: no owned coverage ball carries the retired hand-authored shape.
- **`run_overpass_action_probe.gd`** — 14 gates, including "later actor/action
  choice never mutates the incoming authoritative launch" and "every realised
  incoming segment is a prefix of the unchanged free flight", which are the two
  M5 invariants B6's identity work sits on top of.

- **M8 / M9** — not run. They are the next stage, not part of construction.

## Is the first draft complete?

**No, and the gap is named rather than hidden.** The packet's list of what a
complete first draft may *not* knowingly contain has five items. Four are clear:

- a missing ordinary contact family — none; seven families, all in the rubric.
- two production authorities for one physical question — none found by the
  census, and the one that existed (the home block's superseded swing) is
  repaired.
- a legacy path manufacturing a ball where free flight should own it — none;
  every edge is same-launch by identity.
- an architectural decision silently replaced by a guessed constant — none. No
  new magnitude was authored in this pass. Every number used
  (`_movement_time`, `TRAVEL_COST_PER_METER`, the lateral mode, the set flight
  window) already existed and already governed the same kind of journey.

The fifth is the open one:

> event-boundary player resets that make required M7 actions impossible

The serve leg still publishes nothing about the other eleven volis, and the
receive formation is a placement drawn at coordinates gameplay does not use. So
the *serve-to-reception* leg still has the shape C5 just removed from the
attack leg. It does not make a required M7 action impossible — the reception
still happens, from a consistent (if different) set of positions — but it is the
same defect, one leg upstream, and calling the draft complete while it stands
would be the kind of claim this repository keeps being warned about.

FD-001 and FD-004 in the debt ledger carry it, with the reason it was attempted
and backed out rather than shipped: doing it properly reorders a certified M4
path and moves reception quality, which is a decision with a measurable cost and
deserves its own pass.

## Next certification / repair priority

1. **FD-001 + FD-004 together** — decide whether `live_positions` is seeded from
   `_receive_formation_map` for the receiving side at rally start. That collapses
   the drawn and simulated receive shapes into one *without* reordering anything,
   and it is the last leg where a shape appears rather than forms. Measure
   reception quality and the side-out mix either side of it.
2. **FD-002** — publish `_cover_phase_map` on the coverage event. Cheapest of the
   three silences, same helper as the two that already work.
3. **FD-003** — once 1 and 2 land, narrow `_support_target_for_side` to a genuine
   no-information case and make it read as a hold rather than a journey.
4. **M8** — the canonical side-out. It is now worth running: the structural
   layer it inspects exists, so its findings will be about fidelity rather than
   about missing architecture, which is exactly the state the packet wanted
   before certification began.
5. **Task #140** — "Is 12% the right price for a shanked serve-receive?" That is
   the volleyball question under FD-005's rate observations, and it should be
   answered before anything is tuned toward the advisory bands.
