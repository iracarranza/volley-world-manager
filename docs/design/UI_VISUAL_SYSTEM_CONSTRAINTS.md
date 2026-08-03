# UI Visual System — technical constraints

Date: 2026-08-03
Measured at: `b33b5b9`

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

**Godot note:** `.tres` files cannot reference GDScript constants, so the theme
values are duplicated from `UIPalette` by hand or by a small generator tool. A
regression check asserting that a sample of theme colours equals the
corresponding `UIPalette` constant is what stops the two drifting; without it,
the duplication silently rots.

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
- **A grade colour map exists** — `AttributeProfiles.GRADE_COLORS` (S/A/B/C/D)
  plus the `GRADE_*_MIN` band constants. Fold these into `UIPalette` rather than
  defining a second grade palette; they are already consumed by the dashboard.

---

## 7. Player visual identity should reuse the 3D rig

`PlayerActor3D` already articulates a figure from `height_cm`, `wingspan_cm`,
`stride_length_m` and `dominant_hand`, scaling limb length and body height from
real player data — which is the exact input list a procedural bust would need.

Rendering that existing rig into a `SubViewport` texture is substantially
cheaper than authoring a parallel 2D bust pipeline, and it guarantees the roster
card and the match court show *the same player* rather than two representations
that drift apart as the model changes.

Note this has been scoped once already: a `Placeholder3D` slot existed on the
Roster tab and was removed during the roster rebuild.

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

- `godot --headless --path . --script res://tests/test_runner.gd` — 617 checks
  at `b33b5b9`. Theme work should not move this number; if it does, a scene
  binding broke.
- `tools/validate_ui_bindings.sh` exists and should be run after any `.tscn`
  restructuring — a `%UniqueName` left dangling by a node move is the most
  likely failure mode of this work, and it fails silently on tabs nobody opens.
- Add a check asserting `UIPalette` and the `.tres` themes agree on a sample of
  colours, per §1.
- After a fresh checkout or any new `class_name`, run
  `godot --headless --path . --import` first — see HANDOFF.md.
