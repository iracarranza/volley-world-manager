# The muzzle was a sticker and the wing was a panel

Two user reports against the study renders on this branch: the muzzles *"look
awkward because of the stickerbake… a weird teeth, kind of creepy feel"*, and
the Avi wings *"float off the arm instead of being an extension"*. Both held up,
and each turned out to be several causes stacked rather than one.

Measured by rendering `tools/render_voli_body_redesign_pass4.gd`, which drives
production actors rather than a mockup, before and after.

## The muzzle

Four separate decisions were making the same picture.

**It was a different colour from the head.** All four muzzled types — Feli,
Cani, Ursi, Simi — authored the whole snout `"color": "crown"`. On Feli that is
`f0dcc0` against a `c98f4e` head: a near-white patch with a hard edge across a
tan face. That is the sticker, and it is one word per type.

It was also making the mouth worse in **two opposite directions at once**, which
nobody had looked at. The mouth's ink colour is chosen from *skin* luminance, so
Feli's dark stroke landed on near-white and read as a bared row of something,
while Ursi's dark `4a3b34` skin selects the *light* stroke and put a pale mouth
on a pale muzzle where it nearly disappeared. A skin-coloured muzzle gives the
mouth the same contrast against the snout as against the head, on every type.

The two-tone reading `crown` was there for survives as a **nose**, which is
where a real muzzle actually changes colour. Derived from the already-featured
muzzle rather than authored four times, so it follows the short/standard/long
axis for free — verified across every type and every axis value:

```
type   muzzle       muz_r    muz_z   nose_z
Feli   short       0.0860  -0.1300  -0.1601
Feli   standard    0.1000  -0.1500  -0.1850
Feli   long        0.1120  -0.1950  -0.2342
Avi    (beak, no muzzle)             no nose
```

**The mouth was seven boxes, and the boxes were not the whole story.** Seven
un-rotated `BoxMesh` segments on a parabola cannot follow a curve, and a 0.10 m
muzzle curves away far faster than a 0.185 m head, so toward the corners each
box left the surface at a different depth. The recorded repair at the time was
`MUZZLE_LIFT = 0.13`, which does not close the gaps — it floats the whole row in
front of the snout, which is the picture the user eventually reported.

The half nobody had found: `PlayerActor3D._ink_node` gives **every** mesh its
own inverted hull, so seven boxes carried **seven independent 30 mm black
outlines**. That is what actually drew the chips. The mouth is now one swept
`build_stroke` mesh framed on the surface normal at each sample, so it has one
outline and nothing to separate from. `MUZZLE_LIFT` goes back to `SURFACE_LIFT`
because there is no longer a gap to hide.

**Two of the mouth's three dimensions were sized for the wrong object.**
`MOUTH_THICKNESS * radius` and `FEATURE_DEPTH * radius` used the **head's**
radius while the position wrapped the **muzzle's** — on Feli an 18.5 mm bar
standing 18.5 mm proud of a snout 150 mm tall. The span already carried
`mouth_scale` through `step`; these two never did.

`MOUTH_SEGMENTS` became `MOUTH_SAMPLES` and rose from 7 to 15. Half its
justification retired with the change: *"more costs mesh instances on every actor
on court"* was true of seven `BoxMesh` instances with seven ink twins and is not
true of vertices in one mesh. Per face, 14 mesh instances became 2.

### The nose took two attempts, and the first one is the instructive one

At a quarter of the muzzle radius it came out as a bauble bolted to the face —
because a cosmetic carries a 0.030 m inverted hull, so a 25 mm nose is *smaller
than its own outline*. The ring dominated the mark and the protrusion caught the
key light, so the one thing that read on the face was a bright disc in a heavy
circle. Wider, flattened, sunk into the snout, and moved onto the body's lighter
0.018 m pen. **A part small enough to be mostly outline is not a small part, it
is an outline** — which is the same failure the seven mouth boxes were.

## The wing

**It could not fold at the elbow, and that is why the block frame was worse than
the rest frame.** One 0.86 m box per side, parented to `BodyPivot/LeftArm` — the
*upper* bone — while an Avi arm is a two-bone chain of 0.45 and 0.53. The fan
spanned a joint it was not attached across. At rest the arm is nearly straight
and the lie is cheap; raise the arms to block and the wing tears off the limb,
which is exactly what the study renders showed.

Two fans per side now, one per bone: coverts on the upper arm, primaries on the
forearm. The fix and the anatomy are the same thing.

**"Feathers, not panels" was written directly above a constant-section slab.**
0.40 m of chord at the shoulder and 0.40 m at the wrist is a shield. `build_fan`
tapers and rakes the trailing edge.

**The translucency was not doing what it looked like it was doing.** `alpha
0.55` was buying back silhouette the slabs ate — but `_ink_node`'s twin is opaque
regardless of its host's alpha, so a see-through wing was carrying a solid 30 mm
black contour. That contour is the strongest cue in the whole picture that a
thing is a separate object. Tapered fans eat far less silhouette, so they are
opaque again, and an `ink` key puts them on the body's own 0.018 m pen.

`BACKLOG.md` justifies the heavier crown line because *"a crown is the smallest
thing on a figure and carries the whole identity of its type"*. A wing is the one
cosmetic that argument excludes — the same file calls it *"the largest cosmetic
in the game"*. The opt-in meta keeps the default the rule wants: a new ear or
tail still takes the crown weight without anybody remembering.

**And it did not scale with the arm.** `_apply_arm_length` scaled `Mesh`,
`Elbow` and the forearm and stopped, so an Avi with a non-unit arm ratio grew a
limb out from under its own wing. Sibling cosmetics of the two arm bones now
scale with them.

## A cache that would have hidden all of it

`voli_sticker.gd`'s `FINGERPRINT_SOURCES` digests every source that can change a
baked body's geometry — and did not list `face_expressions.gd`. So rebuilding the
mouth invalidated nothing and every cached headshot would have kept serving the
old face from disk. A latent bug independent of this work, and one that fails
exactly like a cache that works.


## Whiskers, and where the angular jaw actually comes from

Reviewing the rendered sheet: *"looks a bit more natural on cani than feli, but
has this strange angular jawline type look. feli is also missing whiskers."*

**The angular jaw is the study's muzzle, not production's.** Columns A/B/C
replace the sphere with `_front_tapered_prism(back_w, back_h, front_w, front_h,
depth)` — eight vertices, so the jaw is a straight edge meeting a corner. That is
also exactly why it lands better on Cani: a dog's snout genuinely is long and
squarish, and a cat's is short and round, so the same prism flatters one and
gives the other a lantern jaw. Production kept the sphere, so the CURRENT column
does not have it.

**Feli was flat for a findable reason.** With a nose and a mouth on it and
nothing else, the whole lower head is one unbroken plane. Cani never had that
problem: its folded ears and longer muzzle already break the same area up. So the
missing whiskers were not only missing detail, they were the missing *division*.

Three a side, cones because a whisker tapers to a point, rooted on the whisker
pad and fanned about the horizontal, long enough that the tips cross outside the
head's outline — which is the point, since this rig is read by its outline.

They carry **no ink hull at all**, which needed a new opt-out. That is the third
time in this pass the same rule bit: the hull is 30 mm, a whisker is 4 mm, and
inking one produces a black rod seven times its own width. The nose hit it at a
quarter of a muzzle radius and the mouth hit it seven times over. Where a part is
drawn *as* the stroke, its geometry has to be the stroke, and `ink: "none"` says
so — a face feature or cosmetic can now decline the line it would otherwise be
swallowed by.


## The muzzle became a wedge, and Feli was off kilter for two reasons

Reviewing again: *"fine with the angular jawline but needs to be proportioned
better for feli… cani's updated muzzle look intuitively correct, but feli's mouth
and nose make it look off kilter."* The wedge was adopted into production,
proportioned per species. The off-kilter half turned out to be two stacked
causes, and the first one is not a proportion at all.

### Feli's muzzle was sinking down its own face

`_toward_universal` pulls `head_y` toward the shared figure, and every extra's
position is absolute in `BodyPivot` space. So the head walks and the snout stands
still. Measured: **Feli's head rises 0.0455 m under the blend, Cani's 0.0330 m** —
two bodies authored with an identical 0.185 m head, and Feli's snout ends up
nearly half a centimetre lower on its face.

That is not cosmetic drift, because `_mouth_override` anchors the mouth at
`muzzle.position.y - head.position.y`: the **unblended** muzzle against the
**blended** head. The mouth inherited the whole error and the nose, derived from
the muzzle, inherited it again. Cani looked correct under identical rules because
Cani's drift was two thirds the size.

`_add_neck` exists because the same blend opens a gap at the *other* end of the
head, and its comment already states the rule: re-authoring every `head_y`
against the blend would be *"correct until the blend moves, and silently wrong
after."* Head-worn parts now move with the head by construction, classified by
distance from the authored head rather than by a name list — so a future horn or
jowl follows for free, and tails, tail feathers and arm-parented wings correctly
do not.

### And it was authored bigger than the dog's

Feli 0.10 x 0.15 against Cani's 0.095 x 0.14 on the same head — wider *and*
taller — while projecting 0.15 forward against Cani's 0.19. Fat in section, short
in reach. Since the nose, the mouth and the whiskers are all sized and seated off
the muzzle, one oversized muzzle put three oversized features on a face with no
room for them.

### Two things the wedge itself needed

**Width and height taper independently.** A single ratio makes the front pad a
scale model of the back, which is a cone with corners. A snout narrows faster
across than top-to-bottom, and that difference *is* the jawline — the study this
shape came from used 0.64 across against 0.71 down, and collapsing them to one
number lost the shape being copied.

**The winding was inverted, and it announced itself.** Every wedge rendered as a
snout-shaped black hole: the muzzle was culled and what showed was the interior
of its own ink hull. `_patch_quad` emits `a-b-c`/`a-c-d` and this codebase's
front face for that order is the *negation* of the geometric cross product, so
corners listed clockwise-from-outside point inward. `_limb_mesh` records the same
trap in the same file — reversed winding made an inverted-hull outline "fill the
limb solid black". Derived from the existing `build_fan`, which was already
correct, rather than flipped until it looked right.

**And the mouth needed `ink: "none"` too** — a 4 mm stroke inside a 30 mm hull is
a 64 mm blob, which on a tapered pad drew as a hash mark. That is the fourth time
this pass: the mouth as seven boxes, the nose at a quarter of a muzzle radius,
the whiskers, and now the mouth again once the pad it sits on got small enough to
show it.


## The speckles were the eyes' own outlines, and the eyes were mostly outline

Reported last: *"little artifacts/noise on all of their faces -- looks like eye
bags or speckles when they should be plain… dotted lines next to their eyes and
vegi looks like mustache."*

Tested rather than reasoned about: the same gallery rendered with
`ink_metres`/`crown_ink_metres` collapsed to 0.0005. **Every artifact vanished.**
So the noise was the ink, and the only question left was which parts.

The eyes. A Feli eye is authored 0.053 m across and `_ink_node` grew a 0.030 m
inverted hull on every side of it -- so the drawn eye was 0.113 m and **more than
half of it was its own outline**. Grown out of a mark that thin, the hull bursts
through the surrounding head, and the fringes that leaves are the "eye bags" and
"dotted lines". Vegi, having no muzzle to distract from them, read as a
moustache.

There is a second defect underneath, and it is the one worth keeping. The hull is
a fixed distance in **metres** while the eye box scales with the **head**, so a
small-headed voli's eyes were proportionally much larger than a big-headed one's
-- which is precisely what `face_expressions.gd`'s head-normalised units exist to
prevent, undone downstream by a constant in another file that nobody had
connected to them.

Eyes now decline the hull like the mouth and the whiskers, and `EYE_WIDTH` /
`EYE_HEIGHT` rise by a fifth so the drawn eye is about what it was on a mid-sized
head -- and is now the size it says it is on every head.

**The first correction overshot, and that is the instructive part.** Compensating
for the hull's full growth -- 0.060 m across, 0.34 in normalised units on a
0.178 m head -- doubled the constants and produced eyes half again too big,
because most of that growth went sideways *into* the skull and was never visible.
What ever showed was the box plus a thin rim. Measured against the ink-collapsed
render instead of against the arithmetic, the answer is a fifth, not a double.

Muzzles also moved to the body's 0.018 m pen. A snout is part of a head, not a
crown-weight detail, and at 0.030 m its outline was printing a box on the cheek.

**That is six times in one pass** that a 30 mm hull on a small feature was the
actual defect: the mouth as seven boxes, the nose at a quarter of a muzzle
radius, the whiskers, the mouth again on a tapered pad, the muzzle on the cheek,
and now the eyes. The rule earned by all six: **a part small enough to be mostly
outline is not a small part, it is an outline** -- and the parts that are marks
rather than objects should carry no hull at all.
