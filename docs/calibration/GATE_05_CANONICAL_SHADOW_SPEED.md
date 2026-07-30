# Gate 5 Review: Canonical Shadow Reception Speed

Review date: 2026-07-29

Status: **SUPERSEDED BY GATE 20; HISTORICAL RESULT ONLY**

Gate 20 reversed this temporary decision after the full timing contract was
reviewed. Calculated signature speed is now authoritative and shadow duration
is derived from it. See `GATE_20_CANONICAL_SERVE_TIMING.md` for the current
contract. The measurements below remain useful as history, not current truth.

Gate 5 promotes duration-derived speed from a comparison candidate to the
canonical speed descriptor used by shadow reception. The prior independent
speed remains recorded under `independent_speed_candidate` for audit and
rollback comparisons.

This promotion does not replace the official receiver, reception quality, or
rally outcome.

## Reproduction command

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --canonical-shadow \
  --samples=120 --start-seed=50000
```

## Result

The batch requested 600 serves and produced:

- 585 eligible receptions;
- 15 service-error skips;
- zero malformed samples;
- complete coverage of all five serve styles;
- `canonical_derived_speed_rate` of 100%;
- canonical shadow reachability of 70.77%;
- official/canonical-shadow claimant agreement of 78.12%.

The independent-speed and derived-speed candidates selected different receivers
in 0.68% of eligible samples. For every serve style, canonical shadow
reachability exactly matched derived-speed-candidate reachability.

## Contract change

For shadow reception:

- `summary.signature` now contains the duration-derived speed;
- `summary.canonical_signature_source` is `duration_derived_speed`;
- top-level perception and opportunity fields in each trace entry are canonical;
- `shadow_selected` identifies the derived-speed receiver;
- the old calculation remains in `independent_speed_signature` and
  `independent_speed_candidate`.

The `legacy_claimant_id` remains the actor used by live rally resolution.

## Decision

The next shadow gate can use repeated in-flight observations without carrying
two competing speed clocks. Each new read should update perceived destination,
arrival time, confidence, and movement intent while preserving the player's
current position and commitment.

These results describe seeded game fixtures, not real-world volleyball
performance measurements.
