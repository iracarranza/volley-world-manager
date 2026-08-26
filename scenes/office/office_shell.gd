class_name CanonicalOfficeShell
extends Control

## Persistent renderer for the canonical manager office-bedroom.
## Title, Desk, Calendar, Door and Interview are camera states of one unchanged
## room. Screens are UI overlays above this shell; they never author room geometry.

const CAMERA_NAMES := [&"MainMenu", &"TransitionMid", &"Desk", &"Calendar", &"Door", &"Interview", &"OfficeWide"]
const TITLE_IDLE_SECONDS := 22.0
const TITLE_IDLE_YAW_DEGREES := 1.15
const TITLE_IDLE_PITCH_DEGREES := 0.35
const TITLE_IDLE_BOB_METRES := 0.025

@onready var viewport: SubViewport = %OfficeViewport
@onready var office: Node3D = %CanonicalOfficeLowPoly
@onready var cameras: Node3D = office.get_node("Cameras")

var _active_name: StringName = &"MainMenu"
var _idle_enabled := false
var _idle_t := 0.0
var _main_menu_transform := Transform3D.IDENTITY
var _main_menu_fov := 37.0
var _blend_camera: Camera3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_menu_transform = _camera(&"MainMenu").transform
	_main_menu_fov = _camera(&"MainMenu").fov
	snap_to(&"MainMenu")
	apply_career_state(null)
	set_process(true)


func _process(delta: float) -> void:
	if not _idle_enabled or _active_name != &"MainMenu" or _blend_camera != null:
		return
	_idle_t += delta
	var phase := TAU * (_idle_t / TITLE_IDLE_SECONDS)
	var camera := _camera(&"MainMenu")
	camera.transform = _main_menu_transform
	camera.rotate_y(deg_to_rad(sin(phase) * TITLE_IDLE_YAW_DEGREES))
	camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(cos(phase * 0.73) * TITLE_IDLE_PITCH_DEGREES))
	camera.position.y += sin(phase * 0.57) * TITLE_IDLE_BOB_METRES


func set_title_idle(enabled: bool) -> void:
	_idle_enabled = enabled
	if not enabled:
		_idle_t = 0.0
		var menu := _camera(&"MainMenu")
		menu.transform = _main_menu_transform
		menu.fov = _main_menu_fov


func snap_to(name: StringName) -> void:
	if not name in CAMERA_NAMES:
		push_warning("Unknown office camera: %s" % name)
		return
	_clear_blend_camera()
	for child in cameras.get_children():
		if child is Camera3D:
			(child as Camera3D).current = child.name == name
	_active_name = name
	if name != &"MainMenu":
		set_title_idle(false)


func play_to(name: StringName, duration := 1.35) -> void:
	if not name in CAMERA_NAMES:
		push_warning("Unknown office camera: %s" % name)
		return
	set_title_idle(false)
	var target := _camera(name)
	var source := _current_camera()
	if source == target:
		_active_name = name
		return
	_clear_blend_camera()
	_blend_camera = Camera3D.new()
	_blend_camera.name = "OfficeBlendCamera"
	_blend_camera.transform = source.transform
	_blend_camera.fov = source.fov
	cameras.add_child(_blend_camera)
	_blend_camera.current = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_blend_camera, "transform", target.transform, duration)
	tween.tween_property(_blend_camera, "fov", target.fov, duration)
	await tween.finished
	target.current = true
	_active_name = name
	_clear_blend_camera()


func focus_calendar() -> void:
	await play_to(&"Calendar", 0.72)


func focus_door() -> void:
	await play_to(&"Door", 0.62)


func focus_interview() -> void:
	await play_to(&"Interview", 0.82)


func focus_office_wide() -> void:
	await play_to(&"OfficeWide", 0.78)


func focus_desk() -> void:
	await play_to(&"Desk", 0.72)


func apply_career_state(career: Variant) -> void:
	# History is automatic environmental accretion. A new/no career starts with
	# empty frame anchors; known historical collections reveal frames without the
	# player needing to curate them manually.
	var history_count := _history_event_count(career)
	for i in 4:
		var frame := office.find_child("HistoryFrame%02d" % i, true, false)
		var image := office.find_child("HistoryImage%02d" % i, true, false)
		var show := i < mini(history_count, 4)
		if frame != null:
			frame.visible = show
		if image != null:
			image.visible = show

	# The archive is a slow visual record of elapsed career time. It changes
	# subtly rather than acting like a meter; concrete historical pictures still
	# depend on actual events above.
	var archive := office.find_child("ArchiveBox", true, false) as Node3D
	if archive != null:
		var weeks := 0
		if career != null and "absolute_week" in career:
			weeks = maxi(int(career.absolute_week), 0)
		var fullness := clampf(float(weeks) / 156.0, 0.0, 1.0)
		archive.scale = Vector3(1.0 + fullness * 0.14, 1.0 + fullness * 0.18, 1.0 + fullness * 0.10)


func _history_event_count(career: Variant) -> int:
	if career == null:
		return 0
	var total := 0
	for key in ["history", "club_history", "honours", "trophies", "competition_wins", "major_events", "fan_favorites"]:
		if not key in career:
			continue
		var value = career.get(key)
		match typeof(value):
			TYPE_ARRAY:
				total += Array(value).size()
			TYPE_DICTIONARY:
				total += Dictionary(value).size()
			TYPE_INT, TYPE_FLOAT:
				total += maxi(int(value), 0)
	return total


func _camera(name: StringName) -> Camera3D:
	return cameras.get_node(str(name)) as Camera3D


func _current_camera() -> Camera3D:
	if _blend_camera != null:
		return _blend_camera
	for child in cameras.get_children():
		if child is Camera3D and (child as Camera3D).current:
			return child as Camera3D
	return _camera(_active_name)


func _clear_blend_camera() -> void:
	if _blend_camera != null and is_instance_valid(_blend_camera):
		_blend_camera.queue_free()
	_blend_camera = null
