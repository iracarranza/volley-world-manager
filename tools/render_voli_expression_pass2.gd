extends SceneTree
## Second Voli facial-expression study.
##
## Production PlayerActor3D and production FaceExpressions.GRID stay authoritative.
## These four variants are render-only experiments layered onto the generated
## face solids after configure(): Canonical+, Selective Sclera, Open Mouth Set,
## and Hybrid Expressive. No production face code is changed by this probe.

const PLAYER := preload("res://scenes/components/player_actor_3d.tscn")
const FACE := preload("res://scripts/data/face_expressions.gd")

const OUTPUT_DIR := "res://artifacts/voli-expression-pass2"
const CANVAS := Vector2i(1920, 1080)
const BG := Color("171b20")
const PANEL := Color("252b32")
const PANEL_ALT := Color("2b323a")
const INK := Color("f0eadc")
const MUTED := Color("aaa69c")
const ACCENT := Color("8da8b8")
const FACE_DARK := Color("10151b")
const SCLERA := Color("e9e5d9")
const MOUTH_INNER := Color("7c302e")

const EYE_ORDER: Array[String] = ["full", "half", "flat"]
const MOUTH_ORDER: Array[String] = ["smile", "flat", "frown"]
const VARIANTS: Array[Dictionary] = [
	{"key": "canonical_plus", "title": "CANONICAL+", "note": "brows · lids · mild asymmetry"},
	{"key": "selective_sclera", "title": "SELECTIVE SCLERA", "note": "eye whites only at high intensity"},
	{"key": "open_mouth", "title": "OPEN MOUTH SET", "note": "geometric call · gasp · strain"},
	{"key": "hybrid", "title": "HYBRID EXPRESSIVE", "note": "bounded combination of all three"},
]

const SUBJECTS: Array[Dictionary] = [
	{
		"key": "feli", "label": "Feli Voli",
		"body_type": "Feli", "player_id": 92017,
		"appearance": {
			"palette_index": 0, "marking": "none",
			"ears": "standard", "muzzle": "standard", "build": "standard",
		},
	},
	{
		"key": "vegi", "label": "Vegi Voli",
		"body_type": "Vegi", "player_id": 91027,
		"appearance": {
			"produce": "Tomato", "palette_index": 0, "marking": "none",
		},
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CANVAS
	root.content_scale_size = CANVAS
	RenderingServer.set_default_clear_color(BG)

	for subject in SUBJECTS:
		for variant in VARIANTS:
			var sheet := _build_variant_sheet(subject, variant)
			root.add_child(sheet)
			for _i in 14:
				await process_frame
			_save("%s_%s.png" % [subject.key, variant.key])
			sheet.queue_free()
			for _i in 3:
				await process_frame

	var overview := _build_overview_sheet(SUBJECTS[0])
	root.add_child(overview)
	for _i in 14:
		await process_frame
	_save("feli_four_variant_overview.png")
	overview.queue_free()
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
		print("VOLI_EXPRESSION_PASS2 ", path)


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


func _build_variant_sheet(subject: Dictionary, variant: Dictionary) -> Control:
	var sheet := _base_sheet(
		"Voli expression pass 2 · %s · %s" % [subject.label, variant.title],
		"Production PlayerActor3D + FaceExpressions.GRID · %s" % variant.note
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
			_add_portrait_card(sheet, Vector2(x, y), cell, subject, expression, str(variant.key), true)
	return sheet


func _build_overview_sheet(subject: Dictionary) -> Control:
	var sheet := _base_sheet(
		"Voli expression pass 2 · four bounded directions",
		"Same production %s, camera, palette and nine-expression grammar. Each row is one facial architecture experiment." % subject.label
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
		_add_label(sheet, "%s + %s" % [components[0], components[1]], Vector2(x, 150), Vector2(cell.x, 22), 11, MUTED)
	for row in VARIANTS.size():
		var y := top + float(row) * (cell.y + y_gap)
		var variant: Dictionary = VARIANTS[row]
		_add_label(sheet, str(variant.title), Vector2(48, y + 44), Vector2(180, 30), 16, INK, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(sheet, str(variant.note), Vector2(48, y + 76), Vector2(180, 48), 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		for column in expressions.size():
			var x := left + float(column) * (cell.x + x_gap)
			_add_portrait_card(sheet, Vector2(x, y), cell, subject, expressions[column], str(variant.key), false)
	return sheet


func _expression_order() -> Array[String]:
	var result: Array[String] = []
	for eye_state in EYE_ORDER:
		for mouth_shape in MOUTH_ORDER:
			result.append(str(FACE.GRID[eye_state][mouth_shape]))
	return result


func _add_portrait_card(
	parent: Control, at: Vector2, size: Vector2, subject: Dictionary,
	expression: String, variant: String, show_expression: bool
) -> void:
	var frame := ColorRect.new()
	frame.position = at
	frame.size = size
	frame.color = PANEL_ALT if variant == "hybrid" else PANEL
	parent.add_child(frame)
	var inset := 8.0
	var caption_h := 34.0 if show_expression else 0.0
	var viewport_size := Vector2i(int(size.x - inset * 2.0), int(size.y - inset * 2.0 - caption_h))
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
	_build_portrait_world(viewport, subject, expression, variant)
	if show_expression:
		_add_label(parent, expression.to_upper(), at + Vector2(8, size.y - 38), Vector2(size.x - 16, 30), 16, INK)


func _build_portrait_world(viewport: SubViewport, subject: Dictionary, expression: String, variant: String) -> void:
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
	stage.add_child(key)

	var actor := PLAYER.instantiate()
	stage.add_child(actor)
	actor.configure(
		int(subject.player_id), true, "Voli", "Right",
		{
			"body_type": str(subject.body_type),
			"height_cm": 188.0,
			"wingspan_cm": 191.0,
			"stride_length_m": 0.83,
			"expression": expression,
			"appearance": Dictionary(subject.appearance).duplicate(true),
		}
	)
	actor.shadow.visible = false
	actor.focus_ring.visible = false
	actor.identity_label.visible = false
	_apply_expression_variant(actor, expression, variant)

	var body_pivot := actor.get_node("BodyPivot") as Node3D
	var head := actor.get_node("BodyPivot/Head") as Node3D
	var target_y := body_pivot.position.y + head.position.y - 0.015
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.66 if str(subject.body_type) == "Feli" else 0.62
	camera.near = 0.05
	camera.far = 10.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, target_y, -2.5), Vector3(0.0, target_y, 0.0), Vector3.UP)
	camera.current = true


func _apply_expression_variant(actor: Node, expression: String, variant: String) -> void:
	var face := actor.get_node_or_null("BodyPivot/Head/Face") as Node3D
	if face == null:
		return
	var components: Array[String] = FACE.components(expression)
	if components.is_empty():
		return
	var eye_state := components[0]
	_add_brows(face, expression, eye_state, variant == "hybrid")
	_apply_eye_character(face, eye_state, variant)
	if variant == "selective_sclera" or variant == "hybrid":
		if expression in ["worried", "cross", "tired"]:
			_add_sclera(face, expression)
	if variant == "open_mouth" or variant == "hybrid":
		if expression in ["happy", "worried", "devious", "cross", "tired"]:
			_replace_with_open_mouth(face, expression, variant == "hybrid")


func _apply_eye_character(face: Node3D, eye_state: String, variant: String) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := face.get_node_or_null(eye_name) as MeshInstance3D
		if eye == null:
			continue
		var side := -1.0 if eye_name == "EyeL" else 1.0
		var y_scale := 1.0
		match eye_state:
			"full": y_scale = 1.06
			"half": y_scale = 0.91
			"flat": y_scale = 0.82
		var x_scale := 1.02 if side < 0.0 else 0.96
		if variant == "hybrid":
			x_scale += 0.04 if side < 0.0 else -0.01
		eye.scale = Vector3(x_scale, y_scale, 1.0)


func _add_brows(face: Node3D, expression: String, eye_state: String, strong: bool) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := face.get_node_or_null(eye_name) as MeshInstance3D
		if eye == null or eye.mesh == null:
			continue
		var side := -1.0 if eye_name == "EyeL" else 1.0
		var bounds := eye.mesh.get_aabb().size
		var brow := MeshInstance3D.new()
		brow.name = "BrowL" if side < 0.0 else "BrowR"
		var box := BoxMesh.new()
		box.size = Vector3(bounds.x * 1.15, maxf(bounds.y * 0.22, bounds.x * 0.09), bounds.z * 0.72)
		brow.mesh = box
		var lift := bounds.y * (0.76 if eye_state == "full" else 0.60)
		var asymmetric := bounds.y * (0.10 if side > 0.0 else 0.0)
		brow.position = eye.position + Vector3(0.0, lift - asymmetric, -bounds.z * 0.08)
		var angle := eye.rotation_degrees.z * (1.20 if strong else 1.05)
		if expression == "worried":
			angle += -12.0 * side
		elif expression in ["cross", "tired"]:
			angle += 10.0 * side
		elif expression in ["happy", "relaxed"]:
			angle *= 0.55
		brow.rotation_degrees.z = angle
		brow.material_override = _material(FACE_DARK)
		face.add_child(brow)


func _add_sclera(face: Node3D, expression: String) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := face.get_node_or_null(eye_name) as MeshInstance3D
		if eye == null or eye.mesh == null:
			continue
		var size := eye.mesh.get_aabb().size
		var white := MeshInstance3D.new()
		white.name = "%sSclera" % eye_name
		var box := BoxMesh.new()
		var widen := 1.48 if expression == "worried" else 1.34
		var heighten := 1.35 if expression == "worried" else (1.18 if expression == "cross" else 1.05)
		box.size = Vector3(size.x * widen, size.y * heighten, size.z * 0.58)
		white.mesh = box
		white.position = eye.position + Vector3(0.0, 0.0, size.z * 0.16)
		white.rotation_degrees = eye.rotation_degrees
		white.material_override = _material(SCLERA)
		face.add_child(white)
		## Existing eye becomes the dark pupil/iris floating over the new white.
		eye.scale *= Vector3(0.60, 0.72, 0.90)
		white.move_to_front()
		face.move_child(white, max(0, eye.get_index()))


func _replace_with_open_mouth(face: Node3D, expression: String, strong: bool) -> void:
	var mouths: Array[MeshInstance3D] = []
	for child in face.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and str(mesh.name).begins_with("Mouth") and not str(mesh.name).contains("Cavity"):
			mouths.append(mesh)
	if mouths.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var z_sum := 0.0
	for mouth in mouths:
		var size := mouth.mesh.get_aabb().size
		min_x = minf(min_x, mouth.position.x - size.x * 0.5)
		max_x = maxf(max_x, mouth.position.x + size.x * 0.5)
		min_y = minf(min_y, mouth.position.y - size.y * 0.5)
		max_y = maxf(max_y, mouth.position.y + size.y * 0.5)
		z_sum += mouth.position.z
		mouth.visible = false
	var width := max_x - min_x
	var centre := Vector3((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, z_sum / float(mouths.size()) - 0.004)
	var cavity_size := Vector2(width * 0.76, maxf(width * 0.24, 0.018))
	match expression:
		"happy": cavity_size = Vector2(width * 0.88, width * (0.34 if strong else 0.28))
		"worried": cavity_size = Vector2(width * 0.58, width * (0.54 if strong else 0.46))
		"devious": cavity_size = Vector2(width * 0.70, width * 0.20)
		"cross": cavity_size = Vector2(width * 0.78, width * (0.26 if strong else 0.22))
		"tired": cavity_size = Vector2(width * 0.55, width * (0.34 if strong else 0.28))
	var cavity := MeshInstance3D.new()
	cavity.name = "MouthCavity"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 5
	cavity.mesh = sphere
	cavity.scale = Vector3(cavity_size.x, cavity_size.y, maxf(width * 0.10, 0.008))
	cavity.position = centre
	if expression == "devious":
		cavity.rotation_degrees.z = -7.0
	elif expression == "cross":
		cavity.rotation_degrees.z = 4.0
	cavity.material_override = _material(FACE_DARK)
	face.add_child(cavity)

	if expression in ["happy", "worried", "tired"]:
		var inner := MeshInstance3D.new()
		inner.name = "MouthInner"
		var inner_sphere := SphereMesh.new()
		inner_sphere.radius = 0.5
		inner_sphere.height = 1.0
		inner_sphere.radial_segments = 8
		inner_sphere.rings = 4
		inner.mesh = inner_sphere
		inner.scale = Vector3(cavity_size.x * 0.48, cavity_size.y * 0.30, maxf(width * 0.05, 0.004))
		inner.position = centre + Vector3(0.0, -cavity_size.y * 0.22, -0.006)
		inner.material_override = _material(MOUTH_INNER)
		face.add_child(inner)
	if expression == "cross":
		var teeth := MeshInstance3D.new()
		teeth.name = "MouthTeeth"
		var teeth_box := BoxMesh.new()
		teeth_box.size = Vector3(cavity_size.x * 0.72, cavity_size.y * 0.34, maxf(width * 0.045, 0.004))
		teeth.mesh = teeth_box
		teeth.position = centre + Vector3(0.0, cavity_size.y * 0.08, -0.006)
		teeth.material_override = _material(SCLERA)
		face.add_child(teeth)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material


func _add_label(parent: Control, text: String, at: Vector2, size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
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
