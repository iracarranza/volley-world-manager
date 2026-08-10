# Off-ball movement: the other ten players

A rally has twelve people on court and the simulation has an opinion about
roughly two of them. This document is about the other ten — what they should be
doing, what the code currently does instead, and where the missing model would
have to live.

## The observation

A serve is received at 8% quality. The pass is a shank. On a real court, four
people move immediately and none of them are the passer: the setter releases
toward where the ball actually went, the outside abandons their approach and
opens up to cover, the middle turns to chase, the libero steps into the space
the setter left. Some of them will not reach it. They go anyway, because the
alternative is conceding a ball that was still playable.

In playback, all ten stand still.

The concern this raises is the right one and it is not a rendering concern: a
poor first contact currently produces an *unplayable* situation as a matter of
structure rather than as a consequence of anybody's geometry. Nobody attempts
the second ball because nobody was ever asked to.

## What is actually there

Two separate gaps, and they need separating because they have different fixes.

### 1. The resolver publishes positions for almost nobody

Playback moves a player only when something authoritative says to. That rule is
correct and was hard-won — the code it replaced lerped every player toward the
action by a fixed fraction (0.08 front row, 0.15 back, 0.18 for a block), which
is twelve volis drifting for a reason nobody could name. `match_screen`'s own
comment is explicit that the replacement for invented movement is *nothing*, and
that "if serve-receive movement turns out to matter, the fix is for the resolver
to publish it, not for playback to make it up."

It turns out to matter. Measured over 400 rallies:

| event | n | carries phase targets | share |
|---|---|---|---|
| SERVE | 400 | 0 | 0.000 |
| RECEPTION | 384 | 0 | 0.000 |
| SET | 517 | 241 | 0.466 |
| ATTACK | 517 | 434 | 0.839 |
| BLOCK | 434 | 198 | 0.456 |
| DEFENSE | 308 | 218 | 0.708 |

**Mean players given a position per event: 1.77, of twelve on court.**

Serve receive — the phase in the screenshot, and the phase a viewer watches most
closely because it is where every rally starts — has a publication rate of
exactly zero on both sides. There is no underlying opinion for playback to draw.

### 2. Correction: the ready stance is fine

**An earlier version of this document claimed the ready stance was sampled once
per flight and that off-ball joints went unwritten for the whole of it. That was
wrong, and it is left here rather than deleted because the reasoning that
produced it is a trap worth seeing.**

The reasoning was: joints are only written by `set_pose`; during a flight
`set_pose` is called for the contact actors; `reset_player_poses()` — which
poses everybody — appears *after* the loop. Each of those statements is true.
The conclusion does not follow, because `_apply_contact_poses` runs every frame
inside the loop and its own first line is `reset_player_poses()`. Every actor is
posed every frame, and has been all along.

Checked rather than reasoned about, `GaitBiomechanics.resolve(0, 0.0, 0.0)`
returns hip 16°, knee −54°, abduction 15°, torso −0.30 rad — the full ready
stance, at a `gait_blend` of exactly 0.00. It reaches the court.

So the observation that prompted this — "the ready stance is not observed at
all" — is not about the pose. It is about the **stillness**: twelve players
correctly crouched in a defensive posture and none of them going anywhere reads
as a frozen court, and the missing thing is the movement, not the stance. Which
is §1, and is the whole of the real work.

## What the model needs

The two gaps want fixing in the opposite order to how they were found.

### Pose every player every frame

The cheap half, and it is nearly free: off-ball actors need `set_pose` called on
them inside the flight loop, not after it. Their speed estimate is already
correct and already decaying; the gait model already knows what a stationary
player looks like. This alone turns ten statues into ten people in a defensive
posture whose legs settle under them when they stop.

It changes nothing about where anybody stands, which is why it is separable and
should land first.

### Give the resolver an off-ball opinion

The larger half. The rule "playback draws what the resolver decided" is right
and must not be relaxed — so the resolver has to decide more.

What is missing is not per-player pathfinding. It is a **phase intention** for
each of the six players on a side, derived from the same things the resolver
already knows:

- **Role and rotation.** Where a setter, libero, middle and two pins are
  *supposed* to be at each phase is a formation, and formations already exist
  (`_receive_formation_positions` builds one for serve receive today — it is
  used to aim the serve and then discarded rather than published).
- **The ball's actual destination.** `_reached_point` already computes, for the
  claimant, how far they get in the time available. The same function applied to
  the other five with the same arrival gives five more honest answers — most of
  them "not far enough", which is exactly the information a viewer needs to see
  that the ball was *contested* rather than conceded.
- **The phase they are anticipating.** An outside hitter during serve receive is
  not moving toward the ball at all; they are moving toward their approach mark.
  That intention is already computed downstream, in the approach model. It is
  produced too late to be drawn.

The natural shape is a per-contact `phase_intentions` dictionary alongside the
existing `home_phase_targets`: one entry per player on court, each carrying a
target, the intention that produced it (`cover`, `approach`, `chase`, `base`,
`release`) and whether they expected to arrive. Playback then draws all twelve
with no new authority, and the caption layer gains something it currently cannot
say — *who else went for it*.

### The consequence the design cares about

Once the other five are placed with honest arrival, a shanked pass stops being
automatically unplayable. Whether the ball is recovered becomes a question about
who was near it, how fast they are and how far the pass went — which is the
question the game is supposed to be asking, and which its own movement and
reachability models are already equipped to answer for one player at a time.

That is the change: not new physics, but the existing physics applied to five
more people per side.

## Not in scope here

- Collisions between defenders. Two players converging on one ball is a real
  situation and a real animation problem; it is a separate entry.
- Second-contact recovery *rules* — who is allowed to play an overpass, what
  counts as a double. The intention layer above is about where people go, not
  about legality.
