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
	print("Rendered live creation flow with project theme to %s" % OUTPUT_DIR)
	quit()


func _capture(screen: Control, step: int, file_name: String) -> void:
	screen.debug_jump_to_step(step)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		quit(1)
