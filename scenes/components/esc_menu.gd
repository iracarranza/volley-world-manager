class_name EscMenu
extends Control

## The things that are not the game.
##
## Saving, quitting, loading somebody else's career and choosing a theme were
## four buttons in the journal's top row, sitting beside Training and Scouting as
## though they were the same kind of thing. They are not: Training is somewhere
## you go inside a career, and Save Career is something you do *to* one. Mixing
## them costs the ribbon two slots and tells a manager that leaving is as
## ordinary as opening the clipboard.
##
## So they live behind Escape, which is where every game keeps them, and the
## ribbon gets the room back for rooms.
##
## ## An overlay rather than a scene
##
## Same reasoning as `DeskPopup`, and it has to be even more true here: this must
## be openable from *any* screen, including the match centre, without any of them
## knowing it exists. It hangs off the application root as the last child, above
## the wipe, and takes input before anything under it.
const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal resume_requested
signal save_requested
signal load_requested(save_id: String)
signal title_requested
signal theme_requested(theme_name: String)
signal quit_requested

const FRAME := Vector2(420.0, 480.0)

var _saves: VBoxContainer = null
var _theme_row: HBoxContainer = null
var _career_actions: VBoxContainer = null
var _theme_name: String = "dark"


static func build() -> EscMenu:
	var menu := EscMenu.new()
	menu._compose()
	return menu


func _compose() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_scrim_input)

	var scrim := _Scrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = FRAME
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var resume := Button.new()
	resume.text = "Back to it"
	resume.pressed.connect(close_menu)
	column.add_child(resume)

	## Career actions, hidden when there is no career -- the menu is reachable
	## from the title screen too, and offering to save nothing is a button that
	## does nothing.
	_career_actions = VBoxContainer.new()
	_career_actions.add_theme_constant_override("separation", 6)
	column.add_child(_career_actions)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(func() -> void: save_requested.emit())
	_career_actions.add_child(save)
	var title_button := Button.new()
	title_button.text = "Quit to title"
	title_button.pressed.connect(func() -> void:
		close_menu()
		title_requested.emit()
	)
	_career_actions.add_child(title_button)

	_heading(column, "Theme")
	_theme_row = HBoxContainer.new()
	_theme_row.add_theme_constant_override("separation", 6)
	column.add_child(_theme_row)
	## Two, and they are named rather than described. `Mikasa` and `Molten` are
	## what this interface calls its themes everywhere else, and a settings pane
	## that said `Dark` and `Light` would be the only place in the game that does
	## not.
	for pair in [["Mikasa", "dark"], ["Molten", "light"]]:
		var button := Button.new()
		button.text = str(pair[0])
		button.toggle_mode = true
		var value := str(pair[1])
		button.pressed.connect(func() -> void:
			_theme_name = value
			_refresh_theme_buttons()
			theme_requested.emit(value)
		)
		_theme_row.add_child(button)

	_heading(column, "Other careers")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_saves = VBoxContainer.new()
	_saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saves.add_theme_constant_override("separation", 4)
	scroll.add_child(_saves)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: quit_requested.emit())
	column.add_child(quit)


func _heading(into: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	into.add_child(label)


func open_menu(saves: Array, theme_name: String, has_career: bool) -> void:
	_theme_name = theme_name
	_career_actions.visible = has_career
	_refresh_theme_buttons()
	for child in _saves.get_children():
		child.queue_free()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "None saved."
		empty.add_theme_font_size_override("font_size", 12)
		_saves.add_child(empty)
	for entry in saves:
		var row := Button.new()
		row.text = str(Dictionary(entry).get("label", entry))
		var save_id := str(Dictionary(entry).get("id", entry))
		row.pressed.connect(func() -> void:
			close_menu()
			load_requested.emit(save_id)
		)
		_saves.add_child(row)
	visible = true
	grab_focus()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	resume_requested.emit()


func _refresh_theme_buttons() -> void:
	for index in range(_theme_row.get_child_count()):
		var button := _theme_row.get_child(index) as Button
		if button != null:
			button.button_pressed = (index == 0) == (_theme_name != "light")


func _scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close_menu()
		accept_event()


class _Scrim extends Control:
	func _draw() -> void:
		draw_rect(
			Rect2(Vector2.ZERO, size),
			UIPalette.color(&"scrim", UIPalette.control_is_light(self)), true
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()
