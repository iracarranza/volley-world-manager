extends Control

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const UICardStock := preload("res://scripts/data/ui_card_stock.gd")
const ScreenWipeScript := preload("res://scenes/components/screen_wipe.gd")
const TrainingScreenScript := preload("res://scenes/screens/training_screen.gd")
const ScoutingScreenScript := preload("res://scenes/screens/scouting_screen.gd")
const ScheduleScreenScript := preload("res://scenes/screens/schedule_screen.gd")
const LockInScreenScript := preload("res://scenes/screens/lock_in_screen.gd")
const AccommodationScreenScript := preload("res://scenes/screens/accommodation_screen.gd")
const KitchenScreenScript := preload("res://scenes/screens/kitchen_screen.gd")
const EscMenuScript := preload("res://scenes/components/esc_menu.gd")
const DeskScreenScript := preload("res://scenes/screens/desk_screen.gd")
const EncyclopediaScreenScript := preload("res://scenes/screens/encyclopedia_screen.gd")
const SETTINGS_PATH := "user://settings.cfg"

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var office_shell: CanonicalOfficeShell = %OfficeShell
@onready var title_screen: VolleyballTitleScreen = %TitleScreen
@onready var new_career_screen: VolleyballNewCareerScreen = %NewCareerScreen
@onready var journal: VolleyballJournalScreen = %Journal
@onready var match_center: Control = %MatchCenter
@onready var career_navigation: CareerNavigation = %CareerNavigation

var _wipe: ScreenWipe = null
var _has_shown := false
var _training_screen: VolleyballTrainingScreen = null
var _scouting_screen: VolleyballScoutingScreen = null
var _schedule_screen: VolleyballScheduleScreen = null
var _lock_in_screen: LockInScreen = null
var _accommodation_screen: AccommodationScreen = null
var _kitchen_screen: KitchenScreen = null
var _esc_menu: EscMenu = null
var _desk_screen: DeskScreen = null
var _encyclopedia_screen: EncyclopediaScreen = null
var _theme_name := "dark"


func _ready() -> void:
	get_viewport().size_changed.connect(_sync_halftone_scale)
	_sync_halftone_scale()
	journal.set_meta(UIStyleSystem.MEDIUM_META, UIStyleSystem.MEDIUM_SEWN)

	title_screen.new_career_requested.connect(_show_new_career)
	title_screen.career_load_requested.connect(_load_career)
	title_screen.theme_requested.connect(_apply_theme)
	title_screen.exit_requested.connect(func() -> void: get_tree().quit())
	new_career_screen.back_requested.connect(_show_title)
	new_career_screen.career_created.connect(_show_desk)
	journal.title_requested.connect(_show_title)
	journal.play_match_requested.connect(_show_lock_in)
	journal.training_requested.connect(_show_training)
	journal.scouting_requested.connect(_show_scouting)
	journal.encyclopedia_requested.connect(_show_encyclopedia)
	journal.accommodation_requested.connect(_show_accommodation)
	journal.kitchen_requested.connect(_show_kitchen)
	journal.menu_requested.connect(_open_menu)
	career_navigation.destination_requested.connect(_navigate_career)
	var journal_sections := journal.get_node_or_null("%Sections") as TabContainer
	if journal_sections != null:
		journal_sections.tab_changed.connect(func(_tab: int) -> void:
			call_deferred("_apply_journal_vocabulary")
		)
	call_deferred("_connect_match_center_signal")

	_wipe = ScreenWipeScript.new()
	_wipe.z_index = 80
	add_child(_wipe)
	_load_theme()
	_apply_journal_vocabulary()
	_show_title()


func _ensure_training_screen() -> void:
	if _training_screen != null:
		return
	_training_screen = TrainingScreenScript.new()
	_adopt_screen(_training_screen)
	_training_screen.back_requested.connect(_show_desk)
	# This is a cross-workspace link, not ownership: Training describes what is
	# taught; Calendar remains the peer workspace that owns when it happens.
	_training_screen.schedule_requested.connect(_show_schedule)


func _ensure_scouting_screen() -> void:
	if _scouting_screen != null:
		return
	_scouting_screen = ScoutingScreenScript.new()
	_adopt_screen(_scouting_screen)
	_scouting_screen.back_requested.connect(_show_desk)


func _ensure_schedule_screen() -> void:
	if _schedule_screen != null:
		return
	_schedule_screen = ScheduleScreenScript.new()
	_adopt_screen(_schedule_screen)
	_schedule_screen.back_requested.connect(_show_desk)


func _ensure_accommodation_screen() -> void:
	if _accommodation_screen != null:
		return
	_accommodation_screen = AccommodationScreenScript.new()
	_adopt_screen(_accommodation_screen)
	_accommodation_screen.back_requested.connect(_show_desk)


func _ensure_kitchen_screen() -> void:
	if _kitchen_screen != null:
		return
	_kitchen_screen = KitchenScreenScript.new()
	_adopt_screen(_kitchen_screen)
	_kitchen_screen.back_requested.connect(_show_desk)


func _ensure_encyclopedia_screen() -> void:
	if _encyclopedia_screen != null:
		return
	_encyclopedia_screen = EncyclopediaScreenScript.new()
	_adopt_screen(_encyclopedia_screen)
	_encyclopedia_screen.back_requested.connect(_show_desk)


func _ensure_lock_in_screen() -> void:
	if _lock_in_screen != null:
		return
	_lock_in_screen = LockInScreenScript.new()
	_adopt_screen(_lock_in_screen)
	_lock_in_screen.bind(CareerManager, get_node("/root/GameManager"))
	_lock_in_screen.cancelled.connect(_show_journal)
	_lock_in_screen.confirmed.connect(_show_match)


func _adopt_screen(screen: Control) -> void:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	add_child(screen)
	# Lazy screens are appended after the persistent navigation node. Keep the
	# navigation above ordinary content, and the wipe above both.
	if career_navigation != null and career_navigation.is_inside_tree():
		move_child(career_navigation, -1)
	if _wipe != null and _wipe.is_inside_tree():
		move_child(_wipe, -1)
	var is_light := _theme_name == "light"
	UIStyleSystem.apply(screen, is_light)
	for palette_node in screen.find_children("*", "", true, false):
		if palette_node.is_in_group("ui_palette_3d") and palette_node.has_method("apply_ui_palette"):
			palette_node.apply_ui_palette(is_light)


func _connect_match_center_signal() -> void:
	if match_center:
		match_center.career_exit_requested.connect(_show_journal)


func _show_only(screen: Control) -> void:
	if not _has_shown or _wipe == null or not _wipe.is_inside_tree():
		_has_shown = true
		_swap_to(screen)
		return
	_wipe.play(func() -> void: _swap_to(screen))


func _swap_to(screen: Control) -> void:
	for candidate in [
		title_screen, new_career_screen, journal, match_center,
		_training_screen, _scouting_screen, _schedule_screen, _lock_in_screen,
		_encyclopedia_screen, _accommodation_screen, _kitchen_screen, _desk_screen,
	]:
		if candidate != null:
			candidate.visible = candidate == screen
	var office_visible := screen == title_screen or (_desk_screen != null and screen == _desk_screen)
	office_shell.visible = office_visible
	_sync_career_navigation(screen)
	UIStyleSystem.reveal(screen)
	if screen == title_screen:
		title_screen.enforce_live_office_overlay()


func _sync_career_navigation(screen: Control) -> void:
	if _desk_screen != null and screen == _desk_screen:
		career_navigation.present(&"desk", screen, true)
	elif screen == journal:
		career_navigation.present(&"journal", screen)
	elif _schedule_screen != null and screen == _schedule_screen:
		career_navigation.present(&"calendar", screen)
	elif _training_screen != null and screen == _training_screen:
		career_navigation.present(&"training", screen)
	elif _scouting_screen != null and screen == _scouting_screen:
		career_navigation.present(&"scouting", screen)
	elif _accommodation_screen != null and screen == _accommodation_screen:
		career_navigation.present(&"housing", screen)
	elif _kitchen_screen != null and screen == _kitchen_screen:
		career_navigation.present(&"kitchen", screen)
	elif _encyclopedia_screen != null and screen == _encyclopedia_screen:
		career_navigation.present(&"encyclopedia", screen)
	else:
		# Title, New Career, Lock-In and Match are not ordinary workspaces.
		career_navigation.clear()


func _navigate_career(destination: StringName) -> void:
	match destination:
		&"desk": _show_desk()
		&"journal": _show_journal()
		&"calendar":
			if career_navigation.current_destination() == &"desk":
				_open_calendar_from_desk()
			else:
				_show_schedule()
		&"training": _show_training()
		&"scouting": _show_scouting()
		&"housing": _show_accommodation()
		&"kitchen": _show_kitchen()
		&"encyclopedia": _show_encyclopedia()


func _show_title() -> void:
	if CareerManager.has_career():
		CareerManager.save_career()
	title_screen.refresh_saves()
	title_screen.reset_departure()
	office_shell.visible = true
	office_shell.snap_to(&"MainMenu")
	office_shell.set_title_idle(true)
	_apply_office_career_state()
	_show_only(title_screen)


func _show_new_career() -> void:
	new_career_screen.reset_form()
	office_shell.set_title_idle(false)
	_show_only(new_career_screen)


func _load_career(save_id: String) -> void:
	var error := CareerManager.load_career(save_id)
	if not error.is_empty():
		return
	_apply_office_career_state()
	office_shell.set_title_idle(false)
	# One room, one camera move: title furniture fades while the persistent office
	# camera physically moves from MainMenu to Desk.
	title_screen.play_desk_departure()
	await office_shell.play_to(&"Desk", 1.55)
	_show_desk_after_title_transition()


func _show_desk_after_title_transition() -> void:
	_ensure_desk_screen()
	_desk_screen.bind(CareerManager, get_node("/root/GameManager"))
	office_shell.visible = true
	office_shell.snap_to(&"Desk")
	_swap_to(_desk_screen)


func _show_journal() -> void:
	journal.refresh()
	_apply_journal_vocabulary()
	_show_only(journal)


func _apply_journal_vocabulary() -> void:
	# `Home` is an old implementation name. The Journal's first page is the
	# manager's current working record; career home is the physical Desk.
	var sections := journal.get_node_or_null("%Sections") as TabContainer
	if sections != null and sections.get_tab_count() > 0:
		sections.set_tab_title(0, "Current")
	var section_title := journal.get_node_or_null("%SectionTitle") as Label
	if section_title != null and section_title.text == "Home":
		section_title.text = "Current"
	# Keep internal section ids stable for the large existing Journal script, but
	# translate any visible navigation control that still presents that id.
	for node in journal.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and str(button.get_meta("section", "")) == "Home":
			button.text = "Current"


func _ensure_desk_screen() -> void:
	if _desk_screen != null:
		return
	_desk_screen = DeskScreenScript.new()
	_adopt_screen(_desk_screen)
	_desk_screen.opened.connect(_desk_opened)


func _show_desk() -> void:
	_ensure_desk_screen()
	_desk_screen.bind(CareerManager, get_node("/root/GameManager"))
	_apply_office_career_state()
	office_shell.visible = true
	office_shell.snap_to(&"Desk")
	_show_only(_desk_screen)


func _desk_opened(what: String) -> void:
	match what:
		"journal": _show_journal()
		"training": _show_training()
		"scouting": _show_scouting()
		"housing": _show_accommodation()
		"kitchen": _show_kitchen()
		"encyclopedia": _show_encyclopedia()
		"calendar": _open_calendar_from_desk()
		"office_wide": office_shell.focus_office_wide()
		"settings": _open_menu()
		"phone", "machine": pass


func _open_calendar_from_desk() -> void:
	await office_shell.focus_calendar()
	_show_schedule()


func _apply_office_career_state() -> void:
	var career = CareerManager.career if CareerManager.has_career() else null
	office_shell.apply_career_state(career)


func _show_lock_in() -> void:
	_ensure_lock_in_screen()
	_lock_in_screen.refresh()
	_show_only(_lock_in_screen)


func _show_accommodation() -> void:
	_ensure_accommodation_screen()
	_accommodation_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_accommodation_screen)


func _show_kitchen() -> void:
	_ensure_kitchen_screen()
	_kitchen_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_kitchen_screen)


func _ensure_esc_menu() -> void:
	if _esc_menu != null:
		return
	_esc_menu = EscMenuScript.build()
	_esc_menu.z_index = 100
	add_child(_esc_menu)
	UIStyleSystem.apply(_esc_menu, _theme_name == "light")
	_esc_menu.save_requested.connect(func() -> void:
		if CareerManager.has_career():
			CareerManager.save_career()
	)
	_esc_menu.title_requested.connect(_show_title)
	_esc_menu.load_requested.connect(_load_career)
	_esc_menu.theme_requested.connect(func(name: String) -> void:
		_apply_theme(name)
		UIStyleSystem.apply(_esc_menu, name == "light")
	)
	_esc_menu.quit_requested.connect(func() -> void: get_tree().quit())


func _open_menu() -> void:
	_ensure_esc_menu()
	move_child(_esc_menu, -1)
	_esc_menu.open_menu(_save_entries(), _theme_name, CareerManager.has_career())


func _save_entries() -> Array:
	var out: Array = []
	for metadata in CareerManager.list_save_metadata():
		out.append({
			"id": str(metadata.get("save_id", "")),
			"label": "%s  /  %s" % [
				str(metadata.get("career_name", "Career")),
				str(metadata.get("organization_name", "Organization")),
			],
		})
	return out


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	if _esc_menu != null and _esc_menu.visible:
		_esc_menu.close_menu()
	else:
		_open_menu()
	get_viewport().set_input_as_handled()


func _show_encyclopedia() -> void:
	_ensure_encyclopedia_screen()
	_show_only(_encyclopedia_screen)


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
	var height := float(get_viewport().get_visible_rect().size.y)
	UIHalftone.set_viewport_height(height)
	UICardStock.set_viewport_height(height)


func _apply_theme(theme_name: String, persist: bool = true) -> void:
	var resolved := "light" if theme_name == "light" else "dark"
	_theme_name = resolved
	theme = LightTheme if resolved == "light" else DarkTheme
	if _wipe != null:
		_wipe.set_palette(
			Color(0.94, 0.92, 0.86) if resolved == "light" else Color(0.09, 0.10, 0.13),
			Color(0.20, 0.18, 0.14) if resolved == "light" else Color(0.02, 0.02, 0.03),
		)
	new_career_screen.set_light_mode(resolved == "light")
	if match_center.has_method("set_light_mode"):
		match_center.set_light_mode(resolved == "light")
	UIHalftone.clear_cache()
	UICardStock.clear_cache()
	UIStyleSystem.apply(self, resolved == "light")
	# The title deliberately breaks the generic opaque-screen rule so the live
	# room can show through; apply its alpha treatment after the broad style walk.
	title_screen.set_theme_name(resolved)
	for palette_node in get_tree().get_nodes_in_group("ui_palette_3d"):
		if palette_node.has_method("apply_ui_palette"):
			palette_node.apply_ui_palette(resolved == "light")
	if persist:
		var config := ConfigFile.new()
		config.set_value("presentation", "theme", resolved)
		config.save(SETTINGS_PATH)


func _show_training() -> void:
	_ensure_training_screen()
	_training_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_training_screen)


func _show_scouting() -> void:
	_ensure_scouting_screen()
	_scouting_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_scouting_screen)


func _show_schedule() -> void:
	_ensure_schedule_screen()
	_schedule_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_schedule_screen)
