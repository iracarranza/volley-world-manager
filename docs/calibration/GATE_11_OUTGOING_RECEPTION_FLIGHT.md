# Gate 11: Outgoing Reception Flight

Date: 2026-07-30

## Question

Can every successful shadow reception create a complete outgoing `BallFlight`
without changing the official rally result?

## Contract

`RallyContactSystem.resolve_shadow_reception()` accepts the graded contact from
Gate 9. A candidate exists only when the contact was attempted and succeeded.
The candidate must preserve these exact equalities:

- flight origin equals contact position;
- flight start time equals contact time;
- flight destination equals the decision's outgoing target;
- calculated speed and duration describe the same distance and geometric arc.

Speed ranges, vertical angles, spin ranges, and stability ranges in
`ACTION_PROFILES` are game-balance fixtures. They are not aerodynamic
simulation and are not claims about real volleyball measurements.

## Reproduction

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --outgoing-flight --samples=120 --start-seed=110000
```

## Result

The controlled batch requested 600 serves across five styles. There were 590
eligible receptions, 10 serve errors, and zero invalid traces.

| Measure | Result |
|---|---:|
| Successful outgoing candidates | 265 / 590 (44.92%) |
| Continuity valid, given candidate | 100.00% |
| Mean speed | 5.91 m/s |
| Mean duration | 0.835 s |
| Mean stability | 0.797 |
| Mean topspin descriptor | 0.499 rps |
| Mean signed sidespin descriptor | +0.489 rps |
| Mean speed-duration relative error | below 0.000000000000001 |

All candidates in this fixture used `safe_center_pass`; action-profile
comparison is therefore not inferred from this batch. Gate 10 separately
demonstrated that elite fixtures can expose quick-release choices.

The speed fixture was revised during Gate 12. The first internally consistent
candidate averaged 7.75 m/s and 0.637 s, but it left every selected setter late.
The accepted 5.91 m/s / 0.835 s fixture preserves 100% internal continuity and
allows downstream second-contact windows. This is project calibration evidence,
not a real-world speed standard.

## Gate decision

Gate 11 passes. Contact-to-flight continuity is complete and deterministic in
shadow mode. The official `RallyEvent` reception and its legacy trajectory are
unchanged. Gate 12 may now let a setter perceive this outgoing flight and form
second-contact opportunities, still without changing the live result.
