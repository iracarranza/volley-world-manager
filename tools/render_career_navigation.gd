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

	var journal := app.get_node("CareerWorkspaceHost/Journal") as Control
	app.call("_apply_journal_vocabulary")
	app.call("_swap_to", journal)
	await _settle(journal)
	_save("journal")

	app.call("_ensure_training_screen")
	var training := app.get("_training_screen") as Control
	app.call("_swap_to", training)
	await _settle(training)
	_save("training")

	app.call("_ensure_scouting_screen")
	var scouting := app.get("_scouting_screen") as Control
	app.call("_swap_to", scouting)
	await _settle(scouting)
	_save("scouting")

	app.call("_ensure_schedule_screen")
	var calendar := app.get("_schedule_screen") as Control
	app.call("_swap_to", calendar)
	await _settle(calendar)
	_save("calendar")

	app.call("_ensure_accommodation_screen")
	var housing := app.get("_accommodation_screen") as Control
	app.call("_swap_to", housing)
	await _settle(housing)
	_save("housing")

	app.call("_ensure_kitchen_screen")
	var kitchen := app.get("_kitchen_screen") as Control
	app.call("_swap_to", kitchen)
	await _settle(kitchen)
	_save("kitchen")

	app.call("_ensure_encyclopedia_screen")
	var encyclopedia := app.get("_encyclopedia_screen") as Control
	app.call("_swap_to", encyclopedia)
	await _settle(encyclopedia)
	_save("encyclopedia")

	# Desk is spatial rather than a paper workspace. The review image must use the
	# same close seated camera that the real Desk destination uses, not whatever
	# office camera happened to be current when the renderer started.
	app.call("_ensure_desk_screen")
	var desk := app.get("_desk_screen") as Control
	var office_shell := app.get_node("OfficeShell") as CanonicalOfficeShell
	office_shell.snap_to(&"Desk")
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
