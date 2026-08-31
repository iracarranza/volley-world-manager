class_name WorldRegisterGlobe
extends Control

## Interactive player-facing globe built entirely from canonical world data.
##
## Panel tessellation is mapped through WorldSurfaceMapper. Terrain and political
## ownership are sampled in world space, while the only mutable transform is the
## presentation root. The flat WorldRegisterMap remains available as a proof and
## debugging view; it is not used to draw this component.

const Topology := preload("res://scripts/data/world_panel_topology.gd")
const Mapper := preload("res://scripts/world/world_surface_mapper.gd")
const Geography := preload("res://scripts/data/world_geography.gd")
const Politics := preload("res://scripts/data/world_political_geography.gd")
const Palette := preload("res://scripts/data/ui_palette.gd")

signal region_selected(region_name: String)

const MODE_REGIONS: StringName = &"regions"
const MODE_TERRAIN: StringName = &"terrain"
const MODE_SEAMS: StringName = &"seams"

const PANEL_U_STEPS := 24
const PANEL_V_STEPS := 72
const SEAM_STEPS := 32
const GLOBE_RADIUS := 1.0
const POLITICAL_RADIUS := 1.006
const HIGHLIGHT_RADIUS := 1.013
const SEAM_RADIUS := 1.018
const SEAM_HALF_WIDTH := 0.0048
const DRAG_THRESHOLD := 5.0
const ROTATION_SPEED := 0.008
const MIN_CAMERA_DISTANCE := 2.55
const MAX_CAMERA_DISTANCE := 4.10

const TERRAIN_COLORS := {
	"deep_ocean": Color("102f46"),
	"shelf": Color("24677a"),
	"volcanic": Color("985e4e"),
	"glacial": Color("b7d0cc"),
	"cold_highland": Color("81969a"),
	"dry_plateau": Color("9b8566"),
	"arid": Color("bd9d68"),
	"river_lowland": Color("68a07c"),
	"highland": Color("74866b"),
	"wet_lowland": Color("4c876d"),
	"temperate": Color("73926f"),
}

const REGION_COLORS := [
	Color("d2aa62"), Color("d8c77b"), Color("7db2bf"), Color("78a98b"),
	Color("b58d72"), Color("d08274"), Color("9484bc"), Color("d5a06d"),
	Color("8eb16f"), Color("74a9a5"), Color("b889ac"), Color("cfbd73"),
	Color("789ec4"), Color("be8677"),
]

## Presentation offsets only. Every anchor still comes from political geography.
const LABEL_OFFSETS := {
	"Landavol": Vector2(-28, -18),
	"Zaitgaist": Vector2(34, 16),
	"Spëddigh": Vector2(-16, -18),
	"Rhėn Tempaol": Vector2(-38, 12),
	"Ĭspayk": Vector2(28, 12),
	"Tãul ys Feynt": Vector2(-34, -12),
	"Lo-ong Ralī": Vector2(-20, 12),
}

static var _terrain_mesh_cache: ArrayMesh
static var _political_mesh_cache: ArrayMesh
static var _region_mesh_cache: Dictionary = {}
static var _seam_mesh_cache: ArrayMesh
static var _panel_vertex_counts_cache: Dictionary = {}
static var _unique_panel_edges_cache: Array[Dictionary] = []

var _mode: StringName = MODE_REGIONS
var _selected_region := "Landavol"
var _hover_region := ""
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _globe_root: Node3D
var _camera: Camera3D
var _terrain_instance: MeshInstance3D
var _political_instance: MeshInstance3D
var _seam_instance: MeshInstance3D
var _region_instances: Dictionary = {}
var _terrain_material: StandardMaterial3D
var _political_material: StandardMaterial3D
var _seam_material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _hover_material: StandardMaterial3D
var _labels_layer: Control
var _label_buttons: Dictionary = {}
var _press_position := Vector2.ZERO
var _dragging := false
var _pointer_down := false
var _camera_distance := 3.15


func _ready() -> void:
	custom_minimum_size = Vector2(560, 430)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_ensure_cached_geometry()
	_build_scene()
	_build_labels()
	focus_region("Landavol")
	_apply_mode()
	set_process(true)


func _process(_delta: float) -> void:
	_update_labels()


func set_mode(mode_name: StringName) -> void:
	if mode_name not in [MODE_REGIONS, MODE_TERRAIN, MODE_SEAMS]:
		return
	_mode = mode_name
	_apply_mode()


func mode() -> StringName:
	return _mode


func set_selected_region(region_name: String) -> void:
	if not Politics.all_regions().has(region_name):
		return
	_selected_region = region_name
	_update_region_visibility()


func selected_region() -> String:
	return _selected_region


func regions() -> Array:
	return Politics.all_regions()


func focus_region(region_name: String) -> void:
	var direction := Politics.region_center_world(region_name)
	if direction.length_squared() < 0.9 or _globe_root == null:
		return
	_globe_root.quaternion = Quaternion(direction.normalized(), Vector3.BACK)


func set_presentation_rotation_degrees(rotation_degrees_value: Vector3) -> void:
	if _globe_root != null:
		_globe_root.rotation_degrees = rotation_degrees_value


func presentation_rotation() -> Quaternion:
	return _globe_root.quaternion if _globe_root != null else Quaternion.IDENTITY


static func world_direction_to_region(direction: Vector3) -> String:
	if direction.length_squared() < 0.000001:
		return ""
	return Politics.region_at(direction.normalized())


static func canonical_panel_count() -> int:
	return Topology.PANEL_IDS.size()


static func panel_vertex_counts() -> Dictionary:
	_ensure_cached_geometry()
	return _panel_vertex_counts_cache.duplicate()


static func unique_seam_count() -> int:
	_ensure_cached_geometry()
	return _unique_panel_edges_cache.size()


static func terrain_front_faces_are_outward() -> bool:
	_ensure_cached_geometry()
	var arrays := _terrain_mesh_cache.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(0, vertices.size(), 3):
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		## Godot's spatial front face is clockwise. From outside the sphere that
		## means the mathematical cross product points inward (negative radial
		## dot), while the authored vertex normals still point outward for light.
		if (b - a).cross(c - a).dot(a + b + c) >= -0.000001:
			return false
	return true


static func seam_sample_directions() -> Array[Vector3]:
	_ensure_cached_geometry()
	var result: Array[Vector3] = []
	for edge in _unique_panel_edges_cache:
		for t in [0.0, 0.5, 1.0]:
			var edge_t := lerpf(float(edge.t0), float(edge.t1), float(t))
			result.append(_panel_edge_world(String(edge.panel), String(edge.edge), edge_t))
	return result


func _build_scene() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "GlobeViewportContainer"
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "GlobeViewport"
	_viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport_container.add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "WorldRegisterScene"
	_viewport.add_child(_world_root)
	_globe_root = Node3D.new()
	_globe_root.name = "CanonicalGlobePresentation"
	_world_root.add_child(_globe_root)

	_terrain_material = _make_surface_material(false)
	_terrain_instance = _mesh_instance("CanonicalTerrain", _terrain_mesh_cache, _terrain_material)
	_globe_root.add_child(_terrain_instance)

	_political_material = _make_overlay_material(0.40)
	_political_instance = _mesh_instance("CanonicalPoliticalFootprints", _political_mesh_cache, _political_material)
	_globe_root.add_child(_political_instance)

	_highlight_material = _make_overlay_material(0.84)
	_highlight_material.albedo_color = Color("f3d477")
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color("5b4818")
	_highlight_material.emission_energy_multiplier = 0.72
	_hover_material = _make_overlay_material(0.58)
	_hover_material.albedo_color = Color("65d6ce")
	for region_name in Politics.all_regions():
		var instance := _mesh_instance(
			"Selected_%s" % String(region_name).validate_node_name(),
			_region_mesh_cache.get(region_name), _highlight_material
		)
		instance.visible = false
		_globe_root.add_child(instance)
		_region_instances[region_name] = instance

	_seam_material = _make_overlay_material(0.26)
	_seam_material.albedo_color = Color("eadfc2")
	_seam_instance = _mesh_instance("CanonicalPanelSeams", _seam_mesh_cache, _seam_material)
	_globe_root.add_child(_seam_instance)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101b22")
	env.background_energy_multiplier = 0.25
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9cad0")
	env.ambient_light_energy = 0.66
	environment.environment = env
	_world_root.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28, -32, 0)
	key_light.light_color = Color("fff2d2")
	key_light.light_energy = 1.05
	key_light.shadow_enabled = false
	_world_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(24, 146, 0)
	fill_light.light_color = Color("94b9d0")
	fill_light.light_energy = 0.36
	_world_root.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.name = "GlobeCamera"
	_camera.position = Vector3(0, 0, _camera_distance)
	_camera.fov = 42.0
	_camera.near = 0.1
	_camera.far = 20.0
	_camera.current = true
	_world_root.add_child(_camera)


func _build_labels() -> void:
	_labels_layer = Control.new()
	_labels_layer.name = "CanonicalRegionLabels"
	_labels_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_labels_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels_layer)
	for region_name in Politics.all_regions():
		var name := String(region_name)
		var button := Button.new()
		button.name = "Label_%s" % name.validate_node_name()
		button.text = name
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 11)
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.025, 0.065, 0.09, 0.78)
		normal_style.border_color = Color(0.37, 0.55, 0.60, 0.55)
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(7)
		normal_style.content_margin_left = 7
		normal_style.content_margin_right = 7
		normal_style.content_margin_top = 3
		normal_style.content_margin_bottom = 3
		var hover_style := normal_style.duplicate()
		hover_style.bg_color = Color(0.08, 0.20, 0.24, 0.94)
		hover_style.border_color = Palette.color(&"accent_alt", false)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func() -> void:
			set_selected_region(name)
			region_selected.emit(name)
		)
		_labels_layer.add_child(button)
		_label_buttons[name] = button


func _update_labels() -> void:
	if _camera == null or _globe_root == null:
		return
	var show_labels := _mode == MODE_REGIONS
	for region_name in _label_buttons:
		var button: Button = _label_buttons[region_name]
		var canonical := Politics.region_center_world(String(region_name))
		var presented := _globe_root.transform.basis * canonical
		var front := presented.z > 0.07
		button.visible = show_labels and front
		if not button.visible:
			continue
		var world_position := _globe_root.to_global(canonical * 1.045)
		var projected := _camera.unproject_position(world_position)
		button.modulate.a = clampf((presented.z - 0.07) / 0.26, 0.0, 1.0)
		button.reset_size()
		var offset := Vector2(LABEL_OFFSETS.get(region_name, Vector2.ZERO))
		button.position = projected - button.size * 0.5 + offset
		button.add_theme_color_override(
			"font_color",
			Palette.color(&"accent", false) if region_name == _selected_region \
			else Palette.color(&"ink", false)
		)
		button.add_theme_color_override("font_hover_color", Palette.color(&"ink", false))
		button.add_theme_color_override("font_pressed_color", Palette.color(&"accent", false))


func _apply_mode() -> void:
	if _terrain_instance == null:
		return
	_political_instance.visible = _mode == MODE_REGIONS
	_seam_instance.visible = true
	match _mode:
		MODE_REGIONS:
			_terrain_material.albedo_color = Color.WHITE
			_seam_material.albedo_color = Color(0.92, 0.87, 0.74, 0.26)
		MODE_TERRAIN:
			_terrain_material.albedo_color = Color(1.08, 1.08, 1.08, 1.0)
			_seam_material.albedo_color = Color(0.88, 0.86, 0.78, 0.10)
		MODE_SEAMS:
			_terrain_material.albedo_color = Color(0.56, 0.59, 0.60, 1.0)
			_seam_material.albedo_color = Color(1.0, 0.91, 0.66, 0.92)
	_update_region_visibility()


func _update_region_visibility() -> void:
	for region_name in _region_instances:
		var instance: MeshInstance3D = _region_instances[region_name]
		var selected: bool = region_name == _selected_region
		var hovered: bool = region_name == _hover_region
		instance.visible = _mode == MODE_REGIONS and (selected or hovered)
		if instance.visible:
			instance.set_surface_override_material(
				0, _highlight_material if selected else _hover_material
			)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_set_camera_distance(_camera_distance - 0.18)
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_set_camera_distance(_camera_distance + 0.18)
			accept_event()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_pointer_down = true
			_dragging = false
			_press_position = mouse.position
			accept_event()
			return
		if not _pointer_down:
			return
		_pointer_down = false
		if not _dragging:
			_select_at_screen(mouse.position)
		_dragging = false
		accept_event()
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pointer_down:
			if not _dragging and motion.position.distance_to(_press_position) >= DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_rotate_presentation(motion.relative)
				accept_event()
			return
		var region := _region_at_screen(motion.position)
		if region != _hover_region:
			_hover_region = region
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
				if not region.is_empty() else Control.CURSOR_DRAG
			_update_region_visibility()


func _rotate_presentation(delta: Vector2) -> void:
	var yaw := Quaternion(Vector3.UP, delta.x * ROTATION_SPEED)
	var pitch := Quaternion(Vector3.RIGHT, delta.y * ROTATION_SPEED)
	_globe_root.quaternion = (pitch * yaw * _globe_root.quaternion).normalized()


func _set_camera_distance(value: float) -> void:
	_camera_distance = clampf(value, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	if _camera != null:
		_camera.position.z = _camera_distance


func _select_at_screen(screen_point: Vector2) -> void:
	var region := _region_at_screen(screen_point)
	if region.is_empty():
		return
	set_selected_region(region)
	region_selected.emit(region)


func _region_at_screen(screen_point: Vector2) -> String:
	if _camera == null or _globe_root == null:
		return ""
	var ray_origin := _camera.project_ray_origin(screen_point)
	var ray_direction := _camera.project_ray_normal(screen_point).normalized()
	var b := ray_origin.dot(ray_direction)
	var c := ray_origin.length_squared() - GLOBE_RADIUS * GLOBE_RADIUS
	var discriminant := b * b - c
	if discriminant < 0.0:
		return ""
	var distance := -b - sqrt(discriminant)
	if distance < 0.0:
		distance = -b + sqrt(discriminant)
	if distance < 0.0:
		return ""
	var presented_direction := (ray_origin + ray_direction * distance).normalized()
	var canonical_direction := _globe_root.transform.basis.inverse() * presented_direction
	return world_direction_to_region(canonical_direction)


static func _ensure_cached_geometry() -> void:
	if _terrain_mesh_cache != null:
		return
	_build_unique_panel_edges()
	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var political := SurfaceTool.new()
	political.begin(Mesh.PRIMITIVE_TRIANGLES)
	var region_tools: Dictionary = {}
	for region_name in Politics.all_regions():
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		region_tools[region_name] = tool

	for panel_id in Topology.PANEL_IDS:
		var panel_vertices := 0
		for ux in range(PANEL_U_STEPS):
			for vy in range(PANEL_V_STEPS):
				var uv00 := Vector2(float(ux) / PANEL_U_STEPS, float(vy) / PANEL_V_STEPS)
				var uv10 := Vector2(float(ux + 1) / PANEL_U_STEPS, float(vy) / PANEL_V_STEPS)
				var uv11 := Vector2(float(ux + 1) / PANEL_U_STEPS, float(vy + 1) / PANEL_V_STEPS)
				var uv01 := Vector2(float(ux) / PANEL_U_STEPS, float(vy + 1) / PANEL_V_STEPS)
				var d00 := Mapper.panel_uv_to_world(panel_id, uv00).normalized()
				var d10 := Mapper.panel_uv_to_world(panel_id, uv10).normalized()
				var d11 := Mapper.panel_uv_to_world(panel_id, uv11).normalized()
				var d01 := Mapper.panel_uv_to_world(panel_id, uv01).normalized()
				var c00 := _terrain_color(d00)
				var c10 := _terrain_color(d10)
				var c11 := _terrain_color(d11)
				var c01 := _terrain_color(d01)
				_add_oriented_triangle(terrain, d00, d10, d11, c00, c10, c11, GLOBE_RADIUS)
				_add_oriented_triangle(terrain, d00, d11, d01, c00, c11, c01, GLOBE_RADIUS)
				panel_vertices += 6

				var center := (d00 + d10 + d11 + d01).normalized()
				var region := Politics.region_at(center)
				if region.is_empty():
					continue
				var region_color := _region_color(region)
				_add_oriented_triangle(political, d00, d10, d11, region_color, region_color, region_color, POLITICAL_RADIUS)
				_add_oriented_triangle(political, d00, d11, d01, region_color, region_color, region_color, POLITICAL_RADIUS)
				var region_tool: SurfaceTool = region_tools[region]
				var highlight := Color.WHITE
				_add_oriented_triangle(region_tool, d00, d10, d11, highlight, highlight, highlight, HIGHLIGHT_RADIUS)
				_add_oriented_triangle(region_tool, d00, d11, d01, highlight, highlight, highlight, HIGHLIGHT_RADIUS)
		_panel_vertex_counts_cache[panel_id] = panel_vertices

	_terrain_mesh_cache = terrain.commit()
	_political_mesh_cache = political.commit()
	for region_name in region_tools:
		var region_tool: SurfaceTool = region_tools[region_name]
		_region_mesh_cache[region_name] = region_tool.commit()
	_seam_mesh_cache = _build_seam_mesh()


static func _build_unique_panel_edges() -> void:
	var corner_keys := {}
	for panel_id in Topology.PANEL_IDS:
		for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			corner_keys[_direction_key(Mapper.panel_uv_to_world(panel_id, uv))] = true
	var seen := {}
	for panel_id in Topology.PANEL_IDS:
		for edge in ["u_min", "u_max", "v_min", "v_max"]:
			var cuts: Array[float] = [0.0, 1.0]
			for candidate in [1.0 / 3.0, 2.0 / 3.0]:
				if corner_keys.has(_direction_key(_panel_edge_world(panel_id, edge, candidate))):
					cuts.append(candidate)
			cuts.sort()
			for cut_index in range(cuts.size() - 1):
				var t0 := cuts[cut_index]
				var t1 := cuts[cut_index + 1]
				var a_key := _direction_key(_panel_edge_world(panel_id, edge, t0))
				var b_key := _direction_key(_panel_edge_world(panel_id, edge, t1))
				var key := "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
				if seen.has(key):
					continue
				seen[key] = true
				_unique_panel_edges_cache.append({
					"panel": panel_id, "edge": edge, "t0": t0, "t1": t1,
				})


static func _build_seam_mesh() -> ArrayMesh:
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seam_color := Color.WHITE
	for edge in _unique_panel_edges_cache:
		for step in range(SEAM_STEPS):
			var t0 := lerpf(float(edge.t0), float(edge.t1), float(step) / SEAM_STEPS)
			var t1 := lerpf(float(edge.t0), float(edge.t1), float(step + 1) / SEAM_STEPS)
			var p0 := _panel_edge_world(String(edge.panel), String(edge.edge), t0)
			var p1 := _panel_edge_world(String(edge.panel), String(edge.edge), t1)
			var tangent := (p1 - p0).normalized()
			var normal := (p0 + p1).normalized()
			var side := normal.cross(tangent).normalized() * SEAM_HALF_WIDTH
			var a := (p0 * SEAM_RADIUS) - side
			var b := (p0 * SEAM_RADIUS) + side
			var c := (p1 * SEAM_RADIUS) + side
			var d := (p1 * SEAM_RADIUS) - side
			_add_position_triangle(seams, a, b, c, seam_color)
			_add_position_triangle(seams, a, c, d, seam_color)
	return seams.commit()


static func _panel_edge_world(panel_id: String, edge: String, t: float) -> Vector3:
	match edge:
		"u_min": return Mapper.panel_uv_to_world(panel_id, Vector2(0.0, t)).normalized()
		"u_max": return Mapper.panel_uv_to_world(panel_id, Vector2(1.0, t)).normalized()
		"v_min": return Mapper.panel_uv_to_world(panel_id, Vector2(t, 0.0)).normalized()
		"v_max": return Mapper.panel_uv_to_world(panel_id, Vector2(t, 1.0)).normalized()
	return Vector3.ZERO


static func _direction_key(direction: Vector3) -> String:
	return "%d,%d,%d" % [
		int(round(direction.x * 100000.0)),
		int(round(direction.y * 100000.0)),
		int(round(direction.z * 100000.0)),
	]


static func _terrain_color(direction: Vector3) -> Color:
	var sample := Geography.sample_world(direction)
	var terrain := String(sample.get("terrain", "temperate"))
	var color := Color(TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["temperate"]))
	var elevation := float(sample.get("elevation", 0.0))
	if elevation > Geography.SEA_LEVEL:
		color = color.lightened(clampf(elevation * 0.055, 0.0, 0.075))
	return color


static func _region_color(region_name: String) -> Color:
	var index := Politics.all_regions().find(region_name)
	var color: Color = REGION_COLORS[index % REGION_COLORS.size()]
	color.a = 0.72
	return color


static func _add_oriented_triangle(
	tool: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	ca: Color, cb: Color, cc: Color,
	radius: float
) -> void:
	## Godot culls counter-clockwise spatial faces. Keep the visible front face
	## clockwise when viewed from outside the sphere; the previous comparison did
	## the opposite and rendered the far hemisphere through an invisible shell.
	if (b - a).cross(c - a).dot(a + b + c) > 0.0:
		_add_surface_vertex(tool, a, ca, radius)
		_add_surface_vertex(tool, c, cc, radius)
		_add_surface_vertex(tool, b, cb, radius)
		return
	_add_surface_vertex(tool, a, ca, radius)
	_add_surface_vertex(tool, b, cb, radius)
	_add_surface_vertex(tool, c, cc, radius)


static func _add_surface_vertex(tool: SurfaceTool, direction: Vector3, color: Color, radius: float) -> void:
	tool.set_normal(direction.normalized())
	tool.set_color(color)
	tool.add_vertex(direction.normalized() * radius)


static func _add_position_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (a + b + c).normalized()
	var points := [a, b, c]
	if (b - a).cross(c - a).dot(a + b + c) > 0.0:
		points = [a, c, b]
	for point in points:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(point)


func _mesh_instance(instance_name: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = instance_name
	instance.mesh = mesh
	if mesh != null and mesh.get_surface_count() > 0:
		instance.set_surface_override_material(0, material)
	return instance


func _make_surface_material(transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_overlay_material(alpha: float) -> StandardMaterial3D:
	var material := _make_surface_material(true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 1, alpha)
	material.no_depth_test = false
	return material
