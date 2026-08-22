# 01 — Tests, Deterministic Fixtures, and Probes

Status: **VERIFIED METHOD**

VWM uses several kinds of proof because no single test style answers every question.

The maintainer's job is to choose an instrument that matches the claim.

## Unit/regression tests

`tests/test_runner.gd` contains broad automated checks for model/system behavior and integration invariants.

These are strongest when the expected fact is crisp:

```text
contact count == 1
source launch unchanged
unavailable actor excluded
save field survives reload
```

A test should prove a semantic property, not merely repeat the implementation line by line.

## Deterministic fixtures

A deterministic fixture fixes inputs and seed so the same situation can be reproduced.

This is especially important in a probabilistic simulation. Without controlled seeds, “before/after looked different” may be ordinary random variation.

Useful fixture inputs include:

- fixed players/attributes;
- fixed positions/body state;
- fixed ball launch;
- fixed tactic/principles;
- fixed RNG seed;
- one intended branch.

## Constructed fixtures are legitimate

Some legal states are rare in ordinary generated rallies.

The current overpass integration is a textbook example: a 1,200-rally census hit the relevant exit 0 times, while a constructed fixture exercised it end-to-end.

These results answer different questions:

```text
census
→ how often did this sample naturally reach the state?

constructed fixture
→ does the state behave correctly when it occurs?
```

Do not reject a legal branch because random sampling did not encounter it.

## Focused probes

`tools/` contains purpose-built scripts/scenes for one measurement or certification question.

A good probe:

- calls production/shared code rather than recreating it;
- fixes irrelevant variables;
- prints structured measurements;
- can fail when the hypothesis is wrong;
- names the unit/meaning of every reported value.

A probe that can only pass is documentation, not an instrument.

## Distribution probes

Some questions require many samples:

- generated player distributions;
- attribute leverage;
- action-selection frequency;
- physical launch ranges;
- rare-event incidence.

Use fixed seed sets when comparing revisions so A/B differences come from code rather than a different sample.

## Visual previews

Rendered preview scenes are tests of legibility/composition, not simulation authority.

Use them for:

- pose clarity;
- UI material hierarchy;
- movement animation;
- sticker silhouette;
- theme behavior.

Pair them with numeric/semantic tests when a visual effect depends on an underlying measurable invariant.

## Baseline versus acceptance

A historical full-suite check count is not an acceptance criterion by itself. Sampling tests can emit variable numbers of checks, and adding a fixture naturally increases the count.

Record:

```text
what command ran
what semantic gates passed/failed
what baseline was compared
```

not only “2164 PASS.”

## Byte-neutral/behavior-neutral comparison

During a migration, it can be useful to run the same fixed sample with a candidate integration enabled/disabled and compare outputs.

If a branch never fires, byte-neutral output is expected and useful—it shows unrelated rallies were not disturbed.

Then a constructed fixture must prove the branch itself.

## A failing test is evidence, not an instruction

When a test fails after a correctness change:

1. inspect what semantic claim the test makes;
2. determine whether the code violated it;
3. determine whether the claim itself was a legacy assumption;
4. repair the owner, not the easiest assertion.

Do not widen tolerances or lower thresholds until you understand the disagreement.

## Probe hygiene

Before trusting a measurement, check for confounds:

- mutable player fatigue/state carried between trials;
- cache warming;
- fixture branch never reached;
- event categories conflated;
- incorrect unit labels;
- test using display/default data as physical truth;
- RNG not reset/seeded.

A probe can be wrong even if production code is right.

## Test the boundary you changed

If you modify a serialization field, test save/reload.

If you modify a contact transfer relation, test the physical input/output relation.

If you modify overpass integration, test contact bookkeeping + continuation.

If you modify a theme, inspect the rendered theme states.

The closest focused test should fail before a broader outcome statistic is expected to move.

## Building a fixture from a bug

When you find a bug:

```text
live symptom
→ reduce to smallest deterministic state that reproduces it
→ encode fixture
→ verify fixture fails before fix
→ repair owner
→ verify fixture passes
→ run broad suite
```

That fixture becomes protection against recurrence and a piece of architecture documentation.

## Reading exercise

Open one current M4/M5 probe and one ordinary regression test. For each, write:

- input state;
- controlled variables;
- measured/asserted fact;
- whether it tests calculation or live integration;
- what it cannot prove.

## Source trail

- `tests/test_runner.gd`
- `tools/`
- `tools/preview/`
- `docs/review/` certification notes
- `docs/textbook/VALIDATION.md`

Next: how to decide whether a number should be derived, measured, or explicitly authored.