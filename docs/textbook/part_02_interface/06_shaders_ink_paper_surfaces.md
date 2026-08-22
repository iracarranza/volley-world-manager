# 06 — Shaders, Ink, Paper, and Surface Effects

Status: **VERIFIED AT ARCHITECTURE LEVEL**

VWM's visual style is produced by several layers that are easy to confuse when you first encounter Godot:

```text
Theme / StyleBox
→ ordinary UI shape, margins, state styling

custom Control drawing
→ irregular lines, edges, marks, cork, etc.

Canvas shader / material
→ per-pixel surface treatment such as fibre/halftone

palette data
→ consistent colours shared across systems
```

A visual bug is much easier to fix when you identify which layer owns it.

## What a shader is in this project

A shader is a small program run by the renderer for many pixels/vertices. In VWM's UI, the important shaders are primarily **surface treatments** rather than gameplay effects.

Files under `scenes/themes/` include `.gdshader` resources such as card-fibre and halftone treatments.

You do not usually call a shader function from GDScript. Instead, a `ShaderMaterial` references the shader and exposes parameters that code/resources can set.

**Godot reminder:** a Material belongs to rendering; changing a shader parameter changes how pixels are produced, not the underlying career or rally state.

## Theme versus shader

Suppose a button has the wrong corner radius. That is a Theme/StyleBox problem.

Suppose the paper grain is too dense at large window sizes. That is likely a shader/material scaling problem.

Suppose an irregular drawn border is wrong. That may be a custom drawing component such as `ink_outline.gd`.

Use the smallest correct layer.

## Halftone and resolution

`Application` explicitly listens for viewport size changes and synchronizes halftone scale. The reason is important: a dot period expressed directly in pixels changes its apparent physical density as the window resolution changes.

The desired relationship is closer to:

```text
same interface object
→ roughly same perceived print scale
→ regardless of window size
```

This is a common graphics issue: screen pixels are not automatically design units.

## Material language is semantic

`UIStyleSystem` does not apply one texture to every panel. It distinguishes media:

- sewn cloth;
- drawn paper;
- printed form;
- board;
- card;
- pinned/cork.

The medium says what kinds of visual marks make sense.

Examples from the style system's design comments:

- a stitched surface can use running stitches;
- a small button should not look “disabled” because stitching resembles a dashed disabled border;
- a paper control can receive an ink edge/highlighter;
- a manila card's fibre is the material itself rather than a print effect;
- a pinned cork board may leave the board bare while slips carry the information.

These are design rules expressed as code, not arbitrary decoration.

## Palette modules

VWM uses shared palette/data modules such as `ui_palette.gd`, `ui_halftone.gd`, and `ui_card_stock.gd`.

This avoids scattering literal colours through screens.

**GDScript reminder:** a script preloaded into a constant can act like a module when it exposes static data/functions. The caller does not need to instantiate a Node if the module holds no scene-tree state.

The benefit is consistency and inspectability:

```text
one semantic colour/material definition
→ many consumers
```

rather than each screen independently approximating the same paper colour.

## Custom ink edges

Components such as `ink_outline.gd`, `creased_edge.gd`, and `printed_rule.gd` represent effects that are easier to draw procedurally than encode as a rectangular StyleBox.

A procedural line can vary in geometry or mimic a hand/printing process while still being driven from deterministic inputs.

When editing these components, separate:

- **geometry** — where the line goes;
- **style** — width/colour/texture;
- **semantic trigger** — which UI medium/control receives it.

Changing geometry to compensate for a wrong semantic trigger is a maintenance trap.

## `draw_center = false` and layered buttons

Some VWM StyleBoxes deliberately avoid filling their center. That lets another material/ink/highlight layer provide the visible surface while the StyleBox still owns margins/corners/state geometry.

This is a good example of layered rendering: a StyleBox does not have to be the entire visual object.

## Theme changes and baked assets

The voli sticker pipeline shows a special case: the palette becomes part of a rendered texture. Once baked, the colours are literally pixels.

Therefore a theme change cannot merely recolour the Sticker node afterward. `UIVoliSticker.set_palette()` clears/rebuilds the relevant cache so the bake is produced in the correct palette.

This distinction is fundamental:

```text
live styled Control
→ can respond to theme data at draw time

baked texture
→ style is already embedded in pixels
→ invalidate/rebake when style input changes
```

## Shader debugging

If a shader-backed UI object looks wrong:

1. confirm the Control is actually using the expected Material;
2. inspect shader parameters in the Inspector/Remote tree;
3. check whether code changes parameters after `_ready()`;
4. test at multiple viewport sizes;
5. temporarily remove the material to separate shader output from underlying geometry;
6. inspect light/dark theme behavior separately.

Do not immediately edit shader math if the wrong node/material was assigned.

## Reading a simple shader

GDScript and Godot shading language are different languages. A `.gdshader` usually contains a function such as `fragment()` for pixel work.

Conceptually:

```text
input texture / UV / uniforms
→ shader arithmetic
→ output COLOR
```

You do not need advanced graphics mathematics to begin maintaining VWM's surface shaders. Start by identifying:

- uniforms (parameters supplied from outside);
- UV coordinates (position within the surface);
- texture samples;
- final colour/alpha.

Then change one parameter/effect at a time and compare using a controlled preview.

## Performance boundary

A visual effect that runs every frame on a large screen can be more expensive than a one-time component build. Conversely, a sticker bake is expensive because it performs offscreen 3D rendering/readback/tracing, then becomes cheap to reuse.

When optimizing UI, first identify whether the cost is:

```text
construction
layout
per-frame draw
shader pixels
image readback
cache miss
```

The fixes are different.

## Source trail

- `scripts/systems/ui_style_system.gd`
- `scripts/data/ui_palette.gd`
- `scripts/data/ui_halftone.gd`
- `scripts/data/ui_card_stock.gd`
- `scenes/themes/light_theme.tres`
- `scenes/themes/dark_theme.tres`
- `scenes/themes/card_fibre.gdshader`
- `scenes/themes/halftone_surface.gdshader`
- `scenes/components/ink_outline.gd`
- `scenes/components/creased_edge.gd`
- `scenes/components/printed_rule.gd`

Next: how VWM turns visual judgement into repeatable preview/probe work instead of editing by memory.