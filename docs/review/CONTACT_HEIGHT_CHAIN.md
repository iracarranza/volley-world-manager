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

## The third repair: the platform resolver reads the ball

The set seam above was not irreducible, and treating it as such was the wrong
call — corrected here rather than left standing.

`_platform_contact_result` is the shared resolver for every platform family
(reception, dig, coverage), and it took its contact height from
`pass_contact_height_meters(digger)` — the passer's own body. The reception site
says why in its own words: the trajectory's endpoint height was "ambiguous", so
the body's number was used rather than make either meaning of
`end_height_meters` authoritative by accident.

**That deferral had expired.** The ambiguity is what this pass resolved: the
serve's flight terminates at the pass, and a flight that resolves its start and
publishes its launch states its far end. So the resolver reads the ball
directly, with the body kept as the fallback for a flight that resolves neither
end and for a derivation that lands at or below the floor.

One function, `realised_flight_end_height`, shared between the resolver and the
forward pass — so the height a contact is *resolved* at and the height it is
*drawn* at are one derivation rather than two that agree by inspection.

| | before | after |
|---|---|---|
| SET/home drawn seams | 59 | **0** |
| SET/opponent drawn seams | 65 | 47 |
| total drawn seams | 184 | **102** |

**This one moves rally outcomes, which is why it was measured rather than
assumed.** Feeding a solver its correct input changes what the solver returns;
that is an ordinary migration consequence, not a new magnitude, and the test is
whether a governed bound breaks. None did:

| | before | after | band |
|---|---|---|---|
| dig rate | 0.412 | 0.416 | **0.35–0.55 gate** |
| stuff rate | 0.108 | 0.106 | **0.08–0.14 gate** |
| serve error | 0.181 | 0.181 | **0.12–0.20 gate** |
| kill rate | 0.610 | 0.630 | advisory |
| contacts per rally | 4.807 | 4.814 | advisory |
| block touch | 0.818 | 0.830 | advisory |
| swing balance | 0.932 | **0.888** | advisory, near 1.00 |

The swing-balance move is the one worth watching and is recorded as an
observation rather than acted on: it is a home/opponent symmetry indicator and
it moved *away* from 1.00.

## Certified

**2,174 checks pass, 0 fail** at `10bfbdd`. Canonical side-out 7 of 7. Drawn
seams 378 at the M8 baseline to **102**, with block contacts, ATTACK both sides,
RECEPTION both sides and SET/home all at zero.

The count is worth reading twice here because two consecutive deltas mean
opposite things. 2,163 to 2,170 authored no checks at all -- the gate was
appended after `test_runner.gd` loaded -- so that seven is entirely sampling
gates drawing more, which is the signature of the platform resolver changing what
rallies do. 2,170 to 2,174 is exactly the four the gate adds, so publishing the
wall's reaches moved no population, which is the signature of a pure metadata
addition. Both readings exist only because both predecessors were recorded.

## Four instrument defects, all mine, all the same fault

Worth a count rather than four asides. Every one is a value measured against the
wrong quantity -- `FAILURE_MODES.md` §0 -- committed by tools written to find
exactly that:

1. **The census compared against the raw `end_height_meters` field**, a 1.0 m
   placeholder on a `start_resolved` flight. It reported a serve-to-reception
   defect the drawn path does not have.
2. **The census scored the block against the incoming flight's far end**, which
   was never the block's authority -- a swing that beat the wall ends somewhere
   the contact never was.
3. **`_contact_posture` tested `event.success`**, the contact's outcome rather
   than whether the ball was met, so every service error and shank was drawn
   reaching for a ball it had just struck. That one was in production, not a
   probe.
4. **A gate asserted the ball cleared the hands against a wall that was not
   there.** `wall_reach_heights` was on the ATTACK event and the assertion read
   the BLOCK event, so its loop never ran. It would have passed on any engine
   including a broken one, and the only reason it did not ship green is that the
   same gate carried a fourth assertion whose whole job was to prove the sample
   was non-empty. That guard failed; the three substantive assertions passed.

The lesson is the guard, not the fix. A check that cannot fail is worse than no
check, and the cheapest way to find one is to assert that its population exists.

## Two of those were in the census itself

Both are the same fault this repository logs most — measuring against the wrong
quantity — and both were in the tool I built for this pass:

- It compared the proxy against the raw `end_height_meters` **field**, which for
  a `start_resolved` flight is the 1.0 m placeholder rather than the answer. That
  reported a serve-to-reception defect the drawn path does not have. It now calls
  the same `realised_flight_end_height` the resolver does.
- It scored the **block** against the incoming flight's far end, which was never
  the block's authority — a swing that beat the wall ends somewhere the contact
  never was. The block answers to its own proved intersection, and the row now
  says `authoritative by own proof`.

## The residual, exactly

**One thing, and it is an asymmetry rather than a missing owner.** `SET/opponent`
reads 73 of 139 legs breaking at a 0.161 m mean, worst 1.014, against
`SET/home` at 7 of 139 and 0.005 m. The ball's height at the set has an owner on
both sides now; one side's two answers disagree. Filed as **FD-009** rather than
kept inside FD-006, because "no owner" and "two owners that differ" are different
defects and this repository has repaired three of the second kind in this packet
alone.

**Where it is not**, checked rather than assumed: both sides call the same
`_reception_pass_result` with symmetric arguments in the same order, so the pass
is not forked. The opponent path carries a `SET_DECISION` event the home path
does not — 114 per 300 rallies, publishing no outgoing flight — which is the
most visible structural difference and the first place to look.

The 55 block legs that still score a "seam" are not one: the ball went past the
wall, so the leg into the event does not end at the event. The probe reports that
split explicitly rather than burying it in the total.
