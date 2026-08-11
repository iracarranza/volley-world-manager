class_name VolleyballNewCareerScreen
extends Control

signal career_created
signal back_requested

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

const STEPS := ["01  ORIGIN", "02  FOUNDATION", "03  PHILOSOPHY", "04  SIGNATURE"]
const AXIS_QUESTIONS := [
	{"key": "decisiveness", "question": "How should rallies be won?", "low": "Outlast", "middle": "Adapt", "high": "Finish"},
	{"key": "pin_focus", "question": "Where should attack volume live?", "low": "Middles", "middle": "Spread", "high": "Pins"},
	{"key": "tempo_variation", "question": "How should tempo behave?", "low": "Repeatable", "middle": "Responsive", "high": "Variable"},
	{"key": "emotional_expression", "question": "What drives the group?", "low": "Discipline", "middle": "Composure", "high": "Emotion"},
	{"key": "serve_aggression", "question": "What should serving demand?", "low": "Control", "middle": "Pressure", "high": "Damage"},
	{"key": "transition_commitment", "question": "What follows a defensive touch?", "low": "Reset", "middle": "Read", "high": "Go Again"},
	{"key": "block_commitment", "question": "Where should defense commit?", "low": "Floor", "middle": "Read", "high": "Net"},
]

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var step_rail: VBoxContainer = %StepRail
@onready var step_kicker: Label = %StepKicker
@onready var question_title: Label = %QuestionTitle
@onready var question_hint: Label = %QuestionHint
@onready var region_grid: GridContainer = %RegionGrid
@onready var type_row: HBoxContainer = %TypeRow
@onready var preset_option: OptionButton = %PresetOption
@onready var identity_name_edit: LineEdit = %IdentityNameEdit
@onready var identity_tag_grid: GridContainer = %IdentityTagGrid
@onready var career_name_edit: LineEdit = %CareerNameEdit
@onready var organization_name_edit: LineEdit = %OrganizationNameEdit
@onready var review_text: RichTextLabel = %ReviewText
@onready var error_label: Label = %ErrorLabel
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton

var current_step := 0
var selected_region := "Landavol"
var selected_type := "Club"
var selected_values: Dictionary = {}
var identity_tracks_region := true
var light_mode_enabled := false
var step_panels: Array[Control] = []
var step_labels: Array[Label] = []
var tag_buttons: Dictionary = {}


func _ready() -> void:
	step_panels = [%RegionStep, %TypeStep, %IdentityStep, %NamesStep]
	_build_step_rail()
	_build_region_choices()
	_build_type_choices()
	_build_identity_choices()
	previous_button.pressed.connect(_previous)
	next_button.pressed.connect(_next)
	%CancelButton.pressed.connect(func() -> void: back_requested.emit())
	reset_form()


func reset_form() -> void:
	current_step = 0
	error_label.text = ""
	selected_region = "Landavol"
	selected_type = "Club"
	identity_tracks_region = true
	_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	_select_button_with_metadata(region_grid, selected_region)
	_select_button_with_metadata(type_row, selected_type)
	preset_option.select(0)
	_show_step()


func _build_step_rail() -> void:
	for child in step_rail.get_children():
		child.queue_free()
	step_labels.clear()
	for step_name in STEPS:
		var label := Label.new()
		label.text = step_name
		label.custom_minimum_size = Vector2(170, 42)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		step_rail.add_child(label)
		step_labels.append(label)


func _build_region_choices() -> void:
	var group := ButtonGroup.new()
	for region_name in VolleyballRegions.manageable_names():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(190, 68)
		button.text = "%s\n%s" % [region_name, _region_signature(region_name)]
		button.set_meta("value", region_name)
		button.pressed.connect(_select_region.bind(region_name))
		region_grid.add_child(button)


func _build_type_choices() -> void:
	var group := ButtonGroup.new()
	for type_name in ["Club", "Academy"]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(280, 150)
		button.text = ("CLUB\nCompete now\n10 senior players · larger budget" \
			if type_name == "Club" else \
			"ACADEMY\nBuild for later\n12 young players · higher potential")
		button.set_meta("value", type_name)
		button.pressed.connect(_select_type.bind(type_name))
		type_row.add_child(button)


func _build_identity_choices() -> void:
	preset_option.add_item("Regional Tradition")
	for preset_name in TeamPrinciplesModel.PRESET_NAMES:
		preset_option.add_item(preset_name)
	preset_option.add_item("Custom")
	preset_option.item_selected.connect(_preset_selected)
	identity_name_edit.text_changed.connect(func(_text: String) -> void:
		if preset_option.get_item_text(preset_option.selected) != "Custom":
			preset_option.select(preset_option.item_count - 1)
		identity_tracks_region = false
	)
	career_name_edit.text_changed.connect(func(_text: String) -> void:
		if current_step == 3: _refresh_review()
	)
	organization_name_edit.text_changed.connect(func(_text: String) -> void:
		if current_step == 3: _refresh_review()
	)
	for question in AXIS_QUESTIONS:
		var question_label := Label.new()
		question_label.text = str(question.question)
		question_label.custom_minimum_size = Vector2(220, 38)
		question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		identity_tag_grid.add_child(question_label)
		var group := ButtonGroup.new()
		var axis_buttons: Array[Button] = []
		for choice in [
			{"label": question.low, "value": 0.2},
			{"label": question.middle, "value": 0.5},
			{"label": question.high, "value": 0.8},
		]:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(104, 38)
			button.text = str(choice.label)
			button.pressed.connect(_tag_selected.bind(
				str(question.key), float(choice.value)
			))
			identity_tag_grid.add_child(button)
			axis_buttons.append(button)
		tag_buttons[str(question.key)] = axis_buttons


func _show_step() -> void:
	for index in range(step_panels.size()):
		step_panels[index].visible = index == current_step
		step_labels[index].modulate = UIPalette.color(
			&"accent" if index == current_step else &"ink_faint", light_mode_enabled
		)
	step_kicker.text = "QUESTION %d OF %d" % [current_step + 1, STEPS.size()]
	match current_step:
		0:
			question_title.text = "Where does your volleyball begin?"
			question_hint.text = VolleyballRegions.definition(selected_region).tagline
		1:
			question_title.text = "What are you taking responsibility for?"
			question_hint.text = "A club is judged immediately. An academy gets time, but fewer resources."
		2:
			question_title.text = "What should your team believe?"
			question_hint.text = "Choose a shortcut, then challenge any principle. Departure from local tradition lowers starting cohesion and familiarity."
			_refresh_alignment_preview()
		3:
			question_title.text = "Put a name on the project."
			question_hint.text = "This is the signature attached to every result that follows."
			_refresh_review()
	previous_button.text = "Back to title" if current_step == 0 else "Previous"
	next_button.text = "Create career" if current_step == step_panels.size() - 1 \
		else "Continue"


func _select_region(region_name: String) -> void:
	selected_region = region_name
	if identity_tracks_region:
		_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	question_hint.text = VolleyballRegions.definition(selected_region).tagline


func _select_type(type_name: String) -> void:
	selected_type = type_name


func _preset_selected(index: int) -> void:
	var choice := preset_option.get_item_text(index)
	if choice == "Custom":
		identity_tracks_region = false
		return
	if choice == "Regional Tradition":
		identity_tracks_region = true
		_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	else:
		identity_tracks_region = false
		_set_principles(TeamPrinciplesModel.for_identity(choice), true)
	_refresh_alignment_preview()


func _tag_selected(axis_name: String, value: float) -> void:
	selected_values[axis_name] = value
	identity_tracks_region = false
	preset_option.select(preset_option.item_count - 1)
	_refresh_alignment_preview()


func _set_principles(principles: TeamPrinciples, update_name: bool) -> void:
	selected_values = principles.to_dict()
	selected_values.erase("preset_name")
	if update_name:
		identity_name_edit.set_block_signals(true)
		identity_name_edit.text = str(principles.preset_name)
		identity_name_edit.set_block_signals(false)
	_sync_tag_buttons()


func _sync_tag_buttons() -> void:
	for axis_name in tag_buttons:
		var value := float(selected_values.get(axis_name, 0.5))
		var target_index := 0 if value < 0.35 else (2 if value > 0.65 else 1)
		var buttons: Array = tag_buttons[axis_name]
		for index in range(buttons.size()):
			(buttons[index] as Button).button_pressed = index == target_index


func _refresh_alignment_preview() -> void:
	var principles := TeamPrinciplesModel.custom(_identity_name(), selected_values)
	var state := VolleyballRegions.starting_identity_state(selected_region, principles)
	%AlignmentPreview.text = "REGIONAL ALIGNMENT  %d%%    STARTING FAMILIARITY  %d%%    COHESION  %d%%" % [
		roundi(float(state.alignment) * 100.0),
		roundi(float(state.familiarity) * 100.0),
		roundi(float(state.cohesion) * 100.0),
	]


func _refresh_review() -> void:
	var principles := TeamPrinciplesModel.custom(_identity_name(), selected_values)
	var state := VolleyballRegions.starting_identity_state(selected_region, principles)
	review_text.text = "[font_size=24][b]%s[/b][/font_size]\n%s · %s\n\n[b]%s[/b]\n%s\n\nRegional alignment %d%%\nTactical familiarity %d%% · Cohesion %d%%" % [
		organization_name_edit.text if not organization_name_edit.text.is_empty() else "Unnamed organization",
		selected_region, selected_type, principles.preset_name,
		_identity_summary(), roundi(float(state.alignment) * 100.0),
		roundi(float(state.familiarity) * 100.0), roundi(float(state.cohesion) * 100.0),
	]


func _identity_summary() -> String:
	var tags: Array[String] = []
	for question in AXIS_QUESTIONS:
		var value := float(selected_values.get(str(question.key), 0.5))
		tags.append(str(question.low) if value < 0.35 else (
			str(question.high) if value > 0.65 else str(question.middle)
		))
	return " · ".join(tags)


func _identity_name() -> String:
	var identity_name := identity_name_edit.text.strip_edges()
	return identity_name if not identity_name.is_empty() else "Custom Identity"


func _previous() -> void:
	error_label.text = ""
	if current_step == 0:
		back_requested.emit()
		return
	current_step -= 1
	_show_step()


func _next() -> void:
	error_label.text = ""
	if current_step < step_panels.size() - 1:
		current_step += 1
		_show_step()
		return
	_create_career()


func _create_career() -> void:
	var error := CareerManager.create_career(
		career_name_edit.text, organization_name_edit.text,
		selected_region, selected_type, _identity_name(), selected_values,
	)
	error_label.text = error
	if error.is_empty():
		career_created.emit()


func _select_button_with_metadata(container: Container, value: String) -> void:
	for child in container.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("value", "")) == value


func _region_signature(region_name: String) -> String:
	match region_name:
		"Spëddigh": return "work · tempo"
		"Pāwa Hitō": return "stamina · transition"
		"Bloc du Larg": return "structure · block"
		"Xérvu": return "serve · variation"
		"Taktikã": return "intellect · discipline"
		"Ispayk": return "power · pins"
		"A'ace": return "stars · ambition"
		_: return "balance · breadth"


func set_light_mode(enabled: bool) -> void:
	light_mode_enabled = enabled
	%Background.color = UIPalette.color(&"canvas", enabled)
	%AccentBand.color = UIPalette.color(&"accent", enabled)
	question_hint.modulate = UIPalette.color(&"ink_muted", enabled)
	step_kicker.modulate = UIPalette.color(&"accent", enabled)
	error_label.modulate = UIPalette.color(&"danger", enabled)
	%AlignmentPreview.modulate = UIPalette.color(&"accent_alt", enabled)
	if not step_labels.is_empty():
		_show_step()
