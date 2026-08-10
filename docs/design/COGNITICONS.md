# Cogniticons: a continuous read on twelve volis

> There should be a consistent and legible flow of information on every home
> voli at all times.

## Where it stands, measured

Sampled at 30 Hz across 200 rallies, counting how many volis have a live
`PlayerCognitionCue` at each instant:

| | mean, of six |
|---|---|
| home volis with a live cue | **0.75** |
| opponent volis with a live cue | **0.82** |
| distinct home volis ever given a cue | 6 of 6 |

Two readings, and the second is the surprising one.

**The ask is 6.00 and the game is at 0.75** — one voli in eight, at any given
moment. It is not that some volis are never instrumented; all six appear
eventually. It is that cues are attached to *interesting moments* and there is
nothing in between, so eleven of twelve people on court are blank most of the
time.

**And the opponent currently carries more cue-time than the home side**, which
is backwards relative to the design. Whatever restriction is applied to the
other side of the net, it has to start from the home side being the
better-instrumented one.

State and attention mix over the same sample:

```
committed 22581   searching 16427   reacting 4360   recognizing 3308
calling     972   deciding    372   lost_sight  24

position  19270   ball      13702   setter     7234
hitter     3710   none       2322   teammate   1806
```

`lost_sight` — the BLIND marker — fires 24 times in 47,000 cue-samples. That is
the correct order of magnitude for a marker that should mean something when it
appears, and it is worth protecting when the volume goes up by eight times.

## The architecture is already right, and this changes nothing about it

`PlayerCognitionCue`'s own rule is the one that makes sword-and-shield possible:

> **A cue never names a picture.** `state`, `attention_kind` and `affect` are the
> vocabulary; an eye shape, a call symbol or a colour is a renderer's reading of
> them. The 2D badge and the 3D billboard consume the same cue and must agree on
> meaning without agreeing on geometry, which is only possible if nothing here is
> a sprite name.

So a shield, a sword, a diamond and a filling bar are **readings**, and they
belong to `match_court_3d` and `tactical_court`, not to the model. What the
model owes them is a vocabulary rich enough that the reading is unambiguous.

The second rule matters just as much here, because a continuous read has more
opportunities to lie:

> **A cue carries only what its player perceived.** Grading an outcome is allowed
> after the decision boundary the cue describes, never before it.

An ambient intent glyph is a claim about what a voli is *trying* to do. That is
always honest. It stops being honest the moment the glyph reflects whether the
attempt will work.

## What the vocabulary is missing

Today a cue carries: `state` (what mental stage), `attention_kind` and
`attention_player_id` / `attention_position` (what they are looking at),
`visibility`, `certainty`, `urgency`, `affect`, `punctuation`.

None of those answers the question the sword and the shield are asking, which
is **what is this voli preparing to do with their body.** It is a third axis,
orthogonal to both of the existing two: a voli can be `committed`, attending the
`ball`, and either dropping into a dig posture or winding up to swing. Same
state, same attention, opposite pictures.

### 1. `intent` — a closed vocabulary, one per cue

```
receiving       taking the first ball
defending       in a dig posture, ball on the other side
covering        collapsed behind our own hitter
preparing_attack  off the net, getting available to swing
approaching     in the run-up, committed to a swing
blocking        at the net, closing or waiting to close
setting         going to, or at, the second ball
watching        none of the above, and honest about it
```

`watching` is deliberately in the list. A vocabulary with no term for "nothing
in particular" invites the compiler to invent an intent to fill a gap, and an
invented intent is worse than a blank one — it is the drifting-volis defect
moved from the legs to the icons.

### 2. `progress` — a float, 0 to 1

The sword filling vertically as approach distance is gained is a *progress*
quantity, and nothing in the cue carries one. One float, meaningful only for
intents that accumulate:

| intent | what progress means | already computed by |
|---|---|---|
| `approaching` | run-up distance covered | `ApproachMechanicsModel` |
| `blocking` | close toward the wall position | the block's own close terms |
| `covering` | collapse toward the cover mark | `_cover_phase_map` + `_reached_point` |
| `setting` | travel toward the release seat | `_spatial_setter_choice` |

For every other intent it is zero and the renderer draws a plain glyph.

This is also where the honesty rule bites, and it bites well: progress is *how
far along the attempt is*, never *how likely it is to succeed*. A hitter who
will arrive late still fills their sword — they are running — and the lateness
shows up as the sword not being full when the ball arrives. That reads correctly
without the icon knowing the outcome.

## The tie-in: the intents are already computed, then thrown away

This is the point, and it is why the off-ball movement work is the right thing
to build this on.

**Every phase map is a statement of intention that is currently converted into a
coordinate and discarded.** The map knows *why* it sent each voli where it sent
them, and then publishes only the where:

| already decided, in code | intent it means |
|---|---|
| `_receive_formation_map`: passer seam / front-row staging / short coverage — the formation builder branches on exactly these three | `receiving` / `preparing_attack` / `covering` |
| `_transition_phase_map`: front row to the approach mark, back row to base | `preparing_attack` / `defending` |
| `_transition_phase_map`: the chase, when the second contact has no margin | `receiving` |
| `_cover_phase_map` reading `attack_coverage_responsibility`: *cover nearest attacker* / *cover assigned hitter* | `covering` |
| the same field: *release for transition* | `preparing_attack` |
| the same field: *take second contact* | `setting` |
| `_block_wall_positions` and the wall staging | `blocking` |
| `_floor_phase_positions` | `defending` |

Nothing in that table needs inventing. It is a second return value on functions
that already run, for every voli, on every flight — which is precisely the
coverage the ask requires, because as of the off-ball work those maps now place
between four and seven volis on every drawn leg.

**So continuity is not a new system. It is publishing the reason alongside the
coordinate.**

## Continuity as an invariant, not an aspiration

"At all times" is testable, and it should be tested, because 0.75-of-six is
exactly the sort of thing that reads as fine in a screenshot and is obviously
wrong in motion:

> At every sampled instant between the first contact and the last, every home
> voli on court has exactly one active cue.

Two halves, and both matter. *At least one* is the coverage requirement. *Exactly
one* is the legibility requirement — overlapping cues on one voli mean the
renderer picks by `_precedes`, and a picture chosen by a tie-break is a picture
nobody designed.

That gate is what turns cues from decoration into a layer, and it is the reason
to add the intent axis before adding any more moments: **a cue stream that must
tile cannot be built out of highlights.**

## The worked example, since it is the clearest statement of the flow

The setter through one first-ball sequence, as the vocabulary would carry it:

| when | attention | intent | state | progress |
|---|---|---|---|---|
| serve in the air | `ball` | `watching` | `searching` | — |
| pass leaves the platform | `ball` | `setting` | `recognizing` | travel to the seat |
| arriving at the ball | `hitter` | `setting` | `deciding` | 1.0 |
| ball released | `hitter` | `covering` | `committed` | collapse |

Only the third row exists today, via `_compile_setter_scan`. The other three are
the gap, and all three are derivable from state the resolver already publishes —
the staged release seat, the pass trajectory, the cover responsibility.

And the two around them, which the ask describes directly:

- A back-row voli watches the passer, then moves to cover and **holds shield**:
  `attention: teammate` → `attention: ball, intent: covering` → `intent:
  defending`. Two of those three transitions are already the phase maps firing.
- A front-row voli sees the receiver commit and **starts preparing to attack**
  while the ball is still down: `intent: preparing_attack` the moment
  `_transition_phase_map` sends them to their approach mark, then `approaching`
  with a filling progress once the set is up.

## The opponent: restricted, but not fictional

`audience` already exists with `private` / `public` / `observable`, and
`active_by_player_for_spectators` already filters on it — `match_court_3d` uses
the filtered sampler and `tactical_court` uses the unfiltered one, which is the
correct split of coach's-eye versus spectator's-eye.

The rule this ask implies:

**Opponent cues are emitted at `observable` only, and carry `intent`, facing and
`visibility` — never `certainty`, never `attention_player_id`, and never the
interior states `deciding` or `recognizing`.**

The reasoning in the ask is right and worth preserving: whether an opponent is
in a defensive posture *is obvious from the court*, so withholding it would be a
fiction rather than a fog. What is genuinely hidden is what they have decided
and how sure they are. So the other side of the net gets shields, swords and a
head that points somewhere — and no diamonds, no confidence, no read.

That also fixes the inversion in the measurement above: the home side gains a
continuous stream while the opponent gains only the observable half of it, and
the home side ends up the better-instrumented one, as it should be.

## The risk this ask creates, stated so it can be designed against

**Constant information is how you make nothing legible.** Going from 0.75 glyphs
to 12 is a sixteenfold increase in ink, and the first casualty would be the
things that currently read: the BLIND marker at 24 appearances in 47,000
samples, the call, the moment of decision.

The answer is a two-tier hierarchy, and it should be a rule the renderer is held
to rather than a matter of taste:

- **Ambient tier — `intent`.** Always present, small, low contrast, changing
  rarely. This is the sword and the shield. Its job is that a glance anywhere on
  court tells you what that voli is doing, and that *nothing draws the eye*.
- **Punctuating tier — `state`, `punctuation`, `affect`.** Appears, is loud,
  goes away. Deciding, calling, losing sight, reacting. Its job is to be the
  only thing moving when it happens.

If the ambient tier ever competes with the punctuating tier, the ambient tier is
wrong — too saturated, too large, or animating when it should be still. The
existing markers are the calibration target: whatever is done to the twelve
must leave `lost_sight` as startling as it is now.

## Order

1. **`intent` and `progress` on `PlayerCognitionCue`**, with `intent` a closed
   vocabulary beside the existing ones and `watching` in it from the start.
2. **Return the reason from the phase maps.** Each one already branches on it;
   this is a second value, not a second pass.
3. **Compile the ambient stream from those reasons**, one tiling cue per voli
   per flight.
4. **The continuity gate** — every home voli, exactly one active cue, at every
   sampled instant. Add it with step 3 rather than after, so the number it
   protects is never allowed to regress from 6.00.
5. **The opponent restriction**, at `observable`, intent and facing only.
6. **Renderer: the two tiers**, with the ambient tier's contrast set against the
   existing punctuating markers rather than in isolation.
7. **`progress` for the four intents that accumulate**, which is where the
   filling sword arrives.
