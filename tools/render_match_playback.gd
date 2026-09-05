extends Node

## Frames of a real rally, filmed through the real match centre.
##
## The earlier frame renderer says in its own header: *"No MatchScreen, no
## playback loop, no async pacing"* — it drove `MatchCourt3D` directly with
## trajectories it computed itself. That is the right tool for comparing two
## curves and the wrong one for a human-review artifact, because everything the
## review is *about* lives in the layer it skipped: which pose an actor takes,
## whether a contact is drawn at all, how the windows are paced, what the
## caption says.
##
## So this instantiates `MatchScreen` and calls `load_and_play_rally`, the same
## entry the desk calls, and photographs it while it runs. Nothing here decides
## anything about the rally or the drawing; it holds a camera.
##
## Must be run with a renderer, never `--headless`:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/match_playback.tscn

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const MANAGER := preload("res://scripts/managers/game_manager.gd")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")

const OUT_DIR := "res://artifacts/m8-visual/playback"
## Real seconds between frames. The rally is played at its own pace and sampled,
## rather than stepped, because the pacing is one of the things under review.
const FRAME_INTERVAL_SECONDS: float = 0.22
const MAX_FRAMES: int = 48

var _screen: Control
var _saved := 0
var _label: Label
var _side_dir := OUT_DIR


func _ready() -> void:
	get_window().size = Vector2i(1120, 720)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_DIR)
	)
	## **The rally is searched for, not chosen.** A seed picked by hand is a seed
	## picked because it looked good, and the artifact is supposed to be evidence.
	## The requirement is a rally that walks the whole chain, so that is the test.
	_label = Label.new()
	_label.position = Vector2(12.0, 8.0)
	_label.add_theme_font_size_override("font_size", 15)
	add_child(_label)
	## Both serving sides, because a drawing defect that only shows on one side
	## is the shape this engine has produced more than any other -- three
	## home/opponent drifts were found and repaired in this packet alone.
	for side in range(2):
		var label := "home" if side == 0 else "opponent"
		var chosen := _find_full_chain_rally(side == 0)
		if chosen.is_empty():
			push_error("no %s-serving rally walked the whole chain" % label)
			continue
		print("filming %s serve, seed %d, %d contacts: %s" % [
			label, int(chosen.seed), int(chosen.contacts), str(chosen.chain),
		])
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("%s/%s" % [OUT_DIR, label])
		)
		_side_dir = "%s/%s" % [OUT_DIR, label]
		_saved = 0
		_screen = MATCH_SCREEN.instantiate() as Control
		add_child(_screen)
		await get_tree().process_frame
		UIStyleSystem.apply(_screen, false)
		await get_tree().process_frame
		_screen.load_and_play_rally(chosen.result as RallyResult, 1.0)
		await _film()
		print("  %s frames written: %d" % [label, _saved])
		_screen.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


## A rally that actually walks the chain the review is about.
##
## Both serving sides are searched and the first qualifying seed on each is
## taken, so neither side is represented by a hand-picked best case.
func _find_full_chain_rally(serving_home: bool) -> Dictionary:
	for index in range(240):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(970000 + index)
		if result == null:
			continue
		var chain: Array = []
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event == null:
				continue
			chain.append(str(
				RallyEvent.EventType.keys()[int(event.event_type)]
			))
		if chain.has("SERVE") and chain.has("RECEPTION") \
				and chain.has("SET") and chain.has("ATTACK") \
				and (chain.has("BLOCK") or chain.has("DIG")):
			return {
				"seed": 970000 + index, "serving_home": serving_home,
				"result": result, "contacts": chain.size(), "chain": chain,
			}
	return {}


func _film() -> void:
	var elapsed := 0.0
	while _saved < MAX_FRAMES:
		await get_tree().create_timer(FRAME_INTERVAL_SECONDS).timeout
		elapsed += FRAME_INTERVAL_SECONDS
		var image := get_viewport().get_texture().get_image()
		if image == null:
			continue
		## A frame with nothing drawn in it is not evidence, and an artifact full
		## of them reads as a rendered rally to anyone skimming. Counted rather
		## than silently written.
		if _is_blank(image):
			continue
		_label.text = "t = %5.2f s" % elapsed
		image.save_png("%s/frame_%02d.png" % [_side_dir, _saved])
		_saved += 1
		if not _screen.is_inside_tree():
			return


static func _is_blank(image: Image) -> bool:
	var reference := image.get_pixel(0, 0)
	for y in range(0, image.get_height(), 37):
		for x in range(0, image.get_width(), 41):
			if image.get_pixel(x, y) != reference:
				return false
	return true
