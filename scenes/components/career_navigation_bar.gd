class_name CareerNavigationBar
extends MarginContainer

## Persistent navigation shared by ordinary career workspaces.
##
## MASTER_UI_FLOW.md §0.1 makes these eight destinations peers. This control is
## deliberately presentation-light: it owns destination selection and active
## state, while Application owns what each destination means and when the bar is
## suppressed for title/new-career/presence modes.

signal destination_requested(destination: StringName)

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const DESTINATIONS: Array[Dictionary] = [
	{"id": &"desk", "label": "Desk"},
	{"id": &"journal", "label": "Journal"},
	{"id": &"calendar", "label": "Calendar"},
	{"id": &"training", "label": "Training"},
	{"id": &"scouting", "label": "Scouting"},
	{"id": &"housing", "label": "Housing"},
	{"id": &"kitchen", "label": "Kitchen"},
	{"id": &"encyclopedia", "label": "Encyclopedia"},
]

const HEIGHT := 42.0

var _buttons: Dictionary = {}
var _active: StringName = &""
var _status: Label = null
var _panel: PanelContainer = null


func _ready() -> void:
	name = "CareerNavigation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = HEIGHT
	_build()
	_apply_palette()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		_apply_palette()


func set_active(destination: StringName) -> void:
	_active = destination
	for key in _buttons:
		var button := _buttons[key] as Button
		button.button_pressed = StringName(key) == destination


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for item in DESTINATIONS:
		var destination := item.id as StringName
		var button := Button.new()
		button.text = str(item.label)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Open %s" % item.label
		button.pressed.connect(func() -> void:
			if destination != _active:
				destination_requested.emit(destination)
		)
		_buttons[destination] = button
		row.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_status = Label.new()
	_status.text = ""
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)


func _apply_palette() -> void:
	if _panel == null:
		return
	var light := UIPalette.control_is_light(self)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIPalette.color(&"canvas", light), 0.96)
	style.border_color = Color(UIPalette.color(&"accent", light), 0.48)
	style.border_width_bottom = 1
	_panel.add_theme_stylebox_override(&"panel", style)
	if _status != null:
		_status.add_theme_color_override(&"font_color", UIPalette.color(&"ink_muted", light))
