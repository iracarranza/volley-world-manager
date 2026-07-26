class_name VolleyballPlayerAttributeWheel
extends Control

var axes: Array[String] = []
var profile: Dictionary = {}
var axis_tooltips: Dictionary = {}


func set_profile(new_profile: Dictionary, new_tooltips: Dictionary = {}) -> void:
	profile = new_profile.duplicate(true)
	axes.clear()
	for axis_name in profile:
		axes.append(str(axis_name))
	axis_tooltips = new_tooltips.duplicate(true)
	queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.29
	for index in range(axes.size()):
		var label_position := center + _axis_vector(index) * (radius + 25.0)
		if at_position.distance_to(label_position) <= 58.0:
			return "%s\n%s" % [axes[index], axis_tooltips.get(axes[index], "Derived from the player's underlying attributes.")]
	return "Hover an axis label to see its contributing attributes."


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or axes.size() < 3:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.29
	for ring_index in range(1, 5):
		var ring := PackedVector2Array()
		for index in range(axes.size()):
			ring.append(center + _axis_vector(index) * radius * float(ring_index) / 4.0)
		ring.append(ring[0])
		draw_polyline(ring, Color(0.35, 0.48, 0.65, 0.42), 1.0, true)
	var values := PackedVector2Array()
	for index in range(axes.size()):
		var direction := _axis_vector(index)
		draw_line(center, center + direction * radius, Color(0.42, 0.55, 0.72, 0.52), 1.0, true)
		values.append(center + direction * radius * clampf(float(profile.get(axes[index], 0)) / 100.0, 0.0, 1.0))
	if values.size() >= 3:
		draw_colored_polygon(values, Color(0.1, 0.55, 0.92, 0.28))
		var outline: PackedVector2Array = values.duplicate()
		outline.append(values[0])
		draw_polyline(outline, Color(0.3, 0.76, 1.0, 0.95), 2.0, true)
	var font := ThemeDB.fallback_font
	for index in range(axes.size()):
		var label := "%s %d" % [axes[index], int(profile.get(axes[index], 0))]
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var label_position := center + _axis_vector(index) * (radius + 25.0)
		label_position += Vector2(-label_size.x * 0.5, 6.0)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.86, 0.92, 1.0))


func _axis_vector(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * float(index) / float(axes.size())
	return Vector2(cos(angle), sin(angle))
