class_name UIPrintedRule
extends Control

## A panel edge that was **printed**, not drawn.
##
## This is the whole of what makes the clipboard a different object from the
## journal, and the previous attempt missed it. The medium system had two states,
## sewn and drawn, and "drawn" was defined as *the same treatment with a pen edge
## instead of a stitched one*: the same halftone screen, the same paper stock,
## the same per-patch tint variation. A different border on an identical surface
## is not a different object, which is exactly what it looked like.
##
## The distinction that actually separates them is not the border. It is **who
## made the marks**:
##
## | | the journal | the clipboard |
## |---|---|---|
## | substrate | screened, warm, hand-toned | flat stock, cooler, unscreened |
## | divisions | drawn by hand, wandering | printed, dead straight, hairline |
## | consistency | no two patches from the same scrap | every sheet off the same press |
## | the hand | *everything* | only what was added: marker, red pen, highlighter |
##
## That last row is the principle. On the journal there is no machine anywhere.
## On the clipboard the *form* is machine-made and only the annotation is human,
## which is what makes a scrawled marker board and a red pen circle read as
## somebody's marks rather than as more of the same style.
##
## So this draws the opposite of `UIInkOutline` in every respect: no wander, no
## nib, no pooling at corners, no seeded imperfection. A hairline of uniform
## width, mechanically square, in a grey that was mixed for a printer rather than
## for a pen. Where the pen says "a hand was here", this says "a hand was not".

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## A printed hairline. One pixel is what a form rule is; anything heavier starts
## reading as a drawn box again.
const RULE_WIDTH: float = 1.0
const RULE_ALPHA: float = 0.34
## The heavier rule under a header. Printed forms use exactly two weights and no
## more, which is part of why they read as printed.
const HEAVY_WIDTH: float = 1.8
const HEAVY_ALPHA: float = 0.46

## The faint printed grid the form is laid out on. Visible enough to be felt and
## not to be read -- a form's grid is for whoever set the type, not for whoever
## fills it in.
const GRID_PITCH: float = 22.0
const GRID_ALPHA: float = 0.085

## The corner ticks. Real forms carry crop or registration marks from the press,
## and they are the single cheapest thing that says "this was printed in a batch"
## rather than "somebody ruled this".
const TICK_LENGTH: float = 7.0
const TICK_INSET: float = 4.0
const TICK_ALPHA: float = 0.30

## Ink mixed for a press: near-neutral, slightly cool, and never the page's own
## ink colour. A form is printed in a cheap grey, not in the warm brown-black
## somebody's pen lays down.
const PRESS_INK_LIGHT := Color(0.34, 0.36, 0.38)
const PRESS_INK_DARK := Color(0.56, 0.60, 0.64)

## Whether this panel carries the grid, or only its edge. A card gets the grid;
## a button is a printed box on a form and gets the rule alone.
@export var gridded: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parent := get_parent() as Control
	if parent != null:
		parent.resized.connect(queue_redraw)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 6.0 or size.y < 6.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var press := PRESS_INK_LIGHT if light_mode else PRESS_INK_DARK

	if gridded:
		_draw_grid(press)

	## The frame. `draw_rect` with a width, not a polyline of segments -- the
	## corners are exactly square and that is the point.
	draw_rect(
		Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)),
		Color(press, RULE_ALPHA), false, RULE_WIDTH
	)
	if gridded:
		_draw_ticks(press)


## Printed at a fixed pitch in *screen* pixels rather than as a fraction of the
## panel, because a press does not rescale its grid to fit the sheet. Two panels
## of different sizes side by side therefore share a grid, which is most of what
## makes it read as printed rather than as a decoration each panel drew for
## itself.
func _draw_grid(press: Color) -> void:
	var faint := Color(press, GRID_ALPHA)
	var x := GRID_PITCH
	while x < size.x:
		draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0), faint, 1.0)
		x += GRID_PITCH
	var y := GRID_PITCH
	while y < size.y:
		draw_line(Vector2(1.0, y), Vector2(size.x - 1.0, y), faint, 1.0)
		y += GRID_PITCH


## Registration ticks just inside each corner, in the gap outside the frame.
func _draw_ticks(press: Color) -> void:
	var ink := Color(press, TICK_ALPHA)
	for corner in [
		[Vector2(TICK_INSET, TICK_INSET), Vector2(1.0, 1.0)],
		[Vector2(size.x - TICK_INSET, TICK_INSET), Vector2(-1.0, 1.0)],
		[Vector2(TICK_INSET, size.y - TICK_INSET), Vector2(1.0, -1.0)],
		[Vector2(size.x - TICK_INSET, size.y - TICK_INSET), Vector2(-1.0, -1.0)],
	]:
		var at: Vector2 = corner[0]
		var direction: Vector2 = corner[1]
		draw_line(at, at + Vector2(direction.x * TICK_LENGTH, 0.0), ink, 1.0)
		draw_line(at, at + Vector2(0.0, direction.y * TICK_LENGTH), ink, 1.0)
