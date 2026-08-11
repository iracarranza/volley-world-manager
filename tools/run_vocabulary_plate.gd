extends Node

## The whole cogniticon vocabulary on one sheet.
##
##     xvfb-run -a godot --path . res://tools/vocabulary_plate.tscn
##
## Four shields, three blades, two hands, and the eye at four lid positions.
## One sheet because the families only have to differ *from each other*: a
## shield and a blade being distinguishable is the entire premise of dropping
## the family hues, and that claim cannot be checked one mark at a time.
const Marks := preload("res://scripts/data/cogniticon_marks.gd")

## Lid positions, as the fraction of its travel each lid has closed. These are
## the four expressions the design names, and the point of the plate is whether
## they are four *different faces* rather than four numbers.
## Six apertures across the range, so the *progression* can be judged rather
## than three chosen poses. The lid is the eye's top border, so each of these
## is a different eye rather than the same eye with something laid over it.
const APERTURES := [
	{"name": "closing", "openness": 0.34},
	{"name": "narrowed", "openness": 0.58},
	{"name": "wary", "openness": 0.82},
	{"name": "watching", "openness": 1.0},
	{"name": "widening", "openness": 1.3},
	{"name": "shocked", "openness": 1.62},
]


func _ready() -> void:
	await get_tree().process_frame
	for dark in [true, false]:
		await _shoot(dark)
	get_tree().quit()


func _shoot(dark: bool) -> void:
	var stage := Node3D.new()
	add_child(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 15.0)
	camera.fov = 44.0
	stage.add_child(camera)
	var ground := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(46.0, 30.0)
	ground.mesh = quad
	ground.position = Vector3(0.0, 0.0, -1.0)
	var backdrop := StandardMaterial3D.new()
	backdrop.albedo_color = Color("14181a") if dark else Color("f2ede1")
	backdrop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = backdrop
	stage.add_child(ground)
	var ink := Color("dfe7e4") if dark else Color("242a2c")

	var shields: Dictionary = Marks.shield_textures(dark)
	var blades: Dictionary = Marks.blade_textures(dark)
	var hands: Dictionary = Marks.hand_textures(dark)
	var row := 3.1
	var column := -5.4
	for intent in Marks.SHIELD_INTENTS:
		_mark(stage, shields[intent], Vector3(column, row, 0.0), 0.011)
		_caption(stage, intent, Vector3(column, row - 1.5, 0.0), ink)
		column += 3.0
	row = 0.2
	column = -5.4
	for intent in Marks.BLADE_INTENTS:
		_mark(stage, blades[intent], Vector3(column, row, 0.0), 0.011)
		_caption(stage, intent, Vector3(column, row - 1.5, 0.0), ink)
		column += 3.0
	for intent in Marks.HAND_INTENTS:
		_mark(stage, hands[intent], Vector3(column, row, 0.0), 0.011)
		_caption(stage, intent, Vector3(column, row - 1.5, 0.0), ink)
		column += 3.0

	var parts: Dictionary = Marks.eye_part_textures(dark)
	row = -3.2
	column = -6.4
	for lid in APERTURES:
		_eye(stage, parts, lid, Vector3(column, row, 0.0))
		_caption(stage, str(lid["name"]), Vector3(column, row - 1.6, 0.0), ink)
		column += 2.6

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://vocabulary_%s.png" % ("mikasa" if dark else "molten")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


func _mark(stage: Node3D, texture: Texture2D, at: Vector3, size: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = size
	sprite.shaded = false
	sprite.transparent = true
	sprite.position = at
	stage.add_child(sprite)


func _caption(stage: Node3D, text: String, at: Vector3, ink: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = 0.0038
	label.modulate = ink
	label.position = at
	stage.add_child(label)


## One eye at one openness. Its whole shape comes from where the lids are.
func _eye(stage: Node3D, parts: Dictionary, lid: Dictionary, at: Vector3) -> void:
	var step: int = Marks.aperture_step(float(lid["openness"]))
	_mark(stage, parts["eye_%d" % step], at, 0.011)
	_mark(stage, parts["pupil"], at + Vector3(0.13, 0.0, 0.01), 0.011)
