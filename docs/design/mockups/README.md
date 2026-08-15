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
stands. `pawa_wide.jpg` is a third frame for Pāwa Hitō, showing the approach
rather than the court.

**The claim that used to be here was wrong, and it is worth saying how.** It
read: *the match camera cannot show what a court stands on* — that a terrace
edge occludes everything below it, so height is a property of the approach and
not of the court. That was written after four passes of sea, headlands and
islands failed to appear in the broadcast frame, and it was a conclusion drawn
from a broken instrument. `match_court_3d.tscn` sets the camera's `far` to
**80 m**, and the probe only ever raised it inside the closeup, so every
backdrop test was run through a camera that could not see past 80 m. The sea
starts at 140. Nothing was being occluded; it was being clipped. Once the far
plane was opened on the broadcast camera too, sky, water, islands and ridge all
appeared in the same frame at the first attempt.

The volis are twelve per court, home in the region's kit and away in a light
change strip. These are the first frames where the kit palette and the court
palette appear together — they were designed a day apart against different
grounds, and the exposure fix moved every rendered colour after both.

The volis are twelve per court, home in the region's kit and away in a light
change strip. Each region's kit now carries a **construction language** as well
as a colour — placket, ticks, panels, columns, uneven bands, seams, sponsor
blocks, one heritage band — marked front and back, so a side is nameable from a
grayscale frame without making any kit louder.

**Pāwa Hitō is mid-tune and shipped that way.** The backdrop is in frame for the
first time, but the islands and headland are still over-scaled and read as
slabs, and the open-air camera framing (lifted and levelled, since it is the one
venue with something above the horizon worth seeing) has not been balanced
against the court. Scale, haze and framing are the next pass. The other seven
venues are unaffected — they keep the original broadcast seat exactly.
