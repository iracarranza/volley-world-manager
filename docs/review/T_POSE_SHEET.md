# The T-pose sheet

`tools/run_voli_t_pose_sheet.gd` photographs every voli body at a matched
height with the arms straight out. Run:

```bash
xvfb-run -a godot --path . res://tools/voli_t_pose_sheet.tscn
```

## Why it exists

`run_body_type_preview.gd` already photographs the bodies, but only ever
mid-action -- stand, serve, set, attack, block, dig. Every image it produces
shows a shape with something being done to it, so there was no plate showing
limb lengths and shoulder placement with nothing on top of them.

Ten subjects: the five body types that are themselves, then Vegi once per
produce, because Vegi is the one type that cannot be photographed by a single
subject.

## What it measured

A T-pose is also the only attitude in which a drawn reach can be read off the
rig directly, so the tool prints one. Drawn hand-to-hand span against the
`wingspan_cm` the same voli was configured with, all ten at 188 cm / 191 cm:

| subject | drawn span m | ratio to wingspan |
|---|---|---|
| Avi | 2.255 | 1.18 |
| Cani | 2.311 | 1.21 |
| Feli | 2.287 | 1.20 |
| Ursi | 2.481 | 1.30 |
| Simi | 3.252 | **1.70** |
| Vegi (Tomato) | 2.164 | 1.13 |
| Vegi (Eggplant) | 1.881 | 0.98 |
| Vegi (Pear) | 1.973 | 1.03 |
| Vegi (Stalk) | 1.766 | 0.92 |
| Vegi (Pepper) | 2.138 | 1.12 |

**This is an observation, not a defect report, and the distinction is the whole
of what is worth saying about it.** No claim anywhere states that a drawn span
equals `wingspan_cm`. `_resolve_silhouette` reads wingspan only as a *ratio*
against height -- `arm_length_scale` is `(wingspan/height) / reference_ratio`,
clamped to `[0.78, 1.24]` -- so the absolute arm length is whatever the body
type's `arm.height` authored, and the six were authored independently of each
other. Nothing is out of range and no acceptance bound governs the figure.

What the spread does say is that "wingspan" is not a shared unit across body
types: the same 191 cm draws 1.77 m of Stalk and 3.25 m of Simi, a factor of
1.84 between them. Two consumers to keep apart when that matters --
`fit_contact_anchor_height` solves against the real node transforms, so it
already carries whatever each body draws; `height_cm` through
`player_generator.gd` is what the rally resolves contacts at, and it never
reads the mesh at all.

Simi is the outlier by a distance and it is the authored one: `arm.height` is
0.98 against 0.72-0.86 for the rest, and the comment on the neighbouring block
says the reach is the point of the type.

## Two caption notes

Vegi rows read `Vegi (Produce)`. The produce is in parentheses because it is not
a second name for the type -- `run_body_type_preview.gd` prints the type alone
for exactly that reason, and a bracket says "this Vegi, grown this way" where a
separator says "a species".

Aubergine is captioned **Eggplant** on this sheet and nowhere else. `PRODUCE` is
the authority and is untouched; `SHEET_NAMES` is a caption table for one plate.

## Framing note

The camera is built *after* the subjects and sized from the widest measured
span. An assumed padding was tried first and cropped Simi's hands -- the one
subject the sheet most needs to show whole, for the reason directly above.
