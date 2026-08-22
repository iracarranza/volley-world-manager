# 04 — The Desk and Diegetic UI

Status: **VERIFIED**

Most VWM screens are documents. `DeskScreen` is deliberately different: it represents the **room-level home state** from which the manager chooses what to pick up.

That distinction explains why the desk should not be understood as “a menu with fancy icons.”

## The desk's contract

`DeskScreen` documents three core rules:

1. objects are identified by their shape/context rather than large labels;
2. hover lifts/highlights the object's silhouette rather than tinting a generic rectangle;
3. anything that needs sustained reading opens a document/screen of its own.

So the desk is primarily navigation plus atmosphere.

Its signal is intentionally abstract:

```gdscript
signal opened(what: String)
```

The desk emits a key such as `training`, `scouting`, `housing`, etc. `Application` owns the mapping from that key to an actual screen.

This is an architectural boundary:

```text
DeskScreen
→ knows physical desk objects and clicks

Application
→ knows navigation graph
```

## A custom projection, not a 3D scene

The desk uses a deliberately simple closed-form projection from desk-space coordinates into screen coordinates rather than constructing the whole room in 3D.

The source represents objects in real-ish centimetres on a desk and uses one viewing elevation plus far-edge narrowing.

Why?

- layout remains deterministic and easy to author;
- click hit-testing can invert the same arithmetic rather than raycast;
- object scale can be compared in one unit system;
- the stylized drawing remains compatible with the rest of the 2D interface.

The important lesson is not “avoid 3D.” It is:

> use the simplest representation that preserves the facts the interaction needs.

## One coordinate system fixed several visual bugs

Earlier versions mixed normalized desk shares, hand-picked pixel heights, and raw screen-pixel room elements. Those values could not be compared.

The current desk instead describes footprints/heights in a shared physical-ish unit system. A mug beside a journal therefore acquires a sensible relative size without a second independent “mug scale.”

This echoes the simulation architecture: **shared units reduce hidden contradictions**.

## Painter's order

The desk is drawn using a painter-style ordering: nearer/higher-resting objects draw later.

An object entry carries a footprint plus `rest` and `height`. A clipboard can therefore lie across a journal by being physically above it in the desk model instead of by a special `DRAW_CLIPBOARD_LAST` rule.

This is a recurring VWM design preference:

```text
represent the cause
→ derive the visual/resulting order

rather than
encode the desired result directly
```

## Interactable and non-interactable objects coexist

Some desk objects open screens; others are simply furniture. This matters because a room containing only clickable destinations reads like a toolbar.

`FURNITURE` marks objects such as the lamp/mug/books that exist to establish place rather than navigation.

Do not assume every drawn object needs a game action.

## `_draw()` as a retained-state renderer

The desk is a custom-drawn `Control`. It stores object descriptions/state and draws them when Godot requests `_draw()`.

**Godot reminder:** custom drawing does not create a Node per visible stroke. A single Control can issue many Canvas drawing commands. This is useful when the drawing is tightly coupled and individual parts do not need independent scene-tree behavior.

The tradeoff is that hit-testing and hover state must be handled by the desk code because there is no Button node for every painted object.

## Tooltips are the accessibility/clarity layer

The “nothing is labelled” rule is a visual-design choice, not a requirement that objects be mysterious. Hover/tooltips can name an object and report current information without permanently turning the room into a diagram.

When extending the desk, preserve both sides:

- silhouette/context should make the object plausible;
- tooltip/interaction should make its function discoverable.

## Diegetic does not mean simulation-authoritative

A phone can represent calls, a clipboard can represent training, and a folder can represent housing. Those metaphors determine navigation/presentation.

They do **not** move career state simply because the object is drawn.

The owning management system still handles facts such as:

- training schedule/application;
- housing assignment;
- scouting/recruitment;
- career save state.

A desk click should request an action/screen, not directly rewrite the underlying model unless the desk itself truly owns that action.

## Where to inspect it

`DeskScreen` is mostly code-drawn, so the Remote scene tree tells you less about the individual desk objects than it does for a Container-built screen. Most objects are entries in the script's data tables rather than child Controls.

Use:

- source code for projection/object definitions;
- the running screen for visual placement;
- any desk-specific preview/probe for iteration;
- tooltips/click behavior to verify hit regions.

## Safe changes

For a new desk destination:

1. add/position an object only if it belongs in the room metaphor;
2. give it a stable `key` and tooltip;
3. emit the key from the desk;
4. map the key in `Application`;
5. keep screen creation/navigation outside `DeskScreen`.

For a visual adjustment, prefer changing shared projection/material facts over hand-correcting every object.

## Source trail

- `scenes/screens/desk_screen.gd`
- `scenes/application.gd`
- `docs/design/DIEGETIC_MANAGEMENT.md`
- `docs/design/THE_DESK_AND_THE_PHONE.md` where present
- related screen/component scripts

Next: the visual material stack—shaders, halftone, fibre, ink and surface treatment.