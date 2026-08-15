extends Node

## Photograph the eight major venues as *rooms*, not as floors.
##
## The surface pass asked what a court is made of. These ask what it is like to
## play in, and almost none of it is the floor: altitude, mist, glare off a
## pillar, a resonance at the end line, a wall of sponsor screens. Those are
## light, atmosphere and a little geometry, which is why this probe exists
## separately from `court_surface_probe` rather than growing another column.
##
## **Purely visual.** Each venue below is a *look* for a modifier that is not
## designed yet and is not designed here. What this can settle is narrow and
## worth settling first: whether a venue reads as itself in one frame, from the
## camera a match is actually watched from, without a label.
##
## It depends on the exposure fix. At the old stop the floor was already clipping,
## so a deliberate glare and an accidental blow-out were the same pixels and
## Blôc's whole idea was unphotographable. 0.42 is the headroom these live in.
##
## Run:
##   xvfb-run -a godot --path . res://tools/venue_probe.tscn

const COURT := preload("res://scenes/components/match_court_3d.tscn")

## Court metrics, taken from the court scene rather than restated: the net is at
## the origin, the posts sit at ±4.72, and the floor is 18 x 9.
const HALF_LENGTH := 9.0
const HALF_WIDTH := 4.5
const POST_X := 4.72

var _court: Node3D
var _env: Environment
var _key: DirectionalLight3D
var _fill: OmniLight3D
var _extras: Node3D


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for venue in _venues():
		await _shoot(Dictionary(venue))
	get_tree().quit()


## Eight rooms. Each entry is a light change, an atmosphere change, and a hook
## that adds whatever geometry the idea needs.
func _venues() -> Array:
	return [
		{
			"id": "landavol", "label": "Landavol - the reference room",
			"build": func(): pass,
		},
		{
			"id": "pawa", "label": "Pawa Hito - altitude, thin hard light",
			## Thin air scatters less, so the light is harder and the shadows are
			## blacker rather than the room being brighter. Height is drawn by what
			## the light does, not by a mountain in the background.
			"build": func():
				_key.rotation_degrees = Vector3(-66.0, -48.0, 0.0)
				_key.light_energy = 2.6
				_key.light_color = Color(1.0, 0.99, 0.95)
				_fill.light_energy = 0.8
				_env.ambient_light_color = Color(0.30, 0.42, 0.62)
				_env.ambient_light_energy = 0.22
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.62, 0.70, 0.80)
				_env.fog_density = 0.004
				_env.fog_sky_affect = 0.0,
		},
		{
			"id": "speddigh", "label": "Speddigh - cold ectoplasmic mist",
			## The mist is the room. Dense, cold, and sitting low so a voli standing
			## still is in it to the knee while the ball above is clear.
			"build": func():
				_key.light_energy = 0.75
				_key.light_color = Color(0.78, 0.88, 1.0)
				_fill.light_color = Color(0.70, 0.85, 1.0)
				_fill.light_energy = 2.0
				_env.ambient_light_color = Color(0.55, 0.68, 0.80)
				_env.ambient_light_energy = 0.95
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.74, 0.86, 0.94)
				_env.fog_density = 0.006
				_env.fog_sky_affect = 0.0
				for layer in range(3):
					var sheet := _box(
						Vector3(26.0, 0.02, 16.0),
						Vector3(0.0, 0.28 + float(layer) * 0.30, 0.0),
						Color(0.80, 0.90, 0.98, 0.16), 0.0, 1.0
					)
					sheet.name = "Mist%d" % layer
					var material := sheet.material_override as StandardMaterial3D
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color = Color(0.80, 0.90, 0.98, 0.16)
					material.emission_enabled = true
					material.emission = Color(0.62, 0.76, 0.88)
					material.emission_energy_multiplier = 0.30,
		},
		{
			"id": "bloc", "label": "Bloc du Larg - sun and gleaming pillars",
			## The one that needed the exposure fix. A low sun rakes across the net
			## and four polished pillars sit behind it, so the block is read against
			## bright metal rather than against a dark hall.
			"build": func():
				_key.rotation_degrees = Vector3(-14.0, -86.0, 0.0)
				_key.light_energy = 2.4
				_key.light_color = Color(1.0, 0.96, 0.84)
				_env.ambient_light_energy = 0.55
				_env.glow_enabled = true
				_env.glow_intensity = 1.6
				_env.glow_bloom = 0.55
				for i in range(4):
					var pillar := _box(
						Vector3(0.42, 7.0, 0.42),
						Vector3(-6.0 + float(i) * 4.0, 3.5, -6.6),
						Color(0.94, 0.92, 0.86), 0.92, 0.10, 0.55
					)
					pillar.name = "Pillar%d" % i,
		},
		{
			"id": "xervu", "label": "Xervu - the end line answers the serve",
			## The architecture responds at the end line, so the light lives *there*
			## rather than over the net: two warm bands under the serving zones and
			## a resonance ring on the floor behind each.
			"build": func():
				_env.ambient_light_energy = 0.42
				_env.glow_enabled = true
				_env.glow_intensity = 0.9
				for side in [-1.0, 1.0]:
					var band := _box(
						Vector3(9.4, 0.02, 0.5),
						Vector3(0.0, 0.02, side * (HALF_LENGTH + 0.9)),
						Color(1.0, 0.72, 0.26), 0.0, 1.0, 2.6
					)
					band.name = "Resonance%d" % int(side)
					for ring in range(3):
						var arc := _box(
							Vector3(6.0 - float(ring) * 1.6, 0.02, 0.10),
							Vector3(0.0, 0.02, side * (HALF_LENGTH + 1.9 + float(ring) * 0.75)),
							Color(1.0, 0.62, 0.20), 0.0, 1.0, 1.4 - float(ring) * 0.35
						)
						arc.name = "Ring%d_%d" % [int(side), ring],
		},
		{
			"id": "taktika", "label": "Taktika - the room that is watching",
			## Flat, even, shadowless: nothing here should feel like weather. The
			## only mark is a fine grid on the floor, which is the room treating the
			## court as a diagram.
			"build": func():
				_key.light_energy = 0.9
				_key.light_color = Color(0.94, 0.97, 1.0)
				_fill.light_energy = 1.0
				_env.ambient_light_color = Color(0.70, 0.76, 0.80)
				_env.ambient_light_energy = 1.05
				for i in range(-4, 5):
					var line := _box(
						Vector3(0.03, 0.02, HALF_LENGTH * 2.0),
						Vector3(float(i) * 1.0, 0.012, 0.0),
						Color(0.80, 0.86, 0.88), 0.0, 1.0, 0.25
					)
					line.name = "Grid%d" % i,
		},
		{
			"id": "aace", "label": "A'ace - sponsors and bettors, watching",
			## A wall of screens on both sides and a ring of cold light above. The
			## room is instrumented, and the volis are the instrument.
			"build": func():
				_env.ambient_light_color = Color(0.62, 0.68, 0.82)
				_env.ambient_light_energy = 0.6
				_env.glow_enabled = true
				_env.glow_intensity = 1.3
				var tints := [
					Color(0.20, 0.85, 0.95), Color(0.95, 0.30, 0.55),
					Color(0.30, 0.95, 0.55), Color(0.98, 0.78, 0.20),
				]
				for i in range(4):
					var screen := _box(
						Vector3(3.6, 1.5, 0.10),
						Vector3(-6.6 + float(i) * 4.4, 3.2, -(HALF_WIDTH + 3.4)),
						Color(tints[i]), 0.0, 1.0, 2.1
					)
					screen.name = "Screen%d" % i
				for end in [-1.0, 1.0]:
					var board := _box(
						Vector3(0.10, 1.3, 5.2),
						Vector3(end * (HALF_LENGTH + 2.6), 2.6, -1.2),
						Color(tints[int(end) + 1]), 0.0, 1.0, 1.8
					)
					board.name = "Board%d" % int(end),
		},
		{
			"id": "ispayk", "label": "Ispayk - hallowed, and past it",
			## Grand and dim. High warm light from far above, banners down the long
			## walls, and nothing new in the room -- the pride and the poverty being
			## the same fact, which is how `GEOGRAPHY.md` already puts it.
			"build": func():
				_key.rotation_degrees = Vector3(-78.0, -20.0, 0.0)
				_key.light_energy = 1.0
				_key.light_color = Color(1.0, 0.90, 0.72)
				_fill.light_color = Color(1.0, 0.82, 0.58)
				_fill.light_energy = 3.0
				_env.ambient_light_color = Color(0.42, 0.36, 0.30)
				_env.ambient_light_energy = 0.5
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.52, 0.44, 0.34)
				_env.fog_density = 0.012
				_env.fog_sky_affect = 0.0
				for i in range(5):
					var banner := _box(
						Vector3(1.2, 3.8, 0.06),
						Vector3(-7.0 + float(i) * 3.5, 5.0, -(HALF_WIDTH + 2.4)),
						Color(0.55, 0.20, 0.18), 0.0, 0.9, 0.30
					)
					banner.name = "Banner%d" % i,
		},
	]


func _shoot(venue: Dictionary) -> void:
	_court = COURT.instantiate()
	add_child(_court)
	await get_tree().process_frame
	_key = _court.get_node("KeyLight") as DirectionalLight3D
	_fill = _court.get_node("FillLight") as OmniLight3D
	## The environment is a shared sub-resource, so it must be duplicated or every
	## venue after the first inherits the one before it -- which is exactly the
	## bug that made the first run of this look like a single foggy room eight
	## times.
	var holder := _court.get_node("WorldEnvironment") as WorldEnvironment
	_env = holder.environment.duplicate() as Environment
	holder.environment = _env
	_extras = Node3D.new()
	_extras.name = "VenueExtras"
	_court.add_child(_extras)
	var build: Callable = venue.get("build", func(): pass)
	build.call()
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://venue_%s.png" % str(venue.get("id", "x"))
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [ProjectSettings.globalize_path(path), venue.get("label", "")])
	_court.queue_free()
	await get_tree().process_frame


## One emissive or plain box, parented under the venue's own node so it goes away
## with the court.
func _box(
	size: Vector3, at: Vector3, colour: Color,
	metallic: float = 0.0, roughness: float = 0.9, emission: float = 0.0
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	node.material_override = material
	_extras.add_child(node)
	return node
