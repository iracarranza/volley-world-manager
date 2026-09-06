extends Node3D
## Isolated visual prototype for reducing visible Voli arm articulation seams.
## No production PlayerActor3D or animation semantics are changed.
## Run the companion scene and compare four constructions across bend angles.

const BENDS := [5.0, 45.0, 90.0, 120.0]
const VARIANTS := ["A  CURRENT", "B  OVERLAP", "C  SHAPED OVERLAP", "D  SLEEVE"]
const ARM_LENGTH := 0.44
const ARM_RADIUS := 0.085

var body_material: StandardMaterial3D
var joint_material: StandardMaterial3D

func _ready() -> void:
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.72, 0.48, 0.34)
	body_material.roughness = 0.82
	joint_material = body_material.duplicate()
	joint_material.albedo_color = Color(0.60, 0.36, 0.27)

	for row in BENDS.size():
		for column in VARIANTS.size():
			var root := Node3D.new()
			root.position = Vector3((column - 1.5) * 1.35, (1.5 - row) * 1.25, 0.0)
			add_child(root)
			_build_arm(root, column, deg_to_rad(BENDS[row]))

			if row == 0:
				_add_label(root, VARIANTS[column], Vector3(0, 0.58, 0), 30)
		if row < BENDS.size():
			var label_root := Node3D.new()
			label_root.position = Vector3(-2.72, (1.5 - row) * 1.25, 0.0)
			add_child(label_root)
			_add_label(label_root, "%d deg" % int(BENDS[row]), Vector3.ZERO, 27)

func _build_arm(root: Node3D, variant: int, bend: float) -> void:
	var shoulder := Vector3(0, ARM_LENGTH, 0)
	var elbow := Vector3.ZERO
	var forearm_direction := Vector3(sin(bend), -cos(bend), 0).normalized()
	var wrist := elbow + forearm_direction * ARM_LENGTH

	match variant:
		0:
			_add_segment(root, shoulder, elbow, ARM_RADIUS, ARM_RADIUS * 0.90)
			_add_segment(root, elbow, wrist, ARM_RADIUS * 0.90, ARM_RADIUS * 0.78)
			_add_sphere(root, elbow, ARM_RADIUS * 1.18, joint_material)
		1:
			# Cheap seam removal: both opaque segments penetrate the elbow pivot.
			var overlap := 0.075
			_add_segment(root, shoulder, elbow + (elbow - shoulder).normalized() * overlap, ARM_RADIUS, ARM_RADIUS * 0.94)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, ARM_RADIUS * 0.94, ARM_RADIUS * 0.78)
		2:
			# Same overlap, with broader ends around the articulation to create a
			# continuous silhouette without introducing a visible joint object.
			var overlap := 0.085
			_add_segment(root, shoulder, elbow + (elbow - shoulder).normalized() * overlap, ARM_RADIUS, ARM_RADIUS * 1.18)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, ARM_RADIUS * 1.15, ARM_RADIUS * 0.76)
		3:
			# Preserve the pivot but skin over it with a rounded connector aligned
			# along the bisector of upper/forearm directions.
			var overlap := 0.065
			_add_segment(root, shoulder, elbow + (elbow - shoulder).normalized() * overlap, ARM_RADIUS, ARM_RADIUS * 0.98)
			_add_segment(root, elbow - forearm_direction * overlap, wrist, ARM_RADIUS * 0.98, ARM_RADIUS * 0.77)
			var upper_into_joint := (elbow - shoulder).normalized()
			var bisector := (upper_into_joint + forearm_direction).normalized()
			if bisector.length_squared() < 0.001:
				bisector = forearm_direction
			_add_capsule(root, elbow, bisector, ARM_RADIUS * 1.07, 0.24)

	_add_sphere(root, wrist, ARM_RADIUS * 0.82, body_material)

func _add_segment(root: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_a
	mesh.bottom_radius = radius_b
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 16
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	_place_y_axis_between(instance, a, b)

func _add_capsule(root: Node3D, center: Vector3, direction: Vector3, radius: float, height: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.05)
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = body_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	instance.position = center
	instance.basis = _basis_y_along(direction)

func _add_sphere(root: Node3D, center: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
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
