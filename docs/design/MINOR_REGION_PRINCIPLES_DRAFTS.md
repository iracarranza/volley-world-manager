# Minor region principles — drafts, not a decision

Written 2026-08-16, on `6b1f316`. **Nothing here is applied.** `BACKLOG.md` §3a
names this as a design question that was never decided rather than decided and
unbuilt, and the decision is the user's. This document does the work that has to
happen before the decision can be made well: what the seven axes actually do,
what the existing tables already commit each region to, and three drafts of
different ambition with their costs stated.

One thing in §3a is *not* a design question, and it is separated out in §1.

---

## 1. The label is wrong today, whichever way the design goes

```gdscript
static func preferred_principles(region_name: String) -> TeamPrinciples:
    var resolved_name := canonical_name(region_name)
    return TeamPrinciplesModel.custom(
        "%s Tradition" % resolved_name,
        Dictionary(REGIONAL_PRINCIPLES.get(
            resolved_name, REGIONAL_PRINCIPLES.Landavol
        )),
    )
```

A Kutré Lyn club is handed a principle set named **Kutrén Tradition** whose seven
numbers are byte-identical to Landavol's. The name asserts a tradition the numbers
do not contain.

This is `FAILURE_MODES.md` §0 in an unusual place — not a threshold outside its
range, but a *label* outside the content's range — and it is the reason the
project cannot currently tell "this region plays balanced volleyball" from "this
region has no entry". Six regions are in the second state and are displayed as the
first.

**The fix is independent of every draft below**: when the lookup misses, say so.
`"Reference Set"`, or `"%s (no tradition on record)"`, or whatever reads right on
the clipboard. It costs one branch and it makes the six drafts below *visible* as
a gap rather than invisible as a duplicate.

Draft A is that fix and nothing else.

---

## 2. What the seven axes actually do

No draft can be judged without this, and it was not written down anywhere. Every
row was read out of `rally_simulator.gd` rather than inferred from the name.

| axis | where it is read | what it does |
|---|---|---|
| `decisiveness` | `_identity_tempo_shift`, attack selection | 0.55 of the *commitment* blend that pulls the called tempo quicker or slower |
| `pin_focus` | `_select_hitter` | lane weight, `lerp(0.35, 1.65)` toward pins and the inverse toward the front quick. Exactly 0.5 skips the whole branch |
| `tempo_variation` | `_identity_tempo_shift`, set strictness | the **rate** at which a side rotates tempo, in a direction the pass does not predict. Past 0.5 it buys a second step |
| `emotional_expression` | `identity_effects.confidence_volatility` | `1.0 + (x − 0.5) × 0.6` on confidence swing |
| `serve_aggression` | serve risk, both sides | `+ (x − 0.5) × 0.70` on serve risk, and a smaller term on pace |
| `transition_commitment` | `_identity_tempo_shift` | 0.45 of the commitment blend |
| `block_commitment` | blocker commitment, both sides | how readily a blocker commits to the shot rather than staying home |

### The one thing this table settles

**"Always first tempo" is expressible, and I was wrong to think it wasn't.**

`tempo_variation` is a rotation *rate*, not a tempo *level*, so a region whose
whole identity is "we play quick" appears to have no axis to say it on. It has
one, in the pair:

```gdscript
## Lower tempo is quicker: 0 is the first-tempo ball, 3 the high one.
var commitment := lerpf(decisiveness, transition_commitment, 0.45)
...
if commitment >= 0.66: tempo_shift -= 1
```

High commitment pulls the tempo *quicker*. So **low variation with high
commitment is "always quick"; high variation is "unreadable"** — two different
identities, both sayable. Rhėn Tempaol is the first and Spëddigh is the second,
and the vocabulary separates them.

This paragraph exists because the opposite claim was drafted first and would have
turned into a proposal for an eighth axis. Checking what the function does before
writing about the axis is the whole of §0.

---

## 3. Can the numbers be derived rather than authored?

The house rule is that numbers come from models. So before authoring forty-two
numbers, the honest question is whether the eight *existing* sets can be predicted
from the tables the same regions already carry — `REGION_POSITION_AFFINITY`,
`REGION_SPECIALTY`, `REGIONAL_CURVES`, the body biases. A rule that reproduces the
majors has earned the right to author the minors. One that doesn't is a dial with
extra steps.

Two axes have a real signal. Three have none.

### `pin_focus` against pin mass — perfect rank agreement, n=5

Pin mass is `OH + OP` position affinity. Only five majors carry an affinity entry.

| region | OH + OP | MB | `pin_focus` |
|---|---:|---:|---:|
| Blôc du Larg | 1.8 | 1.3 | 0.32 |
| Taktikã | 1.8 | 0.8 | 0.40 |
| Spëddigh | 1.8 | 0.8 | 0.42 |
| Xérvu | 2.4 | 0.9 | 0.50 |
| Pāwa Hitō | 2.5 | 1.3 | 0.70 |

The three tied at 1.8 hold the three lowest `pin_focus` values; 2.4 and 2.5 hold
the two highest. **Rank agreement is exact.**

And a caution that is the reason to write this section at all: the *share*
`(OH+OP) / (OH+OP+MB)` — the more natural-looking statistic — inverts Blôc du
Larg and Taktikã and destroys the agreement. Same data, one instrument works and
one doesn't. §0, one more time.

### `block_commitment` against middle mass — one inversion, and it is explicable

| region | MB | height bias | block attr in specialty | `block_commitment` |
|---|---:|---:|---|---:|
| Xérvu | 0.9 | — | no | 0.45 |
| Spëddigh | 0.8 | — | no | 0.52 |
| Taktikã | 0.8 | — | no | 0.52 |
| Pāwa Hitō | 1.3 | + | no | 0.58 |
| Blôc du Larg | 1.3 | + | `block_timing` | 0.72 |

Monotone in MB mass except Xérvu, which sits below two regions with *less* middle
mass than it. The explanation is available: Xérvu spends its identity on the
serve, and a side that wins the first ball has less use for the wall. That is a
real reason, but it is a reason a human supplied after seeing the number, which is
what over-fitting sounds like from the inside. Call it *directional, not
predictive*.

### `transition_commitment` against endurance and transit attributes

Pāwa Hitō (`stamina`, `transition_speed`, `explosiveness`) is 0.94, the highest in
the world. Spëddigh (`work_rate`, `acceleration`, `lateral_speed`) is 0.78, second.
Blôc du Larg — block, reception, dig, nothing that runs — is 0.35, the lowest.
The ordering follows the specialty lists cleanly.

### `serve_aggression` — one data point, but a decisive one

Xérvu holds all six serve attributes and 0.92. No other region holds a serve
attribute and no other region exceeds 0.72. **No minor region holds one either**,
so the derivation's answer for all six minors is "near reference", and that is a
real derived answer rather than a shrug.

### `decisiveness`, `tempo_variation`, `emotional_expression` — nothing

- `decisiveness` has no candidate signal. Taktikã holds `decision_making` and sits
  at 0.48, below Spëddigh, which holds none.
- `tempo_variation`: Spëddigh holds `tempo_control` and is 0.90, the highest — but
  Xérvu holds no tempo attribute and is 0.72, second. One point for, one against.
- `emotional_expression` has **no modelled input anywhere in the project**. It is
  the temperament axis and it is authored by definition.

### Verdict on derivation

**Two axes of seven derive; one is directional; four are authorship.** A rule
fitted on n=5 that reproduces the majors on two columns has not earned forty-two
numbers, and pretending otherwise would be exactly the failure this repository
documents. What the derivation *has* earned is the **ordering** — where each minor
sits relative to the others and to the majors on `pin_focus`,
`block_commitment` and `transition_commitment`. The drafts below use it for that
and say plainly where a number is invented.

---

## 4. Zaitgaist is not one of the six

It should never get a table entry, under any draft.

Its specialty comes from `region_overlay`, rewritten each season by
`SixnetLeague.apply_influence_drift()` to mirror whoever last won. Tradition
resistance is **0.0**. Position affinity is flat *on purpose*. The region's entire
identity is that it has no identity of its own and wears the current one.

So its principles should be **the reigning Sixnet champion's principles**, looked
up rather than stored, falling back to the reference set before a champion exists.
That is a five-line change in `preferred_principles`, it is consistent with
everything else already built for the region, and **seven hardcoded numbers for
Zaitgaist would be the defect** — a permanent tradition for the region defined by
not having one.

This is the only part of §3a with an answer that does not need a design call. It
is separable from all three drafts and could ship on its own.

---

## 5. Draft A — silence, honestly labelled

Keep the balanced fallback. Fix the label. Add a line to the tooltip or the
clipboard that says the region has no coached tradition on record.

**Claim:** a small programme raises volis with a specialty and does not have a
distinctive team system. That is a true thing about sport, and §3a already
establishes that the minor taglines are honest without it — every one describes
what its *volis* are like, not how the side is coached. Generation carries the
tier's identity; tactics do not.

**Cost:** one branch. No suite risk beyond the label.

**What it gives up:** `REGIONAL_IDENTITY_OVER_A_MATCH.md` asks everywhere else
that a region with a named tradition play like it. Six of fourteen regions opt
out.

---

## 6. Draft B — seven numbers per region

Ordering from §3 where §3 has one; invention where it doesn't, marked **[A]**.

Read the tables as a proposal to argue with, not as a result.

### Tãul ys Feynt — deception
`feinting`, `tooling`, `finesse` · pin mass 2.6, MB 0.4 · height −3.0 · read 1.20

| axis | value | why |
|---|---:|---|
| decisiveness | 0.34 | the tip is the patient option; you wait for the blocker to leave the ground |
| pin_focus | 0.72 | pin mass 2.6, second highest in the world; MB 0.4 |
| tempo_variation | 0.74 | deception made structural — but no `tempo_control`, so under Spëddigh |
| emotional_expression | 0.30 | **[A]** village halls, wrists not roars |
| serve_aggression | 0.38 | no serve attribute, and a side that wins the long point does not give it away on the first ball |
| transition_commitment | 0.40 | nothing that runs |
| block_commitment | 0.28 | MB 0.4, height −3.0 |

### Lo-ong Ralī — endurance defence
`stamina`, `dig_control`, `anticipation` · pin mass 1.7, MB 0.3, L 2.4 · height −5.0 · fatigue 0.50, the flattest curve in the world

| axis | value | why |
|---|---:|---|
| decisiveness | 0.30 | they do not need to end it now, and that is the whole region |
| pin_focus | 0.44 | pin mass 1.7 is below every major — but MB 0.3 means the middle is not the alternative |
| tempo_variation | 0.42 | **[A]** |
| emotional_expression | 0.44 | **[A]** |
| serve_aggression | **0.26** | the lowest in the world. A side that wins by outlasting does not hand over points, and it sits consistently below Blôc's 0.30 |
| transition_commitment | 0.66 | `stamina`; see the open question below |
| block_commitment | **0.22** | MB 0.3 and height −5.0. They chose the floor over the net |

**Open question, flagged rather than resolved:** `transition_commitment` is the
one number here I would not defend hard. `stamina` argues high — legs that allow
you to run the transition every time. The defensive identity argues low — a side
that stays home to cover. The sim reads it as tempo pull, so 0.66 says "they play
quick", and an endurance defence probably does not. **0.44 is the alternative and
may be the better answer.**

### Bompaçao — the platform
`reception`, `reception_balance`, `ball_control` · pin mass 2.1, MB 0.4, L 2.2 · height −2.0

| axis | value | why |
|---|---:|---|
| decisiveness | 0.46 | **[A]** |
| pin_focus | 0.58 | pin mass 2.1, mid |
| tempo_variation | 0.50 | reference, and *earned*: a perfect pass makes every tempo available, and they hold no attribute that rotates between them |
| emotional_expression | 0.66 | **[A]** barrio courts, loud |
| serve_aggression | 0.44 | no serve attribute |
| transition_commitment | 0.58 | the first contact is what makes a transition swing possible at all |
| block_commitment | 0.30 | MB 0.4 |

### Rhėn Tempaol — first tempo
`approach_timing`, `arm_speed`, `transition_speed` · pin mass 1.4 (lowest), MB 1.6, S 2.0 · height −1.0

| axis | value | why |
|---|---:|---|
| decisiveness | 0.82 | with the row below, this is the pair the sim reads as *quick* |
| pin_focus | **0.24** | the lowest in the world, below Blôc's 0.32. MB 1.6, OP 0.5 |
| tempo_variation | **0.26** | they do not vary. One tempo, and it is the first one |
| emotional_expression | 0.40 | **[A]** |
| serve_aggression | 0.42 | no serve attribute |
| transition_commitment | 0.88 | `transition_speed`; second to Pāwa's 0.94, and second is right — Pāwa is a battery, this is a sprint |
| block_commitment | 0.62 | the only middle-heavy minor, MB 1.6 — but height −1.0 keeps it under Blôc's 0.72 |

**This is the region the draft is really for.** Low variation plus high commitment
is a sentence the simulator can already say and no region currently says.

### Kutré Lyn — placement
`attack_accuracy`, `shot_variety`, `court_vision` · pin mass 2.8 (highest), MB 0.5 · height 0.0

| axis | value | why |
|---|---:|---|
| decisiveness | 0.58 | **[A]** |
| pin_focus | 0.78 | the highest pin mass in the world; only Ĭspayk's 0.88 above it |
| tempo_variation | 0.68 | `shot_variety` is variation at the contact rather than in the call — high, not top |
| emotional_expression | **0.24** | **[A]** "a hard swing is an admission of failure" is a temperament before it is a technique |
| serve_aggression | 0.48 | Xérvu's neighbour, and does not own the serve |
| transition_commitment | 0.52 | **[A]** |
| block_commitment | 0.34 | MB 0.5 |

### Zaitgaist
No entry. See §4.

### What Draft B costs

Twenty-nine authored numbers (seven × five minus Zaitgaist's row minus the six
that §3 orders). Fourteen carry **[A]** — pure authorship. Every one of them is a
lever on live rally behaviour, and none is covered by a gate today, so the honest
statement is that Draft B ships fourteen unmeasured constants into the simulation.
That is the exact population `audit_unmeasured_constants.py` counts.

**If Draft B is chosen, it should ship with the measurement**: a probe that plays
each minor region against Landavol and reports the tempo distribution, pin share,
serve error rate and block commitment rate, so that the numbers can be checked
against the behaviour they were written to produce. That is the difference between
authoring a model and authoring a table.

---

## 7. Draft C — only the axes the tables already force

The middle position, and the one most in keeping with how this project has handled
every other "we don't know yet" — build what is entailed, leave the rest at
reference, and say which is which.

Author only `pin_focus`, `block_commitment` and `transition_commitment` — the
three §3 gives an ordering for. Leave `decisiveness`, `tempo_variation`,
`serve_aggression` and `emotional_expression` at Landavol's 0.50.

| region | pin_focus | block_commitment | transition_commitment |
|---|---:|---:|---:|
| Tãul ys Feynt | 0.72 | 0.28 | 0.40 |
| Lo-ong Ralī | 0.44 | 0.22 | 0.44 |
| Bompaçao | 0.58 | 0.30 | 0.58 |
| Rhėn Tempaol | 0.24 | 0.62 | 0.88 |
| Kutré Lyn | 0.78 | 0.34 | 0.52 |

**Zero invented numbers.** Every value above is a placement in an ordering the
existing tables already commit the region to, and each of the three has a stated
mechanism in §2.

**What it costs:** Rhėn Tempaol at `decisiveness` 0.50 has commitment
`lerp(0.50, 0.88, 0.45) = 0.67`, which just clears the 0.66 pull, so the first-tempo
identity survives Draft C — narrowly, and by accident rather than by design.
Kutré Lyn's temperament and Lo-ong Ralī's refusal to gamble on serve are both lost;
those are the two most characterful numbers in Draft B and both are **[A]**.

**What it gains:** it can ship without a calibration pass, because nothing in it is
a claim the tables were not already making.

---

## 8. Recommendation

**§1 and §4 regardless of the rest**, because neither is a design question: the
fallback should not name itself after the region it stands in for, and Zaitgaist's
principles should be looked up from the champion rather than stored.

Then **Draft C**, with Draft B's tables kept in this document as the authored layer
to apply once there is a probe to check them against. C makes five regions play
measurably differently from Landavol without adding a single number nobody has
measured, and it leaves B available rather than foreclosed.

The one thing I would not do is Draft B as written today. Fourteen unmeasured
constants shipping at once into live rally behaviour is how the serve got a pace
relief floor nobody had looked at.
