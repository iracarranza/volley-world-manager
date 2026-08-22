# Validation Guide

Run commands from the repository root. Use the Godot 4 executable installed on your machine; `godot` below means that executable.

Do not use an old check count as a substitute for establishing the baseline on the current branch.

## 1. Inspect the working tree first

```bash
git status --short
git branch --show-current
```

Existing unrelated work belongs to the current checkout/user. Do not reset/clean/stash it destructively just to obtain a clean test run.

## 2. Textbook source-manifest validation

```bash
godot --headless --path . \
  --script res://docs/textbook/tools/validate_textbook.gd
```

The validator checks:

- every listed textbook/reference file exists;
- every listed source file exists;
- every listed source symbol/string still appears in that file.

It does **not** prove conceptual accuracy, link targets inside Markdown, or current behavioral authority. Those require source/design review.

## 3. Parser/resource scan

```bash
godot --headless --editor --path . --quit
```

Use the first relevant parser/resource error as the starting point. Later errors may cascade from one dependency that failed to load.

## 4. Project test suite

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Interpret the semantic assertions, not only the number of printed checks. Sampling tests/added fixtures can change the count without a regression.

## 5. Focused probes

Run the probe/fixture closest to the boundary you changed before relying on the full suite.

Examples live under `tools/` and `tools/preview/`. Current rally review documents normally record the exact focused probe used for certification.

A focused probe should prove a named invariant such as:

```text
source launch unchanged
contact # correct
actor physically unavailable
save field survives reload
cache invalidates on source change
```

## 6. UI / visual validation

For scene/path changes, use the running Godot editor and Remote Scene Tree. If the repository's UI-binding validation script exists in the checkout, run it as well.

For visual behavior, use the relevant preview scene rather than treating a headless pass as proof of legibility.

## 7. Git diff checks

```bash
git diff --check
git diff --stat
git diff
```

Read the diff as a reviewer. Look for:

- unrelated edits;
- duplicated constants/authority;
- stale comments/docs;
- generated/cache files;
- accidental policy changes inside plumbing.

## 8. Documentation freshness check

For a textbook/design update:

1. inspect the live source symbols named by the chapter;
2. inspect the current canonical design/review authority;
3. ensure VERIFIED/PARTIALLY IMPLEMENTED/PROPOSED/HISTORICAL labels are accurate;
4. update `STATUS.md` and `source_manifest.json` if the architecture/source map changed;
5. keep historical Gate/session material marked historical.

## 9. Rally-specific certification

Do not treat an aggregate outcome rate as the first acceptance test for correctness migration.

Prefer:

```text
controlled fixture
→ focused physical/semantic invariant
→ live integration fixture
→ broad suite
→ observational census/outcome deltas
```

Production promotion is a separate decision; see [Certification and Production Promotion](part_07_working_safely/03_certification_and_promotion.md).

## Reporting a validation run

Record:

- branch/commit;
- exact command;
- focused probe result;
- full-suite result;
- known unrelated warnings separately;
- what semantic invariant the run proves;
- any part you could not execute.

A useful report says more than `PASS 2164`.