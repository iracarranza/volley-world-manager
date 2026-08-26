extends SceneTree
## Captures the actual title-overlay fade and persistent office camera move as a
## numbered PNG sequence. This certifies that one room survives MainMenu -> Desk.

const APPLICATION := preload("res://scenes/application.tscn")
const OUTPUT_DIR := "res://artifacts/office-transition"
const FRAME_COUNT := 32

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
	# Start both asynchronous presentation actions without awaiting either so the
	# captured sequence is the composition the player actually sees.
	title.play_desk_departure()
	office.play_to(&"Desk", 1.55)
	for index in range(1, FRAME_COUNT):
		# Two rendered frames between captures gives a compact but smooth review
		# sequence without making CI artifacts unnecessarily large.
		await process_frame
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
