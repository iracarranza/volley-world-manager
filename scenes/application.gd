extends Control

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const LightTheme := preload("res://scenes/themes/light_theme.tres")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const UICardStock := preload("res://scripts/data/ui_card_stock.gd")
const ScreenWipeScript := preload("res://scenes/components/screen_wipe.gd")
const TrainingScreenScript := preload("res://scenes/screens/training_screen.gd")
const ScoutingScreenScript := preload(
	"res://scenes/screens/scouting_screen.gd"
)
const ScheduleScreenScript := preload("res://scenes/screens/schedule_screen.gd")
const LockInScreenScript := preload("res://scenes/screens/lock_in_screen.gd")
const AccommodationScreenScript := preload(
	"res://scenes/screens/accommodation_screen.gd"
)
const KitchenScreenScript := preload("res://scenes/screens/kitchen_screen.gd")
const EscMenuScript := preload("res://scenes/components/esc_menu.gd")
const DeskScreenScript := preload("res://scenes/screens/desk_screen.gd")
const EncyclopediaScreenScript := preload(
	"res://scenes/screens/encyclopedia_screen.gd"
)
const SETTINGS_PATH := "user://settings.cfg"

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var title_screen: VolleyballTitleScreen = %TitleScreen
@onready var new_career_screen: VolleyballNewCareerScreen = %NewCareerScreen
@onready var journal: VolleyballJournalScreen = %Journal
@onready var match_center: Control = %MatchCenter

var _wipe: ScreenWipe = null
## Whether any screen has been shown yet. The first one arrives rather than being
## wiped to -- see `_show_only`.
var _has_shown: bool = false
## Built in code rather than in `main.tscn`, because both are whole-screen
## Controls with no scene content of their own -- everything they show is drawn
## from the career. A .tscn for either would be an empty node with a script.
var _training_screen: VolleyballTrainingScreen = null
var _scouting_screen: VolleyballScoutingScreen = null
var _schedule_screen: VolleyballScheduleScreen = null
var _lock_in_screen: LockInScreen = null
var _accommodation_screen: AccommodationScreen = null
var _kitchen_screen: KitchenScreen = null
var _esc_menu: EscMenu = null
## The desk: the home state a career starts on, and the one screen that owns
## nothing -- it emits a key and `_desk_opened` maps it to a page.
var _desk_screen: DeskScreen = null
var _encyclopedia_screen: EncyclopediaScreen = null
## The theme currently up, kept because the style pass is a tree walk that
## happens once. A screen built after that walk was never in the tree for it, so
## it has to be given the same pass on the way in or it arrives unstyled -- a
## page with no backdrop, which in the dark theme is invisible.
var _theme_name: String = "dark"


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
	## The journal is the one object made of cloth.
	##
	## The stitched treatment was the whole interface when the journal was the
	## whole interface. It is not any more -- the clipboard, the folders and the
	## planner are paper somebody drew on -- so the sewn edge is declared here,
	## once, on the one screen it belongs to. Everything else takes the pen.
	journal.set_meta(UIStyleSystem.MEDIUM_META, UIStyleSystem.MEDIUM_SEWN)

	title_screen.new_career_requested.connect(_show_new_career)
	title_screen.career_load_requested.connect(_load_career)
	title_screen.theme_requested.connect(_apply_theme)
	title_screen.exit_requested.connect(func() -> void: get_tree().quit())
	new_career_screen.back_requested.connect(_show_title)
	new_career_screen.career_created.connect(_show_desk)
	journal.title_requested.connect(_show_title)
	## Not straight to the match. `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §2:
	## a roster is only worth studying if committing to one is an act, and until
	## now the last thing a manager did before a match was click a fixture.
	journal.play_match_requested.connect(_show_lock_in)
	call_deferred("_connect_match_center_signal")
	## Added in code rather than the scene because it has to be the last child --
	## later siblings draw over earlier ones -- and a node whose whole job is to
	## cover everything is easier to keep last here than in a .tscn somebody will
	## reorder.
	journal.training_requested.connect(_show_training)
	journal.scouting_requested.connect(_show_scouting)
	journal.encyclopedia_requested.connect(_show_encyclopedia)
	journal.accommodation_requested.connect(_show_accommodation)
	journal.kitchen_requested.connect(_show_kitchen)
	journal.menu_requested.connect(_open_menu)
	## Last, so the sheet covers everything, including the screens built later.
	_wipe = ScreenWipeScript.new()
	add_child(_wipe)
	_load_theme()
	_show_title()


## The three code-built screens, each stood up the first time it is asked for.
##
## **They were all built here in `_ready`, and that was the stall.** Opening the
## game froze for tens of seconds before the title screen would take a click, and
## every click made during the freeze arrived at once when it ended -- which is a
## blocked main thread, not a slow renderer.
##
## The clipboard is what blocks. It builds a worksheet, the worksheet asks for
## every figure it can draw -- seven volis, a headshot each plus three phases in
## two views, forty-nine stickers -- and each one is a posed 3D render, two
## texture readbacks and a contour trace. That is a real cost and it is the right
## cost for a page of drawn bodies. It is simply not a cost the *title screen*
## should be paying, and it was, because a screen nobody had asked for was in the
## tree before the first frame.
##
## Measured, not guessed: `tools/preview/startup_probe.gd` traces frame times off
## a cold boot and names anything over four frames' worth. Headless it settles in
## under three seconds; with a renderer attached the boot path used to contain one
## frame minutes long, and that frame is this.
##
## Lazily built rather than deferred by a frame or two, because the work is not
## small and deferring only decides *which* frame is ruined. A manager who never
## opens the clipboard should never pay for it.
func _ensure_training_screen() -> void:
	if _training_screen != null:
		return
	_training_screen = TrainingScreenScript.new()
	_adopt_screen(_training_screen)
	_training_screen.back_requested.connect(_show_journal)
	_training_screen.schedule_requested.connect(_show_schedule)


func _ensure_scouting_screen() -> void:
	if _scouting_screen != null:
		return
	_scouting_screen = ScoutingScreenScript.new()
	_adopt_screen(_scouting_screen)
	_scouting_screen.back_requested.connect(_show_journal)


func _ensure_schedule_screen() -> void:
	if _schedule_screen != null:
		return
	_schedule_screen = ScheduleScreenScript.new()
	_adopt_screen(_schedule_screen)
	_schedule_screen.back_requested.connect(_show_training)


## The encyclopedia is the cheapest screen in the game to stand up, because it
## authors nothing: every line it prints already exists in `VolleyballRegions`.
func _ensure_accommodation_screen() -> void:
	if _accommodation_screen != null:
		return
	_accommodation_screen = AccommodationScreenScript.new()
	_adopt_screen(_accommodation_screen)
	_accommodation_screen.back_requested.connect(_show_journal)


func _ensure_kitchen_screen() -> void:
	if _kitchen_screen != null:
		return
	_kitchen_screen = KitchenScreenScript.new()
	_adopt_screen(_kitchen_screen)
	_kitchen_screen.back_requested.connect(_show_journal)


func _ensure_encyclopedia_screen() -> void:
	if _encyclopedia_screen != null:
		return
	_encyclopedia_screen = EncyclopediaScreenScript.new()
	_adopt_screen(_encyclopedia_screen)
	_encyclopedia_screen.back_requested.connect(_show_journal)


func _ensure_lock_in_screen() -> void:
	if _lock_in_screen != null:
		return
	_lock_in_screen = LockInScreenScript.new()
	_adopt_screen(_lock_in_screen)
	_lock_in_screen.bind(CareerManager, get_node("/root/GameManager"))
	_lock_in_screen.cancelled.connect(_show_journal)
	_lock_in_screen.confirmed.connect(_show_match)


## Add a screen, and put the wipe back on top of it.
##
## Later siblings draw over earlier ones, so a screen added after the wipe covers
## the sheet that is supposed to cover it -- which is invisible until the one
## frame it matters, on the wipe that carried you to that very screen.
func _adopt_screen(screen: Control) -> void:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	add_child(screen)
	if _wipe != null and _wipe.is_inside_tree():
		move_child(_wipe, -1)
	var is_light := _theme_name == "light"
	UIStyleSystem.apply(screen, is_light)
	## The 3D nodes carry their palette in materials rather than in a theme, so
	## they are painted by hand and a new screen's have never been painted.
	for palette_node in screen.find_children("*", "", true, false):
		if palette_node.is_in_group("ui_palette_3d") \
				and palette_node.has_method("apply_ui_palette"):
			palette_node.apply_ui_palette(is_light)


func _connect_match_center_signal() -> void:
	if match_center:
		match_center.career_exit_requested.connect(_show_journal)


## Every screen change goes through here, so the wipe does too.
##
## The swap itself is handed to the wipe as a callable and happens while the
## sheet is across, which is why the outgoing screen is never seen being torn
## down. The first call has no wipe -- there is nothing to leave.
func _show_only(screen: Control) -> void:
	## **The first call really has no wipe now.** The comment above said so and the
	## code did not: the guard tested whether the wipe existed, and by this point it
	## has just been added, so opening the game played a full wipe over a window
	## that had never been drawn -- half a second of sheet across a blank screen
	## during the exact frames a cold start is busiest. Nothing to leave means
	## nothing to cover.
	if not _has_shown or _wipe == null or not _wipe.is_inside_tree():
		_has_shown = true
		_swap_to(screen)
		return
	_wipe.play(func() -> void: _swap_to(screen))


func _swap_to(screen: Control) -> void:
	for candidate in [
		title_screen, new_career_screen, journal, match_center,
		_training_screen, _scouting_screen, _schedule_screen, _lock_in_screen,
		_encyclopedia_screen, _accommodation_screen, _kitchen_screen,
		_desk_screen,
	]:
		if candidate != null:
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
		_show_journal()


func _show_journal() -> void:
	journal.refresh()
	_show_only(journal)


## ## The desk
##
## The home state, and where a career now begins rather than the journal. Built
## on demand like every other screen, and it is the one that owns *nothing*: it
## emits a key and this maps it to a page.
##
## The map lives here rather than on the desk because the desk does not know what
## a screen is -- it knows there is a journal on it. That separation is what lets
## the desk be a picture of a room and still be navigation.
func _ensure_desk_screen() -> void:
	if _desk_screen != null:
		return
	_desk_screen = DeskScreenScript.new()
	add_child(_desk_screen)
	_desk_screen.opened.connect(_desk_opened)
	UIStyleSystem.apply(_desk_screen, _theme_name == "light")


func _show_desk() -> void:
	_ensure_desk_screen()
	_desk_screen.bind(CareerManager, get_node("/root/GameManager"))
	_show_only(_desk_screen)


func _desk_opened(what: String) -> void:
	match what:
		"journal":
			_show_journal()
		"training":
			_show_training()
		"scouting":
			_show_scouting()
		"housing":
			_show_accommodation()
		"kitchen":
			_show_kitchen()
		"encyclopedia":
			_show_encyclopedia()
		"settings", "phone", "machine":
			## Settings opens the same overlay Escape does, because there is one
			## place the game keeps the things that are not the game and a second
			## one would drift. The phone and the machine have no screens yet and
			## deliberately do nothing rather than opening a placeholder.
			if what == "settings":
				_open_menu()


## The gate in front of the match.
##
## `prepare_fixture` has already run by the time this is reached -- the journal
## does it before emitting -- so the opponent, the fixture and the lineup the
## board reads are the ones the match will actually be played with. Backing out
## leaves the fixture prepared and unplayed, which is the same state the journal
## was already in.
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


## ## The escape menu
##
## Built after the wipe and moved above it, because it has to cover everything
## including the sheet -- it is the one overlay that is *not* part of the game
## being played, so nothing in the game may draw over it.
func _ensure_esc_menu() -> void:
	if _esc_menu != null:
		return
	_esc_menu = EscMenuScript.new()
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
	_esc_menu.open_menu(
		_save_entries(), _theme_name, CareerManager.has_career()
	)


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


## Escape, from anywhere. `_unhandled_key_input` rather than `_input`, so a
## screen that wants Escape for its own panel -- the kitchen's, the housing
## page's -- gets it first and this only fires when nothing else claimed it.
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


## Both substrates, from one signal. The halftone and the card fleck are separate
## systems on purpose -- see `UICardStock`'s header -- but they are the same kind
## of pixel-pitch texture and a window resize is the same event for both. Missing
## one here is a bug you can only see at a window size nobody develops at.
func _sync_halftone_scale() -> void:
	var height := float(get_viewport().get_visible_rect().size.y)
	UIHalftone.set_viewport_height(height)
	UICardStock.set_viewport_height(height)


func _apply_theme(theme_name: String, persist: bool = true) -> void:
	var resolved := "light" if theme_name == "light" else "dark"
	_theme_name = resolved
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
	UICardStock.clear_cache()
	UIStyleSystem.apply(self, resolved == "light")
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
