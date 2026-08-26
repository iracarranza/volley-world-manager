class_name CareerNavigation
extends Control

## Persistent peer navigation for ordinary career workspaces.
##
## The Desk remains the spatial home, but it is not a mandatory interchange.
## Once the manager is in ordinary career UI, the destinations named by
## MASTER_UI_FLOW.md are peers. This overlay deliberately lives at Application
## level rather than being copied into each screen, so routing vocabulary,
## active-state behavior, and ordinary Back semantics have one owner.

const HEADER_HEIGHT := 56.0
const DESTINATIONS := [
	{"key": &"desk", "label": "Desk", "method": "_show_desk"},
	{"key": &"journal", "label": "Journal", "method": "_show_journal"},
	{"key": &"calendar", "label": "Calendar", "method": "_show_schedule"},
	{"key": &"training", "label": "Training", "method": "_show_training"},
	{"key": &"scouting", "label": "Scouting", "method": "_show_scouting"},
	{"key": &"housing", "label": "Housing", "method": "_show_accommodation"},
	{"key": &"kitchen", "label": "Kitchen", "method": "_show_kitchen"},
	{"key": &"encyclopedia", "label": "Encyclopedia", "method": "_show_encyclopedia"},
]
const LAZY_SCREENS := [
	"_training_screen", "_scouting_screen", "_schedule_screen",
	"_accommodation_screen", "_kitchen_screen", "_encyclopedia_screen",
]

var _buttons: Dictionary = {}
var _bar: PanelContainer = null
var _rewired: Dictionary = {}
var _last_content_screen: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	# Screens are lazily created and swapped by Application. Polling this tiny set
	# lets the shared shell discover them without giving every workspace a second
	# copy of the navigation contract.
	set_process(true)


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
		var method_name: String = str(destination.method)
		button.pressed.connect(func() -> void: _navigate(key, method_name))
		row.add_child(button)
		_buttons[key] = button


func _process(_delta: float) -> void:
	var application := get_parent()
	if application == null:
		visible = false
		return
	_rewire_lazy_back_routes(application)
	var active := _active_destination(application)
	# Presence modes and pre-career screens own the whole viewport. The header is
	# ordinary career navigation, not a universal game HUD.
	visible = not active.is_empty()
	_update_content_inset(application, active)
	if not visible:
		return
	for key in _buttons:
		(_buttons[key] as Button).button_pressed = key == active


func _active_destination(application: Node) -> StringName:
	var journal := application.get_node_or_null("Journal")
	if journal != null and journal.visible:
		return &"journal"
	var mappings := [
		["_desk_screen", &"desk"],
		["_schedule_screen", &"calendar"],
		["_training_screen", &"training"],
		["_scouting_screen", &"scouting"],
		["_accommodation_screen", &"housing"],
		["_kitchen_screen", &"kitchen"],
		["_encyclopedia_screen", &"encyclopedia"],
	]
	for mapping in mappings:
		var screen = application.get(str(mapping[0]))
		if screen != null and screen.visible:
			return mapping[1]
	return &""


func _active_content_screen(application: Node, active: StringName) -> Control:
	if active == &"journal":
		return application.get_node_or_null("Journal") as Control
	var by_key := {
		&"desk": "_desk_screen", &"calendar": "_schedule_screen",
		&"training": "_training_screen", &"scouting": "_scouting_screen",
		&"housing": "_accommodation_screen", &"kitchen": "_kitchen_screen",
		&"encyclopedia": "_encyclopedia_screen",
	}
	if not by_key.has(active):
		return null
	return application.get(str(by_key[active])) as Control


func _update_content_inset(application: Node, active: StringName) -> void:
	var current := _active_content_screen(application, active)
	if _last_content_screen != null and _last_content_screen != current:
		_last_content_screen.offset_top = 0.0
	_last_content_screen = current
	if current == null:
		return
	# The Desk is a spatial surface and the header may float over its unused top
	# edge. Paper/cork workspaces are inset so their own ribbons never collide
	# with the persistent career header.
	current.offset_top = 0.0 if active == &"desk" else HEADER_HEIGHT


func _rewire_lazy_back_routes(application: Node) -> void:
	# Older specialist screens expose a generic back_requested signal. Application
	# historically wired that signal to Journal (and Schedule back to Training).
	# The canonical architecture instead treats Desk as the spatial home. Rewire
	# those legacy callbacks once when each lazy screen appears; the screens
	# themselves remain presentation-agnostic.
	for property_name in LAZY_SCREENS:
		var screen = application.get(property_name)
		if screen == null:
			continue
		var id := screen.get_instance_id()
		if _rewired.has(id) or not screen.has_signal("back_requested"):
			continue
		for connection in screen.get_signal_connection_list("back_requested"):
			var callable: Callable = connection.callable
			if callable.is_valid():
				screen.disconnect("back_requested", callable)
		var desk_callable := Callable(application, "_show_desk")
		if desk_callable.is_valid():
			screen.connect("back_requested", desk_callable)
		_rewired[id] = true


func _navigate(key: StringName, method_name: String) -> void:
	var application := get_parent()
	if application == null:
		return
	if _active_destination(application) == key:
		return
	if application.has_method(method_name):
		application.call(method_name)
