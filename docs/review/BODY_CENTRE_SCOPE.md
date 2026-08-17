# M3 scoped: the gap is one `return`, and closing it needs one relation

Run: 2026-08-17, from `0788741`. Instruments:
`tools/run_body_centre_probe.gd`, `tools/run_platform_standoff_options.gd`.
**Measurement only — nothing changed in production.**

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

**So the decision is one number, and it is not the stand-off.** It is the
**shoulder anchor** — where the shoulder sits as a fraction of standing height.
With it, everything else is derived and nothing further is authored:

```text
arm_length = standing_reach - shoulder_height
drop       = shoulder_height - contact_height
offset     = sqrt(arm_length^2 - drop^2)
```

Every contact family then follows from the contact height it is already given,
and net encroachment is the same relation read toward the tape.

That ratio is the same kind of thing as the `1.215` and `0.32` already inside
`standing_reach_cm()` and the `0.43` inside `default_stride_length_m()` — a body
proportion with a stated basis, not a balance dial. It is the smallest decision
this milestone can be reduced to, and the tables above bound exactly what getting
it wrong is worth.

## 4. What was *not* found

- No defect in either reach model.
- No second model of one fact.
- No plumbing gap: the resolver's defensive path is internally consistent — it
  places the body on the ball and then asks a reach model whether the ball is
  reachable, which is redundant rather than contradictory.

Suite unchanged: **2,133 checks, no failures**. Nothing was changed.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_body_centre_probe.gd
```

Deterministic; no rally is resolved and no RNG is drawn.
