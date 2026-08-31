# Regional kit iterations

The fourteen strips were reworked against the separated kit garments and the
current Voli proportions. Every row below is renderable through
`RegionalKits.marks_for(region, champion, attempt)`; these are not prose-only
alternatives. Attempt 3 is selected for play.

The common progression is deliberate:

1. **Restrained read** -- the original torso-centred idea, reduced to 72%.
2. **Garment read** -- the same construction carried onto sleeves and shorts at
   88%, proving it belongs to clothing rather than to one nominal torso.
3. **Match read** -- full-scale geometry, exaggerated for distance and scaled in
   the dressed garment's frame across all six body families.

| Region | Attempt 1 | Attempt 2 | Attempt 3 selected |
|---|---|---|---|
| Landavol | Quiet placket | Collar-and-cuff canon | Architect's baseline: placket, yoke, sleeve and shorts piping |
| Spëddigh | Twin tick rows | Compressed yoke | Full-kit pulse: dense dashed rules at yoke, hem, cuffs and shorts |
| Pāwa Hitō | Straight side bars | Shoulder-to-hem panels | Kinetic sweep: bowed side panels continuing down limbs |
| Blôc du Larg | Three columns | Seven structural bays | Nine-pier facade: full-height pinstripes continuing onto shorts and sleeves |
| Xérvu | Uneven chest beats | Vertical syncopation | Struck rhythm: tapered irregular strokes with limb echoes |
| Taktikã | Fine centre seam | Measured grid | Court schematic: exact cross-lines, centre rule and limb axes |
| Ĭspayk | Chest stripe | Heritage ring | Bound archive band: full circumference, dark edging and broad limb tabs |
| A'ace | Sponsor plaque | Paid patchwork | Broadcast billboard: dominant chest block with satellite placements |
| Tãul ys Feynt | Angled seams | Redirected pairs | Double feint: opposing broken angles crossing shirt, sleeve and shorts |
| Lo-ong Ralī | Long torso rails | Waist-spanning rails | Unbroken circuit: paired lines continuing across every garment break |
| Bompaçao | Low stripe | Platform ring | Load-bearing base: low full ring with heavy shorts blocks and cuff rule |
| Rhėn Tempaol | Shoulder rays | Descending fan | First-tempo burst: asymmetric fan resolving early and repeating on limbs |
| Kutré Lyn | Split seam | Hard three-way fork | Decision tree: angular branch system with divergent sleeve and shorts cuts |
| Zaitgaist | Whole champion copy | Single quoted mark | Two-motif remix: enough of the champion to quote, never enough to impersonate |

## Garment and proportion contract

Marks are authored against a 0.28 m radius by 0.90 m reference torso, a 0.07 m
arm by 0.84 m arm cut, and a 0.11 m leg by 0.66 m leg cut. The actor maps width,
height, offsets and curved-panel bow into the actual host garment before pose and
physical scaling. This keeps longitude, coverage and visual weight stable on
narrow Avi, broad Ursi, short Cani, long-reach Simi and the reference Feli.

Vegi are the exception in material, not in clothing. Produce remains visible and
receives no torso paint. Sleeves and shorts still carry each region's secondary
motif, so a Stalk or Pear does not become regionless.

## Evidence

`tools/render_all_kits.gd` writes three evidence groups:

- `artifacts/all-kits/iterations/`: 42 reference-body attempt renders.
- `artifacts/all-kits/proportions/`: each selected strip on six body/proportion fixtures.
- `artifacts/all-kits/*_front.png` and `*_back.png`: selected front/back finals.

A selected design is acceptable only when its primary gesture remains visible,
marks remain seated on the garment, front and back agree, produce is unpainted,
and no limb motif crosses a garment edge on any fixture.
