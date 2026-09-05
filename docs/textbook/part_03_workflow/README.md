# Part 3 — A Safe Development Workflow

How to change this project without breaking it, and how to *prove* you did not.

This part is short and is the most reusable in the book. Parts 4 to 7 all assume
the discipline described here: trace before you edit, measure before you change,
read the FAIL line, and record the commit your number came from.

1. [Safe Change Workflow](01_safe_change_workflow.md) — the six-step loop, the
   change worksheet, validation layers, measurement discipline, and the four
   stop conditions
2. [Debugging, Testing, and Git](02_debugging_testing_and_git.md) — fixed seeds,
   the testing layers, the balance probe, git in a tree several people are
   editing, and what makes a regression test real

## Prerequisites

- [Part 1 — The Project](../part_01_project/README.md) — you must be able to
  trace a call path
- [Part 2 — GDScript for This Codebase](../part_02_gdscript/README.md)

## The four habits

1. **Trace, do not guess.** Superseded paths in this codebase still parse.
2. **Measure the predecessor.** A delta with one end is not attributable.
3. **Read the FAIL line.** The total moves for reasons unrelated to correctness.
4. **Name the commit.** A number is worth only the commit it was measured on.

## Where this leads

- [Part 4 — The Match and Rally Engine](../part_04_match_engine/README.md)
- [Part 7 — Art, 3D Assets and the Drawn World](../part_07_art_and_assets/README.md)
