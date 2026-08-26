class_name CareerNavigation
extends Control

## Persistent peer navigation for ordinary career workspaces.
##
## The Desk remains the spatial home, but it is not a mandatory interchange.
## Once the manager is in ordinary career UI, the destinations named by
## MASTER_UI_FLOW.md are peers. This component owns only presentation and emits
## destination intent; Application owns the actual routing graph.

signal destination_requested(destination: StringName)

const HEADER_HEIGHT := 56.0
const DESTINATIONS := [
	{"key": &"desk", "label": "Desk"},
	{"key": &"journal", "label": "Journal"},
	{"key": &"calendar", "label": "Calendar"},
	{"key": &"training", "label": "Training"},
	{"key": &"scouting", "label": "Scouting"},
	{"key": &"housing", "label": "Housing"},
	{"key": &"kitchen", "label": "Kitchen"},
	{"key": &"encyclopedia", "label": "Encyclopedia"},
]

var _buttons: Dictionary = {}
var _bar: PanelContainer = null
var _active: StringName = &""
var _last_content_screen: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This is global career chrome, not content. Dynamic workspaces may carry
	# their own CanvasItem ordering, so make the contract explicit rather than
	# depending on the order lazy screens happened to be appended to Application.
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	clear()


func _build() -> void:
	_bar = PanelContainer.new()
	_bar.name = "CareerNavigationBar"
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 18.0
	_bar.offset_top = 8.0
	_bar.offset_right = -18.0
	_bar.offset_bottom = 48.0
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	for destination in DESTINATIONS:
		var button := Button.new()
		button.text = str(destination.label)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Open %s" % str(destination.label)
		var key: StringName = destination.key
		button.pressed.connect(func() -> void: _request(key))
		row.add_child(button)
		_buttons[key] = button


func present(active: StringName, content_screen: Control = null, spatial := false) -> void:
	if _last_content_screen != null and _last_content_screen != content_screen:
		_last_content_screen.offset_top = 0.0
	_last_content_screen = content_screen
	_active = active
	visible = not active.is_empty()
	if content_screen != null:
		content_screen.offset_top = 0.0 if spatial else HEADER_HEIGHT
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == active)


func clear() -> void:
	if _last_content_screen != null:
		_last_content_screen.offset_top = 0.0
	_last_content_screen = null
	_active = &""
	visible = false
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(false)


func current_destination() -> StringName:
	return _active


func button_for(key: StringName) -> Button:
	return _buttons.get(key) as Button


func destination_count() -> int:
	return _buttons.size()


func _request(key: StringName) -> void:
	if key == _active:
		return
	destination_requested.emit(key)
