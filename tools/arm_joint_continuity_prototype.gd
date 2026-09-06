extends Node3D
## Isolated visual prototype for reducing visible Voli arm articulation seams.
## No production PlayerActor3D or animation semantics are changed.
## A CURRENT reproduces the authored PlayerActor3D arm: the same 0.88 m,
## 8-sided tapered ArmMesh centered 0.20 m below each pivot. The elbow pivot is
## 0.40 m below the shoulder and wrist 0.48 m below elbow. No elbow sphere exists.
## B-D retain those pivots/proportions and vary only elbow continuity treatment.

const BENDS := [5.0, 45.0, 90.0, 120.0]
const VARIANTS := ["A  CURRENT", "B  OVERLAP", "C  SHAPED OVERLAP", "D  SLEEVE"]
const UPPER_PIVOT_LENGTH := 0.40
const FOREARM_PIVOT_LENGTH := 0.48
const PRODUCTION_MESH_HEIGHT := 0.88
const PRODUCTION_TOP_RADIUS := 0.075
const PRODUCTION_BOTTOM_RADIUS := 0.09
const PRODUCTION_MESH_OFFSET := 0.20
var body_material: StandardMaterial3D

func _ready() -> void:
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.72, 0.48, 0.34)
	body_material.roughness = 0.82
	for row in BENDS.size():
		for column in VARIANTS.size():
			var root := Node3D.new()
			root.position = Vector3((column - 1.5) * 1.35, (1.5 - row) * 1.25, 0.0)
			add_child(root)
			_build_arm(root, column, deg_to_rad(BENDS[row]))
			if row == 0:
				_add_label(root, VARIANTS[column], Vector3(0, 0.58, 0), 30)
		var label_root := Node3D.new()
		label_root.position = Vector3(-2.72, (1.5 - row) * 1.25, 0.0)
		add_child(label_root)
		_add_label(label_root, "%d deg" % int(BENDS[row]), Vector3.ZERO, 27)
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "user://arm_joint_continuity.png"
	var error := image.save_png(path)
	print("ARM_JOINT_RENDER|%s|%s" % [path, error_string(error)])
	get_tree().quit(0 if error == OK else 1)

func _build_arm(root: Node3D, variant: int, bend: float) -> void:
	var shoulder := Vector3(0, UPPER_PIVOT_LENGTH, 0)
	var elbow := Vector3.ZERO
	var upper_direction := (elbow - shoulder).normalized()
	var forearm_direction := Vector3(sin(bend), -cos(bend), 0).normalized()
	var wrist := elbow + forearm_direction * FOREARM_PIVOT_LENGTH
	match variant:
		0:
			_add_production_mesh(root, shoulder + upper_direction * PRODUCTION_MESH_OFFSET, upper_direction)
			_add_production_mesh(root, elbow + forearm_direction * PRODUCTION_MESH_OFFSET, forearm_direction)
		1:
			var overlap := 0.075
			_add_segment(root, shoulder, elbow + upper_direction * overlap, PRODUCTION_TOP_RADIUS, PRODUCTION_BOTTOM_RADIUS)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, PRODUCTION_BOTTOM_RADIUS, PRODUCTION_TOP_RADIUS)
		2:
			var overlap := 0.085
			_add_segment(root, shoulder, elbow + upper_direction * overlap, PRODUCTION_TOP_RADIUS, 0.102)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, 0.100, PRODUCTION_TOP_RADIUS)
		3:
			var overlap := 0.065
			_add_segment(root, shoulder, elbow + upper_direction * overlap, PRODUCTION_TOP_RADIUS, PRODUCTION_BOTTOM_RADIUS)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, PRODUCTION_BOTTOM_RADIUS, PRODUCTION_TOP_RADIUS)
			var bisector := (upper_direction + forearm_direction).normalized()
			if bisector.length_squared() < 0.001:
				bisector = forearm_direction
			_add_capsule(root, elbow, bisector, 0.091, 0.21)
	_add_production_palm(root, wrist, forearm_direction)

func _add_production_mesh(root: Node3D, center: Vector3, direction: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = PRODUCTION_TOP_RADIUS
	mesh.bottom_radius = PRODUCTION_BOTTOM_RADIUS
	mesh.height = PRODUCTION_MESH_HEIGHT
	mesh.radial_segments = 8
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.basis = _basis_y_along(direction)
	root.add_child(instance)

func _add_segment(root: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_a
	mesh.bottom_radius = radius_b
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	_place_y_axis_between(instance, a, b)

func _add_capsule(root: Node3D, center: Vector3, direction: Vector3, radius: float, height: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.05)
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	instance.position = center
	instance.basis = _basis_y_along(direction)

func _add_production_palm(root: Node3D, wrist: Vector3, direction: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = wrist
	instance.scale = Vector3(0.78, 1.08, 0.46)
	instance.basis = _basis_y_along(direction)
	root.add_child(instance)

func _place_y_axis_between(node: Node3D, a: Vector3, b: Vector3) -> void:
	node.position = (a + b) * 0.5
	node.basis = _basis_y_along((b - a).normalized())

func _basis_y_along(direction: Vector3) -> Basis:
	var y := direction.normalized()
	var reference := Vector3.FORWARD
	if absf(y.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _add_label(root: Node3D, text: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.0045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)
