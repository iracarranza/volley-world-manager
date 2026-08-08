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
const WhiteboardScript := preload("res://scenes/components/whiteboard.gd")
const RedPenCircleScript := preload("res://scenes/components/red_pen_circle.gd")
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
var _whiteboard: UIWhiteboard = null
var _rotation_option: OptionButton = null
var _selected_preset: String = "Combination Play"
var _activity_rail: VBoxContainer = null
var _detail: VBoxContainer = null
var _sidebar: VBoxContainer = null
var _open_phase: String = ""
var _open_activity: String = ""


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	_populate_rail()
	refresh()


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

	shell.content.add_child(_build_fit_strip())

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
	_modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modes.size_flags_stretch_ratio = 2.6
	## Plastic binder dividers rather than the journal's cut index tabs. Torn
	## paper is the journal's own material and it followed the tabs here by
	## default; a clipboard's dividers are the thing you buy in a packet of five.
	_modes.set_meta(&"ui_tabs", &"plastic")
	body.add_child(_modes)

	_modes.add_child(_build_tactics_page())
	_modes.add_child(_build_development_page())

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 8)
	_sidebar.custom_minimum_size = Vector2(300.0, 0.0)
	body.add_child(_sidebar)


## The strip the doc calls for: what a declared tactic is asking of the squad,
## and the one gap worth training next, pointing at the session rather than at a
## tab -- there is no drill tab left to point at. `Rotation` narrows which of the
## six authored plans the strip is reading, per §0.7: a filter on one control, not
## a navigation level of its own.
##
## The ask count and the named gap are placeholders. Decomposing a preset into
## per-voli asks (§0.2) and scoring them against learned comfort (§0.4) are both
## unbuilt; this strip is laid out at the shape the finished one should have.
func _build_fit_strip() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var rotation_label := Label.new()
	rotation_label.text = "Rotation"
	row.add_child(rotation_label)

	_rotation_option = OptionButton.new()
	for rotation_number in range(1, 7):
		_rotation_option.add_item("R%d" % rotation_number)
	_rotation_option.select(0)
	row.add_child(_rotation_option)

	var sep := VSeparator.new()
	row.add_child(sep)

	var summary := Label.new()
	summary.text = "4 asks · 1 unfamiliar"
	row.add_child(summary)

	var arrow_sep := VSeparator.new()
	row.add_child(arrow_sep)

	var gap := Label.new()
	gap.text = "⟨ Ivo 4 · slide coordinate ⟩"
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	var to_session := Label.new()
	to_session.text = "→ tomorrow's session"
	row.add_child(to_session)
	return panel


## Tactics: a preset rail on the left, and the board a coach explains it on.
##
## The board replaces the tactical court that was here. The court draws the same
## information as exact geometry, which is the one register this interface uses
## nowhere else -- everything around it is a hand and an instrument, and a plan
## rendered in 1px lines reads as machine output sitting inside somebody's
## notebook. A phase is not a diagram; it is the thing a young coach scrawls on a
## board, wipes, and scrawls again, which is what `UIWhiteboard` draws.
##
## The phase buttons are the board's own vocabulary rather than the page's:
## picking one squeegees what is there and draws the next layout in behind the
## wipe.
func _build_tactics_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Tactics"
	page.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.text = "Declare how this rotation attacks and defends. \
A blank tactic is every voli's own comfort -- maximum familiarity, no edge."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(caption)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)

	var preset_scroll := ScrollContainer.new()
	preset_scroll.set_meta("ui_style_exempt", true)
	preset_scroll.custom_minimum_size = Vector2(210.0, 0.0)
	preset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(preset_scroll)

	var preset_rail := VBoxContainer.new()
	preset_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_rail.add_theme_constant_override("separation", 4)
	preset_scroll.add_child(preset_rail)

	_add_heading(preset_rail, "Attack")
	var attack_group := ButtonGroup.new()
	for preset_name in ["Feed Opposite", "Combination Play", "Pipe and Middle"]:
		_add_preset_button(preset_rail, preset_name, attack_group)
	_add_heading(preset_rail, "Defense")
	var defense_group := ButtonGroup.new()
	for preset_name in ["Funnel into Line", "Spread Block"]:
		_add_preset_button(preset_rail, preset_name, defense_group)

	var board_column := VBoxContainer.new()
	board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_column.add_theme_constant_override("separation", 6)
	split.add_child(board_column)

	## Which phase is on the board. A row of four, because four is the whole
	## vocabulary -- there is no menu here, and picking one is a wipe rather than
	## a navigation.
	var phase_row := HBoxContainer.new()
	phase_row.add_theme_constant_override("separation", 6)
	board_column.add_child(phase_row)
	var phase_group := ButtonGroup.new()
	for phase_name in WhiteboardScript.PHASES:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = phase_group
		button.text = phase_name
		button.button_pressed = phase_name == "Block"
		var chosen := str(phase_name)
		button.pressed.connect(func() -> void: _whiteboard.set_phase(chosen))
		_circle_on_hover(button)
		phase_row.add_child(button)

	_whiteboard = WhiteboardScript.new()
	_whiteboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_whiteboard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_column.add_child(_whiteboard)

	var declared := Label.new()
	declared.name = "DeclaredLabel"
	declared.text = "Declared: %s  ·  scroll a bar to reprioritise" % _selected_preset
	board_column.add_child(declared)
	return page


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
	var board_column: Node = _whiteboard.get_parent()
	var declared := board_column.get_node("DeclaredLabel") as Label
	if declared != null:
		declared.text = "Declared: %s  ·  scroll a bar to reprioritise" % preset_name


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
