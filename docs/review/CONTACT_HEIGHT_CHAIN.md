# The contact-height chain

Extends the block's §5 repair to the other families. The block reached §5 by
publishing an intersection its feasibility test had already proved; this asks
what every other family knows about where the ball was, and finds that the answer
is a chain with one break in it.

## The census

`tools/run_contact_authority_census.gd`, 300 rallies, both serving sides, read
entirely from published metadata and the shipped `BallPresentation.contact_height`
call — so a family that looks authoritative there is authoritative in the game.
Full BEFORE table in `docs/review/contact_authority/`.

```
RECEPTION  consumes launch + start_resolved (251/251, derivable)
           publishes resolved + launch (251/251)   <- fully authoritative
SET        consumes that resolved flight (159 known)
           publishes default, launch 0 (159/159)   <- the break
ATTACK     consumes default, launch 0 (273/273)    <- cannot derive anything
BLOCK      consumes launch + default; repaired last pass by its own key
```

The set receives an authoritative ball and hands the attack one that has
forgotten both its heights and its launch. Everything downstream was a body proxy
because the information was **destroyed upstream**, not because it was never
computed.

**Two things on record turned out to be wrong, and the census is how.**
`end_height_meters` is not "already the body's number" as FD-006 said — it is the
1.0 m default on all but 273 of 1259 legs, and the 0.033 m agreement measured on
serve-to-reception is a coincidence between that default and a hip-height
platform contact. And RECEPTION is not a body proxy by necessity: every one of
its incoming legs carries a real start height and a launch.

## The repair, and its size

`_set_arc` is handed `release_height_meters` and `hitter_contact_height_meters`
and solves `BallFlightModel.duration_for_apex` **between** them. It returned
neither. Returning them, and passing them at the six sites that build a set
flight, is the whole change.

Nothing was authored. The duration above is already the time to fall from the
apex to `arrival_height_meters`, so a flight drawn to any other far end disagrees
with its own published length — the two heights were load-bearing before they
were published, just invisibly.

Result on the attack, from that alone:

| | before | after |
|---|---|---|
| ATTACK/home | body-proxy, 135 of 135 breaking, mean 2.065 m | **authoritative**, 0 breaks, mean 0.021 m |
| ATTACK/opponent | body-proxy, 138 of 138 breaking, mean 2.110 m | **authoritative**, 0 breaks, mean 0.018 m |

Then one forward pass, `_stamp_realised_contact_heights`, copies each incoming
flight's resolved far end onto the next contact as `ball_contact_height_meters`,
and `BallPresentation.contact_height` prefers it over the body. It is a copy and
not a computation: it reads only flights that say they know
(`height_source == "resolved"`), so a family whose writer never resolved its
heights is left alone rather than given a number invented in the pass. That is
the difference between propagating authority and minting a second one.

Drawn seams, 180 rallies:

| | M8 baseline | block pass | this pass |
|---|---|---|---|
| RECEPTION both | 144 breaks | 144 | **0, 0.000** |
| SET/home | 53 breaks, 0.336 m | 53, 0.337 | 59, 0.293 |
| SET/opponent | 52 breaks, 0.193 m | 52, 0.187 | 65, 0.420 |
| ATTACK both | 0 | 0 | 0 |
| BLOCK, ball met | 129 | **0** | 0 |
| total seam jumps | 378 | 309 | **184** |

The set row rising is the finding described below, not a regression: the pass's
own arc disagreeing with its corrected contact, which the platform proxy had been
concealing.

Outcome mix unchanged to three decimals on every figure — contacts per rally
4.807, kill 0.610, dig 0.412, stuff 0.108, serve error 0.181, ace 0.010,
reception quality 0.434, block touch 0.818. This pass moved the record, not the
rally. Canonical side-out 7 of 7.

## What did not work, and why it is recorded

The contact's **own** outgoing launch height looks like a better source than the
incoming leg's far end — it is by definition where the ball was when the contact
launched it, and it is available on families the incoming leg cannot speak for.
It was tried and rejected on measurement:

```
family      legs  |flown-launch|  |flown-body|  |launch-body|
RECEPTION    162          0.366         0.366         0.000
SET          110          0.000         0.003         0.003
```

On the reception the published launch height equals the body proxy **to three
decimals** — it is the platform wearing a flight's clothes, not an independent
statement about the ball. Preferring it moved no reception seam and widened the
opponent set's from 42 breaks to 63. Backed out.

The measurement that settles it is in the same table: on the SET, the incoming
ball evaluated at the contact and the set's own launch height agree to 0.000,
which is what a coherent contact looks like. On the RECEPTION they differ by
0.366 m, so one of them is not about the ball.

## The reception, closed — and what closing it exposed

The reception looked unreachable and was not. Two readings had to be corrected:

- **The serve flight is already terminated at the pass.** Measured: the serve's
  published end time and the reception's own stamp agree, so evaluating the
  flight at its far end *is* evaluating it at the contact. An earlier reading in
  this document said the flight ran on to the landing; that was wrong, and the
  measurement that settles it is that the time-based and end-based evaluations
  come out identical (0.713 / 0.000 / 2.951 on all three statistics).
- **A `start_resolved` flight can state its far end.** It knows where it started
  and how it left; integrating its own launch across its own duration is
  evaluating it, not extrapolating past it. That is the same integration
  `BallPresentation` already performed to draw the leg, moved to the side of the
  boundary that owns the fact.

RECEPTION went **144 breaks to 0**, both sides. Total drawn seams 246 to **184**,
against 378 at the M8 baseline.

**And it opened a set seam of 0.29–0.42 m, which is a finding rather than a
regression.** The reception's outgoing arc is solved from the *platform's*
height. Once its contact says the ball's height instead, the arc departs from
somewhere the contact no longer claims. That disagreement was always in the
record; the platform proxy was hiding it by being wrong at both ends at once, so
the two errors cancelled in the drawing and nothing could see either.

Writing the contact height back onto the reception's own flight was tried and
does nothing useful: every family reaching that point publishes a launch, and the
launch was solved *from* the start height it shipped with, so overwriting only
the height leaves a flight disagreeing with its own length. An honest gap beats a
worse record.

## The residual, exactly

**The pass's own arc, 124 legs, 0.29–0.42 m, appearing as a set seam.** It is one
thing and it is stated above: the reception's outgoing flight is solved from the
platform's height, and the contact now says the ball's. Closing it means
re-solving the pass from the ball's height rather than the body's.

That is not a seam repair and it is not free. `pass_apex_meters` feeds the set's
release clamp (`minf(set_release_height, pass_apex_meters)`), so moving the pass's
launch moves what the setter is allowed to do with it, which moves rally
outcomes. It is simulation work with a measurable cost, and it wants its own pass
with its own before-and-after — exactly the shape this one refused to do by
guessing.

Also open, and smaller: the `SET_DECISION` path's 114 legs publish no outgoing
flight at all, so nothing downstream of them can resolve. And 60 block legs still
score a "seam" that is not one — the ball went past the wall, so the leg into the
event does not end at the event.
