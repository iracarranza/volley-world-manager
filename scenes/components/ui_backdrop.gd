class_name VolleyballUIBackdrop
extends ColorRect

const UIPalette := preload("res://scripts/data/ui_palette.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	var light_mode := UIPalette.control_is_light(self)
	var stroke := Color(UIPalette.color(&"stroke", light_mode), 0.18)
	var ink := Color(UIPalette.color(&"ink_muted", light_mode), 0.16)
	var accent := Color(UIPalette.color(&"accent", light_mode), 0.15)
	var accent_alt := Color(UIPalette.color(&"accent_alt", light_mode), 0.13)

	# Loose notebook ruling reads softer than a precise application grid.
	var y := 31.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y + 5.0), stroke, 1.0)
		y += 64.0

	_draw_scrap(Vector2(size.x * 0.74, size.y * 0.10), Vector2(430.0, 270.0), -0.055, accent_alt)
	_draw_scrap(Vector2(size.x * 0.06, size.y * 0.68), Vector2(320.0, 190.0), 0.075, accent)
	_draw_court_doodle(Vector2(size.x * 0.73, size.y * 0.18), light_mode)
	_draw_ball_doodle(Vector2(size.x * 0.13, size.y * 0.79), minf(size.x, size.y) * 0.105, ink)
	_draw_starburst(Vector2(size.x * 0.58, size.y * 0.12), 30.0, 15.0, accent)
	_draw_stitches(Vector2(size.x * 0.43, size.y * 0.91), 190.0, ink)


func _draw_scrap(origin: Vector2, scrap_size: Vector2, angle: float, color: Color) -> void:
	draw_set_transform(origin, angle)
	var points := PackedVector2Array([
		Vector2(-9.0, 5.0), Vector2(scrap_size.x - 5.0, -7.0),
		Vector2(scrap_size.x + 7.0, scrap_size.y + 4.0),
		Vector2(4.0, scrap_size.y - 2.0),
	])
	draw_colored_polygon(points, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(scrap_size.x * 0.18 - 38.0, -17.0),
		Vector2(scrap_size.x * 0.18 + 35.0, -20.0),
		Vector2(scrap_size.x * 0.18 + 40.0, 2.0),
		Vector2(scrap_size.x * 0.18 - 34.0, 4.0),
	]), Color(color.lightened(0.65), 0.22))
	draw_colored_polygon(PackedVector2Array([
		Vector2(scrap_size.x * 0.72 - 38.0, scrap_size.y - 13.0),
		Vector2(scrap_size.x * 0.72 + 35.0, scrap_size.y - 16.0),
		Vector2(scrap_size.x * 0.72 + 40.0, scrap_size.y + 6.0),
		Vector2(scrap_size.x * 0.72 - 34.0, scrap_size.y + 8.0),
	]), Color(color.lightened(0.55), 0.20))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_court_doodle(origin: Vector2, light_mode: bool) -> void:
	var line_color := Color(UIPalette.color(&"accent", light_mode), 0.20)
	draw_set_transform(origin, -0.045)
	var court := Rect2(Vector2.ZERO, Vector2(365.0, 224.0))
	draw_rect(court, line_color, false, 4.0)
	draw_rect(court.grow(-7.0), Color(line_color, 0.10), false, 2.0)
	draw_line(Vector2(0.0, 112.0), Vector2(365.0, 109.0), line_color, 4.0)
	draw_line(Vector2(120.0, 0.0), Vector2(124.0, 224.0), line_color, 2.0)
	draw_line(Vector2(242.0, 0.0), Vector2(238.0, 224.0), line_color, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_ball_doodle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, Color(color, 0.045))
	draw_arc(center, radius, 0.0, TAU, 48, color, 4.0, true)
	draw_arc(center + Vector2(-radius * 0.42, 0.0), radius * 0.82, -1.2, 1.2, 24, color, 3.0, true)
	draw_arc(center + Vector2(radius * 0.32, 0.0), radius * 0.84, 1.9, 4.4, 24, color, 3.0, true)


func _draw_starburst(center: Vector2, outer: float, inner: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var radius := outer if index % 2 == 0 else inner
		var angle := TAU * float(index) / 16.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _draw_stitches(origin: Vector2, length: float, color: Color) -> void:
	for index in range(9):
		var x := origin.x + length * float(index) / 8.0
		var wobble := 4.0 if index % 2 == 0 else -3.0
		draw_line(Vector2(x, origin.y + wobble), Vector2(x + 11.0, origin.y - wobble), color, 3.0)
