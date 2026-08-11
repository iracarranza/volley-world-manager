class_name VolleyballTitleScreen
extends Control

signal new_career_requested
signal career_load_requested(save_id: String)
signal theme_requested(theme_name: String)
signal exit_requested

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var save_list: ItemList = %SaveList
@onready var save_detail: Label = %SaveDetail
@onready var load_selected_button: Button = %LoadSelectedButton
@onready var delete_button: Button = %DeleteButton
@onready var load_menu_button: Button = %LoadMenuButton
@onready var continue_button: Button = %ContinueButton
@onready var theme_option: OptionButton = %ThemeOption

var saves: Array[Dictionary] = []


func _ready() -> void:
	%NewCareerButton.pressed.connect(func() -> void: new_career_requested.emit())
	load_menu_button.pressed.connect(_open_load_menu)
	continue_button.pressed.connect(_continue_last_played)
	%OptionsButton.pressed.connect(func() -> void: %OptionsDialog.popup_centered())
	%ExitButton.pressed.connect(func() -> void: exit_requested.emit())
	load_selected_button.pressed.connect(_load_selected)
	%LoadDialog.close_requested.connect(%LoadDialog.hide)
	delete_button.pressed.connect(_confirm_delete)
	%DeleteConfirmation.confirmed.connect(_delete_selected)
	save_list.item_selected.connect(_select_save)
	## The themes have one pair of names, and these are they. The title screen
	## called them Midnight Court and Daylight Gym while the match centre called
	## the same two themes Mikasa Dark and Molten Light -- two names for one thing,
	## in the two places a player is most likely to see both.
	theme_option.add_item("Mikasa")
	theme_option.add_item("Molten")
	theme_option.item_selected.connect(_theme_selected)
	refresh_saves()


func refresh_saves() -> void:
	saves = CareerManager.list_save_metadata()
	save_list.clear()
	for metadata in saves:
		save_list.add_item("%s  /  %s" % [
			metadata.get("career_name", "Career"),
			metadata.get("organization_name", "Organization"),
		])
	load_menu_button.disabled = saves.is_empty()
	load_selected_button.disabled = saves.is_empty()
	delete_button.disabled = saves.is_empty()
	%SaveCount.text = "%02d ACTIVE FILES" % saves.size()
	_refresh_continue()
	if saves.is_empty():
		save_detail.text = "No careers have been written yet."
	else:
		save_list.select(0)
		_select_save(0)


## The card at the foot of the brand column: the save you were last in.
##
## It needs no new field and no second pass over the save directory.
## `list_save_metadata()` already sorts by `last_saved_unix` descending, so the
## most recently played career is `saves[0]` -- the same row the load dialog
## opens preselected. If that sort ever changes, this button silently starts
## opening the wrong career, which is why the ordering is asserted in the suite
## rather than left as a comment.
func _refresh_continue() -> void:
	continue_button.visible = not saves.is_empty()
	if saves.is_empty():
		return
	var metadata := saves[0]
	%ContinueTitle.text = str(metadata.get("organization_name", "Organization"))
	%ContinueDetail.text = "%s  ·  next: %s" % [
		metadata.get("date", "Week 1"), metadata.get("next_fixture", "None"),
	]


func _continue_last_played() -> void:
	if saves.is_empty():
		return
	career_load_requested.emit(str(saves[0].save_id))


func set_theme_name(theme_name: String) -> void:
	var light_mode := theme_name == "light"
	theme_option.select(1 if light_mode else 0)
	%Background.color = UIPalette.color(&"canvas", light_mode)
	%CourtBand.color = UIPalette.color(&"canvas_alt", light_mode)
	%AccentBar.color = UIPalette.color(&"accent", light_mode)
	%Title.modulate = UIPalette.color(&"ink", light_mode)
	%Edition.modulate = UIPalette.color(&"accent", light_mode)
	_tint_menu(light_mode)


## Everything on this screen painted by a hand-rolled `StyleBoxFlat` or a
## `theme_override_colors` entry -- which is the whole menu and both cards.
##
## A `theme_override_` beats the theme, so none of it followed the light. In
## Molten the page turned cream and the menu stayed the near-black
## `Color(0.025, 0.065, 0.11)` it is authored as, gold border and all: the
## backdrop was the only part of the screen that knew which theme it was in.
## Measured by reading the two tables rather than by looking at it, because on
## a dark page the defect is invisible.
func _tint_menu(light_mode: bool) -> void:
	var ink := UIPalette.color(&"ink", light_mode)
	var muted := UIPalette.color(&"ink_muted", light_mode)
	var accent := UIPalette.color(&"accent", light_mode)
	var stitch := UIPalette.color(&"accent_alt", light_mode)
	var panel: StyleBoxFlat = %MenuPanel.get_theme_stylebox(&"panel")
	if panel != null:
		panel.bg_color = Color(UIPalette.color(&"canvas", light_mode), 0.96)
		panel.border_color = Color(accent, 0.45)
	## The four menu buttons share one pair of styleboxes, so this retints the
	## same two resources four times over. The font colours are per button.
	for button: Button in [%NewCareerButton, %LoadMenuButton, %OptionsButton, %ExitButton]:
		var normal: StyleBoxFlat = button.get_theme_stylebox(&"normal")
		if normal != null:
			normal.bg_color = Color(UIPalette.color(&"surface", light_mode), 0.96)
			normal.border_color = Color(accent, 0.65)
		var hover: StyleBoxFlat = button.get_theme_stylebox(&"hover")
		if hover != null:
			hover.bg_color = UIPalette.color(&"surface_hover", light_mode)
			hover.border_color = accent
		button.add_theme_color_override(&"font_color", ink)
		button.add_theme_color_override(&"font_hover_color", ink)
		button.add_theme_color_override(&"font_pressed_color", ink)
	var card: StyleBoxFlat = continue_button.get_theme_stylebox(&"normal")
	if card != null:
		card.bg_color = Color(UIPalette.color(&"surface", light_mode), 0.96)
		card.border_color = Color(stitch, 0.5)
	var card_hover: StyleBoxFlat = continue_button.get_theme_stylebox(&"hover")
	if card_hover != null:
		card_hover.bg_color = UIPalette.color(&"surface_hover", light_mode)
		card_hover.border_color = stitch
	%MenuKicker.add_theme_color_override(&"font_color", accent)
	%MenuTitle.add_theme_color_override(&"font_color", ink)
	%Subtitle.add_theme_color_override(&"font_color", muted)
	%SaveCount.add_theme_color_override(&"font_color", UIPalette.color(&"ink_faint", light_mode))
	%ContinueKicker.add_theme_color_override(&"font_color", accent)
	%ContinueTitle.add_theme_color_override(&"font_color", ink)
	%ContinueDetail.add_theme_color_override(&"font_color", muted)


func _open_load_menu() -> void:
	refresh_saves()
	%LoadDialog.popup_centered_ratio(0.68)


func _select_save(index: int) -> void:
	if index < 0 or index >= saves.size():
		return
	var metadata := saves[index]
	save_detail.text = "%s · %s\n%s identity · Reputation %d\n%s · Next: %s" % [
		metadata.get("organization_type", "Club"), metadata.get("region", "Region"),
		metadata.get("identity", "Balanced"), int(metadata.get("reputation", 0)),
		metadata.get("date", "Week 1"),
		metadata.get("next_fixture", "None"),
	]


func _load_selected() -> void:
	var selected := save_list.get_selected_items()
	if not selected.is_empty():
		%LoadDialog.hide()
		career_load_requested.emit(str(saves[selected[0]].save_id))


func _confirm_delete() -> void:
	if not save_list.get_selected_items().is_empty():
		%DeleteConfirmation.popup_centered()


func _delete_selected() -> void:
	var selected := save_list.get_selected_items()
	if selected.is_empty():
		return
	var error: String = CareerManager.delete_save(str(saves[selected[0]].save_id))
	if not error.is_empty():
		save_detail.text = error
	else:
		refresh_saves()


func _theme_selected(index: int) -> void:
	theme_requested.emit("light" if index == 1 else "dark")
