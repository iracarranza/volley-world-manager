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

**Does not settle.** The shape of T1 itself. Knowing the channel is empty says
nothing about what belongs in it, and choosing an absorption curve by eye is
exactly what §0 forbids. §11's own instruction stands: "if the shadow cannot
discriminate a plausible transfer relation from the existing bands, the honest
outcome is to say so and stop." What this pass adds is that there are no existing
bands *in this dimension* to discriminate against.

**Does not settle.** T2, the reachable platform-angle range. This probe measures
speed and height, not angle, and the current model has no angle representation at
all — the destination is chosen and the drift is applied to it.

---

## 6. Tests — three checks, and they are characterisation, not invariants

`_test_the_incoming_ball_reaches_no_platform_launch`. Two incoming flights over
the same line, one four times as fast as the other, through both resolvers.

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

Suite: **2,145 checks, no failures.**

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_platform_transfer_probe.gd
```

Deterministic.
