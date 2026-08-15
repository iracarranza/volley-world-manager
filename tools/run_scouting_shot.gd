extends Node

## The folders, as a picture.
##
##     xvfb-run -a godot --path . res://tools/scouting_shot.tscn
##
## Shot with a mark on three of them, because an unmarked drawer proves the
## stagger and nothing else -- the point of the render is whether a pencil word
## on a tab is legible against manila in both themes.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Folder Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	## Play some, so the clippings strip has something true on it. A board shot
	## before any match has been played proves the strip draws and nothing else.
	for _week in range(4):
		career_manager.advance_week()
		for fixture in career_manager.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career_manager.career.absolute_week):
				career_manager.simulate_fixture(int(fixture.id))
				break

	for light_mode in [false, true]:
		var screen: Control = load("res://scenes/screens/scouting_screen.gd").new()
		screen.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		screen.bind(career_manager, game_manager)
		var marks: Dictionary = career_manager.career.scouting_marks
		var players: Array = game_manager.players
		for index in range(mini(players.size(), 6)):
			if index % 2 == 0:
				marks[int(players[index].id)] = 1 + (index % 3)
		screen.refresh()
		load("res://scripts/systems/ui_style_system.gd").apply(screen, light_mode)
		var tag := "molten" if light_mode else "mikasa"
		for _settle in range(6):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://scouting_%s.png" % tag)
		print("saved scouting_%s" % tag)
		## **Opened off the board's own list rather than off the roster.** This
		## shot used to open `players[0]`, which is somebody already asleep in the
		## club's own Bunkhouse -- so the panel drew a report and never the half
		## that says what joining would be, because you cannot offer a place to
		## somebody who has one. The board prefers the transfer pool now and the
		## probe has to ask the board.
		var board: Array = screen._prospects()
		if board.is_empty():
			print("nobody on the board to open")
			screen.queue_free()
			continue
		## Marked before opening, so the report shot shows a pin actually in the
		## card rather than three unpressed toggles -- the pressed state is the
		## only one that carries a pin colour now, and a probe that never presses
		## one cannot see whether it reads.
		career_manager.career.scouting_marks[int(board[0].id)] = 1
		screen._open(int(board[0].id))
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(
			"user://scouting_%s_report.png" % tag
		)
		print("saved scouting_%s_report" % tag)
		screen._panel.close_panel()
		screen._strip_open = true
		screen._refresh_strip_size()
		for _settle in range(4):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(
			"user://scouting_%s_cuttings.png" % tag
		)
		print("saved scouting_%s_cuttings" % tag)
		screen.queue_free()
		await get_tree().process_frame
