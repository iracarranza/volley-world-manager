# M3 scoped: the gap is one `return`, and closing it needs one relation

Run: 2026-08-17, from `0788741`. Instrument:
`tools/run_body_centre_probe.gd`. **Measurement only — nothing changed.**

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

### The smallest decision

**One relation, for the platform family first:** how far in front of the body
centre the platform contact point sits, as a function of what already exists
(`wingspan_cm`, `standing_reach_cm`, posture). Everything else in M3 — the set,
the dig, net encroachment — follows the same shape once one family is authored
and can copy its structure rather than re-deciding it.

Two ways to source it that do not involve taste:

1. **Derive it from the body model.** `VolleyballPlayer` already carries
   `wingspan_cm` and `standing_reach_cm`; a platform contact in front of the
   waist is a fixed fraction of arm length, and arm length is derivable from
   wingspan. This introduces one ratio rather than one distance, and the ratio is
   anatomical rather than tactical.
2. **Author it from reference**, the way `BALL_LAUNCH_KINEMATICS.md` and the
   locomotion bands were authored — a measured figure with the source recorded.

Option 1 needs one number that is a body proportion; option 2 needs a source.
Neither is a balance dial, and both are smaller than the milestone's text
suggests. **This is the boundary, and it is a required unmeasured physical
relation rather than an implementation question.**

---

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
