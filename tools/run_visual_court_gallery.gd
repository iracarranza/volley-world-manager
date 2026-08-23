extends "res://tools/run_venue_probe.gd"

## Review renderer for the regional courts.
##
## Uses the production PlayerActor3D + RegionalKits path inherited from
## run_venue_probe.gd, so body markings and kit construction are the same code a
## match uses. Adds two review views: a wide room/setting shot for every venue,
## and a low cinematic volleyball action shot.

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

var _cinematic_restore: Array[Dictionary] = []
var _cinematic_ball: MeshInstance3D


func _shoot(venue: Dictionary) -> void:
	_court = COURT.instantiate()
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
	_frame_broadcast()
	await _settle()
	_save("venue_%s.png" % id, str(venue.get("label", "")))

	await _closeup(id)
	await _wide(id)
	await _cinematic(id)

	_court.queue_free()
	await get_tree().process_frame


func _wide(id: String) -> void:
	if _open_air:
		## Pāwa keeps the purpose-built establishing seat authored by the venue
		## probe: it is the one court whose setting continues beyond the room.
		await _establishing(id)
		## The inherited name is `wide`; nothing else to do.
		return
	var camera := _venue_camera()
	if camera == null:
		return
	## High opposite corner: enough room to read the bowl, fixtures, roof and
	## venue-specific architecture without becoming an architectural elevation.
	camera.position = Vector3(-19.5, 11.5, 20.5)
	camera.fov = 54.0
	camera.look_at(Vector3(0.0, 2.2, 0.0), Vector3.UP)
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
