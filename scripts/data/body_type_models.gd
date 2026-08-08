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
## All six types are modelled. `Vegi` replaces `Homi` -- there is no human in
## this world, and the default body being "the normal one" was the only thing
## making the other five read as costumes. Vegi is now the no-lean body the way
## Landavol is the no-lean region: it exists so "unremarkable" has a home instead
## of every type needing an identity.
##
## The three animal types are told apart at the **ear** before anything else,
## because ears survive a silhouette when a torso profile does not: Feli pricks
## up, Cani drops, Ursi is round and set high, Simi is a flat disc on the side of
## the head. Everything below that -- limb thickness, leg length, where the mass
## sits -- is the second read.

## Body types with a silhouette of their own. Anything else falls back.
const MODELLED: Array[String] = ["Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi"]

const FALLBACK_TYPE: String = "Vegi"

## The shapes a Vegi grows in.
##
## These names are internal and stay internal. A Vegi is not "a Tomato" and is
## never labelled as one anywhere a player can read -- they are all just Vegi,
## and the produce is how the variety is generated rather than what the variety
## *is*. Surfacing the name turns a body into a species and invites a taxonomy
## nobody asked for; keeping it internal leaves a roster of Vegi who happen to
## look unlike each other, which is the intent.
##
## Fixed per player for their whole career, because a body you recognise across
## seasons is the point of drawing bodies at all.
##
## Six, with deliberately unlike silhouettes -- squat, tall, wide, waisted,
## rooted and stalky -- so one Vegi reads as a different Vegi at a glance from
## across the court rather than needing the colour to carry it.
## Five, and the count went *down* on purpose.
##
## Pumpkin and Turnip were both "a heavy round mass", which is the silhouette
## Ursi already owns outright and owns better -- a Vegi competing with a body
## type for the same read is a Vegi doing nothing. Pear is already the massive
## one among the produce and needs no help. Pepper takes their slot as the
## lobed, square-shouldered shape none of the others reach, and it is the reason
## palettes exist: a bell pepper is the one produce whose *colour* is the first
## thing anybody names about it.
const PRODUCE: Array[String] = [
	"Tomato", "Aubergine", "Pear", "Stalk", "Pepper",
]

const PRODUCE_BODIES := {
	"Tomato": {
		"skin": Color("d63b2a"), "crown": Color("3f7a35"),
		"crown_shape": "calyx",
		"torso": {"shape": "sphere", "radius": 0.33, "height": 0.66},
		"torso_y": 1.02, "head_y": 1.46, "head_radius": 0.13,
		"shoulder": Vector2(0.31, 1.28), "rig_height": 1.80,
	},
	"Aubergine": {
		"skin": Color("54307a"), "crown": Color("4e8a3a"),
		"crown_shape": "hood",
		"torso": {"shape": "capsule", "radius": 0.25, "height": 1.10},
		"torso_y": 1.16, "head_y": 1.78, "head_radius": 0.12,
		"shoulder": Vector2(0.27, 1.52), "rig_height": 2.06,
	},
	"Pear": {
		"skin": Color("b8c452"), "crown": Color("5c8a3c"),
		"crown_shape": "twig",
		## A pear is two masses, so it is the one produce with a second torso
		## lobe rather than a single scaled primitive -- the waist is the shape.
		"torso": {"shape": "sphere", "radius": 0.32, "height": 0.60},
		"torso_y": 0.94, "head_y": 1.62, "head_radius": 0.12,
		"shoulder": Vector2(0.26, 1.40), "rig_height": 1.92,
		"extra_lobe": {"radius": 0.22, "height": 0.48, "y": 1.36},
	},
	## The stalky one -- green onion, celery, sugarcane. Every other produce is
	## a mass with limbs on it; this is the one that is essentially vertical, so
	## it covers a silhouette none of the other five reach. The narrow torso is
	## the whole read, which is why it is the tallest and the thinnest at once.
	"Stalk": {
		"skin": Color("9dbf5c"), "crown": Color("cfe08a"),
		"torso": {"shape": "capsule", "radius": 0.165, "height": 1.34},
		"torso_y": 1.24, "head_y": 1.92, "head_radius": 0.105,
		"shoulder": Vector2(0.22, 1.60), "rig_height": 2.12,
		## Ribs, so a thin cylinder does not read as a pipe. Offset in pairs
		## down the length rather than spaced evenly, which is closer to how a
		## stalk actually bundles.
		"ribs": [
			{"x": -0.10, "y": 1.44, "height": 0.86},
			{"x": 0.10, "y": 1.40, "height": 0.78},
			{"x": 0.0, "y": 1.34, "height": 0.94},
		],
		"crown_shape": "blades",
	},
	## Square-shouldered and lobed, which is a shape none of the other four
	## reach: broad across the top and tapering to the bottom, rather than a
	## mass with a waist or a tube. The lobes reuse the Stalk's rib mechanism
	## turned through ninety degrees of purpose -- vertical capsules laid on the
	## surface, which is exactly what a pepper's ridges are.
	"Pepper": {
		"skin": Color("c8332c"), "crown": Color("4f7c3a"),
		"torso": {"shape": "sphere", "radius": 0.335, "height": 0.78},
		"torso_y": 1.04, "head_y": 1.56, "head_radius": 0.128,
		"shoulder": Vector2(0.34, 1.34), "rig_height": 1.88,
		## Laid on the sphere's surface rather than near its axis. At the Stalk's
		## depth these sat inside a torso twice the radius and drew nothing --
		## a rib is a ridge, and a ridge that does not break the surface is not
		## visible at any distance.
		"ribs": [
			{"x": -0.215, "y": 1.05, "z": 0.215, "height": 0.60, "thickness": 0.058},
			{"x": 0.0, "y": 1.05, "z": 0.305, "height": 0.66, "thickness": 0.062},
			{"x": 0.215, "y": 1.05, "z": 0.215, "height": 0.60, "thickness": 0.058},
			{"x": -0.215, "y": 1.05, "z": -0.215, "height": 0.60, "thickness": 0.058},
			{"x": 0.215, "y": 1.05, "z": -0.215, "height": 0.60, "thickness": 0.058},
		],
		"crown_shape": "cap",
	},
}


## Colourways, per body.
##
## Two volis of the same body type used to be the same colour, which meant the
## only thing separating them on a roster was a name -- and a roster is where you
## are supposed to *recognise* people. A palette is the cheapest identity there
## is: it costs no geometry, survives any distance the game is watched from, and
## it is the first thing anybody describes a teammate by.
##
## Bell peppers are why this exists. A pepper's colour is the first thing anybody
## names about it, so the produce that most needed variants is the one that made
## it obvious every body needed them.
##
## Deterministic per voli and fixed for their career, like the produce. `crown`
## is the secondary -- leaves, beak, ears, muzzle -- and it is chosen with the
## skin rather than separately, because the pairing is the palette.
const PALETTES := {
	"Feli": [
		{"skin": Color("c98f4e"), "crown": Color("f0dcc0")},
		{"skin": Color("6d6a66"), "crown": Color("d9d5cd")},
		{"skin": Color("2f2b2c"), "crown": Color("b9a98f")},
		{"skin": Color("d8b98a"), "crown": Color("8a5f3c")},
	],
	"Avi": [
		{"skin": Color("8fb7d6"), "crown": Color("e8a63c")},
		{"skin": Color("d9dfe4"), "crown": Color("d96a3c")},
		{"skin": Color("4a7f5e"), "crown": Color("e8c93c")},
		{"skin": Color("c46b8a"), "crown": Color("f2e0c0")},
	],
	"Cani": [
		{"skin": Color("8a6a45"), "crown": Color("e8ddc8")},
		{"skin": Color("3c3a3f"), "crown": Color("c9c2b4")},
		{"skin": Color("c9a06a"), "crown": Color("f4ecdc")},
		{"skin": Color("6f4a34"), "crown": Color("d8c3a0")},
	],
	"Ursi": [
		{"skin": Color("4a3b34"), "crown": Color("d9c9b4")},
		{"skin": Color("1f1c1e"), "crown": Color("cdd6db")},
		{"skin": Color("8a6f52"), "crown": Color("efe3cd")},
		{"skin": Color("d6c6ad"), "crown": Color("6b5847")},
	],
	"Simi": [
		{"skin": Color("6f5a4e"), "crown": Color("f0d9bd")},
		{"skin": Color("2e2a2b"), "crown": Color("c4a888")},
		{"skin": Color("a08466"), "crown": Color("f4e6cf")},
		{"skin": Color("55402f"), "crown": Color("e0b98c")},
	],
	"Tomato": [
		{"skin": Color("d63b2a"), "crown": Color("3f7a35")},
		{"skin": Color("e8b13a"), "crown": Color("4d7d38")},
		{"skin": Color("7d2a3a"), "crown": Color("4a7040")},
	],
	"Aubergine": [
		{"skin": Color("54307a"), "crown": Color("4e8a3a")},
		{"skin": Color("2b2140"), "crown": Color("6a9b46")},
		{"skin": Color("d8d2e0"), "crown": Color("5b8c3f")},
	],
	"Pear": [
		{"skin": Color("b8c452"), "crown": Color("5c8a3c")},
		{"skin": Color("caa23c"), "crown": Color("6b7a3a")},
		{"skin": Color("8f5a3a"), "crown": Color("5f7a42")},
	],
	"Stalk": [
		{"skin": Color("9dbf5c"), "crown": Color("cfe08a")},
		{"skin": Color("e4ebd2"), "crown": Color("8fbf5c")},
		{"skin": Color("6f9a4a"), "crown": Color("d6e6a0")},
	],
	## Five, because a bell pepper's colours are a known set and this is the
	## produce the whole palette idea came from.
	"Pepper": [
		{"skin": Color("c8332c"), "crown": Color("4f7c3a")},
		{"skin": Color("e8b43a"), "crown": Color("4f7c3a")},
		{"skin": Color("d97a1e"), "crown": Color("5a8440")},
		{"skin": Color("5d8f3f"), "crown": Color("3f6b32")},
		{"skin": Color("6b3f7a"), "crown": Color("4a7040")},
	],
}


## Which colourway a voli wears. Seeded from the id like `produce_for`, and
## deliberately a *different* hash string so body shape and colour do not
## correlate -- one hash driving both would make every Tomato red and every
## Stalk pale, which is the thing this is meant to prevent.
static func palette_for(body_key: String, player_id: int) -> Dictionary:
	var options: Array = PALETTES.get(body_key, [])
	if options.is_empty():
		return {}
	var index := absi(hash("palette:%s:%d" % [body_key, player_id])) % options.size()
	return Dictionary(options[index])


## The torso's radius a fraction of the way up from its centre, so a part worn
## on it can be sized to where it actually sits. `up` is in units of the torso's
## own vertical semi-axis.
##
## A sphere torso narrows toward the top and a capsule does not, and a single
## constant cannot serve both -- which is how the kit band ended up either
## buried or floating depending on which produce wore it.
static func _torso_radius_at(torso: Dictionary, up: float) -> float:
	var radius := float(torso.get("radius", 0.32))
	if str(torso.get("shape", "sphere")) != "sphere":
		return radius
	var t := clampf(up, 0.0, 0.98)
	return radius * sqrt(maxf(1.0 - t * t, 0.04))


## What grows out of the top. One shape per produce rather than one stem and two
## leaves for all of them.
##
## Every Vegi wearing the same crown meant the head was the one place they were
## identical, which is the worst place to be identical -- it is where the eye
## goes first and where the face already lives. These are also chosen to *not*
## sit at eye level: the old leaves stuck straight out sideways across the face,
## which was the collision complaint.
static func _produce_crown(body: Dictionary) -> Array:
	var top := float(body.head_y) + float(body.head_radius) * 0.92
	match str(body.get("crown_shape", "calyx")):
		"hood":
			## Aubergine. A broad calyx that caps the head rather than sprouting
			## from it, angled back so it never crosses the face.
			return [
				{
					"name": "Hood", "parent": "BodyPivot", "shape": "cone",
					"radius": float(body.head_radius) * 1.48, "height": 0.19,
					"position": Vector3(0.0, top + 0.05, 0.03),
					"rotation": Vector3(-16.0, 0.0, 0.0), "color": "crown",
				},
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.03, "bottom_radius": 0.042, "height": 0.13,
					"position": Vector3(0.0, top + 0.15, 0.02), "color": "crown",
				},
			]
		"twig":
			## Pear. A pear has a bare stalk and nothing else, and it is the one
			## produce whose silhouette is already doing enough work.
			return [
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.022, "bottom_radius": 0.038, "height": 0.26,
					"position": Vector3(0.0, top + 0.11, 0.01),
					"rotation": Vector3(-9.0, 0.0, 6.0), "color": "crown",
				},
			]
		"blades":
			## Stalk. A fan of upright leaves, which is what a stalk's top is.
			var blades: Array = []
			for index in range(3):
				var lean := -16.0 + 16.0 * float(index)
				blades.append({
					"name": "Blade%d" % index, "parent": "BodyPivot",
					"shape": "box", "size": Vector3(0.055, 0.30, 0.022),
					"position": Vector3(
						-0.05 + 0.05 * float(index), top + 0.14, 0.0
					),
					"rotation": Vector3(0.0, 0.0, lean), "color": "crown",
				})
			return blades
		"cap":
			## Pepper. A flat cap disc with a short thick stem through it.
			return [
				{
					"name": "Cap", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": float(body.head_radius) * 1.02,
					"bottom_radius": float(body.head_radius) * 1.26,
					"height": 0.055,
					"position": Vector3(0.0, top + 0.02, 0.0), "color": "crown",
				},
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.032, "bottom_radius": 0.046, "height": 0.14,
					"position": Vector3(0.0, top + 0.10, 0.0), "color": "crown",
				},
			]
		_:
			## Tomato. A star calyx, laid flat on the crown of the head where it
			## reads as a tomato's five points rather than as ears.
			var points: Array = [
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.028, "bottom_radius": 0.042, "height": 0.14,
					"position": Vector3(0.0, top + 0.07, 0.0), "color": "crown",
				},
			]
			for index in range(5):
				var angle := TAU * float(index) / 5.0
				points.append({
					"name": "Calyx%d" % index, "parent": "BodyPivot",
					"shape": "box", "size": Vector3(0.055, 0.022, 0.18),
					"position": Vector3(
						sin(angle) * float(body.head_radius) * 0.62,
						top + 0.01,
						cos(angle) * float(body.head_radius) * 0.62,
					),
					"rotation": Vector3(-14.0, rad_to_deg(angle), 0.0),
					"color": "crown",
				})
			return points


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
	## Raised, and `leg_height` grown to match, so the extra room becomes leg
	## rather than a longer gap. The hip block above it was also deep enough to
	## eat the top of the thigh, which is what made the joint read as a bubble
	## with legs under it instead of a waist.
	"hip_y": 0.545,
	"hip_x": 0.075,
	"torso_height": 0.420,
	"torso_radius": 0.145,
	"head_radius": 0.088,
	"head_y": 0.930,
	"leg_height": 0.370,
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
	## Which colourway this voli wears. Keyed by produce for a Vegi and by type
	## for everyone else, so a palette is a property of the *shape* rather than
	## of the species -- a Tomato's colours have nothing to say about a Stalk's.
	var palette_key := produce_for(player_id) if resolved == "Vegi" else resolved
	match resolved:
		"Feli":
			authored = _feli()
		"Avi":
			authored = _avi()
		"Cani":
			authored = _cani()
		"Ursi":
			authored = _ursi()
		"Simi":
			authored = _simi()
		_:
			authored = _vegi(produce_for(player_id))
	var palette := palette_for(palette_key, player_id)
	if not palette.is_empty():
		authored["skin"] = palette.skin
		authored["crown"] = palette.crown
	return _add_neck(_toward_universal(authored))


## Close the gap between the torso and the head, whatever the blend left there.
##
## `_toward_universal` pulls `head_y` toward the shared figure but leaves the
## torso where the type authored it, so the two move apart by however far that
## type disagreed with the reference. On the round produce that is most of a
## head's height, and a head hanging clear of the shoulders reads as broken
## rather than as long-necked.
##
## Fixing it by re-authoring every `head_y` would be a set of constants tuned
## against the blend -- correct until the blend moves, and silently wrong after.
## A neck sized from the two things it spans is correct by construction, and it
## is also just a real part of a body.
static func _add_neck(spec: Dictionary) -> Dictionary:
	var torso: Dictionary = spec.get("torso", {})
	var head: Dictionary = spec.get("head", {})
	var torso_top := float(spec.get("torso_y", 1.1)) \
		+ float(torso.get("height", 0.8)) * 0.5
	var head_bottom := float(spec.get("head_y", 1.8)) \
		- float(head.get("height", 0.3)) * 0.5
	## Always drawn, even when the two already meet: a short collar of neck at
	## the join is what stops a sphere head reading as balanced on a sphere body.
	var span := maxf(head_bottom - torso_top, 0.0) + 0.06
	var extras: Array = spec.get("extras", [])
	extras.append({
		"name": "Neck", "parent": "BodyPivot", "shape": "cylinder",
		"top_radius": float(head.get("radius", 0.13)) * 0.52,
		"bottom_radius": float(head.get("radius", 0.13)) * 0.72,
		"height": span,
		"position": Vector3(0.0, torso_top + span * 0.5 - 0.03, 0.0),
		"color": "skin",
	})
	spec["extras"] = extras
	return spec


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
	var extras: Array = _produce_crown(body)
	## The singlet, as a **collar** rather than a belt.
	##
	## It used to be a cylinder 6% wider than the widest point of the torso, sat
	## at the torso's centre. That was the fix for an earlier bug -- a band the
	## same size as the body fought it for pixels -- but the cure was worse: a
	## ring wider than the body is a ring *sticking out of* the body, and on a
	## round produce it read as a hoop somebody had been posted through. It also
	## sat exactly where the arms swing, so every pose collided with it.
	##
	## A collar avoids both. It sits high, where every produce narrows toward the
	## head, so it is small; it is sized from the torso's own profile at that
	## height rather than from its widest point, so it hugs rather than floats;
	## and it is nowhere near the arms. A neckline is also simply what a singlet
	## looks like from across a court -- the band was never reading as clothing.
	var collar_y := float(body.torso_y) + float(torso.get("height", 0.7)) * 0.42
	extras.append({
		"name": "Kit", "parent": "BodyPivot",
		"shape": "cylinder",
		"top_radius": _torso_radius_at(torso, 0.34) * 1.08,
		"bottom_radius": _torso_radius_at(torso, 0.30) * 1.12,
		"height": 0.075, "position": Vector3(0.0, collar_y, 0.0),
		"color": "kit",
	})
	if body.has("extra_lobe"):
		var lobe: Dictionary = body.extra_lobe
		extras.append({
			"name": "UpperLobe", "parent": "BodyPivot", "shape": "sphere",
			"radius": float(lobe.radius), "height": float(lobe.height),
			"position": Vector3(0.0, float(lobe.y), 0.0), "color": "skin",
		})
	if body.has("ribs"):
		## A stalk is a bundle, not a tube. Without these the narrowest torso in
		## the set reads as a length of pipe with a face on it.
		var rib_index := 0
		for raw_rib in body.ribs:
			var rib: Dictionary = raw_rib
			rib_index += 1
			extras.append({
				"name": "Rib%d" % rib_index, "parent": "BodyPivot",
				"shape": "capsule",
				"height": float(rib.height),
				"radius": float(rib.get("thickness", 0.045)),
				"position": Vector3(
					float(rib.x), float(rib.y), float(rib.get("z", 0.04))
				),
				"color": "crown",
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
		"shorts": {"shape": "box", "size": Vector3(0.42, 0.20, 0.30)},
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
		"shorts": {"shape": "box", "size": Vector3(0.50, 0.22, 0.34)},
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
		"shorts": {"shape": "box", "size": Vector3(0.44, 0.20, 0.32)},
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
				## Feathers, not panels. The wing fans are the largest cosmetic in
				## the game and the only one big enough to hide the body wearing
				## them -- an Avi's own torso, and on a block the teammate behind.
				## Translucency keeps the reach they exist to show while giving
				## back the silhouette they were eating.
				"alpha": 0.55,
			},
			{
				"name": "WingRight", "parent": "BodyPivot/RightArm",
				"shape": "box", "size": Vector3(0.06, 0.86, 0.40),
				"position": Vector3(0.07, -0.40, 0.12),
				"rotation": Vector3(0.0, 0.0, -6.0), "color": "skin",
				"alpha": 0.55,
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
## How many sides a lathed limb has, and how many rings each rounded end gets.
##
## Twelve is the same count the capsules use, so a limb sits beside a torso
## without one of them looking faceted next to the other. Three cap rings is the
## fewest that still reads as round at the shoulder, which is where a limb meets
## a body and where a flat lid is most obvious.
const LIMB_SIDES: int = 12
const LIMB_CAP_RINGS: int = 3


## A limb: tapered along its length and rounded at both ends.
##
## **This is the shape the complaint was about.** Arms and legs were
## `CylinderMesh`, and a cylinder has flat lids -- so a voli was a produce with
## four rods stuck in it, and no amount of colour or pose fixed that, because the
## problem was the geometry ending in a disc. A limb narrows toward the wrist or
## ankle and finishes in a dome, and those two facts are most of what separates a
## drawn body from an assembled one.
##
## Lathed by hand rather than reached for from the primitives, because Godot has
## no tapered capsule: `CapsuleMesh` has one radius and `CylinderMesh` has two
## radii and no caps worth the name. The profile is a bottom hemisphere scaled to
## the bottom radius, a straight taper, and a top hemisphere scaled to the top
## radius -- so a limb is one surface from end to end and the ends belong to it.
static func _limb_mesh(
	top_radius: float, bottom_radius: float, height: float
) -> Mesh:
	var top := maxf(top_radius, 0.004)
	var bottom := maxf(bottom_radius, 0.004)
	var shaft := maxf(height - top - bottom, 0.001)
	## Each ring as (height above the base, radius there).
	var profile: Array[Vector2] = []
	for ring in range(LIMB_CAP_RINGS + 1):
		var angle := PI * 0.5 * (float(ring) / float(LIMB_CAP_RINGS))
		profile.append(Vector2(
			bottom - cos(angle) * bottom, sin(angle) * bottom
		))
	profile.append(Vector2(bottom + shaft, top))
	for ring in range(1, LIMB_CAP_RINGS + 1):
		var angle := PI * 0.5 * (float(ring) / float(LIMB_CAP_RINGS))
		profile.append(Vector2(
			bottom + shaft + sin(angle) * top, cos(angle) * top
		))
	## Centred on the origin like every other primitive here, so a limb can be
	## dropped in where a cylinder was without moving anything that positions it.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(profile.size() - 1):
		var lower: Vector2 = profile[index]
		var upper: Vector2 = profile[index + 1]
		for side in range(LIMB_SIDES):
			var a := TAU * float(side) / float(LIMB_SIDES)
			var b := TAU * float(side + 1) / float(LIMB_SIDES)
			var points := [
				Vector3(cos(a) * lower.y, lower.x - height * 0.5, sin(a) * lower.y),
				Vector3(cos(b) * lower.y, lower.x - height * 0.5, sin(b) * lower.y),
				Vector3(cos(b) * upper.y, upper.x - height * 0.5, sin(b) * upper.y),
				Vector3(cos(a) * upper.y, upper.x - height * 0.5, sin(a) * upper.y),
			]
			for corner in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(points[corner])
	surface.generate_normals()
	return surface.commit()


static func build_mesh(spec: Dictionary) -> Mesh:
	match str(spec.get("shape", "capsule")):
		"limb":
			return _limb_mesh(
				float(spec.get("top_radius", 0.09)),
				float(spec.get("bottom_radius", 0.07)),
				float(spec.get("height", 0.5)),
			)
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


## Broad, upright and built to keep going. Cani is the endurance body: a wider
## chest than Feli carries the stamina and transition-speed bonus, and the legs
## are plantigrade rather than digitigrade, which is the fastest way to tell the
## two animals apart from a distance -- Feli reads as coiled, Cani reads as
## *standing*. The ears drop instead of pricking up, for the same reason.
static func _cani() -> Dictionary:
	return {
		"torso": {"shape": "capsule", "radius": 0.295, "height": 1.00},
		"torso_y": 1.14,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.54, 0.22, 0.36)},
		"shorts_y": 0.62,
		"head": {"shape": "sphere", "radius": 0.185, "height": 0.35},
		"head_y": 1.80,
		"arm": {"top_radius": 0.075, "bottom_radius": 0.09, "height": 0.86},
		"leg": {"top_radius": 0.115, "bottom_radius": 0.085, "height": 0.74},
		"shoe": {"shape": "capsule", "radius": 0.115, "height": 0.28},
		"shoulder": Vector2(0.38, 1.50),
		"hip": Vector2(0.17, 0.48),
		"rig_height": 2.00,
		"skin": Color("8a6a45"),
		"crown": Color("e8ddc8"),
		"extras": [
			## Rotated past horizontal so they hang rather than point. A cone
			## tipped 150 degrees reads as a drop ear at any distance the game is
			## watched from; the same cone at 14 degrees is a cat.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.075, "height": 0.26,
				"position": Vector3(-0.15, 1.86, 0.02),
				"rotation": Vector3(0.0, 0.0, 152.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.075, "height": 0.26,
				"position": Vector3(0.15, 1.86, 0.02),
				"rotation": Vector3(0.0, 0.0, -152.0), "color": "skin",
			},
			## Longer and lower than Feli's. `PlayerActor3D._mouth_override` reads
			## this by name, so the face draws its mouth onto the muzzle instead of
			## burying it inside.
			{
				"name": "Muzzle", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.095, "height": 0.14,
				"position": Vector3(0.0, 1.74, -0.19), "color": "crown",
			},
			{
				"name": "Tail", "parent": "BodyPivot", "shape": "cylinder",
				"top_radius": 0.035, "bottom_radius": 0.06, "height": 0.62,
				"position": Vector3(0.0, 0.92, 0.28),
				"rotation": Vector3(58.0, 0.0, 0.0), "color": "skin",
			},
		],
	}


## Heavy, low and immovable. Ursi trades acceleration and lateral speed for
## reception stability, attack power and composure, and the silhouette says so
## before the numbers do: the widest torso in the game on the shortest legs, so
## the mass sits low and nothing about it suggests it changes direction quickly.
##
## The limbs are thick rather than long. That matters against Avi, which is the
## other body built around a wall -- Avi makes a wall by being tall and wide with
## nothing to it, Ursi makes one by being dense.
static func _ursi() -> Dictionary:
	return {
		"torso": {"shape": "capsule", "radius": 0.355, "height": 1.02},
		"torso_y": 1.10,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.62, 0.22, 0.42)},
		"shorts_y": 0.60,
		"head": {"shape": "sphere", "radius": 0.20, "height": 0.36},
		"head_y": 1.74,
		"arm": {"top_radius": 0.095, "bottom_radius": 0.105, "height": 0.80},
		"leg": {"top_radius": 0.135, "bottom_radius": 0.10, "height": 0.64},
		"shoe": {"shape": "capsule", "radius": 0.13, "height": 0.30},
		"shoulder": Vector2(0.44, 1.46),
		"hip": Vector2(0.20, 0.46),
		"rig_height": 1.92,
		## Dark enough that the face palette flips to its light ink, which is the
		## check that rule was written for.
		"skin": Color("4a3b34"),
		"crown": Color("d9c9b4"),
		"extras": [
			## Small, round, set high and wide. Ears are the whole reason a bear
			## reads as a bear at silhouette scale.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.075, "height": 0.13,
				"position": Vector3(-0.17, 1.87, 0.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.075, "height": 0.13,
				"position": Vector3(0.17, 1.87, 0.0), "color": "skin",
			},
			{
				"name": "Muzzle", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.105, "height": 0.13,
				"position": Vector3(0.0, 1.68, -0.17), "color": "crown",
			},
		],
	}


## All reach and no weight, and deliberately *not* a person.
##
## The first Simi was a human with long arms, which is the one failure mode this
## body cannot have -- the roster is animals and produce, and the moment one type
## reads as an ordinary human being it becomes the default everyone else is a
## costume of. That is exactly why Homi was retired; drawing it back in under
## another name would undo the same decision twice.
##
## The fix is proportion rather than decoration. The arms are the longest in the
## game and the legs the shortest, so the hands hang near the knees; the shoulders
## are wide and set *low*; and the head is small and sits close to them with
## almost no neck. Nothing about the standing silhouette is upright-human, and
## none of it needs a costume to say so. The flat side-discs went with it -- ears
## in a human's place on a human's head was half the problem.
static func _simi() -> Dictionary:
	return {
		"torso": {"shape": "capsule", "radius": 0.285, "height": 0.76},
		"torso_y": 0.98,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.46, 0.20, 0.32)},
		"shorts_y": 0.56,
		"head": {"shape": "sphere", "radius": 0.145, "height": 0.25},
		"head_y": 1.44,
		"arm": {"top_radius": 0.062, "bottom_radius": 0.08, "height": 1.20},
		"leg": {"top_radius": 0.10, "bottom_radius": 0.072, "height": 0.54},
		"shoe": {"shape": "box", "size": Vector3(0.21, 0.06, 0.32)},
		## Wide and low. A shoulder line below the head's own radius is what
		## makes a body read as hunched without posing it that way.
		"shoulder": Vector2(0.38, 1.26),
		"hip": Vector2(0.13, 0.42),
		"rig_height": 1.66,
		"skin": Color("6f5a4e"),
		"crown": Color("f0d9bd"),
		"extras": [
			## Small, low and set well back, nothing like a human ear's place.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.052, "height": 0.085,
				"position": Vector3(-0.135, 1.42, 0.045), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.052, "height": 0.085,
				"position": Vector3(0.135, 1.42, 0.045), "color": "skin",
			},
			## A heavy brow over a short muzzle. The muzzle is what takes the
			## mouth off the skull -- `_mouth_override` reads it by name -- and a
			## face with its mouth on a snout is not a human face.
			{
				"name": "Brow", "parent": "BodyPivot", "shape": "box",
				"size": Vector3(0.20, 0.05, 0.06),
				"position": Vector3(0.0, 1.505, -0.115),
				"rotation": Vector3(-12.0, 0.0, 0.0), "color": "crown",
			},
			{
				"name": "Muzzle", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.082, "height": 0.10,
				"position": Vector3(0.0, 1.395, -0.125), "color": "crown",
			},
		],
	}
