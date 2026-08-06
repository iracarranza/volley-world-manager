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
	print("--- stacked edges ---")
	_report_stacking()
	get_tree().quit()


## Which drawn edges run parallel to another one close enough to read as a
## doubled line rather than as two separate surfaces.
##
## Any surface that *draws an edge at all* counts here, whether that edge is a
## pen line or a stylebox border -- the eye does not care which system produced
## it, only that there are three lines within twenty pixels of each other.
func _report_stacking() -> void:
	var edged: Array = []
	_collect_edged(_dashboard, edged)
	var flagged := 0
	for outer in edged:
		for inner in edged:
			if outer == inner:
				continue
			var outer_rect: Rect2 = outer["rect"]
			var inner_rect: Rect2 = inner["rect"]
			if not outer_rect.encloses(inner_rect):
				continue
			## The four gaps between the two edges. Only the smallest matters:
			## one side running close is enough to read as a doubled line.
			var gaps := [
				inner_rect.position.x - outer_rect.position.x,
				inner_rect.position.y - outer_rect.position.y,
				outer_rect.end.x - inner_rect.end.x,
				outer_rect.end.y - inner_rect.end.y,
			]
			var tightest: float = gaps.min()
			if tightest > 16.0:
				continue
			flagged += 1
			print(
				"%-22s (%s) inside %-22s (%s) -- %.0f px apart"
				% [
					inner["name"], inner["kind"], outer["name"], outer["kind"],
					tightest,
				]
			)
	if flagged == 0:
		print("none within 16 px")


func _collect_edged(node: Node, into: Array) -> void:
	if node is Control:
		var control := node as Control
		var variation := String(control.theme_type_variation)
		var kind := ""
		if control.get_node_or_null("InkOutline") != null:
			kind = "ink"
		elif control is PanelContainer or control is TabContainer:
			var style_name := &"panel"
			if control.has_theme_stylebox(style_name, control.theme_type_variation):
				var box := control.get_theme_stylebox(
					style_name, control.theme_type_variation
				) as StyleBoxFlat
				if box != null and box.border_width_left > 0:
					kind = "border"
		if not kind.is_empty() and control.is_visible_in_tree():
			into.append({
				"name": String(control.name),
				"kind": "%s/%s" % [kind, variation if not variation.is_empty() else "-"],
				"rect": Rect2(control.global_position, control.size),
			})
	for child in node.get_children():
		_collect_edged(child, into)


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
