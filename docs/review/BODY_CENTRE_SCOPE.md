# M3: the gap is one `return`, and the missing relation was already in the repository

Run: 2026-08-17, from `0788741`. Instruments:
`tools/run_body_centre_probe.gd`, `tools/run_platform_standoff_options.gd`.
**Measured, then derived. One production addition, and it invents nothing.**

M3's exit condition: *"A voli's body location is distinct from the point where
hands/platform contact the ball. Reach, wingspan, body type and net encroachment
use one physical geometry instead of placing the sternum on the ball."*

---

## 1. The sternum is on the ball, and it is one line

`_reached_point` is where every defensive journey ends and what it returns is the
body's new position. Driven with ample time across a range of trips:

| trip | time | body-to-ball | on the ball? |
|---:|---:|---:|---|
| 0.40 m | 3.00 s | **0.0000 m** | YES |
| 1.00 m | 3.00 s | **0.0000 m** | YES |
| 2.00 m | 3.00 s | **0.0000 m** | YES |
| 3.00 m | 3.00 s | **0.0000 m** | YES |
| 4.50 m | 3.00 s | **0.0000 m** | YES |

Five of five, zero to four decimal places. `_reached_point` returns `target`
unchanged whenever the movement fits the time and the read carried no shortfall:

```gdscript
if _movement_time(mover, start, target, mode) <= available_time:
    if shortfall_meters <= 0.0:
        return target
```

The shortfall term is real and does displace the body — but it models a **wrong
read**, not the geometry of standing beside a ball in order to play it. A
defender who read the ball correctly stands on it.

---

## 2. What already exists, so the milestone is not told to build it

**`_base_reach_meters`** — the claimant's reachability tolerance, and build is
already in it:

| wingspan | ball_control | reception | dig |
|---:|---:|---:|---:|
| 175 cm | 30 | 1.0725 m | 0.9925 m |
| 175 cm | 70 | 1.1725 m | 1.0925 m |
| 220 cm | 30 | 1.1670 m | 1.0870 m |
| 220 cm | 70 | 1.2670 m | 1.1870 m |

Wingspan, control and the libero's role bonus all reach it. **But it is a
tolerance, not a stand-off**: it decides whether a ball is reachable from where
the body is; it does not decide where the body goes.

**`ContactEnvelopeSystem._horizontal_reach`** — 0.2708 m (RECOVERING) to 0.4859 m
(DIVING), varying with posture, balance and technique.

### A finding I nearly published, and the doc that stopped it

Those two figures both read as "how far can this body reach horizontally" and
differ by about **three times** — which looks exactly like two models of one
physical fact, the shape this repository keeps catching.

It is not. `PLATFORM_CONTACT.md` §13.11 already rules on it:

> **`ContactEnvelopeSystem` is not the feasible-launch envelope.** Its name is
> the one this design wants and its content is a different question — it answers
> "can this body reach that contact point", which belongs to the *body state*
> stage… Its own header says it is "game-balance mappings, not claims of
> biomechanical measurement."

So they answer different questions at different stages and are not claimed to
agree. Recorded because "two models of one fact" was a satisfying finding, it was
wrong, and only the governing design document said so.

---

## 3. What closing M3 needs, and why it is not buildable yet

The gap is narrow and precisely located. What it needs is not narrow:

**Where does a body stand relative to a ball it intends to play?**

That is a different geometry per contact family, and none of them is in this
engine:

- a **platform pass** is taken in front of the body and below the waist, so the
  body stands *behind and under* the ball's line;
- an **overhead set** is taken above the forehead, so the body stands almost
  beneath it;
- a **dig** may be taken anywhere the arms reach, in any posture, so there is
  barely a stand-off at all;
- **net encroachment** — the milestone's fourth clause — is the same relation
  read from the other side: how close a body may stand to the tape given where
  its contact point is.

`PLATFORM_CONTACT.md` §4 *describes* the first of these — "a ball met at the
waist in front of the body can be angled almost anywhere" — but authors no
distance. There is no measurement in the repository to draw one from, and
choosing one by eye is the failure `FAILURE_MODES.md` §0 exists to prevent. It
would also not be a small error: at the ~1.1 m scale `_base_reach_meters` already
operates on, a stand-off chosen half a metre wrong changes who can reach what
across the whole floor defence.

### The smallest decision — reduced to one number, by trying it

Two sourcing options were named at first, and naming is not measuring. Measured
(`tools/run_platform_standoff_options.gd`, six generated rosters):

| candidate basis | min | p50 | max | share of reach |
|---|---:|---:|---:|---:|
| overhead extension × 1.00 | 0.381 | 0.450 | 0.506 | 36.7% |
| overhead extension × 0.75 | 0.286 | 0.337 | 0.379 | 27.5% |
| overhead extension × 0.50 | 0.190 | 0.225 | 0.253 | 18.3% |
| overhead extension × 0.35 | 0.133 | 0.157 | 0.177 | 12.8% |
| *wingspan / 2 (upper bound, a dive)* | 0.882 | 1.019 | 1.124 | — |

against `_base_reach_meters` at p50 **1.227 m**. So the entire plausible range of
answers spans about **0.29 m against a 1.23 m tolerance** — a body placement,
not a rebalance of the floor defence, and a smaller error than the shortfall term
already applies for a misread.

**A third form appeared to need no ratio at all, and was implemented to find
out.** The arms are a segment of known length anchored at the shoulder; a ball
met at a known height fixes the angle; the offset is Pythagoras:

```gdscript
var reach_span := (standing_reach_cm() - height_cm) / 100.0
var shoulder := height_cm / 100.0 - reach_span
var drop := shoulder - contact_height_meters
return sqrt(reach_span * reach_span - drop * drop)
```

Measured, it returns **0.000 m across the entire platform range** — 0.30 m,
0.60 m and 0.90 m all zero. `standing_reach − height` is **not arm length**. It
is the 0.450 m the arms add *above the head*, and a 0.45 m segment anchored at a
1.47 m shoulder cannot reach a ball at the waist at all. The function was removed
rather than shipped: a value that is zero exactly where it matters is the knob
that cannot reach its own range, built rather than inherited.

**So the decision was one number, and it is not the stand-off.** It is the
**shoulder anchor** — where the shoulder sits as a fraction of standing height.

### And the repository already commits to one

`BodyTypeModels.UNIVERSAL_RATIOS`, in `scripts/data/`, is the shared figure every
body type is a *pull away from* rather than a replacement for. It carries
`shoulder_y: 0.815` and `hand_y: 0.395`, authored once with the basis recorded in
its own comment:

> *Feli's shoulders sat at 0.745 of its height and Avi's at 0.750, against
> roughly **0.82 on a human**, while both hung arms long enough to put the hands
> at 0.30–0.32 where a person's fingertips reach about 0.38.*

I had said there was no source in the repository to cite. There was; I had not
looked in the body data. Reading it here rather than authoring a second one is
also what M3's exit condition literally asks for — **one physical geometry**, so
the simulation and the drawn body are the same body.

### The derivation, and the cross-check that validates it

```gdscript
func shoulder_height_meters() -> float:      # BodyTypeModels.UNIVERSAL_RATIOS
func arm_length_meters() -> float:           # standing_reach - shoulder
func contact_offset_meters(height) -> float: # sqrt(arm^2 - drop^2)
```

Arm length is derived from *this voli's* `standing_reach_cm()`, which already
carries their own wingspan, so a long-armed voli gets a long arm. The shared
figure is then the **check** rather than the source — and the two independent
routes agree:

| route | min | p50 | max |
|---|---:|---:|---:|
| `standing_reach − shoulder` (this voli's wingspan) | 0.703 | **0.802** | 0.882 |
| `(shoulder_y − hand_y) × height` (shared figure) | 0.729 | **0.807** | 0.881 |
| median disagreement | | **0.005 m** | |

Five millimetres. Two independently authored parts of the repository — the
`1.215`/`0.32` inside `standing_reach_cm()` and the `0.815`/`0.395` inside
`UNIVERSAL_RATIOS` — describing the same skeleton and agreeing about it. That is
what says the anchor is being read correctly rather than merely being read.

### What it produces

| contact height | min | p50 | max | share of reach |
|---|---:|---:|---:|---:|
| 0.30 m — shin, off the floor | 0.000 | **0.000** | 0.000 | 0% |
| 0.60 m — knee, a low dig | 0.000 | **0.000** | 0.000 | 0% |
| 0.90 m — thigh, a driven ball | 0.297 | **0.449** | 0.515 | 36.6% |
| 1.10 m — waist, the platform pass | 0.607 | **0.642** | 0.689 | 52.3% |
| 1.40 m — chest, a high float | 0.703 | **0.786** | 0.844 | 64.1% |
| 1.80 m — overhead, not a platform | 0.000 | **0.000** | 0.000 | 0% |

**Zero above the shoulder** — an overhead contact is taken above the body, not in
front of it. **Zero at the floor** — a ball further below the shoulder than the
arm is long is not reached in front of a standing body at all; it is reached by
leaving the feet, which is a posture question the contact envelope already owns.
Neither boundary was placed. Both are what the geometry does.

**Nothing is authored in this function**: not a ratio, not a distance, not a
band. Every term was already in the repository and the two that describe the same
skeleton agree to five millimetres.

## 4. What was *not* found

- No defect in either reach model.
- No second model of one fact.
- No plumbing gap: the resolver's defensive path is internally consistent — it
  places the body on the ball and then asks a reach model whether the ball is
  reachable, which is redundant rather than contradictory.

## 5. Promotion attempted, and reverted on measurement

`_reached_point` now takes `contact_height_meters` and `incoming_direction`, and
`_body_behind_contact` places the body behind the ball along its own line of
travel — a passer gets behind the ball and plays it in front of their platform.
Both default to nothing, so an un-migrated caller keeps exactly its old arrival,
the same shape `entry_facing` used before every caller was migrated.

**Then it was wired at the reception, measured, and unwired.** The outcome mix
came back byte-identical, which prompted the question that mattered: is the
stand-off firing at all? It was — 0.575 m for a reference voli — but on an input
that is not real.

**The serve's arrival height is the 1.0 m default on all 120 serves sampled**, to
three decimal places, because `_ball_trajectory` is passed `NAN` for `end_height`
at the serve. That default is not an oversight anyone needs to discover; the
parameter's own comment already names it:

> `BallTrajectory.create` has taken these since it was written and no caller ever
> passed them, so every published trajectory in the game carried the 1.0 m
> defaults… on seed 20010's dig the record answered 1.000 m at the far end where
> the ball really arrives at 2.190 — **a metre and a fifth of fiction**, in the
> exact methods a future interception resolver has to trust.

Placing a body against that would have been a physical geometry built on a
placeholder — the failure mode this repository exists to catch, committed rather
than caught. The wiring was removed and the reason written at the call site.

## 6. The next dependency, and it is a bug rather than a decision

**Publish the serve's real arrival height.** `height_source` already records
which trajectories know theirs and which took the default, so the gap is
countable today. Once a reception's flight carries a true `end_height_meters`,
the two arguments are already there, the relation is already derived and tested,
and the promotion is one line at the call site plus a certified before/after.

Two further consequences follow from the same input and are named rather than
built:

- **Posture.** The shoulder anchor here is the *standing* one. A passer squats,
  which lowers it — and `UNIVERSAL_RATIOS` carries `hip_y` 0.545 as the other end
  of that travel. Whether the stand-off should read a posture-adjusted shoulder
  is a real question, and `body_state` now survives the leg boundary
  (`ACTOR_CONTINUITY.md`) so the input for it exists.
- **Net encroachment**, the milestone's fourth clause, is the same relation read
  toward the tape and needs nothing further once a contact height is real.

Suite: **2,136 checks, no failures** — 2,133 plus exactly the three written for
the derivation.
