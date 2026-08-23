class_name DynamicCourtCamera
extends Node

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

var free_enabled: bool = false
var follow_player_id: int = -1
var orbit_target := Vector3(0.0, 1.1, 0.0)
var orbit_yaw: float = 0.0
var orbit_elevation: float = deg_to_rad(28.0)
var orbit_distance: float = 18.0
var _dragging: bool = false
var _known_player_signature: String = ""

var _court: MatchCourt3D
var _free_button: Button
var _follow_option: OptionButton
var _camera_button: Button


func _ready() -> void:
	_court = get_node_or_null(court_path) as MatchCourt3D
	set_process(true)
	set_process_unhandled_input(true)
	call_deferred("_build_controls")


func _process(delta: float) -> void:
	if _court == null or not is_instance_valid(_court):
		_court = get_node_or_null(court_path) as MatchCourt3D
		return
	_refresh_players_if_needed()
	if not free_enabled:
		return
	var desired := Vector3(0.0, 1.1, 0.0)
	if follow_player_id >= 0:
		var actor := _court.actor_for(follow_player_id)
		if actor != null and is_instance_valid(actor):
			desired = actor.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
		else:
			follow_player_id = -1
	var response := 1.0 - exp(-FOLLOW_RESPONSE * maxf(delta, 0.0))
	orbit_target = orbit_target.lerp(desired, response)
	_apply_free_camera()


func _unhandled_input(event: InputEvent) -> void:
	var root := get_parent() as Control
	if root == null or not root.visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mouse.pressed
			if mouse.pressed:
				enable_free(true)
			get_viewport().set_input_as_handled()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			enable_free(true)
			zoom_steps(1.0)
			get_viewport().set_input_as_handled()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			enable_free(true)
			zoom_steps(-1.0)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		enable_free(true)
		orbit(Vector2(motion.relative))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		enable_free(true)
		zoom_steps(log(maxf(gesture.factor, 0.001)) / log(1.0 / ZOOM_FACTOR_PER_STEP))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		enable_free(true)
		orbit(pan.delta * 6.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_V:
				enable_free(not free_enabled)
				get_viewport().set_input_as_handled()
			KEY_F:
				_cycle_follow()
				get_viewport().set_input_as_handled()
			KEY_HOME:
				follow_player_id = -1
				orbit_target = Vector3(0.0, 1.1, 0.0)
				enable_free(true)
				_select_follow_for_id(-1)
				get_viewport().set_input_as_handled()


func enable_free(enabled: bool) -> void:
	if _court == null or _court.camera_3d == null:
		return
	if enabled and not free_enabled:
		_capture_current_view()
	free_enabled = enabled
	if _free_button != null:
		_free_button.button_pressed = free_enabled
		_free_button.text = "Free view" if not free_enabled else "Free: on"
	if free_enabled:
		_apply_free_camera()


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
	follow_player_id = player_id
	enable_free(true)
	_select_follow_for_id(player_id)


func _capture_current_view() -> void:
	var camera := _court.camera_3d
	var target := orbit_target
	if follow_player_id >= 0:
		var actor := _court.actor_for(follow_player_id)
		if actor != null:
			target = actor.global_position + Vector3(0.0, FOLLOW_HEIGHT, 0.0)
	else:
		target = Vector3(0.0, 1.1, 0.0)
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


func _build_controls() -> void:
	var root := get_parent()
	if root == null:
		return
	var controls := root.get_node_or_null("HUD/TopPanel/Margin/Controls") as HBoxContainer
	if controls == null:
		return
	_camera_button = root.get_node_or_null("HUD/TopPanel/Margin/Controls/CameraButton") as Button
	var close_button := root.get_node_or_null("HUD/TopPanel/Margin/Controls/CloseButton") as Button

	_free_button = Button.new()
	_free_button.name = "FreeCameraButton"
	_free_button.text = "Free view"
	_free_button.toggle_mode = true
	_free_button.custom_minimum_size = Vector2(88.0, 0.0)
	_free_button.tooltip_text = "Free camera (V): right-drag orbit, wheel zoom"
	_free_button.toggled.connect(func(on: bool) -> void: enable_free(on))
	controls.add_child(_free_button)
	if close_button != null:
		controls.move_child(_free_button, close_button.get_index())

	_follow_option = OptionButton.new()
	_follow_option.name = "CameraFollowOption"
	_follow_option.custom_minimum_size = Vector2(122.0, 0.0)
	_follow_option.tooltip_text = "Follow a player (F cycles)"
	_follow_option.item_selected.connect(_follow_selected)
	controls.add_child(_follow_option)
	if close_button != null:
		controls.move_child(_follow_option, close_button.get_index())

	if _camera_button != null:
		## Static preset selection should always win over the free camera. Connected
		## deferred so MatchScreen's existing cycle handler runs first.
		_camera_button.pressed.connect(func() -> void:
			free_enabled = false
			follow_player_id = -1
			if _free_button != null:
				_free_button.set_pressed_no_signal(false)
				_free_button.text = "Free view"
			_select_follow_for_id(-1)
		)
	_refresh_players(true)


func _refresh_players_if_needed() -> void:
	if _court == null:
		return
	var ids: Array = _court.player_actors.keys()
	ids.sort()
	var signature := ",".join(ids.map(func(id): return str(id)))
	if signature != _known_player_signature:
		_refresh_players(true)


func _refresh_players(force: bool = false) -> void:
	if _follow_option == null or _court == null:
		return
	var ids: Array = _court.player_actors.keys()
	ids.sort()
	var signature := ",".join(ids.map(func(id): return str(id)))
	if not force and signature == _known_player_signature:
		return
	_known_player_signature = signature
	var wanted := follow_player_id
	_follow_option.clear()
	_follow_option.add_item("Follow: court")
	_follow_option.set_item_metadata(0, -1)
	for raw_id in ids:
		var id := int(raw_id)
		var actor := _court.actor_for(id)
		## `voli_name`, not `display_name`: `PlayerActor3D` has never had the
		## latter. Reading a property that does not exist is an error rather than
		## a null, so this did not fall through to the "Voli %d" default below --
		## it took the match view down as the follow list was built.
		var label := str(actor.voli_name).strip_edges() if actor != null else ""
		if label.is_empty():
			label = "Voli %d" % id
		_follow_option.add_item(label)
		_follow_option.set_item_metadata(_follow_option.item_count - 1, id)
	_select_follow_for_id(wanted)


func _follow_selected(index: int) -> void:
	if _follow_option == null or index < 0 or index >= _follow_option.item_count:
		return
	follow(int(_follow_option.get_item_metadata(index)))


func _select_follow_for_id(player_id: int) -> void:
	if _follow_option == null:
		return
	for index in range(_follow_option.item_count):
		if int(_follow_option.get_item_metadata(index)) == player_id:
			_follow_option.select(index)
			return
	_follow_option.select(0)


func _cycle_follow() -> void:
	if _follow_option == null or _follow_option.item_count <= 1:
		follow(-1)
		return
	var next := (_follow_option.selected + 1) % _follow_option.item_count
	_follow_option.select(next)
	_follow_selected(next)
