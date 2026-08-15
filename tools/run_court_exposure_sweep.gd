extends Node

## Find the exposure at which the court renders the colour it is authored as.
##
## `court_surface` is `#cf8659` in `ui_palette.gd` and reaches the frame at
## `#ffa14f`: the red channel has been clipped for as long as the court has
## existed, so the palette and the pixel have never agreed. Everything downstream
## inherits that -- kit contrast measured against the palette hex is measured
## against a colour the renderer does not produce, and three different pale
## surfaces (concrete, maple, board) all arrive as white because there is no
## headroom left above the terracotta.
##
## This sweeps the two knobs that matter and *measures* rather than eyeballs:
##
##   `tonemap_white`  how far above 1.0 the filmic curve keeps rolling off. The
##                    real fix for clipping -- at 1.0 the curve has nothing left
##                    to compress bright albedos into.
##   `tonemap_exposure` overall stop, for landing the terracotta on its target
##                    once there is headroom to land it in.
##
## Success is two things at once, which is why both test surfaces are here: the
## default court within a few points of `#cf8659`, **and** three pale materials
## still distinguishable from each other. An exposure that fixes the first by
## crushing everything dark fails the second, and that is the failure this
## measures rather than trusts.
##
## Run:
##   xvfb-run -a godot --path . res://tools/court_exposure_sweep.tscn

const COURT := preload("res://scenes/components/match_court_3d.tscn")

## What the court is authored as, from `ui_palette.gd`. The target, not a guess.
const TARGET := Color("cf8659")

## The albedos that have to stay apart. Terracotta first because it is the one
## with a target; the three pale ones exist to prove headroom.
const TEST_ALBEDOS: Array = [
	["default  ", Color(0.72, 0.40, 0.20)],
	["concrete ", Color(0.66, 0.64, 0.61)],
	["maple    ", Color(0.88, 0.75, 0.54)],
	["board    ", Color(0.79, 0.66, 0.46)],
]

## exposure, fill energy.
##
## `tonemap_white` was the first sweep and is **inert**: four values from 1.0 to
## 4.0 produced pixel-identical frames, so the filmic path in this build ignores
## it. A knob that cannot reach its own stated range, measured rather than
## assumed, and the reason it is not in this table.
##
## Fill energy replaces it because the residue is chromatic rather than
## brightness: at every exposure the blue channel lands far under target (55
## against 89) while red clips. The fill is an omni at `(1, 0.79, 0.55)` -- a
## warm light strong enough to be a colour cast, not a fill.
const CONFIGS: Array = [
	[1.00, 5.0], [0.75, 5.0], [0.55, 5.0],
	[1.00, 3.0], [0.85, 3.0], [0.70, 3.0],
	[1.00, 2.0], [0.85, 2.0], [0.70, 2.0],
	[1.00, 1.2], [0.85, 1.2], [0.70, 1.2],
	[1.00, 0.6], [0.85, 0.6],
]

## Where the court fills the frame, taken off a rendered shot rather than
## computed -- a patch chosen from the geometry can land on a line.
const PATCH := Vector2i(380, 560)
const PATCH_RADIUS := 14


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var court := COURT.instantiate()
	add_child(court)
	await get_tree().process_frame
	var floor_mesh := court.get_node_or_null("CourtSurface") as MeshInstance3D
	var env_holder := court.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var fill := court.get_node_or_null("FillLight") as OmniLight3D
	if floor_mesh == null or env_holder == null or fill == null:
		push_error("court is missing CourtSurface or WorldEnvironment")
		get_tree().quit()
		return
	print("target for default: #%s" % TARGET.to_html(false))
	print("expo fill  | " + " | ".join(TEST_ALBEDOS.map(func(a): return str(a[0]))) + " | dE default")
	for config in CONFIGS:
		var exposure := float(config[0])
		var white := float(config[1])  ## fill energy, see CONFIGS
		env_holder.environment.tonemap_exposure = exposure
		fill.light_energy = white
		var row := "%.2f %.1f  " % [exposure, white]
		var error := 0.0
		for entry in TEST_ALBEDOS:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.roughness = 0.76
			floor_mesh.material_override = material
			await get_tree().process_frame
			await get_tree().process_frame
			var seen := _sample()
			row += "| #%s " % seen.to_html(false)
			if str(entry[0]).begins_with("default"):
				error = _distance(seen, TARGET)
		print("%s| %.1f" % [row, error])
	get_tree().quit()


## Average a patch, so one antialiased pixel does not decide an exposure.
func _sample() -> Color:
	var image := get_tree().root.get_texture().get_image()
	var total := Vector3.ZERO
	var count := 0
	for y in range(PATCH.y - PATCH_RADIUS, PATCH.y + PATCH_RADIUS):
		for x in range(PATCH.x - PATCH_RADIUS, PATCH.x + PATCH_RADIUS):
			var pixel := image.get_pixel(x, y)
			total += Vector3(pixel.r, pixel.g, pixel.b)
			count += 1
	total /= maxf(float(count), 1.0)
	return Color(total.x, total.y, total.z)


## Plain RGB distance in 0-255. Not perceptual, and it does not need to be: this
## is asking whether a number was hit, not how wrong it looks.
func _distance(seen: Color, want: Color) -> float:
	return Vector3(
		(seen.r - want.r) * 255.0, (seen.g - want.g) * 255.0, (seen.b - want.b) * 255.0
	).length()
