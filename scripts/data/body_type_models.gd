extends RefCounted
class_name BodyTypeModels

## What each body type looks like, as data.
##
## `PlayerActor3D` was one hand-built rig: a capsule torso, a sphere head, four
## cylinders, and every attachment point written into `set_pose()` as a literal
## -- `left_arm.position = Vector3(-0.40, 1.52, 0.0)`. Six body types already
## existed in generation, carrying real height, mass and attribute deltas, and
## all six drew as that same capsule. A Feli and an Ursi differed in the
## simulation and were indistinguishable on the court.
##
## The rig cannot simply be swapped per type, because those literals only fit
## the proportions they were written for: a taller torso needs its shoulders
## higher or the arms grow out of its chest. So the attachment points move into
## the silhouette alongside the meshes, and `set_pose()` reads them. Posing then
## works for any body plan that can name a shoulder, a hip and a head.
##
## Three types are modelled here. `Vegi` replaces `Homi` -- there is no human
## in this world, and the default body being "the normal one" was the only thing
## making the other five read as costumes. Cani, Ursi and Simi still fall back
## to the Vegi silhouette until they are drawn; the fallback is explicit rather
## than a missing-key crash, and it is visible in `is_modelled()`.

## Body types with a silhouette of their own. Anything else falls back.
const MODELLED: Array[String] = ["Vegi", "Feli", "Avi"]

const FALLBACK_TYPE: String = "Vegi"

## Produce a Vegi grows as. A Vegi is not a generic plant person: each one is a
## particular fruit or vegetable, fixed for that player's whole career, because
## a body you recognise across seasons is the point of drawing bodies at all.
##
## Five, with deliberately unlike silhouettes -- squat, tall, wide, waisted and
## rooted -- so the type reads at a glance from across the court rather than
## needing the colour to carry it.
const PRODUCE: Array[String] = [
	"Tomato", "Aubergine", "Pumpkin", "Pear", "Turnip",
]

const PRODUCE_BODIES := {
	"Tomato": {
		"skin": Color("d63b2a"), "crown": Color("3f7a35"),
		"torso": {"shape": "sphere", "radius": 0.40, "height": 0.72},
		"torso_y": 1.02, "head_y": 1.46, "head_radius": 0.13,
		"shoulder": Vector2(0.38, 1.28), "rig_height": 1.80,
	},
	"Aubergine": {
		"skin": Color("54307a"), "crown": Color("4e8a3a"),
		"torso": {"shape": "capsule", "radius": 0.30, "height": 1.14},
		"torso_y": 1.16, "head_y": 1.78, "head_radius": 0.12,
		"shoulder": Vector2(0.32, 1.52), "rig_height": 2.06,
	},
	"Pumpkin": {
		"skin": Color("d97a1e"), "crown": Color("6b7a2e"),
		"torso": {"shape": "sphere", "radius": 0.50, "height": 0.76},
		"torso_y": 0.96, "head_y": 1.42, "head_radius": 0.15,
		"shoulder": Vector2(0.46, 1.20), "rig_height": 1.76,
	},
	"Pear": {
		"skin": Color("b8c452"), "crown": Color("5c8a3c"),
		## A pear is two masses, so it is the one produce with a second torso
		## lobe rather than a single scaled primitive -- the waist is the shape.
		"torso": {"shape": "sphere", "radius": 0.38, "height": 0.66},
		"torso_y": 0.94, "head_y": 1.62, "head_radius": 0.12,
		"shoulder": Vector2(0.30, 1.40), "rig_height": 1.92,
		"extra_lobe": {"radius": 0.26, "height": 0.52, "y": 1.36},
	},
	"Turnip": {
		"skin": Color("e8e2ea"), "crown": Color("7fa03e"),
		"torso": {"shape": "sphere", "radius": 0.42, "height": 0.80},
		"torso_y": 1.00, "head_y": 1.48, "head_radius": 0.13,
		"shoulder": Vector2(0.38, 1.26), "rig_height": 1.82,
		"blush": Color("9c5fa8"),
	},
}


## Deterministic per player, so a Vegi is the same aubergine every match, in
## every screen, for their whole career. Seeded from the id rather than drawn
## from any RNG: the generation stream is shared, and taking a value from it
## here would reroll every player created afterwards.
static func produce_for(player_id: int) -> String:
	var index := absi(hash("vegi:%d" % player_id)) % PRODUCE.size()
	return PRODUCE[index]


static func is_modelled(body_type: String) -> bool:
	return body_type in MODELLED


## One shared body, described as fractions of a player's own height.
##
## The three type functions below were each authored as a complete skeleton, so
## every one of them restated the whole figure in order to say the one or two
## things that make it distinctive. Restating the whole figure is how they drifted
## away from each other and away from a person: Feli's shoulders sat at 0.745 of
## its height and Avi's at 0.750, against roughly 0.82 on a human, while both
## hung arms long enough to put the hands at 0.30-0.32 where a person's fingertips
## reach about 0.38. Low shoulders and long arms is not a neutral pair of errors
## -- together they read as simian, which is a thing the silhouette says about a
## player that nobody chose to say.
##
## So the shared figure lives here once, and a body type is a *pull away from it*
## rather than a replacement for it. Long arms remain available to a body type
## that should have them, and remain available to an individual player whose
## attributes earn them; what is no longer available is a whole species reading
## as ape because its skeleton was drawn freehand.
const UNIVERSAL_RATIOS := {
	"shoulder_y": 0.815,
	"shoulder_x": 0.170,
	## Where the fingertips land. Arm length is derived from this and the
	## shoulder rather than set directly, because the reach is the thing the eye
	## actually reads and the length is only how you get there.
	"hand_y": 0.395,
	"hip_y": 0.520,
	"hip_x": 0.075,
	"torso_height": 0.420,
	"torso_radius": 0.145,
	"head_radius": 0.088,
	"head_y": 0.930,
	"leg_height": 0.330,
}

## How far a body type is allowed to pull the shared figure.
##
## At 1.0 each type is exactly the skeleton it was authored as; at 0.0 the three
## are identical and only their cosmetics differ. The drafts read too strongly --
## the type was the whole body rather than a note on top of one -- so the pull is
## a minority share. Identity is meant to arrive through the parts that are
## *added* (a tail, a beak and crest, a produce torso), which stay at full
## strength below, not through rebuilding the frame.
const TYPE_EXPRESSION: float = 0.45


## The full description of one player's body: meshes, attachment points,
## colours and cosmetic parts.
static func silhouette(body_type: String, player_id: int) -> Dictionary:
	var resolved := body_type if is_modelled(body_type) else FALLBACK_TYPE
	var authored: Dictionary
	match resolved:
		"Feli":
			authored = _feli()
		"Avi":
			authored = _avi()
		_:
			authored = _vegi(produce_for(player_id))
	return _toward_universal(authored)


## Blends an authored skeleton toward the shared figure.
##
## Only proportions are touched. Colours, materials, shapes and the whole
## `extras` list pass through untouched, because those are what the type is
## supposed to be saying.
static func _toward_universal(spec: Dictionary) -> Dictionary:
	var rig := float(spec.get("rig_height", 2.0))
	if rig <= 0.0:
		return spec
	var blended := spec.duplicate(true)
	var shoulder := Vector2(spec.get("shoulder", Vector2(0.34, 1.5)))
	var hip := Vector2(spec.get("hip", Vector2(0.15, 0.46)))
	var arm: Dictionary = Dictionary(spec.get("arm", {}))
	var authored_hand := shoulder.y - float(arm.get("height", 0.8))
	var shoulder_y := _pull(shoulder.y, UNIVERSAL_RATIOS.shoulder_y * rig)
	var hand_y := _pull(authored_hand, UNIVERSAL_RATIOS.hand_y * rig)
	blended["shoulder"] = Vector2(
		_pull(shoulder.x, UNIVERSAL_RATIOS.shoulder_x * rig), shoulder_y
	)
	blended["hip"] = Vector2(
		_pull(hip.x, UNIVERSAL_RATIOS.hip_x * rig),
		_pull(hip.y, UNIVERSAL_RATIOS.hip_y * rig),
	)
	## Derived, so the reach is what was blended and the bone follows. Floored
	## well clear of zero: a degenerate arm is a worse failure than a long one.
	arm["height"] = maxf(shoulder_y - hand_y, 0.25)
	blended["arm"] = arm
	var leg: Dictionary = Dictionary(spec.get("leg", {}))
	if leg.has("height"):
		leg["height"] = _pull(
			float(leg.height), UNIVERSAL_RATIOS.leg_height * rig
		)
		blended["leg"] = leg
	var head: Dictionary = Dictionary(spec.get("head", {}))
	if head.has("radius"):
		var head_radius := _pull(
			float(head.radius), UNIVERSAL_RATIOS.head_radius * rig
		)
		head["radius"] = head_radius
		if head.has("height"):
			head["height"] = head_radius * 1.9
		blended["head"] = head
	blended["head_y"] = _pull(
		float(spec.get("head_y", rig * 0.9)), UNIVERSAL_RATIOS.head_y * rig
	)
	## The produce torso is the Vegi's whole identity and its proportions are the
	## cosmetic, so it is left alone. The other two carry the kit on the torso and
	## are pulled like any other bone.
	if str(spec.get("torso_material", "kit")) != "skin":
		var torso: Dictionary = Dictionary(spec.get("torso", {}))
		if torso.has("height"):
			torso["height"] = _pull(
				float(torso.height), UNIVERSAL_RATIOS.torso_height * rig
			)
		if torso.has("radius"):
			torso["radius"] = _pull(
				float(torso.radius), UNIVERSAL_RATIOS.torso_radius * rig
			)
		blended["torso"] = torso
	return blended


static func _pull(authored: float, universal: float) -> float:
	return universal + (authored - universal) * TYPE_EXPRESSION


## A vegetable that plays volleyball.
##
## The produce is the torso rather than a head on a humanoid frame, because the
## silhouette has to survive being 40 pixels tall on a wide court shot. The kit
## therefore cannot be the torso colour the way it is for the other two -- it
## would paint over the whole body -- so it becomes a band around the middle
## and the produce keeps its own skin.
static func _vegi(produce: String) -> Dictionary:
	var body: Dictionary = PRODUCE_BODIES.get(produce, PRODUCE_BODIES["Tomato"])
	var torso: Dictionary = body.torso
	var shoulder: Vector2 = body.shoulder
	var extras: Array = [
		## Stem and leaves, the part that says "picked" rather than "grown".
		{
			"name": "Stem", "parent": "BodyPivot",
			"shape": "cylinder", "top_radius": 0.035, "bottom_radius": 0.05,
			"height": 0.20, "position": Vector3(0.0, body.head_y + 0.16, 0.0),
			"color": "crown",
		},
		{
			"name": "LeafLeft", "parent": "BodyPivot",
			"shape": "box", "size": Vector3(0.30, 0.02, 0.16),
			"position": Vector3(-0.15, body.head_y + 0.10, 0.02),
			"rotation": Vector3(0.0, -18.0, 22.0), "color": "crown",
		},
		{
			"name": "LeafRight", "parent": "BodyPivot",
			"shape": "box", "size": Vector3(0.30, 0.02, 0.16),
			"position": Vector3(0.15, body.head_y + 0.10, -0.02),
			"rotation": Vector3(0.0, 18.0, -22.0), "color": "crown",
		},
		## The singlet, as a band.
		##
		## It has to sit *clear* of the produce rather than near it. At 0.94 and
		## 1.02 of the body radius the band crossed the surface it was worn over
		## and the two fought for the same pixels, which drew a jagged
		## two-colour rash around every Vegi instead of a shirt. A band wider
		## than the widest point of the body cannot intersect it at all.
		{
			"name": "Kit", "parent": "BodyPivot",
			"shape": "cylinder",
			"top_radius": float(torso.get("radius", 0.40)) * 1.06,
			"bottom_radius": float(torso.get("radius", 0.40)) * 1.06,
			"height": 0.30, "position": Vector3(0.0, body.torso_y, 0.0),
			"color": "kit",
		},
	]
	if body.has("extra_lobe"):
		var lobe: Dictionary = body.extra_lobe
		extras.append({
			"name": "UpperLobe", "parent": "BodyPivot", "shape": "sphere",
			"radius": float(lobe.radius), "height": float(lobe.height),
			"position": Vector3(0.0, float(lobe.y), 0.0), "color": "skin",
		})
	if body.has("blush"):
		## A turnip is white below and purple on the shoulder. Same rule as the
		## kit band: the cap is a fraction *larger* than the body so it encloses
		## it cleanly, rather than a fraction smaller and coincident with it.
		extras.append({
			"name": "Blush", "parent": "BodyPivot", "shape": "sphere",
			"radius": float(torso.get("radius", 0.42)) * 1.04,
			"height": float(torso.get("height", 0.80)) * 0.58,
			"position": Vector3(0.0, float(body.torso_y) + 0.20, 0.0),
			"color_value": body.blush,
		})
	return {
		"produce": produce,
		"torso": torso,
		"torso_y": float(body.torso_y),
		"torso_material": "skin",
		"shorts": {"shape": "capsule", "radius": 0.24, "height": 0.30},
		"shorts_y": float(body.torso_y) - float(torso.get("height", 0.7)) * 0.55,
		"head": {"shape": "sphere", "radius": float(body.head_radius),
			"height": float(body.head_radius) * 1.9},
		"head_y": float(body.head_y),
		"arm": {"top_radius": 0.055, "bottom_radius": 0.07, "height": 0.72},
		"leg": {"top_radius": 0.085, "bottom_radius": 0.07, "height": 0.56},
		"shoe": {"shape": "capsule", "radius": 0.10, "height": 0.28},
		"shoulder": shoulder,
		"hip": Vector2(0.15, 0.44),
		"rig_height": float(body.rig_height),
		"skin": Color(body.skin),
		"crown": Color(body.crown),
		"extras": extras,
	}


## Lean, low and quick. Feli trades stamina and discipline for explosiveness and
## lateral speed, so the silhouette is built to read as *coiled*: a shorter
## torso carried low, digitigrade legs with a short shank, and a tail that gives
## the eye something to track when they change direction.
static func _feli() -> Dictionary:
	return {
		"torso": {"shape": "capsule", "radius": 0.27, "height": 0.94},
		"torso_y": 1.10,
		"torso_material": "kit",
		"shorts": {"shape": "capsule", "radius": 0.29, "height": 0.42},
		"shorts_y": 0.62,
		"head": {"shape": "sphere", "radius": 0.185, "height": 0.34},
		"head_y": 1.74,
		"arm": {"top_radius": 0.065, "bottom_radius": 0.08, "height": 0.84},
		## Short shank, long thigh: the leg reads as bent even when the pose
		## code has it straight, which is what makes a digitigrade stance work
		## without giving the rig an extra joint it would have to animate.
		"leg": {"top_radius": 0.105, "bottom_radius": 0.075, "height": 0.66},
		"shoe": {"shape": "capsule", "radius": 0.11, "height": 0.26},
		"shoulder": Vector2(0.36, 1.46),
		"hip": Vector2(0.16, 0.46),
		"rig_height": 1.96,
		"skin": Color("c98f4e"),
		"crown": Color("f0dcc0"),
		"extras": [
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.085, "height": 0.22,
				"position": Vector3(-0.11, 1.92, 0.0),
				"rotation": Vector3(0.0, 0.0, 14.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.085, "height": 0.22,
				"position": Vector3(0.11, 1.92, 0.0),
				"rotation": Vector3(0.0, 0.0, -14.0), "color": "skin",
			},
			{
				"name": "Muzzle", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.10, "height": 0.15,
				"position": Vector3(0.0, 1.70, -0.15), "color": "crown",
			},
			## Hung off the hips rather than the torso so it swings with the
			## stride the pose code already drives, instead of sitting rigid.
			## Swept up and back off the hips. The first pass angled it down and
			## forward, which put a brown stick alongside the shins and read as
			## a third leg -- the one silhouette mistake that actively costs
			## legibility rather than merely looking plain.
			{
				"name": "Tail", "parent": "BodyPivot", "shape": "cylinder",
				"top_radius": 0.03, "bottom_radius": 0.055, "height": 0.72,
				"position": Vector3(0.0, 0.96, 0.34),
				"rotation": Vector3(36.0, 0.0, 0.0), "color": "skin",
			},
		],
	}


## Tall, light and long-armed. Avi carries the wingspan bonus and the jump
## reach, and pays for it in reception stability -- a body that is all leverage
## and no ballast. The wing fans hang off the arm nodes so they travel with
## every pose the rig already has, which is what makes a block read as a wall
## rather than as two thin sticks.
static func _avi() -> Dictionary:
	return {
		"torso": {"shape": "capsule", "radius": 0.25, "height": 1.10},
		"torso_y": 1.20,
		"torso_material": "kit",
		"shorts": {"shape": "capsule", "radius": 0.27, "height": 0.38},
		"shorts_y": 0.64,
		"head": {"shape": "sphere", "radius": 0.155, "height": 0.30},
		"head_y": 1.94,
		"arm": {"top_radius": 0.05, "bottom_radius": 0.065, "height": 0.98},
		"leg": {"top_radius": 0.08, "bottom_radius": 0.055, "height": 0.80},
		"shoe": {"shape": "box", "size": Vector3(0.20, 0.06, 0.30)},
		"shoulder": Vector2(0.32, 1.62),
		"hip": Vector2(0.13, 0.50),
		"rig_height": 2.16,
		"skin": Color("8fb7d6"),
		"crown": Color("e8a63c"),
		"extras": [
			{
				"name": "Beak", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.075, "height": 0.26,
				"position": Vector3(0.0, 1.92, -0.18),
				"rotation": Vector3(-90.0, 0.0, 0.0), "color": "crown",
			},
			{
				"name": "Crest", "parent": "BodyPivot", "shape": "box",
				"size": Vector3(0.03, 0.22, 0.20),
				"position": Vector3(0.0, 2.10, 0.03),
				"rotation": Vector3(-14.0, 0.0, 0.0), "color": "crown",
			},
			{
				"name": "WingLeft", "parent": "BodyPivot/LeftArm",
				"shape": "box", "size": Vector3(0.06, 0.86, 0.40),
				"position": Vector3(-0.07, -0.40, 0.12),
				"rotation": Vector3(0.0, 0.0, 6.0), "color": "skin",
			},
			{
				"name": "WingRight", "parent": "BodyPivot/RightArm",
				"shape": "box", "size": Vector3(0.06, 0.86, 0.40),
				"position": Vector3(0.07, -0.40, 0.12),
				"rotation": Vector3(0.0, 0.0, -6.0), "color": "skin",
			},
			{
				"name": "TailFeathers", "parent": "BodyPivot", "shape": "box",
				"size": Vector3(0.34, 0.05, 0.44),
				"position": Vector3(0.0, 0.72, 0.26),
				"rotation": Vector3(24.0, 0.0, 0.0), "color": "crown",
			},
		],
	}


## One primitive from one spec dictionary. Everything is a Godot primitive on
## purpose: the existing rig already was, there is no asset pipeline in this
## project, and a silhouette assembled from primitives can be tuned by editing
## a number in this file rather than by re-exporting a mesh.
static func build_mesh(spec: Dictionary) -> Mesh:
	match str(spec.get("shape", "capsule")):
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = float(spec.get("radius", 0.3))
			sphere.height = float(spec.get("height", 0.6))
			sphere.radial_segments = 14
			sphere.rings = 7
			return sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = float(spec.get("top_radius", 0.1))
			cylinder.bottom_radius = float(spec.get("bottom_radius", 0.1))
			cylinder.height = float(spec.get("height", 0.5))
			cylinder.radial_segments = 10
			return cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = float(spec.get("radius", 0.1))
			cone.height = float(spec.get("height", 0.25))
			cone.radial_segments = 8
			return cone
		"box":
			var box := BoxMesh.new()
			box.size = spec.get("size", Vector3(0.2, 0.2, 0.2))
			return box
		_:
			var capsule := CapsuleMesh.new()
			capsule.radius = float(spec.get("radius", 0.3))
			capsule.height = float(spec.get("height", 1.0))
			capsule.radial_segments = 12
			capsule.rings = 6
			return capsule
