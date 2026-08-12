extends Node

## The desk, as a picture.
##
##     xvfb-run -a godot --path . res://tools/desk_shot.tscn


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Desk Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## A few weeks in, so the journal has something unread and the desk has
	## something true to say. A desk shot on week one proves only that it draws.
	for _week in range(5):
		career_manager.advance_week()

	for light_mode in [false, true]:
		var screen: Control = load("res://scenes/screens/desk_screen.gd").new()
		screen.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		screen.bind(career_manager, game_manager)
		load("res://scripts/systems/ui_style_system.gd").apply(screen, light_mode)
		var tag := "molten" if light_mode else "mikasa"
		for _settle in range(5):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://desk_%s.png" % tag)
		print("saved desk_%s" % tag)
		screen.queue_free()
		await get_tree().process_frame
