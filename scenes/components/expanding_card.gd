class_name ExpandingCard
extends VBoxContainer

## A card that says one thing until you open it.
##
## The accommodation page is three decisions and a building, and the first build
## laid all three out flat -- twenty-one equipment checkboxes down one column,
## every voli down another -- which left the one thing worth looking at, the
## rooms themselves, sharing a third of the page with a list nobody reads twice.
##
## ## The label is the summary, not a heading
##
## Two lines, and the second line is a **reading rather than a title**. `Equipment`
## over `Nothing fitted` is a card you never need to open; `Familiarity` over
## `Average social level: sharing` has already answered the question most visits
## are asking. A card whose closed state says only what is inside it has spent a
## row of the page saying nothing.
##
## Which is also why there is no count in the label unless a count is the reading.
## *Equipment (3)* is a fact about the interface. *A landline and a fan, in nine
## rooms* is a fact about the club.
const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal toggled_open(is_open: bool)

## Which way the mark points. Drawn rather than typed, because `▾` renders as a
## box in the display face this interface is set in and the arrow is the one
## piece of furniture on the card.
const MARK_SIZE: float = 7.0
const MARK_INSET: float = 12.0

var _open: bool = false
var _head: Button = null
var _title: Label = null
var _reading: Label = null
var _mark: Control = null
var body: VBoxContainer = null


static func build(title: String, reading: String = "") -> ExpandingCard:
	var card := ExpandingCard.new()
	card._compose(title, reading)
	return card


func _compose(title: String, reading: String) -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## The whole head is the hit area, not a chevron in the corner. A card that
	## only opens from its arrow is a card the player learns to aim at.
	_head = Button.new()
	_head.focus_mode = Control.FOCUS_ALL
	_head.pressed.connect(_toggle)
	add_child(_head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## The label is inside the button, so it must not eat the click that opens it.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(row)

	_mark = _Mark.new()
	_mark.custom_minimum_size = Vector2(MARK_SIZE * 2.0, MARK_SIZE * 2.0)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_mark)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_title = Label.new()
	_title.text = title
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_title)
	_reading = Label.new()
	_reading.text = reading
	_reading.add_theme_font_size_override("font_size", 12)
	_reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reading.visible = not reading.is_empty()
	text.add_child(_reading)

	## The head has to be at least as tall as the two lines inside it, and a
	## `Button` does not size to a child it is only hosting.
	_head.custom_minimum_size = Vector2(0.0, 44.0)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.visible = false
	add_child(body)


## Rewrite the second line without touching what is open.
##
## Called on every refresh, and it must not close the card: a manager who opened
## the equipment list and then fitted something would watch it shut under them.
func set_reading(reading: String) -> void:
	if _reading == null:
		return
	_reading.text = reading
	_reading.visible = not reading.is_empty()


func is_open() -> bool:
	return _open


func set_open(open: bool) -> void:
	_open = open
	body.visible = open
	if _mark != null:
		_mark.open = open
		_mark.queue_redraw()


func _toggle() -> void:
	set_open(not _open)
	toggled_open.emit(_open)


## The mark, drawn. Right when closed, down when open, and it is the only thing
## on the card that is not type.
class _Mark extends Control:
	var open: bool = false

	func _draw() -> void:
		var ink := UIPalette.color(
			&"ink_muted", UIPalette.control_is_light(self)
		)
		var middle := size * 0.5
		var reach := MARK_SIZE * 0.62
		var points := PackedVector2Array()
		if open:
			points.append(middle + Vector2(-reach, -reach * 0.55))
			points.append(middle + Vector2(reach, -reach * 0.55))
			points.append(middle + Vector2(0.0, reach * 0.75))
		else:
			points.append(middle + Vector2(-reach * 0.55, -reach))
			points.append(middle + Vector2(-reach * 0.55, reach))
			points.append(middle + Vector2(reach * 0.75, 0.0))
		draw_colored_polygon(points, ink)
