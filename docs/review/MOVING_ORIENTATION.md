# Moving orientation: the form decides, and §8 stops

Run: 2026-08-17, from `f93a78b`. Instruments:
`tools/run_moving_orientation_probe.gd` (gates A–H),
`tools/run_defensive_form_probe.gd` (the §8 determination).

The previous pass gave a *resting* body a justified orientation and stopped at
exactly this line:

> **When does a moving body turn, versus travel while holding its orientation?**

---

## 1. The defect, in one line

`apply_position` assigned `facing = velocity.normalized()` for every movement
alike. That rule says a backpedalling defender is facing away from the net and a
shuffling blocker is facing down the net rather than across it. Neither is what
those movements are.

The repair is not a threshold. The **form** decides, and the engine already
carries the form — `RallyPlayerState.MovementMode` has described the physical
movement since it was written.

| mode | orientation | why |
|---|---|---|
| `IDLE` | preserved | nothing happened |
| `LATERAL` | preserved | ready footwork; travels sideways or backward while square |
| `BLOCK_CLOSE` | preserved | a close runs *along* the net, body across it |
| `RECOVERY` | preserved | recovery invents nothing; the last real one stands |
| `APPROACH` | **route** | the run-up is physically part of the swing |
| `TRANSITION` | **route** | an opened-up run: torso turns, legs run |

**No angle, distance, speed or turn-rate constant was added.** The whole rule is
one predicate over an enum that already existed.

---

## 2. Production changes

### a. `RallyPlayerState.movement_establishes_facing()`

`apply_position` consults it before adopting a velocity as an orientation.

### b. `RallyMovementSystem.project_toward` sets the mode *before* the position

It set `projected.movement_mode = mode` on the line *after* `apply_position`,
which handed the new predicate the mode of whatever leg the body had finished
previously. An approach projected from a body that had been shuffling was
classified as a shuffle. Reordered, with the reason in the comment.

### c. Four arrival sites now state the form they arrived in

Each was applying a position while the persistent actor still carried the state
builder's `IDLE`, so no arrival in the engine could establish an orientation
even when the movement plainly did.

| site | classified | policy |
|---|---|---|
| `LiveAttackIntegrator` | `APPROACH` | §6 — a committed run-up |
| `LiveSetterIntegrator` | `TRANSITION` | §7 — `ShadowSetterResponseSystem` already resolves the release in TRANSITION |
| `LiveReceptionIntegrator` | `LATERAL` | §4 — `RallyOpportunitySystem` resolved every step of the pursuit in LATERAL |
| `LiveBlockIntegrator` | `BLOCK_CLOSE` | §5 — and structurally, not by the accident of a zero arrival velocity |
| `RallyOpportunitySystem` | `LATERAL` | §4 — stated before the step rather than by the `set_intent` below it |

This is §11 — *fix the movement-mode classification rather than adding an
exception to facing.* Two of the five change behaviour (attack, setter); three
are documentation of a mode whose effect was already correct.

### d. One stale comment corrected, not a behaviour

`_blocker_close_terms` constructs its closing actor with `&"home"` for opponent
blockers too, under the note *"Side is irrelevant here."* Since `create()`
started deriving facing from the side that reason is false. The claim that
survives is arithmetic: a close runs along the net, so the route is ±x, the dot
product with either side's ±y facing is zero, and `facing_fit` is 0.5 for both.
Written down because it stops being true the moment a close gains any component
toward the net.

---

## 3. Gates A–H — **25 checks, 0 fail**

| gate | result |
|---|---|
| A — IDLE/LATERAL preserve | **PASS** (also BLOCK_CLOSE, RECOVERY) |
| B — backpedal does not turn the body around | **PASS** |
| C — BLOCK_CLOSE square to the net | **PASS**, priced at `facing_fit` 0.5 |
| D — APPROACH/TRANSITION establish the route, and only those two | **PASS**, all six modes |
| E — no route prepares itself before evaluation | **PASS**, both halves |
| F — the claimant reads a live orientation | **PASS** |
| G — prior movement changes a later equal ball | **PASS** |
| H — A1–A8 still hold | **PASS** |

Gate G, the one the previous pass could not write:

| prior movement | facing | reach margin |
|---|---|---:|
| ran that way (TRANSITION) | (1, 0) | **1.0075** |
| stood still (LATERAL shuffle) | (0, −1) | **0.7448** |
| ran the other way (TRANSITION) | (−1, 0) | **0.5123** |

Three histories, three answers, one ball.

**The first draft of gate G measured a ball straight behind and failed.** Not
because the engine was wrong — because the net-ward ready facing is *already*
the worst possible orientation for a ball directly behind, so "turned the wrong
way" and "never turned" are the same number. The fixture was degenerate. Moved
to the side, where the square body sits in the middle with room on both sides of
it. Recorded because a gate that cannot separate its own cases reads exactly
like a gate that passed.

Gate H holds the certified results unchanged: `facing_fit`
1.0000 / 0.8536 / 0.5000 / 0.1464 / 0.0000, turn delay 0.0200 → 0.1995 s, and
**exactly one distinct top speed** across all five.

---

## 4. §8 — **BLOCKED**, on two independent grounds

The policy asks whether the defensive resolver can choose between *retain facing
+ LATERAL* and *turn/open + TRANSITION* from relations that already exist, and
says to stop rather than fake it. It cannot, and the reasons are not the one
this pass expected.

### Ground 1 — there is no cost to opening up

`LocomotionModel.direction_change_seconds` takes a mode, which is why the first
draft of `run_defensive_form_probe.gd` asserted this half was solved. Measured,
it is not:

| `facing_fit` | LATERAL | TRANSITION | difference |
|---:|---:|---:|---:|
| 1.00 | 0.0200 | 0.0199 | −0.0000 |
| 0.50 | 0.1097 | 0.1097 | −0.0000 |
| 0.00 | 0.1995 | 0.1995 | −0.0000 |

Largest difference across every fit: **0.000024 s**. The function normalises each
mode against *its own* reference cadence —
`reference_cadence_hz(mode) / cadence_hz(player, mode)` — so the mode cancels and
what survives is how far this player's turnover sits from their band's midpoint.
That is deliberate and correct for what it does measure. It means the engine
prices **changing direction** and does not price **changing form**.

A comparison whose two branches pay the same entry fee is not a comparison.
Whichever form is faster wins always, which is a rule, not a decision.

### Ground 2 — coverage has no per-form speed

`ENABLE_UNIFIED_SPEED_MODEL` is `false`, so `evaluate_arrival` runs on
`legacy_maximum_speed(player, lateral_speed/100, 4.65)` — one ceiling, no mode
in it.

| rating | coverage today | unified LATERAL | unified TRANSITION | today vs LATERAL |
|---:|---:|---:|---:|---:|
| 20 | 1.9859 | 2.2067 | 3.8180 | −10% |
| 50 | 2.9640 | 2.5961 | 4.5146 | **+14%** |
| 95 | 4.4312 | 3.1802 | 5.5594 | **+39%** |

Obtaining a second form means flipping that flag, and the flag's own comment
records what that does: the legacy ceiling *"runs defenders up to 43% faster
laterally than the stride model allows, which inflates every reach this function
reports."* Every defensive arrival in the game moves, in every direction,
before any form is ever compared. That is a locomotion rebalance wearing an
orientation repair's clothes.

### And a third thing worth knowing

Even with both halves, the comparison would buy less than it looks:

| available time | LATERAL m | TRANSITION m | gain |
|---:|---:|---:|---:|
| 0.30 s | 0.2025 | 0.2025 | 0.0000 |
| 0.50 s | 0.5625 | 0.5625 | 0.0000 |
| 0.80 s | 1.3210 | 1.4400 | 0.1190 |
| 1.80 s | 3.8859 | 5.8181 | 1.9322 |

A defensive window is `ball_time − reaction_delay − turn_delay`, roughly 0.53 s
on a hard-driven ball. Reaching the LATERAL ceiling takes 0.570 s and the
TRANSITION ceiling 0.991 s, so **inside a normal defensive window neither body
reaches its own top speed** and the forms are identical whatever the model says.
The comparison is worth building for long pursuits, and worth almost nothing for
the balls a defender actually plays.

No coefficient was guessed to paper over any of this.

---

## 5. What this pass does *not* yet reach

The outcome mix over 600 rallies is **byte-identical** before and after:
295 home points, kill 151, opponent_kill 164, attack_error 69,
opponent_attack_error 40, counter_block 45, blocked 18, ace 5, serve_error 108.

That is not a null result, and it is not a claim of safety either. The reason is
specific and is the next boundary: `_ready_facings` hands the legacy resolver's
defensive claim a **stationary** side-relative facing for every defender,
because the resolver has no persistent actor to read a moved facing from —
`RallyPlayerState.create` appears exactly twice in `rally_simulator.gd`, both
constructing a fresh actor for one leg.

So orientation now evolves honestly everywhere an actor is carried
(`project_toward`, the four integrators, the opportunity system), and the one
consumer that would show it in a rally outcome still cannot see it.

**Follow-up, and it reverses the recommendation this section originally made.**
Measured with `tools/run_carried_facing_probe.gd` over the same 600 rallies: of
**796** defensive contacts, **2** were made by a body that had already run.
0.3%. Every defensive leg in the resolver is `"lateral"`, and LATERAL preserves
— so a defender cannot change their own orientation, and a carrier built for
them would hold the ready facing they already receive.

Carrying an actor between legs is therefore **downstream of §8, not upstream of
it**. Defenders never change orientation because every defensive leg is LATERAL;
every leg is LATERAL because nothing can select the other form; nothing can
select it because §4's two relations are missing. The boundary did not move.

---

## 6. Tests

`_test_moving_orientation`, six checks. Four fail on the pre-pass resolver,
verified by surgically reverting `apply_position` and the `project_toward`
ordering while keeping every signature so the suite still compiles:

```
TEST FAILED: a backpedalling defender travels backward and stays square to the net
TEST FAILED: a closing blocker stays square to the net rather than facing along it
TEST FAILED: a projected leg adopts its route only when its own form justifies it
TEST FAILED: prior movement leaves a defender genuinely better or worse prepared
```

The two APPROACH/TRANSITION checks pass on both and are **labelled invariants**
in the test itself: the old universal rule also produced route-facing, so they
cannot fail on it. They guard the other direction — that the repair did not
simply freeze facing everywhere.

Suite: **2,123 checks, no failures** — 2,117 plus exactly the six written, so no
sampling population moved.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_moving_orientation_probe.gd
godot --headless --path . --script res://tools/run_defensive_form_probe.gd
```

Both are deterministic and reproduce exactly.
