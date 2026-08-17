# BLOCKED: a resting defender has no direction they are prepared to defend

Run: 2026-08-16, from `7e1bb2e`. Instrument:
`tools/run_defensive_readiness_probe.gd`. **One production repair, then BLOCKED.**

Audit step 0 came back NO. Everything downstream of **stance** stops there — and
that turns out to be a much smaller set than the first draft of this document
claimed.

Two corrections to that draft, both of which came from being pushed on it:

1. **Step 1 — blocker landing/recovery — is not downstream of stance at all.** It
   was a live defect and is repaired; §5 carries it.
2. **Gates C–H are audits of the *existing* selector, not builds on a future
   one.** Missing stance changes arrival *magnitudes*; it does not change the
   *ordering rules* the policy states. Run, they all **PASS**: §§0–10 of the
   policy are already implemented. §6 carries them.

So the honest headline is not "defence is blocked". It is: **the responsibility
policy already holds; only ready stance is missing.**

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

## 5. Step 1 — REPAIRED: a landing blocker was a standing body

Independent of stance, and a live defect. `_note_recovery` is called at exactly
five sites and every one is a **platform contact** — a reception or a dig. So
nothing in the engine ever recorded that somebody was in the air.

`_recovery_time_penalties(rally_clock)` *is* handed to
`CoverageModel.choose_claimant` for the floor defence. For a front-row blocker it
was always empty: the claim search offered them the whole of the next ball's
flight, starting from a body two feet off the ground. That is policy §3 and §10
violated at the one moment they are about.

Measured over 300 rallies:

| | before | after |
|---|---:|---:|
| defensive contacts | 151 | 155 |
| **contacts with any body registered unavailable** | **0** | **72 (46%)** |
| total unavailable bodies across those contacts | 0 | 113 |

**Nothing was invented.** `block_jump_timing` already publishes each blocker's
`hang_seconds` and whether the jump went up late; `BlockJumpModel.jump_timeline`
already turns those into a landing instant; and `hang_seconds` is
`2·√(2·leap/g)` — ballistics, not a tuned number. All three were consumed **only
by playback**, so the engine drew the jump correctly and then forgot about it
when deciding who could reach the next ball. Textbook PLUMBING under the policy's
own classification.

Written straight into `player_recovery` rather than through `_note_recovery`,
because that function looks its delay up in `RECOVERY_DELAY_SECONDS` by name and
the four states there are floor recoveries. Adding a fifth would be inventing a
duration for something the jump model already measures. The record shape is the
one `_recovery_time_penalties` and `_recovery_debt` already read.

An existing floor recovery is never shortened by jumping — a blocker still
getting up who goes up anyway keeps the longer debt.

---

## 6. Gates C–H — the policy's ordering rules already hold

Driven directly against `CoverageCalculator.choose_claimant`, the function both
sides' floor defence calls. Deterministic; no rally resolved.

The selector turns out to have the policy's shape written into it already. Two
structures do the work, and neither is a weighted sum:

```gdscript
if not bool(arrival.get("reachable", false)):
    continue                      ## §0's hard gate, before any score
...
## "The lock, applied before the score is consulted at all. If the ball is
##  arriving inside somebody's immediate envelope it is theirs, and the
##  weighted claim cannot take it off them."
var deciding := owners if not owners.is_empty() else reachable_evaluations
```

### The complete gate table

Gates A and B belong in it too; the first draft listed only C–H, which left the
two most important verdicts implicit.

| gate | fixture | verdict | fails on old behaviour? |
|---|---|---|---|
| **A** §§11–12 stance | resting defender facing toward / across / away | **PASS at the movement model, BLOCKED at the claimant** — see below | **no — invariant** |
| **B** §§3, 10 landing blocker | blocker airborne when the ball comes down | **REPAIRED** | **YES** — 0 of 151 → 72 of 155 |
| **C** §7 anti-steal | ball on voli 1; voli 2 elite, 3.08 m away | **PASS** — lock decides, not the 0.620/0.575 score | no — invariant |
| **D** §5 transfer | responsible voli stranded 13.5 m away, reach margin −10.3 to −12.4 | **PASS** at every ball time 1.40 → 0.35 s | no — invariant |
| **E** §§2, 4 short ball | assigned short defender vs elite deep defender whose reach margin is **larger** (1.275 vs 0.818) | **PASS** — short defender holds it | no — invariant |
| **F** §1 overlap | identical distance, only `zone.priority` differs | **PASS both ways** — 1.032 vs 0.552, flips with the field | no — invariant |
| **G** §0 floor | both volis 13–14 m away, ball in 0.25 s | **PASS** — returns no claimant, caller falls back | no — invariant |
| **H** §9 spacing | two bodies at 0.10 → 5.00 m | **PASS** — reports 0.077 / 0.336 / 0.931 m honestly | no — invariant |

**Gate A's verdict is two-part, and that split is the whole finding.**

- *At the movement model* it **passes**, and is gated in the suite by
  `_test_movement_model_prices_facing` (three checks): facing fit reads the angle,
  a body prepared the wrong way pays a turn cost and arrives later, and
  preparation does not change top speed. §1's table is that gate's measurement.
- *At the defensive claimant* it is **unrunnable**, because `evaluate_arrival`
  takes no actor and therefore no facing. §1 layer 3 is the demonstration: four
  balls, four directions, one answer.

**Only gate B fails on old behaviour.** A–H otherwise pass identically before and
after, and are invariant tests by the goal's own definition — the responsibility
structure was already correct, and gate A's model-level half was already correct
too. There is no "before" for gate A to fail against, because this pass made no
production change to the movement model; claiming otherwise would be
manufacturing evidence.

**Per-candidate terms** — responsibility source and priority, position,
velocity/facing, ball time, turn/startup cost, arrival and reach margin,
recovery, obstruction/crowding, ability refinement and the final claimant with
its reason — are printed for every fixture by
`tools/run_defensive_claim_gates.gd`, one row per candidate, with the
`immediate_lock` / owner count and chosen id on the summary line. The stance
columns read as constants there, which is the boundary rather than an omission.

Gate E is the one worth dwelling on: the deep defender has the **better raw reach
margin** and still does not get the ball, because the short defender's immediate
lock fires first. That is §4 working without any deep-defender penalty existing.

**One observation from gate H, not a defect:** `nearest_teammate_meters` reads
`1000.0` once the other body is out of reach, because the spacing is measured
only across *reachable* candidates. A sentinel inside a metres field is the shape
the second-contact audit flagged for `claim_margin`. Defensible — an unreachable
team-mate is not interfering with your platform — but a consumer that averages
this field will average a sentinel.

---

## 7. Ledger

| audit step | verdict |
|---|---|
| **0 — resting-defender facing** | **BLOCKED — missing physical state** |
| **1 — blocker landing/recovery propagation** | **REPAIRED** |
| 2 — velocity/facing into defensive arrival | **BLOCKED** by step 0 — would propagate a constant (§3) |
| **3 — feasibility gate + no-feasible fallback** | **PASS** — already a hard gate (gates D, G) |
| **4 — immediate possession → short/zone precedence** | **PASS** — gates C, E, F |
| **5 — fallback ordering** | **PASS** — gate D |
| 6 — coefficient calibration | **not required** — no gate failed |

Policy sections, as implemented today:

| §§0–10 responsibility and ordering | **already hold** |
| §§11–13 ready stance | **BLOCKED** on step 0 |

Nothing was calibrated and no claimant weight was touched. Step 2 remains the
only wiring left, and it is worthless until step 0 has an answer: propagating a
facing that is always route-aligned would add a term that never varies.

---

## 7. Tests

`_test_landing_blocker_is_unavailable`, four checks — **the in-situ one fails on
the pre-repair resolver**, verified by disabling the call site and re-running:

1. a blocker still in the air owes the claim search the rest of their hang;
2. that debt expires when they land rather than persisting;
3. a jump never shortens a floor recovery the blocker already owed;
4. **the airborne debt reaches the floor-defence claim search** ← the repair gate.

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

Suite: **2,107 checks, no failures.** 2,106 plus seven written, minus six: the
airborne debt changes who reaches the next ball, so rallies resolve differently
and several sampling gates drew fewer checks. A negative delta is expected when
production behaviour changes; the FAIL line is the signal.

Population movement, **observations only, not tuned**: defensive contacts 151 →
155, and 46% of them now happen with a body still in the air where none did
before.

---

## 8. The exact next boundary

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
