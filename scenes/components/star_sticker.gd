class_name UIStarSticker
extends Control

## A foil star, stuck on next to something that matters.
##
## Marks the attributes a player's own position is actually scored on. That
## needed a channel of its own and had been taking the wrong one: the key rows
## were set in the heading face at full-strength ink against a muted body face,
## which is two fonts in one column of eight labels, and the column stopped
## reading as a list.
##
## **Hue means grade, shape means relevance.** Keeping the two apart is the
## whole point, and a sticker is the cleanest way to do it -- it is an *object
## on* the page rather than a property *of* the text, so it cannot be confused
## with the grade colour a few centimetres to its right no matter what colour it
## is. Gold is the obvious colour for the obvious reason: it is what a star
## sticker is, and nobody has ever had to be told what one means.
##
## Every sticker is put on slightly crooked, and no two the same way. A sheet of
## stickers applied at identical angles is a printed bullet, which is what this
## exists instead of.

## The foil, and the shadow it casts on the paper.
const FOIL := Color("e8b93c")
const FOIL_LIGHT := Color("f7dc86")
const FOIL_EDGE := Color("8a6a14")
const SHADOW := Color(0.0, 0.0, 0.0, 0.20)

## How far off square a sticker can be put on, in degrees.
const MAX_TILT_DEGREES: float = 17.0

## How deep the points cut in, as a share of the outer radius. A real foil star
## is stubby -- a thin-pointed one reads as a sparkle or an asterisk.
const INNER_RATIO: float = 0.46

## How much of the width the star takes, leaving the rest as the margin the
## sticker sits in.
const FILL_SHARE: float = 0.78


## Which sticker this is, for the tilt. Set by whoever places it; the same
## attribute should be crooked the same way every time it is looked at.
@export var sticker_seed: int = 0:
	set(value):
		sticker_seed = value
		if is_inside_tree():
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 * FILL_SHARE
	if radius < 2.0:
		return
	var centre := size * 0.5
	var tilt := deg_to_rad((_unit(11) - 0.5) * 2.0 * MAX_TILT_DEGREES)
	var points := _star(centre, radius, tilt)
	## Lifted off the page a fraction, so it is stuck on rather than printed in.
	draw_colored_polygon(_star(centre + Vector2(0.6, 1.0), radius, tilt), SHADOW)
	draw_colored_polygon(points, FOIL)
	## Foil is not one colour -- it catches the light across part of its face and
	## goes dull across the rest, and that split is most of why it reads as metal
	## rather than as a yellow shape. Drawn as the star clipped to its own upper
	## half by taking every vertex above the centre and closing across it.
	var lit := PackedVector2Array()
	for point in points:
		if point.y <= centre.y + radius * 0.12:
			lit.append(point)
	if lit.size() >= 3:
		draw_colored_polygon(lit, FOIL_LIGHT)
	draw_polyline(points, FOIL_EDGE, 0.9, true)


## A five-pointed star as ten alternating radii, starting at the top.
func _star(centre: Vector2, radius: float, tilt: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(11):
		var reach := radius if index % 2 == 0 else radius * INNER_RATIO
		var angle := -PI * 0.5 + tilt + TAU * float(index) / 10.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * reach)
	return points


## A stable 0-1 from this sticker's seed. Hand-mixed rather than `randf()`, so
## an attribute's sticker is crooked the same way on every visit.
func _unit(step: int) -> float:
	var accumulated := (sticker_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0
