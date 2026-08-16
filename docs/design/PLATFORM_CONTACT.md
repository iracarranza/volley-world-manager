# The Platform Contact

Design pass: 2026-08-16. Status: **DESIGN. Nothing here is implemented.**

Covers the four contacts a voli makes with the forearms: serve reception, the
controlled floor dig, the emergency dig, and attack coverage.

`docs/design/CONTACT_AND_BALL_FLIGHT.md` is normative where the two disagree.
This document is the answer to its UNRESOLVED PHYSICS items 1, 2, 3, 4 and 6,
which are one question rather than five.

---

## 0. The thing this replaces

Today the event family chooses the ball:

```gdscript
if RECEPTION: apex = contact_height + lerpf(1.45, 3.80, execution)
if DIG:       apex = contact_height + lerpf(1.35, 3.05, 1.0 - spoil)
if COVERAGE:  apex = 1.8   # and duration 0.58, invented after the rally
```

Three independent opinions about one physical act, none derived from the ball
that arrived. The redesign log's §13 states the objection: reception and the dig
may legitimately produce different balls, but the difference must come from
intent, contact state and execution — not from which enum arm the code took.

---

## 1. The four contexts as they stand

Audited in `rally_simulator.gd` at `5ba5cee`. **"Emergency dig" has no row of its
own because it has no code of its own** — there is one `_dig_pass_result` with
three callers and a posture vocabulary that does not contain it.

| | serve reception | controlled dig | emergency dig | attack coverage |
|---|---|---|---|---|
| resolver | `_reception_pass_result` | `_dig_pass_result` | *(none)* | *(none)* |
| intended target | `desired_target`, a point | `desired_target`, a point | — | contact + `Vector2(0.04, ±0.05)` |
| intended recipient | `setter` passed in | `setter` passed in | — | none |
| intended height/shape | **none** | **none** | — | **none** |
| incoming trajectory | passed; **read only by recovery** | passed; read for *direction only* | — | in scope, unread |
| incoming pace | `serve_force` + `_incoming_ball_speed` → recovery only | `_incoming_ball_speed` → diagnostic only | — | not computed |
| arrival / reach margin | `reach_margin_meters`, `edge_ratio` | `reach_margin_meters` | — | **none** |
| body velocity | `contact - start` as a **vector** | travel **scalar** only | — | none |
| posture | derived in-model | passed in as a string | — | **none** |
| contact position | passed | passed | — | the rebound point |
| contact height | `pass_contact_height_meters` | `pass_contact_height_meters` | — | **not computed** |
| execution inputs | reception, ball_control, reception_balance, reception_stability, alignment, settle, redirect, force | `_defense_terms.quality` (one scalar) | — | `coverage_quality` (one scalar) |
| RNG | **two normal draws** | **none** | — | one uniform, before the contact |
| horizontal error | stochastic, symmetric, `pow(1-execution, 1.35)` | **deterministic**, downrange bias + `digger.id % 2` lateral sign | — | **none** — fixed offset |
| vertical rule | `lerpf(1.45, 3.80, execution)`, plus a shank branch below 0.18 | `lerpf(1.35, 3.05, 1 - spoil)` | — | constant 1.8 |
| duration | `duration_for_apex` | `duration_for_apex` | — | constant 0.58 |
| outgoing consumer | set release height, jump-set decision, `_set_arc` clamp | same | — | **nothing** — the trajectory is display-only |

### Three defects the table exposes

**The dig's largest posture penalty cannot fire.** `_dig_pass_result:9693`
matches `"emergency", "fall"` for a penalty of 0.80. `"fall"` is a *recovery
state* — `platform` / `knee` / `fall` / `blown_away`, produced at `:10425` as a
**consequence** of the contact — and `"emergency"` is produced nowhere at all.
The posture classifiers emit only `planted`, `reaching`, `off-axis`, `moving`,
so the achievable maximum is `reaching` at 0.55.

This is why the measured spoil ceiling is 0.745 rather than anything near 1.0,
and it means the 1.35–3.05 band was calibrated with a third of its intended
range switched off. **That band should not be ported forward**, and this is the
reason — not a preference.

**Incoming momentum is computed and discarded.** `_incoming_ball_speed` and
`_incoming_ball_force` run on both families and reach only the recovery state
and the diagnostics. The one physical quantity that most obviously decides what
a platform can do with a ball is measured, published, and not consulted by
either outgoing model.

**The two horizontal models are structurally different, not differently tuned.**
Reception scatters stochastically and symmetrically about its target; the dig is
fully deterministic, biased downrange, with its lateral sign taken from
`digger.id % 2`. One family draws and the other does not, so "preserve the
existing RNG" cannot mean the same thing for both.

---

## 2. The shared input contract

```text
PlatformContactIntent      what the voli is trying to produce
PlatformContactState       what contact was physically available
PlatformContactExecution   how well they realized the intent inside that
    ↓
PlatformContactResult      the outgoing launch state, and what it was worth
```

The load-bearing claim is the middle one. **Circumstance does not degrade the
ball; it narrows the set of balls available.** Execution then picks somewhere
inside that set, further from the intent the worse it is. Nothing in this model
says a bad contact goes low, and nothing says it goes high.

---

## 3. Intent variables

Five fields, which is the minimum that separates the four contexts:

| field | meaning |
|---|---|
| `target_point` | where the ball is meant to go |
| `target_tolerance_meters` | how precise the attempt is — a radius, not a promise |
| `desired_contact_height_meters` | how high the *next* contact wants it, 0 for "don't care" |
| `desired_hang_seconds` | recovery time being asked for, 0 for "as soon as feasible" |
| `intended_recipient_id` | who it is aimed at, or −1 |

The four contexts differ only in these values:

| | tolerance | desired height | hang | recipient |
|---|---|---|---|---|
| serve reception | tight (setter's hands) | setter's reach | minimal | the setter |
| controlled dig | a setting zone | setter's reach | **deliberately more** | the setter |
| emergency dig | own side of the court | 0 — don't care | 0 | −1 |
| attack coverage | own side, broad | 0 | 0 | −1 |

That is the whole of the "four contexts" distinction. There is no fifth kind of
platform.

> `intended_recipient_id` is **intent and nothing else**. It may not terminate a
> flight, and it may not be used to pick the second contact. §9 of the spec
> already measured the cost of letting it: the actual second-contact actor
> differs from the designated setter on about 22.8% of successful digs.

A controlled dig asking for *more* hang than a reception is the model's answer to
"should a dig be higher than a pass?" — sometimes yes, and it should be because
the team wanted the time, not because the enum said `DIG`.

---

## 4. Contact and circumstance variables

What was physically available, all of it already resolved somewhere today:

| field | source today |
|---|---|
| incoming velocity (direction and speed) | `incoming_trajectory` + `_incoming_ball_speed` |
| contact position | resolved by every context |
| contact height | `pass_contact_height_meters` |
| contact time | resolved by every context |
| arrival margin | `reach_margin_meters` (reception, dig) |
| lateral offset from the body | `edge_ratio` (reception only) |
| body velocity | vector in reception, scalar in the dig |
| posture | `planted` / `reaching` / `off-axis` / `moving` |

**These constrain two things and only two:**

1. **How much of the incoming speed the platform can retain or add.** A planted
   passer can absorb almost all of it or drive through it; a diving arm can do
   neither and returns roughly what it was given, minus a lot.
2. **What platform angles are reachable.** A ball met at the waist in front of
   the body can be angled almost anywhere. A ball met at full stretch, wide,
   below the knee, can be angled through a few degrees and no more.

That is the feasible envelope. It is a *range*, not a penalty.

**Coverage's missing state is class B, not C.** Everything above is derivable at
the three coverage sites from values already in scope: `coverer_start`, the
deflection's `end_time` and duration, `_movement_time`, `_reached_point`, and
`pass_contact_height_meters`. Coverage has no arrival or posture because nobody
computed them, not because they are unknowable.

---

## 5. Execution variables

Execution answers one question: **how far from the intended platform angle and
intended speed retention did this contact actually land?**

| field | source today |
|---|---|
| platform technique | `reception`, `ball_control` |
| stability under load | `reception_stability`, `reception_balance` |
| already-resolved contest outcome | `reception_quality` / `_defense_terms.quality` |
| the existing draws | reception's two normals; the dig's contest draw |

Execution error is expressed as **an angular deviation of the platform plus a
proportional error in retained speed** — the two things a passer actually gets
wrong. It is not a destination offset and not an apex penalty.

This is where attribute failure lives, and it is the only place it lives.

---

## 6. The outgoing result contract

```text
PlatformContactResult
    launch_position          Vector2      (the contact point)
    launch_height_meters     float
    launch_time_seconds      float
    outgoing_speed_mps       float
    outgoing_direction       Vector2      (horizontal bearing)
    outgoing_vertical_mps    float
    control                  float        derived, see §7
```

Everything the game currently reads is downstream of that and derived, not
stored: apex is `vertical² / 2g` above launch, duration and destination come from
`BallFlightModel`, and the second-contact height is *wherever the ball actually
is when someone reaches it* — which is what §5 of the spec means by a realized
segment.

**There is no apex band, in any context.** The apex is a consequence.

### How the vertical falls out

Intent asks for a ball at height `h` after time `t`. Given the actual contact
height, that is a required vertical launch speed — one call to the existing
`BallFlightModel`. Feasibility says whether that vertical speed is inside the
envelope this contact can produce. If it is, execution deviates from it. If it
is not, the voli produces the closest thing the envelope contains, which is the
physical meaning of "they did what they could with it".

An intent with `desired_height = 0` (emergency, coverage) asks only for a ball
that stays inbounds and is reachable by somebody, so its vertical is whatever
the envelope's centre offers — genuinely unconstrained, which is what those
contexts mean.

---

## 7. What survives of `quality` and `spoil`

**`spoil` does not survive.** It collapses feasibility narrowing, posture and
execution error into one scalar, and those three must stay separate or the whole
intent/circumstance/execution split means nothing. It is also the carrier of both
authored fictions this document exists to remove — the apex band and the
`digger.id % 2` lateral sign.

**`quality` survives, with its causal direction reversed.** Today it is an input
that decides the ball. It should be an **output**: how close the realized ball
came to the intent, in the units the intent was stated in. That makes it
comparable across contexts for the first time — a 0.7 coverage contact and a 0.7
reception currently mean different things and are read by the same downstream
code.

**`platform_feasibility` survives and is promoted.** Reception already computes
very nearly the envelope this design needs; it just spends it on a scalar
instead of using it as a constraint.

**Reception's `execution` survives** as an execution-error magnitude, which is
what it already is.

---

## 8. Attribute failure versus circumstantial difficulty

No rule anywhere says which way a bad ball goes. Both cases are the same two
equations with different inputs:

**Good circumstance, poor execution.** The envelope is wide — a planted platform
under a driven serve has plenty of pace to work with and can angle it anywhere.
Poor technique misses the intended platform angle by several degrees. Several
degrees of a *fast* ball is a long way: it goes hard, and to the wrong place —
over the net, into the antenna, off the court. **A shank, and fast.**

**Poor circumstance, good execution.** The envelope is narrow. An arm scraped
under a dying tip has almost no incoming pace to redirect and no posture to
generate from, so the reachable set is small and slow. Executed perfectly, the
ball goes exactly where the voli intended it to and barely gets there. **Weak,
short, and controlled.**

**Poor circumstance, good execution, fast ball.** A libero who gets a platform to
a hard-driven spike at full stretch: the envelope is narrow in *angle* but the
incoming pace is enormous, so what is reachable includes a very high ball. Angle
it up and it pops five metres. **The rescue ball — and it arrives without a rule
granting it**, purely because the energy was there and the angle was available.

That third case is the one the current model cannot express at all, and it is the
one the redesign log's §12 asked for by name.

---

## 9. Must incoming momentum participate? Yes

It is the answer to §8 and it is what makes the reception/dig band difference
dissolve rather than get re-tuned.

The three contexts face structurally different incoming balls: a reception meets
a serve at 13–15 m/s of horizontal pace; a dig meets a spike, harder; coverage
meets a ball that has just been stopped by a pair of hands and has almost
nothing left. **The band differences the two families currently hard-code are
approximately what incoming pace would produce anyway** — which is why they look
plausible and why they resist tuning: they are a real effect encoded in the wrong
variable.

The quantity is already computed on both families and already discarded. Wiring
it into the outgoing model is REMOVING FICTION in the strict sense the spec
defines: the simulator has the number and the consumer carries something else.

---

## 10. What is still AUTHORING PHYSICS

Four relations, named honestly. Each replaces more than it costs.

1. **Speed retention.** What fraction of incoming speed a platform returns, as a
   range across posture. Real, measurable in the sport — pass speeds off serves
   are observable — and it has a physical form (restitution) rather than being a
   curve fitted by eye.
2. **Generation capacity.** How much speed a voli can *add* from a given posture,
   which is what makes a tip save hard and a planted platform able to drive a
   ball.
3. **Reachable platform-angle range** as a function of contact height, arrival
   margin and lateral offset. This is the envelope's shape.
4. **The execution-error to platform-angle mapping**, in degrees, scaled by
   technique. The swing already has the analogue —
   `AttackSwingModel.vertical_spread_degrees` — so this is the one item with an
   existing pattern to follow rather than a blank page.

What they replace: two apex bands (four constants), the shank branch (two), the
dig's four spoil weights, the `digger.id % 2` rule, coverage's 0.58 and 1.8, and
three fixed target offsets. **Four authored relations for sixteen authored
numbers**, and each of the four is a quantity somebody could go and measure.

None of them may be chosen by eye. Each needs a distribution and an acceptance
criterion before it is promoted, which is what §11 is for.

---

## 11. The smallest safe first slice

**Slice 1 — intent, published, inert.** Attach the five intent fields of §3 to
every platform contact and publish them on the event. Nothing reads them. This is
provably outcome-neutral — rallies must be byte-identical — and it makes the
four contexts' differences countable for the first time, the way `height_source`
made the height gap countable.

**Slice 2 — the envelope as a shadow.** Implement §§4–6 as a resolver that runs
beside the current one, publishes what it *would* have produced, and changes
nothing. Then measure: outgoing speed, vertical, apex, destination error, and how
often the current model's ball lies outside the envelope the shadow says was
available. That measurement is what the four authored relations get calibrated
against, and it is the only honest way to introduce them. The repository has run
this pattern twice before, for the block and for reception.

**Slice 3 — promote one context.** The controlled dig, because it has the richest
state and the worst current model, and because it is where the `id % 2` rule
lives. One context, measured, before any other moves.

**Slice 4 — coverage's contact state.** Resolve arrival, posture and contact
height at the three coverage sites from values already in scope (§4). All class
B, no new physics.

**Slice 5 — reception and coverage promoted; the bands and `spoil` deleted.**

Do not reorder these. Slice 2 before slice 3 is the whole safety argument.

---

## 12. Can coverage own its ball afterwards? Yes — after slice 4

The blocker recorded in `CONTACT_AND_BALL_FLIGHT.md` was that coverage's apex is
class C and the `spoil` that would drive it needs a posture and an arrival that
coverage never resolves.

This design removes both halves. There is no apex to supply, because the apex is
a consequence of intent and envelope rather than an input. And coverage's intent
is expressible in the §3 fields without inventing anything: broad tolerance, own
side, no desired height, no hang requirement, no recipient — which is exactly
what "keep it alive" means.

What remains is coverage's contact state, and §4 establishes that every field of
it is derivable from values already in scope at all three call sites. That is
slice 4, it is class B throughout, and after it coverage resolves its outgoing
ball once, publishes it, and hands it to `_resolve_home_continuation`, which has
been accepting `incoming_pass_trajectory` since the dig pass and receiving
nothing.

---

## What this document may not be used to justify

- Creating `PlatformContact` classes because they are named here. The redesign
  log says this and it is repeated because it has happened before.
- Promoting any of the four authored relations without a measured distribution.
- Reordering the slices to get to coverage faster.
- Porting either apex band into the envelope as a default. The dig's was
  calibrated against a dead branch (§1); reception's carries an unreachable shank
  arm whose minimum realized rise, measured over 663 receptions, is 2.231 m
  against a branch that turns on below 1.873 m. Neither is evidence of anything
  yet, and neither is disproven.
