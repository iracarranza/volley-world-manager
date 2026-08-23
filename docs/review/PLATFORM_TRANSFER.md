# M4 slice 2, first half: the incoming ball reaches nothing

Run: 2026-08-17, from `9ce1413`. Instrument:
`tools/run_platform_transfer_probe.gd`. 600 rallies on the vertical slice, both
serving sides, seeds 23000–23299.

`PLATFORM_CONTACT.md` §11 gives slice 2 two jobs. The second — "how often the
ball the current model produces lies outside the envelope the shadow says was
physically available" — needs T1 and T2, which are unauthored. **The first does
not**, and it is the one that has to come first:

> outgoing speed, vertical, apex, destination error

T1 is *"incoming speed + platform/body state + absorption ability → outgoing
speed"*. Before authoring it, the obvious question is what the shipped model
already does with the first term. Nobody had looked.

**Nothing. It does nothing with it.** That is the finding, and it changes what
slice 3 is: not a refinement of an existing channel, but a channel that does not
exist.

---

## 1. Method — the probe authors nothing

Both resolvers publish their own output. The probe converts it into §6's contract
and reads `incoming_speed_mps`, which both already publish:

```text
outgoing_vertical_mps = sqrt(2 g * apex_rise)      -- the rise is published
outgoing_horizontal   = court distance / duration  -- both published
outgoing_speed_mps    = hypot of the two
```

No constant is introduced and no relation is assumed. Contacts with no outgoing
flight are not counted: a defender who never controlled the ball did not pass
anything, and the resolvers correctly refuse to stamp a trajectory on a miss.

**One instrument bug, worth recording.** The first draft read `duration_seconds`
— the key `_truncated_arc` uses internally — where `BallTrajectory.to_dict()`
publishes `duration`. It found nothing on every flight and reported **zero
measurable contacts over 600 rallies**. An empty population reads exactly like a
finding, which is why the run that produced it was not written up.

---

## 2. The shipped ball, in §6's units

595 controlled platform contacts.

| | n | outgoing speed p50 | vertical p50 | horizontal p50 | apex rise p50 | duration p50 |
|---|---:|---:|---:|---:|---:|---:|
| reception | 484 | 8.643 | 7.427 | 4.215 | 2.814 | 1.336 |
| dig | 87 | 7.089 | 6.968 | 0.825 | 2.477 | 1.226 |
| coverage | 24 | **6.170** | **5.940** | **1.671** | **1.800** | **0.580** |

Ranges: reception speed 7.412–11.599, dig 6.053–7.650, coverage **6.170–6.170**.

A dig's destination error runs 0.087–1.609 m, median **0.596 m** — against a
target that sits about 0.8 m from the contact point in the first place. The pass
misses by most of the distance it was trying to travel, which is what §13.9's
item 3 looks like from the other end.

---

## 3. Coverage does not produce a ball. It produces a drawing

Every column is min == p50 == max across all 24 contacts. Traced rather than
inferred: **no coverage site calls a pass resolver at all.** The three
`ATTACK_COVERAGE` events publish no `outgoing_trajectory`, so the flight is
stamped by the end-of-rally display fallback, whose arm for this type reads
`flight_time = 0.58` and `apex = 1.8`. The distance is fixed too — the coverage
target is `contact + (0.04, ±0.05)`, which is 0.969 m every time.

§4 says coverage's missing state is class B rather than C. That understates it.
The state is derivable, yes — but there is also nothing downstream to give it to.

> **This is the cheapest real physics in M4.** Coverage is the only context where
> promoting a resolver replaces a *constant* rather than a calibrated band, so
> nothing has to be shown to be worse than what it replaces. Every other context
> has to beat a model somebody tuned.

---

## 4. T1's own question, asked of the shipped model

Incoming speed spans **1.68 to 50.08 m/s** (p50 13.16) across 571 contacts, so
the input genuinely varies. This is not a flat predictor being asked to explain a
varying output.

### The dig — flat, and the correlation agrees

| incoming quartile | incoming p50 | outgoing p50 | vertical p50 |
|---|---:|---:|---:|
| Q1 | 4.449 | 7.217 | 7.203 |
| Q2 | 6.238 | 7.098 | 6.968 |
| Q3 | 7.813 | 7.081 | 6.908 |
| Q4 | **18.772** | **7.062** | 6.945 |

A four-fold change in the incoming ball moves the outgoing ball by 2%, in the
wrong direction. `r(incoming, vertical) = +0.0093`.

### The reception — a large correlation that is not a transfer relation

| incoming quartile | incoming p50 | outgoing p50 | vertical p50 |
|---|---:|---:|---:|
| Q1 | 9.671 | 8.297 | 7.478 |
| Q2 | 12.966 | 8.503 | 7.439 |
| Q3 | 13.605 | 8.775 | 7.364 |
| Q4 | 14.181 | 9.045 | 7.390 |

`r(incoming, outgoing speed) = +0.4290`, which looks like the relation existing
already. **It is not, and the decomposition is the whole point of measuring in
§6's units rather than in a single scalar:**

| | dig | reception |
|---|---:|---:|
| r(incoming, outgoing **speed**) | −0.0428 | **+0.4290** |
| r(incoming, outgoing **vertical**) | +0.0093 | **−0.1700** |
| r(incoming, **horizontal**) | −0.1642 | **+0.4928** |
| r(incoming, flight duration) | −0.0338 | −0.1861 |
| r(incoming, **pass distance**) | −0.1775 | **+0.5064** |

Outgoing speed is the hypotenuse of a vertical the apex band sets and a
horizontal that is `distance / duration`. The reception's +0.43 tracks **pass
distance** at +0.51: a harder serve is received further from the seat and the
ball has further to go. Nothing was retained; the ball was thrown further.

And the one component the contact model actually sets moves the **wrong way**:
`r(incoming, vertical) = −0.170`. That is the execution penalty — a harder serve
scores worse, worse execution lowers the apex band. It is a quality effect
wearing a physics correlation's clothes.

> **Read in the source, the answer is trivial once you look.** The dig's apex is
> `pass_contact_height + lerpf(1.35, 3.05, 1.0 − spoil)` and the reception's is
> `lerpf(PASS_APEX_RISE_MIN, PASS_APEX_RISE_MAX, execution)`. Neither expression
> contains the incoming trajectory. `incoming_speed_mps` is computed at both
> sites, published on both events, and read by **the recovery bands only**.

That is this repository's commonest defect, and §11 predicted it in the abstract:
a value computed correctly and dropped.

---

## 4a. And the launch angle, which nothing chooses — T2's version of the same question

T2 is "the reachable platform-angle range from body/contact circumstance", and it
is unauthored. The same question part 4 asked of T1: **what angle does the
shipped model produce?** It is not chosen anywhere. Rise comes from an apex band
and the destination from a target expression, and the two never see each other,
so the angle between them is a by-product.

| family | n | min° | p50° | max° | rise per metre travelled |
|---|---:|---:|---:|---:|---:|
| reception | 484 | 33.7 | **60.9** | 88.8 | 0.51 |
| dig | 87 | 65.2 | **83.3** | 89.2 | **2.48** |
| coverage | 24 | 74.3 | 74.3 | 74.3 | 1.86 |

The reception's 61° over 5.7 m is roughly what a pass looks like. **The dig's
83° is not a pass, it is a bucket** — 2.5 m of rise for 0.97 m of travel, because
the apex band gives it up to 3 m of height and the target expression gives it
0.97 m of court. Neither number is wrong on its own terms and together they are
not a volleyball contact.

### The two terms are not merely independent, they are inverted

| family | r(pass distance, apex rise) |
|---|---:|
| reception | **−0.3658** |
| dig | **−0.4848** |
| coverage | −0.0000 |

A ball thrown further needs more rise to arrive, so a physical model shows a
strong *positive* here. The engine shows a strong negative, and the mechanism is
plain once measured: both terms are driven by the same quality scalar in opposite
senses. A spoiled dig gets a *lower* apex (`lerpf(1.35, 3.05, 1.0 − spoil)`) and
a *larger* drift off its target, so it goes further and lower at once.

> **§13.9 lists these as two separate hidden preferences — item 2, the apex band,
> and item 3, the target offset — without noticing they contradict each other.**
> They are not two preferences. They are one missing relation, and the negative
> correlation is the shape of its absence.

---

## 4b. T1 gets its distribution — and its *form* was already shipped

§11 says slice 2 is "where T1 gets its distribution". Two things fell out of
looking for it, and the first was not expected.

**The form is not open.** `BlockDeflectionModel` is a shipped contact model in
this engine with exactly T1's shape:

```gdscript
const STUFF_PACE_KEPT: float = 0.72
const TOOL_PACE_KEPT: float = 0.60
const RECYCLE_PACE_KEPT: float = 0.12
const TOUCH_PACE_KEPT: float = 0.16
```

`outgoing = incoming × retention`, one fraction per contact kind, each with a
departure angle beside it — and its own comment records that the magnitudes were
rebased against a measured swing-pace band rather than picked. **So a platform T1
has a precedent to copy rather than a form to invent**, the same way M3's missing
shoulder anchor turned out to be `UNIVERSAL_RATIOS.shoulder_y` rather than a new
number.

**The distribution is what a proposal has to explain.** `outgoing / incoming`
across the shipped model — which does not compute it and therefore does not
control it:

| family / posture | n | min | p50 | max |
|---|---:|---:|---:|---:|
| reception | 484 | 0.508 | **0.656** | 1.530 |
| reception / planted | 72 | 0.582 | 0.655 | 1.266 |
| reception / reaching | 5 | 0.508 | 0.629 | 0.728 |
| dig | 87 | **0.139** | 0.974 | **4.228** |
| dig / planted | 50 | **0.139** | 0.974 | **4.228** |
| dig / reaching | 10 | 0.186 | 0.843 | 2.541 |

Read the min and max, not the median. A retention fraction is a *fraction*: the
block's four are single numbers between 0.12 and 0.72. **The dig's planted
posture spans a factor of thirty**, and **63 of 571 contacts return the ball
faster than it arrived**. A passer does add energy — a platform is not a wall —
but a *planted* dig returning 4.2× on a slow ball is not a passer driving through
it. It is a height band with no reference to the incoming ball, which is part 4's
finding restated in the units T1 would be authored in.

One datum worth handing forward rather than burying: **the reception's implied
retention is 0.656 at the median with a comparatively tight 0.51–1.53 spread**,
which sits between the block's tool (0.60) and stuff (0.72). That is not a
proposal and it is not a calibration — it is the one place in this measurement
where the present behaviour is already close to something a single fraction could
reproduce.

---

## 5. What this settles for slice 3, and what it does not

**Settles.** T1 is not a recalibration. There is no `outgoing = f(incoming, …)`
in the engine to be improved on, so slice 3 cannot be argued for or against by
comparing its transfer curve to the shipped one — there is nothing to compare
against. That removes a whole class of "is the new model better" argument and
replaces it with a harder, cleaner one: is the new model *plausible*, measured
against the sport.

**Settles.** Coverage should be promoted first among the platform contexts,
against `PLATFORM_CONTACT.md` §11's slice order which puts it fourth. Not
proposed as a change to that order here — the goal this pass runs under keeps the
slice order — but recorded, because the reason is measured: it is the only
context whose current ball is a display constant, so promotion there cannot
regress a tuned behaviour.

**Settles the form, not the magnitude.** §4b: `BlockDeflectionModel` already
ships T1's shape, so slice 3 does not have to invent a representation. What it
still has to author is four-to-six numbers — a retention fraction and a departure
angle per platform context — and choosing those by eye is exactly what §0
forbids. §11's own instruction stands: "if the shadow cannot discriminate a
plausible transfer relation from the existing bands, the honest outcome is to say
so and stop." What this pass adds is that there are no existing bands *in this
dimension* to discriminate against, and a measured range for the magnitudes to be
argued within.

**Does not settle.** T2's *shape* — the reachable platform-angle range. §4a
measures the angle the shipped model emits and finds it unbounded and, on the
dig, unphysical; it says nothing about what a body can actually do, which is what
T2 has to state. Nothing in this repository carries a shoulder range of motion,
and M3's `contact_offset_meters` gives where the platform is, not which way it
can face.

---

## 5a. §4b's other defect, now in metres

> **The controlled dig has no setting target at all.** All three sites aim at
> `contact + (0.03–0.04, −0.03 to −0.05)` — about 0.8 m from where the ball was
> dug. **The setter's position is never consulted.**

Slice 1 published the anchor and the intended recipient side by side, which is
what turns that paragraph into a number: the record names the setter and then
aims where the setter is not.

| purpose | n | min | **p50** | max | mean |
|---|---:|---:|---:|---:|---:|
| controlled dig | 277 | 0.126 | **4.054 m** | 8.982 | 3.872 |
| serve reception | 484 | 0.000 | **0.000 m** | 0.441 | 0.071 |

Metres from the published `target_anchor` to the release seat of the setter the
same record names as `intended_recipient_id`. The reception is the control — it
aims *at* the seat by construction, offset only by `_desired_pass_target`'s
overpass safety margin, so 0.000 / 0.441 is what an honest gap looks like.

**Four metres at the median, on a nine-metre court, up to nearly nine.** That is
the distance between what a controlled dig says it wants and where it throws the
ball, and it is now countable rather than anecdotal — which was §13.10's stated
reason for adding `anchor_source` in the first place.

Held as a universal rather than a rate: every controlled dig in a 60-seed sweep
aims within a stride of its own contact point. Demonstrated live by pointing one
dig site at the seat, which failed the check and moved the count 2,147 → 2,155.

---

## 6. Tests — six checks, and most are characterisation, not invariants

`_test_the_incoming_ball_reaches_no_platform_launch`. Two incoming flights over
the same line, one four times as fast as the other, through both resolvers; then
one dig target a stride away against one six metres away.

The fourth check holds §4a's finding at the **mechanism** rather than at the
correlation — a correlation is a sampling quantity and would make a brittle gate.
The apex expression does not read the target, so a dig thrown four times as far
leaves at exactly the same height, and that is the whole of the −0.485 stated
deterministically.

They hold a **gap** open rather than a behaviour correct, and they are labelled
that way in the source. When slice 3 promotes a real transfer relation they must
fail, and the diff that changes them is the promotion. Demonstrated by adding
`+ _incoming_ball_speed(incoming_trajectory) * 0.02` to both apex expressions:

```
TEST FAILED: a dig off a savage ball leaves at the same height as one off a gentle ball
TEST FAILED: and a reception's height is set by execution, never by the ball's pace
FAIL: 2 of 2149 checks failed
```

The count moving 2,145 → 2,149 under that edit is itself worth noting: a two-line
transfer term perturbed four sampling populations, which is what a real physical
change looks like and what the inert slice 1 pass deliberately was not.

The first check exists so the other two cannot pass on a degenerate fixture: it
asserts the two flights really do differ by nearly four times before asking
whether anything downstream noticed.

Suite: **2,147 checks, no failures.**

---

---

## 7. One repair taken on the way: the continuation dig's empty arrival

§4b traced a second defect and stopped at tracing it:

> **The continuation dig passes `arrival = {}`.** Empty, so `reach_margin`
> defaults to 0.0 and `stretched` computes `(0.25 − 0.0) / 0.85 = 0.294` — a 29%
> stretch fabricated on every continuation dig.

**Not a design question.** `cont_defense` carries the arrival and the two lines
above the call already read it. Measured first, over 600 rallies
(`tools/run_continuation_dig_arrival.gd`):

| | before | after |
|---|---:|---:|
| resolved continuation passes | 9 | 9 |
| published reach margin, min / p50 / max | −0.160 / 0.338 / 1.866 | unchanged |
| stretch that margin implies, p50 | **0.000** | — |
| stretch actually used | **0.294, constant** | the margin's |
| spoil, p50 | 0.400 | **0.341** |
| pass apex, p50 | 3.345 | **3.445** |
| destination error, p50 | 0.821 | **0.701** |

8 of the 9 were charged a stretch penalty for a ball they reached comfortably.
The direction is systematic — margins on this path are mostly *positive*, so a
constant 0.294 makes every one of them worse than it was.

**And the outcome mix over 600 rallies is unchanged**: 290 home points, 3,887
events, every terminal count equal. Nine contacts, none of which flipped a
rally. Stated plainly rather than dressed up: this repair is correct and its
consequence is small.

The suite is the one place it did register. It went from 2,146 to 2,146 while
**one check was added**, so a sampling gate drew one fewer — the signature of a
real behaviour change, and the opposite of slice 1's exactly-what-was-written.

### Why there is no caller-level gate

The check added here is an **invariant** — that `_dig_pass_result`'s arrival is
load-bearing, so passing `{}` costs something. The gate that would actually have
caught this defect has to run at the *call site*, and with nine samples in 600
rallies a sampling gate over that population would be noise. Recorded rather
than papered over with a weak test.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_platform_transfer_probe.gd
godot --headless --path . --script res://tools/run_continuation_dig_arrival.gd
```

Deterministic.
