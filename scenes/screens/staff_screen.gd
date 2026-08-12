class_name StaffScreen
extends Control

## The people you employ, and what they have told you.
##
## **Draft.** Rendered to be argued with rather than shipped.
##
## ## An org chart is the least interesting true thing
##
## The Club tab listed four roles and the resource each owns, which is accurate
## and inert. What a manager actually has with a chef is a *correspondence*: the
## chef comes to you, about food, in the first person, and the way you know the
## kitchen is going well is that they said so.
##
## So the hub is four **cards** in the page's own language -- name, the room they
## are in, what is true right now, and their rating -- **beside** the selected
## one's reports, in full, on the page.
##
## ## Reading is not clicking
##
## A middle draft put every report behind a panel that took the whole page, on
## the reasoning that a card-that-opens is what this interface means by a way in.
## That applied the accommodation page's shape where it does not belong, and it
## broke the rule the rest of the interface is built on: **a manager should get
## what they need to know in the fewest clicks and the least looking.** Four
## people whose reports are each one click away is four clicks to answer *how is
## the club*, and three of them are spent finding out nothing changed.
##
## Submenus are for **specific changes**. The accommodation page hides twenty-one
## equipment rows because fitting a console is an act you go and perform; it does
## not hide the floor figure, because that is what you came to read. Everything
## here is reading, so nothing is hidden. When staff gain something a manager
## *does* -- hire, reassign, send somebody on a trip -- that is what opens a
## panel.
##
## The reports are in the two-voice shape the inbox already uses. The report names
## the mechanic and its figures; the utterance is what they actually said, and it
## is shorter and vaguer, because a chef does not know they are running at 0.91 of
## a week's paste.
##
## ## The head is reserved
##
## The inbox draws a voli's actual body into a `SubViewport` and rings it. Staff
## have no body: `BodyTypeModels` builds volis, and a second character pipeline
## for four people who never step on court is the most expensive possible way to
## answer *who is this*. The frame here is the inbox's frame at the inbox's size
## with a monogram in it, so the layout is honest about the space a head will
## take without inventing one.
const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const StaffMember := preload("res://scripts/models/staff_member.gd")
const Reports := preload("res://scripts/data/staff_reports.gd")
const Familiarity := preload("res://scripts/data/staff_familiarity.gd")
const FoodBlock := preload("res://scripts/data/food_block.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const CardScript := preload("res://scenes/components/menu_card.gd")

signal back_requested

const PORTRAIT: float = 104.0

var _career_manager: Node = null
var _game_manager: Node = null
var _cards: VBoxContainer = null
var _log: VBoxContainer = null
var _desk_title: Label = null
## Whose reports are showing. Never -1 once anybody is employed: the page opens
## on somebody, because a hub whose right half is blank until you click has spent
## half the screen asking a question it could have answered.
var _selected: int = -1


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(self, "Staff", [back_button] as Array[Button])

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(body)

	## The four down the left, at the width their figures need: narrow enough
	## that the reports get the rest, wide enough that the ratings still line up
	## in a column somebody can read down.
	_cards = VBoxContainer.new()
	_cards.custom_minimum_size = Vector2(430.0, 0.0)
	_cards.add_theme_constant_override("separation", 8)
	body.add_child(_cards)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_desk_title = Label.new()
	_desk_title.add_theme_font_size_override("font_size", 18)
	right.add_child(_desk_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 10)
	scroll.add_child(_log)


func _staff() -> Array:
	if _career_manager != null and _career_manager.career != null:
		return _career_manager.career.staff
	return []


func refresh() -> void:
	if _cards == null:
		return
	for child in _cards.get_children():
		child.queue_free()
	if _selected < 0 and not _staff().is_empty():
		_selected = int(_staff()[0].id)
	for entry in _staff():
		var member := entry as VolleyballStaffMember
		if member == null:
			continue
		var card := CardScript.build(
			str(member.display_name), Reports.desk_name(str(member.role))
		)
		card.set_reading(_headline(member))
		## The one number everybody has, so the hub can be read down rather than
		## across: who is the best person here, and who just arrived.
		card.set_figure(
			str(int(member.rating)),
			"%s · %s" % [
				str(member.home_region), _tenure(int(member.weeks_employed)),
			]
		)
		card.toggle_mode = true
		card.button_pressed = int(member.id) == _selected
		var who := int(member.id)
		card.pressed.connect(func() -> void: _open(who))
		_cards.add_child(card)
	_refresh_log()


## The card's third line: what this person would lead with today.
##
## Their first report's *report* half, because that is already the one thing
## worth saying and writing a second summary beside it is how two descriptions of
## one fact start to disagree.
func _headline(member: Resource) -> String:
	var cards := _cards_for(member)
	if cards.is_empty():
		return "Nothing this week."
	return str(Dictionary(cards[0]).get("report", ""))


func _open(staff_id: int) -> void:
	_selected = staff_id
	refresh()


func _member(staff_id: int) -> Resource:
	for entry in _staff():
		if int(entry.id) == staff_id:
			return entry
	return null


## Everything this person has said, newest first.
##
## Derived on open rather than stored, which is the same trick §16 uses for a
## voli's preferences: there is no correspondence table, because a report is a
## reading of state that already exists and storing it would be a second copy of
## the club that could disagree with the first.
func _refresh_log() -> void:
	if _log == null:
		return
	for child in _log.get_children():
		child.queue_free()
	var member := _member(_selected)
	if member == null:
		return
	_desk_title.text = "%s · %s" % [
		Reports.desk_name(str(member.role)), str(member.display_name),
	]
	var cards := _cards_for(member)
	if cards.is_empty():
		_log.add_child(_label("Nothing this week.", 13))
		return
	for card in cards:
		_log.add_child(_card_panel(Dictionary(card), str(member.display_name)))


## What this person has to say, derived on open rather than stored.
##
## The same trick §16 uses for a voli's preferences: a report is a *reading* of
## state that already exists, and storing it would be a second copy of the club
## that could disagree with the first. The cost, named honestly, is that the log
## is a snapshot rather than a history.
func _cards_for(member: Resource) -> Array:
	match str(member.role):
		StaffMember.ROLE_CHEF:
			return Reports.kitchen(
				member, _service(), _familiar(), str(_team().food_block)
			)
		StaffMember.ROLE_SCOUT:
			return Reports.desk(member, _watched(), _marked())
		StaffMember.ROLE_PHYSIO:
			return Reports.treatment(member, _tired(), _squad())
	return []


## One report, in the inbox's own shape: the mechanic above, the person below.
func _card_panel(card: Dictionary, speaker: String) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	## The report is the decision, so it is first and it is the larger type.
	var report := _label(str(card.get("report", "")), 15)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(report)

	## And the utterance sits at the bottom bound beside their face, read last --
	## the same order the inbox uses, for the same reason: the figures are what
	## you act on and the sentence is who is asking.
	var speech := HBoxContainer.new()
	speech.add_theme_constant_override("separation", 12)
	column.add_child(speech)
	speech.add_child(_monogram(speaker, PORTRAIT))
	var said := _label("“%s”" % str(card.get("utterance", "")), 15)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speech.add_child(said)
	return panel


## The frame a head will go in, with a letter in it until there is one.
func _monogram(who: String, at: float) -> Control:
	var mark := _Monogram.new()
	mark.letter = who.substr(0, 1).to_upper() if not who.is_empty() else "?"
	mark.custom_minimum_size = Vector2(at, at)
	mark.size_flags_vertical = Control.SIZE_SHRINK_END
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark


func _team() -> Resource:
	return _game_manager.team if _game_manager != null else null


func _familiar() -> Dictionary:
	if _career_manager != null and _career_manager.career != null:
		return _career_manager.career.staff_familiarity
	return {}


func _service() -> Dictionary:
	if _career_manager == null or _career_manager.career == null:
		return {}
	return _career_manager._week_service(
		str(_career_manager.career.region),
		int(_career_manager.career.absolute_week)
	)


func _squad() -> int:
	return _game_manager.players.size() if _game_manager != null else 0


func _tired() -> int:
	var count := 0
	if _game_manager == null:
		return 0
	for player in _game_manager.players:
		if float(player.fatigue) >= 0.34:
			count += 1
	return count


func _watched() -> int:
	var count := 0
	if _game_manager == null:
		return 0
	for player in _game_manager.players:
		if int(player.weeks_observed) >= 8:
			count += 1
	return count


func _marked() -> int:
	if _career_manager == null or _career_manager.career == null:
		return 0
	return Dictionary(_career_manager.career.scouting_marks).size()


func _tenure(weeks: int) -> String:
	if weeks <= 0:
		return "just arrived"
	if weeks == 1:
		return "one week here"
	if weeks < 52:
		return "%d weeks here" % weeks
	var years := weeks / 52
	return "a year here" if years == 1 else "%d years here" % years


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A ringed initial, at the size the inbox rings a face.
##
## Drawn rather than a `Panel` with a stylebox, because the style walk replaces
## styleboxes on its way past -- the inbox had to mark its ring exempt for
## exactly this reason, and a widget that draws itself cannot be stripped.
class _Monogram extends Control:
	var letter: String = "?"

	func _draw() -> void:
		var light := UIPalette.control_is_light(self)
		var middle := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(middle, radius, UIPalette.color(&"surface_raised", light))
		draw_arc(
			middle, radius, 0.0, TAU, 48,
			UIPalette.color(&"stroke_strong", light), 1.5, true
		)
		var font := get_theme_default_font()
		if font == null:
			return
		var at := int(radius * 0.9)
		var extent := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, at)
		draw_string(
			font, middle + Vector2(-extent.x * 0.5, extent.y * 0.34),
			letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, at,
			UIPalette.color(&"ink_muted", light)
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()
