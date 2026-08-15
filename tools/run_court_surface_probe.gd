extends Node

## Photograph the candidate regional court surfaces on the real court, under the
## real lights.
##
## The first pass at these was drawn flat, in plan, in a browser -- and a plan
## cannot answer the only question that matters about a surface. Gloss, grain and
## roughness are *lighting* phenomena: A'ace's maple is a claim about specular
## response and Bompaçao's slab is a claim about the absence of one, and neither
## exists in an SVG. Concrete drawn flat also read as stripes, which is what
## evenly spaced cracks look like when nothing shades them.
##
## So this loads `MatchCourt3D` itself -- its camera, its key light, its fill,
## its environment -- and swaps only the `CourtSurface` material. What comes back
## is what the match centre would show.
##
## Run:
##   xvfb-run -a godot --path . res://tools/court_surface_probe.tscn

const COURT := preload("res://scenes/components/match_court_3d.tscn")

## Each candidate is albedo, roughness, and a grain description -- the three
## things a `StandardMaterial3D` needs to be a floor rather than a colour.
##
## `grain` is the noise frequency in cycles per metre and how deep it cuts. A
## slab is coarse and shallow; board is fine and directional; new synthetic has
## none at all, which is itself the point of it.
const SURFACES: Array = [
	{
		"id": "landavol", "label": "Landavol - the default",
		"albedo": Color(0.72, 0.40, 0.20), "rough": 0.76, "grain": 0.0, "cut": 0.0,
	},
	{
		"id": "bompacao", "label": "Bompacao - concrete slab",
		"albedo": Color(0.66, 0.64, 0.61), "rough": 0.97, "grain": 26.0, "cut": 0.10,
	},
	{
		"id": "ispayk", "label": "Ispayk - painted concrete, covered",
		"albedo": Color(0.25, 0.49, 0.39), "rough": 0.88, "grain": 18.0, "cut": 0.05,
	},
	{
		"id": "feynt", "label": "Taul ys Feynt - village hall board",
		"albedo": Color(0.79, 0.66, 0.46), "rough": 0.70, "grain": 9.0, "cut": 0.06,
	},
	{
		"id": "aace", "label": "A'ace - new maple, high gloss",
		"albedo": Color(0.88, 0.75, 0.54), "rough": 0.18, "grain": 0.0, "cut": 0.0,
	},
	{
		"id": "rali", "label": "Lo-ong Rali - rough board on earth",
		"albedo": Color(0.49, 0.42, 0.32), "rough": 0.99, "grain": 34.0, "cut": 0.13,
	},
	{
		"id": "taktika", "label": "Taktika - matte synthetic",
		"albedo": Color(0.36, 0.44, 0.47), "rough": 0.62, "grain": 0.0, "cut": 0.0,
	},
]

## Where the match is watched from. Not invented here -- the court scene owns a
## camera and this uses it, because a surface judged from a flattering angle is
## the same mistake as a surface judged in plan.
const SHOT := Vector2i(1280, 720)


func _ready() -> void:
	var root := get_tree().root
	root.content_scale_size = SHOT
	get_window().size = SHOT
	for surface in SURFACES:
		await _shoot(Dictionary(surface))
	get_tree().quit()


func _shoot(surface: Dictionary) -> void:
	var court := COURT.instantiate()
	add_child(court)
	await get_tree().process_frame
	var floor_mesh := court.get_node_or_null("CourtSurface") as MeshInstance3D
	if floor_mesh == null:
		push_error("no CourtSurface under MatchCourt3D")
		return
	floor_mesh.material_override = _material(surface)
	## Two frames: one to apply, one to let the light settle before reading the
	## buffer back. A single frame photographs the previous surface.
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://court_%s.png" % str(surface.get("id", "x"))
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [ProjectSettings.globalize_path(path), surface.get("label", "")])
	court.queue_free()
	await get_tree().process_frame


## Albedo, roughness, and a grain that actually perturbs the normal.
##
## The grain is a *normal* map rather than an albedo tint, which is the whole
## reason for doing this in the engine: a tint is visible from any angle and
## under any light, and a rough surface is not -- it appears when the key light
## rakes it and vanishes when it does not. That difference is what separates a
## slab from a sheet of grey paper, and it is invisible to a drawing.
func _material(surface: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(surface.get("albedo", Color.WHITE))
	material.roughness = float(surface.get("rough", 0.8))
	var grain := float(surface.get("grain", 0.0))
	if grain <= 0.0:
		return material
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	## Frequency is per texel of a 512 map laid over an 18 m court, so this is
	## roughly `grain` cycles per metre -- a number that can be argued about
	## against a real floor instead of tuned until it looks nice.
	noise.frequency = grain / 512.0
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = float(surface.get("cut", 0.08)) * 32.0
	texture.noise = noise
	material.normal_enabled = true
	material.normal_texture = texture
	material.normal_scale = 1.0
	material.uv1_scale = Vector3(4.0, 4.0, 1.0)
	return material
