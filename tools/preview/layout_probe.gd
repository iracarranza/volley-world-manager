extends Control

## Why a page does not fit the window, as numbers.
##
## Godot gives no warning when a layout cannot fit: a `MarginContainer` whose
## minimum exceeds its parent is simply placed at a negative offset, so the page
## grows out through the top *and* bottom edges at once and the ribbon vanishes.
## Nothing is logged and nothing looks broken from inside the tree.
##
## This walks a screen and prints every control whose minimum height is non-zero,
## then the chain from the window down to it, so the one node forcing the
## overflow is visible rather than guessed at. It found the roster page needing
## **812 px in a 720 px window** -- 46 px off each edge -- and named the two
## controls responsible.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/layout_probe.tscn

var _app: Control
var _frame: int = 0


func _ready() -> void:
	var manager := get_node("/root/CareerManager")
	manager.create_career("Probe", "Harbor City VC", "Landavol", "Club", "Balanced")
	_app = (load("res://scenes/application.tscn") as PackedScene).instantiate()
	_app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_app)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != 40:
		return
	## Which page to weigh. The journal's roster is what this was written for;
	## `clipboard` opens the training screen instead, which is the other page
	## that has run off the bottom edge.
	var wants_clipboard := "clipboard" in OS.get_cmdline_user_args()
	var subject: Control = null
	if wants_clipboard:
		_app.call("_show_training")
		## Shown *and* settled, which are two different things and the difference
		## is a wrong answer. A screen behind the wipe has never been laid out, so
		## every autowrapping label in it reports the height it needs at zero
		## width -- one word per line -- and the page appears to need twice the
		## window. Measuring that would be measuring the probe.
		var screen := _app.find_child("TabsHost", true, false)
		while screen != null and screen is Control:
			(screen as Control).visible = true
			screen = screen.get_parent()
		for _settle in range(40):
			await get_tree().process_frame
		subject = _app.find_child("Tactics", true, false) as Control
	else:
		var journal := _app.get_node("%Journal") as Control
		journal.visible = true
		var sections := journal.find_child("Sections", true, false) as TabContainer
		if sections != null:
			for index in range(sections.get_tab_count()):
				if sections.get_tab_title(index) == "Roster":
					sections.current_tab = index
		await get_tree().process_frame
		await get_tree().process_frame
		subject = journal.find_child("Roster", true, false) as Control
	print("window height = %.0f" % size.y)
	var roster := subject
	if roster == null:
		print("no page node")
		get_tree().quit()
		return
	_walk(roster, 0)
	print("--- the chain from the window down to the page ---")
	var chain: Array[Control] = []
	var node: Node = roster
	while node != null and node != get_parent():
		if node is Control:
			chain.append(node as Control)
		node = node.get_parent()
	chain.reverse()
	for link in chain:
		print("%-24s min=%4.0f  actual=%4.0f  pos.y=%5.0f  %s" % [
			link.name, link.get_combined_minimum_size().y, link.size.y,
			link.global_position.y, link.get_class(),
		])
	get_tree().quit()


## Every node whose own minimum height is what its parent has to honour.
func _walk(node: Node, depth: int) -> void:
	var control := node as Control
	if control != null:
		var mins := control.get_combined_minimum_size()
		if mins.y > 0.0:
			print("%s%-26s min=%4.0f  actual=%4.0f  %s" % [
				"  ".repeat(depth), control.name, mins.y, control.size.y,
				"custom=%.0f" % control.custom_minimum_size.y \
					if control.custom_minimum_size.y > 0.0 else "",
			])
	for child in node.get_children():
		_walk(child, depth + 1)
