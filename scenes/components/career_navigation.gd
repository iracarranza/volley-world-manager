class_name CareerNavigation
extends Control

## Persistent peer navigation for ordinary career workspaces.
##
## The Desk remains the spatial home, but it is not a mandatory interchange.
## Once the manager is in ordinary career UI, the destinations named by
## MASTER_UI_FLOW.md are peers. This component owns presentation and emits
## destination intent; Application owns the actual routing graph and workspace
## geometry.

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

## These controls pre-date the persistent career header. They remain connected
## for compatibility, but once the global shell is present they must not appear
## as a second navigation system on the same screen.
const JOURNAL_LEGACY_PEERS := [
	"Training", "Scouting", "Housing", "Kitchen", "Encyclopedia",
]
const WORKSPACE_REDUNDANT_ACTIONS := ["Back", "Daily Schedule"]

var _buttons: Dictionary = {}
var _bar: PanelContainer = null
var _active: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Global career chrome, explicitly above ordinary workspace content.
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


func present(active: StringName) -> void:
	_active = active
	visible = not active.is_empty()
	_suppress_visible_workspace_legacy_navigation()
	for key in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == active)


func clear() -> void:
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


func _suppress_visible_workspace_legacy_navigation() -> void:
	var app := get_parent()
	if app == null:
		return
	var host := app.get_node_or_null("CareerWorkspaceHost")
	if host == null:
		return
	for child in host.get_children():
		if child is Control and (child as Control).visible:
			_suppress_legacy_navigation(child as Control)


func _suppress_legacy_navigation(content_screen: Control) -> void:
	for node in content_screen.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		var parent := button.get_parent()
		if parent == null:
			continue
		# Journal used to generate specialist workspace buttons into its own
		# header. The persistent career header now owns those peer destinations.
		if parent.name == &"Header" and button.text in JOURNAL_LEGACY_PEERS:
			button.visible = false
			continue
		# ScreenShell ribbons used Back as a local escape hatch, and Training also
		# duplicated Calendar as Daily Schedule. With peer navigation visible,
		# both are redundant and produce the two-button-language defect.
		if parent.name == &"ScreenRibbon" and button.text in WORKSPACE_REDUNDANT_ACTIONS:
			button.visible = false
