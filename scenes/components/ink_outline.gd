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
## Small on purpose, and smaller than it first shipped. At 1.15 the wobble was
## the loudest thing about the line; a drawn edge is mostly straight, and what
## says "hand" is the *variation in the ink*, not the deviation of the path.
const WANDER_PIXELS: float = 0.62

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

## How much ink the ball can fail to lay down, at worst.
##
## A ballpoint does not deposit an even line: the ball picks up ink in bursts, so
## a stroke runs solid, thins over a stretch where the bearing is dry, and comes
## back. That starvation is what a real pen line looks like up close, and it is a
## different thing from the path wandering -- one is where the line goes, the
## other is how much of it arrives.
##
## 0.62 leaves the driest stretch faint but never absent. A line that genuinely
## breaks reads as a rendering gap rather than as ink.
const COVERAGE_DEPTH: float = 0.62

## How many segments a dry stretch lasts. A pen starves over a run and re-inks;
## per-segment noise would be a dotted line, which is a different instrument.
const COVERAGE_RUN: int = 5

## How much thinner the stroke goes where it is starved. A dry ball lays down a
## narrower line as well as a fainter one.
const COVERAGE_WIDTH_FLOOR: float = 0.72

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
	## `set_anchors_and_offsets_preset`, not `set_anchors_preset`.
	##
	## The latter takes `keep_offsets = false` to mean "recompute the offsets so
	## the control keeps the rect it already has" -- it changes which edges the
	## control is anchored to and deliberately leaves it exactly where it was.
	## Read as "snap to full rect" it looks right and does nothing, which is what
	## happened: under a `PanelContainer` the outline was fitted by the container
	## and drew correctly, and under every `Button` it kept its content-derived
	## rect of 163x0 and returned at the size guard without painting a pixel. Six
	## of the seven inked surfaces on the dashboard were blank.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		var coverage := _coverage(index)
		draw_line(
			from, to,
			Color(ink, ink.a * coverage),
			_stroke_width(midpoint, shortest)
				* lerpf(COVERAGE_WIDTH_FLOOR, 1.0, coverage),
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
	var radius := clampf(
		_resolved_radius(), 0.0, minf(rect.size.x, rect.size.y) * 0.5
	)
	## The ring in draw order, clockwise from the top: each side's straight run,
	## then the arc that turns onto the next side.
	var side_starts := [
		rect.position + Vector2(radius, 0.0),
		rect.position + Vector2(rect.size.x, radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - radius),
	]
	var side_ends := [
		rect.position + Vector2(rect.size.x - radius, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y - radius),
		rect.position + Vector2(radius, rect.size.y),
		rect.position + Vector2(0.0, radius),
	]
	var arc_centres := [
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y - radius),
		rect.position + Vector2(radius, rect.size.y - radius),
		rect.position + Vector2(radius, radius),
	]
	var outward := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var path := PackedVector2Array()
	var step := 0
	for side in range(4):
		var from: Vector2 = side_starts[side]
		var to: Vector2 = side_ends[side]
		var divisions := maxi(int(from.distance_to(to) / SEGMENT_LENGTH), 1)
		for division in range(divisions):
			step += 1
			path.append(
				from.lerp(to, float(division) / float(divisions))
					+ outward[side] * _wander(step)
			)
		if radius <= 0.5:
			continue
		## The turn onto the next side, walked around rather than cut across.
		##
		## This was a single straight segment between the two corner points --
		## a 45-degree chamfer. The stylebox behind it is rounded, so the panel's
		## own corner sat *outside* the ink and the one place the eye looks for
		## the hand was the one place the line was provably machine-made.
		var start_angle := -PI * 0.5 + float(side) * PI * 0.5
		var arc_steps := maxi(int(radius * PI * 0.5 / SEGMENT_LENGTH) + 1, 4)
		for division in range(arc_steps):
			var angle := start_angle \
				+ PI * 0.5 * float(division) / float(arc_steps)
			step += 1
			## Wander applied along the radius, so the pen strays off the curve
			## the same way it strays off a straight -- perpendicular to travel.
			path.append(
				arc_centres[side]
					+ Vector2(cos(angle), sin(angle)) * (radius + _wander(step))
			)
	if path.size() > 0:
		path.append(path[0])
	return path


## What radius the surface underneath actually uses.
##
## Read from the parent's own stylebox rather than carried as a constant here:
## the two themes are free to round their panels differently, and a pen that
## turns at a radius the panel does not use traces an edge that is not there.
## `corner_radius` stays as the fallback for a parent with no flat stylebox.
func _resolved_radius() -> float:
	var parent := get_parent() as Control
	if parent == null:
		return corner_radius
	var variation := parent.theme_type_variation
	for style_name: StringName in [&"panel", &"normal"]:
		if not parent.has_theme_stylebox(style_name, variation):
			continue
		var box := parent.get_theme_stylebox(style_name, variation) as StyleBoxFlat
		if box != null:
			return float(box.corner_radius_top_left)
	return corner_radius


## How far off true the pen is at this point along the chain.
##
## Two hashed values at different rates summed, so the line drifts on a long
## wavelength and jitters on a short one -- a single frequency reads as a
## regular ripple, which is a spring rather than a hand.
func _wander(step: int) -> float:
	var slow := _unit(step / 3 + 1) - 0.5
	var fast := _unit(step + 977) - 0.5
	return (slow * 1.4 + fast * 0.6) * WANDER_PIXELS


## How much ink reached the paper on this segment.
##
## Cubed, so most of the stroke is fully inked and only occasionally does the
## ball run dry -- a linear draw would leave the whole line permanently patchy,
## which reads as a bad texture rather than as a pen. The slow term holds a dry
## stretch across several segments the way a real bearing does; the fast term is
## the grain within it.
func _coverage(index: int) -> float:
	var starve := _unit(index / COVERAGE_RUN + 313)
	var grain := _unit(index + 4409)
	var dry := pow(starve, 3.0) * 0.82 + pow(grain, 5.0) * 0.18
	return clampf(1.0 - COVERAGE_DEPTH * dry, 0.0, 1.0)


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
