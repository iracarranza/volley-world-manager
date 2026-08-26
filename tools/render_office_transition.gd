extends SceneTree
## Compact review capture of the live MainMenu -> Desk move. Four rendered
## frames elapse between PNGs, so 28 captures cover the full 1.55s transition
## without spending CI time encoding dozens of near-identical full-size PNGs.

const APPLICATION := preload("res://scenes/application.tscn")
const OUTPUT_DIR := "res://artifacts/office-transition"
const FRAME_COUNT := 28

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var app := APPLICATION.instantiate()
	root.add_child(app)
	for _i in 18:
		await process_frame
	var title := app.get_node("TitleScreen") as VolleyballTitleScreen
	var office := app.get_node("OfficeShell") as CanonicalOfficeShell
	office.set_title_idle(false)
	_save(0)
	title.play_desk_departure()
	office.play_to(&"Desk", 1.55)
	var swapped := false
	for index in range(1, FRAME_COUNT):
		for _frame in 4:
			await process_frame
		if not swapped and StringName(office.get("_active_name")) == &"Desk":
			# Application hides the title at exactly this point before showing the
			# transparent Desk layer. The review only needs the visual endpoint.
			title.visible = false
			swapped = true
			await process_frame
		_save(index)
	quit()

func _save(index: int) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/frame_%02d.png" % [OUTPUT_DIR, index]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("OFFICE_TRANSITION_RENDER ", path)
