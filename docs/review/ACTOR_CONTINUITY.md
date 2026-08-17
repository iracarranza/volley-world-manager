# Actor continuity: the state survived the leg, and nothing read it back

Run: 2026-08-17, from `46c1331`. Instrument:
`tools/run_actor_continuity_probe.gd`.

Two certified repairs were **latent**, and both waited on the same thing:

- `ContactEnvelopeSystem`'s AIRBORNE takeoff exclusion (`READINESS_REMOVAL.md` §3)
- the claimant's usable-time requirement (`SHORT_BALL_RESPONSIBILITY.md` §4)

Each was correct. Each fired in a deliberately constructed fixture. Neither
changed a live rally.

---

## 1. The gap was smaller than "carry an actor between legs"

Three facts, measured before anything was built:

1. **`rally_simulator.gd` never calls `ContactEnvelopeSystem` at all.** The
   envelope is reached only from the shadow systems, which read `RallyState`
   actors.
2. The resolver **rebuilds a fresh `RallyState` per phase** — four sites — and
   seeds it from `live_positions` and `live_velocities` only.
3. **`player_recovery` already carried both the debt and a name for it**, per
   rally, reset in `simulate_rally`: `"airborne"` from a block jump,
   `"fall"` / `"knee"` / `"blown_away"` from the floor, `"platform"` from a clean
   forearm contact.

So the compromised state already survived the leg. Nothing read the name back
into the actor the envelope looks at. The whole repair is one function that does
exactly that, called at each of the four phase builds:

```gdscript
func _seed_carried_body_states(state: RallyState, at_time: float) -> void:
    for actor in state.all_player_states():
        var record: Dictionary = player_recovery.get(actor.player_id, {})
        if record.is_empty():
            continue
        var ready_at := float(record.get("ready_at", 0.0))
        if ready_at <= at_time:
            continue
        actor.recovery_until = maxf(actor.recovery_until, ready_at)
        actor.body_state = RallyPlayerState.BodyState.AIRBORNE \
            if str(record.get("state", "")) == "airborne" \
            else RallyPlayerState.BodyState.RECOVERING
        actor.movement_mode = RallyPlayerState.MovementMode.RECOVERY
```

**No new state, no new value, no new relation.** The AIRBORNE/RECOVERING split is
the one `player_recovery` already draws. `RECOVERY` as the movement mode is what
the moving-orientation policy says recovery is: it preserves whatever orientation
the last real movement established. A voli owing nothing at that moment is left
exactly as the builder made them.

---

## 2. Gates C1–C6 — **6 pass, 0 fail**

| gate | result |
|---|---|
| C1 — a phase state is seeded with the recovery still owed | **PASS** |
| C2 — a block landing survives as AIRBORNE, a floor trip as RECOVERING | **PASS** |
| C3 — a body owing nothing is left as the builder made it | **PASS** |
| C4 — one actor per player per phase; lookups return that same actor | **PASS** |
| C5 — a new rally starts with nobody carrying anything | **PASS** |
| C6 — the carried state reaches the envelope | **PASS** |

C6 is the one the continuity exists for:

| body | state | jump available |
|---|---|---|
| carried airborne | AIRBORNE | **none** |
| clean | BALANCED | 0.6172 m |

C4 matters because a seeded body and the body a system later reads must be the
same object. `RallyState.player_state` returns the stored actor and
`all_player_states` enumerates each id once, with zero duplicates.

---

## 3. It fires in live rallies — 46 times in 300

Instrumented over 300 rallies on the vertical slice, both serving sides:

| carried state | seedings | mean still owed | max |
|---|---:|---:|---:|
| `airborne` | **42** | 0.741 s | 0.903 s |
| `knee` | 3 | 0.652 s | 1.005 s |
| `fall` | 1 | 0.822 s | 0.822 s |

Landing blockers dominate, which is what the sport predicts: the block is the
contact most often followed immediately by another ball.

---

## 4. And the outcome mix is byte-identical — which is a fact, not reassurance

600 rallies, before and after: 288 home points, 3,955 events, kill 154,
opponent_kill 174, attack_error 66, opponent_attack_error 43, counter_block 32,
blocked 18, ace 5, serve_error 108.

**Reported, not targeted**, and it says something specific rather than "nothing
happened". The seeding demonstrably fires 46 times, so the state is genuinely
carried. It changes no outcome because `recovery_until` and the resolver's own
`_recovery_time_penalties` were *already* excluding those bodies through the
availability checks, which run before anything asks the envelope a posture
question.

So the honest reading is: **the clock was already right; the body was not.** What
changed is that a compromised body is now compromised *as a body* — AIRBORNE with
its 0.82 posture factor and its takeoff exclusion, rather than a fresh BALANCED
actor that happened to be filtered out upstream. That is the difference between a
model that is correct and a model that gets the right answer for an adjacent
reason, and it is what makes the two previously-latent repairs load-bearing the
moment any path asks the envelope about a body mid-recovery.

**Facing rides along and is expected inert.** Every defensive leg in the resolver
is LATERAL and LATERAL preserves orientation, so a defender's facing cannot
change between legs while the form comparison is blocked — measured at 2 of 796
defensive contacts made by a body that had run
(`tools/run_carried_facing_probe.gd`). Its inertness is not a failure of this
pass and must not be reported as a consequence of it.

---

## 5. Tests

`_test_compromised_bodies_survive_the_boundary`, two checks. **Both fail on the
pre-pass resolver**, verified by removing the body-state assignment and
re-running:

```
TEST FAILED: a landing and a floor trip survive into the next phase, distinctly
TEST FAILED: and the carried state reaches the envelope that refuses a second takeoff
```

Suite: **2,133 checks, no failures.**

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_actor_continuity_probe.gd
```

Deterministic; no rally is resolved and no RNG is drawn.
