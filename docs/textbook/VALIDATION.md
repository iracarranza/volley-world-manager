# Validation Guide

Run commands from the repository root.

## Documentation source check

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

On this computer Godot may instead be located at:

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

This checks that documented source files and named symbols still exist. It cannot prove that explanations are conceptually correct.

## Project tests

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

## Parser and resource scan

```bash
/Users/iracarranza/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
```

## Git safety checks

```bash
git status --short
git diff --check
git diff --stat
```

Read the status before staging anything. Existing unrelated modifications belong to the person working on the project.
