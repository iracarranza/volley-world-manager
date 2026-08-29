extends "res://scenes/screens/new_career_screen_v2.gd"

## A layout fix for the 1280x720 base resolution, and nothing else.
##
## It briefly owned a `_show_step` as well, which reassigned two of the six
## subtitles *after* `super._show_step()` had already assigned them -- trimming
## implementation talk out of steps 1 and 3 while the sentences it was replacing
## stayed behind in `new_career_screen_v2.gd`. Two strings per subtitle, and the
## one a reader finds first was the one the player never saw. The trims now live
## at the single site that authors the copy.

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
