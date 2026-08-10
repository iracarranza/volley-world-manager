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


## Court-space movement below this is a rounding artefact, not a direction.
const TRAVEL_HEADING_FLOOR: float = 0.0025


func set_player_position(player_id: int, position: Vector2) -> void:
	if not player_actors.has(player_id):
		return
	## **Step 9: a travelling voli faces where they are going.**
	##
	## `has_facing` and `facing_yaw` were set in exactly three places -- inside
	## the actor's own `_turn_toward`, and the two offline tools. Neither this
	## file nor `match_screen.gd` touched them, so during a rally an actor only
	## ever turned at the instant of a contact pose and then held that heading
	## for the rest of the point. A voli who had not touched the ball had no
	## heading at all.
	##
	## The machinery was complete the whole time -- a turn rate, a neck limit, an
	## independent head look. Nothing drove it. A moving body's heading is its
	## velocity, which is a fact this method already holds every frame and was
	## discarding.
	##
	## Below the floor the step is noise rather than a direction: a body that has
	## effectively stopped keeps the heading it had rather than spinning to chase
	## a rounding error.
	var previous: Vector2 = live_positions.get(player_id, position)
	live_positions[player_id] = position
	var actor := player_actors[player_id] as PlayerActor3D
	var step := position - previous
	if step.length() >= TRAVEL_HEADING_FLOOR:
		var world_step := tactical_to_world(position.x, position.y) \
			- tactical_to_world(previous.x, previous.y)
		actor.face_travel(atan2(-world_step.x, -world_step.z))
	actor.set_tactical_position(position, tactical_to_world(position.x, position.y))


## How far along its own journey a leg is, which is not how far along the ball is.
##
## Every leg used to be sampled at the ball's `progress`, so a long walk inside a
## short flight was simply drawn fast -- unboundedly so. A plan entry may now
## carry `seconds`, the time the leg actually takes at the player's own top
## speed; where it does, the leg is sampled against that clock and is allowed to
## still be in progress when the flight ends. The next window's plan starts from
## wherever the body got to, so an unfinished leg continues rather than snapping.
##
## Entries without `seconds`, and calls that pass no window, keep the old
## behaviour exactly: the leg is the flight.
func _plan_fraction(
	movement: Dictionary, progress: float, window_seconds: float
) -> float:
	var leg_seconds := float(movement.get("seconds", 0.0))
	if leg_seconds <= 0.0 or window_seconds <= 0.0:
		return clampf(progress, 0.0, 1.0)
	return clampf(progress * window_seconds / leg_seconds, 0.0, 1.0)


## Where a leg is at a given fraction of itself, corner included.
func _plan_sample(movement: Dictionary, fraction: float, fallback: Vector2) -> Vector2:
	var start := Vector2(movement.get("start", fallback))
	var target := Vector2(movement.get("target", start))
	var waypoint: Variant = movement.get("waypoint", null)
	if not (waypoint is Vector2):
		return start.lerp(target, fraction)
	var corner := Vector2(waypoint)
	var first_distance := start.distance_to(corner)
	var second_distance := corner.distance_to(target)
	var corner_fraction := first_distance / maxf(first_distance + second_distance, 0.0001)
	if fraction <= corner_fraction:
		return start.lerp(corner, fraction / maxf(corner_fraction, 0.0001))
	return corner.lerp(
		target, (fraction - corner_fraction) / maxf(1.0 - corner_fraction, 0.0001)
	)


func apply_movement_plan(
	plan: Dictionary, progress: float, window_seconds: float = 0.0
) -> void:
	## Everyone gets sampled, including the players who are not going anywhere.
	##
	## The actor's gait is driven by the distance between successive placements,
	## so a player who stops being placed keeps whatever speed they last had --
	## and `set_pose` reads that every frame, so they hold a mid-stride pose
	## indefinitely. Frozen mid-stride is exactly the thing the gait model's own
	## test forbids at zero speed, arrived at from outside the model.
	##
	## Re-placing a stationary player at their current position costs a Vector2
	## compare and lets their speed estimate decay to zero, which puts their legs
	## under them. It matters much more now that standing still is the default
	## rather than something almost nobody did.
	for raw_player_id in live_positions:
		if plan.has(raw_player_id):
			continue
		set_player_position(int(raw_player_id), Vector2(live_positions[raw_player_id]))
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var fallback: Vector2 = live_positions.get(player_id, Vector2.ZERO)
		set_player_position(player_id, _plan_sample(
			movement, _plan_fraction(movement, progress, window_seconds), fallback
		))


## Settle every leg where the window actually left it.
##
## This used to snap unconditionally to `target`, which was harmless while every
## leg finished with the flight and is not harmless now that a leg may be paced
## slower than the ball. A leg still travelling is left where it got to and
## picked up by the next window's plan, which starts from live positions.
func finish_movement_plan(plan: Dictionary, window_seconds: float = 0.0) -> void:
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var fallback: Vector2 = live_positions.get(player_id, Vector2.ZERO)
		set_player_position(player_id, _plan_sample(
			movement, _plan_fraction(movement, 1.0, window_seconds), fallback
		))


## The actor for a voli, or null. Public because a caller that needs to know
## where a body is *facing* -- to measure a platform against it, say -- cannot
## get that from a position.
func actor_for(player_id: int) -> PlayerActor3D:
	return player_actors.get(player_id) as PlayerActor3D


func set_player_pose(
	player_id: int,
	event_type: int,
	elevation: float,
	phase: float,
	direction: Vector2,
	highlighted: bool,
	contact_posture: String = "planted",
	contact_recovery: String = "platform",
	## Where the forearms have to point, solved by `PlatformAim` from the two
	## flights on the event. Empty for every contact that is not a pass, and for
	## a pass whose trajectories were not published -- the posture's own constant
	## is then still the fallback.
	platform_aim: Dictionary = {},
	action_context: Dictionary = {},
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
	actor.contact_platform_aim = platform_aim
	actor.set_pose(
		event_type, elevation, phase, direction, highlighted, action_context
	)


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
	## The same parabola `BallTrajectory.height_at_progress` draws, from the same
	## function, because it is the same ball. These were two hand-kept copies of
	## one curve -- the court sampled a Dictionary and the resource sampled its own
	## fields -- and a court that disagreed with the model about where the ball was
	## would have been invisible until something checked one against the other.
	var height := BallFlightModel.height_between(
		float(trajectory.get("start_height_meters", 1.0)),
		float(trajectory.get("end_height_meters", 1.0)),
		float(trajectory.get("duration", 0.5)),
		t,
	)
	return tactical_to_world(court_position.x, court_position.y, height)


func trajectory_world_velocity(trajectory: Dictionary, progress: float) -> Vector3:
	var lower := maxf(progress - 0.004, 0.0)
	var upper := minf(progress + 0.004, 1.0)
	if is_equal_approx(lower, upper):
		return Vector3.ZERO
	return (trajectory_world_position(trajectory, upper) \
		- trajectory_world_position(trajectory, lower)) / (upper - lower)


## What this flight is going to look like, before its first frame.
##
## The colour and weight belong to the contact that launched the ball, so they
## are set once here rather than recomputed every frame from a sample -- a trail
## that changed colour halfway down a flight would be saying the contact changed
## its mind. `light_mode_enabled` is read because the grade palette has a light
## variant and a gold trail on a pale court has to be a darker gold to read.
func begin_ball_flight(trajectory: Dictionary, quality: float) -> void:
	var style := BallPresentation.trail_style(
		quality, trajectory, light_mode_enabled
	)
	ball_actor.set_flight_style(Color(style.color), float(style.power))


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


## The rally's cognition stream, and the sampler both playback paths share.
##
## `active_by_player_for_spectators` rather than the unfiltered sampler the
## tactical board uses: this presentation is a camera in a gym and a setter's
## private weighing of three options is not something a camera can see. That is
## the only difference between the two renderers, and it is a difference of
## audience rather than of meaning -- everything about *what* a cue means is
## decided once, in `CognitionBadge`.
var cognition_cues: Array = []


func set_cognition_stream(cues: Array) -> void:
	cognition_cues = cues
	clear_cognition()


func sample_cognition(simulation_time: float) -> void:
	if cognition_cues.is_empty():
		return
	var active: Dictionary = CognitionTimeline.active_by_player_for_spectators(
		cognition_cues, simulation_time
	)
	for raw_id in player_actors:
		var player_id := int(raw_id)
		var actor := player_actors[player_id] as PlayerActor3D
		if actor == null:
			continue
		var cue: Resource = active.get(player_id) as Resource
		if cue == null:
			actor.hide_cognition_cue()
			continue
		actor.show_cognition_cue(cue)
		_apply_cognition_look(actor, cue)


## A cue that names something on the court also turns the head toward it.
##
## Through the actor's existing `look_toward`, so the cognition layer never
## learns how a neck works -- and only when the cue actually names a place. With
## no attention cue the existing ball tracking is left alone, which is what the
## handoff asks for and is also the honest default: a player with nothing
## particular in mind is watching the ball.
func _apply_cognition_look(actor: PlayerActor3D, cue: Resource) -> void:
	var target := Vector2.ZERO
	match str(cue.attention_kind):
		"hitter", "setter", "teammate":
			var other := int(cue.attention_player_id)
			if not live_positions.has(other):
				return
			target = Vector2(live_positions[other])
		"position":
			target = Vector2(cue.attention_position)
		_:
			return
	var from: Vector2 = live_positions.get(int(cue.player_id), Vector2(0.5, 0.5))
	var delta := tactical_to_world(target.x, target.y) \
		- tactical_to_world(from.x, from.y)
	if delta.length() < 0.05:
		return
	actor.look_toward(atan2(delta.x, delta.z))


func clear_cognition() -> void:
	for raw_id in player_actors:
		var actor := player_actors[raw_id] as PlayerActor3D
		if actor != null:
			actor.hide_cognition_cue()
			actor.clear_look()
