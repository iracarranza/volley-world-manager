# M5 — authoritative free flight and second-contact interception

Built in development and audited 2026-08-17 from `170b205`.

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
| unresolved overpasses in this fixed population | 0 |

The development arm's terminal outcomes are reported only as integration
effects; none is a calibration target. The retired arm remains available so this
protocol can validate future changes rather than becoming stale when production
eventually opens.

M4 attribute leverage remains monotone on identical ball/body/intent/draws:
stability 20→80 raises the easy T1 ceiling 6.48→10.14 m/s and the hard ceiling
5.71→7.06 m/s; technique 20→80 lowers the easy spatial error 0.696→0.140 m and
the hard spatial error 1.507→0.151 m. The values are authored game abstractions,
not biomechanical measurements.

The leverage figures are a **spatial destination error in metres**, not an angle.
Earlier drafts of this line called them radians and a later edit relabelled them
degrees; both were wrong. Traced to the sole producer,
`run_platform_shadow_probe.gd::_leverage_measure`, whose `mean_error` accumulates
`realised.spatial_error_meters` — a distance on the court, not a rotation. The
magnitude confirms it: 0.14–1.5 is right for metres of pass placement and
implausible as the mean of the model's 1.5°–7.0° execution sigma in either
angular unit. The model does expose a true angle, `execution_error_degrees`, but
no leverage probe aggregates it, so the number reported here was never that
field. Physics is unchanged; only the unit label is corrected.

## Production boundary — now open

Production is **open for all three platform families**:
`ENABLE_PHYSICAL_PLATFORM_DIG` and `ENABLE_PHYSICAL_RECEPTION` are both `true`,
so reception, controlled dig and attack coverage each launch one authoritative
free flight and let M5 decide the next contact. The path below records the
boundary that held the dig closed and how each part was cleared; see
[`PLATFORM_DIG_PROMOTION.md`](PLATFORM_DIG_PROMOTION.md) and
[`PLATFORM_RECEPTION_PROMOTION.md`](PLATFORM_RECEPTION_PROMOTION.md) for the
promotion evidence. **M4 is DONE.**

The same-side interception contracts passed but did not certify every launch the
authored T1--T3 model can produce — specifically, a launch that clears the net.

`tools/run_m5_overpass_census.gd` found no overpass in 1,200 ordinary rallies
across all six rotations (244 physical digs: 234 intercepted, 10 floor
terminals). That is population evidence, not impossibility. A contact made at
0.62 court depth from a plausible 24.4 m/s descending attack, using the authored
0.8 circumstance severity and the ordinary shared platform resolver, launches
at `(-0.262, 5.502, -3.731)` m/s and clears the net at 2.493 m. No new constant
or enum-specific band is involved.

That `crossed_net_unresolved` state is **no longer a dead end**: M5 now resolves
it as the receiving side's ordinary first team contact through
`OverpassActionSystem`, in both the control and attack branches, at both live
exits (see [`OVERPASS_ACTION_HANDOFF.md`](OVERPASS_ACTION_HANDOFF.md)). The
overpass boundary that gated controlled-dig, reception and coverage promotion is
therefore cleared, and the physical dig has been promoted — the distribution
moved when the flag flipped, and that movement was observed, never fitted.

Coverage's keep-alive selection is governed and live. It owns no recipient
policy of its own: the intended actor is exactly the one the existing
second-contact policy (`_second_contact_setter`) names, with the coverer
excluded, and from there it is the shared physical platform contact producing
one authoritative free flight routed through M5 interception. It ships on the
same `ENABLE_PHYSICAL_PLATFORM_DIG` flag as the dig. See
[`COVERAGE_KEEP_ALIVE.md`](COVERAGE_KEEP_ALIVE.md).
