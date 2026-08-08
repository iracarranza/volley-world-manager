class_name UIStickyNote
extends Control

## The two selectors, on a note stuck to the clipboard.
##
## What is being planned and where it is being looked at from used to be two rows
## of buttons across the top of the sheet, which put four controls between the
## page's own heading and the drawing they act on. They are not part of the form:
## a printed sheet does not have its own view selector, and pretending it does is
## what made them read as page furniture rather than as tools.
##
## A sticky note is the right object because it is the only thing on the desk
## that is **added after the fact**. The form was printed; the note was written
## and stuck on afterwards, which is exactly what a per-session view preference
## is. It also licenses the one thing the medium otherwise forbids -- a written
## hand -- without breaking the rule, because the note is not the form.
##
## Three options per heading, no more. Two headings of three fit a note; a fourth
## option or a third heading does not, and the constraint is doing useful work --
## it is why the presets moved off this page rather than being squeezed in.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal option_chosen(heading: String, option: String)

## The pad, and the shade of it. Not the cliché yellow: a warm ochre sits on the
## cream form without fighting the plastic dividers, and in the dark theme it has
## to keep its hue while dropping its value or the note becomes the brightest
## thing on the screen.
const NOTE_LIGHT := Color(0.95, 0.86, 0.55)
const NOTE_DARK := Color(0.52, 0.44, 0.24)
## The adhesive strip across the top, which is the only part actually stuck down
## and therefore the only part that does not curl.
const GUM_SHARE: float = 0.22
const CURL: float = 7.0

const ROW_HEIGHT: float = 24.0
const HEADING_HEIGHT: float = 17.0
const PADDING: float = 9.0

var headings: Array[String] = []
var options: Dictionary = {}
var chosen: Dictionary = {}
var disabled: Dictionary = {}

var _hovered := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("ui_style_exempt", true)
	resized.connect(queue_redraw)


func set_group(heading: String, values: Array, selected: String) -> void:
	if not heading in headings:
		headings.append(heading)
	options[heading] = values
	chosen[heading] = selected
	_refresh_minimum()
	queue_redraw()


func set_chosen(heading: String, value: String) -> void:
	chosen[heading] = value
	queue_redraw()


## Which options cannot be picked right now, per heading. Greyed rather than
## hidden: a note with a struck-through line still tells you the line exists.
func set_disabled(heading: String, values: Array) -> void:
	disabled[heading] = values
	queue_redraw()


func _refresh_minimum() -> void:
	var rows := 0
	for heading in headings:
		rows += int(Array(options.get(heading, [])).size())
	custom_minimum_size = Vector2(
		168.0,
		PADDING * 2.0 + float(headings.size()) * HEADING_HEIGHT
			+ float(rows) * ROW_HEIGHT + CURL
	)


func _option_rect(heading_index: int, option_index: int) -> Rect2:
	var y := PADDING + size.y * GUM_SHARE * 0.35
	for index in range(heading_index):
		var heading := headings[index]
		y += HEADING_HEIGHT + float(Array(options.get(heading, [])).size()) * ROW_HEIGHT
	y += HEADING_HEIGHT + float(option_index) * ROW_HEIGHT
	return Rect2(
		Vector2(PADDING, y), Vector2(size.x - PADDING * 2.0, ROW_HEIGHT - 2.0)
	)


func _at(position: Vector2) -> Vector2i:
	for heading_index in range(headings.size()):
		var values: Array = options.get(headings[heading_index], [])
		for option_index in range(values.size()):
			if _option_rect(heading_index, option_index).has_point(position):
				return Vector2i(heading_index, option_index)
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _at((event as InputEventMouseMotion).position)
		if was != _hovered:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit := _at(button.position)
	if hit.x < 0:
		return
	var heading: String = headings[hit.x]
	var value := str(Array(options[heading])[hit.y])
	if value in Array(disabled.get(heading, [])):
		return
	chosen[heading] = value
	option_chosen.emit(heading, value)
	accept_event()
	queue_redraw()


func _draw() -> void:
	if size.x < 60.0 or size.y < 40.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var paper := NOTE_LIGHT if light_mode else NOTE_DARK
	var ink := Color(0.28, 0.24, 0.16) if light_mode else Color(0.92, 0.89, 0.80)

	## The note lifts at the bottom corners, because only the gum strip along the
	## top is stuck down. That curl is the whole of what separates a sticky note
	## from a coloured rectangle, and it has to be in the *silhouette* -- shading
	## a flat rectangle to look curled does not work at this size.
	var sheet := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(size.x, 0.0),
		Vector2(size.x, size.y - CURL),
		Vector2(size.x * 0.72, size.y - CURL * 0.35),
		Vector2(size.x * 0.34, size.y),
		Vector2(0.0, size.y - CURL * 0.6),
	])
	var shadow := PackedVector2Array()
	for point in sheet:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.20))
	draw_colored_polygon(sheet, paper)
	## The gum strip reads as a slightly darker band because it is two layers.
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(size.x, size.y * GUM_SHARE)),
		Color(paper.darkened(0.07), 0.9)
	)
	draw_polyline(sheet, Color(paper.darkened(0.30), 0.55), 1.0, true)
	draw_line(sheet[sheet.size() - 1], sheet[0], Color(paper.darkened(0.30), 0.55), 1.0, true)

	var font := get_theme_default_font()
	var font_size := maxi(get_theme_default_font_size() - 2, 10)
	for heading_index in range(headings.size()):
		var heading: String = headings[heading_index]
		var values: Array = options.get(heading, [])
		var struck: Array = disabled.get(heading, [])
		if not values.is_empty():
			var first := _option_rect(heading_index, 0)
			draw_string(
				font, first.position + Vector2(0.0, -5.0), heading.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, first.size.x, maxi(font_size - 2, 9),
				Color(ink, 0.55)
			)
		for option_index in range(values.size()):
			var value := str(values[option_index])
			var rect := _option_rect(heading_index, option_index)
			var off := value in struck
			var picked := str(chosen.get(heading, "")) == value
			if picked:
				## Circled, not filled. This is a note somebody wrote on, and what
				## you do to a written option is ring it.
				draw_rect(rect.grow(-1.0), Color(ink, 0.10))
				draw_rect(rect.grow(-1.0), Color(ink, 0.55), false, 1.3)
			elif _hovered == Vector2i(heading_index, option_index) and not off:
				draw_rect(rect.grow(-1.0), Color(ink, 0.06))
			draw_string(
				font, rect.position + Vector2(7.0, rect.size.y - 6.0), value,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, font_size,
				Color(ink, 0.30 if off else 0.92)
			)
			if off:
				## Struck through rather than hidden: a note with a crossed-out
				## line still says the line exists, which is the point of greying.
				var middle := rect.position.y + rect.size.y * 0.52
				draw_line(
					Vector2(rect.position.x + 5.0, middle),
					Vector2(rect.end.x - 5.0, middle),
					Color(ink, 0.42), 1.1, true
				)
