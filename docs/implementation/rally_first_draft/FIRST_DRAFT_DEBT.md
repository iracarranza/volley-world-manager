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

## FD-001 — nothing is published about the other eleven volis during the serve

Class: F4
Subsystem: off-ball movement / phase maps (`rally_simulator.gd`)
First observed at: this run's C0 census
Reproduction: `godot --headless --path . --script res://tools/run_action_window_census.gd` — the `SERVE` row reads `published 0, silent 3300`
Expected semantic invariant: for each canonical leg, the resolver can state why every on-court voli is or is not moving (packet C0)
Observed: the serve leg publishes no phase map at all, so `tactical_court._support_target_for_side` invents a target for eleven volis out of their base position and the action point — presentation authoring movement the resolver never decided
Likely upstream owner: `_receive_formation_map` and the serving side's own transition
Blocks later construction: no
Why deferred: the receive formation is presently a **placement** (`progress 0.0`), and it is also the definition of where the receivers stand for the reception feasibility check. Turning it into a journey taken during the serve flight moves reception quality directly, which is a change worth its own measurement rather than a rider on C5's.
Next diagnostic: extend `_establish_shape` to the receive formation with the serve flight as the window, then re-run the balance probe for reception quality specifically
Relevant spec: `05_CONTINUOUS_ACTION_AND_INTEGRATION.md` C5, `OFF_BALL_MOVEMENT.md`

---

## FD-002 — attack coverage publishes no phase map

Class: F4
Subsystem: off-ball movement (`_resolve_attack_coverage`)
First observed at: this run's C0 census
Reproduction: as above — the `ATTACK_COVERAGE` row reads `published 0, silent 110`
Expected semantic invariant: same as FD-001
Observed: the coverage leg names no off-ball targets; all eleven non-actors are presentation's invention
Likely upstream owner: `_resolve_attack_coverage`
Blocks later construction: no
Why deferred: it is the cheapest of the three silences and it was still left, on purpose. Publishing `_cover_phase_map` here is not a reporting addition — the map calls `_reached_point`, which moves volis and writes `live_positions`, so it is the same C5 behaviour change applied to a third leg. FD-001, FD-002 and FD-004 are one shape of repair ("this leg publishes no off-ball map, so presentation invents it and nobody walks anywhere"), and closing them one at a time means three separate distribution measurements of three overlapping changes. They should move together and be measured once.
Next diagnostic: publish `_cover_phase_map` on the coverage event with the keep-alive flight as the window, in the same pass as FD-001

---

## FD-003 — presentation still invents 46.4% of off-ball movement

Class: F4
Subsystem: `scenes/components/tactical_court.gd` (`_support_target_for_side`)
First observed at: this run's C0 census
Reproduction: as above — the summary line `volis presentation must invent: 8229 of 17734 (46.4%)`
Expected semantic invariant: "presentation may not invent movement targets because the resolver did not publish them" (`01_TARGET_AUTHORITY_STATE` §9)
Observed: a fallback in the tactical court derives a target from base position and action point for any voli the resolver did not name
Likely upstream owner: this is the *aggregate* of FD-001, FD-002 and the un-mapped volis on the SET/DIG legs; it closes as they do
Blocks later construction: no
Why deferred: the fallback cannot be removed before the maps that would replace it exist, and removing it early would leave volis frozen rather than wrongly placed — a worse failure, and one that hides the real gap instead of surfacing it
Next diagnostic: close FD-001 and FD-002, re-measure, then narrow the fallback to a genuine "no information" case and make it visibly a hold rather than a journey

---

## FD-004 — the drawn receive shape and the simulated one are different coordinates

Class: F4
Subsystem: `_receive_formation_map`, `_initial_home_positions`, `_initial_opponent_positions`
First observed at: this run's C0 census; the second half found while attempting the repair
Reproduction: `godot --headless --path . --script res://tools/run_action_window_census.gd` — `RECEPTION` publishes 2,904 targets and only 1,452 carry a duration
Expected semantic invariant: C5 — receivers establish from their actual starting positions before the ball is struck, and one physical fact has one answer

Observed, and it is worse than the census row suggests:

1. `_receive_formation_map` publishes where the six *stand* to receive — passers on their seams, front row off the passing lanes, setter at the release — with `progress: 0.0`. Nobody moves there; they appear there.
2. **Gameplay does not believe that map.** It writes nothing into `live_positions`, which is seeded by `_initial_home_positions` from the rotation slot or the defensive plan's `SERVE_RECEIVE` zone. So the reception claim and the receiver's reach are computed from a *different* set of coordinates than the ones drawn.

Likely upstream owner: the receive leg as a whole — FD-001 and FD-004 are two halves of one repair
Blocks later construction: no

Why deferred — and this one was attempted and backed out deliberately:

The obvious fix is to walk the six into the formation during the serve's flight and write the result back to `live_positions`. It cannot be done where the map is published: the formation is attached to the **reception** event (correctly, because playback draws a leg as `event → next_contact`), and by then the receiver's claim and reach have already been resolved and `live_positions[receiver.id]` holds their actual contact position. Writing the shape back there would move the receiver off the ball they just played.

Doing it properly means establishing the shape *before* the reception claim, which reorders a certified M4 path and changes reception feasibility materially — the receivers would read from their seams instead of the rotation grid.

That may well be the more correct volleyball (a receiving side is in formation when the ball is struck, not moving into it during the flight). But it is not on the packet's F1 list: no second authority governs a physical fact here, because gameplay consistently uses `live_positions` and the formation map is consistently presentation. It is a reporting inconsistency plus an off-ball fidelity gap, which is F4 — and F4 inside a certified family is exactly what B1–B4's "audit, do not rewrite" covers.

Next diagnostic / repair: decide whether `live_positions` should be seeded from `_receive_formation_map` at rally start for the receiving side, which would collapse the two shapes into one without reordering anything. Then measure reception quality and the dig/side-out mix before and after. That is a volleyball decision with a measurable cost, and it deserves its own pass rather than a rider on this one.

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
3. movement/actor continuity — FD-001, FD-002, FD-004
4. responsibility/selection — *empty*
5. attack/block interaction — *empty*
6. home/opponent asymmetry — *empty; the B4 repair closed the one found*
7. tactical wiring — *not yet audited (M9)*
8. presentation/reporting — FD-003
9. calibration/balance — FD-005
