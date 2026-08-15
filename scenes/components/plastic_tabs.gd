class_name UIPlasticTabs
extends Control

## Binder dividers, in translucent plastic.
##
## `UIPaperTabs` cuts index tabs into the page, which is right for the journal --
## a tab there is part of the sheet it belongs to. A clipboard's dividers are not
## part of anything: they are the coloured plastic ones out of a packet of five,
## punched and dropped in, and the whole reason anyone buys them over card is that
## **you can read the page through them**.
##
## So the two materials disagree on every property and this is not a restyle of
## the other one:
##
## | | paper tab | plastic divider |
## |---|---|---|
## | edge | cut, stepped, occasionally nicked | moulded, a clean radius |
## | body | opaque | translucent, tinted, and darker where it laps the page |
## | tint | the page's own | a colour from the packet, per tab |
## | wear | torn | scuffed, and creased where it has been folded back |
##
## The translucency is the load-bearing one. A tucked divider shows the sheet
## behind it dimmed and tinted rather than hidden, which is what puts it *behind*
## the page without needing the tone trick the paper tabs use.
##
## Drawn behind the `TabBar`'s own labels, like the paper version, so text, hit
## testing and keyboard traversal all stay with Godot's control.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The packet. Five colours in the order they come, so a two-tab row is always
## the first two and adding a third does not reshuffle the first two.
const PACKET: Array[Color] = [
	Color(0.28, 0.55, 0.62),
	Color(0.82, 0.62, 0.24),
	Color(0.55, 0.36, 0.62),
	Color(0.42, 0.63, 0.38),
	Color(0.78, 0.42, 0.36),
]

## How much of the page shows through. The front divider is held flat against the
## sheet so it reads denser; a tucked one is lifted and catches more light.
const FRONT_ALPHA: float = 0.50
const TUCKED_ALPHA: float = 0.30

## A moulded corner, not a snipped one.
const CORNER: float = 6.0
const CORNER_STEPS: int = 5

## How far short of the row a tucked divider sits.
const TUCKED_DROP: float = 3.0

## The bright line along a moulded edge, which is most of what says "plastic"
## rather than "coloured rectangle".
const SHEEN_ALPHA: float = 0.55
const RULE_WIDTH: float = 1.2

var _bar: TabBar = null
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
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
	var current := _bar.current_tab
	for index in range(_bar.tab_count):
		if index != current:
			_draw_divider(index, false, light_mode)
	## The rule across the feet of everything tucked behind, drawn straight --
	## a moulded sheet does not sit in a cut, so there is nothing to step.
	draw_line(
		Vector2(0.0, size.y - RULE_WIDTH), Vector2(size.x, size.y - RULE_WIDTH),
		Color(UIPalette.color(&"stroke_strong", light_mode), 0.38), RULE_WIDTH
	)
	if current >= 0 and current < _bar.tab_count:
		_draw_divider(current, true, light_mode)


func _draw_divider(index: int, front: bool, light_mode: bool) -> void:
	var rect := _bar.get_tab_rect(index)
	if rect.size.x < 6.0 or rect.size.y < 6.0:
		return
	var top := rect.position.y + (0.0 if front else TUCKED_DROP)
	var body := Rect2(
		Vector2(rect.position.x, top), Vector2(rect.size.x, size.y - top)
	)
	var tint := PACKET[index % PACKET.size()]
	## The same plastic in both themes -- a coloured sheet is a coloured sheet --
	## but on the dark page it has to give back more than it takes, or a
	## translucent tab over a near-black page is simply a darker hole.
	if not light_mode:
		tint = tint.lightened(0.10)
	var outline := _moulded(body)

	draw_colored_polygon(outline, Color(tint, FRONT_ALPHA if front else TUCKED_ALPHA))
	## Where the divider laps over the sheet below it, the overlap is denser --
	## two thicknesses of the same plastic. Only the tucked ones have it, because
	## the front one is what everything else laps *onto*.
	if not front:
		draw_colored_polygon(
			_moulded(Rect2(body.position, Vector2(body.size.x, 6.0))),
			Color(tint, 0.16)
		)
	## The moulded edge: a bright line down the lit side and along the top, and a
	## darker one opposite. Plastic has an edge that catches light along its whole
	## length, which is the difference between a sheet and a fill.
	draw_polyline(
		outline, Color(tint.lightened(0.55), SHEEN_ALPHA if front else SHEEN_ALPHA * 0.6),
		RULE_WIDTH, true
	)
	draw_polyline(
		outline, Color(tint.darkened(0.45), 0.40), RULE_WIDTH * 0.6, true
	)
	## A crease across the front divider, where it has been folded back over the
	## clamp more than once. Only the front one, because it is the one that gets
	## handled.
	if front and body.size.y > 16.0:
		var crease := body.position.y + body.size.y * 0.62
		draw_line(
			Vector2(body.position.x + 3.0, crease),
			Vector2(body.end.x - 3.0, crease),
			Color(tint.lightened(0.70), 0.22), 1.0
		)


## The outline of a divider: square at the foot, radiused at the two top corners.
func _moulded(rect: Rect2) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(Vector2(rect.position.x, rect.end.y))
	path.append(Vector2(rect.position.x, rect.position.y + CORNER))
	for step in range(CORNER_STEPS + 1):
		var angle := PI + (PI * 0.5) * float(step) / float(CORNER_STEPS)
		path.append(
			Vector2(rect.position.x + CORNER, rect.position.y + CORNER)
				+ Vector2(cos(angle), sin(angle)) * CORNER
		)
	for step in range(CORNER_STEPS + 1):
		var angle := -(PI * 0.5) + (PI * 0.5) * float(step) / float(CORNER_STEPS)
		path.append(
			Vector2(rect.end.x - CORNER, rect.position.y + CORNER)
				+ Vector2(cos(angle), sin(angle)) * CORNER
		)
	path.append(Vector2(rect.end.x, rect.end.y))
	return path
