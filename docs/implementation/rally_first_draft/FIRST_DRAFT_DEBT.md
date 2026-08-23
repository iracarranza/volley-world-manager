# Rally first-draft debt ledger

Owned by the implementation run. Only failures and debt encountered or
deliberately deferred while executing this packet — not a copy of
`OUTSTANDING.md`.

## Entry template

```text
## FD-### — <short name>

Class: F0 / F1 / F2 / F3 / F4 / F5 / F6
Subsystem:
First observed at commit:
Reproduction command / fixture:
Expected semantic invariant:
Observed behavior:
Likely upstream owner:
Blocks later construction: yes / no
Why deferred:
Next diagnostic / repair:
Relevant existing spec/review:
```

---

## FD-001 — WITHDRAWN. The serve leg is published; the census was counting a leg that does not exist

Class: F3 (instrument defect, not engine defect)
Subsystem: `tools/run_action_window_census.gd`
Disposition: **withdrawn on evidence, not repaired**

The entry claimed the serve leg publishes nothing about the other eleven volis
and that presentation therefore invents them. It does not. A rally's first
contact has **no preceding interval** — playback draws a leg as
`event -> next_contact` and reads its targets off `next_contact` — so both
sides' serve-flight movement is published on the RECEPTION event, all twelve of
them, which is the only event where it can be drawn.

The resolver has known this the whole time. `_receive_formation_map`'s own note
records measuring 400 serves of 400 with no preceding flight, and says the map
is published on the reception "because playback draws a leg as `event ->
next_contact`".

So the 3,300 "silent" voli-legs on the SERVE row were an artefact of the census
scoring a leg that does not exist — a threshold measured against the wrong
distribution, committed by the instrument built to find those. The census now
carries a `no leg` column and excludes it.

What was real inside this entry was the receive formation being a *placement* at
coordinates gameplay did not use. That is FD-004, and it is repaired.

---

## FD-002 — attack coverage publishes no phase map

Class: F4
Subsystem: `_resolve_attack_coverage`
Reproduction: `godot --headless --path . --script res://tools/run_action_window_census.gd` — `ATTACK_COVERAGE` reads `published 0, silent 143` over 300 rallies
Disposition: **retained as non-blocking debt, with evidence**

The goal's test is whether this "still represents missing authoritative off-ball
state / actor-state substitution under packet first-draft criteria". It does not,
and the evidence is specific rather than a shrug:

- **No actor-state substitution.** Nothing resets or defaults a voli at the
  coverage boundary. `live_positions` carries across it, recovery debt is
  published on the coverage contact like every other, and C1's gate in
  `run_continuous_action_probe.gd` passes (273 contacts in 400 rallies carrying
  debt the next leg still owes).
- **No required M7 action is made impossible.** M7's own seven-item closure
  criterion is certified in full; coverage is not among the actions it names, and
  the actions it does name all overlap their preceding ball phases.
- **The interval is the block deflection**, 0.22–0.38 s measured in the D0 walk,
  on 13 events per 300 rallies.
- **Closing it would not close the class.** The remaining silence is 5,125
  voli-legs across five legs; coverage is 143 of them, 2.8%. This is one member
  of the FD-003 family, not a separable defect.

Its cost is presentation fidelity for a third of a second on a rare leg, which
the packet's §10 lists by name as permitted in a complete first draft.

Next repair: publish `_cover_phase_map` on the coverage event with the keep-alive
flight as the window — the same helper the block and transition legs already use.
Grouped with FD-003 rather than taken alone, because `_cover_phase_map` calls
`_reached_point`, so it moves volis and needs measuring with its siblings rather
than as three overlapping single-change measurements.

---

## FD-003 — presentation draws off-ball movement the resolver did not publish

Class: F4 — and explicitly permitted in a complete first draft
Subsystem: `scenes/components/tactical_court.gd` (`_support_target_for_side`)
Reproduction: as above — `volis presentation must invent: 5125 of 14736 (34.8%)`
Disposition: **open, non-blocking**

**The number was overstated and is corrected here.** This entry previously read
46.4%, which included FD-001's phantom serve leg. The measured figure with that
artefact removed is **34.8%**.

The packet's §10 permits a complete first draft to contain "presentation lag
behind newly authoritative state". This is exactly that: the simulation now
publishes traversal times, arrival windows, unified receiver geometry, per-contact
body positions and leg starts, and presentation has not caught up to any of it.

And the boundary is one-way, which is the part that matters for the completion
criterion. Verified rather than assumed: no script under `scripts/simulation`,
`scripts/models` or `scripts/managers` loads anything under `scenes/`, and
presentation never writes resolver state — `match_court_3d.live_positions` is the
court's own drawing copy, not the resolver's. Deleting `_support_target_for_side`
outright would change no gameplay number in any rally; it would change only what
is drawn. Presentation reconstructs no gameplay truth because it cannot.

Next repair: publish the acting side's off-ball map on the SET, ATTACK, BLOCK,
DIG and coverage legs, using `_establish_shape` and the existing phase maps, and
measure the five together. Then narrow the fallback to a genuine no-information
case and make it read as a hold rather than a journey.

---

## FD-004 — CLOSED. One receiver geometry, seeded before the serve

Class: F1 (two answers to one physical question) — repaired
Subsystem: `_receive_formation_map`, `_initial_home_positions`, `_initial_opponent_positions`
Disposition: **closed and certified**

The reception claim built `reception_origins` from `live_positions`, seeded from
the rotation grid or the plan's zone, while `_receive_formation_map` separately
published the shape the six actually take up. Gameplay believed one, the drawing
showed the other, and `result.initial_home_positions` — what `match_court_3d`
spawns actors at — was the gameplay one.

The formation is now seeded into `live_positions` at rally initialization, so it
is the spawn position, the claim's origin and the start of every later traversal
at once. The reception event publishes `_lineup_live_shape` — the volis' actual
state — instead of recomputing a second copy.

`tools/run_receive_geometry_probe.gd`, 500 rallies, 422 serve receptions:

```
bystanders that moved from spawn        0 of 2,110
worst displacement               0.000000 court units
receivers that travelled              411, mean 0.1367
serve -> reception lineage breaks       0
receptions stamped before the serve     0
```

A second home/opponent drift was found while tracing it and repaired in the same
pass: `_initial_home_positions` honoured a serve-receive zone whether or not it
was `enabled`, where `_initial_opponent_positions` had always checked.

Cost, measured and not fitted: dig 0.393 → 0.407, kill 0.659 → 0.611, contacts
4.796 → 4.827, every governed band still holding, reception quality unchanged at
0.434 to three decimals.

---

## FD-005 — contacts per rally and kill rate sit outside their advisory bands

Class: F5
Subsystem: whole-engine outcome mix
First observed at: M4 reception promotion (`9e2b55d`), unchanged by this run
Reproduction: `godot --headless --path . --script res://tools/run_rally_balance_probe.gd`
Observed: contacts per rally 4.796 against an advisory "above 6.0"; kill rate 0.659 against an advisory 0.45–0.50; ace rate 0.010 against 0.05–0.09
Likely upstream owner: reception outcome mix — roughly 12% of physical receptions floor, which was the recorded and deliberately unfitted consequence of M4's promotion
Blocks later construction: no
Why deferred: these are **advisory targets, not acceptance bounds**, and were recorded as observations at promotion. The bands the probe does gate on — dig rate 0.35–0.55, stuff 0.08–0.14, serve error 0.12–0.20 — are all inside. Fitting the architecture to move them is exactly what the packet forbids.
Next diagnostic: task #140, "Is 12% the right price for a shanked serve-receive?", which is a volleyball question and not a calibration one

---

## Post-draft clustering

1. ball/contact authority — *empty; B0/B6 closed every edge by launch identity*
2. causality/timing — *empty; the B4 repair closed the one violation found*
3. movement/actor continuity — *empty; FD-004 closed, FD-001 withdrawn*
4. responsibility/selection — *empty*
5. attack/block interaction — *empty*
6. home/opponent asymmetry — *empty; two drifts found and both repaired — the block's stale swing and the receive zone's `enabled` check*
7. tactical wiring — *not yet audited (M9)*
8. presentation/reporting — FD-002, FD-003 (one family)
9. calibration/balance — FD-005
