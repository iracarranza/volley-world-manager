# Failure modes

A screening list, not an essay. Every entry here is a mistake that was actually
made in this repository, most of them more than once, and several of them by the
same person on the same afternoon after writing the warning about the previous
one.

Read it before any change where the right answer is not obvious. The point is
not to feel careful; it is to run the checks in **§0** against the specific
thing you are about to do.

---

## 0. The screen

Six questions. If a change touches a number, a threshold, a model, or a
calibration, answer all six *before* writing code.

1. **What are the candidate causes, and what single measurement separates
   them?** Write them down, three or four, and mark the one you believe. If you
   cannot name a measurement that would distinguish them, you are about to guess
   expensively. (§1)
2. **Where does this number sit relative to the distribution it acts on?**
   Measure the distribution first. A threshold outside its distribution does
   nothing, and does nothing *silently*. (§2)
3. **Am I reading a mean as if it were a stable quantity?** Check the median and
   the tails. (§3)
4. **Is this fact already computed somewhere else?** If two places derive it,
   they will diverge, and the divergence will be found months later by accident.
   (§4)
5. **If I am adding a term, does the population aggregate stay where it was
   calibrated?** Solve for that explicitly. Otherwise you are shipping two
   changes wearing one name. (§5)
6. **Does the thing I am about to trust actually run what the game runs?** Check
   the calibration, the harness, the test, and the flag-off path. (§6)
7. **Work backwards from what demonstrably arrives.** Before adding a value and
   hoping it reaches the far end, print what is *already* at the far end. (§14)
8. **Is this reading still true after the thing that changed it?** A quantity
   derived before a correction, and read after it, describes a world that no
   longer exists. Find every derived value downstream of anything you move.
   (§15)
9. **Is there an unowned ratio here?** Two audited quantities combined produce a
   third that nothing checks. Measure its distribution and bound it against a
   model that already has an opinion. (§16)

---

## 1. Chasing the wrong element of a problem

**What it looks like.** The block was being beaten, so: is the wall too narrow?
Widen it. Still beaten: is it in the wrong place? Restage it. Still beaten: the
*hitter was contacting 5.4 m off the net*, and no property of the wall was ever
going to fix that.

Two full passes of work, each internally correct, both aimed at the wrong layer.

**The screen.** Name the candidates up front and the measurement that separates
them:

> Candidates: wall too narrow, wall mispositioned, **hitter contacting too
> deep**, block constants too soft. Discriminator: contact-to-crossing
> displacement against the observed miss distance -- if they match, the wall is
> irrelevant.

That measurement takes four minutes and would have gone first.

**Corollary.** When a fix "helps but does not close it", that is evidence you are
downstream of the cause, not evidence you need a bigger version of the same fix.
The crossing-read moved the miss from 2.13 m to 1.20 m and felt like progress; it
was compensating for the contact depth and became unnecessary the moment the real
defect was fixed.

---

## 2. A threshold set outside the distribution it cuts

**The single most common defect in this repository.** Found at least eleven
times: the recovery speed band, the off-axis alignment bound, the dig moving
test, `poor` against posture, all three block outcome bands, the `funnel` band,
and -- after all of those were documented -- a `rising` threshold set at 0.28
against an offset distribution spanning 0.27 to 0.54.

**Symptoms.** An outcome that never fires. A dial that changes nothing. Two
options that produce identical results. Byte-identical output after changing a
constant.

**The screen.** Before setting or trusting a threshold, print p10/p25/p50/p75/p90
of the quantity it is compared against. If the threshold is outside that range,
it is not a threshold, it is a constant answer.

**The trap inside the trap.** Having found one, do not fix it by moving the
threshold until the counts look right. Ask what the band is *for* and what share
of the distribution that implies. `BLOCK_FUNNEL_MARGIN` fired zero times because
its band was 0.08 wide inside a spread half a unit across -- the fix was to size
the bands against the measured spread, not to nudge one until `funnel` appeared.

---

## 3. Reading a mean as a stable quantity

**Instances.** Mean net clearance read -1.42 m and non-monotone across a sweep
while the median was 0.13-0.31 m and monotone -- a handful of steep-arc swings
dragging it. The "constant" approach mark. The double-charged approach walk.

**The subtler version: centring on the arithmetic mean.** Centring a threshold on
the mean of its input only preserves an aggregate when the mapping between them
is *linear*. `REFERENCE_EFFECTIVENESS` set to the measured mean of 0.676 left the
stuff rate at 16.2% against a 12.0% target, because depth-below-hands is dense
just under the threshold: lowering it converts many touches into stuffs while
raising it by as much converts far fewer back. The constant had to be solved
against the rate it preserves (0.900), and documented as *not* the mean.

**The screen.** Report medians and percentiles by default. Use a mean only when
you have checked the distribution is not skewed, and when centring on one, ask
whether the mapping downstream is linear.

---

## 4. Two sources for one fact

**Instances, all real.**

- The 2D tactical court and the 3D playback read *different functions* for the
  block wall's position. Blockers rendered stacked inside one another.
- Gravity: declared four times at two values (9.8, 9.8, 9.81, and a fourth
  private copy inside the very test meant to verify the flight model).
- The wall staged from the pre-reachability contact, stamped from the
  post-reachability contact, and drawn from a third recomputation.
- Gate D re-implemented the resolver's entire chain by hand and fell behind it.
- `crossing_x` computed independently in the resolver and in the blocker's read.

**The screen.** Before computing a quantity, grep for it. If it exists, call it.
If two callers genuinely need different values -- as with the 75-degree drawn-arc
cap against the 85-degree resolved-flight cap -- that is fine, but **each must
say so and name the other**. The defect there was not the divergence, it was that
neither file knew the other existed.

**Tests are not exempt.** A test with its own copy of a physical constant is not
independent, it is testing a different universe. Independence belongs in the
*formula*, not the constant.

---

## 5. Adding a term while silently rebalancing

**What it looks like.** Block jump timing needed three attempts, and each looked
right:

| attempt | stuff rate | against a 12.0% baseline |
|---|---|---|
| scale off raw timing | 18.9% | |
| divide by relative effectiveness | 15.8% | convex, unbounded below |
| centre on the arithmetic mean | 16.2% | mapping is not linear |
| solve against the preserved rate | 12.2% | correct |

Any of the first three would have shipped "timing now matters" *and* "the wall is
much stronger" as one indivisible change, and no later sweep could have separated
them.

**The screen.** When adding a term to an existing model, solve its scaling so the
population aggregate is unchanged, and say in the comment which aggregate you
preserved and how you solved for it. What is new should be the *spread*, not the
mean. Applies to `STANDING_JUMP_FRACTION` (mean phase = 0.620 preserved),
`REFERENCE_EFFECTIVENESS` (stuff rate = 12.2% preserved), and
`REFERENCE_MASS_FACTOR` (mean cadence preserved).

**The related trap.** A new term can cancel an existing one. Pricing mass into
turnover at full strength cancelled the stride benefit almost exactly, because
mass grows with height too -- height would have bought nothing, the precise defect
the stride model exists to fix. That needed a sensitivity solved against the gate
asserting the property, not a value chosen.

---

## 6. Measuring something the game does not run

**Instances.**

- Gate D: **no caller anywhere** -- no tool, no test. It hand-rolled the
  resolver's chain, never gained `_feasible_launch`, pinned contact depth at a
  literal 0.36 m, and passed an empty array for defenders, so its hitters had
  only the block to avoid.
- `ExecutionScaleCalibration.contest_shares`: projected a block mix from
  thresholds the geometric path overwrites. Zero callers. A wrong answer nobody
  was asking for.
- `block_progression_calibration.CONTACT_HEIGHT_METERS`: a fixed 2.55 m standing
  in for a 3.0-3.3 m range -- below all of it.

**The pattern.** A calibration holds constant the very quantity whose variation
decides the outcome it measures, and nothing runs it, so nothing notices.

**The screen.** A calibration must (a) have a caller, ideally a test that fails
if it stops running, (b) call the production path rather than reproduce it, and
(c) sweep the quantities that vary in play rather than pin them. *A calibration
that measures a chain the game does not run is worse than no calibration* --
because it is trusted.

---

## 7. Correct, then clobbered

Values computed properly and then discarded or overwritten downstream.

- The dig posture: computed, then the branch rebuilt the dict as a literal and
  dropped it.
- `_contest_block`'s bands and the block-intent margins: fully live-looking, and
  entirely dead because `geometric.block_outcome` overwrites the result.
- `arm_state` and `block_effectiveness`: attached to the wall unconditionally
  while only `reach_height_m` was flag-gated -- and the contact keyed off their
  *presence*, so the whole timing model ran with the flag shut.

**The screen.** After adding a value, grep for every write to its destination. If
a feature flag is involved, verify flag-off is **byte-identical**, not merely
"looks the same".

---

## 8. Determinism

- `jumping_reach_cm()` reads `fatigue`, so mutating fatigue inside the resolver
  breaks replay. Costs must be *reported* on the result and applied by the
  caller.
- **Changing the number of RNG draws re-sequences every seeded outcome after
  it.** Block-intent gates flipped on the re-shuffle alone. Draw
  unconditionally, gate afterwards.
- Prefer deterministic derivation over a new draw. `BlockJumpModel` decides
  early-vs-late from the close fraction rather than rolling, because a draw there
  would have re-sequenced everything downstream for no gain in fidelity.

---

## 9. The measuring tool is also code

Every one of these was wrong, and each produced a confident wrong conclusion:

- A lowest-body-point probe that named the *neck* on a standing player
  (recursive `minf` with per-call minima, no name tracking).
- A dig-terms tool averaging over rows with no arrival, understating one side by
  1.43x.
- A jump probe sampling `close` uniformly over [0.34, 1.0] when live delivers p25
  0.785 and p50 1.00 -- which inflated every state keyed off it and made a
  constant look already correct.
- A "7x disagreement" between harness and rally that was a **denominator
  mismatch**: per-block-formed against per-swing.

**The screen.** Before believing a surprising measurement, check the tool's own
denominators, filters and sampling against what it claims to describe.

---

## 10. One sample is not a measurement

`STRAIN_AVERSION` was derived twice and the second derivation overturned the
first: three roster pairings said 1.10, eight said 0.85. Attack error and stuff
both moved several points between those samples *at a fixed value of the
constant*.

Block-intent gates separated by two or three counts out of fifty and flipped on
random re-sequencing alone, until the sample was widened from 300 rallies of one
six to 1,200 across four rosters.

**The screen.** A figure read off one handful of pairings is a draw from a wide
distribution, not a measurement. Widen the sample before concluding, especially
before concluding that something does *not* work.

---

## 11. A gate that cannot resolve its own claim

The identity gate comparing defensive against physical attacking has both arms
sitting at a 90% kill rate, and under one flag they come out bit-identical to
four decimals. The margins it passes on are 0.0056 and 0.0023.

That is not a property being violated; it is a metric with no headroom, built on
a ratio whose numerator is counted per rally and whose denominator is counted per
swing.

**The screen.** When a gate fails on a tiny margin, check whether it *can* pass
on a large one. If both arms are pinned near a ceiling, fix the metric. **Do not
raise the sample count** -- no sample size rescues a 0.0004 margin on a saturated
quantity.

---

## 12. Do not widen a bound to close a gap

The standing rule, and it deserves its own entry because the temptation is
strongest exactly when everything else is done.

If a change is correct and a bound rejects it, the bound is the finding. Ship the
change behind a flag, off, with the measurement and the blocker documented, and
name what has to be true before it opens. Several flags in
`rally_feature_flags.gd` exist in exactly that state and each one records what it
is waiting on.

**The related discipline:** do not ship half of a change because the other half is
hard. Scaling the net-clearance margin without teaching the power choice about
the tape bought nothing and drifted a ratchet; it was reverted and the finding
recorded until both halves could land together.

---

## 13. Report what happened

- When a fix moves the target by 1.5 points, say "moved 1.5 points", not
  "fixed".
- When an earlier claim was wrong, withdraw it explicitly and say what replaced
  it. Two claims in this repository were withdrawn this way -- the approach
  budget's "100% deficit" (a double-charged walk) and "the approach mark ignores
  the set" (it does not; it moves ~3.5 m within one tempo). Both had already been
  written into docs and commits before being caught.
- A hypothesis that dies on measurement is worth recording. Two died on the block
  jump work -- the jump multiplier and a supposed 7x involvement gap -- and both
  are written down so they are not raised again.


---

## 14. Work backwards from what arrives

The most repeated shape of wasted work here is not a wrong theory. It is a
correct-looking change that turns out to affect nothing:

- `block_miss_reason` stamped through four layers and arriving empty, because a
  curator in the middle dropped it.
- An `anchor` added to `evaluate_arrival` and read on both sides of the net, to
  reconcile a 0.75 m disagreement. Byte-identical rallies -- the key never
  arrived, every call took the fallback, and the disagreement was never real.
- A deflection bonus added to the third dig site. Correct, and the branch never
  fires in the sample.
- A `movement_start` key added to an event that already had one eleven lines up.

Each cost a full measure-and-verify cycle to discover, and each was avoidable by
one cheap step: **print what is at the destination before changing what is at the
source.**

Dump the keys actually present on the event, the dict, the record. Then trace
backwards to whatever wrote them. This finds curators that drop fields, branches
that never fire, and values that were already there -- before any of them cost a
rebuild.

It also finds the subtler thing. Dumping the `arrival` dict on a DEFENSE event
showed that most of them are *empty*: only claimed digs carry one. So a
comparison of "claim distance" against "drawn distance" was silently comparing
44 rows against 78, and the 0.75 m gap between them was a denominator mismatch,
not a defect in the engine. On matched rows the two agree to three decimals.

That is the same defect as the "7x involvement gap" between harness and rally,
which was per-block-formed against per-swing. Twice in one day, from the same
habit of trusting a number without checking what it was averaged over.

**The rule:** when a measurement surprises you, inspect the *rows* before
inspecting the model.
---

## 15. A reading that outlived the thing it described

**What it looks like.** `_reachable_contact` exists to spare a hitter who cannot
make the ideal contact: it pulls the contact back along their route to the point
they reach as the ball arrives. Once it binds, the hitter is on time *by
construction*. All three swings went on charging `hitter_arrival_margin`, which
was computed one line earlier against the contact that no longer existed.

So the ball was moved to the hitter *and* the hitter was penalised for not
reaching where it used to be. Measured, the opponent's mean arrival margin read
-0.461 s against the home side's +0.288 s, and that stale term alone was 0.662
of their 0.958 mean approach deficit -- the reason they backed off 71% of swings
against the home side's 2%, and through that, the reason they almost never
spiked, which is upstream of most of the dig asymmetry.

**Why it survived so long.** Both sides run the identical code. The defect is
symmetric; only its *binding* is asymmetric, because only the opponent's hitter
routinely fails to make the contact inside the set's flight. A grep for
asymmetry finds nothing, and a side-by-side reading of the two functions finds
nothing, because there is nothing there to find.

It also survived a partial fix. On the home path, `resolved_approach` **is**
re-evaluated against the clamped contact, with a comment explaining exactly why
-- "a clamped contact would then have been scored on a runway nobody ran." The
same author, at the same moment, left the margin stale two lines above. Half the
downstream readings were refreshed and half were not, which is why the remaining
half looked deliberate.

**How it was found.** Not by reading the code. By splitting one published
outcome into the two independent rewrites behind it: every swing passes a
set-quality gate *and* an approach gate, and only the second one's output was
ever stamped on an event. Two separate investigations had already attributed
"the opponent never spikes" to the first gate -- once by reading a threshold
against a distribution, once by re-applying that threshold against the resolved
set quality -- and neither moved the mix, because the first gate costs 31 swings
and the second costs 85. Itemising the second gate's five terms then put the
cause on one of them.

**The rule:** anything that *moves* a quantity invalidates every value derived
from its old position. Before the change, list what reads it; after the change,
re-read them all or say in the code why one is deliberately left alone. And when
a model publishes a single verdict assembled from several independent
judgements, publish the judgements too -- an unattributable total sends
investigations to the wrong file, repeatedly.

## 16. Nothing bounds a quantity the model never claimed to own

**What it looks like.** Playback drew every player's leg by lerping them from
where they were to where the plan said, across the ball's flight. There is no
speed anywhere in that sentence. Distance and time both came from elsewhere --
the resolver's positions and the ball's kinematics -- and the quantity that
falls out of dividing one by the other was owned by nobody, so nothing ever
checked it.

Measured over 600 rallies and 15,314 planned legs: median 0.00 m/s (most bodies
stand still, which is correct), p90 4.53, **p99 13.38, max 57.11 m/s**. The
worst case was a 4.49 m return to defensive base drawn inside a 0.079 s
attack-to-block window. Six percent of base-posture legs and fifteen percent of
legs belonging to the player about to touch the ball exceeded 7 m/s, which is
about the fastest a human covers ground on a volleyball court.

**Why it survived.** Every input was individually defensible. The positions came
from the resolver, the durations came from the ball model, and both had been
audited. The engine already owned a locomotion model that answers exactly this
question -- `LocomotionModel.maximum_speed` -- and playback simply never asked
it, because playback was not understood to be making a physical claim. It was
"drawing", and drawing does not get calibrated.

**How the wrong instrument nearly closed it.** The reported symptom was a block
that replayed itself while bodies teleported. The first measurement taken was
the blocker's base position against the block contact point over the attack's
flight, which printed a plausible-looking 15.9 m/s for the assisting blocker.
That number was an artefact: the simulator *does* stage blockers during the
set's flight, one window earlier, so the attack window was the wrong window.
Re-measured correctly, the wall slides 3.6 cm inside the attack flight -- the
staging was never the problem. The real number only appeared when the question
changed from "is this specific body being dragged?" to "how fast is *every*
planned leg being drawn?"

**The rule:** when two audited quantities are combined, the ratio between them
is a third quantity, and it is unowned by default. Name it, measure its
distribution, and bound it against whatever model in the engine already has an
opinion about it -- there usually is one. And a symptom seen on screen names a
*moment*, not a cause: measure the whole population the moment belongs to before
measuring the moment.

## 17. A number tuned against one instance of a thing, applied to every instance

**What it looks like.** The tactic sheet draws volis as stickers: a traced
outline, a shaded body, and a die-cut border of constant weight. Constant weight
is the point of the object, so the border was a constant -- `STICKER_BORDER =
3.4` px -- and it was chosen while looking at a blocker who filled a third of
the sheet.

Then the sizing was fixed. A voli stopped being drawn at a share of the panel
and started being drawn at the metres they occupy, which is correct and which
made a plan-view figure about thirty pixels tall. At thirty pixels a 3.4 px cut
on each side meets in the middle: every sticker rendered as a featureless white
blob on a dark board.

**Why it survived, and how it was nearly misdiagnosed twice.** The blobs were
white, and the shading palette had a real bug in it at the same time -- `_shade`
opened with `var light_mode := true`, a stub written in the shape of a decision,
so the dark theme was being painted in the light palette. Fixing that changed
nothing visible, which was the useful result: it meant the palette was not what
was being seen. The second guess was that the posterise was collapsing to one
tone. Measured over the 5,006 opaque pixels of a block bake, the render's
luminance runs 0.000 to 0.799 with a median of 0.283, and the three tone buckets
came out 283 / 1,397 / 3,326 -- spread across all three, exactly as designed, and
none of it visible under the border. Only after both candidates were measured
and cleared was the border the remaining suspect.

**The rule:** a constant is only constant with respect to something. Write down
what -- pixels, metres, or a share of the object it belongs to -- and check that
the answer still holds at the smallest and largest instance the code can
produce. "Constant weight" was a claim about the *object*, and the object varies
in size on screen, so the honest encoding is a share with a floor and a ceiling.
A stub written as a plausible-looking assignment (`var light_mode := true`) is
the same defect wearing different clothes: it reads as a decision and it is
actually an unasked question.

## 18. Recursion depth is an input the caller never sees

**What it looks like.** The sticker baker simplifies each traced silhouette with
Douglas-Peucker, written the obvious recursive way: find the worst point, keep
it, recurse on both halves. It worked for a year, because the only pose ever
baked was a blocker at full extension -- a tall, simple outline that splits
close to evenly and bottoms out in a few dozen levels.

Adding an attack pose and a dig pose broke it instantly. A crouched body has a
long, convoluted boundary, and the split degenerates toward one point per level,
so the depth is O(n) in the contour length rather than O(log n). Godot raised
"Stack overflow. Check for infinite recursion in your script." -- which is the
wrong diagnosis, there was no infinite recursion -- and every sticker on the
sheet came back empty. **An empty sticker draws as nothing**, so the visible
symptom was a page with no volis on it and no error anywhere near the drawing.

**Why it survived.** Nothing in the signature of `_simplify(points, tolerance)`
says anything about how deep it will go, and the one input that controls that --
how gnarly the shape is -- is not a parameter, it is a property of the picture.
The pose set was the real argument and it was three files away.

**The rule:** a recursive helper's depth is an input, and if it is bounded by
data the caller does not control, write the loop. The rewrite here is the same
algorithm on an explicit stack and is four lines longer. Separately: a component
whose failure mode is *drawing nothing* needs to say so out loud -- silence and
success look identical, and the log was the only place the truth existed.

## 19. A knob undone by the stage after it

**What it looks like.** Volis on the tactic sheet came out fluorescent -- a
magenta torso over teal shorts, louder than the red pencil that is the only thing
on the sheet allowed to shout. The cause was clear enough: kit colours are mixed
to sit on a lit 3D court, and the sticker bake had just been switched to unshaded
rendering, so they arrived at full strength.

So a cap went in: clamp saturation to 0.40 before writing the pixel. Rendered
again, sampled off the sheet: **every ink came back at s = 0.50**, with a 0.40
cap in the code three lines above it.

**Why.** The next line quantises each channel to `COLOUR_STEPS = 6` so the
sticker has a countable palette. At v = 0.67 a saturation of 0.40 wants the dark
channel at 0.40; the nearest sixth is 0.333; and 0.333 against a 0.667 maximum
*is* a saturation of 0.50. The quantiser was not ignoring the cap -- it was
rounding straight past it. Every value the cap could produce landed on a step
that put the saturation back.

**The rule:** a limit is only a limit if it survives everything downstream of it.
When a value passes through a second stage -- quantised, snapped, rounded,
re-encoded -- check the limit against the *output*, not the assignment. This is
§0's defect wearing yet another hat: a knob that cannot reach its own stated
range, except here the knob could reach it and the next stage undid it. Twelve
steps and a 0.30 cap now measure out at 0.28-0.38, which is what the cap says.

**Adjacent, same pass:** the sheet's graph paper looked irregular, and it was two
grids rather than one bad one. Sampling a pixel row across the sheet found lines
at exactly 13.0 px spacing interleaved with lines at exactly 22.0 px -- the
worksheet's own squared paper, and `UIPrintedRule`'s layout grid drawn over it
because the rule was added to the panel last and therefore drew last. Neither
grid was wrong. **Count the things before measuring one of them.**
