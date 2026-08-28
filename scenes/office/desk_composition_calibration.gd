extends Node
## Screen-space registration for the seated 3D Desk.
## Historical DeskScreen is composition authority; room geometry remains spatial authority.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null: return

	# Camera is now registered closely enough; object passes must not chase composition
	# by changing the view unless the desk/wall split itself regresses.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.62, -0.50)
	desk_camera.fov = 55.0
	desk_camera.look_at(Vector3(1.05, 1.02, -1.58), Vector3.UP)

	_place(office, "WindowGlass", Vector3(0.22, 1.70, -1.936), Vector3(1.34, 0.88, 0.025), 0.0)
	_scale_named(office, ["WindowTop", "WindowBottom", "WindowMullionH"], Vector3(1.24, 1.0, 1.0))
	_move_named(office, ["WindowGlass", "WindowTop", "WindowBottom", "WindowLeft", "WindowRight", "WindowMullionV", "WindowMullionH"], Vector3(-0.13, 0.06, 0.0), true)
	var delta := Vector3(-0.08, 0.01, 0.0)
	_move_named(office, ["CalendarBacking", "CalendarHeader", "CalendarMark"], delta, false)
	for i in 6: _move_named(office, ["CalendarRow%02d" % i], delta, false)
	for i in 5: _move_named(office, ["CalendarCol%02d" % i], delta, false)

	# Lamp has a dedicated back-centre patch. The broad historical shade silhouette
	# is restored without allowing the base to intersect papers/books.
	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(1.02, 0.88, -1.78)
		lamp_base.scale = Vector3(1.18, 1.12, 1.18)
	if lamp_stem != null:
		lamp_stem.position = Vector3(1.02, 1.17, -1.78)
		lamp_stem.scale = Vector3(1.15, 1.38, 1.15)
		lamp_stem.rotation_degrees = Vector3(0, 0, -20)
	if lamp_shade != null:
		lamp_shade.position = Vector3(1.13, 1.45, -1.77)
		lamp_shade.scale = Vector3(1.42, 1.28, 1.28)

	# Restore historical density through valid vertical layering. Flat documents may
	# overlap in plan when the upper object is physically above the lower one.
	# Journal is again the dominant working object, as in the historical DeskScreen.
	_place(office, "Journal", Vector3(1.34, 0.858, -1.50), Vector3(0.61, 0.050, 0.36), -4.0)
	_place(office, "JournalPageEdge", Vector3(1.34, 0.886, -1.50), Vector3(0.58, 0.011, 0.332), -4.0)
	_place(office, "TrainingClipboard", Vector3(0.70, 0.862, -1.48), Vector3(0.43, 0.030, 0.37), 7.0)
	_place(office, "ClipboardClip", Vector3(0.67, 0.887, -1.62), Vector3(0.12, 0.030, 0.050), 7.0)
	# Large scouting board sits diagonally at lower-left but remains inside desktop.
	_place(office, "ScoutingBoard", Vector3(0.37, 0.842, -1.30), Vector3(0.48, 0.030, 0.31), 10.0)

	# Communications form one compact cluster at the right edge rather than isolated boxes.
	_place(office, "PhoneBase", Vector3(1.70, 0.88, -1.62), Vector3(0.30, 0.14, 0.19), -5.0)
	_place(office, "PhoneHandset", Vector3(1.70, 0.985, -1.62), Vector3(0.32, 0.065, 0.08), -5.0)
	_place(office, "AnsweringMachine", Vector3(1.69, 0.87, -1.34), Vector3(0.30, 0.12, 0.17), 4.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null: machine_light.position = Vector3(1.58, 0.93, -1.28)

	# Housing/meal papers sit beneath the main working objects, giving historical
	# paper density without mesh intersections.
	_place(office, "HousingFolder", Vector3(0.88, 0.835, -1.25), Vector3(0.38, 0.026, 0.23), -5.0)
	_place(office, "MealPad", Vector3(1.28, 0.837, -1.19), Vector3(0.32, 0.020, 0.20), 8.0)

	# Mug is close to the journal/communications cluster but has genuine clearance.
	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.52, 0.92, -1.29)
		mug.scale = Vector3(1.0, 1.0, 1.0)

	# Back-left books form a loose stack. Keep them out of the lamp-base footprint.
	var book_positions := [Vector3(0.34, 0.84, -1.70), Vector3(0.54, 0.84, -1.71), Vector3(0.57, 0.882, -1.70), Vector3(0.60, 0.920, -1.69)]
	var book_sizes := [Vector3(0.20, 0.042, 0.14), Vector3(0.25, 0.048, 0.16), Vector3(0.21, 0.048, 0.13), Vector3(0.18, 0.042, 0.12)]
	var book_yaws := [6.0, -5.0, 10.0, -9.0]
	for i in 4:
		var book := office.find_child("ReferenceBook%02d" % i, true, false) as Node3D
		if book != null:
			book.position = book_positions[i]
			_set_box_size(book, book_sizes[i])
			book.rotation_degrees = Vector3(0, book_yaws[i], 0)

	var cup := office.find_child("PencilCup", true, false) as Node3D
	if cup != null: cup.position = Vector3(0.27, 0.92, -1.77)
	# Keep authored pencils centered on the moved cup; previous pass left them behind.
	for i in 3:
		var pencil := office.find_child("Pencil%02d" % i, true, false) as Node3D
		if pencil != null:
			pencil.position.x -= 0.17
			pencil.position.z = -1.77

func _place(office: Node3D, node_name: String, pos: Vector3, size: Vector3, yaw: float) -> void:
	var node := office.find_child(node_name, true, false) as Node3D
	if node == null: return
	node.position = pos
	node.rotation_degrees = Vector3(0, yaw, 0)
	_set_box_size(node, size)

func _move_named(office: Node3D, names: Array[String], delta: Vector3, skip_glass := false) -> void:
	for node_name in names:
		if skip_glass and node_name == "WindowGlass": continue
		var node := office.find_child(node_name, true, false) as Node3D
		if node != null: node.position += delta

func _scale_named(office: Node3D, names: Array[String], factor: Vector3) -> void:
	for node_name in names:
		var node := office.find_child(node_name, true, false) as Node3D
		if node != null: node.scale *= factor

func _set_box_size(node: Node3D, size: Vector3) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is BoxMesh:
			var box := (mesh as BoxMesh).duplicate() as BoxMesh
			box.size = size
			(node as MeshInstance3D).mesh = box
