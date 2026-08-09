extends SceneTree

## Where the first thirty seconds go.
##
##     godot --headless --path . --script res://tools/preview/startup_probe.gd
##
## The reported symptom is that the game is unresponsive for a while after
## launch and then comes right on its own -- clicks made during the stall all
## landing at once when it ends, which is a **blocked main thread** rather than a
## slow renderer. A renderer that cannot keep up drops frames; it does not queue
## your clicks and hand them back later. So this measures the main thread and
## nothing else, and runs headless deliberately: with no rendering in the way,
## anything it finds is work the CPU is actually doing.
##
## What it prints is a frame-time trace, not a total. A total cannot tell a
## thirty second stall from thirty seconds of honest work spread evenly, and
## those want opposite fixes -- the first wants moving off the boot path, the
## second wants a progress bar. Every frame over `SLOW_FRAME_MS` is named with
## what had just happened, so the stall arrives with a suspect attached.

const MAIN_SCENE := "res://scenes/application.tscn"

## A frame worth naming. Sixteen milliseconds is a frame's whole budget, so this
## is four frames' worth: long enough not to print noise, short enough that a
## stall cannot hide inside it.
const SLOW_FRAME_MS: float = 64.0
const WATCH_SECONDS: float = 30.0

var _started: int = 0
var _last: int = 0
var _frames: int = 0
var _slow: Array[Dictionary] = []
var _worst: float = 0.0
var _total_stall_ms: float = 0.0
## When the trace last saw a slow frame, so "settled after" is the end of the
## disruption rather than the first quiet frame in the middle of it.
var _last_slow_at: float = 0.0


func _initialize() -> void:
	_started = Time.get_ticks_usec()
	_last = _started
	_clipboard = "clipboard" in OS.get_cmdline_user_args()
	print("--- startup probe%s ---" % (" (clipboard)" if _clipboard else ""))
	_mark("autoloads ready")
	var packed: PackedScene = load(MAIN_SCENE)
	_mark("main scene loaded")
	var main := packed.instantiate()
	_mark("main scene instantiated")
	root.add_child(main)
	_mark("main scene in tree")


func _mark(what: String) -> void:
	print("%8.1f ms  %s" % [_elapsed(), what])
	_last = Time.get_ticks_usec()


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - _started) / 1000.0


## Every viewport in the tree, by path, with the size and update policy it had
## when it was last looked at.
##
## Here because the stall only appears with a renderer attached -- headless boots
## in under three seconds -- and the thing a renderer can be given too much of is
## viewports. A `SubViewport` left on `UPDATE_ALWAYS` costs its full area every
## frame whether or not anything can see it, and the cost of one that was sized
## from a window rather than from its own panel does not show up anywhere except
## the frame time.
var _viewports: Dictionary = {}


func _survey_viewports(when: String) -> void:
	var found := {}
	for node in root.get_children():
		_walk_viewports(node, found)
	for path: String in found:
		var was: String = str(_viewports.get(path, ""))
		if was != found[path]:
			print("%8.1f ms  %s: %s %s" % [_elapsed(), when, path, found[path]])
	_viewports = found


func _walk_viewports(node: Node, into: Dictionary) -> void:
	var viewport := node as SubViewport
	if viewport != null:
		into[str(root.get_path_to(viewport))] = "%dx%d update=%d msaa=%d" % [
			viewport.size.x, viewport.size.y,
			viewport.render_target_update_mode, viewport.msaa_3d,
		]
	for child in node.get_children():
		_walk_viewports(child, into)


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last) / 1000.0
	_last = now
	_frames += 1
	## Surveyed before the slow-frame report, so a viewport that appeared on the
	## frame that stalled is printed above the stall rather than after it.
	_survey_viewports("viewport")
	if frame_ms > SLOW_FRAME_MS:
		var at := _elapsed()
		_slow.append({"frame": _frames, "at": at, "ms": frame_ms})
		_worst = maxf(_worst, frame_ms)
		_total_stall_ms += frame_ms
		_last_slow_at = at
		print("%8.1f ms  frame %-4d took %.0f ms" % [at, _frames, frame_ms])
	if _clipboard and not _clipboard_open and _elapsed() > 3000.0:
		_open_the_clipboard()
	if _elapsed() > WATCH_SECONDS * 1000.0:
		_report()
		return true
	return false


## Open the clipboard on a settled game and time its figures.
##
##     godot --headless --path . --script res://tools/preview/startup_probe.gd -- clipboard
##
## The clipboard is where the sticker bake lives -- forty-nine posed renders, two
## readbacks and two contour traces each -- and it is the one page whose first
## open is worth a number of its own. Run it twice: the first pass cuts every
## sticker, the second reads them off disk.
var _clipboard: bool = false
var _clipboard_open: bool = false


func _open_the_clipboard() -> void:
	_clipboard_open = true
	var began := Time.get_ticks_usec()
	var clipboard_script: GDScript = load("res://scenes/screens/training_screen.gd")
	var screen: Control = clipboard_script.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.get_child(root.get_child_count() - 1).add_child(screen)
	print("%8.1f ms  clipboard built in %.0f ms" % [
		_elapsed(), float(Time.get_ticks_usec() - began) / 1000.0,
	])


func _report() -> void:
	print("--- %d frames in %.1f s ---" % [_frames, _elapsed() / 1000.0])
	print("slow frames: %d, worst %.0f ms, %.0f ms of stall in total" % [
		_slow.size(), _worst, _total_stall_ms,
	])
	if _slow.is_empty():
		print("settled: immediately")
	else:
		print("settled after %.1f s" % (_last_slow_at / 1000.0))
