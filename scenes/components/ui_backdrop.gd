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
	var grid_color := Color(UIPalette.color(&"stroke", light_mode), 0.12)
	var accent_color := Color(UIPalette.color(&"accent_alt", light_mode), 0.10)
	var court_color := Color(UIPalette.color(&"accent", light_mode), 0.09)
	var grid_step := 56.0
	var offset := 18.0
	var x := offset
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += grid_step
	var y := offset
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += grid_step
	var court_size := Vector2(minf(size.x * 0.42, 560.0), minf(size.y * 0.72, 620.0))
	var court_rect := Rect2(
		Vector2(size.x - court_size.x * 0.74, size.y * 0.14), court_size
	)
	draw_rect(court_rect, court_color, false, 3.0)
	draw_line(
		Vector2(court_rect.position.x, court_rect.get_center().y),
		Vector2(court_rect.end.x, court_rect.get_center().y),
		court_color, 3.0,
	)
	draw_arc(
		Vector2(size.x * 0.12, size.y * 0.84), minf(size.x, size.y) * 0.22,
		-PI * 0.85, PI * 0.10, 48, accent_color, 18.0, true,
	)
