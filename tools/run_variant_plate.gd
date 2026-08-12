extends Node

## Variants, and the backdrop that carries both the rating and the success.
##
##     xvfb-run -a godot --path . res://tools/variant_plate.tscn
##
## Two questions turned out to be one. A rating colour needs somewhere to sit
## that is not the ink, and succeeding needed a treatment that was not another
## set of paths per family. Both are answered behind the mark: a disc for an
## ordinary contact, a flare for one that came off.
##
## Drawn on one sheet because they interact -- a mark that is already coming
## apart does not need a loud silhouette behind it saying the same word, which is
## why `broken` keeps the disc.
const Marks := preload("res://scripts/data/cogniticon_marks.gd")

## The rating scale, as the interface already uses it: S gold, A green, B blue,
## C neutral, D red.
const GRADES := ["S", "A", "B", "C", "D"]

var _backdrops: Dictionary = {}


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
	_backdrops = Marks.backdrop_textures()

	## Row one: the marks and their breaks, with no backdrop at all, so the
	## fractures can be judged as drawings before colour joins the argument.
	var column := -7.6
	for entry in [
		["approaching|plain", blades, "blade", "approaching"],
		["approaching|broken", blades, "shattered", "approaching"],
		["defending|plain", shields, "shield", "defending"],
		["defending|broken", shields, "fractured", "defending"],
		["blocking|plain", shields, "wall", "blocking"],
		["blocking|broken", shields, "breached", "blocking"],
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

	## Row two: the disc, across the whole rating scale. Sized per family, which
	## is what the extent probe's 64% spread bought.
	column = start
	for grade in GRADES:
		_seat(stage, blades["approaching|plain"], "approaching", "plain",
			Vector3(column, 1.0, 0.0), UIPalette.grade_color(grade, not dark))
		_seat(stage, shields["defending|plain"], "defending", "plain",
			Vector3(column + gap, 1.0, 0.0), UIPalette.grade_color(grade, not dark))
		_caption(stage, "disc %s" % grade, Vector3(column + gap * 0.5, -0.4, 0.0), ink)
		column += stride

	## Row three: the flare. Same marks, same grades, loud ground -- so what a
	## rally that came off looks like beside one that merely happened.
	column = start
	for grade in GRADES:
		_seat(stage, blades["approaching|ascendant"], "approaching", "ascendant",
			Vector3(column, -2.6, 0.0), UIPalette.grade_color(grade, not dark))
		_seat(stage, shields["defending|ascendant"], "defending", "ascendant",
			Vector3(column + gap, -2.6, 0.0), UIPalette.grade_color(grade, not dark))
		_caption(stage, "flare %s" % grade, Vector3(column + gap * 0.5, -4.0, 0.0), ink)
		column += stride

	## Row four: commitment forming, then failing -- and the two breaks seated on
	## a D disc, which is how a failure actually reaches the court.
	column = -7.6
	for step in [0.0, 0.3, 0.6, 1.0]:
		_mark(stage, Marks.commitment(step, false, dark),
			Vector3(column, -6.2, 0.0), 0.0105, Color(1, 1, 1, 1))
		_caption(stage, "%.0f%%" % (step * 100.0), Vector3(column, -7.5, 0.0), ink)
		column += 2.7
	var failed := UIPalette.grade_color("D", not dark)
	_seat(stage, Marks.commitment(1.0, true, dark), "commitment", "broken",
		Vector3(column, -6.2, 0.0), failed)
	_caption(stage, "broken", Vector3(column, -7.5, 0.0), ink)
	column += 2.7
	_seat(stage, blades["approaching|broken"], "approaching", "broken",
		Vector3(column, -6.2, 0.0), failed)
	_caption(stage, "blade D", Vector3(column, -7.5, 0.0), ink)
	column += 2.7
	_seat(stage, shields["defending|broken"], "defending", "broken",
		Vector3(column, -6.2, 0.0), failed)
	_caption(stage, "shield D", Vector3(column, -7.5, 0.0), ink)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://variants_%s.png" % ("mikasa" if dark else "molten")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


## A mark on its backdrop, at the size that mark's family asks for.
func _seat(
	stage: Node3D, texture: Texture2D, intent: String, variant: String,
	at: Vector3, tint: Color
) -> void:
	var size := 0.0105
	var behind := Sprite3D.new()
	behind.texture = _backdrops[variant]
	behind.pixel_size = size * Marks.backdrop_scale(intent)
	behind.shaded = false
	behind.transparent = true
	behind.modulate = Color(tint.r, tint.g, tint.b, 0.62)
	behind.position = at + Vector3(0.0, 0.0, -0.02)
	stage.add_child(behind)
	_mark(stage, texture, at, size, Color(1, 1, 1, 1))


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


func _caption(stage: Node3D, text: String, at: Vector3, ink: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.0062
	label.modulate = ink
	label.position = at
	stage.add_child(label)
