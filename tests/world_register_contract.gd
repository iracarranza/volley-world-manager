extends SceneTree

const RegisterView := preload("res://scenes/components/world_register_view.gd")
const Encyclopedia := preload("res://scenes/screens/encyclopedia_screen.gd")
const Politics := preload("res://scripts/data/world_political_geography.gd")
const Regions := preload("res://scripts/data/regions.gd")
const LockedTaglines := preload("res://scripts/data/region_taglines_locked.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("WORLD REGISTER: %s" % message)


func _run() -> void:
	var view := RegisterView.new()
	root.add_child(view)
	await process_frame
	_check(view.all_regions().size() == Politics.all_regions().size(), "register must expose every political region")
	for region_name in Politics.all_regions():
		_check(view.all_regions().has(region_name), "register omitted %s" % region_name)
	_check(view.selected_region() == "Landavol", "register default selection must be Landavol")
	view.select_region("Pāwa Hitō")
	_check(view.selected_region() == "Pāwa Hitō", "region selection did not reach canonical map")
	_check(not view.terrain_summary("Pāwa Hitō").is_empty(), "Pāwa terrain must come from geography")
	_check(view.details_text().contains("Pāwa Hitō"), "selected-region card did not update")
	_check(
		view.details_text().contains(String(LockedTaglines.TAGLINES["Pāwa Hitō"])),
		"selected-region card did not use the approved regional tagline"
	)
	_check(view.details_text().contains("Terrain"), "selected-region card must expose physical geography")
	view.set_mode(&"terrain")
	_check(view.mode() == &"terrain", "terrain mode did not reach map")
	view.set_mode(&"seams")
	_check(view.mode() == &"seams", "seam mode did not reach map")

	var screen := Encyclopedia.new()
	root.add_child(screen)
	await process_frame
	_check(
		screen.article_text().contains(String(LockedTaglines.TAGLINES["A'ace"])),
		"Encyclopedia article did not use the approved regional tagline"
	)
	screen.open_world_register("Kutré Lyn")
	_check(screen.world_register_open(), "Encyclopedia must expose World Register as a real view")
	_check(screen.selected_register_region() == "Kutré Lyn", "direct World Register selection was lost")
	for region_name in LockedTaglines.TAGLINES:
		_check(
			String(Regions.definition(region_name).get("tagline", "")) \
				== String(LockedTaglines.TAGLINES[region_name]),
			"%s did not resolve to its approved tagline" % region_name
		)

	view.queue_free()
	screen.queue_free()
	await process_frame
	if failures == 0:
		print("World Register contract: %d checks, 0 failures" % checks)
		quit(0)
		return
	push_error("World Register contract: %d checks, %d failures" % [checks, failures])
	quit(1)
