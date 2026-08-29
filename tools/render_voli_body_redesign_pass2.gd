extends SceneTree
## Second render-only Voli body redesign study.
##
## This pass responds to two failures in the first study:
## - Feli/Cani: the tapered study muzzle was drawn under the production
##   seven-piece spherical-mouth projection, so the exposed dark segments read
##   as teeth/stitches. Here the study muzzle owns its own single neutral mouth
##   stroke on its actual front plane.
## - Avi: the first study hung feather slabs beside the production arm. Here the
##   visible arm cylinders are hidden and the arm bones themselves carry two
##   contiguous wing masses, so the wing IS the forelimb silhouette.
##
## The production PlayerActor3D, materials, rig and poses remain authoritative.
## Nothing here is referenced by production scenes.

const PLAYER := preload("res://scenes/components/player_actor_3d.tscn")

const OUTPUT_DIR := "res://artifacts/voli-body-redesign-pass2"
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
	{"key": "current", "title": "CURRENT", "note": "production body"},
	{"key": "a", "title": "PASS A · MINIMAL", "note": "correct the failure only"},
	{"key": "b", "title": "PASS B · SILHOUETTE", "note": "stronger species read"},
	{"key": "c", "title": "PASS C · CANDIDATE", "note": "conservative synthesis"},
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
	_save("comparison_current_a_b_c.png")
	comparison.queue_free()
	for _i in 3:
		await process_frame

	for pass_index in range(1, PASSES.size()):
		var sheet := _build_pass_sheet(PASSES[pass_index])
		root.add_child(sheet)
		for _i in 18:
			await process_frame
		_save("pass_%s.png" % str(PASSES[pass_index].key))
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
		print("VOLI_BODY_REDESIGN_PASS2 ", path)


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
		"Voli body redesign · integrated muzzle + wing pass",
		"Current / A / B / C. Simple construction stays visible; the changed feature must belong to the body instead of decorating it."
	)
	var left := 260.0
	var top := 170.0
	var cell := Vector2(390, 202)
	var x_gap := 12.0
	var y_gap := 18.0
	for column in PASSES.size():
		var x := left + float(column) * (cell.x + x_gap)
		_add_label(sheet, str(PASSES[column].title), Vector2(x, 112), Vector2(cell.x, 24), 14, INK)
		_add_label(sheet, str(PASSES[column].note), Vector2(x, 137), Vector2(cell.x, 20), 11, MUTED)

	var rows := [
		{"subject": SUBJECTS[0], "label": "FELI FACE", "view": "face", "pose": "stand"},
		{"subject": SUBJECTS[1], "label": "CANI FACE", "view": "face", "pose": "stand"},
		{"subject": SUBJECTS[2], "label": "AVI · REST", "view": "body", "pose": "stand"},
		{"subject": SUBJECTS[2], "label": "AVI · BLOCK", "view": "body", "pose": "block"},
	]
	for row in rows.size():
		var y := top + float(row) * (cell.y + y_gap)
		_add_label(sheet, str(rows[row].label), Vector2(48, y + 78), Vector2(180, 32), 18, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
		for column in PASSES.size():
			var x := left + float(column) * (cell.x + x_gap)
			_add_actor_card(sheet, Vector2(x, y), cell, rows[row].subject, str(PASSES[column].key), str(rows[row].view), str(rows[row].pose))
	return sheet


func _build_pass_sheet(pass_spec: Dictionary) -> Control:
	var sheet := _base_sheet(
		"Voli body redesign · %s" % str(pass_spec.title),
		"Feli and Cani use a muzzle-aware mouth. Avi's upper/lower wing masses replace the visible arm cylinders and follow the same bones."
	)
	var top := 180.0
	var face_cell := Vector2(410, 360)
	var body_cell := Vector2(500, 760)

	_add_label(sheet, "FELI · FACE", Vector2(60, 130), Vector2(face_cell.x, 30), 18, INK)
	_add_actor_card(sheet, Vector2(60, top), face_cell, SUBJECTS[0], str(pass_spec.key), "face", "stand")
	_add_label(sheet, "CANI · FACE", Vector2(500, 130), Vector2(face_cell.x, 30), 18, INK)
	_add_actor_card(sheet, Vector2(500, top), face_cell, SUBJECTS[1], str(pass_spec.key), "face", "stand")

	_add_label(sheet, "AVI · REST", Vector2(950, 130), Vector2(430, 30), 18, INK)
	_add_actor_card(sheet, Vector2(950, top), Vector2(430, 760), SUBJECTS[2], str(pass_spec.key), "body", "stand")
	_add_label(sheet, "AVI · BLOCK", Vector2(1410, 130), Vector2(430, 30), 18, INK)
	_add_actor_card(sheet, Vector2(1410, top), Vector2(430, 760), SUBJECTS[2], str(pass_spec.key), "body", "block")

	_add_label(sheet,
		"One muzzle mass + one mouth stroke. No bridge stack; no spherical-mouth sticker bake.",
		Vector2(60, 585), Vector2(850, 65), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(sheet,
		"Wing geometry is centred on the arm axis and split at the elbow, so the fold is the pose rather than an offset cosmetic.",
		Vector2(60, 660), Vector2(850, 75), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	return sheet


func _add_actor_card(parent: Control, at: Vector2, size: Vector2, subject: Dictionary, variant: String, view: String, pose: String) -> void:
	var frame := ColorRect.new()
	frame.position = at
	frame.size = size
	frame.color = PANEL_ALT if variant == "c" else PANEL
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
	_build_actor_world(viewport, subject, variant, view, pose)


func _build_actor_world(viewport: SubViewport, subject: Dictionary, variant: String, view: String, pose: String) -> void:
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
	if pose == "block":
		actor.set_pose(5, 0.62, 0.5, Vector2.ZERO, true)
	else:
		actor.set_pose(-1, 0.0, 0.5, Vector2.ZERO, false)
	_apply_body_variant(actor, str(subject.body_type), variant)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 20.0
	stage.add_child(camera)
	if view == "face":
		var body_pivot := actor.get_node("BodyPivot") as Node3D
		var head := actor.get_node("BodyPivot/Head") as Node3D
		var target_y := body_pivot.position.y + head.position.y - 0.02
		camera.size = 0.58
		camera.look_at_from_position(Vector3(0.92, target_y + 0.02, -2.10), Vector3(0.0, target_y - 0.01, 0.0), Vector3.UP)
	else:
		camera.size = 2.42 if pose == "block" else 2.28
		camera.look_at_from_position(Vector3(2.35, 1.30, -4.65), Vector3(0.0, 1.12 if pose == "block" else 1.05, 0.0), Vector3.UP)
	camera.current = true


func _apply_body_variant(actor: Node, body_type: String, variant: String) -> void:
	if variant == "current":
		return
	if body_type in ["Feli", "Cani"]:
		_design_muzzle(actor, body_type, variant)
	elif body_type == "Avi":
		_design_integrated_wings(actor, variant)


## One species-authored wedge replaces the spherical muzzle. Critically, the
## production seven-segment mouth is hidden and a single stroke is placed on the
## wedge's own front plane, so no segment can poke through as a false tooth.
func _design_muzzle(actor: Node, body_type: String, variant: String) -> void:
	var muzzle := actor.find_child("Muzzle", true, false) as MeshInstance3D
	if muzzle == null or muzzle.mesh == null:
		return
	var old_size := muzzle.mesh.get_aabb().size
	var material := _material_from(muzzle)
	var spec := _muzzle_spec(body_type, variant, old_size)
	var depth := float(spec.depth)
	var back_w := float(spec.back_w)
	var back_h := float(spec.back_h)
	var front_w := float(spec.front_w)
	var front_h := float(spec.front_h)

	muzzle.mesh = _front_tapered_prism(back_w, back_h, front_w, front_h, depth)
	muzzle.material_override = material
	## Keep the rear face approximately where production placed it; extra length
	## therefore grows forward (-Z) instead of being split through the skull.
	muzzle.position.z -= (depth - old_size.z) * 0.5

	## Prefix, for the same reason the wings above are: the mouth was seven boxes
	## named `Mouth0..Mouth6` and is now one swept stroke named `Mouth`, so seven
	## exact lookups found nothing and the study drew over a live mouth.
	for old_mouth in actor.find_children("Mouth*", "MeshInstance3D", true, false):
		(old_mouth as MeshInstance3D).visible = false

	var nose := MeshInstance3D.new()
	nose.name = "StudyNose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(front_w * (0.46 if body_type == "Feli" else 0.40), front_h * 0.18, 0.014)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, front_h * 0.16, -depth * 0.5 - 0.008)
	nose.material_override = _material(FACE_DARK)
	muzzle.add_child(nose)

	var mouth := MeshInstance3D.new()
	mouth.name = "StudyMouth"
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(front_w * (0.64 if body_type == "Feli" else 0.58), 0.012, 0.012)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, -front_h * 0.19, -depth * 0.5 - 0.008)
	mouth.material_override = _material(FACE_DARK)
	muzzle.add_child(mouth)


func _muzzle_spec(body_type: String, variant: String, old_size: Vector3) -> Dictionary:
	var old_w := maxf(old_size.x, 0.16)
	var old_h := maxf(old_size.y, 0.11)
	var old_d := maxf(old_size.z, 0.13)
	if body_type == "Feli":
		match variant:
			"a":
				return {"back_w": old_w * 1.00, "back_h": old_h * 0.80, "front_w": old_w * 0.72, "front_h": old_h * 0.60, "depth": old_d * 0.88}
			"b":
				return {"back_w": old_w * 1.08, "back_h": old_h * 0.76, "front_w": old_w * 0.64, "front_h": old_h * 0.54, "depth": old_d * 0.78}
			_:
				return {"back_w": old_w * 1.04, "back_h": old_h * 0.78, "front_w": old_w * 0.68, "front_h": old_h * 0.57, "depth": old_d * 0.82}
	else:
		match variant:
			"a":
				return {"back_w": old_w * 0.98, "back_h": old_h * 0.82, "front_w": old_w * 0.68, "front_h": old_h * 0.60, "depth": old_d * 1.12}
			"b":
				return {"back_w": old_w * 0.94, "back_h": old_h * 0.78, "front_w": old_w * 0.57, "front_h": old_h * 0.52, "depth": old_d * 1.34}
			_:
				return {"back_w": old_w * 0.96, "back_h": old_h * 0.80, "front_w": old_w * 0.62, "front_h": old_h * 0.56, "depth": old_d * 1.24}


## The Avi rig already has exactly the articulation a wing needs: shoulder and
## elbow. Replace the visible upper/lower arm cylinders with wing masses centred
## on those same axes. The production WingLeft/WingRight cosmetics are hidden.
## Hide whatever the production body is currently calling its wings.
##
## **By prefix, because the names moved and an exact lookup fails silently.**
## These read `["WingLeft", "WingRight"]`, and production has since split each
## wing into a covert and a primary so it can fold at the elbow -- so the lookup
## found nothing, hid nothing, and the study drew its own wing variant *on top of*
## the production one. A comparison sheet that quietly shows both is worse than
## no sheet, because it still looks like a comparison.
static func _hide_production_wings(actor: Node) -> void:
	for node in actor.find_children("Wing*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false


func _design_integrated_wings(actor: Node, variant: String) -> void:
	_hide_production_wings(actor)

	for side_name in ["LeftArm", "RightArm"]:
		var arm := actor.get_node_or_null("BodyPivot/%s" % side_name) as Node3D
		if arm == null:
			continue
		var elbow := arm.get_node_or_null("Elbow") as Node3D
		var upper := arm.get_node_or_null("Mesh") as MeshInstance3D
		var lower := elbow.get_node_or_null("Mesh") as MeshInstance3D if elbow != null else null
		if elbow == null or upper == null or lower == null:
			continue
		var material := _material_from(upper)
		upper.visible = false
		lower.visible = false
		var spec := _wing_spec(variant)

		var upper_wing := MeshInstance3D.new()
		upper_wing.name = "StudyUpperWing"
		upper_wing.mesh = _vertical_tapered_prism(
			float(spec.thickness), float(spec.thickness) * 0.92,
			float(spec.upper_top_depth), float(spec.upper_bottom_depth),
			float(spec.upper_length)
		)
		upper_wing.position = Vector3(0.0, -float(spec.upper_length) * 0.47, 0.0)
		upper_wing.material_override = material
		arm.add_child(upper_wing)

		var lower_wing := MeshInstance3D.new()
		lower_wing.name = "StudyLowerWing"
		lower_wing.mesh = _vertical_tapered_prism(
			float(spec.thickness) * 0.94, float(spec.tip_thickness),
			float(spec.lower_top_depth), float(spec.lower_bottom_depth),
			float(spec.lower_length)
		)
		lower_wing.position = Vector3(0.0, -float(spec.lower_length) * 0.46, 0.0)
		lower_wing.material_override = material
		elbow.add_child(lower_wing)

		## A tiny overlap across the elbow is deliberate: two solids may remain
		## visibly segmented, but they must read as one articulated forelimb rather
		## than two cosmetics floating beside a hidden arm.
		var fold := MeshInstance3D.new()
		fold.name = "StudyWingFold"
		var fold_mesh := SphereMesh.new()
		fold_mesh.radius = float(spec.lower_top_depth) * 0.22
		fold_mesh.height = float(spec.lower_top_depth) * 0.34
		fold_mesh.radial_segments = 8
		fold_mesh.rings = 4
		fold.mesh = fold_mesh
		fold.scale = Vector3(0.48, 0.72, 1.0)
		fold.position = Vector3.ZERO
		fold.material_override = material
		elbow.add_child(fold)


func _wing_spec(variant: String) -> Dictionary:
	match variant:
		"a":
			return {
				"thickness": 0.070, "tip_thickness": 0.040,
				"upper_length": 0.43, "upper_top_depth": 0.18, "upper_bottom_depth": 0.29,
				"lower_length": 0.47, "lower_top_depth": 0.29, "lower_bottom_depth": 0.14,
			}
		"b":
			return {
				"thickness": 0.080, "tip_thickness": 0.034,
				"upper_length": 0.45, "upper_top_depth": 0.22, "upper_bottom_depth": 0.37,
				"lower_length": 0.51, "lower_top_depth": 0.37, "lower_bottom_depth": 0.11,
			}
		_:
			return {
				"thickness": 0.074, "tip_thickness": 0.036,
				"upper_length": 0.44, "upper_top_depth": 0.20, "upper_bottom_depth": 0.33,
				"lower_length": 0.49, "lower_top_depth": 0.33, "lower_bottom_depth": 0.125,
			}


func _front_tapered_prism(back_w: float, back_h: float, front_w: float, front_h: float, depth: float) -> ArrayMesh:
	var bz := depth * 0.5
	var fz := -depth * 0.5
	var vertices := [
		Vector3(-back_w * 0.5, back_h * 0.5, bz), Vector3(back_w * 0.5, back_h * 0.5, bz),
		Vector3(back_w * 0.5, -back_h * 0.5, bz), Vector3(-back_w * 0.5, -back_h * 0.5, bz),
		Vector3(-front_w * 0.5, front_h * 0.5, fz), Vector3(front_w * 0.5, front_h * 0.5, fz),
		Vector3(front_w * 0.5, -front_h * 0.5, fz), Vector3(-front_w * 0.5, -front_h * 0.5, fz),
	]
	return _mesh_from_quads(vertices, [
		[4, 5, 6, 7], [1, 0, 3, 2], [0, 4, 7, 3],
		[5, 1, 2, 6], [0, 1, 5, 4], [7, 6, 2, 3],
	])


func _vertical_tapered_prism(top_w: float, bottom_w: float, top_d: float, bottom_d: float, length: float) -> ArrayMesh:
	var ty := length * 0.5
	var by := -length * 0.5
	var vertices := [
		Vector3(-top_w * 0.5, ty, -top_d * 0.5), Vector3(top_w * 0.5, ty, -top_d * 0.5),
		Vector3(top_w * 0.5, ty, top_d * 0.5), Vector3(-top_w * 0.5, ty, top_d * 0.5),
		Vector3(-bottom_w * 0.5, by, -bottom_d * 0.5), Vector3(bottom_w * 0.5, by, -bottom_d * 0.5),
		Vector3(bottom_w * 0.5, by, bottom_d * 0.5), Vector3(-bottom_w * 0.5, by, bottom_d * 0.5),
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
