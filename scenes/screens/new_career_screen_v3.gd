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
			if child is Control:
				(child as Control).custom_minimum_size.x = 72.0
	for key in _slider_labels:
		var entry: Dictionary = _slider_labels[key]
		var slider := entry.get("slider") as HSlider
		if slider != null:
			slider.custom_minimum_size.x = 118.0
	voli_controls.add_theme_constant_override("separation", 4)


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
