class_name UIPaperTabs
extends Control

## A tab row as index tabs cut into the page.
##
## This was the last machine-made thing on the screen, and by the end it was
## the only one: a solid accent-filled lozenge with mathematically exact corners
## sitting on a page where every other surface is cut, sewn or written. It did
## not read as a different style so much as a different application.
##
## What a tab row *is* in a journal is a set of index tabs -- little flags cut
## into the top of a divider sheet, the one you are on standing forward with the
## page continuing out of it, and the others tucked behind it. That is exactly
## what a `TabContainer` means, and it needs no new idea: the same blade that
## cut the scroll windows cuts these.
##
## Drawn behind the `TabBar`'s own labels rather than replacing them, so the
## text, the hit testing, the keyboard traversal and the tab order stay with
## Godot's control. The theme reduces the stylebox to padding; everything with a
## colour in it is here.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The divider line the tabs are cut into -- the top edge of the sheet below.
const RULE_ALPHA: float = 0.50
const RULE_WIDTH: float = 1.3

## How the blade behaves. The same model as the panel edges and the scroll
## windows: held flat across a facet, stepped, occasionally nicked.
const CUT_FACET_PIXELS: float = 6.0
const CUT_DEPTH_PIXELS: float = 0.9
const CUT_NICK_CHANCE: float = 0.12
const CUT_NICK_PIXELS: float = 1.8

## The corner the tab is cut round at the top. Small: an index tab is snipped,
## not die-cut, so the corner is a couple of facets rather than an arc.
const TAB_CORNER: float = 7.0

## How far short of the row's full height an unselected tab sits.
##
## The whole of "one of these is in front" is here. A selected tab reaches the
## rule and opens into the page below it; the others stop above it and have the
## rule drawn straight across their feet, which puts them behind the sheet.
const TUCKED_DROP: float = 3.0

## How much the front tab lifts out of the page, and how far the rest sink into
## it. Small numbers, because these are sheets of paper and not buttons -- and
## the sink especially, because a tucked tab that goes properly dark stops
## reading as paper behind paper and starts reading as a disabled control.
const FRONT_LIFT: float = 0.14
const TUCKED_SINK: float = 0.13


var _bar: TabBar = null
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	## Behind the labels, not over them. A child `CanvasItem` draws after its
	## parent by default, which for a backing shape means painting out the very
	## text it is a backing for.
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar = get_parent() as TabBar
	if _bar == null:
		return
	_seed = int(String(_bar.name).hash() & 0x7FFFFFFF)
	_bar.tab_changed.connect(func(_index: int) -> void: queue_redraw())
	_bar.tab_selected.connect(func(_index: int) -> void: queue_redraw())
	_bar.resized.connect(queue_redraw)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if _bar == null or size.x < 8.0 or size.y < 8.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var ink := UIPalette.color(&"stroke_strong", light_mode)
	var paper := UIPalette.color(&"surface_raised", light_mode)
	var current := _bar.current_tab
	## The tucked tabs first, so the front one is drawn over their edges and the
	## stacking is done by draw order rather than by arithmetic.
	for index in range(_bar.tab_count):
		if index != current:
			_draw_tab(index, false, ink, paper, light_mode)
	## Then the rule, across the feet of everything behind.
	var rule := _cut_path(
		Vector2(0.0, size.y - RULE_WIDTH), Vector2(size.x, size.y - RULE_WIDTH),
		4409
	)
	draw_polyline(rule, Color(ink, RULE_ALPHA), RULE_WIDTH, true)
	## And the front tab last, which is what breaks the rule where it stands.
	if current >= 0 and current < _bar.tab_count:
		_draw_tab(current, true, ink, paper, light_mode)


## One index tab, cut out and either standing forward or tucked behind.
func _draw_tab(
	index: int, front: bool, ink: Color, paper: Color, light_mode: bool
) -> void:
	var rect := _bar.get_tab_rect(index)
	if rect.size.x < 6.0 or rect.size.y < 6.0:
		return
	var top := rect.position.y + (0.0 if front else TUCKED_DROP)
	var foot := size.y
	var salt := 977 + index * 613
	## Down the left side, across the top with its two snipped corners, and back
	## down the right. Open at the bottom: a tab is part of the sheet it belongs
	## to, so there is no line where they meet -- and for the front tab that
	## opening is what lets it join the page below.
	var outline := PackedVector2Array()
	outline.append_array(
		_cut_path(Vector2(rect.position.x, foot), Vector2(rect.position.x, top + TAB_CORNER), salt)
	)
	outline.append_array(
		_cut_path(
			Vector2(rect.position.x + TAB_CORNER, top),
			Vector2(rect.end.x - TAB_CORNER, top), salt + 101
		)
	)
	outline.append_array(
		_cut_path(Vector2(rect.end.x, top + TAB_CORNER), Vector2(rect.end.x, foot), salt + 211)
	)
	## The fill closes across the bottom; the drawn edge does not.
	var filled := outline.duplicate()
	filled.append(Vector2(rect.position.x, foot))
	## The front tab is a sheet closer to the light, the tucked ones are further
	## from it. On paper "closer to the light" means nearer white; on the dark
	## page it means nearer the accent's own value -- but in both it is the same
	## claim, and the lift is small because these are sheets and not buttons.
	## Asymmetric between the themes, because the two pages give a sheet very
	## different room to move. On the dark page there is a long way down before
	## paper stops looking like paper, and the drawn edge is faint enough that
	## the tucked tabs need the tone to separate them. On cream there is almost
	## nowhere to go: a tenth of the way to black is already grey card rather
	## than a sheet in shadow, and the ink is dark enough to do the separating on
	## its own.
	var shade := paper.lightened(FRONT_LIFT * (4.0 if light_mode else 1.0)) \
		if front else paper.darkened(TUCKED_SINK * (0.6 if light_mode else 1.0))
	draw_colored_polygon(filled, shade)
	draw_polyline(
		outline, Color(ink, 0.75 if front else 0.42), RULE_WIDTH, true
	)


## A blade's path between two points.
##
## Offset perpendicular to travel, held flat across a facet and then stepped --
## never interpolated, because smoothing the step out is what turns a cut back
## into a wobbly drawn line.
func _cut_path(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var span := from.distance_to(to)
	var normal := (to - from).normalized().orthogonal() if span > 0.001 \
		else Vector2.RIGHT
	var facets := maxi(int(span / CUT_FACET_PIXELS), 1)
	var path := PackedVector2Array()
	for step in range(facets + 1):
		var facet := mini(step, facets - 1)
		var offset := (_unit(salt + facet * 37) - 0.5) * 2.0 * CUT_DEPTH_PIXELS
		if _unit(salt + facet * 37 + 5) < CUT_NICK_CHANCE:
			offset -= _unit(salt + facet * 37 + 11) * CUT_NICK_PIXELS
		path.append(
			from.lerp(to, float(step) / float(facets)) + normal * offset
		)
	return path


## A stable 0-1 from this row's seed and a step along a cut. Hand-mixed rather
## than `randf()`, so a tab is cut the same way every frame and every run.
func _unit(step: int) -> float:
	var accumulated := (_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0
