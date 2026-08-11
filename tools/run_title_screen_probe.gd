extends SceneTree

## Exercises the retint without entering the tree: `--script` loads no autoloads,
## so the screen's `_ready` cannot run, and its `@onready` handles are filled in
## by hand instead. Scene-unique `%` names resolve on a detached instance.
func _initialize() -> void:
	var screen: Control = load("res://scenes/screens/title_screen.tscn").instantiate()
	screen.continue_button = screen.get_node("%ContinueButton")
	var panel: StyleBoxFlat = screen.get_node("%MenuPanel").get_theme_stylebox(&"panel")
	var button: StyleBoxFlat = screen.get_node("%NewCareerButton").get_theme_stylebox(&"normal")
	var card: StyleBoxFlat = screen.continue_button.get_theme_stylebox(&"normal")
	printerr("authored  panel=%s button=%s card=%s" % [panel.bg_color, button.bg_color, card.bg_color])
	screen.theme_option = screen.get_node("%ThemeOption")
	screen.theme_option.add_item("Mikasa")
	screen.theme_option.add_item("Molten")
	screen.set_theme_name("light")
	printerr("molten    panel=%s button=%s card=%s" % [panel.bg_color, button.bg_color, card.bg_color])
	screen.set_theme_name("dark")
	printerr("mikasa    panel=%s button=%s card=%s" % [panel.bg_color, button.bg_color, card.bg_color])
	var none: Array[Dictionary] = []
	screen.saves = none
	screen._refresh_continue()
	printerr("continue visible with no saves: ", screen.continue_button.visible)
	var one: Array[Dictionary] = [{"save_id": "a", "organization_name": "Doblok Volei",
		"date": "Week 4", "next_fixture": "Port Azure VC", "last_saved_unix": 9}]
	screen.saves = one
	screen._refresh_continue()
	printerr("continue visible with a save: ", screen.continue_button.visible,
		" / ", screen.get_node("%ContinueTitle").text,
		" / ", screen.get_node("%ContinueDetail").text)
	screen.free()
	quit()
