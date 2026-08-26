extends SceneTree
## Renders the actual application title screen, not a reconstructed mockup.
## The application scene is instantiated so its real theme, title scene and
## startup styling path are exercised.

const APPLICATION := preload("res://scenes/application.tscn")
const OUTPUT_DIR := "res://artifacts/current-title-screen"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var app := APPLICATION.instantiate()
	root.add_child(app)
	# Let Application._ready(), deferred title routing, theme application and
	# layout settle before reading the rendered viewport.
	for _i in 12:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/title_screen.png" % OUTPUT_DIR
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("TITLE_RENDER ", path)
	quit()
