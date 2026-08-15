# Readable bodies

Body language a viewer can read, and why the poses that exist are not being
read today.

## 0. The observation this starts from

> *Movement seems to be mostly biomechanically informed, but some smaller or
> faster movement -- especially the difference between reaching / off-axis /
> taking a knee -- are either too infrequent for me to know the difference
> between, or actually might read as incidental rather than intentional, like
> something the player's eye might pass over and not register rather than
> something they can read and understand.*

Both halves of that are worth separating, because **one of them is measurably
false and the other is the real problem.**

### It is not frequency

Measured over 300 rallies and 447 floor contacts, `contact_posture` comes back:

| posture | share |
|---|---|
| `moving` | 30.2% |
| `reaching` | 26.0% |
| `planted` | 22.1% |
| `off-axis` | 21.7% |

Near-uniform. A viewer watching a single set sees every one of these many times
over. Whatever is wrong, it is not that the rare ones are rare.

### It is legibility, and the code already knew it was supposed to be

`player_actor_3d.gd` says, above the dig postures:

> *The depths are ordered so the two that matter tactically -- planted against
> reaching -- are unmistakably different at a glance from a court camera.*

That is the correct goal, stated. The report is that it is not being achieved.
So this is not a missing intention; it is an intention that was implemented at
the amplitude the biomechanics produced, which is not the amplitude a viewer
needs.

## 1. Fidelity and legibility are different problems

This engine's rule is that numbers come from models. That rule is right and
nothing here proposes weakening it. But a pose has a second job the model does
not know about: it has to be **recognised, from a court camera, in the fraction
of a second it exists.**

Those two requirements do not conflict, because they live at different layers.
The simulation owns what the contact *was*. The drawing owns what a viewer can
*tell*. This repository already has that seam and already uses it twice:
`PlatformAim.posture_for` is explicitly "a second, purely geometric opinion",
and the full-stretch reach band was widened in playback rather than in the
classifier precisely so that outcomes did not move to fix a drawing.

**Caricature belongs on the drawing side of that seam.** Everything below is a
gain applied to a true value, never a change to the value.

## 2. Why a correct pose can still be unreadable

Three reasons, and they need different fixes.

### 2a. Silhouette, not joint angles

A viewer at camera distance reads an **outline**, not a knee angle. Planted,
reaching and off-axis currently differ mostly *inside* a similar outline: same
standing height, same base, arms in front. The four properties that actually
change a silhouette are:

- **base width** -- how far apart the feet are
- **height** -- how far the head is below standing
- **axis** -- whether the shoulders are level or tilted
- **asymmetry** -- whether the arms are together in front or one is out

Each posture should own **one** of those as its primary tell and push it hard:

| posture | the tell | pushed |
|---|---|---|
| `planted` | level shoulders, narrow-ish base, platform square in front | the *reference*; deliberately unexaggerated |
| `reaching` | asymmetry and height -- one side extended, body past its base | far |
| `off-axis` | axis -- shoulders tilted, platform out to one side | far |
| `knee` | height -- head dropped sharply, one leg folded under | far |

The discipline that makes this work is that they are **different axes**. If all
four are exaggerated on all four properties, none of them reads, because
contrast is relative. `planted` staying plain is what lets the other three be
legible.

### 2b. A pose too brief to read

A shape that exists for 0.15 s cannot be recognised however distinct it is. Two
standard remedies, both of which have somewhere to live here already:

- **Anticipation.** A beat of preparation before the contact tells the viewer
  what is about to happen, so the contact itself confirms rather than informs.
  The signed contact phase already runs -1 to 0 across the incoming flight; this
  is a matter of putting more shape into the negative half.
- **Follow-through, held.** The aftermath work split a window into flight and
  aftermath. The aftermath is exactly where a contact's shape can be *held*
  rather than immediately eased back to the gait -- which is what makes a fast
  action readable in every sport broadcast ever cut.

### 2c. One channel where there should be two

If the difference between a reach and a knee matters to the player's decisions,
it should not be carried only by a pose. `COGNITICONS.md` exists for exactly
this: a vocabulary for what a voli is showing. Anything that is *information*
rather than *flavour* deserves both channels.

## 3. Expressive body language

Requested, and it belongs in the same project -- with one advantage over §2. A
gesture is a **novel shape** rather than a variation on a stance, so it is
easier to read than any posture delta will ever be. This is the higher-yield
half of the work.

| gesture | who | when | what it tells the viewer |
|---|---|---|---|
| **Raised hand, calling for the ball** | the target hitter | during the set's flight | who the set is going to, *before* it gets there |
| **Point at the target** | setter | as they release | where the offence is committed |
| **Point to direct** | middle, libero | between contacts | that somebody is organising the floor |
| **Hands up, waiting** | front-row blockers | while the opponent builds | that the wall is ready and reading, distinct from the block itself |
| **Turn and track** | everyone | continuously | already built -- head, torso, then a step |

Two rules keep this from becoming noise:

1. **A gesture is a consequence, not decoration.** The hand goes up because the
   setter is choosing, and the choice already exists in the model. If a gesture
   cannot be derived from something the simulation decided, it should not be
   drawn.
2. **Budget them.** The action vocabulary already has a notability budget for
   captions and the same shape applies here: twelve players all gesturing every
   rally is a crowd, not a communication.

`hands up, waiting` is already logged separately as the blocker's idle pose, and
it is the one to build first -- it covers two front-row players for most of
every rally.

## 4. More pronounced movement overall

Also requested, and the same principle governs it: the *distance* a voli covers
is simulation and must not be inflated, but the *shape* of covering it is
drawing. Deeper knee drive, more trunk counter-rotation, a wider arm carry at
speed -- none of which changes where anybody ends up or when they get there.

The one hard constraint: whatever amplitude gets added has to survive
`step_quantised_fraction`. Pushing a gait harder while the feet are quantised
into steps produces a body that bounces harder without travelling differently,
which reads as effort rather than as speed.

## 5. What this does not settle

- **How far is too far.** Caricature has a limit and past it bodies read as
  cartoons. There is no measurement for this; it is a judgement made by looking,
  and it should be made against the two-frame test -- can you name the posture
  from a still?
- **Whether `planted` staying plain is enough contrast**, or whether it also
  needs a tell of its own once the other three are pushed.
- **Left-handedness.** Every gesture above is described right-handed and the
  clipboard-mirroring entry is the same unsolved problem.
