extends SceneTree

const ApplicationScene := preload("res://scenes/application.tscn")
const NavigationScript := preload("res://scenes/components/career_navigation.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app := ApplicationScene.instantiate()
	root.add_child(app)
	for _i in 8:
		await process_frame

	var nav := app.get_node("CareerNavigation") as CareerNavigation
	_expect(nav != null, "Application owns one persistent navigation shell")
	_expect(not nav.visible and nav.current_destination().is_empty(), "Title suppresses ordinary career navigation")

	app.call("_ensure_training_screen")
	var training := app.get("_training_screen") as Control
	app.call("_swap_to", training)
	await process_frame
	_expect(nav.current_destination() == &"training", "Training is a peer destination")
	_expect(is_equal_approx(training.offset_top, NavigationScript.HEADER_HEIGHT), "Training is inset below the global header")
	_expect(_has_back_route(training, app), "Training Back routes to Desk")

	app.call("_ensure_schedule_screen")
	var calendar := app.get("_schedule_screen") as Control
	app.call("_swap_to", calendar)
	await process_frame
	_expect(nav.current_destination() == &"calendar", "Calendar is a first-class peer destination")
	_expect(is_zero_approx(training.offset_top), "leaving Training restores its layout")
	_expect(_has_back_route(calendar, app), "Calendar Back routes to Desk rather than Training")

	for entry in [
		["_ensure_scouting_screen", "_scouting_screen", &"scouting"],
		["_ensure_accommodation_screen", "_accommodation_screen", &"housing"],
		["_ensure_kitchen_screen", "_kitchen_screen", &"kitchen"],
		["_ensure_encyclopedia_screen", "_encyclopedia_screen", &"encyclopedia"],
	]:
		app.call(str(entry[0]))
		var screen := app.get(str(entry[1])) as Control
		app.call("_swap_to", screen)
		await process_frame
		_expect(nav.current_destination() == entry[2], "%s is a peer destination" % entry[2])
		_expect(_has_back_route(screen, app), "%s Back routes to Desk" % entry[2])

	var journal := app.get_node("Journal") as Control
	app.call("_swap_to", journal)
	app.call("_apply_journal_vocabulary")
	await process_frame
	_expect(nav.current_destination() == &"journal", "Journal is a peer destination, not the hub")
	var section_title := journal.get_node_or_null("%SectionTitle") as Label
	_expect(section_title != null and section_title.text == "Current", "Journal presents Current rather than Home")
	for node in journal.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and str(button.get_meta("section", "")) == "Home":
			_expect(button.text == "Current", "Journal navigation translates legacy Home id to Current")

	app.call("_ensure_desk_screen")
	var desk := app.get("_desk_screen") as Control
	app.call("_swap_to", desk)
	await process_frame
	_expect(nav.current_destination() == &"desk", "Desk remains the spatial home destination")
	_expect(is_zero_approx(desk.offset_top), "Desk remains a full spatial surface")

	var match_center := app.get_node("MatchCenter") as Control
	app.call("_swap_to", match_center)
	await process_frame
	_expect(not nav.visible and nav.current_destination().is_empty(), "presence mode suppresses ordinary navigation")

	if _failures.is_empty():
		print("APPLICATION_NAVIGATION_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("APPLICATION_NAVIGATION_TEST " + failure)
		quit(1)


func _has_back_route(screen: Object, app: Object) -> bool:
	if screen == null or not screen.has_signal("back_requested"):
		return false
	var expected := Callable(app, "_show_desk")
	for connection in screen.get_signal_connection_list("back_requested"):
		if connection.get("callable") == expected:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
