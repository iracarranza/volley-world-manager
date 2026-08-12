extends Node

## The kitchen, as a picture.
##
##     xvfb-run -a godot --path . res://tools/kitchen_shot.tscn


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Kitchen Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## Two lines, so the mix has something to be a mix *of* and the chef has one
	## paste they know and two they are learning.
	game_manager.team.supply_lines.assign(["Xérvu", "Spëddigh"])
	for _week in range(9):
		career_manager.advance_week()
		for fixture in career_manager.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career_manager.career.absolute_week):
				career_manager.simulate_fixture(int(fixture.id))
				break

	for light_mode in [false, true]:
		var screen: Control = load("res://scenes/screens/kitchen_screen.gd").new()
		screen.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		screen.bind(career_manager, game_manager)
		load("res://scripts/systems/ui_style_system.gd").apply(screen, light_mode)
		var tag := "molten" if light_mode else "mikasa"
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://kitchen_%s.png" % tag)
		print("saved kitchen_%s" % tag)
		## And with a preset running, which is the state the two bars exist for.
		screen._nudge(load("res://scripts/data/region_larder.gd").paste_name("Landavol"), 0.3)
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://kitchen_%s_preset.png" % tag)
		print("saved kitchen_%s_preset" % tag)
		for card in ["block", "lines", "presets"]:
			screen._open(str(card))
			for _settle in range(3):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(
				"user://kitchen_%s_%s.png" % [tag, str(card)]
			)
			print("saved kitchen_%s_%s" % [tag, str(card)])
		screen.queue_free()
		await get_tree().process_frame
