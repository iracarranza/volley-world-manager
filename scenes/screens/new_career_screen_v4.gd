extends "res://scenes/screens/new_career_screen_v3.gd"

const PRODUCTION_VOLLEYBALL_PREVIEW := preload(
	"res://scenes/components/production_volleyball_philosophy_preview.gd"
)


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

	_volleyball_preview = PRODUCTION_VOLLEYBALL_PREVIEW.new() as VolleyballPhilosophyPreview
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
