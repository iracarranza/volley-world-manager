class_name VolleyballTrainingScreen
extends Control

## The clipboard: two pages, and a strip that ties them to tomorrow.
##
## Per `docs/design/TACTICS_AND_TRAINING.md` §0.9, drills are no longer a page
## here -- they are an appointment in the day, run live. That leaves the
## clipboard with the two halves that *are* pages: **Tactics**, where a plan is
## declared (a preset, then specifics, decomposed to per-voli asks); and
## **Development**, the attribute work that raises the 0-100 ceiling, which was
## this screen's whole "Attribute" mode before the split. The fit strip below the
## ribbon is the connective tissue the doc calls for -- it names the worst gap
## between what Tactics just asked for and what the squad is actually
## comfortable with, and points at the session that would close it rather than at
## a tab, because there is no third tab to point at any more.
##
## This pass is a visual draft, not the finished mechanic. The Tactics tab's
## presets and the strip's ask/familiarity numbers are placeholders -- §0.2 and
## §0.4 have not been built yet -- laid out at the fidelity the finished screen
## should have, so the shape can be judged before the model exists.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const UIStyleSystemScript := preload("res://scripts/systems/ui_style_system.gd")
const WorksheetScript := preload("res://scenes/components/worksheet.gd")
const RallyEventModelScript := preload("res://scripts/models/rally_event.gd")
const RedPenCircleScript := preload("res://scenes/components/red_pen_circle.gd")
const RosterTrayScript := preload("res://scenes/components/roster_tray.gd")
const StickyNoteScript := preload("res://scenes/components/sticky_note.gd")
const TrainingSystem := preload("res://scripts/systems/training_system.gd")
const TrainingFocusModel := preload("res://scripts/systems/training_focus_model.gd")
const DailyScheduleSystem := preload("res://scripts/systems/daily_schedule_system.gd")
const TrainingRegimenModel := preload("res://scripts/models/training_regimen.gd")
const TrainingProjection := preload("res://scripts/systems/training_projection.gd")
const SystemFitBandsScript := preload("res://scenes/components/system_fit_bands.gd")


signal back_requested
signal schedule_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _modes: TabContainer = null
var _fit_strip: HBoxContainer = null
var _worksheet: UIWorksheet = null
var _selected_preset: String = "Combination Play"
var _phase_group: ButtonGroup = null
var _view_group: ButtonGroup = null
var _tray: UIRosterTray = null
var _sticky: UIStickyNote = null
var _drill_label: Label = null
var _place_along: SpinBox = null
var _place_depth: SpinBox = null
var _activity_rail: VBoxContainer = null
var _detail: VBoxContainer = null
var _sidebar: VBoxContainer = null
var _open_phase: String = ""
var _open_activity: String = ""


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	_load_sheet()
	_populate_rail()
	refresh()


## Put the club's saved sheet back on the clipboard, and keep it saved.
##
## Every edit writes the whole sheet rather than patching one field. A tactic
## sheet is six numbers and two small dictionaries -- writing all of it costs
## nothing measurable, and the alternative is eight places that each have to
## remember which part they changed, which is how a plan ends up half-saved.
func _load_sheet() -> void:
	if _worksheet == null or _game_manager == null:
		return
	var team: Resource = _game_manager.get("team")
	if team == null or team.tactic_sheet == null:
		return
	team.tactic_sheet.apply_to(_worksheet)
	_worksheet.queue_redraw()


func _save_sheet() -> void:
	if _worksheet == null or _game_manager == null:
		return
	var team: Resource = _game_manager.get("team")
	if team == null:
		return
	team.tactic_sheet = TacticSheet.from_worksheet(_worksheet)
	if _career_manager != null and _career_manager.has_method("save_career"):
		_career_manager.save_career()


func _ready() -> void:
	_build()


func _build() -> void:
	var schedule_button := ScreenShell.action(
		"Daily Schedule", "The day pays for these sessions."
	)
	schedule_button.pressed.connect(func() -> void: schedule_requested.emit())
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(
		self, "Clipboard", [schedule_button, back_button] as Array[Button],
		ScreenShell.BACKING_CORK,
	)
	## The clipboard is a printed form, not a page out of the journal. Declared
	## here, once, the same way the journal declares its cloth -- and it is what
	## takes the halftone screen, the warm stock and the hand-drawn edges off
	## this object, leaving the marker and the red pen as the only human marks.
	set_meta(UIStyleSystemScript.MEDIUM_META, UIStyleSystemScript.MEDIUM_FORM)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(body)

	## Two pages, in the causal order §0 gives them: declare, then raise. Visible
	## tabs, unlike the dashboard's outer sections, which hide theirs because a
	## separate nav strip names them -- here the tabs are the only thing saying
	## there are two ways to use this clipboard.
	_modes = TabContainer.new()
	_modes.tabs_visible = true
	## Plastic binder dividers rather than the journal's cut index tabs. Torn
	## paper is the journal's own material and it followed the tabs here by
	## default; a clipboard's dividers are the thing you buy in a packet of five.
	_modes.set_meta(&"ui_tabs", &"plastic")

	## The tabs and the line beside them share a row, and the host is what lets
	## them.
	##
	## The line used to be a panel of its own above the tabs -- a full row of the
	## page's height spent on one sentence, on a page that was already running off
	## the bottom edge of the window. A `TabContainer` draws its own tab strip and
	## has no slot to put anything beside it, and a plain child of one *becomes a
	## tab*, so the strip cannot simply be given a second occupant.
	##
	## A plain `Control` can hold both. It is not a `Container`, so it does not
	## recompute what is under it: the tabs take the whole rect and the line is
	## anchored to the top right, sitting in the empty part of the strip the tab
	## titles never reach.
	var tabs_host := Control.new()
	tabs_host.name = "TabsHost"
	tabs_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs_host.size_flags_stretch_ratio = 2.6
	body.add_child(tabs_host)

	_modes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs_host.add_child(_modes)
	tabs_host.add_child(_build_tab_strip_line())

	_modes.add_child(_build_tactics_page())
	_modes.add_child(_build_development_page())




## What the clipboard is pointing at, on the tab strip's own row.
##
## This was a panel across the top holding a rotation selector, an ask count and
## a named gap. Two of those three went, and not for space alone: the rotation
## selector filtered a strip whose numbers were placeholders, so it was a control
## over nothing, and "4 asks, 1 unfamiliar" was the placeholder it filtered. A
## control that cannot change anything and a figure that is not measured are
## worse than an empty strip, because they read as working.
##
## What is left is the one line that says what the page is for -- the gap worth
## training, and where it goes. Right-aligned into the part of the tab strip the
## two titles never reach, so it costs no height at all.
##
## Still a placeholder itself, and labelled as one below. Decomposing a preset
## into per-voli asks and scoring them against learned comfort are both unbuilt.
const TAB_STRIP_LINE_HEIGHT: float = 30.0


func _build_tab_strip_line() -> Control:
	var row := HBoxContainer.new()
	row.name = "TabStripLine"
	row.add_theme_constant_override("separation", 10)
	## Anchored along the top edge and grown leftward from the right one, so it
	## keeps its distance from the corner however wide the page gets, and the tab
	## titles keep the left end of the strip to themselves.
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -12.0
	row.offset_top = 3.0
	row.offset_bottom = TAB_STRIP_LINE_HEIGHT
	## A row sitting over a tab strip would otherwise eat the clicks meant for
	## the tab beside it wherever the two overlap.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The page's one instruction, which cost a row of its own for a sentence you
	## need once. Up here it costs nothing: the tab strip has the height already.
	var how := Label.new()
	how.name = "HowLabel"
	how.text = "Drag a voli from a slot onto the court."
	how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(how)

	var gap := Label.new()
	gap.name = "GapLabel"
	gap.text = "⟨ Ivo 4 · slide coordinate ⟩"
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	var to_session := Label.new()
	to_session.name = "SessionLabel"
	to_session.text = "→ tomorrow's session"
	to_session.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(to_session)
	return row


## Tactics: a preset rail on the left, and the board a coach explains it on.
##
## The board replaces the tactical court that was here. The court draws the same
## information as exact geometry, which is the one register this interface uses
## nowhere else -- everything around it is a hand and an instrument, and a plan
## rendered in 1px lines reads as machine output sitting inside somebody's
## notebook. A phase is not a diagram; it is the thing a young coach scrawls on a
## board, wipes, and scrawls again, which is what `UIWorksheet` draws.
##
## The phase buttons are the board's own vocabulary rather than the page's:
## picking one squeegees what is there and draws the next layout in behind the
## wipe.
func _build_tactics_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Tactics"
	page.add_theme_constant_override("separation", 8)

	## The sheet and the tools share the page.
	##
	## The presets are gone from here entirely. They are a choice about the whole
	## tactic and this page is about placing bodies, so keeping them in view cost
	## a row of width for something nobody touches while dragging -- and losing
	## them is what let the two selectors fit on one note.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	## The tools stand on the left and the sheet takes what is left.
	##
	## They were the other way round. What is on this page is a *desk*, and the
	## two halves are not interchangeable: the note and the slots are what a hand
	## reaches for, the sheet is what the hand reaches *toward*. Put the tools on
	## the far side and every drag crosses the whole page.
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.custom_minimum_size = Vector2(196.0, 0.0)
	body.add_child(tools)

	## The note goes above the slots, for the same reason.
	##
	## It says what is being planned -- which phase, seen from where -- and that
	## is the thing you settle before you start placing bodies. Under the slots it
	## was read after the work it governs, and the slots are the taller of the two,
	## so it also sat wherever the tray happened to end.
	_sticky = StickyNoteScript.new()
	_sticky.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sticky.set_group("Planning", WorksheetScript.PHASES, "Block")
	_sticky.set_group("Looking from", WorksheetScript.VIEWS, WorksheetScript.VIEW_THREE_QUARTER)
	_sticky.option_chosen.connect(_sticky_chosen)
	tools.add_child(_sticky)

	tools.add_child(_build_coordinate_entry())

	_tray = RosterTrayScript.new()
	_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray.voli_dropped.connect(_drop_voli)
	tools.add_child(_tray)

	_worksheet = WorksheetScript.new()
	_worksheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_worksheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_worksheet.custom_minimum_size = Vector2(0.0, 200.0)
	body.add_child(_worksheet)

	_worksheet.sticker_baked.connect(_headshot_baked)
	## Holding a voli on the sheet lights their card in the tray, which is the
	## whole of "which voli is who": the bodies are on the court and the names
	## are in the tray, and nothing joined the two until this.
	_worksheet.voli_grabbed.connect(func(who: String) -> void:
		_tray.lit_key = who
	)
	_worksheet.voli_released.connect(func() -> void:
		_tray.lit_key = ""
	)
	## Deferred, because the page is built before it is added to the tab container
	## -- so the worksheet is not in the tree yet, its `_ready` has not run, and
	## its baker does not exist. Called inline this returned silently and the tray
	## stayed empty with nothing to say it had failed.
	call_deferred("_request_headshots")

	## What the sheet currently says, written out.
	##
	## The marks are the control, so the words are not a second control -- they are
	## the receipt. A page whose whole state lives in a drawing needs one line
	## somewhere that a manager can read back without decoding it, which is the same
	## argument §0.10 makes for the adjustment line.
	## Both receipts on one line, and the line is why the page fits.
	##
	## Measured rather than trimmed by eye: `layout_probe -- clipboard` weighs the
	## page against the window it has to live in, and found the tactics page
	## needing 561 px plus a 45 px tab strip where 560 px was going -- fifty over,
	## which is the clipping. Most of that floor is the tools column and cannot
	## come off without losing a control. Two one-line receipts stacked cost 52 px
	## of it for text that reads perfectly well side by side.
	##
	## They stay separate labels because they are separate sentences with separate
	## sources -- one is what the sheet says, the other is what was declared -- and
	## two nodes on one row is a layout, while one node holding both is a format
	## string that has to be taken apart again the next time either changes.
	var receipts := HBoxContainer.new()
	receipts.add_theme_constant_override("separation", 12)
	page.add_child(receipts)

	_drill_label = Label.new()
	_drill_label.name = "DrillLabel"
	receipts.add_child(_drill_label)
	_worksheet.drill_changed.connect(_drill_written)
	## Everything that changes the sheet writes it. Connected here, beside the
	## worksheet's construction, so a new signal that changes the plan and forgets
	## to save is visibly missing from one list rather than invisibly missing from
	## eight call sites.
	for changed in [
		_worksheet.drill_changed, _worksheet.zone_priority_changed,
		_worksheet.behaviour_changed, _worksheet.placements_changed,
		_worksheet.phase_changed, _worksheet.view_changed,
	]:
		changed.connect(func(_a = null, _b = null, _c = null) -> void: _save_sheet())
	_drill_written(_worksheet.drill_zone)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipts.add_child(spacer)

	var declared := Label.new()
	declared.name = "DeclaredLabel"
	declared.text = _selected_preset
	receipts.add_child(declared)
	_sync_view_availability()
	return page


## "Ivo drills a roll from 4, into deep cross." One sentence, rebuilt from the
## sheet rather than assembled as the manager clicks -- so it cannot drift from
## what is drawn.
func _drill_written(zone_index: int) -> void:
	if _drill_label == null or _worksheet == null:
		return
	var zone: Dictionary = WorksheetScript.NET_ZONES[
		clampi(zone_index, 0, WorksheetScript.NET_ZONES.size() - 1)
	]
	## Only what the sheet still shows. It used to name the shot and the corner it
	## was aimed at; both were drawn as a first guess and both came off, and a line
	## of prose describing marks that are no longer on the page is the worst kind
	## of stale -- it reads as authoritative and nothing on screen contradicts it.
	var who := ""
	for profile in _tray_profiles():
		if str(profile.get("key", "")) == _worksheet.drill_who:
			who = str(profile.get("display_name", ""))
			break
	if who.is_empty():
		_drill_label.text = "Zone %s — drop a voli on the pin." % str(zone["label"])
		return
	_drill_label.text = "%s works from %s." % [who, str(zone["label"])]


## Place the selected voli at a typed coordinate.
##
## Not a shortcut for the drag -- the other way round. Scouting will hand this
## screen *numbers*: where the block got beaten, which seam on the floor leaked
## most, where attacks were stuffed or touched. Every one of those is a point on
## a court, and a planner that can only be operated by pointing cannot accept any
## of them without pretending to be a mouse. The field is the human end of the
## same door. See `docs/design/TACTICS_AND_TRAINING.md` §0.12.
##
## Metres from the middle of the court and metres from the net, because those are
## the units the sheet is drawn in and the units a report will quote.
func _build_coordinate_entry() -> Control:
	var row := HBoxContainer.new()
	row.name = "CoordinateEntry"
	row.add_theme_constant_override("separation", 4)

	_place_along = SpinBox.new()
	_place_along.min_value = -4.5
	_place_along.max_value = 4.5
	_place_along.step = 0.1
	_place_along.value = 0.0
	_place_along.tooltip_text = "Metres right of the middle line"
	_place_along.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_place_along)

	_place_depth = SpinBox.new()
	_place_depth.min_value = -9.0
	_place_depth.max_value = 9.0
	_place_depth.step = 0.1
	_place_depth.value = 3.0
	_place_depth.tooltip_text = "Metres back from the net"
	_place_depth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_place_depth)

	var place := Button.new()
	place.text = "Place"
	place.pressed.connect(_place_at_coordinate)
	row.add_child(place)
	return row


func _place_at_coordinate() -> void:
	if _worksheet == null or _tray == null or _tray.selected < 0:
		return
	var squad := _tray_profiles()
	var slot: int = _tray.selected
	var who := str(squad[slot].get("key", "")) if slot < squad.size() else ""
	_worksheet.place_voli_at(
		slot, Vector2(float(_place_along.value), float(_place_depth.value)), who
	)


func _sticky_chosen(heading: String, option: String) -> void:
	if heading == "Planning":
		_choose_phase(option)
	else:
		_choose_view(option)


## The seven faces, baked through the worksheet's own queue.
##
## The same rig, the same trace, a tighter camera -- a face is a very small
## silhouette. Standing up a second baker would mean a second SubViewport and a
## second copy of the actor for no gain.
## Hand the sheet the lineup, and take the faces back out of its bake queue.
##
## One queue, not two. The tray's headshots and the sheet's figures are the same
## seven volis rendered from the same rig; standing up a second baker would mean
## a second SubViewport and a second copy of the actor for nothing.
func _request_headshots() -> void:
	if _worksheet == null or _worksheet.stickers() == null:
		return
	## Wired here rather than where the page is built, because the worksheet's own
	## `_ready` has not run at build time -- the page is assembled before it is
	## added to the tab container -- so its baker is still null. The same reason
	## this whole call is deferred.
	_worksheet.set_squad(_tray_profiles())


## The seven the sheet can draw, read off the real lineup where there is one.
##
## `key` is what a sticker is filed under, and it is the player's id rather than
## the tray slot: a slot is a place in a formation and the same voli can be moved
## between two of them, at which point a slot-keyed bake is a photograph of the
## wrong person.
func _tray_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for player in _lineup():
		out.append({
			"key": "v%d" % int(player.id),
			## The id, because it is what every per-voli difference is seeded
			## from -- produce, colourway, coat. Without it the bake falls back
			## to player 1 and the whole tray comes out as one voli.
			"player_id": int(player.id),
			"height_cm": player.height_cm,
			"mass_kg": player.mass_kg,
			"wingspan_cm": player.wingspan_cm,
			"stride_length_m": player.stride_length_m,
			"body_type": player.body_type,
			"dominant_hand": player.dominant_hand,
			"standing_reach_meters": player.standing_reach_cm() / 100.0,
			"jumping_reach_meters": player.jumping_reach_cm() / 100.0,
			"display_name": player.display_name,
		})
	if not out.is_empty():
		return out
	return _placeholder_profiles()


## Six on court plus a libero, in rotation order, from whatever the manager has
## actually declared. Falls back to the head of the roster so a career with no
## declared lineup still draws seven different people rather than nothing.
func _lineup() -> Array:
	if _game_manager == null:
		return []
	var team: Resource = _game_manager.get("team")
	if team == null:
		return []
	var picked: Array = []
	var seen := {}
	for raw_id in Array(team.get("starting_player_ids")):
		var player: VolleyballPlayer = _game_manager.player_by_id(int(raw_id))
		if player != null and not seen.has(player.id):
			seen[player.id] = true
			picked.append(player)
	for raw_id in Array(team.get("libero_ids")):
		if picked.size() >= 7:
			break
		var libero: VolleyballPlayer = _game_manager.player_by_id(int(raw_id))
		if libero != null and not seen.has(libero.id):
			seen[libero.id] = true
			picked.append(libero)
	for player in _game_manager.players:
		if picked.size() >= 7:
			break
		if not seen.has(player.id):
			seen[player.id] = true
			picked.append(player)
	return picked


## Varied deliberately -- the whole reason to bake a face rather than draw an
## icon is that these are different people, and seven identical heads would prove
## nothing. Only reached before a career is bound.
func _placeholder_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bodies := ["Vegi", "Cani", "Avi"]
	var names := ["Ivo", "Mira", "Sena", "Boro", "Tavi", "Nemi", "Lira"]
	for slot in range(7):
		out.append({
			"key": "p%d" % slot,
			"height_cm": 178.0 + float((slot * 7) % 26),
			"wingspan_cm": 182.0 + float((slot * 5) % 28),
			"stride_length_m": 0.80 + float(slot % 4) * 0.035,
			"body_type": bodies[slot % bodies.size()],
			"dominant_hand": "Left" if slot == 2 else "Right",
			"standing_reach_meters": 2.36 + float(slot % 5) * 0.05,
			"jumping_reach_meters": 3.10 + float(slot % 6) * 0.06,
			"display_name": names[slot],
		})
	return out


func _headshot_baked(key: String) -> void:
	if not key.ends_with("_head") or _tray == null:
		return
	var who := key.trim_suffix("_head")
	var built: UIVoliSticker.Sticker = _worksheet.stickers().sticker(key)
	if built == null:
		return
	var squad := _tray_profiles()
	for slot in range(squad.size()):
		if str(squad[slot].get("key", "")) != who:
			continue
		_tray.set_headshot(slot, built.texture, str(squad[slot].get("display_name", "")))
		## The sheet knows a voli by their tray key, so the card has to as well
		## or the lit-up signal has nothing to match against.
		_tray.set_key(slot, str(squad[slot].get("key", "")))
		return


## A voli dropped from the tray onto the sheet.
##
## The drop point arrives in screen space because it crossed between two
## controls, so it is mapped back through the worksheet's own rect -- and refused
## if it landed anywhere else, which is what makes dropping onto the sidebar do
## nothing rather than something surprising.
func _drop_voli(slot: int, at: Vector2) -> void:
	if _worksheet == null:
		return
	var local := at - _worksheet.global_position
	if local.x < 0.0 or local.y < 0.0 \
			or local.x > _worksheet.size.x or local.y > _worksheet.size.y:
		return
	var squad := _tray_profiles()
	var who := str(squad[slot].get("key", "")) if slot < squad.size() else ""
	_worksheet.place_voli(slot, local, who)


## Picking a phase, and picking a view.
##
## The greying is honest -- a view that cannot express a phase should say so
## rather than accepting the click and drawing nothing. The auto-switch is the
## part to watch: a control that silently moves *another* control is how a player
## loses their model of a screen, so it fires only when the chosen combination is
## genuinely empty, it moves the phase rather than the view (the view is what the
## player just asked for, so it is the one that must be honoured), and it says so
## on the board. If §0.10's table ever fills in, both behaviours disappear.
func _choose_phase(phase_name: String) -> void:
	if _worksheet == null:
		return
	_worksheet.set_phase(phase_name)
	if _sticky != null:
		_sticky.set_chosen("Planning", phase_name)
	_sync_view_availability()


func _choose_view(view_name: String) -> void:
	if _worksheet == null:
		return
	_worksheet.set_view(view_name)
	if WorksheetScript.adjustment_for(view_name, _worksheet.phase).is_empty():
		var fallback := WorksheetScript.first_phase_for(view_name)
		if not fallback.is_empty():
			_worksheet.set_phase(fallback)
			if _sticky != null:
				_sticky.set_chosen("Planning", fallback)
	_sync_view_availability()


## Grey every phase this view has nothing to say about, and put what the current
## pair *does* adjust on the line under the board -- so the answer to "what does
## this screen do right now" is always written down rather than inferred.
func _sync_view_availability() -> void:
	if _worksheet == null:
		return
	if _sticky != null:
		var struck: Array[String] = []
		for phase_name in WorksheetScript.PHASES:
			if WorksheetScript.adjustment_for(_worksheet.view, phase_name).is_empty():
				struck.append(phase_name)
		_sticky.set_disabled("Planning", struck)
		_sticky.set_chosen("Looking from", _worksheet.view)
	var page: Node = _worksheet.get_parent()
	var declared := page.find_child("DeclaredLabel", true, false) as Label
	if declared == null:
		return
	var current := WorksheetScript.adjustment_for(
		_worksheet.view, _worksheet.phase
	)
	declared.text = current if not current.is_empty() \
		else "Reading only from this view."


func _add_rail_label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


## Circle it in red when the cursor is over it. Added as a child so the control
## keeps whatever the theme gave it and the pen mark is a separate hand on top,
## the same way `UIInkOutline` layers over a panel rather than restyling it.
func _circle_on_hover(control: Control) -> void:
	if control.get_node_or_null("RedPenCircle") != null:
		return
	var circle := RedPenCircleScript.new()
	circle.name = "RedPenCircle"
	control.add_child(circle)


func _add_preset_button(
	parent: Node, preset_name: String, group: ButtonGroup
) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.text = preset_name
	button.button_pressed = preset_name == _selected_preset
	button.pressed.connect(func() -> void: _select_preset(preset_name))
	_circle_on_hover(button)
	parent.add_child(button)


func _select_preset(preset_name: String) -> void:
	_selected_preset = preset_name
	var page: Node = _worksheet.get_parent()
	var declared := page.find_child("DeclaredLabel", true, false) as Label
	if declared != null:
		declared.text = "%s  ·  %s" % [
		preset_name,
		WorksheetScript.adjustment_for(_worksheet.view, _worksheet.phase),
	]


## Development: a rail of attribute sessions ordered body-first, and the panel
## that sets whichever one is picked. This is the screen's original "Attribute"
## mode, unchanged -- only the name and its neighbour on the clipboard moved.
func _build_development_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Development"
	page.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.text = "From the weight room to the meeting room. \
Sessions near the top cost the legs; sessions near the bottom cost the day."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(caption)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)

	var rail_scroll := ScrollContainer.new()
	rail_scroll.set_meta("ui_style_exempt", true)
	rail_scroll.custom_minimum_size = Vector2(230.0, 0.0)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(rail_scroll)
	_activity_rail = VBoxContainer.new()
	_activity_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activity_rail.add_theme_constant_override("separation", 4)
	rail_scroll.add_child(_activity_rail)

	split.add_child(_build_detail_scroll())

	## This week's state lives here now rather than beside every page. It is
	## reference a manager reads before choosing -- fatigue means, familiarity
	## percentages -- and Tactics needed that column for the roster tray, which is
	## a thing you operate rather than read.
	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 8)
	_sidebar.custom_minimum_size = Vector2(224.0, 0.0)
	split.add_child(_sidebar)
	return page


## The one detail panel Development uses.
##
## Kept as its own scroll (rather than inlined into `_build_development_page`)
## because `_open_phase_panel` reparents it as sessions are picked -- the pattern
## carries over from when a second page shared it. There is only one page left
## to reparent it onto now.
func _build_detail_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	## Exempt from the paper-window treatment every other scrolling region wears.
	## That treatment threads a slip and an overlay onto the region assuming the
	## region paints its own content -- true of an `ItemList`, false here, where
	## the content is child nodes the overlay is a sibling of and draws over. The
	## panel came out as an empty sheet with a scrollbar.
	scroll.set_meta("ui_style_exempt", true)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)
	return scroll


## The rail of attribute sessions, body first.
func _populate_rail() -> void:
	if _activity_rail == null:
		return
	for child in _activity_rail.get_children():
		child.queue_free()
	for activity_name in TrainingSystem.ATTRIBUTE_TRAINING_ORDER:
		var description := TrainingSystem.description(activity_name)
		var button := Button.new()
		button.text = activity_name
		button.tooltip_text = str(description.get("description", ""))
		button.custom_minimum_size = Vector2(0.0, 34.0)
		var chosen := str(activity_name)
		button.pressed.connect(func() -> void: _open_phase_panel(chosen, chosen))
		_activity_rail.add_child(button)


## The week's state: what the day affords, what the club knows, how tired the
## squad is, and what last week actually did. All four are things a manager needs
## before choosing this week's sessions rather than after.
func refresh() -> void:
	if _sidebar == null:
		return
	for child in _sidebar.get_children():
		child.queue_free()
	if _career_manager == null or _game_manager == null:
		return

	var day: Dictionary = DailyScheduleSystem.evaluate(
		_game_manager.team.daily_schedule
	)
	_add_heading(_sidebar, "This week")
	_add_line(_sidebar, "Training blocks: %.1f of %d scheduled" % [
		float(day.get("effective_training_blocks", 0.0)),
		int(day.get("training_blocks", 0)),
	])
	_add_line(_sidebar, "Sleep: %d blocks · Meals: %d" % [
		int(day.get("sleep_blocks", 0)), int(day.get("meal_blocks", 0)),
	])
	for warning in Array(day.get("warnings", [])):
		_add_line(_sidebar, "· %s" % str(warning))

	_add_heading(_sidebar, "What the club knows")
	_add_line(_sidebar, "System familiarity %d%% · cohesion %d%%" % [
		roundi(float(_game_manager.team.tactical_familiarity) * 100.0),
		roundi(float(_game_manager.team.cohesion) * 100.0),
	])

	_add_heading(_sidebar, "Squad fatigue")
	var players: Array = _game_manager.players
	var total := 0.0
	var worst_name := ""
	var worst := -1.0
	for player in players:
		total += float(player.fatigue)
		if float(player.fatigue) > worst:
			worst = float(player.fatigue)
			worst_name = str(player.display_name)
	if not players.is_empty():
		_add_line(_sidebar, "Mean %d%% · heaviest %s at %d%%" % [
			roundi(total / players.size() * 100.0), worst_name, roundi(worst * 100.0),
		])

	_add_heading(_sidebar, "Last week")
	var report: Dictionary = _career_manager.last_training_report
	if report.is_empty():
		_add_line(_sidebar, "No week has been trained yet.")
	else:
		for squad in Array(report.get("squads", [])):
			var row: Dictionary = squad
			_add_line(_sidebar, "%s — %s (%s focus), %d volis, +%d" % [
				str(row.get("squad_name", "Squad")),
				str(row.get("activity", "")),
				str(row.get("focus", "")),
				int(row.get("players", 0)),
				int(row.get("attribute_improvements", 0)),
			])
		for missed in Array(report.get("unaffordable", [])):
			var row2: Dictionary = missed
			_add_line(_sidebar, "· %s did not run — the day was %.1f blocks short." % [
				str(row2.get("squad_name", "Squad")),
				float(row2.get("blocks_required", 0.0))
					- float(row2.get("blocks_left", 0.0)),
			])


## One session's own panel. Laid out the way the tactical planner is: what you are
## editing, then who you are assigning to it.
func _open_phase_panel(phase_id: String, activity: String) -> void:
	if _detail == null:
		return
	_open_phase = phase_id
	_open_activity = activity
	## The panel follows the mode the click came from, so a phase picked on the
	## flowchart opens under the flowchart rather than on the tab next door.
	var host: Control = _modes.get_child(mini(_modes.current_tab, _modes.get_child_count() - 1))
	var scroll: Control = _detail.get_parent()
	if scroll.get_parent() != host and not host.is_ancestor_of(scroll):
		scroll.get_parent().remove_child(scroll)
		host.add_child(scroll)
	for child in _detail.get_children():
		child.queue_free()
	var description := TrainingSystem.description(activity)

	_add_heading(_detail, activity if phase_id == activity
		else "%s · %s" % [phase_id.capitalize(), activity])
	_add_line(_detail, str(description.get("description", "")))
	_add_line(_detail, "Costs %d training block%s of the day." % [
		int(description.get("blocks", 2)),
		"" if int(description.get("blocks", 2)) == 1 else "s",
	])

	## The other half of a session, and the half the screen used to hide.
	##
	## A week does two separate things: it moves individual attributes, and it
	## moves what the club knows collectively. Both were already paid out per
	## squad, scaled by turnout, but only the attribute half was ever drawn -- so
	## a manager comparing Team Practice against Strength & Jump saw two attribute
	## pools and none of the reason to run the first.
	var in_match := _in_match_line(description)
	if not in_match.is_empty():
		_add_line(_detail, in_match)

	var regimen := _regimen_for(activity)

	## Three levels, exactly one of them true. A `ButtonGroup` is what makes that
	## the control's own rule, and `button_pressed` is seeded from the stored
	## focus so the screen opens showing what this session is set to.
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	_detail.add_child(focus_row)
	var focus_label := Label.new()
	focus_label.text = "Focus"
	focus_row.add_child(focus_label)
	var focus_group := ButtonGroup.new()
	for level: int in [
		TrainingRegimenModel.Focus.LOW,
		TrainingRegimenModel.Focus.MEDIUM,
		TrainingRegimenModel.Focus.HIGH,
	]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = focus_group
		button.text = TrainingRegimenModel.focus_name(level)
		button.tooltip_text = _focus_blurb(level)
		button.button_pressed = int(regimen.focus) == level
		var chosen: int = level
		button.pressed.connect(func() -> void: _set_focus(chosen))
		focus_row.add_child(button)

	## What this session can move, and -- at high focus -- which of it the manager
	## is naming. At LOW the list is shown greyed, because a low-focus squad does
	## not get to choose and the screen should say so rather than offering buttons
	## that do nothing. At MEDIUM a picked attribute is *struck off*; at HIGH it
	## is *aimed at*. Same control, opposite meaning, so the label says which.
	_add_heading(_detail, _pool_heading(int(regimen.focus)))
	var pool_row := HFlowContainer.new()
	_detail.add_child(pool_row)
	var has_unsimulated := false
	for attribute_name in Array(description.get("attributes", [])):
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = str(attribute_name).capitalize()
		chip.button_pressed = str(attribute_name) in regimen.attributes
		chip.disabled = int(regimen.focus) == TrainingRegimenModel.Focus.LOW
		## Say when an attribute is not yet read by a rally. A manager aiming a
		## high-focus week at one of these would watch the number climb and see
		## nothing change on court.
		if not TrainingSystem.is_simulated(str(attribute_name)):
			chip.text += " *"
			chip.tooltip_text = "Not yet read by a rally — trains, but does not show up on court."
			has_unsimulated = true
		var picked := str(attribute_name)
		chip.pressed.connect(func() -> void: _toggle_attribute(activity, picked))
		pool_row.add_child(chip)
	if Array(description.get("attributes", [])).is_empty():
		_add_line(_detail, "Moves no attributes — this one is for the legs.")
	if has_unsimulated:
		_add_line(_detail, "* trains, but no rally reads it yet.")

	## What the week will *actually* be aimed at, rather than how many chips are
	## lit. The model caps a high-focus week and falls back to a random draw when
	## nothing valid is named, so a count of the chips would overstate both ends.
	if int(regimen.focus) == TrainingRegimenModel.Focus.HIGH:
		var named := TrainingFocusModel.selected_attributes(
			regimen, Array(description.get("attributes", [])), 0, 0
		).size()
		if regimen.attributes.is_empty():
			_add_line(_detail, "Nothing named yet, so this week is worked loosely — pick attributes above to aim it.")
		else:
			var over := regimen.attributes.size() - named
			var tail := ""
			if over > 0:
				tail = " %d more will not be trained; a week can be aimed at %d at most." % [
					over, TrainingFocusModel.HIGH_FOCUS_MAX,
				]
			_add_line(_detail, "Aimed at %d. The week's progress is split between them, so fewer moves each further.%s" % [named, tail])

	_add_band_panel(regimen, description)

	## Who is doing it. A squad is the other half of a regimen.
	_add_heading(_detail, "Squad")
	var squad_row := HFlowContainer.new()
	_detail.add_child(squad_row)
	for player in (_game_manager.players if _game_manager != null else []):
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.text = str(player.display_name)
		toggle.button_pressed = int(player.id) in regimen.player_ids
		## A voli already claimed by another session cannot be in two places, and
		## the screen says which rather than silently refusing the click.
		var claimed := _claimed_elsewhere(int(player.id), activity)
		if not claimed.is_empty():
			toggle.disabled = true
			toggle.tooltip_text = "Already training with %s." % claimed
		var member := int(player.id)
		toggle.pressed.connect(func() -> void: _toggle_member(activity, member))
		squad_row.add_child(toggle)


## What this session does to the windows a rally actually reads.
##
## The panel used to answer "what does this session do" with a familiarity
## percentage, which is a number about a number. The planner was legible because
## it drew the consequence; this draws the consequence too. A system-fit band is
## an ideal and a tolerance the simulator reads directly, and the attributes a
## session trains are the same ones those bands are derived from -- so aiming a
## week somewhere moves a window, visibly, and the projection is produced by
## running the real training path on a copy rather than by a second formula that
## would be free to disagree with the first.
func _add_band_panel(regimen: TrainingRegimen, description: Dictionary) -> void:
	if _game_manager == null or _game_manager.players.is_empty():
		return
	_add_heading(_detail, "The windows this session works on")
	var touched := TrainingProjection.axes_touched(
		description, _game_manager.players[0]
	)
	if touched.is_empty():
		## Said rather than drawn as flat bars. A strength circuit moves
		## explosiveness and jump reach, which none of these windows is derived
		## from -- a fact about the session, not a null result.
		_add_line(_detail, "None. This session works on attributes the rally reads \
somewhere other than these four windows.")
		return
	if regimen.player_ids.is_empty():
		for axis in touched:
			_add_line(_detail, "· %s — %s" % [str(axis.label), str(axis.note)])
		_add_line(_detail, "Assign a squad below to see where each voli sits.")
		return
	for axis in touched:
		_add_line(_detail, "%s — %s" % [str(axis.label), str(axis.note)])
		var rows := TrainingProjection.squad_rows(
			axis, _game_manager.players, regimen
		)
		if rows.is_empty():
			continue
		var bands := SystemFitBandsScript.new()
		bands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bands.set_rows(rows, str(axis.unit), int(axis.decimals))
		_detail.add_child(bands)
		var direction := TrainingProjection.direction_sentence(axis)
		if not direction.is_empty():
			_add_line(_detail, direction)
	_add_line(_detail, "The tick is where a voli naturally sits; the bar is how much \
room they have to be wrong. A week moves these far less than the gap between two \
volis does, so the useful question is who to put on the session.")


## What a full-turnout week of this session is worth to the club rather than to
## the individual. Empty when an activity moves neither, so a strength circuit
## does not carry a line saying it builds nothing.
func _in_match_line(description: Dictionary) -> String:
	var familiarity := float(description.get("familiarity", 0.0))
	var cohesion := float(description.get("cohesion", 0.0))
	if is_zero_approx(familiarity) and is_zero_approx(cohesion):
		return ""
	var parts: Array[String] = []
	if not is_zero_approx(familiarity):
		parts.append("system familiarity %+.1f%%" % (familiarity * 100.0))
	if not is_zero_approx(cohesion):
		parts.append("cohesion %+.1f%%" % (cohesion * 100.0))
	return "In match, at full turnout: %s a week." % ", ".join(parts)


## Which other session has this voli, if any.
func _claimed_elsewhere(player_id: int, activity: String) -> String:
	if _career_manager == null or _career_manager.career == null:
		return ""
	for regimen in _career_manager.career.training_regimens:
		if str(regimen.activity) == activity:
			continue
		if player_id in regimen.player_ids:
			return str(regimen.squad_name)
	return ""


func _pool_heading(focus: int) -> String:
	match focus:
		TrainingRegimenModel.Focus.HIGH:
			return "Aim the week at"
		TrainingRegimenModel.Focus.MEDIUM:
			return "Strike off"
	return "This session can move (low focus takes them at random)"


func _toggle_attribute(activity: String, attribute_name: String) -> void:
	var regimen := _regimen_for(activity)
	if attribute_name in regimen.attributes:
		regimen.attributes.erase(attribute_name)
	else:
		regimen.attributes.append(attribute_name)
	_open_phase_panel(_open_phase, activity)
	refresh()


func _toggle_member(activity: String, player_id: int) -> void:
	var regimen := _regimen_for(activity)
	if player_id in regimen.player_ids:
		regimen.player_ids.erase(player_id)
	else:
		regimen.player_ids.append(player_id)
	_open_phase_panel(_open_phase, activity)
	refresh()


func _set_focus(level: int) -> void:
	if _career_manager == null or _open_activity.is_empty():
		return
	var regimen := _regimen_for(_open_activity)
	regimen.focus = level
	_open_phase_panel(_open_phase, _open_activity)
	refresh()


## The regimen this activity runs under, creating it if the club has not set one.
func _regimen_for(activity: String) -> TrainingRegimen:
	## A detached regimen when there is no career to hang it on. The screen is
	## reachable before a career is loaded -- from a debug jump, or the moment
	## after a save is cleared -- and it crashed on the null rather than drawing
	## an empty week.
	if _career_manager == null or _career_manager.career == null:
		var orphan := TrainingRegimen.new()
		orphan.squad_name = activity
		orphan.activity = activity
		orphan.focus = TrainingRegimenModel.Focus.MEDIUM
		return orphan
	var career = _career_manager.career
	for existing in career.training_regimens:
		if str(existing.activity) == activity:
			return existing
	var regimen := TrainingRegimen.new()
	regimen.squad_name = activity
	regimen.activity = activity
	regimen.focus = TrainingRegimenModel.Focus.MEDIUM
	career.training_regimens.append(regimen)
	return regimen


func _focus_blurb(level: int) -> String:
	match level:
		TrainingRegimenModel.Focus.LOW:
			return "Take what the session gives you. Cheapest on the legs."
		TrainingRegimenModel.Focus.HIGH:
			return "Name the attributes. Fewer named moves each of them further."
	return "Strike attributes off the list and work what is left."


func _add_heading(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _add_line(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
