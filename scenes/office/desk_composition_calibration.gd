extends Node
## Screen-space registration for the seated 3D Desk.
## Historical DeskScreen is composition authority; room geometry remains spatial authority.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent().get_node_or_null("CanonicalOfficeLowPoly") as Node3D
	if office == null: return

	# Camera locked after iteration 6.
	var desk_camera := office.get_node("Cameras/Desk") as Camera3D
	desk_camera.position = Vector3(1.05, 1.75, -0.65)
	desk_camera.fov = 53.5
	desk_camera.look_at(Vector3(1.05, 0.84, -1.53), Vector3.UP)

	_set_material(office.find_child("DeskTop", true, false), Color("3a2923"), 0.88)
	_set_material(office.find_child("DeskWall", true, false), Color("302e2e"), 0.97)

	# Window registration is frozen.
	_place(office, "WindowGlass", Vector3(0.62, 1.58, -1.936), Vector3(0.95, 0.88, 0.025), 0.0)
	_scale_named(office, ["WindowTop", "WindowBottom", "WindowMullionH"], Vector3(0.92, 1.0, 1.0))
	_move_named(office, ["WindowGlass", "WindowTop", "WindowBottom", "WindowLeft", "WindowRight", "WindowMullionV", "WindowMullionH"], Vector3(0.27, -0.08, 0.0), true)

	# Calendar is explicit rather than accumulated from relative transforms.
	# Measured from iteration 14: target historical footprint ~284x131 px.
	var wall_z := -1.943
	_place(office, "CalendarBacking", Vector3(1.465, 1.24, wall_z), Vector3(0.59, 0.43, 0.045), 0.0)
	_place(office, "CalendarHeader", Vector3(1.465, 1.415, wall_z - 0.028), Vector3(0.59, 0.075, 0.025), 0.0)
	for i in 6:
		_place(office, "CalendarRow%02d" % i, Vector3(1.465, 1.315 - float(i) * 0.052, wall_z - 0.03), Vector3(0.52, 0.010, 0.018), 0.0)
	for i in 5:
		_place(office, "CalendarCol%02d" % i, Vector3(1.255 + float(i) * 0.105, 1.185, wall_z - 0.03), Vector3(0.009, 0.255, 0.018), 0.0)
	var calendar_mark := office.find_child("CalendarMark", true, false) as Node3D
	if calendar_mark != null: calendar_mark.position = Vector3(1.36, 1.255, wall_z - 0.05)
	_set_material(office.find_child("CalendarBacking", true, false), Color("4d4a43"), 0.96)
	_set_material(office.find_child("CalendarHeader", true, false), Color("26272a"), 0.94)
	for i in 6: _set_material(office.find_child("CalendarRow%02d" % i, true, false), Color("777269"), 0.96)
	for i in 5: _set_material(office.find_child("CalendarCol%02d" % i, true, false), Color("777269"), 0.96)

	var lamp_base := office.find_child("LampBase", true, false) as Node3D
	var lamp_stem := office.find_child("LampStem", true, false) as Node3D
	var lamp_shade := office.find_child("LampShade", true, false) as Node3D
	if lamp_base != null:
		lamp_base.position = Vector3(1.02, 0.88, -1.78)
		lamp_base.scale = Vector3(1.18, 1.12, 1.18)
	if lamp_stem != null: lamp_stem.visible = false
	if lamp_shade != null: lamp_shade.visible = false
	_detail_box_rot(office, "DeskLampUpright", Vector3(1.02, 1.15, -1.78), Vector3(0.035, 0.45, 0.035), Color("343b42"), Vector3.ZERO)
	_detail_frustum(office, "DeskLampJoint", Vector3(1.02, 1.36, -1.78), 0.040, 0.040, 0.032, Color("343b42"), Vector3(90, 0, 0), false)
	_detail_box_rot(office, "DeskLampArm", Vector3(0.92, 1.33, -1.78), Vector3(0.24, 0.030, 0.030), Color("343b42"), Vector3(0, 0, -10))
	_detail_frustum(office, "DeskLampShadeDetailed", Vector3(0.82, 1.24, -1.77), 0.08, 0.15, 0.15, Color("20252b"), Vector3(0, 0, -6), false)
	_detail_frustum(office, "DeskLampGlow", Vector3(0.82, 1.165, -1.765), 0.082, 0.115, 0.010, Color("e7c28f"), Vector3(0, 0, -6), true)

	_place(office, "Journal", Vector3(1.23, 0.858, -1.45), Vector3(0.62, 0.050, 0.40), -4.0)
	_set_material(office.find_child("Journal", true, false), Color("203f54"), 0.93)
	_place(office, "JournalPageEdge", Vector3(1.23, 0.887, -1.265), Vector3(0.57, 0.011, 0.028), -4.0)
	_place(office, "TrainingClipboard", Vector3(0.70, 0.862, -1.38), Vector3(0.43, 0.030, 0.39), 7.0)
	_place(office, "ClipboardClip", Vector3(0.67, 0.887, -1.53), Vector3(0.12, 0.030, 0.050), 7.0)
	_place(office, "ScoutingBoard", Vector3(0.43, 0.842, -1.30), Vector3(0.48, 0.030, 0.31), 10.0)

	_place(office, "PhoneBase", Vector3(1.70, 0.88, -1.62), Vector3(0.30, 0.14, 0.19), -5.0)
	_place(office, "PhoneHandset", Vector3(1.70, 0.985, -1.62), Vector3(0.32, 0.065, 0.08), -5.0)
	_place(office, "AnsweringMachine", Vector3(1.69, 0.87, -1.34), Vector3(0.30, 0.12, 0.17), 4.0)
	var machine_light := office.find_child("MachineLight", true, false) as Node3D
	if machine_light != null: machine_light.position = Vector3(1.58, 0.93, -1.28)

	_place(office, "HousingFolder", Vector3(0.46, 0.835, -1.69), Vector3(0.31, 0.026, 0.24), -5.0)
	_set_material(office.find_child("HousingFolder", true, false), Color("344b3e"), 0.94)
	_place(office, "MealPad", Vector3(1.20, 0.837, -1.205), Vector3(0.28, 0.020, 0.18), 8.0)

	var mug := office.find_child("Mug", true, false) as Node3D
	if mug != null:
		mug.position = Vector3(1.51, 0.92, -1.43)
		mug.scale = Vector3(1.0, 1.0, 1.0)
		_set_material(mug, Color("61706a"), 0.90)
	_detail_frustum(office, "MugCoffee", Vector3(1.51, 0.981, -1.43), 0.047, 0.047, 0.006, Color("4b2d1d"), Vector3.ZERO, false)
	_detail_box(office, "MugHandleTop", Vector3(1.568, 0.955, -1.43), Vector3(0.045, 0.012, 0.012), Color("61706a"), 0.0)
	_detail_box(office, "MugHandleSide", Vector3(1.590, 0.925, -1.43), Vector3(0.012, 0.070, 0.012), Color("61706a"), 0.0)
	_detail_box(office, "MugHandleBottom", Vector3(1.568, 0.895, -1.43), Vector3(0.045, 0.012, 0.012), Color("61706a"), 0.0)

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
	for i in 3:
		var pencil := office.find_child("Pencil%02d" % i, true, false) as Node3D
		if pencil != null:
			pencil.position.x -= 0.17
			pencil.position.z = -1.77

	_add_working_details(office)

func _add_working_details(office: Node3D) -> void:
	_detail_frustum(office, "JournalEmblem", Vector3(1.06, 0.889, -1.54), 0.050, 0.050, 0.005, Color("758995"), Vector3.ZERO, false)
	for i in 3:
		_detail_box(office, "JournalLine%02d" % i, Vector3(1.28, 0.890, -1.555 + float(i) * 0.035), Vector3(0.20 - float(i) * 0.025, 0.005, 0.006), Color("71818a"), -4.0)
	for i in 5:
		_detail_box(office, "TrainingRule%02d" % i, Vector3(0.70, 0.880, -1.45 + float(i) * 0.055), Vector3(0.28, 0.004, 0.005), Color("62696b"), 7.0)
	var slip_positions := [Vector3(0.31, 0.861, -1.34), Vector3(0.49, 0.861, -1.31), Vector3(0.34, 0.861, -1.21), Vector3(0.53, 0.861, -1.19)]
	for i in 4:
		_detail_box(office, "ScoutingSlip%02d" % i, slip_positions[i], Vector3(0.13, 0.008, 0.075), Color("aaa69c"), 10.0)
		_detail_frustum(office, "ScoutingPin%02d" % i, slip_positions[i] + Vector3(-0.045, 0.008, -0.020), 0.010, 0.010, 0.006, Color("713f3d") if i % 2 == 0 else Color("4c755b"), Vector3.ZERO, false)
	for row in 3:
		for col in 3:
			_detail_box(office, "PhoneKey%d%d" % [row, col], Vector3(1.645 + float(col) * 0.035, 0.953, -1.575 + float(row) * 0.027), Vector3(0.018, 0.006, 0.014), Color("777f83"), -5.0)
	for i in 4:
		_detail_box(office, "MachineSpeaker%02d" % i, Vector3(1.68 + float(i) * 0.028, 0.936, -1.34), Vector3(0.014, 0.006, 0.055), Color("161a1e"), 4.0)

func _detail_box(parent: Node3D, name_: String, pos: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	_detail_box_rot(parent, name_, pos, size, color, Vector3(0, yaw, 0))

func _detail_box_rot(parent: Node3D, name_: String, pos: Vector3, size: Vector3, color: Color, rot: Vector3) -> void:
	var n := MeshInstance3D.new(); n.name = name_
	var mesh := BoxMesh.new(); mesh.size = size; n.mesh = mesh
	n.position = pos; n.rotation_degrees = rot
	n.material_override = _new_material(color, 0.92, false)
	parent.add_child(n)

func _detail_frustum(parent: Node3D, name_: String, pos: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color, rot: Vector3, emissive: bool) -> void:
	var n := MeshInstance3D.new(); n.name = name_
	var mesh := CylinderMesh.new(); mesh.top_radius = top_radius; mesh.bottom_radius = bottom_radius; mesh.height = height; mesh.radial_segments = 12; n.mesh = mesh
	n.position = pos; n.rotation_degrees = rot
	n.material_override = _new_material(color, 0.78, emissive)
	parent.add_child(n)

func _new_material(color: Color, roughness: float, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = roughness
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.35
	return m

func _set_material(node: Node, color: Color, roughness: float) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _new_material(color, roughness, false)

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
