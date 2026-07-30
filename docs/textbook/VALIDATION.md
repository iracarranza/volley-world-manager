# Validation Guide

Run commands from the repository root.

The project currently targets Godot 4.7.1. On another computer, replace the
executable in the examples with that installation's Godot 4 command. Establish
the baseline before editing; a historical check count in `STATUS.md` is not a
substitute for running it locally.

## Documentation source check

```bash
godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

On this computer Godot may instead be located at:

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
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
