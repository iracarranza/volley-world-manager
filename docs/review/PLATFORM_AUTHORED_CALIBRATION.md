# M4 shared platform calibration and controlled-dig rollout

Run: 2026-08-17. Instruments:
`tools/run_platform_shadow_probe.gd`,
`tools/run_platform_dig_rollout_probe.gd`,
`tools/run_platform_attribute_leverage.gd`, and
`tools/run_platform_intent_census.gd`.

## Authority ruling

T1--T3 are an explicit **category-3 game-abstraction layer**. They delimit a
plausible feasible contact space; they are not measured biomechanics and must
not be cited as scientific quantities. The measurement protocol in
`PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md` remains future validation and possible
replacement infrastructure, not an M4 prerequisite.

The model has six authored parameters:

| relation | parameter | value | one meaning only |
|---|---|---:|---|
| T1 | incoming pace retained | 0.30 | share of arrival speed available at the outgoing ceiling |
| T1 | active generation | 6.5 m/s | maximum stable-body contribution to that ceiling |
| T2 | planted redirection half-angle | 65° | angular reach from the natural rebound line |
| T2 | maximum circumstance narrowing | 82% | share of that angular reach removed at full constraint |
| T3 | weak-technique angular sigma | 7.0° | selected-to-realised direction error endpoint |
| T3 | elite-technique angular sigma | 1.5° | selected-to-realised direction error endpoint |

There is no seventh parameter for a second angle edge. T2 is one cone centred on
the derived natural rebound, `-incoming_velocity`. BallFlight's existing signed
elevation domain also constrains every candidate; it is not copied into a
platform constant. The square/square-root circumstance transforms preserve the
authored endpoints and add no midpoint or contact-family band.

Neither event family nor result label reaches the relation. Reception, dig and
coverage supply different body/intent facts to one evaluator; they do not own
different T1--T3 values.

## Calibration basis

The six values were adjusted against plausible contact-level outputs only:
launch pace, direction, apex, flight time/range and ability to serve the stated
anchors. Terminal kills, digs, side-outs and points were never acceptance
targets. The legacy ball is reported against the shadow envelope as a diagnosis
of the model being replaced, not as a fitting target.

Over 600 fixed rallies the final shadow reads:

| family | contacts | physical input | selection | intent simultaneously satisfied |
|---|---:|---:|---:|---:|
| reception | 484 | 484 | 484 | 189 |
| controlled dig | 277 | 277 | 277 | 122 |
| attack coverage | 24 | 24 | 0 | 0 |

Controlled-dig realised launches span 1.934--10.099 m/s, 27.164--85.000°,
1.174--6.140 m absolute apex, and 0.681--2.144 s to the floor; medians are
7.283 m/s, 64.436°, 2.913 m and 1.391 s. The steep/high tail follows from fast
incoming balls plus a narrow reachable direction, not from a dig-only rescue
band.

Coverage now owns incoming vector, contact height, arrival and posture on all 24
observations. It deliberately selects no ball: its height and arrival intent are
unset and the full keep-alive preference is not designed. All 24 contacts also
arrive at the fully constrained T2 endpoint under the existing arrival model,
which exposes how far the legacy coverage-success contest is from physical
arrival; it is not a reason to widen T2.

## Attribute leverage

The shadow leverage fixture holds ball, body, intent and draws fixed at ratings
20/40/60/80. Easy-contact speed capacity rises 6.48 → 10.14 m/s and difficult-
contact capacity 5.71 → 7.06 m/s. Mean destination error falls 0.696 → 0.140 m
on the easy fixture and 1.507 → 0.151 m on the difficult fixture. Weak and elite
volis both retain a launch; ratings change what can be generated and how closely
the selected launch is executed, not whether physics exists.

The production-closed legacy attribute probe is unchanged as a second guard:
easy reception target error separates 1.561 → 0.212 m and easy dig error
2.029 → 0.640 m; difficult contacts retain strong survival separation. This is
not evidence for the six magnitudes. It certifies that the migration did not
erase the attributes already acting upstream.

## Controlled-dig rollout

Slice 3 is implemented behind `ENABLE_PHYSICAL_PLATFORM_DIG = false`, with an
independent development override. Opening it does not open continuous reception,
setter, attack or block paths.

In the paired 600-rally run:

- production closed: 0 of 87 successful digs promoted;
- development rollout: 86 of 86 successful digs promoted;
- 0 of 188 failed digs published an outgoing ball;
- every promoted ball carried one resolved trajectory and matched its DIG event
  endpoint;
- launch pace 3.071 / 6.068 / 8.773 m/s min/median/max;
- apex 1.307 / 2.447 / 4.319 m;
- segment time 0.061 / 1.147 / 1.753 s.

Terminal-outcome deltas are printed but have no acceptance bound. Calibrating
T1--T3 to recover the old outcome mix would make the legacy apex/spoil model its
own authority.

## Production blocker and next boundary

Only 41 of 86 promoted successful digs remain airborne to the intended target
plane. The other 45 are legitimate short/shanked free flights. The current rally
architecture nevertheless advances directly to a set at the stored endpoint,
which can mean setting a ball at floor height. M4 must not relabel those balls as
successful setter contacts or force them to the intended recipient.

That is the exact M5 boundary: free flight must exist independently of its later
interceptor, and a teammate may claim a shank en route before it lands. Therefore
the controlled-dig code is complete as a development rollout but remains closed
for production until M5 owns interception.

The next M4-specific policy boundary is coverage selection. Physical contact
state is complete, but an unset height/floor intent leaves multiple feasible
keep-alive launches equally ranked. The documented full preference (including
how tactics value survival, height and tempo) must be designed before coverage
can own an outgoing ball. No substitute choice is authored here.
