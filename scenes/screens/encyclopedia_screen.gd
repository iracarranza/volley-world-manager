class_name EncyclopediaScreen
extends Control

## What the world already knows about itself, said out loud.
##
## The article view reads simulation-owned regional data. The World Register
## beside it reads the canonical physical/political world surface. Neither view
## maintains a parallel geography or tactical description.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const WorldRegisterViewScript := preload("res://scenes/components/world_register_view.gd")
const Regions := preload("res://scripts/data/regions.gd")

signal back_requested

const PRINCIPLE_ORDER: Array[String] = [
	"decisiveness", "pin_focus", "tempo_variation", "emotional_expression",
	"serve_aggression", "transition_commitment", "block_commitment",
]

var _entries: ItemList
var _article: RichTextLabel
var _subjects: Array[String] = []
var _articles_view: HBoxContainer
var _register_view: WorldRegisterView
var _articles_button: Button
var _register_button: Button
var _view_group: ButtonGroup
var _shell


func _ready() -> void:
	_build()


func _build() -> void:
	if _entries != null:
		return
	var back := ScreenShell.action("Back", "Return to the journal.")
	back.pressed.connect(func() -> void: back_requested.emit())
	_articles_button = ScreenShell.action("Articles")
	_register_button = ScreenShell.action("World Register")
	_articles_button.toggle_mode = true
	_register_button.toggle_mode = true
	_view_group = ButtonGroup.new()
	_articles_button.button_group = _view_group
	_register_button.button_group = _view_group
	_articles_button.pressed.connect(_show_articles)
	_register_button.pressed.connect(_show_register)
	_shell = ScreenShell.build(
		self, "Encyclopedia",
		[_articles_button, _register_button, back] as Array[Button]
	)

	_articles_view = HBoxContainer.new()
	_articles_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_articles_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_articles_view.add_theme_constant_override("separation", 14)
	_shell.content.add_child(_articles_view)

	_entries = ItemList.new()
	_entries.custom_minimum_size = Vector2(220, 0)
	_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entries.item_selected.connect(_entry_selected)
	_articles_view.add_child(_entries)

	_article = RichTextLabel.new()
	_article.bbcode_enabled = true
	_article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_article.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_articles_view.add_child(_article)

	_register_view = WorldRegisterViewScript.new()
	_register_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.content.add_child(_register_view)

	_populate()
	_show_articles()


## Majors then minors, in the order `manageable_names` already puts them.
func _populate() -> void:
	_entries.clear()
	_subjects.clear()
	for region_name in Regions.manageable_names():
		var name := str(region_name)
		_subjects.append(name)
		_entries.add_item("%s%s" % [
			name, "" if Regions.is_major(name) else "  ·  minor",
		])
	if _entries.item_count > 0:
		_entries.select(0)
		_show_region(_subjects[0])


func _entry_selected(index: int) -> void:
	if index < 0 or index >= _subjects.size():
		return
	_show_region(_subjects[index])


func _show_articles() -> void:
	if _articles_view == null:
		return
	_articles_view.visible = true
	_register_view.visible = false
	_articles_button.button_pressed = true
	_shell.title.text = "Encyclopedia"


func _show_register() -> void:
	if _register_view == null:
		return
	_articles_view.visible = false
	_register_view.visible = true
	_register_button.button_pressed = true
	_shell.title.text = "World Register"


## Public entry point for a direct jump from another UI or a render/test harness.
func open_world_register(region_name: String = "") -> void:
	if _entries == null:
		_build()
	_show_register()
	if not region_name.is_empty():
		_register_view.select_region(region_name)


func world_register_open() -> bool:
	return _register_view != null and _register_view.visible


func selected_register_region() -> String:
	return _register_view.selected_region() if _register_view != null else ""


func set_world_register_mode(mode_name: StringName) -> void:
	if _register_view == null:
		_build()
	_register_view.set_mode(mode_name)


func focus_world_register_region(region_name: String) -> void:
	if _register_view == null:
		_build()
	_register_view.focus_region(region_name)


func set_world_register_rotation_degrees(rotation_degrees_value: Vector3) -> void:
	if _register_view == null:
		_build()
	_register_view.set_globe_rotation_degrees(rotation_degrees_value)


func _show_region(region_name: String) -> void:
	var definition: Dictionary = Regions.definition(region_name)
	var lines: Array[String] = []
	lines.append("[font_size=26][b]%s[/b][/font_size]" % region_name)
	lines.append("[i]%s · %s[/i]" % [
		Regions.demonym(region_name),
		"Sixnet region" if Regions.is_major(region_name) \
			else "minor region · runs no academy",
	])
	lines.append("")
	lines.append(str(definition.get("tagline", "")))
	lines.append("")
	lines.append("[b]Tradition[/b]  physical %d · technical %d · mental %d" % [
		int(definition.get("physical", 0)),
		int(definition.get("technical", 0)),
		int(definition.get("mental", 0)),
	])
	var clubs := Regions.clubs_in(region_name)
	lines.append("[b]Clubs[/b]  %s" % " · ".join(clubs))
	## REGION_ADJACENCY is the development/influence graph, not the canonical
	## physical map. Keep it legible here under its actual meaning rather than
	## calling it a border table.
	var development_links: Array = Regions.REGION_ADJACENCY.get(
		Regions.canonical_name(region_name), []
	)
	if not development_links.is_empty():
		lines.append("[b]Development links[/b]  %s" % " · ".join(development_links))
	var given_names: Array = definition.get("names", [])
	if not given_names.is_empty():
		lines.append("[b]Names given here[/b]  %s" % " · ".join(given_names))
	lines.append("")
	lines.append("[b]How they play[/b]")
	var principles: Dictionary = Regions.REGIONAL_PRINCIPLES.get(
		Regions.canonical_name(region_name), {}
	)
	for key in PRINCIPLE_ORDER:
		if not principles.has(key):
			continue
		lines.append("  %-24s %.2f" % [
			str(key).capitalize().replace("_", " "), float(principles[key]),
		])
	_article.text = "\n".join(lines)
