# 04 — Measurement, Failed Hypotheses, and Removed Models

Status: **HISTORICAL METHOD / CURRENT PRACTICE**

VWM's rally rewrite increasingly treats a failed hypothesis as useful evidence rather than as wasted work.

A strong development sequence is:

```text
observe symptom
→ form narrow hypothesis
→ build measurement/fixture
→ try to falsify it
→ keep/reject hypothesis
→ change owning mechanism only after evidence
```

## Example: “digging is weak” was the wrong diagnosis

A rotation study initially appeared to show wildly different floor-defence activity.

Splitting `DEFENSE` into actual floor digs versus attack coverage exposed that the counting instrument itself conflated two events.

Further measurement showed some rotations rarely reached opponent attack at all because serve-receive outcomes ended rallies upstream.

The important development lesson:

> do not buff the system where the symptom is visible until you know where the causal chain first diverges.

## Example: spacing term looked inert

A serve-receive crowding/spacing term produced the same spacing value repeatedly.

Possible explanations included wrong position inputs or fixed rotation. Measurements rejected both.

The actual reason was semantic: serve-receive formation intentionally places players on designed seams, so spacing is stable there. Crowding belongs more naturally to mid-rally movement.

The right result was **no fix**.

## Example: `readiness`

`RallyPlayerState.readiness` existed as a field but nothing meaningfully wrote it. Its consumers therefore saw a constant/identity.

Rather than inventing a new readiness mechanic, the project removed it and used explicit body/recovery/approach state already present.

A field existing in code is not proof that the design requires it.

## Example: short-ball immediate-control lock

A nominal claimant could remain locked even with no usable positive time.

The repair was not a new ownership weight. It was the semantic condition already implied by “can make the contact”:

```text
available_time > 0
```

This is preferable to tuning the claimant score until the fixture changes winner.

## Example: platform T1–T3 evidence gap

The project searched for empirical relationships needed by a shared platform model and found that available evidence did not cleanly provide the exact incoming→outgoing pace transfer, reachable angle limits by circumstance, or skill-error relation required.

Instead of pretending a paper supported exact values, the design documented the gap and explicitly authorized six category-3 game abstractions.

This creates an honest hierarchy:

```text
derived relation
measured relation
explicit authored abstraction
```

Each is acceptable when named correctly.

## Example: unit-label error

T3 leverage outputs were described inconsistently as degrees/radians, while the actual producer reported spatial destination error in metres.

The correct fix was to repair the documentation after tracing `spatial_error_meters`—not change the physics to make the prose true.

## Measurement confounds

A probe can lie without containing a code bug in the production system.

Common confounds include:

- state not reset between seeded runs;
- event types conflated;
- warm versus cold cache;
- fixture not reaching the branch under study;
- sampling checks producing variable test counts;
- using presentation/default fields as physical truth;
- measuring an outcome downstream of an upstream terminal imbalance.

Before quoting a number, understand what generated the sample.

## Controlled fixtures versus natural incidence

Rare legal states should use constructed fixtures.

A branch firing 0 times in 1,200 ordinary rallies tells you something about incidence under that sample, not whether the branch works.

For overpasses, the project separately proved:

```text
natural census: rare/zero
constructed fixture: branch executes correctly
```

Both facts are useful and answer different questions.

## Outcome rates are observations during correctness migration

When architecture is being corrected, a change in kills/digs/sideouts is evidence to inspect—not automatically a target to restore.

Restoring the old rate can reintroduce the old bug through a different knob.

Use outcome tuning only after:

1. authority is correct;
2. physical/decision semantics are governed;
3. measurement instrument is trusted;
4. calibration has been explicitly authorized.

## How to document a rejected hypothesis

A good review note records:

- symptom;
- hypothesis;
- instrument;
- result;
- why hypothesis was rejected/accepted;
- what boundary remains.

This prevents future maintainers from repeating the same attractive wrong explanation.

## The value of exact STOP boundaries

The project often stops not because code is hard but because the next step would require inventing policy or an unmeasured magnitude.

That is healthy.

Examples:

- defensive movement opening/top-speed relation;
- coverage keep-alive selection preference.

A clear blocker should state the **smallest decision required**, supported by measurements/options, rather than a broad “needs design.”

## Reading exercise

Choose one review document in `docs/review/` that ended in “no change” or a deferred boundary.

Write:

1. what looked wrong;
2. what was measured;
3. which explanation failed;
4. what new fact was established;
5. why not coding something was the correct result.

## Source trail

- `docs/review/`
- `docs/design/MEASUREMENT_CONFOUNDS.md`
- `tools/` probes/audits
- `docs/design/PLATFORM_PHYSICS_EVIDENCE_GAP.md`
- `docs/review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md`

Part VI returns to the management game and follows the long-term loops that give the rally engine meaning.