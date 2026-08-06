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


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 30:
		return
	var path := "user://ink_shot_%s.png" % ("light" if _light_mode else "dark")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	get_tree().quit()
