extends Node

## The journal's own tabs, as pictures.
##
##     xvfb-run -a godot --path . res://tools/journal_shot.tscn
##
## Every other page in the game has a probe that draws it and none of the
## journal's seven sections did, which is why the Club tab could print four
## staff members who did not exist for as long as it did: nothing ever looked at
## it except by launching the game and clicking.
##
## Club and Team only. The other five are not what changed, and ten more frames
## of unchanged pages is not evidence of anything.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Journal Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## A few weeks so tenure, palate and form are off their opening values --
	## a shot of week one is a shot of every field at its default.
	for _week in range(4):
		career_manager.advance_week()

	for light_mode in [false, true]:
		var journal: Control = load(
			"res://scenes/screens/journal_screen.tscn"
		).instantiate()
		journal.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		journal.set_anchors_preset(Control.PRESET_FULL_RECT)
		## The journal is the one object made of cloth, and the medium is
		## declared by `application.gd` rather than by the scene -- a probe that
		## skips it shoots the journal in the default hand.
		var styler := load("res://scripts/systems/ui_style_system.gd")
		journal.set_meta(styler.MEDIUM_META, styler.MEDIUM_SEWN)
		add_child(journal)
		journal.refresh()
		styler.apply(journal, light_mode)
		## Club opens on its Staff sub-tab, which is where the staff hub now
		## lives -- the standalone page it was drafted as duplicated a submenu the
		## journal already had.
		for section in ["Club", "Team"]:
			journal._navigate(str(section))
			for _settle in range(4):
				await get_tree().process_frame
			var path := "user://journal_%s_%s.png" % [
				"molten" if light_mode else "mikasa", str(section).to_lower(),
			]
			get_viewport().get_texture().get_image().save_png(path)
			print("saved %s" % ProjectSettings.globalize_path(path))
		journal.queue_free()
		await get_tree().process_frame
