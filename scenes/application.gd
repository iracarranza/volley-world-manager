extends Control

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const SETTINGS_PATH := "user://settings.cfg"

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var title_screen: VolleyballTitleScreen = %TitleScreen
@onready var new_career_screen: VolleyballNewCareerScreen = %NewCareerScreen
@onready var career_dashboard: VolleyballCareerDashboard = %CareerDashboard
@onready var match_center: Control = %MatchCenter


func _ready() -> void:
	title_screen.new_career_requested.connect(_show_new_career)
	title_screen.career_load_requested.connect(_load_career)
	title_screen.theme_requested.connect(_apply_theme)
	title_screen.exit_requested.connect(func() -> void: get_tree().quit())
	new_career_screen.back_requested.connect(_show_title)
	new_career_screen.career_created.connect(_show_dashboard)
	career_dashboard.title_requested.connect(_show_title)
	career_dashboard.play_match_requested.connect(_show_match)
	call_deferred("_connect_match_center_signal")
	_load_theme()
	_show_title()


func _connect_match_center_signal() -> void:
	if match_center:
		match_center.career_exit_requested.connect(_show_dashboard)


func _show_only(screen: Control) -> void:
	for candidate in [title_screen, new_career_screen, career_dashboard, match_center]:
		candidate.visible = candidate == screen
	UIStyleSystem.reveal(screen)


func _show_title() -> void:
	if CareerManager.has_career():
		CareerManager.save_career()
	title_screen.refresh_saves()
	_show_only(title_screen)


func _show_new_career() -> void:
	new_career_screen.reset_form()
	_show_only(new_career_screen)


func _load_career(save_id: String) -> void:
	var error := CareerManager.load_career(save_id)
	if error.is_empty():
		_show_dashboard()


func _show_dashboard() -> void:
	career_dashboard.refresh()
	_show_only(career_dashboard)


func _show_match() -> void:
	match_center.enter_career_match()
	_show_only(match_center)


func _load_theme() -> void:
	var config := ConfigFile.new()
	var theme_name := "dark"
	if config.load(SETTINGS_PATH) == OK:
		theme_name = str(config.get_value("presentation", "theme", "dark"))
	_apply_theme(theme_name, false)


func _apply_theme(theme_name: String, persist: bool = true) -> void:
	var resolved := "light" if theme_name == "light" else "dark"
	theme = LightTheme if resolved == "light" else DarkTheme
	title_screen.set_theme_name(resolved)
	new_career_screen.set_light_mode(resolved == "light")
	if match_center.has_method("set_light_mode"):
		match_center.set_light_mode(resolved == "light")
	UIStyleSystem.apply(self, resolved == "light")
	for palette_node in get_tree().get_nodes_in_group("ui_palette_3d"):
		if palette_node.has_method("apply_ui_palette"):
			palette_node.apply_ui_palette(resolved == "light")
	if persist:
		var config := ConfigFile.new()
		config.set_value("presentation", "theme", resolved)
		config.save(SETTINGS_PATH)
