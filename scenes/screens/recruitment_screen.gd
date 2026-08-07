class_name VolleyballRecruitmentScreen
extends Control

## The scouting list, as a list a scout would actually keep.
##
## The obvious build for this is a table: five headed columns, a row per
## prospect, ruled lines. It is also the wrong one. A spreadsheet says every row
## is the same kind of thing and your job is to sort them, and that is not what
## scouting is -- a scout carries a page with names on it, ticks the ones they
## want, scores through the ones they have seen enough of, and puts a question
## mark next to the rest.
##
## So the information *is* columnar -- name, age, position, rating, salary, in
## that order, aligned so the eye can run down any one of them -- but nothing is
## ruled. Alignment does the work that lines would do. The marks are the point:
## every prospect carries a state the manager set, and the row is drawn to look
## like that state was made with a pen.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")

const MARK_NONE: int = 0
const MARK_SIGN: int = 1
const MARK_WATCH: int = 2
const MARK_PASS: int = 3

signal back_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _list: VBoxContainer = null


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(self, "Scouting", [back_button] as Array[Button])
	var column := shell.content

	var hint := Label.new()
	hint.text = "Click a name to cycle: sign · keep an eye on · seen enough."
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)


func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _career_manager == null:
		return
	var prospects := _prospects()
	if prospects.is_empty():
		var empty := Label.new()
		empty.text = "Nobody scouted yet. Send somebody to watch a game."
		_list.add_child(empty)
		return
	for prospect in prospects:
		_list.add_child(_row_for(prospect))


## Whoever the career is currently looking at. Falls back to the club's own
## roster so the screen has something true to draw before a scouting pipeline
## exists -- the layout is the thing being proven here.
func _prospects() -> Array:
	var career = _career_manager.career
	if career != null and "scouted_players" in career:
		var scouted: Array = career.scouted_players
		if not scouted.is_empty():
			return scouted
	if _game_manager == null:
		return []
	return _game_manager.players


## Real columns, made of aligned labels rather than padded text.
##
## The first cut padded a single string with `%-22s`, which aligns only in a
## monospace font and this interface is not set in one -- so the ages landed at
## eight different x positions and the one claim the design rests on, that
## alignment does the work lines would do, was not true on screen. Fixed widths
## on separate labels is what actually aligns, and it still draws no rules.
##
## The labels sit inside the button with `MOUSE_FILTER_IGNORE`, so the whole row
## stays one click target -- a scout ticks a name, not a cell.
const COLUMN_WIDTHS := {
	"mark": 34.0, "name": 190.0, "age": 44.0,
	"position": 150.0, "rating": 52.0, "salary": 96.0,
}


func _row_for(prospect) -> Control:
	var row := Button.new()
	row.flat = true
	row.custom_minimum_size = Vector2(0.0, 30.0)
	var prospect_id := int(prospect.id)
	var mark := _mark_for(prospect_id)

	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	_column(line, _mark_glyph(mark), "mark", HORIZONTAL_ALIGNMENT_CENTER)
	_column(line, str(prospect.display_name), "name", HORIZONTAL_ALIGNMENT_LEFT)
	_column(line, str(int(prospect.age)), "age", HORIZONTAL_ALIGNMENT_RIGHT)
	_column(line, str(prospect.position_role), "position", HORIZONTAL_ALIGNMENT_LEFT)
	_column(line, str(_rating_of(prospect)), "rating", HORIZONTAL_ALIGNMENT_RIGHT)
	_column(line, _salary_of(prospect), "salary", HORIZONTAL_ALIGNMENT_RIGHT)

	## A struck-through name is the one visual that is not alignment, because
	## "seen enough" is the one state a scout expresses by damaging the page.
	if mark == MARK_PASS:
		row.modulate = Color(1.0, 1.0, 1.0, 0.42)
	elif mark == MARK_SIGN:
		row.modulate = Color(1.0, 0.96, 0.80)
	row.pressed.connect(func() -> void: _cycle(prospect_id))
	return row


func _column(
	parent: Node,
	text: String,
	key: String,
	alignment: HorizontalAlignment,
) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(float(COLUMN_WIDTHS.get(key, 90.0)), 0.0)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


## Marks live on the career, not the screen. A note you have to re-make every
## time you open the page is not a note, and a shortlist that forgets itself
## between sessions is worse than none.
func _mark_for(prospect_id: int) -> int:
	if _career_manager == null or _career_manager.career == null:
		return MARK_NONE
	return int(_career_manager.career.scouting_marks.get(prospect_id, MARK_NONE))


func _cycle(prospect_id: int) -> void:
	if _career_manager == null or _career_manager.career == null:
		return
	_career_manager.career.scouting_marks[prospect_id] = \
		(_mark_for(prospect_id) + 1) % 4
	refresh()


## The mark, as something a pen could have made.
func _mark_glyph(mark: int) -> String:
	match mark:
		MARK_SIGN:
			return "[x]"
		MARK_WATCH:
			return "[?]"
		MARK_PASS:
			return "[-]"
	return "[ ]"


func _rating_of(prospect) -> int:
	## Whatever the club's own summary says they are worth, so the number on this
	## page is the number on their profile page rather than a second opinion.
	var profiles := load("res://scripts/systems/attribute_profile_system.gd")
	var summary: Dictionary = profiles.summary_profile(prospect)
	return roundi(float(summary.get("Overall", 50.0)))


func _salary_of(prospect) -> String:
	if "salary" in prospect:
		return "%d/wk" % int(prospect.salary)
	## No salary model yet. Derived from the rating so the column is populated
	## with something monotone rather than a placeholder that sorts randomly --
	## and stated here so nobody reads it as a real wage bill.
	return "~%d/wk" % (_rating_of(prospect) * 18)
