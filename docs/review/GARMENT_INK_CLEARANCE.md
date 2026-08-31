# The dashing under the sleeve is the limb's own outline

The report: *"all the voli models have noise along their bodies just like the
face did -- under the legs/shorts area, sometimes above the shorts shell, under
the sleeve, and here under feli's neckline area."*

Three places named, and one cause under all three.

## The finding

`_add_garments` sizes every garment shell as a **multiple of the limb's radius**
-- the sleeve at 1.30, the shorts leg at 1.28 -- while `_ink_node` grows the
limb's outline hull by a **fixed 0.018 m**. A proportional clearance and an
absolute grow agree at exactly one radius. Everywhere else the outline is either
buried or outside the garment, and the garment shells are thin enough that it is
mostly outside.

`tools/garment_clearance.tscn` measures the shell's narrow end against the limb's
surface across the band that shell covers, plus the limb's hull:

| body | sleeve clear | shorts clear | collar clear |
|---|---|---|---|
| Vegi | **−0.0016** | +0.0056 | **−0.0639** |
| Feli | **−0.0016** | +0.0067 | **−0.0202** |
| Avi | **−0.0050** | +0.0014 | **−0.0200** |
| Cani | +0.0005 | +0.0085 | **−0.0311** |
| Ursi | +0.0064 | +0.0144 | **−0.0413** |
| Simi | +0.0004 | +0.0097 | **−0.0331** |

Metres. Negative means the limb's outline hull is outside the garment that is
supposed to cover it; within a couple of millimetres means the two surfaces are
parallel, coincident and unbiased in depth, which is the dash.

Read against the report, the table says the same three things the eye did:

- **The sleeve** is the worst pair. Five of six bodies sit inside ±5 mm and three
  are negative. Avi is worst at −5.0 mm, which is also the thinnest arm -- the
  proportional multiplier buys least where the limb is smallest, and Avi's arm is
  the one a wing has to share space with.
- **The shorts** clear on every body, but Avi by 1.4 mm and Vegi by 5.6 mm. That
  is the *"sometimes"* in the report: it depends on the body type, exactly as a
  proportional clearance against a fixed grow has to.
- **The collar** is negative on all six, by 20 to 64 mm. It is not a tube around a
  limb but a ring sunk into the torso's top, placed at `torso_top - neck_radius *
  0.12` -- deliberately below the torso's surface, and therefore well below where
  that torso's 0.018 m hull reaches. Feli is named in the report and Feli is
  −20 mm; Vegi is the worst at −64 mm.

## This is the face bug in another place

The face pass found an eye 0.053 m across rendering at 0.113 m because the hull
was bigger than the mark, and `_ink_weight_for` was added so a part that declares
itself body takes the lighter line. That fixed the parts that *state* a weight.
It could not fix this, because here the hull is the right size for the limb and
the wrong size for the gap between the limb and its clothing -- nobody sized the
garment against an outline, because the outline is grown later and elsewhere.

## Two wrong instruments on the way here, both recorded

The first reading compared `mesh.get_aabb()` on the shell against
`mesh.get_aabb()` on the limb and reported every sleeve at −14 to −19 mm. Two
faults, and they pulled the same way:

1. **A flared cylinder's AABB is its hem at both ends.** `size.x` is twice the
   *larger* radius, so the sleeve was being measured at its widest and called its
   narrowest. The radii are on the `CylinderMesh` resource and only the resource
   says which end is which.
2. **A limb is a lathe, not a primitive.** Its widest point is the shoulder dome,
   which is not necessarily under the sleeve. Comparing against a whole-mesh
   maximum overstates the interference by however much the limb tapers.

Banding the limb to the shell's own span moved the sleeve column from −0.0165 to
−0.0016 on Vegi: **an order of magnitude**, and the difference between "the
garment is far too tight" and "the garment and the outline are coincident". Those
call for different fixes, so the first table would have bought the wrong one.

The collar figures are unaffected by either fault -- that comparison is a height
against a height -- which is why they are the same in all three readings.

## What a fix has to not do

The obvious move is to widen the multipliers until the table goes positive, and
it is the wrong one twice over. It re-tunes a number that was chosen for how a
garment *looks* to fix a problem in how an outline is *grown*, and it leaves the
next body type to re-break it, because the disagreement between a ratio and a
constant is structural and does not go away by moving the ratio.

What the record is missing is that a garment knows what it covers. The shell is
built in `_add_garments` from the limb spec, so the clearance it needs is
derivable there -- but the hull weight lives in `player_actor_3d.gd` and the two
files have never had to agree. That is the seam, and it is the same shape as
every published-record seam closed this month: two halves of one fact, each
correct alone.
