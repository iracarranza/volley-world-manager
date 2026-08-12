extends Node

## The board, as a picture rather than as a list of labels.
##
##     xvfb-run -a godot --path . res://tools/lock_in_shot.tscn
##
## `run_lock_in_board` dumps the text and proves the wiring; it cannot say
## whether the thing looks like a whiteboard. The draft in the lock-in artifact
## is a *visual* argument -- cards as magnets on melamine, marker rules edge to
## edge, a tray of pens -- and the only way to check a visual argument is to
## look at it.
##
## Shot in both themes, because `board` is the one medium whose light form is
## the *default* reading: a whiteboard in a gym is lit.


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Object = load("res://scripts/managers/career_manager.gd").new()
	var game_manager: Object = load("res://scripts/managers/game_manager.gd").new()
	add_child(game_manager)
	add_child(career_manager)
	## Handed over rather than resolved off `/root/GameManager`, so this probe
	## reads the manager it just built instead of whichever one the autoload
	## table happened to stand up.
	career_manager.game_manager_override = game_manager

	var error: String = career_manager.create_career(
		"Lock In Probe", "Probe VC", "Landavol", "Club", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	## One fixture simulated, so the board has a previous meeting to print and
	## the statistics path is exercised rather than assumed.
	## The calendar has to reach the fixture before it can be played; a brand new
	## career's first fixture is weeks out.
	for _step in range(60):
		var due: Resource = null
		for fixture in career_manager.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career_manager.career.absolute_week):
				due = fixture
				break
		if due != null:
			break
		career_manager.advance_week()

	var first: Resource = null
	for fixture in career_manager.career.fixtures:
		if not bool(fixture.completed) \
				and int(fixture.week) <= int(career_manager.career.absolute_week):
			first = fixture
			break
	if first != null:
		career_manager.simulate_fixture(int(first.id))

	var next: Resource = null
	for fixture in career_manager.career.fixtures:
		if not bool(fixture.completed):
			next = fixture
			break
	for _step in range(60):
		var any_due := false
		for fixture in career_manager.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career_manager.career.absolute_week):
				any_due = true
				break
		if any_due:
			break
		career_manager.advance_week()
	for fixture in career_manager.career.fixtures:
		if not bool(fixture.completed) \
				and int(fixture.week) <= int(career_manager.career.absolute_week):
			next = fixture
			break
	if next != null:
		var prepare_error: String = career_manager.prepare_fixture(int(next.id))
		if not prepare_error.is_empty():
			print("could not prepare a fixture: %s" % prepare_error)

	for light_mode in [true, false]:
		## **The theme first, then the walk.** `application.gd` sets the theme on
		## its own root and then calls `UIStyleSystem.apply`; the walk recolours
		## against whatever the theme already put there. A probe that skips the
		## theme gets a dark-theme card lit for the light palette -- which is what
		## the first shot showed, and it looked exactly like a broken medium
		## rather than a broken harness.
		var board: Control = load("res://scenes/screens/lock_in_screen.gd").new()
		board.theme = load("res://scenes/themes/light_theme.tres") if light_mode \
			else load("res://scenes/themes/dark_theme.tres")
		board.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(board)
		board.bind(career_manager, game_manager)
		board.refresh()
		## The same call `application.gd` makes when it shows a screen. The medium
		## is declared on the root inside `_build`, so this walk is what turns a
		## tree of bare Controls into melamine.
		load("res://scripts/systems/ui_style_system.gd").apply(board, light_mode)
		for _frame in range(6):
			await get_tree().process_frame
		var path := "user://lock_in_%s.png" % ("molten" if light_mode else "mikasa")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved %s" % ProjectSettings.globalize_path(path))
		board.queue_free()
		await get_tree().process_frame
