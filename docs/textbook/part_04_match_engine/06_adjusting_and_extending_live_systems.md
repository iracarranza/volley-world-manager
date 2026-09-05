# P4-C6 — Adjusting and Extending Live Match Systems

Status: **VERIFIED** for the current 2D playback, tactical-planner geometry, and visualization controls. The extension recipes are **GUIDANCE** and must be verified after each change.

Keywords: playback feed, scroll, tactical planner, serve receive, event metadata, visualization layers, new systems

This chapter is the practical map for changing what a match does and what a player sees. The most important rule is to keep three responsibilities separate:

1. The tactical planner stores the coach's instruction.
2. The simulator uses that instruction to resolve the rally.
3. Playback presents the resolved events without deciding the result.

If a change crosses all three, implement and test all three deliberately.

## Prerequisites

- [P4-C1 Current Rally Pipeline](01_current_rally_pipeline.md) — the resolver you will be changing
- [P3-C1 Safe Change Workflow](../part_03_workflow/01_safe_change_workflow.md) — the loop every recipe here assumes

## Learning goals

After this chapter you should be able to:

1. keep the planner / simulator / playback responsibilities separate while changing all three;
2. adjust the playback feed without changing simulator timing;
3. trace a dragged planner marker all the way into a rally outcome;
4. add a visualizer, a tactical system, or a rally event using the recipes here;
5. verify any of it against the minimum checklist.

## Vocabulary

| Term | Meaning |
|---|---|
| **Playback feed** | The three text areas reporting a rally as it plays. |
| **Planner** | The tactical editor where a coach's instruction is stored. |
| **Coverage zone** | A stored position and radius a defender is responsible for. |
| **Visualization layer** | A toggleable court overlay. Presentation only. |
| **Metadata key** | A named extra on a `RallyEvent`; part of the shared contract. |
| **Recipe** | A stepwise procedure in this chapter. **GUIDANCE**, verify after use. |

## 1. The current live path

For a normal match rally, the active call path is:

```text
main.gd::_resolve_rally
  -> GameManager.resolve_active_rally
  -> RallySimulator.resolve
  -> RallyResult.events
  -> main.gd::_play_rally
  -> TacticalCourt animation and drawing
```

`RallySimulator` remains the authoritative normal-match resolver. Persistent rally classes and development rollouts must not be mistaken for normal live behavior; check [STATUS.md](../STATUS.md) before editing them.

## 2. Adjusting the playback feed

The match dashboard uses three different text areas:

- `DashboardEventLabel` shows the current event in full.
- `DashboardPlaybackHistoryLabel` shows every earlier event in abbreviated form.
- `DashboardExplanationLabel` shows the completed-point explanation and factors.

The history and explanation are `RichTextLabel` nodes with internal scrolling. Do not turn them back into content-fitting labels: a long rally would increase the dashboard's minimum height and move the court and controls.

`Main._append_playback_history()` owns the compact history format. Change that helper when adjusting timestamps, event names, ordering, or summary wording. `Main._set_playback_caption()` owns the full current-event text.

Playback speed is presentation only. The speed choices are populated in `Main._populate_static_options()`. Minimum visual durations and automatic-rally breathing room are in `Main._play_rally()`. Do not modify simulator event times merely to make playback feel slower.

After changing the feed:

1. Run a short rally and a long multi-exchange rally.
2. Confirm the current event wraps fully.
3. Confirm old events stay inside their scroll region.
4. Confirm post-point analysis scrolls without resizing the dashboard.
5. Test replay, skip, and auto-rallies.

## 3. How tactical positions become gameplay

Serve-receive and floor-defense positions are stored on the current `DefensivePlan`.

```text
drag marker on TacticalCourt
  -> coverage_zone_position_changed
  -> Main._coverage_zone_position_changed
  -> GameManager.set_coverage_zone_center
  -> DefensivePlan.set_zone_center
```

At rally resolution, `RallySimulator.resolve()` reads the same plan. For serve receive:

- `_initial_home_positions()` creates the starting snapshot from reception-zone centers.
- `CoverageCalculator.choose_claimant()` uses zone center, radius, priority, player movement, and ball time.
- the reception event records `movement_start`, arrival evidence, and `planner_zone_center`.
- the setter release target shapes `desired_pass_target` and the outgoing pass.

Floor positioning also affects defensive target selection, responsibility fit, and coverage calculations later in the rally. Offensive planner assignments affect hitter choice, lane, tempo, approach destination, and attack metadata.

When an opponent attack develops, `_home_floor_phase_positions()` converts the
saved floor zones into the current phase shape. It preserves the selected
blockers at the net and adjusts the other defenders using block-defense
relationship, depth, short-ball posture, and seam responsibility. Claimant
arrival is evaluated from these phase positions, and the same positions are
attached to attack, block, and defense events for playback.

Attack events record `approach_start_position`. During the incoming set,
`TacticalCourt` moves the hitter from their current live position to that
waypoint and then through the approach run to contact. The waypoint changes the
displayed route without secretly selecting a hitter or recomputing attack
quality.

This means a planner edit needs two kinds of proof:

- state proof: the plan or initial snapshot contains the new position;
- event proof: the same fixed seed produces changed ownership, movement, arrival geometry, target, quality, or another resolved event field.

A visual marker moving is not enough. A changed event caption without changed simulator data is not enough either.

## 4. Adjusting an existing planner mechanic

Use this sequence for serve receive, floor defense, setter release, hitter lanes, or a similar instruction:

1. Find the scene signal emitted by `TacticalCourt`.
2. Find the `Main` callback connected in `_ready()`.
3. Find the `GameManager` mutation method.
4. Confirm the model serializes the value in `to_dict()` and restores it in `load_dict()`.
5. Search `RallySimulator` for the model property and identify the exact decision or calculation it changes.
6. Put causal evidence on the relevant `RallyEvent.metadata` when playback or debugging needs it.
7. Compare two results with the same seed and only one tactical input changed.
8. Test save/load if the instruction should survive reopening a career.

Avoid reading marker coordinates directly from the UI during simulation. The simulator should receive model data through `GameManager`, not inspect a `Control` node.

## 5. Visualization controls

The main-screen **Visuals** menu applies one bit mask to both the full tactical court and the dashboard preview. The current public layers are:

- `VISUAL_BALL_PATH`: the curved trajectory line; the moving ball remains visible when this is off.
- `VISUAL_PLAYER_PATHS`: planned assignment paths, drag paths, and accumulated movement trails.
- `VISUAL_TACTICAL_GUIDES`: lane targets and setter-release guidance.
- `VISUAL_COVERAGE_ZONES`: reception/floor zones and serve-receive legality bounds.
- `VISUAL_CONTACT_OVERLAYS`: active-player rings and block/contact coverage marks.

`Main._setup_visualization_controls()` builds the menu. `Main._apply_visualization_layers()` sends the selected mask to both courts. `TacticalCourt.set_visualization_layers()` stores it and redraws.

The ball path is deliberately independent from the ball. This lets a player remove the persistent trajectory line without making ball flight unreadable.

Shadow timing, opportunity, and contact-envelope graphics are developer
diagnostics, not ordinary visualizers. Normal `_play_rally()` calls clear those
traces even in editor/debug builds. Only the explicit shadow-debug fixture (or
an explicit interaction with its debug controls) requests them.

## 6. Adding a new visualizer

Suppose you want a “defensive seams” overlay.

1. Add a new power-of-two constant in `tactical_court.gd`, such as `VISUAL_DEFENSIVE_SEAMS := 32`.
2. Include it in `VISUAL_ALL` if it should default on.
3. Write a small draw helper, for example `_draw_defensive_seams()`.
4. Call the helper from `_draw()` only when its bit is enabled.
5. Add a checked item with the same ID in `Main._setup_visualization_controls()`.
6. Add the ID to `Main._refresh_visualization_menu()`.
7. Apply the same mask to both courts; do not let preview and workspace silently diverge.
8. Add a regression check that the layer can be enabled and disabled independently.

A visualizer may read resolved data, model instructions, or debug evidence. It must not mutate the rally, select an actor, change quality, or become an input to simulation.

## 7. Adding a new tactical system

For a new instruction such as “libero release depth”:

1. Define the stored value and valid range on the appropriate model.
2. Add serialization before building UI, so the data contract is clear.
3. Add one manager mutation method.
4. Add the planner control and connect it to the manager method.
5. Read the value in one named simulator decision.
6. Record the relevant input and result on the event or analysis dictionary.
7. Add fixed-seed tests for default behavior, changed behavior, determinism, and save/load.
8. Add playback only after the simulation evidence is correct.
9. Update this textbook's status, evidence table, index, and source manifest.

If the system changes player knowledge rather than physical truth, pass a player-specific observation into the decision. Do not give the decision function hidden access to the entire authoritative game state.

## 8. Changing movement-to-action mechanics

The attack path is a worked example of a causal system. Do not tune the visible
approach animation to change an outcome. Follow the data in this order:

`responsibility perception → release time → preparation movement → approach state → contact envelope → available actions → selected action → event → playback`

`ApproachMechanicsSystem.prepare_for_attack()` resolves when a hitter may leave
their current responsibility and projects a copied actor toward the called
lane's staging point. `evaluate_takeoff()` then derives approach speed,
alignment, runway completion, lateral control, and jump conversion from that
actor's actual position, velocity, facing, time, and player attributes.

`ContactEnvelopeSystem.evaluate()` consumes the profile for attack contacts.
The profile modifies usable jump displacement, remaining takeoff time, and
balance; it does not rewrite the player's permanent ratings. The action menu is
then derived from both the athlete and this particular approach. A player can
still make a controlled contact after losing the runway while no longer having
a legal power attack.

When adding another dependency—such as penultimate-step technique—add it to the
resolved approach profile and prove all of the following:

1. Equal state and inputs produce the same profile.
2. The new input changes its intended physical quantity.
3. That quantity changes at least one downstream contact envelope or action.
4. Player decisions use perceived evidence; authoritative truth is audit-only.
5. The event stores enough resolved evidence for playback to present, not
   recompute, the action.

For opponent attacks, reuse the same profile contract after opponent player
state and perception have migrated. Do not mirror a home-only shortcut and call
it opponent simulation.

## 9. Adding a new rally event or contact

Before adding an event type, decide whether it is:

- a real resolved contact or state transition;
- a decision record used only for explanation;
- a visual phase that belongs only in playback.

For a real event:

1. Add or reuse a `RallyEvent.EventType`.
2. Resolve actor, timing, positions, success, and quality in simulation.
3. Use `_add_event()` so ordering and result analysis stay consistent.
4. Document every new metadata key at its producer and consumer.
5. Update live player and ball state before resolving the next dependent action.
6. Teach playback how to animate the event without recomputing its outcome.
7. Add deterministic tests for event order, contact ownership, spatial continuity, and terminal behavior.

Do not create a second hidden event schema only for one screen. Extend the shared contract when the information is genuinely part of the resolved rally.

## 10. Minimum verification checklist

For any new or adjusted match system, verify:

- the same seed and inputs produce the same result;
- changing the intended input changes causal event evidence;
- save/load retains player-facing tactical settings;
- no player teleports between consecutive event positions;
- both home and opponent orientation are handled;
- replay does not mutate match state;
- visualizer toggles do not change simulation results;
- long event and explanation text remains contained and scrollable;
- UI bindings, parser scan, textbook validation, and the full test suite pass.

Use the exact commands in [VALIDATION.md](../VALIDATION.md).

---

## 11. Common mistakes

| Mistake | Consequence |
|---|---|
| Changing simulator event times to slow playback | Presentation concern corrupting the simulation record |
| Turning a history label back into a fitting label | A long rally resizes the dashboard and moves the court |
| A second event schema for one screen | Two contracts that drift apart |
| A visualizer that reads back into the resolver | A toggle now changes results |
| Editing persistent classes expecting live effect | They are flag-gated; check STATUS.md first |
| Adding a metadata key at the producer only | The consumer never learns it exists |

---

## 12. Check yourself

1. You want playback to feel slower. Which file, and which not? *(`Main._play_rally()` minimum durations — not simulator event times.)*
2. A dragged marker changes nothing in the rally. Where does the chain break? *(Trace `coverage_zone_position_changed` → `GameManager.set_coverage_zone_center` → `DefensivePlan` → `resolve` reading the plan.)*
3. Why must a visualizer never feed the resolver? *(A presentation toggle would change simulation results.)*
4. You add a metadata key. What are the two places to document it? *(Its producer and its consumer.)*
5. Your new persistent code has no live effect. First check? *(STATUS.md — production rollout flags are off by design.)*

---

## Where this leads

- [P4-C5 Migration and Visible Proof](05_migration_and_visible_proof.md) — how new systems earn promotion
- [P7-C5 Rendering, Probes and Validation](../part_07_art_and_assets/05_rendering_probes_and_validation.md) — verifying anything visual
- [VALIDATION.md](../VALIDATION.md) — the exact commands
