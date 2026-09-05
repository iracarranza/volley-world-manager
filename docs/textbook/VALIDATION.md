# Validation Guide

Run commands from the repository root.

The project targets **Godot 4.7.2**, which is what every workflow in
`.github/workflows/` installs and what `project.godot` declares via
`config/features=PackedStringArray("4.7", ...)`. Install it with
`brew install --cask godot`, which puts `godot` on the PATH.

Establish the baseline **before** editing. A historical check count in
`STATUS.md` or `CLAUDE.md` is not a substitute for running it locally — those
figures are only worth the commit they were measured on, and at least one of
them has been stale for a week at a time.

## Documentation source check

```bash
godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

This checks that documented source files and named symbols still exist. It cannot prove that explanations are conceptually correct.

## Project tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

## Parser and resource scan

```bash
godot --headless --editor --path . --quit
```

## UI binding check

```bash
./tools/validate_ui_bindings.sh
```

This catches stale `%NodeName` and explicit `get_node()` paths that a script
parser can miss.

## Git safety checks

```bash
git status --short
git diff --check
git diff --stat
```

Read the status before staging anything. Existing unrelated modifications belong to the person working on the project.

## Passing-result interpretation

A successful foundation run prints `PASS: <number> volleyball foundation
checks` and exits successfully. Godot may subsequently print known shutdown-only
ObjectDB/resource warnings. The editor scan may print the inherited `MatchScreen`
recovery warning described in [FRESH_AGENT_HANDOFF.md](FRESH_AGENT_HANDOFF.md).
Report those separately; do not conceal a parser error or failed assertion among
known warnings.
