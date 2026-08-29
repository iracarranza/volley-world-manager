extends "res://scenes/screens/new_career_screen_v2.gd"

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
	## Compact toggles inherited the global button's 28 px of horizontal content
	## margin. At 72 px wide that left the body labels with roughly 44 px, so a
	## pressed/focused choice could clip differently from the same unpressed text.
	## Keep the global theme untouched and give only this dense editor stable,
	## symmetric content margins in every interaction state.
	for node in voli_controls.find_children("*", "Button", true, false):
		_stabilize_editor_toggle(node as Button)
	voli_controls.add_theme_constant_override("separation", 4)


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


## The club fork names the kind of commitment, not a crude difficulty preset.
## The deeper vacancy/founding flows are specified in CHARACTER_CREATION §04,
## but they should only become live controls when their consequences are backed
## by world state rather than invented by this screen.
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
## geometry is part of the CI evidence rather than something a static first frame
## can never catch.
func debug_select_body_for_render(body_type: String) -> void:
	_select_body_type(body_type)


func debug_select_club_route_for_render(type_name: String) -> void:
	_select_type(type_name)
	_select_button_with_metadata(type_row, type_name)


## Keep implementation status out of player-facing copy. The builder can be an
## incomplete implementation without announcing its seams inside the fiction.
func _show_step() -> void:
	super._show_step()
	if not _v2_ready:
		return
	match current_step:
		1:
			question_hint.text = "Six visible decisions. None is a quality score."
		3:
			question_hint.text = "Take an existing institution or found a new one."
