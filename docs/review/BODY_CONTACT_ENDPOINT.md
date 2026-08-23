# A published fact that moved a gate, and a stale write it uncovered

The first-draft closure pass ended with the suite unrun over its own final
state. Run over `475a7cc`, it came back **1 of 2141 checks failed** —
*Allotted duration and the movement model agree for every phase type*.

Two separate defects were under it. Neither was a movement regression, and the
band was not touched.

## What the gate emits, and why that cost an hour

The check reads a 120-seed sweep, asserts four per-phase bands and two overall
bounds, and emits **one boolean**. When it fails there is no way to know which
of the six bounds went or by how much, so the first move is always to rebuild
the sweep by hand. `tools/probe_movement_agreement.gd` now does that on exactly
the arguments the gate passes, and is worth keeping for the next time.

Measured at `475a7cc`, against `570176d` — the commit whose suite was recorded
at 2,139/0 — rebuilt in a worktree so the two are the same instrument:

| phase | `570176d` | `475a7cc` | |
|---|---:|---:|---|
| RECEPTION | 0.9952 (89) | **0.7802** (83) | out |
| SET | 0.8210 (46) | 0.8210 (46) | ok |
| ATTACK | 1.0303 (87) | 1.0303 (87) | ok |
| DIG | 0.9977 (40) | **0.6872** (**6**) | out |
| ATTACK_COVERAGE | 1.0000 (4) | **0.5209** (4) | out |
| mean / perceptible | 0.9770 / 0.0414 | 0.8777 / 0.1549 | out |

SET and ATTACK are identical to four decimals. That is the whole diagnosis in
one row: if any rally resolved differently, those two would have moved too.

## Defect 1 — a key-presence test used as a proxy for an endpoint

`movement_timing_ratio_calibration` divides a modelled traversal by the
resolver's `movement_duration`, so the two have to describe the same journey.
It picked the journey's end like this:

```gdscript
var destination := Vector2(event.metadata.get(
    "body_contact_position", event.start_position
))
```

— the body where one was published, the ball otherwise. That was never a rule
about endpoints. It was a proxy that happened to select the right end for as
long as the only families publishing a body position were the two the resolver
*times* to a body.

They are not the same set, and the resolver says so at each site:

| family | `movement_duration` timed to |
|---|---|
| ATTACK | `intended_hitter_body` — the hitter's centre stops behind the ball |
| SET | the setter's own contact |
| RECEPTION | `serve_landing` — the platform reaches out to the ball |
| DIG | the ball's floor target |

M8 published `body_contact_position` from `_add_event` for every contact, which
is correct — it is a real fact about every contact, and M8 needs it. The proxy
silently became "always the body", and three of five numerators started being
measured to an end their denominator had never been timed to. RECEPTION's leg to
the body is a mean 1.195 m against 1.630 m to the ball; the ratio fell by very
nearly that fraction.

The repair names the two families instead of inferring them
(`_destination_is_body_contact`). **The bands stand where they were measured.**
Redrawing them would have been fitting a gate to an instrument change, which is
the one move this repository is most often told not to make.

## Defect 2 — the opponent dig wrote its reach after the event that reads it

Chasing the first defect surfaced a real one. DIG did not merely shift; its
sample count fell **40 → 6**, because the sweep discards a leg shorter than five
centimetres. Dumped per event:

```
DIG   n 13   mean->ball 1.973   mean->body 0.000   body != movement_target: 10 of 13
```

Every opponent digger was published as contacting the ball **from the spot they
started at**, after a mean 1.97 m of travel, with the published body position
disagreeing with the leg's own `movement_target`.

All thirteen were opponent digs, and the cause is ordering. Of the four
floor-defence sites, three write the reach into the live map before appending
the event; the first opponent dig wrote it *after*:

```gdscript
_add_event(result, RallyEventModel.EventType.DIG, ...)   # line 3816
...
opponent_live_positions[opponent_defender.id] = opponent_defender_reach   # 3879
```

Nothing between the two lines resolved anything, so the drift was invisible —
until two published facts started reading that map at append time.
`body_contact_position` was one. The other is `opponent_phase_targets`, built
from `opponent_live_positions.duplicate(true)` inside the same metadata literal:
the opponent's whole defensive shape was published with the digger still
standing where they began, while the caption on the same event read *"after
moving 1.8m"*.

Moving the write above the call fixes both. It is the third home/opponent drift
found this pass, after the block's stale swing and the receive zone's `enabled`
check — and like those two, it was one side quietly doing what its twin did not.

## What the repairs cost

Nothing, and that is checkable rather than asserted. After both:

| phase | `570176d` | after repairs |
|---|---:|---:|
| RECEPTION | 0.9952 (89) | 0.9952 (89) |
| SET | 0.8210 (46) | 0.8210 (46) |
| ATTACK | 1.0303 (87) | 1.0303 (87) |
| DIG | 0.9977 (40) | 0.9977 (40) |
| ATTACK_COVERAGE | 1.0000 (4) | 1.0000 (4) |
| mean / perceptible | 0.9770 / 0.0414 | 0.9770 / 0.0414 |

Every figure and every sample count identical to four decimals. DIG returning to
0.9977 *on 40 samples* is the part worth reading: the writeback move changes no
duration, no leg start and no ball position, so a dig's ratio must be exactly
what it was. It is.

## What this says about the count

The failing check was one of 2,141 — and it was the only instrument in the suite
positioned to notice. Nothing else asserts on `body_contact_position`; playback
(`match_screen`) and `run_canonical_sideout` both read it and would have drawn
and printed the stale value without complaint. M8's structural trace prints a
travel column derived from it, so on a rally whose dig belonged to the opponent
it would have reported a digger who covered two metres as having covered none —
and the two zeros that trace *did* show were both checked and both turned out to
be correct volleyball, which is exactly how a third one would have been read.

The lesson is the ordinary one, in a new costume: **a new published fact is an
input to everything already reading that key.** `body_contact_position` was
added as an output for M8 and arrived as an input to a calibration gate through
a fallback nobody was thinking about. Before publishing a field, grep its
readers — the fallback arm is where the damage is, because that arm is the one
that stops being taken.
