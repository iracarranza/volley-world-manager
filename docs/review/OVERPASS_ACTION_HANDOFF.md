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

## Progress after the checkpoint — attack branch wired, M5 architecture DONE

**Attack branch: live-integrated at both exits and certified.** Commits
`c6fed2e` (initial wiring), `7d003cd` (attack enters the real block path).

- When the overpass contest selects `attack`, `_resolve_overpass_attack` now
  forms the **defending** side's real block from live front-row state and the
  overpass flight window (home defends → `_form_home_block`; opponent defends →
  `_form_opponent_block`), turns it into a wall via
  `GeometricAttackPromotion.block_wall`, and swings through `execute_attack`.
  No set parameters are fabricated: `preset_window_seconds = 0.0` is true (the
  attack is off an overpass, not a set), tempo/set_quality/setter_x enter only
  as neutral minor read-cues, and the wall geometry is driven by the real
  `attack_x`, the real flight window, and live positions. `WALL_JOIN_CLOSE`
  naturally yields an **empty** wall when nobody can physically close — a
  viable block enters the real block path, an unreachable one does not, and
  neither is a policy decision.
- Swing outcomes are classified symmetrically: net/out → attack error;
  stuff/monster → blocked (home) / counter-block (opponent, blocker id from the
  formation primary); tool/block_crush/high_hands → kill; and in/touch/recycle
  route the outgoing ball into the **defending** side's
  `_resolve_overpass_into_*`, so a live block deflection or a dug ball
  continues the rally rather than terminating it. A `null` swing degrades to a
  kill, never a hidden replacement ball.
- The receiving attack is contact #1, exactly one outgoing ball is produced,
  and the incoming launch is asserted byte-identical after resolution.

**Certification.** Focused overpass probe PASS; three constructed live fixtures
(`_test_overpass_control_wires_live`, `_test_overpass_attack_selects_and_launches_live`,
`_test_overpass_attack_forms_real_block`) exercise both branches and the
real-block formation end to end; full suite **2170 PASS** at `7d003cd`. The
exit still fires **0× in 1,200 ordinary rallies**, so all overpass wiring is
byte-neutral to production and exercised only by constructed fixtures.

**M5 marked DONE (architecture).** Every exit criterion is met and certified —
launch authoritative/immutable, intended recipient ≠ endpoint/interceptor,
realised segment an exact prefix, truthful same-side terminals, legal crossing
→ opponent ordinary first-contact choice, control + attack live/symmetric with
the launch invariant asserted. This is an architecture condition and does not
require flipping production authority. `ENABLE_PHYSICAL_PLATFORM_DIG` stays
`false`. See `docs/design/RALLY_MILESTONES.md`.

**Still open (downstream of M5, not blocking it):**
1. **Physical-dig production promotion** — a *separate M4-migration
   evaluation*, not part of the M5 architecture exit. Its stated blocker (an
   ungoverned overpass) is cleared, but flipping the flag moves the outcome
   distribution. The correct instrument is a paired legacy/new census read as
   **observation only** — no outcome fitting, no silent flag flip.
2. **Coverage keep-alive selection** — the next known policy boundary. Coverage
   has complete contact/body state and the shared T1–T3 feasible envelope but no
   governed preference for choosing among physically feasible keep-alive
   launches. This is decision policy, not physics, and is a genuine STOP: it
   must not be resolved by inventing a fixed apex/pop, a forced recipient, a
   coverage-specific trajectory band, a new coefficient, or arbitrary weights.

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
