# The Platform Contact

Design pass: 2026-08-16. Status: **DESIGN. Nothing here is implemented.**
Revised the same day by the §3a audit, which changed the intent representation
from one exact launch to anchors plus a derived bound. §§3, 4a, 4b, 6, 11 and 12
carry amendments; **§3a is the reasoning and should be read first.**

**§13 is a second audit**, of whether this model can carry a layered manager
tactical system. It changes no earlier conclusion and adds the missing half:
where preferences come from. Read it before proposing any tactical field, and
read §13.2 before citing the block as a precedent.

**§14 reconciles §13 with `ATTRIBUTE_WIRING_AUDIT.md`** and corrects one of its
conclusions: `tactical_discipline` is a blend weight, so a manager instruction is
*adhered to* rather than obeyed, and §13.3's "named choices override" is wrong.
It also re-orders the implementation — the `AttemptJudgment` correction now comes
before the block proof.

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

**Four questions, in order, and each has a different kind of answer.**

```text
1. TACTICAL INTENT      what does the voli want?            a decision
2. PHYSICAL FEASIBILITY what can this contact produce?      physics
3. SELECTION            which feasible ball do they try?    a decision
4. EXECUTION            how accurately do they hit it?      physics + capability
   ↓
   REALIZED LAUNCH
```

The first draft of this document collapsed 2 and 3, and that was the mistake
worth catching before any code existed.

**The feasible envelope answers exactly one question — what launches this body,
at this contact, off this ball, could physically produce.** It does not know
which of them is a good idea. A voli at full stretch under a hard ball can
physically produce a rocket over the net, a soft ball straight up, and several
things in between; the envelope contains all three and prefers none of them.
Choosing is a separate act, and it is a *decision*, not a physical law.

Collapsing them would have smuggled a preference in as geometry — "take the
centre of the envelope" is a tactical rule wearing a physicist's coat, and it
would have been unfalsifiable because nothing would have named it.

**Circumstance therefore does not degrade the ball; it narrows the set of balls
available.** The voli chooses inside that set, and execution lands somewhere near
what they chose. Nothing here says a bad contact goes low, and nothing says it
goes high.

This also gives the model **three distinct ways to produce a bad ball**, which the
old scalar could not tell apart:

| failure | meaning |
|---|---|
| narrow envelope | there was no good ball available — circumstance |
| poor selection | a good ball was available and they went for the wrong one |
| poor execution | they chose well and mishit it |

A voli who overpasses a free ball did not necessarily mishit it. That distinction
does not exist in the engine today.

---

## 3. Intent variables

**Revised 2026-08-16 by the §3a audit.** The first version of this table had five
fields naming one exact launch. Three of the five changed shape and one was
deleted; §3a is the reasoning and it should be read before this table is used.

| field | shape | meaning |
|---|---|---|
| `purpose` | label | which context this is, for diagnosis only |
| `target_anchor` | **anchor** | where the ball is meant to go — a preferred place, not a constraint |
| `height_anchor_meters` | **anchor** | preferred height **at that place**, or *unset* |
| `arrival_floor_seconds` | **one-sided bound** | before this the ball is not more useful, or *unset* |
| `intended_recipient_id` | id | who it is aimed at, or −1 |

`target_tolerance_meters` is **deleted** — §3a explains why a radius is the wrong
instrument and why an anchor needs none.

Three fields, three different shapes, and the shapes are not a stylistic choice:
**each one matches what the simulator can actually derive.** Time has a derived
floor and no derived ceiling. The target and the height have derived anchors and
no derived widths. A representation that gave all three the same shape would have
had to invent whatever the shape demanded and the data did not supply.

> **Intent does not name a launch.** It names anchors to be near and a bound not
> to violate. Which launch is attempted is §4a's, against §4's envelope.

### The height field names a place, not a person

It was `desired_contact_height_meters` in the first draft, and that name asserted
something the model must never assert: that the intended recipient is the one who
touches the ball, at that height. **They are not, and §9 of the spec measured it —
the actual second-contact actor differs from the designated setter on about 22.8%
of successful digs.**

The renamed field says what a passer can actually intend: *"around there, around
that high, around then."* Where the ball genuinely ends up being contacted is
free-flight interception, resolved later, by whoever gets there.

> `intended_recipient_id` is **intent and nothing else**. It may not terminate a
> flight and it may not pick the second contact. It exists so a pass can be aimed
> at a person, which is real, and so that aiming at them can be *wrong*.

### Context supplies a default policy, not a shape

The four contexts differ in their **purpose**, and purpose suggests a starting
policy:

| | usual purpose | how much the anchor matters | recipient | has one today? |
|---|---|---|---|---|
| serve reception | deliver a settable ball | a great deal | the setter | **yes** — `_desired_pass_target(preferred_release, …)` |
| controlled dig | recover the rally | somewhat | the setter | **no** — see §4b |
| emergency dig | survive the contact | barely | −1 | no context exists |
| attack coverage | keep the ball alive | hardly at all | −1 | **no** — a fixed offset |

The third column is **prose about purpose, not a field**. It was
`usual tolerance` while intent carried a radius; §3a deletes the radius, and how
strongly an anchor pulls is a selection weight rather than a property of the
intent record. The column stays because the ordering in it is real and a later
pass will need it.

**Only the reception aims at anything.** The controlled dig and coverage both aim
at a fixed small offset from their own contact point, which is not a setting zone
and not a person. §4b traces it.

**But the height and time fields are not in that table, and that is deliberate.**

The first draft put them there — reception "minimal hang", controlled dig
"deliberately more" — and that is the old event-specific apex band moved up one
layer and given a better name. `if DIG: more hang` is the same defect as
`if DIG: apex band 1.35–3.05`; it is merely harder to see.

Height and time are **rally state, not context**:

- an ordinary reception off a readable serve wants a direct, low, fast ball,
  because the setter is already there;
- a reception from deep in the corner off a hard jump serve may want to buy the
  setter two extra strides, and buys them with height;
- a controlled dig usually wants recovery time, because the offence has to
  rebuild from nothing;
- **a transition dig with the setter already stood in base may want the same
  direct ball a good reception wants** — the offence is already assembled;
- an emergency contact may want nothing but survival, and precision goes.

So: context proposes, rally state disposes. Whatever eventually computes these
two fields must read where the setter is, how much of the offence is assembled,
and how rushed the contact is — not which enum arm it was reached from.

That computation is **not authored in this pass**. What is settled here is only
that it may not be a per-context constant.

---

## 3a. Is intent a point or a region? — audited 2026-08-16

The first two drafts of this page assumed intent ultimately names an exact
`(target, height at target, time to target)`, which uniquely specifies one
ballistic launch. That is mathematically sufficient — §4b works the arithmetic —
and it is the wrong model. This section is the audit, and it rejects **both** the
exact-launch form and the obvious replacement.

### Why "a voli does not compute exact numbers" is not the argument

It is the first argument that comes to mind and it proves too much. A server does
not compute an exact launch either, and the canonical forward serve — this
repository's one certified forward contact — is built on aim → one intent speed →
execution perturbation → one launch. If cognitive realism were the test, that
model would be wrong too, and it is not.

The real distinction is which side the binding constraint sits on.

**A server's envelope is wide and their intent is what selects.** Standing behind
the line, unhurried, on their own toss, essentially the whole envelope is
available; there is no ordinary case where the intended serve is physically
impossible. Intent-as-point is fine because nothing else is competing to choose.

**A platform contact is the opposite: circumstance binds, not choice.** §8 of this
page is built entirely on that — "poor circumstance, good execution" produces a
ball that goes exactly where the voli intended and barely gets there. That
sentence only means something if intent had slack for circumstance to eat. An
exact-launch intent has no slack by construction.

### And the serve does not actually use an exact intent

Checked in `geometric_attack_resolver.gd::_serve_launch` rather than assumed, and
the answer reverses the precedent:

```gdscript
var relief_floor := minf(reach_floor, full_speed)
for step in range(SERVE_PACE_RELIEF_STEPS):
    var trial := lerpf(full_speed, relief_floor, …)
```

The serve names a **preferred** pace, relaxes it toward a floor that is
`BallFlightModel.minimum_speed_to_reach` — *derived*, since `829ec7a` — takes the
quickest trial that clears the net, and keeps a `forced` fallback (the highest
ball at the tape) for when nothing clears at all.

That is an anchor, a derived bound, a preference direction and a defined answer in
the infeasible case. **The shipped, certified serve is already intent-as-anchors,
not intent-as-point**, and the pace-relief floor's own history is the lesson that
the bound must be derived rather than dialled.

### The decisive argument: the point form exists only to skip a stage it cannot skip

Exact intent buys exactly one thing — it lets the controlled dig skip §4a, because
a feasible point has a single candidate. But it can only be a point if something
supplies the third scalar, and §4b already traced that scalar to class D:
underivable, unauthored, and gating slice 3.

> **The point form does not avoid an unbuilt component. It swaps an unbuilt
> selection rule for an unbuilt intent policy — and the selection rule is needed
> regardless**, for coverage, for the emergency regime, and for every controlled
> dig whose intended launch turns out infeasible.

One unbuilt thing is better than two.

### Why the obvious replacement is also wrong

The natural alternative — target *region*, acceptable height *range*, earliest and
latest useful arrival — **authors more numbers than the form it replaces**, and
that has to be said plainly because it is the shape the question invites:

| proposed field | where would its bound come from? |
|---|---|
| earliest useful arrival | `_movement_time` to the release seat — **derived** ✓ |
| latest useful arrival | nothing derives it ✗ |
| acceptable height range, low and high | nothing derives either edge ✗ |
| target region radius | nothing derives it ✗ |

Four of five bounds would be invented. A range is also the wrong *shape* even
where a width could be found: it is flat inside and infinitely bad outside, so it
authors a **cliff** at a boundary nobody measured, and it cannot rank two launches
that are both inside it. Volleyball intent is graded — a ball 20 cm high is
slightly worse, not identical-then-suddenly-a-disaster.

### What is actually derivable, and it is heterogeneous

| quantity | what the simulator has | shape it supports |
|---|---|---|
| release seat `T` | `setter_release_target()`, both sides, manager policy | an **anchor**, no radius |
| standing release height `h₁` | `set_contact_height_meters(setter, false)` | an **anchor**, no width |
| setter arrival `t₀` | `_movement_time`, existing locomotion model | a **floor**, no ceiling |

Three quantities, three different shapes. **The heterogeneity is the finding.**
Any uniform representation — all points, or all ranges — has to manufacture
whatever the uniformity requires and the data does not provide.

### The brief's own two examples resolve cleanly under this

**`travel_time = 0` does not mean the ball should arrive in 0 seconds.** Under the
point form that is an outright defect requiring a margin to patch. Under a floor
it is automatic: `t ≥ 0` is simply *slack*, so the arrival bound stops binding and
the anchors and the preference decide. A setter already at the seat does not
compress the ball to nothing; they stop constraining it.

**`set_contact_height_meters(setter, false)` is an anchor, not an assertion.** As
an equality it claims the intended setter contacts the ball at that height, which
§9 of the spec measured false on 22.8% of successful digs, and which is also
wrong whenever the actual interceptor jumps, is shorter, or is somebody else. As a
preferred height *for the ball at the target region*, it survives all three,
because it asserts nothing about who arrives.

### Evidence that the point form silently absorbs preferences

This is not hypothetical. `_desired_pass_target` already does it:

```gdscript
# A distant passer aims slightly higher/off the net to reduce overpass risk
var safety_offset := clampf((distance_meters - 4.0) * 0.006, 0.0, 0.045)
return Vector2(release_target.x, clampf(release_target.y + safety_offset, 0.55, 0.70))
```

That is **a selection preference — avoid the overpass, §4a's second bullet —
compiled into the target point**, at the cost of five bare numeric literals that
are not even named constants, and therefore cannot be found by
`audit_unmeasured_constants.py` or referenced by any gate.

When intent must be a point, preferences do not go away. They get baked into the
point as authored offsets, in the least visible form available. That is the
mechanism this audit exists to stop, and one instance of it is already shipped.

### The verdict, and the strict-dominance claim

**Intent is anchors plus at most one derived bound. It does not name a launch.**

The minimal shippable preference — *satisfy the arrival floor, then be as near the
anchors as the envelope allows, breaking ties toward the earlier ball* — has one
criterion and no weights, so it can be named without authoring anything. Against
the point form's own degenerate policy (`t = t₀`, which §4b offered as the
fallback), it is strictly better:

| case | point form, `t = t₀` | anchors + floor, minimal preference |
|---|---|---|
| the `(T, h₁, t₀)` launch is feasible | that launch | **the same launch** — the floor binds at `t₀`, both anchors are hit exactly, so it maximises the preference |
| it is not feasible | intent is infeasible, selection unresolved, no ball defined | the preference still ranks the feasible set; a ball comes out and the binding constraint is nameable |

Identical where the easy case holds, defined where it does not, and one fewer
authored number. That is the whole argument.

### What this does not fix

It does not remove the trade-off. Deciding *how much* to prefer an earlier ball
over a nearer-to-anchor one is the same tactical question §4b called the missing
rally-intent policy — it has moved from intent into selection rather than
disappearing. The gain is that it is now **one** open question instead of two, it
sits in the layer that is allowed to be wrong (§10a), and the model has defined
behaviour without it.

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

That is the feasible envelope. It is a *range*, not a penalty, and it is a range
of **launches the contact could produce** — not a ranking of them.

> **The envelope has no opinion.** It does not contain a best ball, a default
> ball, or a centre worth taking. Asking it "what happens if the voli has no
> particular intent" is a category error: something still has to choose, and that
> something is §4a, not this.

**Coverage's missing state is class B, not C.** Everything above is derivable at
the three coverage sites from values already in scope: `coverer_start`, the
deflection's `end_time` and duration, `_movement_time`, `_reached_point`, and
`pass_contact_height_meters`. Coverage has no arrival or posture because nobody
computed them, not because they are unknowable.

---

## 4a. Feasible-launch selection — the stage that does not exist yet

Between "what could this contact produce" and "how well did they hit it" sits a
choice, and it is unresolved.

**Amended by §3a: selection is now universal, and that is a simplification.**

The earlier text said selection was trivial when intent was precise and feasible,
and "the whole question" otherwise — two regimes, with the boundary between them a
measured rate nobody had. Since intent no longer names a launch, **every platform
contact runs the same selection stage with the same shape**: maximise the intent
preference over the feasible envelope.

The contexts stop differing in mechanism and differ only in how many constraints
bind. Coverage's "keep it alive" is not a special broad case needing different
machinery; it is this machinery with an unset height anchor and an unset arrival
floor. A reception is the same machinery with all three supplied and pulling hard.

What is still missing is the preference itself. A coverage contact has an entire
envelope of balls that all keep it alive; a reception whose anchored ball the
envelope cannot produce needs the nearest thing it can. Both need an ordering over
feasible launches, and there is none.

> **THE UNRESOLVED DECISION.** Given an intent and a feasible envelope, what makes
> one feasible launch preferable to another?

Candidate considerations, recorded so the question is not re-derived from
scratch, and deliberately **unweighted and unordered**:

- probability the ball stays inbounds and playable;
- avoiding an overpass — a ball that crosses the net is worse than a bad ball
  that stays home;
- recovery time bought for teammates;
- leaving broad setting space rather than a corner;
- how much energy the contact has to spend to get there;
- **nearness to the intent anchors** — added by §3a, and it is the term that
  makes the stage universal rather than a fallback.

**No weights, no constants, no scoring function in this pass.** Writing one here
would be authoring the most consequential rule in the model before anything can
measure it.

### Two things §3a hands this pass for free

**A minimal preference that authors nothing.** *Satisfy the arrival floor; then be
as near the anchors as the envelope allows; break ties toward the earlier ball.*
One criterion, no weights, and §3a shows it reproduces the point form's own
degenerate policy exactly wherever that policy was defined. It is not the answer —
it forecloses tempo entirely — but it means **slice 3 does not have to wait for the
full preference**, only for a named one.

**An authored rule to absorb rather than add.** `_desired_pass_target`'s safety
offset is already the overpass-avoidance bullet above, compiled into the
reception's target point as five bare literals (§3a). When this pass lands it
should *take that rule over*, not sit beside it. A preference order that leaves the
old offset in place would have the same consideration expressed twice, in two
layers, at two strengths — which is the shape §10 of this page exists to prevent.

### Why this is decision logic and not physics

Because it can be *wrong*, and physics cannot. A voli may choose a feasible ball
that turns out badly — that is a read, a habit, a panic, or a bad instruction.
Physics only says what was available.

This has two consequences worth stating now:

1. **It belongs with cognition, not with the launch solver.** It may legitimately
   read what the *voli* believes — where they think their teammates are, what
   they think the ball is doing — rather than ground truth. §8 of the spec fixes
   that direction: authoritative ball → read → decision, never the reverse.
2. **Attributes may reach it**, and they are different attributes from the ones
   that reach execution. Decision-making and technique are not the same thing,
   and a model with both can express the voli who always makes the right choice
   and shanks it, and the one with a beautiful platform who keeps picking the
   wrong ball.

## 4b. Rally-state intent — audited, and it is not ready

The design said the controlled dig could be promoted before the selection pass
"because its intent is precise enough that selection has a single candidate".
**That was asserted, not audited.** This section is the audit.

### A target point and a recipient do not determine a launch

A ballistic flight from a known contact `(P, h₀)` to a target `(T, h₁)` has three
unknowns — horizontal speed, vertical speed, flight time — and two equations,
the horizontal reach and the vertical drop. **One free parameter remains.** The
same dig can put the ball on the same spot at the same height as a low fast ball,
a medium one, or a high slow one, and nothing about "aim at the setter" chooses
between them.

So a controlled dig is vertically underspecified by exactly one scalar, and the
old apex band was the thing secretly supplying it. Remove the band without
replacing that scalar and the model has a hole where its intent should be.

Three intent constraints — target point, height at target, time to target —
determine the launch exactly. The question is where the third comes from.

### What the simulator has at a controlled dig, classified

Traced at all three dig sites: `rally_simulator.gd:3449` (opponent),
`:5639` (home floor), `:6956` (continuation).

| input | class | note |
|---|---|---|
| setter identity | **A** | the *rotational* setter — `lineup.active_setter_id()` / `opponent_team.setter()`. The actual second contact is chosen later by `_second_contact_setter` |
| setter release target | **B** | `defensive_plan.setter_release_target()` and `_opponent_setter_release_target()` both exist, are manager-set policy, and are **already consumed by reception** |
| setter live position | **A** | `live_positions` / `opponent_live_positions`, freshness varies by path |
| setter travel time to the seat | **C** | `_movement_time`, the existing locomotion model, no new constant |
| contact time | **A** | the incoming trajectory's `end_time` |
| defender contact state | **A** | `arrival`, posture, control — **except at `:6956`, see below** |
| tempo / recovery instructions | **B** | `transition_commitment` and `tempo_variation` exist as principles and reach nothing on this path |
| standing set release height | **C** | `set_contact_height_meters(setter, false)` |
| jump-set feasibility | **circular — unusable** | `_jump_set_decision` consumes `pass_apex_meters`, the quantity being derived |
| offence assembly / attackers ready | **D** | no representation of how much of the offence has rebuilt |
| time wanted *beyond* the setter's arrival | **D** | nothing states it |

### Two defects found while tracing

**The controlled dig has no setting target at all.** All three sites aim at
`contact + Vector2(0.03–0.04, −0.03 to −0.05)` — about 0.8 m from where the ball
was dug. **The setter's position is never consulted**; the setter is passed to
`_dig_pass_result` only to supply a *reach height*. The reception, by contrast,
aims at `_desired_pass_target(preferred_release, …)`, a real seat.

So this document's earlier claim that a controlled dig intends "a playable ball
to a setting zone" describes no code. It intends a point a stride away from
itself. The setting target it needs already exists on both sides and is simply
not read.

> **Measured 2026-08-17, and it is four metres.** Slice 1 publishes the anchor
> and the intended recipient side by side, so the contradiction is now countable:
> over 277 controlled digs the published `target_anchor` sits a median **4.054 m**
> from the release seat of the setter the same record names, up to 8.982 m. The
> reception is the control at 0.000 m median, 0.441 m worst.
> `docs/review/PLATFORM_TRANSFER.md` §5a.

**The continuation dig passes `arrival = {}`.** Empty, so `reach_margin` defaults
to 0.0 and `stretched` computes `(0.25 − 0.0) / 0.85 = 0.294` — a 29% stretch
fabricated on every continuation dig.

> **Repaired 2026-08-17.** Not a design question: `cont_defense` carries the
> arrival and the two lines above the call already read it. Measured first —
> 9 resolved continuation passes in 600 rallies, reach margins spanning −0.160 to
> 1.866, and the stretch they imply is 0.000 at the median, so 8 of the 9 were
> charged for a ball they reached comfortably. Spoil p50 0.400 → 0.341,
> destination error p50 0.821 → 0.701, outcome mix unchanged.
> `docs/review/PLATFORM_TRANSFER.md` §7. That is precisely the defect that
disqualified coverage from owning its ball, already live on one of the three
controlled-dig sites.

### Can rally state supply the missing scalar? Partly — and the remainder is D

The physically meaningful thing the vertical knob buys is **time for the setter
to get to the seat**, and that is derivable without circularity:

```text
T   = setter_release_target(setter)                 B, already policy
h₁  = set_contact_height_meters(setter, standing)   C
t₀  = _movement_time(setter, setter_position, T)    C, existing locomotion model
```

None of those reads the dig's apex band, its duration, its `spoil`, or its
outgoing trajectory. The derivation is clean, and it produces the behaviour the
design asked for *without authoring it*: a setter already stood at the seat needs
no time, so the ball wants to be direct; a setter scrambling out of the back
court needs two strides, so the ball wants to be higher.

**But `t = t₀` exactly is a degenerate policy.** It makes every intended ball
arrive with zero margin, which erases the arrival-margin variation the set model
already consumes, and leaves no way for a team to intend a *quicker* transition
than its setter's legs strictly require — which is what tempo means.

> **THE MISSING RALLY-INTENT POLICY.** How much time beyond the setter's bare
> arrival does the team want to buy, and what does it trade away to buy it?
>
> Buying time means a higher, slower ball: easier for the setter, and equally
> easier for the opposing block to form against. That trade is the transition
> tempo decision. `transition_commitment` and `tempo_variation` exist as
> principles and reach nothing here.

That is class D, it is not derivable from anything present, and **it is not
authored in this pass.**

### Amended by §3a — the missing scalar dissolves, and the trade does not

**The margin above was only required because intent had to be a point.** Under
anchors-plus-a-floor, `t₀` is the floor and nothing needs to name a distance
beyond it: the arrival constraint either binds or is slack, and the preference
decides inside whatever the envelope permits. So the class D scalar is gone as a
*field*.

The **trade** it was standing for is not gone. It moves into §4a's preference,
which now has to rank an earlier ball against a nearer-to-anchor one, and that is
the same tactical question in the same units of ignorance. Two things change, and
both are improvements:

1. It sits in the layer that is **allowed to be wrong** (§10a). A margin in the
   intent record is a physical-looking quantity that would have had to be right; a
   weight in a preference is a decision, and a voli or a coach making it badly is
   the thing being modelled.
2. The model has **defined behaviour without it** — the minimal preference in §4a.
   The margin form had none: `t = t₀` was offered as the ship-it fallback and it is
   undefined the moment the `t₀` launch is infeasible.

### And this is how tempo enters without becoming another apex constant

The units test settles it, and it is the reason to prefer the preference form
beyond tidiness.

`transition_commitment` and `tempo_variation` are **dimensionless**, 0–1,
manager-set, already persisted, and already read as a dimensionless pull by
`_identity_tempo_shift`. A weight between two preference terms is also
dimensionless. **The principle can be spent directly as the weight, and no new
quantity is introduced.**

A margin in the intent record is in **seconds**. Converting a 0–1 principle into
seconds needs a seconds-per-unit-principle scale factor, and no such quantity
exists anywhere in the engine. That factor would be a new authored constant, with
units, on the most consequential path in the model — which is exactly the shape of
the apex band this whole document exists to delete, one layer up and harder to
see.

> Tempo is a **weight**, not a **margin**. The weight is free because the number
> already exists and somebody already set it; the margin is not, because it needs a
> conversion nobody has measured.

**The magnitude is still open.** What is settled here is only the form: whatever
the selection pass authors, it may spend the existing principles as weights and it
may not introduce a tempo quantity with units.

### So does the controlled dig bypass the selection problem?

**No, and after §3a it does not even try to.**

The original claim was that once T, h₁ and t are fixed, intent names exactly one
launch, so selection has a single candidate wherever that launch is feasible. The
arithmetic is right and the conclusion was unquantified: a defender stretched under
a hard-driven spike will often be unable to produce the ball the team wants, and
nobody knew how often.

§3a settles it by removing the premise. Intent no longer fixes a launch, so there
is no single candidate to have, and the controlled dig runs the same selection
stage as every other context. What slice 2 measures therefore changes, and gets
sharper — see the restated gate in §11.

**This is the honest cost of §3a**, stated once and plainly: under the point form
slice 3 could have shipped with selection deferred *if* the measured feasibility
rate came back high. It can no longer. Selection must exist for slice 3, though it
may be the minimal no-weight preference of §4a rather than the full one. Set
against that, the class D intent margin that also gated slice 3 is gone, and it had
no prospect of being derived at all.

---

## 5. Execution variables

**This heading was missing.** The section existed with no `## 5.` above it, so the
document ran 4b → 6 and the execution stage — named as stage 4 of the four-stage
contract in §2, and referenced as "§5" by §6 — had no anchor to link to. Found
while revising for §3a; content unchanged.

Execution answers one question: **how far from the *selected* platform angle and
selected speed retention did this contact actually land?**

> The word was "intended" until §3a, and the change is not cosmetic. Execution
> deviates from what the voli **went for**, which is §4a's output, not from what
> they **wanted**, which is §3's anchors. Under the old point form the two were the
> same object and the distinction did not arise; now they are different, and
> measuring execution error against intent would charge a passer for a ball their
> circumstance never made available — which is precisely the conflation of
> circumstance with technique that §2 and §8 exist to prevent.

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

**Rewritten by §3a.** The earlier version of this passage read intent as a
required vertical launch speed, which was the point form stated in the units of
the solver.

Intent supplies a place to be near, a height to be near there, and a time not to
be earlier than. Each of those is a *ranking* over the envelope, not a filter on
it: given the actual contact height, `BallFlightModel` says what each candidate
launch would deliver at the anchor, and the preference says which delivery is
better. Feasibility never has to agree with intent, and intent is never
"infeasible" — it is only more or less well served by what the contact can do.

**Selection therefore always has work to do, and always the same work**, which is
the simplification §3a bought. There is no branch where it is trivial and no
branch where it is undefined. What is missing is only the ranking itself, and §4a
names a minimal one that authors nothing.

An intent with an `unset` height anchor — emergency, coverage — does not resolve
to a default ball. It removes one term from the ranking, which **widens** what
scores equally rather than nominating a member. Something still chooses. An
earlier draft of this page said such a contact takes "whatever the envelope's
centre offers"; that sentence was a tactical rule disguised as geometry, and it is
deleted rather than corrected.

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
Poor technique misses the selected platform angle by several degrees. Several
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

## 9. Must incoming momentum participate? Yes — and it is two separate claims

It is the answer to §8 and it is what makes the reception/dig band difference
dissolve rather than get re-tuned. But the first draft of this section made an
error worth naming permanently, because it is the most tempting error available
to every future pass on this page.

> **Knowing a number exactly is not permission to invent what it does.**

Two claims, and only one of them is settled:

**Claim 1 — REMOVING FICTION, settled.** The incoming velocity is authoritative
and is currently discarded. `_incoming_ball_speed` and `_incoming_ball_force` are
computed on both platform families and reach only the recovery state and the
diagnostics; neither outgoing model consults them. **Omitting the incoming ball
from a model of what a platform does with it is wrong**, and correcting that
omission needs no new physics — the value exists and is exact.

**Claim 2 — AUTHORING PHYSICS, not settled.** The mapping

```text
incoming velocity + posture/platform state + absorption/generation ability
    → outgoing speed
```

does not exist anywhere in this engine, in any form, for any contact. It is a
transfer relation — restitution plus applied force — and it has never been
written, measured, or calibrated here.

**Claim 1 does not license Claim 2.** A pass that says "the incoming speed is
already authoritative, so wiring it in is plumbing" would be smuggling the entire
transfer relation in under a REMOVING FICTION label. That is precisely the trap
§8 of the spec's own history describes, and it is easier to fall into here than
anywhere else on this page, because the input really is exact and the omission
really is a defect.

**So: the incoming ball is a required input from slice 1 onward, and its effect
on the outgoing launch may not be promoted until the transfer relation has a
measured model with an acceptance criterion.** Until then it may be recorded,
carried and measured in shadow — and nothing more.

### Why it will be worth the trouble

The three contexts face structurally different incoming balls: a reception meets a
serve at 13–15 m/s of horizontal pace; a dig meets a spike, harder; coverage meets
a ball that two hands have just stopped and which has almost nothing left. **The
band differences the two families currently hard-code are approximately what
incoming pace would produce anyway** — which is why they look plausible and why
they resisted tuning. They are a real effect encoded in the wrong variable.

That is a hypothesis with a measurement attached, not a result. Slice 2 is where
it gets tested, and it may fail.

---

## 10. What is still AUTHORING PHYSICS — three relations, not four

The first draft listed four. Two of them were one relation counted twice:
"speed retention" and "generation capacity" are the absorbing and the driving
halves of a single map from incoming speed and posture to outgoing speed. A
platform that returns 40% of a hard ball and one that adds 3 m/s to a dead ball
are the same function evaluated at different inputs, and splitting them would
have produced two authored curves that have to be kept consistent by hand — the
defect this whole document exists to remove.

**T1 — the transfer relation.** `incoming speed + posture/platform state +
absorption-generation ability → outgoing speed`. This is §9's Claim 2. It has a
physical form (restitution plus applied force) and a real-world referent: pass
speeds off served balls are observable.

**T2 — the reachable platform-angle range**, as a function of contact height,
arrival margin and lateral offset. This is the envelope's shape — how much
freedom the body has to point the ball.

**T3 — execution error as platform-angle deviation**, in degrees, scaled by
technique. The only one of the three with an existing pattern to copy rather
than a blank page: `AttackSwingModel.vertical_spread_degrees` and its sigma
budgets do exactly this job for the swing.

What they replace: two apex bands (four constants), the shank branch (two), the
dig's four spoil weights, the `digger.id % 2` rule, coverage's 0.58 and 1.8, and
three fixed target offsets. **Three authored relations for sixteen authored
numbers**, and each of the three is a quantity somebody could go and measure.

**The selection rule of §4a is not on this list**, and that is a deliberate
classification, not an omission — see §10a.

None of the three may be chosen by eye. Each needs a distribution and an
acceptance criterion before it is promoted, which is what §11 is for.

## 10a. Selection is decision logic, not a fourth physical relation

It would be easy to call §4a's preference order "T4" and calibrate it alongside
the others. That would be wrong, and the distinction matters for where the code
eventually lives and what it is allowed to read.

**A physical relation cannot be mistaken. A decision can.** T1, T2 and T3
describe what a body and a ball do; if they are wrong, the physics is wrong.
Selection describes what a voli *chooses*, and a voli choosing badly is not a
modelling error — it is the thing being modelled.

Three consequences:

1. **It is calibrated against different evidence.** T1–T3 are calibrated against
   ball behaviour. Selection is calibrated against *decisions* — how often a
   real passer overpasses a tight ball rather than eating it, which is a
   scouting-and-tendencies question, not a ballistics one.
2. **It may read perceived state, and the physics may not.** Selection is
   downstream of a read, so it may act on where the voli *thinks* the setter is.
   T1–T3 must act on ground truth. §8 of the spec fixes that direction.
3. **It carries different attributes.** Decision quality and platform technique
   are separate ratings, and keeping the stages apart is what lets a voli be good
   at one and bad at the other.

So selection is authored eventually, but as decision logic beside the existing
choosers — `_serve_decision`, `_second_contact_setter`, `CoverageModel` — and not
as a physical constant in the launch solver.

---

## 11. The smallest safe first slice

**Slice 1 — publish the intent that already exists, and mark the intent that does
not.** Narrower than the first draft said, and the narrowing is the point.

> **BUILT, 2026-08-17.** Seven fields — the five below plus §13.10's two source
> markers — on all eight platform-contact events. The prediction at the end of
> this section held: coverage has none, and the other two turned out to carry a
> recipient and both derived anchors while only the reception's *target* came
> from anywhere a manager can reach. The dig naming the setter and then aiming a
> stride from the digger is now two adjacent fields rather than a paragraph.
> `docs/review/PLATFORM_INTENT.md` has the census and the byte-identical check.

**Restated after §3a**, which changed the field list and moved one field from
"must be authored" to "already derivable":

| field | today |
|---|---|
| `purpose` | free — the call site knows it |
| `target_anchor` | exists — `desired_target` on both resolvers, the fixed offset on coverage |
| `intended_recipient_id` | exists — `setter` on reception and dig, absent on coverage |
| `height_anchor_meters` | **derivable** — `set_contact_height_meters(setter, false)`, class C |
| `arrival_floor_seconds` | **derivable** — `_movement_time(setter, position, seat)`, class C |
| ~~`target_tolerance_meters`~~ | **deleted by §3a** — a radius nothing derives, replaced by an anchor that needs none |

The first version of this slice published two real fields and three absence
markers, because under the point form the height and time fields required an
authored policy before they could carry anything. **Under anchors and a floor they
require no policy at all** — both are class C, computed from models that already
exist, and neither reads the dig's apex band, its `spoil`, or its outgoing
trajectory.

So slice 1 now publishes **five real fields**, with `unset` reserved for the
contexts that genuinely have no anchor rather than for the ones whose policy was
missing. Coverage and the emergency regime will carry `unset` on the height anchor
and the arrival floor, and that is a true statement about them rather than a
placeholder.

Publishing them is still not the same as *reading* them: nothing consumes any of
this in slice 1, and rallies must come back byte-identical.

That keeps the slice provably outcome-neutral — rallies must come back
byte-identical — while making countable, for the first time, how many platform
contacts in the game have any stated intent at all. The expected answer is that
coverage has none and the other two have half of one.

**Slice 2 — the envelope as a shadow, and the transfer relation with it.**

> **First half measured, 2026-08-17**, and it sharpens what the second half is
> for. The paragraph below asks what the shadow would produce against the
> existing bands. Measured, **there are no existing bands in T1's dimension**:
> the incoming ball's speed reaches the outgoing launch at r = +0.009 on the dig
> and −0.170 on the reception, and the reception's apparent +0.429 on total speed
> decomposes entirely into pass *distance* (+0.506). Coverage is starker still —
> it calls no pass resolver at all, so its ball is the display fallback's
> constant on all 24 contacts in 600 rallies. `docs/review/PLATFORM_TRANSFER.md`.
>
> So the sharpest question below — how often the current ball lies outside the
> available envelope — is still the right one, but it can no longer be answered
> as "the bands are approximately right/wrong". There is nothing in this
> dimension to be approximately anything.
>
> **And T1's form turned out to be already shipped.** `BlockDeflectionModel`
> spends incoming speed as `outgoing = incoming × PACE_KEPT`, one fraction per
> contact kind with a departure angle beside it, magnitudes rebased against a
> measured swing-pace band. Slice 3 therefore has a representation to copy, not
> one to invent — what it must still author is four to six numbers. The range
> they have to be argued within is measured: the reception implies 0.508–1.530
> (p50 0.656), the dig's *planted* posture implies 0.139–4.228, and 63 of 571
> contacts currently return the ball faster than it arrived.

It
also carries the gate measurement §4b asks for: **what fraction of controlled
digs could physically have produced the ball the team wanted.**
Implement §§4–6 as a resolver that runs beside the current one, publishes what it
*would* have produced, and changes nothing. Then measure: outgoing speed,
vertical, apex, destination error, and — the sharpest question — **how often the
ball the current model produces lies outside the envelope the shadow says was
physically available.** A current ball that is routinely infeasible is the
strongest possible evidence that the bands are fiction; one that sits comfortably
inside is evidence the bands were accidentally right and the envelope is too
loose.

This is where T1 gets its distribution. It is also where T1 may fail: if the
shadow cannot discriminate a plausible transfer relation from the existing bands,
the honest outcome is to say so and stop, not to promote it because the
architecture is prettier. The repository has run this pattern twice, for the
block and for reception.

**The rally-state intent gate — between slices 2 and 3.** Added after the §4b
audit; the sequence in the first two drafts of this page was wrong.

Slice 3 cannot begin until three things are true, and none of them is a
measurement of the model being replaced. **Conditions 2 and 3 are restated by
§3a**; condition 1 is untouched.

1. The controlled dig reads a real setting target instead of
   `contact + Vector2(0.03, −0.04)`. Class B on both sides; the value exists and
   the reception already uses it.
2. ~~The missing rally-intent policy — time wanted beyond the setter's bare
   arrival — is designed and named, or the model ships with `t = t₀`.~~
   **Dissolved.** There is no margin to design: `t₀` is a floor and the preference
   works inside it. What replaces this condition is that §4a has **a named
   preference**, which may be the minimal no-weight one.
3. Slice 2 has reported, not *whether one intended launch was feasible*, but
   **whether the intent constraints are simultaneously satisfiable inside the
   envelope, and which one binds when they are not.**

Condition 3's restatement is worth its own paragraph, because the new measurement
is strictly better and costs nothing extra:

> The old gate asked a yes/no question about a point, which discards how far
> outside the envelope the intent fell and in which direction. The new one is a
> **satisfiability** question over a constraint set — is there any launch in the
> envelope that reaches the target region at around the height anchor no earlier
> than the floor — and it reports *which constraint is the binding one*. "The
> arrival floor is unreachable on 40% of stretched digs" and "the height anchor is
> unreachable on 40%" are completely different findings that the point form
> returns as the same number.

It is also weight-free: satisfiability needs no preference, so this measurement
does not wait on the selection pass. That is what keeps slice 2 where it is.

> **The intent policy may not be calibrated against the current model's output.**
> "Successful digs today rise a median 2.507 m, so intent wants 2.5" would make
> the model being replaced its own design authority, and the band it came from
> was itself calibrated against an unreachable posture branch. Historical
> distributions are descriptive evidence about the old model, never the causal
> source of intended geometry.

**Slice 3 — promote one context.** The controlled dig, because it has the richest
state and the worst current model, and because it is where the `id % 2` rule
lives. One context, measured, before any other moves.

**Slice 4 — coverage's contact state.** Resolve arrival, posture and contact
height at the three coverage sites from values already in scope (§4). All class
B, no new physics.

**Slice 5 — reception and coverage promoted; the bands and `spoil` deleted.**

Do not reorder these. Slice 2 before slice 3 is the whole safety argument.

**Selection (§4a) is not in this list, and §3a changed when it is needed.**

The earlier text said slices 3 and 4 were reachable without it "because the
controlled dig's intent is precise enough that selection has one candidate."
That is no longer true, and it was never measured. Since intent names anchors
rather than a launch, **selection is required from slice 3 onward** — but only in
its minimal, weight-free form, which §4a shows can be named without authoring
anything.

The full preference, with tempo weights, is still a separate pass and is still
required before coverage and the emergency regime. So the dependency edge moved
earlier and got thinner rather than disappearing:

| | before §3a | after §3a |
|---|---|---|
| slice 3 needs | the intent margin policy (class D, underivable) | a **named** preference; minimal is enough |
| slice 5 needs | the full selection pass | unchanged |
| open questions gating slice 3 | two | **one** |

---

## 12. Can coverage own its ball afterwards? Yes — but later than the first draft said

The blocker recorded in `CONTACT_AND_BALL_FLIGHT.md` was that coverage's apex is
class C and the `spoil` that would drive it needs a posture and an arrival that
coverage never resolves.

This design removes both halves. There is no apex to supply, because the apex is
a consequence rather than an input. And coverage's contact state, per §4, is
derivable at all three call sites from values already in scope — class B
throughout, missing only because nobody computed it.

**But the first draft said "after slice 4", and that was wrong.** Coverage's
intent is `keep it alive`, which is the broadest intent in the model, and §4a
establishes that a broad intent is exactly the case where **the envelope alone
cannot produce a ball**. Something must choose among the feasible launches that
all keep it alive, and that chooser does not exist and is not designed.

### §3a changes coverage's *reason* for being last, not its position

The claim below — "coverage has no escape at any rate, because its intent does not
name a launch at all" — was true and is now vacuous: **no intent names a launch**,
so that is no longer what distinguishes coverage.

What distinguishes it is that coverage has the **fewest binding constraints**. Its
height anchor and arrival floor are both `unset`, so nothing but the preference
orders its feasible set, and the preference is the least-measured component in the
whole design. Coverage is therefore the contact whose ball is **most sensitive to
whatever weights the selection pass eventually authors**, and the one where getting
them wrong is least likely to be caught by anything else.

Same position, better reason, and the new reason survives the next redesign:
"least constrained, therefore most weight-sensitive" is a property of the contact,
where "its intent does not name a launch" was a property of a representation that
has now been discarded.

So the honest dependency is:

```text
slice 1  →  slice 2  →  RALLY-STATE INTENT GATE (§4b)  →  slice 3 (controlled dig)
                                                                    ↓
                                                        slice 4 (coverage state)
                                                                    ↓
                                               SELECTION PASS (§4a) ← required here
                                                                    ↓
                                              slice 5 (coverage owns its ball)
```

Coverage was the contact that motivated this whole design, and it turns out to be
the **last** one that can be finished, because it is the one with the least
intent. That is worth stating plainly rather than discovering during slice 5.

The controlled dig can be promoted without the selection pass **only where its
intended launch is feasible**, which §4b establishes is a measured rate rather
than a property, and which slice 2 reports. Coverage has no such escape at any
rate, because its intent does not name a launch at all.

---

## 13. How manager tactics reach this contact — audited 2026-08-16

The design must eventually carry a layered tactical interface — style, team
instructions, role instructions, individual instructions, rally context — that
compiles into intent and preference and **never** into physics. This section
audits whether `7eb64fd`'s model can take that, against the code that exists
rather than against a diagram.

**Verdict: structurally compatible, and more of it is already built than the
brief assumes. The gap is not architecture. It is one compile step, one missing
layer, and two channels that currently bypass the whole chain.**

### 13.1 Four of the five tactical layers already have homes

Audited in `team_principles.gd`, `defensive_plan.gd`, `tactic_sheet.gd`,
`worksheet.gd` and `rally_simulator.gd`.

| layer | where it lives today | persisted | reaches the rally |
|---|---|---|---|
| **style** | `TeamPrinciples.PRESETS` (6) and `Regions.REGIONAL_PRINCIPLES` (8+), seven dimensionless axes | yes | **yes** — read throughout the resolver |
| **team instructions** | `DefensivePlan`: `block_strategy`, `floor_system`, `block_defense_relationship`, `defensive_depth`, `short_ball_posture`, `block_intent`, `serve_target`, `serve_risk`, `setter_release_targets` | yes | **partly** — `serve_risk` and `block_intent` do; the rest do not |
| **role / position** | `TacticSheet.behaviours`, keyed `"slot:phase"`; `zone_priorities` as `[line, seam, cross, tip]` | yes | **no** — read only by the worksheet and `DrillSession` |
| **individual** | *nothing* | — | — |
| **rally context** | rally state | n/a | yes |

Two things follow that are worth having before any field is proposed.

**The role layer is already correctly keyed and has no consumer.**
`TacticSheet` stores behaviours by *slot*, and its own comment says why: "a plan
is a shape the club plays, and it outlives the particular voli standing in
position four." That is exactly the role/position layer, already built, already
saved, and read by nothing in the rally. Its own file states the ambition — "the
whole point of telling a voli to close the line is that they then close the
line."

**The individual layer is absent by decision, not by oversight**, and it cannot
be added to `TacticSheet`: it needs a different key (player id, not slot) and a
different lifetime (it follows the voli through a transfer; a slot instruction
does not). That is a data-model consequence worth knowing before anyone extends
the sheet.

### 13.2 The pattern is shipped for the block — and its instruction arm is dead

`_block_hands_intent` is already the exact chain the brief describes, and it is
worth reading before anything new is designed:

```gdscript
match instruction:
    "soft block": return "soft"     ## 1. the manager said
    "kill block": return "kill"
...
return "soft" if AttemptJudgmentModel.backs_off(blocker, deficit) else "kill"
                                    ## 2. the voli read it   3. otherwise press
```

It returns **an intent** — what the blocker *means to do with their hands* — and
the physics resolves it afterward. `MANAGER INSTRUCTION → intent → feasibility →
execution → ball`, in one function, already in production.

**And the instruction never arrives.** The value comes from
`formation.get("hands_instruction", "")`; `_form_home_block` and
`_form_opponent_block` do not put that key in the dictionary, and **nothing in
the repository writes it**. The `match` falls through on every block in every
rally. The comment above it says `TacticSheet` "stores a per-voli block
behaviour… this is their first consumer", and that is false — `behaviour_of` is
called by the worksheet and by `DrillSession`, and by nothing else.

> This is a third instance of the §0 shape, and a new variant of it.
> `audit_unreachable_branches.py` **does not flag it**, because the literals
> `"soft block"` and `"kill block"` genuinely are produced — in
> `worksheet.gd`'s menu table, four hops upstream, in a `Control` that never
> talks to the resolver. The tool's own findings document names this limitation
> ("cross-file domain tracking… is not built") and here is a live example: the
> *literal* exists and the *domain* is empty.

The practical consequence for this design is a caution, not a licence. **The
tactical→intent pattern must not be cited as proven because the block does it.**
The block writes it down and does not run it.

### 13.3 Two combination rules already exist, and the difference between them is the answer

The brief asks which layers override and which combine, and says not to assume
additive modifiers. The codebase has already answered, twice, differently, and
both answers are right:

```gdscript
## Categorical — the instruction REPLACES the layer below
match instruction:
    "soft block": return "soft"

## Scalar — the instruction is the BASE, style adds a signed deviation
serve_risk = defensive_plan.serve_risk
serve_risk = clampf(serve_risk + (home_principles.serve_aggression - 0.5) * 0.70, …)
```

> **Named choices override. Graded preferences combine.**

That is not a stylistic split; it follows from what the quantities *are*. You
cannot half-soft-block — the hands go one way or the other, so a style cannot
blend into a stated choice. Serve risk is a position on a continuum, so a team
that believes in aggression genuinely sits further along it than the same
instruction on a cautious team.

And it maps onto §3a's split exactly, which is the sign it is the right rule:

| §3a category | combination rule |
|---|---|
| **anchors** — a place chosen | override; the seat is at one place |
| **categorical intent** — a stated choice | override; the shipped block pattern |
| **preference weights** — how much a thing is wanted | combine, as deviations |

> **§14.3 corrects the middle row.** The "override" half of this rule was read
> off `_block_hands_intent`'s `match instruction: return`, which §13.2 had just
> established is dead — so it was an unexercised branch cited as a precedent. An
> unmediated override also makes every voli obey identically, which is the one
> outcome the tactical system must not produce. The corrected rule is below;
> **the two rows about anchors and preference weights stand.**

**There is no modifier stack**, and that is the load-bearing claim. The layers
resolve to one value per dimension by precedence or by deviation, and then stop.
Conflicting wants are *not* reconciled by arithmetic on instructions — they are
reconciled by the feasible envelope at selection, which is physical. A team that
wants a low fast pass and a precise one is not resolved by weighting; it is
resolved by what the contact can actually produce.

### 13.4 The five categories, separated

| category | what it is | who may change it | examples |
|---|---|---|---|
| **physical anchors** | a place a person chooses to aim or stand | manager, directly | `setter_release_target` — already manager-set via `set_setter_release_target` |
| **derived constraints** | a fact computed from bodies and the rally | **nobody** | `arrival_floor_seconds` from `_movement_time`; `height_anchor_meters` from `set_contact_height_meters` |
| **tactical preferences** | how feasible launches are ranked | every tactical layer | higher/lower, sooner/later, precision/tempo, overpass aversion |
| **body / contact state** | what actually happened to this body | nobody | incoming ball, arrival, posture, `ContactEnvelopeSystem`'s reach result |
| **execution inputs** | technique and the draws | nobody | `reception`, `ball_control`, the existing normals |

The rule that falls out of the first two rows is checkable and worth stating as
the test for every future instruction:

> **An instruction may move an anchor only when that anchor is policy. It may
> never move a derived physical fact — for those it may only weight a
> preference.**

The release seat is policy: a coach genuinely chooses where the setter works
from, and the game already lets them. A setter's standing release height is not
policy — it is how tall they are with their arms up. Their travel time is not
policy — it is how fast they run. "Setter operates closer to the net" moves the
first. "Pass higher" may not touch the second or third.

### 13.5 Do the three current fields survive? Two do. One is already fused.

The audit the brief asks for, on `7eb64fd`'s own fields:

| field | verdict |
|---|---|
| `height_anchor_meters` | **clean.** Pure derivation from the setter's body. Future-proof precisely *because* "pass higher" must not move it |
| `arrival_floor_seconds` | **clean, and must stay a floor.** "Give more recovery time" may not raise it; the setter's legs do not slow down because the manager wants a slower ball. The instruction weights arrival preference *above* the floor |
| `target_anchor` | **fused, today, in production.** `_desired_pass_target` returns the manager's release seat **plus** an overpass-safety offset — an anchor and a preference added into one `Vector2`, with five bare literals doing the fusing |

So the answer to "do any currently combine manager preference with derived
fact?" is **yes, exactly one, and it is the only one of the three that already
exists in code.** The split is: the seat is the anchor; overpass aversion becomes
a preference; and the reception stops being the one context whose target silently
includes a safety rule no other context gets and no team can turn off.

### 13.6 The four example instructions, routed

| instruction | routes to | may not |
|---|---|---|
| pass higher / lower | preference weight on height relative to the anchor | move `height_anchor_meters`; touch apex |
| pass faster / more recovery time | preference weight on arrival, above the floor | move `arrival_floor_seconds` |
| setter base closer to / further from the net | **the anchor** — `setter_release_targets`, which already exists and is already read by reception | anything else |
| set tighter / further off the net | the *set* contact's target anchor, when that contact is designed | increase attack quality; force the ball netward |

Three of the four are preference weights and one is an anchor move, and the one
that moves an anchor is the one already implemented — which is the strongest
available evidence that the split is drawn in the right place.

### 13.7 Is the six-object structure useful? Four distinctions are load-bearing; the objects are not.

The brief proposes `PlatformContactIntent` / `Preferences` / `State` /
`Selection` / `Execution` / `Result`. Assessed one at a time:

| proposed | verdict |
|---|---|
| Intent vs **Preferences** | **load-bearing, and it is the answer to the brief's key question.** They must stay separate, for a reason stronger than tidiness — see below |
| **State** | load-bearing; already §2 and §4 |
| **Selection** | load-bearing **as an output record**, not as an input stage object. It is what makes Case B diagnosable |
| **Execution** | not load-bearing. It is a function's parameters — attributes and draws — and naming it adds a box without adding a boundary |
| **Result** | load-bearing; already §6 |

**Why intent and preferences must not fuse**: they have different *lifetimes and
authorities*. Anchors and the arrival floor are derived per contact, from this
setter at this instant. Preferences are compiled from tactics and are stable
across every contact in a rotation. Fusing them means recompiling the tactical
hierarchy on every touch, and — worse — it makes the Case A / Case B comparison
below impossible to state, because "the same want met a different circumstance"
requires the want to be a separate object that can be held constant.

**But the redesign log's rule stands: do not create classes to match a diagram.**
The recommendation is to publish these as named, documented regions of one
record — the same discipline `height_source` and `launch_source` already use —
and to promote any of them to a class only when a second consumer exists. Four
concepts, zero classes, until something needs one.

### 13.8 The Case A / Case B test

The brief's own readiness test. Both stories under this architecture, with the
same compiled tactics:

**Compiled once, from style + team + individual:**
`arrival preference → sooner` (fast transition, "pass lower"),
`height preference → lower`, `precision weight → raised` (libero individual),
`anchor → the release seat, moved netward` (team: setter closer to net).

**Case A — readable serve, balanced arrival, setter already at the seat.**
The arrival floor is ≈ 0 and therefore *slack*; the envelope is wide, because a
planted platform under a moderate serve can angle and pace the ball almost
anywhere. Every preference is satisfiable at once: the ranking's maximum is a low,
fast, accurate ball to the seat. Execution perturbs it. **The instruction is
realized.**

**Case B — same tactics, libero at full stretch under a hard serve.**
Nothing about the compiled preference changes — and that is the point of keeping
it a separate object. What changes is the envelope: at full stretch the reachable
platform-angle range is narrow, so the low fast ball is simply not in the set.
The ranking still runs, over a smaller set, and its maximum is whatever least
badly serves the same wants. Because the incoming pace is enormous and the one
available angle is upward, **the ball that comes out is high and loose** — a
survival ball, produced with no rule anywhere saying "bad circumstance means high
ball." It is §8's third case, reached by tactics rather than by hypothesis.

Both stories are told by the same five stages with one object differing. **The
architecture passes its own test**, and the reason it passes is §3a: a preference
can be held constant across two circumstances in a way an exact intended launch
cannot, because an exact launch is *defined* partly by the circumstance it was
computed against.

### 13.9 Hidden tactical preferences already baked into geometry or bands

The migration list. Each is a real coaching preference currently expressed
somewhere it cannot be argued with, and each should eventually become a
selection-layer weight:

1. **`_desired_pass_target`'s safety offset** — overpass aversion, in the target
   point, five bare literals. Known; §3a.
2. **The dig's apex band `lerpf(1.35, 3.05, …)`** — this is the instruction *"give
   the setter recovery time"*, authored as physics and applied to every team in
   the world with no way to differ. It is the single largest hidden preference in
   the model and it is the one this whole document exists to delete.
3. **The dig's target `contact + Vector2(0.03, −0.04)`** — a tactical
   *non*-decision baked as geometry: aim a stride from yourself. §4b.
4. **`digger.id % 2` lateral sign** — already condemned; not a preference so much
   as a fiction standing where one belongs.
5. **`_block_hands_intent`'s fall-through to `"kill"`** — "press unless you know
   better" is a team aggression default, authored in the resolver rather than
   sourced from `block_commitment`, which exists and is per-team.
6. **`_block_intent_margins`** — and this one is subtler and worth stating
   carefully. `block_intent` is a *legitimate* team instruction in the *right*
   place, and its magnitudes were argued against a real distribution. But it
   reaches the ball as direct shifts to the outcome bands
   (`{"stuff": -0.06, "touch": -0.02, "funnel": 0.09}`), which is
   `INSTRUCTION → outcome`, skipping intent, feasibility and execution entirely.
   Under the target grammar the same instruction would set the hands' angle and
   let the deflection model produce those shifts. **A right tactic in a wrong
   channel** — and it is the clearest example in the codebase of what the brief
   is asking future work to avoid.

Not on this list, and deliberately: `DefensivePlan`'s `defensive_depth`,
`short_ball_posture`, `floor_system` and `zone_priorities`. Those are preferences
sitting in a preference store, which is where they belong. `zone_priorities` in
particular is already a manager-set, persisted, dimensionless ranking over four
lanes — the single closest existing thing to the preference object this design
needs, and the natural template for it.

### 13.10 What slices 1 and 2 must publish so tactics can arrive without a rewrite

Two additions, both in the manner of `height_source`, both free:

**Slice 1 gains `anchor_source` per anchor.** The reception's target comes from a
manager-set seat; the dig's comes from a fixed offset off its own contact point.
Today those are the same type and are indistinguishable in the data. Marking them
means the first tactical consumer can find every anchor that is *not* policy and
therefore not yet steerable — and it makes §13.9's item 3 countable rather than
anecdotal.

**Slice 1 also gains `preference_source`, whose honest current value is
`"none"`.** Nothing supplies a preference yet. Publishing the field with an
absence marker is what stops the schema changing when tactics arrive: the marker
takes a new value, the record does not grow a new shape. This is the same
argument §11 already makes for the intent fields themselves.

**Slice 2 publishes the envelope's extent, not only its satisfiability.** That is
what buys the acceptance criterion for every future tactical pass:

> **Changing a tactical preference must leave the feasible envelope
> byte-identical and move only the selection.**

That is a gate somebody can write, and it is the falsifiable form of "tactics do
not change physics." Any future instruction that fails it has reached the
resolver, whatever its comment says.

### 13.11 Does the grammar generalise to the other contact families?

Checked, not redesigned. The five stages are recognisable in all four:

| family | intent anchor | feasibility | shipped example of the pattern |
|---|---|---|---|
| **strike** — serve, attack | aim point, target zone | launch search against net and court | **yes, and it works**: `_serve_launch` relaxes a preferred pace toward a derived floor, takes the quickest clearing trial, keeps a fallback |
| **platform** — reception, dig, coverage | seat, height anchor, arrival floor | the launch envelope this document designs | designed here; unbuilt |
| **set** — overhead redirection | the hitter's contact window | reachable release from the pass | not designed |
| **block** — block contact | hands intent, lane | closure and reach | **written and unwired** — §13.2 |

The strike family is the only one where the whole chain runs, and it is the model
to copy. One warning for whoever writes the set or block version:
**`ContactEnvelopeSystem` is not the feasible-launch envelope.** Its name is the
one this design wants and its content is a different question — it answers "can
this body reach that contact point", which belongs to the *body state* stage, not
to feasibility. Its own header says it is "game-balance mappings, not claims of
biomechanical measurement". Conflating the two would put a balance layer inside
the physics stage, which is the failure this architecture is built to prevent.

### 13.12 Attribute separation — does the architecture permit it?

The brief asks whether the stages can carry different attributes rather than one
scalar doing five jobs. They can, and three of the five already have a home:

| job | stage | today |
|---|---|---|
| read / anticipation | perception | `anticipation` reaches block and dig reads |
| movement | body state | the locomotion model, `transition_speed` |
| balance / stability | contact feasibility | `reception_balance`, `reception_stability` — currently spent on a scalar |
| decision-making | **selection** | `decision_making`, `tactical_discipline` exist and reach nothing here |
| technique | execution | `reception`, `ball_control` |
| evaluation | downstream | `quality`, causal direction reversed per §7 |

The architecture permits the split because the stages are separate; **nothing
about it forces the split**, and that is worth saying. The mappings above are not
locked and should not be. What the design does guarantee is that if
`reception_quality` is still doing five jobs later, it will be a choice somebody
made rather than a shape the model imposed.

### 13.13 The next implementation pass

**Not platform slice 1. Wire the dead instruction arm first.**

`formation["hands_instruction"]` from `TacticSheet.behaviour_of(slot, "Block")` is
the smallest end-to-end proof that a manager instruction can reach a contact as
*intent*. Everything it needs exists and is persisted; the consumer is written;
the vocabulary matches; and the comment claiming it already works is currently
false, which is worse than an absence because it will be believed.

It is the right first pass for three reasons:

1. **It changes production behaviour**, so it actually tests the acceptance
   criterion rather than asserting it. Slice 1 is outcome-neutral by
   construction and can prove nothing about the chain.
2. **It adds no physics and no constant.** The intent function, the bands and the
   deflection model are untouched; one dictionary key starts carrying a value it
   was written to carry.
3. **It is the only place the pattern is already written**, so the pass is a
   connection rather than a design.

It must ship with the honest correction to the comment above `_block_hands_intent`,
a gate that the instruction actually reaches the resolver, and a measured report
of how much behaviour moves — the instruction currently fires on 0% of blocks, so
any team using it will see a real change and the suite baseline will move.

Then platform slice 1, with `anchor_source` and `preference_source` per §13.10.

---

## 14. Reconciling the tactical design with the attribute audit — 2026-08-16

`docs/review/ATTRIBUTE_WIRING_AUDIT.md` §7.2 flags `tactical_discipline` as
having "both good and questionable consumers" and asks that the semantic
conflict be resolved **before** tactical intent starts depending on it. This is
that resolution. It changes one conclusion in §13 and it does not need a new
attribute, a new slider or a new constant, because **the repository already
contains its own answer in one shipped function.**

### 14.1 The contract is already implemented — in `AttackPowerModel`

```gdscript
static func aggression_from(
    aggression_rating: float, team_decisiveness: float, tactical_discipline: float
) -> float:
    return clampf(lerpf(aggression_rating, team_decisiveness, tactical_discipline), 0.0, 1.0)
```

At discipline 0 the hitter swings at their own temperament. At discipline 1 they
swing at what the team wants. **`tactical_discipline` is the blend weight
between individual disposition and the team's call** — which is exactly the
audit's own stated question, "how strongly do they adhere to the team's
assignment/method", and it is live production code.

> **`tactical_discipline` is a blend weight. It is never a capability and never a
> threshold.**

That single sentence resolves every consumer, and it is a test rather than an
opinion: discipline may appear only where there is *a call and a disposition to
blend between*. Where there is no call, it has no referent and must do nothing.

| consumer | verdict |
|---|---|
| `AttackPowerModel.aggression_from` | **canonical.** The form every other use should take |
| tempo strictness, `rally_simulator.gd:7545` | **correct.** Pulls the setter toward the *called* tempo. Additive rather than a blend, but the direction and the referent are right |
| `AttemptJudgment.judgment()` | **wrong — see §14.2** |
| `ContactEnvelopeSystem` block `action_balance` | **wrong.** A blend weight raising a physical balance quantity, which is both a capability use and a mental→physics crossing. The audit already has this; noted here only because §13 must not build on it |
| `FamiliaritySystem` | out of scope; not a contact decision |

### 14.2 `AttemptJudgment` — yes, it should change, and the sign is the problem

The function answers: *does this voli recognise the attempt is beyond them and
back off?* It weights `decision_making` 0.50, `tactical_discipline` 0.30,
`composure` 0.20.

**Discipline does not belong, and not merely because it is imprecise.** Every one
of the four `backs_off` sites — the setter's tempo, the hitter's swing (×2), the
blocker's hands — has the same shape: *the safer option is also a departure from
the called action.* A setter who declines the quick set is abandoning the called
play. A blocker who softs is not killing.

So under the contract in §14.1, discipline should push a voli **toward persisting
with the call**, and in `judgment()` it does the opposite: more discipline → higher
judgment → more likely to back off. **The sign is inverted relative to the
attribute's own definition**, and the docstring shows why — "a marginal one gets
chanced by all but the most disciplined" is using *discipline as self-restraint*,
a second meaning the codebase does not otherwise use and does not have an
attribute for.

It is also a **capability** use of a non-ability attribute: higher is
monotonically better at recognising. §8.2 of the audit sets exactly that test,
and `ego`, `aggression` and `leadership` are already excluded from
`ABILITY_ATTRIBUTES` for failing it.

**The recommended shape splits one question into the two it actually is:**

```text
recognition  — do I know this is beyond me?
    decision_making, composure                    a capability

response     — knowing that, do I abandon the call?
    aggression, and tactical_discipline           temperament, then adherence
    where a call exists                           -- only where there is a call
```

`aggression` is named because it already means precisely this — "how strongly do
they pursue terminal/high-commitment actions" — and `backs_off` is by definition
a decision not to pursue one. **No attribute is invented**; one is removed from a
function it does not belong in, and one already-defined non-ability attribute is
available for the term that is genuinely temperament.

**Not decided here: the weights.** The current 0.50/0.30/0.20 was chosen by eye,
and replacing it by eye would repeat that. Discipline's removal alone moves four
live decision sites, so the change needs a measured before/after — that is what
the next pass is for, and it is why this is a design note rather than an edit.

### 14.3 What this corrects in §13.3

§13.3 concluded "named choices override, graded preferences combine," reading the
override half off `_block_hands_intent`'s `match instruction: return "soft"`. Two
problems, and the second is the serious one:

1. That branch is **dead** (§13.2), so an unexercised shape was cited as a shipped
   precedent. `aggression_from` is a live one and it disagrees.
2. **An unmediated override makes every voli obey identically**, which is the one
   behaviour the tactical system exists to avoid. A team told "kill block" would
   contain twelve identical blockers.

The corrected rule is one rule where §13.3 had two, and it subsumes both:

> **Every tactical layer resolves, by precedence, to one *call*.
> `tactical_discipline` is how much of that call survives contact with the voli's
> own read and disposition.**

Categorical calls and graded preferences differ only in what is being blended —
a choice between two named actions, or a position on a scale. The layer stack
still produces exactly one call per dimension, so there is still **no modifier
stack**; what changed is that the call is *adhered to*, not *obeyed*.

This is what makes the brief's success criterion structural rather than
aspirational: the same instruction meets a different voli and a different
circumstance and produces different, sensible behaviour, without the manager
scripting either.

### 14.4 The three corrections the brief names, checked against this

**"Pass higher + play faster" is not a contradiction, so style must compile
per-phase.** Agreed, and the data model already assumes it in two places:
`TacticSheet.behaviours` is keyed `"slot:phase"` with phases `Attack` / `Block` /
`Floor`, and **five of the seven principle axes are already phase-scoped** —
`serve_aggression` (serve), `block_commitment` (block), `pin_focus` (attack),
`tempo_variation` and `transition_commitment` (set/transition). Only
`decisiveness` and `emotional_expression` are global, and those two read as
temperament rather than instruction, which is consistent.

So the requirement is not a change of shape but a prohibition, worth stating
before anyone compiles a style: **a style may not compile to one speed or risk
scalar.** "Higher first contact so the offence can assemble, then fast" is one
coherent instruction across two phases, and the phase key already exists to hold
it.

**No "under pressure" tactics layer.** Not needed, and §14.3 is why: the variation
a pressure layer would script is already produced by the read, the envelope and
discipline. Adding a conditional layer on top would double-count circumstance —
once in the physics and once in the instruction — and give the manager a lever on
something they are not in the gym for.

**Tactics are not a conditional scripting language.** Same mechanism. The manager
states one stable call per dimension per phase; the voli decides what it means on
this ball. Any design that needs `if …` in the instruction has moved the voli's
job to the manager.

### 14.5 Is the block still the next implementation pass? Yes — but it is now second

§13.13 recommended wiring `formation["hands_instruction"]` as the smallest
end-to-end proof. That is still the right proof, and **it can no longer be
first**, because of a dependency §14.2 exposes.

If the instruction is wired while `judgment()` still contains discipline, then at
one block decision discipline is spent **twice**: once inside
`backs_off` → the read, and again as the adherence weight on the call. That is
the audit's regression principle violated in the very pass meant to demonstrate
the architecture — and it would be invisible, because both spends push in
plausible directions.

So the order inverts:

```text
pass 1   AttemptJudgment semantic correction   (attributes; no tactics)
pass 2   block instruction wired, adhered to per discipline   (the proof)
pass 3   platform slice 1                       (§13.10 markers)
```

Pass 1 is the larger and less glamorous one — it touches four live decision sites
and will move the suite baseline — and it has to land first for the proof to prove
anything.

### 14.6 The final semantic contract for the attributes in scope

| attribute | primary question | may it be a capability? | where it may appear |
|---|---|---|---|
| `decision_making` | given what is perceived, how good is the option chosen? | yes | recognition, selection |
| `composure` | how much does pressure disrupt otherwise available judgment? | yes | recognition, execution stability |
| `tactical_discipline` | how much of the team's call survives contact with my own read? | **no** | only as a **blend weight**, and only where a call exists |
| `aggression` | how strongly do I pursue terminal, high-commitment actions? | **no** | the temperament side of a blend |
| `court_vision`, `anticipation` | what do I perceive / predict? | yes | perception only |

The two "no" rows are the load-bearing ones. Both are already outside
`ABILITY_ATTRIBUTES`, and the rule that keeps them honest is the audit's own:
**a non-ability attribute may never appear where higher is monotonically
better.** `judgment()` currently breaks it for `tactical_discipline`; nothing else
in the rally does.

---

## Implementation conclusions that survive every revision

Carried forward unchanged through the §3a audit, because none of them depends on
how intent is represented:

- **Do not repair the continuation dig's `{}` arrival path in place.** The fake
  29% stretch it fabricates is a symptom; patching it would make the old model
  slightly less wrong and slightly harder to replace.
- **Slice 2's shadow consumes the correctly derived arrival state and measures
  it**, rather than inheriting the empty one.
- **The eventual replacement eliminates the 29% stretch**, by deriving arrival
  rather than defaulting it.
- **The controlled dig must eventually use the existing setter release target**,
  which both sides already carry and the reception already reads. **No production
  behaviour changes in this pass.**

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
- **Reading §3a as licence to author a tempo weight.** It settles that tempo
  enters as a dimensionless weight over existing principles rather than as a
  margin in seconds. The magnitude is the selection pass's, and it is open.
- **Reading "intent is anchors" as "intent is a box".** §3a rejects the range
  form explicitly and for a stated reason: four of its five bounds would be
  invented, and a range authors a cliff where the data supports a gradient.
- **Citing the block as proof the tactical→intent pattern works.** §13.2: it is
  written and wired to nothing. It is a template, not evidence.
- **Letting a tactical instruction move a derived constraint.** §13.4: an
  instruction may move an anchor only where the anchor is policy. "Pass higher"
  may not raise the height anchor, and "give more recovery time" may not raise
  the arrival floor — those are a setter's height and a setter's legs.
- **Building the feasible-launch envelope on `ContactEnvelopeSystem`.** §13.11:
  the name is right and the content is a different question. It answers whether a
  body can reach a contact point, which is body state, and it says in its own
  header that it is a balance mapping rather than a measurement.
