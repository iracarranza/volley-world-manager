extends Control

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var title_screen: VolleyballTitleScreen = %TitleScreen
@onready var new_career_screen: VolleyballNewCareerScreen = %NewCareerScreen
@onready var career_dashboard: VolleyballCareerDashboard = %CareerDashboard
@onready var match_center: Control = %MatchCenter


func _ready() -> void:
	title_screen.new_career_requested.connect(_show_new_career)
	title_screen.career_load_requested.connect(_load_career)
	new_career_screen.back_requested.connect(_show_title)
	new_career_screen.career_created.connect(_show_dashboard)
	career_dashboard.title_requested.connect(_show_title)
	career_dashboard.play_match_requested.connect(_show_match)
	call_deferred("_connect_match_center_signal")
	_show_title()


func _connect_match_center_signal() -> void:
	if match_center:
		match_center.career_exit_requested.connect(_show_dashboard)


func _show_only(screen: Control) -> void:
	for candidate in [title_screen, new_career_screen, career_dashboard, match_center]:
		candidate.visible = candidate == screen


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
