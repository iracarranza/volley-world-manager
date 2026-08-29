extends SceneTree
## Render-only design study for the production Voli face system.
##
## This deliberately instantiates the actual PlayerActor3D scene and feeds it the
## actual FaceExpressions grid. The only experimental step happens afterwards:
## the same generated face feature nodes are given alternate primitive geometry.
## Nothing here is referenced by production scenes.

const PLAYER := preload("res://scenes/components/player_actor_3d.tscn")
const FACE := preload("res://scripts/data/face_expressions.gd")

const OUTPUT_DIR := "res://artifacts/voli-face-comparison"
const CANVAS := Vector2i(1920, 1080)
const BG := Color("171b20")
const PANEL := Color("23282f")
const PANEL_ALT := Color("2a3038")
const INK := Color("f0eadc")
const MUTED := Color("aaa69c")
const ACCENT := Color("8da8b8")

const EYE_ORDER: Array[String] = ["full", "half", "flat"]
const MOUTH_ORDER: Array[String] = ["smile", "flat", "frown"]
const VARIANTS: Array[Dictionary] = [
	{"key": "canonical", "title": "CANONICAL", "note": "production box solids"},
	{"key": "bold", "title": "BOLD BLOCKS", "note": "same solids, heavier read"},
	{"key": "rounded", "title": "ROUNDED", "note": "ellipsoid feature solids"},
	{"key": "disc", "title": "SHALLOW DISCS", "note": "round plates close to surface"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CANVAS
	RenderingServer.set_default_clear_color(BG)

	var canonical := _build_canonical_sheet()
	root.add_child(canonical)
	for _i in 18:
		await process_frame
	_save("canonical_3x3.png")
	canonical.queue_free()
	for _i in 3:
		await process_frame

	var comparison := _build_comparison_sheet()
	root.add_child(comparison)
	for _i in 18:
		await process_frame
	_save("construction_comparison.png")
	comparison.queue_free()
	for _i in 2:
		await process_frame
	quit()


func _save(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not write %s: %s" % [path, error_string(error)])
	else:
		print("VOLI_FACE_RENDER ", path)


func _base_sheet(title: String, subtitle: String) -> Control:
	var sheet := Control.new()
	sheet.size = Vector2(CANVAS)
	var background := ColorRect.new()
	background.color = BG
	background.size = sheet.size
	sheet.add_child(background)
	_add_label(sheet, title, Vector2(48, 28), Vector2(1824, 44), 32, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(sheet, subtitle, Vector2(48, 74), Vector2(1824, 30), 17, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	return sheet


## The source matrix itself: eye state down the page, mouth state across it.
## This is the high-resolution truth plate before any construction alternatives.
func _build_canonical_sheet() -> Control:
	var sheet := _base_sheet(
		"Voli face grammar · production Godot render",
		"Actual PlayerActor3D · fixed Vegi / Tomato · FaceExpressions.GRID · no reconstructed character art"
	)
	var left := 252.0
	var top := 196.0
	var cell := Vector2(470, 248)
	var gap := Vector2(22, 24)

	_add_label(sheet, "EYES ↓", Vector2(52, 132), Vector2(170, 34), 15, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	for column in MOUTH_ORDER.size():
		var x := left + float(column) * (cell.x + gap.x)
		_add_label(sheet, MOUTH_ORDER[column].to_upper(), Vector2(x, 132), Vector2(cell.x, 42), 20, INK)
	for row in EYE_ORDER.size():
		var y := top + float(row) * (cell.y + gap.y)
		_add_label(sheet, EYE_ORDER[row].to_upper(), Vector2(52, y + 88), Vector2(160, 42), 20, INK, HORIZONTAL_ALIGNMENT_LEFT)
		for column in MOUTH_ORDER.size():
			var expression := str(FACE.GRID[EYE_ORDER[row]][MOUTH_ORDER[column]])
			var x := left + float(column) * (cell.x + gap.x)
			_add_portrait_card(sheet, Vector2(x, y), cell, expression, "canonical", true)
	return sheet


## Four construction systems under identical body, camera, light, expression and
## palette. Columns stay in the source 3x3 order rather than alphabetical order,
## so neighbouring faces differ by one component exactly as FaceExpressions does.
func _build_comparison_sheet() -> Control:
	var sheet := _base_sheet(
		"Voli face construction study · Godot",
		"Only facial primitive construction changes. Body, expression grammar, camera, palette and lighting are held fixed."
	)
	var expressions := _expression_order()
	var left := 250.0
	var top := 190.0
	var cell := Vector2(170, 178)
	var x_gap := 10.0
	var y_gap := 28.0

	for column in expressions.size():
		var x := left + float(column) * (cell.x + x_gap)
		var components: Array[String] = FACE.components(expressions[column])
		_add_label(sheet, expressions[column].to_upper(), Vector2(x, 122), Vector2(cell.x, 28), 14, INK)
		_add_label(
			sheet,
			"%s + %s" % [components[0], components[1]],
			Vector2(x, 150), Vector2(cell.x, 22), 11, MUTED
		)

	for row in VARIANTS.size():
		var y := top + float(row) * (cell.y + y_gap)
		var variant: Dictionary = VARIANTS[row]
		_add_label(sheet, str(variant.title), Vector2(48, y + 46), Vector2(180, 28), 16, INK, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(sheet, str(variant.note), Vector2(48, y + 76), Vector2(180, 44), 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		for column in expressions.size():
			var x := left + float(column) * (cell.x + x_gap)
			_add_portrait_card(
				sheet, Vector2(x, y), cell, expressions[column], str(variant.key), false
			)
	return sheet


func _expression_order() -> Array[String]:
	var result: Array[String] = []
	for eye_state in EYE_ORDER:
		for mouth_shape in MOUTH_ORDER:
			result.append(str(FACE.GRID[eye_state][mouth_shape]))
	return result


func _add_portrait_card(
	parent: Control, at: Vector2, size: Vector2,
	expression: String, variant: String, show_expression: bool
) -> void:
	var frame := ColorRect.new()
	frame.position = at
	frame.size = size
	frame.color = PANEL_ALT if variant == "canonical" else PANEL
	parent.add_child(frame)

	var inset := 8.0
	var caption_h := 34.0 if show_expression else 0.0
	var viewport_size := Vector2i(
		int(size.x - inset * 2.0), int(size.y - inset * 2.0 - caption_h)
	)
	var container := SubViewportContainer.new()
	container.position = at + Vector2(inset, inset)
	container.size = Vector2(viewport_size)
	container.stretch = true
	parent.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	container.add_child(viewport)
	_build_portrait_world(viewport, expression, variant)

	if show_expression:
		_add_label(
			parent, expression.to_upper(),
			at + Vector2(8, size.y - 38), Vector2(size.x - 16, 30),
			16, INK
		)


func _build_portrait_world(viewport: SubViewport, expression: String, variant: String) -> void:
	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("30363d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f0e8dc")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color("fff1dd")
	key.light_energy = 0.72
	key.rotation_degrees = Vector3(-28.0, -24.0, 0.0)
	key.shadow_enabled = false
	stage.add_child(key)

	var actor := PLAYER.instantiate()
	stage.add_child(actor)
	actor.configure(
		91027, true, "Voli", "Right",
		{
			"body_type": "Vegi",
			"height_cm": 188.0,
			"wingspan_cm": 191.0,
			"stride_length_m": 0.83,
			"expression": expression,
			"appearance": {
				"produce": "Tomato",
				"palette_index": 0,
				"marking": "none",
			},
		}
	)
	actor.shadow.visible = false
	actor.focus_ring.visible = false
	actor.identity_label.visible = false
	_apply_face_variant(actor, variant)

	var head := actor.get_node("BodyPivot/Head") as Node3D
	var target_y := head.global_position.y - 0.015
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.62
	camera.near = 0.05
	camera.far = 10.0
	stage.add_child(camera)
	camera.look_at_from_position(
		Vector3(0.0, target_y, -2.5),
		Vector3(0.0, target_y, 0.0),
		Vector3.UP
	)
	camera.current = true


## Every option begins with the production face nodes generated by
## PlayerActor3D._build_face(). This function changes only their primitive shape
## or weight, then points each existing ink hull at the replacement mesh.
func _apply_face_variant(actor: Node, variant: String) -> void:
	if variant == "canonical":
		return
	var face := actor.get_node_or_null("BodyPivot/Head/Face") as Node3D
	if face == null:
		return
	for child in face.get_children():
		var feature := child as MeshInstance3D
		if feature == null or feature.mesh == null:
			continue
		var feature_name := str(feature.name)
		var is_eye := feature_name.begins_with("Eye")
		var size := feature.mesh.get_aabb().size
		match variant:
			"bold":
				feature.scale = Vector3(1.14, 1.30, 1.18) if is_eye \
					else Vector3(1.14, 1.42, 1.18)
			"rounded":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 12
				sphere.rings = 6
				feature.mesh = sphere
				feature.scale = Vector3(size.x, size.y, size.z)
			"disc":
				var disc := CylinderMesh.new()
				disc.top_radius = 0.5
				disc.bottom_radius = 0.5
				disc.height = 1.0
				disc.radial_segments = 12
				var prior_z := feature.rotation_degrees.z
				feature.mesh = disc
				## Cylinder axis is Y. Rotate it onto the facial plane and map the
				## old box's xyz extents to face-x, depth, face-y respectively.
				feature.rotation_degrees = Vector3(90.0, 0.0, prior_z)
				feature.scale = Vector3(size.x, size.z * 0.48, size.y)
		_sync_ink_mesh(feature)


func _sync_ink_mesh(feature: MeshInstance3D) -> void:
	var ink := feature.get_node_or_null("Ink") as MeshInstance3D
	if ink != null:
		ink.mesh = feature.mesh


func _add_label(
	parent: Control, text: String, at: Vector2, size: Vector2,
	font_size: int, color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
