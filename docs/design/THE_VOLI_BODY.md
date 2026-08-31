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

### Open questions for a decision

1. Does the pre-serve phase get flat unconditionally, or does the passer go
   poised at the toss? (I would say at the toss: it is the first moment the ball
   can move.)
2. Does a voli who is *travelling* have a stance at all, or does the gait own the
   feet entirely until they arrive? The foot-plant machinery already anchors a
   stance foot, so this is a question about who wins, not about what exists.
3. Is "poised" the same posture for all six body types, or does Ursi -- "wide on
   contact, narrow on movement" -- read differently at rest?

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
usually the sign it is right. It also keeps each body type's silhouette intact,
which `BODY_TYPES.md` needs: its whole premise is that a Cani setter and a Feli
setter should differ visibly, and a kit that flattens them into one outline
would undo that.

### What must not happen

- A kit that hides the body type. If a viewer cannot tell Ursi from Avi at a
  glance in kit, the kit is wrong, not the body.
- Team colour applied by tinting the whole voli. That is the current failure
  with more steps.
- The number becoming the only team signal. It is too small to read at playback
  distance and it is the one part of a kit that is per-voli rather than per-team.

### Open questions for a decision

1. Is there an away kit, and if so does it change hue only or cut as well?
2. Does the kit carry anything besides club identity -- a captain's mark, a
   libero's contrasting shirt? The libero is a real rule and a real reason for a
   second shirt, and it is the one case where the *rules* demand the kit differ.
3. Does the creator let a manager see their voli in club kit before they have a
   club? Q1 currently shows a voli in something; whose colours are those?

## 3. What this does not decide

Nothing here says how either is built, and neither should start until §1's
selector and §2's cut question have answers. Both sections name what must not
happen precisely because the shortcut in each case -- a hand-set pose flag, a
whole-body tint -- is quicker than the real thing and would be very hard to
walk back once every body model depends on it.
