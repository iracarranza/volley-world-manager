# P7-C4 — Faces, Expressions and Cogniticons

Status: **VERIFIED**
Keywords: expression grid, combinatorial design, normalised coordinates, eye state, mouth shape, blink, envelope, pure function
Primary sources: `scripts/data/face_expressions.gd`; `scripts/data/cogniticon_motion.gd`; `tools/validate_voli_body_construction.gd`

## Prerequisites

- [P7-C1 The Voli Body](01_the_voli_body.md) — a face is built from the same primitives as the body
- [P2-C3 Collections, Types and Null](../part_02_gdscript/03_collections_types_and_null.md) — the grid is a nested `Dictionary`

## Learning goals

After this chapter you should be able to:

1. explain why a face is a **grid** rather than a list of authored expressions;
2. add an eye state and gain three faces without touching any other file;
3. read **head-normalised coordinates** and say why they exist;
4. state the contract every motion module in this codebase obeys;
5. name the difference between an expression and a cogniticon.

## Vocabulary

| Term | Meaning |
|---|---|
| **Expression** | A named face: `happy`, `devious`, `deadpan`… Derived, never authored. |
| **Eye state** | `full`, `half`, or `flat` — how open the eyes are, plus their tilt. |
| **Mouth shape** | `smile`, `flat`, or `frown` — a signed curve and a half-width. |
| **Grid** | The eye × mouth table that defines which expressions exist. |
| **Head-normalised** | Coordinates on `[-1, 1]` against the head's own semi-axes, so they work at any head size. |
| **Cogniticon** | A mark showing what a voli is *attending to*, distinct from how they feel. |
| **Envelope** | A motion curve expressed in real seconds, not as a fraction of a window. |

## 1. Why the face is solid, not painted

The obvious implementation is a drawn texture on a quad in front of the head:
cheaper, and finer control. It was rejected, and the reason generalises:

> "it would have read as a sticker. Every other feature on these bodies is a box
> or a sphere sitting in space, so a painted face would have been the only flat
> thing on an actor made of solids."

Small solids projected onto the head *curve with it and light with it*, "which is
what makes the face belong to the head rather than sit on it."

> **Principle.** Consistency of *construction* is a visual property. A single
> object made differently from everything around it reads as foreign even when
> each piece is individually well made.

## 2. The grid: nine faces from six numbers

This is the most transferable idea in Part 7.

```gdscript
const EYES := {
	"full": {"squash": 1.18, "tilt": 7.0},
	"half": {"squash": 0.66, "tilt": -20.0},
	"flat": {"squash": 0.26, "tilt": 0.0},
}

const MOUTHS := {
	"smile": {"curve": 1.00, "half_width": 0.34},
	"flat":  {"curve": 0.00, "half_width": 0.42},
	"frown": {"curve": -0.85, "half_width": 0.28},
}

const GRID := {
	"full": {"smile": "happy",   "flat": "neutral",    "frown": "worried"},
	"half": {"smile": "devious", "flat": "suspicious", "frown": "cross"},
	"flat": {"smile": "relaxed", "flat": "deadpan",    "frown": "tired"},
}
```

**Nothing is authored per expression.** A face is a *pair*, and the name is a
lookup. `GRID` is "the single source of truth for which expressions exist.
Adding a row or a column adds faces without touching anything else."

### 2.1 The failure this replaced, and why it matters

The first version worked the other way round: five named faces, each with
hand-picked numbers. It produced a `happy` that everybody read as **devious** —

> "because a smile under narrowed eyes is a scheme rather than a delight."

The fix was to stop naming the *intent* and start naming the *combination*:

> "With the name derived from the parts that cannot happen: narrowed eyes plus a
> smile *is* devious, and it is called that because of what it is made of rather
> than what it was meant to be."

> **The lesson.** When authored labels keep disagreeing with what people see,
> the labels are the problem. Derive the name from the parts and the
> disagreement becomes impossible by construction.

### 2.2 The arithmetic of adding a row

Three eyes × three mouths = nine faces from six authored entries. Add a fourth
eye state — say `wide` — and you get **three more faces for one entry**, and you
have to name them, but you do not have to draw them.

> **Check.** Which existing expression would `flat` eyes plus a `smile` be if the
> grid did not name it `relaxed`? Nothing — an unnamed cell is not a face. The
> grid is exhaustive by construction, which is exactly why it is the source of
> truth.

### 2.3 `components()` and `label()` are inverses

```gdscript
static func components(expression: String) -> Array[String]
static func label(eye_state: String, mouth_shape: String) -> String
```

One maps a name to its pair, the other a pair to its name. Keeping both means no
caller has to know the grid's shape.

## 3. Head-normalised coordinates

```gdscript
const EYE_U: float = 0.40
const EYE_V: float = 0.19
const MOUTH_V: float = -0.34
```

> "Where the features sit, in head-normalised coordinates: u across, v up, both
> on `[-1, 1]` against the head's own semi-axes. Authored this way so one set of
> numbers serves a 0.105-radius Stalk head and a 0.185-radius Feli head without
> a per-type table."

That is a **76% size difference** absorbed by one convention. The alternative —
a table of pixel offsets per body type — would need six rows, would need a
seventh the day a body is added, and would drift.

> **Transferable rule.** If a number would need one value per type, check whether
> it can be expressed as a fraction of something the type already has.

### 3.1 Worked example: placing a feature

To add a nose 40% of the way up from centre and slightly left:

```gdscript
const NOSE_U: float = -0.12
const NOSE_V: float = 0.40
```

Those two constants are correct for every head in the game, present and future.
Had you written `Vector3(-0.013, 0.042, ...)` you would have written them for
exactly one.

## 4. The flat mouth is the widest, on purpose

```gdscript
"flat":  {"curve": 0.00, "half_width": 0.42},
```

Wider than both the smile (`0.34`) and the frown (`0.28`).

> "A straight line drawn right across the face is not a milder smile or a milder
> frown — it is its own reading, and the width is what stops it looking like a
> curve that failed."

A neutral state must be **positively** constructed. If you build it by setting a
parameter to zero and changing nothing else, it will read as a failed version of
its neighbours rather than as itself. Compare `Landavol`'s `"reference"` kit in
[P7-C2](02_kits_colour_and_marks.md) — the same principle, in a different medium.

## 5. What a face is *not* allowed to mean

A scoping rule sits in the source and it is easy to violate:

> "These are perceptive or emotional surface states layered over action poses,
> **not volleyball-quality labels.** Neutral/concerned/focused-looking
> combinations may accompany preparation, contact, or recovery without implying a
> clean, strained, successful, or failed action."

So a `worried` face must not mean the pass was bad. Expression is a *surface
state*; quality lives in the simulation. Wiring a face to a rally outcome would
make the face a readout, and a readout is not a character.

## 6. Cogniticons, and the motion contract

Cogniticons are separate: they show what a voli is *attending to* rather than
how they feel. `scripts/data/cogniticon_motion.gd` owns their movement, and its
header states a contract every motion module here follows:

> "Nothing here touches a node, holds state, or reads a frame delta — same shape
> as `SpikeBiomechanics`, `BlockBiomechanics` and `GaitBiomechanics`."

Three reasons are given, and all three are worth knowing:

1. `match_screen.gd` carries a `playback_speed` from **0.1 to 4.0**, and
   animation driven by frame deltas would run at the wrong rate on a slow replay;
2. the bodies are already phase-driven, so "a second clock beside them is a
   second clock to disagree with them";
3. **a pure function can be gated headlessly**, which is how every other claim in
   this repository is checked.

### 6.1 Envelopes are in seconds, and that was measured

The obvious design is to run each envelope across its window as a 0-to-1
progress. A probe over 936 windows across 180 rallies says that breaks: the
attack window's median is **a third of a second** and its tenth percentile is
**three hundredths**. A window-relative animation would play out in two frames
on a fast swing and stretch over a second and a half on a roll shot.

> "A body's motion is its own duration; so is a mark's."

So every envelope is in real seconds, clamped, and allowed to keep running past
the end of its window.

### 6.2 The blink

The module contains a complete idle-liveness model, described as "the whole of
what makes an idle mark feel alive": fast down and slower up, "which is what a
real blink is and what separates it from" a symmetric fade — and desynchronised
per voli, so "no two volis blink together."

> **Worth knowing:** this machinery currently serves the 2D marks. The 3D face
> has no idle layer — `block_phase_model.gd` notes that "the blocker has no idle
> pose." If you add one, copy this module's contract rather than inventing a
> second clock.

## 7. Common mistakes

**Authoring an expression directly.** Add a row or a column to `GRID`; do not add
a tenth face with its own numbers. That is the design the current one replaced.

**Positioning a feature in metres.** Use head-normalised `u`/`v` or your feature
will be right on one body and wrong on five.

**Building a neutral by zeroing a parameter.** It will read as a failed curve.
Give it its own positive construction.

**Driving motion from a frame delta.** It desynchronises at any playback speed
other than 1.0 and cannot be gated headlessly.

**Indexing face parts positionally.** `parts()` returns eyes, pupils and mouth;
when pupils were added, every positional assertion silently retargeted and a
mouth check began testing an eye. Key by name.

## 8. Check yourself

1. You add an eye state `wide`. How many new faces, and how many new numbers? *(Three faces; one entry in `EYES` plus three names in `GRID`.)*
2. Why is `devious` not authored? *(It is what narrowed eyes plus a smile already is; naming it separately is how the old system produced a "happy" that read as a scheme.)*
3. A feature sits correctly on a Feli and floats off a Stalk. What went wrong? *(Absolute coordinates instead of head-normalised.)*
4. Why can't a face mean "the pass was bad"? *(Expressions are surface states; quality labels belong to the simulation.)*
5. Why are envelopes in seconds? *(Window durations vary from 0.03 s to 1.5 s; a window-relative curve would play in two frames or stretch over a second and a half.)*

## Where this leads

- [P7-C5 Rendering, Probes and Validation](05_rendering_probes_and_validation.md) — how face assertions are checked
- [`COGNITICONS.md`](../../design/COGNITICONS.md) — what a voli is showing, in full
- [`THE_VOLI_BODY.md`](../../design/THE_VOLI_BODY.md) — how a voli stands and dresses
