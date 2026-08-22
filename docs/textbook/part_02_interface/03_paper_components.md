# 03 — Paper Windows, Cards, Tabs, and Reusable Components

Status: **VERIFIED**

VWM's interface is intentionally not a collection of generic panels. Different pages are represented as physical objects: journal cloth, paper forms, cork boards, manila cards, pinned slips, whiteboards and desk objects.

The implementation still uses ordinary Godot Controls. The visual language comes from **reusable components + the style system**, not from a separate rendering engine.

## Components are small architectural claims

Look in `scenes/components/` and you will find pieces such as:

- `paper_window.gd`
- `paper_tabs.gd`
- `plastic_tabs.gd`
- `pinned_slip.gd`
- `sticky_note.gd`
- `creased_edge.gd`
- `printed_rule.gd`
- `cork_board.gd`
- `dashboard_card.gd`
- `menu_card.gd`

These are not all “widgets” in the same sense. Some own interaction; some draw material/edge treatment; some wrap another Control.

The useful question is:

> What repeated visual or behavioral fact does this component own?

If the answer is only “this screen needed a border once,” it probably should not be a component.

## Composition instead of giant inheritance trees

Godot supports inheritance, but VWM frequently composes UI behavior.

A page may be:

```text
PanelContainer
+ style variation
+ PaperWindow child/overlay
+ printed rule
+ content Controls
```

rather than one enormous `PaperPageWithTabsAndRulesAndShadow` class.

This keeps the visual vocabulary reusable and lets the style system decide which pieces belong to a medium.

## Theme variation versus custom drawing

A Theme is good at stateful rectangular styling:

```text
Button normal / hover / pressed
Panel fill / border / margins
font sizes / colours
```

A custom component is better when the effect cannot be described as one normal rectangle:

- a hand-drawn edge;
- a folded/creased edge;
- pinned paper;
- cork texture;
- tabs projecting outside a page;
- irregular ink marks.

That division is visible in `UIStyleSystem`: it assigns theme variations *and* installs material-specific helper components.

## Godot reminder: drawing in a Control

A custom `Control` can implement `_draw()` and use methods such as `draw_line`, `draw_polygon`, `draw_circle`, etc. Godot calls `_draw()` when the CanvasItem needs repainting.

If internal state changes, `queue_redraw()` asks Godot to call `_draw()` again.

This is how an object can remain a normal UI node while drawing something more expressive than a StyleBox.

## Medium is data on the subtree

`UIStyleSystem` defines a `MEDIUM_META` key. A screen/root can set metadata declaring its material, and the recursive style walk carries that choice down the subtree.

Current media include concepts such as:

```text
drawn paper
sewn cloth
printed form
board
card
pinned/cork
```

The important design rule is that **drawn is the default and specialized media are explicit**. A new screen should not silently inherit the journal's cloth identity merely because the journal existed first.

**GDScript reminder:** Node metadata is arbitrary key/value data attached with `set_meta()` and read with `get_meta()` / `has_meta()`. It is useful for cross-cutting presentation tags that do not deserve a new property on every Control subclass.

## Names sometimes form a styling contract

`ScreenShell` names its backdrop `Background` because `UIStyleSystem` recognizes that name.

This is a project convention worth noticing: a Node name can sometimes be part of a styling contract rather than only a label for humans.

Before renaming UI nodes, search the codebase for the name.

## Why paper windows exist

Scrollable/readable regions such as `ItemList` or `RichTextLabel` can be made to look like a physical sheet without forcing the content generator to know how the sheet is drawn.

That gives a layered responsibility:

```text
content control
→ owns text/items

paper component
→ owns material/edge treatment

screen
→ owns meaning and arrangement
```

One bug recorded in the style system is instructive: applying an opaque paper overlay to a `ScrollContainer` hid the child controls because the content of a ScrollContainer *is made of child nodes*. A `RichTextLabel`, by contrast, draws its own text before children/overlays.

The fix was architectural: do not decorate every scrollable Control identically just because they share the word “scroll.”

## Cards: semantic surface versus button

`MenuCard` extends `Button`, but its comments make an important distinction: it is a **card that is clickable**, not a normal button made large.

That affects both layout and styling.

The card contains:

```text
MarginContainer
└─ HBoxContainer
   ├─ text column
   │  ├─ title
   │  ├─ flavour
   │  └─ current reading
   └─ optional figure column
```

Its child labels ignore mouse input so the entire parent Button remains the hit area.

The third line—the current reading—is what makes a card useful without opening it. That is an information-design decision expressed directly in component structure.

## Tabs represent the document, not only navigation

Paper/plastic tab components make tabs feel attached to folders/pages rather than like default application tabs.

When changing tabs, distinguish:

- TabContainer logic: which page is active;
- Theme/tab styling: basic state appearance;
- paper/plastic tab component: physical-document metaphor.

A visual defect should be fixed at the right layer.

## Reusable components should not become data authorities

A `PinnedSlip` may display a player's scouting information. It should not decide the scouting confidence.

A `DashboardCard` may display a result. It should not compute the career result.

A `PaperWindow` may size around content. It should not decide what content exists.

This is the same presentation boundary that appears throughout VWM:

```text
model/system decides fact
→ screen selects fact
→ component presents fact
```

## Inspecting component-built UI

Because many components are created in code, use both Local and Remote scene trees.

A useful workflow:

1. run the game;
2. navigate to the relevant screen;
3. switch Scene dock to **Remote**;
4. expand the screen subtree;
5. select the runtime Control;
6. inspect its Theme Type Variation, size, anchors and metadata;
7. return to the component script to see where those values originate.

This closes the gap between “what the code says it created” and “what Godot actually laid out.”

## Safe extension example

Suppose you want a new folder-like information panel.

Before making a new component, ask:

1. Is the material already represented by an existing medium?
2. Can a `ScreenShell` + existing panel variation provide the structure?
3. Is the unusual part content, or genuinely a reusable visual object?
4. Does the new component need interaction, or only drawing?

Prefer assembling existing vocabulary over inventing a near-duplicate surface.

## Source trail

- `scripts/systems/ui_style_system.gd`
- `scenes/components/screen_shell.gd`
- `scenes/components/paper_window.gd`
- `scenes/components/paper_tabs.gd`
- `scenes/components/plastic_tabs.gd`
- `scenes/components/pinned_slip.gd`
- `scenes/components/menu_card.gd`
- `scenes/components/creased_edge.gd`
- `scenes/components/printed_rule.gd`

Next: why the desk is intentionally *not* built like these document screens.