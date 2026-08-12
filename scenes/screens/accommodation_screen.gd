class_name AccommodationScreen
extends Control

## Where the squad lives.
##
## `docs/design/ACCOMMODATIONS_AND_CARE.md` §10–§18. The model has been built for
## a while -- structures, floor, equipment, the weekly recovery share -- and none
## of it was drawn, which meant every one of those decisions was being made for
## the manager by a default they could not see.
##
## ## The building is the page
##
## The first build gave it a third: four columns of equal weight, one of which
## was a twenty-one row list of checkboxes and another of which was the food
## supply. That is a page about *arrangements*, and the arrangement a manager
## actually holds in their head is the rooms.
##
## So the plan takes the room, and everything else is a **card that opens into a
## panel**. Not a dropdown: a dropdown puts what you opened inside the column you
## opened it from, so twenty-one items either scroll in a 330px gutter or shove
## everything under them off the page -- both of which happened.
##
## Each card carries three lines, and the third is the one that earns it the
## space: a title, what it is for, and **what is true right now**. `Equipment` /
## `Fit your volis' rooms with helpful stuff` / `cookbook, in 5 rooms`. The
## common visit is somebody checking rather than changing, and it never has to
## open anything.
##
## ## The table went with the food
##
## Supply lines, pastes and who is eating badly were here and should not have
## been. Housing and food are two systems that happen to share a rest multiplier,
## and putting them on one page made the page a list of everything that is not
## volleyball. Food gets its own.
##
## ## Nothing here is free
##
## Every change is priced, and priced where the change is made. An arrangement
## you alter by ticking a box is one the game has told you costs nothing, and
## none of these do -- fitting nine rooms with a console is nine consoles, and
## moving a squad is a lease and a fortnight of nobody knowing where anything is.
## The prices do not leave the account yet; see `BACKLOG`.
const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const Accommodation := preload("res://scripts/data/accommodation.gd")
const PairFamiliarity := preload("res://scripts/data/pair_familiarity.gd")
const FloorPlanScript := preload("res://scenes/components/floor_plan.gd")
const CardScript := preload("res://scenes/components/menu_card.gd")
const PopupScript := preload("res://scenes/components/desk_popup.gd")

signal back_requested

## §10's floor rule only bites if a manager can push past it, and only stays
## legible if they cannot push a dozen people into one room.
const MIN_OCCUPANTS: int = 1
const MAX_OCCUPANTS: int = 4

var _career_manager: Node = null
var _game_manager: Node = null
var _plan: FloorPlan = null
var _caption: Label = null
var _lease_card: MenuCard = null
var _kit_card: MenuCard = null
var _people_card: MenuCard = null
var _panel: DeskPopup = null
## Which card the panel is showing, or empty. Kept because a refresh happens on
## every click *inside* the panel -- fitting a fan rebuilds the page -- and a
## panel that closed itself the moment you used it would be unusable for exactly
## the task it exists for.
var _showing: String = ""

## The three, in the order they sit on the page.
##
## Title, flavour, and the function that fills the panel. Held as data rather
## than three near-identical branches, because the next card is a row here.
const CARDS := {
	"building": {
		"title": "Building",
		"flavour": "Rent or buy a space for your volis",
	},
	"kit": {
		"title": "Equipment",
		"flavour": "Fit your volis' rooms with helpful stuff",
	},
	"people": {
		"title": "Familiarity",
		"flavour": "See who has got to know who",
	},
}


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(
		self, "Accommodation", [back_button] as Array[Button]
	)
	var column := shell.content

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var stage := VBoxContainer.new()
	stage.add_theme_constant_override("separation", 6)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)

	_plan = FloorPlanScript.new()
	_plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plan.room_focused.connect(_room_focused)
	stage.add_child(_plan)

	## Under the plan, not over it: the picture is the subject and the line is
	## the caption on it.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	stage.add_child(footer)
	_caption = Label.new()
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_caption)
	## Turning is a drag, and the two buttons are for anybody who did not guess
	## that. Not a view toggle: they move the same continuous angle.
	for turn in [-45.0, 45.0]:
		var spin := Button.new()
		spin.text = "↺" if turn < 0.0 else "↻"
		spin.tooltip_text = "Turn the building. Dragging it does the same."
		var degrees := float(turn)
		spin.pressed.connect(func() -> void: _plan.turn_by(degrees))
		footer.add_child(spin)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(330.0, 0.0)
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)

	for key in CARDS:
		var entry: Dictionary = CARDS[key]
		var card := CardScript.build(str(entry["title"]), str(entry["flavour"]))
		var name := str(key)
		card.pressed.connect(func() -> void: _open_panel(name))
		side.add_child(card)
		match name:
			"building":
				_lease_card = card
			"kit":
				_kit_card = card
			_:
				_people_card = card

	## Last child of the screen root, which is a plain `Control` -- later siblings
	## draw over earlier ones, and nothing recomputes the rect of a child that is
	## not under a `Container`.
	_panel = PopupScript.build()
	_panel.closed.connect(func() -> void: _showing = "")
	add_child(_panel)


func _open_panel(key: String) -> void:
	_showing = key
	var entry: Dictionary = CARDS.get(key, {})
	_panel.open(str(entry.get("title", "")), str(entry.get("flavour", "")))
	_fill_panel()


## Repaint whatever the panel is showing, without opening or closing it.
##
## Every control inside the panel edits the club and then calls `refresh`, so
## this runs on each of those clicks and has to leave the panel exactly where it
## was.
func _fill_panel() -> void:
	if _panel == null or _showing.is_empty():
		return
	for child in _panel.body.get_children():
		child.queue_free()
	match _showing:
		"building":
			_fill_building()
		"kit":
			_fill_kit()
		"people":
			_fill_people()


func _card_for(key: String) -> MenuCard:
	match key:
		"building":
			return _lease_card
		"kit":
			return _kit_card
	return _people_card


func _team() -> Resource:
	return _game_manager.team if _game_manager != null else null


func _squad() -> int:
	return _game_manager.players.size() if _game_manager != null else 0


func _club_region() -> String:
	if _career_manager != null and _career_manager.career != null:
		return str(_career_manager.career.region)
	return "Landavol"


func _rooms() -> int:
	var team := _team()
	return Accommodation.rooms_occupied(
		str(team.housing_structure), _squad(), int(team.housing_occupants_per_room)
	)


func refresh() -> void:
	if _plan == null or _team() == null:
		return
	var team := _team()
	_plan.set_room(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment, _rooms()
	)
	_refresh_caption()
	_refresh_lease()
	_refresh_kit()
	_refresh_people()
	_fill_panel()


## The one line under the building, and it is the floor rule.
##
## Not a sentence about what crowding does. The number, the wall it is measured
## against, and how far past it -- a manager who wants to know what that costs
## has three rooms of evidence directly above the caption.
func _refresh_caption() -> void:
	var team := _team()
	var crowding := Accommodation.crowding(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment,
	)
	var parts: Array[String] = [
		"%s · %d of %d rooms · %d to a room" % [
			str(team.housing_structure), _rooms(), _plan.room_count(),
			int(team.housing_occupants_per_room),
		],
		"floor %.0f of %.0f" % [_plan.used(), _plan.effective_capacity()],
	]
	if crowding > 0.0:
		parts.append("over by %.1f" % crowding)
	if int(team.housing_settling_weeks) > 0:
		parts.append("still settling, %d week%s" % [
			int(team.housing_settling_weeks),
			"" if int(team.housing_settling_weeks) == 1 else "s",
		])
	_caption.text = "  ·  ".join(parts)


## ## Building
##
## All seven, with what each costs to move into *here*. A picker showing only
## what is available in this region would be §15's cage rebuilt in the
## interface: the whole point of renting is that a Landavol club can lease a Row
## and will pay for it, and that is only a decision if it is on the page.
func _refresh_lease() -> void:
	var team := _team()
	var region := _club_region()
	var current := str(team.housing_structure)
	var home := str(Dictionary(Accommodation.STRUCTURES.get(current, {})).get("region", ""))
	_lease_card.set_reading("%s · %s" % [
		current,
		"built everywhere" if home.is_empty()
			else ("local practice" if home == region else "%s practice" % home),
	])


func _fill_building() -> void:
	var team := _team()
	var region := _club_region()
	var current := str(team.housing_structure)
	for structure_name in Accommodation.STRUCTURES:
		var entry: Dictionary = Accommodation.STRUCTURES[structure_name]
		var name := str(structure_name)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_panel.body.add_child(row)
		var titles := VBoxContainer.new()
		titles.add_theme_constant_override("separation", 0)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(titles)
		var label := Label.new()
		label.text = name
		titles.add_child(label)
		## The sentence already authored in `STRUCTURES.why`, on the page rather
		## than in a tooltip -- there is room here, and seven of them stacked is
		## the comparison this panel exists to make.
		var why := Label.new()
		why.text = "%s · %d rooms, %.0f floor each · %s" % [
			str(entry.get("why", "")), int(entry.get("rooms", 0)),
			float(entry.get("floor", 0.0)),
			"rent %.1f" % Accommodation.rent_for(name, region),
		]
		why.add_theme_font_size_override("font_size", 11)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titles.add_child(why)
		var action := Button.new()
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if name == current:
			action.text = "Here"
			action.disabled = true
		else:
			action.text = _money(Accommodation.move_cost(name, region))
			action.tooltip_text = (
				"Move the squad into a %s.\n\nThe lease, and %d weeks of nobody"
				+ " knowing where anything is."
			) % [name, Accommodation.SETTLING_WEEKS]
			action.pressed.connect(func() -> void: _lease_signed(name))
		row.add_child(action)

	## §15: you can furnish what you rent and you can only build what you own,
	## and nothing owns anything yet. Named rather than left out, because the
	## card's own flavour says *rent or buy* and a panel with no buying in it
	## would be the page contradicting its own label.
	var owning := Label.new()
	owning.text = "Buying one of your own is not built yet."
	owning.add_theme_font_size_override("font_size", 11)
	_panel.body.add_child(owning)


## ## Equipment
##
## A list with prices, and the description in the tooltip. The first build put
## `console  morale · tactical` on the row, which is two words standing in for a
## trade and reads as neither -- and it had no price at all, so the whole column
## was a set of switches the game had implied were free.
func _refresh_kit() -> void:
	var team := _team()
	var fitted: Array = []
	for item in team.housing_large_equipment:
		fitted.append(str(item))
	for item in team.housing_small_equipment:
		fitted.append(str(item))
	_kit_card.set_reading(
		"Nothing fitted" if fitted.is_empty()
			else "%s, in %d rooms" % [_readable(fitted), _rooms()]
	)


func _fill_kit() -> void:
	var team := _team()
	_kit_rows(
		Accommodation.LARGE_EQUIPMENT, team.housing_large_equipment,
		Accommodation.FLOOR_LARGE_ITEM
	)
	_kit_rows(
		Accommodation.SMALL_EQUIPMENT, team.housing_small_equipment,
		Accommodation.FLOOR_SMALL_ITEM
	)


func _kit_rows(catalogue: Dictionary, installed: Array, floor_cost: float) -> void:
	for item in catalogue:
		var name := str(item)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_panel.body.add_child(row)
		var label := Label.new()
		label.text = "%s · %.0f floor" % [name.replace("_", " "), floor_cost]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = Accommodation.detail_for(name)
		row.add_child(label)
		var action := Button.new()
		var here := installed.has(name)
		action.text = "Take out" if here \
			else _money(Accommodation.fitting_cost(name, _rooms()))
		action.tooltip_text = "Take it out of every room." if here \
			else "Fit one in each of your %d occupied rooms." % _rooms()
		action.pressed.connect(func() -> void: _fit(installed, name, not here))
		row.add_child(action)


## ## Familiarity
##
## §7's dorms row: **who shares a room is who knows each other.** The card's
## reading is the arrangement, because that is the decision; the panel is what it
## has bought, which is the pairs.
func _refresh_people() -> void:
	var team := _team()
	_people_card.set_reading(
		"Average social level: %s" % _social_level(int(team.housing_occupants_per_room))
	)


func _fill_people() -> void:
	var team := _team()
	var sharing := HBoxContainer.new()
	sharing.add_theme_constant_override("separation", 8)
	_panel.body.add_child(sharing)
	var label := Label.new()
	label.text = "To a room"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sharing.add_child(label)
	sharing.add_child(_step_button(-1))
	var count := Label.new()
	count.text = str(int(team.housing_occupants_per_room))
	count.custom_minimum_size = Vector2(18.0, 0.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sharing.add_child(count)
	sharing.add_child(_step_button(1))

	if _game_manager == null:
		return
	var pairs: Array = []
	var players: Array = _game_manager.players
	for first in range(players.size()):
		for second in range(first + 1, players.size()):
			pairs.append({
				"who": "%s and %s" % [
					str(players[first].display_name), str(players[second].display_name),
				],
				"level": PairFamiliarity.of(
					team.pair_familiarity,
					int(players[first].id), int(players[second].id)
				),
			})
	pairs.sort_custom(func(a, b) -> bool: return float(a["level"]) > float(b["level"]))
	## The top of the list only. Every pair in a fourteen-voli squad is
	## ninety-one rows, which is a table nobody reads twice -- and the reading a
	## manager wants from this is *who already knows each other*, which is the
	## top of it.
	for entry in pairs.slice(0, 10):
		var line := Label.new()
		line.text = "%s — %d" % [str(entry["who"]), roundi(float(entry["level"]))]
		line.add_theme_font_size_override("font_size", 12)
		_panel.body.add_child(line)


## The word for an occupancy, which is what the closed card says.
##
## Words rather than a number because the closed line is a reading: `2` is the
## setting and `sharing` is what it means for somebody living there.
func _social_level(per_room: int) -> String:
	match per_room:
		1:
			return "alone"
		2:
			return "sharing"
		3:
			return "on top of each other"
	return "no room to stand"


func _step_button(step: int) -> Button:
	var team := _team()
	var button := Button.new()
	button.text = "−" if step < 0 else "+"
	var target := int(team.housing_occupants_per_room) + step
	button.disabled = target < MIN_OCCUPANTS or target > MAX_OCCUPANTS
	button.tooltip_text = "%s to a room. Fewer rooms to fit out, and %s." % [
		target,
		"less rest and pairs that build faster" if step > 0
			else "more rest and nothing built",
	]
	button.pressed.connect(func() -> void: _change_occupants(step))
	return button


func _room_focused(_index: int) -> void:
	_refresh_caption()


func _lease_signed(structure: String) -> void:
	var team := _team()
	team.housing_structure = structure
	team.housing_settling_weeks = Accommodation.SETTLING_WEEKS
	## The career carries the same fact -- §15 makes the lease what a save is
	## generated from -- and two names for one thing is how they drift.
	if _career_manager != null and _career_manager.career != null:
		_career_manager.career.housing_structure = structure
	refresh()


func _change_occupants(delta: int) -> void:
	var team := _team()
	team.housing_occupants_per_room = clampi(
		int(team.housing_occupants_per_room) + delta, MIN_OCCUPANTS, MAX_OCCUPANTS
	)
	refresh()


func _fit(installed: Array, item: String, install: bool) -> void:
	if install and not installed.has(item):
		installed.append(item)
	elif not install:
		installed.erase(item)
	refresh()


## What a price looks like. Grouped, because five figures unbroken is a number
## nobody reads at a glance and every one of these is being compared to another.
func _money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return out


## A list of things, as somebody would say it.
func _readable(items: Array) -> String:
	var words: Array[String] = []
	for item in items:
		words.append(str(item).replace("_", " "))
	if words.size() == 1:
		return words[0]
	if words.size() == 2:
		return "%s and %s" % [words[0], words[1]]
	return "%s and %d more" % [words[0], words.size() - 1]
