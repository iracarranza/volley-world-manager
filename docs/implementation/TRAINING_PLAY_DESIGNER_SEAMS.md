# Training Play Designer — Implementation Seam Map

This file translates `docs/design/TRAINING_PLAY_DESIGNER.md` into prerequisites without implementing the feature.

## Existing substrate

- `VolleyballPlayer` ratings and state.
- position familiarity and training.
- rating-derived system-fit concepts.
- tactical planner surfaces/state.
- rotation-specific tactical models.
- setter decision and authoritative rally execution.
- pair familiarity infrastructure.
- situation exposure/read infrastructure.
- daily schedule infrastructure.

## Missing substrate that must land before the visual designer

### 1. LearnedPreference authority

Need explicit persisted state for the things match training changes. Do not store a drawn polyline as the authoritative preference.

Minimum conceptual channels:

- hitter coordinate comfort by relevant lane;
- tempo comfort with hitter–setter relationship ownership;
- defensive loci/course comfort by rotation slot;
- block posture comfort by blocking pair.

### 2. Ask schema

A tactic/preset/drawing needs to decompose into comparable asks. Each ask should identify:

- subject/grain;
- requested behavior/target;
- natural comfort;
- learned offset/current comfort;
- source: comfort default / preset / manager override;
- practice priority/gap.

Do not make one universal numeric payload if different asks require different geometry.

### 3. Fit evaluator

Compare each ask to current comfort and return per-ask gaps. Aggregate summaries may exist, but the actionable unit remains the ask.

### 4. Training writer

A drill session must update the same learned-preference state the fit evaluator reads. Assistant-run and attended sessions must share this authority.

### 5. Demonstration compiler

Only after 1–4 exist, compile direct manipulation into asks:

`dragged player/path/target -> semantic route/coordinate/tempo/role ask`

The compiler should reject/flag impossible or unsupported concepts rather than storing arbitrary animation instructions.

## Runtime separation

### Demonstration playback
May use idealized automatic reception/dig -> set -> attack to explain the plan. This is presentation of intent.

### Practice execution
Must call authoritative player capability/decision/physics systems. This is where unfamiliarity and individual differences become visible.

Never use demonstration playback as practice truth.

## Save model

Prefer saving semantic asks plus optional authoring geometry needed to reconstruct the drawing. If both are saved, semantic asks are gameplay authority and drawing geometry is editor presentation metadata.

## Rotation handling

Honor the existing design principle: author a small number of meaningful base situations and derive rigid rotational permutations where possible. Per-rotation override remains advanced granularity, not mandatory administration.

## Match-earned drift

Where live match behavior and training refer to the same semantic quantity, successful repeated behavior may move the same learned preference. This requires an explicit merge rule:

- drill pressure moves toward manager ask;
- match evidence moves toward repeatedly successful realized behavior;
- manager may later encourage or revert.

Do not implement this as a second `placement_memory` if the quantity is semantically identical.

## UI build order

1. static court + actual rotation;
2. direct manipulation of semantic destinations/routes;
3. automatic ideal demonstration loop;
4. save/compile to asks;
5. fit/gap overlay;
6. actual practice attempt;
7. designed-vs-observed comparison;
8. derived rotation preview.

The interface is last in the dependency chain, not first.