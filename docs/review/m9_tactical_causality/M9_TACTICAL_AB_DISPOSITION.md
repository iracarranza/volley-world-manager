# `chatgpt/m9-tactical-ab` disposition

Audit only; **do not merge**.

- The branch is rooted on the older pre-M8 line and its diff includes unrelated camera/player changes and deletions, not only a probe.
- `tools/run_tactical_ab_probe.gd` covers four spatial instructions already subsumed by the canonical 39-family, 240-gate M9 instrument.
- Its workflow changes repository-wide pull-request policy for `main` and downloads Godot 4.7.2, while the accepted/local certification toolchain is 4.7.1.
- The workflow and probe are coupled: merging the CI file alone would reference a script absent from canonical M9; merging both would duplicate narrower certification authority.

Useful idea retained: same-seed first-mediator comparisons with terminal outcomes treated as observations. Canonical `tools/run_m9_tactical_causality.gd` already implements that principle with population guards and both-side coverage. CI policy/toolchain migration remains separate debt.
