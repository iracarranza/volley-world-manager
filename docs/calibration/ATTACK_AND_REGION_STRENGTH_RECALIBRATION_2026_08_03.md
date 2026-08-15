# Attack and Regional Strength Recalibration

Date: 2026-08-03
Baseline: `b33b5b9`
Tools:

- `godot --headless --path . --script res://tools/run_attack_diagnostic.gd`
- `godot --headless --path . --script res://tools/run_region_strength_diagnostic.gd`

## Attack measurement correction

The original attack diagnostic inferred hitters from `decisive_actor_id` and
counted terminal rally outcomes. That actor can be a blocker or defender, and a
rally can contain multiple attacks. The corrected tool counts actual home
`ATTACK` events, reads the event actor, and uses the event's `attack_missed`
metadata and quality.

The fix has three parts:

- Compress raw hitter capability around 0.78 at 0.50 gain, preserving player
  order while reducing amplification.
- Reduce average-stamina match accrual from `0.008 + 0.012 decisive` to
  `0.0035 + 0.006 decisive`; an ordinary match now taxes rather than exhausts.
- Replace the hard `quality < 0.24` cliff with a bounded logistic response:
  10% floor, 30% ceiling, 0.12 response width around the same midpoint.

Across 10 career seeds x 3 fixtures, corrected home-swing error rates by hitter
CA quartile are:

| Quartile | Hitter CA | Error rate |
| --- | ---: | ---: |
| Q1 | 68.5 | 0.198 |
| Q2 | 72.3 | 0.204 |
| Q3 | 76.9 | 0.109 |
| Q4 | 81.2 | 0.050 |

This replaces the original cliff of roughly 0.49 to 0.03. The edge quartiles
sit about one to two percentage points outside the 0.06-0.20 reference band in
this 30-match sample; the middle half is in band. A narrower follow-up response
overfit the deterministic rally paths and performed worse, so these constants
retain the broader population result rather than chasing one draw. The bounded
10% per-swing floor prevents elite execution from becoming structurally
error-free, while finite samples can still produce a zero-error match.

## Regional strength

`region_strength` now measures the real population by `home_region`. Prime is a
positionally valid seven (1 S, 2 OH, 2 MB, 1 OP, 1 L), weighted 70% mean, 15%
best, and 15% weakest. The next seven provide depth; final strength is 65% prime
and 35% depth. Sixnet results update only `sixnet_form`.

Across six independently generated 1,200-player worlds:

| Region | Mean strength | Observed range |
| --- | ---: | ---: |
| Blôc du Larg | 77.28 | 74.31-81.74 |
| Xérvu | 77.06 | 72.81-79.61 |
| Pāwa Hitō | 76.77 | 73.63-78.27 |
| Ĭspayk | 76.30 | 73.91-78.34 |
| Taktikã | 76.29 | 72.77-80.57 |
| Landavol | 75.94 | 72.95-79.36 |
| Spëddigh | 74.80 | 73.05-77.20 |
| A'ace | 73.95 | 70.11-77.32 |

The scale makes the former drift thresholds inert. A meaningful neighboring
gap is now 4 points rather than 15, and isolated weakness begins below 74 rather
than 40. A'ace's low production strength is intentional: acquisition remains a
separate `club_region` effect.
