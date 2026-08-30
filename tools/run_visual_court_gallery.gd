extends "res://tools/run_venue_probe.gd"

## Review renderer for the regional courts.
##
## Uses the production PlayerActor3D + RegionalKits path inherited from
## run_venue_probe.gd, so body markings and kit construction are the same code a
## match uses. Adds a setting view and a low cinematic volleyball action shot.

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

var _cinematic_restore: Array[Dictionary] = []
var _cinematic_ball: MeshInstance3D


func _shoot(venue: Dictionary) -> void:
	var court_scene := load(COURT_PATH) as PackedScene
	_court = court_scene.instantiate()
	add_child(_court)
	await get_tree().process_frame
	_key = _court.get_node("KeyLight") as DirectionalLight3D
	_fill = _court.get_node("FillLight") as OmniLight3D
	var holder := _court.get_node("WorldEnvironment") as WorldEnvironment
	_env = holder.environment.duplicate() as Environment
	holder.environment = _env
	_extras = Node3D.new()
	_extras.name = "VenueExtras"
	_court.add_child(_extras)
	_open_air = bool(venue.get("open_air", false))
	_tight = bool(venue.get("tight", false))
	_arena()
	_roof_lights(str(venue.get("id", "")))
	_fixtures(str(venue.get("id", "")))
	_floor_for(str(venue.get("id", "")))
	_volis(str(venue.get("id", "")))
	var build: Callable = venue.get("build", func(): pass)
	build.call()

	var id := str(venue.get("id", "x"))
	_review_tune(id)
	_frame_broadcast()
	await _settle()
	_save("venue_%s.png" % id, str(venue.get("label", "")))

	await _closeup(id)
	await _wide(id)
	await _cinematic(id)

	_court.queue_free()
	await get_tree().process_frame


## Keep the venue ideas, remove only first-pass overstatement exposed by the
## four-view contact sheet. This is review-layer tuning until approved; the
## canonical venue probe stays untouched.
func _review_tune(id: String) -> void:
	match id:
		"speddigh":
			## Cold mist still reads when bodies retain value. The first gallery
			## pushed the floor and change strip nearly to white from three sources
			## at once: fill, ambient and emissive mist planes.
			_fill.light_energy = 1.25
			_env.ambient_light_energy = 0.76
			for child in _extras.get_children():
				if str(child.name).begins_with("Mist") and child is MeshInstance3D:
					var material := (child as MeshInstance3D).material_override as StandardMaterial3D
					if material != null:
						material.albedo_color.a = 0.10
						material.emission_energy_multiplier = 0.14
		"bloc":
			## Gleam, not blown exposure. The architecture should compete with the
			## wall at the net without bleaching the court itself.
			_env.glow_intensity = 1.05
			_env.glow_bloom = 0.30
			for child in _extras.get_children():
				if str(child.name).begins_with("Window") and child is MeshInstance3D:
					var material := (child as MeshInstance3D).material_override as StandardMaterial3D
					if material != null:
						material.emission_energy_multiplier = 1.55
		_:
			pass


## Pāwa still uses the authored terrace, sea and court. Only the placeholder
## natural forms are replaced here. Box primitives are good architecture; a row
## of boxes is not a mountain range. Continuous faceted meshes give the same
## low-poly language without making the horizon look like a city.
func _terrace() -> void:
	super._terrace()
	for child in _extras.get_children():
		var name := str(child.name)
		if name.begins_with("Ridge") or name.begins_with("FarRange") \
				or name.begins_with("Island") or name.begins_with("Headland") \
				or name == "Shoulder":
			child.queue_free()

	## One connected near range with an irregular crest and a deeper, quieter
	## range behind it. The silhouettes overlap by construction rather than by
	## hoping individual masses happen to touch.
	_add_ridge(
		"PawaNearRidge", -525.0, -690.0, 760.0, 17,
		Color(0.30, 0.34, 0.40), -40.0, 18.0, 23.0, 0.83, 2.17
	)
	_add_ridge(
		"PawaFarRidge", -760.0, -805.0, 940.0, 14,
		Color(0.39, 0.43, 0.49), -44.0, 6.0, 15.0, 1.07, 2.63
	)

	## Four unequal island sites. Each is a pair of overlapping volcanic mounds,
	## not a repeated cone, and every base continues below the sea plane.
	var island_sites := [
		[Vector3(-275.0, 0.0, -180.0), Vector2(38.0, 30.0), -7.0, 0.25],
		[Vector3(-350.0, 0.0, -50.0), Vector2(25.0, 19.0), -13.0, 1.15],
		[Vector3(-310.0, 0.0, 92.0), Vector2(31.0, 24.0), -10.0, 2.05],
		[Vector3(-405.0, 0.0, 205.0), Vector2(20.0, 16.0), -16.0, 2.80],
	]
	for i in range(island_sites.size()):
		var spec: Array = island_sites[i]
		var at: Vector3 = spec[0]
		var radii: Vector2 = spec[1]
		var top := float(spec[2])
		var phase := float(spec[3])
		_add_mound(
			"PawaIsland%dA" % i, at, radii, -43.0, top,
			Color(0.27, 0.32, 0.39).lightened(float(i) * 0.035), phase
		)
		_add_mound(
			"PawaIsland%dB" % i,
			at + Vector3(radii.x * 0.48, 0.0, -radii.y * 0.32),
			radii * Vector2(0.58, 0.66), -43.0, top - 5.0,
			Color(0.29, 0.34, 0.40).lightened(float(i) * 0.035), phase + 0.9
		)

	## The court is cut into the inland shoulder. Keep it low enough that the
	## wide view sees landscape rather than a vertical wall beside the lens.
	_add_mound(
		"PawaShoulder", Vector3(58.0, 0.0, -22.0), Vector2(58.0, 96.0),
		-58.0, 27.0, Color(0.27, 0.23, 0.20), 0.6, Vector2(0.38, 0.17)
	)

	## Long, low headlands break the sea edge without becoming islands the size
	## of the court.
	_add_mound(
		"PawaHeadland0", Vector3(-125.0, 0.0, -170.0), Vector2(42.0, 82.0),
		-44.0, -17.0, Color(0.23, 0.21, 0.20), 1.7, Vector2(0.28, -0.12)
	)
	_add_mound(
		"PawaHeadland1", Vector3(-165.0, 0.0, 176.0), Vector2(36.0, 70.0),
		-44.0, -19.0, Color(0.24, 0.22, 0.20), 2.4, Vector2(-0.22, 0.16)
	)


func _add_ridge(
	name: String, front_x: float, back_x: float, span_z: float, segments: int,
	colour: Color, base_y: float, mean_top: float, relief: float,
	phase_a: float, phase_b: float,
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := span_z * 0.5
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var z0 := lerpf(-half, half, t0)
		var z1 := lerpf(-half, half, t1)
		var top0 := mean_top \
			+ relief * 0.62 * sin(float(i) * phase_a + 0.35) \
			+ relief * 0.38 * sin(float(i) * phase_b + 1.1)
		var top1 := mean_top \
			+ relief * 0.62 * sin(float(i + 1) * phase_a + 0.35) \
			+ relief * 0.38 * sin(float(i + 1) * phase_b + 1.1)
		var crest0 := Vector3(
			lerpf(front_x, back_x, 0.43 + 0.08 * sin(float(i) * 1.41)), top0, z0
		)
		var crest1 := Vector3(
			lerpf(front_x, back_x, 0.43 + 0.08 * sin(float(i + 1) * 1.41)), top1, z1
		)
		var front0 := Vector3(front_x + 18.0 * sin(float(i) * 0.71), base_y, z0)
		var front1 := Vector3(front_x + 18.0 * sin(float(i + 1) * 0.71), base_y, z1)
		var back0 := Vector3(back_x, base_y - 7.0, z0)
		var back1 := Vector3(back_x, base_y - 7.0, z1)
		_tri(surface, front0, front1, crest1)
		_tri(surface, front0, crest1, crest0)
		_tri(surface, crest0, crest1, back1)
		_tri(surface, crest0, back1, back0)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = surface.commit()
	_apply_terrain_material(node, colour)
	_extras.add_child(node)


func _add_mound(
	name: String, center: Vector3, radii: Vector2, base_y: float, top_y: float,
	colour: Color, phase: float, summit_offset: Vector2 = Vector2.ZERO,
) -> void:
	const SEGMENTS := 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	for i in range(SEGMENTS):
		var angle := TAU * float(i) / float(SEGMENTS)
		var wobble := 1.0 + 0.15 * sin(float(i) * 2.3 + phase) \
			+ 0.07 * sin(float(i) * 4.7 + phase * 0.4)
		var radial := Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * wobble
		base.append(center + Vector3(radial.x, base_y, radial.y))
		var inner := radial * (0.45 + 0.08 * sin(float(i) * 1.7 + phase))
		shoulder.append(
			center + Vector3(inner.x, lerpf(base_y, top_y, 0.63), inner.y)
		)
	var summit := center + Vector3(
		summit_offset.x * radii.x, top_y, summit_offset.y * radii.y
	)
	for i in range(SEGMENTS):
		var j := (i + 1) % SEGMENTS
		_tri(surface, base[i], base[j], shoulder[j])
		_tri(surface, base[i], shoulder[j], shoulder[i])
		_tri(surface, shoulder[i], shoulder[j], summit)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = surface.commit()
	_apply_terrain_material(node, colour)
	_extras.add_child(node)


func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _apply_terrain_material(node: MeshInstance3D, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	node.material_override = material


func _wide(id: String) -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	if _open_air:
		## Uphill of the terrace, looking across the court and down toward the sea.
		## The old establishing camera stared into the terrace steps and shoulder;
		## this keeps the court as the scale reference and lets the drop continue
		## behind it.
		camera.position = Vector3(29.0, 18.0, 48.0)
		camera.fov = 51.0
		camera.look_at(Vector3(-18.0, -3.2, 0.0), Vector3.UP)
	else:
		## Inside the room, above the end rake. The first gallery put this camera
		## outside the shell, so seven "wide" views were photographs of a wall.
		camera.position = Vector3(10.6, 9.6, 18.4)
		camera.fov = 55.0
		camera.look_at(Vector3(-1.0, 1.7, -1.2), Vector3.UP)
	await _settle()
	_save("venue_%s_wide.png" % id, "wide")


func _cinematic(id: String) -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	_pose_cinematic()
	## Court-level lens, below shoulder height, looking slightly upward through a
	## hitter and a two-person wall. This is deliberately not a gameplay camera;
	## it is a visual proof that bodies, markings, kits and venue lighting survive
	## the distance at which the player will actually inspect them.
	camera.position = Vector3(6.6, 1.15, 4.1)
	camera.fov = 38.0
	camera.look_at(Vector3(0.0, 2.35, 0.1), Vector3.UP)
	await _settle(4)
	_save("venue_%s_cinematic.png" % id, "cinematic")
	_restore_after_cinematic()


func _pose_cinematic() -> void:
	_cinematic_restore.clear()
	var actors: Array[PlayerActor3D] = []
	for child in _court.get_children():
		if child is PlayerActor3D:
			actors.append(child as PlayerActor3D)
	for actor in actors:
		_cinematic_restore.append({
			"actor": actor,
			"position": actor.position,
			"rotation": actor.rotation,
		})
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)

	var hitter := _actor_by_id(101)
	var blocker_l := _actor_by_id(-100)
	var blocker_r := _actor_by_id(-99)
	if hitter != null:
		hitter.position = Vector3(0.15, 0.0, 2.05)
		hitter.rotation.y = 0.0
		hitter.has_facing = true
		hitter.facing_yaw = 0.0
		hitter.set_pose(
			RallyEventModel.EventType.ATTACK, 0.95, 0.50,
			Vector2(0.0, -1.0), true
		)
	if blocker_l != null:
		blocker_l.position = Vector3(-0.58, 0.0, -1.05)
		blocker_l.rotation.y = PI
		blocker_l.has_facing = true
		blocker_l.facing_yaw = PI
		blocker_l.block_arms = &"two"
		blocker_l.set_pose(
			RallyEventModel.EventType.BLOCK, 0.82, 0.50,
			Vector2(0.0, 1.0), true
		)
	if blocker_r != null:
		blocker_r.position = Vector3(0.58, 0.0, -1.05)
		blocker_r.rotation.y = PI
		blocker_r.has_facing = true
		blocker_r.facing_yaw = PI
		blocker_r.block_arms = &"two"
		blocker_r.set_pose(
			RallyEventModel.EventType.BLOCK, 0.78, 0.48,
			Vector2(0.0, 1.0), true
		)
	_add_cinematic_ball()


func _actor_by_id(id: int) -> PlayerActor3D:
	for child in _court.get_children():
		if child is PlayerActor3D and (child as PlayerActor3D).player_id == id:
			return child as PlayerActor3D
	return null


func _add_cinematic_ball() -> void:
	_cinematic_ball = MeshInstance3D.new()
	_cinematic_ball.name = "CinematicBall"
	var sphere := SphereMesh.new()
	sphere.radius = 0.105
	sphere.height = 0.21
	sphere.radial_segments = 16
	sphere.rings = 8
	_cinematic_ball.mesh = sphere
	_cinematic_ball.position = Vector3(0.18, 3.15, 0.42)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.94, 0.82, 0.25)
	material.roughness = 0.72
	_cinematic_ball.material_override = material
	_court.add_child(_cinematic_ball)


func _restore_after_cinematic() -> void:
	if is_instance_valid(_cinematic_ball):
		_cinematic_ball.queue_free()
	for state in _cinematic_restore:
		var actor := state.get("actor") as PlayerActor3D
		if actor == null or not is_instance_valid(actor):
			continue
		actor.position = Vector3(state.get("position", actor.position))
		actor.rotation = Vector3(state.get("rotation", actor.rotation))
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
	_cinematic_restore.clear()


func _settle(frames: int = 2) -> void:
	for _i in range(frames):
		await get_tree().process_frame


func _save(filename: String, label: String) -> void:
	var path := "user://%s" % filename
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [ProjectSettings.globalize_path(path), label])
