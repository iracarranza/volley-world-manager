# Interface drafts

Aesthetic drafts of screens that do not exist yet. Nothing here is wired and no
plate corresponds to a scene file; open them in a browser.

| file | covers |
|---|---|
| `title_screen.html` | the title screen — the room the desk is in, and exempt from the desk media |
| `interface_drafts.html` | the interview, voli page, roster register, week in blocks, housing change, phone |

## interface_drafts.html

Seven plates covering six interfaces the design asks for and the build does not
have: the interview, the voli page, the roster register, the week in blocks, the
housing change, and the phone. The seventh
plate redraws the voli page in Molten, because a cream substrate on a light
ground is the case a dark-only draft always gets wrong.

### Why they are in the repo rather than only in a chat

Two of them settled arguments that had been settled before and drifted back —
what a heading may say, and whether the manila card or the cork board suits a
subject — and a drawing is a cheaper way to lose that argument than a build is.
See `docs/design/DIEGETIC_MANAGEMENT.md` §11 for the rule every plate is drawn
against, and §4.2/§4.3 for the medium assignments.

### What it is drawn from

The palette is lifted verbatim from `scripts/data/ui_palette.gd`, both themes.
The two faces are the game's own, and unlike `title_screen.html` — which
carries base64 copies — they are linked from the repo:

| face | path |
|---|---|
| Short Stack | `Short_Stack/ShortStack-Regular.ttf` |
| Cherry Bomb One | `Cherry_Bomb_One/CherryBombOne-Regular.ttf` |

The relative paths in the `@font-face` rules assume the file stays at this
depth. Moving it three directories up without fixing them produces a silent
fallback to the browser's default sans, which looks close enough to be missed —
so if a plate suddenly reads as generic, check the fonts resolved before
checking anything else.

Plates are sized at the game's window proportion using `container-type:
inline-size` and `cqw` units, so a plate scales as a unit and the type inside it
keeps its relative size. This is a drawing convention only; Godot does nothing
of the kind.

## venues/

Seventeen frames of the eight major venues, rendered from `MatchCourt3D` itself
by `tools/venue_probe.tscn` — its camera, its lights, its environment, with only
the venue's own light and geometry swapped in. Re-runnable in a few minutes:

```bash
xvfb-run -a godot --path . res://tools/venue_probe.tscn
```

Each region has two: `<region>.jpg` from the broadcast seat, and
`<region>_close.jpg` at play level near the net, which is where a venue is
actually judged — kit against floor, and a shadow that says where somebody
stands. `pawa_wide.jpg` is the third frame Pāwa Hitō needs and no other venue
does, for a reason worth keeping: **the match camera cannot show what a court
stands on.** It sits 9 m up looking slightly down at a court 19 m away, so a
terrace edge occludes everything below it. Height is not a property of the
court; it is a property of the approach to it.

The volis are twelve per court, home in the region's kit and away in a light
change strip. These are the first frames where the kit palette and the court
palette appear together — they were designed a day apart against different
grounds, and the exposure fix moved every rendered colour after both.

**Still short, and not for want of geometry.** Pāwa Hitō does not read as high
up. Three passes of terraces, headlands and sea changed nothing, because land
*below* a court cannot fix it: nothing in those frames had a size anybody
already knows. A ridge above the horizon and a procedural sky get closer — a
viewer knows roughly how big a mountain is, and a horizon is the line that says
where the ground stops. What would finish it is an authored backdrop rather than
blocks. That is art, not geometry.
