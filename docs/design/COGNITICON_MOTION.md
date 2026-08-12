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

## 8b. Doubt without colour: the lead forks

Colour's role in this vocabulary is still an open question, and doubt should not
be the thing that forces it. It does not have to be — **doubt has a better home
in shape than in hue**, and the eye already has the vocabulary for it.

The lead line is the eye's certainty axis, and it is already three-valued:
flicks for a glance, dashed for tracking, solid with an arrowhead for locked on.
Doubt is the fourth value and it is the obvious one:

> **A certain eye has one lead. A doubtful eye's lead forks.**

Two prongs, aimed at the two things the voli cannot choose between. That is
strictly better than a hue for four reasons:

1. It survives any court colour, which is the problem §8 ran into.
2. It is **specific**. A colour says *this voli is unsure*; a fork says *this
   voli is unsure between the middle and the pin*, which is the actual state and
   the actual drama.
3. It scales without a new mechanism — the fork angle widens with uncertainty,
   and a third candidate is a third prong.
4. It composes with a vocabulary that already exists rather than adding an axis
   to the layer.

It is also the same move that let the family hues go earlier in this session:
shape carries the meaning, so colour does not have to.

### 8b.1 The supporting beats

The fork is the statement; three smaller things make it read as *doubt* rather
than as *two leads*:

- **The pupil cannot settle.** It drifts between the candidates rather than
  resting on one — slow, a few percent of the eye's width, well inside the
  ambient motion budget in §1.1. This is the single most legible cue and it is
  nearly free once the pupil aims at all (§2.2).
- **The aperture is wide and unsteady**, not narrow. Narrow is *focus*; doubt is
  the opposite of a hard read, and an eye that cannot hold its own shape says so.
- **The upper lid goes asymmetric** — a half-squint on one side, which is the
  face of suspicion in every drawing tradition that has one.

### 8b.2 What the fork needs from the resolver

The candidates. The block read already has them: the wall chooses between
eligible hitters, and `wrong_read` and the block's own close terms mean the
resolver knows both which one was picked and which one it was picked *over*.

The cue does not carry a second attention target today. That is one field --
something like an `alternate_attention_player_id` -- and it is the only new
data this whole section needs. Everything else is drawing.

Resolving the scene's "orange in doubt" this way leaves colour entirely
unspent, which is the point: the role of colour can then be decided on its own
terms rather than being settled by the first thing that needed it.

## 9. Synchrony is the combination, and it is free

"All of the attacking volis' swords swing in at once and begin charging — this
is a combination play, and as this registers in your mind the volis begin
moving."

Nothing has to detect a combination or label one. Three blades arriving on the
same frame *is* the signal, and it emerges from each voli independently entering
at their own moment.

### 9.1 The rule, restated — the first version said too much

An earlier draft of this section said "no entry may be offset for visual
variety", which reads as *no variation at all*, and that is wrong. Volis do have
genuinely different approach timings, and they should.

The rule is narrower, and it is about the **source** of the offset rather than
its size:

> The only thing allowed to stagger the marks is the simulation.

Two offsets that look identical on screen and are not the same thing at all:

- **Simulated.** The middle commits 80 ms before the pin because the resolver
  gave them different distances, tempos and reaction times. That difference is
  *information*. A combination where the middle goes first and the pin follows
  is a different play from one where they leave together, and the marks should
  say which. Drawing it is the whole point.
- **Cosmetic.** A renderer adding a random 0–150 ms jitter so twelve marks do
  not look mechanical. This is the one to refuse, because it destroys the
  signal: once everything is staggered, a real combination and a broken play
  look the same. The scene's "as this registers in your mind" moment lands
  *because* the timing is true. Invented, it would be a lie that occasionally
  coincided with the truth.

### 9.2 The consequence worth more than the rule

If the stagger is always simulated, then **how tightly the marks arrive is
itself a readable quality of the play** — not just that a combination is
happening, but how good this team is at it. A well-drilled side's blades land
within a few frames of each other; a poorly-drilled one's straggle.

`Familiarity` already models exactly that and already modifies reads and
timings. So team chemistry becomes visible in the cogniticon layer without a
single number being added to it, which is the same shape as the fill: a quantity
the simulation already owns, drawn instead of dropped.

The same fact in reverse: when the marks *do not* arrive together on a play that
was supposed to be a combination, that is a broken play, and it will read as one
without anyone drawing it.

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

## 13. Variants, and the backdrop that carries both the rating and the success

A family says what a voli is doing. A **variant** says how it is going, and the
rally's own events choose it — no mark reads another mark, so a fractured shield
is fractured because the resolver says the ball went through it, not because
some other voli's blade was drawn nearby.

| | ascendant | broken |
|---|---|---|
| where it lives | **behind** the mark, in the backdrop | **in** the mark |
| blade | flares | fractures across its midpoint, the tip falling away |
| shield | flares | fractures apex to hem, the halves parting |
| commitment | — | fractures on its long axis |

**The two directions are not symmetrical, and that is the design.** Succeeding
is something that happens *around* a voli: the mark is unchanged and the ground
behind it catches light. Failing happens *to* the mark — it breaks, and the
pieces fall away from each other.

The first version drew both into the ink: flame tongues off a blade's edge, rays
off a shield's rim. That meant every family owed two more path lists, and a
flaming blade and a shining shield had nothing in common but intent. One flare
behind any mark costs one drawing for the whole vocabulary and says the same
thing about every family.

### A break is a fracture, not a cut

A shape parted along a straight line reads as **two shapes** — which is exactly
what the first attempt produced: a shield in halves and a blade drawn in two
pieces. A *jagged* seam is what makes it read as one thing that broke, because
the two edges are complementary: the teeth of one side are the gaps of the
other, and the eye reassembles them.

The seams run where the shape is weakest, which is also where they read: **apex
to hem** down a shield, **across the midpoint** of a blade. And the loose piece
falls and turns — parted-but-level is a shape with a crack in it; falling away
is what says it lost.

Teeth are scaled to the shape being cut. `FRACTURE_JAG` on a blade's 12-unit
width put teeth taller than they were wide, which rasterised as a scribble
rather than as a break; the blade takes five shallow teeth against a shield's
seven.

### Commitment stopped being a symbol

The diamond was a *state*: an abstract shape meaning `committed` that a viewer
had to be taught, and which was reported, fairly, as unreadable — "still not
sure what it means as well lol."

It comes back as a **duration**. Committing to a ball takes a moment, and a mark
that draws itself around its own perimeter says that with no vocabulary at all:
a loading bar bent into a shape. Half-drawn is a decision half-made.

A bar also needs its **track**. Without one a half-formed commitment is just a
short line — legible as motion, useless as a fraction, and at nought it rendered
as literally nothing. The track is the same diamond, thinner and dashed, which
is this vocabulary's existing word for *provisional*. So the empty part of the
bar is already saying "not yet" without a second colour or an alpha channel.

A commitment that fails does not fade. It breaks, on the same jagged seam as
everything else — three families breaking three different ways still have to
break in one hand.

### The backdrop: sized to its own mark

Two questions turned out to be one. A rating colour needs somewhere to sit that
is **not** the ink — the ink is doing contrast, and a mark above a head sits
against the lit court on one frame and the dark surround on the next, so tinting
it spends the thing that makes one ink work everywhere. And succeeding needed a
treatment that was not another set of paths per family.

Both are answered behind the mark: a **disc** for an ordinary contact, a
**flare** for one that came off. The flare is the disc plus what it is throwing
off — same radius, tongues on top, longest at the top because heat rises and a
ring even all the way round reads as a stamp. A broken mark keeps the disc: the
grade is already saying it went badly, and a second loud silhouette behind a
shape that is coming apart is two things shouting the same word.

It draws only when the rally has something to say — a grade off neutral, or a
variant off plain. Grade C is *nothing to report*, and a neutral disc behind
each of twelve volis is twelve pieces of furniture.

**Sized per family, and that is what the extent probe bought.**
`tools/run_mark_extent_probe.gd` measures the ink bounding box of every mark and
the radius a circle needs to contain it:

| mark | radius | vs canvas |
|---|---|---|
| eye, nominal | 91 | 84% |
| blade, plain | 111 | 102% |
| shield, plain | 131 | 121% |
| shield, fractured | 139 | 129% |

A single radius sized for the largest is **64% wider** than the smallest mark
needs, so the same grade would read louder behind a shield than behind an eye —
the opposite of what a rating scale is for. `backdrop_scale` derives the share
from each family's authored geometry, which is free and exact; scanning ten
textures at load is a million `get_pixel` calls.

The eye takes no backdrop at all. It is already the loudest thing the layer
draws — a lid, a pupil and a lead in one slot — and a coloured ground behind it
turns a face into a badge.

### Four defects the plates found by disagreeing with a gate

- **A cleaved shield carried *more* ink than a whole one.** The split filtered
  the outline's vertices onto one side of the cut; a side's vertices are
  contiguous only if the closed loop's start vertex sits on the far side. It did
  not, the run wrapped, and the open polyline joined its two ends with a chord
  straight across the shield — a stray diagonal that read plausibly as the cut.
- **Then the fixed cut read as intact with a nick in the rim**, because the old
  drawing had only looked cleaved because of the bug.
- **A vertical break did nothing at all, silently.** `signf` has a third answer,
  and a shield's apex sits exactly at x=27 — the vertex the cut was aimed
  through scored zero, the walk saw no sign change, and the outline came back in
  one piece. No error; just an unbroken shield labelled "fractured".
  `_side_of` has two answers.
- **The flare covered less ground than the disc**, because it was drawn at a
  smaller base radius than the shape it was supposed to be the loud version of.

The gate for a break is width where it broke, not ink count — a fracture *adds*
a seam, and the first version of that gate asked a shattered blade to carry less
ink and failed on a drawing that was right.

### The variants are wired, and the compiler barely reaches them

`CogniticonMotion.variant_for` reads the two axes a cue already carries —
`state` and `affect` — so the rally events decide the variant and nothing else
does. `tools/run_variant_mix_probe.gd` then measures what that actually yields
over 19,559 compiled cues from 240 rallies:

| variant | count | share |
|---|---|---|
| plain | 19,218 | 98.3% |
| ascendant | 310 | 1.6% |
| broken | 31 | 0.2% |

| affect | share | | state | share |
|---|---|---|---|---|
| neutral | 98.4% | | committed | 88.7% |
| pleased | 1.1% | | searching | 5.1% |
| confident | 0.5% | | recognizing | 2.5% |
| — | — | | lost_sight | 0.2% |

**`upset` and `sad` are emitted zero times.** Both branches exist in
`_compile_reactions`, and both sit behind `named_action` — a signature move —
which is only recorded when it comes off. So the only route to a `broken` mark
today is `lost_sight`, at 0.2%: the shattered blade and the cleaved shield are
drawn, gated and wired, and a viewer would see one about once every eight
rallies.

That is a **compiler gap, not a drawing gap**, and it is exactly the half of
the §6 scenario that has no source: "the blockers' shields grey out and cleave"
needs a blocker who has been beaten to read as `upset`, and nothing tells a
blocker they were beaten. `_compile_block_read` has `closed` — how far the wall
actually shut — but the outcome lives on the *attack* event, one contact later.

Deliberately not built in this pass. `affect` feeds `affect_grade`, so making
beaten blockers `upset` recolours the badge tier across every rally at once, and
that wants its own measurement rather than being smuggled in behind a set of
drawings. Logged rather than done.
