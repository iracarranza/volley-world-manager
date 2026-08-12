class_name FloorPlan
extends Control

## One room, in plan, with everything in it drawn against the wall.
##
## `ACCOMMODATIONS_AND_CARE.md` §10: *"occupancy and equipment compete for the
## same floor."* That is the single rule the whole housing system turns on, and
## it is the one thing a list of checkboxes cannot show. Two volis and a rack of
## weights is seven floor in a room that has five, and a manager reading two
## columns of ticks has no way to see it.
##
## So the room is drawn at the size the structure actually is, the things in it
## are laid in end to end, and the wall is a heavy line at capacity. Anything
## past the wall is drawn **outside the room**, which is what crowding is: not a
## penalty that fires, a bed that does not fit.
##
## ## Why the blocks are their real widths
##
## An occupant is two floor and takes twice the width of a fan. That is the only
## reason this reads faster than the numbers it is drawn from -- a plan where
## every item is a same-sized chip is a list with a border round it, and the
## trade it exists to show would be invisible again.
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const Accommodation := preload("res://scripts/data/accommodation.gd")

## One unit of floor, in pixels. Sized so the widest room in the game -- the
## Row's seven, plus whatever is spilling past its wall -- fits a column beside
## two others without the page scrolling sideways.
##
## Raised from 27 after looking at it: at that width a one-floor item had 23px
## of usable cell, every small item's label failed to fit, and `_write` dropped
## it -- so a shelf of installed equipment drew as a row of blank boxes and read
## as empty floor. The plan's whole job is to say what is taking up the room.
const CELL: float = 32.0
const ROOM_HEIGHT: float = 52.0
## Room for the wall's own weight and for a block sitting hard against it.
const MARGIN: float = 3.0
const WALL_WIDTH: float = 2.5
const BLOCK_INSET: float = 2.0

## What is in the room, in the order it is laid down: people first, because they
## are why the room exists, then the large things, then the small.
var occupants: int = 2
var small: Array = []
var large: Array = []
var structure: String = "Bunkhouse"

var _light_mode: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Re-read the room. Called by the screen after any edit, which is every click.
func set_room(
	structure_name: String, occupant_count: int,
	small_items: Array, large_items: Array
) -> void:
	structure = structure_name
	occupants = occupant_count
	small = small_items
	large = large_items
	_resize()
	queue_redraw()


func _notification(what: int) -> void:
	## The palette is read off the theme rather than passed in, the way every
	## other drawn component here does it, so a theme switch repaints the plan
	## without the screen having to know the plan exists.
	if what == NOTIFICATION_THEME_CHANGED:
		_light_mode = UIPalette.control_is_light(self)
		queue_redraw()


func capacity() -> float:
	return float(Dictionary(Accommodation.STRUCTURES.get(structure, {})).get("floor", 5.0))


## The wall a block is actually judged against.
##
## **A privacy screen partitions the room**, and this is where the plan would
## otherwise lie about it. `Accommodation.crowding` gives the screen back one
## occupant's worth of floor, so a room can sit past its own wall and be
## uncrowded -- and a picture drawing a bed outside the wall above a caption
## reading *over by 0.0* is the interface disagreeing with itself.
##
## So the screen is drawn as what it is: a second, lighter wall further out. The
## arithmetic is `crowding`'s own, not a second opinion -- past this line and
## past zero crowding are the same condition.
func partition_relief() -> float:
	return Accommodation.FLOOR_PER_OCCUPANT if small.has("privacy_screen") else 0.0


func effective_capacity() -> float:
	return capacity() + partition_relief()


func used() -> float:
	return Accommodation.floor_used(occupants, small, large)


func _resize() -> void:
	## The plan is as wide as the room *or* as wide as what has been put in it,
	## whichever is more -- a room that has been overfilled has to have somewhere
	## to draw the part that does not fit.
	var span := maxf(effective_capacity(), used())
	custom_minimum_size = Vector2(span * CELL + MARGIN * 2.0, ROOM_HEIGHT + MARGIN * 2.0)


## Every block in the room, left to right, as `{floor, label, kind}`.
##
## Built here rather than in `_draw` so a gate can walk it: the widths this
## returns are the arithmetic `Accommodation.floor_used` does, and if the two
## ever disagree the picture is lying about the model.
func blocks() -> Array:
	var out: Array = []
	for index in range(maxi(occupants, 0)):
		out.append({
			"floor": Accommodation.FLOOR_PER_OCCUPANT,
			"label": "bed", "kind": "occupant",
		})
	for item in large:
		out.append({
			"floor": Accommodation.FLOOR_LARGE_ITEM,
			"label": _short(str(item)), "kind": "large",
		})
	for item in small:
		out.append({
			"floor": Accommodation.FLOOR_SMALL_ITEM,
			"label": _short(str(item)), "kind": "small",
		})
	return out


func _draw() -> void:
	var wall_x := MARGIN + effective_capacity() * CELL
	var floor_ink := UIPalette.color(&"surface_inset", _light_mode)
	var pen := UIPalette.color(&"stroke", _light_mode)
	var heavy := UIPalette.color(&"stroke_strong", _light_mode)
	var over_ink := UIPalette.color(&"danger", _light_mode)

	## The room itself: the floor, then the three walls that are not the one
	## being pushed against.
	var room := Rect2(
		Vector2(MARGIN, MARGIN), Vector2(effective_capacity() * CELL, ROOM_HEIGHT)
	)
	draw_rect(room, floor_ink, true)
	draw_rect(room, pen, false, 1.0)
	## The floor grid, one line per unit, so the widths are countable rather than
	## only comparable. Faint: it is a measure, not a division.
	for step in range(1, int(ceilf(effective_capacity()))):
		var x := MARGIN + float(step) * CELL
		draw_line(
			Vector2(x, MARGIN + 1.0), Vector2(x, MARGIN + ROOM_HEIGHT - 1.0),
			Color(pen, 0.45), 1.0
		)

	var cursor := MARGIN
	for block in blocks():
		var width := float(block["floor"]) * CELL
		var rect := Rect2(
			Vector2(cursor + BLOCK_INSET, MARGIN + BLOCK_INSET),
			Vector2(width - BLOCK_INSET * 2.0, ROOM_HEIGHT - BLOCK_INSET * 2.0)
		)
		## A block is "out" the moment any part of it is past the wall. Not its
		## midpoint and not its far edge: half a bed outside is a bed that does
		## not fit, and rounding that in the room's favour is how a picture ends
		## up disagreeing with the number under it.
		var out := cursor + width > wall_x + 0.01
		draw_rect(rect, _fill_for(str(block["kind"]), out), true)
		draw_rect(rect, over_ink if out else heavy, false, 1.0)
		_write(str(block["label"]), rect, out)
		cursor += width

	## The walls last, over everything, because the whole point is which side of
	## one a thing is on. The room's own wall is solid; the partition, when there
	## is one, is drawn out where it actually holds -- lighter, because it is a
	## screen somebody stood up rather than a wall the building has.
	if partition_relief() > 0.0:
		var built := MARGIN + capacity() * CELL
		draw_line(
			Vector2(built, MARGIN), Vector2(built, MARGIN + ROOM_HEIGHT),
			Color(heavy, 0.35), 1.0
		)
	draw_line(
		Vector2(wall_x, MARGIN - 1.0), Vector2(wall_x, MARGIN + ROOM_HEIGHT + 1.0),
		heavy, WALL_WIDTH
	)


## What a block is filled with.
##
## Three weights rather than three hues: a person is the solid thing in a room,
## a large item is furniture, a small item is something on a shelf. Colour is
## spent entirely on whether it fits, which is the only reading the plan is for.
func _fill_for(kind: String, out: bool) -> Color:
	if out:
		return Color(UIPalette.color(&"danger", _light_mode), 0.24)
	match kind:
		"occupant":
			return UIPalette.color(&"surface_hover", _light_mode)
		"large":
			return UIPalette.color(&"surface_raised", _light_mode)
	return UIPalette.color(&"surface", _light_mode)


## Write what fits, shortening until it does.
##
## A fixed truncation cannot work: the hand this interface is set in is
## proportional, so `land` fits a one-floor block and `cook` does not, and the
## first version silently drew nothing for the ones that missed. A blank block in
## a plan whose whole job is *what is taking up the room* is the worst possible
## failure -- it reads as floor nobody is using.
func _write(text: String, rect: Rect2, out: bool) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var size := 10
	var room_for := rect.size.x - 3.0
	var shown := text
	var extent := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	while extent.x > room_for and shown.length() > 2:
		shown = shown.substr(0, shown.length() - 1)
		extent = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	if extent.x > room_for:
		return
	text = shown
	draw_string(
		font, rect.position + Vector2(
			(rect.size.x - extent.x) * 0.5, rect.size.y * 0.5 + extent.y * 0.30
		),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size,
		UIPalette.color((&"danger" if out else &"ink_muted"), _light_mode)
	)


## `mattress_topper` is wider than the one cell it occupies, so the plan writes
## what it can and the list beside it carries the full name.
##
## The first word only, and no more than four letters of it -- a starting point
## rather than a promise, since `_write` shortens further whenever the hand this
## is set in makes four too many.
func _short(item: String) -> String:
	var words := item.split("_")
	return str(words[0]).substr(0, 4)
