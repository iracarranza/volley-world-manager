extends Control

const SHOTS_DIR := "user://dashboard_preview"

var _dashboard: Control
var _frame: int = 0
var _steps: Array = []
var _step_index: int = 0


## Mirrors `application.gd::_apply_theme()`. Without this the preview renders the
## dashboard with Godot's built-in font and default control styling, because the
## theme is assigned to the Application root and this harness never creates one
## -- so every screenshot looked plausible and showed a UI nobody ships. Layout
## judged from those is layout judged against the wrong font metrics.
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")
const UIStyle := preload("res://scripts/systems/ui_style_system.gd")

## Set to true to capture the light theme instead.
const PREVIEW_LIGHT_MODE: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	theme = LightTheme if PREVIEW_LIGHT_MODE else DarkTheme
	var manager := get_node("/root/CareerManager")
	var error: String = manager.create_career(
		"Preview Career", "Harbor City VC", "Landavol", "Club", "Balanced"
	)
	if not error.is_empty():
		print("career error: %s" % error)
	var packed := load("res://scenes/screens/career_dashboard.tscn") as PackedScene
	_dashboard = packed.instantiate()
	add_child(_dashboard)
	if _dashboard.has_method("set_light_mode"):
		_dashboard.set_light_mode(PREVIEW_LIGHT_MODE)
	UIStyle.apply(self, PREVIEW_LIGHT_MODE)
	_steps = [
		["01_home", func() -> void: _dashboard._navigate("Home")],
		["01b_home_inbox", func() -> void:
			var t := _dashboard.find_child("HomeSubTabs", true, false)
			if t != null: t.current_tab = 1],
		["02_nav_open", func() -> void:
			var t := _dashboard.find_child("HomeSubTabs", true, false)
			if t != null: t.current_tab = 0
			_dashboard._toggle_nav_dropdown()],
		["03_roster", func() -> void: _dashboard._navigate("Roster")],
		["04_roster_page2", func() -> void: _dashboard._step_attribute_page(1)],
		["05_roster_list", func() -> void: _dashboard._toggle_roster_list()],
		["06_advance", func() -> void:
			_dashboard._toggle_roster_list()
			_dashboard._reveal_advance()],
		["07_team", func() -> void:
			_dashboard._hide_advance_reveal()
			_dashboard._navigate("Team")],
		["08_advance_blocked", func() -> void:
			get_node("/root/CareerManager").advance_week()
			_dashboard._reveal_advance()],
		["09_jumped_to_fixture", func() -> void: _dashboard._confirm_advance()],
		## The rest of the nav. These were never captured, so four of the seven
		## sections had no screenshot at all and any layout judgement about them
		## was being made from memory.
		["10_team_training", func() -> void:
			_dashboard._navigate("Team")
			var tabs := _dashboard.find_child("TeamSubTabs", true, false)
			if tabs != null:
				tabs.current_tab = mini(1, maxi(tabs.get_tab_count() - 1, 0))],
		["11_team_teamtraining", func() -> void:
			var tabs := _dashboard.find_child("TeamSubTabs", true, false)
			if tabs != null:
				tabs.current_tab = maxi(tabs.get_tab_count() - 1, 0)],
		["12_club_staff", func() -> void: _dashboard._navigate("Club")],
		["12b_club_food", func() -> void:
			var t := _dashboard.find_child("ClubSubTabs", true, false)
			if t != null: t.current_tab = 1],
		## The foldouts start closed, so everything inside them -- including the
		## jump-to-globe control -- was invisible to every screenshot taken so far.
		## A collapsed panel photographs as a panel with nothing in it.
		["12b2_club_food_stores", func() -> void:
			var column := _dashboard.find_child("FoldoutColumn", true, false)
			if column == null:
				return
			for child in column.get_children():
				if child is Button and str(child.text).ends_with("Paste stores"):
					(child as Button).button_pressed = true
					break],
		["12c_club_sponsors", func() -> void:
			var t := _dashboard.find_child("ClubSubTabs", true, false)
			if t != null: t.current_tab = 2],
		["12_transfers", func() -> void: _dashboard._navigate("Transfers")],
		["13_competition", func() -> void: _dashboard._navigate("Competition")],
		["14_sixnet", func() -> void: _dashboard._navigate("Sixnet")],
	]


func _process(_delta: float) -> void:
	_frame += 1
	## Every step gets its own settle window so tweens finish before the grab.
	if _frame % 24 != 0:
		return
	if _step_index >= _steps.size():
		get_tree().quit()
		return
	var step: Array = _steps[_step_index]
	if _frame % 48 == 24:
		(step[1] as Callable).call()
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [SHOTS_DIR, step[0]])
	print("saved %s" % step[0])
	_step_index += 1
