# M8 playback frames — for human review

Filmed through the **real match centre**, not a reconstruction of it.
`tools/render_match_playback.gd` instantiates `scenes/screens/match_screen.tscn`
and calls `load_and_play_rally` — the same entry the desk calls — then
photographs the viewport while it runs. Every pose, every drawn contact, every
window's pacing and every caption in these frames is the shipped playback path
deciding, not the tool.

That distinction is the reason this exists. The earlier renderer
(`tools/render_rally_frames.gd`) states in its own header that it uses "no
MatchScreen, no playback loop, no async pacing" — correct for comparing two
curves, useless for reviewing the layer those things live in.

Reproduce:

```bash
xvfb-run -a godot --path . --rendering-method gl_compatibility \
    res://tools/match_playback.tscn
```

Never `--headless`: there is no renderer, and the frames come back blank. The
tool discards blank frames rather than writing them, so a full set is evidence
that something was actually drawn.

## What was filmed

Both serving sides, each the **first** seed from 970000 that walks the whole
chain — searched by rule rather than chosen, so neither side is represented by a
hand-picked best case.

| side | seed | contacts |
|---|---|---|
| home serve | 970001 | SERVE · RECEPTION · SET · ATTACK · BLOCK · POINT |
| opponent serve | 970000 | SERVE · RECEPTION · SET_DECISION · SET · ATTACK · BLOCK · DIG · POINT |

Sampled at 0.22 s of real playback time and thinned to every fourth frame, so
each directory spans the same rally at roughly 0.88 s intervals. The frame
numbers are contiguous after thinning; the HUD's own `NN / NN` counter and
`t=` clock are the authority on where in the rally each frame sits.

## What to look for

The machine gates cover identity — actor, position, height, time, lineage,
symmetry. These frames are for the questions a gate cannot ask:

- **Does the repaired ball height read as volleyball?** The block's contact is
  now drawn where the intersection was proved rather than at the top of the
  blocker's reach, and the reception at the ball's own height rather than at a
  fixed platform height. Both should look like the ball met a body, not like a
  body was moved to the ball.
- **Does a beaten block read as reaching and missing** rather than as a contact
  that silently did nothing?
- **Does the pacing read as a rally** — one continuous action — or as a
  sequence of separate windows queueing up?
