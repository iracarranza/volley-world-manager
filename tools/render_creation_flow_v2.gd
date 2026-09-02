extends SceneTree

## Renders the actual upgraded career builder, not a parallel mockup.
## The project theme is assigned explicitly because this tool instantiates the
## screen outside Application, where the inherited theme normally comes from.
## That means Short Stack remains the body/interface face and Cherry Bomb One
## remains available through the theme's heading variations; Godot's fallback
## UI font must never be the evidence used to judge a VWM screen.

const OUTPUT_DIR := "res://artifacts/creation-flow-drafts"
const SIZE := Vector2i(1280, 720)
const DARK_THEME := preload("res://scenes/themes/dark_theme.tres")
const CAREER_SCENE := preload("res://scenes/screens/new_career_screen_v2.tscn")
const CAPTURES := [
	[0, "01_you.png"],
	[1, "02_volleyball.png"],
	[2, "03_place.png"],
	[3, "04_club.png"],
	[4, "05_management.png"],
	[5, "06_signature.png"],
	[6, "save_setup.png"],
]
const VIGNETTE_FILES := [
	["02_q1_quick.png", "02_q1_read.png", "02_q1_hitter.png"],
	["02_q2_controlled.png", "02_q2_target.png", "02_q2_aggressive.png"],
	["02_q3_floor.png", "02_q3_read.png", "02_q3_block.png"],
	["02_q4_reset.png", "02_q4_opportunity.png", "02_q4_pressure.png"],
	["02_q5_structure.png", "02_q5_available.png", "02_q5_pressure.png"],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = SIZE
	var screen := CAREER_SCENE.instantiate()
	screen.theme = DARK_THEME
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	await process_frame
	await process_frame

	for capture in CAPTURES:
		await _capture(screen, int(capture[0]), str(capture[1]))

	## A default screenshot cannot prove that toggle text remains intact once the
	## pressed/focus style is active. Exercise one of the narrowest body controls
	## and one route card explicitly, then keep those frames in the same artifact.
	screen.debug_select_body_for_render("Simi")
	await _capture(screen, 0, "01_you_selected.png")
	screen.debug_select_club_route_for_render("Founded")
	await _capture(screen, 3, "04_club_selected.png")

	## A screenshot taken immediately after changing an animated vignette mostly
	## proves that all fifteen share a starting state. Freeze each Q1-Q5 option at
	## the same late decision/consequence fraction instead, so the artifact proves
	## whether the tactical distinctions are actually visible on the court.
	for question_index in range(VIGNETTE_FILES.size()):
		for choice_index in range(3):
			screen.debug_show_volleyball_question_for_render(question_index, choice_index)
			await process_frame
			await process_frame
			var preview := screen.get("_volleyball_preview") as Node
			if preview != null:
				preview.process_mode = Node.PROCESS_MODE_DISABLED
				preview.call("_apply_frame", 0.72)
			await _capture_current(str(VIGNETTE_FILES[question_index][choice_index]))
			if preview != null:
				preview.process_mode = Node.PROCESS_MODE_INHERIT

	## Keep the end of the nested sequence and the section-level review in the
	## same artifact as navigation evidence.
	screen.debug_show_volleyball_question_for_render(5, 2)
	await _capture_current("02_volleyball_q6_selected.png")
	screen.debug_show_volleyball_review_for_render()
	await _capture_current("02_volleyball_review.png")

	print("Rendered live creation flow with project theme to %s" % OUTPUT_DIR)
	quit()


func _capture(screen: Control, step: int, file_name: String) -> void:
	screen.debug_jump_to_step(step)
	await process_frame
	await process_frame
	await _capture_current(file_name)


func _capture_current(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		quit(1)
