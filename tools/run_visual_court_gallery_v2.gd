extends "res://tools/run_visual_court_gallery.gd"

## Second visual review pass: the first natural-form pass fixed the skyline but
## exposed the authored support slab in the establishing frame. Keep the court,
## stands, rails, sea, kit and lighting; replace only the rectangular support
## boxes and conical island review geometry with continuous terrain.


func _terrace() -> void:
	super._terrace()
	for child in _extras.get_children():
		var name := str(child.name)
		if name == "Terrace" or name.begins_with("Hillside") \
				or name.begins_with("PawaIsland") or name.begins_with("PawaHeadland") \
				or name == "PawaShoulder":
			child.queue_free()

	_add_terraced_ground()

	var island_sites := [
		[Vector3(-276.0, 0.0, -178.0), Vector2(36.0, 28.0), -8.0, 0.25],
		[Vector3(-346.0, 0.0, -48.0), Vector2(23.0, 18.0), -14.0, 1.15],
		[Vector3(-316.0, 0.0, 92.0), Vector2(29.0, 22.0), -11.0, 2.05],
		[Vector3(-398.0, 0.0, 202.0), Vector2(18.0, 15.0), -17.0, 2.80],
	]
	for i in range(island_sites.size()):
		var spec: Array = island_sites[i]
		var at: Vector3 = spec[0]
		var radii: Vector2 = spec[1]
		var top := float(spec[2])
		var phase := float(spec[3])
		_add_rugged_mound(
			"PawaIslandRugged%dA" % i, at, radii, -43.0, top,
			Color(0.27, 0.32, 0.39).lightened(float(i) * 0.035), phase,
			Vector2(0.18, -0.10),
		)
		_add_rugged_mound(
			"PawaIslandRugged%dB" % i,
			at + Vector3(radii.x * 0.46, 0.0, -radii.y * 0.30),
			radii * Vector2(0.54, 0.64), -43.0, top - 5.0,
			Color(0.30, 0.34, 0.40).lightened(float(i) * 0.035), phase + 0.9,
			Vector2(-0.13, 0.17),
		)

	## Inland shoulder: broad and low, blending into the upper terrace rather than
	## presenting a wall beside the wide camera.
	_add_rugged_mound(
		"PawaShoulderRugged", Vector3(55.0, 0.0, -20.0), Vector2(68.0, 108.0),
		-57.0, 22.0, Color(0.27, 0.23, 0.20), 0.6, Vector2(0.28, 0.10),
	)
	_add_rugged_mound(
		"PawaHeadlandRugged0", Vector3(-128.0, 0.0, -174.0), Vector2(39.0, 78.0),
		-44.0, -18.0, Color(0.23, 0.21, 0.20), 1.7, Vector2(0.20, -0.08),
	)
	_add_rugged_mound(
		"PawaHeadlandRugged1", Vector3(-164.0, 0.0, 178.0), Vector2(34.0, 66.0),
		-44.0, -20.0, Color(0.24, 0.22, 0.20), 2.4, Vector2(-0.16, 0.12),
	)


func _add_terraced_ground() -> void:
	const SEGMENTS := 16
	var ring_specs := [
		[Vector2(22.5, 30.0), -0.45, 0.0],
		[Vector2(29.5, 38.5), -3.2, 2.0],
		[Vector2(36.5, 47.5), -8.0, 4.8],
		[Vector2(43.5, 56.0), -14.5, 8.0],
		[Vector2(51.0, 65.0), -24.0, 11.0],
	]
	var rings_: Array = []
	for ring_index in range(ring_specs.size()):
		var spec: Array = ring_specs[ring_index]
		var radii: Vector2 = spec[0]
		var y := float(spec[1])
		var shift_x := float(spec[2])
		var points: Array[Vector3] = []
		for i in range(SEGMENTS):
			var angle := TAU * float(i) / float(SEGMENTS)
			var cx := cos(angle)
			var sz := sin(angle)
			## Superellipse-like edge: recognisably a cut terrace, but with corners
			## eroded away and a deterministic volcanic wobble.
			var ex := (1.0 if cx >= 0.0 else -1.0) * pow(absf(cx), 0.72)
			var ez := (1.0 if sz >= 0.0 else -1.0) * pow(absf(sz), 0.72)
			var wobble := 1.0 + 0.035 * sin(float(i) * 2.31 + float(ring_index) * 0.77) \
				+ 0.018 * sin(float(i) * 4.13 + 0.8)
			points.append(Vector3(shift_x + ex * radii.x * wobble, y, ez * radii.y * wobble))
		rings_.append(points)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner: Array[Vector3] = rings_[0]
	var top_center := Vector3(0.0, -0.45, 0.0)
	for i in range(SEGMENTS):
		var j := (i + 1) % SEGMENTS
		_tri(surface, top_center, inner[i], inner[j])
	for ring_index in range(rings_.size() - 1):
		var upper: Array[Vector3] = rings_[ring_index]
		var lower: Array[Vector3] = rings_[ring_index + 1]
		for i in range(SEGMENTS):
			var j := (i + 1) % SEGMENTS
			_tri(surface, upper[i], lower[i], lower[j])
			_tri(surface, upper[i], lower[j], upper[j])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "PawaTerracedLandform"
	node.mesh = surface.commit()
	_apply_terrain_material(node, Color(0.285, 0.242, 0.215))
	_extras.add_child(node)

	## Thin irregular ledges make the terrace cuts legible at match-camera scale.
	for ring_index in range(1, rings_.size() - 1):
		var ledge: Array[Vector3] = rings_[ring_index]
		var ledge_surface := SurfaceTool.new()
		ledge_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(SEGMENTS):
			var j := (i + 1) % SEGMENTS
			var a: Vector3 = ledge[i]
			var b: Vector3 = ledge[j]
			var inward_a := Vector3(a.x * 0.965, a.y + 0.08, a.z * 0.965)
			var inward_b := Vector3(b.x * 0.965, b.y + 0.08, b.z * 0.965)
			_tri(ledge_surface, a, b, inward_b)
			_tri(ledge_surface, a, inward_b, inward_a)
		ledge_surface.generate_normals()
		var ledge_node := MeshInstance3D.new()
		ledge_node.name = "PawaTerraceLedge%d" % ring_index
		ledge_node.mesh = ledge_surface.commit()
		_apply_terrain_material(ledge_node, Color(0.34, 0.285, 0.245).darkened(float(ring_index) * 0.035))
		_extras.add_child(ledge_node)


func _add_rugged_mound(
	name: String, center: Vector3, radii: Vector2, base_y: float, top_y: float,
	colour: Color, phase: float, summit_offset: Vector2 = Vector2.ZERO,
) -> void:
	const SEGMENTS := 12
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	var crest: Array[Vector3] = []
	for i in range(SEGMENTS):
		var angle := TAU * float(i) / float(SEGMENTS)
		var wobble := 1.0 + 0.14 * sin(float(i) * 2.17 + phase) \
			+ 0.06 * sin(float(i) * 4.31 + phase * 0.6)
		var radial := Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * wobble
		base.append(center + Vector3(radial.x, base_y, radial.y))
		var shoulder_radial := radial * (0.48 + 0.06 * sin(float(i) * 1.53 + phase))
		shoulder.append(center + Vector3(
			shoulder_radial.x, lerpf(base_y, top_y, 0.62), shoulder_radial.y
		))
		var crest_radial := radial * (0.17 + 0.04 * sin(float(i) * 2.91 + phase))
		var crest_height := top_y - absf(sin(float(i) * 1.71 + phase)) * maxf(1.8, (top_y - base_y) * 0.055)
		crest.append(center + Vector3(
			crest_radial.x + summit_offset.x * radii.x,
			crest_height,
			crest_radial.y + summit_offset.y * radii.y,
		))
	var top_center := center + Vector3(
		summit_offset.x * radii.x * 0.8,
		top_y - 0.8,
		summit_offset.y * radii.y * 0.8,
	)
	for i in range(SEGMENTS):
		var j := (i + 1) % SEGMENTS
		_tri(surface, base[i], base[j], shoulder[j])
		_tri(surface, base[i], shoulder[j], shoulder[i])
		_tri(surface, shoulder[i], shoulder[j], crest[j])
		_tri(surface, shoulder[i], crest[j], crest[i])
		_tri(surface, crest[i], crest[j], top_center)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = surface.commit()
	_apply_terrain_material(node, colour)
	_extras.add_child(node)


func _wide(id: String) -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	if _open_air:
		## Inland edge of the upper terrace. Enough height to read the stepped
		## hillside, but close enough that the flat volleyball court remains the
		## scale reference instead of turning into a model on a plinth.
		camera.position = Vector3(24.0, 11.8, 31.5)
		camera.fov = 55.0
		camera.look_at(Vector3(-13.0, -1.0, -1.0), Vector3.UP)
	else:
		camera.position = Vector3(10.6, 9.6, 18.4)
		camera.fov = 55.0
		camera.look_at(Vector3(-1.0, 1.7, -1.2), Vector3.UP)
	await _settle()
	_save("venue_%s_wide.png" % id, "wide")
