extends SceneTree
## Captures the actual application title treatment over the live office and the
## transparent Desk interaction layer over the same persistent room.

const APPLICATION := preload("res://scenes/application.tscn")
const DESK := preload("res://scenes/screens/desk_screen.gd")
const OUTPUT_DIR := "res://artifacts/integrated-office-ui"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var app := APPLICATION.instantiate()
	root.add_child(app)
	for _i in 18:
		await process_frame
	_save("title")

	# Build the same Desk overlay Application uses, but without requiring a save
	# fixture merely to certify visual integration.
	var title := app.get_node("TitleScreen") as Control
	var office_shell := app.get_node("OfficeShell") as CanonicalOfficeShell
	title.visible = false
	var desk := DESK.new() as DeskScreen
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(desk)
	office_shell.visible = true
	office_shell.snap_to(&"Desk")
	for _i in 8:
		await process_frame
	_save("desk")
	quit()

func _save(name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("INTEGRATED_OFFICE_RENDER ", path)
