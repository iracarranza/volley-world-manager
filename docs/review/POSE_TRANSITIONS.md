# Filming a rally to measure the pose transitions

`tools/probe_pose_transitions.gd` samples ten joints on all twelve actors off
the live rig while `MatchScreen.load_and_play_rally` runs, on two rallies that
walk the whole chain -- a home serve (`SERVE RECEPTION SET ATTACK BLOCK POINT`,
seed 970001) and an opponent serve that also reaches a dig (seed 970000). The
question it was built for: does a voli *move* between poses, or *arrive* in the
next one.

## The instrument was wrong three times first, and each error pointed the wrong way

Recorded because the numbers each version produced were all plausible, and two
of them would have closed the investigation with the opposite conclusion.

1. **A fixed sample count over a variable rally.** `MAX_SAMPLES` was 900 at
   1/30 s, thirty seconds of sampling on a rally of five. Every sample past the
   end landed in the "did not move" column, and the rig read as **97% still** --
   which says a body that never moves, and would have retired the whole question
   as "nothing to smooth". Fixed by sampling while `playback_active` is true.
2. **Gaps keyed on the joint name.** Twelve actors are read at the same sample
   index, so consecutive rows come from different bodies and every gap between
   one movement and the next collapsed to one frame -- a uniform `0.002 s` down
   the column, which reads as continuous motion. The gap between two movements
   is a property of *one voli's* joint. Fixed by keying on actor and joint.
3. **The nominal interval as the denominator.** Under xvfb with software GL and
   twelve outlined actors the renderer holds **3.6-4.3 fps**, so a sample lands
   every 0.25 s while the code divided by the 1/30 s it had asked for. That
   inflates every rate about eightfold, and it inflated them into the snap band:
   the first run reported 14 "snaps" that were ordinary limb movement.

The third error is the one worth keeping, because fixing it exposed a fourth:
at 4 fps the probe *cannot see a one-frame snap at all*. It is sixty times
coarser than the thing it was built to detect, and it duly reported zero of
them. Joint angles are a function of **rally** time, so the fix is to film in
slow motion -- `PLAYBACK_SPEED = 0.1` buys 53 samples per rally second out of a
renderer that draws four a wall second, and every rate is divided back out.

**A zero from an instrument that cannot resolve the phenomenon is not a
negative result.** That is the same failure as a threshold outside its own
distribution: it does nothing, and it does nothing silently.

## What the corrected film says

Two rallies, 4.74 s and 6.75 s of rally time, 72,960 samples.

```
joint             n      mean       p50       p95       max     snaps
torso          7296       6.9       0.0      29.4    1888.8         0
l_arm          7296      35.7       0.0     149.4    5380.6        13
r_arm          7296      36.4       0.0     167.6    5380.6        14
l_elbow        7296      15.8       0.0      71.2    3833.1         1
r_elbow        7296      19.1       0.0      80.7    3833.1         1
l_leg          7296      11.4       0.0      56.2    1630.3         0
r_leg          7296      11.3       0.0      55.0    2227.6         0
l_knee         7296      24.3       0.0      71.4    2520.0         0
r_knee         7296      24.8       0.0      71.3    2520.0         0
head           7296      68.6      23.0     149.0    6853.9        19
```

```
joint         moved       of    share mean gap s   p50 step   p95 step
torso          1313     7296    18.0%      0.062       0.21       3.42
l_arm          1341     7296    18.4%      0.061       0.63      17.31
r_arm          1347     7296    18.5%      0.060       1.22      13.52
l_elbow        1063     7296    14.6%      0.077       0.49       7.24
r_elbow        1199     7296    16.4%      0.068       0.66       8.00
l_leg          1217     7296    16.7%      0.067       0.35       5.96
r_leg          1218     7296    16.7%      0.067       0.53       6.09
l_knee         1241     7296    17.0%      0.066       0.63      15.58
r_knee         1241     7296    17.0%      0.066       0.66      15.60
head           5724     7296    78.5%      0.024       0.56       3.33
```

**The limbs and the head are on two different clocks.** Every limb changes on
14-18% of samples -- roughly nine times a rally second, a 0.11 s cadence -- and
the head changes on 78.5%, which at this sampling rate is every frame. The head
is driven continuously by `look_toward`; the limbs are not driven continuously
by anything.

**The typical movement is small and the tail is enormous.** A limb's median
turn when it moves at all is half a degree; its p95 is 13-17 degrees in one
frame, and the largest are near a hundred. 48 samples cross 3000 deg/s, twice
the shoulder speed of a spike at the top of the swing; 279 more sit in the
1200-3000 band.

## Where the tail lands, and what it is

```
side      joint       degrees       deg/s   leg
opponent  head          124.0        6836   04 / 08   SET   t=2.60s
opponent  head          124.0        7239   04 / 08   SET   t=2.60s
opponent  head          124.0        6966   02 / 08   RECEPTION   t=1.19s
home      head          124.0        6374   03 / 06   SET   t=2.66s
opponent  head          124.0        6883   01 / 08   SERVE   t=0.00s
home      r_arm          96.9        4834   03 / 06   SET   t=2.66s
home      l_arm          96.9        4834   03 / 06   SET   t=2.66s
```

Two signatures, and both are exact repeats rather than distributions -- which is
what an angle being **reassigned** looks like, as against one being turned.

**124.0 degrees is `2 x HEAD_YAW_LIMIT_DEGREES`.** The neck clamp is 62.0
(`player_actor_3d.gd:327`), and the recurring figure is the head pinned at one
limit and then at the other, in a single frame, with nothing in between. The
clamp exists so a neck never reaches ninety and reads as broken; nothing bounds
the *rate*, so the clamp itself becomes the snap. It appears on five separate
legs and on both sides, so it is not one bad target.

**Both arms move by an identical 96.9 degrees in the same frame.** Two limbs
turning the same amount to the tenth of a degree simultaneously is one pose
being swapped for another, not two arms swinging.

The tail distributes across **all twelve legs** of the two rallies -- 32 at a
SET, 49 at an ATTACK, 58 at another, 21 at a BLOCK, 19 after POINT COMPLETE. It
is not one broken transition. It is every pose change.

## What is missing, and what is not

`set_pose` (`player_actor_3d.gd:2412`) writes every joint from scratch each
frame out of the per-action biomechanics modules: gait first, then the contact
pose over the top when `is_contact_actor`. **The per-limb architecture already
exists** -- there is no animation to dismantle, and nothing to gain by
"treating poses as directions per limb" because that is what they already are.

What does not exist is continuity *in time* across a pose change.
`StanceTransition` is exactly the mechanism, and its own header names the
defect -- *"nothing tweens it because nothing holds the previous one"* -- but it
is wired to two entry points only: `ready_stance` (`:110`) and floor recovery
(`:2208`). The moment `is_contact_actor` flips, or a contact pose ends, the
joints jump from the module's values to the gait's with nothing between, and no
clock holds the previous pose. The head has the same hole one level down: no
`StanceTransition` and no rate limit, only a clamp.

So the repair is not a new system. It is the third and fourth entry points into
the one that is already written and already deriving its own durations from the
distance between two joint sets.

## Reproducing

```bash
xvfb-run -a $GODOT_BIN --path . --rendering-method gl_compatibility \
  res://tools/pose_transitions.tscn
```

Never `--headless`: there is no rig to read off.
