# M9 — Tactical Causality: Scope and Authority

## Purpose

M9 certifies that a manager instruction changes the rally through a causal simulation path, not merely storage, labels, diagnostics, or presentation.

Required chain:

`manager instruction → team/actor intent → responsibility/action/position choice → physical situation → realised rally consequence`

A changed variable, log line, tooltip, event label, or outcome-rate shift alone is not proof.

## Entry condition

M8 contact/visual authority remains owned by its current implementation branch. This packet may be prepared in parallel but M9 implementation begins only after M8 closes or explicitly releases the affected authority boundary.

## Governing repository authority

1. Current implementation and active tests/probes.
2. Rally architecture and current implementation docs.
3. Existing tactic definitions/UI only as evidence of player-selectable intent; storage does not prove simulation authority.
4. Design prose where it does not contradict working implementation.

## M9 boundary

IN:
- every player-selectable tactical instruction that can affect a rally;
- storage/read path;
- simulation consumer;
- actor/team decision changed;
- resulting physical state/action changed;
- deterministic causal certification;
- home/opponent symmetry where applicable.

OUT:
- new tactical product semantics;
- outcome-rate tuning;
- attack/defence scaling redesign;
- M8 contact/trajectory authority;
- presentation-only effects.

## Classification

Each selectable instruction receives exactly one current-state class:

- `CAUSAL`: complete instruction→physical consequence chain exists and is certifiable.
- `PARTIAL`: live consumer exists but chain terminates before a realised physical consequence or bypasses required authority.
- `STORED_ONLY`: selectable/persisted but no live rally consumer found.
- `DEAD`: legacy/non-selectable path with no current gameplay authority.
- `UNKNOWN`: temporary census state only; must be eliminated before implementation begins.

## Completion criterion

M9 closes when every in-scope selectable instruction is either:

1. `CAUSAL` with deterministic evidence; or
2. explicitly removed/disabled from player choice because no governing semantics exist.

Do not fabricate semantics merely to eliminate `STORED_ONLY`.
