extends Control

## One frame of the dashboard home screen, for judging the drawn edge.
##
## Separate from `dashboard_preview.tscn` because that harness walks nineteen
## sections and takes minutes; looking at a line does not need the tour.

const UIStyle := preload("res://scripts/systems/ui_style_system.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")

## Flipped from the command line via `--light`, so both themes come from one
## harness rather than from a constant somebody has to remember to edit back.
var _light_mode: bool = false
var _dashboard: Control
var _frame: int = 0


func _ready() -> void:
	_light_mode = "--light" in OS.get_cmdline_user_args()
	theme = LightTheme if _light_mode else DarkTheme
	var manager := get_node("/root/CareerManager")
	manager.create_career(
		"Preview Career", "Harbor City VC", "Landavol", "Club", "Balanced"
	)
	var packed := load("res://scenes/screens/career_dashboard.tscn") as PackedScene
	_dashboard = packed.instantiate()
	add_child(_dashboard)
	if _dashboard.has_method("set_light_mode"):
		_dashboard.set_light_mode(_light_mode)
	UIStyle.apply(self, _light_mode)


## The views worth looking at when a style changes, and not the full nineteen --
## the whole-dashboard tour takes minutes and most of it is the same surfaces
## again.
var _steps: Array = []
var _step: int = 0


func _build_steps() -> void:
	_steps = [
		["home", func() -> void: _dashboard._navigate("Home")],
		["nav_open", func() -> void: _dashboard._toggle_nav_dropdown()],
		["roster", func() -> void:
			_dashboard._close_nav_dropdown()
			_dashboard._navigate("Roster")],
		["team", func() -> void: _dashboard._navigate("Team")],
		["team_training", func() -> void:
			var tabs := _dashboard.find_child("TeamSubTabs", true, false)
			if tabs != null:
				tabs.current_tab = mini(1, maxi(tabs.get_tab_count() - 1, 0))],
		["club", func() -> void: _dashboard._navigate("Club")],
		["transfers", func() -> void: _dashboard._navigate("Transfers")],
	]


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 20:
		return
	if _steps.is_empty():
		_build_steps()
	if _step >= _steps.size():
		get_tree().quit()
		return
	## Each step gets a settle window so any tween finishes before the grab.
	if _frame % 24 != 0:
		return
	var entry: Array = _steps[_step]
	if _frame % 48 == 0:
		(entry[1] as Callable).call()
		return
	var suffix := "light" if _light_mode else "dark"
	var path := "user://ink_%s_%s.png" % [entry[0], suffix]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	_step += 1
