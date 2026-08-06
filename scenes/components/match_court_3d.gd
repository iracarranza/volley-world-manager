class_name MatchCourt3D
extends Node3D

const FALLBACK_PLAYER_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

@export var court_width: float = 9.0
@export var court_length: float = 18.0
@export var player_actor_scene: PackedScene

@onready var camera_3d: Camera3D = $Camera3D
@onready var ball_actor: BallActor3D = $BallActor3D
@onready var players_container: Node3D = $Players

var player_actors: Dictionary = {}
var live_positions: Dictionary = {}
var home_player_ids: Dictionary = {}
var camera_preset: int = 0
var light_mode_enabled: bool = false

const CAMERA_PRESETS: Array[Dictionary] = [
	{"name": "Broadcast", "position": Vector3(12.5, 8.2, 10.8), "fov": 48.0},
	{"name": "End line", "position": Vector3(0.0, 7.1, 15.8), "fov": 46.0},
	{"name": "High tactical", "position": Vector3(0.0, 15.2, 9.4), "fov": 43.0},
]


func _ready() -> void:
	add_to_group("ui_palette_3d")
	apply_ui_palette(false)
	_apply_camera_preset()
	ball_actor.reset_flight()


func tactical_to_world(tactical_x: float, tactical_y: float, height: float = 0.0) -> Vector3:
	return Vector3(
		(tactical_x - 0.5) * court_width,
		height,
		(tactical_y - 0.5) * court_length,
	)


func setup_players(
	initial_home_positions: Dictionary,
	initial_opponent_positions: Dictionary,
	player_names: Dictionary = {},
	player_handedness: Dictionary = {},
	player_physical_profiles: Dictionary = {},
) -> void:
	for child in players_container.get_children():
		child.free()
	player_actors.clear()
	live_positions.clear()
	home_player_ids.clear()
	for raw_player_id in initial_home_positions:
		_spawn_player(
			int(raw_player_id), Vector2(initial_home_positions[raw_player_id]),
			true, str(player_names.get(int(raw_player_id), "HOME %s" % raw_player_id)),
			str(player_handedness.get(int(raw_player_id), "Right")),
			Dictionary(player_physical_profiles.get(int(raw_player_id), {})),
		)
	for raw_player_id in initial_opponent_positions:
		_spawn_player(
			int(raw_player_id), Vector2(initial_opponent_positions[raw_player_id]),
			false, str(player_names.get(int(raw_player_id), "AWAY %s" % raw_player_id)),
			str(player_handedness.get(int(raw_player_id), "Right")),
			Dictionary(player_physical_profiles.get(int(raw_player_id), {})),
		)


func ensure_player(
	player_id: int,
	position: Vector2,
	home_team: bool,
	display_name: String,
	dominant_hand: String = "Right",
	physical_profile: Dictionary = {},
) -> PlayerActor3D:
	if player_actors.has(player_id):
		return player_actors[player_id] as PlayerActor3D
	return _spawn_player(
		player_id, position, home_team, display_name, dominant_hand, physical_profile
	)


func _spawn_player(
	player_id: int,
	position: Vector2,
	home_team: bool,
	display_name: String,
	dominant_hand: String,
	physical_profile: Dictionary,
) -> PlayerActor3D:
	var scene_to_use := player_actor_scene if player_actor_scene != null else FALLBACK_PLAYER_SCENE
	var actor := scene_to_use.instantiate() as PlayerActor3D
	players_container.add_child(actor)
	actor.configure(
		player_id, home_team, display_name, dominant_hand, physical_profile
	)
	actor.apply_ui_palette(light_mode_enabled)
	player_actors[player_id] = actor
	live_positions[player_id] = position
	if home_team:
		home_player_ids[player_id] = true
	actor.set_tactical_position(position, tactical_to_world(position.x, position.y))
	return actor


func apply_ui_palette(light_mode: bool) -> void:
	light_mode_enabled = light_mode
	_apply_mesh_color($ArenaFloor, UIPalette.color(&"court_floor", light_mode))
	_apply_mesh_color($CourtSurface, UIPalette.color(&"court_surface", light_mode))
	for line in [
		$EndLineHome, $EndLineAway, $AttackLineHome, $AttackLineAway,
		$SidelineLeft, $SidelineRight,
	]:
		_apply_mesh_color(line, UIPalette.color(&"court_line", light_mode))
	_apply_mesh_color($Net, UIPalette.color(&"court_net", light_mode), true)
	_apply_mesh_color($LeftPost, UIPalette.color(&"court_post", light_mode), false, 0.18)
	_apply_mesh_color($RightPost, UIPalette.color(&"court_post", light_mode), false, 0.18)
	var environment := $WorldEnvironment.environment.duplicate() as Environment
	environment.background_color = UIPalette.color(&"canvas", light_mode).darkened(0.18)
	environment.ambient_light_color = UIPalette.color(&"ink_muted", light_mode)
	$WorldEnvironment.environment = environment
	for actor in player_actors.values():
		(actor as PlayerActor3D).apply_ui_palette(light_mode)


func _apply_mesh_color(
	mesh_instance: MeshInstance3D,
	color: Color,
	transparent: bool = false,
	metallic: float = 0.0,
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	material.metallic = metallic
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material


func set_player_position(player_id: int, position: Vector2) -> void:
	if not player_actors.has(player_id):
		return
	live_positions[player_id] = position
	var actor := player_actors[player_id] as PlayerActor3D
	actor.set_tactical_position(position, tactical_to_world(position.x, position.y))


func apply_movement_plan(plan: Dictionary, progress: float) -> void:
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var start := Vector2(movement.get("start", live_positions.get(player_id, Vector2.ZERO)))
		var target := Vector2(movement.get("target", start))
		var waypoint: Variant = movement.get("waypoint", null)
		var sample := start.lerp(target, progress)
		if waypoint is Vector2:
			var corner := Vector2(waypoint)
			var first_distance := start.distance_to(corner)
			var second_distance := corner.distance_to(target)
			var corner_progress := first_distance / maxf(first_distance + second_distance, 0.0001)
			if progress <= corner_progress:
				sample = start.lerp(corner, progress / maxf(corner_progress, 0.0001))
			else:
				sample = corner.lerp(
					target, (progress - corner_progress) / maxf(1.0 - corner_progress, 0.0001)
				)
		set_player_position(player_id, sample)


func finish_movement_plan(plan: Dictionary) -> void:
	for raw_player_id in plan:
		var movement: Dictionary = plan[raw_player_id]
		set_player_position(int(raw_player_id), Vector2(movement.get("target", Vector2.ZERO)))


func set_player_pose(
	player_id: int,
	event_type: int,
	elevation: float,
	phase: float,
	direction: Vector2,
	highlighted: bool,
	contact_posture: String = "planted",
	contact_recovery: String = "platform",
) -> void:
	if not player_actors.has(player_id):
		return
	var actor := player_actors[player_id] as PlayerActor3D
	actor.set_highlighted(highlighted)
	## Carried rather than derived here. The resolver already decided how
	## strained this contact was; the court's job is to hand that verdict to the
	## actor, not to form a second opinion from the positions.
	actor.contact_posture = contact_posture
	actor.contact_recovery = contact_recovery
	actor.set_pose(event_type, elevation, phase, direction, highlighted)


func reset_player_poses() -> void:
	for actor_resource in player_actors.values():
		var actor := actor_resource as PlayerActor3D
		actor.set_highlighted(false)
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


func trajectory_world_position(trajectory: Dictionary, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var start := Vector2(trajectory.get("start_position", Vector2(0.5, 0.5)))
	var control := Vector2(trajectory.get("control_position", start.lerp(
		Vector2(trajectory.get("end_position", start)), 0.5
	)))
	var end := Vector2(trajectory.get("end_position", start))
	var inverse := 1.0 - t
	var court_position := inverse * inverse * start \
		+ 2.0 * inverse * t * control + t * t * end
	var start_height := float(trajectory.get("start_height_meters", 1.0))
	var end_height := float(trajectory.get("end_height_meters", 1.0))
	var apex_height := float(trajectory.get("apex_height_meters", 1.0))
	var base_height := lerpf(start_height, end_height, t)
	var midpoint_height := lerpf(start_height, end_height, 0.5)
	var arc_height := maxf(apex_height - midpoint_height, 0.0)
	var height := base_height + 4.0 * arc_height * t * (1.0 - t)
	return tactical_to_world(court_position.x, court_position.y, height)


func trajectory_world_velocity(trajectory: Dictionary, progress: float) -> Vector3:
	var lower := maxf(progress - 0.004, 0.0)
	var upper := minf(progress + 0.004, 1.0)
	if is_equal_approx(lower, upper):
		return Vector3.ZERO
	return (trajectory_world_position(trajectory, upper) \
		- trajectory_world_position(trajectory, lower)) / (upper - lower)


func set_ball_trajectory_sample(trajectory: Dictionary, progress: float) -> void:
	var ball_position := trajectory_world_position(trajectory, progress)
	ball_actor.set_flight_sample(
		ball_position,
		trajectory_world_velocity(trajectory, progress),
	)
	_watch_the_ball(ball_position)


## Everybody on the court follows the ball with their eyes.
##
## `PlayerActor3D` has had a full head-look since the rig gained a neck -- an
## absolute heading in, clamped to what a neck can actually do, stored relative
## to the body so a player can watch the ball without turning to it. It had
## never been called. Twelve volis stared straight ahead through every rally
## while the machinery to do otherwise sat there complete.
##
## Driven from the ball's own sampled position rather than from the event's end
## point, so a head tracks the *flight* and not the destination -- watching
## where a ball is going to land is what a spectator does, not a player.
func _watch_the_ball(ball_position: Vector3) -> void:
	for raw_id in player_actors:
		var actor := player_actors[raw_id] as PlayerActor3D
		if actor == null:
			continue
		var offset := ball_position - actor.global_position
		var flat := Vector2(offset.x, offset.z)
		if flat.length_squared() < 0.0004:
			continue
		## Same convention as every other heading in the rig: Godot's forward is
		## -Z, so a direction (dx, dz) is `atan2(-dx, -dz)`. `flat` already holds
		## that pair, so the world's z is its y.
		var heading := atan2(-flat.x, -flat.y)
		## Pitch from the ball's height above the eyes rather than above the
		## floor -- a tall voli looks *down* at a ball a short one looks up at.
		var eye_height := actor.global_position.y + actor.shoulder_offset.y + 0.18
		var rise := ball_position.y - eye_height
		actor.look_toward(heading, rad_to_deg(atan2(rise, flat.length())))


func cycle_camera() -> String:
	camera_preset = (camera_preset + 1) % CAMERA_PRESETS.size()
	_apply_camera_preset()
	return str(CAMERA_PRESETS[camera_preset]["name"])


func _apply_camera_preset() -> void:
	if camera_3d == null:
		return
	var preset: Dictionary = CAMERA_PRESETS[camera_preset]
	camera_3d.position = Vector3(preset["position"])
	camera_3d.fov = float(preset["fov"])
	camera_3d.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
