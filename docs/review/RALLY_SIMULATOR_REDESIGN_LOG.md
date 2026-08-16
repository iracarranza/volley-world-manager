# Rally Simulator Redesign Log

Status: **DECISION / PROVENANCE JOURNAL.**

This file records *why* the rally simulator is being redesigned the way it is.
It is intentionally different from the normative specs:

- `docs/design/VOLLEYBALL_FIDELITY.md` owns the fidelity standard.
- `docs/design/CONTACT_AND_BALL_FLIGHT.md` owns current contact/flight semantics.
- `docs/FAILURE_MODES.md` owns recurring engineering failure patterns.
- `docs/review/PROBE_HANDOFF.md` owns current measurement handoff details.

This journal owns the reasoning trail: questions that exposed defects, rejected
approaches, measurements that changed direction, and design hypotheses that are
important even when they are not yet production code.

Do not treat an older entry here as current truth when a later entry supersedes
it. The value of the file is that the superseded reasoning remains visible.

---

## 1. The redesign goal

The target is not merely a rules-correct rally. The target is a rally where:

> **I can watch a normal rally and argue about the volleyball decision instead
> of arguing about whether the athlete could physically have been there.**

That standard changed the development priority. Many surrounding management
systems are already conceptually rich, but their consequences are only
meaningful if the rally engine can make a tired, badly positioned, late-reading,
well-trained or technically gifted voli visibly play differently for causal
reasons.

The canonical side-out remains the main certification sequence:

```text
medium float serve
→ three-person reception
→ setter transition
→ several plausible attack options
→ block reads/forms
→ floor defence
→ transition attack
→ kill / block / dig / continuation
```

The simulator should eventually make this sequence physically and tactically
legible without relying on presentation tricks to hide bad decisions.

---

## 2. Working method that emerged during the redesign

Several passes began as small repairs and exposed deeper ownership problems.
The process is now part of the design.

### 2.1 One authoritative model per physical quantity

A ball cannot have one speed for cognition, another for drawing, another for
reachability and another for the event log. A contact cannot have one time for
the animation and another for the next actor's movement window.

When multiple systems answer the same physical question, the first task is to
find the authority rather than average or reconcile the answers.

### 2.2 Remove fiction before authoring physics

Two categories must stay separate:

- **Removing fiction:** an authoritative answer already exists and another
  record/consumer carries something else.
- **Authoring physics:** the simulator has no authoritative answer yet.

A plumbing pass must not fill a missing quantity with a guessed apex, duration,
error scale, proxy, deterministic parity trick, or new formula. If it reaches a
missing physical rule, stop and name the rule.

### 2.3 Classify required quantities A / B / C

Before an ownership migration:

- **A:** already authoritative physical truth.
- **B:** exactly derivable from authoritative truth without a new assumption.
- **C:** missing physical rule.

A required C is a STOP condition.

This prevented `ATTACK_COVERAGE` from inheriting DIG's already-unmeasured apex
heuristic and fake arrival state.

### 2.4 Measurement is only useful when the instrument is valid

Repeated lesson: a precise number from the wrong model is worse than no number.
Examples include:

- a serve speed reconstructed from trajectory endpoints rather than its launch;
- sequential-rally differences being mistaken for the direct effect of a local
  physics change;
- a 29.4% home serve-error slice being interpreted as side asymmetry before the
  matched-population test showed the servers were clones and the window was
  noisy;
- a gate asserting an identity effect on serve error when ability confounded the
  comparison more strongly than aggression.

### 2.5 Fresh-manager isolated rallies answer a different question from sequential matches

A fresh `GameManager` per seed isolates the direct causal effect of a change.
Sequential match runs include all later propagation through score, rotations,
server identity, morale/state and subsequent rally conditions.

Both are useful. They must not be conflated.

### 2.6 Outcome movement is not automatically regression

Correcting a false physical fact is allowed to move outcomes.

Examples:

- publishing real serve launch state changed reception because cognition had
  previously consumed an endpoint-derived fake speed;
- replacing the inverse serve with a forward physical serve changed error rates;
- removing the strong-float lofted punt increased error in that factorial cell
  because the old impossible lob had been hiding net risk.

The correct question is whether the causal chain became more truthful and
legible, not whether an old aggregate remained fixed.

### 2.7 A local inconsistency is evidence, not automatically an implementation task

The redesign repeatedly found defects that were real but unsafe to fix locally.
The `ATTACK_COVERAGE` fabricated trajectory is the clearest case: it is wrong,
but fixing it alone would require copying unresolved DIG physics and therefore
increase the number of independent opinions about platform-ball height.

### 2.8 Shadow models are not authorities just because they have richer data

The first serve launch-ownership implementation accidentally promoted the
geometric serve because it carried explicit launch velocity. Measurement showed
it described a different ball: roughly 77° lofted launch and horizontal speed
far below the ball the rally actually flew.

A physically explicit shadow can still be the wrong model.

---

## 3. Early questions that changed the architecture

These were conversational design questions before the current contact/flight
spec existed. They should remain visible because later architecture is answering
them.

### 3.1 Should the ball determine rally time?

**Question:** the ball motion was essentially constant while blockers hung,
rallies could end before the ball reached the floor, and athlete events appeared
to run on their own timing. Could the duration of each physical ball leg become
the synchronization source?

**Direction:** yes in principle. The ball's physical flight should own the time
between contacts. Athletes are then evaluated by what they can do during that
window: how far they must move, whether a contact envelope is reachable, whether
a block can load/jump in time, etc.

The later refinement is important: the ball should not simply preselect the next
actor. A free flight exists independently; bodies read/react/intercept it. The
realized segment ends when an actual contact occurs.

Conceptually:

```text
contact A
→ authoritative outgoing/free-flight state
→ bodies read and move during that flight
→ contact B occurs if/when an actor can make it
→ realized A→B segment
```

This is the origin of the later free-flight versus realized-segment distinction.

### 3.2 Cogniticons were flashing like sonar

**Question:** cogniticons repeatedly flashed merely to say everyone was
"watching," which read as sonar rather than new information. Icons should appear
when a voli actually begins/changes an action, and persist long enough to be
legible. "Waiting" should be limited to an actual pre-serve state.

**Direction:** cogniticons should represent changed or meaningful action/state,
not continuous awareness. If not superseded, an icon should remain visible
longer rather than pulse periodically. A pre-serve routine gives `waiting` a real
phase instead of making it generic inactivity.

This remains a presentation/cognition principle: **show what changed, not that a
voli still exists.**

### 3.3 Jump sets need a stable approach window

**Question:** a setter who has to leap forward just to reach a jump set would
usually be better staying down and making a stable standing contact. Jump-set
capability should therefore be limited by an approach/stability window, not only
raw reach.

**Direction:** distinguish geometric reach from a stable action envelope.
Reaching a contact point is necessary, not sufficient. Body momentum, plant,
posture and usable launch window matter.

This idea later generalized to blockers, defenders and platform contacts: body
center and contact point are different facts, and feasible contact is not just a
circle around the body.

### 3.4 Very high serves/spikes/passes should cost something physical

**Question:** some serves rose implausibly high; similarly, any action placing the
ball higher should not be free. A voli should not be able to produce arbitrary
height without enough arm strength/power transfer, and high balls should carry
accuracy cost.

**Direction:** vertical shape must come from a physical launch, not a display
apex. Height should interact with power, timing and accuracy. Do not bolt on a
"high-ball penalty" while the underlying outgoing launch is still fictional.

The forward-serve work eventually validated this ordering: fix physical launch
ownership first; tune or author the trade-offs only after the quantity is real.

### 3.5 Responsibility, stacking and ready stance

**Question:** volis were standing next to/inside one another and the simulator
would assign a ball to an implausible rescuer—for example, a libero sprinting
from midcourt to take a ball already in the opposite's immediate area. Short tips
should belong to a designated short-ball defender or landing blocker before a
farther teammate. If a ball is in one voli's immediate reach, another voli
should not take responsibility unless the first has already touched it. The
previous contacter should clear space for the next action.

**Direction:** responsibility must precede interception rather than being inferred
from whoever can mathematically arrive fastest after contact.

Important hypotheses:

- immediate-control space creates strong ownership;
- responsibility zones and tactical assignments matter before raw pursuit;
- collisions/obstruction should make stacking costly rather than visually
  harmless;
- a previous contacter must recover/clear rather than remain inside the next
  contacter's workspace;
- short-ball responsibility is a role/positioning problem, not simply nearest
  Euclidean distance.

The ready stance was proposed as a physical commitment: planting the feet and
preparing to react within a directional vicinity. A visible foot/lean cue could
show the direction of expected reaction. A ball entering that prepared zone
should become easier to receive; a ball breaking the read (tip, sharp angle,
et deflection) should be harder to recover.

This remains later work, but it defines what "responsibility before
interception" should eventually feel like.

---

## 4. From event categories to physical contact families

A major redesign direction is that contexts should not each own unrelated
physics simply because their event names differ.

The emerging families are:

1. **Platform contact** — serve reception, floor dig, attack coverage, possibly
   bump set / emergency platform continuations.
2. **Set / overhead redirection.**
3. **Overhead strike** — serve and attack can share struck-flight primitives even
   when tactical selection differs.
4. **Block** — distinct contact geometry.

The rule is:

> **Same physical question → same resolver/physical primitive. Context changes
> intent and inputs around it.**

It is *not*:

> same action name → same whole code path.

This distinction is why the old proposed "2.6A platform extraction" was delayed.
Extracting shared plumbing before deciding what the outgoing ball meant would
have formalized the wrong semantics.

---

## 5. DIG / coverage split and the first outgoing platform ball

Commit landmarks:

- `faf0b78` — semantic `DEFENSE → DIG` split and `ATTACK_COVERAGE` separated.
- `664cb3e` — successful floor DIG begins publishing a physical outgoing ball.
- `8815331` — platform/contact audit exposes which pieces are shared and which
  are heuristics.

The DIG pass was useful because it established an ownership chain:

```text
DIG contact
→ `_dig_pass_result`
→ outgoing trajectory
→ SET consumes that exact incoming trajectory
```

But it also authored two pieces under plumbing pressure:

- apex rise `lerpf(1.35, 3.05, 1 - spoil)`;
- deterministic lateral miss based on `digger.id % 2`.

Those are now explicitly unresolved physics, not patterns to copy.

This experience produced the hard STOP rule in
`CONTACT_AND_BALL_FLIGHT.md`.

---

## 6. Height semantics and the serve mystery

Commits in this sequence included `0fbd337`, `91884f6`, `1bd633f`, and
`ad21923`.

A MatchScreen verification initially appeared to show disagreement between
published and drawn apexes. The real distinction was that
`apex_height_meters` is a **relative rise**, not an absolute world height.
That contract is now settled:

```text
apex_height_meters = relative rise
apex_rise_meters   = same quantity
height_contract    = "relative_rise"
```

Presentation converts that rise to gravity-true absolute geometry.
Do not reopen this semantic decision.

### 6.1 Correcting serve start height unexpectedly changed reception

A diagnostic experiment changed the serve trajectory's fictional start height
from 1.0 m to the real contact height. Reception changed slightly.

The causal chain was eventually proven:

```text
serve trajectory start height
→ BallPresentation.launch_speed_mps
→ `_read_error_meters`
→ perceived arrival
→ reception result
```

`BallPresentation.launch_speed_mps` reconstructed speed from the trajectory
start/end/duration. Therefore changing an endpoint representation changed what
cognition believed about how the ball left the hand.

That finding created the contact/flight ownership spec.

---

## 7. Contact and ball-flight semantics that resulted

`ad21923` added `docs/design/CONTACT_AND_BALL_FLIGHT.md`.

The load-bearing distinctions are:

### 7.1 Contact intent

What the voli attempts before the result is known: purpose, intended recipient,
target region, shape/tempo, etc.

Important:

- intended recipient ≠ actual future interceptor;
- intended target ≠ realized outgoing ball.

### 7.2 Physical contact

Consumes incoming ball, real body/contact state, capability, contextual intent
and already-resolved difficulty. Produces the outgoing launch and immediate body
consequence.

It does **not** decide the next interceptor merely because it needs a target.

### 7.3 Outgoing launch state

The ball immediately after contact, before the next actor is known.

Core invariant:

> **Launch velocity belongs to the ball leaving the contact. It does not change
> because somebody later intercepts it earlier.**

### 7.4 Free flight versus realized segment

The free flight is what the ball would do untouched. The realized segment is the
portion that actually occurred before the next event/contact.

Truncating the realized segment must not retroactively redefine the launch.

### 7.5 Presentation is downstream

Presentation may interpolate, convert relative rise to absolute height, and draw
only the realized portion. It cannot be the gameplay source of speed or other
physical truth.

---

## 8. Serve: the launch-ownership pass that correctly failed

The first implementation attempt assumed the geometric serve's
`resolved.flight` was the already-authoritative launch state.

Endpoint invariance looked perfect: truncating the flight did not change that
state. But measurement showed the promoted state described a different ball:
roughly 77° launch, with horizontal speed around one-third of the production
trajectory's implied horizontal pace in the representative case.

The correct response was to revert.

The discovery:

- the geometric serve was a **shadow** with rich launch data;
- production `_serve_arc` was the ball the rally actually flew;
- neither was a clean authority.

This is the canonical example of why "has the right fields" is not the same as
"owns the truth."

---

## 9. Serve authority audit and forward rebuild

Landmarks:

- `0898c0c` — serve causal-direction audit, no production change.
- `d63a6f7` — one forward physical serve becomes live.
- `a95772b` — measurement-only certification.
- `829ec7a` — arbitrary pace-relief floor replaced by a derived bound; power
  reserve experiment reverted.

### 9.1 Why neither old serve model was acceptable

Production was an inverse solve:

```text
roll serve error / decide landing
→ move landing to satisfy verdict
→ solve launch backwards to reach that landing
```

The geometric shadow had the right order but selected the lofted branch almost
every time.

The 2.89× horizontal-speed disagreement was not an arithmetic bug. The two paths
were answering different questions.

### 9.2 Canonical forward serve

The live order is now:

```text
aim / intent
→ feasible launch search (pace relief × spin, tape filter, quickest clearing)
→ execution error
→ ONE authoritative launch state
→ AttackResolutionModel / BallFlightModel
→ net clearance + landing + in/net/long/wide + duration
→ trajectory stamped with launch state
→ receiver read
→ presentation
```

Nothing manufactures a landing first.

`_read_error_meters` consumes the serve's published launch pace rather than
`BallPresentation.launch_speed_mps`.

### 9.3 Forward ordering exposed two hidden defects

1. A candidate was flown under spin-adjusted gravity but checked at the net under
   default 9.8. One ball had two gravities. Fixed by using the candidate's own
   gravity consistently.
2. Serve clearance used a flat 0.12 m constant while attack clearance already
   used a spread-derived rule. The shared rule was reused rather than inventing a
   new serve constant.

### 9.4 Certification corrected several misleading interpretations

Controlled populations showed:

- ability affects error strongly and monotonically;
- tactical risk arrives primarily as pace and also increases error when isolated;
- matched home/opponent populations are symmetric;
- the earlier 29.4% home slice was real for that window but not evidence of a
  side-specific physics defect;
- power execution shortfall is the dominant netting channel, not vertical error.

`SERVE_SPREAD_MULTIPLIER` can move long/wide rates but cannot solve the power-net
channel.

### 9.5 The strong-float punt and the derived relief floor

`SERVE_PACE_RELIEF_FLOOR = 0.55` stopped the driven search before the physical
minimum speed. Strong float servers therefore fell into absurd lofted punts.

`829ec7a` replaced the dial with
`BallFlightModel.minimum_speed_to_reach(...)`, solved per spin setting.

The pathology disappeared without inventing a replacement number.

### 9.6 Power reserve remains authored physics

A two-sigma power-shortfall reserve was attempted using existing execution
spread. Both additive and quadrature variants turned live serves into multi-second
lobs with enormous clearance.

Making the reserve work requires choosing a smaller pace-sigma budget than the
vertical-angle budget. Nothing in the model currently says what that number
should be.

The experiment was reverted. This is a named design question, not a plumbing
bug.

---

## 10. ATTACK_COVERAGE ownership attempt and why it stopped

`5ba5cee` is a measurement/classification stop, not an implementation.

Current successful coverage:

```text
block rebound
→ coverage claimant chosen + quality/success
→ event has no outgoing trajectory
→ rally finishes
→ `_ensure_event_trajectories` fabricates coverage ball afterwards
```

Measured over 1,400 isolated rallies:

- 60 successful coverage contacts;
- 60/60 trajectories fabricated afterwards;
- duration fixed at 0.58 s;
- rise/apex fixed at 1.8;
- endpoint heights default 1.0 → 1.0;
- target offset fixed;
- next contact SET in 60/60;
- actual coverage→SET event gap roughly 0.885–1.296 s, median ~1.115 s.

The drawn ball can therefore appear to finish roughly half a second before the
setter actually contacts it.

Classification:

**A:** contact position/time, actor, coverage control/quality, incoming ball,
travel distance.

**B:** platform contact height, eventual setter contact height, duration once an
apex is known, and the continuation handoff.

**C:** outgoing vertical shape/apex and a valid physical state that would drive
it. Coverage currently has no posture/arrival model, so feeding it DIG's spoil
function would silently manufacture difficulty from defaults.

Conclusion: coverage cannot safely own its ball until the platform-contact
physical model exists.

---

## 11. Current platform-contact vertical discrepancy

The current reception and DIG vertical models are not one physical model.

Plotting *rise* against their local quality-like scalar gives approximately:

| quality | reception rise | DIG rise |
|---:|---:|---:|
| 1.00 | 3.80 | 3.05 |
| 0.50 | 2.63 | 2.20 |
| 0.18 | 1.87 | 1.66 |
| 0.00 | 3.05 | 1.35 |

Reception is U-shaped: it flattens as execution worsens, then below its shank
threshold it turns upward again. DIG is monotone decreasing with spoil.

But the dramatic sign disagreement is **currently unreachable in live play**.
In an 800-rally corpus the reception shank branch (`execution < 0.18`) was never
entered. Realized reception rise stayed well above the trough. DIG likewise
never reached its theoretical 1.35 m floor.

The *practical* disagreement firing on every contact is the different ordinary
bands:

- reception: 1.45–3.80 m rise;
- DIG: 1.35–3.05 m rise.

Measured medians differed by roughly 0.32 m in the cited corpus. That propagates
directly into setter contact height and jump-set availability.

Important interpretation:

- "reception lifts a bad contact, DIG flattens one" is true of the code but not
  currently observable in normal rallies;
- the unreachable branch is **untested**, not disproven;
- the differing ordinary bands are the live structural disagreement.

Do not calibrate a future unified model against only the live distribution and
conclude that high shanks cannot exist merely because the current threshold
never fires.

---

## 12. Current design hypothesis: platform failure has more than one cause

A recent design question sharpened the platform model substantially.

### User hypothesis

A good pass should result from both good attributes and good circumstance, where
circumstance itself is partly created by attributes such as read, movement and
stability.

A poor contact caused primarily by **attribute/execution failure** despite good
position—for example, a voli arriving correctly but lacking the stability/control
to absorb a hard driven spike—should more often become an uncontrolled shank or
other deviation from intent, rather than automatically being rewarded with a
high rescue ball.

A poor contact caused primarily by **circumstance** can fail differently:

- a libero barely getting a platform under a hard ball may still have the skill
  to pop it high and keep it playable;
- an arm scraped under a falling tip at the last instant may barely move the ball
  at all;
- awkward reach/posture may constrain what launch can physically be produced
  even when the voli executes that constrained option well.

### Refinement / answer

This distinction is useful, but do **not** encode a rigid rule such as:

```text
attribute failure → low/shank
circumstance failure → high rescue
```

A hard ball that overwhelms a stable platform can still ricochet high depending
on platform angle and contact geometry.

The stronger architectural distinction is:

> **Circumstance constrains the feasible outgoing-launch envelope. Execution
> ability determines how closely the voli realizes an intended launch inside
> that envelope.**

Attributes can affect both stages:

- anticipation, movement, stability and body control help create a better contact
  state;
- platform technique/control help realize the intended outgoing ball once that
  state exists.

This suggests three separate layers.

### Layer A — intent

What ball is the voli trying to create?

Examples:

- reception: precise setter-oriented pass;
- controlled dig: playable ball to a setting area, potentially with deliberate
  recovery time;
- emergency dig: keep the ball alive, precision secondary;
- coverage: alive/controllable continuation, possibly only a broad target.

Intent may include target region/recipient and desired shape/tempo.

### Layer B — contact feasibility/state

What physical contact was actually available?

Potential inputs already partly represented elsewhere:

- incoming velocity/trajectory;
- arrival/reach margin;
- body velocity;
- planted vs moving;
- posture/stability;
- contact point/height;
- one-arm / platform / emergency contact shape;
- travel and recovery state.

This layer limits what launches are physically feasible. An arm barely under a
tip should not have the same available outgoing envelope as a balanced platform
under a serve.

### Layer C — execution error

Given the intended launch and feasible contact state, how closely does the voli
realize it?

Attribute failure belongs primarily here. Poor execution should increase
deviation from intent—direction, pace, vertical component, control—not choose one
universal visual failure such as "goes high."

### Result

The physical model should tend toward:

```text
intent
+ incoming ball
+ contact/body state
+ execution capability/error
→ realized outgoing launch
```

A scalar `quality` may remain as a useful summary or downstream evaluation, but
it should not be the sole cause of outgoing height.

This is the current preferred direction for the platform-contact redesign.

---

## 13. Another consequence: event type should not secretly choose apex band

Reception and DIG may legitimately produce different typical balls. The problem
is not that their apexes differ; the problem is that the difference is currently
attached directly to event family constants.

A controlled dig might intentionally be higher than a serve reception because a
team needs recovery time. A clean reception can be more direct because the
setter is already prepared. Conversely, an emergency tip save may barely rise.

Those differences should come from:

- **intent** (desired shape / recovery time / precision);
- **contact state** (what is feasible);
- **execution** (what was actually realized).

They should not come from:

```text
if event == RECEPTION: use 1.45–3.80
if event == DIG:       use 1.35–3.05
```

unless those ranges are eventually shown to be derived from context-specific
inputs rather than independent authored opinions.

---

## 14. The next platform-contact design pass

The next pass should be a **design/audit pass, not immediate extraction**.

It should compare:

- serve reception;
- controlled floor dig;
- emergency dig;
- attack coverage.

For each, identify current:

- contact intent / target;
- incoming ball state;
- arrival/reach state;
- posture/body state;
- contact position/height;
- control/execution inputs;
- horizontal miss behavior;
- vertical response;
- duration;
- outgoing-ball consumer.

Then define the minimum shared contract:

```text
PlatformContactIntent
    purpose
    intended target/region
    intended recipient if known
    desired shape/tempo if known

PlatformContactState
    incoming ball
    actual contact position/height/time
    actual body/posture/motion/arrival state

PlatformContactExecution
    relevant technical capability
    already-resolved execution/error inputs

PlatformContactResult
    realized outgoing launch state
    control/evaluation
    immediate body consequence
```

Names are illustrative; do not create classes merely because they are written in
this journal.

The critical questions are:

1. What is genuinely shared physical input across all platform contacts?
2. Which intent differences are legitimate by context?
3. Which contact-state quantities are missing for coverage/emergency contacts?
4. Can outgoing vertical shape be computed from intent + state + execution
   without one generic `spoil → apex` curve?
5. What physical quantities still require authored rules?

Only after this contract is coherent should the old 2.6A-style shared plumbing
be extracted.

---

## 15. Responsibility / interception direction after platform physics

The next large rally problem remains second-contact ownership and realistic
responsibility.

The desired order is not:

```text
choose setter
→ build pass that terminates at setter
```

It is closer to:

```text
platform contact intends a playable target/shape
→ authoritative outgoing free flight
→ candidates read/move
→ responsibility + reachability determine actual second contact
```

The intended setter can influence intent without becoming a guaranteed future
interceptor.

This is how the platform redesign reconnects to the earlier user questions about
liberos stealing balls, volis stacking, short-ball defenders and ready stance.

---

## 16. Presentation and cogniticon implications

The redesign is simulation-first, but it should make presentation easier rather
than harder.

Once actions have real start/change times and balls have authoritative flight:

- cogniticons can fire when a voli begins/changes a meaningful action;
- a read/ready state can persist rather than pulse;
- a pre-serve waiting state can exist for an actual pre-serve duration;
- blockers stop "hanging" because their movement/jump is evaluated against the
  ball window;
- a rally cannot visually finish before its terminal ball reaches the floor;
- previous contacters can visibly clear space because recovery is part of the
  continuing body state;
- MatchScreen draws the same physical ball gameplay used rather than a repaired
  approximation.

Do not improve 3D playback by disguising simulator decisions. Improve simulator
decisions so their physical manifestation naturally looks like volleyball.

---

## 17. Decision ledger

This is not exhaustive history; it lists the commits that materially changed the
redesign direction.

| commit | significance |
|---|---|
| `faf0b78` | `DEFENSE → DIG`; attack coverage becomes a distinct semantic contact |
| `664cb3e` | successful floor DIG begins owning an outgoing trajectory; also introduces later-named apex/miss heuristic debt |
| `8815331` | fidelity/platform audit; reveals shared primitives and why immediate platform extraction would be premature |
| `0fbd337` | MatchScreen trajectory verification exposes relative-rise vs absolute-height distinction |
| `91884f6` | partial DIG/reception height repair; remaining 1.0 defaults become explicit |
| `1bd633f` | isolated serve-height fork proves height correction changes reception through launch-speed reconstruction |
| `ad21923` | `CONTACT_AND_BALL_FLIGHT.md`; formal ownership/free-flight/realized-segment semantics |
| `0898c0c` | serve authority audit: production inverse fit vs forward-but-degenerate shadow; verdict C |
| `d63a6f7` | canonical forward serve; one launch, one flight, outcome from physics |
| `a95772b` | forward serve certification; power shortfall identified as dominant net-error channel |
| `829ec7a` | pace-relief floor derived from minimum reachable speed; attempted power reserve reverted as authored physics |
| `5ba5cee` | ATTACK_COVERAGE census/classification; ownership migration stops on missing platform physics |
| `666a56f` | `PLATFORM_CONTACT.md`; intent/circumstance/execution replaces per-event apex bands. Audit finds the DIG posture penalty `"emergency"/"fall"` unreachable, and incoming momentum computed but discarded by both outgoing models |
| `e8004b1` | platform design tightened: feasible-launch **selection** separated from feasibility; incoming momentum split into authoritative input vs authored transfer relation; hang/height moved from context to rally state; authored relations reduced four → three |

---

## 18. Current unresolved rally-physics questions

Keep this list aligned conceptually with `CONTACT_AND_BALL_FLIGHT.md`; the spec is
normative when wording differs.

### Platform contact

Designed in `docs/design/PLATFORM_CONTACT.md`; that page and the spec are
normative. What remains genuinely open after the design pass:

- **the rally-intent policy** — how much time beyond the setter's bare arrival
  does the team want a transition ball to buy, and what does it trade away to buy
  it? Audited 2026-08-16: the target seat, the standing release height and the
  setter's travel time are all available and non-circular, but `t = travel time`
  alone is degenerate — it gives every intended ball zero arrival margin and
  leaves no way to intend a quicker transition than the setter's legs require.
  Gates controlled-dig promotion;
- **the selection rule** — given an intent and a feasible envelope, what makes one
  feasible launch preferable to another? Required before any broad-intent contact
  (coverage, emergency) can be promoted, and required for the controlled dig
  wherever its intended launch turns out infeasible. Decision logic, not physics;
- **the transfer relation** — incoming speed + posture + ability → outgoing speed.
  The incoming velocity is authoritative and currently discarded, but knowing the
  input exactly is *not* permission to invent its transformation;
- the reachable platform-angle range, and execution error as angular deviation;
- how `desired_height_at_target` and `desired_time_to_target` are computed from
  rally state — settled only that they may **not** be per-context constants;
- coverage posture/arrival/contact-state resolution (class B, derivable);
- **the controlled dig has no setting target** — all three sites aim at
  `contact + Vector2(~0.04, ~-0.04)` and never consult the setter's position,
  while both sides already carry a `setter_release_target` the reception uses;
- **the continuation dig passes an empty arrival**, fabricating a 29% stretch on
  every one — the same defect that disqualified coverage, already live;
- how much of the offence has rebuilt at a transition contact: no representation
  exists, and it is the natural second input to the rally-intent policy;
- whether a contact *modality* — two-arm platform, one-arm save — is needed,
  which is only true if it changes the feasible envelope;
- what `quality` means once it is an evaluation of realized-against-intended
  rather than a cause.

Settled and not to be reopened: `spoil` does not survive as the vertical driver;
event family may not choose an apex band; the dead `"emergency"/"fall"` penalty
is not to be repaired, only cited.

### Serve

- how much pace reserve a server plans against power shortfall; current model
  deliberately leaves this unanswered rather than adding a sigma dial.

### Flight / interception

- explicit free-flight versus realized-segment representation if the existing
  marker becomes insufficient;
- serve endpoint semantics once reception interception is represented cleanly;
- reception outgoing free flight → actual second-contact interception.

### Other contacts

- ATTACK_COVERAGE owns no outgoing ball until platform model exists;
- SET/ATTACK/BLOCK remaining height/launch ownership migrations;
- opponent set-quality lineage and approach/body-contact diagnostics (later 3A /
  3B work).

### Spatial volleyball

- responsibility before interception;
- ready stance / directional reaction commitment;
- collision and obstruction;
- previous contacter clearing;
- short-ball ownership;
- continuous off-ball movement across ball phases.

---

## 19. Principles to preserve in future rally work

1. **The ball is a physical object, not an event label.**
2. **Contact intent is not a guaranteed outcome.**
3. **Launch state belongs to the contact that created it.**
4. **A later interceptor cannot redefine how the ball was launched.**
5. **Responsibility should exist before the simulator chooses who touches the ball.**
6. **Body center, body state and contact point are separate facts.**
7. **Reachability does not guarantee a stable volleyball action.**
8. **Context should change intent and contact state, not create private physics for the same physical act.**
9. **Quality is an evaluation/summary unless explicitly proven to be a physical cause.**
10. **Attributes may affect both circumstance creation and execution; do not collapse those stages.**
11. **Presentation consumes simulation truth; it does not repair or invent it.**
12. **A threshold outside its observed distribution is not a working mechanic.**
13. **A guessed constant added to finish plumbing is a new physical opinion. Stop instead.**
14. **Measure isolated direct effects before interpreting sequential match cascades.**
15. **Do not tune balance while changing the physical quantity being measured.**
16. **Do not preserve old outcomes merely because they are old. Preserve causal correctness.**
17. **Do not generalize a local heuristic because another context currently needs an answer.**
18. **The useful metric is often the number of independent physical opinions, not the number of abstractions/classes.**

---

## 20. How to use this journal

When a future pass raises a question that sounds familiar:

1. Read the relevant normative design doc first.
2. Search this journal for the physical quantity or contact family.
3. Find the earlier question and why the previous direction changed.
4. Re-run the named probe where one exists rather than trusting copied numbers.
5. If new evidence contradicts an entry here, append the new result and mark the
   old conclusion superseded; do not erase the reasoning chain.

The redesign has improved most when a failed implementation or user question was
allowed to change the architecture instead of being patched around. Preserve
that habit.
