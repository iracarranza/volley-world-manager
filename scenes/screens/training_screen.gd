class_name VolleyballTrainingScreen
extends Control

## Training, out of the roster menu and into its own place.
##
## It used to be a dropdown on the journal's Team tab: pick one activity
## for the whole club, press Apply. That is the entire decision the old model
## could express, so the screen was honest about it. With squads, focus and a day
## that has to pay for the sessions, there is enough to decide that it wants a
## room of its own.
##
## The room has two halves, because training does. **Attribute** work runs from
## the weight room to the meeting room -- conditioning, then the technical
## sessions that drill one phase, then film and talk, which cost nothing
## physically and move reads and decisions. **In-match** work is the rally
## itself: the same phases, but arranged as the loop a point actually travels,
## because what a squad drills against the ball is a different question from what
## numbers it is trying to raise.
##
## Both halves share the panel below them -- pick a session either way and you
## are setting the same regimen -- and both share the week's state on the right,
## which is what a manager needs *before* choosing rather than after.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const TrainingFlowchartScript := preload(
	"res://scenes/components/training_flowchart.gd"
)
const TrainingSystem := preload("res://scripts/systems/training_system.gd")
const TrainingFocusModel := preload("res://scripts/systems/training_focus_model.gd")
const DailyScheduleSystem := preload("res://scripts/systems/daily_schedule_system.gd")
const TrainingRegimenModel := preload("res://scripts/models/training_regimen.gd")

signal back_requested
signal schedule_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _flowchart: TrainingFlowchart = null
var _modes: TabContainer = null
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
		self, "Training", [schedule_button, back_button] as Array[Button]
	)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(body)

	## The two halves. Visible tabs, unlike the dashboard's outer sections, which
	## hide theirs because a separate nav strip names them -- here the tabs are
	## the only thing saying there are two ways to train.
	_modes = TabContainer.new()
	_modes.tabs_visible = true
	_modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modes.size_flags_stretch_ratio = 2.6
	body.add_child(_modes)

	_modes.add_child(_build_attribute_mode())
	_modes.add_child(_build_match_mode())

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 8)
	_sidebar.custom_minimum_size = Vector2(300.0, 0.0)
	body.add_child(_sidebar)


## The attribute half: a rail of sessions ordered body-first, and the panel that
## sets whichever one is picked.
func _build_attribute_mode() -> Control:
	var page := VBoxContainer.new()
	page.name = "Attributes"
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


## The in-match half: the rally as a loop you click.
func _build_match_mode() -> Control:
	var page := VBoxContainer.new()
	page.name = "In Match"
	page.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.text = "The rally, in the order a point travels it. \
Pick the moment you want drilled against a live ball."
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(caption)

	_flowchart = TrainingFlowchartScript.new()
	_flowchart.phase_selected.connect(_open_phase_panel)
	## The chart takes the larger share and the panel the rest. Both stretch, so
	## the ring stays round on a tall window instead of the chart sitting at its
	## minimum with dead page under it.
	_flowchart.size_flags_stretch_ratio = 1.7
	page.add_child(_flowchart)
	return page


## One detail panel, shared by both halves.
##
## Both modes set the same regimen, so two panels would be two views of one piece
## of state and would need keeping in step. This one is reparented as the mode
## changes instead, which cannot drift.
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
