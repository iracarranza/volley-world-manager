class_name VolleyballTitleScreen
extends Control

signal new_career_requested
signal career_load_requested(save_id: String)

@onready var continue_button: Button = %ContinueButton
@onready var save_list: ItemList = %SaveList
@onready var save_detail: Label = %SaveDetail
@onready var load_button: Button = %LoadButton

var saves: Array[Dictionary] = []


func _ready() -> void:
	%NewCareerButton.pressed.connect(func() -> void: new_career_requested.emit())
	continue_button.pressed.connect(_continue_latest)
	load_button.pressed.connect(_load_selected)
	save_list.item_selected.connect(_select_save)
	refresh_saves()


func refresh_saves() -> void:
	saves = CareerManager.list_save_metadata()
	save_list.clear()
	for metadata in saves:
		save_list.add_item("%s — %s" % [metadata.get("career_name", "Career"),
			metadata.get("organization_name", "Organization")])
	continue_button.disabled = saves.is_empty()
	load_button.disabled = saves.is_empty()
	if saves.is_empty():
		save_detail.text = "No saved careers yet. Start a new club or academy."
	else:
		save_list.select(0)
		_select_save(0)


func _select_save(index: int) -> void:
	if index < 0 or index >= saves.size():
		return
	var metadata := saves[index]
	save_detail.text = "%s · %s\n%s · Reputation %d\n%s · Next: %s" % [
		metadata.get("organization_type", "Club"), metadata.get("region", "Region"),
		metadata.get("date", "Week 1"), int(metadata.get("reputation", 0)),
		metadata.get("organization_name", "Organization"),
		metadata.get("next_fixture", "None")]


func _continue_latest() -> void:
	if not saves.is_empty():
		career_load_requested.emit(str(saves[0].save_id))


func _load_selected() -> void:
	var selected := save_list.get_selected_items()
	if not selected.is_empty():
		career_load_requested.emit(str(saves[selected[0]].save_id))
