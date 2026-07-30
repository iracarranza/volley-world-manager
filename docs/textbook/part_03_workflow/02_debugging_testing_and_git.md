# P3-C2 — Debugging, Testing, and Git

Status: **VERIFIED**
Keywords: fixed seed, test runner, parser scan, git diff, regression
Primary sources: `tests/test_runner.gd`; [VALIDATION.md](../VALIDATION.md)

## Debugging from evidence

Capture the exact symptom, seed, event sequence, actor IDs, positions, ball trajectory, and expected behavior. “Movement looks wrong after ten seconds” becomes actionable when paired with the first event where position continuity breaks.

## Fixed-seed debugging

The simulator seeds its random generator. Reuse one seed while investigating so changes in output are caused by code, not a different random sequence. A deterministic test should compare meaningful invariants rather than every incidental number.

## Testing layers

- unit-like checks: one model or calculation;
- contract checks: producer output matches consumer expectations;
- integration checks: a real entry point reaches the intended system;
- parser/resource scan: all scripts and paths load;
- manual playback: timing and readability feel correct.

Automated tests cannot decide whether a rally looks natural. Manual viewing cannot reliably prove edge cases or deterministic behavior. Use both.

## Git as a safety tool

Before editing:

```bash
git status --short
```

After editing:

```bash
git diff --check
git diff --stat
git diff -- path/to/file.gd
```

Do not discard modifications merely because you did not create them in the current session. They may be unfinished user work.

## Good regression test

A good regression test fails for the original defect, passes after the fix, uses the smallest stable setup, and explains the gameplay contract through its assertions.
