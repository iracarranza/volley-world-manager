# Gate 15: Disabled Rollout Boundary

Historical note: Gate 29 later implemented an audited activation branch while
leaving the production flag disabled. Gate 15 remains the baseline proof that
the off state preserves official event identity.

Date: 2026-07-30

## Question

Can the project expose one auditable reception-source boundary while proving
that no shadow event can become official yet?

## Implementation

`RallyFeatureFlags.ENABLE_CONTINUOUS_RECEPTION_EVENTS` is the centralized
production flag and is `false`.

`RallyRolloutPolicy.select_reception_source()` always returns the existing
official events. It reports whether a shadow candidate was available, but it
contains no activation branch. Changing the constant alone therefore cannot
silently activate the migration; a later reviewed gate must implement that
branch deliberately.

## Reproduction

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --disabled-rollout --summary-only \
  --samples=120 --start-seed=150000
```

## Result

The fixture requested 600 serves. There were 585 eligible receptions, 15 serve
errors, and zero invalid traces.

| Measure | Result |
|---|---:|
| Rollout status recorded | 100.00% |
| Flag enabled | 0.00% |
| Official source selected | 100.00% |
| Official event identity preserved | 100.00% |
| Shadow candidates available | 43.59% |

## Gate decision

Gate 15 passes. The migration now has a searchable, centralized boundary but
remains impossible to activate accidentally through the current policy. Live
reception rollout still requires a separate gate, explicit implementation,
visible 2D review, and comparison acceptance criteria.
