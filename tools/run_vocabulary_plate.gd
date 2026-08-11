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
const LIDS := [
	{"name": "watching", "upper": 0.16, "lower": 0.0, "shown": true},
	{"name": "narrowed", "upper": 0.74, "lower": 0.34, "shown": true},
	{"name": "doubtful", "upper": 0.36, "lower": 0.0, "shown": true},
	## Shock is the lid **gone**, not the lid moved. A wide eye is one with
	## nothing cutting across it, which is why "completely gone" is a lid state
	## rather than a different drawing.
	{"name": "shocked", "upper": 0.0, "lower": 0.0, "shown": false},
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
	column = -5.0
	for lid in LIDS:
		_eye(stage, parts, lid, Vector3(column, row, 0.0))
		_caption(stage, str(lid["name"]), Vector3(column, row - 1.6, 0.0), ink)
		column += 3.4

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


## The eye, assembled from a fixed socket and a lid that cuts across it.
##
## The socket never changes -- an eye does not change shape. The lid travels
## from just inside the socket's upper edge down toward its centre, and at the
## widest expression is simply not drawn.
func _eye(stage: Node3D, parts: Dictionary, lid: Dictionary, at: Vector3) -> void:
	_mark(stage, parts["socket"], at, 0.011)
	_mark(stage, parts["pupil"], at + Vector3(0.14, 0.0, 0.01), 0.011)
	if not bool(lid["shown"]):
		return
	## The socket's own half-height, in the units these sprites are placed in.
	## The lid rides inside that, never outside it -- a lid drawn past the eye
	## reads as an eyebrow, which is what the first attempt drew.
	var reach: float = Marks.EYE_RADII.y * float(Marks.SCALE) * 0.011
	var upper := Sprite3D.new()
	upper.texture = parts["lid"]
	upper.pixel_size = 0.011
	upper.shaded = false
	upper.transparent = true
	upper.position = at + Vector3(0.0, reach * (1.0 - float(lid["upper"])), 0.02)
	stage.add_child(upper)
	if float(lid["lower"]) <= 0.001:
		return
	var lower := Sprite3D.new()
	lower.texture = parts["lid"]
	lower.pixel_size = 0.011
	lower.shaded = false
	lower.transparent = true
	lower.scale = Vector3(1.0, -1.0, 1.0)
	lower.position = at - Vector3(0.0, reach * (1.0 - float(lid["lower"])), 0.02)
	stage.add_child(lower)
