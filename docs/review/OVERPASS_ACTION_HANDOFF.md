# Overpass ordinary-first-contact handoff

Date: 2026-08-17

Branch: `claude/system-fit-serve-receive-von64k`

Starting checkpoint: `fcdfdb354ac9f691ff9ccff05efaffa9b90b7825`

## Current boundary

The approved overpass policy now has a constructed, shared-physics implementation and a passing fixture probe. It is **not yet connected to the two live `RallySimulator` overpass exits**, so production rally outcomes are unchanged by this checkpoint. `ENABLE_PHYSICAL_PLATFORM_DIG` remains `false`.

An overpass is represented as the receiving side's ordinary first team contact:

1. preserve the authoritative incoming free flight;
2. find eligible actors and physically reachable contacts after the legal net crossing;
3. apply volleyball legality to the available actions;
4. rank attack and platform-control candidates using existing player, tactical, perception, body-state, and contact-quality information;
5. execute the selected contact into one outgoing physical ball;
6. record that contact as contact one for the receiving team.

There is no fixed attack-over-control priority and no overpass-specific physics constant or target outcome rate. The current set resolver assumes second-contact semantics, including hitter selection and contact state, so an overhead/set-like first contact is deliberately absent rather than mislabeled as `SET`.

## Implemented in this checkpoint

- `free_flight_interception_system.gd`
  - can search beyond a legal net crossing without treating the crossing itself as terminal;
  - exposes velocity at time and the authoritative net-crossing result;
  - can derive the existing attack-approach profile for an interception opportunity;
  - refuses opportunities for an actor whose recovery/commitment state says they are unavailable at contact time.
- `rally_decision_system.gd`
  - owns the existing ordinary first-contact action availability thresholds.
- `shadow_reception_system.gd`
  - delegates to that shared first-contact decision function instead of carrying a duplicate set of thresholds.
- `overpass_action_system.gd`
  - constructs and ranks attack, controlled-first-contact, and emergency-first-contact candidates;
  - applies libero/front-row/back-row attack legality;
  - executes platform control through the shared platform-contact model;
  - executes attacks through the current geometric attack resolver;
  - preserves the incoming launch and produces exactly one outgoing free flight;
  - applies receiving-side possession and team-contact count `1` to a `RallyState`.
- `run_overpass_action_probe.gd`
  - provides deterministic constructed certification independent of naturally rare overpass incidence.

One defect was exposed while constructing the fixtures: a recovering/committed actor could still be offered a contact when their standing reach overlapped the flight. Availability is now checked before an interception opportunity is published.

## Focused certification

Command:

```text
Godot --headless --rendering-method gl_compatibility --path . --script res://tools/run_overpass_action_probe.gd
```

Result: **PASS**. The probe certifies:

- an obvious tape attack can win;
- an unavailable attacker cannot win (another legal actor may still attack);
- attack and control can both remain feasible, with attributes and tactics changing the choice;
- when attack is illegal, control wins;
- selected attack and control each produce one outgoing physical ball;
- later choice does not mutate the incoming launch and played segments remain prefixes of it;
- attack and control both become the receiving team's first contact and possession changes accordingly.

Godot project import also completes without parse errors. The full test suite was **not rerun for this interrupted checkpoint**; the last full-suite result at the starting checkpoint was 2,163 passing checks with unrelated node/resource warnings.

## Exact continuation work

The two current live exits are `rally_simulator.gd` around lines 4216 and 6238, where `crossed_net_unresolved` still ends as `m5_unresolved_overpass`.

1. At each exit, construct receiving-side `RallyPlayerState` actors from authoritative live position, velocity/facing, commitment, and recovery state. Do not reconstruct them from presentation positions.
2. Pass the unchanged incoming free flight, those actors, the receiving lineup, side, and team principles into `OverpassActionSystem.choose()`.
3. For platform control, publish a first-contact event (not `SET`), then enter the existing normal second-contact path using the generated outgoing free flight.
4. For attack, carry the generated swing/flight into the existing block and floor-defence continuation. An in-court open-net fixture is only a kill *opportunity*; live integration must not award an automatic kill or skip a viable block.
5. Preserve the realized incoming prefix and stamp `team_contact_number = 1` on every selected overpass action.
6. Add symmetric live-path tests for both receiving sides and rerun the full suite and relevant balance/resolution probes.
7. Keep overhead/set-like first contact excluded until the set contact form can be generalized without inheriting second-contact intent, hitter-selection, or contact-count assumptions.

## Progress after the checkpoint — control branch wired

**Control branch: live-integrated at both exits and certified.** Commits
`c147c30` (wiring) and `f766cf9` (live fixture).

- Both `crossed_net_unresolved` exits now route the receiving side's ordinary
  first contact through `OverpassActionSystem` when the chosen action is a
  controlled/emergency first contact, and fall through to the old
  `m5_unresolved_overpass` terminal otherwise. `_resolve_overpass_into_home`
  feeds `_resolve_home_continuation`; `_resolve_overpass_into_opponent` feeds
  `_resolve_opponent_transition`; both at `exchange_number + 1`, both guarded by
  `MAX_EXCHANGES`.
- The legacy resolver drives no persistent `RallyState`, so this uses
  `choose()`/`execute_control()` (which need none) and hands the generated
  authoritative free flight to the existing transition machinery, **not**
  `apply_first_contact()`. Receiving actors are built from the authoritative live
  maps via the existing `_second_contact_actor_states` recipe. The control intent
  uses the receiving side's own release seat / set-contact height / setter
  movement time — all class C.
- Certification: focused overpass probe still PASS; full suite **2160 with the
  change and 2160 with it stashed** — byte-neutral, because the exit fires **0
  times in 1,200 ordinary rallies** (`run_m5_overpass_census`). A constructed
  live fixture (`_test_overpass_control_wires_live`, suite 2160 → 2164) exercises
  `_overpass_control_contact` end to end: actors from live maps, one authoritative
  outgoing ball as contact 1, incoming launch byte-identical after resolution.

**Still open:**
1. **Attack branch** — when the contest selects `attack`, both exits currently
   fall through to the old terminal. Wiring it needs `execute_attack` +
   the defending side's block/floor-defence classification (kill / blocked /
   dug → that side's transition). `execute_attack`'s `resolve_swing` already
   accounts for blockers/defenders from positions, so no fabricated set
   parameters are required — it is plumbing, not a policy question.
2. **Home-side live fixture** — the control fixture exercises the opponent-side
   helper path; a symmetric home-side fixture should follow.
3. **M5 roadmap + physical-dig promotion** reassessment, once the attack branch
   lands.

## Files intended for this checkpoint

```text
docs/review/OVERPASS_ACTION_HANDOFF.md
scripts/simulation/free_flight_interception_system.gd
scripts/simulation/rally_decision_system.gd
scripts/simulation/shadow_reception_system.gd
scripts/simulation/overpass_action_system.gd
scripts/simulation/overpass_action_system.gd.uid
tools/run_overpass_action_probe.gd
tools/run_overpass_action_probe.gd.uid
```

Other modified files in the worktree predate this checkpoint and are deliberately not included.
