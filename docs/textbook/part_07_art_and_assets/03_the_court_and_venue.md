# P7-C3 — The Court and the Venue

Status: **VERIFIED**
Keywords: court metrics, free zone, venue, camera preset, key/fill/ambient, exposure, envelope, open air
Primary sources: `scenes/components/match_court_3d.gd`; `tools/run_venue_probe.gd`; `tools/run_visual_court_gallery_v2.gd`

## Prerequisites

- [P7-C2 Kits, Colour and Marks](02_kits_colour_and_marks.md) — the floor colour you measured kits against is defined here
- [P2-C2 Resources, Nodes and Signals](../part_02_gdscript/02_resources_nodes_and_signals.md) — the court is a `Node3D` tree

## Learning goals

After this chapter you should be able to:

1. state the court's dimensions and the **free zone** around it, and say why nothing may stand inside it;
2. add a venue without putting geometry where a voli runs;
3. explain the three-light setup and why ambient is the largest;
4. say why every camera preset must fit inside one shared envelope;
5. avoid the two axis mistakes this system has already made.

## Vocabulary

| Term | Meaning |
|---|---|
| **Court** | The playing surface: 9 m wide (X) by 18 m long (Z), net at the origin. |
| **Free zone** | The clear area around the court. FIVB competition: 5 m from sidelines, 8 m behind end lines. |
| **Venue** | The *room* around the court — walls, roof, seating, light, atmosphere. |
| **Envelope** | The volume every camera preset must stay inside, set by the tightest enclosed venue. |
| **Key / fill / ambient** | The three lights. Key is directional, fill is an omni, ambient is the air. |
| **Exposure** | The camera's stop. `0.42` here — chosen so a deliberate glare is not a blow-out. |
| **Open air** | A venue with no roof; `venue_open_air` on `MatchCourt3D`. |

## 1. The court's numbers, stated once

```gdscript
@export var court_width: float = 9.0
@export var court_length: float = 18.0
```

And, from the probe that photographs it:

> "the net is at the origin, the posts sit at ±4.72, and the floor is 18 x 9."

So:

- **X is width.** The court spans `x = -4.5 … +4.5`. The posts sit just outside, at `±4.72`.
- **Z is length.** The court spans `z = -9 … +9`. The end lines are at `z = ±9`.
- **The net is the plane `z = 0`.**

> **Learn these three facts now.** Both of the venue system's worst bugs were
> axis confusions, and both would have been caught by someone who could say
> without checking which axis was 18 m long.

## 2. The free zone: where the building may start

```gdscript
const FREE_ZONE_SIDE := 9.5
const FREE_ZONE_END := 17.0
```

Measured from the centre: `4.5 + 5.0 = 9.5` at the sides, `9.0 + 8.0 = 17.0` at
the ends. The rule attached to them is absolute:

> **Nothing structural may stand inside this.**

### 2.1 The two bugs this constant exists to prevent

**Pillars on the court.** The first pass put Blôc's pillars at `z = -6.6` —
inside the free zone, *on the court, in play*, where a voli chasing a ball would
run into them. The source states the principle plainly: *"A pillar holds up a
hall; it does not stand on the sand."*

**Seating on the end line, from swapped axes.** The first build ran the
long-side seating rakes along Z at `8.2`. But the court is 18 m long along Z, so
`8.2` is 0.8 m *inside* an end line at `z = 9` — the stand stood exactly where a
server takes their run-up. As the comment says: *"Nobody could have jump served
in any of these halls."*

Note what these have in common. Neither is a rendering error; both are rooms
that look plausible in a screenshot and are unplayable. **A venue must be
checked against the game's geometry, not only against your eye.**

> **Why the end figure is the one that matters:** 8 m behind the end line,
> "because the run-up is what the end zone is *for*." A rule is easier to
> remember when you know what it protects.

## 3. Lighting: three lights, and the air is the biggest

```gdscript
const KEY_ENERGY: float = 0.62
const FILL_ENERGY: float = 0.95
const AMBIENT_ENERGY: float = 1.35

const KEY_COLOR := Color(1.0, 0.96, 0.90)
const FILL_COLOR := Color(1.0, 0.90, 0.78)
const AMBIENT_COLOR := Color(0.92, 0.87, 0.80)
```

Three things to take from this.

**Ambient does most of the work, and that is a correction.** The source records
the previous setup: ambient `0.72` against a key of `1.15` and a fill of `5.0`.
At those values *"ambient was a rounding error and every surface was either lit
or in shadow; there was no third state, which is what 'harsh' means."*

> **Vocabulary in use.** *Harsh* is not a mood word here — it names a specific
> measurable condition: a two-state lighting solution with no mid-tone. If you
> can only describe a render as "harsh", look for a missing third state.

### 3.1 Why the lights are warm

**Both lights are warm, and near each other.** *"near enough to each other that
the court does not read as two-toned."* The fill is warmer because it stands in
for bounce off a wooden floor — a light's colour should have a physical excuse.

### 3.2 Exposure is a prerequisite, not a polish step

**Exposure is `0.42`, and it is load-bearing.** From the venue probe: at the old
stop *"the floor was already clipping, so a deliberate glare and an accidental
blow-out were the same pixels."* One venue's entire concept was unphotographable
until the exposure was fixed. **Headroom is a prerequisite for an effect, not a
polish step.**

## 4. Cameras: one envelope for every preset

```gdscript
const CAMERA_PRESETS: Array[Dictionary] = [
	{"name": "Broadcast", "position": Vector3(15.0, 9.0, 9.5), "fov": 46.0},
	{"name": "End line", "position": Vector3(0.0, 8.0, 19.4), "fov": 50.0},
	{"name": "High tactical", "position": Vector3(0.0, 10.25, 0.2), "fov": 92.0},
]
```

The constraint is stated in the source and is worth internalising:

> "The compact Spëddigh shell is the limiting enclosed venue: its usable end
> depth is 20.05 m and its ceiling is 10.85 m. Presets live inside that common
> envelope so selecting one can never put the lens behind an opaque wall or
> above the roof."

Check the numbers: `End line` sits at `z = 19.4` against a usable depth of
`20.05`; `High tactical` sits at `y = 10.25` against a ceiling of `10.85`. Both
are inside, with very little to spare.

**This is why `High tactical` has a 92° FOV.** It cannot rise far enough to frame
the whole court from a comfortable lens, so *"the tactical FOV widens to retain
the whole court from the physically available height."* The wide angle is a
consequence of the ceiling, not a stylistic choice.

> **Design principle.** A shared constraint belongs to the *tightest* member of
> the set. Tuning each preset per venue would produce a camera that behaves
> differently depending on where you are playing, which is worse than a
> compromise that behaves the same everywhere.

## 5. Venues

Eight venues, each keyed to a region:

```gdscript
const VENUE_REGION := {
	"landavol": "Landavol", "speddigh": "Spëddigh", "pawa": "Pāwa Hitō",
	"bloc": "Blôc du Larg", "xervu": "Xérvu", "taktika": "Taktikã",
	"aace": "A'ace", "ispayk": "Ĭspayk",
}
```

`MatchCourt3D` carries the venue state:

```gdscript
var venue_region: String = ""
var venue_id: String = ""
var venue_open_air: bool = false
var venue_tight: bool = false
```

and builds the room from the reviewed gallery geometry:

```gdscript
const VENUE_BUILDER := preload("res://tools/run_visual_court_gallery_v2.gd")
```

**A `tools/` script is preloaded by a runtime component.** That is unusual and
deliberate — the gallery is where the geometry was reviewed, and *"its base
exposes a runtime entry point that builds only the room (no probe actors or
capture)."* One source, so a venue cannot be right in a render and wrong in a
match. The venue probe carefully does *not* preload the court in return, because
that would create a circular resource dependency.

### 5.1 What a venue is allowed to be

From the probe's header:

> "almost none of it is the floor: altitude, mist, glare off a pillar, a
> resonance at the end line, a wall of sponsor screens. Those are light,
> atmosphere and a little geometry."

And a scoping note you should respect: each venue is currently *"a look for a
modifier that is not designed yet and is not designed here."* The question the
probe can settle is narrow — **whether a venue reads as itself in one frame,
from the camera a match is actually watched from, without a label.**

## 6. Adding a venue: the procedure

1. **Pick the region** and add an entry to `VENUE_REGION`.
2. **Build the room** in the venue builder, keeping every structural element
   outside `FREE_ZONE_SIDE` / `FREE_ZONE_END`.
3. **Check your axes.** 9 m across X, 18 m along Z. Write down which is which
   before placing anything.
4. **Stay inside the envelope** if you add or move geometry near the ceiling or
   the end wall — the camera presets assume Spëddigh's 20.05 m / 10.85 m.
5. **Photograph it:**
   ```bash
   godot --path . res://tools/venue_probe.tscn
   ```
6. **Apply the one-frame test:** does it read as itself, from the broadcast
   camera, with no label?

## 7. Common mistakes

**Placing structure by eye.** A pillar 2 m inside the free zone looks
fine in a still and is standing on the court.

**Swapping X and Z.** The court is not square, and the mistake produces a room
that is subtly wrong rather than obviously broken.

**Tuning a camera per venue.** Presets are shared; the envelope belongs to the
tightest hall.

**Adding an effect before checking headroom.** A glare needs somewhere above the
floor's value to go.

**Restating court metrics locally.** The probe takes them "from the court scene
rather than restated." Two copies of a dimension is one dimension that will
drift.

## 8. Check yourself

1. A wall is proposed at `z = 15`. Legal? *(Yes — the end free zone ends at `17.0`. But check the camera envelope: `End line` sits at `z = 19.4`.)*
2. A pillar at `x = 8.0`? *(No. The side free zone runs to `9.5`.)*
3. Why is ambient the strongest light? *(To supply the mid-tone; without it every surface is lit or shadowed, which is what "harsh" means.)*
4. Why does `High tactical` use a 92° FOV? *(The ceiling limits its height, so the lens must widen to keep the whole court.)*
5. Why does `MatchCourt3D` preload a script from `tools/`? *(So the reviewed geometry has exactly one source and cannot differ between render and match.)*

## Where this leads

- [P7-C5 Rendering, Probes and Validation](05_rendering_probes_and_validation.md) — running these probes properly
- [P4-C6 Adjusting and Extending Live Systems](../part_04_match_engine/06_adjusting_and_extending_live_systems.md) — the 2D counterpart of this view
- [`ABSTRACTION_AND_MANIFESTATION.md`](../../design/ABSTRACTION_AND_MANIFESTATION.md) — why there are paired 2D and 3D views at all
