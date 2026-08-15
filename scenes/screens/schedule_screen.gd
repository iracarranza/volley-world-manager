class_name VolleyballScheduleScreen
extends Control

## The club's day, as thirty-six blocks you paint.
##
## The schedule is the one screen where the manager spends a resource that is
## genuinely fixed -- there are thirty-six blocks and there will never be more --
## so it is built as a strip you fill rather than a list you configure. Pick what
## you want to lay down, click the blocks, watch the consequences update beside
## you. Nothing here refuses an edit: a club may sleep four hours and train at
## dawn, and the panel will simply tell them what that costs.
##
## Personal schedules use the same strip. A voli's day is the club's with
## something changed, so the editor is the same editor with a different owner and
## the club's day drawn faintly underneath as the thing being departed from.

const DailyScheduleModel := preload("res://scripts/models/daily_schedule.gd")
const DailyScheduleSystem := preload("res://scripts/systems/daily_schedule_system.gd")
const ScreenShell := preload("res://scenes/components/screen_shell.gd")

## Blocks per row on the strip.
##
## Thirty-six in one row does not fit. Each block is a themed `Button`, and the
## theme's font and padding put its minimum width near 37px rather than the 26
## asked for -- so the row demanded about 1315px, forced the column wider than
## the window, and carried the header's right-aligned Back button off the screen
## with it. The screen had no scroll, so Back was simply unreachable.
##
## Eighteen is also the better read: the day breaks at noon, and two half-days
## stacked is a clearer picture of a schedule than one long ribbon.
const BLOCKS_PER_ROW: int = 18

signal back_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _strip: VBoxContainer = null
var _readout: VBoxContainer = null
var _roster_list: ItemList = null
var _brush: int = DailyScheduleModel.Activity.TRAINING
## -1 is the club's own day; a player id edits that voli's.
var _editing_owner: int = -1


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	_populate_roster()
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(
		self, "Daily Schedule", [back_button] as Array[Button]
	)
	var column := shell.content

	## The brushes. One per assignable activity -- the locked ones are not here,
	## because a manager does not get to schedule somebody's rehab away.
	var brushes := HBoxContainer.new()
	brushes.add_theme_constant_override("separation", 6)
	column.add_child(brushes)
	var brush_label := Label.new()
	brush_label.text = "Lay down"
	brushes.add_child(brush_label)
	for activity in [
		DailyScheduleModel.Activity.SLEEP,
		DailyScheduleModel.Activity.MEAL,
		DailyScheduleModel.Activity.TRAINING,
		DailyScheduleModel.Activity.SOCIAL,
		DailyScheduleModel.Activity.FREE,
	]:
		var button := Button.new()
		button.text = DailyScheduleModel.activity_name(activity)
		var chosen: int = activity
		button.pressed.connect(func() -> void: _brush = chosen)
		brushes.add_child(button)

	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 4)
	column.add_child(_strip)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var who := VBoxContainer.new()
	who.custom_minimum_size = Vector2(240.0, 0.0)
	body.add_child(who)
	var who_label := Label.new()
	who_label.text = "Whose day"
	who.add_child(who_label)
	var club_button := Button.new()
	club_button.text = "The club"
	club_button.pressed.connect(func() -> void:
		_editing_owner = -1
		refresh()
	)
	who.add_child(club_button)
	_roster_list = ItemList.new()
	_roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_list.item_selected.connect(_select_owner)
	who.add_child(_roster_list)

	_readout = VBoxContainer.new()
	_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_readout.add_theme_constant_override("separation", 6)
	body.add_child(_readout)


func _populate_roster() -> void:
	if _roster_list == null or _game_manager == null:
		return
	_roster_list.clear()
	for player in _game_manager.players:
		_roster_list.add_item("%s · %s" % [
			str(player.display_name), str(player.position_role)
		])


func _select_owner(index: int) -> void:
	if _game_manager == null or index < 0 or index >= _game_manager.players.size():
		return
	_editing_owner = int(_game_manager.players[index].id)
	refresh()


## The day being edited, created from the club's if this voli has never had one.
func _current_schedule() -> DailySchedule:
	if _game_manager == null:
		return null
	var team = _game_manager.team
	if _editing_owner < 0:
		return team.daily_schedule
	if not team.personal_schedules.has(_editing_owner):
		var personal := DailySchedule.new()
		personal.owner_id = _editing_owner
		## Starts as a copy of the club's, because a personal schedule is a
		## departure from the club's day and it should begin at zero departure.
		personal.blocks = team.daily_schedule.blocks.duplicate()
		team.personal_schedules[_editing_owner] = personal
	return team.personal_schedules[_editing_owner]


func refresh() -> void:
	if _strip == null or _game_manager == null:
		return
	var schedule := _current_schedule()
	if schedule == null:
		return
	for child in _strip.get_children():
		child.queue_free()
	var row: HBoxContainer = null
	for index in range(schedule.blocks.size()):
		if index % BLOCKS_PER_ROW == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			_strip.add_child(row)
			## The clock the row starts at, so the strip says where in the day it
			## is without needing a tooltip per block.
			var stamp := Label.new()
			stamp.text = DailyScheduleModel.clock_label(index)
			stamp.custom_minimum_size = Vector2(62.0, 0.0)
			stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(stamp)
		var block := Button.new()
		var value := int(schedule.blocks[index])
		block.custom_minimum_size = Vector2(26.0, 46.0)
		block.tooltip_text = "%s · %s" % [
			DailyScheduleModel.clock_label(index),
			DailyScheduleModel.activity_name(value),
		]
		block.text = _glyph(value)
		block.disabled = DailyScheduleModel.is_locked(value)
		var slot := index
		block.pressed.connect(func() -> void: _paint(slot))
		row.add_child(block)
	_refresh_readout(schedule)


func _paint(index: int) -> void:
	var schedule := _current_schedule()
	if schedule == null:
		return
	if DailyScheduleModel.is_locked(int(schedule.blocks[index])):
		return
	schedule.blocks[index] = _brush
	refresh()


func _refresh_readout(schedule: DailySchedule) -> void:
	for child in _readout.get_children():
		child.queue_free()
	if _game_manager == null:
		return
	var report: Dictionary = DailyScheduleSystem.evaluate(schedule)
	_line("%s of sleep · %d meals · %d social" % [
		_duration(int(report.get("sleep_blocks", 0))),
		int(report.get("meal_blocks", 0)),
		int(report.get("social_blocks", 0)),
	])
	_line("Training: %d blocks, worth %.1f" % [
		int(report.get("training_blocks", 0)),
		float(report.get("effective_training_blocks", 0.0)),
	])
	_line("Overnight recovery: %+d%%" % roundi(float(report.get("recovery", 0.0)) * 100.0))
	for warning in Array(report.get("warnings", [])):
		_line("· %s" % str(warning))
	if _editing_owner >= 0:
		var deviation := schedule.deviation_from(_game_manager.team.daily_schedule)
		_line("%d block%s different from the club's day%s" % [
			deviation, "" if deviation == 1 else "s",
			" — this voli is on their own schedule."
				if deviation > DailyScheduleSystem.DEVIATION_TOLERANCE_BLOCKS else ".",
		])
	var roster: Dictionary = DailyScheduleSystem.evaluate_roster(
		_game_manager.team.daily_schedule,
		_game_manager.team.personal_schedules,
		_game_manager.players.size(),
	)
	for warning in Array(roster.get("warnings", [])):
		_line("· %s" % str(warning))


## A letter per activity. The strip is thirty-six buttons wide, so a word does
## not fit and a colour alone would not survive the light theme.
func _glyph(value: int) -> String:
	match value:
		DailyScheduleModel.Activity.SLEEP:
			return "z"
		DailyScheduleModel.Activity.MEAL:
			return "M"
		DailyScheduleModel.Activity.TRAINING:
			return "T"
		DailyScheduleModel.Activity.SOCIAL:
			return "S"
		DailyScheduleModel.Activity.REHAB:
			return "R"
		DailyScheduleModel.Activity.SPONSOR:
			return "$"
		DailyScheduleModel.Activity.TRAVEL:
			return ">"
	return "·"


func _duration(blocks: int) -> String:
	var minutes := blocks * DailyScheduleModel.MINUTES_PER_BLOCK
	return "%dh%02d" % [minutes / 60, minutes % 60]


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.add_child(label)
