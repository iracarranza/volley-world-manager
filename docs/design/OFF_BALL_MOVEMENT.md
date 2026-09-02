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

It turns out to matter.

#### Measure the flight, not the event

The first instrument for this counted phase targets **per event**, and it was
the wrong instrument in a way worth recording, because it is the failure mode
this repository keeps rediscovering: *a probe that measures the wrong channel
reports a clean result for a dirty system.*

`_build_movement_plan(event, next_contact)` draws the leg from `event` to
`next_contact`, and reads its targets off **`next_contact`**. So a target on the
RECEPTION event moves people during the *serve's* flight, and a target on the
SET event moves them during the *pass's*. Counting publication per event cannot
see that, and it reported a fixed serve receive while the formation was being
drawn at the wrong moment — or, on the serve event itself, never drawn at all:
nothing precedes the first contact of a rally, so that leg does not exist.
**Measured, 400 serves of 400 had no preceding flight.**

The honest instrument walks consecutive contacts and asks how many volis the
leg between them actually moves. Measured over 400 rallies:

| flight drawn | before | after |
|---|---|---|
| SERVE → RECEPTION | 3.42 | **6.00** |
| RECEPTION → SET | 1.00 | **4.52** |
| SET → ATTACK | 5.00 | 5.00 |
| ATTACK → BLOCK | 2.75 | **6.88** |
| BLOCK → DEFENSE | 4.42 | 4.23 |
| DEFENSE → SET | 0.67 | **4.15** |
| **mean, of twelve** | **3.20** | **5.29** |

#### What each leg needed, and where it came from

Nothing below is new geometry. Every one of them was already being computed and
then either discarded or attached to the wrong contact.

- **The serve's flight** wanted the receive formation.
  `_receive_formation_positions` already asked `CourtConstants` for the whole
  six-slot shape and kept only the passers, because all it needed was somewhere
  to aim the serve. `_receive_formation_map` makes the same call and keeps it
  whole.
- **The pass's flight** wanted the transition. Front-row volis release to the
  approach mark `_approach_start_position` would put them on for the lane
  `_fallback_assignment` says is theirs; back-row volis take base. The hitter is
  excluded because their release is already staged on the SET event, and moving
  them twice cost the ATTACK phase's timing ratio 1.0912 → 1.2111 before the
  gate caught it.
- **The spike's flight** wanted cover — and the intentions were already written
  down. Every `DefensiveAssignment` carries an
  `attack_coverage_responsibility`: *cover nearest attacker*, *cover assigned
  hitter*, *take second contact*, *release for transition*. Until now the only
  reader was `_resolve_attack_coverage`, choosing the one voli who plays a
  recycled ball; the other four had a stated intention and nowhere to stand.
  `_cover_phase_map` reads the responsibility each voli already has. *Release
  for transition* is the one that makes it read as volleyball rather than as
  everyone converging — the voli the tactic told to leave goes the other way.

In every case `_reached_point` decides how much of the target a voli actually
covers in the time available, on the same movement model that times and charges
every other journey in the engine. An attack flight is often under a quarter of
a second, so most cover answers are "barely moved" — which is the correct
picture, and is the information a viewer needs to see who committed.

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

**The implementation spec for this half is
`docs/implementation/OFFBALL_RESOLVER_AUTHORITY.md`.** It carries the phase
split, the six named holes in priority order, and the gates. What follows here
is the design reasoning it is built on.

**One number this section could not have, and now can.** The table above counts
volis *moved* per leg and reports a mean of 5.29 of twelve. The companion
question -- how many the resolver has an *opinion* about -- is 6.89 of twelve
over 1,760 flights at `6ae238e`, and twelve minus that is precisely the
population `_apply_cheat_steps` invents a destination for: 1,194 legs of 1,507
and two thirds of all drawn travel. The two figures measure different things and
neither supersedes the other; the second is the one that says how much is left.

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

**That shape now exists and is not a separate dictionary.** `_travel_intent`
publishes `intent`, `progress`, `traversal_seconds` and `window_seconds` into the
`*_phase_intents` map that already sits beside the targets, and every one of
3,223 off-ball legs carries it. The vocabulary the code settled on is
`covering / defending / blocking / preparing_attack / receiving / setting`, and
the spec adds `chasing` and `recovering` to it; `base` and `release` are not
added, because a base return is already resolver-published ground and *release
for transition* is a branch `_cover_phase_map` already takes. What is missing is
not the shape. It is that only 6.89 of twelve get an entry at all.

### The consequence the design cares about

Once the other five are placed with honest arrival, a shanked pass stops being
automatically unplayable. Whether the ball is recovered becomes a question about
who was near it, how fast they are and how far the pass went — which is the
question the game is supposed to be asking, and which its own movement and
reachability models are already equipped to answer for one player at a time.

That is the change: not new physics, but the existing physics applied to five
more people per side.

## What this unlocks next

Each phase map decides *why* it sends a voli where it sends them and then
publishes only the where. `_cover_phase_map` branches on
`attack_coverage_responsibility`; `_transition_phase_map` branches on front row
versus back; `_receive_formation_map` branches on passer versus staging versus
short coverage. Those branches are an intention layer, computed for every voli
on every flight and discarded at the moment it becomes a coordinate.

Returning the reason alongside the position is what gives the cognition layer a
continuous read on all twelve -- measured today at 0.75 volis of six carrying a
live cue at any instant, against an ask of six. See
`docs/design/COGNITICONS.md`.

## Not in scope here

- Collisions between defenders. Two players converging on one ball is a real
  situation and a real animation problem; it is a separate entry.
- Second-contact recovery *rules* — who is allowed to play an overpass, what
  counts as a double. The intention layer above is about where people go, not
  about legality.
