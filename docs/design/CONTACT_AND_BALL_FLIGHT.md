# Contact, Ball Flight, and Who Owns Which Fact

Review date: 2026-08-16

Status: **SPEC. Target semantics, not implemented behaviour.**

Every section below is labelled **CURRENT**, **TARGET** or **UNRESOLVED**. Do not
read a TARGET paragraph as a description of what the code does today.

## Why this exists

Five fidelity passes in a row found a defect, fixed it, and were immediately
handed a second defect the fix exposed. That is not a run of bad luck; it is what
happens when several systems each hold a private opinion about the same physical
fact and no document says which one is right. This spec is the referee.

Its job is narrow: to let a future pass answer *"is this removing fiction or
authoring physics?"* without inventing a rule to decide.

## The rule that governs every future pass

**REMOVING FICTION** — the simulator already has an authoritative answer and some
record or consumer carries something else. The dig knows its contact height is
0.915 m; the trajectory stores 1.000 m. Bounded, verifiable, needs no volleyball
judgement.

**AUTHORING PHYSICS** — a required quantity has no authoritative model. What apex
should a poor dig produce? Which way does a spoiled platform miss? These need
design, measurement and an acceptance criterion.

> **A plumbing pass must not introduce a new physical constant, a guessed height
> or duration, an arbitrary error scale, a deterministic proxy, or a new
> formula.** If the plumbing cannot be finished without one: stop, name the
> missing physical question, and make it a separate pass.

This rule exists because it has already been broken twice, both times in
`_dig_pass_result`, and both times by work that was otherwise legitimate. See
UNRESOLVED PHYSICS.

The test to apply: *does this change increase or decrease the number of
independent opinions answering the same physical question?* Prefer convergence.

## 1. Contact intent — TARGET

What a voli is *attempting*, before the body-ball result is known. Where a
context supplies them, intent may carry a tactical purpose, an intended
recipient, an intended target region, an intended redirection, and a desired
shape or tempo.

Two separations are load-bearing:

- **intended recipient ≠ actual future interceptor**
- **intended target ≠ realized outgoing ball**

Not every context specifies everything. A serve reception may attempt a precise
setter-oriented delivery; a controlled dig a broader setting zone; an emergency
dig may only attempt *playable*; attack coverage may only attempt *alive*. These
are descriptions of intent, not numerical models — see UNRESOLVED PHYSICS §4.

**CURRENT:** intent is essentially unrepresented. All three platform contexts use
a fixed small offset from the contact point as their target, and the only setter
property any of them reads is a contact height used to terminate a flight — which
is the opposite of intent.

**"Intended target region" above is deliberate wording, and 2026-08-16 sharpened
what it may mean.** `PLATFORM_CONTACT.md` §3a audited whether intent should
resolve to one exact `(target, height at target, time to target)` — which uniquely
determines a launch — or to a region and a window. **It is neither.** Intent
carries *anchors* to be near and, where one is derivable, a *one-sided bound* not
to be beaten; it does not name a launch and it does not draw a box. A region form
would have to invent an upper arrival bound, both height edges and a target radius,
none of which the simulator derives, and would author a discontinuity at each. Read
§3a before adding any tolerance, window or margin field to a platform intent
record here.

## 2. Physical contact — TARGET

**Takes:** incoming ball state, actual body state, contact position, technical
capability, contextual intent, and already-resolved contextual difficulty.

**Resolves:** whether and how contact occurs, actual contact position and height,
outgoing launch state, control/execution, and immediate body consequence.

**Does not resolve:** who makes the next contact, where they intercept, what it
means tactically, or anything presentation needs.

No current action has been shown to genuinely require the exception. The block is
the closest candidate and remains out of scope.

## 3. Outgoing ball state — TARGET

The physical state belonging to the ball immediately after contact, **before the
next actor is known**. Conceptually: launch position, launch height, launch time,
horizontal launch velocity, vertical launch velocity (or equivalent ballistic
state), and spin where modelled.

> **Launch velocity is a property of the ball leaving the contact. It is not a
> property of whoever later intercepts it.**

`RallyKinematics` already computes struck-flight state. This section asks for
ownership, not a new solver.

**CURRENT — the concrete violation.** `BallPresentation.launch_speed_mps`
reconstructs launch speed from `start_height`, the *chosen endpoint* height, and
duration. So launch speed changes if the flight is truncated somewhere else. On
seed 20000 this is measurable: correcting the serve's launch height from a
fictional 1.0 m to its real 2.70 m moved launch speed 16.803 → 16.375 m/s, which
moved `_read_error_meters` → `arrival` → reception quality 0.489894 → 0.490053.
Because every published trajectory carried 1.0 → 1.0, **the vertical term has been
exactly zero for every ball in the game.**

## 4. Free flight — TARGET

What the outgoing ball would do if nobody touched it. Owns position and height as
functions of time, and the natural floor or boundary endpoint.

**CURRENT:** the serve already behaves this way — `_serve_arc` solves toward a
floor landing with no receiver in it. Presentation's `terminate_at_next_contact`
already assumes flights are truncatable. Trajectory-first second-contact
selection, when it comes, needs to ask where the ball is *before* knowing who
gets there. Three independent pressures point the same way.

## 5. Realized segment — TARGET

The portion of a flight that actually happened between two rally events: actual
start and end contacts, times, positions and heights, derived from the same
physical flight.

> **Truncating a flight must not retroactively redefine its launch state.** A
> ball that is dug at 6 m left the hand at the same speed as one that reached the
> floor.

**CURRENT:** violated by §3's reconstruction, and by `dig` and `reception_pass`,
which terminate at the *designated setter's* reach — a realized-segment endpoint
chosen before the segment's real end is known.

## 6. What `BallTrajectory` should mean — TARGET

**CURRENT: both, and nothing marks which.** Serve is written as free flight;
dig and reception as realized segments; presentation reads everything as free
flight and truncates. A reader must infer the concept from the event type.

**Recommendation: D, eventually two concepts — but not yet, and not as a rewrite.**
The smallest honest step is to make the distinction *legible* before it is
structural: a record should be able to say whether it predicts where the ball
would go or records where it went. `height_source` (added in 91884f6) is the
precedent — a one-field marker that made an invisible gap countable.

Do not create free-flight and realized-segment classes on the strength of this
paragraph. Prove the marker is insufficient first.

## 7. Presentation boundary — TARGET

**Simulation owns** physical trajectory state, launch velocity, gravity and
flight queries used by gameplay, and any value a cognition, read or error model
consumes.

**Presentation may** interpolate, convert coordinates, produce drawable geometry,
convert relative rise into absolute gravity-true geometry, and draw the realized
portion of a resolved flight.

**Presentation must not** decide a gameplay-relevant physical value or become the
authority for speed, reach or contact physics.

**CURRENT:** `BallPresentation.launch_speed_mps` is simulation physics by
function and presentation by module, called from `_read_error_meters` in the
resolver. Its placement is a future ownership migration. **Do not move it as a
side effect of another pass** — it changes reception inputs, so it is its own
task with its own measurement.

**Implemented boundary, 2026-08-25.** A displayed trajectory now consumes the
launch's published `launch_gravity_mps2`; both `BallPresentation` and the 3D
court call the same sampler. For a successful serve/reception pair, presentation
draws the physically played prefix of the published free flight, ending at its
descending crossing of the receiver's platform height. The outgoing pass begins
at that identical point. The launch, gravity and free-flight landing remain
simulator facts; no second serve curve or visual snap is authored.

Promoting that descending crossing to the simulator's responsibility window was
tested and rejected, not hidden. In a fixed 800-rally census it shortened 643
successful contacts by a mean 0.188487 s (range 0.102480–1.542407 s), changed 128
claimants, 364 terminal outcomes and 251 winners, and moved aces 7 → 54. Existing
authority fixtures also failed. Until §4/§5 own interception, the calibrated
floor-landing window therefore remains gameplay authority and the exact
descending prefix is an explicitly marked realized-display segment.

**Float repertoire boundary, 2026-08-25.** The visibly steep Jump Float was
confirmed to be authoritative rather than a presentation reconstruction. The
intended launch distribution had a continuous main band through 30 degrees, an
empty 30--35 degree interval apart from one sample, then a separate lofted tail
from 35--45 degrees. Float launch selection now limits intended angle to 30
degrees. `AttackSwingModel.deliver` remains downstream and unbounded, so an
execution miss can still deliver a ball above 30 degrees. This distinction is
load-bearing: repertoire constrains what ball the server chooses; execution
describes how that attempt actually leaves the hand. Clipping the latter would
rewrite outcomes. The boundary is float-only because topspin owns an
authoritative increased gravity that makes a steep launch dive.

**Posed contact anchors, 2026-08-25.** The simulator's contact point stays
fixed. Presentation poses the actual silhouette for the action and reads its
forearm, hand or block anchor, then derives that actor's body destination from
the measured offset. Reception/dig, standing/jump/underhand front/back sets,
attack, serve and contacted block all follow this contract. There is no shared
0.88 m platform constant and no ball snap.

**Quick-tempo clock, 2026-08-25.** A short set flight remains short. Playback
draws the hitter's already-resolved preparation during the incoming pass and
continues from the setter-release pose on the delivered physical clock. The
physically achieved tempo is reconciled from delivered flight and
takeoff-to-contact; the old release-progress classification is retained under a
separate key for gameplay consumers. This makes the correction observable
without silently changing rally resolution.

## 8. Cognition and read — TARGET

    authoritative physical ball → cognition/read model → perceived state → decision

and never

    presentation reconstruction → cognition → simulation

**A real launch height changing reception difficulty is a causal correction, not
a regression.** The serve finding is the worked example: receivers had been
reading a ball with no vertical velocity, and correcting that legitimately moved
what they could do with it. Outcome movement from a corrected physical input is
evidence, not damage — provided the chain is explainable.

## 9. Intended recipient vs actual interceptor — TARGET

A passer may aim at a known setter. That is intent, and it is legitimate. What is
not legitimate is the intended recipient *defining the physical end of the ball*
before anyone has been shown to reach it.

**CURRENT:** platform trajectories terminate at the designated setter's contact
height; the actual second-contact actor is chosen afterwards and differs on about
**22.8%** of successful digs. That figure is a diagnostic population, **not a
balance target** — it may rise or fall once the ball exists independently.

**Classification:** this is *not* a setter-selection bug. It is a consequence of
constructing a realized segment before its ending contact is known. Under a
free-flight model it dissolves rather than needing a fix.

## 10. The relative-rise contract — CURRENT, and settled

    apex_height_meters  = relative rise above launch
    apex_rise_meters    = the same quantity
    height_contract     = "relative_rise"

`start_height_meters` and `end_height_meters` are absolute. Presentation derives
an absolute gravity apex and stamps `height_contract = "gravity_true"`. A gate in
`test_runner.gd` asserts both halves.

This is deliberate, consistently used by every writer, and matches what
`RallyKinematics` actually solves. **Do not reopen it.** A pass that reinterprets
`apex_height_meters` as absolute is breaking a correct prior decision.

## The serve has two models, and neither is the authority — CURRENT

Audited 2026-08-16. No code changed.

**Production is an inverse fit to an outcome that was already rolled.** The order
in `_resolve_opponent_serve` is: `serve_error := rng.randf() < chance` → choose an
aim point → *(shadow record)* → if the error rolled, `_errant_serve_landing`
**moves the landing to make the verdict true** → take the distance to that
landing → `_serve_arc` sweeps pace × spin calling `solve_angle_for_range` until
something clears the tape, and keeps the fastest ground speed. The code says so
itself: *"the official ball has to go where the official verdict already says it
went."* Landing is an input; launch state is solved backwards from it.

**The geometric shadow is forward but degenerate.** `resolve_serve` aims, applies
execution error, flies it and lets the landing fall out — the right direction —
but measured over ten serves on both sides, `launch_mode` was **lofted 10 times
out of 10**, which is why its launch angle is ~77°. A shot chosen from one branch
every time is not a repertoire.

They are not two answers to one question. Production asks *"what launch puts the
ball where I already decided it lands?"*; the shadow asks *"what does this
server's ball do?"* The 2.89× horizontal-speed gap is that difference, not an
error in either arithmetic.

Measured intended-to-realised pace, ten serves: production keeps **0.53–0.85** of
the geometric pace, relieving downward in every case.

**The 215/218-through-the-net note in `_serve_arc` does not prove real pace is
wrong.** It proves an over-constrained inverse solve: real pace *plus* an exact
predetermined landing *plus* a 2.6 m contact leaves almost no solution above the
tape. That is evidence about the solving direction, not about the server.

**Verdict: C — neither model as currently structured.** Worth keeping from
production: pace relief, the net-clearance filter, and quickest-clearing
selection, which are real machinery. Worth keeping from the shadow: the forward
order — aim, execution error, launch, physics, landing. What must change is that
a rolled outcome may not define a landing that launch state is then fitted to.

**Nothing here requires authoring physics.** Every needed component exists. The
missing piece is order.

## The serve, built forward — CURRENT

Implemented 2026-08-16, on verdict C. The chain, and it is the only one:

    aim (intent)
      -> _serve_launch: pace relief x spin, filtered on the tape,
         quickest clearing ball kept
      -> AttackSwingModel.deliver: bearing, vertical and power execution error
      -> ONE launch state
      -> AttackResolutionModel.resolve under that launch's own gravity
      -> net clearance, landing, in / net / long / wide, duration
      -> trajectory, stamped with the launch state
      -> receiver read
      -> presentation

`GeometricAttackResolverModel.resolve_serve` owns the launch and is now live on
both sides rather than a shadow. `rally_simulator._serve_arc`,
`_ground_to_net_meters` and `_errant_serve_landing` are deleted: nothing
manufactures a landing, and nothing fits a launch to one.

**The serve-error draw survives and decides nothing.** `rng.randf() <
_serve_error_chance(...)` still runs, in its old position, so every downstream
consumer of the main stream keeps the sequence it had. A serve pass that also
reshuffled the reception, the set and the swing would have been unmeasurable.
Removing it is a separate, mechanical change.

### What the forward order exposed

Two defects, both of the §0 kind, neither visible while the sweep was solving
backwards to a landing nothing perturbed afterwards.

**One ball, two gravities.** The old sweep solved each candidate flight under
the ball's spin gravity and then asked its height at the net under the default
9.8. A topspin serve was certified over a tape it crossed as much as a metre
lower. Fixed by passing the candidate's own gravity to the height query.

**A constant standing where a function belongs.** `SERVE_NET_CLEARANCE_METERS`
was a flat 0.12 m. `_feasible_launch` had already found that exact constant
wanting for the swing and replaced it with the margin the shot's own vertical
spread demands, because execution error arrives at the tape as `ground_to_net *
tan(error)` — centimetres from a tight set, a third of a metre from four metres
back. **A serve is struck nine metres back.** Measured on the first forward
build: median clearance 0.071 m against a planned 0.12, 46% of serves missing,
90% of those into the tape. The serve now obeys the swing's clearance rule and
has no constant of its own.

### Before and after, 160 isolated rallies per side

Each rally gets a fresh `GameManager`, so a difference is that rally's own.

| | opponent before | opponent after | home before | home after |
|---|---|---|---|---|
| launch pace | *not published* | 14.27 | *not published* | 13.93 |
| launch angle | *not published* | 18.5° | *not published* | 18.8° |
| horizontal | 15.87 | 13.47 | 15.88 | 13.18 |
| vertical | **0.000 by construction** | 4.35 | **0.000** | 4.45 |
| net clearance | *not computed* | 0.599 | *not computed* | 0.601 |
| landing | manufactured on error | from the flight | manufactured | from the flight |
| duration | 1.095 | 1.253 | 1.092 | 1.270 |
| serve error | 0.150 | 0.181 | 0.150 | 0.294 |
| ace | 0.019 | 0.019 | 0.019 | 0.013 |
| reception quality | 0.411 | 0.471 | 0.339 | 0.379 |
| contacts/rally | 7.74 | 7.27 | 6.25 | 5.84 |
| launch mode | lofted 160/160 | driven 146 / lofted 14 | lofted 160/160 | driven 154 / lofted 6 |

The degenerate branch is gone: a serve is a driven ball most of the time and a
lofted one when the server cannot drive it, which is a repertoire.

**The 15.0% either side was not a measurement.** It was one coin flip called
twice against the same function, so the two sides agreed by construction. They
now differ — 18.1% and 29.4% — because their servers and their instructions
differ. Geometry is not the cause and was checked: both sides serve from x=0.82,
median reach 17.11 m against 17.30 m, aims mirrored.

### Certification, 2026-08-16 — and a correction

Measured with two instruments, because one could not have answered the question.
`tools/run_serve_certification.gd` calls the resolver directly across side ×
style × risk × ability, 400 draws a cell, 36,000 serves.
`tools/run_serve_live_census.gd` runs 400 isolated rallies a side and
*reproduces* each serve's three execution draws from the rally seed, so nothing
in production had to be modified to be measured.

**The controlled serve is sound.** 9.8% error overall, and the responses are the
ones a simulation should have:

| | error | net | long | wide | short | pace | angle | driven |
|---|---|---|---|---|---|---|---|---|
| **all** | 0.098 | 0.029 | 0.018 | 0.034 | 0.017 | 19.45 | 13.7° | 0.93 |
| home | 0.098 | 0.030 | 0.019 | 0.033 | 0.017 | 19.47 | 13.7° | 0.93 |
| opponent | 0.098 | 0.028 | 0.018 | 0.035 | 0.017 | 19.43 | 13.7° | 0.93 |
| weak | 0.168 | 0.034 | 0.029 | 0.069 | 0.036 | 15.74 | 18.6° | 1.00 |
| average | 0.088 | 0.029 | 0.019 | 0.029 | 0.011 | 19.34 | 13.4° | 0.93 |
| strong | 0.038 | 0.024 | 0.007 | 0.004 | 0.002 | 24.41 | 8.9° | 0.87 |
| risk 0.0 | 0.099 | 0.035 | 0.012 | 0.032 | 0.019 | 15.75 | 17.6° | 1.00 |
| risk 0.5 | 0.091 | 0.023 | 0.019 | 0.033 | 0.016 | 20.77 | 12.0° | 0.93 |
| risk 1.0 | 0.104 | 0.029 | 0.024 | 0.037 | 0.014 | 21.43 | 11.1° | 0.87 |

Ability is monotone. Risk reaches the ball as pace (15.75 → 21.43) and not as a
hidden error term. **The two sides are identical to three decimals when
personnel are matched**, which settles the geometry question: 0.098 against
0.098, contact height 2.62 both, target error 1.64 against 1.67.

**Correction to the previous entry.** It said the live sides "differ on
personnel and instructions". The personnel half is wrong and the measurement
says so: across all 800 live serves the server is **the same voli on both
sides** — home #1 and opponent #101, both Jump Float, both 58/74/74/74. They are
attribute-identical clones. The live figures were:

| window | opponent | home | gap |
|---|---|---|---|
| seeds 20000–20159 (the 160 first reported) | 0.181 | **0.294** | +0.113 |
| seeds 20000–20399 | 0.203 | 0.237 | +0.035, z = **+1.19** |

The 29.4% was a 160-sample window, and it reproduces exactly on that window —
the number was right and the inference from it was not. At 400 a side the gap is
1.2 sigma and survives conditioning on serve mode (+0.027 targeted, +0.032
aggressive), consistent with the home side's slightly lower planned pace (13.89
against 14.19) and clearance (0.597 against 0.612), which comes from its risk
instruction. **There is no side asymmetry worth chasing.**

**The live 22% is one style at one ability, not a game-wide rate.** Every live
serve is a Jump Float, which is the worst style in the factorial (0.159 against
0.079–0.091 for the other four) because a float has no topspin to buy a dive.
The vertical slice cannot exercise the serve model, and no live measurement of
it should be read as one until the roster serves more than one way.

### Which channel nets a serve — the earlier answer was wrong

The first reading of this was that a netted serve is low on *both* the vertical
and the power draw, taken from the two conditional **means** (−1.65 and −1.45).
Means cannot answer a sufficiency question. The conditional rates can:

| draw state (bad = below −1σ) | live net rate | factorial net rate | share of live nets |
|---|---|---|---|
| power bad only | **0.810** | 0.113 | 0.596 |
| vertical bad only | 0.163 | 0.035 | 0.154 |
| both bad | 0.941 | 0.352 | 0.118 |
| neither | 0.032 | 0.001 | 0.132 |

**A bad power draw is close to sufficient on its own; a bad vertical draw is
not**, by a factor of four to five, and power alone accounts for 60% of every
serve put into the tape. It does not take both.

### The spread multiplier's response, measured and not committed

`SERVE_SPREAD_MULTIPLIER` was swept 0.45 → 1.00 with no change kept.

| multiplier | factorial error | factorial **net** | factorial long | factorial wide | live error | live **net** |
|---|---|---|---|---|---|---|
| 0.45 | 0.033 | **0.025** | 0.002 | 0.005 | 0.150 | **0.139** |
| 0.55 | 0.055 | **0.030** | 0.007 | 0.014 | 0.174 | **0.150** |
| 0.70 | 0.098 | **0.029** | 0.018 | 0.034 | 0.220 | **0.170** |
| 0.85 | 0.164 | **0.035** | 0.036 | 0.056 | 0.259 | **0.160** |
| 1.00 | 0.229 | **0.038** | 0.051 | 0.078 | 0.314 | **0.158** |

Long and wide scale with the dial across a factor of twenty-five. **The net rate
does not move at all** — and what movement there is runs the wrong way.

That is the whole diagnosis in one table. The clearance margin is derived from
*vertical* spread, so raising the multiplier raises the planned margin (median
0.956 → 1.426 m) and the power error in lockstep, and the two cancel exactly on
the channel that nets the ball. The conditional net rates confirm it: power-only
sits at 0.67–0.81 and vertical-only at 0.16–0.17 **at every multiplier**. They
are properties of the channel, not of the dial.

So the multiplier cannot be used to set the net rate, and recalibrating it would
move long and wide to hit a number that net is producing. Its evidence is stale;
the reason not to touch it now is stronger than that.

### The relief floor is derived — CURRENT, landed 2026-08-16

`SERVE_PACE_RELIEF_FLOOR = 0.55` is gone. The sweep now runs from full pace down
to `BallFlightModel.minimum_speed_to_reach(aim, contact height, gravity)` — the
slowest ball that carries to the aim at all, below which no serve exists to find.
The floor is solved **per spin setting**, because a ball falling at 25 m/s² needs
more speed to carry the same distance than one falling at 9.8, so the pace loop
now sits inside the spin loop rather than beside it.

The bound is derived rather than tuned in the only sense that matters: it is not
a number anybody chose. `_quickest_clearing_loft` had already written the rule
down for its own floor forty lines away — *"The floor is a derived quantity, not
a dial. Below the minimum speed for the range nothing reaches at any angle, and
at it the two roots merge."*

**The float punt is gone.** The strong float cell that served a 68° ball with
10.1 m of clearance now serves **driven at 14.48 m/s and 16.3°**, and an
independent enumeration of the sweep agrees with the resolver on all four probed
cases. Jump Topspin strong is untouched at 28.10 m/s and 6.4°, so the change
reaches only the cell that was broken.

| | before | after A |
|---|---|---|
| live error / net | 0.220 / 0.170 | **0.176 / 0.131** |
| live clearance | 0.61 | **0.85** |
| live driven share | 0.935 | **0.981** |
| factorial error / net | 0.098 / 0.029 | 0.105 / **0.039** |
| factorial driven share | 0.933 | **1.000** |
| factorial angle | 13.7° | 13.1° |
| ability weak / average / strong | 0.168 / 0.088 / 0.038 | 0.176 / 0.097 / 0.042 |
| Jump Float error / net / duration | 0.159 / 0.080 / 1.30 | 0.180 / 0.120 / 1.24 |

Live improves and the factorial's net rate *rises*, and both are the same fact:
**the punt was hiding error.** A ball lobbed nine metres over the tape cannot be
netted, so the strong-float cell scored 0.065 net by never playing a real serve.
Converting it to a driven serve converts its immunity into ordinary risk.
Ability monotonicity survives, and Jump Float remains the worst style now that it
is honest about it.

### The power-shortfall margin — UNRESOLVED, and this is why

Attempted, measured, and **reverted**. Both variants worked and both cost too
much.

The rule tried: plan the launch so the ball still clears at the pace it would
have after a `NET_CLEARANCE_SPREAD_SIGMAS`-sigma power shortfall, using
`AttackSwingModel.power_error_scale` — the same scale `deliver` applies to the
draw, extracted so a planner can read it before the draw is taken. No new
constant: the sigma count is the clearance rule's own and the scale is the
delivery model's own.

| | A (no power budget) | A+B added | A+B in quadrature |
|---|---|---|---|
| factorial net | 0.039 | 0.034 | **0.007** |
| factorial angle | 13.1° | 25.1° | 20.4° |
| factorial driven share | 1.000 | 0.644 | 0.700 |
| **live net** | 0.131 | 0.074 | **0.003** |
| **live angle** | 19.8° | 70.0° | **66.6°** |
| **live clearance** | 0.85 | 10.48 | **9.01** |
| **live duration** | 1.28 | 3.04 | **2.78** |
| **live driven share** | 0.981 | 0.000 | 0.021 |
| **live ace** | 0.009 | 0.000 | **0.000** |

Quadrature is the right combination and was not chosen to soften the result —
`deliver` pulls its three draws from separate normals, so adding two independent
two-sigma shortfalls plans for a serve that essentially never happens. It halved
the cost and did not change the verdict.

**The reason is the distance, and it is not fixable by combination.** Height at
the tape carries a gravity drop going as `1/v²`. For the live server two sigma of
pace is worth **2.19 m** of height at the net against **0.56 m** for two sigma of
angle — so the power budget is four times the angular one and dominates any way
they are combined. A serve that insures against its own mishit at the rate an
angle is insured stops being a serve: every live serve became a 2.8 second lob
with no aces at all.

**Making it work needs a smaller sigma count for pace than for angle, and nothing
in the model says what that number is.** `tactical_risk` already means the pace
instruction and `serve_consistency` is already inside the spread the reserve
would be derived from; reusing either is double-counting dressed as derivation.
So this is a genuine design question — *how much pace does a server hold back?* —
and it is recorded as UNRESOLVED PHYSICS 7 rather than answered with a fourth
constant.

What survives the revert is `AttackSwingModel.power_error_scale`, extracted from
inside `deliver` and behaviour-neutral (both probes reproduce A byte for byte).
It is what makes the quantity nameable before the draw, which is what the pass
that answers the question will need. `_serve_launch` still takes it, named
`_power_shortfall_scale`, so the parameter documents the hole rather than hiding
it.

### The calibration this invalidated

`SERVE_SPREAD_MULTIPLIER = 0.70` carries a sweep table claiming 15.6% / 10.6%
serve error at that value. That table was measured against the old launch — full
pace on the lofted root — and the launch has changed. **The constant is not
wrong; its evidence is stale.** Recalibrating it is a balance pass and was not
done here, because tuning a rate at the same time as changing the physics under
it makes both unmeasurable.

What a recalibration will need to decide is named below, not invented here.

## ATTACK_COVERAGE cannot own its ball yet — traced 2026-08-16, no code changed

The ownership pass was attempted and stopped at the classification step, which is
where it was supposed to stop if a required quantity had no model. One does.

**The current chain, all three sites.** A blocked swing produces a rebound point
(`_attack_coverage_target`, or `BlockDeflectionModel`'s landing).
`_resolve_attack_coverage` scores the six on-court volis on proximity, ball
control, anticipation and their `attack_coverage_responsibility`, adds one RNG
draw, and returns `{player, quality, success}` — **and nothing else**. The event
is added with `start = rebound point`, `end = rebound point + Vector2(0.04,
±0.05)`, and no `outgoing_trajectory`. After the rally is resolved,
`_ensure_event_trajectories` invents one: `flight_time = 0.58`, `apex = 1.8`,
both endpoint heights defaulted to 1.0 m.

Measured over **5,000 isolated rallies, 234 successful coverage contacts, 234 of
234 fabricated afterwards** — every one carries `height_source = "default"`,
duration exactly 0.58, apex exactly 1.8, heights 1.0 → 1.0, and a target offset
of exactly 0.5763 m. Not a distribution with a tight peak: **four values, each
identical on all 234 contacts.** The next contact is a SET in 234 of 234.

(First measured at 1,400 rallies and 60 contacts; deepened to 5,000 rallies with
every figure unchanged to four decimal places. The gap median moved 1.1148 to
1.1158.)

Coverage falls to the home side about three times as often — 172 against 62 —
which is unexplained and probably follows the block-touch asymmetry the dig work
already measured at 22.9% against 6.5%.

**Four accounts of one covered ball, and no two agree.** The drawn flight lasts
0.58 s. The gap from the coverage contact to the SET that plays it runs 0.865 to
1.296 s, median **1.116 s**, with a 5th percentile of 0.927 — so **the drawn ball
lands more than half a second before the setter touches it on essentially every
coverage contact in the game**, not merely at the median. The setter's own reachability window is a third
number and differs per site: the first-exchange home site passes nothing and
falls through to `DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS` (0.68 s); the
continuation site passes `coverage_time`, which is the **incoming** block leg's
duration standing in for the outgoing pass's; the opponent site passes neither,
and also skips `pass_contact_height_meters` and `pass_apex_meters`, which
`_resolve_opponent_transition` has accepted since the bump-height work.

### Classification

**A — already authoritative.** Contact position (the rebound point). Contact
time (the incoming deflection's `end_time`, already published as `event_time`).
The actor. Control, as `coverage_quality`, whose RNG is already spent. The
incoming ball. Travel distance, already computed for `coverer_move_time`.

**B — exactly derivable.** Contact height, from
`GeometricAttackPromotionModel.pass_contact_height_meters(coverer)` — the same
primitive the dig and the reception already call for a platform contact. Ending
height, from `set_contact_height_meters(setter)`, though only the first-exchange
site has a setter in scope; the other two select one inside the continuation.
Duration, from `BallFlightModel.duration_for_apex` — **given an apex**. And the
hand-off itself: `_resolve_home_continuation` already takes `dig_flight_seconds`
and `incoming_pass_trajectory`, so once a ball exists there is a consumer with
its hand out.

**C — missing physics, and this is the stop.**

1. **The apex.** Nothing in the engine models how high a platform contact off a
   block rebound goes. The one adjacent model is `_dig_pass_result`'s
   `pass_contact_height + lerpf(1.35, 3.05, 1.0 - spoil)`, which is UNRESOLVED
   PHYSICS 1 on this page — chosen by eye, never measured against a
   distribution, and authored under exactly the plumbing pressure this pass is
   under now.
2. **The `spoil` that would drive it.** The dig composes spoil from control
   (0.55), reach margin (0.20), posture (0.17) and travel (0.08). Coverage
   resolves **no posture and no arrival at all**, so two of the four terms do
   not exist for it. Handing `_dig_pass_result` an empty arrival does not omit
   the term — it computes `stretched = (0.25 - 0.0) / 0.85 = 0.294`, a 29%
   stretch applied to every coverage contact in the game, arriving by default
   rather than by measurement. That is `FAILURE_MODES.md` §0 in one line.

There is no third route. `BlockDeflectionModel` gives the incoming ball a speed
and a duration, but no relation anywhere in the engine turns incoming pace into
outgoing height — the dig's apex pointedly does not use it, and inventing one is
a restitution model, not plumbing.

**So coverage stays unowned, and the reason is now countable rather than
asserted.** `tools/run_coverage_census.gd` is the instrument; the numbers above
are its output. What this needs is the platform-contact physics pass — one
vertical model for reception, controlled dig, emergency dig and coverage
together, measured against a distribution — which is UNRESOLVED PHYSICS 1 and 4
answered as one question rather than four. Doing coverage first would mean
copying an unmeasured band onto a second family and defaulting two of its four
inputs, which increases the number of independent opinions about a physical
quantity at the exact moment this document exists to reduce it.

## UNRESOLVED PHYSICS — do not fill with defaults

Items 1, 2, 3, 4 and 6 are one question, not five, and
**`docs/design/PLATFORM_CONTACT.md`** is the design pass that answers it: intent,
contact circumstance and execution as three separate layers, with no apex band in
any context. Read it before touching any of them. This page stays normative where
the two disagree.

1. **DIG apex calibration.** `lerpf(1.35, 3.05, 1.0 - spoil)` was chosen by eye
   and never measured against a distribution.
2. **DIG lateral miss direction.** `digger.id % 2` was introduced to avoid a new
   RNG draw. Avoiding randomness does not make a rule physical.
3. **Poor-contact vertical failure modes.** Reception lifts a shanked ball;
   dig flattens a spoiled one. Both are plausible; they disagree.
4. **Platform target intent** across reception, controlled dig, emergency dig and
   coverage. No shared representation exists. **The representation question is
   settled as of 2026-08-16** — `PLATFORM_CONTACT.md` §3a: anchors plus at most one
   derived bound, not an exact launch and not a region. What remains open is the
   *preference* that ranks feasible launches against those anchors, which is
   decision logic and has moved to the selection rule. Note that
   `_desired_pass_target` already compiles an overpass-avoidance preference into
   the reception's target point as five bare literals; the selection pass should
   take that rule over rather than sit beside it.
5. **Serve endpoint semantics** — structurally unresolved until §4/§5 are
	represented. The 2026-08-25 presentation pass made the current boundary
	explicit: the simulator retains the natural floor endpoint and calibrated
	responsibility time, while presentation derives and marks the physically
	played prefix at the descending platform-height crossing. The next outgoing
	flight starts at that same derived contact, so the visible segment is
	continuous without pretending that its endpoint owns gameplay. Promoting the
	crossing to gameplay produced the measured large outcome changes recorded in
	§7 and was reverted. This is a legible interim contract, not the future
	interception model.

	Sharpened rather than settled by the forward
   serve: its *launch* height is now exact and published, and `height_source`
   grew a third value, `start_resolved`, to say so. The ending height is still
   the 1.0 m default, because `BallFlight.from_trajectory` reads
   `end_height_meters` as **the height of the next contact** while the serve's
   own flight solves to the floor. Those are different numbers and publishing
   either one silently would move the receiver's read for a reason nobody
   chose.
7. **What margin does a server plan for their own mishit?** **Verdict A —
   material missing physics.** The clearance rule budgets two sigma of *vertical*
   spread and nothing of power. From nine metres back the gravity drop term goes
   as `1/v²`, so a power shortfall costs far more height at the tape than an
   angle error does: power-only-bad nets 0.81 of live serves against 0.16 for
   vertical-only, and accounts for 60% of every netted serve. Because the margin
   scales with the vertical spread and the power error scales with the same
   multiplier, **the net rate is invariant to the only dial that touches it** —
   0.025 to 0.038 across a factor-of-25 change in every other error channel. Net
   is 17.0 of the live 22.0 points of serve error, so this is not a rounding
   question. What it needs is a decision about how much pace a server holds in
   reserve, which is design, not plumbing.
   **Attempted and reverted 2026-08-16** — see "The power-shortfall margin"
   above for the two measured variants and why neither could be kept. The
   remaining question is narrow and stated: how many sigmas of pace does a server
   hold in reserve, given that two is demonstrably too many?
8. **~~The pace-relief floor is a dial where a derived quantity belongs.~~**
   **Resolved 2026-08-16** — the floor is now
   `BallFlightModel.minimum_speed_to_reach`, per spin setting. Kept below for the
   record of what it was.
   `SERVE_PACE_RELIEF_FLOOR = 0.55` bounds how much pace the launch search may
   give up. For a **strong float server** nothing inside that bound clears: the
   driven root's height at the tape climbs 1.447 → 2.674 m as pace comes off and
   is still short of the 2.877 m needed when the sweep hits its floor, so the
   search falls to the lofted root and serves a **68° ball with 10.1 m of
   clearance and a 2.98 s flight**. That is a punt, not a serve, and it makes
   ability *perverse*: serve technique purifies a float, which removes the topspin
   that would let it dive, so the better float server is the one who cannot keep
   it in. `_quickest_clearing_loft` says this exactly, about its own floor, in
   the same file: *"The floor is a derived quantity, not a dial."* It reaches
   6.5% of live serves (52 of 800, median 2.51 s, 7.0 m clearance) and the whole
   strong-float cell of the factorial.
6. **`ATTACK_COVERAGE` outgoing ball.** Still built by
   `_ensure_event_trajectories` after resolution; the only successful contact
   whose physical ball is not its own. **Traced 2026-08-16 and blocked on items
   1 and 4** — see the section above. Position, time, actor, control and the
   incoming ball are authoritative; contact height, ending height and duration
   are derivable; the apex is not, and the `spoil` that would drive it needs a
   posture and an arrival that coverage never resolves. It is the same question
   as 1 and 4, not a separate one, and it should be answered once for all four
   platform contexts rather than copied onto a second family.

Items 1 and 2 are mine, authored under plumbing pressure. They are the reason the
hard rule above exists.

## Migration principles

Establish contracts → pick **one** canonical rally path → make it obey → measure
physical and volleyball consequences → certify deterministic reproducibility →
then migrate siblings. Never all families at once, and never through a universal
resolver rewrite.

Candidate canonical chain, for evaluation later, not now: opponent float serve →
reception → second-contact interception → set → attack.

## Process rules carried forward

1. One physical quantity, one authoritative owner.
2. Removing fiction and authoring physics are different tasks.
3. No new physical constant or proxy in a plumbing pass.
4. Intent and result are separate.
5. Intended recipient and actual interceptor are separate.
6. Free-flight and realized-segment semantics must never be implicit.
7. Deterministic reproducibility is required after a physics change.
8. Old-seed outcome equivalence is required only for genuine structural refactors.
9. Isolated-rally and sequential-state probes answer different questions. A probe
   that reuses one `GameManager` across seeds lets one divergence cascade.
10. A stale comment, test or document does not override current provenance.
11. A probe comparing quantities with different semantics is invalid and must be
    repaired before anything is tuned.
12. Do not tune balance around a known physical inconsistency.
