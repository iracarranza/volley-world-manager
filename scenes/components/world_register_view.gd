class_name WorldRegisterView
extends VBoxContainer

## The World Register is a reader for canonical world data, not a second author.
## The globe is drawn from WorldGeography/WorldPoliticalGeography; this view adds
## only controls and a compact selected-region record.

const GlobeScript := preload("res://scenes/components/world_register_globe.gd")
const Regions := preload("res://scripts/data/regions.gd")
const Geography := preload("res://scripts/data/world_geography.gd")
const Politics := preload("res://scripts/data/world_political_geography.gd")
const Mapper := preload("res://scripts/world/world_surface_mapper.gd")

signal region_selected(region_name: String)

var _globe: WorldRegisterGlobe
var _details: RichTextLabel
var _mode_buttons: Dictionary = {}
var _mode_group: ButtonGroup


func _ready() -> void:
	_build()


func _build() -> void:
	if _globe != null:
		return
	add_theme_constant_override("separation", 10)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	_mode_group = ButtonGroup.new()
	for spec in [
		["Regions", WorldRegisterGlobe.MODE_REGIONS],
		["Terrain", WorldRegisterGlobe.MODE_TERRAIN],
		["Seams", WorldRegisterGlobe.MODE_SEAMS],
	]:
		var button := Button.new()
		button.text = String(spec[0])
		button.toggle_mode = true
		button.button_group = _mode_group
		var mode_name: StringName = spec[1]
		button.pressed.connect(func() -> void: set_mode(mode_name))
		toolbar.add_child(button)
		_mode_buttons[mode_name] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var hint := Label.new()
	hint.text = "Drag to rotate · wheel to zoom · select a region"
	toolbar.add_child(hint)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	add_child(body)

	var globe_panel := PanelContainer.new()
	globe_panel.name = "WorldGlobeCard"
	globe_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	globe_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(globe_panel)
	_globe = GlobeScript.new()
	_globe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_globe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_globe.region_selected.connect(_globe_region_selected)
	globe_panel.add_child(_globe)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "RegisterCard"
	detail_panel.custom_minimum_size = Vector2(310, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(margin)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_details)

	set_mode(WorldRegisterGlobe.MODE_REGIONS)
	select_region("Landavol")


func set_mode(mode_name: StringName) -> void:
	if _globe == null:
		_build()
	_globe.set_mode(mode_name)
	for key in _mode_buttons:
		var button: Button = _mode_buttons[key]
		button.button_pressed = key == mode_name


func mode() -> StringName:
	return _globe.mode() if _globe != null else WorldRegisterGlobe.MODE_REGIONS


func select_region(region_name: String) -> void:
	if _globe == null:
		_build()
	if not Politics.all_regions().has(region_name):
		return
	_globe.set_selected_region(region_name)
	_show_region(region_name)


func selected_region() -> String:
	return _globe.selected_region() if _globe != null else "Landavol"


func all_regions() -> Array:
	return Politics.all_regions()


func focus_region(region_name: String) -> void:
	if _globe == null:
		_build()
	_globe.focus_region(region_name)


func set_globe_rotation_degrees(rotation_degrees_value: Vector3) -> void:
	if _globe == null:
		_build()
	_globe.set_presentation_rotation_degrees(rotation_degrees_value)


func globe() -> WorldRegisterGlobe:
	return _globe


func details_text() -> String:
	return _details.text if _details != null else ""


func terrain_summary(region_name: String) -> Array[String]:
	var result: Array[String] = []
	for lobe in Politics.REGION_LOBES.get(region_name, []):
		var world := Mapper.panel_uv_to_world(String(lobe.panel), Vector2(lobe.uv))
		var terrain := String(Geography.sample_world(world).get("terrain", ""))
		if terrain.is_empty():
			continue
		var label := terrain.replace("_", " ").capitalize()
		if not result.has(label):
			result.append(label)
	return result


func _globe_region_selected(region_name: String) -> void:
	select_region(region_name)
	region_selected.emit(region_name)


func _show_region(region_name: String) -> void:
	var definition := Regions.definition(region_name)
	var lines: Array[String] = []
	lines.append("[font_size=24][b]%s[/b][/font_size]" % region_name)
	lines.append("[i]%s · %s[/i]" % [
		Regions.demonym(region_name),
		"Sixnet region" if Regions.is_major(region_name) else "minor region",
	])
	lines.append("")
	var tagline := String(definition.get("tagline", ""))
	if not tagline.is_empty():
		lines.append(tagline)
		lines.append("")
	var terrain := terrain_summary(region_name)
	if not terrain.is_empty():
		lines.append("[b]Terrain[/b]  %s" % " · ".join(terrain))
	var clubs := Regions.clubs_in(region_name)
	lines.append("[b]Clubs[/b]  %s" % " · ".join(clubs))
	var development_links: Array = Regions.REGION_ADJACENCY.get(
		Regions.canonical_name(region_name), []
	)
	if not development_links.is_empty():
		lines.append("[b]Development links[/b]  %s" % " · ".join(development_links))
	lines.append("[b]Tradition[/b]  physical %d · technical %d · mental %d" % [
		int(definition.get("physical", 0)),
		int(definition.get("technical", 0)),
		int(definition.get("mental", 0)),
	])
	_details.text = "\n".join(lines)
