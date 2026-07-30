# Gate 13: Shadow Playback Adapter

Date: 2026-07-30

## Question

Can continuous shadow evidence be represented with the existing `RallyEvent`
and `outgoing_trajectory` contracts without entering the official event list?

## Implementation

`RallyPlaybackAdapter.build_shadow_reception_events()` creates detached
`RallyEvent` resources, then serializes them for debug display and calibration.
The first event is the resolved reception flight. The second is the selected
setter's preparation and correction movement.

The reception event contains `metadata.outgoing_trajectory` with the exact keys
read by playback: `start_position`, `control_position`, `end_position`,
`apex_height_meters`, `start_time`, and `duration`.

## Reproduction and result

```text
Godot --headless --path . --script res://tools/run_rally_calibration.gd -- \
  --all-serve-styles --playback-adapter --summary-only \
  --samples=120 --start-seed=130000
```

The fixture requested 600 serves: 590 were eligible, 267 produced successful
shadow passes, and zero traces were invalid.

| Measure | Result |
|---|---:|
| Playback candidates | 267 / 590 (45.25%) |
| Events per candidate | 2.00 |
| Trajectory contract valid | 100.00% |
| Official events mutated | 0 |

## Gate decision

Gate 13 passes. The adapter proves that the proposed state pipeline can feed
the existing playback vocabulary without making playback metadata the source
of simulation truth. The detached events remain developer-only.
