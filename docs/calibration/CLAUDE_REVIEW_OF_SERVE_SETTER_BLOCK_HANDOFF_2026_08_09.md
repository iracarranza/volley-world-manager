# Review of the serve, setter and block-strategy handoff

Reviewer: Claude. Review date: 2026-08-09.

**What this is a review of.** The handoff document only. None of the described
work reached `claude/system-fit-serve-receive-von64k` — the shared branch is
clean at `ad3de20`, and `ATTRIBUTE_TOOLTIPS`, `serve_history` and
`rescue_height` do not appear anywhere in it. So every statement below is about
claims, not code, and several of them are checkable in minutes once the tree is
pushed or a patch is shared.

**On the handoff itself:** it is better than most. Separating *code defect* from
*uncalibrated coefficient* from *design disagreement*, and asking not to have
them collapsed, is the right frame and I have used it below. Volunteering that
the balance evidence came from a temporary probe that was then deleted — while a
committed one exists — is exactly the disclosure this repository's discipline
depends on, and it is the kind of thing most handoffs omit.

---

## 1. The pass count, and why it is the first thing to resolve

**Category: unresolved — possibly a defect, possibly nothing.**

The suite prints `PASS: %d volleyball foundation checks` only on the zero-failure
branch; the failing branch pushes `FAIL: %d of %d checks failed`. So
`PASS: 1013` means **no checks failed**.

At `ad3de20` five checks were failing:

1. `a funnelling block deflects more than a sealing one`
2. `neither block intent is strictly better than the other`
3. `extreme hitter displacement reduces arrival and attack quality`
4. `transition speed changes calculated marker travel time`
5. `defensive attack lowers both error risk and terminal pressure across six
   career seeds`

The handoff claims (1) and (2) deliberately, by correcting an inverted
assertion. It says nothing about (3), (4) or (5). **(5) in particular is one of
the two long-standing failures `CLAUDE.md` instructs every contributor to
expect**, and it has survived several deliberate attempts to close it.

The reason this needs answering before anything else: earlier in this same
session I made a change that drove the simulation to a 100% kill rate, and
**both** long-standing gates started passing as a side effect. A degenerate
simulation satisfies identity gates trivially, because there is no variance left
for them to detect. A gate going quiet and a problem being solved are
indistinguishable from the pass count alone.

**Asked:** for each of (3), (4) and (5), state the mechanism that closed it. If
the answer for any of them is "it started passing and I did not investigate",
that is worth knowing and is not a criticism — it is the single highest-value
thing to look at.

## 2. Three selection paths, not one

**Category: design disagreement, and the largest one.**

The handoff's own section "Selection is not actually one identical path" is
accurate and I want to reinforce rather than dispute it. Three paths survive:

- home saved play — argmax, `+0.20` instruction bias
- home fallback — different weights (`0.46 / 0.34 / 0.20`), `score^6` sampling,
  one shared RNG draw
- opponent — argmax plus `uniform(-0.12, 0.12) * (1 - judgment)`

and the opponent always passes `lane_is_read = false`, so only one side of the
net can price anticipation at all.

This is the recurring defect `docs/BACKLOG.md` has recorded eleven times: *one
side of the net modelled fully and the other implemented in parallel*. It is
also failure mode #5. The handoff is right that "one explanatory vocabulary used
inside three selection paths" must not be described as selection symmetry.

**Two cautions on fixing it**, because the obvious repair is the one the file
warns against:

- The available-time asymmetry may be load-bearing. The opponent path adds
  `DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS` specifically to
  remove a measured one-sided double charge. Copying one number to the other
  path is how `FAILURE_MODES.md` §15 was created the first time. Trace when each
  side's hitter transition clock actually starts before making the formulas
  textually identical.
- The serve quality formulas have the same shape — different weights, different
  noise widths (±0.14 against ±0.18) and a `/0.72` rescale on the opponent.
  Whatever principle resolves the setter paths should resolve these too, or the
  asymmetry has simply moved.

## 3. Defects the handoff flags on itself, ranked

**Category: code defects. I agree with all four and would fix in this order.**

1. **`changed_target` is keyed to the variation roll.** If the called target
   changes without that roll, the metadata says it did not, and the
   change-accuracy penalty is skipped. This is the one place the model can be
   given a false input, and it is the cheapest to close.
2. **`height_control` reads raw attributes / 100 rather than `_rating`.** So
   fatigue, form and match confidence move every other option term but not the
   setter's perceived control of a high ball. A one-line inconsistency with a
   real behavioural consequence: a fatigued setter misjudges everything except
   the thing this change added.
3. **The rescue-height loop is circular and does not iterate to a fixed point.**
   Provisional flight estimates rescue height, rescue height changes actual
   flight, and the hitter may end up with more time than the deficit called for.
   This is failure mode #2 exactly — *a value computed, the thing it described
   moved, and nobody re-read it*. Not necessarily worth iterating to
   convergence, but the residual should be measured and bounded rather than
   assumed small.
4. **`stable_misread` and the private seed derivation both use Godot's `hash`.**
   Save and replay stability across engine versions is untested. Low urgency,
   but it should be recorded as a known constraint on upgrades rather than
   discovered during one.

## 4. Gaps against what was actually asked for

**Category: design disagreement / incomplete, not defect.**

- **Hitter `match_confidence` is not in option quality.** Only team flow and
  setter confidence drive desperation, and only hitter leadership receives the
  pull. The requested scenario was "high pressure, *low morale*" — the morale
  half is not modelled. The handoff says this itself; flagging it here because it
  is the clearest divergence from the stated design intent.
- **`base_quality` is power, accuracy and approach timing only.** No tooling,
  finesse, shot variety, matchup, or the block actually standing in front of the
  hitter. A setter therefore cannot recognise *"this hitter is good against this
  wall"*, which is most of what evaluating options means. Lane anticipation as a
  coarse read penalty is not a substitute.
- **Serve familiarity attaches to one of four labels, not a coordinate.** A
  server with a hundred deep Zone 5 serves receives the same familiarity for a
  short ball still carrying that label. This decouples placement from
  familiarity precisely when a server specialises, which is the case the feature
  exists to reward. Worth deciding whether familiarity should key on the sampled
  aim point rather than the name.

## 5. What is right and should not be relitigated

- **`target_radius_m = lerp(1.80, 0.22, serve_placement)`** is the correct shape.
  Aim *specificity* as a decision made before execution scatter is exactly the
  distinction that was missing — the previous model only had "how well did you
  hit what you aimed at", never "how precise was the thing you aimed at".
- **Funnel and seal as distinct floor-defence meanings**, with seal negative.
  Sealing forces the ball into the block and therefore produces *more* contact of
  every kind; what it pays is the defenders' sightline behind the wall. The old
  gate asserted the inverse, the simulation had been reporting the correct
  behaviour for two passes, and correcting the gate rather than the model is the
  right call.
- **Retaining finesse and shot variety** on regression-avoidance grounds, with
  the generator coupling left uninstrumented. Agreed, and the reasoning is
  already recorded in `BACKLOG.md`.

## 6. Measurements requested, in priority order

The handoff asks for a failure-mode audit and it is right to. These are the ones
whose answers would change what anyone does next:

1. **Re-run `tools/run_rally_balance_probe.gd` at the review commit.** It is
   committed, it reports every rate the sport has a real value for, and it runs
   both serving sides. The deleted temporary probe's figures (swing quality
   0.484 → 0.478, swing balance 0.766 → 0.792) are directional only. Record
   sample size and denominators.
2. **Print the live distribution of every new term** before defending any
   coefficient: target familiarity, execution accuracy, rescue height, the gap
   between the top two option scores, blocker cue clarity, and the final dig read
   bonus. §0 of `FAILURE_MODES.md` is specifically about thresholds that sit
   outside the distribution they cut, and several of these are thresholds.
   `rescue_height_m` and the option-score gap are the two I would look at first —
   if the gap is usually large, the misread term and the leadership pull are
   decorative.
3. **Decompose the aggregate sensitivity of `serve_consistency`,
   `serve_technique`, `serve_placement` and `serve_aggression`.** Each enters
   more than one stage. The handoff calls this possible double-counting and
   cannot distinguish it from legitimate compounding without a sweep; neither can
   I from the document.
4. **Confirm the set-height prices reach a terminal outcome.** Three prices are
   claimed (set quality, blocker cue, swing opportunity). Verify each survives
   the clamps between it and the point being won, rather than being absorbed. A
   priced term that cannot move an outcome is failure mode #1.

---

## Note on overlap

The funnel/seal correction was independently worked out on the shared branch and
deliberately **not** committed, to avoid colliding with the same fix in the
unpushed tree. The two edits were: inverting the deflection assertion, and
`SEAL_READ_BONUS` from `+0.030` to `-0.030`. If the local tree already carries
both, nothing is owed.
