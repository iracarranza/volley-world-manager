class_name KitchenScreen
extends Control

## What the squad eats this week.
##
## Food left the housing page in §19 because housing and food are two systems
## that share a rest multiplier, which is not the same as being one screen. This
## is where it went.
##
## ## The mix is the page
##
## Everything else here is a list; the mix is the only thing that is a *shape*.
## §2's rules all live in it -- a block holds two to four pastes, the ratio costs
## non-linearly, and palate fatigue decays on the specific ratio rather than on
## any one paste -- so the stacked bar is the object and the block, the lines and
## the presets are cards beside it.
##
## ## Two bars, because a preset is a target
##
## The bar draws what **arrived**, and when a preset is set it ghosts what was
## **asked for** behind it. Without that the preset feature lies: a chef
## approximates a target, how closely is their rating and their familiarity, and
## a screen showing only the target would be reporting the manager's intention
## as though it were the week.
const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const FoodBlock := preload("res://scripts/data/food_block.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")
const Larder := preload("res://scripts/data/region_larder.gd")
const Ratio := preload("res://scripts/data/paste_ratio.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const CardScript := preload("res://scenes/components/menu_card.gd")
const PopupScript := preload("res://scenes/components/desk_popup.gd")

signal back_requested

## How much a stepper moves a paste's share. A tenth, because the ratio key
## rounds to a tenth -- a step finer than the thing palate fatigue notices would
## be a control with no consequence.
const STEP: float = 0.1

var _career_manager: Node = null
var _game_manager: Node = null
var _bar: MixBar = null
var _caption: Label = null
var _rows: VBoxContainer = null
var _block_card: MenuCard = null
var _lines_card: MenuCard = null
var _preset_card: MenuCard = null
var _panel: DeskPopup = null
var _showing: String = ""


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
		self, "Kitchen", [back_button] as Array[Button]
	)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(body)

	var stage := VBoxContainer.new()
	stage.add_theme_constant_override("separation", 8)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	_bar = MixBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 96.0)
	stage.add_child(_bar)
	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(330.0, 0.0)
	side.add_theme_constant_override("separation", 10)
	body.add_child(side)
	_block_card = CardScript.build("Block", "The base of the week")
	_block_card.pressed.connect(func() -> void: _open("block"))
	side.add_child(_block_card)
	_lines_card = CardScript.build("Lines", "Larders you can reach")
	_lines_card.pressed.connect(func() -> void: _open("lines"))
	side.add_child(_lines_card)
	_preset_card = CardScript.build("Presets", "Mixes worth repeating")
	_preset_card.pressed.connect(func() -> void: _open("presets"))
	side.add_child(_preset_card)

	_panel = PopupScript.build()
	_panel.closed.connect(func() -> void: _showing = "")
	add_child(_panel)


func _team() -> Resource:
	return _game_manager.team if _game_manager != null else null


func _region() -> String:
	if _career_manager != null and _career_manager.career != null:
		return str(_career_manager.career.region)
	return "Landavol"


func _week() -> int:
	if _career_manager != null and _career_manager.career != null:
		return int(_career_manager.career.absolute_week)
	return 1


func _table() -> Dictionary:
	return FoodSupply.table(_region(), _team().supply_lines, _week())


func _service() -> Dictionary:
	if _career_manager == null or _career_manager.career == null:
		return {}
	return _career_manager._week_service(_region(), _week())


func refresh() -> void:
	if _bar == null or _team() == null:
		return
	var team := _team()
	var service := _service()
	var served: Dictionary = service.get("ratio", {})
	var target: Dictionary = Ratio.normalised(team.paste_preset)
	_bar.set_mix(served, target, _table().get("pastes", {}), _week())

	var block := str(team.food_block)
	_caption.text = "%s  ·  %d of %d slots  ·  mix %.2f  ·  lines %.1f" % [
		block, Ratio.slots_used(served),
		FoodBlock.paste_slots(_career_manager.chef_rating()),
		Ratio.cost(served), float(_table().get("weekly_cost", 0.0)),
	]
	_refresh_rows(served, target)
	_refresh_cards(served)
	_fill_panel()


## One row per paste the club can reach: its share, what it is like this season,
## and whether the chef knows it.
func _refresh_rows(served: Dictionary, target: Dictionary) -> void:
	for child in _rows.get_children():
		child.queue_free()
	var pastes: Dictionary = _table().get("pastes", {})
	var names: Array = pastes.keys()
	names.sort()
	for paste in names:
		var name := str(paste)
		var region := str(pastes[name])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)

		var label := Label.new()
		var condition := Larder.condition(region, _week())
		label.text = "%s · %s%s" % [
			name, Larder.axis_of(region),
			"" if condition == Larder.CONDITION_USUAL else " · %s this season" % condition,
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = (
			"%s, from %s.\n\nThis season it is %s -- %d%% of the nourishment it"
			+ " usually carries."
		) % [
			name, region, condition,
			roundi(Larder.nourishment_of(region, _week()) * 100.0),
		]
		row.add_child(label)

		## What arrived, and what was asked for when they differ. A chef
		## approximates a target, so a screen printing one number would be
		## reporting an intention as though it were the week.
		var share := float(served.get(name, 0.0))
		var figure := Label.new()
		figure.text = "%d%%" % roundi(share * 100.0)
		if not target.is_empty() and absf(share - float(target.get(name, 0.0))) > 0.005:
			figure.text += "  (asked %d%%)" % roundi(float(target.get(name, 0.0)) * 100.0)
		figure.custom_minimum_size = Vector2(140.0, 0.0)
		figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(figure)

		for step in [-STEP, STEP]:
			var button := Button.new()
			button.text = "−" if step < 0.0 else "+"
			var delta := float(step)
			button.pressed.connect(func() -> void: _nudge(name, delta))
			row.add_child(button)


func _refresh_cards(served: Dictionary) -> void:
	var team := _team()
	var block := str(team.food_block)
	var entry: Dictionary = FoodBlock.of(block)
	## The name, not the authored sentence. `why` is a clause and a card's third
	## line is a *reading*: five lines of prose in a 160px column is the card
	## explaining itself instead of reporting.
	_block_card.set_reading(block)
	_block_card.set_figure(
		"%d%%" % roundi(float(entry.get("takes_paste", 1.0)) * 100.0), "takes paste"
	)
	var lines: Array = team.supply_lines
	_lines_card.set_reading(
		"Only %s" % _region() if lines.is_empty() else ", ".join(lines)
	)
	_lines_card.set_figure(
		"%d" % Dictionary(_table().get("pastes", {})).size(), "pastes to hand"
	)
	var presets: Dictionary = team.paste_presets
	_preset_card.set_reading(
		"None saved" if presets.is_empty()
			else ", ".join(presets.keys())
	)
	_preset_card.set_figure(
		"on" if not Dictionary(team.paste_preset).is_empty() else "off",
		"chef following one"
	)


func _open(key: String) -> void:
	_showing = key
	match key:
		"block":
			_panel.open("Block", "The base of the week, off a shelf")
		"lines":
			_panel.open("Lines", "Which larders the club can reach")
		_:
			_panel.open("Presets", "Mixes worth cooking again")
	_fill_panel()


func _fill_panel() -> void:
	if _panel == null or _showing.is_empty():
		return
	for child in _panel.body.get_children():
		child.queue_free()
	match _showing:
		"block":
			_fill_block()
		"lines":
			_fill_lines()
		"presets":
			_fill_presets()


func _fill_block() -> void:
	var team := _team()
	for name in FoodBlock.names():
		var entry: Dictionary = FoodBlock.of(str(name))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_panel.body.add_child(row)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title := Label.new()
		title.text = str(name)
		text.add_child(title)
		## The four axes deliberately do not move together, which is the whole
		## argument for four blocks rather than a ladder -- so all four are on the
		## row rather than a single quality figure.
		var axes := Label.new()
		axes.text = "%s · fed %d · mood %d · %.1f a week · takes paste %d%%" % [
			str(entry.get("why", "")),
			roundi(float(entry["nutrition"]) * 100.0),
			roundi(float(entry["morale"]) * 100.0),
			float(entry["cost"]),
			roundi(float(entry["takes_paste"]) * 100.0),
		]
		axes.add_theme_font_size_override("font_size", 11)
		axes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(axes)
		var action := Button.new()
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if str(name) == str(team.food_block):
			action.text = "Cooking"
			action.disabled = true
		else:
			action.text = "Switch"
			var chosen := str(name)
			action.pressed.connect(func() -> void:
				team.food_block = chosen
				refresh()
			)
		row.add_child(action)


func _fill_lines() -> void:
	var team := _team()
	var region := _region()
	for source in Larder.LARDERS:
		if str(source) == region:
			continue
		var name := str(source)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_panel.body.add_child(row)
		var label := Label.new()
		label.text = "%s · %s · %.1f/wk · %d%% arrives" % [
			Larder.paste_name(name), Larder.axis_of(name),
			FoodSupply.line_cost(region, name),
			roundi(FoodSupply.line_reliability(region, name) * 100.0),
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var action := Button.new()
		var running: bool = team.supply_lines.has(name)
		action.text = "Stop" if running else "Run"
		action.pressed.connect(func() -> void:
			if running:
				team.supply_lines.erase(name)
			else:
				team.supply_lines.append(name)
			refresh()
		)
		row.add_child(action)


## ## Presets
##
## A preset can only be saved from a week that was **actually cooked**, so the
## list is a record of things this club has really eaten rather than a recipe
## book somebody typed. That is also what makes the chef's approximation
## meaningful: you are keeping a mix you have seen land.
func _fill_presets() -> void:
	var team := _team()
	var served: Dictionary = _service().get("ratio", {})
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	_panel.body.add_child(save_row)
	var save_label := Label.new()
	save_label.text = "This week: %s" % _mix_text(served)
	save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_row.add_child(save_label)
	var keep := Button.new()
	keep.text = "Keep"
	keep.disabled = served.is_empty()
	keep.pressed.connect(func() -> void:
		team.paste_presets[_mix_text(served)] = served.duplicate()
		refresh()
	)
	save_row.add_child(keep)

	if not Dictionary(team.paste_preset).is_empty():
		var stop := Button.new()
		stop.text = "Let the chef rotate"
		stop.pressed.connect(func() -> void:
			team.paste_preset = {}
			refresh()
		)
		_panel.body.add_child(stop)

	for name in Dictionary(team.paste_presets):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_panel.body.add_child(row)
		var label := Label.new()
		label.text = str(name)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var follow := Button.new()
		follow.text = "Follow"
		var chosen: Dictionary = Dictionary(team.paste_presets[name])
		follow.pressed.connect(func() -> void:
			team.paste_preset = chosen.duplicate()
			refresh()
		)
		row.add_child(follow)
		var drop := Button.new()
		drop.text = "Forget"
		var key := str(name)
		drop.pressed.connect(func() -> void:
			team.paste_presets.erase(key)
			refresh()
		)
		row.add_child(drop)


func _mix_text(ratio: Dictionary) -> String:
	if ratio.is_empty():
		return "nothing"
	var parts: Array[String] = []
	var names: Array = ratio.keys()
	names.sort()
	for paste in names:
		parts.append("%s %d%%" % [str(paste), roundi(float(ratio[paste]) * 100.0)])
	return ", ".join(parts)


## Move one paste's share and let the rest take up the slack.
##
## Editing the mix by hand **clears the preset**, because a manager who has
## reached in and changed the ratio is a manager standing in the kitchen -- which
## is exactly the case §2 says gets the mix exactly rather than approximately.
func _nudge(paste: String, delta: float) -> void:
	var team := _team()
	var current: Dictionary = _service().get("ratio", {}).duplicate()
	current[paste] = clampf(float(current.get(paste, 0.0)) + delta, 0.0, 1.0)
	var normalised := Ratio.normalised(current)
	team.paste_preset = normalised
	refresh()


## The week's mix, as a bar.
##
## Widths are shares, so the shape *is* the ratio. Colour is what the paste is
## like this season rather than which paste it is: §2's whole reason for the
## condition mechanic is that a rich year is a reason to feed something you do
## not know, and a bar that coloured by region would say the opposite.
class MixBar extends Control:
	var served: Dictionary = {}
	var target: Dictionary = {}
	var regions: Dictionary = {}
	var week: int = 1

	const TARGET_HEIGHT: float = 0.30

	func set_mix(
		served_now: Dictionary, target_now: Dictionary,
		region_of: Dictionary, at_week: int
	) -> void:
		served = served_now
		target = target_now
		regions = region_of
		week = at_week
		queue_redraw()

	func _draw() -> void:
		var light := UIPalette.control_is_light(self)
		draw_rect(
			Rect2(Vector2.ZERO, size),
			UIPalette.color(&"surface_inset", light), true
		)
		if served.is_empty():
			return
		var names: Array = served.keys()
		names.sort()
		var bar_height := size.y * (1.0 - TARGET_HEIGHT)
		var cursor := 0.0
		for paste in names:
			var width := size.x * float(served[paste])
			var region := str(regions.get(paste, ""))
			var rect := Rect2(Vector2(cursor, 0.0), Vector2(width, bar_height))
			draw_rect(rect, _condition_ink(region, light), true)
			draw_rect(rect, UIPalette.color(&"stroke", light), false, 1.0)
			_write(str(paste), rect, light)
			cursor += width
		## And the target underneath, ghosted, when there is one to miss.
		if target.is_empty():
			return
		var ghost := 0.0
		var target_names: Array = target.keys()
		target_names.sort()
		for paste in target_names:
			var width := size.x * float(target[paste])
			draw_rect(
				Rect2(
					Vector2(ghost, bar_height + 3.0),
					Vector2(maxf(width - 2.0, 1.0), size.y - bar_height - 4.0)
				),
				Color(UIPalette.color(&"ink_faint", light), 0.55), true
			)
			ghost += width

	func _condition_ink(region: String, light: bool) -> Color:
		match Larder.condition(region, week):
			Larder.CONDITION_RICH:
				return UIPalette.color(&"positive", light)
			Larder.CONDITION_LEAN:
				return UIPalette.color(&"danger", light)
		return UIPalette.color(&"surface_hover", light)

	func _write(text: String, rect: Rect2, light: bool) -> void:
		var font := get_theme_default_font()
		if font == null:
			return
		var size_px := 11
		var extent := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px
		)
		if extent.x > rect.size.x - 6.0:
			return
		draw_string(
			font,
			rect.position + Vector2(
				(rect.size.x - extent.x) * 0.5, rect.size.y * 0.5 + extent.y * 0.3
			),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px,
			UIPalette.color(&"ink", light)
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()
