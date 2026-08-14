# Volleyball fidelity

**The current primary development track.** What "convincing volleyball" means,
how to check it, and the one sequence that has to be made convincing first.

This document owns the *standard*. It does not own the measurements — those are
in `docs/review/PROBE_HANDOFF.md`, and duplicating them here would produce two
sets of numbers that disagree within a month. Where a finding is named below it
is named as a pointer, not restated with figures.

---

## 0. Why the priority moved

The project has a lot of conceptually credible surrounding systems: housing,
food, staff, scouting, recruitment, the day, the phone. Most of them are
designed further than they are built, and all of them are *worth* building.

The risk is not that those are wrong. It is that the rally engine can be

> **rules-correct volleyball**

without yet being

> **six athletes convincingly solving volleyball problems together.**

Everything else in the game is downstream of the second thing being true. A
housing decision that changes recovery is only interesting if a tired voli is
visibly a worse volleyball player, and *visibly* is doing the work in that
sentence.

---

## 1. Two levels of "volleyball"

The simulator increasingly answers the first question well:

| level | question |
|---|---|
| rules | did the rally follow the rules of volleyball? |
| **fidelity** | **does this look like six athletes playing volleyball?** |

The second needs things the first never asks for:

- sensible occupation of volleyball space, not merely legal positions
- responsibilities visible **before** contact, not inferred after it
- approaches that begin before the set is released
- blockers reading and closing before the attacker contacts
- defenders establishing a base before the swing, not moving after it
- setters with usable lanes to run into
- the previous contacter clearing out of the next action
- body and action state that is **continuous across ball-event boundaries**

That last one is the architectural point, and it has its own section (§5).

---

## 2. The milestone

> **"I can watch a normal rally and argue about the volleyball decision instead
> of arguing about whether the athlete could physically have been there."**

That is a far stronger criterion than more events, more animations, more
tactical buttons or more systems, and it is the one to hold the next stretch of
work against. Any change that does not move it is not on this track.

---

## 3. The canonical side-out

Do not attempt to prove the whole sport at once. **Make one ordinary side-out
sequence convincing**, end to end:

```
medium float serve
  → three-person reception
    → setter transition
      → several plausible attack options
        → opposing block reads and forms
          → floor defence establishes base
            → attack
              → kill / block / dig
                → transition, if the ball is still playable
```

Nothing exotic. No jump-serve ace, no monster block, no scrambling
seven-contact rally. The ordinary case is the one a viewer sees a hundred times
an hour and is therefore the one that has to survive being looked at.

**Validate on controlled, hand-authored, neutral rosters.** Career generation,
extreme morphology, unusual traits, food, housing and long-term development all
have to be kept out of the frame, because every one of them can either hide the
volleyball question or masquerade as an answer to it. A convincing side-out
between two unremarkable teams is the result; a convincing side-out that needed
a 210 cm outlier is not.

---

## 4. The rubric

The check is a **volleyball-literate viewer, with debug text and captions
removed**, answering these from the picture alone. Anything that can only be
answered from a caption is a caption doing the simulation's job.

**Pre-serve**
Who is receiving? Who is being protected? Where is the setter? What rotation
and shape roughly exist?

**Reception**
Whose ball is this? Who is supporting? Is the setter transitioning somewhere
sensible?

**Set**
Which attackers are available? Which are actually approaching? Why is the setter
standing, moving, or jump-setting? Does the chosen set make spatial sense?

**Attack**
Did the hitter begin the approach early enough? Is the body plausibly placed
relative to contact? Is the ball struck from a believable point?

**Block**
Who read? Who committed? Who closed? Is a late blocker *visibly* late?

**Defence**
Who owns line, cross and short? Are defenders set before contact? Does a dig
look like **defending a space** rather than chasing a coordinate after the hit?

**Transition**
Does the previous contacter clear? Does the setter regain a lane? Do the hitters
recreate their approaches?

`READABLE_BODIES.md` is the companion for *why* a correct pose can still fail
this — fidelity and legibility are different problems, and this rubric is the
legibility half stated as questions.

---

## 5. The architecture note, which is a direction and not a rewrite

**The ball has contact-to-contact phases. Athletes act continuously across
them.**

Several recent fixes are all the same fix seen from different angles: the
setter's head start, blockers beginning to form before the attack contact,
approaches overlapping the set's flight, stance transitions, floor recovery
surviving past the contact window, blocker timing surviving multiple playback
windows.

Each was a case where something had been scoped to *one ball flight* and the
athlete needed it to outlive that.

**No rewrite is proposed.** The direction is only this:

> Do not add new architecture that assumes *one ball flight = one complete
> player action window*.

`RALLY_PHYSICAL_TIME.md` and `OFF_BALL_MOVEMENT.md` carry the specific machinery.

---

## 6. Dependency order for this track

From `PROBE_HANDOFF.md`'s continuations, with the fidelity items folded in.
Details and current measurements stay there.

1. **Body centre distinct from ball contact point.** Top of the list. Unblocks
   the net-encroachment question and matters for blocking, setting, wingspan and
   body type.
2. **The canonical side-out validation** (§3), on neutral rosters, against the
   rubric (§4).
3. **Responsibility**: the previous contacter yields and clears; ready stance as
   a directional state; short-ball ownership.
4. **A dug ball gets a real trajectory** — which removes the transition set's
   fallback window, its missing head start and its missing jump-set apex at once.
5. **Increasingly overlapping per-voli actions** (§5).
6. **Lateral and backpedal locomotion** that reads as volleyball movement — the
   plant correction currently sits on its own clamp, which is the §0 shape.
7. **Tactical A/B validation** — see `TACTICS_AND_TRAINING.md`. A tactic is not
   certified because a hidden coefficient moved; it is certified when the
   visible volleyball behaviour changes in the predicted direction.

Also folded in from the same list: splitting `DEFENSE` into a dig and a coverage
event type, which has already produced one wrong conclusion and will produce
more.

---

## 7. What this track is not

It is not a freeze on design. `docs/BACKLOG.md` carries the focus hierarchy and
is explicit that the club-life designs stay valid and are simply waiting.

It is also not a request for more animation. An animation that makes an
impossible arrival look smooth makes the fidelity problem *harder* to see, which
is worse than the jerk that revealed it.

> The question is never "did something plausible get drawn". It is "could this
> athlete have been there, and does the picture say why they were".
