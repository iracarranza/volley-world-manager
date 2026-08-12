class_name VoliCard
extends MarginContainer

## One voli, as a card stuck to the whiteboard.
##
## `docs/design/THE_TACTICAL_WHITEBOARD.md` and the lock-in draft: the six are
## **objects on a board**, not rows in a list. That is not decoration. A row is
## read down a column and a card is read as a thing you could take down and move
## somewhere else -- which is exactly the act the screen exists to make real.
##
## ## No sentences
##
## The draft's first pass wrote lines like *"Serves that break a rally before it
## starts."* That is the game handing over a conclusion the manager should reach
## themselves, ideally by having lost to it once. Every descriptive phrase was
## replaced with a figure or a grade, and nothing here may reintroduce one: if a
## card wants to say something, it is a figure that has not been found yet.
##
## ## What is on it, and why that and nothing else
##
## | field | source | why it earns the space |
## |---|---|---|
## | slot, name, role | the lineup | which of the six this is |
## | region · age | `home_region`, `age` | an address, not an explanation |
## | condition | `FatigueModel.stage_name` + the raw figure | the model's own three branches, with the number beside them |
## | form, conf | `current_form`, `match_confidence` | the two things that moved since last week |
## | slot familiarity | `position_familiarity` | the cost of the lineup you just typed |
## | six grades | `AttributeProfiles.category_grade` | a card is too small for a wheel, and a grade is what you compare *across* six cards |
##
## ## Drawn, not panelled
##
## The first build made this a `PanelContainer` with a `StyleBoxFlat`, and
## `UIStyleSystem` replaced the stylebox on its way past -- the walk restyles
## panels, which is its job. What came out was six cards wearing the big panel's
## marker outline, with no condition stripe and their content clipped on both
## edges by margins that had been overwritten.
##
## So the card paints itself. That is not a workaround dressed as a principle:
## the board's own rule is that nothing on it was manufactured with an edge, and
## a card that draws its own stock, stripe and magnet is the only kind that can
## have a *magnet* at all -- a child node cannot overhang its parent's top edge.
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const FatigueModel := preload("res://scripts/simulation/fatigue_model.gd")
const BoardFace := preload("res://Yatra_One/YatraOne-Regular.ttf")
const BoardHand := preload("res://Short_Stack/ShortStack-Regular.ttf")

## 262px in the draft, and the reason the grades are three-letter tags.
const CARD_WIDTH: float = 262.0
## The condition edge. Wide enough to read as a *stripe on the card* rather than
## as a border the card was manufactured with -- the board's whole rule is that
## everything on it was put there by hand.
const CONDITION_EDGE: float = 5.0
const MAGNET_SIZE := Vector2(26.0, 9.0)
## How far off square a card can sit. Small: this is a card somebody slapped on
## a board, not a photograph in a scrapbook, and past about a degree it stops
## reading as haste and starts reading as a fan of playing cards.
## Raised from 0.9 after looking: at that angle a 262px card shifts four pixels
## corner to corner, which is inside the width of its own border and reads as
## square. Tilt alone was never going to carry this anyway -- see the stagger.
const TILT_DEGREES: float = 1.7
## And how far along the top edge its magnet can wander, as a share of the
## card's width either side of centre.
const MAGNET_DRIFT: float = 0.16
## How far up or down a card can sit relative to its neighbours, in pixels.
##
## **The one that actually does the work.** A row of cards at identical heights
## reads as a table however far each one is rotated, because the eye follows the
## shared top edge and never sees the angles. Break the edge and the same cards
## read as six things somebody stuck up one at a time.
const STAGGER_PIXELS: float = 9.0

var _light_mode: bool = false
var _stage: String = "working"
var _fatigue: float = 0.0
var _libero: bool = false
## One number per card, from the voli's id, driving every off-square choice on
## it. Shared so the tilt and the magnet agree with each other -- a card leaning
## left with its magnet pulled right looks like a mistake rather than a hand.
var _jitter: float = 0.5


## Build the card for one voli in one slot.
##
## `slot_number` is the rotation slot they are standing in, which is not their
## index in the lineup array and is the number the court diagram prints.
static func build(
	player: Resource, slot_number: int, light_mode: bool, libero: bool = false
) -> VoliCard:
	var card := VoliCard.new()
	card._light_mode = light_mode
	card._libero = libero
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	## The magnet hangs above the card, so the rack has to leave room for it or
	## every card in the second row clips the one above.
	card.add_theme_constant_override("margin_top", 12)
	## **Hand-placed, not laid out.**
	##
	## Six cards on an exact grid read as a table with rounded corners. What
	## makes a magnet look like a magnet is that somebody put it there in a hurry
	## and it is very slightly off -- so each card gets a small rotation and its
	## magnet sits a little off centre.
	##
	## Derived from the voli's id rather than randomised, because a card that
	## tilts differently every time the board is rebuilt is a twitch rather than
	## a placement. Rotation survives a Container's layout pass -- containers set
	## position and size, not transform -- which is why this is a property and
	## not a second wrapper node.
	card._jitter = float(int(player.id) * 2654435761 % 1000) / 1000.0
	card.rotation = deg_to_rad(lerpf(-TILT_DEGREES, TILT_DEGREES, card._jitter))
	## A second, independent draw from the same id, so a card that leans left is
	## not also always the one sitting low -- one number driving both would put
	## the whole rack on a diagonal.
	var lift := float(int(player.id) * 40503 % 1000) / 1000.0
	card.add_theme_constant_override("margin_top", int(
		12.0 + lerpf(0.0, STAGGER_PIXELS, lift)
	))
	card.add_theme_constant_override("margin_bottom", int(
		11.0 + STAGGER_PIXELS - lerpf(0.0, STAGGER_PIXELS, lift)
	))
	card._compose(player, slot_number)
	return card


func _compose(player: Resource, slot_number: int) -> void:
	## Rotate about the middle, so a tilted card stays where the rack put it
	## instead of swinging away from its top-left corner.
	pivot_offset = Vector2(CARD_WIDTH * 0.5, 90.0)
	_fatigue = float(player.fatigue)
	_stage = str(FatigueModel.stage_name(_fatigue))
	## Margins on the container, since the stock behind them is drawn rather than
	## supplied by a stylebox whose content margins a walk could overwrite.
	add_theme_constant_override("margin_left", int(CONDITION_EDGE) + 11)
	add_theme_constant_override("margin_right", 12)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)

	## Slot, name and role on one line: the number is structure so it is written
	## in the blue pen, and the role is a label so it is small, spaced and quiet.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	## `L` rather than a number, because a libero has no rotation slot -- they
	## are the swap for whoever is in middle back. Drawing them with one produced
	## two cards numbered 6 and a rotation that cannot exist.
	top.add_child(_display(
		"L" if _libero else str(slot_number), 23,
		UIPalette.board_color(&"marker_blue", _light_mode)
	))
	top.add_child(_display(
		str(player.display_name), 17, UIPalette.board_color(&"ink", _light_mode)
	))
	var role := _label(
		str(player.position_role).to_upper(), 10,
		UIPalette.board_color(&"ink_soft", _light_mode)
	)
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(role)

	## An address, not an explanation. The region is here because a voli is from
	## somewhere, and never because it is offered as the reason they play a way.
	column.add_child(_label(
		"%s · %d" % [str(player.home_region), int(player.age)], 12,
		UIPalette.board_color(&"ink_soft", _light_mode)
	))

	var readout := GridContainer.new()
	readout.columns = 2
	readout.add_theme_constant_override("h_separation", 8)
	readout.add_theme_constant_override("v_separation", 2)
	column.add_child(readout)
	readout.add_child(_key("COND"))
	var condition := HBoxContainer.new()
	condition.add_theme_constant_override("separation", 6)
	readout.add_child(condition)
	condition.add_child(_label(
		_stage.capitalize(), 13,
		UIPalette.board_stage_color(_stage, _light_mode)
	))
	condition.add_child(_label(
		"%.2f" % _fatigue, 13, UIPalette.board_color(&"ink_soft", _light_mode)
	))
	var bar := FatigueBar.new()
	bar.light_mode = _light_mode
	bar.fatigue = _fatigue
	bar.custom_minimum_size = Vector2(84.0, 9.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	condition.add_child(bar)

	readout.add_child(_key("FORM"))
	readout.add_child(_signed(float(player.current_form)))
	readout.add_child(_key("CONF"))
	readout.add_child(_signed(float(player.match_confidence)))

	readout.add_child(_key("SLOT"))
	var familiarity := int(player.position_familiarity.get(player.position_role, 0))
	var slot_line := HBoxContainer.new()
	slot_line.add_theme_constant_override("separation", 5)
	readout.add_child(slot_line)
	slot_line.add_child(_label(
		"%s — %d" % ["L" if _libero else str(slot_number), familiarity], 13,
		UIPalette.board_color(&"ink", _light_mode)
	))
	## A red `!` only when the slot they are *actually in* is low. Familiarity in
	## some other slot is not a warning about this lineup.
	if familiarity < FAMILIARITY_WARNING:
		slot_line.add_child(_display(
			"!", 15, UIPalette.board_color(&"marker_red", _light_mode)
		))

	## The six grades, two rows of three. The whole argument for a card over a
	## wheel: at this size a wheel is a smudge, and a grade is the thing you
	## compare across six cards anyway.
	var grades := GridContainer.new()
	grades.columns = 3
	grades.add_theme_constant_override("h_separation", 12)
	grades.add_theme_constant_override("v_separation", 1)
	column.add_child(grades)
	var profile := AttributeProfiles.summary_profile(player)
	for axis in AttributeProfiles.GRADE_BAND_CATEGORIES:
		var score := float(profile.get(axis, 0.0))
		var tier: String = AttributeProfiles.category_grade(str(axis), score, false)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grades.add_child(cell)
		cell.add_child(_key(str(AXIS_TAGS.get(axis, str(axis).substr(0, 3).to_upper()))))
		cell.add_child(_display(
			tier, 15, UIPalette.board_grade_color(tier, _light_mode)
		))


## Below this the slot is a warning rather than a figure.
##
## A placeholder, and marked as one: it is the same kind of threshold as the
## grades were and wants the same treatment -- measured against the distribution
## of familiarities a real lineup produces, which needs lineups to exist first.
const FAMILIARITY_WARNING: int = 50

const AXIS_TAGS := {
	"Attacking": "ATK", "Defensive": "DEF", "Setting / Control": "SET",
	"Physical": "PHY", "Serving": "SRV", "Mental / Tactical": "MTL",
}


func _display(text: String, size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BoardFace)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	return label


func _label(text: String, size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BoardHand)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	return label


## A field name. Uppercase and letterspaced in the body hand, because a board
## has two hands and not three.
func _key(text: String) -> Label:
	var label := _label(text, 10, UIPalette.board_color(&"ink_soft", _light_mode))
	label.add_theme_constant_override("outline_size", 0)
	return label


## Form and confidence are signed, and the sign is the reading.
func _signed(value: float) -> Label:
	var ink := UIPalette.board_color(&"ink", _light_mode)
	if value > 0.05:
		ink = UIPalette.board_color(&"marker_green", _light_mode)
	elif value < -0.05:
		ink = UIPalette.board_color(&"marker_red", _light_mode)
	return _label("%+.2f" % value, 13, ink)


## The magnet, drawn on top of the card's own top edge.
##
## A magnet rather than a border is the board's entire division rule: nothing on
## a whiteboard was manufactured with an edge, it was stuck there. Drawn in
## `_draw` rather than added as a child so it can overhang the panel, which is
## what makes it read as sitting *on* the card rather than inside it.
func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	draw_rect(body, UIPalette.board_color(&"card", _light_mode), true)
	draw_rect(body, UIPalette.board_color(&"ghost", _light_mode), false, 1.0)
	## The one edge that carries colour, and it carries **condition** rather than
	## quality: a card's left edge is the first thing scanned down a rack, and
	## "can this person play ninety minutes" is the question a rack answers.
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(CONDITION_EDGE, size.y)),
		UIPalette.board_stage_color(_stage, _light_mode), true
	)
	## And the magnet, overhanging the top edge -- which is the whole reason the
	## card draws itself. A magnet inside the card is a decoration; one sitting
	## over the edge is what is holding it up.
	var centre := size.x * (0.5 + lerpf(-MAGNET_DRIFT, MAGNET_DRIFT, _jitter))
	draw_rect(Rect2(
		Vector2(centre - MAGNET_SIZE.x * 0.5, -MAGNET_SIZE.y * 0.55),
		MAGNET_SIZE
	), UIPalette.board_color(&"magnet", _light_mode), true)


## The fatigue bar, with the model's own two thresholds drawn on it.
##
## The hairlines are `LABOURED_ONSET` and `SPENT_ONSET` read from
## `FatigueModel`, not copied, so the bar can never disagree with the word
## printed next to it. A bar whose marks are typed in by hand is a second
## opinion about fatigue, and this interface is only allowed one.
class FatigueBar extends Control:
	var light_mode: bool = false
	var fatigue: float = 0.0

	func _draw() -> void:
		var track := Rect2(Vector2.ZERO, size)
		draw_rect(track, UIPalette.board_color(&"ghost", light_mode), true)
		var filled := Rect2(
			Vector2.ZERO, Vector2(size.x * clampf(fatigue, 0.0, 1.0), size.y)
		)
		draw_rect(filled, UIPalette.board_stage_color(
			str(FatigueModel.stage_name(fatigue)), light_mode
		), true)
		var ink := UIPalette.board_color(&"ink_soft", light_mode)
		for onset in [FatigueModel.LABOURED_ONSET, FatigueModel.SPENT_ONSET]:
			var x := size.x * float(onset)
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), ink, 1.0)
