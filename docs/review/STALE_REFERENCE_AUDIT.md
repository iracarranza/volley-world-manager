# Stale reference audit

Run: 2026-08-16, on `4e63097`. Instrument:
`tools/audit_stale_references.py`. **Six comments repaired; 93 dangling names
reported and left.**

The house style explains *why* a decision was made and cites the function that
made it. That is what makes the comments in this repository worth reading, and
it is also what makes them fragile: delete a function and every comment naming it
becomes a confident statement about code that is not there.

`tools/audit_stale_derivations.py` — which looks for values derived before their
input is reassigned — returns **0 candidates** on `rally_simulator.gd`, and
`prose_audit_findings.json` catalogues 128 findings about *style*. Neither
catches factual staleness. This does.

## What it looks for

Every symbol declared anywhere (`func`, `const`, `var`, `class_name`, `signal`,
`enum`), then every comment mentioning a name in one of two shapes — a
`` `backticked` `` reference, which is the house convention, or a
`_leading_underscore` name, which is unambiguously private. A name matched by
neither any declaration nor any bare mention in code is dangling.

Conservative on purpose: prose is full of ordinary words, and anything looser
drowns the signal.

## Repaired

### One orphaned doc comment — the serious one

Deleting `_serve_arc` in the forward-serve pass left its **nineteen-line doc
comment behind**, sitting immediately above `_swing_spin`'s own doc comment with
no separation. Anyone reading `_swing_spin` met a preamble about serve arcs,
minimum-force solves and a shadow record, describing a function that no longer
exists, and would reasonably have assumed it applied to the swing.

This is the same failure that once deleted `_venue_camera` in this repository —
slicing a function out by text and not checking what the cut left attached to its
neighbour. It is exactly what this audit is for, and it was self-inflicted two
commits earlier.

### Five renamed or relocated references

| where | said | now says |
|---|---|---|
| `attack_power_model.gd:77` | `` `_serve_arc`'s relief loop `` | the serve's relief sweep, with the old and new names given |
| `attack_power_model.gd:93` | `` `_serve_arc` already documents `` | `GeometricAttackResolver._serve_launch` |
| `ball_spin.gd:156` | `` `_serve_arc`'s relief sweep `` | the sweep, with both names |
| `career_state.gd:116`, `volleyball_player.gd:13`, `execution_scale_calibration.gd:79,162` | `` `PlayerGenerator` `` | `VolleyballPlayerGenerator`, the actual `class_name` |

## Deliberately left: history is not staleness

Four surviving `_serve_arc` mentions are **correct** and must stay. They are
comments that say what a thing *used to be* — "these four lived in
`rally_simulator._serve_arc` and have been moved here", "`SERVE_PACE_RELIEF_FLOOR`
stopped the sweep at 0.55". A provenance journal in the comments is the house
style, and naming a deleted symbol in the past tense is the point of it.

**The tool cannot tell these apart from stale ones**, and should not try — the
distinction is tense, and tense is a judgement. Every hit needs reading. That is
also why this audit repaired six comments rather than ninety-three.

## Reported and not repaired: 93 dangling names

Roughly three classes, and only the first is worth systematic work:

1. **Symbols that were deleted or renamed.** `_dig_contest`,
   `_floor_defense_terms`, `_best_blocker`, `_opponent_tempo_call`,
   `_best_positioned_defender`, `_reception_recovery`, `contest_shares`,
   `DIG_LATE_ARRIVAL_SECONDS`, `BLOCK_DESCENT_SECONDS`, `TOOL_EDGE_MARGIN`,
   `MIN_JUMP_DISPLACEMENT_METERS`. Each needs a read to decide tense.
2. **Probes that no longer exist** — `run_ball_flight_probe`,
   `run_mark_extent_probe`, `run_window_budget_probe`, `run_block_verdict_probe`,
   `run_variant_mix_probe`, `run_wall_reach_probe`, `run_playback_schedule_probe`.
   Comments citing a measurement instrument that has been deleted are a specific
   problem for this codebase, because the numbers those probes produced are
   quoted all over the comments and can no longer be reproduced by anyone
   following the citation.
3. **Local variables, doc names and prose** — `BACKLOG`, `FAILURE_MODES`,
   `OUTSTANDING`, `yc`, `Working`, `Watched`, `MAX`. Mostly noise; the doc names
   would be cheap to filter.

**Class 2 is the one worth raising.** Seven deleted probes are cited as the
source of measured claims. `docs/FAILURE_MODES.md` §0 is about numbers measured
with the wrong instrument; a number whose instrument has been deleted cannot be
re-measured at all, and the comment quoting it will outlive anyone's memory of
whether it was right.

## Re-running

```bash
python3 tools/audit_stale_references.py scripts scenes tests
```

Reading each hit is the work. The tool only says which names have nothing behind
them.
