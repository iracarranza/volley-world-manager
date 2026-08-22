# 09 — Platform Contacts and T1–T3

Status: **VERIFIED / M4 IN PROGRESS**

M4 is replacing category-first reception/dig/coverage ball outcomes with one shared forearm-contact model.

The governing idea is:

> reception, dig and coverage are different volleyball situations, but a forearm platform should obey the same underlying physical transfer relations.

## One model, not three physics tables

`PlatformContactModel` intentionally does **not** read event family, result label or team side.

It consumes:

```text
incoming ball velocity
contact position + height
body velocity / circumstance
stability ability
technique ability
compiled intent target/height/time floor
seed
```

and returns a feasible envelope, selected launch (when intent is sufficiently specified), and realized launch.

## T1 — outgoing pace

T1 answers:

> Given the incoming speed, body/platform state and the player's ability to stabilize/generate through contact, what outgoing speed is available?

The current category-3 authored abstractions are:

- incoming pace retention: **0.30**;
- active generation ceiling: **6.5 m/s**.

Body motion along the natural rebound direction can also contribute from already-derived movement velocity.

These values are explicitly game abstractions calibrated for plausible behavior—not measured biomechanics.

## T2 — reachable redirection

T2 defines which outgoing directions the platform can physically create.

The cone is centered on the **natural rebound direction** `-incoming_velocity`, not on tactical intent.

Current authored values:

- planted half-angle: **65°**;
- maximum circumstance narrowing: **82%**.

Circumstance can narrow the cone when the body is stretched/compromised, but intent cannot widen it.

This is a crucial causal rule:

```text
physics defines cone
→ intent chooses inside cone
```

not:

```text
intent wants setter
→ physics invents direction toward setter
```

## T3 — execution error

T3 models technique-driven angular execution error between the selected feasible direction and realized direction.

Current endpoints:

- weak technique sigma: **7.0°**;
- elite technique sigma: **1.5°**.

After execution variation, the direction is projected back into T2 so error cannot manufacture an unreachable launch.

## T3 leverage metrics use metres

A documentation audit traced reported leverage values such as `0.696 → 0.140` to a **spatial error in metres** (`spatial_error_meters`), not radians/degrees.

This is worth remembering because the underlying T3 distribution is angular while a downstream probe may report where that angular error placed the ball in space.

Always trace the producer before labeling a unit.

## Selection is minimal and weight-free

Given intent anchors, the model searches feasible launch candidates that satisfy arrival floor when possible, minimizes three-dimensional miss in common metre units, and prefers earlier ball where otherwise tied.

It avoids adding arbitrary “horizontal error weight vs height error weight” because both misses can already be expressed in metres.

## Envelope first, selection second

`evaluate()` can return a physical envelope even when intent is underconstrained.

That is useful for coverage: current coverage contacts can publish truthful incoming/body/feasible-envelope state without fabricating an outgoing target policy that has not yet been designed.

This is the known next policy boundary after M5 integration.

## Controlled dig rollout

Controlled digs have a development-only physical launch path.

Certification established that:

- successful physical digs produce one authoritative free flight;
- failed digs produce no ball;
- intended setter can miss;
- another teammate can intercept;
- some balls naturally reach floor;
- source launch is not mutated downstream.

Production flag `ENABLE_PHYSICAL_PLATFORM_DIG` remains **false** at the current documented boundary while M5 downstream semantics are completed.

## Reception and coverage

Reception has rich existing intent and physical input and is part of the broader M4 promotion plan.

Coverage has incoming/body/contact state and can be evaluated against T1–T3, but the game has not yet governed **which keep-alive launch a covering player should prefer**.

That missing preference is decision policy, not missing platform physics.

## Why no family-specific bands

It would be tempting to solve different observed rates by adding:

```text
RECEPTION_ANGLE_BONUS
DIG_SPEED_MULTIPLIER
COVERAGE_POP_HEIGHT
```

That would make event names author the physics.

Instead, the same evaluator receives different real circumstances, player state and intent. Different outcomes should emerge from those inputs.

## Authored abstraction versus tuning

The six T1–T3 values were authorized because the desired physical relations could not be fully derived from available evidence and the game needed an explicit simplified model.

They are not target-rate knobs.

Acceptance is based on plausible launch behavior, monotonic attribute leverage and physical consistency—not “the dig percentage should equal X.”

## Safe modification

Do not change T1–T3 because a live outcome rate looks unusual.

First ask:

1. Is the model receiving truthful incoming/body/contact state?
2. Is intent governed correctly?
3. Is the output physically plausible?
4. Does attribute leverage behave monotonically?
5. Is a downstream continuation incorrectly interpreting the launch?

Only a demonstrated failure of the relation itself justifies recalibration.

## Reading exercise

Read `PlatformContactModel.evaluate()` and label the stages:

```text
input validation
→ derive natural rebound
→ T1 speed ceiling
→ T2 direction cone
→ T3 sigma
→ intent selection
→ execution draw
→ projection back into feasibility
```

Then identify which values are derived, authored and numerical-resolution-only.

## Source trail

- `scripts/simulation/platform_contact_model.gd`
- `docs/design/PLATFORM_CONTACT.md`
- `docs/review/PLATFORM_TRANSFER.md`
- `docs/review/PLATFORM_PHYSICS_EVIDENCE_GAP.md`
- `docs/review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md`
- `docs/review/PLATFORM_AUTHORED_CALIBRATION.md`

Next: M5 uses those outgoing launches as real balls—interceptions, shanks, overpasses and continuation.