extends Node
## Application-level routing test. This runs as an ordinary project scene rather
## than with Godot's `--script` MainLoop override, so the project's GameManager
## and CareerManager autoload identifiers exist exactly as they do in gameplay.

const NavigationScript := preload("res://scenes/components/career_navigation.gd")
const ApplicationScene := preload("res://scenes/application.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := ApplicationScene.instantiate()
	add_child(app)
	for _i in 8:
		await get_tree().process_frame

	var nav := app.get_node("CareerNavigation") as CareerNavigation
	var workspace_host := app.get_node("CareerWorkspaceHost") as Control
	_expect(nav != null, "Application owns one persistent navigation shell")
	_expect(workspace_host != null, "Application owns one ordinary-workspace host")
	_expect(is_equal_approx(workspace_host.offset_top, NavigationScript.HEADER_HEIGHT), "workspace host reserves the navigation header height")
	_expect(not nav.visible and nav.current_destination().is_empty(), "Title suppresses ordinary career navigation")

	app.call("_ensure_training_screen")
	var training := app.get("_training_screen") as Control
	app.call("_swap_to", training)
	await get_tree().process_frame
	_expect(nav.current_destination() == &"training", "Training is a peer destination")
	_expect(training.get_parent() == workspace_host, "Training lives in the shared ordinary-workspace host")
	_expect(_has_back_route(training, app), "Training Back route remains wired as a compatibility fallback")
	_expect_no_visible_shell_navigation(training, "Training")

	app.call("_ensure_schedule_screen")
	var calendar := app.get("_schedule_screen") as Control
	app.call("_swap_to", calendar)
	await get_tree().process_frame
	_expect(nav.current_destination() == &"calendar", "Calendar is a first-class peer destination")
	_expect(calendar.get_parent() == workspace_host, "Calendar lives in the shared ordinary-workspace host")
	_expect(_has_back_route(calendar, app), "Calendar Back route remains wired as a compatibility fallback")
	_expect_no_visible_shell_navigation(calendar, "Calendar")

	for entry in [
		["_ensure_scouting_screen", "_scouting_screen", &"scouting"],
		["_ensure_accommodation_screen", "_accommodation_screen", &"housing"],
		["_ensure_kitchen_screen", "_kitchen_screen", &"kitchen"],
		["_ensure_encyclopedia_screen", "_encyclopedia_screen", &"encyclopedia"],
	]:
		app.call(str(entry[0]))
		var screen := app.get(str(entry[1])) as Control
		app.call("_swap_to", screen)
		await get_tree().process_frame
		_expect(nav.current_destination() == entry[2], "%s is a peer destination" % entry[2])
		_expect(screen.get_parent() == workspace_host, "%s shares the ordinary-workspace host" % entry[2])
		_expect(_has_back_route(screen, app), "%s Back route remains wired as a compatibility fallback" % entry[2])
		_expect_no_visible_shell_navigation(screen, str(entry[2]))

	var journal := app.get_node("CareerWorkspaceHost/Journal") as Control
	app.call("_swap_to", journal)
	app.call("_apply_journal_vocabulary")
	await get_tree().process_frame
	_expect(nav.current_destination() == &"journal", "Journal is a peer destination, not the hub")
	_expect(journal.get_parent() == workspace_host, "Journal shares the ordinary-workspace host")
	var section_title := journal.get_node_or_null("%SectionTitle") as Label
	_expect(section_title != null and section_title.text == "Current", "Journal presents Current rather than Home")
	for node in journal.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and str(button.get_meta("section", "")) == "Home":
			_expect(button.text == "Current", "Journal navigation translates legacy Home id to Current")
		if button != null and button.get_parent() != null and button.get_parent().name == &"Header" \
				and button.text in NavigationScript.JOURNAL_LEGACY_PEERS:
			_expect(not button.visible, "Journal suppresses duplicate %s peer button" % button.text)

	app.call("_ensure_desk_screen")
	var desk := app.get("_desk_screen") as Control
	var office_shell := app.get_node("OfficeShell") as CanonicalOfficeShell
	office_shell.snap_to(&"Desk")
	app.call("_swap_to", desk)
	await get_tree().process_frame
	_expect(nav.current_destination() == &"desk", "Desk remains the spatial home destination")
	_expect(desk.get_parent() == app, "Desk remains a full-screen spatial layer outside the inset workspace host")

	app.call("_ensure_lock_in_screen")
	var lock_in := app.get("_lock_in_screen") as Control
	_expect(lock_in.get_parent() == app, "Lock-In remains a presence layer outside ordinary workspace geometry")

	var match_center := app.get_node("MatchCenter") as Control
	app.call("_swap_to", match_center)
	await get_tree().process_frame
	_expect(not nav.visible and nav.current_destination().is_empty(), "presence mode suppresses ordinary navigation")

	if _failures.is_empty():
		print("APPLICATION_NAVIGATION_TEST PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("APPLICATION_NAVIGATION_TEST " + failure)
		get_tree().quit(1)


func _has_back_route(screen: Object, app: Object) -> bool:
	if screen == null or not screen.has_signal("back_requested"):
		return false
	var expected := Callable(app, "_show_desk")
	for connection in screen.get_signal_connection_list("back_requested"):
		if connection.get("callable") == expected:
			return true
	return false


func _expect_no_visible_shell_navigation(screen: Control, label: String) -> void:
	for node in screen.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.get_parent() == null:
			continue
		if button.get_parent().name == &"ScreenRibbon" \
				and button.text in NavigationScript.WORKSPACE_REDUNDANT_ACTIONS:
			_expect(not button.visible, "%s suppresses duplicate ribbon action %s" % [label, button.text])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
