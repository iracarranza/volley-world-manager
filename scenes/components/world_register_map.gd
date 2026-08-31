class_name WorldRegisterMap
extends Control

## Player-facing projection of the canonical world surface.
##
## This control authors no geography. Terrain comes from WorldGeography,
## political occupancy and label anchors come from WorldPoliticalGeography, and
## every screen position comes from WorldSurfaceMapper. The same surface can be
## inspected as regions, terrain, or seams without maintaining a second map.

const Topology := preload("res://scripts/data/world_panel_topology.gd")
const Mapper := preload("res://scripts/world/world_surface_mapper.gd")
const Geography := preload("res://scripts/data/world_geography.gd")
const Politics := preload("res://scripts/data/world_political_geography.gd")
const Palette := preload("res://scripts/data/ui_palette.gd")

signal region_selected(region_name: String)

const MODE_REGIONS: StringName = &"regions"
const MODE_TERRAIN: StringName = &"terrain"
const MODE_SEAMS: StringName = &"seams"
const GRID_U := 8
const GRID_V := 24
const MAP_PADDING := 12.0

const TERRAIN_COLORS := {
	"deep_ocean": Color("0b2638"),
	"shelf": Color("1b4c60"),
	"volcanic": Color("8c5749"),
	"glacial": Color("9bb9b6"),
	"cold_highland": Color("71878a"),
	"dry_plateau": Color("8f7b5f"),
	"arid": Color("ad9367"),
	"river_lowland": Color("668c72"),
	"highland": Color("71806a"),
	"wet_lowland": Color("4f7d69"),
	"temperate": Color("718a6d"),
}

var _mode: StringName = MODE_REGIONS
var _selected_region := "Landavol"
var _hover_region := ""


func _ready() -> void:
	custom_minimum_size = Vector2(600, 430)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_mode(mode_name: StringName) -> void:
	if mode_name not in [MODE_REGIONS, MODE_TERRAIN, MODE_SEAMS]:
		return
	_mode = mode_name
	queue_redraw()


func mode() -> StringName:
	return _mode


func set_selected_region(region_name: String) -> void:
	if not Politics.all_regions().has(region_name):
		return
	_selected_region = region_name
	queue_redraw()


func selected_region() -> String:
	return _selected_region


func regions() -> Array:
	return Politics.all_regions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	var light := Palette.control_is_light(self)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(&"surface_inset", light))
	_draw_surface(light)
	_draw_seams(light)
	if _mode != MODE_TERRAIN:
		_draw_region_labels(light)


func _draw_surface(light: bool) -> void:
	for panel_id in Topology.PANEL_IDS:
		for ux in range(GRID_U):
			for vy in range(GRID_V):
				var uv0 := Vector2(float(ux) / GRID_U, float(vy) / GRID_V)
				var uv1 := Vector2(float(ux + 1) / GRID_U, float(vy + 1) / GRID_V)
				var center := (uv0 + uv1) * 0.5
				var world := Mapper.panel_uv_to_world(panel_id, center)
				var sample := Geography.sample_world(world)
				var color := _terrain_color(String(sample.get("terrain", "temperate")), light)
				if _mode == MODE_SEAMS:
					color = color.lerp(Palette.color(&"surface", light), 0.46)
				var political_region := Politics.region_at(world)
				if _mode == MODE_REGIONS and not political_region.is_empty():
					var overlay := Palette.color(&"ink", light)
					overlay.a = 0.045
					color = color.blend(overlay)
					if political_region == _selected_region:
						var selected := Palette.color(&"accent", light)
						selected.a = 0.24
						color = color.blend(selected)
					elif political_region == _hover_region:
						var hovered := Palette.color(&"accent_alt", light)
						hovered.a = 0.16
						color = color.blend(hovered)
				var points := PackedVector2Array([
					_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, uv0)),
					_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(uv1.x, uv0.y))),
					_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, uv1)),
					_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(uv0.x, uv1.y))),
				])
				draw_colored_polygon(points, color)


func _draw_seams(light: bool) -> void:
	var color := Palette.color(&"stroke_strong", light)
	color.a = 0.72 if _mode == MODE_SEAMS else 0.24
	var width := 2.2 if _mode == MODE_SEAMS else 1.15
	for panel_id in Topology.PANEL_IDS:
		var corners := PackedVector2Array([
			_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(0, 0))),
			_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(1, 0))),
			_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(1, 1))),
			_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(0, 1))),
			_flat_to_screen(Mapper.panel_uv_to_flat(panel_id, Vector2(0, 0))),
		])
		draw_polyline(corners, color, width, true)


func _draw_region_labels(light: bool) -> void:
	var font := get_theme_default_font()
	for region_name in Politics.all_regions():
		var name := String(region_name)
		var anchor := Politics.label_anchor(name)
		if anchor.is_empty():
			continue
		var pos := _flat_to_screen(Mapper.panel_uv_to_flat(
			String(anchor.get("panel", "")), Vector2(anchor.get("uv", Vector2.ZERO))
		))
		var selected: bool = name == _selected_region
		var hovered: bool = name == _hover_region
		var dot_color := Palette.color(&"accent", light) if selected \
			else Palette.color(&"accent_alt", light) if hovered \
			else Palette.color(&"ink", light)
		var text_color := dot_color
		if not selected and not hovered:
			text_color.a = 0.88
		draw_circle(pos, 3.6 if selected else 2.5, dot_color)
		var font_size := 14 if selected else 12
		draw_string(
			font, pos + Vector2(-72, -7), name,
			HORIZONTAL_ALIGNMENT_CENTER, 144.0, font_size, text_color
		)


func _terrain_color(terrain: String, light: bool) -> Color:
	var color := Color(TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["temperate"]))
	if light:
		color = color.lightened(0.18)
	return color


func _layout() -> Dictionary:
	var usable := size - Vector2(MAP_PADDING * 2.0, MAP_PADDING * 2.0)
	var scale := minf(
		usable.x / Mapper.FLAT_SIZE.x,
		usable.y / Mapper.FLAT_SIZE.y
	)
	var drawn := Mapper.FLAT_SIZE * scale
	var origin := Vector2(
		(size.x - drawn.x) * 0.5,
		(size.y - drawn.y) * 0.5
	)
	return {"origin": origin, "scale": scale}


func _flat_to_screen(flat: Vector2) -> Vector2:
	var layout := _layout()
	var origin: Vector2 = layout["origin"]
	var scale: float = float(layout["scale"])
	return Vector2(
		origin.x + flat.x * scale,
		origin.y + (Mapper.FLAT_SIZE.y - flat.y) * scale
	)


func _screen_to_flat(screen_point: Vector2) -> Vector2:
	var layout := _layout()
	var origin: Vector2 = layout["origin"]
	var scale: float = float(layout["scale"])
	return Vector2(
		(screen_point.x - origin.x) / scale,
		Mapper.FLAT_SIZE.y - (screen_point.y - origin.y) / scale
	)


func _flat_to_panel_uv(flat: Vector2) -> Dictionary:
	for panel_id in Topology.PANEL_IDS:
		var p00 := Mapper.panel_uv_to_flat(panel_id, Vector2(0, 0))
		var a := Mapper.panel_uv_to_flat(panel_id, Vector2(1, 0)) - p00
		var b := Mapper.panel_uv_to_flat(panel_id, Vector2(0, 1)) - p00
		var q := flat - p00
		var det := a.x * b.y - a.y * b.x
		if absf(det) < 0.000001:
			continue
		var u := (q.x * b.y - q.y * b.x) / det
		var v := (a.x * q.y - a.y * q.x) / det
		if u >= -0.0001 and u <= 1.0001 and v >= -0.0001 and v <= 1.0001:
			return {
				"panel": panel_id,
				"uv": Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0)),
			}
	return {}


func _region_at_screen(screen_point: Vector2) -> String:
	var hit := _flat_to_panel_uv(_screen_to_flat(screen_point))
	if hit.is_empty():
		return ""
	var world := Mapper.panel_uv_to_world(String(hit["panel"]), Vector2(hit["uv"]))
	return Politics.region_at(world)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var region := _region_at_screen((event as InputEventMouseMotion).position)
		if region != _hover_region:
			_hover_region = region
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
				if not region.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		var region := _region_at_screen(mouse.position)
		if region.is_empty():
			return
		set_selected_region(region)
		region_selected.emit(region)
		accept_event()
