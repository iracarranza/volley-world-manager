# 02 — Derived vs Measured vs Authored Values

Status: **VERIFIED PROJECT METHOD**

A simulation inevitably contains numbers. The important question is not “does this file contain constants?” It is:

> **What gives each magnitude authority?**

VWM increasingly distinguishes three legitimate sources.

## 1. Derived values

A derived value follows from other accepted facts and mathematics.

Examples:

```text
projectile vertical velocity at time t
→ launch velocity - gravity × elapsed time

body/contact stand-off
→ shoulder/arm/contact-height geometry

movement facing after approach
→ movement form + route velocity
```

If a relation can be derived cleanly, adding an independent tuning constant creates a second truth.

Derived does not mean “perfect reality.” The inputs/model can still be simplified. It means the magnitude is a consequence rather than separately chosen.

## 2. Measured values

A measured value comes from an observation/instrument whose meaning and units are known.

Measurements can come from:

- external empirical evidence;
- controlled game probes;
- repository cross-checks;
- rendered/runtime performance measurements.

A measurement needs provenance:

```text
what was measured?
under what fixture/sample?
what unit?
what producer/instrument?
```

“Probe printed 0.14” is not enough.

## 3. Authored game abstractions

Some useful relationships cannot currently be derived or supported by adequate evidence. The game may still need a simplified magnitude.

An authored abstraction is acceptable when it is named honestly and scoped tightly.

M4's six platform values are the clearest example. The repository explicitly calls them **category-3 game abstractions**, not measured biomechanics.

That honesty lets future evidence replace them without rewriting history.

## Authored does not mean outcome-tuned

An authored physical value should be selected/calibrated against the behavior of the physical relation it represents.

For platform contact, relevant checks include:

- plausible outgoing speed range;
- plausible redirection freedom;
- stable monotonic attribute leverage;
- physical envelope consistency;
- ability to satisfy ordinary intent when circumstances permit.

Not:

```text
choose coefficient until dig rate = target
```

Outcome rates are several systems downstream.

## A fourth category: numerical resolution

Values such as:

- search sample count;
- bisection iterations;
- epsilon;

exist to make an algorithm accurate/stable.

They do not describe volleyball.

Mark them clearly so a future balance pass does not tune `SEARCH_SAMPLES` because a kill rate changed.

## Policy values are different again

A decision preference is not physics.

The current coverage blocker illustrates this:

```text
T1–T3
→ says which outgoing launches are feasible

coverage selection policy
→ says which feasible launch the player values
```

A keep-alive preference may eventually need authored decision structure, but it must not be hidden as a new platform redirection constant.

## The authority ladder

When a magnitude seems missing, ask in order:

```text
Can existing facts derive it?
↓ no
Can trustworthy evidence measure/constrain it?
↓ no
Does the design actually require a magnitude now?
↓ yes
Author the smallest explicit game abstraction.
```

Sometimes the correct answer is **defer the feature** because the missing number is not yet necessary.

## Preserve units through reporting

A model may use an angular error internally while a probe reports spatial miss at the destination.

Both can be valid, but labels must match the producer.

The T3 unit correction is a useful example:

```text
internal T3 sigma
→ degrees

probe leverage output
→ resulting spatial_error_meters
```

Changing documentation fixed the mismatch; changing the physics would have been wrong.

## Dimensionless transforms can still be authored choices

A square/square-root transform such as `severity²` or `sqrt(1-severity)` introduces shape even if it adds no new dimensional coefficient.

Document why it is used and what endpoints it preserves.

“Parameter-free” does not mean “semantically neutral.”

## Avoid duplicate calibration knobs

Before adding a constant, search for an existing relation representing the same fact.

Example:

```text
player stride already affects movement
→ do not add TALL_PLAYER_SPEED_BONUS to another system
```

If a contact family's different circumstances already enter a shared model, do not add a family multiplier merely because its observed outcomes differ.

## Calibration needs a declared target

Every calibration pass should say what it is calibrating.

Good:

> choose authored T2 magnitude so ordinary planted platform contacts have useful but bounded redirection, while severe contacts narrow monotonically.

Bad:

> make receptions look about right.

The first can be tested; the second invites outcome fitting.

## Reopening a calibrated relation

Do not reopen a certified magnitude because downstream behavior changed.

Require evidence that:

- inputs are truthful;
- implementation matches the documented relation;
- the relation itself produces implausible/incorrect outputs under controlled fixtures.

Then recalibrate with the same authority discipline.

## Reading exercise

Take these current values and classify them:

- `PACE_RETENTION = 0.30`;
- gravity used by the projectile model;
- `SEARCH_SAMPLES = 241`;
- body contact offset at waist height;
- a future coverage preference weight if one were proposed.

For each, write what evidence/derivation would justify changing it.

## Source trail

- `scripts/simulation/platform_contact_model.gd`
- `scripts/simulation/free_flight_interception_system.gd`
- `docs/review/PLATFORM_PHYSICS_EVIDENCE_GAP.md`
- `docs/review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md`
- `docs/review/PLATFORM_AUTHORED_CALIBRATION.md`
- `docs/design/MEASUREMENT_CONFOUNDS.md`

Next: how a correct candidate becomes certified and eventually production-authoritative.