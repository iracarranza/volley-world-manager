extends SceneTree

## Build the lock-in board against a real career and print what it says.
##
##     godot --headless --path . --script res://tools/run_lock_in_board.gd
##
## The suite cannot reach this screen. It builds its whole body in `refresh()`
## out of managers and a career, so a wrong field name on a fixture or a player
## is a runtime error on the one frame the board is shown and nothing before
## then -- and `tests/test_runner.gd` has no tree to add a `Control` to.
##
## So this stands the board up the way `application.gd` does, plays a fixture
## through so the opponent panel has a completed meeting to print, and dumps
## every label in tree order. Read it for two things: no error lines, and
## figures that are not all zero. An opponent table of zeroes means the
## statistics never reached the fixture, which is the state this whole screen
## was blocked on.
func _initialize() -> void:
	var career_manager: Object = load("res://scripts/managers/career_manager.gd").new()
	var game_manager: Object = load("res://scripts/managers/game_manager.gd").new()
	get_root().add_child(game_manager)
	get_root().add_child(career_manager)
	## Handed over rather than resolved off `/root/GameManager`, so this probe
	## reads the manager it just built instead of whichever one the autoload
	## table happened to stand up.
	career_manager.game_manager_override = game_manager

	var error: String = career_manager.create_career(
		"Lock In Probe", "Probe VC", "Landavol", "Club", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		quit()
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

	var board: Control = load("res://scenes/screens/lock_in_screen.gd").new()
	get_root().add_child(board)
	board.bind(career_manager, game_manager)
	board.refresh()
	print("--- board (%d nodes) ---" % board.get_child_count())
	_dump(board, 0)
	quit()


func _dump(node: Node, depth: int) -> void:
	if node is Label:
		var text := str((node as Label).text)
		if not text.is_empty():
			print("%s%s" % ["  ".repeat(depth), text])
	elif node is Button:
		print("%s[%s]" % ["  ".repeat(depth), str((node as Button).text)])
	for child in node.get_children():
		_dump(child, depth + 1)
