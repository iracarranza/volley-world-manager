class_name UIRosterTray
extends Control

## The seven slots a formation is built out of, and where a voli is picked up.
##
## Six on the court in two rows of three, and the libero under the middle of the
## back row -- which is where they physically are and also the only honest place
## to put them, because a libero is not a seventh court position but a swap for
## whoever is in the middle back. Drawing them tucked under that slot says both
## things at once and costs no explanation.
##
## The tray replaces the week-state sidebar that used to hold this column. That
## panel was reference -- fatigue means, familiarity percentages -- and reference
## does not need to sit permanently beside the one panel a manager operates. What
## belongs here is the thing you *pick up*: a slot with a face in it, which you
## drag onto the sheet.
##
## **A slot is a piece of card with a photo clipped to it**, not a button. It is
## on the clipboard, so it obeys the printed-form medium: hairline rules, square
## corners, no hand in it. The photograph inside is the one thing that is not
## printed, which is what makes it read as clipped on rather than laid out.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal slot_selected(slot: int)
signal voli_dragged(slot: int, at: Vector2)
signal voli_dropped(slot: int, at: Vector2)

## Six court slots in rotation order, then the libero. Index 6 is the libero and
## is drawn under slot 4 -- middle back -- rather than in the grid.
const COURT_SLOTS: int = 6
const LIBERO_SLOT: int = 6
const SLOT_COUNT: int = 7
## Row 0 is the front row at the net, row 1 the back row. The labels are the
## rotation numbers a coach says out loud, which run anticlockwise from right
## back -- so the grid reads 4 3 2 over 5 6 1.
const SLOT_LABELS: Array[String] = ["4", "3", "2", "5", "6", "1", "L"]

const SLOT_GAP: float = 6.0
const LIBERO_SCALE: float = 0.78
## Enough that a face is a face. Below about forty pixels a headshot is a smudge
## and the slot may as well carry initials.
const MIN_SLOT: float = 46.0

var headshots: Dictionary = {}
var names: Dictionary = {}
var selected: int = -1

var _hovered: int = -1
var _dragging: int = -1
var _drag_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("ui_style_exempt", true)
	custom_minimum_size = Vector2(200.0, 210.0)
	resized.connect(queue_redraw)


## Give a slot a face. `texture` is the baked headshot; null empties the slot.
func set_headshot(slot: int, texture: Texture2D, display_name: String) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	if texture == null:
		headshots.erase(slot)
		names.erase(slot)
	else:
		headshots[slot] = texture
		names[slot] = display_name
	queue_redraw()


func slot_rect(slot: int) -> Rect2:
	var columns := 3
	var cell := Vector2(
		(size.x - SLOT_GAP * float(columns - 1)) / float(columns),
		0.0
	)
	cell.x = maxf(cell.x, MIN_SLOT)
	cell.y = cell.x
	if slot == LIBERO_SLOT:
		var libero := cell * LIBERO_SCALE
		return Rect2(
			Vector2(
				(size.x - libero.x) * 0.5,
				cell.y * 2.0 + SLOT_GAP * 2.0
			),
			libero
		)
	var column := slot % columns
	var row := slot / columns
	return Rect2(
		Vector2(
			float(column) * (cell.x + SLOT_GAP),
			float(row) * (cell.y + SLOT_GAP)
		),
		cell
	)


func _slot_at(at: Vector2) -> int:
	for slot in range(SLOT_COUNT):
		if slot_rect(slot).has_point(at):
			return slot
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var was := _hovered
		_hovered = _slot_at(motion.position)
		if _dragging >= 0:
			## Reported in *screen* space, because what the drag lands on is a
			## different control entirely and a tray-local position would mean
			## nothing to it.
			_drag_at = motion.position
			voli_dragged.emit(_dragging, motion.position + global_position)
			queue_redraw()
		elif was != _hovered:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		var slot := _slot_at(button.position)
		if slot < 0:
			return
		selected = slot
		slot_selected.emit(slot)
		## Only a populated slot can be picked up. An empty one is a place to put
		## somebody, not something to carry.
		if headshots.has(slot):
			_dragging = slot
			_drag_at = button.position
		accept_event()
		queue_redraw()
		return
	if _dragging >= 0:
		voli_dropped.emit(_dragging, button.position + global_position)
		_dragging = -1
		accept_event()
		queue_redraw()


func _draw() -> void:
	if size.x < 40.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var press := Color(0.34, 0.36, 0.38) if light_mode else Color(0.56, 0.60, 0.64)
	var font := get_theme_default_font()
	var font_size := maxi(get_theme_default_font_size() - 2, 10)

	for slot in range(SLOT_COUNT):
		var rect := slot_rect(slot)
		if rect.size.x < 8.0:
			continue
		_draw_slot(slot, rect, press, font, font_size, light_mode)

	## The dragged face rides under the cursor, at the size it will land at, so
	## the drop is a placement rather than a guess.
	if _dragging >= 0 and headshots.has(_dragging):
		var carried: Texture2D = headshots[_dragging]
		var box := slot_rect(_dragging).size * 0.86
		draw_texture_rect(
			carried, Rect2(_drag_at - box * 0.5, box), false, Color(1.0, 1.0, 1.0, 0.85)
		)


func _draw_slot(
	slot: int, rect: Rect2, press: Color, font: Font, font_size: int,
	light_mode: bool
) -> void:
	var filled := headshots.has(slot)
	## The card. Printed rules, square corners -- the clipboard's medium, not the
	## journal's, so an empty slot reads as a box on a form rather than as a hole.
	if filled:
		draw_texture_rect(headshots[slot], rect, false)
	else:
		draw_rect(rect, Color(press, 0.05))
	draw_rect(rect, Color(press, 0.42 if filled else 0.26), false, 1.0)

	## A selected slot gets a second rule inside the first -- a printed emphasis
	## rather than a glow, because nothing else on this form glows.
	if slot == selected:
		draw_rect(rect.grow(-3.0), Color(press, 0.75), false, 1.4)
	elif slot == _hovered:
		draw_rect(rect.grow(-3.0), Color(press, 0.34), false, 1.0)

	## The rotation number, bottom left, small. It is the thing a coach says, so
	## it stays legible even under a face.
	var label := SLOT_LABELS[slot]
	var at := rect.position + Vector2(4.0, rect.size.y - 5.0)
	if filled:
		## A printed chip behind it, or the number disappears into the photograph.
		draw_rect(
			Rect2(at + Vector2(-3.0, -float(font_size) - 1.0),
				Vector2(float(font_size) * 0.85 + 6.0, float(font_size) + 4.0)),
			Color(0.98, 0.97, 0.94, 0.82) if light_mode else Color(0.10, 0.11, 0.13, 0.78)
		)
	draw_string(
		font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(press, 0.95)
	)
	if not filled:
		return
	## And the name across the foot, clipped to the card.
	var display_name := str(names.get(slot, ""))
	if display_name.is_empty():
		return
	draw_string(
		font, rect.position + Vector2(rect.size.x * 0.34, rect.size.y - 5.0),
		display_name, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x * 0.62,
		maxi(font_size - 1, 9), Color(press, 0.85)
	)
