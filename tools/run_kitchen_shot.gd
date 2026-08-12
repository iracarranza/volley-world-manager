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
		## And with paste spread on it, which is the state the block exists for.
		var Larder := load("res://scripts/data/region_larder.gd")
		var paint = screen._paint_now()
		var ceiling: int = load("res://scripts/data/food_block.gd").paste_slots(
			career_manager.chef_rating()
		)
		## Cell coordinates and radii scale with the grid, so the probe paints the
		## same picture whatever `CANVAS` is. Written in absolute cells first, and
		## doubling the canvas quietly shrank every blob to a quarter of its area.
		var span := float(load("res://scripts/data/paste_paint.gd").CANVAS)
		for stroke in [
			[Vector2(0.28, 0.31), 0.17, "Landavol"], [Vector2(0.69, 0.41), 0.14, "Xérvu"],
			[Vector2(0.47, 0.72), 0.12, "Spëddigh"], [Vector2(0.37, 0.53), 0.11, "Landavol"],
		]:
			paint.paint(
				Vector2(stroke[0]) * span, float(stroke[1]) * span,
				Larder.paste_name(str(stroke[2])), ceiling
			)
		screen._paint_changed()
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://kitchen_%s_painted.png" % tag)
		print("saved kitchen_%s_painted" % tag)
		screen._open("paint")
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://kitchen_%s_painter.png" % tag)
		print("saved kitchen_%s_painter" % tag)
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
