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

---

## P1 — CONTRACT

### P1.1 The type

`scripts/models/rally_movement_path.gd` — `RallyMovementPath extends Resource`.

| Field | Why |
|---|---|
| `start_time` | Rally-clock, so samples are absolute and a consumer never needs to know which leg it is looking at |
| `sample_times` / `positions` / `velocities` / `facings` | The four required semantics, one entry each |
| `exit_velocity` | The whole momentum question in one field |
| `reached_target` | Distinguishes arrival from running out of window |

`sample(rally_time)` interpolates and **clamps at both ends** — a consumer
asking outside the window is drawing a frame while another leg runs, not
erroring. Facings blend as vectors and renormalise rather than slerping,
because a leg from rest has a zero facing with no angle to slerp from.

### P1.2 What had to be added upstream

`ShadowMovementSystem.integrate()` already emitted `trail`, `sample_times` and
`speeds_mps`. It set `stepper.facing` every step and **recorded none of it**.
Added `facings` and `velocities` per sample — 6 lines. Nothing else was needed;
the contract is built entirely from existing capability, as the spec requires.

### P1.3 Measured, at `3f734ba` + this pass

Single lateral leg, seeded fixture 771000:

| Property | Result |
|---|---|
| priced seconds (`traversal_result`) | 2.51343 |
| path duration | 2.51343 |
| **delta** | **0.00000** |
| samples | 76 |
| rally-clock aligned at first sample | yes |
| start position vs actor position | 0.000000 m |
| mid-leg facing magnitude | 1.0000 |
| `reached_target` | true |
| `exit_velocity` | `(0,0)` — correct: arrival zeroes velocity, per `shadow_movement_system.gd:31` |

> The load-bearing property is the delta. **The movement that decides
> reachability is numerically the movement that is drawn.** That is what makes
> the downstream re-solves removable rather than merely redundant.

### P1.4 Contract tests

`tests/test_runner.gd::_test_authoritative_movement_path_contract`, registered
beside `_test_stride_and_cadence_locomotion`. Eleven assertions covering:
per-sample completeness, monotonic times, rally-clock alignment, exact start,
clamping before/after, exit velocity identity, determinism (sample-for-sample
across two builds), renderer-agnosticism, and the duration identity above.

→ P2.

---

## P2 — RECEIVE SLICE · **G1 PASSED**

### P2.1 What was found in playback, before changing it

`tactical_court._integrate_phase_path` did **four** separate things wrong, not
one:

1. re-integrated the leg from a second freshly built `RallyPlayerState`;
2. integrated over a **fixed 5.0 s window** (`MOVEMENT_SAMPLE_WINDOW_SECONDS`),
   not the leg's own duration;
3. **normalised sample times to `[0,1]`**, discarding absolute time entirely;
4. **forced the last point onto `target`** — *"The event's endpoint is
   authoritative; end exactly on it."*

Plus the facing pre-align, which its own comment justifies as stopping the
re-solve from missing an endpoint the first solve had already committed to.

### P2.2 Resolver side

`_committed_path()` added immediately above `_reached_point()`, which carries
the comment *"Every committed journey in the game passes through here"* — so it
is the choke point P3 will reuse.

It builds the trail from the same actor state, via
`ShadowMovementSystem.integrate`, and returns `null` when there is nothing to
draw. Both reception sites publish `movement_path` on the event.

### P2.3 The G1 disagreement, and the contract fix

First measurement, integrating toward the **ball**:

| Metric | Value |
|---|---|
| receptions carrying a path | 7 / 7 |
| start vs committed | 0.00000 |
| **landing vs committed** | **0.026 – 0.065 court units (up to ~0.5 m)** |

Cause: `_reached_point` does not put the body on the ball. It calls
`_body_behind_contact`, which stands the body back by
`contact_offset_meters` — a voli plays the ball *in front of* themselves.
Integrating to the ball drew the body half a metre past where the resolver had
committed it.

**Fixed in the contract, not in playback** (G1): the path now targets
`receiver_reach` / `opponent_receiver_reach` — where the body actually ended.

| Metric, after | Value |
|---|---|
| paths, 200 seeds | 143 |
| **worst landing vs committed** | **0.000000** |
| **worst start vs committed** | **0.000000** |

### P2.4 Truncated legs, tested directly

The vertical-slice fixture never truncates — 143 of 143 receptions reached, 0
emergency. So the bisection branch of `_reached_point` is **not exercised by any
seed**, and agreement there had to be measured on its own.

36 synthetic truncated cases (4 targets × 3 depths × 3 window fractions),
comparing `_reached_point`'s bisection against the integrated landing:

| Metric | Value |
|---|---|
| worst bisection vs integrated landing | **0.000181 court units** (~2–3 mm) |

### P2.5 Scope boundary, stated rather than skipped

The spec's actor bullet — *consume authoritative `v`/facing; legacy
delta-derived speed only as fallback for unmigrated paths* — is **not yet
satisfied, and deliberately so.**

`tactical_court` (2D, primary playback) and `match_court_3d` → `PlayerActor3D`
(the presentation-only 3D replay) are **separate consumers**. Only the 2D path
was migrated here. `player_actor_3d.gd:1005` still derives speed from drawn
deltas, which is precisely the documented fallback state for an unmigrated
consumer. It becomes wrong only once the 3D replay is migrated, which is P3/P6
work.

### P2.6 Gate

- same movement establishes and depicts arrival — **yes**, 0.000000 both ends
- no duplicate solve on the migrated path — **yes**, `_authoritative_phase_path`
  returns before `_integrate_phase_path` is reached
- no endpoint snap — **yes**, the path's landing *is* the endpoint
- determinism — contract test asserts sample-for-sample equality

### P2.7 Suite

| Run | Result |
|---|---|
| Baseline (`3c2cb2d`, before this work) | 2 of 2,251 |
| P1 (`402ca56`) | 2 of 2,261 — +10 contract assertions |
| **P2 (`ab4e37a`)** | **2 of 2,261** |

Both failures are the two known pre-existing ones in `CLAUDE.md`. P2's count is
**identical to P1's**, so publishing the path and consuming it in playback moved
no outcome and no sampling population — which is what a change that must
preserve outcomes has to look like.

**G1 PASSES.** → P3.
