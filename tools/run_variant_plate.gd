extends Node

## Variants, and the two ways colour could carry a rating.
##
##     xvfb-run -a godot --path . res://tools/variant_plate.tscn
##
## Two questions on one sheet because they interact. A recoloured mark and a
## mark on a coloured disc do not read the same way once the mark itself is
## also flaming or cleaved -- ink that is already saying "this went badly" by
## being broken does not need to say it again in red, and a backdrop behind a
## flaming blade may fight the flames.
const Marks := preload("res://scripts/data/cogniticon_marks.gd")

## The rating scale, as the interface already uses it: S gold, A green, B blue,
## C neutral, D red.
const GRADES := ["S", "A", "B", "C", "D"]


func _ready() -> void:
	await get_tree().process_frame
	for dark in [true, false]:
		await _shoot(dark)
	get_tree().quit()


func _shoot(dark: bool) -> void:
	var stage := Node3D.new()
	add_child(stage)
	var camera := Camera3D.new()
	## Four rows spanning y = +5.5 down to y = -7.9. Framed on that span rather
	## than on the origin -- the first version was centred on zero and cut the
	## commitment row off the bottom of the frame entirely.
	camera.position = Vector3(0.0, -1.2, 20.0)
	camera.fov = 44.0
	stage.add_child(camera)
	var ground := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(64.0, 40.0)
	ground.mesh = quad
	ground.position = Vector3(0.0, -1.2, -1.0)
	var backdrop := StandardMaterial3D.new()
	backdrop.albedo_color = Color("14181a") if dark else Color("f2ede1")
	backdrop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = backdrop
	stage.add_child(ground)
	var ink := Color("dfe7e4") if dark else Color("242a2c")

	var blades: Dictionary = Marks.blade_variant_textures(dark)
	var shields: Dictionary = Marks.shield_variant_textures(dark)

	## Row one: the variants themselves, uncoloured, so their silhouettes can be
	## judged before colour is added to the argument.
	var column := -7.6
	for entry in [
		["approaching|plain", blades, "blade"],
		["approaching|ascendant", blades, "flaming"],
		["approaching|broken", blades, "shattered"],
		["defending|plain", shields, "shield"],
		["defending|ascendant", shields, "shining"],
		["defending|broken", shields, "cleaved"],
	]:
		_mark(stage, (entry[1] as Dictionary)[entry[0]], Vector3(column, 4.4, 0.0),
			0.0105, Color(1, 1, 1, 1))
		_caption(stage, str(entry[2]), Vector3(column, 3.0, 0.0), ink)
		column += 2.9

	## Rows two and three share a stride and a pair gap so the two options are
	## being compared at the same size and spacing rather than at two.
	##
	## The gap started at 1.25 and the discs -- 1.72 across -- overlapped by half
	## a radius, doubling their alpha down the middle. Read off the first plate,
	## that looked exactly like a disc mis-centred behind its mark, which is a
	## defect in the sheet being mistaken for a defect in the idea.
	var stride := 3.3
	var gap := 1.7
	var start := -7.6

	## Row two: colour in the ink.
	column = start
	for grade in GRADES:
		_mark(stage, blades["approaching|plain"], Vector3(column, 1.0, 0.0),
			0.0105, UIPalette.grade_color(grade, not dark))
		_mark(stage, shields["defending|plain"], Vector3(column + gap, 1.0, 0.0),
			0.0105, UIPalette.grade_color(grade, not dark))
		_caption(stage, "ink %s" % grade, Vector3(column + gap * 0.5, -0.4, 0.0), ink)
		column += stride

	## Row three: colour behind the mark, ink left neutral.
	column = start
	for grade in GRADES:
		_disc(stage, Vector3(column, -2.6, -0.02),
			UIPalette.grade_color(grade, not dark))
		_mark(stage, blades["approaching|plain"], Vector3(column, -2.6, 0.0),
			0.0105, Color(1, 1, 1, 1))
		_disc(stage, Vector3(column + gap, -2.6, -0.02),
			UIPalette.grade_color(grade, not dark))
		_mark(stage, shields["defending|plain"], Vector3(column + gap, -2.6, 0.0),
			0.0105, Color(1, 1, 1, 1))
		_caption(stage, "disc %s" % grade, Vector3(column + gap * 0.5, -4.0, 0.0), ink)
		column += stride

	## Row four: commitment forming, then failing.
	column = -7.6
	for step in [0.0, 0.3, 0.6, 1.0]:
		_mark(stage, Marks.commitment(step, false, dark),
			Vector3(column, -6.2, 0.0), 0.0105, Color(1, 1, 1, 1))
		_caption(stage, "%.0f%%" % (step * 100.0), Vector3(column, -7.5, 0.0), ink)
		column += 2.7
	_mark(stage, Marks.commitment(1.0, true, dark), Vector3(column + 0.6, -6.2, 0.0),
		0.0105, UIPalette.grade_color("D", not dark))
	_caption(stage, "broken", Vector3(column + 0.6, -7.5, 0.0), ink)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://variants_%s.png" % ("mikasa" if dark else "molten")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


func _mark(
	stage: Node3D, texture: Texture2D, at: Vector3, size: float, tint: Color
) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = size
	sprite.shaded = false
	sprite.transparent = true
	sprite.modulate = tint
	sprite.position = at
	stage.add_child(sprite)


## The backdrop option: a soft disc the mark sits on.
func _disc(stage: Node3D, at: Vector3, tint: Color) -> void:
	var disc := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.78
	sphere.height = 1.56
	sphere.radial_segments = 32
	## Eight rings, not one. A one-ring sphere is a bicone, and flattened it
	## silhouettes as a *diamond* -- which on this particular sheet collided with
	## the commitment mark and made the backdrop option look like a second glyph.
	sphere.rings = 8
	disc.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = material
	disc.position = at
	disc.scale = Vector3(1.0, 1.0, 0.02)
	stage.add_child(disc)


func _caption(stage: Node3D, text: String, at: Vector3, ink: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0062
	label.modulate = ink
	label.position = at
	stage.add_child(label)
