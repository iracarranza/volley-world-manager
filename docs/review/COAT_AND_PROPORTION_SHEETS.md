# The coat and proportion sheets

Two plates that vary one thing each, and the staging all three voli sheets
share (`tools/preview/voli_sheet_stage.gd`).

```bash
xvfb-run -a godot --path . res://tools/feli_coat_sheet.tscn
xvfb-run -a godot --path . res://tools/avi_proportion_sheet.tscn
```

## The Feli coat sheet

Ten colourways along the sheet with the coat cycling underneath. Colour and
marking come off two separate hashes precisely so they do not correlate, which
means no roster ever lays one against the other; this does.

Both are *chosen* rather than hashed, through `chosen_palette` and
`chosen_marking` -- the same doors the character creator uses. Nothing on the
plate is a voli the world could not generate.

**Feli has four coats, not five.** `MARKINGS["Feli"]` is
`["none", "none", "tabby", "tabby", "patch", "scar"]`, which
`marking_options` deduplicates to **none, tabby, patch, scar** -- blank plus
three. The sheet cycles those four across ten cells, so each coat appears twice
or three times on different palettes.

The vocabulary the other bodies draw from is larger -- `spots`, `speckle` and
`blaze` all exist and all render, they are simply not in Feli's list. Adding one
to this plate would have shown a cat the generator never makes, so it is not
done here. If a fifth Feli coat is wanted, the change belongs in `MARKINGS`.

## The Avi proportion sheet

Seven builds across, three angles down: facing, three-quarter, profile. A facing
view flatters all three axes -- a heavier torso and a longer arm both read as
"wider" from the front -- so the turn is the point of the plate.

One colourway and one bare coat throughout. The first run passed a different id
per column, which hashes a different palette per column, and seven builds
arrived in seven colours; the eye read the colour. A proportion sheet varies
proportion and nothing else.

Height is held at 188 cm. What each column asked for, and what the rig resolved:

| variant | mass kg | torso girth | arm scale | leg scale |
|---|---|---|---|---|
| reference | 82 | 1.000 | 1.000 | 1.027 |
| mass 50 | 50 | **0.880** | 1.000 | 1.027 |
| mass 130 | 130 | **1.140** | 1.000 | 1.027 |
| span 150 | 82 | 1.000 | 0.785 | 1.027 |
| span 235 | 82 | 1.000 | 1.230 | 1.027 |
| stride 0.70 | 82 | 1.000 | 1.000 | 0.860 |
| stride 0.94 | 82 | 1.000 | 1.000 | 1.160 |

### Where the numbers come from

Mass and wingspan are `player_generator.gd`'s own clamps -- 50 to 130 kg, 150 to
235 cm -- so those four columns are builds the world really generates. Nothing
here is a magnitude invented for the plate.

Stride had no such pair to borrow, and that is the first observation:
**the generator never varies stride.** Both assignments in `player_generator.gd`
call `default_stride_length_m()`, which is `height_cm / 100.0 * 0.43` exactly.
So `leg_length_scale` -- a real geometry axis, wired deliberately, with the
torso-compensation machinery behind it -- is driven by a value that is a pure
function of height, and no two generated volis of the same height differ on it.
Its two columns therefore use the ends of `leg_length_scale`'s own clamp, 0.86
and 1.16: the range the *drawing* admits, not one the population fills.

### The mass columns are both clamped

The bolded girths are the second observation. `mass_girth` is
`clamp(pow(mass_kg / expected_mass, 0.35), 0.88, 1.14)`, and at 188 cm the
expected mass is 82 kg. The generator's own extremes land at 0.841 and 1.175 --
**outside that clamp at both ends** -- so they arrive as exactly 0.880 and
1.140, which is what the table shows.

The drawn girth range is narrower than the generated mass range, and a 50 kg and
a 56 kg Avi of the same height are drawn identically. Recorded as an
observation: no acceptance bound governs the figure, the clamp is doing what it
was written to do, and whether the visible range *should* be wider is a design
question this plate only supplies evidence for.
