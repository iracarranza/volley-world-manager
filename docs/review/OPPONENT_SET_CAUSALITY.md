# The opponent's set was on a different clock from the pass that fed it

`_stamp_physical_times` floors a derived moment to its predecessor and records
the correction in `physical_time_floored`. The gate asserts that never has to
happen, and after the serve began being sliced at the reception it fired once
across the sampled 120 rallies.

## What fired

    seed 5032  SET after RECEPTION  floored by 0.6426 s  side=opponent
        event_time=3.554  outgoing.start=2.717

An opponent set whose own outgoing flight starts 0.84 s *before* the reception
that fed it. Not a rounding seam -- most of a second.

## Why

`_resolve_opponent_transition` builds the moment from the narrative clock:

    var opponent_set_contact_time := rally_clock \
        + opponent_second_contact_window + opponent_release_interval

`rally_clock` accumulates as the resolver walks the rally. The reception before
it, since the serve slice, takes its moment from the physical record -- the
instant the ball actually descends to the passer's platform. Two clocks, and
they had no reason to agree once one of them became physical.

The home side has never had this problem, because it already reads the resolved
moment when there is one:

    var set_contact_time := (
        float(physical_choice.contact_time) + release_interval
    ) if not physical_choice.is_empty() \
        else rally_clock + second_contact_window + release_interval

The opponent path computes the same `physical_choice`, uses its
`contact_position` for the setter's marker and its `contact_time` for the
window, and then reached past it for the clock. The fix is to mirror the home
side: same expression, same fallback, no new quantity.

**A near-miss in the same function worth naming.** `second_contact_window` is
set at line 4255 from `physical_choice.contact_time`, and
`opponent_second_contact_window` is computed at 4577 from the last event's
trajectory duration. Two variables, near-identical names, one physical and one
not -- and the set was reading the second.

## What it moved

`tools/probe_causality_floor.gd`: **1 correction to 0**.

`run_rally_balance_probe.gd`, 700 rallies both serving sides, the same probe run
twice with only this file stashed between:

| | before | after | band |
|---|---|---|---|
| contacts per rally | 4.601 | 4.636 | advisory |
| kill rate | 0.529 | 0.526 | 0.45–0.50, out before and after |
| swing balance | 0.973 | **0.957** | near 1.00 |
| dig rate | 0.509 | 0.512 | **gated** 0.35–0.55 |
| stuff rate | 0.102 | 0.097 | **gated** 0.08–0.14 |
| serve error rate | 0.194 | 0.194 | **gated** 0.12–0.20 |
| ace rate | 0.099 | 0.099 | 0.05–0.09, out before and after |
| reception quality | 0.430 | 0.430 | |
| block touch rate | 0.791 | 0.793 | |
| home dig rate | 0.537 | 0.566 | |
| opponent dig rate | 0.479 | 0.459 | |

Every gated band holds. Rallies do resolve differently -- contacts, digs, swings
and coverage all moved a little -- which is what moving a contact's moment by up
to 0.84 s has to look like.

**Two things the table says that the count could not.** The serve-side figures
are byte-identical: ace, serve error and reception quality to three places. That
is the right answer, because this change cannot reach the serve -- it touches the
opponent's *second* contact, which happens after all three are already decided. A
change that moved them would have meant the edit was not what it claimed to be.

And an observation recorded rather than acted on: **swing balance moved 0.973 to
0.957**, away from 1.00, and the home/opponent dig gap widened from 0.058 to
0.107 in the home side's favour. The direction is plausible -- the opponent's set
now lands at its true, later moment, which gives the home block and floor defence
the time they should always have had -- so this reads as an asymmetry being
*revealed* rather than introduced. It is one sample and it is not a gate. Noted
for the next pass that touches either side's transition.
