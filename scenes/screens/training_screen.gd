class_name VolleyballTrainingScreen
extends Control

## Training, out of the roster menu and into its own place.
##
## It used to be a dropdown on the career dashboard's Team tab: pick one activity
## for the whole club, press Apply. That is the entire decision the old model
## could express, so the screen was honest about it. With squads, focus and a day
## that has to pay for the sessions, there is enough to decide that it wants a
## room of its own.
##
## The front page is the flowchart -- the rally as a loop you can click -- with
## the week's state beside it: what last week actually did, what the day affords,
## and how tired the squad is. Clicking a phase opens its own panel, laid out the
## way the tactical planner is: the thing you are editing on the left, the roster
## you are assigning on the right.

const TrainingFlowchartScript := preload(
	"res://scenes/components/training_flowchart.gd"
)
const TrainingSystem := preload("res://scripts/systems/training_system.gd")
const TrainingFocusModel := preload("res://scripts/systems/training_focus_model.gd")
const DailyScheduleSystem := preload("res://scripts/systems/daily_schedule_system.gd")
const DailyScheduleModel := preload("res://scripts/models/daily_schedule.gd")
const TrainingRegimenModel := preload("res://scripts/models/training_regimen.gd")

signal back_requested
signal schedule_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _flowchart: TrainingFlowchart = null
var _detail: VBoxContainer = null
var _sidebar: VBoxContainer = null
var _open_phase: String = ""
var _open_activity: String = ""


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var title := Label.new()
	title.text = "Training"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var schedule_button := Button.new()
	schedule_button.text = "Daily Schedule"
	schedule_button.pressed.connect(func() -> void: schedule_requested.emit())
	header.add_child(schedule_button)
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.2
	body.add_child(left)

	_flowchart = TrainingFlowchartScript.new()
	_flowchart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flowchart.phase_selected.connect(_open_phase_panel)
	left.add_child(_flowchart)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	left.add_child(_detail)

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 10)
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.custom_minimum_size = Vector2(320.0, 0.0)
	body.add_child(_sidebar)


## The week's state, beside the chart: what the day affords, what last week did,
## and how tired everybody is. All three are things a manager needs before
## choosing this week's sessions rather than after.
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


## One phase's own panel. Laid out the way the tactical planner is: what you are
## editing, then who you are assigning to it.
func _open_phase_panel(phase_id: String, activity: String) -> void:
	_open_phase = phase_id
	_open_activity = activity
	for child in _detail.get_children():
		child.queue_free()
	var description := TrainingSystem.description(activity)

	_add_heading(_detail, "%s · %s" % [phase_id.capitalize(), activity])
	_add_line(_detail, str(description.get("description", "")))
	_add_line(_detail, "Costs %d training block%s of the day." % [
		int(description.get("blocks", 2)),
		"" if int(description.get("blocks", 2)) == 1 else "s",
	])

	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	_detail.add_child(focus_row)
	var focus_label := Label.new()
	focus_label.text = "Focus"
	focus_row.add_child(focus_label)
	for level: int in [
		TrainingRegimenModel.Focus.LOW,
		TrainingRegimenModel.Focus.MEDIUM,
		TrainingRegimenModel.Focus.HIGH,
	]:
		var button := Button.new()
		button.toggle_mode = true
		button.text = TrainingRegimenModel.focus_name(level)
		button.tooltip_text = _focus_blurb(level)
		var chosen: int = level
		button.pressed.connect(func() -> void: _set_focus(chosen))
		focus_row.add_child(button)

	## What this session can move, and -- at high focus -- which of it the manager
	## is naming. The pool is the activity's own, so a manager choosing is choosing
	## from what the session can actually train rather than from every attribute in
	## the game.
	##
	## At LOW the list is shown greyed, because a low-focus squad does not get to
	## choose and the screen should say so rather than offering buttons that do
	## nothing. At MEDIUM a picked attribute is *struck off*; at HIGH it is *aimed
	## at*. Same control, opposite meaning, so the label says which.
	var regimen := _regimen_for(activity)
	_add_heading(_detail, _pool_heading(int(regimen.focus)))
	var pool_row := HFlowContainer.new()
	_detail.add_child(pool_row)
	for attribute_name in Array(description.get("attributes", [])):
		var chip := Button.new()
		chip.toggle_mode = true
		chip.text = str(attribute_name).capitalize()
		chip.button_pressed = str(attribute_name) in regimen.attributes
		chip.disabled = int(regimen.focus) == TrainingRegimenModel.Focus.LOW
		## Say when an attribute is not yet read by a rally. A manager aiming a
		## high-focus week at one of these would watch the number climb and see
		## nothing change on court, and a screen that does not say so is selling
		## a decision that is not one.
		if not TrainingSystem.is_simulated(str(attribute_name)):
			chip.text += " *"
			chip.tooltip_text = "Not yet read by a rally — trains, but does not show up on court."
		var picked := str(attribute_name)
		chip.pressed.connect(func() -> void: _toggle_attribute(activity, picked))
		pool_row.add_child(chip)
	var has_unsimulated := false
	for attribute_name in Array(description.get("attributes", [])):
		if not TrainingSystem.is_simulated(str(attribute_name)):
			has_unsimulated = true
	if has_unsimulated:
		_add_line(_detail, "* trains, but no rally reads it yet.")
	if int(regimen.focus) == TrainingRegimenModel.Focus.HIGH:
		var named := regimen.attributes.size()
		_add_line(_detail, "Aimed at %d. The week's progress is split between them, so fewer moves each further." % named)

	## Who is doing it. A squad is the other half of a regimen and the screen had
	## no way to set it, so every regimen was an activity nobody was assigned to.
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


