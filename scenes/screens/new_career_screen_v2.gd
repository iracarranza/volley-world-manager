extends "res://scenes/screens/new_career_screen.gd"

const FLOW_STEPS := [
	"01  YOU",
	"02  VOLLEYBALL",
	"03  PLACE",
	"04  CLUB",
	"05  MANAGEMENT",
	"06  SIGNATURE",
	"SAVE SETUP",
]

const VOLLEYBALL_QUESTIONS := [
	{
		"key": "good_ball",
		"question": "Your team gets a good first touch. How should they attack?",
		"choices": [
			{"label": "Quick attacks", "values": {"decisiveness": 0.72, "tempo_variation": 0.68, "pin_focus": 0.38}},
			{"label": "Read the blockers", "values": {"decisiveness": 0.48, "tempo_variation": 0.62, "pin_focus": 0.48}},
			{"label": "Trust your hitters", "values": {"decisiveness": 0.72, "tempo_variation": 0.42, "pin_focus": 0.72}},
		],
	},
	{
		"key": "serve",
		"question": "How should your team serve?",
		"choices": [
			{"label": "Controlled serves", "values": {"serve_aggression": 0.22}},
			{"label": "Target reception", "values": {"serve_aggression": 0.50}},
			{"label": "Aggressive serves", "values": {"serve_aggression": 0.82}},
		],
	},
	{
		"key": "defense",
		"question": "How should your team defend attacks?",
		"choices": [
			{"label": "Floor defense", "values": {"block_commitment": 0.20}},
			{"label": "Read the attack", "values": {"block_commitment": 0.50}},
			{"label": "Commit the block", "values": {"block_commitment": 0.82}},
		],
	},
	{
		"key": "transition",
		"question": "Your team keeps a difficult attack alive. What should happen next?",
		"choices": [
			{"label": "Reset the play", "values": {"transition_commitment": 0.20}},
			{"label": "Find the opportunity", "values": {"transition_commitment": 0.50}},
			{"label": "Attack in transition", "values": {"transition_commitment": 0.82}},
		],
	},
	{
		"key": "broken_first_contact",
		"question": "The first contact pulls your team out of position. How should they respond?",
		"choices": [
			{"label": "Recover the structure", "values": {"decisiveness": 0.30, "tempo_variation": 0.28}},
			{"label": "Use what's available", "values": {"decisiveness": 0.50, "tempo_variation": 0.58}},
			{"label": "Keep the pressure on", "values": {"decisiveness": 0.78, "tempo_variation": 0.74}},
		],
	},
	{
		"key": "construction",
		"question": "How should your attacks create opportunities?",
		"choices": [
			{"label": "Combination offense", "values": {"pin_focus": 0.34, "tempo_variation": 0.72}},
			{"label": "Flexible offense", "values": {"pin_focus": 0.50, "tempo_variation": 0.56}},
			{"label": "Isolation offense", "values": {"pin_focus": 0.78, "tempo_variation": 0.32}},
		],
	},
]

var _v2_ready := false
var home_region := "Landavol"
var manager_background := "played"
var volleyball_answers: Dictionary = {}
var management_values := {
	"structure": 0.5,
	"squad": 0.5,
	"delegation": 0.5,
}

var _home_region_option: OptionButton
var _management_step: VBoxContainer
var _save_setup_step: VBoxContainer
var _background_row: HBoxContainer
var _management_value_labels: Dictionary = {}
var _seed_label: Label


func _ready() -> void:
	super._ready()
	_upgrade_flow()
	_v2_ready = true
	reset_form()


func reset_form() -> void:
	if not _v2_ready:
		super.reset_form()
		return
	current_step = 0
	error_label.text = ""
	home_region = "Landavol"
	selected_region = "Landavol"
	selected_tier = VolleyballRegions.tier_of(selected_region)
	selected_type = "Established"
	manager_background = "played"
	identity_tracks_region = false
	manager_name_tracks_region = true
	appearance = ManagerProfile.DEFAULT_APPEARANCE.duplicate(true)
	management_values = {"structure": 0.5, "squad": 0.5, "delegation": 0.5}
	volleyball_answers.clear()
	for question in VOLLEYBALL_QUESTIONS:
		volleyball_answers[str(question.key)] = 1
	_rebuild_principles_from_volleyball()
	_suggest_manager_name_from_home()
	_sync_voli_controls()
	_sync_v2_controls()
	_show_step()


func debug_jump_to_step(index: int) -> void:
	if not _v2_ready:
		return
	current_step = clampi(index, 0, step_panels.size() - 1)
	_show_step()


func _upgrade_flow() -> void:
	## The old scene is retained as the layout substrate so this migration does not
	## fork the manager rig, camera or body editor. The flow around it is replaced.
	%RailTitle.text = "Create your\nmanager"
	%RailHint.text = "Choose what is true at the start.\nThe club changes later in play."

	_build_background_row()
	_build_volleyball_questions()
	_build_place_controls()
	_rewrite_club_route()
	_build_management_step()
	_rewrite_signature()
	_build_save_setup_step()

	step_panels = [
		%VoliStep,
		%IdentityStep,
		%RegionStep,
		%TypeStep,
		_management_step,
		%NamesStep,
		_save_setup_step,
	]
	_rebuild_flow_rail()


func _rebuild_flow_rail() -> void:
	for child in step_rail.get_children():
		child.queue_free()
	step_labels.clear()
	for step_name in FLOW_STEPS:
		var label := Label.new()
		label.text = step_name
		label.custom_minimum_size = Vector2(170, 34)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		step_rail.add_child(label)
		step_labels.append(label)


func _build_background_row() -> void:
	var heading := Label.new()
	heading.text = "BACKGROUND"
	heading.add_theme_font_size_override("font_size", 12)
	voli_controls.add_child(heading)
	_background_row = HBoxContainer.new()
	_background_row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for entry in [
		["played", "You played"],
		["coached", "You coached"],
		["analysed", "You analysed"],
		["new", "You're new to this"],
	]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = str(entry[1])
		button.set_meta("value", str(entry[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			manager_background = str(entry[0])
		)
		_background_row.add_child(button)
	voli_controls.add_child(_background_row)


func _build_volleyball_questions() -> void:
	%IdentityHeader.visible = false
	for child in identity_tag_grid.get_children():
		child.queue_free()
	identity_tag_grid.columns = 4
	for question in VOLLEYBALL_QUESTIONS:
		var q_label := Label.new()
		q_label.text = str(question.question)
		q_label.custom_minimum_size = Vector2(285, 42)
		q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		identity_tag_grid.add_child(q_label)
		var group := ButtonGroup.new()
		for index in range(3):
			var choice: Dictionary = question.choices[index]
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(132, 42)
			button.text = str(choice.label)
			button.set_meta("question", str(question.key))
			button.set_meta("choice", index)
			button.pressed.connect(_volleyball_choice.bind(str(question.key), index))
			identity_tag_grid.add_child(button)


func _build_place_controls() -> void:
	var region_step := %RegionStep as VBoxContainer
	var home_label := Label.new()
	home_label.text = "HOME · Where are you from?"
	home_label.add_theme_font_size_override("font_size", 13)
	region_step.add_child(home_label)
	region_step.move_child(home_label, 0)
	_home_region_option = OptionButton.new()
	for region_name in VolleyballRegions.names():
		_home_region_option.add_item(region_name)
		_home_region_option.set_item_metadata(_home_region_option.item_count - 1, region_name)
	_home_region_option.item_selected.connect(_home_region_selected)
	region_step.add_child(_home_region_option)
	region_step.move_child(_home_region_option, 1)
	%RegionStep/Prompt.text = "WORK · Where does your career begin?"
	%AlignmentPreview.visible = false
	for child in tier_row.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		if str(button.get_meta("value", "")) == str(VolleyballRegions.TIER_MAJOR):
			button.text = "MAJOR REGION\nSeveral clubs · more developed infrastructure"
		else:
			button.text = "MINOR REGION\nFewer clubs · smaller institutions"


func _rewrite_club_route() -> void:
	%TypeStep/Prompt.text = "HOW DO YOU ENTER THE CLUB GAME?"
	for child in type_row.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		if str(button.get_meta("value", "")) == "Established":
			button.text = "LOOK FOR A JOB\nStart at an existing club in your work region."
		else:
			button.text = "FOUND A CLUB\nBegin a new institution in your work region."


func _build_management_step() -> void:
	var parent := %QuestionMargin as Container
	_management_step = VBoxContainer.new()
	_management_step.name = "ManagementStepV2"
	_management_step.visible = false
	_management_step.add_theme_constant_override("separation", 18)
	parent.add_child(_management_step)
	_management_step.add_child(_management_axis(
		"structure", "How much structure do you give your volis?",
		"Defined roles", "Guided freedom", "Player-led decisions"
	))
	_management_step.add_child(_management_axis(
		"squad", "What kind of squad do you want to build?",
		"Specialists", "Role flexibility", "Versatile players"
	))
	_management_step.add_child(_management_axis(
		"delegation", "How much do you keep in your own hands?",
		"Manager-led", "Shared responsibility", "Delegated"
	))


func _management_axis(key: String, question: String, left: String, middle: String, right: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.text = question
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	var labels := HBoxContainer.new()
	var left_label := Label.new()
	left_label.text = left
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(left_label)
	var middle_label := Label.new()
	middle_label.text = middle
	middle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(middle_label)
	var right_label := Label.new()
	right_label.text = right
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(right_label)
	box.add_child(labels)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.25
	slider.value = 0.5
	slider.custom_minimum_size = Vector2(0, 34)
	slider.value_changed.connect(func(value: float) -> void:
		management_values[key] = value
		_refresh_management_caption(key)
	)
	box.add_child(slider)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	_management_value_labels[key] = {"slider": slider, "label": value_label, "left": left, "middle": middle, "right": right}
	return box


func _rewrite_signature() -> void:
	%SaveLabel.visible = false
	career_name_edit.visible = false
	%OrgLabel.text = "CLUB NAME"
	organization_name_edit.placeholder_text = "Club name"


func _build_save_setup_step() -> void:
	var parent := %QuestionMargin as Container
	_save_setup_step = VBoxContainer.new()
	_save_setup_step.name = "SaveSetupStepV2"
	_save_setup_step.visible = false
	_save_setup_step.add_theme_constant_override("separation", 14)
	parent.add_child(_save_setup_step)
	var save_label := Label.new()
	save_label.text = "SAVE NAME"
	_save_setup_step.add_child(save_label)
	career_name_edit.reparent(_save_setup_step)
	career_name_edit.visible = true
	career_name_edit.placeholder_text = "Manager · Club"
	var world_label := Label.new()
	world_label.text = "WORLD START"
	_save_setup_step.add_child(world_label)
	var world_value := Label.new()
	world_value.text = "Canonical start"
	world_value.add_theme_font_size_override("font_size", 17)
	_save_setup_step.add_child(world_value)
	var advanced := Label.new()
	advanced.text = "ADVANCED"
	_save_setup_step.add_child(advanced)
	_seed_label = Label.new()
	_save_setup_step.add_child(_seed_label)
	career_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_seed_label())


func _show_step() -> void:
	if not _v2_ready:
		super._show_step()
		return
	for index in range(step_panels.size()):
		step_panels[index].visible = index == current_step
		step_labels[index].modulate = UIPalette.color(
			&"accent" if index == current_step else &"ink_faint", light_mode_enabled
		)
	step_kicker.text = "SAVE SETUP" if current_step == 6 else "QUESTION %d OF 6" % (current_step + 1)
	match current_step:
		0:
			question_title.text = "Who are you?"
			question_hint.text = "Choose how you look and where your professional history begins. Drag the voli to turn them."
		1:
			question_title.text = "What does your volleyball look like?"
			question_hint.text = "Six questions about how your team plays."
		2:
			question_title.text = "Where are you from, and where do you begin?"
			question_hint.text = "Choose where you're from, then where your career begins."
		3:
			question_title.text = "How do you enter the club game?"
			question_hint.text = "Take an existing institution or found a new one."
		4:
			question_title.text = "How do you want to manage?"
			question_hint.text = "These are starting tendencies, not permanent manager attributes."
		5:
			question_title.text = "Ready to begin?"
			question_hint.text = "Review your manager, club, volleyball and management choices."
			_refresh_review_v2()
		6:
			question_title.text = "Before the first day"
			question_hint.text = "Save metadata only. Your manager, volleyball and starting circumstances are already set."
			_refresh_seed_label()
	previous_button.text = "Back to title" if current_step == 0 else "Previous"
	if current_step == 6:
		next_button.text = "Begin career"
	elif current_step == 0:
		next_button.text = "Yup, this is me!"
	elif current_step == 4:
		next_button.text = "Yup, that's how I'll manage."
	elif current_step == 5:
		next_button.text = "Let's get to work."
	else:
		next_button.text = "Continue"


func _next() -> void:
	if not _v2_ready:
		super._next()
		return
	error_label.text = ""
	if current_step < step_panels.size() - 1:
		current_step += 1
		_show_step()
		return
	_create_career_v2()


func _previous() -> void:
	if not _v2_ready:
		super._previous()
		return
	error_label.text = ""
	if current_step == 0:
		back_requested.emit()
		return
	current_step -= 1
	_show_step()


func _home_region_selected(index: int) -> void:
	home_region = str(_home_region_option.get_item_metadata(index))
	if manager_name_tracks_region:
		_suggest_manager_name_from_home()


func _select_region(region_name: String) -> void:
	if not _v2_ready:
		super._select_region(region_name)
		return
	selected_region = region_name
	tier_hint.text = VolleyballRegions.definition(selected_region).tagline
	_refresh_seed_label()


func _select_tier(tier: StringName) -> void:
	if not _v2_ready:
		super._select_tier(tier)
		return
	selected_tier = tier
	_select_button_with_metadata(tier_row, str(tier))
	_fill_region_grid()
	_refresh_seed_label()


func _volleyball_choice(question_key: String, choice_index: int) -> void:
	volleyball_answers[question_key] = choice_index
	_rebuild_principles_from_volleyball()


func _rebuild_principles_from_volleyball() -> void:
	var buckets: Dictionary = {}
	for question in VOLLEYBALL_QUESTIONS:
		var index := int(volleyball_answers.get(str(question.key), 1))
		var choice: Dictionary = question.choices[index]
		for axis in choice.values:
			if not buckets.has(axis):
				buckets[axis] = []
			buckets[axis].append(float(choice.values[axis]))
	selected_values = {
		"decisiveness": 0.5,
		"pin_focus": 0.5,
		"tempo_variation": 0.5,
		"emotional_expression": 0.5,
		"serve_aggression": 0.5,
		"transition_commitment": 0.5,
		"block_commitment": 0.5,
	}
	for axis in buckets:
		var values: Array = buckets[axis]
		var total := 0.0
		for value in values:
			total += float(value)
		selected_values[axis] = total / maxf(float(values.size()), 1.0)
	_sync_v2_volleyball_buttons()


func _sync_v2_controls() -> void:
	_select_button_with_metadata(_background_row, manager_background)
	for index in range(_home_region_option.item_count):
		if str(_home_region_option.get_item_metadata(index)) == home_region:
			_home_region_option.select(index)
	_select_button_with_metadata(tier_row, str(selected_tier))
	_fill_region_grid()
	_select_button_with_metadata(type_row, selected_type)
	_sync_v2_volleyball_buttons()
	for key in management_values:
		var entry: Dictionary = _management_value_labels[key]
		(entry.slider as HSlider).value = float(management_values[key])
		_refresh_management_caption(key)
	if organization_name_edit.text.strip_edges().is_empty():
		organization_name_edit.text = "Harbor City VC"
	if career_name_edit.text.strip_edges().is_empty():
		career_name_edit.text = "%s · %s" % [manager_name, organization_name_edit.text]
	_refresh_seed_label()


func _sync_v2_volleyball_buttons() -> void:
	if identity_tag_grid == null:
		return
	for child in identity_tag_grid.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var key := str(button.get_meta("question", ""))
		button.button_pressed = int(button.get_meta("choice", -1)) == int(volleyball_answers.get(key, 1))


func _refresh_management_caption(key: String) -> void:
	var entry: Dictionary = _management_value_labels[key]
	var value := float(management_values[key])
	var caption := str(entry.middle)
	if value <= 0.01:
		caption = str(entry.left)
	elif value >= 0.99:
		caption = str(entry.right)
	elif value < 0.5:
		caption = "Leans toward %s" % str(entry.left).to_lower()
	elif value > 0.5:
		caption = "Leans toward %s" % str(entry.right).to_lower()
	(entry.label as Label).text = caption


func _suggest_manager_name_from_home() -> void:
	manager_name = ManagerProfile.suggested_name(home_region, absi(hash(home_region)))
	if _manager_name_edit != null:
		_manager_name_edit.set_block_signals(true)
		_manager_name_edit.text = manager_name
		_manager_name_edit.set_block_signals(false)


func _refresh_review_v2() -> void:
	var volleyball_lines: Array[String] = []
	for question in VOLLEYBALL_QUESTIONS:
		var index := int(volleyball_answers.get(str(question.key), 1))
		volleyball_lines.append(str(question.choices[index].label))
	var management_lines := [
		"Structure      %s" % _management_caption_text("structure"),
		"Squad building %s" % _management_caption_text("squad"),
		"Responsibility %s" % _management_caption_text("delegation"),
	]
	review_text.text = "[font_size=24][b]%s[/b][/font_size]\n%s\n\n[b]HOME[/b]  %s\n[b]WORK[/b]  %s\n[b]CLUB[/b]  %s\n\n[b]VOLLEYBALL[/b]\n%s\n\n[b]MANAGEMENT[/b]\n%s" % [
		manager_name if not manager_name.is_empty() else "Unnamed manager",
		_background_label(), home_region, selected_region,
		organization_name_edit.text if not organization_name_edit.text.is_empty() else "Unnamed club",
		" · ".join(volleyball_lines),
		"\n".join(management_lines),
	]


func _management_caption_text(key: String) -> String:
	var entry: Dictionary = _management_value_labels[key]
	var value := float(management_values[key])
	if value <= 0.01:
		return str(entry.left)
	if value >= 0.99:
		return str(entry.right)
	if value < 0.5:
		return "%s-leaning" % str(entry.left)
	if value > 0.5:
		return "%s-leaning" % str(entry.right)
	return str(entry.middle)


func _background_label() -> String:
	match manager_background:
		"played": return "You played"
		"coached": return "You coached"
		"analysed": return "You analysed"
		_: return "You're new to this"


func _refresh_seed_label() -> void:
	if _seed_label == null:
		return
	var seed_value := absi((career_name_edit.text + selected_region + selected_type).hash())
	_seed_label.text = "Seed  %d\nGenerated from the current save name, work region and club route." % seed_value


func _create_career_v2() -> void:
	if career_name_edit.text.strip_edges().is_empty():
		career_name_edit.text = "%s · %s" % [manager_name, organization_name_edit.text]
	var error := CareerManager.create_career(
		career_name_edit.text,
		organization_name_edit.text,
		selected_region,
		selected_type,
		"Your Volleyball",
		selected_values,
		{
			"name": manager_name,
			"region": home_region,
			"background": manager_background,
			"hand": str(appearance.hand),
			"appearance": appearance.duplicate(true),
		},
	)
	error_label.text = error
	if error.is_empty():
		career_created.emit()
