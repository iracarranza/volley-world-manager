# P1-C2 — Godot Project and Runtime

Status: **VERIFIED**
Keywords: project.godot, main scene, Autoload, scene tree, runtime
Primary sources: `project.godot`; `scenes/application.tscn`; `scenes/application.gd`

## The project file

`project.godot` is the central configuration file. Important sections include:

- application name;
- `run/main_scene`, which selects the first scene;
- `[autoload]`, which creates global manager instances;
- display and rendering settings.

Do not edit generated files inside `.godot/`. Godot recreates them.

## Main scene

The configured main scene is `res://scenes/application.tscn`. Its controller, `scenes/application.gd`, changes which full-screen interface is visible. Its functions include `_show_title`, `_show_new_career`, `_show_dashboard`, and `_show_match`.

The application scene is therefore a navigation container. It should coordinate screens, not contain volleyball probability formulas.

## Autoloads

`GameManager` and `CareerManager` are globally available because they are configured as Autoloads. This is convenient, but global access is not permission to place every feature inside them.

Use this separation:

- models hold data;
- systems calculate;
- managers own long-lived state and workflows;
- scene scripts present information and translate user input into method calls.

## Runtime trace method

When you do not know what code runs:

1. identify the visible scene;
2. find its attached script in the `.tscn` file;
3. find the signal connection or callback for the user action;
4. follow each method call;
5. stop only when you reach the model mutation or calculation you care about.

This method is more reliable than searching for a plausible function name and assuming it is active.
