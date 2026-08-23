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
| B2 · set | **closed, no change** | every set consumes a realised prefix by launch identity |
| B3 · attack | **closed, no change** | `551e29e` audited in scope; no second landing authority found |
| B4 · block | **one break repaired** | 100 of 100 touching home blocks met a superseded swing, up to 1.140 s late; both sides now 0 |
| B5 · platform closure | **closed** | one `PlatformContactModel.evaluate` call site, three families, no per-family coefficients |
| B6 · cross-family chain | **closed by identity** | all nine edges 100% same-launch after `authoritative_flight_id` reached serve/set/attack/block |
| C0 · action-window audit | **done** | `run_action_window_census.gd`; 0 of 8,125 placed volis carried a duration. Its first headline of 45.9% invented was its own artefact — corrected to **34.8%** once the serve's non-existent leg was excluded |
| C1 · previous contacter clears | **built; now visible** | recovery debt published from `_add_event`; 273 contacts in 400 rallies carry it |
| C2 · setter transition overlap | **already built** | the hardcoded 0.68 window is now the real interception time; the transition setter takes the same head start the first ball takes from the serve |
| C3 · hitter approach overlap | **already built** | 335 sets publish a hitter approach start before the attack |
| C4 · block read/close | **already built** | 1,087 blocker journeys with real durations before contact |
| C5 · floor defence establishes | **built this pass** | `_establish_shape` walks all three defensive shapes instead of teleporting into them |
| C6 · early arrivals wait | **built this pass** | 4,130 of 4,184 journeys arrive early with 0.433 s mean slack; **0** stretched |
| C7 · phase boundaries sample state | **already built** | `ACTOR_CONTINUITY.md`; recovery/body/facing carried across phase rebuilds |
| D0 · integration walk | **done** | `run_first_draft_walk.gd` prints one rally end to end with launch lineage at every boundary |
| D1 · superseded event-window cleanup | **audited, nothing to remove** | see B6's legacy note: all three surviving legacy paths still serve live paired protocols |
| D2 · history/presentation audit | **closed for authority; fidelity open** | the boundary is one-way and verified; 34.8% of off-ball movement is still drawn from an invented target, which §10 permits by name (FD-003) |
| D3 · checkpoint | **this file** | |
| M8 · canonical side-out | **structural PASS** | seed 76005 on the vertical-slice roster, 8 contacts, 7 boundaries, 7/7 gates — see `M8_CANONICAL_SIDEOUT.md` |

## Production authority

- **reception, controlled dig, attack coverage** — one shared `PlatformContactModel`, T1–T3 at the six authored magnitudes, all three feeding M5.
- **serve** — `_canonical_serve` forward launch search; the old pre-rolled error draw survives only to hold RNG order and has no reader.
- **set** — realised prefix in, one set ball out, on all three paths.
- **attack** — geometric attack, production on all three attack paths.
- **block** — one interaction on one ball; after this pass, on the *actual* ball.
- **continuous actors** — position, velocity, facing and recovery carried across
  phase rebuilds; off-ball journeys now carry their own duration and arrival.

## Certification

- **full suite** — see the entry below. The first run over this pass's own final
  state found **1 of 2,141 failing**, and it was worth having: the movement
  agreement gate had been broken by M8's own new published field, and under that
  sat a real home/opponent drift. Both repaired, neither by touching a band. See
  `docs/review/BODY_CONTACT_ENDPOINT.md`.

  The earlier figure of **2,139 pass, 0 fail** at `413eee5` predates M8's
  instruments and is not the certification for this state. The count is not
  attributable in either case: two checks were written this pass and C5 changed
  which balls come up, so every sampling gate draws against a different
  population. The FAIL line is what was read.
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

**Yes.** Tested against the packet's own list rather than a looser one.

A complete first draft may **not** knowingly contain:

| forbidden | status |
|---|---|
| a missing ordinary contact family | none — seven families, all in the rubric (B0) |
| two production authorities for one physical question | none — 9/9 edges same ball *and* same lineage; the last known duplicate, the receive geometry, closed with 0 of 2,110 bystander displacement |
| a legacy path manufacturing the ball where free flight should own it | none — every published ball carries a launch identity |
| event-boundary player resets that make required M7 actions impossible | none — all seven of M7's own done-when items certified by `run_continuous_action_probe` |
| an architectural decision silently replaced by a guessed constant | none — no new authored magnitude in this pass or the two before it |

And it explicitly **may** contain, by §10: incorrect movement magnitudes inside
a complete path, a failed symmetry gate, a poor outcome distribution, rare-state
defects, and **presentation lag behind newly authoritative state**.

That last clause is what disposes of the largest open item. FD-003 — 34.8% of
voli-legs drawn from a target the resolver did not publish — is presentation lag
by definition: the simulation now publishes traversal times, arrival windows,
unified receiver geometry, per-contact body positions and leg starts, and the
drawing has not caught up to any of it.

### The one test that settles D2

The completion criterion is that presentation no longer **reconstructs gameplay
truth**. Verified rather than argued:

- no script under `scripts/simulation`, `scripts/models` or `scripts/managers`
  loads anything under `scenes/`;
- presentation never writes resolver state — `match_court_3d.live_positions` is
  the court's own drawing copy, not the resolver's;
- deleting `_support_target_for_side` outright would change **no gameplay number
  in any rally**. Every rally would resolve identically; only the drawing would
  differ.

Presentation reconstructs no gameplay truth because the dependency is one-way
and it cannot. What it does is invent a *drawing* where simulation is silent,
which is fidelity debt and is named in §10.

### What was open at the last checkpoint, and what happened to it

- **FD-001 — withdrawn on evidence.** The claim that the serve leg publishes
  nothing was an artefact of this pass's own census scoring a leg that does not
  exist. A rally's first contact has no preceding interval; both sides'
  serve-flight movement is published on the reception, all twelve.
- **FD-004 — closed and certified.** One receiver geometry, seeded at rally
  initialization, 7 gates.
- **FD-002 — retained, proven non-blocking** against the packet criteria: no
  actor-state substitution, no required M7 action made impossible, 13 events per
  300 rallies over a third of a second, and 2.8% of a class it cannot close
  alone.

## Next certification / repair priority

1. **FD-002 + FD-003 together** — publish the acting side's off-ball map on the
   SET, ATTACK, BLOCK, DIG and coverage legs through `_establish_shape` and the
   existing phase maps, and measure the five as one change. Each calls
   `_reached_point`, so each moves volis; measuring them separately would be
   three overlapping distribution measurements of one repair. Then narrow
   `_support_target_for_side` to a genuine no-information case and make it read
   as a hold rather than a journey.
2. **M8's visual layer** — the structural layer passes and cannot go further
   headless. This needs the app running and a person watching, which is what
   P5's own note about localizing a visual failure is for. What the structural
   pass establishes is that if a viewer sees something wrong in seed 76005, the
   simulation is not where it came from.
3. **M9 tactical A/B** — not started. The packet wants each tactic to change a
   predicted *intermediate mechanism*, stated before running, not a terminal
   rate.
4. **Task #140** — "Is 12% the right price for a shanked serve-receive?" That is
   the volleyball question under FD-005's rate observations, and it should be
   answered before anything is tuned toward the advisory bands.
5. **The home/opponent dig gap**, observed at 0.504 against 0.325 after the
   receive-geometry migration, widened from 0.445/0.350. That belongs to the
   held symmetry work (tasks #62–#64), and fitting it is forbidden here.
