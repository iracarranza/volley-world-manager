extends Node

## The blade family and its fill, drawn large enough to judge as drawings.
##
##     xvfb-run -a godot --path . res://tools/blade_plate.tscn
##
## The court plate answers "can it be read at playback distance". This answers
## the other question, which has to be settled first: **is the mark the one that
## was designed?** A blade that reads at range and is not the approved drawing is
## still the wrong thing, and that is exactly the error this entry has already
## made three times -- a stand-in mistaken for the design.
##
## So this is flat, close and large: the three blades, and the fill at five
## points across its range including both ends.
const Marks := preload("res://scripts/data/cogniticon_marks.gd")


func _ready() -> void:
	await get_tree().process_frame
	for dark in [true, false]:
		await _shoot(dark)
	get_tree().quit()


func _shoot(dark: bool) -> void:
	var stage := Node3D.new()
	add_child(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, -1.7, 14.5)
	camera.fov = 42.0
	stage.add_child(camera)
	var ground := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(40.0, 26.0)
	ground.mesh = quad
	ground.position = Vector3(0.0, 0.0, -1.0)
	var backdrop := StandardMaterial3D.new()
	backdrop.albedo_color = Color("14181a") if dark else Color("f2ede1")
	backdrop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = backdrop
	stage.add_child(ground)

	var blades: Dictionary = Marks.blade_textures(dark)
	var column := -3.4
	for intent in Marks.BLADE_INTENTS:
		var sprite := Sprite3D.new()
		sprite.texture = blades[intent]
		sprite.pixel_size = 0.012
		sprite.shaded = false
		sprite.transparent = true
		sprite.position = Vector3(column, 1.7, 0.0)
		stage.add_child(sprite)
		var caption := Label3D.new()
		caption.text = str(intent)
		caption.font_size = 44
		caption.pixel_size = 0.0035
		caption.modulate = Color("dfe7e4") if dark else Color("242a2c")
		caption.position = Vector3(column, 0.35, 0.0)
		stage.add_child(caption)
		column += 3.4

	## The fill, across its whole range. Both ends included on purpose: an empty
	## blade and a full one are the two states a viewer will most often see, and
	## a fill tuned only in the middle gets both of them wrong.
	column = -4.4
	for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var region: Rect2 = Marks.fill_region(progress)
		var fill := Sprite3D.new()
		fill.texture = blades["fill"]
		fill.region_enabled = true
		fill.region_rect = region
		fill.offset = Marks.fill_offset(region)
		fill.pixel_size = 0.012
		fill.shaded = false
		fill.transparent = true
		fill.modulate = Color(1.0, 1.0, 1.0, 0.85)
		fill.position = Vector3(column, -1.6, 0.0)
		stage.add_child(fill)
		var outline := Sprite3D.new()
		outline.texture = blades["approaching"]
		outline.pixel_size = 0.012
		outline.shaded = false
		outline.transparent = true
		outline.position = Vector3(column, -1.6, 0.01)
		stage.add_child(outline)
		var caption := Label3D.new()
		caption.text = "%.2f" % progress
		caption.font_size = 40
		caption.pixel_size = 0.0035
		caption.modulate = Color("dfe7e4") if dark else Color("242a2c")
		caption.position = Vector3(column, -2.9, 0.0)
		stage.add_child(caption)
		column += 2.2

	## The eye's parts, assembled at four apertures and with each lead, which is
	## the only way to judge whether a squint still reads and whether the fork
	## says doubt rather than "two arrows".
	var parts: Dictionary = Marks.eye_part_textures(dark)
	var lead_names: Array = Marks.LEAD_MARKS
	column = -5.6
	for index in range(lead_names.size()):
		var aperture: float = [1.0, 0.45, 1.18, 1.55][index]
		_eye(stage, parts, str(lead_names[index]), aperture, Vector3(column, -4.8, 0.0), dark)
		var caption := Label3D.new()
		caption.text = "%s  ap %.2f" % [str(lead_names[index]), aperture]
		caption.font_size = 34
		caption.pixel_size = 0.0035
		caption.modulate = Color("dfe7e4") if dark else Color("242a2c")
		caption.position = Vector3(column, -6.1, 0.0)
		stage.add_child(caption)
		column += 3.7

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://blades_%s.png" % ("mikasa" if dark else "molten")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


## One eye, assembled from its parts the way the billboard will assemble it.
func _eye(
	stage: Node3D, parts: Dictionary, lead: String, aperture: float,
	at: Vector3, dark: bool
) -> void:
	var outline := Sprite3D.new()
	outline.texture = parts["outline"]
	outline.pixel_size = 0.012
	outline.shaded = false
	outline.transparent = true
	outline.scale = Vector3(1.0, aperture, 1.0)
	outline.position = at
	stage.add_child(outline)
	var pupil := Sprite3D.new()
	pupil.texture = parts["pupil"]
	pupil.pixel_size = 0.012
	pupil.shaded = false
	pupil.transparent = true
	## Aimed right, the way the review draws it -- off centre toward the lead.
	pupil.position = at + Vector3(0.36, 0.0, 0.01)
	stage.add_child(pupil)
	var lead_sprite := Sprite3D.new()
	lead_sprite.texture = parts[lead]
	lead_sprite.pixel_size = 0.012
	lead_sprite.shaded = false
	lead_sprite.transparent = true
	lead_sprite.position = at + Vector3(1.42, 0.0, 0.0)
	stage.add_child(lead_sprite)
