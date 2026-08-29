extends "res://scenes/screens/new_career_screen_v2.gd"

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
