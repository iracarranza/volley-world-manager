extends "res://tools/run_visual_court_gallery.gd"

## Final review layer after the first 32-frame sheet exposed two remaining visual
## defects: Pāwa's natural backdrop sat behind a rectangular support pyramid,
## and Spëddigh's atmosphere erased too much player/court value. This script
## changes only presentation geometry/light used by the review renderer.


func _review_tune(id: String) -> void:
	super._review_tune(id)
	match id:
		"pawa":
			## The free zone is the top of the volcanic terrace, not a navy arena
			## deck. Match its value to the landform so the court is cut into the
			## hill instead of appearing to sit on a separate platform.
			var arena := _court.get_node_or_null("ArenaFloor") as MeshInstance3D
			if arena != null:
				_paint(arena, Color(0.285, 0.235, 0.205))
		"speddigh":
			## Keep the cold-air identity without making the room look overexposed.
			## Roof fixtures are the dominant source, so lowering only ambient/fill
			## in the previous pass did not recover enough body value.
			_key.light_energy = 0.34
			_fill.light_energy = 0.72
			_env.ambient_light_energy = 0.56
			for child in _extras.get_children():
				if child is OmniLight3D and str(child.name).begins_with("RoofLight"):
					(child as OmniLight3D).light_energy *= 0.62
				elif child is MeshInstance3D and str(child.name).begins_with("Mist"):
					var material := (child as MeshInstance3D).material_override as StandardMaterial3D
					if material != null:
						material.albedo_color.a = 0.055
						material.emission_energy_multiplier = 0.045
		_:
			pass


func _terrace() -> void:
	super._terrace()

	## The base probe's support boxes read as a stepped pyramid. The first
	## replacement proved that simply deleting them leaves the arena deck visually
	## floating. Remove the boxes and the parent's peaked islands, then replace
	## both with continuous, two-sided terrain that survives every review camera.
	for child in _extras.get_children():
		var child_name := str(child.name)
		if child_name == "Terrace" or child_name.begins_with("Hillside") \
				or child_name == "PawaShoulder" \
				or child_name.begins_with("PawaIsland"):
			child.queue_free()

	_add_court_landform()

	## Low, broad inland land rather than a cone beside the lens.
	_add_island_plateau(
		"PawaInlandShoulder", Vector3(69.0, 0.0, -52.0), Vector2(74.0, 92.0),
		-35.0, 8.5, Color(0.29, 0.25, 0.22), 0.54
	)

	## Unequal volcanic islands with shoulders and broken crowns. They occupy the
	## same authored sea/backdrop region as the earlier mounds but no longer
	## resolve to repeated triangles from the broadcast seat.
	_add_island_plateau(
		"PawaIslandA", Vector3(-278.0, 0.0, -165.0), Vector2(46.0, 35.0),
		-43.0, -8.0, Color(0.27, 0.32, 0.39), 0.31
	)
	_add_island_plateau(
		"PawaIslandB", Vector3(-342.0, 0.0, -42.0), Vector2(31.0, 23.0),
		-43.0, -13.5, Color(0.30, 0.35, 0.41), 1.27
	)
	_add_island_plateau(
		"PawaIslandC", Vector3(-318.0, 0.0, 104.0), Vector2(39.0, 29.0),
		-43.0, -10.0, Color(0.31, 0.36, 0.42), 2.16
	)
	_add_island_plateau(
		"PawaIslandD", Vector3(-402.0, 0.0, 210.0), Vector2(25.0, 19.0),
		-43.0, -16.0, Color(0.34, 0.39, 0.44), 2.87
	)


func _wide(id: String) -> void:
	if not _open_air:
		await super._wide(id)
		return
	var camera := _venue_camera()
	if camera == null:
		return
	## Higher and farther inland than the first approach shot. The earlier lens
	## looked across the edge of the arena deck and made the support geometry the
	## subject. This one keeps the court as scale reference while showing the
	## continuous slope, sea, islands and distant ridge beyond it.
	camera.position = Vector3(56.0, 31.0, 72.0)
	camera.fov = 40.0
	camera.look_at(Vector3(-27.0, -5.5, 0.0), Vector3.UP)
	await _settle(4)
	_save("venue_%s_wide.png" % id, "wide")


## One continuous volcanic terrace sheet under the court. The central plateau is
## level where the court/parapets need ground; seaward it breaks into irregular
## sloped benches and reaches the sea without exposing a rectangular base.
func _add_court_landform() -> void:
	var x_sections: Array[float] = [
		43.0, 30.0, 20.0, 8.0, -7.0, -19.0, -29.0,
		-41.0, -55.0, -71.0, -91.0, -117.0,
	]
	var center_heights: Array[float] = [
		-5.0, -1.2, -0.08, -0.05, -0.05, -0.16, -2.8,
		-6.5, -10.8, -15.8, -21.0, -26.2,
	]
	var half_widths: Array[float] = [
		47.0, 38.0, 32.0, 30.0, 30.0, 31.5, 34.0,
		37.5, 42.0, 48.0, 55.0, 64.0,
	]
	const Z_SEGMENTS := 12
	var rows: Array = []
	for ix in range(x_sections.size()):
		var row: Array[Vector3] = []
		var x := x_sections[ix]
		var half_z := half_widths[ix]
		for iz in range(Z_SEGMENTS + 1):
			var u := float(iz) / float(Z_SEGMENTS)
			var zn := u * 2.0 - 1.0
			var progress := float(ix) / float(x_sections.size() - 1)
			var edge_drop := pow(absf(zn), 2.2) * lerpf(2.0, 8.0, progress)
			var relief := 0.52 * sin(float(ix) * 1.31 + float(iz) * 1.87) \
				+ 0.25 * sin(float(ix) * 2.43 - float(iz) * 0.91)
			## Court + regulation free-zone plateau stays physically/readably flat.
			if ix >= 2 and ix <= 5 and absf(zn) < 0.84:
				edge_drop = 0.0
				relief *= 0.05
			var z := zn * half_z + 0.70 * sin(float(ix) * 0.73 + float(iz) * 1.19)
			row.append(Vector3(x, center_heights[ix] - edge_drop + relief, z))
		rows.append(row)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(rows.size() - 1):
		for iz in range(Z_SEGMENTS):
			var a: Vector3 = rows[ix][iz]
			var b: Vector3 = rows[ix + 1][iz]
			var c: Vector3 = rows[ix + 1][iz + 1]
			var d: Vector3 = rows[ix][iz + 1]
			if (ix + iz) % 2 == 0:
				_tri(surface, a, b, c)
				_tri(surface, a, c, d)
			else:
				_tri(surface, a, b, d)
				_tri(surface, b, c, d)
	surface.generate_normals()
	var land := MeshInstance3D.new()
	land.name = "PawaCourtLandform"
	land.mesh = surface.commit()
	_apply_two_sided_terrain(land, Color(0.285, 0.235, 0.205))
	_extras.add_child(land)


func _add_island_plateau(
	name_: String, center: Vector3, radii: Vector2, base_y: float, top_y: float,
	colour: Color, phase: float,
) -> void:
	const SEGMENTS := 13
	var base: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	var crown: Array[Vector3] = []
	for i in range(SEGMENTS):
		var angle := TAU * float(i) / float(SEGMENTS)
		var wobble := 1.0 + 0.13 * sin(float(i) * 2.1 + phase) \
			+ 0.06 * sin(float(i) * 4.6 + phase * 0.7)
		var radial := Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * wobble
		base.append(center + Vector3(radial.x, base_y, radial.y))
		var shoulder_scale := 0.62 + 0.05 * sin(float(i) * 1.4 + phase)
		shoulder.append(center + Vector3(
			radial.x * shoulder_scale,
			lerpf(base_y, top_y, 0.62) + 0.45 * sin(float(i) * 1.7 + phase),
			radial.y * shoulder_scale,
		))
		var crown_scale := 0.30 + 0.055 * sin(float(i) * 2.8 + phase * 1.3)
		crown.append(center + Vector3(
			radial.x * crown_scale + radii.x * 0.06 * sin(phase + 1.4),
			top_y + 0.75 * sin(float(i) * 1.9 + phase),
			radial.y * crown_scale + radii.y * 0.05 * cos(phase + 0.8),
		))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		var j := (i + 1) % SEGMENTS
		_tri(surface, base[i], base[j], shoulder[j])
		_tri(surface, base[i], shoulder[j], shoulder[i])
		_tri(surface, shoulder[i], shoulder[j], crown[j])
		_tri(surface, shoulder[i], crown[j], crown[i])
	var crown_center := center + Vector3(
		radii.x * 0.05 * sin(phase + 1.4), top_y - 0.15,
		radii.y * 0.04 * cos(phase + 0.8)
	)
	for i in range(SEGMENTS):
		_tri(surface, crown[i], crown[(i + 1) % SEGMENTS], crown_center)
	surface.generate_normals()
	var island := MeshInstance3D.new()
	island.name = name_
	island.mesh = surface.commit()
	_apply_two_sided_terrain(island, colour)
	_extras.add_child(island)


func _apply_two_sided_terrain(node: MeshInstance3D, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
