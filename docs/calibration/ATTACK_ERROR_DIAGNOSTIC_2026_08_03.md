# Attack Error Diagnostic

Date: 2026-08-03
Measured at: `a71590f` (merge of `codex/recover-player-state-ui` into
`claude/system-fit-serve-receive-von64k`)
Tool: `godot --headless --path . --script res://tools/run_attack_diagnostic.gd`

Ten career-name seeds x three fixtures = 30 matches, played through the real
career path (`prepare_fixture` then `resolve_active_rally` + `record_rally` per
rally, so rotation, fatigue and confidence all move as they do live).

## What was being asked

After the fatigue work, the attack-error rate improved a long way but stayed
out of the `rally_readiness_report.gd` reference band of `[0.06, 0.20]`, and
the spread across careers became enormous — 0.000 to 0.600. The question was
whether that spread is driven by roster capability or by something else, since
those answers lead to completely different work.

## Result: capability, but only the hitters'

| variable | Pearson | Spearman |
| --- | ---: | ---: |
| CA of players actually attacking | **-0.827** | **-0.682** |
| starting-lineup CA | -0.749 | -0.674 |
| opponent differential | -0.749 | -0.674 |
| **whole-roster mean CA** | -0.278 | **-0.048** |
| mean in-match fatigue | +0.687 | +0.860 |
| mean attack quality | -0.886 | -0.924 |

**Whole-roster mean CA has essentially no relationship to the error rate.** It
averages in players who never swing. A diagnostic built on it — which is what
was first proposed — would have reported that capability is not the driver and
sent the investigation somewhere else entirely. The distinction between roster
average and the ability of the players actually taking the attacks is the whole
finding; without it the correlation reads -0.05 instead of -0.68.

`opponent differential` is identical to `lineup_ca` here only because the
opponent is the same fixture opponent across careers, so it carries no
independent information in this sweep. It will once opponents vary.

## The response is a cliff, not a curve

Grouped by the CA of the players taking the attacks:

| quartile | hitter CA | error rate |
| --- | ---: | ---: |
| Q1 | 69.1 | 0.492 |
| Q2 | 73.6 | 0.150 |
| Q3 | 76.6 | 0.124 |
| Q4 | 79.6 | 0.028 |

Eleven points of ability — roughly one grade band — moves the error rate from
one swing in two to one in thirty-five.

The two extreme matches:

| | error rate | hitter CA | mean quality | mean fatigue |
| --- | ---: | ---: | ---: | ---: |
| best | 0.000 | 73.4 | 0.516 | 0.21 |
| worst | 0.597 | 68.6 | 0.196 | 0.38 |

Five CA points apart — about 7% — produce a **2.6x difference in mean attack
quality**.

## Reading

`attack_quality` amplifies hitter-ability differences enormously, and the fixed
`ATTACK_ERROR_THRESHOLD = 0.24` then sits inside the fat part of the resulting
distribution. Small ability differences therefore flip a large share of swings
across a hard cliff.

**This points the fix at the gain of the quality function, not at the
threshold.** Lowering the threshold only relocates the cliff — it would make
strong careers error-free and leave weak ones still dominated by errors, which
is what the earlier threshold sweep already showed.

Fatigue is real but secondary. Note Spearman (+0.86) is well above Pearson
(+0.69): the relationship is monotonic but distinctly non-linear, consistent
with fatigue mattering mostly once it is already high.

## Method notes that cost time to learn

- `fixture_base_seed()` hashes the **career name**, so one career is one sample,
  not a result. Several earlier attempts to read this number from a single save
  each reached a different and equally confident wrong answer.
- Measurements must record the commit they were taken at. Numbers from two
  different trees are not comparable, and both agents on this project have
  compared them at least once.
- Correlate against the ability of the players performing the action being
  measured, not against a squad or roster average.
