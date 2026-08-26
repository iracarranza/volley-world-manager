extends Node
## Fast review packet for the consolidated ordinary-career navigation shell.
## This runs as an ordinary project scene so Application sees the same autoloads
## and initialization contract it has in gameplay.

const APPLICATION := preload("res://scenes/application.tscn")
const OUTPUT_DIR := "res://artifacts/career-navigation"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	var app := APPLICATION.instantiate()
	add_child(app)
	for _i in 14:
		await get_tree().process_frame

	var journal := app.get_node("Journal") as Control
	app.call("_apply_journal_vocabulary")
	app.call("_swap_to", journal)
	await _settle(journal)
	_save("journal")

	app.call("_ensure_training_screen")
	var training := app.get("_training_screen") as Control
	app.call("_swap_to", training)
	await _settle(training)
	_save("training")

	app.call("_ensure_desk_screen")
	var desk := app.get("_desk_screen") as Control
	app.call("_swap_to", desk)
	await _settle(desk)
	_save("desk")
	get_tree().quit()


func _settle(screen: Control) -> void:
	# _swap_to calls the normal reveal tween. Wait for it to finish so the review
	# packet judges the resting layout rather than an animation frame.
	for _i in 28:
		await get_tree().process_frame
	screen.modulate.a = 1.0


func _save(name_: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name_]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("CAREER_NAVIGATION_RENDER ", path)
