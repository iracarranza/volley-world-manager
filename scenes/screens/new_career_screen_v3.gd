extends "res://scenes/screens/new_career_screen_v2.gd"

const VOLLEYBALL_PREVIEW := preload("res://scenes/components/volleyball_philosophy_preview.gd")

## Presentation belongs here rather than in the tactical-value table inherited
## from v2. The values remain the career model's authority; this table explains
## one choice at a time and names the deterministic teaching vignette that shows
## the distinction on the production court.
const VOLLEYBALL_PAGES := [
	{
		"key": "good_ball",
		"question": "Your team gets a good first touch. How should they attack?",
		"choices": [
			{"label": "Quick attacks", "consequence": "Attack before the defense has time to organize.", "vignette": "good_ball_quick"},
			{"label": "Read the blockers", "consequence": "Keep several threats available, then use the block's commitment.", "vignette": "good_ball_read"},
			{"label": "Trust your hitters", "consequence": "Create a favorable contest and let the hitter solve it.", "vignette": "good_ball_hitter"},
		],
	},
	{
		"key": "serve",
		"question": "How should your team serve?",
		"choices": [
			{"label": "Controlled serves", "consequence": "Prioritize putting the serve in while still shaping the first contact.", "vignette": "serve_controlled"},
			{"label": "Target reception", "consequence": "Serve toward a receiver or seam you want to test.", "vignette": "serve_target"},
			{"label": "Aggressive serves", "consequence": "Trade a higher miss risk for more direct reception pressure.", "vignette": "serve_aggressive"},
		],
	},
	{
		"key": "defense",
		"question": "How should your team defend attacks?",
		"choices": [
			{"label": "Floor defense", "consequence": "Protect more floor and turn attacks into playable contacts.", "vignette": "defense_floor"},
			{"label": "Read the attack", "consequence": "Hold defensive choices longer and react to the developing hit.", "vignette": "defense_read"},
			{"label": "Commit the block", "consequence": "Put more defensive pressure at the net before the ball crosses.", "vignette": "defense_block"},
		],
	},
	{
		"key": "transition",
		"question": "Your team keeps a difficult attack alive. What should happen next?",
		"choices": [
			{"label": "Reset the play", "consequence": "Rebuild shape before trying to create a stronger attack.", "vignette": "transition_reset"},
			{"label": "Find the opportunity", "consequence": "Use the developing situation rather than forcing the planned pattern.", "vignette": "transition_opportunity"},
			{"label": "Attack in transition", "consequence": "Turn the save into an attack before the opponent fully resets.", "vignette": "transition_pressure"},
		],
	},
	{
		"key": "broken_first_contact",
		"question": "The first contact pulls your team out of position. How should they respond?",
		"choices": [
			{"label": "Recover the structure", "consequence": "Restore familiar spacing before building the attack.", "vignette": "broken_structure"},
			{"label": "Use what's available", "consequence": "Build the next contact around the players already in position.", "vignette": "broken_available"},
			{"label": "Keep the pressure on", "consequence": "Attack from the broken shape rather than giving the opponent time.", "vignette": "broken_pressure"},
		],
	},
	{
		"key": "construction",
		"question": "How should your attacks create opportunities?",
		"choices": [
			{"label": "Combination offense", "consequence": "Use linked attacker movements to create openings for each other.", "vignette": "construction_combination"},
			{"label": "Flexible offense", "consequence": "Keep several attack routes available and choose from the developing play.", "vignette": "construction_flexible"},
			{"label": "Isolation offense", "consequence": "Create a one-on-one or favorable matchup for a chosen hitter.", "vignette": "construction_isolation"},
		],
	},
]

var _volleyball_page_index := 0
var _volleyball_preview: VolleyballPhilosophyPreview
var _volleyball_progress: Label
var _volleyball_choice_row: HBoxContainer
var _volleyball_review: GridContainer


## The inherited editor was measured around the old five-step screen. With the
## background row added, its horizontal minimum became wider than the 1280x720
## project base and the whole HBox resolved partly off the left edge. Keep the
## production actor/viewer, but recover width from controls that do not need it.
func _ready() -> void:
	super._ready()
	var preview_frame := get_node_or_null(
		"Layout/MainMargin/Main/QuestionPanel/QuestionMargin/VoliStep/PreviewFrame"
	) as Control
	if preview_frame != null:
		preview_frame.custom_minimum_size.x = 220.0
	if _body_row != null:
		for child in _body_row.get_children():
			if child is Button:
				var button := child as Button
				button.custom_minimum_size = Vector2(72.0, 32.0)
				## The body is visible beside the controls. Its canonical type name is
				## enough; "grown", "ears up", "beak" etc. were tiny editorial
				## captions pretending to explain a silhouette the player can see.
				button.text = str(button.get_meta("value", ""))
	for key in _slider_labels:
		var entry: Dictionary = _slider_labels[key]
		var slider := entry.get("slider") as HSlider
		if slider != null:
			slider.custom_minimum_size.x = 118.0
	for node in voli_controls.find_children("*", "Button", true, false):
		_stabilize_editor_toggle(node as Button)
	voli_controls.add_theme_constant_override("separation", 4)
	_install_nested_volleyball_flow()
	if current_step == 1:
		_render_volleyball_page()


## `_sync_voli_controls` destroys and rebuilds coat buttons when body/variety
## changes. Styling only the first set in `_ready` therefore fixes the default
## screenshot but not the live control. Reapply the compact local style after
## every rebuild.
func _sync_voli_controls() -> void:
	super._sync_voli_controls()
	if voli_controls == null or not is_instance_valid(voli_controls):
		return
	for node in voli_controls.find_children("*", "Button", true, false):
		_stabilize_editor_toggle(node as Button)


func _stabilize_editor_toggle(button: Button) -> void:
	if button == null or not button.toggle_mode:
		return
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var source := button.get_theme_stylebox(state)
		if source == null:
			continue
		var style := source.duplicate() as StyleBox
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 5.0
		style.content_margin_bottom = 5.0
		button.add_theme_stylebox_override(state, style)


func _install_nested_volleyball_flow() -> void:
	for child in identity_tag_grid.get_children():
		child.free()
	identity_tag_grid.columns = 1
	identity_tag_grid.add_theme_constant_override("v_separation", 8)

	_volleyball_progress = Label.new()
	_volleyball_progress.add_theme_font_size_override("font_size", 12)
	identity_tag_grid.add_child(_volleyball_progress)

	var preview_heading := Label.new()
	preview_heading.text = "GAMEPLAY PREVIEW"
	preview_heading.add_theme_font_size_override("font_size", 12)
	identity_tag_grid.add_child(preview_heading)

	_volleyball_preview = VOLLEYBALL_PREVIEW.new() as VolleyballPhilosophyPreview
	_volleyball_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volleyball_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity_tag_grid.add_child(_volleyball_preview)

	_volleyball_choice_row = HBoxContainer.new()
	_volleyball_choice_row.add_theme_constant_override("separation", 8)
	identity_tag_grid.add_child(_volleyball_choice_row)

	_volleyball_review = GridContainer.new()
	_volleyball_review.columns = 2
	_volleyball_review.add_theme_constant_override("h_separation", 18)
	_volleyball_review.add_theme_constant_override("v_separation", 6)
	identity_tag_grid.add_child(_volleyball_review)


func _render_volleyball_page() -> void:
	if _volleyball_progress == null:
		return
	var reviewing := _volleyball_page_index >= VOLLEYBALL_PAGES.size()
	_volleyball_choice_row.visible = not reviewing
	_volleyball_review.visible = reviewing
	if reviewing:
		_render_volleyball_review()
	else:
		_render_volleyball_question()


func _render_volleyball_question() -> void:
	var page: Dictionary = VOLLEYBALL_PAGES[_volleyball_page_index]
	var key := str(page.key)
	var selected_index := clampi(int(volleyball_answers.get(key, 1)), 0, 2)
	var selected: Dictionary = page.choices[selected_index]
	step_kicker.text = "VOLLEYBALL · %d OF %d" % [_volleyball_page_index + 1, VOLLEYBALL_PAGES.size()]
	question_title.text = str(page.question)
	question_hint.text = str(selected.consequence)
	_volleyball_progress.text = "%d / %d" % [_volleyball_page_index + 1, VOLLEYBALL_PAGES.size()]
	previous_button.text = "Previous" if _volleyball_page_index == 0 else "Previous question"
	next_button.text = "Confirm choice"
	_set_preview(str(selected.vignette))

	for child in _volleyball_choice_row.get_children():
		child.free()
	var group := ButtonGroup.new()
	for index in range(3):
		var choice: Dictionary = page.choices[index]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.text = str(choice.label)
		button.set_meta("question", key)
		button.set_meta("choice", index)
		button.button_pressed = index == selected_index
		button.pressed.connect(_select_nested_volleyball_choice.bind(key, index))
		_volleyball_choice_row.add_child(button)


func _select_nested_volleyball_choice(question_key: String, choice_index: int) -> void:
	_volleyball_choice(question_key, choice_index)
	## Re-render after the press signal unwinds: the row being replaced contains
	## the button that emitted this signal.
	call_deferred("_render_volleyball_page")


func _set_preview(vignette_id: String) -> void:
	if _volleyball_preview != null:
		_volleyball_preview.set_vignette(vignette_id)


func _render_volleyball_review() -> void:
	step_kicker.text = "VOLLEYBALL · REVIEW"
	question_title.text = "Your volleyball"
	question_hint.text = "The six choices below become your starting tactical tendencies."
	_volleyball_progress.text = "6 choices"
	previous_button.text = "Previous question"
	next_button.text = "Yup, that's my volleyball."
	_set_preview("volleyball_montage")
	for child in _volleyball_review.get_children():
		child.free()
	for page in VOLLEYBALL_PAGES:
		var key := str(page.key)
		var selected_index := clampi(int(volleyball_answers.get(key, 1)), 0, 2)
		var key_label := Label.new()
		key_label.text = _volleyball_summary_label(key)
		key_label.add_theme_font_size_override("font_size", 12)
		_volleyball_review.add_child(key_label)
		var value_label := Label.new()
		value_label.text = str(page.choices[selected_index].label)
		value_label.add_theme_font_size_override("font_size", 15)
		_volleyball_review.add_child(value_label)


func _volleyball_summary_label(key: String) -> String:
	match key:
		"good_ball": return "GOOD BALL"
		"serve": return "SERVE"
		"defense": return "DEFENSE"
		"transition": return "TRANSITION"
		"broken_first_contact": return "BROKEN FIRST CONTACT"
		"construction": return "ATTACK CREATION"
		_: return key.to_upper()


## The club fork names the kind of commitment, not a crude difficulty preset.
func _rewrite_club_route() -> void:
	%TypeStep/Prompt.text = "HOW DO YOU ENTER THE CLUB GAME?"
	for child in type_row.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		if str(button.get_meta("value", "")) == "Established":
			button.text = "TAKE A JOB\nChoose an existing club and inherit its squad,\nexpectations, and circumstances."
		else:
			button.text = "FOUND A CLUB\nSet the backing and priorities that shape\na new club's starting conditions."


## Render probes use the same live controls as a player click so selected-state
## geometry and nested questionnaire states are part of CI evidence.
func debug_select_body_for_render(body_type: String) -> void:
	_select_body_type(body_type)


func debug_select_club_route_for_render(type_name: String) -> void:
	_select_type(type_name)
	_select_button_with_metadata(type_row, type_name)


func debug_show_volleyball_question_for_render(index: int, choice_index: int = -1) -> void:
	current_step = 1
	_volleyball_page_index = clampi(index, 0, VOLLEYBALL_PAGES.size() - 1)
	if choice_index >= 0:
		var page: Dictionary = VOLLEYBALL_PAGES[_volleyball_page_index]
		_volleyball_choice(str(page.key), clampi(choice_index, 0, 2))
	_show_step()


func debug_show_volleyball_review_for_render() -> void:
	current_step = 1
	_volleyball_page_index = VOLLEYBALL_PAGES.size()
	_show_step()


func _next() -> void:
	if not _v2_ready:
		super._next()
		return
	if current_step == 1:
		error_label.text = ""
		if _volleyball_page_index < VOLLEYBALL_PAGES.size():
			_volleyball_page_index += 1
			_render_volleyball_page()
			return
		current_step += 1
		_show_step()
		return
	super._next()


func _previous() -> void:
	if not _v2_ready:
		super._previous()
		return
	if current_step == 1 and _volleyball_page_index > 0:
		error_label.text = ""
		_volleyball_page_index -= 1
		_render_volleyball_page()
		return
	super._previous()


## Keep implementation status out of player-facing copy. The builder can be an
## incomplete implementation without announcing its seams inside the fiction.
func _show_step() -> void:
	super._show_step()
	if not _v2_ready:
		return
	match current_step:
		1:
			_render_volleyball_page()
		3:
			question_hint.text = "Take an existing institution or found a new one."
