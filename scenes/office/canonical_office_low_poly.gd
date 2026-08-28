extends Node3D
## First modeled pass of the canonical office-bedroom.
## This replaces greybox cubes with simple low-poly furniture while preserving
## the same spatial authority and camera contract.

const ROOM_W := 4.8
const ROOM_D := 4.0
const ROOM_H := 2.6

var _mats: Dictionary = {}

func _ready() -> void:
	_build_materials()
	_build_architecture()
	_build_window()
	_build_desk_zone()
	_build_sleep_zone()
	_build_guest_chair()
	_build_wall_state()
	_build_cameras()

func _mat(key: String, color: Color, roughness := 0.78, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mats[key] = m
	return m

func _build_materials() -> void:
	# Muted dark-theme palette: preserve material separation without the bright,
	# warm room wash that made the 3D Desk diverge from the historical UI.
	_mat("floor", Color("342d2a"), 0.88)
	_mat("floor_alt", Color("403630"), 0.88)
	_mat("wall", Color("55534f"), 0.96)
	_mat("wall_left", Color("454649"), 0.96)
	_mat("trim", Color("3b302b"), 0.84)
	_mat("wood", Color("49362e"), 0.82)
	_mat("wood_light", Color("60483a"), 0.82)
	_mat("wood_dark", Color("2e2522"), 0.86)
	_mat("fabric", Color("55565a"), 0.98)
	_mat("fabric_light", Color("85837e"), 0.98)
	_mat("fabric_dark", Color("20252b"), 0.96)
	_mat("paper", Color("aaa69c"), 0.97)
	_mat("paper_alt", Color("77736a"), 0.97)
	_mat("ink", Color("171b20"), 0.92)
	_mat("metal", Color("343b42"), 0.48, 0.10)
	_mat("glass", Color("415866"), 0.28)
	_mat("archive", Color("69553f"), 0.94)
	_mat("frame", Color("302824"), 0.84)
	_mat("photo_a", Color("5f584f"), 0.94)
	_mat("photo_b", Color("4d5b5d"), 0.94)
	_mat("accent", Color("8b743e"), 0.70)
	_mat("red", Color("713f3d"), 0.88)
	_mat("blue", Color("344c5b"), 0.90)

func _box(parent: Node3D, name_: String, pos: Vector3, size: Vector3, mat_key: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.name = name_
	var mesh := BoxMesh.new(); mesh.size = size; n.mesh = mesh
	n.position = pos; n.rotation_degrees = rot; n.material_override = _mats[mat_key]
	parent.add_child(n); return n

func _cyl(parent: Node3D, name_: String, pos: Vector3, radius: float, height: float, mat_key: String, rot := Vector3.ZERO, segments := 8) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.name = name_
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = segments; n.mesh = mesh
	n.position = pos; n.rotation_degrees = rot; n.material_override = _mats[mat_key]
	parent.add_child(n); return n

func _sphere(parent: Node3D, name_: String, pos: Vector3, radius: float, mat_key: String) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.name = name_
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2.0; mesh.radial_segments = 8; mesh.rings = 4; n.mesh = mesh
	n.position = pos; n.material_override = _mats[mat_key]; parent.add_child(n); return n

func _build_architecture() -> void:
	var root := Node3D.new(); root.name = "Architecture"; add_child(root)
	_box(root, "Floor", Vector3(0, -0.055, 0), Vector3(ROOM_W, 0.11, ROOM_D), "floor")
	for i in 12:
		var x := -2.2 + float(i) * 0.4
		_box(root, "FloorPlank%02d" % i, Vector3(x, 0.006, 0), Vector3(0.015, 0.012, ROOM_D), "floor_alt")
	_box(root, "DeskWall", Vector3(0, ROOM_H * 0.5, -ROOM_D * 0.5), Vector3(ROOM_W, ROOM_H, 0.08), "wall")
	_box(root, "LeftWall", Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, -0.25), Vector3(0.08, ROOM_H, 3.5), "wall_left")
	_box(root, "RightWall", Vector3(ROOM_W * 0.5, ROOM_H * 0.5, -0.25), Vector3(0.08, ROOM_H, 3.5), "wall")
	_box(root, "BackBaseboard", Vector3(0, 0.055, -1.945), Vector3(4.72, 0.11, 0.055), "trim")
	_box(root, "LeftBaseboard", Vector3(-2.355, 0.055, -0.25), Vector3(0.055, 0.11, 3.42), "trim")
	_box(root, "RightBaseboard", Vector3(2.355, 0.055, -0.25), Vector3(0.055, 0.11, 3.42), "trim")
	_box(root, "Door", Vector3(2.34, 1.02, 1.02), Vector3(0.10, 1.98, 0.82), "wood")
	_box(root, "DoorFrameTop", Vector3(2.29, 2.05, 1.02), Vector3(0.10, 0.10, 1.00), "trim")
	_box(root, "DoorFrameNear", Vector3(2.29, 1.02, 0.55), Vector3(0.10, 2.08, 0.10), "trim")
	_box(root, "DoorFrameFar", Vector3(2.29, 1.02, 1.49), Vector3(0.10, 2.08, 0.10), "trim")
	_sphere(root, "DoorKnob", Vector3(2.25, 1.02, 1.30), 0.055, "metal")

func _build_window() -> void:
	var root := Node3D.new(); root.name = "WindowZone"; add_child(root)
	var z := -1.944
	_box(root, "WindowGlass", Vector3(0.35, 1.64, z + 0.008), Vector3(1.00, 0.82, 0.025), "glass")
	_box(root, "WindowTop", Vector3(0.35, 2.08, z), Vector3(1.12, 0.07, 0.07), "trim")
	_box(root, "WindowBottom", Vector3(0.35, 1.20, z), Vector3(1.12, 0.08, 0.08), "trim")
	_box(root, "WindowLeft", Vector3(-0.18, 1.64, z), Vector3(0.07, 0.94, 0.07), "trim")
	_box(root, "WindowRight", Vector3(0.88, 1.64, z), Vector3(0.07, 0.94, 0.07), "trim")
	_box(root, "WindowMullionV", Vector3(0.35, 1.64, z - 0.01), Vector3(0.045, 0.82, 0.045), "trim")
	_box(root, "WindowMullionH", Vector3(0.35, 1.64, z - 0.01), Vector3(1.0, 0.045, 0.045), "trim")
	for i in 5:
		var y := 1.95 - float(i) * 0.12
		_box(root, "Blind%02d" % i, Vector3(0.35, y, z - 0.045), Vector3(1.03, 0.025, 0.04), "paper_alt")

func _build_desk_zone() -> void:
	var root := Node3D.new(); root.name = "DeskZone"; add_child(root)
	_box(root, "DeskTop", Vector3(1.05, 0.77, -1.47), Vector3(1.78, 0.09, 0.76), "wood_light")
	for x in [0.23, 1.87]:
		for z in [-1.74, -1.19]: _box(root, "DeskLeg", Vector3(x, 0.39, z), Vector3(0.08, 0.72, 0.08), "wood_dark")
	_box(root, "DrawerPedestal", Vector3(1.66, 0.41, -1.49), Vector3(0.39, 0.64, 0.58), "wood")
	for i in 2:
		var y := 0.56 - float(i) * 0.24
		_box(root, "DrawerFace%02d" % i, Vector3(1.45, y, -1.49), Vector3(0.025, 0.19, 0.51), "wood_light")
		_cyl(root, "DrawerPull%02d" % i, Vector3(1.42, y, -1.49), 0.025, 0.11, "metal", Vector3(0, 0, 90), 8)
	var archive := Node3D.new(); archive.name = "StorageZone"; root.add_child(archive)
	_box(archive, "ArchiveBox", Vector3(1.55, 0.22, -1.14), Vector3(0.42, 0.40, 0.38), "archive")
	_box(archive, "ArchiveLid", Vector3(1.55, 0.43, -1.14), Vector3(0.45, 0.05, 0.41), "paper_alt")
	_box(archive, "ArchiveLabel", Vector3(1.33, 0.26, -1.14), Vector3(0.012, 0.11, 0.19), "paper")
	_build_manager_chair(root)
	_build_desk_objects(root)

func _build_manager_chair(parent: Node3D) -> void:
	var c := Node3D.new(); c.name = "ManagerChair"; parent.add_child(c)
	_box(c, "Seat", Vector3(1.05, 0.49, -0.72), Vector3(0.50, 0.12, 0.48), "fabric_dark")
	_box(c, "Back", Vector3(1.05, 0.88, -0.94), Vector3(0.52, 0.68, 0.12), "fabric_dark", Vector3(-6, 0, 0))
	_cyl(c, "Post", Vector3(1.05, 0.27, -0.72), 0.055, 0.34, "metal")
	for angle in [-55.0, 0.0, 55.0]: _box(c, "ChairSpoke", Vector3(1.05, 0.11, -0.72), Vector3(0.08, 0.05, 0.58), "metal", Vector3(0, angle, 0))
	for p in [Vector3(0.80, 0.08, -0.52), Vector3(1.30, 0.08, -0.52), Vector3(1.05, 0.08, -1.00)]: _cyl(c, "Wheel", p, 0.045, 0.04, "metal", Vector3(90, 0, 0))

func _build_desk_objects(parent: Node3D) -> void:
	var o := Node3D.new(); o.name = "DeskObjects"; parent.add_child(o)
	_box(o, "Journal", Vector3(0.63, 0.84, -1.41), Vector3(0.32, 0.035, 0.42), "fabric_dark", Vector3(0, -5, 0))
	_box(o, "JournalPageEdge", Vector3(0.63, 0.856, -1.41), Vector3(0.29, 0.008, 0.39), "paper", Vector3(0, -5, 0))
	_box(o, "TrainingClipboard", Vector3(1.03, 0.84, -1.42), Vector3(0.29, 0.025, 0.39), "paper_alt", Vector3(0, 4, 0))
	_box(o, "ClipboardClip", Vector3(1.03, 0.86, -1.58), Vector3(0.09, 0.025, 0.045), "metal", Vector3(0, 4, 0))
	_box(o, "PhoneBase", Vector3(1.52, 0.87, -1.56), Vector3(0.25, 0.12, 0.22), "ink")
	_box(o, "PhoneHandset", Vector3(1.52, 0.96, -1.56), Vector3(0.28, 0.055, 0.08), "metal", Vector3(0, 7, 0))
	_box(o, "AnsweringMachine", Vector3(1.76, 0.86, -1.33), Vector3(0.19, 0.10, 0.16), "metal")
	_sphere(o, "MachineLight", Vector3(1.67, 0.91, -1.24), 0.018, "red")
	_box(o, "ScoutingBoard", Vector3(0.31, 0.85, -1.58), Vector3(0.24, 0.045, 0.30), "archive", Vector3(0, -6, 0))
	_box(o, "HousingFolder", Vector3(0.32, 0.84, -1.29), Vector3(0.24, 0.03, 0.25), "blue", Vector3(0, 3, 0))
	_box(o, "MealPad", Vector3(1.24, 0.84, -1.21), Vector3(0.20, 0.02, 0.23), "paper", Vector3(0, -7, 0))
	for i in 4:
		var x := 1.30 + float(i) * 0.09
		_box(o, "ReferenceBook%02d" % i, Vector3(x, 1.02, -1.76), Vector3(0.07, 0.32 + float(i % 2) * 0.04, 0.18), "frame" if i % 2 == 0 else "blue")
	_cyl(o, "LampBase", Vector3(0.82, 0.87, -1.72), 0.10, 0.035, "metal", Vector3.ZERO, 12)
	_cyl(o, "LampStem", Vector3(0.82, 1.08, -1.72), 0.025, 0.38, "metal", Vector3(0, 0, -12), 8)
	_box(o, "LampShade", Vector3(0.88, 1.27, -1.71), Vector3(0.22, 0.12, 0.18), "ink", Vector3(0, 0, -10))
	_cyl(o, "Mug", Vector3(1.18, 0.91, -1.60), 0.055, 0.12, "paper", Vector3.ZERO, 10)
	_cyl(o, "PencilCup", Vector3(0.44, 0.92, -1.72), 0.055, 0.14, "archive", Vector3.ZERO, 10)
	for i in 3: _cyl(o, "Pencil%02d" % i, Vector3(0.42 + float(i) * 0.02, 1.04 + float(i) * 0.015, -1.72), 0.008, 0.22, "accent", Vector3(0, 0, -4 + i * 5), 6)

func _build_sleep_zone() -> void:
	var root := Node3D.new(); root.name = "SleepZone"; add_child(root)
	_box(root, "BedFrame", Vector3(-1.48, 0.20, -0.18), Vector3(1.25, 0.38, 2.05), "wood_dark")
	_box(root, "Headboard", Vector3(-1.48, 0.68, -1.18), Vector3(1.25, 0.78, 0.10), "wood")
	_box(root, "Mattress", Vector3(-1.48, 0.48, -0.18), Vector3(1.15, 0.22, 1.93), "fabric_light")
	_box(root, "Blanket", Vector3(-1.48, 0.61, 0.18), Vector3(1.10, 0.08, 1.10), "fabric")
	_box(root, "Pillow", Vector3(-1.48, 0.67, -0.81), Vector3(0.70, 0.16, 0.36), "paper", Vector3(0, 0, -3))
	_box(root, "Rug", Vector3(-1.42, 0.015, 0.02), Vector3(1.62, 0.025, 2.38), "paper_alt")
	_box(root, "RugInset", Vector3(-1.42, 0.031, 0.02), Vector3(1.38, 0.012, 2.12), "fabric")
	_box(root, "BedsideTop", Vector3(-0.68, 0.53, -0.77), Vector3(0.38, 0.06, 0.38), "wood_light")
	for x in [-0.82, -0.54]:
		for z in [-0.91, -0.63]: _box(root, "BedsideLeg", Vector3(x, 0.27, z), Vector3(0.05, 0.50, 0.05), "wood_dark")
	_cyl(root, "BedLampBase", Vector3(-0.68, 0.58, -0.77), 0.08, 0.025, "accent", Vector3.ZERO, 10)
	_cyl(root, "BedLampStem", Vector3(-0.68, 0.72, -0.77), 0.018, 0.27, "metal")
	_box(root, "BedLampShade", Vector3(-0.68, 0.88, -0.77), Vector3(0.19, 0.15, 0.19), "paper_alt")

func _build_guest_chair() -> void:
	var root := Node3D.new(); root.name = "FlexibleSeating"; add_child(root)
	_box(root, "GuestSeat", Vector3(0.18, 0.46, -0.58), Vector3(0.50, 0.12, 0.50), "fabric_dark", Vector3(0, -8, 0))
	_box(root, "GuestBack", Vector3(0.14, 0.83, -0.79), Vector3(0.50, 0.58, 0.11), "fabric_dark", Vector3(-5, -8, 0))
	for x in [-0.03, 0.39]:
		for z in [-0.74, -0.42]: _box(root, "GuestLeg", Vector3(x, 0.22, z), Vector3(0.055, 0.42, 0.055), "wood_dark", Vector3(0, -8, 0))
	var anchor := Marker3D.new(); anchor.name = "GuestChairInterviewAnchor"; anchor.position = Vector3(0.28, 0, -0.38); root.add_child(anchor)

func _build_wall_state() -> void:
	var root := Node3D.new(); root.name = "WallZone"; add_child(root)
	var z := -1.943
	_box(root, "CalendarBacking", Vector3(1.62, 1.62, z), Vector3(0.50, 0.66, 0.045), "paper")
	_box(root, "CalendarHeader", Vector3(1.62, 1.90, z - 0.028), Vector3(0.50, 0.10, 0.025), "ink")
	for i in 1 + 5:
		var y := 1.35 + float(i) * 0.09
		_box(root, "CalendarRow%02d" % i, Vector3(1.62, y, z - 0.03), Vector3(0.43, 0.012, 0.018), "paper_alt")
	for i in 1 + 4:
		var x := 1.45 + float(i) * 0.085
		_box(root, "CalendarCol%02d" % i, Vector3(x, 1.57, z - 0.03), Vector3(0.010, 0.42, 0.018), "paper_alt")
	_sphere(root, "CalendarMark", Vector3(1.67, 1.54, z - 0.05), 0.025, "red")
	for i in 4:
		var x := -0.78 + float(i) * 0.39
		_box(root, "HistoryFrame%02d" % i, Vector3(x, 2.15, z), Vector3(0.30, 0.28, 0.055), "frame")
		_box(root, "HistoryImage%02d" % i, Vector3(x, 2.15, z - 0.033), Vector3(0.23, 0.20, 0.018), "photo_a" if i % 2 == 0 else "photo_b")

func _camera(parent: Node3D, name_: String, pos: Vector3, target: Vector3, fov := 55.0) -> Camera3D:
	var c := Camera3D.new(); c.name = name_; c.position = pos; c.fov = fov; parent.add_child(c); c.look_at(target, Vector3.UP); return c

func _build_cameras() -> void:
	var cams := Node3D.new(); cams.name = "Cameras"; add_child(cams)
	_camera(cams, "MainMenu", Vector3(0.78, 6.85, 3.55), Vector3(0.38, 0.30, -0.42), 37.0)
	_camera(cams, "TransitionMid", Vector3(0.92, 3.35, 1.65), Vector3(0.88, 0.82, -1.10), 46.0)
	var desk := _camera(cams, "Desk", Vector3(1.05, 1.28, -0.98), Vector3(1.08, 1.20, -1.90), 66.0); desk.current = true
	_camera(cams, "Calendar", Vector3(1.18, 1.62, -0.10), Vector3(1.62, 1.62, -1.94), 42.0)
	_camera(cams, "Door", Vector3(0.72, 1.56, -0.05), Vector3(2.35, 1.0, 1.05), 50.0)
	_camera(cams, "Interview", Vector3(1.58, 1.48, 0.36), Vector3(0.25, 1.0, -0.42), 46.0)
	_camera(cams, "OfficeWide", Vector3(0.18, 4.25, 4.45), Vector3(0.20, 0.60, -0.20), 47.0)
