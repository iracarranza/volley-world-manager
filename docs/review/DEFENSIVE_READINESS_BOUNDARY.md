# BLOCKED: a resting defender has no direction they are prepared to defend

Run: 2026-08-16, from `7e1bb2e`. Instrument:
`tools/run_defensive_readiness_probe.gd`. **No production change.** This is
SUCCESS C under the defensive-responsibility goal: the pass stopped at audit
step 0, which is where the policy told it to stop if the answer came back NO.

The question, from the policy's §12:

> Does `RallyPlayerState.facing` contain meaningful direction for **defenders at
> rest**?
>
> If YES — missing defensive use of velocity/facing is PLUMBING; propagate it.
> If NO — this is a MISSING PHYSICAL STATE. STOP and demonstrate it before
> calibration.

**The answer is NO**, and it is worth being precise about *why*, because the
failure is not the one the phrasing anticipates. `facing` is not unset by
oversight. It is **actively overwritten with the direction of travel on every
leg**, which pins the term that would price preparation at its best possible
value for every voli, always.

---

## 1. The proof, in three layers

Deterministic throughout — no rally resolved, no RNG drawn. One defender at
(0.50, 0.80), one ball at (0.62, 0.66).

### Layer 1 — the movement model **can** price preparation

`_movement_profile` computes `facing_fit = (facing · direction + 1) / 2` and
spends it on the direction-change delay and on arrival balance. Driven with an
honestly-set facing, velocity zero in every row:

| facing | `facing_fit` | travel | turn delay |
|---|---:|---:|---:|
| toward the ball | 1.0000 | 1.3739 s | 0.0200 s |
| 90° across | 0.5000 | 1.4636 s | 0.1097 s |
| **away from the ball** | **0.0000** | **1.5534 s** | **0.1995 s** |
| the class default (0, −1) | 0.9596 | 1.3811 s | 0.0272 s |

**The capability exists and behaves exactly as §11 requires**: a body prepared
the wrong way pays ~0.18 s of extra startup — 13% of the trip — through a turn
cost, and `maximum_speed` is untouched. Preparation buys a cheaper first step,
never a faster body.

That last row matters: the class default is `Vector2(0, −1)`, which in this
fixture happens to sit 0.96 aligned with the route. A constant default is not a
neutral value; it is an arbitrary one whose helpfulness depends on which way the
ball happens to be.

### Layer 2 — the resolver carries momentum across the boundary, but not stance

`_travel` is the resolver's only route into that model. It takes an
`entry_velocity` and has **no facing parameter**; it builds a fresh actor and
sets `actor.facing = opening.normalized()`, with the comment:

> *The resolver does not track facing at this point, and charging a full
> reorientation the player may not need would reintroduce a second disagreement.
> Face the route; the turn floor still applies.*

| caller supplies | travel | Δ |
|---|---:|---:|
| nothing (standing) | 1.3739 s | — |
| **velocity 1.5 m/s toward** | **1.1380 s** | **−0.2359** |
| velocity 1.5 m/s away | 1.3739 s | 0.0000 |
| facing toward — inexpressible | 1.3739 s | 0.0000 |
| facing away — inexpressible | 1.3739 s | 0.0000 |

The two velocity rows differ, so **momentum survives the boundary** — and
correctly: backward momentum is not credited, because
`directional_start_speed = max(velocity · direction, 0)`. The two facing rows
cannot differ, because there is no argument to differ in.

So the two halves of `RallyPlayerState` are treated very differently at exactly
the place the policy cares about.

### Layer 3 — the defensive claimant never sees an actor at all

`CoverageCalculator.evaluate_arrival(player, zone, landing, ball_time, skill,
origin, unassigned_reach)` takes a `VolleyballPlayer` and a **point**. No
`RallyPlayerState`, therefore no velocity, no facing, no body state. Its only
startup term is `reaction_delay = lerp(0.56, 0.18, anticipation)` — one scalar
per voli, identical in every direction.

Four balls, same distance, four sides, all comfortably reachable:

| ball arrives | reachable | reach margin |
|---|---|---:|
| in front | yes | 1.0840 m |
| behind | yes | 1.0840 m |
| left | yes | 1.0840 m |
| right | yes | 1.0840 m |

**Four directions, one answer.** This is §11's named failure verbatim: *"make all
stationary volis equally ready in every direction."*

---

## 2. Where the signal dies

| | |
|---|---|
| `RallyPlayerState.facing` | defaults to the constant `Vector2(0, −1)` |
| `apply_position()` | updates facing **only when velocity is non-zero** — a standing defender never updates it |
| `_travel()` | overwrites facing with the route direction on every call |
| `evaluate_arrival()` | never receives an actor |

**No system anywhere decides which way a defender is oriented while waiting for
an attack.**

A second field has the same shape and is worth recording beside it:
`RallyPlayerState.readiness` defaults to `1.0` and is **never written** anywhere
in the codebase outside `snapshot()`'s copy. `ContactEnvelopeSystem` reads it as
`readiness_factor` and spends it on the contact envelope and the take-off
multiplier — so every voli is permanently at maximum readiness there too. Same
missing state, second consumer.

---

## 3. Why this is a missing relation and not plumbing

The distinction the policy draws is the right one, and this case sits on the far
side of it.

Propagating velocity and facing into `evaluate_arrival` is mechanically easy. It
would also be **useless and misleading**, because the value propagated carries no
information: every actor the resolver builds is faced down its own route, so
`facing_fit` would arrive as 1.0 for every candidate in every situation. The
claimant would gain a term that never varies, and the defect would become harder
to see rather than fixed.

What is missing is not a wire. It is a **rule for what a resting defender is
oriented toward** — and that rule is a physical/behavioural relation nobody has
written. Per §12 and the implementation principle, inventing it here would be
compensating for missing preparation physics, so the pass stops.

---

## 4. What would close it — observations, not a recommendation

Three shapes exist in the codebase's own vocabulary. **None is selected**, and
each has a different gameplay consequence.

1. **Orient toward the ball / the live threat.** The most physically obvious, and
   it makes `facing_fit` nearly 1.0 for a straight-on ball and low for one behind
   — which is what a defender turning to chase actually experiences. Needs a
   published "what is the current threat" direction at the moment of the attack;
   off-ball movement already computes phase targets, so the raw material may
   exist. Consequence: defenders get materially better at balls in front of them
   and worse at balls behind, which is the sport.
2. **Orient toward the assigned zone / responsibility.** Uses `DefensiveZone`
   directly and needs no new read. Consequence: preparation becomes a
   *consequence of the manager's plan* — a defender set deep is genuinely worse at
   a short ball — which is the version with the most tactical texture and the
   biggest behavioural change.
3. **Retain facing from the last committed movement.** Closest to what the fields
   already do, and cheapest: stop `_travel` overwriting, and let
   `apply_position`'s velocity-derived facing persist through the standing case.
   Consequence: smallest, and it only distinguishes volis who have recently
   moved — a defender who has stood still all rally still has an arbitrary
   constant.

Option 3 is the only one that is purely a repair; 1 and 2 are new relations. The
policy's §12 forbids picking one here.

**Also unmeasured until this is decided:** the magnitude. Layer 1 says a full
reversal costs ~0.18 s on a 1.37 s trip. Whether that is the right size for
floor defence has never been swept, and sweeping it before the state exists would
be calibrating a term that is currently constant.

---

## 5. Ledger

| audit step | verdict |
|---|---|
| **0 — resting-defender facing** | **BLOCKED — missing physical state** |
| 1 — blocker landing/recovery propagation | not reached |
| 2 — velocity/facing into defensive arrival | not reached (see §3 — would propagate a constant) |
| 3 — feasibility gate + no-feasible fallback | not reached |
| 4 — immediate possession → short/zone precedence | not reached |
| 5 — fallback ordering | not reached |
| 6 — coefficient calibration | not reached |

Steps 1–6 are not "untested"; they are **downstream of a term that does not yet
carry information**. §11 places ready stance in feasibility/arrival *before*
responsibility ranking, so building the feasibility gate now would bake a
direction-blind arrival into the gate and require redoing it once preparation
exists.

Nothing was calibrated and no claimant weight was touched.

---

## 6. Tests

`_test_movement_model_prices_facing`, three checks:

1. facing fit reads the angle between preparation and the requested direction;
2. a body prepared the wrong way pays a turn cost and arrives later;
3. **preparation does not change top speed, only the cost of starting.**

**These are invariant tests, not repair evidence** — they pass identically before
and after this pass, because this pass changed no production code. They are here
for a specific reason: nothing in the resolver currently supplies a facing that
differs from the route, so `facing_fit` looks like dead weight and could be
deleted as such. If it were, the eventual fix would have nothing to build on.
Check 3 is the one that keeps §11's central prohibition true by construction.

Suite: **2,109 checks, no failures** — 2,106 plus exactly the three written.

---

## 7. The exact next boundary

The rally chain remains certified end to end from `7e1bb2e`. This is not a
regression in it; it is a term inside defensive arrival that has always been
constant, made visible by asking the policy's question.

To resume, the decision needed is one sentence long:

> **What is a defender oriented toward while they wait?**

Once that exists as published state, step 0 flips to YES, steps 1–6 become the
plumbing-and-ordering pass they were written to be, and the magnitude in §4 can
be swept against a distribution instead of guessed.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_defensive_readiness_probe.gd
```

All three layers are exact and reproduce byte-for-byte.
