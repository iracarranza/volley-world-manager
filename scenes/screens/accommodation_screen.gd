class_name AccommodationScreen
extends Control

## Where the squad lives, on one page.
##
## `docs/design/ACCOMMODATIONS_AND_CARE.md` §10–§17. The model has been built for
## a while -- structures, floor, equipment, the table, the weekly recovery share
## -- and none of it was drawn, which meant every one of those decisions was
## being made for the manager by a default they could not see.
##
## ## Three arrangements and a consequence, in that order
##
## The page is not a shop and it is deliberately not four tabs. §6 proposed rows
## and §7 threw three of them out for moving the same quantity; what survived is
## three things that genuinely trade against each other and **one column that
## says who they land on**:
##
## | column | the decision |
## |---|---|
## | the lease | which building, and what it costs to keep an unusual one here |
## | the room | who is in it and what else is, against a floor that holds both |
## | the table | which larders you reach, at what weekly cost and what reliability |
## | the week | and what each of those does to one particular voli's recovery |
##
## The fourth is the reason for the other three. A room is not better or worse:
## it is right for this squad or wrong for it, and the only way to show that is
## to put the squad next to it. A page that stopped at the first three columns
## would be a page of purchases.
##
## ## Nothing here explains itself
##
## Every figure is read from the model that will use it -- `Accommodation`,
## `FoodSupply`, `RegionLarder` -- rather than restated, so the page cannot come
## to a different conclusion than the week does. Where a structure has a
## sentence, it is the sentence already authored in `STRUCTURES.why`, and it is
## in a tooltip rather than on the page, because seven of them stacked is an
## essay about buildings.
const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const Accommodation := preload("res://scripts/data/accommodation.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")
const Larder := preload("res://scripts/data/region_larder.gd")
const ClubEvents := preload("res://scripts/data/club_events.gd")
const FloorPlanScript := preload("res://scenes/components/floor_plan.gd")

signal back_requested

## The widest a room gets. §10's floor rule only bites if a manager can push
## past it, and two is where every structure in the game is comfortable -- so
## the range has to reach somewhere uncomfortable on both sides.
const MIN_OCCUPANTS: int = 1
const MAX_OCCUPANTS: int = 4

var _career_manager: Node = null
var _game_manager: Node = null
var _lease: HFlowContainer = null
var _lease_note: Label = null
var _plan: FloorPlan = null
var _room: VBoxContainer = null
var _table: VBoxContainer = null
var _week: VBoxContainer = null
var _footer: Label = null


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

	## The lease across the top, because it is the choice the other two sit
	## inside: the structure sets the floor the room is spent against and the
	## region sets what the table starts with.
	_lease = HFlowContainer.new()
	_lease.add_theme_constant_override("h_separation", 6)
	_lease.add_theme_constant_override("v_separation", 4)
	column.add_child(_lease)
	_lease_note = Label.new()
	_lease_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_lease_note)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	_room = _panel(body, "The room", 330.0)
	_plan = FloorPlanScript.new()
	_room.add_child(_plan)
	_table = _panel(body, "The table", 260.0)
	_week = _panel(body, "The week", 300.0)

	_footer = Label.new()
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_footer)


## One column of the body: a heading, then a scrolling box under it.
##
## Scrolling rather than clipping because the equipment list is twenty-one items
## and the squad is up to eighteen volis -- a column that silently cut either
## would be hiding exactly the thing the page is for.
func _panel(parent: HBoxContainer, heading: String, width: float) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(width, 0.0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 6)
	parent.add_child(holder)
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 17)
	holder.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	scroll.add_child(inner)
	return inner


func _team() -> Resource:
	return _game_manager.team if _game_manager != null else null


func _club_region() -> String:
	if _career_manager != null and _career_manager.career != null:
		return str(_career_manager.career.region)
	return "Landavol"


func _week_number() -> int:
	if _career_manager != null and _career_manager.career != null:
		return int(_career_manager.career.absolute_week)
	return 1


func refresh() -> void:
	if _lease == null or _team() == null:
		return
	_refresh_lease()
	_refresh_room()
	_refresh_table()
	_refresh_week()


## ## The lease
##
## All seven at once, with what each costs here. A picker that showed only what
## is available in this region would be §15's cage rebuilt in the interface --
## the whole point of renting is that a Landavol club *can* lease a Row and will
## pay for the privilege, and that is only a decision if the manager can see it.
func _refresh_lease() -> void:
	for child in _lease.get_children():
		child.queue_free()
	var team := _team()
	var region := _club_region()
	var current := str(team.housing_structure)
	for structure_name in Accommodation.STRUCTURES:
		var entry: Dictionary = Accommodation.STRUCTURES[structure_name]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = str(structure_name) == current
		button.text = "%s  %.1f" % [
			str(structure_name), Accommodation.rent_for(str(structure_name), region),
		]
		button.tooltip_text = str(entry.get("why", ""))
		var chosen := str(structure_name)
		button.pressed.connect(func() -> void: _lease_signed(chosen))
		_lease.add_child(button)
	var home := str(Dictionary(Accommodation.STRUCTURES.get(current, {})).get("region", ""))
	var lines: Array[String] = []
	if home.is_empty():
		lines.append("%s · %s · built everywhere" % [current, region])
	elif home == region:
		lines.append("%s · %s · local practice" % [current, region])
	else:
		lines.append("%s · %s · %s practice, leased here at ×%.2f" % [
			current, region, home, Accommodation.FOREIGN_RENT_MULTIPLIER,
		])
	_lease_note.text = "  ".join(lines)


## ## The room
##
## The plan first and the lists under it, because the plan is the argument: two
## volis and a rack of weights is seven floor in a Bunkhouse's five, and no
## arrangement of checkboxes says that.
func _refresh_room() -> void:
	var team := _team()
	for child in _room.get_children():
		if child != _plan:
			child.queue_free()
	_plan.set_room(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment,
	)

	var crowding := Accommodation.crowding(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment,
	)
	## Against the wall the plan draws, which is the room's own unless a privacy
	## screen has partitioned it. Two different walls in the picture and the
	## caption would be the page contradicting itself over the one rule it exists
	## to show.
	_line(_room, "Floor %.0f of %.0f%s" % [
		_plan.used(), _plan.effective_capacity(),
		"" if crowding <= 0.0 else "  ·  over by %.1f" % crowding,
	])
	## Named where it is felt rather than where it is spent. §10: crowding is a
	## play, not a failure -- you crowd a room on purpose when you want two volis
	## to know each other by the qualifier -- so it is stated as the trade it is.
	if crowding > 0.0:
		_line(_room, "Rest is down; the pairs in that room build faster.")

	var occupancy := HBoxContainer.new()
	occupancy.add_theme_constant_override("separation", 6)
	_room.add_child(occupancy)
	var occupancy_label := Label.new()
	occupancy_label.text = "Sharing"
	occupancy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occupancy.add_child(occupancy_label)
	## Minus, the figure, plus -- in that order, because the number is what the
	## two buttons act on and reading "− + 3" puts the answer after the
	## controls rather than between them.
	occupancy.add_child(_step_button(-1))
	var count := Label.new()
	count.text = str(int(team.housing_occupants_per_room))
	count.custom_minimum_size = Vector2(18.0, 0.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	occupancy.add_child(count)
	occupancy.add_child(_step_button(1))

	_heading(_room, "Small")
	_equipment(_room, Accommodation.SMALL_EQUIPMENT, team.housing_small_equipment, 1.0)
	_heading(_room, "Large")
	_equipment(_room, Accommodation.LARGE_EQUIPMENT, team.housing_large_equipment, 3.0)


## Every item, with what it answers and what it costs, as a check.
##
## §11: each piece answers a **condition, not a role**, so the tag beside it is
## the condition -- which is also the word the event that reports it will use.
func _equipment(
	into: VBoxContainer, catalogue: Dictionary, installed: Array, floor_cost: float
) -> void:
	for item in catalogue:
		var entry: Dictionary = catalogue[item]
		var check := CheckBox.new()
		check.button_pressed = installed.has(str(item))
		var answers := str(entry.get("answers", ""))
		var cost := str(entry.get("cost", ""))
		var tail := ""
		if not answers.is_empty():
			tail = "  %s" % answers.replace("_", " ")
		if not cost.is_empty():
			tail += "  ·  %s" % cost.replace("_", " ")
		check.text = "%s%s" % [str(item).replace("_", " "), tail]
		check.tooltip_text = "%.0f floor" % floor_cost
		var chosen := str(item)
		var target: Array = installed
		check.toggled.connect(func(on: bool) -> void: _install(target, chosen, on))
		into.add_child(check)


## ## The table
##
## §13's flow: the club's own larder is free and always there, and every other
## region is a line you are running on purpose at a weekly cost that a bad
## season two regions away can cut.
func _refresh_table() -> void:
	var team := _team()
	for child in _table.get_children():
		child.queue_free()
	var region := _club_region()
	var week := _week_number()
	var table: Dictionary = FoodSupply.table(region, team.supply_lines, week)
	_line(_table, "%s · %s" % [region, Larder.season_for_week(week)])

	_heading(_table, "Lines")
	## §13's two importing regions have no larder at all, and a page telling an
	## A'ace club that its food *grows here* would be stating the one thing that
	## is specifically not true of them -- their whole character is that they buy
	## the best of everywhere.
	if Larder.has_larder(region):
		_line(_table, "%s — free, it grows here" % region)
	else:
		_line(_table, "%s grows nothing. Everything on the table is a line." % region)
	for source in Larder.LARDERS:
		if str(source) == region:
			continue
		var check := CheckBox.new()
		check.button_pressed = team.supply_lines.has(str(source))
		check.text = "%s  %.1f/wk  ·  %d%%" % [
			str(source), FoodSupply.line_cost(region, str(source)),
			roundi(FoodSupply.line_reliability(region, str(source)) * 100.0),
		]
		var chosen := str(source)
		check.toggled.connect(func(on: bool) -> void: _run_line(chosen, on))
		_table.add_child(check)

	_heading(_table, "On the table")
	var staples: Dictionary = table["staples"]
	for item in staples:
		_line(_table, "%s — %s" % [str(item), str(staples[item])])
	var pastes: Array = Dictionary(table["pastes"]).keys()
	_line(_table, "Pastes: %s" % (
		"nothing to rotate" if pastes.is_empty() else ", ".join(pastes)
	))
	## The one paste the chef is actually serving, which is what every voli's
	## palate is moving against this week. Read the same way `CareerManager`
	## reads it, so the page cannot name a different one.
	if not pastes.is_empty():
		_line(_table, "This week: %s" % str(pastes[week % pastes.size()]))
	for lean in Array(table.get("lean", [])):
		_line(_table, "%s is lean this season." % str(lean))


## ## The week
##
## One row per voli, and the row is the whole argument for the page: the same
## room and the same table produce a different number for each of them, because
## the terms are conditions rather than qualities.
func _refresh_week() -> void:
	var team := _team()
	for child in _week.get_children():
		child.queue_free()
	if _game_manager == null:
		return
	var region := _club_region()
	var week := _week_number()
	var table: Dictionary = FoodSupply.table(region, team.supply_lines, week)
	var crowding := Accommodation.crowding(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment,
	)
	var clock: Dictionary = {}
	if _career_manager != null and _career_manager.career != null:
		clock = _career_manager.career.palate_clock

	var total := 0.0
	var counted := 0
	for player in _game_manager.players:
		var homesick := Accommodation.homesick(str(player.home_region), region)
		var discomfort := FoodSupply.discomfort(player.palate_regions, table)
		var palate := FoodSupply.palate_of(clock, int(player.id))
		var share := Accommodation.weekly_recovery_share(
			crowding, homesick, discomfort, palate, team.housing_small_equipment
		)
		total += share
		counted += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_week.add_child(row)
		var who := Label.new()
		who.text = str(player.display_name)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		## The tags are why the number is what it is, and they are only here when
		## they are true -- a row of "not homesick, not hungry" on twelve volis is
		## a column of noise around the two who are.
		##
		## **At the club's own thresholds, not at zero.** The first version tagged
		## any discomfort above 0.0, and a shot of a crowded Bunkhouse running one
		## foreign supply line came out with every voli reading *eating among
		## strangers* at 62% — when the food term was 0.09 and the missing 38% was
		## almost entirely the third bed. A tag with no threshold blamed the one
		## thing that was barely wrong and stayed silent about the thing that was.
		##
		## So the numbers are `ClubEvents`', which is where the same conditions
		## become a card somebody knocks on the door about. The page mentioning
		## something the inbox would not is the two of them disagreeing about what
		## is worth a manager's attention.
		var tags: Array[String] = []
		if homesick:
			tags.append("far from home")
		if discomfort >= ClubEvents.DISCOMFORT_MENTIONED:
			tags.append("eating among strangers")
		if palate >= ClubEvents.PALATE_MENTIONED:
			tags.append("same paste")
		## And crowding, which is the term the first shot was missing entirely. It
		## is squad-wide today, so it is the same tag on every row -- which is
		## honest, and is exactly the shape the per-room backlog entry would break.
		if crowding > 0.0:
			tags.append("sharing")
		who.tooltip_text = "%s · %s" % [
			str(player.home_region),
			"settled" if tags.is_empty() else ", ".join(tags),
		]
		row.add_child(who)
		if not tags.is_empty():
			var mark := Label.new()
			mark.text = ", ".join(tags)
			mark.add_theme_font_size_override("font_size", 11)
			row.add_child(mark)
		var figure := Label.new()
		figure.text = "%d%%" % roundi(share * 100.0)
		row.add_child(figure)

	var weekly_cost := float(table.get("weekly_cost", 0.0)) \
		+ Accommodation.rent_for(str(team.housing_structure), region)
	_footer.text = "%d%% of a week's recovery on average · %.1f a week in rent and lines" % [
		roundi((total / maxf(float(counted), 1.0)) * 100.0), weekly_cost,
	]


func _lease_signed(structure: String) -> void:
	var team := _team()
	team.housing_structure = structure
	## The career carries the same fact -- §15 makes the lease what a save is
	## generated from -- and two names for one thing is how they drift. Written
	## here rather than left to agree by luck, which is what they were doing.
	if _career_manager != null and _career_manager.career != null:
		_career_manager.career.housing_structure = structure
	refresh()


## One end of the occupancy control, disabled where the range stops.
func _step_button(step: int) -> Button:
	var team := _team()
	var button := Button.new()
	button.text = "−" if step < 0 else "+"
	var target := int(team.housing_occupants_per_room) + step
	button.disabled = target < MIN_OCCUPANTS or target > MAX_OCCUPANTS
	button.pressed.connect(func() -> void: _change_occupants(step))
	return button


func _change_occupants(delta: int) -> void:
	var team := _team()
	team.housing_occupants_per_room = clampi(
		int(team.housing_occupants_per_room) + delta, MIN_OCCUPANTS, MAX_OCCUPANTS
	)
	refresh()


func _install(installed: Array, item: String, on: bool) -> void:
	if on and not installed.has(item):
		installed.append(item)
	elif not on:
		installed.erase(item)
	refresh()


func _run_line(region: String, on: bool) -> void:
	var team := _team()
	if on and not team.supply_lines.has(region):
		team.supply_lines.append(region)
	elif not on:
		team.supply_lines.erase(region)
	refresh()


func _heading(into: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	into.add_child(label)


func _line(into: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	into.add_child(label)
