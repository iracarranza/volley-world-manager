# M8 visual continuity: what playback owns, and what it was inventing

M8's structural layer was certified headless and its visual layer was left open,
on the stated grounds that it needed a person watching. That turned out to be
half true. The drawn ball is reproducible without the app —
`BallPresentation.display_trajectory` takes an event, the next contact, the
authoritative trajectory and the two bodies, and nothing else — so most of the
visual layer is machine-checkable after all, and only the last question is a
matter for eyes.

The witness was a reported serve-reception where the ball appeared to jump.

## The instruments

`tools/run_playback_continuity_probe.gd` rebuilds the drawn ball exactly as the
viewer sees it and asks three questions, per contact family and per serving side:

- **seam** — leg N arrives at a height, leg N+1 departs from one. For one ball at
  one moment those are the same number, so a difference is a visible jump.
- **floor** — a ball nobody touched reached the floor and must be drawn arriving
  there.
- **reach** — the drawn contact against the actor's published body position.

Per side, because three home/opponent drifts in this engine were each one side
quietly not doing what its twin did.

## The measurement that changed the question twice

**First: `success` does not mean "nobody touched it".** The obvious test for an
untouched ball is the next contact's `success` flag. Measured over 180 rallies it
is wrong for four families out of six:

| family | failed | of those, still published a ball |
|---|---:|---:|
| SERVE | 35 | **35** |
| RECEPTION | 4 | **4** |
| SET | 3 | **3** |
| ATTACK | 14 | **14** |
| BLOCK | 59 | 0 |
| DIG | 47 | 0 |

A failed serve is a service error, a failed reception is a shank, a failed attack
is a swing that went out — every one of them touched. Only the block and the dig
fail by not touching. The authoritative test for "did a contact happen" is B0's
own: did it publish a ball.

**Second: the ace is not an untouched ball.** The witness was an ace, and an ace
looked like the obvious no-touch case. It is not:

```
--- seed 300065  outcome ace
    SERVE      actor Ari   success true   outgoing duration 1.083
    RECEPTION  actor Ivo   success false  outgoing duration 1.143  reach_margin 0.172
```

The receiver reached it — the margin is *positive* — and the reception publishes a
ball. This ace is a shank that could not be played, not a serve that hit the
floor untouched. Its far end was already drawn correctly, and the floor-break
count in the before-baseline is over-stated because it used the `success` test
this file has just retired.

What survived both corrections is the seam, which is measured on heights and does
not depend on either.

## The repair: a drawing concession was authoring physics

`terminate_trajectory` cuts a flight at its interception and floors the result at
0.08 s, because a shorter segment cannot be seen. `display_trajectory` then
derived a struck ball's far end by integrating its launch **across that floored
duration**. Measured at attack-to-block:

```
ATTACK->BLOCK   dur 0.080/0.020   vert -15.73
                arrive 1.594   blocker's hands 2.839   gap 1.245
```

The ball's real flight to the block is 20 ms. Integrated across the 80 ms the
drawing asked for, a −15.73 m/s spike falls four times as far as it actually
does, and arrives more than a metre below the hands about to touch it.

The cut duration is now kept unfloored as `physical_duration_seconds` and the
ballistic far end is derived from it. The floor still governs how long the
segment is *drawn*, which is what it was for: stretching time is a concession
between two authoritative states, and it must not move the ball.

| | before | after |
|---|---:|---:|
| BLOCK / home, mean seam | 2.286 m | **1.914 m** |
| BLOCK / opponent, mean seam | 1.753 m | **1.217 m** |
| seam jumps > 0.05 m | 380 of 835 | 378 of 835 |

Two legs' worth of count, and a third off the block's mean gap. The count barely
moves because the residual below is a different cause with the same symptom.

## The second repair, and the witness itself

The first repair moved the block seam and left the reported symptom untouched,
because the symptom was not a seam. It was the *end* of the rally.

A leg with no next contact is a ball on its way to the floor, and
`display_trajectory` defaults its far end to the floor for exactly that reason.
The struck-ball branch then overwrote it — with where the ball *is* once the
published flight time is spent, which for a ball still falling is not where it
stops. Playback held it at that height for `settle_seconds` and `hold_at_rest()`
put it down. A hang, then a snap.

Measured over 180 rallies, both serving sides:

| | before | after |
|---|---:|---:|
| terminal legs drawn stopping above the floor | **56 of 119** | **0 of 119** |
| mean height above the floor | 0.580 m | 0.000 m |
| worst | **2.362 m**, on a serve | 0.000 m |

A serve error hung nearly two and a half metres up for about two thirds of a
second before being snapped to the ground. That is the reported witness, and it
had nothing to do with aces: it is every ball that ends a rally.

The fall time is now solved from the launch rather than chosen, and the outro
does not grow to match — `MatchScreen.settle_seconds` had already been
lengthening the last window by exactly this fall, and now returns zero for it
because the ball has arrived instead of waiting to.

**Found by a constructed fixture, confirmed in production, and the order
mattered.** 220 rallies produce no ball dying in the net, so the terminal cases
were built rather than waited for; the constructed one showed a 1.33 m jump. Its
duration was a hand-chosen number, though, so it was treated as a lead and not a
finding until production was measured — where the real figure turned out to be
nearly twice as bad.

## Coverage: by situation, not by family

The continuity baseline reports contact families. M8 asks for situations, which
is a different list — a family can be well covered while a situation inside it is
never drawn. Both serving sides, 220 rallies:

| situation | legs | with a seam | breaks | mean | worst |
|---|---:|---:|---:|---:|---:|
| serve→receive | 188 | none | — | — | — |
| ace | 3 | none | — | — | — |
| serve→touch→shank | 3 | 3 | 3 | 0.387 | 0.453 |
| receive→set | 167 | 167 | 166 | 0.354 | 1.831 |
| set→attack | 198 | 198 | 144 | 0.271 | 0.946 |
| attack→floor | 29 | 29 | 0 | 0.000 | 0.000 |
| attack→block→dig | 169 | 169 | 0 | 0.000 | 0.000 |
| stuff | 22 | 22 | 0 | 0.000 | 0.000 |
| dig/coverage | 112 | 112 | 0 | 0.000 | 0.000 |
| terminal out | 61 | 29 | 0 | 0.000 | 0.000 |
| terminal floor | 159 | 159 | 74 | 0.173 | 0.808 |
| recovery_debt leg | 86 | 86 | 15 | 0.057 | 0.837 |

**"With a seam" is a separate column because it has to be.** A seam needs a leg
on either side of it, and a situation classified on the rally's first leg — the
serve, and therefore every ace — has nothing before it to disagree with. The
first version of this table printed those as "0 breaks, mean 0.000", which reads
as a clean result and is no result. That is the same instrument failure this file
documents twice more.

Three situations the sweep never reached, built deterministically instead:

| constructed fixture | arrive | depart | verdict |
|---|---:|---:|---|
| wipe/tool, attack→block | 1.974 | 2.742 | jumps 0.769 m — FD-006 |
| overpass, reception→set | 2.267 | 2.267 | **continuous** |
| terminal net, attack→none | — | — | **repaired above** |

## What remains, and why it is not a presentation defect

The instinctive reading of the residual is that presentation overwrites a height
the resolver publishes — `end_height_meters` is on every trajectory, and
`display_trajectory` computes its own. Measured against the resolver's published
value:

| pair | n | \|published − drawn\| | \|published − body\| |
|---|---:|---:|---:|
| RECEPTION→SET | 46 | **0.000** | 0.140 |
| DIG→SET | 9 | 0.014 | 0.404 |
| BLOCK→DIG | 9 | 0.016 | 0.016 |
| SERVE→RECEPTION | 51 | 0.412 | **0.033** |
| ATTACK→BLOCK | 50 | 1.415 | 2.062 |
| SET→ATTACK | 56 | 2.108 | 2.108 |

The non-struck families match published truth exactly. The struck families do
not — and the reason is that the two numbers are **defined to be different**. The
resolver says so itself, at `rally_simulator.gd:1394`:

> `end_height_meters` is not read as this flight's endpoint. `BallFlight.from_trajectory`
> reads it as the height of the **next contact**, and the comment inside
> `_ball_trajectory` already names the conflict: *"Those are different numbers and
> choosing between them is `CONTACT_AND_BALL_FLIGHT.md`'s unresolved item 5, not
> something to settle as a side effect of owning the launch."*

`|published − body|` of 0.033 on the serve is that comment confirmed by
measurement: the published field already *is* the next contact's body height.

So presentation is not duplicating an answer the resolver gave. It is computing
the one quantity nobody has assigned an owner: **where the ball actually is at
the moment it is touched.** `CONTACT_AND_BALL_FLIGHT.md` §5, *Realized segment*,
is marked TARGET — unbuilt. The seam is that unbuilt item becoming visible.

This is therefore **not F1** and does not reopen `FIRST_DRAFT_COMPLETE`. There is
one authority for every fact that has an authority; the seam is a fact that has
none yet, and the governing document already knows it.

## The decision that is not ours to make here

At a block, the ball's ballistic arrival and the blocker's reach disagree by a
mean 1.2–1.9 m. Two ways to draw that, and they say opposite things:

- draw the ball where its flight puts it, and a block is visibly touching air;
- draw it at the hands, and the flight visibly jumps.

The first is honest and would make a simulation gap plainly visible — the
resolver's block interception does not constrain the ball's height, so a touch
can be asserted on a ball that is not there. The second is what happens today and
hides that behind a jump. Choosing is a product decision about what the match
view is *for*, and implementing the first would need §5 built, which is a
simulation change this pass is scoped out of.

Recorded, not chosen.

## Certification

- **Full suite — 2,141 pass, 0 fail**, the same count as `main`. No gate moved.
- `run_canonical_sideout.gd` — **PASS, 7/7**, figures identical to before both
  repairs: 7 boundaries, 0 lineage breaks, 0 out of order, 5 actors travelling,
  0 facts reconstructed.
- Simulation untouched by construction and by inspection: `display_trajectory`
  duplicates its input and is called only from `match_screen` and from
  `cognition_compiler`, which runs *after* the rally resolves. No resolver path
  reaches it; the resolver's own `BallPresentation` calls are to
  `launch_speed_mps` and `pace_pressure_multiplier` on its own trajectories,
  which this pass does not touch.

## Still presentation-only, still open

- **Contact-iff.** `_apply_contact_poses` poses the next contact's actor with a
  wind-up-to-contact pose with no success test, so the 59 blocks and 47 digs that
  never touched the ball are drawn making a contact. Arguably a defender who
  cannot reach still lunges, so the honest fix is a distinct *reaching-and-missing*
  pose rather than suppressing the pose — which is animation work, not authority
  work.
- **The seam itself**, above, pending §5.
