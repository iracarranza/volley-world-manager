# UI Visual System — as built

Date: 2026-08-06
Measured at: `819a9b8`.

The companion to `UI_VISUAL_SYSTEM_CONSTRAINTS.md`, which described what the
system had to cover before any of it existed. This describes what it *is*. The
constraints doc deliberately held no taste; this one is nothing but, plus the
mechanics that taste turned out to require.

Every figure here was read from the tree. Re-read before trusting it.

---

## 1. The claim

**The interface is a manager's working journal.** Not "styled like" one — the
page is made of things, and every element on it is one of them. A card is a
scrap of cloth cut out and sewn on. A button is a word somebody wrote. The
section menu is a tape measure. A scrolling region is a slip of paper threaded
under the page. The tabs are index tabs cut into a divider.

This is a stronger constraint than a palette, and that is the point: it decides
questions a palette cannot. "What should the hover state be?" has no answer in
a colour system beyond *some other colour*. It has one here — hovering a written
word is going over it with a highlighter, so the wash sweeps on under the
pointer. "What should a scrollbar look like?" is likewise not a taste question
once the region is a slip: it looks like the tab you pull the slip by.

The failure mode this exists to prevent is the one every mixed interface has —
one element drawn by hand next to one struck from a stylebox, which reads not as
two styles but as two applications. **One instrument made the page or it did
not.**

---

## 2. Object classes

The styling pass (`scripts/systems/ui_style_system.gd`) assigns every `Control`
in the tree to a tier, and the tier decides the treatment. The tier list is the
real content of the system; everything else is drawing.

| tier | what it is | edge | mark |
| --- | --- | --- | --- |
| `RaisedPanel` | the sheet everything else is on | sewn | — |
| `CardPanel` | a patch sewn onto the sheet | sewn | — |
| `InsetPanel` | a patch for reserved or preview space | sewn | — |
| `DashboardCard` | one pane of a block cut from one piece | sewn | — |
| `PrimaryAction` … `ChoiceChip` | a word written on the page | nib | highlighter on hover |
| `TapeCase` | the housing the section tape comes out of | none | shell lifts |
| `TapeAction` | a label printed on the steel band | none | — |
| `BareRegion` | a wrapper whose only content is a control | none | — |
| `HitArea` | a clickable region that draws nothing | none | — |
| `FrontmostPanel` | a `PopupPanel`, i.e. a `Window` | stylebox | — |

Two of these were added after the system was otherwise finished, and both were
found by the same failure. They are worth stating as a rule:

> **"Is a `Button`" and "is a control the reader is meant to see" are different
> questions.** Classifying by widget kind answers only the first.

`OpenTacticalWorkspaceButton` is a flat, textless `Button` stretched over the
whole 680×390 tactical preview so that clicking the court opens the full board.
By widget kind it is an ordinary secondary action, so it was given a nib outline
around the entire court and a highlighter wash that swept across the court on
hover. The tactical screen had become a highlighted button. `HitArea` detects
that structurally — `flat`, empty `text`, no `icon` — and leaves it alone.

`TapeCase` is the same lesson from the other side. The navigation button spent
two rounds of work being a control that sat *next to* a tape measure, and no
amount of closing the gap between them ever joined them, because one was a
written word and the other was an object. It is now the case itself.

`FrontmostPanel` is the one exception that cannot be removed: `PopupPanel`
derives from `Window`, is not a `CanvasItem`, and has no surface to draw
through. It keeps a stylebox border. Its *contents* are ordinary panels and get
the treatment on their own.

---

## 3. Treatments

### The nib (`scenes/components/ink_outline.gd`, `Stroke.INK`)

A broad-nib pen, drawn as a closed quadratic ribbon. Width depends on the
direction of travel relative to the nib angle — `|sin(θ_travel − θ_nib)|`, which
is the whole reason calligraphy reads as calligraphy — so the top and bottom
runs come out light and the sides heavy. Corner radii are read from the parent's
own stylebox, all four separately, so the pen turns where the panel turns.

Two things it does *not* do, both of which were tried:

- **Per-segment `draw_line` calls.** They put three discontinuities at every
  joint — two overlapping antialiased quads compositing darker, a width sampled
  fresh, an alpha sampled fresh. Measured on a straight run the stroke swelled
  2→4 px with its strongest periodicity at exactly `SEGMENT_LENGTH`. A regular
  bead every 6 px over a halftone reads as cross-stitch, not ink.
- **Large wander.** `WANDER_PIXELS` is 0.40. A drawn line is mostly straight;
  what says "hand" is variation in the *ink*, not deviation of the path.

### The seam (`ink_outline.gd`, `Stroke.STITCH`)

A running stitch: lens-shaped marks laid along arc length, so their size and
spacing are the same on a long side as on a tight corner. The pitch is rescaled
so a whole number of stitches closes the loop exactly — a sampler is counted out
before it is sewn. Around it: a cut silhouette (`_cut_offset`, held flat across
a facet then stepped, never interpolated), wire stubs where the patch was
separated from its sheet, and a few loose threads.

The seam runs `SEAM_INSET` (5 px) *inside* the boundary. A stitch on the true
edge makes the card stop exactly where its sewing does, which reads as a dashed
border rather than as cloth with a seam in it.

### The highlighter (`ink_outline.gd`, `hover_highlight`)

A chisel-tip wash *behind* the label, absent at rest. Colour is `stroke_strong`
— the same ink the nib is using — because a highlighter that contrasts with the
line it covers is two marks arguing, and because the nib's varying weight is
what read as highlighter in the first place.

Five things vary per control, all seeded from its name:

- where each end over- or under-shot the word
- where the band sat vertically relative to it (`HIGHLIGHT_DRIFT`)
- whether the hand ran level or downhill across it (`HIGHLIGHT_TILT`)
- how the chisel was held (`HIGHLIGHT_SHEAR_SPREAD`)
- which end the stroke started from (`HIGHLIGHT_REVERSE_CHANCE`, 0.30)

Duration scales with the control's width against a 150 px reference, taking
`HIGHLIGHT_SWEEP_LENGTH_SHARE` (0.42) of the difference. A fixed duration is a
fixed *duration*, not a fixed speed: at 0.16 s flat a 60 px chip and a 320 px row
were marked in the same time, so the hand went five times faster across the long
one, and the eye reads that as two different gestures.

### The tape measure (`scenes/components/tape_measure.gd`)

One script, three pieces: `CASE`, `BAND`, `TANG`. The case is a moulded shell
with a reel, a rubberised base and a lipped slot at the nose; the band is a
steel rule with graduations that stay put as it extends (a tape whose markings
move when you pull it is a barber's pole); the tang is a plate riveted to the
band's end, narrower than it and rounded off.

The section buttons sit *on* the band, and the band's whole denominations land
on their edges — handed in by the drawer rather than derived from a pitch,
because only the drawer knows where its buttons ended up. A rule whose numbers
fall at arbitrary points between the buttons is two unrelated things sharing a
strip.

Motion: `TRANS_QUINT`/`EASE_OUT` over 0.28 s out, `TRANS_QUART`/`EASE_IN` over
0.20 s back. A hand pulling a tape is fastest the instant it starts and spends
the rest of the travel slowing against the spring; a spring-loaded reel does not
start at full speed. The recoil is the shorter of the two because pulling is
work and letting go is not.

### The slip (`scenes/components/paper_window.gd`)

Scrolling is the one interaction with no physical answer by default, and a grey
bar from 1995 says "there is more" in the vocabulary of a different program.

A journal solves it with a slip: a strip cut narrower than the page and threaded
under two slits in it. Three cuts, all faceted and nicked rather than ruled —
two across the ends where the slip goes under, one down the side that the pull
tab comes back up through. The page's shadow falls into each end slit and is
**deeper on whichever side is hiding more**, which turns the decoration into a
readout. The slip itself is the page's inset tone mixed 55% back toward the
surface above it: two sheets the same colour are one sheet with lines drawn
on it.

The real `ScrollBar` stays underneath, stripped to nothing by the theme, and
still does the dragging, clicking and wheel. Reimplementing scroll input to get
a nicer grabber would be replacing a working mechanism to change its paint.

### The index tabs (`scenes/components/paper_tabs.gd`)

Cut into the top of a divider sheet: the one you are on stands forward and opens
into the page below it, the others are tucked behind the rule that runs across
their feet. Drawn behind the `TabBar`'s own labels, so text, hit testing and
keyboard traversal stay with Godot's control.

The tuck depth is asymmetric between the themes. On the dark page there is a
long way down before paper stops looking like paper; on cream there is almost
nowhere to go, and a tenth of the way to black is already grey card.

### The star sticker (`scenes/components/star_sticker.gd`)

**Hue means grade, shape means relevance.** The two are kept on separate
channels deliberately. Marking a player's position-relevant attributes by
colouring their names put them in direct collision with an S grade — the one
colour that means "exceptional" also meant "relevant here", and a gold 48 read
as a good 48. Marking them with a *second font* was worse: two faces in a column
of eight labels, and the column stopped reading as a list.

A sticker is an object *on* the page rather than a property *of* the text, so it
cannot be confused with a grade colour no matter what colour it is. Each one is
put on crooked, seeded from the attribute, so the same attribute is always
crooked the same way and no two in a column match.

---

## 4. Colour

`scripts/data/ui_palette.gd` remains the single source of truth, and §1 of the
constraints doc still holds in full: three rendering paths, a `Theme` reaches
only one, so the palette is a GDScript module and the `.tres` files are
duplicated from it under a synchronisation test.

Two rules were added by the drawn treatments, and both are now enforced by the
suite.

### Unpainted tiers must be written in a page ink

Every button tier sets `draw_center = false`, because its edge is drawn by hand
instead. The label therefore sits directly on the panel behind it, and its
colour has to be legible against *that*, not against the fill the stylebox used
to paint.

Both themes carried the old colour for a long time: near-white on cream for the
light primary action, near-canvas on dark for the dark one. "Save Weekly
Training Focus" and "Advance Week" were invisible in both themes simultaneously,
which is also why neither was noticed — there was no working case to compare
against. Primary actions and pressed chips are now written in the accent, which
is a page ink in either theme.

### Grade colours need one table per theme

`GRADE_COLORS` was a single table on the reasoning that a grade means the same
thing on either page. True of the meaning, false of the pigment. C was `f2f4f7`
— as near white as makes no difference — so on cream paper the most common grade
on a roster was not hard to read, it was *absent*, and a player's whole middle
band came out as a column of blank space.

`GRADE_COLORS_LIGHT` is the same five hues at values that survive being written
on paper, with C becoming the page's own muted ink.

### Patch tinting

Sewn surfaces get a small per-name `self_modulate` shift (`PATCH_TINT_SPREAD`,
0.045) so a row of six identical rectangles does not give the metaphor away.
Two tiers opt out via `UNTINTED_TIERS`:

- `RaisedPanel`, because it is the sheet the patches are sewn *onto*, and
  tinting it shifts the whole page rather than one scrap.
- `DashboardCard`, because the six section cards are not separate scraps — they
  are a block of six panes cut from one piece, and giving each its own tone made
  them read as six unrelated things that happen to be in a grid.

---

## 5. Mechanics worth knowing before editing

Hard-won, and each cost a debugging round.

- **`set_anchors_preset(keep_offsets = false)` preserves the current rect.** It
  changes which edges the control is anchored to and deliberately leaves it
  where it was. Read as "snap to full rect" it looks right and does nothing.
  Use `set_anchors_and_offsets_preset`.
- **`draw_polygon` has no antialiasing.** The nib ribbon draws a wider, fainter
  pass underneath to feather itself.
- **`show_behind_parent` puts a child before the parent's own drawing.** This is
  how the highlighter gets under the label and the slip gets under the region's
  text. A node gets one side or the other, which is why `_paper_window` adds
  *two* nodes to the one parent.
- **A `Control` under a `Container` has its rect rewritten every layout pass.**
  The nav dropdown is parented to the screen root for this reason, and
  `UIPaperWindow` goes `top_level` when its parent is a `Container`.
- **`self_modulate` tints only the node's own drawing**; `modulate` would take
  the card's contents with it.
- **A `.uid` file is required beside every script.** A new `class_name` is not
  visible to other scripts until the project is reimported, so components added
  mid-session are `preload`ed by path rather than referenced by class name.

---

## 6. Verification

- `godot --headless --path . --script res://tests/test_runner.gd` — **925 checks
  at `819a9b8`**, one failing (`defensive attack lowers both error risk and
  terminal pressure across six career seeds`, pre-existing, tempo priced
  backwards). Presentation work should not move the count except by adding
  checks; if it drops, a scene binding broke.
- `tools/preview/ink_shot.tscn` walks seven dashboard views in either theme and
  writes PNGs to `user://`. Pass `-- --light` for the light theme. This is the
  fastest way to see a treatment change; the full nineteen-section
  `dashboard_preview.tscn` takes minutes and most of it is the same surfaces
  again.
- `tools/validate_ui_bindings.sh` after any `.tscn` restructuring — a
  `%UniqueName` left dangling by a node move fails silently on tabs nobody
  opens.
- **The light theme is the one at risk.** Every invisible-text defect above was
  a light-theme defect first. Look there before dark.
