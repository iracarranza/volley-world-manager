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

## What was done

`BodyTypeModels._clearing_radius` sizes each shell so its narrow end clears the
limb by one line width, and the ink weight moved to `body_type_models.gd` as
`body_ink_metres` so the file that authors garments owns the number they have to
clear. `player_actor_3d.gd` reads it rather than keeping a second copy.

The standoff is one line width because that is the only non-arbitrary distance
available: a garment sitting exactly `body_ink_metres` off the limb sits *on* the
outline, which is the coincidence being fixed. The base radius is lifted and both
of the shell's own multipliers are then applied to it, so the flare that makes a
cuff read as a cuff is preserved rather than pinched.

The collar is different and is seated in the rig, by `_seat_collar`, for the
reason the shorts are: `_apply_physical_profile` has just scaled the torso by
mass girth and squeeze, and the collar hangs off `BodyPivot` so it inherits
none of that. Two functions both placing it is the correct-then-clobbered shape
this file has been bitten by repeatedly, so the one that knows the final torso
owns it.

| body | sleeve | shorts | collar |
|---|---|---|---|
| Vegi | −0.0016 → **+0.0178** | +0.0056 → **+0.0178** | −0.0639 → **+0.0180** |
| Feli | −0.0016 → **+0.0163** | +0.0067 → **+0.0163** | −0.0202 → **+0.0180** |
| Avi | −0.0050 → **+0.0131** | +0.0014 → **+0.0131** | −0.0200 → **+0.0180** |
| Cani | +0.0005 → **+0.0156** | +0.0085 → **+0.0156** | −0.0311 → **+0.0180** |
| Ursi | +0.0064 → **+0.0170** | +0.0144 → **+0.0170** | −0.0413 → **+0.0180** |
| Simi | +0.0004 → **+0.0225** | +0.0097 → **+0.0225** | −0.0331 → **+0.0180** |

Every collar lands on exactly 0.0180, which is the standoff and not a
coincidence: `_seat_collar`'s floor binds on all six, so each one is placed at
precisely one line width and none of them was already clear.

### What it costs, which a table cannot say

`tools/garment_sheet.tscn` renders the six bodies in kit, and `--only <type>`
frames one. Side by side on Feli: the pale streak running down the inside of each
sleeve is gone, and so is the dark hairline under the collar -- both were the
outline showing through. The cost is that the sleeve reads rounder, closer to a
puffed cap than to a singlet's shoulder. That is the trade the fix is, taken
deliberately.

**One thing the render found that this pass did not cause.** Pale wedges of the
backdrop show between the shirt's hem and the tops of the shorts legs, on both
hips, in the *before* image as well as the after. Logged separately rather than
folded in here, because a defect that survives a change unchanged is not that
change's.

## A third wrong instrument, in the probe rather than the code

The collar was still reading negative on Vegi and Ursi after `_seat_collar` was
in. It was the probe: it compared the highest *world-space AABB corner* of each
mesh, and `body_pivot` carries the pose's pitch and yaw, so under a rotation the
highest corner of a wide torso and of a narrow ring are different physical points
and the comparison drifted with the pose. A rigid rotation applied to both cannot
create or remove a coincidence, so the pivot's own frame is where the question is
well posed. Measured there, all six land on the standoff.

That is three instruments wrong on one finding -- the AABB of a flared cylinder,
the whole-mesh maximum of a lathe, and now a world-space top under a rotation --
and each one was found by a number that did not make sense rather than by
inspection. The pattern is worth naming: every one of them was a *coordinate
frame* or an *extent* question, and every one of them read plausibly.

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

## Re-measured on the new bodies, and a fourth instrument problem

`THE_VOLI_BODY.md` §0 marks the published tables provisional until re-run on the
bodies as they actually stand. Re-run at `HEAD` on macOS/Metal under
`gl_compatibility`, after the Stalk was rebuilt from a smooth shaft into a leek:

| body | sleeve / shorts clear | collar |
|---|---:|---:|
| Vegi | 0.0178 | 0.0180 |
| Feli | 0.0163 | 0.0180 |
| Avi | **0.0131** | 0.0180 |
| Cani | 0.0156 | 0.0180 |
| Ursi | 0.0170 | 0.0180 |
| Simi | **0.0225** | 0.0180 |

Every row positive, every collar on the standoff exactly. The band is 13.1 mm to
**22.5 mm**, so the "13-22 mm" quoted previously wants its upper bound stated as
23 -- Simi sits a half-millimetre above it and always did; nothing regressed.

**The fourth instrument problem is coverage, not arithmetic.**
`probe_garment_clearance.gd:36` iterates `BODY_TYPES` -- the six *types* -- and
passes only `body_type`, so the single "Vegi" row is whatever
`produce_for(player_id)` returns for the probe's id of 1. That is **Pepper**. The
other four produce are never built, and the table above has been read as
covering Vegi when it covers one fifth of it.

For sleeves and shorts this costs nothing, and the reason is worth writing down
rather than rediscovering: those shells are sized from the **limb** spec, and
`arm`/`leg` are fixed constants shared by every produce. Sleeve clearance is
produce-invariant by construction, so no produce change can move it.

**The collar is the exposure.** `_seat_collar` reads the *drawn torso*, which is
exactly what differs per produce -- and this pass replaced the Stalk's torso
outright: a bulb over a parallel-sided shaft with a flat cut top, where it was a
convex spindle tapering to a rounded tip. A Stalk collar has therefore never been
measured, by this probe or any other. It is very likely fine, because
`_seat_collar` derives the seat rather than assuming it, and that is the whole
point of the design. But "very likely fine" is the sentence this document exists
to refuse.

The fix is one line in the probe -- iterate `Bodies.PRODUCE` for the Vegi row and
pass `produce` through `configure` -- and it is deliberately **not** done here,
because the probe arrived in this branch from a parallel session and silently
changing another author's instrument mid-merge is how a record stops being
comparable. Recorded instead, for whoever owns that probe next.
