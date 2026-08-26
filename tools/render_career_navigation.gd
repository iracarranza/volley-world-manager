extends SceneTree
## Fast review packet for the consolidated ordinary-career navigation shell.
## This deliberately avoids save creation and simulation work: it renders the
## actual Application tree and swaps among already-defined workspace states.

const APPLICATION := preload("res://scenes/application.tscn")
const OUTPUT_DIR := "res://artifacts/career-navigation"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var app := APPLICATION.instantiate()
	root.add_child(app)
	for _i in 12:
		await process_frame

	var journal := app.get_node("Journal") as Control
	app.call("_apply_journal_vocabulary")
	app.call("_swap_to", journal)
	await _settle()
	_save("journal")

	app.call("_ensure_training_screen")
	var training := app.get("_training_screen") as Control
	app.call("_swap_to", training)
	await _settle()
	_save("training")

	app.call("_ensure_desk_screen")
	var desk := app.get("_desk_screen") as Control
	app.call("_swap_to", desk)
	await _settle()
	_save("desk")
	quit()


func _settle() -> void:
	for _i in 10:
		await process_frame


func _save(name_: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name_]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("CAREER_NAVIGATION_RENDER ", path)
