extends Node

## The roster visualizer, once per position.
##
##     xvfb-run -a godot --path . res://tools/roster_pose_shot.tscn
##
## One image per position is the only check worth having here: the failure this
## feature exists to fix -- every voli standing in the same neutral stance -- is
## invisible in any single frame and obvious across five. `set_pose` also returns
## early unless `is_contact_actor` is true, and a version that gets that wrong
## renders perfectly well and identically five times over.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Roster Pose Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	for light_mode in [false, true]:
		var journal: Control = load(
			"res://scenes/screens/journal_screen.tscn"
		).instantiate()
		journal.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		journal.set_anchors_preset(Control.PRESET_FULL_RECT)
		var styler := load("res://scripts/systems/ui_style_system.gd")
		journal.set_meta(styler.MEDIUM_META, styler.MEDIUM_SEWN)
		add_child(journal)
		journal.refresh()
		styler.apply(journal, light_mode)
		journal._navigate("Roster")
		for _settle in range(4):
			await get_tree().process_frame

		## The first voli found for each position, so the sheet covers all five
		## rather than five of whatever the squad happens to be full of.
		var seen := {}
		var list: ItemList = journal.roster_list
		for index in range(list.item_count):
			var player = game_manager.player_by_id(
				int(list.get_item_metadata(index))
			)
			if player == null:
				continue
			var position := str(player.primary_position)
			if seen.has(position):
				continue
			seen[position] = true
			list.select(index)
			journal._roster_selected(index)
			for _settle in range(6):
				await get_tree().process_frame
			var tag := "molten" if light_mode else "mikasa"
			var slug := position.to_lower().replace(" ", "_")
			var path := "user://roster_%s_%s.png" % [tag, slug]
			get_viewport().get_texture().get_image().save_png(path)
			print("saved %s (%s)" % [path, player.display_name])
		journal.queue_free()
		await get_tree().process_frame
