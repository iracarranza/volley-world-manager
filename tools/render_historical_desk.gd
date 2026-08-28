extends Node

const DeskScreenScript := preload("res://scenes/screens/desk_screen.gd")
const OUTPUT_DIR := "res://artifacts/historical-desk"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	var desk := DeskScreenScript.new()
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(desk)
	for _i in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "%s/desk_historical.png" % OUTPUT_DIR
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not write %s: %s" % [path, error_string(err)])
	else:
		print("HISTORICAL_DESK_RENDER ", path)
	get_tree().quit()
