extends Node
## Screen-space calibration for the seated 3D Desk.
## Historical DeskScreen is composition authority; the room is spatial authority.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null:
		return

	# Pass 2: prioritize the old screenshot's major masses. The eye is higher and
	# closer to the near edge, looking steeply down; wall/window become context
	# instead of the focal plane. A slightly narrower FOV gives the desk a broad,
	# deliberate interface footprint rather than a room-survey look.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.82, -0.73)
	desk_camera.fov = 51.0
	desk_camera.look_at(Vector3(1.05, 0.76, -1.47), Vector3.UP)

	# Functional objects retain the historical 140x70 desk-space topology, but
	# are deliberately oversized for screen readability. This is an interface
	# disguised as a physical desk, not an architectural scale study.
	_place(office, "Journal", Vector3(1.20, 0.84, -1.51), Vector3(0.56, 0.040, 0.32), -3.0)
	_place(office, "JournalPageEdge", Vector3(1.20, 0.861, -1.51), Vector3(0.53, 0.009, 0.295), -3.0)
	_place(office, "TrainingClipboard", Vector3(0.69, 0.855, -1.43), Vector3(0.46, 0.030, 0.35), 8.0)
	_place(office, "ClipboardClip", Vector3(0.65, 0.88, -1.57), Vector3(0.12, 0.030, 0.055), 8.0)
	_place(office, "ScoutingBoard", Vector3(0.35, 0.84, -1.34), Vector3(0.50, 0.030, 0.39), 4.0)
	_place(office, "HousingFolder", Vector3(0.82, 0.84, -1.18), Vector3(0.48, 0.030, 0.31), -5.0)
	_place(office, "MealPad", Vector3(1.27, 0.84, -1.14), Vector3(0.40, 0.025, 0.28), 9.0)

	# Communications remain a strong far-right cluster, matching the old screen.
	_place(office, "PhoneBase", Vector3(1.72, 0.88, -1.58), Vector3(0.34, 0.14, 0.22), -5.0)
	_place(office, "PhoneHandset", Vector3(1.72, 0.985, -1.58), Vector3(0.37, 0.065, 0.09), -5.0)
	_place(office, "AnsweringMachine", Vector3(1.73, 0.87, -1.31), Vector3(0.34, 0.12, 0.19), 4.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null:
		machine_light.position = Vector3(1.60, 0.93, -1.23)

	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.49, 0.92, -1.44)
		mug.scale = Vector3(1.20, 1.20, 1.20)

	# Historical low book pile, with enough mass to survive the steeper camera.
	var book_positions := [
		Vector3(0.43, 0.84, -1.69),
		Vector3(0.74, 0.84, -1.70),
		Vector3(0.76, 0.885, -1.69),
		Vector3(0.80, 0.925, -1.68),
	]
	var book_sizes := [
		Vector3(0.30, 0.045, 0.20),
		Vector3(0.40, 0.050, 0.24),
		Vector3(0.31, 0.050, 0.18),
		Vector3(0.26, 0.045, 0.16),
	]
	var book_yaws := [6.0, -5.0, 10.0, -9.0]
	for i in 4:
		var book := office.find_child("ReferenceBook%02d" % i, true, false) as Node3D
		if book != null:
			book.position = book_positions[i]
			_set_box_size(book, book_sizes[i])
			book.rotation_degrees = Vector3(0, book_yaws[i], 0)

	# Lamp is the historical vertical anchor: deliberately larger/taller than a
	# literal scale model so its silhouette bridges desktop and wall.
	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(1.03, 0.88, -1.78)
		lamp_base.scale = Vector3(1.30, 1.20, 1.30)
	if lamp_stem != null:
		lamp_stem.position = Vector3(1.03, 1.16, -1.78)
		lamp_stem.scale = Vector3(1.20, 1.45, 1.20)
		lamp_stem.rotation_degrees = Vector3(0, 0, -14)
	if lamp_shade != null:
		lamp_shade.position = Vector3(1.12, 1.43, -1.77)
		lamp_shade.scale = Vector3(1.45, 1.35, 1.35)

	# Supporting pencil cup stays peripheral.
	var cup := office.find_child("PencilCup", true, false) as Node3D
	if cup != null:
		cup.position = Vector3(0.24, 0.92, -1.73)
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
