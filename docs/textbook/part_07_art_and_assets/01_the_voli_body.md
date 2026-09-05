# P7-C1 — The Voli Body

Status: **VERIFIED**
Keywords: silhouette, body type, produce, primitive, spec dictionary, lathe, extras, determinism
Primary sources: `scripts/data/body_type_models.gd`; `scenes/components/player_actor_3d.gd`; `scripts/domain/body_type_gameplay.gd`; `tools/validate_voli_body_construction.gd`

## Prerequisites

- [P2-C1 GDScript Basics](../part_02_gdscript/01_gdscript_basics.md) — `static func`, `const`
- [P2-C3 Collections, Types and Null](../part_02_gdscript/03_collections_types_and_null.md) — a body is a `Dictionary`, and a missing key is the most common bug in this file

## Learning goals

After this chapter you should be able to:

1. explain the difference between a **body type** and a **produce variant**, and say which of the two the simulation can see;
2. read a **spec dictionary** and predict what mesh it builds;
3. add a new body part to an existing body without touching the rig;
4. say why a body is rebuilt from data every time instead of being saved as a model file;
5. verify a body change with a probe rather than an opinion.

## Vocabulary

| Term | Meaning |
|---|---|
| **Voli** | A player. The project-wide name; "player" is reserved for the person holding the controller. |
| **Body type** | One of six morphologies: `Vegi`, `Avi`, `Cani`, `Feli`, `Ursi`, `Simi`. Stored on `VolleyballPlayer.body_type` and readable by the simulation. |
| **Produce** | One of five shapes a `Vegi` grows in: `Tomato`, `Aubergine`, `Pear`, `Stalk`, `Pepper`. Presentation only. **Never named anywhere a user can read.** |
| **Silhouette** | The complete `Dictionary` describing one voli's body, returned by `BodyTypeModels.silhouette()`. |
| **Spec** | A `Dictionary` describing a single mesh: a `shape` plus that shape's parameters. |
| **Primitive** | One of the shapes `build_mesh()` knows how to construct. |
| **Extra** | An optional named part appended to a body — an ear, a brow, a rib, a crown blade. |
| **Lathe** | A mesh made by revolving a 2D outline about the vertical axis. Called `profile` here. |

## 1. Two layers, and only one of them is real to the simulation

A voli's appearance comes from two decisions, and it matters enormously that
they live in different files.

**Body type** is a *gameplay* fact. `BodyTypeGameplay` (`scripts/domain/body_type_gameplay.gd`)
owns it:

```gdscript
const BODY_TYPES: Array[String] = ["Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi"]
```

It carries `BODY_TYPE_METRICS` (height, mass, wingspan offsets) and
`BODY_TYPE_ATTRIBUTES` (ceiling modifiers). The simulator can read all of it.

**Produce** is a *presentation* fact, and `BodyTypeModels` owns it alone:

```gdscript
const PRODUCE: Array[String] = [
	"Tomato", "Aubergine", "Pear", "Stalk", "Pepper",
]
```

Nothing in the simulation reads it. The file's own header states the rule that
governs it, and it is worth quoting because new contributors break it:

> "A Vegi is not 'a Tomato' and is never labelled as one anywhere a player can
> read… Surfacing the name turns a body into a species and invites a taxonomy
> nobody asked for."

So a produce may change how a voli is *drawn* and must never appear in a
scouting report, a squad list, a tooltip, or a save file field a user could
inspect.

> **Checkpoint.** Open `scripts/domain/body_type_gameplay.gd` and
> `scripts/data/body_type_models.gd` side by side. Confirm that the first
> contains no mesh data and the second contains no attribute modifiers. That
> separation is deliberate and CI checks the shared key.

## 2. Determinism: a voli is the same voli every time

A produce is not stored. It is *derived*, from the player's id:

```gdscript
static func produce_for(player_id: int) -> String:
	var index := absi(hash("vegi:%d" % player_id)) % PRODUCE.size()
	return PRODUCE[index]
```

Two consequences follow, and both are deliberate:

1. **A voli is the same aubergine in every screen, every match, for their whole
   career.** A body you recognise across seasons is the point of drawing bodies
   at all.
2. **It draws no numbers from the generation RNG.** The comment above the
   function says why: the generation stream is shared, so taking a value from it
   here would reroll every player created afterwards. This is a general rule in
   this codebase — *presentation must never consume simulation randomness.*

### Worked example: predicting a voli's produce

`produce_for(1)` returns `Pepper`. You can verify any id in a throwaway script:

```gdscript
extends SceneTree
const Bodies := preload("res://scripts/data/body_type_models.gd")
func _initialize() -> void:
	for id in [1, 41, 57, 61, 73]:
		print("%d -> %s" % [id, Bodies.produce_for(id)])
	quit()
```

Run with `godot --headless --path . --script res://tools/_tmp.gd`, then delete
the file. This is worth doing before you conclude "the change did not work" —
the voli you are staring at may simply not be the produce you edited.

## 3. The spec dictionary

Every drawable part of a body is a `Dictionary` with a `shape` key and whatever
parameters that shape needs. `BodyTypeModels.build_mesh(spec)` dispatches on it:

| `shape` | Builds | Key parameters |
|---|---|---|
| `profile` | A lathe — a revolved 2D outline | `profile` (an `Array[Vector2]`), `radius`, `height`, `depth_scale` |
| `sphere` | An ellipsoid | `radius`, `height` |
| `cylinder` | A tube or truncated cone | `top_radius`, `bottom_radius`, `height` |
| `cone` | A cylinder with a zero top | `radius`, `height` |
| `box` | A rectangular block | `size` (a `Vector3`) |
| `capsule` | A rounded rod — **the default** | `radius`, `height` |
| `limb` | A tapered arm or leg | `top_radius`, `bottom_radius`, `height` |
| `wedge` | A tapering snout | `radius`, `height`, `depth`, `taper_width`, `taper_height` |
| `fan` | A flat tapered plate, swept | `root_chord`, `tip_chord`, `span`, `thickness`, `sweep` |
| `sheath` | A C-shaped shell that wraps an axis | `radius`, `arc`, `height`, `thickness`, `taper` |
| `stroke` | A drawn line, used for the mouth | — |

Note the default. **An unrecognised `shape` silently produces a capsule.** A
typo therefore does not raise an error; it produces a rod where you expected a
wing, which is a much harder bug to see. Check spelling first when a part looks
wrong.

### Reading a real profile

Here is the `Stalk` torso:

```gdscript
"torso": {"shape": "profile", "radius": 0.19, "height": 1.36,
	"profile": [Vector2(-1.0, 0.165), Vector2(-0.88, 0.19),
		Vector2(-0.70, 0.148), Vector2(-0.20, 0.145),
		Vector2(0.40, 0.145), Vector2(0.80, 0.147),
		Vector2(1.0, 0.145)], "depth_scale": 0.86},
```

Read a profile point as `(normalised height, radius in metres)`:

- `x` runs `-1.0` at the bottom to `+1.0` at the top;
- `y` is the radius at that height, in metres, and its maximum should agree with
  the `radius` key;
- `depth_scale` squashes the revolved shape front-to-back, so `0.86` makes an
  ellipse rather than a circle in cross-section.

So this body is widest at its very base (`0.19`), steps in sharply at
`x = -0.70`, then runs almost **parallel-sided** to a flat top. That is a leek.

> **Vocabulary in use.** *Parallel-sided* is doing real work in that sentence.
> The same body drawn with a smooth convex bulge tapering to a rounded tip is a
> different vegetable entirely, and the difference is four numbers.

## 4. Extras: adding a part without touching the rig

Beyond the core parts (torso, head, arms, legs, shorts), a body carries an
`extras` array. Each entry is a spec plus a `name`, a `parent`, a `position`,
usually a `rotation`, and a `color`:

```gdscript
{
	"name": "BrowLeft", "parent": "BodyPivot", "shape": "sphere",
	"radius": 0.068, "height": 0.045,
	"position": Vector3(-0.052, 1.505, -0.122),
	"rotation": Vector3(-12.0, 0.0, -9.0),
	"scale": Vector3(1.35, 1.0, 0.48), "color": "crown",
}
```

**This is the extension point you will use most.** To add a feature to a body
you append a spec here; you do not modify `player_actor_3d.tscn`, and you do not
add a node. The rig reads the array and builds what it finds.

`color` is a *key* into the body's palette (`"skin"`, `"crown"`, …) rather than a
literal colour. Use `color_value` only when a part needs a colour the palette
does not name — the white base of a leek uses `color_value`, because it is one
part's exception rather than a palette entry.

### Worked example: giving a body a horizontal collar

Suppose you want a band lying *across* a body rather than along it. Parts default
to standing on their own Y axis, so the band needs a rotation:

```gdscript
{"x": 0.0, "y": 1.02, "height": 0.34, "thickness": 0.052,
	"rotation": Vector3(0.0, 0.0, 90.0), "z": 0.0},
```

Rotating 90° about Z turns the part's long axis from vertical to horizontal.
That single value is the difference between a rib and a collar — and, as §6
shows, between a body that reads as a plant and one that does not.

## 5. Where the rig meets the body

`PlayerActor3D.configure()` is the entry point:

```gdscript
func configure(
	p_player_id: int,
	home_team: bool,
	display_name: String,
	p_dominant_hand: String = "Right",
	physical_profile: Dictionary = {},
) -> void:
```

The `physical_profile` dictionary is the contract between simulation and
presentation. The keys it reads include:

| Key | Effect |
|---|---|
| `body_type` | Which of the six bodies to build; defaults to `"Vegi"` |
| `height_cm` | Clamped to `150.0 – 220.0` |
| `mass_kg` | Clamped to `45.0 – 145.0`; drives limb girth |
| `wingspan_cm` | Clamped to `150.0 – 235.0` |
| `club_region` | Selects the kit — see [P7-C2](02_kits_colour_and_marks.md) |
| `garment` | `"kit"` or `"formal"` |
| `position_role` | `"Libero"` changes the strip |
| `expression` | Which face to build — see [P7-C4](04_faces_and_expressions.md) |
| `appearance` | Per-voli cosmetic overrides, including `produce` |

Those clamps are not decoration. Passing a height of 300 does not produce a tall
voli; it produces a 220 cm voli, silently. If a body is not responding to a
number you changed, check whether the number is outside its clamp.

## 6. Common mistakes, all of them real

Each of these happened in this repository and each is recorded in the source.

**Reasoning about a silhouette instead of rendering it.** The `Stalk` crown went
through seven versions. Six were adjusted by argument and each was confidently
wrong: a tuft, then a starburst, then "a stalk with a fan headdress", then
antlers, then straps. The defect that survived all six was that the blades were
**a third of their correct width** — a fact one photograph settled instantly.
Render first.

**Fixing the wrong variable.** One of those versions held the torso radius fixed
to protect a gameplay property and tried to repair the read with profile detail.
No arrangement of profile points beats a 7:1 shaft; the neighbouring
`Aubergine` is nearly as tall and has no such problem purely because it is
wider. Identify which number actually controls the read before tuning any other.

**Checking only the flattering angle.** A crown built to bend in one plane read
correctly head-on and collapsed into vertical spikes at the portfolio's authored
yaw of 70°. `tools/run_voli_portfolio.gd` states the rule in its own header: *"a
pose that only works head-on is a pose that does not work."*

**Adding a part that duplicates another body's read.** Two produce shapes were
cut for being "a heavy round mass", which `Ursi` "owns outright and owns better".
The rule generalises: *a Vegi competing with a body type for the same read is a
Vegi doing nothing.*

**Assuming a fix is symmetric.** Giving one produce a penalty because its
geometry differs from another's produced a body that was strictly worse for no
design reason. A deviation belongs to the body that deviates; everything else is
baseline.

## 7. Check yourself

1. A teammate adds `"shape": "sphear"` to a spec. What appears on screen, and
   why is there no error? *(A capsule; unrecognised shapes fall through to the
   default branch.)*
2. Why must `produce_for()` avoid the generation RNG? *(The stream is shared;
   consuming a value would reroll every player generated afterwards.)*
3. You set `mass_kg` to `200` and nothing changes. Why? *(It is clamped to
   `145.0`.)*
4. Which of these may appear in a scouting report: body type, produce? *(Body
   type only. Produce is never named where a user can read it.)*
5. A profile's points peak at `y = 0.34` but its `radius` key says `0.19`. Which
   is wrong, and how would you tell? *(They disagree; the profile is the drawn
   shape, so inspect a render, then reconcile the key.)*

## Where this leads

- [P7-C2 Kits, Colour and Marks](02_kits_colour_and_marks.md) — dressing the body you just built
- [P7-C4 Faces and Expressions](04_faces_and_expressions.md) — the head's own rig
- [P7-C5 Rendering, Probes and Validation](05_rendering_probes_and_validation.md) — proving any of this
- [`BODY_TYPES.md`](../../design/BODY_TYPES.md) — why six types, and what each one is *for*
