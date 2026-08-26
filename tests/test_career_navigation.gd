extends SceneTree

const NavigationScript := preload("res://scenes/components/career_navigation.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var nav := NavigationScript.new()
	host.add_child(nav)
	await process_frame

	_expect(nav.destination_count() == 8, "shared header exposes exactly eight peer destinations")
	for key in [
		&"desk", &"journal", &"calendar", &"training",
		&"scouting", &"housing", &"kitchen", &"encyclopedia",
	]:
		_expect(nav.button_for(key) != null, "header exposes %s" % key)

	nav.present(&"journal")
	_expect(nav.visible, "ordinary career workspace shows persistent navigation")
	_expect(nav.current_destination() == &"journal", "Journal becomes active destination")
	_expect(nav.button_for(&"journal").button_pressed, "active Journal button is selected")

	nav.present(&"desk")
	_expect(nav.button_for(&"desk").button_pressed, "Desk becomes selected")
	_expect(not nav.button_for(&"journal").button_pressed, "previous destination is deselected")

	var requested: Array[StringName] = []
	nav.destination_requested.connect(func(destination: StringName) -> void:
		requested.append(destination)
	)
	nav.button_for(&"training").emit_signal("pressed")
	await process_frame
	_expect(requested == [&"training"], "inactive peer emits one routing request")

	nav.present(&"training")
	nav.button_for(&"training").emit_signal("pressed")
	await process_frame
	_expect(requested.size() == 1, "active destination does not request redundant navigation")

	nav.clear()
	_expect(not nav.visible, "presence/pre-career state can suppress global navigation")
	_expect(nav.current_destination().is_empty(), "clear removes active destination")

	if _failures.is_empty():
		print("CAREER_NAVIGATION_TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("CAREER_NAVIGATION_TEST " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
