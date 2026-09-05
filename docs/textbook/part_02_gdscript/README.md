# Part 2 — GDScript for This Codebase

Enough of the language to read and change the files Part 1 showed you — taught
against real scripts from this project rather than generic examples.

This part is deliberately **not** a GDScript tutorial. It covers the subset this
codebase actually uses, in the order you meet it, and spends its time on the
places where this project's conventions differ from the defaults.

1. [GDScript Basics](01_gdscript_basics.md) — the top of a script, typing,
   functions, and the six-question contract for reading anything unfamiliar
2. [Resources, Nodes, and Signals](02_resources_nodes_and_signals.md) — the two
   base types, how parts communicate, and reference semantics
3. [Collections, Types, and Null](03_collections_types_and_null.md) — arrays,
   dictionaries, schema drift, and a parser-error diagnosis table

## Prerequisites

- [Part 1 — The Project](../part_01_project/README.md)

## The three ideas to carry forward

1. **A signature is a claim.** Everything a function depends on should be in it.
2. **Choose the class by what the thing is, not by what is convenient.** A
   calculation in a Node is a calculation no test can reach.
3. **An untyped collection defers an error to somewhere less useful.** Type it
   where it is created.

## Where this leads

- [Part 3 — A Safe Development Workflow](../part_03_workflow/README.md)
- [Part 4 — The Match and Rally Engine](../part_04_match_engine/README.md)
