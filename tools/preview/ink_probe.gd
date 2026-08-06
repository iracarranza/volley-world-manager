extends Control

## Which surfaces actually carry a drawn edge, and how big it is.
##
## The style pass assigns the outline by theme variation, which is easy to read
## as correct and hard to confirm: a card whose outline exists but has zero size
## draws nothing, and looks exactly like a card that never got one. This walks
## the real dashboard after a real style pass and reports both facts side by
## side.

const UIStyle := preload("res://scripts/systems/ui_style_system.gd")
const DarkTheme := preload("res://scenes/themes/dark_theme.tres")

var _dashboard: Control
var _frame: int = 0


func _ready() -> void:
	theme = DarkTheme
	var manager := get_node("/root/CareerManager")
	manager.create_career(
		"Preview Career", "Harbor City VC", "Landavol", "Club", "Balanced"
	)
	var packed := load("res://scenes/screens/career_dashboard.tscn") as PackedScene
	_dashboard = packed.instantiate()
	add_child(_dashboard)
	UIStyle.apply(self, false)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 30:
		return
	var tiers := {}
	var report: Array[String] = []
	_walk(_dashboard, tiers, report)
	print("--- tier census ---")
	for key in tiers:
		print("%s: %d" % [key, tiers[key]])
	print("--- inked surfaces ---")
	for line in report:
		print(line)
	get_tree().quit()


func _walk(node: Node, tiers: Dictionary, report: Array[String]) -> void:
	if node is Control:
		var control := node as Control
		var variation := String(control.theme_type_variation)
		if not variation.is_empty():
			tiers[variation] = int(tiers.get(variation, 0)) + 1
		if variation in ["CardPanel", "DashboardCard", "InsetPanel"]:
			var outline := control.get_node_or_null("InkOutline")
			var outline_size := "MISSING"
			if outline != null:
				outline_size = str((outline as Control).size)
			report.append(
				"%-28s %-14s parent=%s outline=%s visible=%s"
				% [
					control.name, variation, str(control.size), outline_size,
					control.is_visible_in_tree(),
				]
			)
	for child in node.get_children():
		_walk(child, tiers, report)
