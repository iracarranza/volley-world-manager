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
## So the hub is not a staff table. It is four **cards**, in the page's own
## language -- name, the room they are in, and what is true right now -- and each
## one opens into a panel that takes the whole page.
##
## The first draft split it: people down the left, the selected one's reports on
## the right. That is a browser, and a browser is what you build when the list is
## the subject. Here the list is four items you already know, and the subject is
## whichever one you went to see -- so the reading gets the page and the choosing
## gets a card. It also puts staff in the same shape as the accommodation page,
## which matters more than either screen: a card that opens is now what this
## interface *means* by a way in.
##
## Behind each card is a **log**, in the two-voice shape the inbox already uses.
## The report names the mechanic and its figures; the utterance is what they
## actually said, and it is shorter and vaguer, because a chef does not know they
## are running at 0.91 of a week's paste.
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
const PopupScript := preload("res://scenes/components/desk_popup.gd")

signal back_requested

const PORTRAIT: float = 104.0

var _career_manager: Node = null
var _game_manager: Node = null
var _cards: VBoxContainer = null
var _panel: DeskPopup = null
var _log: VBoxContainer = null
## Who the panel is showing, or -1. Kept because a refresh rebuilds the cards on
## every advance and a panel that closed itself would be unusable.
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

	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(_cards)

	## Last child of the screen root, which is a plain `Control` -- later siblings
	## draw over earlier ones, and nothing recomputes the rect of a child that is
	## not under a `Container`.
	_panel = PopupScript.build()
	_panel.fill_page()
	_panel.closed.connect(func() -> void: _selected = -1)
	add_child(_panel)
	_log = _panel.body


func _staff() -> Array:
	if _career_manager != null and _career_manager.career != null:
		return _career_manager.career.staff
	return []


func refresh() -> void:
	if _cards == null:
		return
	for child in _cards.get_children():
		child.queue_free()
	for entry in _staff():
		var member := entry as VolleyballStaffMember
		if member == null:
			continue
		var card := CardScript.build(
			str(member.display_name), Reports.desk_name(str(member.role))
		)
		card.set_reading(_headline(member))
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
	var member := _member(staff_id)
	if member == null:
		return
	_panel.open(
		str(member.display_name),
		"%s · %s · %s" % [
			Reports.desk_name(str(member.role)), str(member.home_region),
			_tenure(int(member.weeks_employed)),
		]
	)
	_refresh_log()


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
	if _selected < 0:
		return
	var member := _member(_selected)
	if member == null:
		return
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
