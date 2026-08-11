# Cogniticon motion: a mark that belongs to a body

Draft. The ask: the marks should feel like a living extension of the voli they
are attached to — the eye narrowing in suspicion and widening in shock, the
blade swooping in rather than appearing, charging, and slashing down on the
spike. This is the design review before any of it is built, scoped to **the eye
and the blade**.

Nothing here is implemented. Where a decision is not mine to make it is left as
an open question at the bottom rather than guessed at.

---

## 0. What already exists, because three things this session did not

`PlayerCognitionCue` is richer than the renderer uses. Everything below is
already published, already validated, and already crosses a save:

| field | values | drawn today |
|---|---|---|
| `state` | searching, recognizing, deciding, calling, committed, **lost_sight**, **reacting** | as a badge shape |
| `attention_kind` | ball, setter, hitter, teammate, position, none | not at all |
| `attention_hold` | glance, track, fixed | not at all |
| `urgency` | 0–1 | badge emphasis only |
| `affect` | neutral, confident, urgent, upset, sad, pleased | as a face glyph |
| `visibility` | visible, partially_obscured, occluded | not at all |
| `progress` | 0–1 | the blade's fill |
| `dwell_seconds` | seconds, or −1 for no fade | `glyph_strength` |

And **`cognition_badge.gd` already computes `eye_openness`** — line 117, clamped
0–1 — which the 3D renderer has never read. That is the exact input for "narrows
in suspicion", sitting there finished. It is the fourth dropped key found in this
subsystem, after `progress`, `reach_margin_meters` and `wall_reach_heights`.

**So most of this design is wiring, not invention.** That is worth saying up
front because it changes what the work is: the risk is not "can we express
suspicion", it is "will twelve animated marks wreck the layer".

---

## 1. The three constraints any motion has to satisfy

### 1.1 Motion is preattentive, and this layer's job is to not be looked at

`COGNITICONS.md` is unambiguous: the ambient tier "must never draw the eye", and
its job is that "a glance anywhere on court tells you what that voli is doing,
and that *nothing draws the eye*". Motion is the strongest attention signal in
the visual system — stronger than colour, stronger than size. Twelve moving
marks would do more damage to the two-tier rule than any size or alpha mistake
made so far.

**This is the whole design problem.** Everything else is easy.

The resolution is that the two tiers already describe two kinds of motion, so
the budget maps onto them rather than being a new axis:

| tier | motion | why it is safe |
|---|---|---|
| **ambient** — on twelve volis, always | slow, small, continuous, never a snap | sub-threshold: a drift of a few percent over a second does not trigger the motion channel |
| **punctuating** — rare by construction | fast, large, brief | `lost_sight` fires 24 times in 47,000 cue-samples; it is allowed to be loud *because* it is nearly never on |

The rule that follows: **an ambient mark may never change faster than about a
quarter of its own size per second.** A blink is the exception the rule has to
name explicitly, and blinks are what the next section is about.

### 1.2 Everything must be a pure function of simulation time

`match_screen.gd` carries `playback_speed`, clamped 0.1 to 4.0, and drives
`sample_cognition(simulation_time)` from a lerp between event times. Animation
driven by frame deltas would therefore:

- play at the wrong rate under a 0.25× replay
- desynchronise from the bodies, which are already phase-driven
- and be untestable headlessly, which is how everything else in this repo is
  checked

So cogniticon motion is `resolve(phase, …) -> Dictionary`, exactly like
`SpikeBiomechanics`, `BlockBiomechanics` and `GaitBiomechanics`. Same house
style, same reason, and it makes every claim below gate-able without eyes.

### 1.3 The honesty rule governs the shock

This is the one place the ask brushes against an existing principle, so it needs
stating precisely rather than being discovered later.

`COGNITICONS.md`: an ambient glyph "is a claim about what a voli is *trying* to
do. That is always honest. It stops being honest the moment the glyph reflects
whether the [attempt succeeded]." And progress is "distance covered, never
likelihood of arriving".

A shock reaction is honest **if and only if it fires at or after the moment that
caused it.** An eye that widens as the ball is struck is a voli reacting. An eye
that widens a beat *before* the ball is struck is the resolver's knowledge
leaking through the drawing — the same defect as entry 6, "blockers already know
the outcome", which is still open.

The states make this easy: `lost_sight` and `reacting` are already *reactions*,
and a cue's `starts_at` is when it begins. The rule is therefore mechanical —
**no shock envelope may begin before its cue's `starts_at`** — and it is
gate-able, which is better than being a note in a doc.

---

## 2. The eye

### 2.1 Aperture — narrowing in suspicion

One number, `eye_openness`, already computed. The mark's `ry` scales with it:

| reading | ry | reads as |
|---|---|---|
| narrowed | 0.45 × nominal | focus, suspicion, a hard read |
| nominal | 1.0 | watching |
| widened | 1.55 | shock |

Narrowing should come from `attention_hold == fixed` and high `urgency` —
someone locked on and under pressure — and widening only from the shock envelope
below. The pupil's radius stays constant through all of it; an eye that scales
whole reads as zooming rather than as squinting.

### 2.2 The pupil follows what the voli is looking at

The single biggest "alive" win available, and it is nearly free. The actor
already computes a look heading and `look_toward` already clamps it to a neck's
range. Offsetting the pupil within the eye by that same heading — projected into
the billboard's plane — gives twelve eyes that all turn to the ball together,
and turn away when a voli loses it.

`attention_kind` says *what* is being looked at, so the pupil can be aimed at
the right thing rather than always at the ball: the setter, a hitter, a
teammate, a spot on the floor.

**And `visibility` is the other half.** A voli whose view is `occluded` should
have the pupil drift off-target — they are looking, and not seeing. That is
`attention_kind` and `visibility` disagreeing, which is a true and currently
undrawn thing.

### 2.3 Blink — the beat that makes it alive

A blink is a fast closure and a slower opening, roughly 90 ms down and 150 ms
up, every 3–6 seconds. It is the exception to the ambient motion budget, and it
gets away with it because it is brief and because a face that never blinks is
uncanny in a way a face that does is not.

**Twelve volis must not blink in unison.** The phase comes from a hash of
`player_id`, so it is deterministic, scrub-safe, and different per body without
any randomness.

Blinking should **stop** while `attention_hold == fixed`. Not blinking is what
staring *is*, and getting that for free from a hold the model already publishes
is the kind of detail that sells the whole layer.

### 2.4 Shock — the one exception to the single ink

The ask is a red glow, and this session established that marks are drawn in one
ink so they never compete with the palette. The exception is worth taking for
exactly one reason: `lost_sight` fires 24 times in 47,000 samples. A colour that
appears roughly once a match is not competing with anything — it is the rarest
event in the layer wearing the only colour in the layer.

Envelope, fast in and slow out, because that is what a startle looks like:

```
  0 ms    the causing event
 40 ms    aperture at 1.55, ink at full red        <- snap
160 ms    still wide, red beginning to bleed out
420 ms    back to nominal aperture and ink
```

Gate: the envelope's start must be ≥ the cue's `starts_at`.

---

## 3. The blade

### 3.1 Swoop in, rather than appear

Every mark currently pops into existence, which is most of why they read as
overlays rather than as belonging to a body. The blade enters over ~0.22 s —
the same order as `FADE_SECONDS` (0.22) and `GLANCE_DWELL_SECONDS` (0.18), so
the vocabulary already thinks at this scale.

Drawn as a blade being *drawn*: it arrives from behind the voli's shoulder,
rotating from about 35° off vertical into upright, with the fade running ahead
of the motion so it is never seen as a solid object in the wrong place.

### 3.2 Charge — prominence, not size

`progress` already drives the fill. Two more things ride it, both small:

- scale 1.0 → 1.12 across the run-up
- the blade's tilt straightens from ~6° to 0° as it fills

That is deliberately modest. The fill is the loud signal; the scale is there so
a full blade *feels* heavier than an empty one, not so it announces itself.

### 3.3 The slash

At the attack's contact, and **not before it** — the honesty rule again, and the
same rule that keeps the block's rise off the ball's clock.

```
  0 ms    contact
120 ms    rotated ~70° through the downswing, streak trailing
300 ms    settled, blade withdrawing
```

The streak should be the blade's own silhouette smeared along the arc rather
than a new shape, so the mark never stops being the mark.

### 3.4 Sheathe — and it answers an open entry

The mirror of the swoop, and worth more than symmetry: **a hitter the setter
passed over should have their blade sheathe.** That is backlog entry 14 — a
passed-over hitter having no post-decision assignment — showing up in the one
layer that can say it without moving a body. It does not fix the entry; it makes
its absence legible, which is arguably what the layer is for.

---

## 4. Shape of the work

One new module, `CogniticonMotion`, pure and phase-driven, in the pattern of the
other biomechanics files. It returns a transform and a set of drawing
parameters; `CogniticonMarks` keeps rasterising and gains a per-frame overlay
for the pupil and the aperture, which cannot be baked into a shared texture
because they differ per voli per frame.

That is the one real architecture question: **the eye can no longer be a shared
static texture.** Options are a small per-voli texture regenerated on change
(cheap if the aperture is quantised to ~8 steps), or the eye assembled from
three sprites (outer, pupil, leads) transformed independently. The second is
almost certainly right and costs one more node.

---

## 5. Open questions — the ones I should not answer alone

1. **Do the eye and the intent mark appear together?** They are two axes —
   *what I am doing* and *where I am looking* — and the review drew them at two
   different heights, implying both. One billboard node can draw one thing, and
   the badge tier currently pre-empts the intent tier entirely. Animation forces
   this decision; it has been deferred twice.

2. **Is continuous ambient motion allowed at all**, or should twelve idle marks
   be perfectly still with motion reserved for punctuating moments? The blink
   is the test case: it is the thing that most makes a mark feel alive and the
   thing most likely to make a court feel busy.

3. **Does the red earn its exception?** It is the only colour in a vocabulary
   deliberately reduced to one ink, justified by rarity alone.

4. **Should the shock ever fire for the opponent's volis?** A shocked opponent
   is information about their read that the manager arguably has not earned —
   the same question `SCOUTING.md` asks about everything else on that side.

5. **What is the actual per-contact time budget?** A swoop plus a charge plus a
   slash is ~0.7 s of motion inside windows that are often shorter than that.
   Worth measuring before tuning any envelope, rather than after.

---

# The scenario, read back

The design was answered with a scene rather than with settings, which turned out
to be the right instrument: several things in it change the design rather than
decorating it. This section is the scene read back in the system's own terms,
so that where it disagrees with what is above, the disagreement is on the page.

## 6. The rule that changes: **a mark shows what the voli believes**

The setter telegraphs left; the blockers' eyes follow left; the set is a slide
right; the eyes swing and widen. **The blockers' eyes were pointing at the wrong
place, and that is exactly correct.**

This inverts §1.3 in a way that makes it sharper rather than weaker. The old
statement was defensive — do not leak the resolver's knowledge. The real rule is
positive:

> A cogniticon draws the voli's **model of the world**, not the world.

Everything follows from that. A pupil aimed at a decoy is honest. A shield that
never fills is honest. A blocker who is doubtful about a read the resolver has
already settled is honest. And the thing that remains forbidden is unchanged and
now easier to state: a mark may not show what the voli **could not know yet** —
which is a claim about *time*, not about correctness.

So the gate is temporal, and only temporal: no envelope may begin before its
cue's `starts_at`. Being wrong is allowed. Being early is not.

This is also where the drama comes from. A layer that only ever showed true
things could not contain a decoy.

## 7. Hand-off, not two slots

"Onlookers take their glance and immediately begin a new action, the eye
minimising away for a new icon."

That answers the deferred question, and answers it better than either option I
had: the eye and the intent mark **share one slot and trade it**. The eye
minimises away as the intent arrives. The transition is itself expressive —
a voli finishing looking and starting doing is one continuous gesture rather
than two marks appearing.

The remaining case for concurrency was hitter and blocker *course* — line or
cross, which way the wall is going. **That does not need a second mark either.**
Direction belongs on the intent mark:

- the blade **tilts** toward the course it is swinging — line, cross, or the
  angle between
- the shield **leans** toward the lane it is closing

which is one parameter on a mark already being drawn, reads at a glance, and
keeps one mark per voli. If that turns out to be too subtle at playback
distance, concurrency is still available as a fallback — but it should be the
fallback, not the plan.

## 8. Colour is an affect ramp — and the court I just softened is in the way

The scene needs three colour states beyond the ink: **orange for doubt**, **red
for shock**, **grey for a mark that has been defeated**. That is more than the
single-red exception in §2.4, and it is justified — doubt and shock are a
continuum and drawing them as one hue with two values is what makes the swing
from one to the other read as escalation.

**But orange is now close to the worst available choice.** The court was
softened to an apricot `cf8659` in the same session, and the ambient marks float
above heads against exactly that ground. An orange mark on an apricot floor is
the same mistake as the original coral-on-terracotta, which is why the ink went
white in the first place.

Three ways out, and this needs a decision rather than a guess:

1. **Keep the ink neutral and carry affect in the halo.** A white mark ringed in
   orange, then red. Contrast stays the ink's job; hue becomes the halo's. This
   is the most conservative and probably the right one.
2. **Push the hues away from the court** — doubt as a cool amber or a sickly
   yellow-green, shock as a magenta-red rather than an orange-red. Keeps colour
   on the mark, costs the obvious reading of "orange means doubt".
3. **Draw doubt as behaviour rather than hue** — a flicker, an unsteady pupil,
   a mark that cannot hold still — and reserve colour for shock alone. The most
   expressive and the most work.

## 9. Synchrony is the combination, and it is free

"All of the attacking volis' swords swing in at once and begin charging — this
is a combination play, and as this registers in your mind the volis begin
moving."

Nothing has to detect a combination or label one. Three blades arriving on the
same frame *is* the signal, and it emerges from each voli independently entering
at their own moment. That only works if entry timing is derived from each voli's
own cue rather than staggered for looks — so **no entry may be offset for visual
variety.** A stagger added to stop marks looking mechanical would destroy the
one moment the layer most needs to land.

The same fact in reverse: when the marks *do not* arrive together, that is a
broken play, and it will read as one without anyone drawing it.

## 10. The motion primitives the scene actually names

The scene is precise about verbs, and they resolve to a small set — small enough
that the eye and the blade share most of it:

| primitive | in the scene | driven by |
|---|---|---|
| **arrive** | swords swing in; eyes appear | cue `starts_at` |
| **surge** | charging serve; middle's sword since takeoff | `progress`, `SignatureMoveModel.charge` |
| **minimise away** | the eye going as a new icon comes | cue end, handing to the next |
| **form and shatter** | the hesitant passer's commitment diamond | a state that was entered and lost |
| **swing** | blockers' eyes following the telegraph, then snapping | pupil aim, from the believed target |
| **widen** | shock at the slide | state → `reacting` / `lost_sight` |
| **slash** | the spike | the attack's contact |
| **cleave and grey** | defenders' shields cut and falling | the attack's *outcome*, after it lands |

"Bursting with power" has a home already: `SignatureMoveModel.charge` is a 0–1
quantity with an availability threshold at 0.62, so a serve's blade can visibly
cross from *strong* into *signature* without a new number being invented.

**Two of these are new architecture, not new drawings.** *Form and shatter*
needs a state's *transition* rather than its value — the renderer currently sees
only what a cue is, never what it stopped being. And *cleave* is one voli's mark
acting on another's, which nothing in the layer can express: marks are strictly
per-voli today. Both are worth building; neither is a tuning pass.

## 11. The camera is part of this feature

The scene opens zoomed on the server, pans to the receiving team as the toss
goes up, and follows. **The scenario is a camera script**, and the marks are
timed against it — eyes "appear" as the camera arrives on them, which is a
statement about framing as much as about cues.

So the dynamic camera is not the next feature after this one. It is the other
half of this one, and the framing decisions I listed as prerequisites are
answered by the scene: it follows the ball, it moves rather than cutting, and it
anticipates the *contact* rather than trailing the ball.

## 12. What is still open

1. **Which of the three colour routes in §8**, given the apricot court.
2. **Is opponent cognition always visible?** The scene depends on reading the
   blockers' doubt and their bite on the decoy — that is the payoff. It is also
   information a manager has arguably not earned, and `SCOUTING.md` gates
   everything else about the other side. If it is always visible, that is a
   deliberate choice worth writing into the scouting doc rather than an
   inconsistency.
3. **Does direction-on-the-mark (§7) carry course well enough**, or is
   concurrency needed after all?
4. **The time budget** from §5 is now sharper, not looser: the scene has a
   charge, a hand-off, a swing, a shock and a slash inside one rally. Worth
   measuring the real windows before any envelope is tuned.
