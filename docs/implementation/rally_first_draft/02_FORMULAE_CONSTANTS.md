# 02 — Formula, relation and constant authority

This file prevents the implementation pass from treating every missing-looking number as permission to invent one.

Use four labels consistently:

- **AUTHORED** — an explicit game-design magnitude. Use it as written unless another authority supersedes it.
- **DERIVED** — calculate from authoritative state; do not replace with a constant.
- **MEASURED** — evidence/diagnostic result, not automatically a gameplay target.
- **DISCOVERED** — current implementation fact that must be verified if source has moved.

## 1. Ball flight

### Authority

**DERIVED / existing implementation authority.** Reuse the existing ball-flight / `RallyKinematics` / geometric resolver machinery. Do not create a second ballistic solver for M6 or M7.

The implementation already owns launch state and gravity-consistent flight queries. The unfinished work is predominantly ownership/order/continuity, not a new flight equation.

Required invariant:

```text
contact launch state
→ one free flight
→ zero or one first realised interaction
```

Truncating the realised segment at an interception does not alter the original launch.

### Relative-rise contract

**AUTHORED/SETTLED SEMANTICS. Do not reopen.**

- `apex_height_meters` / `apex_rise_meters` are relative rise above launch where the existing contract says so.
- `start_height_meters` and `end_height_meters` are absolute.
- presentation may derive gravity-true drawable geometry but gameplay does not read a presentation reconstruction.

## 2. Shared platform contact T1–T3

These six values are **AUTHORED game abstractions**, explicitly not measured biomechanics.

| relation | parameter | value |
|---|---|---:|
| T1 | incoming pace retained | `0.30` |
| T1 | active generation | `6.5 m/s` |
| T2 | planted redirection half-angle | `65°` |
| T2 | maximum circumstance narrowing | `82%` |
| T3 | weak-technique angular sigma | `7.0°` |
| T3 | elite-technique angular sigma | `1.5°` |

Shared semantics:

### T1 — outgoing pace capacity

Existing shared relation combines:

```text
retained incoming pace
+ active generation
+ positive body contribution
→ outgoing pace ceiling/capability
```

The exact implementation in `PlatformContactModel` is authority. Do not duplicate the relation in reception/dig/coverage code.

### T2 — reachable redirection

- natural rebound direction is **DERIVED** from `-incoming_velocity`;
- one cone is centred on that rebound;
- planted half-angle is the authored 65° endpoint;
- circumstance narrows the same cone by at most the authored 82%;
- do not create family-specific left/right edges or a reception-only cone.

### T3 — execution error

- error is angular deviation from the selected feasible platform direction;
- technique interpolates between the authored 7.0° weak endpoint and 1.5° elite endpoint through the existing model;
- downstream leverage may measure resulting spatial miss in metres, but the authored quantity is angular degrees;
- no family-specific sigma.

### Family rule

Reception, controlled dig and coverage differ by incoming ball/body/intent/circumstance facts, **not by T1–T3 coefficients**.

## 3. Body/contact geometry

**DERIVED. Closed.**

Platform body placement uses:

- the actual contact family's per-voli contact height;
- the existing universal shoulder relation / body morphology;
- the voli's standing reach / wingspan;
- incoming direction.

Do not author:

- a new stand-off distance;
- a trajectory-endpoint height as body height;
- a family-specific body offset.

Full arrivals stand at the derived body/contact relation; partial journeys remain physical rather than snapping.

## 4. Movement and reach

### Existing movement model is authority

**DISCOVERED / existing implementation.** Use the existing `RallyMovementSystem` / locomotion authority for movement feasibility, traversal and cost unless a work unit explicitly repairs an internal inconsistency.

Do not add a second `distance / constant_speed` timing model.

### Short-leg timing work

The current reception promotion blocker is **not** authorization for a new timing tolerance or speed constant.

Audit in this order:

1. timeline origin;
2. distance already covered / head-start accounting;
3. reaction/start delay accounting;
4. turn/standing-start accounting already present in the movement model;
5. movement integration / stepping;
6. interception-time accounting;
7. phase-boundary bookkeeping;
8. whether the movement-agreement instrument compares unlike intervals.

If the discrepancy can be corrected using existing authoritative state/relations, do so.

If it genuinely requires a new authored/unmeasured magnitude, use the STOP rule. Do **not** widen the movement-agreement gate.

### Head start

**SETTLED SEMANTICS.** A setter head start represents **distance already physically covered before the new leg's contact window**, not free extra time appended to the leg.

The existing first-ball setter head start is grounded in the preceding serve flight. Preserve that meaning.

When expected release target and realised interception diverge:

- movement before the pass exists may be toward the plan/release target;
- once interception occurs, realised remaining position/time comes from physical state;
- do not grant precognition of the final pass endpoint merely to simplify movement.

## 5. Actor continuity

**DERIVED from existing state.**

The current engine already carries per-rally recovery/body state and facing across phase-state rebuilds. M7 must extend continuity rather than create a second actor-history model.

For each player:

```text
position(t2) = result of authoritative movement from position(t1)
velocity(t2) = result of that movement/state transition
body/recovery state(t2) = prior state advanced by elapsed time and actions
facing(t2) = prior facing unless an established movement form changes it
```

This is semantic notation, not a mandate to create those exact functions or store a dense continuous trajectory.

## 6. Physical time

### Simulation clock

**CLOSED AUTHORITY.** `rally_clock` and existing contact/flight durations own simulation time. Do not create a second rally clock.

Required:

- event timestamps remain chronological;
- contact/flight durations are deterministic from the simulation path;
- causality corrections should not be required to repair a newly created event order once the underlying timing is correct.

### Playback

Playback scale is presentation. It may scale all physical time uniformly; it may not feed back into gameplay timing.

Do not reintroduce event-specific clamps as simulation authority.

## 7. Set posture / set pace constants

Current source contains unmeasured set-posture pace terms such as the documented `JUMP_SET_PACE_BONUS` and `STANDING_SET_ARM_SWING` starting values.

Classification: **existing authored/unmeasured debt**, not a mandate to retune during first-draft construction.

Rules:

- preserve unless the work unit actually requires changing them;
- do not fit them to rally outcomes;
- if M6 proves they cause an authority inconsistency rather than a calibration issue, separate the correctness repair from later tuning.

## 8. Block/contact constants

The current block and attack systems contain numerous existing authored/calibrated constants. M6 is an **ownership consistency audit**, not a blanket recalibration pass.

Therefore:

- keep current values while verifying causal order/authority;
- change a magnitude only when an existing governing spec/review explicitly authorizes the change or a separate calibration decision is made;
- do not adjust block/attack constants to compensate for a different upstream reception/set/movement distribution.

## 9. Tactical values

M9 evaluates whether tactical inputs cause the intended visible mechanisms. M6/M7 should preserve existing tactical inputs and route them through authoritative state.

Do not create new tactical weights merely to produce a visible A/B difference. If an existing tactic has no causal path after the architectural migrations, record the missing wiring and use existing semantics first.

## 10. Measurements are not targets by default

The following kinds of values are **MEASURED observations** unless an existing test/spec explicitly defines an acceptance bound:

- dig/reception rates;
- alternate-interceptor frequency;
- intended-recipient miss frequency;
- rally length;
- jump-set rate;
- outcome mix;
- side-out rate;
- most symmetry measurements outside an explicitly named gate;
- counts emitted by variable-sampling tests.

Do not fit architecture or physical constants to reproduce historical measured values.

## 11. Existing explicit gates remain gates

Where the repo already defines a numerical acceptance bound as a correctness/promotion criterion, keep the bound unchanged unless a separate authority explicitly changes it.

Examples include the existing movement-agreement and named symmetry/balance gates.

A gate may be reclassified only when its **semantic assertion** is obsolete because authority moved. In that case replace the assertion with the equivalent truth under the new authority; do not merely loosen the number.
