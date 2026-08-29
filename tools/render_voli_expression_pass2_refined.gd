extends "res://tools/render_voli_expression_pass2.gd"
## Iteration 2 of the bounded expression study.
##
## Keeps the production rig and the pass-2 matrix harness intact, but pushes the
## four experimental directions after reviewing the first Godot render: brows
## read too lightly, sclera were too timid, and open mouths collapsed to dots at
## portrait size. This file only overrides those render-only construction rules.

const REFINED_OUTPUT_DIR := "res://artifacts/voli-expression-pass2-refined"
const REFINED_FACE_DARK := Color("0b1016")
const REFINED_SCLERA := Color("f0ecdf")
const REFINED_MOUTH_INNER := Color("8c3935")


func _save(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REFINED_OUTPUT_DIR))
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s" % [REFINED_OUTPUT_DIR, filename]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not write %s: %s" % [path, error_string(error)])
	else:
		print("VOLI_EXPRESSION_PASS2_REFINED ", path)


func _apply_eye_character(face: Node3D, eye_state: String, variant: String) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := face.get_node_or_null(eye_name) as MeshInstance3D
		if eye == null:
			continue
		var side := -1.0 if eye_name == "EyeL" else 1.0
		var y_scale := 1.0
		match eye_state:
			"full": y_scale = 1.12
			"half": y_scale = 0.94
			"flat": y_scale = 0.84
		var x_scale := 1.04 if side < 0.0 else 0.95
		if variant == "hybrid":
			x_scale = 1.10 if side < 0.0 else 0.91
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
		box.size = Vector3(
			bounds.x * (1.42 if strong else 1.30),
			maxf(bounds.y * (0.34 if strong else 0.29), bounds.x * 0.11),
			bounds.z * 0.70,
		)
		brow.mesh = box
		var lift := bounds.y * (0.92 if eye_state == "full" else 0.72)
		var asymmetric := bounds.y * (0.16 if side > 0.0 else 0.0)
		brow.position = eye.position + Vector3(0.0, lift - asymmetric, -bounds.z * 0.15)
		var angle := eye.rotation_degrees.z * (1.38 if strong else 1.18)
		match expression:
			"worried":
				## Inner ends climb: concern should read before the mouth does.
				angle += -18.0 * side
			"cross":
				angle += 16.0 * side
			"tired":
				angle += 8.0 * side
				brow.position.y -= bounds.y * 0.12
			"happy":
				angle *= 0.42
				brow.position.y += bounds.y * 0.08
			"relaxed":
				angle *= 0.28
				brow.position.y -= bounds.y * 0.04
			"devious":
				angle *= 1.18
				if side > 0.0:
					brow.position.y += bounds.y * 0.10
		brow.rotation_degrees.z = angle
		brow.material_override = _material(REFINED_FACE_DARK)
		face.add_child(brow)


func _add_sclera(face: Node3D, expression: String) -> void:
	for eye_name in ["EyeL", "EyeR"]:
		var eye := face.get_node_or_null(eye_name) as MeshInstance3D
		if eye == null or eye.mesh == null:
			continue
		var side := -1.0 if eye_name == "EyeL" else 1.0
		var size := eye.mesh.get_aabb().size
		var white := MeshInstance3D.new()
		white.name = "%sSclera" % eye_name
		var box := BoxMesh.new()
		var white_x := 1.56
		var white_y := 1.36
		var pupil_x := 0.48
		var pupil_y := 0.62
		match expression:
			"worried":
				## Bilateral white: this is the clearest 'something changed' state.
				white_x = 1.72
				white_y = 1.46
				pupil_x = 0.43
				pupil_y = 0.57
			"cross":
				## One eye flashes much more white, keeping the face constructed and
				## asymmetric rather than becoming a pair of cartoon eyeballs.
				if side < 0.0:
					white_x = 1.30
					white_y = 1.16
					pupil_x = 0.72
					pupil_y = 0.82
				else:
					white_x = 1.72
					white_y = 1.34
					pupil_x = 0.42
					pupil_y = 0.58
			"tired":
				white_x = 1.48 if side < 0.0 else 1.62
				white_y = 1.14
				pupil_x = 0.58 if side < 0.0 else 0.48
				pupil_y = 0.64
		box.size = Vector3(size.x * white_x, size.y * white_y, size.z * 0.55)
		white.mesh = box
		## Forward is -Z. The white sits a hair nearer the skull than the dark
		## pupil, so depth rather than child order decides the layering.
		white.position = eye.position + Vector3(0.0, 0.0, size.z * 0.12)
		white.rotation_degrees = eye.rotation_degrees
		white.material_override = _material(REFINED_SCLERA)
		face.add_child(white)
		eye.scale *= Vector3(pupil_x, pupil_y, 0.90)


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
	var width := max_x - min_x
	var centre := Vector3(
		(min_x + max_x) * 0.5,
		(min_y + max_y) * 0.5 - width * 0.025,
		z_sum / float(mouths.size()) - 0.008,
	)

	## Keep the authored curve at the corners for smile/frown vocabulary, and
	## replace only the middle with volume. That is the key difference from pass
	## one, where an open mouth erased the matrix's own mouth shape.
	for index in mouths.size():
		var preserve := false
		if expression in ["happy", "devious", "worried"]:
			preserve = index <= 1 or index >= mouths.size() - 2
		elif expression == "cross":
			preserve = index == 0 or index == mouths.size() - 1
		mouths[index].visible = preserve

	var cavity_size := Vector2(width, maxf(width * 0.30, 0.022))
	match expression:
		"happy":
			cavity_size = Vector2(width * 1.28, width * (0.52 if strong else 0.44))
		"worried":
			cavity_size = Vector2(width * 0.88, width * (0.78 if strong else 0.68))
		"devious":
			cavity_size = Vector2(width * 1.04, width * 0.30)
		"cross":
			cavity_size = Vector2(width * 1.16, width * (0.40 if strong else 0.34))
		"tired":
			cavity_size = Vector2(width * 0.88, width * (0.56 if strong else 0.48))

	var cavity := MeshInstance3D.new()
	cavity.name = "MouthCavity"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	cavity.mesh = sphere
	cavity.scale = Vector3(cavity_size.x, cavity_size.y, maxf(width * 0.13, 0.010))
	cavity.position = centre
	if expression == "devious":
		cavity.rotation_degrees.z = -8.0
		cavity.position.x += width * 0.04
	elif expression == "cross":
		cavity.rotation_degrees.z = 4.0
	cavity.material_override = _material(REFINED_FACE_DARK)
	face.add_child(cavity)

	if expression in ["happy", "worried", "tired"]:
		var inner := MeshInstance3D.new()
		inner.name = "MouthInner"
		var inner_sphere := SphereMesh.new()
		inner_sphere.radius = 0.5
		inner_sphere.height = 1.0
		inner_sphere.radial_segments = 10
		inner_sphere.rings = 5
		inner.mesh = inner_sphere
		inner.scale = Vector3(cavity_size.x * 0.56, cavity_size.y * 0.34, maxf(width * 0.06, 0.005))
		inner.position = centre + Vector3(0.0, -cavity_size.y * 0.23, -0.014)
		inner.material_override = _material(REFINED_MOUTH_INNER)
		face.add_child(inner)

	if expression == "cross":
		var teeth := MeshInstance3D.new()
		teeth.name = "MouthTeeth"
		var teeth_box := BoxMesh.new()
		teeth_box.size = Vector3(cavity_size.x * 0.70, cavity_size.y * 0.34, maxf(width * 0.055, 0.005))
		teeth.mesh = teeth_box
		teeth.position = centre + Vector3(0.0, cavity_size.y * 0.07, -0.015)
		teeth.rotation_degrees.z = 4.0
		teeth.material_override = _material(REFINED_SCLERA)
		face.add_child(teeth)
