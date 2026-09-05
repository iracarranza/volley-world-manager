# Authoritative movement — execution record

Running log for `docs/specs/AUTHORITATIVE_RALLY_MOVEMENT.md`. One section per
pass. Measurements carry the commit they were taken on.

---

## P0 — VERIFY · **G0 PASSED**

### P0.1 The traced leg: serve → receive

```
main.gd::_resolve_rally
  → GameManager.resolve_active_rally(seed)             game_manager.gd:499
  → RallySimulator.resolve(...)                        rally_simulator.gd:824
      receiver_start  ← live_positions / zone centre   :1258
      _movement_time(receiver, receiver_start,
                     reception_point, "lateral")       :1263   ← NO entry_velocity
        → _travel(...)                                 :9592
            actor := RallyPlayerState.create(...)      fresh state
            actor.velocity = entry_velocity            (ZERO here)
            actor.facing   = entry_facing              (ZERO here)
          → RallyMovementSystem.traversal_result(...)  rally_movement_system.gd:417
              → _leg_seconds(...)                      CLOSED FORM
              ← {seconds, exit_speed, exit_velocity}   ← NO TRAIL
      event.metadata["movement_duration"] = receiver_move_time   :1272 :1458
  → RallyResult.events
  → main.gd::_play_rally
      tactical_court._build_movement_paths()           tactical_court.gd:654
        _integrate_phase_path()                        :671
          RallyPlayerState.create(...) — SECOND fresh actor
          actor.facing = opening.normalized()          ← pre-align cheat
          ShadowMovementSystem.integrate(..., 1/30)    :703  ← SECOND SOLVE
      match_court_3d.set_tactical_position()           :160 :406
        player_actor_3d: instant_speed :=
          travelled / frame_time                       player_actor_3d.gd:1005
          → ground_speed_mps (smoothed :1048)          ← THIRD DERIVATION
          → stride_cycle → gait
```

### P0.2 Established facts

| Question | Answer | Evidence |
|---|---|---|
| Input state at the leg | `pos` only. `velocity` and `facing` are passed as `Vector2.ZERO` on the reception path | `rally_simulator.gd:1263`; `_travel` defaults `:9592` |
| `_movement_time()` output | **A scalar `float` (seconds).** Delegates to `_travel` → `traversal_result`, then discards everything but `["seconds"]` | `:9580` |
| Analytical or sampled? | **Analytical, closed form.** `traversal_result` → `_leg_seconds`; returns `{seconds, exit_speed, exit_velocity}` | `rally_movement_system.gd:417` |
| Is there a reusable trail? | **No.** Confirmed — the spec's warning was correct | same |
| Data discarded | `exit_speed`, `exit_velocity` at every `_movement_time` call site (30 of them) | `:9580` |
| Where path is re-derived | `tactical_court.gd:_integrate_phase_path` `:671` | — |
| Where facing is re-derived | same function, pre-aligned to the route to force endpoint agreement | `:687` comment |
| Where speed is re-derived | `player_actor_3d.gd:1005` from drawn deltas | — |

### P0.3 Momentum guard — **PARTIAL**

Not the classification the research doc implied. Sharper:

| Leg | Threads entry velocity? | Correct? |
|---|---|---|
| Home serve reception `:1263` | No | **Yes — correct.** Everyone genuinely starts a rally at rest |
| Opponent serve reception `:4008` | No | **Yes — correct.** Same reason |
| Hitter approach `:2278` `:2299` | Yes | Fixed |
| Opponent hitter `:5040` `:5061` | Yes | Fixed |
| Continuation hitter `:6907` `:6930` | Yes | Fixed |
| Defence / coverage / setter chase / block close / rebase | No | **No — dead stop, wrongly** |

**Root cause is not the call sites.** `live_velocities` is written at exactly
**three** places — `:2304`, `:5066` (opponent), `:6935` — all hitters, all after
an approach leg. Every other player has **no velocity state to carry**, so
passing `entry_velocity` at those call sites would pass zero anyway.

> The momentum fix and the authoritative-path contract are **the same change**.
> A leg that publishes `{time, position, velocity, facing}` commits exit
> velocity by construction. Fixing momentum separately would be building half of
> P1 with a different shape.

No separate P0 fix made. Folded into P1.

### P0.4 G0 evidence — can the resolver own a path?

The blocking question, stated by `movement_integration_calibration.gd` itself:

> "`RallyMovementSystem.project_toward()` is what every reachability,
> arrival-margin, and opportunity decision in the engine is built on. If
> `ShadowMovementSystem` steps to a different place than that function projects,
> then adopting trails would silently move every one of those decisions. If it
> lands in the same place, trails are a refinement rather than a replacement."

Run at `e1fbe63`, `MovementIntegrationCalibration.run()`, defaults (8 seeds):

| Metric | Value |
|---|---|
| `sample_count` | 768 |
| `mean_disagreement_meters` | **0.0000035** |
| `worst_disagreement_meters` | **0.00018** |
| `within_tolerance_rate` | **1.0** |
| `reach_agreement_rate` | **1.0** |
| `source_immutable_rate` | 1.0 |
| coverage | completed **and** incomplete traversals observed; trail is sampled |
| `minimum_trail_samples` | 6 |

**Worst disagreement is 0.18 mm.** Reach agreement is exact.

**G0 PASSES.** The resolver can own a path without a semantic rewrite: call the
integrator it already provably agrees with, from the actor state `_travel`
already builds. No decision moves.

→ P1.
