extends SceneTree

const Encyclopedia := preload("res://scenes/screens/encyclopedia_screen.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")

const OUT := "res://artifacts/world-geography"
const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var screen := Encyclopedia.new()
	screen.theme = DarkTheme
	screen.position = Vector2.ZERO
	screen.size = Vector2(SIZE)
	viewport.add_child(screen)
	await process_frame
	UIStyleSystem.apply(screen, false)
	screen.open_world_register("Landavol")
	await _save(viewport, "world_register.png")
	screen.open_world_register("Pāwa Hitō")
	await _save(viewport, "world_register_pawa.png")

	screen.queue_free()
	viewport.queue_free()
	await process_frame
	print("Rendered World Register proof to %s" % OUT)
	quit(0)


func _save(viewport: SubViewport, file_name: String) -> void:
	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := "%s/%s" % [OUT, file_name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
