class_name VolleyballPlayerAttributeWheel
extends Control

signal expand_requested

const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const LEGEND_LINE_HEIGHT: float = 22.0
const EXPANDED_LEGEND_LINE_HEIGHT: float = 34.0

@export var expansion_enabled: bool = true
## Roster presentation uses the polygon itself as the key. Other compact
## contexts can retain the denser side legend until they are redesigned.
@export var inline_axis_labels: bool = false

var axes: Array[String] = []
var profile: Dictionary = {}
## Optional second dataset on the same axes, drawn as an outline behind the
## current one -- a player's potential rather than their current ability.
## Empty means no potential is known or relevant, and only the current shape
## draws, exactly as before this existed.
var potential_profile: Dictionary = {}
var axis_tooltips: Dictionary = {}
var show_grades: bool = true
var expanded_presentation: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL if expansion_enabled else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
		if expansion_enabled else Control.CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func set_expanded_presentation(expanded: bool) -> void:
	expanded_presentation = expanded
	queue_redraw()


func set_inline_axis_labels(enabled: bool) -> void:
	inline_axis_labels = enabled
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not expansion_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			expand_requested.emit()
			accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo \
				and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			expand_requested.emit()
			accept_event()


func set_profile(
	new_profile: Dictionary,
	new_tooltips: Dictionary = {},
	use_grades: bool = true,
	new_potential_profile: Dictionary = {},
) -> void:
	profile = new_profile.duplicate(true)
	potential_profile = new_potential_profile.duplicate(true)
	axes.clear()
	for axis_name in profile:
		axes.append(str(axis_name))
	axis_tooltips = new_tooltips.duplicate(true)
	show_grades = use_grades
	queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	var geometry := _geometry()
	var center: Vector2 = geometry.center
	var radius: float = geometry.radius
	if inline_axis_labels:
		for index in range(axes.size()):
			if _axis_label_rect(index, geometry).has_point(at_position):
				return _axis_tooltip(index)
		return "Hover an axis label for contributors." \
			+ (" Click to open the Attribute Lab." if expansion_enabled else "")
	var legend_line_height := _legend_line_height()
	for index in range(axes.size()):
		var legend_row := Rect2(
			float(geometry.legend_x),
			float(geometry.legend_y) + float(index) * legend_line_height,
			float(geometry.legend_width), legend_line_height,
		)
		var spoke_label := center + _axis_vector(index) \
			* (radius + (22.0 if expanded_presentation else 10.0))
		if legend_row.has_point(at_position) or at_position.distance_to(spoke_label) <= 14.0:
			return _axis_tooltip(index)
	return "Hover a numbered spoke or legend row for contributors." \
		+ (" Click to open the Attribute Lab." if expansion_enabled else "")


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or axes.size() < 3:
		return
	var geometry := _geometry()
	var center: Vector2 = geometry.center
	var radius: float = geometry.radius
	var font := ThemeDB.fallback_font
	var light_mode := UIPalette.control_is_light(self)
	var stroke := UIPalette.color(&"stroke", light_mode)
	var muted := UIPalette.color(&"ink_muted", light_mode)
	var ink := UIPalette.color(&"ink", light_mode)
	var accent := UIPalette.color(&"accent", light_mode)
	var current := UIPalette.color(&"accent_alt", light_mode)
	for ring_index in range(1, 5):
		var ring := PackedVector2Array()
		for index in range(axes.size()):
			ring.append(center + _axis_vector(index) * radius * float(ring_index) / 4.0)
		ring.append(ring[0])
		draw_polyline(
			ring, Color(stroke, 0.48),
			1.5 if expanded_presentation else 1.0, true,
		)
		if expanded_presentation:
			draw_string(
				font,
				center + Vector2(7.0, -radius * float(ring_index) / 4.0 + 4.0),
				str(ring_index * 25), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(muted, 0.8),
			)
	for index in range(axes.size()):
		draw_line(
			center, center + _axis_vector(index) * radius,
			Color(stroke, 0.56),
			1.5 if expanded_presentation else 1.0, true,
		)
	## Potential draws first, faint and behind, so the current shape stays the
	## thing the eye lands on. Ceilings are always at or beyond the current
	## value on every axis, so this outline never sits inside the current one.
	if not potential_profile.is_empty():
		var potential_values := PackedVector2Array()
		for index in range(axes.size()):
			potential_values.append(center + _axis_vector(index) * radius * clampf(
				float(potential_profile.get(axes[index], 0)) / 100.0, 0.0, 1.0
			))
		if potential_values.size() >= 3:
			draw_colored_polygon(
				potential_values,
				Color(accent, 0.15 if expanded_presentation else 0.10),
			)
			var potential_outline: PackedVector2Array = potential_values.duplicate()
			potential_outline.append(potential_values[0])
			draw_polyline(
				potential_outline, Color(accent, 0.9),
				3.5 if expanded_presentation else 2.0, true,
			)
	var values := PackedVector2Array()
	for index in range(axes.size()):
		values.append(center + _axis_vector(index) * radius * clampf(
			float(profile.get(axes[index], 0)) / 100.0, 0.0, 1.0
		))
	if values.size() >= 3:
		draw_colored_polygon(
			values, Color(current, 0.38 if expanded_presentation else 0.28)
		)
		var outline: PackedVector2Array = values.duplicate()
		outline.append(values[0])
		draw_polyline(
			outline, current,
			4.0 if expanded_presentation else 2.0, true,
		)
		if expanded_presentation:
			for point in values:
				draw_circle(point, 5.0, ink)
				draw_circle(point, 2.2, UIPalette.color(&"surface_inset", light_mode))
	if inline_axis_labels:
		_draw_inline_axis_labels(font, geometry)
		if expansion_enabled and not expanded_presentation:
			draw_string(
				font, Vector2(5.0, 13.0), "EXPAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(current, 0.72),
			)
		return
	var marker_font_size := 13 if expanded_presentation else 10
	for index in range(axes.size()):
		var marker := str(index + 1)
		var marker_size := font.get_string_size(
			marker, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_font_size
		)
		var marker_position := center + _axis_vector(index) \
			* (radius + (22.0 if expanded_presentation else 10.0))
		marker_position += Vector2(-marker_size.x * 0.5, marker_size.y * 0.35)
		draw_string(font, marker_position, marker, HORIZONTAL_ALIGNMENT_LEFT, -1,
			marker_font_size, muted)
	draw_line(
		Vector2(float(geometry.legend_x) - 7.0, 6.0),
		Vector2(float(geometry.legend_x) - 7.0, size.y - 6.0),
		Color(stroke, 0.45), 1.0,
	)
	var legend_font_size := 15 if expanded_presentation else (10 if size.x < 380.0 else 11)
	var legend_line_height := _legend_line_height()
	for index in range(axes.size()):
		var score := float(profile.get(axes[index], 0))
		var value_text := "%d %s" % [int(score), AttributeProfiles.grade(score)] \
			if expanded_presentation and show_grades \
			else (AttributeProfiles.grade(score) if show_grades else str(int(score)))
		if not potential_profile.is_empty():
			var potential_score := float(potential_profile.get(axes[index], 0))
			value_text += ("  >  %d %s" % [
				int(potential_score), AttributeProfiles.grade(potential_score),
			] if expanded_presentation and show_grades else "/%s" % (
				AttributeProfiles.grade(potential_score) if show_grades \
				else str(int(potential_score))
			))
		var baseline := float(geometry.legend_y) + float(index) * legend_line_height \
			+ (23.0 if expanded_presentation else 15.0)
		var value_width := 124.0 if expanded_presentation else 44.0
		var name_width := maxf(float(geometry.legend_width) - value_width - 4.0, 40.0)
		draw_string(
			font, Vector2(float(geometry.legend_x), baseline),
			"%d  %s" % [index + 1, axes[index]], HORIZONTAL_ALIGNMENT_LEFT,
			name_width, legend_font_size, ink,
		)
		draw_string(
			font, Vector2(float(geometry.legend_x) + name_width, baseline),
			value_text, HORIZONTAL_ALIGNMENT_RIGHT, value_width, legend_font_size,
			accent if not potential_profile.is_empty() else current,
		)
	if expansion_enabled and not expanded_presentation:
		draw_string(
			font, Vector2(5.0, 13.0), "EXPAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(current, 0.72),
		)


func _geometry() -> Dictionary:
	if inline_axis_labels:
		var label_margin_x := 142.0 if expanded_presentation else 92.0
		var label_margin_y := 58.0 if expanded_presentation else 38.0
		return {
			"center": Vector2(size.x * 0.5, size.y * 0.51),
			"radius": maxf(minf(
				size.x * 0.5 - label_margin_x,
				size.y * 0.5 - label_margin_y
			), 34.0),
			"legend_x": 0.0,
			"legend_y": 0.0,
			"legend_width": 0.0,
		}
	if expanded_presentation:
		var expanded_legend_width := clampf(size.x * 0.34, 300.0, 440.0)
		var expanded_wheel_width := size.x - expanded_legend_width
		return {
			"center": Vector2(expanded_wheel_width * 0.5, size.y * 0.5),
			"radius": maxf(minf(expanded_wheel_width * 0.43, size.y * 0.43), 60.0),
			"legend_x": expanded_wheel_width + 12.0,
			"legend_y": maxf(
				(size.y - float(axes.size()) * EXPANDED_LEGEND_LINE_HEIGHT) * 0.5, 8.0
			),
			"legend_width": expanded_legend_width - 20.0,
		}
	var legend_width := clampf(size.x * 0.48, 142.0, maxf(size.x - 130.0, 142.0))
	var wheel_width := size.x - legend_width
	var center := Vector2(wheel_width * 0.48, size.y * 0.5)
	var radius := maxf(minf(wheel_width * 0.34, size.y * 0.34), 28.0)
	return {
		"center": center,
		"radius": radius,
		"legend_x": wheel_width + 4.0,
		"legend_y": maxf((size.y - float(axes.size()) * LEGEND_LINE_HEIGHT) * 0.5, 4.0),
		"legend_width": legend_width - 8.0,
	}


func _legend_line_height() -> float:
	return EXPANDED_LEGEND_LINE_HEIGHT if expanded_presentation else LEGEND_LINE_HEIGHT


func _draw_inline_axis_labels(font: Font, geometry: Dictionary) -> void:
	var font_size := 16 if expanded_presentation else 11
	var label_color := UIPalette.color(&"ink", UIPalette.control_is_light(self))
	for index in range(axes.size()):
		var rect := _axis_label_rect(index, geometry)
		var axis_name := axes[index]
		var score := float(profile.get(axis_name, 0.0))
		var label := axis_name
		if expanded_presentation:
			label += "  %d %s" % [int(score), AttributeProfiles.grade(score)]
			if not potential_profile.is_empty():
				var potential_score := float(potential_profile.get(axis_name, 0.0))
				label += "  >  %d %s" % [
					int(potential_score), AttributeProfiles.grade(potential_score),
				]
		draw_string(
			font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.68),
			label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size,
			label_color,
		)


func _axis_label_rect(index: int, geometry: Dictionary) -> Rect2:
	var vector := _axis_vector(index)
	var width := 250.0 if expanded_presentation else 126.0
	var height := 30.0 if expanded_presentation else 22.0
	var distance := float(geometry.radius) + (34.0 if expanded_presentation else 23.0)
	var anchor := Vector2(geometry.center) + vector * distance
	## Pull top and bottom labels slightly inward; side labels have more room and
	## remain attached to their spoke without colliding with the popup boundary.
	if absf(vector.y) > 0.75:
		anchor.y += 8.0 if vector.y < 0.0 else -5.0
	return Rect2(anchor - Vector2(width * 0.5, height * 0.5), Vector2(width, height))


func _axis_tooltip(index: int) -> String:
	var axis_name := axes[index]
	var score := float(profile.get(axis_name, 0.0))
	var value_line := "Current: %d (%s)" % [int(score), AttributeProfiles.grade(score)]
	if not potential_profile.is_empty():
		var potential_score := float(potential_profile.get(axis_name, 0.0))
		value_line += "\nPotential: %d (%s)" % [
			int(potential_score), AttributeProfiles.grade(potential_score),
		]
	return "%s\n%s\n\n%s" % [
		axis_name, value_line,
		AttributeProfiles.axis_tooltip(
			axis_name, str(axis_tooltips.get(axis_name, ""))
		),
	]


func _axis_vector(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * float(index) / float(axes.size())
	return Vector2(cos(angle), sin(angle))
