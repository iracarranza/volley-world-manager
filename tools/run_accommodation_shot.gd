extends Node

## The accommodation page, as a picture.
##
##     xvfb-run -a godot --path . res://tools/accommodation_shot.tscn
##
## The gates prove the arithmetic: block widths sum to `floor_used`, past the
## wall means crowded. They cannot say whether a room with three beds and a bath
## in it *reads* as overfull, and that is the whole argument for drawing a plan
## rather than printing two numbers.
##
## Shot in both themes and in two states -- a settled squad and a deliberately
## overcrowded one -- because the second is the state the page exists for and it
## is the one a screenshot of a fresh career would never show.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Object = load("res://scripts/managers/career_manager.gd").new()
	var game_manager: Object = load("res://scripts/managers/game_manager.gd").new()
	add_child(game_manager)
	add_child(career_manager)
	career_manager.game_manager_override = game_manager

	var error: String = career_manager.create_career(
		"Accommodation Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## A few weeks so the palate clock has moved off zero and the page has
	## something to show in its last column other than a wall of full weeks.
	for _week in range(6):
		career_manager.advance_week()

	for light_mode in [false, true]:
		for crowded in [false, true]:
			var team: Resource = game_manager.team
			if crowded:
				## §10's own example: two volis and a rack of weights is seven
				## floor in a room that holds five.
				team.housing_structure = "Bunkhouse"
				team.housing_occupants_per_room = 3
				team.housing_large_equipment.assign(["free_weights"])
				team.housing_small_equipment.assign(["console", "landline"])
				team.supply_lines.assign(["Pāwa Hitō"])
			else:
				team.housing_structure = "Farmhouse"
				team.housing_occupants_per_room = 2
				team.housing_large_equipment.assign([])
				team.housing_small_equipment.assign(["cookbook"])
				team.supply_lines.assign([])

			## The theme first, then the walk -- `application.gd`'s own order. A
			## probe that skips the theme shoots a dark card lit for the light
			## palette, which looks like a broken medium rather than a broken
			## harness.
			var page: Control = load(
				"res://scenes/screens/accommodation_screen.gd"
			).new()
			page.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
				else load("res://scenes/themes/dark_theme.tres")
			page.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(page)
			page.bind(career_manager, game_manager)
			load("res://scripts/systems/ui_style_system.gd").apply(page, light_mode)
			for _frame in range(6):
				await get_tree().process_frame
			var path := "user://accommodation_%s_%s.png" % [
				"molten" if light_mode else "mikasa",
				"crowded" if crowded else "settled",
			]
			get_viewport().get_texture().get_image().save_png(path)
			print("saved %s" % ProjectSettings.globalize_path(path))
			page.queue_free()
			await get_tree().process_frame
