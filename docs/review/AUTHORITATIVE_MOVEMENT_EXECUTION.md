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

---

## P3 — PROPAGATE

### P3.1 Scope

`_reached_point` has **18 call sites** — its own comment calls it the place
"every committed journey in the game passes through". Six are contact-actor
legs and are now migrated:

| Site | Leg |
|---|---|
| `:1284` | home reception *(P2)* |
| `:4069` | opponent reception *(P2)* |
| `:3439` | recycle coverage |
| `:3680` | opponent defence |
| `:6038` | home coverage |
| `:6282` | home defence |
| `:7694` | continuation coverage |
| `:7889` | transition defence |

The remaining sites are off-ball staging and unit rebase. They feed
`unit_movement_targets` for **support** players, and playback's
`_authoritative_phase_path` deliberately serves only `movement_player_id`, so
migrating them requires a playback change as well. Deferred to P6, which is
where the spec reassesses off-ball.

### P3.2 Agreement after propagation

120 seeds, all events carrying a path:

| Event type | n | reached | worst landing vs committed |
|---|---:|---:|---:|
| RECEPTION | 84 | 84 | **0.000000** |
| DIG | 38 | 38 | **0.000000** |
| ATTACK_COVERAGE | 10 | 8 | **0.014978** |

Worst start vs committed, all types: **0.000000**.

### P3.3 The coverage residual is a sim defect, and it was previously hidden

Two of ten coverage legs land 0.015 court units (~0.15 m) short of the position
the event commits them to. **This is not a path error.**

`_reached_point`'s reachable branch tests one point and returns another:

```gdscript
if _movement_time(mover, start, target, mode) <= available_time:
    ...
    return _body_behind_contact(mover, target, contact_height, incoming_direction)
```

It asks whether `target` is reachable in the window, then commits the body to
`_body_behind_contact(target, …)` — an offset point **whose reachability is
never tested**. On coverage legs that offset can push the endpoint further from
the start than the point that was tested, so the resolver commits a body to a
position its own movement model says it cannot reach in time.

Confirmed by construction: capping the path's duration at
`min(_movement_time(start→committed), window)` changed the residual by
**exactly zero**, which can only happen if the closed form already says the
journey exceeds the window.

**Why it appears now.** The old playback forced the final sample onto the
target — *"The event's endpoint is authoritative; end exactly on it."* The snap
was hiding this. Removing the snap did not create the disagreement; it made an
existing one measurable, which is the point of the pass.

**Not fixed here, deliberately.** Correcting `_reached_point` moves committed
body positions and therefore outcomes. Per the spec that needs its own pass with
its own before/after measurement, not a change smuggled into a propagation.
Recorded as the first genuine sim defect this work has surfaced.

**Not fudged either.** The path reports where the body can actually get. A
0.15 m honest shortfall on 2 of 10 coverage legs is preferable to a snap that
made every leg look exact.

### P3.4 Suite · **G2 PASSED**

| Run | Result |
|---|---|
| Baseline `3c2cb2d` | 2 of 2,251 |
| P1 `402ca56` | 2 of 2,261 |
| P2 `ab4e37a` | 2 of 2,261 |
| **P3 `2c95dd6`** | **2 of 2,261** |

Same two known failures throughout. Three consecutive passes at an identical
count: migrating six legs to the authoritative path moved no outcome and no
sampling population.

**G2 PASSES.** → P4.

---

## P4 — RECEIVE PREP · **already implemented, one gap**

P4 asks for reception's two separate clocks. **Both exist.** This pass is
therefore verification with evidence, not construction — and the spec's rule
"repo truth wins" makes that the correct outcome rather than a shortfall.

### P4.1 Clock one — feet, from the ball read

The authoritative movement path, migrated in P2. Starts at `rally_clock` when
the serve is struck and runs for the leg's own duration. Before this work it was
a scalar duration that playback reconstructed; it is now the solved leg.

### P4.2 Clock two — platform, from predicted contact

`match_screen.gd:1152`:

> "Every other contact is prepared for while the ball is on its way: the phase
> runs **-1 to 0 across the incoming flight** and the contact lands at the end
> of it."

So reception already gets a full pre-contact window, scaled by the incoming
flight rather than by a fixed number of milliseconds. Within it,
`player_actor_3d.gd`:

| Constant | Phase | Meaning |
|---|---:|---|
| `SQUARE_UP_PHASE[RECEPTION]` | **-0.85** | turns to face the ball early — "the platform has to be pointed at the ball well before it arrives" |
| `PLATFORM_PHASE` | **-0.34** | arms start coming together |
| `PLATFORM_SET_PHASE` | **-0.08** | platform fully formed — "complete a little *before* contact" |
| `PLATFORM_DRIVE_START` | **-0.14** | legs begin driving |
| `PLATFORM_DRIVE_END` | **+0.34** | drive continues past contact |

**"Platform must emerge pre-contact; no contact-frame pose snap"** — satisfied by
construction. Every one of those numbers is negative.

Two related behaviours worth recording as already-correct:

- a serve has no incoming flight, so it gets a **1.12 s pre-roll**
  (`SERVE_PREPARATION_SECONDS`), without which "every authored toss, load and
  overhead swing existed only in diagnostics";
- a block's wind-up is deliberately moved onto the *set's* flight, because the
  wall must peak when the hitter swings, not when the ball arrives — measured at
  up to 1.19 s late when drawn the other way.

### P4.3 The gap: prep is timed on true flight, not perceived flight

P4 requires *"Use perceived/predicted flight, not true future knowledge."*

**Not met.** `match_screen.gd`, `match_court_3d.gd` and `player_actor_3d.gd`
contain **no** reference to `perceived_arrival`, `BallFlightEstimate` or
`read_error`. The pose phase runs across the **true** incoming flight, so a
passer who misreads still begins forming their platform on the ball's real
schedule.

Partially compensated: `contact_posture` is resolver-carried
(`rally_simulator.gd:1514`) and does encode strain, so a bad read degrades the
*pose*, just not its *timing*.

**Not built here.** Retiming prep against `BallFlightEstimate` changes drawn
timing for every contact and needs its own before/after render comparison, which
is P7 tooling. Recorded as the second genuine gap this work has surfaced, after
the `_reached_point` defect in P3.3.

---

## P5 — STATE/RECOVERY · **already implemented; two of my own claims corrected**

### P5.1 The derived recovery function exists, in production

`rally_simulator.gd:11445` `_note_recovery(player, state, at_time)` — **6
production call sites** — is precisely the function P5 asks for:

```
action/contact + body state (+ existing athlete vars) → recovery
```

- keyed by recovery **state**: `platform 0.0 / knee 0.55 / fall 0.95 / blown_away 1.35`;
- scaled by **existing athlete vars**: `explosiveness * 0.6 + work_rate * 0.4`,
  bounded `lerpf(1.28, 0.74, quickness)` — *"a springy defender is back up
  sooner… without letting anyone shrug off a blow-away"*;
- writes `player_recovery[id] = {state, ready_at, delay}`, which **constrains the
  next action**.

No invented attribute model, and nothing to replace. P5's `iff` is satisfied by
code that predates this work.

### P5.2 Correction to `SPORTS_SIM_ARCHITECTURE.md` R5

That artifact listed *"Per-contact costs are literals, not functions of
body/contact"* as a production root cause, citing
`live_reception_integrator.gd:59`, `live_block_integrator.gd:160`,
`live_attack_integrator.gd:32`.

**Wrong scope.** Those three files are the **development-only promoted contact
paths**, gated off in production. Production recovery goes through
`_note_recovery`, which is derived and athlete-scaled. R5 is corrected to apply
to the development integrators only.

### P5.3 Correction to the same artifact's envelope claim — upheld, with a caveat

`contact_envelope_system.evaluate()` — the function carrying `balance_factor`
and `posture_factor` by `BodyState` — is reached **only** from shadow systems
(`shadow_reception_system.gd`, `shadow_block_system.gd`). `rally_simulator.gd`
never calls it. So "modelled, flag-gated off" was right.

Caveat worth recording: *other* functions in that file **are** production —
`setter_capability_system.gd:217` uses `nominal_jump_displacement_meters`. The
file is live; the body-state gating inside `evaluate()` is not.

### P5.4 Why the envelope's own recovery cannot replace the literals

`contact_envelope_system.gd:185`:

```gdscript
"recovery_time_seconds": lerpf(0.36, 0.18, action_balance) if jump_possible else 0.0,
```

Its `[0.18 … 0.36]` range brackets the development integrators' literals almost
exactly, which is suggestive. But it returns **`0.0` when `not jump_possible`**
— it models *landing from a jump*, not recovery in general. Promoting it wholesale
would give every grounded contact zero recovery, and a grounded emergency dig
genuinely costs 0.34 s.

**So the spec's `iff` fails for that particular function**, and the literals are
left alone. Recorded because "the ranges line up" is exactly the kind of partial
match that gets mistaken for a derivation.

### P5.5 Body state across actions

Already preserved and used: `RallyPlayerState.body_state` carries
`BALANCED/MOVING/REACHING/DIVING/AIRBORNE/RECOVERING`; block and attack
integrators branch on `AIRBORNE` directly; the reception integrator branches on
`action == "emergency_keep_alive"`, which at that point is the same condition as
`body_state == DIVING`. `contact_posture` is resolver-derived and reaches the
actor, so a compromised contact changes the drawn pose.

**No change made in P5.** The pass is verification, and two claims in my own
prior artifact are corrected by it.

---

## P6 — REMAINING CONTINUITY · **YES, the architecture expresses it**

The spec's question: can the current hybrid/event architecture express off-ball
transition, rebase, approach prep, block close, recovery and continuation
convincingly using authoritative paths — or is a scheduler required?

**YES. No scheduler needed, and the evidence is the work above rather than an
architectural preference.**

| Evidence | Value |
|---|---|
| Legs migrated with no outcome movement | 6 |
| Suite across P1→P3 | 2 of 2,261, **unchanged three times** |
| Landing vs committed, reception + dig | 0.000000 |
| Start vs committed, all types | 0.000000 |
| Analytical ↔ stepped agreement | 0.18 mm worst over 768 samples |

Nothing in the six migrated legs needed a rally clock stepping agents. A leg is
solved once, published, and interpolated — the event architecture carries that
fine, because a path is just a richer event payload.

### P6.1 What the remaining legs actually need

The 10 unmigrated `_reached_point` sites are off-ball staging and unit rebase.
They are blocked on **one bounded playback change, not on architecture**:
`_authoritative_phase_path` serves only `movement_player_id`, so support players
fall through to the legacy re-solve. Serving paths per-player instead is a
dictionary lookup, not a scheduler.

### P6.2 What would require a scheduler, stated so the bar is on record

Nothing encountered in P0–P5. A scheduler becomes necessary only for behaviour
that cannot be expressed as *"a leg, solved at a known time, with a known
duration"* — e.g. a player changing target **mid-leg** in response to something
that happens during it. Every leg in this engine is committed against a contact
that is already scheduled, so that case has not arisen.

**`RallyScheduler` remains uncalled by production, correctly.**

---

## P7 — VALIDATE / CLEAN

### P7.1 Before → after

| Measure | Before | After |
|---|---|---|
| Movement solves per migrated leg | **3** (price, re-integrate, re-derive speed) | **1** (2D consumer); 3D replay still re-derives — unmigrated |
| Endpoint snap on migrated legs | forced onto `movement_target` | **none** — the path's landing *is* the endpoint |
| Facing pre-align on migrated legs | required to hit the endpoint | **none** |
| Time normalisation | trail times discarded, renormalised | rally-clock absolute, normalised only for the progress index |
| Momentum state carried | 3 hitter legs only | unchanged — see below |
| Suite | 2 of 2,251 | 2 of 2,261, same two known failures |
| Contact error, reception + dig | not measurable (snapped) | **0.000000** |

### P7.2 Reconstruction sites remaining

| Site | Status |
|---|---|
| `tactical_court._integrate_phase_path` | **kept**, as the documented fallback for the 10 unmigrated off-ball legs |
| `player_actor_3d.gd:1005` delta→speed | **kept** — the 3D replay is a separate, unmigrated consumer |
| `_reached_point` reachability/commit mismatch | **open sim defect**, P3.3 |
| Prep timed on true rather than perceived flight | **open gap**, P4.3 |

Nothing was removed that is still load-bearing, and nothing was left that is
merely redundant.

### P7.3 DONE criteria

| Criterion | State |
|---|---|
| No migrated playback re-solve | **met** for the 6 migrated legs |
| No competing actor movement truth | **not met** — 3D replay unmigrated (P2.5) |
| Momentum verified | **met as classification** (P0.3); the fix is a contract consequence, not yet applied to non-hitter legs |
| Receive moves + preps pre-contact | **met** (P4) |
| State/recovery continuity where supported | **met** (P5) |
| No endpoint cheats | **met** on migrated legs |
| Deterministic suite passes | **met**, 2 of 2,261 three times |
| No unjustified scheduler/AAA expansion | **met** — nothing added |

**Not fully DONE.** Two criteria are outstanding and both are scoped, not
blocked: migrate the 3D replay consumer, and migrate the 10 off-ball legs behind
the one playback change in P6.1.

---

## P8 — 3D CONSUMER · a fourth movement truth, found and removed

### P8.1 The discovery pass

Broad search for competing truths, not just the two documented:

| Solver | Site | Status |
|---|---|---|
| Resolver closed form | `_movement_time` → `traversal_result` | authoritative |
| 2D playback re-integration | `tactical_court.gd:755` | bypassed for migrated legs (P2/P3) |
| **3D plan straight-line lerp** | **`match_court_3d._plan_sample`** | **found here** |
| Actor speed/facing reconstruction | `player_actor_3d.gd:1005`, `:1060` | **migrated here** |

`_plan_sample` was `start.lerp(target, fraction)` — constant speed, **no
acceleration, no turn cost, no movement model at all**. The 3D court was not a
second opinion about the leg; it was a fourth, and the crudest of the four.

### P8.2 What that cost, measured

81 legs over 60 seeds, comparing the old lerp against the solved path at 20
steps per leg:

| Divergence | Worst |
|---|---:|
| **Position, mid-leg** | **0.5481 m** |
| **Speed** | **2.4455 m/s** |

0.55 m is most of a body width. 2.45 m/s is roughly walk-versus-run — and since
the actor's gait is driven by speed, the drawn *stride* was wrong by that much
too, not only the position.

### P8.3 What changed

- `_set_plan_target` carries the event's `movement_path`;
- `_plan_sample` samples it when present, keeping the lerp only for unmigrated legs;
- new `_plan_motion` extracts `{velocity, facing}` per frame;
- `set_player_position` and `PlayerActor3D.set_tactical_position` take a
  `motion` dictionary;
- the actor uses the **solved speed unsmoothed** — smoothing exists to hide
  noise in a per-frame difference, and a sampled velocity has none — and turns
  onto the **solved heading**, converted court→metres via `court_delta_meters`
  because the court is 9 m by 18 m and a court-space direction is not an angle.

`should_open_up` still decides *whether* the body turns onto travel. That is a
presentation rule with measured constants which the path does not encode, and
it is what lets a voli shuffle or backpedal with their eyes on the ball.

### P8.4 Verified

Sampled profile on a real reception leg — 0 → 1.599 → 2.932 → 2.932 → 0 m/s:
acceleration, cruise and arrival, none of which a lerp can express.

Suite: **2 of 2,261**, the two known failures, unchanged from P1/P2/P3.

---

## P9 — the off-ball migration, and what it found

### P9.1 One publication point, twenty call sites

`_travel_intent` is the choke point every staging, rebase and wall-close journey
passes through. Publishing a `path` there migrated all of them in one edit
rather than at each caller. `_wall_close_intent` and `_shape_intents` and
`_hold_phase_intents` all delegate to it, so they are covered by construction.

Consumers wired: `_apply_explicit_targets` in `match_screen.gd` now carries the
intent's path into the plan entry, and `tactical_court._authoritative_phase_path`
serves any player through the new `_published_offball_path` instead of only
`movement_player_id`. The 3D court already samples the plan entry's path (P8).

**Cost.** 60.24 ms/rally before, 64.06 ms/rally after — 6.3%, for an integration
per moving off-ball player per event.

**Outcomes.** The 700-rally balance probe is byte-identical across the whole
pass, all nineteen figures, both serving sides. `ShadowMovementSystem.integrate`
touches no RNG, so this is what it had to look like.

**Suite.** 2 of 2,261, the two known pre-existing failures. Zero checks written,
zero gained — no sampling population moved.

### P9.2 The serve walk-in was the last pathless contact leg

Both serve sites published `movement_start` and `movement_target` and no
journey — the server's return to court, once per rally, drawn by playback's own
re-integration. Measured before the fix: **60 of 60 rallies**. After: contact
legs with real displacement are 127 with a path, **0 without**.

### P9.3 A hold intent that was standing on its own destination

`_hold_phase_intents` read `here` from `resolved_positions` first and only fell
back to the live position, so a player whose resolved spot had moved was told
they were already on it and published a zero-length hold. Playback walked them
anyway. Measured: **38 legs of 0.05 to 0.24 court units described as standing
still.** Now the leg starts at the live position and ends at the resolved one.

### P9.4 Coverage, measured

60 rallies, seeds 4000–4059:

| | with path | stationary (none needed) | moving and pathless |
|---|---|---|---|
| contact legs | 127 | — | **0** |
| off-ball legs | 1,303 | 642 | 38 |

The 38 are the hitter's and first passer's recovery holds, which publish
`targets[id] = here` — the target *is* the live position, so there is no journey
to solve. They register as "moving" only against the *previous* event's target,
which is the reachability finding below, not a missing path.

### P9.5 Third reachability defect — surfaced, measured, not absorbed

**15 legs of 1,303 land short of the target the resolver then adopts as the
body's position.**

| intent | n | worst shortfall |
|---|---|---|
| `blocking` | 6 | 0.109 court units |
| `preparing_attack` | 9 | **0.457** court units |

`_wall_close_intent` passes `to, to` — the intended block position as both the
intended and the reached point, untruncated. `_travel_intent` then caps the
journey at the window and the path lands where the body actually got, while the
resolver's live position becomes `to`. The resolver blocks from a place the
mover could not close to in time.

This is the same family as the `_reached_point` defect recorded in P6: a
reachability question asked of one point and answered for another. **It is a
simulation defect, not a movement-contract defect** — the contract is now
self-consistent (one solve, one path, every consumer reading it), and what
disagrees is the resolver's own commitment. Fixing it moves block and approach
positions and therefore rally outcomes, which is outside this pass by the goal's
own separation of concerns. Recorded here with its size so the next pass has a
measurement rather than a suspicion.

All other 1,288 off-ball legs agree with their published target to within
**0.038 court units**, and 1,273 to within 0.05.

---

## P10 — deleting a dead truth, and finding a live one

### P10.1 The 2D lerp table was dead and is now gone

`tactical_court._support_target_for_side` invented a drift toward the action for
any voli the resolver had not published — a fifth movement truth, and once 35.6%
of voli-legs by its own comment. It was overwritten in every case by
`*_phase_positions` and the phase maps, which are applied after it.

Measured over 60 rallies, **per playback leg** (event → next_contact, which is
how the court actually reads targets): **0 of 3,481** legs reached it. Deleted,
50 lines, along with its two call sites and the unused parameter they needed.

A first measurement said 15.9% and was wrong: it counted events rather than
legs, so it charged the SERVE event with 660 uncovered legs. Nothing precedes
the first contact of a rally, so the serve leg reads the *reception* event's
maps, which are complete. The instrument was the defect.

### P10.2 The staged walk is solved

Three sites published `staged_next_actor_id` and `staged_next_position` and no
journey — the setter's walk across during a pass flight. They now publish
`staged_next_path`, read by `match_screen` and by `tactical_court` off the event
being *played* rather than the contact being approached. The other two staged
sites already routed through the phase maps and were covered by P9.

Balance probe byte-identical again, all nineteen figures.

### P10.3 The real coverage number, from playback rather than from the resolver

Every census up to here was taken on resolver output, which is the wrong
instrument: it can say what was published but not what playback *selects*. A
headless `TacticalCourt` driven through 10 rallies leg by leg says:

| source | legs | share |
|---|---|---|
| authoritative published path | 264 | 41.8% |
| **legacy local re-integration** | **317** | **50.2%** |
| hold, no path needed | 51 | 8.1% |

So half of production playback still re-solves. The source is now known and is
not any of the four truths already removed: those legs get their target from
`*_phase_positions`, the map `_add_event` stamps on every event with the
resolver's live positions for the ten players not making the contact. It is a
*fact* — "this body is here now" — with no journey attached, and playback walks
the drawn body to it over the phase.

Displacements are real, 0.04 to 0.27 court units, concentrated on RECEPTION,
SET, BLOCK and ATTACK legs.

**This is the remaining gap to DONE and it is not closed.** Two readings are
possible and they demand different fixes:

1. the resolver moved these bodies without publishing the journey, in which case
   the journey has to be published, as everywhere else in P9 and P10; or
2. playback's drawn body drifted from `live_positions` on an earlier leg and
   this is a *correction*, in which case walking it is papering over a
   continuity break that `playback_continuity_mismatches` should be recording.

Distinguishing them means comparing each such target against the same player's
previous published target, per leg, in playback order. That measurement has not
been taken and nothing should be changed until it has.

---

## P11 — a truncated journey is continued, not re-solved

P10.3 split the 317 re-integrating legs two ways: 214 re-aimed at a target the
body had never reached, and 103 aimed somewhere new. The first group is not a
new journey at all. The resolver re-publishes the same destination because the
rest of the walk is still owed; playback was answering that by solving it again.

`tactical_court` now carries the last authoritative path per player and, when a
leg's target matches that path's own landing, resumes it — the tail from the
sample nearest the body's current position, renormalised over what remains. That
is interpolation of the one solved answer. `carried_movement_paths` is cleared by
`begin_rally_playback`, so nothing survives a rally.

**Matched measurement**, 10 rallies through a headless court seeded with the
same `initial_home_positions` production uses:

| | before | after |
|---|---|---|
| authoritative | 264 | **488** |
| legacy re-integration | 296 | **78** |
| hold, none needed | 72 | 66 |
| continuity mismatches | 21 (worst 0.366) | 21 (worst 0.366) |

The mismatch count is the important control. It is the court's own record of the
drawn body disagreeing with the resolver's reported start, and it did not move —
so the 218 legs that stopped re-solving were not silently absorbing a teleport.

An earlier reading of this same measurement said 317 legacy legs and 51 holds.
It was taken without `begin_rally_playback` between rallies and without the
initial snapshot, so the court began each rally wherever the last one left off.
Both numbers above use the production call.

### P11.1 The 78 that remain, by source

| source | n | where |
|---|---|---|
| `*_phase_positions` | ~40 | mostly POINT, the settle after the rally ends |
| `movement_player` | ~21 | **SET, ATTACK and BLOCK contacts publish no `movement_path`** |
| `*_phase_targets` | ~8 | BLOCK, DIG, SET |

The middle row is the next real gap: the eight migrated contact sites are the
receptions, the coverages and the defences. A setter's chase, a hitter's approach
and a blocker's close are still solved twice.

---

## P12 — the held position, and the leg it implies

`_add_event` stamps `*_phase_positions` on every event: where the ten bodies not
making this contact stand, as a fact, with no journey attached. Playback walked
the drawn body to that fact by re-integrating the walk locally — 40 of 632 legs
after P11.

It now publishes `*_phase_hold_paths` beside it: for each body that moved since
the previous contact and whose leg no other site solved, the leg itself, built
from `_positions_at_last_contact` to the current live position. One site, because
`_add_event` is the one place that sees every contact.

Both consumers read it at the *lowest* priority — `tactical_court` after the
phase intents, `match_screen` before `_apply_explicit_targets` — so any stated
journey still wins and this only fills silence.

Adding it needed one new field, `_bodies_by_id`, populated once per rally from
both rosters, because `_add_event` is handed no roster.

| | P11 | P12 |
|---|---|---|
| authoritative | 488 | **512** |
| legacy re-integration | 78 | **54** |
| hold | 66 | 66 |
| continuity mismatches | 21 (worst 0.366) | 21 (worst 0.366) |

Balance probe byte-identical: this publishes and reads, and changes no decision.

### P12.1 What the last 54 are

| source | n | note |
|---|---|---|
| `phase_positions` at POINT | 24 | the settle after the rally is over |
| `movement_player` at SET / ATTACK / BLOCK | 23 | **the three contacts that publish no `movement_path`** |
| `phase_positions` at SET / ATTACK | 7 | |

The 23 are the last real gap. Eleven resolver sites add those three event types
and none of them carries a solved leg for its own actor: a setter's chase, a
hitter's approach and a blocker's close are still the only journeys in the game
solved twice.

---

## P13 — the last two solves, and what is honestly left

### P13.1 The contact actor's own leg, from the one place that sees every contact

Eight contact sites published `movement_path`; eleven — every SET, ATTACK and
BLOCK — published nothing, so the setter's chase, the hitter's approach and the
blocker's close were the last journeys solved twice.

Rather than eleven bespoke edits, `_add_event` publishes the actor's leg when
the site did not: `_positions_at_last_contact[actor]` to
`body_contact_position`, over the journey's own duration. Same two facts every
other leg is built from, and skipped entirely where a site stated its own — so
the eight sites that know more about their leg than `_add_event` does keep it.

Legacy re-integration 54 → **31**, authoritative 512 → **535**.

### P13.2 `_integrate_phase_path` is deleted

The 31 that remained were measured before deciding what to do with them:

> **0 the model moved. 31 the model did not move**, drawn up to 0.531 court
> units from where the model says they stand.

So none of them is a journey. Re-integrating them was inventing a walk to cover
a disagreement — precisely the "downstream fudge to hide upstream disagreement"
the spec forbids, and it carried the two remaining endpoint cheats with it: the
forced last sample and the pre-aligned facing.

Deleted, 61 lines, along with `MOVEMENT_SAMPLE_WINDOW_SECONDS`. What is drawn
now is a straight two-point correction, appended to
`playback_continuity_mismatches` with `correction: true`. **The mismatch count
rose from 21 to 52 — exactly 21 + 31.** That is the point: the disagreement was
always there and is now counted instead of smoothed.

### P13.3 Final production state

| | legs | share |
|---|---|---|
| authoritative published path | 535 | 85.5% |
| recorded correction, no re-solve | 31 | 5.0% |
| hold | 66 | 10.6% |

**No production consumer re-simulates movement.** The remaining 0.531 court
units of correction are the reachability defect of P9.5 surfacing at the
drawing, and closing it means changing where the resolver commits bodies, which
changes rally outcomes and is deliberately outside this pass.
