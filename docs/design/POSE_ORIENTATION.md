# Pose orientation: which way an arm actually points

Short, and worth its own file because the mistake it records was invisible for
the entire life of the rig and was found by a camera move rather than by reading
the code.

## The convention

`PlayerActor3D` faces **-Z**. Both shoes sit at `z = -0.06`, and `set_pose`
turns the actor with `atan2(-dx, -dz)` for the same reason.

A limb hangs down its parent's local **-Y**. Rotating it about **+X** by `theta`
puts its tip at:

```
up = -cos(theta)
z  = -sin(theta)          # negative z is FORWARD
```

So **positive X rotations swing a limb forward** and negative ones swing it
back. Rolling about **+Z** by `theta` moves the tip to `x = sin(theta)`, so a
**positive roll moves a limb toward +X** -- which brings the *left* arm inward
and the *right* arm outward.

## What was wrong

Every arm angle in the file had the opposite sign. The dig platform, the set,
the block, the serve and the attack swing all pointed **behind** the player:

| pose | was | pointed | now |
| --- | --- | --- | --- |
| dig platform | -51 | backward | +51 |
| set | -118 | backward | +118 |
| block | -175 | backward | +175 |
| serve contact | -145 | backward | -190 |
| attack swing | -175 → -80 | backward, and swinging *down behind* | -160 → -260, over the top |

The platform's roll was inverted too: the two arms were rolled *apart*, so a
"platform" was a shrug.

## Why nobody saw it

**The only tool that photographed a pose stood behind the players.**
`run_body_type_preview.gd` put its camera at `z = +8.4` while the rig faces -Z,
so every reference image of every pose was taken from the back. From back there,
two arms swung out behind the body overlap and read as a platform in front,
and a swing travelling backward reads as travelling forward.

The instrument was mirrored, so everything it certified was mirrored. The dig
was reviewed and approved from those images.

Three things follow, and they generalise past this file:

- **A preview that can only see one side has not verified the pose**, it has
  verified a silhouette. The tool now shoots from -Z, and the dig gets the
  elevated angle a match is watched from, because a platform aimed at the camera
  is end-on and invisible.
- **The sign of a rotation is a claim, and claims get checked numerically.** The
  table above was produced by evaluating `(-cos, -sin)` for each angle, which
  took a minute and would have caught this at any point in the last several
  months.
- **Symmetric geometry hides orientation bugs.** These bodies are near
  mirror-symmetric, so a backwards limb looks like a plausible limb. The knee
  and the elbow are the first joints asymmetric enough to give it away.

## Elbows

The arm is two bones (`Elbow` under each arm, mirroring `Knee` under each leg),
split `UPPER_ARM_SHARE = 0.46` so the lower segment is slightly longer -- it
carries the hand as well as the forearm.

Bend is **diagnostic, not decorative**:

| pose | elbow | why |
| --- | --- | --- |
| ready | 17 | nobody stands with locked elbows |
| dig | **0** | a platform is two forearms joined flat; any bend and the ball leaves at an angle nobody chose |
| set | 84 | hands at the forehead, the classic triangle |
| block | 4 | a block that bends gets driven back through the net |
| attack | 112 → 6 | cocked behind the head, opening through contact: a whip, not a windmill |
| serve | 96 → 8 | same, shallower |

The pair that most needs it is **dig against set**. Both are "arms in front of
the body", and locked-against-folded is the whole difference between them at any
distance the game is watched from.
