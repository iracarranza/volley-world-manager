extends Control

## Title and new-career screens.
##
## The dashboard preview starts from an already-created career, so the two
## screens every player sees first had no capture at all and any judgement about
## them was being made from memory. Same theme application as the dashboard
## harness, for the same reason: without it these render in Godot's built-in
## font and show a UI nobody ships.

const SHOTS_DIR := "user://dashboard_preview"
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const UIStyle := preload("res://scripts/systems/ui_style_system.gd")

var _steps: Array = []
var _step_index: int = 0
var _frame: int = 0
var _screen: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	theme = DarkTheme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_steps = [
		["15_title", "res://scenes/screens/title_screen.tscn"],
		["16_new_career", "res://scenes/screens/new_career_screen.tscn"],
	]


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % 24 != 0:
		return
	if _step_index >= _steps.size():
		get_tree().quit()
		return
	var step: Array = _steps[_step_index]
	if _frame % 48 == 24:
		if _screen != null:
			_screen.queue_free()
		var packed := load(str(step[1])) as PackedScene
		if packed == null:
			_step_index += 1
			return
		_screen = packed.instantiate()
		add_child(_screen)
		if _screen is Control:
			_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		UIStyle.apply(self, false)
		return
	get_viewport().get_texture().get_image().save_png(
		"%s/%s.png" % [SHOTS_DIR, str(step[0])]
	)
	print("saved %s" % str(step[0]))
	_step_index += 1
