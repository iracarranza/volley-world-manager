# M5 — authoritative free flight and second-contact interception

Built and certified 2026-08-17 from `170b205`.

## Authority

A successful physical platform contact now resolves one launch and one natural
free flight to the floor. The intended target plane is diagnostic only. A later
contact is selected from physical opportunities along that flight; it does not
rewrite the launch or declare the flight's endpoint.

`FreeFlightInterceptionSystem` owns:

- the full projectile derived from the contact's launch;
- exact ball position and height versus physical time;
- each actor's physically reachable contact opportunities;
- the uncontrolled terminal at the floor, sideline/baseline, or net;
- the realised segment derived as a prefix of the full flight.

`RallySimulator` still owns the decision between viable claimants. M5 extracts
no new weights: it applies the existing second-contact responsibility,
set-accuracy, decision-making and temperament policy to physical opportunities.
Contact timing is ranked against the existing platform target and height anchors
with the same unweighted three-dimensional miss used by M4 selection. Physics
therefore defines possibility; intent and attributes still choose within it.

The free flight and realised segment share an `authoritative_flight_id` and the
same launch state. The played segment records the natural endpoint as provenance
and is never reconstructed from the selected recipient.

## Fixed-population certification

`tools/run_platform_dig_rollout_probe.gd`, 600 paired rallies (300 per serving
side), with the retired dig ball available only through a debug measurement
override:

| contract | result |
|---|---:|
| successful physical digs | 89 / 89 promoted |
| failed digs with outgoing ball | 0 / 187 |
| authoritative free flights | 89 / 89 |
| realised physical interceptions | 83 / 89 |
| uncontrolled floor contacts | 6 / 89 |
| intended setter had no opportunity | 31 |
| non-intended interceptor took the ball | 33 |
| realised-prefix failures | 0 |
| launch mutations after interception | 0 |
| digger duplicated as second contact | 0 |
| next-contact actor mismatches | 0 |
| unreachable intended setter terminating flight | 0 |
| unresolved overpasses in this population | 0 |

The production arm's terminal outcomes are reported only as integration effects;
none is a calibration target. The retired arm remains available so this protocol
can validate future changes rather than becoming stale when production opens.

M4 attribute leverage remains monotone on identical ball/body/intent/draws:
stability 20→80 raises the easy T1 ceiling 6.48→10.14 m/s and the hard ceiling
5.71→7.06 m/s; technique 20→80 lowers easy angular error 0.696→0.140 degrees
and hard error 1.507→0.151 degrees. The values are authored game abstractions,
not biomechanical measurements.

## Production boundary and next blocker

The physical controlled-dig path is production-authoritative after this gate.
Reception and coverage are not implicitly promoted with it.

Coverage now has complete contact/body state but no governed preference for
choosing among feasible keep-alive launches. Its missing rule is decision policy,
not physics: there is no target height, recipient or timing anchor from which a
minimal selection can be derived. M5 does not invent one, and no coverage launch
is promoted until that materially different volleyball decision is authored.

An overpass is also named rather than guessed: a free flight crossing the net
above the tape reports `crossed_net_unresolved`. It did not occur in the fixed
controlled-dig population. If a later contact family reaches it, resolving which
opponent may play it and as what action is a separate semantic policy boundary.
