# UI Visual System — technical constraints

Date: 2026-08-03
Measured at: `b33b5b9`, revised against `f2fbc80` ("Recalibrate attacks and
split regional strength") after review.

> **Status as of 2026-08-06 (`819a9b8`): the work this planned is built.** See
> **[UI_VISUAL_SYSTEM.md](UI_VISUAL_SYSTEM.md)** for the system as it actually
> exists — the object classes, the treatments, and the two colour rules the
> drawn edges turned out to require.
>
> This page is kept as the record of the constraints, most of which held:
>
> - **§1 (three rendering paths, palette is a GDScript module) held in full**,
>   including the synchronisation test, which has since caught real drift.
> - **§3 (`theme_type_variation`) held**, and the variation list grew into the
>   object-class table that is now the centre of the system.
> - **§6 (grade colours move to `UIPalette`, thresholds stay in
>   `AttributeProfiles`) held** — and needed a second table. One set of five
>   colours cannot serve a dark page and a cream one; see the built doc, §4.
> - **§5 (fonts do not exist yet) is superseded.** Short Stack and Cherry Bomb
>   One are both in the tree and both under test for regional glyph coverage.
> - **§7 (player visual identity) partly landed.** The Roster's 3D slot exists
>   and renders the rig; per-player cosmetic variation is still the open
>   prerequisite it describes.
> - **§9's check count (620) is stale.** It is 925 at `819a9b8`. The line above
>   it — re-read the current count rather than trusting a figure quoted in a doc
>   — is the part that matters.

This is the **structural half** of the visual system: what the system has to
cover, where it has to live, and what already exists. It deliberately contains
no design taste — palette values, type scale, corner radii and motion curves
belong in `UI_VISUAL_SYSTEM.md` alongside the "continental gym toybox"
direction. The point of separating them is that the taste can change freely
later; the structure below cannot, without the same rework happening twice.

Every number here was measured from the tree, not estimated.

---

## 1. There are three rendering paths, and a Theme reaches only one

This is the single most important constraint, and the one a Theme-resource-only
plan gets wrong on day one.

| path | reachable by a `Theme`? | hardcoded colour today |
| --- | --- | ---: |
| Control nodes (`Label`, `Button`, `PanelContainer`, …) | yes | 252 `theme_override_*` lines |
| Custom `_draw()` — `player_attribute_wheel.gd` | not meaningfully | 17 `Color()` literals |
| 3D materials — `match_court_3d.tscn`, `player_actor_3d.gd` | **no, at all** | 16 across both |

`VolleyballPlayerAttributeWheel` paints its rings, spokes, potential polygon and
current polygon with literal `Color(...)` values inside `_draw()`. A `Theme` can
technically be queried via `get_theme_color()`, but only for items registered
against a control type — awkward, undiscoverable, and it still would not help
the 3D path at all. `MatchCourt3D` builds `StandardMaterial3D` in its scene file
and `PlayerActor3D._apply_material_color()` constructs materials in code.
Neither can consume a Control theme under any arrangement.

### Consequence: the palette is a GDScript module, not a Theme

```
scripts/data/ui_palette.gd     <- single source of truth, plain constants
        |
        +--> scenes/themes/*.tres      (Control nodes)
        +--> player_attribute_wheel.gd (custom _draw)
        +--> match_court_3d / player_actor_3d (3D materials)
```

`UIPalette` holds named colour tokens for both themes plus the semantic roles
(surface, surface-raised, ink, ink-muted, accent, positive, negative, grade
bands, regional accents). The `.tres` themes are written to match it and the
other two paths read it directly.

If the palette lives only in the `.tres` files, the wheel and the 3D court are
outside the system permanently and get hand-patched later — which is the
"another collection of hardcoded per-screen styles" outcome the work exists to
prevent, merely relocated.

### Neither `.tres` themes nor scene-defined 3D materials can read a constant

Both downstream targets are static resource data. Godot cannot reference a
GDScript constant from a `.tres` theme *or* from a `[sub_resource
type="StandardMaterial3D"]` inside a `.tscn`. So "read it directly" is only true
for code paths, and two mechanisms are required, both mandatory:

1. **A synchronisation test, not an optional one.** Theme values are duplicated
   from `UIPalette` by hand or by a generator. Either way the duplication rots
   silently unless a regression check asserts the `.tres` colours equal their
   `UIPalette` counterparts. Without it `UIPalette` is documentation, not a
   source of truth. Treat the check as part of the definition of done for the
   theme, not as a follow-up.
2. **A runtime material applicator for the 3D path.** `MatchCourt3D`'s court,
   lines, net and posts carry materials authored in the scene file, which will
   never see `UIPalette`. They need code that walks the mesh instances on
   `_ready()` and assigns colours from the palette — the pattern
   `PlayerActor3D._apply_material_color()` already uses for the player rig.
   Until that exists, the 3D court is outside the system regardless of what the
   palette module contains.

---

## 2. Theme coverage gaps

Control types by usage across all `.tscn` files, against what the two existing
themes actually define:

| type | uses | styled today |
| --- | ---: | --- |
| `Label` | 104 | font colour only |
| `Button` | 62 | colours + normal/hover/pressed |
| `OptionButton` | 40 | colours + normal/hover |
| `PanelContainer` | 16 | panel stylebox |
| `RichTextLabel` | 13 | **nothing** |
| `PopupPanel` | 6 | **nothing** |
| `CheckButton` | 6 | colours only |
| `LineEdit` | 5 | colour + normal |
| `ItemList` | 5 | **nothing** |
| `HSplitContainer` | 5 | **nothing** |
| `HSeparator` | 5 | **nothing** |
| `TabContainer` | 2 | **nothing** |

`RichTextLabel` is the third most-used control and carries most of the game's
prose — dossier, news, Sixnet standings, team summary. `ItemList` is every
roster and fixture list. `PopupPanel` is the Attribute Lab and Player Dossier.
All three are currently unstyled and inherit Godot defaults, which is a large
part of why the UI reads as a stock editor tool.

`TabContainer` matters more than its count suggests: the outer `Sections`
container hides its tabs (`tabs_visible = false`) and is driven by the custom
nav, but the Team sub-tabs are visible and are the only place default Godot tab
chrome is on screen.

---

## 3. Use `theme_type_variation` — it is used nowhere today

Zero occurrences across the project. This is the Godot mechanism for "same
control, different role" without per-node overrides:

```gdscript
theme_type_variation = &"ChunkyButton"    # defined once in the Theme
```

Without it, "chunky primary action" versus "compact stat button" versus "nav
item" becomes either three theme resources or three sets of local overrides —
i.e. the current situation with new colours. Name the variation set in the
system doc **before** any screen work, because retrofitting variations after
screens are restyled means touching every screen twice.

A minimum set worth defining up front: primary action, secondary/quiet action,
nav item, destructive action, sticker/tag, stat label, heading levels, card
panel, raised panel, and inset/well panel.

---

## 4. The migration is 252 override lines

| file | overrides |
| --- | ---: |
| `career_dashboard.tscn` | 85 |
| `main.tscn` | 57 |
| `new_career_screen.tscn` | 44 |
| `title_screen.tscn` | 43 |
| `match_screen.tscn` | 18 |
| `dashboard_card.tscn` | 5 |

Writing the theme is the smaller half of the job; deleting these and
re-expressing them as theme types and variations is the larger one.

By kind: `theme_override_constants` 142, `theme_override_font_sizes` 54,
`theme_override_colors` 37, `theme_override_styles` 19.

The 142 constants are mostly `separation` and margin values. They are the most
mechanical to centralise, the highest count, and the least visually risky —
a good first migration that proves the system end to end before colour and type
are touched.

---

## 5. Fonts do not exist in this project yet

No `.ttf`, `.otf` or `.woff*` anywhere. Everything currently renders in Godot's
built-in default face.

A rounded-humanist heading face and a compact statistical face therefore have to
be sourced, licence-checked and committed. Two requirements that are easy to
miss:

- **Tabular (fixed-width) figures on the statistical face.** Without them every
  numeric column — roster ability grades, Sixnet standings, attribute tables —
  shifts horizontally as values change. In a dense simulation UI this reads as
  cheap more than almost anything else.
- **Full coverage of the region name glyphs.** `Spëddigh`, `Pāwa Hitō`,
  `Xérvu`, `Taktikã`, `Braç Sindao` and `Tu'ul ys Feynt` need diaereses,
  macrons, acute accents, tildes and cedillas present in both faces, or region
  names fall back mid-string and look broken.

---

## 6. What already exists — do not rebuild it

- **Theme switching and persistence work.** `scenes/application.gd` holds
  `_load_theme()`, an `_apply_theme()` and a `theme_requested` signal from the
  title screen, with both `.tres` files wired. The gap is that the two themes
  are thin, not that the mechanism is missing.
- **Both theme resources exist** and already define `StyleBoxFlat`s for button
  normal/hover and panel.
- **A grade colour map exists** — `AttributeProfiles.GRADE_COLORS` (S/A/B/C/D).
  Move **only the colours** into `UIPalette`; they are presentation. The
  `GRADE_*_MIN` threshold constants beside them stay in `AttributeProfiles`,
  because what counts as an A is a domain decision the simulation owns, not a
  styling one. Moving the thresholds would put game balance in the UI layer.

---

## 7. Player visual identity should reuse the 3D rig

`PlayerActor3D` already articulates a figure from `height_cm`, `wingspan_cm`,
`stride_length_m` and `dominant_hand`, scaling limb length and body height from
real player data — which is the exact input list a procedural bust would need.

Rendering that existing rig into a `SubViewport` texture is substantially
cheaper than authoring a parallel 2D bust pipeline, and it guarantees the roster
card and the match court show *the same player* rather than two representations
that drift apart as the model changes.

Two constraints on that, both of which make this step larger than it looks:

**Portraits must be cached, not live.** Fourteen concurrently rendering
`SubViewport`s is a real cost, and the existing `MatchScreen` viewport is
already set to `render_target_update_mode = 4` (`UPDATE_ALWAYS`), so the project
has form here. Render each portrait **once** to a texture, cache it, and
regenerate only when the inputs change. The cache key is the physical profile —
height, mass, wingspan, position, handedness — which changes rarely and slowly
(aging), so the cache is cheap and long-lived.

**The rig cannot yet tell two players apart.** It varies body proportions and
handedness, but every player is drawn with the same skin colour: `Color("d6a06c")`
is hardcoded three times in `PlayerActor3D._configure_appearance()`, for head,
arms and legs. There is no hair, no facial variation, and no per-player cosmetic
data on `VolleyballPlayer` at all. Two players of similar build are currently
indistinguishable except by team colour.

So reusing the rig is still the right call — it is far cheaper than a parallel
pipeline and keeps one representation — but **portraits are not worth shipping
until per-player cosmetic variation exists**. That means new generated,
serialized fields on the player model (skin tone, hair style/colour, and
whatever else the art direction wants), which is a player-model change, not a
UI change. Sequence it accordingly: cosmetic identity first, portraits second.

Note the surface has been scoped once already: a `Placeholder3D` slot existed on
the Roster tab and was removed during the roster rebuild.

---

## 8. Component gallery requirements

Beyond "every control and state":

- The attribute wheel at **both** sizes — inline (400x285) and the expanded
  popup — since they are separate rendering paths with different presentation
  flags.
- The densest **real** list, at `Team.roster_limit` (14) rows, not a
  three-row sample. Density is the dashboard's actual problem and short samples
  hide it.
- Both themes side by side. The light theme is the one at risk: warm surfaces
  on warm surfaces lose panel separation, so whatever carries structure —
  outline, shadow, or fill — has to be verified there first, not in dark.
- Long-string cases: a full region name with diacritics, a 3-line trait list,
  and a `RichTextLabel` at its scroll threshold.

---

## 9. Verification

- `godot --headless --path . --script res://tests/test_runner.gd` — **620 checks
  at `f2fbc80`** (617 at `b33b5b9`, before the attack recalibration and regional
  strength split added three). Theme work should not move this number; if it
  does, a scene binding broke. Re-read the current count before trusting any
  figure quoted in a doc — that is what the "measured at" line is for.
- `tools/validate_ui_bindings.sh` exists and should be run after any `.tscn`
  restructuring — a `%UniqueName` left dangling by a node move is the most
  likely failure mode of this work, and it fails silently on tabs nobody opens.
- Add a check asserting `UIPalette` and the `.tres` themes agree on a sample of
  colours, per §1.
- After a fresh checkout or any new `class_name`, run
  `godot --headless --path . --import` first — see HANDOFF.md.
