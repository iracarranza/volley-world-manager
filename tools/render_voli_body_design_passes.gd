extends SceneTree
## Render-only Voli body design study.
##
## The point is not to smooth anatomy or add detail everywhere. Each pass keeps
## the visible low-poly / constructed language and only replaces shapes that
## currently read as defaults or communicate the wrong anatomy.
##
## CURRENT is the production body. The three experimental passes are:
## 1. INTENTIONAL PRIMITIVES -- minimum change; taper semantically weak parts.
## 2. SILHOUETTE AUTHORED -- stronger species-specific shape differences.
## 3. SPECIES PLANES -- most adventurous bounded pass; a few extra planes where
##    they carry species identity, while seams and segmented construction remain.
##
## Nothing here is referenced by production scenes.

const PLAYER := preload("res://scenes/components/player_actor_3d.tscn")

const OUTPUT_DIR := "res://artifacts/voli-body-design-pass"
const CANVAS := Vector2i(1920, 1080)
const BG := Color("151a20")
const PANEL := Color("242a31")
const PANEL_ALT := Color("2a3139")
const INK := Color("f0eadc")
const MUTED := Color("aaa69c")
const ACCENT := Color("8da8b8")
const FACE_DARK := Color("11161c")

const SUBJECTS: Array[Dictionary] = [
	{
		"key": "feli", "label": "FELI", "body_type": "Feli", "player_id": 92017,
		"appearance": {"palette_index": 0, "marking": "none", "ears": "standard", "muzzle": "standard", "build": "standard"},
	},
	{
		"key": "cani", "label": "CANI", "body_type": "Cani", "player_id": 92031,
		"appearance": {"palette_index": 0, "marking": "none", "ears": "standard", "muzzle": "standard", "build": "standard"},
	},
	{
		"key": "avi", "label": "AVI", "body_type": "Avi", "player_id": 92043,
		"appearance": {"palette_index": 0, "marking": "none"},
	},
]

const PASSES: Array[Dictionary] = [
	{"key": "current", "title": "CURRENT", "note": "production geometry"},
	{"key": "intentional", "title": "PASS 1 · INTENTIONAL PRIMITIVES", "note": "same simplicity · better taper"},
	{"key": "silhouette", "title": "PASS 2 · SILHOUETTE AUTHORED", "note": "species read before detail"},
	{"key": "planes", "title": "PASS 3 · SPECIES PLANES", "note": "extra planes only where they earn it"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CANVAS
	root.content_scale_size = CANVAS
	RenderingServer.set_default_clear_color(BG)

	var comparison := _build_comparison_sheet()
	root.add_child(comparison)
	for _i in 18:
		await process_frame
	_save("voli_body_design_comparison.png")
	comparison.queue_free()
	for _i in 3:
		await process_frame

	for pass_index in range(1, PASSES.size()):
		var sheet := _build_pass_sheet(PASSES[pass_index])
		root.add_child(sheet)
		for _i in 18:
			await process_frame
		_save("%s.png" % str(PASSES[pass_index].key))
		sheet.queue_free()
		for _i in 3:
			await process_frame
	quit()


func _save(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not write %s: %s" % [path, error_string(error)])
	else:
		print("VOLI_BODY_DESIGN ", path)


func _base_sheet(title: String, subtitle: String) -> Control:
	var sheet := Control.new()
	sheet.size = Vector2(CANVAS)
	var background := ColorRect.new()
	background.color = BG
	background.size = sheet.size
	sheet.add_child(background)
	_add_label(sheet, title, Vector2(48, 24), Vector2(1824, 44), 31, INK, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(sheet, subtitle, Vector2(48, 70), Vector2(1824, 34), 16, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	return sheet


func _build_comparison_sheet() -> Control:
	var sheet := _base_sheet(
		"Voli body design study · three bounded passes",
		"Low-poly construction stays visible. Geometry is added only when a default primitive gives the wrong read."
	)
	var left := 210.0
	var top := 165.0
	var cell := Vector2(395, 274)
	var gap := Vector2(14, 18)
	for column in PASSES.size():
		var x := left + float(column) * (cell.x + gap.x)
		_add_label(sheet, str(PASSES[column].title), Vector2(x, 112), Vector2(cell.x, 26), 14, INK)
		_add_label(sheet, str(PASSES[column].note), Vector2(x, 137), Vector2(cell.x, 20), 11, MUTED)
	for row in SUBJECTS.size():
		var y := top + float(row) * (cell.y + gap.y)
		_add_label(sheet, str(SUBJECTS[row].label), Vector2(48, y + 104), Vector2(135, 32), 21, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
		for column in PASSES.size():
			var x := left + float(column) * (cell.x + gap.x)
			_add_actor_card(sheet, Vector2(x, y), cell, SUBJECTS[row], str(PASSES[column].key), false)
	return sheet


func _build_pass_sheet(pass_spec: Dictionary) -> Control:
	var sheet := _base_sheet(
		"Voli body design · %s" % str(pass_spec.title),
		"Feli / Cani / Avi · same actor rig, pose, materials and camera · render-only geometry study"
	)
	var cell := Vector2(560, 790)
	var gap := 28.0
	var left := 86.0
	var top := 170.0
	for index in SUBJECTS.size():
		var x := left + float(index) * (cell.x + gap)
		_add_label(sheet, str(SUBJECTS[index].label), Vector2(x, 124), Vector2(cell.x, 34), 22, INK)
		_add_actor_card(sheet, Vector2(x, top), cell, SUBJECTS[index], str(pass_spec.key), true)
	return sheet


func _add_actor_card(parent: Control, at: Vector2, size: Vector2, subject: Dictionary, variant: String, close_view: bool) -> void:
	var frame := ColorRect.new()
	frame.position = at
	frame.size = size
	frame.color = PANEL_ALT if variant == "planes" else PANEL
	parent.add_child(frame)
	var inset := 8.0
	var viewport_size := Vector2i(int(size.x - inset * 2.0), int(size.y - inset * 2.0))
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
	_build_actor_world(viewport, subject, variant, close_view)


func _build_actor_world(viewport: SubViewport, subject: Dictionary, variant: String, close_view: bool) -> void:
	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("30363d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e0ea")
	environment.ambient_light_energy = 0.62
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0da")
	key.light_energy = 0.92
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("8fa5bf")
	rim.light_energy = 0.28
	rim.rotation_degrees = Vector3(-12.0, 155.0, 0.0)
	stage.add_child(rim)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(3.6, 0.04, 3.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.025, 0.0)
	floor.material_override = _material(Color("20262d"))
	stage.add_child(floor)

	var actor := PLAYER.instantiate()
	stage.add_child(actor)
	actor.configure(
		int(subject.player_id), true, "Voli", "Right",
		{
			"body_type": str(subject.body_type),
			"height_cm": 188.0,
			"wingspan_cm": 191.0,
			"stride_length_m": 0.83,
			"expression": "neutral",
			"appearance": Dictionary(subject.appearance).duplicate(true),
		}
	)
	actor.shadow.visible = false
	actor.focus_ring.visible = false
	actor.identity_label.visible = false
	actor.set_pose(-1, 0.0, 0.5, Vector2.ZERO, false)
	_apply_body_variant(actor, str(subject.body_type), variant)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.30 if close_view else 2.48
	camera.near = 0.05
	camera.far = 20.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(2.35, 1.22, -4.65), Vector3(0.0, 1.07, 0.0), Vector3.UP)
	camera.current = true


func _apply_body_variant(actor: Node, body_type: String, variant: String) -> void:
	if variant == "current":
		return
	if body_type in ["Feli", "Cani"]:
		_design_muzzle(actor, body_type, variant)
		if variant == "planes":
			_add_paws(actor, body_type)
	elif body_type == "Avi":
		_design_wings(actor, variant)


func _design_muzzle(actor: Node, body_type: String, variant: String) -> void:
	var muzzle := actor.find_child("Muzzle", true, false) as MeshInstance3D
	if muzzle == null or muzzle.mesh == null:
		return
	var old_size := muzzle.mesh.get_aabb().size
	var material := _material_from(muzzle)
	var depth := maxf(old_size.z, 0.13)
	var back_w := maxf(old_size.x, 0.14)
	var back_h := maxf(old_size.y, 0.10)
	var front_ratio := 0.66
	var height_ratio := 0.70

	if body_type == "Feli":
		match variant:
			"intentional":
				depth *= 0.92
				front_ratio = 0.64
				height_ratio = 0.68
			"silhouette":
				depth *= 0.82
				back_w *= 1.05
				front_ratio = 0.54
				height_ratio = 0.62
			"planes":
				depth *= 0.80
				back_w *= 1.08
				front_ratio = 0.48
				height_ratio = 0.58
	else:
		match variant:
			"intentional":
				depth *= 1.10
				front_ratio = 0.64
				height_ratio = 0.70
			"silhouette":
				depth *= 1.28
				back_w *= 0.96
				front_ratio = 0.54
				height_ratio = 0.64
			"planes":
				depth *= 1.38
				back_w *= 0.94
				front_ratio = 0.47
				height_ratio = 0.60

	muzzle.mesh = _front_tapered_prism(back_w, back_h * 0.82, back_w * front_ratio, back_h * height_ratio, depth)
	muzzle.material_override = material
	## Carry the front face outward as the snout gets longer so the mouth, which
	## production authored against the old spherical muzzle, remains near the
	## visible face instead of disappearing into the new solid.
	muzzle.position.z -= maxf(depth - old_size.z, 0.0) * 0.34

	if variant in ["silhouette", "planes"]:
		_add_nose(actor, muzzle, body_type, depth, back_w, back_h)
	if variant == "planes":
		_add_snout_bridge(actor, muzzle, body_type, depth, back_w, back_h, material)


func _add_nose(actor: Node, muzzle: MeshInstance3D, body_type: String, depth: float, width: float, height: float) -> void:
	var parent := muzzle.get_parent() as Node3D
	if parent == null:
		return
	var nose := MeshInstance3D.new()
	nose.name = "StudyNose"
	var box := BoxMesh.new()
	box.size = Vector3(width * (0.34 if body_type == "Feli" else 0.30), height * 0.20, maxf(depth * 0.08, 0.012))
	nose.mesh = box
	nose.position = muzzle.position + Vector3(0.0, height * 0.06, -depth * 0.52)
	nose.material_override = _material(FACE_DARK)
	parent.add_child(nose)


func _add_snout_bridge(actor: Node, muzzle: MeshInstance3D, body_type: String, depth: float, width: float, height: float, material: Material) -> void:
	var parent := muzzle.get_parent() as Node3D
	if parent == null:
		return
	var bridge := MeshInstance3D.new()
	bridge.name = "StudySnoutBridge"
	var bridge_depth := depth * (0.62 if body_type == "Feli" else 0.78)
	var bridge_width := width * (0.44 if body_type == "Feli" else 0.38)
	bridge.mesh = _front_tapered_prism(bridge_width, height * 0.32, bridge_width * 0.70, height * 0.20, bridge_depth)
	bridge.position = muzzle.position + Vector3(0.0, height * 0.34, depth * 0.18)
	bridge.material_override = material
	parent.add_child(bridge)


func _add_paws(actor: Node, body_type: String) -> void:
	for side_name in ["LeftArm", "RightArm"]:
		var elbow := actor.get_node_or_null("BodyPivot/%s/Elbow" % side_name) as Node3D
		if elbow == null:
			continue
		var lower := elbow.get_node_or_null("Mesh") as MeshInstance3D
		if lower == null or lower.mesh == null:
			continue
		var length := lower.mesh.get_aabb().size.y
		var paw := MeshInstance3D.new()
		paw.name = "StudyPaw"
		var sphere := SphereMesh.new()
		sphere.radius = 0.075 if body_type == "Feli" else 0.085
		sphere.height = 0.13 if body_type == "Feli" else 0.145
		sphere.radial_segments = 8
		sphere.rings = 4
		paw.mesh = sphere
		paw.scale = Vector3(1.18, 0.86, 1.38)
		paw.position = Vector3(0.0, lower.position.y - length * 0.52, -0.018)
		paw.material_override = _material_from(lower)
		elbow.add_child(paw)


func _design_wings(actor: Node, variant: String) -> void:
	for wing_name in ["WingLeft", "WingRight"]:
		var wing := actor.find_child(wing_name, true, false) as MeshInstance3D
		if wing == null or wing.mesh == null:
			continue
		var side := -1.0 if wing_name == "WingLeft" else 1.0
		var old_size := wing.mesh.get_aabb().size
		var material := _material_from(wing)
		match variant:
			"intentional":
				wing.mesh = _vertical_tapered_prism(
					maxf(old_size.x * 1.35, 0.07), maxf(old_size.x * 0.70, 0.04),
					old_size.z * 0.92, old_size.z * 0.52, old_size.y
				)
				wing.material_override = material
			"silhouette":
				wing.visible = false
				_add_feather_fan(wing, side, material, 3, false)
			"planes":
				wing.visible = false
				_add_feather_fan(wing, side, material, 4, true)


func _add_feather_fan(source: MeshInstance3D, side: float, material: Material, count: int, add_root: bool) -> void:
	var parent := source.get_parent() as Node3D
	if parent == null:
		return
	var base := source.position
	var base_rot := source.rotation_degrees
	for index in range(count):
		var t := float(index) / maxf(float(count - 1), 1.0)
		var feather := MeshInstance3D.new()
		feather.name = "StudyFeather%d" % index
		var length := lerpf(0.60, 0.84, t)
		var depth := lerpf(0.19, 0.34, t)
		feather.mesh = _vertical_tapered_prism(0.075, 0.035, depth, depth * 0.55, length)
		feather.position = base + Vector3(side * (0.015 + 0.024 * t), -0.01 - 0.035 * t, lerpf(-0.11, 0.10, t))
		feather.rotation_degrees = base_rot + Vector3(lerpf(-9.0, 10.0, t), 0.0, side * lerpf(9.0, -7.0, t))
		feather.material_override = material
		parent.add_child(feather)
	if add_root:
		var root_piece := MeshInstance3D.new()
		root_piece.name = "StudyWingRoot"
		root_piece.mesh = _vertical_tapered_prism(0.11, 0.075, 0.25, 0.18, 0.34)
		root_piece.position = base + Vector3(side * 0.01, 0.24, -0.01)
		root_piece.rotation_degrees = base_rot + Vector3(-3.0, 0.0, side * 4.0)
		root_piece.material_override = material
		parent.add_child(root_piece)


func _front_tapered_prism(back_w: float, back_h: float, front_w: float, front_h: float, depth: float) -> ArrayMesh:
	var bz := depth * 0.5
	var fz := -depth * 0.5
	var vertices := [
		Vector3(-back_w * 0.5, back_h * 0.5, bz),
		Vector3(back_w * 0.5, back_h * 0.5, bz),
		Vector3(back_w * 0.5, -back_h * 0.5, bz),
		Vector3(-back_w * 0.5, -back_h * 0.5, bz),
		Vector3(-front_w * 0.5, front_h * 0.5, fz),
		Vector3(front_w * 0.5, front_h * 0.5, fz),
		Vector3(front_w * 0.5, -front_h * 0.5, fz),
		Vector3(-front_w * 0.5, -front_h * 0.5, fz),
	]
	return _mesh_from_quads(vertices, [
		[4, 5, 6, 7], [1, 0, 3, 2], [0, 4, 7, 3],
		[5, 1, 2, 6], [0, 1, 5, 4], [7, 6, 2, 3],
	])


func _vertical_tapered_prism(top_w: float, bottom_w: float, top_d: float, bottom_d: float, length: float) -> ArrayMesh:
	var ty := length * 0.5
	var by := -length * 0.5
	var vertices := [
		Vector3(-top_w * 0.5, ty, -top_d * 0.5),
		Vector3(top_w * 0.5, ty, -top_d * 0.5),
		Vector3(top_w * 0.5, ty, top_d * 0.5),
		Vector3(-top_w * 0.5, ty, top_d * 0.5),
		Vector3(-bottom_w * 0.5, by, -bottom_d * 0.5),
		Vector3(bottom_w * 0.5, by, -bottom_d * 0.5),
		Vector3(bottom_w * 0.5, by, bottom_d * 0.5),
		Vector3(-bottom_w * 0.5, by, bottom_d * 0.5),
	]
	return _mesh_from_quads(vertices, [
		[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0],
	])


func _mesh_from_quads(vertices: Array, quads: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for raw_quad in quads:
		var q: Array = raw_quad
		for index in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(vertices[int(index)])
	st.generate_normals()
	return st.commit()


func _material_from(source: MeshInstance3D) -> Material:
	var material: Material = source.material_override
	if material == null and source.mesh != null and source.mesh.get_surface_count() > 0:
		material = source.get_active_material(0)
	if material != null:
		return material.duplicate()
	return _material(Color("c98f4e"))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	material.metallic = 0.0
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
