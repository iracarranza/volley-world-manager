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

**Pāwa Hitō's next pass has landed**, and the three things named here — scale,
haze and framing — each turned out to be a different defect than the label
suggested. The other seven venues are unaffected; every change is inside the
open-air branch.

**Haze was not a tuning problem, it was a unit.** `_sky()` switches this venue
alone to `FOG_MODE_DEPTH`, where `fog_density` means *opacity over the depth
ramp*. The venue then set it to `0.004` — the number Spëddigh and Ĭspayk both use
correctly as a per-metre **exponential** density, which is what every other venue
leaves the mode at. Four tenths of one percent of opacity, over a depth ramp
whose begin and end had been carefully argued about in a comment directly
underneath. The ramp was right; there was nothing to apply it with. This is
`FAILURE_MODES.md` §0 arriving in a renderer: a value measured with the wrong
instrument, where the instrument changed underneath the number.

**Scale was not the reason they read as slabs.** With the fog working, the
islands receded properly in value and *still* looked like blocks — which is the
diagnosis: a single axis-aligned box seen near face-on is a rectangle, and no
amount of haze fixes a silhouette. Each island is now three descending lumps
sharing a base sixteen metres under the water, so the outline steps and no base
edge shows. Tops came down from 25 m above the water to 8–20 m at the same
distance.

**The ridge needed the opposite of what it had.** Six tall towers became nine
tapered masses and immediately read as a *skyline*, because evenly spaced
same-height objects that do not touch is what a city looks like. It is now
fourteen segments spaced well under their own width so they merge, with heights
from two sine terms at incommensurate rates — a few high points, long low cols,
no catchable period — plus a second range at the far end of the fog ramp that
arrives as a pale suggestion.

**Framing was one number.** The lifted open-air seat aimed at 4.0 m, above the
net, which sank the court into the bottom-left quarter and gave the far terrace
the rest of the frame. Aiming at 2.6 m and standing slightly closer brings the
subject back to the middle and still leaves the horizon a fifth down from the
top.

Two things the pass found that were not on the list. The terraces were 3.4 m
plates with water visible underneath — the same *visible base* defect as the
islands, one scale up — and now cut down to −60 so they read as one mass. And the
establishing frame's camera stood at z = 54 with the hillside reaching forward to
z = 55, so a 150 m flank sat beside the lens and filled two thirds of the shot;
moved out over the water, where the terracing, the drop and the court on top of
it are finally all in one frame.
