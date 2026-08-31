# The voli body

How a voli stands, and how a voli dresses. Written before either is built,
because both are decisions about volleyball and about identity rather than
about code, and both have a wrong answer that is easy to reach by accident.

Companion documents, and what each already owns: `BODY_TYPES.md` is the
*typology* -- which archetype a voli is and what that costs them in attributes.
`READABLE_BODIES.md` is the *legibility of action* -- whether a viewer can tell
a reach from a knee. `OFF_BALL_MOVEMENT.md` owns what the twelve do between
contacts. This document owns the body itself: its posture at rest and its
surface.

## 0. The models are authoritative

The Voli models reconciled in `074a15f` are the canonical body from here on.
That is a decision with reach, so it is written down rather than assumed: it
fixes what a voli looks like in the creator, in match playback, in headshots and
in the journal, and every later question about bodies is asked against these
rather than against whatever preceded them.

Two consequences worth stating now. Anything measured against the old bodies is
provisional until re-measured -- the platform release census in particular, which
counted a 108-degree single-frame drop before `player_actor_3d.gd` gained a
hundred and thirteen lines. And the contact heights the rally resolves at read
`height_cm` through `player_generator.gd`, not the mesh, so adopting these models
does **not** move any number in the rally. Those two facts are easy to confuse
and they point opposite ways.

## 1. How a voli stands

### The observation

> *the ready pose itself feels much too unbalanced because of the volis standing
> on their toes, maybe it needs two modes? one being ready flat footed and one
> being ready poised*

### What is already settled, and must not be re-litigated

`OFF_BALL_MOVEMENT.md` §2 retracted an earlier claim that the ready stance was
never reached, and the retraction is checked rather than argued:
`GaitBiomechanics.resolve(0, 0.0, 0.0)` returns hip 16°, knee −54°, abduction
15°, torso −0.30 rad at a `gait_blend` of exactly 0.00. The stance reaches the
court. The complaint that produced that retraction -- "the ready stance is not
observed at all" -- turned out to be about stillness, not posture.

**This is a different observation and should not be mistaken for that one.** It
is not that the stance is absent or that nobody moves. It is that the weight is
in the wrong place while the stance is held.

### What a ready stance actually is

A defensive ready position puts the weight *forward*, over the balls of the
feet, with the heels light. Light is not lifted. The heels stay in contact, or
within a centimetre of it, because the stance has to be holdable for the length
of a serve toss and because the first movement out of it is often backwards --
which is impossible from the toes.

Standing on the toes is a real volleyball posture, but a different one: it is
the last instant before a jump or a lunge, and it is expensive. A body cannot
hold it and does not try. Drawing it as the resting state reads as a permanent
flinch, which is exactly the "unbalanced" in the observation.

### Two modes, and the question that matters

The proposal is right. The question the implementation turns on is **what
selects between them**, and it should not be a mode flag someone sets by hand.

The honest selector is *time pressure*, because that is what it is in life. A
passer waiting through a server's routine is flat-footed. A defender watching a
hitter load is poised. The difference is how soon this voli might have to move,
and that is a quantity the resolver already publishes -- window seconds, arrival
margin, the traversal times C6 added. It does not need a new one.

So the rule to aim at:

> A voli is **poised** when something they may have to reach is imminent, and
> **flat** otherwise. Imminence comes from the published window, not from a
> per-pose flag and not from a new threshold.

**What must not happen:** a new authored magnitude for "how imminent is
imminent". If the boundary cannot be derived from a window the resolver already
states, that is a finding about the published record -- the same class as every
seam closed this week -- and the answer is to publish the missing quantity, not
to invent a constant here.

### Decided

1. **Poised begins at the toss.** Before it the receiving side is flat; the toss
   is the first moment the ball can move, and it is what a passer actually reacts
   to.
2. **A travelling voli has no stance.** The gait owns the feet until they arrive.
   The foot-plant machinery still anchors a stance foot -- this only settles who
   wins when both could speak, and it is the gait.
3. **One posture for all six body types.** Poised is poised; nothing about Ursi's
   contact width or Simi's touch axes changes what a body does at rest. The body
   types differ in what they can *do*, which is the correction §2 records, and a
   per-type resting pose would be that mistake in another form.

## 2. How a voli dresses

### The observation

> *the "colored shape" doesn't really work anymore, especially for vegi since
> they are already radically differently colored. allowing them to wear kits
> properly will help them stay differentiated while still being legibly on a
> team*

### Why the current approach fails, stated precisely

Species identity and team identity are both being carried by **hue**, and hue is
one channel. A Feli in a teal shape reads as a teal cat; a Vegi whose own colour
is already saturated has nothing left to say with the shape, because the loudest
colour on the body is not the team's.

That is not a tuning problem. Two independent facts are competing for one
signal, and no palette fixes that. They need separate channels.

### The separation

- **Species keeps the body**: silhouette, proportion, own colour, the muzzle and
  the wing and the ears that `b3a855f` made specific.
- **Team takes the garment**: a shape that reads as *clothing* -- a shoulder
  line, a hem, a sleeve edge, a number -- laid over the body rather than
  replacing its colour.

Then a Vegi in a teal kit is a Vegi wearing teal, which is what a viewer needs,
instead of a teal Vegi, which is a contradiction.

### The hard part is six body plans

A kit has to survive Vegi, Feli, Avi, Cani, Ursi and Simi. Avi is the case that
decides the approach: a sleeve and a wing want the same space, and `b3a855f`
deliberately made a wing a wing rather than an arm. Any garment that assumes
two arms in the usual place will either clip through the wing or erase it.

Two ways to go, and I would take the second:

1. **One deformable garment** fitted to each body at build time. Fewer assets,
   and it will fight Avi forever.
2. **One kit design, six cuts.** Same colours, same number placement, same
   material treatment; different tailoring per body plan, with Avi's cut opening
   for the wing the way a real garment would be made for a body that shape.

The second is more work up front and is also how actual kit works, which is
usually the sign it is right.

**A correction to an earlier draft of this section, because getting it backwards
matters.** That draft said a kit must not flatten silhouettes because
`BODY_TYPES.md` needs a Cani setter and a Feli setter to differ *visibly*. It
does not. That document is about **playstyle and attributes** -- a Cani setter is
grounded and chases a bad pass down; an Avi setter reaches a higher ball and
opens hitting geometry a Cani cannot. The difference is what they can do, not
what they look like.

So the silhouette argument stands on its own feet rather than borrowing that
one. A viewer who cannot tell an Avi setter from a Cani setter cannot predict
which balls this team can still run an offence from, and that is a *gameplay*
legibility loss -- the same currency `READABLE_BODIES.md` deals in. The kit must
not flatten the body because the body is telling the viewer what the setter is
capable of, not because the typology asked for a portrait.

### What must not happen

- A kit that hides the body type. If a viewer cannot tell Ursi from Avi at a
  glance in kit, the kit is wrong, not the body -- because the silhouette is
  what says which balls this voli can still play.
- Team colour applied by tinting the whole voli. That is the current failure
  with more steps.
- The number becoming the only team signal. It is too small to read at playback
  distance and it is the one part of a kit that is per-voli rather than per-team.

### Decided

1. **The away kit is a hue change only.** Same six cuts, same number placement.
   Nothing about playing away changes what a body is shaped like, so nothing
   about it should change the tailoring.
2. **The libero wears the away kit.** The rules demand a contrasting shirt and
   this already exists, so it costs one rule and no new garment: the libero is
   the one player on the home side wearing the away hue.
3. **The manager does not wear a kit at all.** They wear formal dress.

### Two garment classes, which is the finding in that third answer

Q1 shows a voli in club teal before that manager has a club, and the reason is
not a missing colour -- it is that **a kit was the only clothing that existed**,
so anyone who needed dressing got dressed as a player. A manager in a strip is a
category error a viewer reads instantly, and no palette fixes it.

So the system has two classes over the same six cuts:

- **Kit** -- players. Club hue home, away hue for away fixtures and for the
  libero. Number. The sleeve and shorts already described.
- **Formal** -- managers. Not a strip, not club-coloured, and not carrying a
  number. Whatever a person on the bench who is not playing wears.

They share the tailoring problem and nothing else, which is convenient: the six
cuts are built once for the body plans and both classes hang off them. Avi's
wing opening is the same opening in a jacket as in a singlet.

### What formal is

A **collared shirt and trousers** over the same six cuts, in a neutral that is
not the club's hue, carrying no number. The club is present as a small mark
rather than as the garment's colour.

That last clause is the whole point and is worth stating separately, because it
is the rule the kit exists to establish read from the other side. A player says
which club they play for by wearing its colour; a manager is *attached* to a club
without being one of its eleven, so the club appears on them as a badge would --
present, small, and not the thing you see first. A manager in club teal was the
failure this section opened with, and dressing them in a neutral is not a palette
choice, it is what keeps the two roles legible at playback distance.

Nothing here needs a second tailoring pass: a collar is a ring at the neck
opening the six cuts already have, and trousers are the shorts cut continued past
the knee. Avi's wing opening is the same opening in a shirt as in a singlet.

## 2b. What got built, and the one thing that surprised us

Both sections are built. Two notes, because in each case the measurement moved
the work somewhere the design did not anticipate.

**The stance was half a design question.** §1 assumed the fix was choosing
between two postures, and that half is built exactly as decided --
`ReadyStance.choose` takes `ball_is_live` off `ServeBiomechanics.TOSS_START`, so
poised begins at the toss and no threshold was invented. But the *reason* the
stance looked unbalanced was not the choice of posture at all. The gait blended
both ankles to zero at rest, on the stated grounds that a standing voli's sole is
already flat, and it is not: the shoe hangs off the knee and inherits the leg's
fold, which put every body 53.7 degrees onto its toe. Cancelling hip and knee at
the ankle -- the expression the walk already uses -- brings defending to 9.7 and
the other two to 3.6. See `docs/review/READY_STANCE_FOOT.md`.

So the two modes were real and needed, and they were also not the bug. Worth
keeping in mind next time a posture reads wrong: the stance may be right and the
thing under it wrong.

**The garments needed the outline to be one number.** §2's six cuts are built,
and building them surfaced that a shell sized as a *multiple* of the limb radius
cannot clear an outline grown at a *fixed* 0.018 m -- they agree at one radius
and nowhere else. The ink weight now lives in `body_type_models.gd` as
`body_ink_metres`, because the file that authors garments is the one that has to
clear them. See `docs/review/GARMENT_INK_CLEARANCE.md`.

## 3. What this does not decide

Nothing here says how either is built. Both sections name what must not happen
precisely because the shortcut in each case -- a hand-set pose flag, a whole-body
tint -- is quicker than the real thing and would be very hard to walk back once
every body model depends on it.

What a formal outfit *is* was the last thing open here and is now answered in §2.
What it means for who the manager is -- whether they choose it, whether it says
anything about them -- still belongs to `CHARACTER_CREATION.md`.
