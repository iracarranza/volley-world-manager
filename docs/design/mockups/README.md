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
