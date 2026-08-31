# The volis were on their toes because a zero ankle is not a flat foot

> *the ready pose itself feels much too unbalanced because of the volis standing
> on their toes, maybe it needs two modes? one being ready flat footed and one
> being ready poised*

Two things, and only one of them was the design question it looked like.

## The measurement

`tools/sole_contact.tscn` reports how far each shoe is tipped forward of the
orientation the scene authors it at. On the untouched rig, standing still:

| stance | pitch, every body |
|---|---|
| defending | **+53.69°** |
| watching | +19.90° |
| blocking | +17.8 to +18.3° |

Fifty-four degrees is not weight-forward, it is a foot standing on its front
edge. Identical on all six body types, which says it is the stance and not the
body.

## Why

`GaitBiomechanics.resolve` blends both ankles toward **zero** as speed falls,
and its comment says why: a voli standing still "has their feet flat because the
sole and the floor are already parallel". They are not. The shoe hangs off
`Knee`, so it inherits the whole leg chain -- at the defending stance's hip 16
and knee −54 the foot comes out about 38° off, and the projection through the
15° abduction makes it 53.7.

The file already knows the right expression. Its own constant for the walk says
"in stance the sole is held flat -- the ankle cancels hip and knee exactly,
because a planted foot does not rotate with the leg above it", and the stance
phase computes `ankle = -(hip + knee)`. The standing case needed the same
cancellation against the *stance's* joints and got a zero instead.

Applied, blended on `ready_blend` so it arrives exactly as the gait's own ankle
leaves:

| stance | before | after |
|---|---|---|
| defending | +53.69° | **+9.71°** |
| watching | +19.90° | **+3.58°** |
| blocking | ~+18.1° | **+3.6°** |

Nine degrees forward is a poised stance: the weight over the front of the foot,
the heel light and down. Three is a foot under the body. No angle was authored --
the stance says what the leg does and the foot now follows from it.

## Poised begins at the toss

The other half is the design decision in `THE_VOLI_BODY.md` §1, and it needed no
new threshold. `ReadyStance.choose` takes `ball_is_live`, and `match_screen`
computes it from `ServeBiomechanics.TOSS_START` -- the phase where the serve's
own toss already begins. Before it the ball cannot move and nobody has anything
to be ready for, so every body wears `watching`, which exists and is authored for
"a voli watching a ball that is not theirs". Before the toss the ball is nobody's.

Authoring a fourth stance for "flat" was the obvious move and is the one
`ready_stance.gd` says in its own header it will not make: *the stances are not
invented here*.

## Three instruments, two of them confidently wrong

This finding took three tries to measure and the first two produced clear,
plausible, wrong verdicts. Recorded because the pattern matters more than the
result.

1. **Toe and heel as extreme-z AABB corners.** The shoe is a capsule whose long
   axis is y, so its z extent is a few centimetres and an extreme-z corner can
   sit at either end. The two "corners" being compared were mostly different
   heights up the shin. It reported an 11-24 cm "toe up" on every body -- 30 to
   70 degrees -- which is impossible and was the only reason it got caught.
2. **The shoe's local y against world up.** Reasonable, and wrong:
   `SHOE_BASE_PITCH_DEGREES` is 90 because the mesh is modelled lying down and
   stood up by the scene, so the shoe's local y runs *along* the foot. A
   correctly flat shoe reads 90 in that measure, not 0. This one printed a
   confident "heels" for every body and stance, and **a production change was
   made and then reverted on the strength of it** -- the change was in fact
   correct, and the reverted sign was the right sign. It went back in once the
   reference was fixed.
3. **The same axis, minus the authored base.** 0 is a shoe sitting as modelled,
   positive is forward. This is the table above.

The second one is the expensive kind: it did not look broken. It produced a
uniform, self-consistent answer across eighteen rows, and uniformity read as
confirmation when it was really the signature of a constant offset nobody had
subtracted. The check that would have caught it immediately is the one this
repository keeps rediscovering -- *ask the instrument for a case whose answer is
already known*. A shoe with a zero ankle on a straight leg should read zero, and
it would have read 90.
