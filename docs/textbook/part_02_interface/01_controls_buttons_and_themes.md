# 7 — Controls, Buttons, Themes, and Interaction States

Status: **VERIFIED CORE PATH / SCREEN CONSUMERS TO BE EXPANDED**

VWM's UI is built from ordinary Godot controls, but most of its visual identity comes from **shared Theme resources plus reusable component scripts**, not from individually styling every button on every screen.

A useful first trace is `MenuCard`.

```gdscript
class_name MenuCard
extends Button
```

That one line tells you two things at once:

- `MenuCard` is a VWM-specific class;
- it inherits Godot's `Button` behavior instead of reimplementing clicking/focus/interaction from scratch.

**Godot reminder — inheritance**

`extends Button` means a `MenuCard` *is* a Button with additional behavior. Since `Button` itself belongs to Godot's `Control` UI family, `MenuCard` also participates in Godot's UI layout, focus, mouse input, theme lookup, and sizing systems.

## A VWM button has two different kinds of behavior

When reading a control, separate:

```text
what it looks like
from
what it does when activated
```

Godot's Theme system handles much of the first. Signals/callbacks and the owning screen/application code handle the second.

That separation is useful because changing a border radius should not require touching career logic, and opening a new screen should not require reimplementing button drawing.

## Theme resources

VWM currently has shared Theme resources including:

```text
scenes/themes/light_theme.tres
scenes/themes/dark_theme.tres
```

A `.tres` file is a serialized Godot Resource. Here the resource is a `Theme`.

The Theme contains reusable styles such as:

```text
ButtonNormal
ButtonHover
ButtonPressedInked
ButtonDisabled
PrimaryNormalInked
PrimaryHoverInked
QuietNormalInked
DangerNormalInked
```

These are `StyleBox` resources describing things such as:

- margins/padding;
- background color;
- border widths/colors;
- corner radii;
- shadows.

So a visible button is not usually "drawing itself." Godot asks the active Theme for the style corresponding to that control and interaction state.

## Interaction state is engine behavior

A button naturally moves through states such as:

```text
normal
hover
pressed
disabled
```

You do not need to write an `_process()` loop that checks whether the mouse is over every button and manually swaps its border.

Godot's Button/Control system already knows its input state and requests the appropriate theme style.

This is why `light_theme.tres` can define different boxes for normal, hover, and pressed states and the same `MenuCard` code can focus on content/layout.

## Where to inspect this in Godot

A practical path is:

```text
FileSystem
→ scenes/themes/light_theme.tres
→ Inspector
→ inspect Button/theme style entries
```

You can also open the `.tres` as text to search style resource names directly.

When you later inspect a particular Button in a scene, remember that its final style may come from:

```text
project/control Theme
→ theme type
→ theme variation/override
→ per-control override (if any)
```

The visible result is therefore a lookup chain, not necessarily one property authored on the Button itself.

## `MenuCard` composes its own children in code

The card's visible content is not a single Button label. `_compose()` creates nested containers and labels:

```gdscript
var margin := MarginContainer.new()
add_child(margin)

var row := HBoxContainer.new()
margin.add_child(row)

_column = VBoxContainer.new()
row.add_child(_column)
```

This is runtime UI composition.

**GDScript reminder — `:=`**

`var row := HBoxContainer.new()` creates a mutable local variable and asks GDScript to infer that it contains an `HBoxContainer`.

**Godot reminder — Containers**

Containers are Control nodes that arrange child Controls. A `VBoxContainer` lays children vertically; an `HBoxContainer` lays them horizontally; a `MarginContainer` adds a margin/layout wrapper around its child content.

The hierarchy is doing real layout work:

```text
MenuCard (Button)
└─ MarginContainer
   └─ HBoxContainer
      ├─ VBoxContainer (title/flavour/reading)
      └─ VBoxContainer (optional figure column)
```

That diagram is more useful than thinking of the card as "one button with some text."

## The whole card remains the hit area

`MenuCard` deliberately makes its child text ignore mouse input:

```gdscript
margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

and similarly for internal containers/labels.

Why?

Because the **Button itself** should receive the click. If a decorative/child Control intercepts pointer input, a user may have to click an arbitrary empty corner instead of anywhere on the card.

This is a good example of causal learning: `mouse_filter` matters because VWM's component is visually richer than a default text-only button while still needing one coherent hit target.

## Size flags and minimum size

The card sets:

```gdscript
custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

The first says "do not let layout shrink me below this minimum."

The second says the Control should expand/fill available horizontal space when its parent Container lays it out.

But the script later allows the height to grow when text wraps:

```gdscript
custom_minimum_size.y = maxf(
    CARD_HEIGHT,
    _column.get_combined_minimum_size().y + CARD_PADDING
)
```

The important architecture idea is that **the Container owns layout placement**, while the child reports constraints such as its minimum size.

If a card clips text, the first question is therefore not "which pixel coordinate is wrong?" It may be "what minimum size did this Control report, and when did Godot know the wrapped label's height?"

## Deferred layout work

`MenuCard` connects:

```gdscript
_column.minimum_size_changed.connect(_grow_to_fit)
```

and may use deferred execution after resize.

This exists because text wrapping depends on width, and width is assigned during a layout pass. The script cannot always know the final required height at the exact instant text is assigned.

This is a recurring Godot idea:

> some UI facts only become true after the engine has performed layout.

Later render chapters show an analogous issue with frames: some image facts only become true after the renderer has produced a frame.

## Signals: appearance ends, behavior begins

A `MenuCard` inherits the standard Button `pressed` signal.

A screen that owns the card can connect that signal to a callback which opens the appropriate page/window or performs another action.

Conceptually:

```text
Theme determines how card looks in current state
↓
Button receives user activation
↓
`pressed` signal fires
↓
owning screen/application callback responds
↓
game/navigation action
```

The exact final callback depends on which screen created the card; that consumer trace belongs in the screens/navigation chapter rather than inside the reusable card component.

**VWM boundary**

`MenuCard` should know how to be a good reusable menu card. It should not become the authority for the career/club system it opens.

## Static builder pattern

`MenuCard` exposes:

```gdscript
static func build(title: String, flavour: String) -> MenuCard:
    var card := MenuCard.new()
    card._compose(title, flavour)
    return card
```

Read the signature first:

```text
inputs: title String, flavour String
returns: MenuCard
```

Because the function is `static`, callers can ask the class itself to build a ready-to-use card.

The implementation then:

```text
construct instance
→ compose its child hierarchy
→ return configured instance
```

This is different from instantiating a `.tscn`: this component is assembled by script.

## What to change for common tasks

### "Change button colors/borders globally"

Start with the relevant Theme resources, not every screen script.

### "Change only the MenuCard's internal spacing"

Inspect `menu_card.gd`, especially `_compose()` and the Container/theme constant overrides.

### "Change what happens when one particular menu card is pressed"

Find the screen that builds/connects that card. Do not put the destination-specific logic into reusable `MenuCard` merely because it receives the click.

### "The text overflows the card"

Inspect minimum-size calculation, autowrap behavior, parent container width, and the deferred layout timing before hardcoding a larger fixed height.

## Source-reading exercise

Before reading the comments in `MenuCard._compose()`, try to identify:

1. which node remains the actual clickable Button;
2. why the nested Controls ignore the mouse;
3. which Container owns the left text stack;
4. which member contains the optional right-hand figures;
5. why a wrapped line can force a later minimum-height recalculation.

If you can answer those, you are already reading Godot UI architecture rather than merely GDScript syntax.