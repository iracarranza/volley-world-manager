# Team Identity Directional Baseline

Date: 2026-08-02

This report validates identity direction, not global match balance. It uses
`tools/run_identity_calibration.gd -- --samples=12`: 12 rallies from each
serving side for each of six independent career-name seeds, or 144 rallies per
identity. `fixture_base_seed()` is career-name-derived, so one career is not a
population result.

## Directional results

| Identity | Ace | Serve error | Serve quality | Home attack error | Home kill | Mean contacts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Balanced | 0.007 | 0.056 | 0.657 | 0.205 | 0.469 | 5.979 |
| Defensive | 0.007 | 0.056 | 0.642 | 0.093 | 0.397 | 6.201 |
| Fast Tempo | 0.007 | 0.056 | 0.666 | 0.362 | 0.447 | 5.861 |
| Physical | 0.014 | 0.063 | 0.672 | 0.328 | 0.444 | 5.847 |
| Technical | 0.007 | 0.056 | 0.649 | 0.202 | 0.429 | 6.014 |
| Development | 0.007 | 0.056 | 0.647 | 0.207 | 0.427 | 6.076 |

The regression contract intentionally compares broad directions:

- Physical serving must exceed Defensive in quality, ace rate and error rate.
- Defensive attacking must stay below Physical in both home attack-error and
  home kill rate. Control therefore buys safety at the cost of terminal output.
- Fast Tempo must produce fewer contacts per rally than Defensive.

`mean_home_attack_effectiveness` remains diagnostic rather than asserted. A
slower system can produce cleaner individual contacts even while ending fewer
attempts; requiring the mean to order by identity would conflate execution with
terminal output again.

## Calibration boundary

Neutral decisiveness (`0.50`) leaves attack effectiveness equal to execution,
and neutral serve risk (`0.50`) adds no reception pressure. This preserves the
existing Balanced inputs. Non-neutral identities change risk/reward around that
baseline; they do not modify player attributes or the global attack-error
threshold.

The global report is still not signed off. In this sample, ace rate remains
below the `0.02-0.10` reference band for every identity and block touch/stuff
rates remain high. Do not tune `ATTACK_ERROR_THRESHOLD` from one identity or one
career. Re-run the stratified report after any capability, fatigue, block, dig,
serve-reception or threshold change.
