extends SceneTree
## Refined render-only Voli body redesign study.
##
## Evidence from pass 2:
## - hiding Mouth0..Mouth6 by exact lookup still left thin legacy face solids in
##   the close-up, so this pass suppresses every Face child whose name begins
##   with Mouth before placing one muzzle-local neutral stroke.
## - a pale tapered muzzle still risks reading as a protruding tooth block. Pass
##   A keeps that minimal-change option; B/C test species shape as the primary
##   read by carrying the head/skin material onto the new wedge.
## - Avi is correctly attached to the arm bones now, but a four-sided taper is
##   still a paddle. B/C use two simple extruded profile masses: shoulder-to-
##   elbow and elbow-to-tip. They remain visibly segmented, but together are the
##   forelimb rather than cosmetics beside it.
##
## Production PlayerActor3D, rig, materials, poses and body proportions remain
## authoritative. Nothing here is referenced by production scenes.

const PLAYER := preload("res://scenes/components/player_actor_3d.tscn")

const OUTPUT_DIR := "res://artifacts/voli-body-redesign-pass3"
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
	{"key": "a", "title": "PASS A · MINIMAL", "note": "one wedge · arm-axis wing"},
	{"key": "b", "title": "PASS B · SILHOUETTE", "note": "species wedge · shaped wing"},
	{"key": "c", "title": "PASS C · CANDIDATE", "note": "restrained synthesis"},
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
		print("VOLI_BODY_REDESIGN_PASS3 ", path)


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
		"Voli body redesign · refined muzzle + forelimb wing",
		"Current / A / B / C. The study changes semantic shape, not general anatomical smoothness."
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
		"Muzzle mouth is authored on the muzzle front plane. Avi wing masses replace visible arm cylinders and share their articulation."
	)
	var top := 180.0
	var face_cell := Vector2(410, 360)
	_add_label(sheet, "FELI · FACE", Vector2(60, 130), Vector2(face_cell.x, 30), 18, INK)
	_add_actor_card(sheet, Vector2(60, top), face_cell, SUBJECTS[0], str(pass_spec.key), "face", "stand")
	_add_label(sheet, "CANI · FACE", Vector2(500, 130), Vector2(face_cell.x, 30), 18, INK)
	_add_actor_card(sheet, Vector2(500, top), face_cell, SUBJECTS[1], str(pass_spec.key), "face", "stand")
	_add_label(sheet, "AVI · REST", Vector2(950, 130), Vector2(430, 30), 18, INK)
	_add_actor_card(sheet, Vector2(950, top), Vector2(430, 760), SUBJECTS[2], str(pass_spec.key), "body", "stand")
	_add_label(sheet, "AVI · BLOCK", Vector2(1410, 130), Vector2(430, 30), 18, INK)
	_add_actor_card(sheet, Vector2(1410, top), Vector2(430, 760), SUBJECTS[2], str(pass_spec.key), "body", "block")

	_add_label(sheet,
		"A deliberately tests the least change. B pushes silhouette. C keeps the successful structural changes at a quieter scale.",
		Vector2(60, 585), Vector2(850, 62), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(sheet,
		"Visible segmentation is retained: the question is whether each simple mass looks authored for its job.",
		Vector2(60, 660), Vector2(850, 62), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
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
		camera.size = 3.05 if pose == "block" else 2.28
		camera.look_at_from_position(
			Vector3(2.35, 1.42 if pose == "block" else 1.30, -4.65),
			Vector3(0.0, 1.35 if pose == "block" else 1.05, 0.0),
			Vector3.UP
		)
	camera.current = true


func _apply_body_variant(actor: Node, body_type: String, variant: String) -> void:
	if variant == "current":
		return
	if body_type in ["Feli", "Cani"]:
		_design_muzzle(actor, body_type, variant)
	elif body_type == "Avi":
		_design_integrated_wings(actor, variant)


func _design_muzzle(actor: Node, body_type: String, variant: String) -> void:
	var muzzle := actor.find_child("Muzzle", true, false) as MeshInstance3D
	if muzzle == null or muzzle.mesh == null:
		return
	var old_size := muzzle.mesh.get_aabb().size
	var crown_material := _material_from(muzzle)
	var head := actor.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var skin_material := _material_from(head) if head != null else crown_material
	var spec := _muzzle_spec(body_type, variant, old_size)
	var depth := float(spec.depth)
	var back_w := float(spec.back_w)
	var back_h := float(spec.back_h)
	var front_w := float(spec.front_w)
	var front_h := float(spec.front_h)

	muzzle.mesh = _front_tapered_prism(back_w, back_h, front_w, front_h, depth)
	## A is the minimal-change colour test. B/C let the species-defining shape do
	## the work instead of making a pale rectangular front read like exposed teeth.
	muzzle.material_override = crown_material if variant == "a" else skin_material
	_sync_ink_mesh(muzzle)
	muzzle.position.z -= (depth - old_size.z) * 0.5

	var face := actor.get_node_or_null("BodyPivot/Head/Face") as Node3D
	if face != null:
		for child in face.get_children():
			if str(child.name).begins_with("Mouth"):
				(child as Node3D).visible = false
	## Production grew a nose of its own after this study was written, and it is a
	## cosmetic under `BodyPivot` rather than a face feature under `Head/Face` --
	## so the loop above does not reach it and the study's dark bar was landing on
	## top of a live pale one. A variant column showing both proposals at once is
	## not a variant column.
	for grown in actor.find_children("Nose", "MeshInstance3D", true, false):
		(grown as MeshInstance3D).visible = false

	var nose := MeshInstance3D.new()
	nose.name = "StudyNose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(front_w * (0.43 if body_type == "Feli" else 0.37), front_h * 0.16, 0.014)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, front_h * 0.17, -depth * 0.5 - 0.008)
	nose.material_override = _material(FACE_DARK)
	muzzle.add_child(nose)

	var mouth := MeshInstance3D.new()
	mouth.name = "StudyMouth"
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(front_w * (0.60 if body_type == "Feli" else 0.54), 0.011, 0.012)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, -front_h * 0.20, -depth * 0.5 - 0.008)
	mouth.material_override = _material(FACE_DARK)
	muzzle.add_child(mouth)


func _muzzle_spec(body_type: String, variant: String, old_size: Vector3) -> Dictionary:
	var old_w := maxf(old_size.x, 0.16)
	var old_h := maxf(old_size.y, 0.11)
	var old_d := maxf(old_size.z, 0.13)
	if body_type == "Feli":
		match variant:
			"a":
				return {"back_w": old_w, "back_h": old_h * 0.80, "front_w": old_w * 0.72, "front_h": old_h * 0.60, "depth": old_d * 0.88}
			"b":
				return {"back_w": old_w * 1.08, "back_h": old_h * 0.74, "front_w": old_w * 0.62, "front_h": old_h * 0.50, "depth": old_d * 0.76}
			_:
				return {"back_w": old_w * 1.04, "back_h": old_h * 0.77, "front_w": old_w * 0.67, "front_h": old_h * 0.55, "depth": old_d * 0.81}
	else:
		match variant:
			"a":
				return {"back_w": old_w * 0.98, "back_h": old_h * 0.82, "front_w": old_w * 0.68, "front_h": old_h * 0.60, "depth": old_d * 1.12}
			"b":
				return {"back_w": old_w * 0.92, "back_h": old_h * 0.75, "front_w": old_w * 0.54, "front_h": old_h * 0.48, "depth": old_d * 1.36}
			_:
				return {"back_w": old_w * 0.95, "back_h": old_h * 0.78, "front_w": old_w * 0.60, "front_h": old_h * 0.53, "depth": old_d * 1.25}


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
		if variant == "a":
			upper_wing.mesh = _vertical_tapered_prism(
				float(spec.thickness), float(spec.thickness) * 0.92,
				float(spec.upper_top_depth), float(spec.upper_bottom_depth), float(spec.upper_length)
			)
		else:
			upper_wing.mesh = _upper_wing_profile(spec)
		upper_wing.position = Vector3(0.0, -float(spec.upper_length) * 0.47, 0.0)
		upper_wing.material_override = material
		arm.add_child(upper_wing)

		var lower_wing := MeshInstance3D.new()
		lower_wing.name = "StudyLowerWing"
		if variant == "a":
			lower_wing.mesh = _vertical_tapered_prism(
				float(spec.thickness) * 0.94, float(spec.tip_thickness),
				float(spec.lower_top_depth), float(spec.lower_bottom_depth), float(spec.lower_length)
			)
		else:
			lower_wing.mesh = _lower_wing_profile(spec)
		lower_wing.position = Vector3(0.0, -float(spec.lower_length) * 0.46, 0.0)
		lower_wing.material_override = material
		elbow.add_child(lower_wing)

		var fold := MeshInstance3D.new()
		fold.name = "StudyWingFold"
		var fold_mesh := SphereMesh.new()
		fold_mesh.radius = float(spec.lower_top_depth) * 0.20
		fold_mesh.height = float(spec.lower_top_depth) * 0.31
		fold_mesh.radial_segments = 8
		fold_mesh.rings = 4
		fold.mesh = fold_mesh
		fold.scale = Vector3(0.46, 0.66, 1.0)
		fold.material_override = material
		elbow.add_child(fold)


func _wing_spec(variant: String) -> Dictionary:
	match variant:
		"a":
			return {
				"thickness": 0.070, "tip_thickness": 0.040,
				"upper_length": 0.43, "upper_top_depth": 0.18, "upper_mid_depth": 0.24, "upper_bottom_depth": 0.29,
				"lower_length": 0.47, "lower_top_depth": 0.29, "lower_mid_depth": 0.23, "lower_bottom_depth": 0.14,
			}
		"b":
			return {
				"thickness": 0.078, "tip_thickness": 0.032,
				"upper_length": 0.45, "upper_top_depth": 0.18, "upper_mid_depth": 0.34, "upper_bottom_depth": 0.36,
				"lower_length": 0.51, "lower_top_depth": 0.36, "lower_mid_depth": 0.29, "lower_bottom_depth": 0.055,
			}
		_:
			return {
				"thickness": 0.073, "tip_thickness": 0.034,
				"upper_length": 0.44, "upper_top_depth": 0.18, "upper_mid_depth": 0.30, "upper_bottom_depth": 0.32,
				"lower_length": 0.49, "lower_top_depth": 0.32, "lower_mid_depth": 0.25, "lower_bottom_depth": 0.070,
			}


## Six-point convex side profile, extruded only enough to preserve the existing
## solid/constructed language. The shoulder root is narrow and the lower end
## broadens into the elbow, so it reads as a wing root rather than a board.
func _upper_wing_profile(spec: Dictionary) -> ArrayMesh:
	var length := float(spec.upper_length)
	var top_d := float(spec.upper_top_depth)
	var mid_d := float(spec.upper_mid_depth)
	var bottom_d := float(spec.upper_bottom_depth)
	var points: Array[Vector2] = [
		Vector2(length * 0.5, -top_d * 0.50),
		Vector2(length * 0.5, top_d * 0.50),
		Vector2(0.02, mid_d * 0.56),
		Vector2(-length * 0.5, bottom_d * 0.45),
		Vector2(-length * 0.5, -bottom_d * 0.45),
		Vector2(0.02, -mid_d * 0.48),
	]
	return _extruded_yz_polygon(points, float(spec.thickness))


## The lower segment starts broad at the elbow and resolves to a blunt point at
## the hand. No detached feather plates: the single polygon is the forearm wing.
func _lower_wing_profile(spec: Dictionary) -> ArrayMesh:
	var length := float(spec.lower_length)
	var top_d := float(spec.lower_top_depth)
	var mid_d := float(spec.lower_mid_depth)
	var bottom_d := float(spec.lower_bottom_depth)
	var points: Array[Vector2] = [
		Vector2(length * 0.5, -top_d * 0.48),
		Vector2(length * 0.5, top_d * 0.48),
		Vector2(0.04, mid_d * 0.58),
		Vector2(-length * 0.5, bottom_d * 0.48),
		Vector2(-length * 0.5, -bottom_d * 0.48),
		Vector2(0.04, -mid_d * 0.42),
	]
	return _extruded_yz_polygon(points, float(spec.thickness) * 0.94)


func _extruded_yz_polygon(points: Array[Vector2], thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_x := -thickness * 0.5
	var right_x := thickness * 0.5
	## Front/back caps. The profile is convex, so a fan is stable and keeps the
	## study mesh deliberately low-complexity.
	for index in range(1, points.size() - 1):
		_add_vertex(st, left_x, points[0])
		_add_vertex(st, left_x, points[index + 1])
		_add_vertex(st, left_x, points[index])
		_add_vertex(st, right_x, points[0])
		_add_vertex(st, right_x, points[index])
		_add_vertex(st, right_x, points[index + 1])
	## Perimeter walls.
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		_add_vertex(st, left_x, points[index])
		_add_vertex(st, right_x, points[index])
		_add_vertex(st, right_x, points[next])
		_add_vertex(st, left_x, points[index])
		_add_vertex(st, right_x, points[next])
		_add_vertex(st, left_x, points[next])
	st.generate_normals()
	return st.commit()


func _add_vertex(st: SurfaceTool, x: float, point: Vector2) -> void:
	st.add_vertex(Vector3(x, point.x, point.y))


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


func _sync_ink_mesh(feature: MeshInstance3D) -> void:
	var ink := feature.get_node_or_null("Ink") as MeshInstance3D
	if ink != null:
		ink.mesh = feature.mesh


func _material_from(source: MeshInstance3D) -> Material:
	if source == null:
		return _material(Color("c98f4e"))
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
