extends Control

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const ScreenWipeScript := preload("res://scenes/components/screen_wipe.gd")
const SETTINGS_PATH := "user://settings.cfg"

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var title_screen: VolleyballTitleScreen = %TitleScreen
@onready var new_career_screen: VolleyballNewCareerScreen = %NewCareerScreen
@onready var career_dashboard: VolleyballCareerDashboard = %CareerDashboard
@onready var match_center: Control = %MatchCenter

var _wipe: ScreenWipe = null


func _ready() -> void:
	## Keep the halftone screen the same size relative to the window.
	##
	## The dot period is in pixels, so a maximised window prints a finer and
	## finer screen until it is gone. Connected here rather than inside
	## `UIHalftone` because the palette module has no scene tree of its own and
	## should not acquire one to learn about a resize.
	var window_viewport := get_viewport()
	window_viewport.size_changed.connect(_sync_halftone_scale)
	_sync_halftone_scale()
	title_screen.new_career_requested.connect(_show_new_career)
	title_screen.career_load_requested.connect(_load_career)
	title_screen.theme_requested.connect(_apply_theme)
	title_screen.exit_requested.connect(func() -> void: get_tree().quit())
	new_career_screen.back_requested.connect(_show_title)
	new_career_screen.career_created.connect(_show_dashboard)
	career_dashboard.title_requested.connect(_show_title)
	career_dashboard.play_match_requested.connect(_show_match)
	call_deferred("_connect_match_center_signal")
	## Added in code rather than the scene because it has to be the last child --
	## later siblings draw over earlier ones -- and a node whose whole job is to
	## cover everything is easier to keep last here than in a .tscn somebody will
	## reorder.
	_wipe = ScreenWipeScript.new()
	add_child(_wipe)
	_load_theme()
	_show_title()


func _connect_match_center_signal() -> void:
	if match_center:
		match_center.career_exit_requested.connect(_show_dashboard)


## Every screen change goes through here, so the wipe does too.
##
## The swap itself is handed to the wipe as a callable and happens while the
## sheet is across, which is why the outgoing screen is never seen being torn
## down. The first call has no wipe -- there is nothing to leave.
func _show_only(screen: Control) -> void:
	if _wipe == null or not _wipe.is_inside_tree():
		_swap_to(screen)
		return
	_wipe.play(func() -> void: _swap_to(screen))


func _swap_to(screen: Control) -> void:
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


func _sync_halftone_scale() -> void:
	UIHalftone.set_viewport_height(float(get_viewport().get_visible_rect().size.y))


func _apply_theme(theme_name: String, persist: bool = true) -> void:
	var resolved := "light" if theme_name == "light" else "dark"
	theme = LightTheme if resolved == "light" else DarkTheme
	## The sheet is paper in the light theme and ink in the dark one. A wipe that
	## kept one colour would be the only element in the game that ignores the
	## theme, and it covers the whole screen.
	if _wipe != null:
		_wipe.set_palette(
			Color(0.94, 0.92, 0.86) if resolved == "light" else Color(0.09, 0.10, 0.13),
			Color(0.20, 0.18, 0.14) if resolved == "light" else Color(0.02, 0.02, 0.03),
		)
	title_screen.set_theme_name(resolved)
	new_career_screen.set_light_mode(resolved == "light")
	if match_center.has_method("set_light_mode"):
		match_center.set_light_mode(resolved == "light")
	## Before the style pass, not after. Every cached halftone material carries a
	## tint for the theme it was built under, so a switch that reuses them leaves
	## every panel screened in the previous theme's ink -- close enough to right
	## that nothing looks broken, which is the worst kind of stale.
	UIHalftone.clear_cache()
	UIStyleSystem.apply(self, resolved == "light")
	for palette_node in get_tree().get_nodes_in_group("ui_palette_3d"):
		if palette_node.has_method("apply_ui_palette"):
			palette_node.apply_ui_palette(resolved == "light")
	if persist:
		var config := ConfigFile.new()
		config.set_value("presentation", "theme", resolved)
		config.save(SETTINGS_PATH)
