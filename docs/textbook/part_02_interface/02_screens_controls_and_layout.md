# 02 — Screens, Controls, and Layout

Status: **VERIFIED**

VWM's interface is built from ordinary Godot `Control` nodes, but the project deliberately separates three jobs:

```text
Application
→ which screen exists / is visible

Screen script
→ what this page contains and what signals it emits

Reusable component/theme systems
→ how repeated UI structures look and behave
```

That separation is the easiest way to understand the UI.

## `Control` is Godot's UI branch

A `Control` is a Node with rectangle/layout behavior. Buttons, Labels, Panels, Containers, ScrollContainers and most of VWM's interface descend from it.

Unlike a `Node2D`, whose position is primarily spatial, a `Control` participates in UI layout: anchors, offsets, minimum size, size flags and Containers can all affect where it ends up.

**Godot reminder:** when a `Control` is inside a `Container`, the Container usually owns its final rectangle. Manually changing the child's position may be overwritten during the next layout pass.

## VWM's screen router

`scenes/application.gd` is the high-level screen coordinator. It preloads screen scripts, receives signals from existing screens, lazily creates others, applies the current style, and swaps visibility.

The important flow is:

```text
screen emits intent
→ Application receives it
→ `_ensure_*()` creates screen if needed
→ `_adopt_screen()` attaches/styles it
→ `_show_only()` performs transition
→ `_swap_to()` controls visibility
```

The screen itself does not need to know the application graph.

For example, the desk emits:

```gdscript
signal opened(what: String)
```

and the application maps that key to a destination. This keeps `DeskScreen` concerned with the physical desk rather than with screen-navigation policy.

## Why some screens are made in code

Several screens are instantiated from scripts instead of `.tscn` files because their visible content is created from career/game state and a scene file would contain little beyond an empty root.

This is a useful Godot distinction:

```text
.tscn-authored screen
→ useful when hierarchy/static nodes are meaningful in editor

code-built screen
→ useful when hierarchy itself is generated from runtime data
```

Neither approach is inherently better. Use the one that makes ownership clearer.

## Lazy construction

`Application` does not build every expensive screen in `_ready()`.

The training/worksheet path can request dozens of posed sticker bakes. Paying that cost before the title screen appears caused startup stalls, so screens are created only when first requested.

Typical pattern:

```gdscript
func _ensure_training_screen() -> void:
    if _training_screen != null:
        return
    _training_screen = TrainingScreenScript.new()
    _adopt_screen(_training_screen)
```

This is **lazy initialization**: defer creation until there is a real consumer.

It is not the same as merely waiting one frame. A large cost deferred by one frame is still a large blocking cost; lazy construction removes the cost from sessions that never use the feature.

## Shared screen anatomy

`VolleyballScreenShell` builds the page structure common to many full-screen screens:

```text
Background
└─ MarginContainer
   └─ VBoxContainer
      ├─ ribbon
      │  ├─ title
      │  └─ actions
      └─ page/card region
         └─ content VBoxContainer
```

A screen asks `VolleyballScreenShell.build(...)` for this structure and receives a small `Shell` object containing references to:

- `content` — where the screen adds its own controls;
- `ribbon` — where extra top-level actions may be attached;
- `title` — so dynamic headings can be changed.

This is composition rather than inheritance. Screens do not subclass a giant `BaseScreen`; they receive a shared piece of UI and fill it.

## Containers are layout algorithms

VWM uses Containers heavily:

- `VBoxContainer` stacks children vertically;
- `HBoxContainer` places them horizontally;
- `MarginContainer` adds controlled padding;
- `PanelContainer` provides a themed surface around content;
- `ScrollContainer` lets content exceed its visible region.

A common beginner mistake is to think the scene tree is only a draw-order tree. For `Control` nodes it is also a **layout relationship**.

If a label wraps and a panel does not grow, inspect:

1. which Container owns the label;
2. the label's minimum size;
3. size flags;
4. whether the parent is itself constrained;
5. whether layout happens before the final text width is known.

`MenuCard`'s deferred `_grow_to_fit()` exists for exactly this reason: an autowrapped label's final minimum height is only meaningful after the layout system gives it a width.

## Anchors and full-screen controls

For dynamically adopted screens, VWM calls:

```gdscript
screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
```

This tells the `Control` to track the full parent rectangle.

**Godot reminder:** anchors are fractions of the parent's rectangle; offsets are pixel distances from those anchors. Presets are convenient ways to configure common combinations.

## Draw order still matters

Sibling order matters for `CanvasItem`-based UI. Later siblings normally draw over earlier ones.

VWM's screen wipe is intentionally kept as the last child. `_adopt_screen()` moves the wipe back to the end after adding a lazily created screen, otherwise the new screen could draw over the transition sheet.

This is a good example of a concern that is neither business logic nor theme styling: it belongs to the application/root presentation layer.

## Screen transitions do not own navigation

`UIStyleSystem.reveal()` handles the small fade/rise when a page becomes visible. `ScreenWipe` covers the actual screen swap.

Those effects decorate navigation. They do not decide **which** destination should open.

VWM boundary:

```text
screen signal / application route = navigation authority
screen wipe / reveal tween = presentation
```

If an animation breaks, the fallback should still leave a usable screen. `reveal()` explicitly restores a known visible/home state before creating its tween so a killed tween cannot leave an invisible but clickable page.

## Where to inspect this in Godot

Start with:

```text
scenes/application.tscn
scenes/application.gd
```

In the editor:

1. open `application.tscn`;
2. inspect its authored children in the Scene dock;
3. open `application.gd`;
4. note which screens are `%UniqueName` references and which are created later in code;
5. run the project and use the Remote scene tree to see code-built screens after they exist.

The **Remote** tree is essential when learning a code-built Godot project: it shows runtime Nodes that do not exist in the Local authored scene.

## Safe modifications

If you want to change:

- **which screen opens** → inspect signals and `application.gd`;
- **screen-wide shared anatomy** → inspect `screen_shell.gd`;
- **one screen's content** → inspect its script/scene;
- **global visual treatment** → inspect theme/style system;
- **transition animation** → inspect `screen_wipe.gd` / `UIStyleSystem.reveal()`.

Do not solve a global problem locally unless the exception is intentional.

## Source trail

- `scenes/application.gd`
- `scenes/application.tscn`
- `scenes/components/screen_shell.gd`
- `scripts/systems/ui_style_system.gd`
- `scenes/components/screen_wipe.gd`
- `scenes/screens/`

Next: the reusable physical-document vocabulary—paper windows, cards, tabs and related components.