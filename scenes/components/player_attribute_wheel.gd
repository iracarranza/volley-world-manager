class_name VolleyballPlayerAttributeWheel
extends Control

const AXES: Array[String] = ["Physical", "Serve", "Reception", "Setting", "Attack", "Defense / IQ"]
const AXIS_TOOLTIPS := {
	"Physical": "Acceleration, lateral speed, transition speed, jump reach, explosiveness, stamina",
	"Serve": "Serve power, serve accuracy",
	"Reception": "Reception, reception balance, reception stability, ball control",
	"Setting": "Set accuracy, set balance, set stability, court vision",
	"Attack": "Attack power, attack accuracy, approach timing",
	"Defense / IQ": "Block timing, anticipation, decision-making, composure, tactical discipline, improvisation",
}

var profile: Dictionary = {}


func set_profile(new_profile: Dictionary) -> void:
	profile = new_profile.duplicate(true)
	queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.29
	for index in range(AXES.size()):
		var label_position := center + _axis_vector(index) * (radius + 25.0)
		if at_position.distance_to(label_position) <= 58.0:
			return "%s\n%s" % [AXES[index], AXIS_TOOLTIPS[AXES[index]]]
	return "Hover an axis label to see its contributing attributes."


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.29
	for ring_index in range(1, 5):
		var ring := PackedVector2Array()
		for index in range(AXES.size()):
			ring.append(center + _axis_vector(index) * radius * float(ring_index) / 4.0)
		ring.append(ring[0])
		draw_polyline(ring, Color(0.35, 0.48, 0.65, 0.42), 1.0, true)
	var values := PackedVector2Array()
	for index in range(AXES.size()):
		var direction := _axis_vector(index)
		draw_line(center, center + direction * radius, Color(0.42, 0.55, 0.72, 0.52), 1.0, true)
		values.append(center + direction * radius * clampf(float(profile.get(AXES[index], 0)) / 100.0, 0.0, 1.0))
	if values.size() >= 3:
		draw_colored_polygon(values, Color(0.1, 0.55, 0.92, 0.28))
		var outline: PackedVector2Array = values.duplicate()
		outline.append(values[0])
		draw_polyline(outline, Color(0.3, 0.76, 1.0, 0.95), 2.0, true)
	var font := ThemeDB.fallback_font
	for index in range(AXES.size()):
		var label := "%s %d" % [AXES[index], int(profile.get(AXES[index], 0))]
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var label_position := center + _axis_vector(index) * (radius + 25.0)
		label_position += Vector2(-label_size.x * 0.5, 6.0)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.86, 0.92, 1.0))


func _axis_vector(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * float(index) / float(AXES.size())
	return Vector2(cos(angle), sin(angle))
