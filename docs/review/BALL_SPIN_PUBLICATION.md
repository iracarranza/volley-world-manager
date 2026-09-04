# The spin was resolved and never published, and the interesting axis is not the one I expected

Measured at `03726c2` by `tools/run_ball_spin_probe.gd`, 150 rallies, seeds
61000-61149, after `_stamp_spin` was added to the serve path and the three
swings.

## What was wrong

`BallSpin` has resolved `axis` and `rate_rps` since it was written. Exactly one
consequence ever left the resolver: `gravity_for`, folded into the flight as a
heavier gravity. Everything else -- the rate, the axis, the two derived
components -- was computed, used to pick a launch, and dropped.

So a topspin serve and a float were indistinguishable to anything downstream,
including anything that might want to draw a spinning ball. `_stamp_launch_state`
copies six launch fields onto the published trajectory and `spin` sits in the
same dictionary, uncopied; and that function is called from **two sites, both
serves**, so no swing published anything at all.

An earlier probe read this as "spin is constant at 0.78 rps" across 25 of 120
serves and zero of 94 attacks. That was measuring publication, not physics, and
would have killed three treatments on the strength of a missing field.

## What the record says now

| family | n | no spin | mean rps | min | p50 | max | mean abs axis | axis max | cut across |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ATTACK | 77 | 36 | 13.77 | 12.70 | 13.24 | 14.51 | **0.453** | **1.000** | **55** |
| SERVE | 32 | 118 | 0.77 | 0.39 | 0.78 | 0.78 | 0.000 | 0.000 | 0 |
| BLOCK | 0 | 36 | | | | | | | |
| DIG | 0 | 26 | | | | | | | |
| RECEPTION | 0 | 118 | | | | | | | |
| SET | 0 | 113 | | | | | | | |

**The families that report nothing are correct rather than incomplete.**
`from_swing` and `from_serve` are the only producers, so a set, a dig, a
reception and a block impart none. A spin treatment on those contacts would be
depicting something the model says is not there.

## The finding: rate barely moves, axis moves fully

**Attack rate spans 12.70 to 14.51 revolutions per second.** That is 1.8 rps of
spread inside a range that runs to `MAX_RATE_RPS` 22.0 -- about 13% of the scale,
with the tenth and ninetieth percentiles nearly touching the extremes. Every
spike in the game turns at essentially the same speed.

**Attack axis spans 0.000 to 1.000, mean absolute 0.453, and 55 of 77 swings cut
across the ball past the handedness lean.** Pure topspin to pure sidespin, most
of the range, most of the time.

This is the opposite of the assumption the ribbon was drafted under. A band
frequency keyed to `rate_rps` would look the same on every attack in the game --
a caption with extra steps, which is the exact failure the treatment was
supposed to avoid. The channel that carries information is **which way the axis
points**, and that one is rich.

Two design consequences, neither of them tuning:

- **The ribbon should depict the axis, not the rate.** The plane a band twists
  in is a direction; its frequency is a speed. The direction is what varies.
- **Sidespin is real and common, so the skew treatment is not dead.** It was
  parked on the grounds that a lateral kick is invisible from a side-on camera.
  That objection stands, but it is now a camera problem rather than an absence
  of anything to draw -- 55 of 77 swings have genuine sidespin on them.

## Three gaps this turned up on the way

**Only 32 of 150 serves publish spin at all.** `_canonical_serve` returns empty
when the geometric resolver reports the serve unavailable, and
`_stamp_launch_state` returns early on an empty launch. So roughly four serves
in five never reach the resolver's launch state, and this probe cannot see them.
Whether that is a serve-resolution gap or an expected fallback is not
established here.

**Every serve that does publish is a float.** Rate clusters at 0.78 with axis
exactly 0.000, which is `from_serve`'s float branch. The vertical slice appears
to contain no topspin server, so the topspin half of the serve model is
unmeasured rather than measured and found narrow.

**The attack's published trajectory carries no `launch_gravity_mps2`.** It reads
0.00 for all 77, because only `_stamp_launch_state` sets that field and it is
serve-only. Whether the attack arc applied spin gravity internally before
publishing is a separate question and is not answered here -- but anything
re-deriving an attack's flight from the record is using 9.8.

**36 of 113 attacks still publish no spin.** Three swing sites are stamped and
they cover 77; the remaining path has not been identified. Recorded rather than
guessed at.
