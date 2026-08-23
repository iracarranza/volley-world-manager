extends "res://tools/run_visual_court_gallery.gd"

## Final review layer after the first 32-frame sheet exposed two remaining visual
## defects: Pāwa's natural backdrop sat behind a rectangular support pyramid,
## and Spëddigh's atmosphere erased too much player/court value. This script
## changes only presentation geometry/light used by the review renderer.


func _review_tune(id: String) -> void:
	super._review_tune(id)
	if id != "speddigh":
		return
	## Keep the cold-air identity without making the room look overexposed.
	## Roof fixtures are the dominant source, so lowering only ambient/fill in the
	## previous pass did not recover enough body value.
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


func _terrace() -> void:
	super._terrace()

	## The base probe's Terrace + Hillside boxes were useful construction
	## placeholders, but from the establishing camera they resolve as a stepped
	## rectangular pyramid. Remove only those support boxes; retain court,
	## parapets, sea, seating and the irregular distant geography built by the
	## parent review layer.
	for child in _extras.get_children():
		var child_name := str(child.name)
		if child_name == "Terrace" or child_name.begins_with("Hillside") \
				or child_name == "PawaShoulder":
			child.queue_free()

	_add_court_landform()

	## A low inland shoulder keeps the court visibly cut into a hillside without
	## becoming a mountain beside the lens. Two overlapping mounds avoid a single
	## repeated-cone silhouette and leave the sea-side drop as the wide shot's
	## dominant spatial cue.
	_add_mound(
		"PawaInlandShoulderA", Vector3(50.0, 0.0, -28.0), Vector2(43.0, 74.0),
		-34.0, 12.0, Color(0.28, 0.24, 0.21), 0.43, Vector2(0.30, 0.12)
	)
	_add_mound(
		"PawaInlandShoulderB", Vector3(63.0, 0.0, 46.0), Vector2(32.0, 49.0),
		-34.0, 8.0, Color(0.30, 0.26, 0.22), 1.37, Vector2(-0.22, -0.18)
	)


## One continuous volcanic terrace sheet under the court. The central plateau is
## level where the court/parapets need ground; seaward it breaks into irregular
## sloped benches and reaches the sea without exposing a rectangular base.
func _add_court_landform() -> void:
	var x_sections: Array[float] = [
		34.0, 20.0, 7.0, -8.0, -19.0, -28.0,
		-40.0, -54.0, -70.0, -89.0, -114.0,
	]
	var center_heights: Array[float] = [
		-1.2, -0.10, -0.06, -0.06, -0.18, -3.1,
		-7.0, -11.5, -16.4, -21.4, -26.2,
	]
	var half_widths: Array[float] = [
		39.0, 32.0, 30.0, 30.0, 31.0, 33.5,
		37.0, 41.5, 47.0, 54.0, 63.0,
	]
	const Z_SEGMENTS := 10
	var rows: Array = []
	for ix in range(x_sections.size()):
		var row: Array[Vector3] = []
		var x := x_sections[ix]
		var half_z := half_widths[ix]
		for iz in range(Z_SEGMENTS + 1):
			var u := float(iz) / float(Z_SEGMENTS)
			var zn := u * 2.0 - 1.0
			var edge_drop := pow(absf(zn), 2.15) * lerpf(1.8, 7.5, float(ix) / float(x_sections.size() - 1))
			var relief := 0.55 * sin(float(ix) * 1.31 + float(iz) * 1.87) \
				+ 0.28 * sin(float(ix) * 2.43 - float(iz) * 0.91)
			## The occupied court/free-zone plateau must remain functionally flat.
			if ix <= 4 and absf(zn) < 0.82:
				edge_drop = 0.0
				relief *= 0.08
			var z := zn * half_z + 0.75 * sin(float(ix) * 0.73 + float(iz) * 1.19)
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
			## Alternate diagonals so the low-poly facets do not form a visible
			## repeated herringbone at distance.
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
	_apply_terrain_material(land, Color(0.285, 0.235, 0.205))
	_extras.add_child(land)
