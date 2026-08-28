extends Node
## Final screen-space calibration for the seated 3D Desk.
## Historical DeskScreen is composition authority; the room is spatial authority.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null:
		return

	# Pass 3 settles between Pass 1's room-survey angle and Pass 2's near-plan
	# view. Keep the desktop dominant while restoring a useful wall band, window,
	# calendar and the lamp's side silhouette. Freeze this camera after review.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.70, -0.66)
	desk_camera.fov = 53.5
	desk_camera.look_at(Vector3(1.05, 0.82, -1.53), Vector3.UP)

	# Screen-space hierarchy: broad scouting at far left, vertical training left-
	# centre, journal as the dominant centre-right anchor, secondary documents
	# lower/near, communications stacked at far right.
	_place(office, "Journal", Vector3(1.25, 0.84, -1.53), Vector3(0.58, 0.045, 0.35), -3.0)
	_place(office, "JournalPageEdge", Vector3(1.25, 0.864, -1.53), Vector3(0.55, 0.010, 0.322), -3.0)
	_place(office, "TrainingClipboard", Vector3(0.70, 0.855, -1.47), Vector3(0.43, 0.030, 0.38), 7.0)
	_place(office, "ClipboardClip", Vector3(0.66, 0.88, -1.62), Vector3(0.12, 0.030, 0.055), 7.0)
	_place(office, "ScoutingBoard", Vector3(0.34, 0.84, -1.38), Vector3(0.51, 0.030, 0.39), 3.0)
	_place(office, "HousingFolder", Vector3(0.82, 0.84, -1.20), Vector3(0.46, 0.030, 0.30), -5.0)
	_place(office, "MealPad", Vector3(1.29, 0.84, -1.17), Vector3(0.39, 0.025, 0.27), 8.0)

	_place(office, "PhoneBase", Vector3(1.73, 0.88, -1.61), Vector3(0.34, 0.14, 0.22), -5.0)
	_place(office, "PhoneHandset", Vector3(1.73, 0.985, -1.61), Vector3(0.37, 0.065, 0.09), -5.0)
	_place(office, "AnsweringMachine", Vector3(1.74, 0.87, -1.34), Vector3(0.34, 0.12, 0.19), 4.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null:
		machine_light.position = Vector3(1.61, 0.93, -1.26)

	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.50, 0.92, -1.46)
		mug.scale = Vector3(1.15, 1.15, 1.15)

	var book_positions := [
		Vector3(0.43, 0.84, -1.72),
		Vector3(0.75, 0.84, -1.72),
		Vector3(0.77, 0.882, -1.71),
		Vector3(0.81, 0.920, -1.70),
	]
	var book_sizes := [
		Vector3(0.29, 0.042, 0.19),
		Vector3(0.39, 0.048, 0.23),
		Vector3(0.30, 0.048, 0.175),
		Vector3(0.25, 0.042, 0.155),
	]
	var book_yaws := [6.0, -5.0, 10.0, -9.0]
	for i in 4:
		var book := office.find_child("ReferenceBook%02d" % i, true, false) as Node3D
		if book != null:
			book.position = book_positions[i]
			_set_box_size(book, book_sizes[i])
			book.rotation_degrees = Vector3(0, book_yaws[i], 0)

	# Lamp remains the vertical bridge between desktop and wall, but Pass 3 backs
	# off the Pass-2 scale so the articulated side silhouette reads again.
	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(1.02, 0.88, -1.79)
		lamp_base.scale = Vector3(1.20, 1.15, 1.20)
	if lamp_stem != null:
		lamp_stem.position = Vector3(1.00, 1.15, -1.79)
		lamp_stem.scale = Vector3(1.15, 1.34, 1.15)
		lamp_stem.rotation_degrees = Vector3(0, 0, -19)
	if lamp_shade != null:
		lamp_shade.position = Vector3(1.13, 1.39, -1.78)
		lamp_shade.scale = Vector3(1.35, 1.25, 1.25)

	var cup := office.find_child("PencilCup", true, false) as Node3D
	if cup != null:
		cup.position = Vector3(0.24, 0.92, -1.74)
	for i in 3:
		var pencil := office.find_child("Pencil%02d" % i, true, false) as Node3D
		if pencil != null:
			pencil.position.x -= 0.20

func _place(office: Node3D, node_name: String, pos: Vector3, size: Vector3, yaw: float) -> void:
	var node := office.find_child(node_name, true, false) as Node3D
	if node == null:
		return
	node.position = pos
	node.rotation_degrees = Vector3(0, yaw, 0)
	_set_box_size(node, size)

func _set_box_size(node: Node3D, size: Vector3) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is BoxMesh:
			var box := (mesh as BoxMesh).duplicate() as BoxMesh
			box.size = size
			(node as MeshInstance3D).mesh = box
