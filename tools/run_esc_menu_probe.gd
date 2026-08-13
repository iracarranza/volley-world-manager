extends Node

## Does the escape menu open?
##
##     xvfb-run -a godot --path . res://tools/esc_menu_probe.tscn
##
## Opened from a live career, because that is the state it is opened from and
## `open_menu` branches on it: `has_career` reveals the career actions and the
## save list is only non-empty once something has been saved.

const EscMenuScript := preload("res://scenes/components/esc_menu.gd")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")


func _ready() -> void:
	await get_tree().process_frame
	await _probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var error: String = career_manager.create_career(
		"Esc Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	print("has_career = %s" % str(career_manager.has_career()))
	var entries: Array = []
	for metadata in career_manager.list_save_metadata():
		entries.append({
			"id": str(metadata.get("save_id", "")),
			"label": "%s / %s" % [
				str(metadata.get("career_name", "Career")),
				str(metadata.get("organization_name", "Organization")),
			],
		})
	print("save entries = %d" % entries.size())

	## `build()` is the constructor; `new()` is what `application.gd` was calling
	## and is the whole bug.
	var menu = EscMenuScript.build()
	add_child(menu)
	UIStyleSystem.apply(menu, false)
	await get_tree().process_frame
	print("--- opening with no saves")
	menu.open_menu([], "dark", career_manager.has_career())
	for _settle in range(3):
		await get_tree().process_frame
	print("    visible = %s" % str(menu.visible))
	menu.close_menu()
	await get_tree().process_frame

	print("--- opening with %d saves" % entries.size())
	menu.open_menu(entries, "dark", career_manager.has_career())
	for _settle in range(3):
		await get_tree().process_frame
	print("    visible = %s" % str(menu.visible))

	## Reopening without closing, which is what a second Escape press does when
	## something else swallowed the first one.
	print("--- reopening while already open")
	menu.open_menu(entries, "dark", career_manager.has_career())
	for _settle in range(3):
		await get_tree().process_frame
	print("    visible = %s" % str(menu.visible))
	print("esc menu probe finished without crashing")
