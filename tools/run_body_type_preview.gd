extends Node

## Line the body types up and photograph them.
##
## A silhouette is a claim about what reads at a glance, and that claim can only
## be checked by looking. Renders all six modelled types plus every canonical
## Vegi shape at a matched height, so what differs is shape rather than scale.
##
## Run:
##   xvfb-run -a godot --path . res://tools/body_type_preview.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

## Body type and, for a Vegi, which produce. Named rather than given ids: the id
## that grows a pumpkin is a property of the hash, not something worth
## hand-maintaining here.
const SUBJECTS: Array = [
	["Feli", ""], ["Avi", ""], ["Cani", ""], ["Ursi", ""], ["Simi", ""],
	["Vegi", "Tomato"], ["Vegi", "Aubergine"], ["Vegi", "Pear"],
	["Vegi", "Stalk"], ["Vegi", "Pepper"],
]

## This is a body-type catalog, so every subject uses the same neutral stance.
const POSES: Array = [
	["stand", -1, 0.0],
]

const COLUMNS := 5
const CELL_WIDTH := 256.0
const CELL_HEIGHT := 330.0

var _subjects: Array = []


func _ready() -> void:
	## Resolved into a local array because `SUBJECTS` is a const, and a const
	## collection is read-only in Godot 4 -- writing a resolved id back into it
	## raises an error per attempt instead of storing anything.
	for index in range(SUBJECTS.size()):
		var entry: Array = SUBJECTS[index]
		var wanted := str(entry[1])
		var subject := {"type": str(entry[0]), "produce": wanted, "id": index + 1}
		if not wanted.is_empty():
			## Search for an id that hashes to this produce, so the preview runs
			## through the same deterministic selection a match does rather than
			## bypassing it.
			for candidate in range(1, 6000):
				if BodyTypeModelsScript.produce_for(candidate) == wanted:
					subject["id"] = candidate
					break
		_subjects.append(subject)
	await get_tree().process_frame
	for pose in POSES:
		await _shoot(pose)
	get_tree().quit()


func _shoot(pose: Array) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

	## Lit from the side the camera is on. This tool spent its whole life
	## photographing the backs of their heads -- the rig faces -Z and the camera
	## sat on +Z -- which was survivable while the subject was a silhouette and is
	## not once the subject is what the arms are doing.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 152.0, 0.0)
	light.light_energy = 1.3
	stage.add_child(light)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce4ec")
	env.ambient_light_energy = 1.15
	environment.environment = env
	stage.add_child(environment)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 3.05, -10.0)
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	camera.size = 6.5
	stage.add_child(camera)

	_add_catalog_overlay(stage)
	var column_spacing := 2.31
	var row_spacing := 3.0
	for index in range(_subjects.size()):
		var subject: Dictionary = _subjects[index]
		var label := _subject_label(subject)
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			int(subject.id), index % 2 == 0, label, "Right",
			{
				"height_cm": 188.0, "wingspan_cm": 191.0,
				"body_type": str(subject.type),
			},
		)
		var column := index % COLUMNS
		var row := index / COLUMNS
		actor.set_tactical_position(
			Vector2.ZERO,
			Vector3(
				-column_spacing * float(column - 2),
				0.8 + row_spacing * float(1 - row),
				0.0,
			),
		)
		actor.identity_label.visible = false
		actor.set_pose(
			int(pose[1]), float(pose[2]), 0.5, Vector2.ZERO, int(pose[1]) >= 0
		)
		actor.set_highlighted(false)

	for _frame in range(8):
		await get_tree().process_frame
	var output_dir := "res://artifacts/voli-body-types"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var path := "%s/voli_body_types_%s.png" % [output_dir, str(pose[0])]
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


func _subject_label(subject: Dictionary) -> String:
	if str(subject.produce).is_empty():
		return str(subject.type)
	return "%s · %s" % [str(subject.type), str(subject.produce)]


func _add_catalog_overlay(stage: Node) -> void:
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var sheet := Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sheet)
	for index in range(_subjects.size()):
		var column := index % COLUMNS
		var row := index / COLUMNS
		var panel := Panel.new()
		panel.position = Vector2(float(column) * CELL_WIDTH + 5.0, float(row) * CELL_HEIGHT + 24.0)
		panel.size = Vector2(CELL_WIDTH - 10.0, CELL_HEIGHT - 10.0)
		var border := StyleBoxFlat.new()
		border.bg_color = Color(1.0, 1.0, 1.0, 0.0)
		border.border_color = Color("26384a")
		border.set_border_width_all(2)
		border.corner_radius_top_left = 10
		border.corner_radius_top_right = 10
		border.corner_radius_bottom_left = 10
		border.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", border)
		sheet.add_child(panel)

		var caption := Label.new()
		caption.text = _subject_label(_subjects[index])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.position = Vector2(8.0, panel.size.y - 45.0)
		caption.size = Vector2(panel.size.x - 16.0, 36.0)
		caption.add_theme_color_override("font_color", Color("172534"))
		caption.add_theme_font_size_override("font_size", 20)
		panel.add_child(caption)
