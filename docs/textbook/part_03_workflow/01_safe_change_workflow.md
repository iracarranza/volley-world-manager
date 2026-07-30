# P3-C1 — Safe Change Workflow

Status: **VERIFIED** project workflow guidance
Keywords: scope, trace, contract, implementation, validation, documentation
Primary sources: [VALIDATION.md](../VALIDATION.md); `tests/test_runner.gd`

## The six-step loop

### 1. State one observable goal

Weak: “improve rallies.”
Strong: “during serve reception, choose among players using their current positions and ball arrival time.”

### 2. Trace current behavior

Find the input callback, manager call, simulation function, result model, and playback consumer. Write down exact source symbols.

### 3. Identify the contract

List inputs, outputs, types, metadata keys, side effects, and deterministic expectations. For playback, verify what the consumer reads instead of inventing a schema.

### 4. Make the smallest vertical change

A vertical change connects data, calculation, result, and visible or testable evidence. It is better than adding several unused abstractions at once.

### 5. Validate in layers

Run focused tests, full tests, parser scan, and a relevant manual scenario. Use a fixed seed when working on simulation.

### 6. Update status and evidence

If a feature is only foundational, label it partially implemented. Update the source manifest if a documented symbol moves.

## Change worksheet

```text
Goal:
Current call path:
Files expected to change:
Contract preserved or changed:
Focused test:
Manual visible sign:
Known non-goals:
```

## Stop conditions

Stop and investigate when unrelated files change, deterministic tests become unstable, a UI script begins owning core simulation state, or a “temporary” fallback hides invalid data.
