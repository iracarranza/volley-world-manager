# Part 1 — The Project

Read these chapters first, in order. They explain the product, the runtime entry
points, the directory structure, and one complete user-action path.

By the end of Part 1 you should be able to open the repository, find the code
that runs when a user does something, and know which directory a change belongs
in — before you know any GDScript at all. That is deliberate: **orientation
first, syntax second.**

1. [What You Are Building](01_what_you_are_building.md) — the product, the two
   loops, and why improvement has to be *legible*
2. [Godot Project and Runtime](02_godot_project_and_runtime.md) — `project.godot`,
   autoloads, the four architectural layers, and the runtime trace method
3. [Repository Map](03_repository_map.md) — every directory, the coupling rule,
   and a test for where new code belongs
4. [Following a User Action](04_following_a_user_action.md) — "Resolve Rally"
   traced end to end, and how to tell which side of a contract failed

## Prerequisites

None. Part 1 assumes no GDScript.

## Where this leads

- [Part 2 — GDScript for This Codebase](../part_02_gdscript/README.md) — the
  language, taught against files you have now seen
- [Part 3 — A Safe Development Workflow](../part_03_workflow/README.md) — how to
  change any of it without breaking the checks
