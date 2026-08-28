extends Node
## Screen-space registration for the seated 3D Desk.
## Historical DeskScreen is composition authority; room geometry remains spatial authority.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null:
		return

	# 1. Camera: restore the historical wall band and put the rear desk edge near
	# y=230 at 1280x720 instead of centering the optical axis on the tabletop.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.62, -0.50)
	desk_camera.fov = 55.0
	desk_camera.look_at(Vector3(1.05, 1.02, -1.58), Vector3.UP)

	# 2. Wall anchors. The window is intentionally oversized: Desk mode crops it
	# like the historical interface while OfficeWide still reveals the real room.
	_place(office, "WindowGlass", Vector3(0.22, 1.70, -1.936), Vector3(1.34, 0.88, 0.025), 0.0)
	_scale_named(office, ["WindowTop", "WindowBottom", "WindowMullionH"], Vector3(1.24, 1.0, 1.0))
	_move_named(office, ["WindowGlass", "WindowTop", "WindowBottom", "WindowLeft", "WindowRight", "WindowMullionV", "WindowMullionH"], Vector3(-0.13, 0.06, 0.0), true)
	var calendar := office.find_child("CalendarBacking", true, false) as Node3D
	if calendar != null:
		var delta := Vector3(0.08, 0.06, 0.0)
		_move_named(office, ["CalendarBacking", "CalendarHeader", "CalendarMark"], delta, false)
		for i in 6: _move_named(office, ["CalendarRow%02d" % i], delta, false)
		for i in 5: _move_named(office, ["CalendarCol%02d" % i], delta, false)

	# 3. Lamp: left of centre, with shade and base separated vertically in screen
	# space. It is the bridge between wall context and working surface.
	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(0.91, 0.88, -1.80)
		lamp_base.scale = Vector3(1.25, 1.15, 1.25)
	if lamp_stem != null:
		lamp_stem.position = Vector3(0.91, 1.17, -1.80)
		lamp_stem.scale = Vector3(1.18, 1.40, 1.18)
		lamp_stem.rotation_degrees = Vector3(0, 0, -20)
	if lamp_shade != null:
		lamp_shade.position = Vector3(1.02, 1.45, -1.79)
		lamp_shade.scale = Vector3(1.48, 1.32, 1.32)

	# 4. Journal: dominant centre-right anchor. Move back/right so its projected
	# footprint rises toward historical x~560-875, y~305-505.
	_place(office, "Journal", Vector3(1.43, 0.84, -1.64), Vector3(0.60, 0.050, 0.36), -3.0)
	_place(office, "JournalPageEdge", Vector3(1.43, 0.867, -1.64), Vector3(0.56, 0.011, 0.326), -3.0)

	# 5. Training: vertical left-centre anchor.
	_place(office, "TrainingClipboard", Vector3(0.72, 0.855, -1.58), Vector3(0.42, 0.030, 0.40), 7.0)
	_place(office, "ClipboardClip", Vector3(0.68, 0.88, -1.75), Vector3(0.12, 0.030, 0.055), 7.0)

	# 6. Scouting: broad far-left object, intentionally allowed to crop.
	_place(office, "ScoutingBoard", Vector3(0.25, 0.84, -1.48), Vector3(0.54, 0.030, 0.40), 3.0)

	# 7. Communications: retain the historical vertical right-side stack.
	_place(office, "PhoneBase", Vector3(1.79, 0.88, -1.66), Vector3(0.34, 0.14, 0.22), -5.0)
	_place(office, "PhoneHandset", Vector3(1.79, 0.985, -1.66), Vector3(0.37, 0.065, 0.09), -5.0)
	_place(office, "AnsweringMachine", Vector3(1.80, 0.87, -1.39), Vector3(0.34, 0.12, 0.19), 4.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null: machine_light.position = Vector3(1.67, 0.93, -1.31)

	# 8. Secondary material stays lower/nearer and visually subordinate.
	_place(office, "HousingFolder", Vector3(0.88, 0.84, -1.28), Vector3(0.39, 0.030, 0.255), -5.0)
	_place(office, "MealPad", Vector3(1.34, 0.84, -1.25), Vector3(0.33, 0.025, 0.23), 8.0)
	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.55, 0.92, -1.51)
		mug.scale = Vector3(1.10, 1.10, 1.10)

	var book_positions := [Vector3(0.42, 0.84, -1.73), Vector3(0.72, 0.84, -1.74), Vector3(0.75, 0.882, -1.73), Vector3(0.79, 0.920, -1.72)]
	var book_sizes := [Vector3(0.28, 0.042, 0.18), Vector3(0.36, 0.048, 0.21), Vector3(0.28, 0.048, 0.16), Vector3(0.23, 0.042, 0.145)]
	var book_yaws := [6.0, -5.0, 10.0, -9.0]
	for i in 4:
		var book := office.find_child("ReferenceBook%02d" % i, true, false) as Node3D
		if book != null:
			book.position = book_positions[i]
			_set_box_size(book, book_sizes[i])
			book.rotation_degrees = Vector3(0, book_yaws[i], 0)

	var cup := office.find_child("PencilCup", true, false) as Node3D
	if cup != null: cup.position = Vector3(0.22, 0.92, -1.75)
	for i in 3:
		var pencil := office.find_child("Pencil%02d" % i, true, false) as Node3D
		if pencil != null: pencil.position.x -= 0.22

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
