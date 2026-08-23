extends "res://tools/run_venue_probe.gd"

## Pāwa-only visual iteration. Reuses the authoritative venue probe/court/actors
## and changes only the landscape placeholders so comparison is like-for-like.

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for venue_value in _venues():
		var venue := Dictionary(venue_value)
		if str(venue.get("id", "")) != "pawa":
			continue
		await _shoot(venue)
	get_tree().quit()


func _terrace() -> void:
	## Keep the existing court terrace, lower agricultural steps, parapets and sea.
	## Replace only the box-shaped natural forms that currently read as towers.
	super._terrace()
	for child in _extras.get_children():
		var n := str(child.name)
		if n.begins_with("Peak") or n.begins_with("Island") or n.begins_with("Headland") or n == "Shoulder":
			child.free()

	## Inland shoulder: broad, sloped volcanic ground rather than a vertical wall.
	_volcanic_mass("ShoulderA", Vector3(57.0, 13.0, -28.0), 64.0, 76.0, 1.0, 1.85,
		Color(0.25, 0.22, 0.20), 0.35, 0.20)
	_volcanic_mass("ShoulderB", Vector3(86.0, 25.0, 45.0), 52.0, 92.0, 0.9, 1.45,
		Color(0.28, 0.25, 0.22), 0.95, 0.15)

	## Near headlands break the waterline with low sloping land, not rectangular piers.
	_volcanic_mass("HeadlandA", Vector3(-126.0, -17.0, -176.0), 58.0, 30.0, 1.0, 2.1,
		Color(0.22, 0.22, 0.21), 0.25, 0.30)
	_volcanic_mass("HeadlandB", Vector3(-170.0, -16.0, 205.0), 72.0, 34.0, 1.0, 2.35,
		Color(0.24, 0.24, 0.23), 0.75, 0.28)

	## Mid-distance islands: compound volcanic silhouettes with bases below sea level.
	_add_island("IslandA", Vector3(-245.0, -9.0, -185.0), 48.0, 44.0, 1.25, 0.25)
	_add_island("IslandB", Vector3(-305.0, -7.0, -35.0), 62.0, 52.0, 1.05, 0.75)
	_add_island("IslandC", Vector3(-280.0, -10.0, 125.0), 50.0, 42.0, 1.35, 1.20)
	_add_island("IslandD", Vector3(-350.0, -5.0, 270.0), 70.0, 56.0, 1.15, 1.55)

	## Far archipelago/ridge. Broad low masses overlap into a broken horizon; depth fog
	## supplies distance instead of giant cuboids supplying scale.
	var ridge_specs := [
		[Vector3(-430.0, 12.0, -410.0), 84.0, 92.0, 1.25, 0.15],
		[Vector3(-505.0, 18.0, -235.0), 104.0, 108.0, 1.10, 0.55],
		[Vector3(-560.0, 10.0, -55.0), 82.0, 86.0, 1.40, 0.95],
		[Vector3(-520.0, 22.0, 125.0), 112.0, 116.0, 1.15, 1.25],
		[Vector3(-470.0, 8.0, 315.0), 90.0, 82.0, 1.55, 1.65],
	]
	for i in range(ridge_specs.size()):
		var s: Array = ridge_specs[i]
		_volcanic_mass("Ridge%d" % i, Vector3(s[0]), float(s[1]), float(s[2]), 1.0,
			float(s[3]), Color(0.27, 0.31, 0.36).lightened(float(i) * 0.025),
			float(s[4]), 0.10)


func _add_island(id: String, center: Vector3, radius: float, height: float, stretch_z: float, yaw: float) -> void:
	var rock := Color(0.23, 0.27, 0.30)
	_volcanic_mass(id + "Main", center, radius, height, 1.0, stretch_z, rock, yaw, 0.14)
	_volcanic_mass(id + "Spur", center + Vector3(radius * 0.46, -height * 0.16, radius * 0.22),
		radius * 0.58, height * 0.66, 0.9, stretch_z * 0.72, rock.lightened(0.035), yaw + 0.55, 0.18)


func _volcanic_mass(
	id: String,
	center: Vector3,
	radius: float,
	height: float,
	stretch_x: float,
	stretch_z: float,
	color: Color,
	yaw: float,
	top_ratio: float
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * top_ratio
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	var mass := MeshInstance3D.new()
	mass.name = id
	mass.mesh = mesh
	mass.position = center
	mass.rotation.y = yaw
	mass.scale = Vector3(stretch_x, 1.0, stretch_z)
	mass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_extras.add_child(mass)
	return mass
