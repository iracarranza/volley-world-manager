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

## UNRESOLVED PHYSICS — do not fill with defaults

1. **DIG apex calibration.** `lerpf(1.35, 3.05, 1.0 - spoil)` was chosen by eye
   and never measured against a distribution.
2. **DIG lateral miss direction.** `digger.id % 2` was introduced to avoid a new
   RNG draw. Avoiding randomness does not make a rule physical.
3. **Poor-contact vertical failure modes.** Reception lifts a shanked ball;
   dig flattens a spoiled one. Both are plausible; they disagree.
4. **Platform target intent** across reception, controlled dig, emergency dig and
   coverage. No shared representation exists.
5. **Serve endpoint semantics** — floor landing or reception contact — unresolved
   until §4/§5 are represented. Note that `launch_speed_mps` reads *both*
   endpoints, so this choice is not cosmetic.
6. **`ATTACK_COVERAGE` outgoing ball.** Still built by
   `_ensure_event_trajectories` after resolution; the only successful contact
   whose physical ball is not its own.

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
