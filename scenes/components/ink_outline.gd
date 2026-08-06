class_name UIInkOutline
extends Control

## A panel edge drawn as a pen line rather than a border width.
##
## `StyleBoxFlat` draws a rectangle of constant thickness with mathematically
## exact corners, which is the single most machine-made thing on the screen. A
## pen does none of that: it wanders off the straight by a fraction of a
## millimetre, it thins where the hand moves fastest along a run, and it pools
## where the hand slows and turns.
##
## So this draws the edge itself, as a chain of short segments whose offset and
## width both vary. It sits over the panel it belongs to and paints nothing else,
## which keeps it composable with the halftone -- one says what the surface is
## made of, the other says how its edge was drawn.
##
## **Deterministic, seeded per panel.** A wobble that redraws differently every
## frame is a shimmer, and a wobble shared by every panel is a texture rather
## than a hand. The seed comes from the panel's identity, so a given card always
## has the same imperfect edge and two cards side by side never have the same
## one.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## How long each drawn segment is, in pixels.
##
## Short enough that the line reads as continuously varying and long enough that
## a full card is not hundreds of draw calls. At 14 a dashboard card's edge is
## about fifty segments.
const SEGMENT_LENGTH: float = 14.0

## How far the line may stray from true, in pixels.
##
## Small on purpose. Past about a pixel and a half the panel stops looking hand
## drawn and starts looking broken -- the eye reads a wobbly rectangle as a
## rendering fault long before it reads it as craft.
const WANDER_PIXELS: float = 1.15

## Pen width along a run, and what it becomes at a corner.
##
## Thicker at corners because that is where a hand slows and the ink pools, which
## is the detail that sells a drawn line more than the wander does.
const STROKE_WIDTH: float = 1.6
const CORNER_WIDTH: float = 2.7

## How much of the run either side of a corner is affected by the pooling, as a
## fraction of the shortest side.
const CORNER_SHARE: float = 0.14

## Inset from the panel's own rect, so the line sits on the edge rather than half
## outside it.
const EDGE_INSET: float = 1.0

## Which panel this is, for the wander. Assigned by whoever creates the outline;
## identical seeds draw identical edges, which is the point.
@export var ink_seed: int = 0

## Corner radius to follow, so the pen turns where the stylebox turns.
@export var corner_radius: float = 10.0


func _ready() -> void:
	## Purely decorative: it must never eat a click meant for the card it is
	## drawn over, and it must never be restyled by the pass that created it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var ink := UIPalette.color(&"stroke_strong", light_mode)
	var points := _outline_points()
	if points.size() < 2:
		return
	var shortest := minf(size.x, size.y)
	for index in range(points.size() - 1):
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var midpoint := (from + to) * 0.5
		draw_line(
			from, to, ink,
			_stroke_width(midpoint, shortest),
			true,
		)


## The path the pen takes, already wandered.
##
## Built as one closed chain rather than four independent sides, so the corners
## join instead of meeting -- four separately jittered edges leave visible gaps
## exactly where a real line is heaviest.
func _outline_points() -> PackedVector2Array:
	var rect := Rect2(
		Vector2(EDGE_INSET, EDGE_INSET),
		size - Vector2(EDGE_INSET, EDGE_INSET) * 2.0
	)
	var radius := clampf(corner_radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		rect.position + Vector2(radius, 0.0),
		rect.position + Vector2(rect.size.x - radius, 0.0),
		rect.position + Vector2(rect.size.x, radius),
		rect.position + Vector2(rect.size.x, rect.size.y - radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y),
		rect.position + Vector2(radius, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - radius),
		rect.position + Vector2(0.0, radius),
	]
	var path := PackedVector2Array()
	var step := 0
	for index in range(corners.size()):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % corners.size()]
		var span := from.distance_to(to)
		var divisions := maxi(int(span / SEGMENT_LENGTH), 1)
		var normal := (to - from).orthogonal().normalized() \
			if span > 0.001 else Vector2.ZERO
		for division in range(divisions):
			var along := float(division) / float(divisions)
			step += 1
			path.append(
				from.lerp(to, along) + normal * _wander(step)
			)
	if path.size() > 0:
		path.append(path[0])
	return path


## How far off true the pen is at this point along the chain.
##
## Two hashed values at different rates summed, so the line drifts on a long
## wavelength and jitters on a short one -- a single frequency reads as a
## regular ripple, which is a spring rather than a hand.
func _wander(step: int) -> float:
	var slow := _unit(step / 3 + 1) - 0.5
	var fast := _unit(step + 977) - 0.5
	return (slow * 1.4 + fast * 0.6) * WANDER_PIXELS


## Thicker where the hand slows: at the corners, and never in the middle of a
## straight run.
func _stroke_width(point: Vector2, shortest: float) -> float:
	var band := maxf(shortest * CORNER_SHARE, 6.0)
	var to_edge := minf(
		minf(point.x, size.x - point.x),
		minf(point.y, size.y - point.y)
	)
	var along := minf(
		maxf(point.x, size.x - point.x),
		maxf(point.y, size.y - point.y)
	)
	## Distance to the nearest corner, cheaply: a point is near one when it is
	## near two edges at once.
	var corner_proximity := 1.0 - clampf(
		(along - (maxf(size.x, size.y) - band)) / maxf(band, 1.0), 0.0, 1.0
	)
	if to_edge > band:
		corner_proximity = 0.0
	return lerpf(STROKE_WIDTH, CORNER_WIDTH, corner_proximity)


## A stable 0-1 from this outline's seed and a step along its path.
##
## Hand-mixed rather than `randf()`: the edge has to be the same every frame or
## it shimmers, and the same across runs or a screenshot is not reproducible.
func _unit(step: int) -> float:
	var accumulated := (ink_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0
