class_name DynamicCourtCamera
extends Node

signal mode_changed(mode: StringName, player_id: int)

## Presentation-only camera control for the 3D match viewer.
##
## The rally owns bodies and ball. This node reads their rendered transforms and
## moves only Camera3D. It therefore cannot alter contact positions, movement
## plans, simulation time or any other gameplay state.

@export var court_path: NodePath

const MIN_DISTANCE: float = 5.5
const MAX_DISTANCE: float = 46.0
const MIN_ELEVATION: float = deg_to_rad(7.0)
const MAX_ELEVATION: float = deg_to_rad(78.0)
const DRAG_RADIANS_PER_PIXEL: float = 0.0055
const ZOOM_FACTOR_PER_STEP: float = 0.86
const FOLLOW_HEIGHT: float = 1.15
const FOLLOW_RESPONSE: float = 8.0
const FOLLOW_DISTANCE: float = 9.0

var free_enabled: bool = false
var follow_player_id: int = -1
var orbit_target := Vector3(0.0, 1.1, 0.0)
var orbit_yaw: float = 0.0
var orbit_elevation: float = deg_to_rad(28.0)
var orbit_distance: float = 18.0
var _dragging: bool = false

var _court: MatchCourt3D


func _ready() -> void:
	_court = get_node_or_null(court_path) as MatchCourt3D
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if _court == null or not is_instance_valid(_court):
		_court = get_node_or_null(court_path) as MatchCourt3D
		return
	if not free_enabled:
		return
	var desired := Vector3(0.0, 1.1, 0.0)
	if follow_player_id >= 0:
		var actor := _court.actor_for(follow_player_id)
		if actor != null and is_instance_valid(actor):
			desired = actor.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
		else:
			follow_player_id = -1
			_court.set_camera_follow_target(-1)
			mode_changed.emit(&"free", -1)
	var response := 1.0 - exp(-FOLLOW_RESPONSE * maxf(delta, 0.0))
	orbit_target = orbit_target.lerp(desired, response)
	_apply_free_camera()


## Keyboard camera affordances remain global while the Match View is open.
## Pointer gestures are accepted explicitly from the court viewport through
## `handle_court_input`, so clicking broadcast controls can never orbit it.
func _unhandled_input(event: InputEvent) -> void:
	var root := get_parent() as Control
	if root == null or not root.visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] \
				and not mouse.pressed:
			_dragging = false
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_V:
			if free_enabled and follow_player_id < 0:
				select_preset(_court.camera_preset)
			else:
				enable_free(true)
			get_viewport().set_input_as_handled()
		KEY_F:
			_cycle_follow()
			get_viewport().set_input_as_handled()
		KEY_HOME:
			reset_free_view()
			get_viewport().set_input_as_handled()


## Returns true when the pointer gesture belongs to the camera. MatchScreen
## calls this from the visible court Control's `gui_input`, which is reliable
## even though the rendered court itself lives inside a SubViewport.
func handle_court_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mouse.pressed
			if mouse.pressed:
				enable_free(true)
			return true
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			enable_free(true)
			zoom_steps(1.0)
			return true
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			enable_free(true)
			zoom_steps(-1.0)
			return true
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		enable_free(true)
		orbit(Vector2(motion.relative))
		return true
	if event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		enable_free(true)
		zoom_steps(log(maxf(gesture.factor, 0.001)) / log(1.0 / ZOOM_FACTOR_PER_STEP))
		return true
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		enable_free(true)
		orbit(pan.delta * 6.0)
		return true
	return false


func select_preset(index: int) -> String:
	if _court == null:
		return ""
	free_enabled = false
	follow_player_id = -1
	_dragging = false
	_court.set_camera_follow_target(-1)
	var name := _court.set_camera_preset(index)
	mode_changed.emit(&"preset", -1)
	return name


func enable_free(enabled: bool) -> void:
	if _court == null or _court.camera_3d == null:
		return
	if not enabled:
		select_preset(_court.camera_preset)
		return
	if not free_enabled:
		follow_player_id = -1
		_court.set_camera_follow_target(-1)
		_capture_current_view(Vector3(0.0, 1.1, 0.0))
	free_enabled = true
	_apply_free_camera()
	mode_changed.emit(&"free", -1)


func reset_free_view() -> void:
	follow_player_id = -1
	free_enabled = true
	_court.set_camera_follow_target(-1)
	orbit_target = Vector3(0.0, 1.1, 0.0)
	orbit_yaw = deg_to_rad(58.0)
	orbit_elevation = deg_to_rad(30.0)
	orbit_distance = 19.0
	_apply_free_camera()
	mode_changed.emit(&"free", -1)


func orbit(pixel_delta: Vector2) -> void:
	orbit_yaw -= pixel_delta.x * DRAG_RADIANS_PER_PIXEL
	orbit_elevation = clampf(
		orbit_elevation - pixel_delta.y * DRAG_RADIANS_PER_PIXEL,
		MIN_ELEVATION, MAX_ELEVATION,
	)
	_apply_free_camera()


func zoom_steps(steps: float) -> void:
	orbit_distance = clampf(
		orbit_distance * pow(ZOOM_FACTOR_PER_STEP, steps), MIN_DISTANCE, MAX_DISTANCE
	)
	_apply_free_camera()


func follow(player_id: int) -> void:
	if _court == null:
		return
	if player_id < 0:
		enable_free(true)
		return
	var actor := _court.actor_for(player_id)
	if actor == null:
		enable_free(true)
		return
	var entering_follow := follow_player_id < 0
	follow_player_id = player_id
	free_enabled = true
	_court.set_camera_follow_target(player_id)
	orbit_target = actor.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
	if entering_follow:
		orbit_yaw = deg_to_rad(72.0)
		orbit_elevation = deg_to_rad(24.0)
		orbit_distance = FOLLOW_DISTANCE
	_apply_free_camera()
	mode_changed.emit(&"follow", player_id)


func player_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _court == null:
		return entries
	var ids: Array = _court.player_actors.keys()
	ids.sort_custom(func(a, b):
		var a_home := _court.home_player_ids.has(int(a))
		var b_home := _court.home_player_ids.has(int(b))
		if a_home != b_home:
			return a_home
		return int(a) < int(b)
	)
	for raw_id in ids:
		var player_id := int(raw_id)
		var actor := _court.actor_for(player_id)
		var identity := str(actor.identity_label.text).strip_edges() \
			if actor != null else "Voli %d" % player_id
		entries.append({
			"id": player_id,
			"home": _court.home_player_ids.has(player_id),
			"label": "%s · %s" % [
				"HOME" if _court.home_player_ids.has(player_id) else "AWAY",
				identity,
			],
		})
	return entries


func followed_player_label() -> String:
	if follow_player_id < 0 or _court == null:
		return ""
	var actor := _court.actor_for(follow_player_id)
	return str(actor.identity_label.text).strip_edges() if actor != null else ""


func _capture_current_view(target: Vector3) -> void:
	var camera := _court.camera_3d
	orbit_target = target
	var offset := camera.global_position - target
	orbit_distance = clampf(offset.length(), MIN_DISTANCE, MAX_DISTANCE)
	if orbit_distance <= 0.001:
		return
	orbit_elevation = clampf(
		asin(clampf(offset.y / orbit_distance, -1.0, 1.0)),
		MIN_ELEVATION, MAX_ELEVATION,
	)
	orbit_yaw = atan2(offset.x, offset.z)


func _apply_free_camera() -> void:
	if not free_enabled or _court == null or _court.camera_3d == null:
		return
	var horizontal := cos(orbit_elevation) * orbit_distance
	var offset := Vector3(
		sin(orbit_yaw) * horizontal,
		sin(orbit_elevation) * orbit_distance,
		cos(orbit_yaw) * horizontal,
	)
	_court.camera_3d.global_position = orbit_target + offset
	_court.camera_3d.look_at(orbit_target, Vector3.UP)


func _cycle_follow() -> void:
	var entries := player_entries()
	if entries.is_empty():
		enable_free(true)
		return
	var next_index := 0
	for index in range(entries.size()):
		if int(entries[index].id) == follow_player_id:
			next_index = (index + 1) % entries.size()
			break
	follow(int(entries[next_index].id))
