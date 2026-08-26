extends Node3D
## Canonical office-bedroom greybox.
## Geometry is deliberately primitive: this scene exists to certify spatial and
## camera continuity before art direction. See OFFICE_LAYOUT_FIRST_PASS.md.

const ROOM_W := 4.8
const ROOM_D := 4.0
const ROOM_H := 2.6

var _mats := {}

func _ready() -> void:
	_build_materials()
	_build_architecture()
	_build_furniture()
	_build_wall_state()
	_build_cameras()

func _mat(key: String, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	_mats[key] = m
	return m

func _build_materials() -> void:
	_mat("floor", Color("9b9488"))
	_mat("wall", Color("d5d0c4"))
	_mat("wood", Color("695344"))
	_mat("bed", Color("b5b1a8"))
	_mat("dark", Color("3c3b39"))
	_mat("paper", Color("ded8c7"))
	_mat("history", Color("8c745f"))
	_mat("window", Color("78919b"))
	_mat("archive", Color("87715a"))

func _box(parent: Node3D, name_: String, pos: Vector3, size: Vector3, mat_key: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = _mats[mat_key]
	parent.add_child(n)
	return n

func _build_architecture() -> void:
	var root := Node3D.new(); root.name = "Architecture"; add_child(root)
	_box(root, "Floor", Vector3(0, -0.05, 0), Vector3(ROOM_W, 0.1, ROOM_D), "floor")
	# Desk/history wall is -Z. Side walls stop short of the front edge so wide
	# cameras can read the room without a removable-wall system in the greybox.
	_box(root, "DeskWall", Vector3(0, ROOM_H/2.0, -ROOM_D/2.0), Vector3(ROOM_W, ROOM_H, 0.08), "wall")
	_box(root, "LeftWall", Vector3(-ROOM_W/2.0, ROOM_H/2.0, -0.25), Vector3(0.08, ROOM_H, 3.5), "wall")
	_box(root, "RightWall", Vector3(ROOM_W/2.0, ROOM_H/2.0, -0.25), Vector3(0.08, ROOM_H, 3.5), "wall")
	# Door on right wall toward room interior.
	_box(root, "Door", Vector3(ROOM_W/2.0 - 0.05, 1.0, 1.05), Vector3(0.10, 2.0, 0.86), "wood")
	# Window remains on desk wall, to desk-right.
	_box(root, "Window", Vector3(1.62, 1.65, -ROOM_D/2.0 + 0.045), Vector3(1.0, 0.85, 0.06), "window")

func _build_furniture() -> void:
	var desk_zone := Node3D.new(); desk_zone.name = "DeskZone"; add_child(desk_zone)
	_box(desk_zone, "Desk", Vector3(1.05, 0.38, -1.48), Vector3(1.65, 0.76, 0.72), "wood")
	_box(desk_zone, "ManagerChair", Vector3(1.05, 0.46, -0.75), Vector3(0.52, 0.92, 0.48), "dark")
	var objects := Node3D.new(); objects.name = "DeskObjectAnchors"; desk_zone.add_child(objects)
	_box(objects, "Journal", Vector3(0.72, 0.79, -1.38), Vector3(0.32, 0.035, 0.42), "paper")
	_box(objects, "TrainingClipboard", Vector3(1.16, 0.79, -1.43), Vector3(0.30, 0.035, 0.40), "paper")
	_box(objects, "Phone", Vector3(1.57, 0.84, -1.43), Vector3(0.24, 0.13, 0.24), "dark")
	_box(objects, "Scouting", Vector3(0.34, 0.81, -1.46), Vector3(0.28, 0.07, 0.34), "history")

	var sleep := Node3D.new(); sleep.name = "SleepZone"; add_child(sleep)
	_box(sleep, "BedBase", Vector3(-1.48, 0.25, -0.18), Vector3(1.25, 0.50, 2.05), "wood")
	_box(sleep, "Mattress", Vector3(-1.48, 0.55, -0.18), Vector3(1.15, 0.20, 1.95), "bed")
	_box(sleep, "Pillow", Vector3(-1.48, 0.71, -0.82), Vector3(0.70, 0.13, 0.35), "paper")

	var storage := Node3D.new(); storage.name = "StorageZone"; add_child(storage)
	_box(storage, "Archive", Vector3(-1.88, 0.35, 1.25), Vector3(0.72, 0.70, 0.62), "archive")

	var seating := Node3D.new(); seating.name = "FlexibleSeating"; add_child(seating)
	_box(seating, "GuestChairRest", Vector3(0.15, 0.44, 1.15), Vector3(0.50, 0.88, 0.50), "dark")
	var interview := Marker3D.new(); interview.name = "GuestChairInterviewAnchor"; interview.position = Vector3(0.30, 0, -0.45); seating.add_child(interview)

func _build_wall_state() -> void:
	var wall := Node3D.new(); wall.name = "WallZone"; add_child(wall)
	_box(wall, "Calendar", Vector3(0.35, 1.62, -1.945), Vector3(0.48, 0.64, 0.055), "paper")
	var frames := Node3D.new(); frames.name = "HistoryFrameAnchors"; wall.add_child(frames)
	# Deliberately sparse new-career sample: anchors demonstrate future capacity.
	for i in 4:
		var x := -0.55 + float(i) * 0.43
		_box(frames, "HistoryAnchor%02d" % (i + 1), Vector3(x, 2.12, -1.945), Vector3(0.30, 0.28, 0.055), "history")

func _camera(parent: Node3D, name_: String, pos: Vector3, target: Vector3, fov := 55.0) -> Camera3D:
	var c := Camera3D.new()
	c.name = name_
	c.position = pos
	c.fov = fov
	parent.add_child(c)
	c.look_at(target, Vector3.UP)
	return c

func _build_cameras() -> void:
	var cams := Node3D.new(); cams.name = "Cameras"; add_child(cams)
	_camera(cams, "MainMenu", Vector3(0.0, 6.7, 3.9), Vector3(0.0, 0.35, -0.15), 42.0)
	_camera(cams, "TransitionMid", Vector3(0.75, 3.75, 2.0), Vector3(0.75, 0.65, -1.0), 48.0)
	var desk := _camera(cams, "Desk", Vector3(1.05, 1.42, -0.38), Vector3(1.03, 0.82, -1.48), 56.0)
	desk.current = true
	_camera(cams, "Calendar", Vector3(0.60, 1.55, -0.58), Vector3(0.35, 1.62, -1.94), 48.0)
	_camera(cams, "Door", Vector3(0.55, 1.55, -0.25), Vector3(2.35, 1.0, 1.05), 52.0)
	_camera(cams, "Interview", Vector3(1.60, 1.55, 0.72), Vector3(0.28, 1.05, -0.42), 48.0)
	_camera(cams, "OfficeWide", Vector3(0.0, 4.6, 4.7), Vector3(0.0, 0.55, -0.15), 50.0)
