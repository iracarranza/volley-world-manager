extends Node

## The phone ringing over the board it interrupted.
##
##     xvfb-run -a godot --path . res://tools/phone_shot.tscn


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Phone Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	for light_mode in [false, true]:
		var screen: Control = load("res://scenes/screens/scouting_screen.gd").new()
		screen.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		screen.bind(career_manager, game_manager)
		load("res://scripts/systems/ui_style_system.gd").apply(screen, light_mode)
		var call_panel: Control = load("res://scenes/components/call_intrusion.gd").build()
		screen.add_child(call_panel)
		call_panel.ring(
			"Your scout", "Something strange is happening with Mendoza.", true
		)
		var tag := "molten" if light_mode else "mikasa"
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://phone_%s.png" % tag)
		print("saved phone_%s" % tag)
		screen.queue_free()
		await get_tree().process_frame
