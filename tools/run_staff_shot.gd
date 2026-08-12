extends Node

## The staff hub, as a picture.
##
##     xvfb-run -a godot --path . res://tools/staff_shot.tscn
##
## A draft, shot to be argued with. One frame per person, because the whole
## claim being tested is that four people read as four *correspondences* rather
## than as four rows of a table -- and one frame of one of them cannot show that.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Staff Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## A line to somewhere else, so the chef has both a paste they know and one
	## they are still learning -- which is the whole mechanic on one screen.
	game_manager.team.supply_lines.assign(["Xérvu"])
	## And weeks of cooking, so familiarity is off its baseline. A shot at week
	## one is a shot of every number at its default, which proves nothing.
	for _week in range(9):
		career_manager.advance_week()
		for fixture in career_manager.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career_manager.career.absolute_week):
				career_manager.simulate_fixture(int(fixture.id))
				break

	for light_mode in [false, true]:
		var screen: Control = load("res://scenes/screens/staff_screen.gd").new()
		screen.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		screen.bind(career_manager, game_manager)
		load("res://scripts/systems/ui_style_system.gd").apply(screen, light_mode)
		## The hub with nothing open, which is the state a manager arrives in and
		## the one a shot of an open panel cannot show.
		for _settle in range(4):
			await get_tree().process_frame
		var hub := "user://staff_%s_hub.png" % ("molten" if light_mode else "mikasa")
		get_viewport().get_texture().get_image().save_png(hub)
		print("saved %s" % ProjectSettings.globalize_path(hub))
		for entry in career_manager.career.staff:
			screen._open(int(entry.id))
			for _settle in range(4):
				await get_tree().process_frame
			var path := "user://staff_%s_%s.png" % [
				"molten" if light_mode else "mikasa",
				str(entry.role).to_lower().replace(" ", "_"),
			]
			get_viewport().get_texture().get_image().save_png(path)
			print("saved %s" % ProjectSettings.globalize_path(path))
		screen.queue_free()
		await get_tree().process_frame
