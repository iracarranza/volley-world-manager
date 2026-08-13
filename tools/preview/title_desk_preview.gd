extends Control

const DarkTheme := preload("res://scenes/themes/dark_theme.tres")

var _screen: VolleyballTitleScreen
var _frame := 0


func _ready() -> void:
	theme = DarkTheme
	_screen = load("res://scenes/screens/title_screen.tscn").instantiate()
	add_child(_screen)
	_screen.set_theme_name("dark")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 12:
		get_viewport().get_texture().get_image().save_png("user://title_desk_draft.png")
		_screen.desk_surface.departure = 0.48
		_screen.get_node("%MenuPanel").modulate.a = 0.42
		_screen.get_node("%Brand").modulate.a = 0.55
	if _frame == 24:
		get_viewport().get_texture().get_image().save_png("user://title_desk_transition.png")
		_screen.desk_surface.departure = 1.0
		_screen.get_node("%MenuPanel").modulate.a = 0.0
		_screen.get_node("%Brand").modulate.a = 0.0
	if _frame == 36:
		get_viewport().get_texture().get_image().save_png("user://title_desk_endpoint.png")
		get_tree().quit()
