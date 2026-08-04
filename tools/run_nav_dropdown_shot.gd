extends Node

## Screenshot the career dashboard's navigation drawer, open and closed.
##
## The drawer is animated and geometric -- a clipper tweened across a strip --
## so the only honest way to check it is to look at the pixels. Run under a
## virtual display; the images land in `user://` (see the printed paths).
##
## Run:
##   xvfb-run -a godot --path . res://tools/nav_dropdown_shot.tscn
##
## A scene rather than `--script`: autoloads (CareerManager, GameManager) are
## not initialised in script mode, and the dashboard needs both.

const DASHBOARD := preload("res://scenes/screens/career_dashboard.tscn")

## One width, deliberately. The project stretches `canvas_items` from a fixed
## 1280x720 base with an expanding aspect, so controls always lay out against
## that base and a resized window only ever gives the strip *more* room. There
## is no narrow case to photograph: driving `root.size` to fake one warps the
## layout (the strip lands at a negative x) and measures nothing real.
const WIDTHS: Array[int] = [1280]


func _ready() -> void:
	var root := get_tree().root
	await get_tree().process_frame
	CareerManager.create_career(
		"Shot", "Screenshot VC", "Landavol", "Club", "Balanced"
	)
	for width in WIDTHS:
		await _shoot(width)
	get_tree().quit()


func _shoot(width: int) -> void:
	var root := get_tree().root
	## `content_scale_size` is the base the `canvas_items` stretch maps onto, so
	## it -- not just the OS window -- is what decides the size controls actually
	## lay out against. Setting the window alone left every width measuring
	## identically, which made the narrow cases silently inert.
	root.size = Vector2i(width, 720)
	root.content_scale_size = Vector2i(width, 720)
	DisplayServer.window_set_size(Vector2i(width, 720))
	for _frame in range(4):
		await get_tree().process_frame
	var screen: Control = DASHBOARD.instantiate()
	root.add_child(screen)
	for _frame in range(6):
		await get_tree().process_frame
	await _capture(screen, "closed_%d" % width)
	screen.call("_open_nav_dropdown")
	## Past the 0.20s slide, so the drawer is measured at rest rather than
	## mid-tween.
	for _frame in range(45):
		await get_tree().process_frame
	await _capture(screen, "open_%d" % width)
	screen.queue_free()
	await get_tree().process_frame


func _capture(screen: Control, label: String) -> void:
	var root := get_tree().root
	await get_tree().process_frame
	var image := root.get_texture().get_image()
	var path := "user://nav_%s.png" % label
	image.save_png(path)
	var strip: Control = screen.get_node("%NavStrip")
	var clip: Control = screen.get_node("%NavClip")
	var panel: Control = screen.get_node("%DropdownPanel")
	var nav: Control = screen.get_node("%HomeNav").get_parent()
	print("%-12s strip=%s clip_pos=%s clip_size=%s panel_size=%s panel_min=%s nav_size=%s" % [
		label, strip.get_global_rect(), clip.position, clip.size,
		panel.size, panel.get_combined_minimum_size(), nav.size,
	])
	print("             saved %s" % ProjectSettings.globalize_path(path))
