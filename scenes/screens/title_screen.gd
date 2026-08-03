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
@onready var theme_option: OptionButton = %ThemeOption

var saves: Array[Dictionary] = []


func _ready() -> void:
	%NewCareerButton.pressed.connect(func() -> void: new_career_requested.emit())
	load_menu_button.pressed.connect(_open_load_menu)
	%OptionsButton.pressed.connect(func() -> void: %OptionsDialog.popup_centered())
	%ExitButton.pressed.connect(func() -> void: exit_requested.emit())
	load_selected_button.pressed.connect(_load_selected)
	%LoadDialog.close_requested.connect(%LoadDialog.hide)
	delete_button.pressed.connect(_confirm_delete)
	%DeleteConfirmation.confirmed.connect(_delete_selected)
	save_list.item_selected.connect(_select_save)
	theme_option.add_item("Midnight Court")
	theme_option.add_item("Daylight Gym")
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
	if saves.is_empty():
		save_detail.text = "No careers have been written yet."
	else:
		save_list.select(0)
		_select_save(0)


func set_theme_name(theme_name: String) -> void:
	var light_mode := theme_name == "light"
	theme_option.select(1 if light_mode else 0)
	%Background.color = UIPalette.color(&"canvas", light_mode)
	%CourtBand.color = UIPalette.color(&"canvas_alt", light_mode)
	%AccentBar.color = UIPalette.color(&"accent", light_mode)
	%Title.modulate = UIPalette.color(&"ink", light_mode)
	%Edition.modulate = UIPalette.color(&"accent", light_mode)


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
