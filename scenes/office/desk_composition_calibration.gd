extends Node
## Runtime calibration layer for the seated 3D Desk camera.
##
## The historical DeskScreen is the composition authority: its 140x70 cm desk
## already encoded deliberate object footprints and a 52-degree seated view.
## The canonical office remains spatial authority outside this crop. This layer
## translates those old desk-space placements into the real 3D desk rather than
## redesigning the working surface during the 2D -> 3D migration.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null:
		return

	# Reproduce the old screen's much steeper seated look. The previous 3D shot
	# was only ~21 degrees down and consequently spent almost half the frame on
	# wall. Historical DeskScreen's authored elevation is 52 degrees.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.62, -0.55)
	desk_camera.fov = 58.0
	desk_camera.look_at(Vector3(1.05, 0.78, -1.47), Vector3.UP)

	# Historical DeskScreen footprint centres translated from its 140x70 cm desk
	# into the modeled 1.78x0.76 m desktop. Y here is the top of the desk.
	_place(office, "Journal", Vector3(1.164, 0.84, -1.551), Vector3(0.483, 0.035, 0.271), -2.0)
	_place(office, "JournalPageEdge", Vector3(1.164, 0.856, -1.551), Vector3(0.455, 0.008, 0.248), -2.0)
	_place(office, "TrainingClipboard", Vector3(0.713, 0.855, -1.475), Vector3(0.394, 0.025, 0.293), 7.0)
	_place(office, "ClipboardClip", Vector3(0.675, 0.875, -1.585), Vector3(0.105, 0.025, 0.045), 7.0)
	_place(office, "ScoutingBoard", Vector3(0.421, 0.835, -1.410), Vector3(0.445, 0.025, 0.337), 2.0)
	_place(office, "HousingFolder", Vector3(0.847, 0.835, -1.291), Vector3(0.432, 0.025, 0.271), -4.0)
	_place(office, "MealPad", Vector3(1.215, 0.835, -1.242), Vector3(0.356, 0.020, 0.239), 8.0)

	_place(office, "PhoneBase", Vector3(1.711, 0.875, -1.698), Vector3(0.280, 0.12, 0.174), -4.0)
	_place(office, "PhoneHandset", Vector3(1.711, 0.965, -1.698), Vector3(0.305, 0.055, 0.070), -4.0)
	_place(office, "AnsweringMachine", Vector3(1.711, 0.86, -1.486), Vector3(0.305, 0.10, 0.141), 3.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null:
		machine_light.position = Vector3(1.59, 0.91, -1.43)

	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.476, 0.91, -1.595)

	# The old desk's books are a low stack under the lamp, not upright shelving.
	var books: Array[Node3D] = []
	for i in 4:
		var book := office.find_child("ReferenceBook%02d" % i, true, false) as Node3D
		if book != null:
			books.append(book)
	var book_positions := [
		Vector3(0.452, 0.84, -1.725),
		Vector3(0.758, 0.84, -1.725),
		Vector3(0.764, 0.875, -1.720),
		Vector3(0.805, 0.905, -1.705),
	]
	var book_sizes := [
		Vector3(0.254, 0.035, 0.163),
		Vector3(0.356, 0.040, 0.206),
		Vector3(0.267, 0.045, 0.152),
		Vector3(0.220, 0.035, 0.135),
	]
	var book_yaws := [5.0, -4.0, 9.0, -8.0]
	for i in books.size():
		books[i].position = book_positions[i]
		_set_box_size(books[i], book_sizes[i])
		books[i].rotation_degrees = Vector3(0, book_yaws[i], 0)

	# Lamp returns to the centre-back overlap that tied wall and desktop together.
	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(1.063, 0.87, -1.763)
	if lamp_stem != null:
		lamp_stem.position = Vector3(1.063, 1.10, -1.763)
		lamp_stem.rotation_degrees = Vector3(0, 0, -12)
	if lamp_shade != null:
		lamp_shade.position = Vector3(1.12, 1.31, -1.763)

	# Pencil cup was not part of the historical authority; keep it but tuck it
	# into unused far-left space so it does not displace a functional object.
	var cup := office.find_child("PencilCup", true, false) as Node3D
	if cup != null:
		cup.position = Vector3(0.25, 0.92, -1.76)
	for i in 3:
		var pencil := office.find_child("Pencil%02d" % i, true, false) as Node3D
		if pencil != null:
			pencil.position.x -= 0.19

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
			# Mesh resources can be shared; duplicate before calibration mutation.
			var box := (mesh as BoxMesh).duplicate() as BoxMesh
			box.size = size
			(node as MeshInstance3D).mesh = box
