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
const WATCH_SECONDS: float = 75.0

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
	if _clipboard:
		_drive_the_clipboard(frame_ms)
	if _elapsed() > WATCH_SECONDS * 1000.0:
		_report()
		return true
	return false


## Open the clipboard, leave it, and keep watching.
##
## The reported symptom is not the opening -- that stall was found and moved off
## the boot path. It is that the game **stays** slow after you navigate away,
## which is a different bug: something the page leaves behind is still costing
## frames on a screen that is no longer visible. So the trace is in three phases
## and the one that matters is the third.
##
## Frame times are averaged per phase rather than reported per frame, because a
## background cost is a small tax on every frame and not a stall on one -- which
## is exactly why the slow-frame threshold that found the first bug is blind to
## this one. Two instruments for two shapes of the same complaint.
## Late enough that the bake is over before either boundary. The first attempt
## closed at 16 s and caught a single 11.8 s frame of bake inside the "after"
## column -- thirteen frames, twelve of which were one bake. A background tax
## cannot be read off a window that a stall is sitting in.
const CLIPBOARD_OPEN_AT: float = 4000.0
const CLIPBOARD_CLOSE_AT: float = 40000.0

var _phase_frames := {"before": 0, "open": 0, "after": 0}
var _phase_ms := {"before": 0.0, "open": 0.0, "after": 0.0}
var _clipboard_screen: Control = null


func _phase_now() -> String:
	if _elapsed() < CLIPBOARD_OPEN_AT:
		return "before"
	return "open" if _elapsed() < CLIPBOARD_CLOSE_AT else "after"


func _drive_the_clipboard(frame_ms: float) -> void:
	var phase := _phase_now()
	_phase_frames[phase] = int(_phase_frames[phase]) + 1
	_phase_ms[phase] = float(_phase_ms[phase]) + frame_ms
	if phase != "before" and not _clipboard_open:
		_open_the_clipboard()
	## Hidden rather than freed, because hiding is what the game does. Navigating
	## away from a screen leaves it in the tree -- that is the whole design -- so
	## freeing it here would measure a thing the game never does.
	if phase == "after" and _clipboard_screen != null \
			and _clipboard_screen.visible:
		_clipboard_screen.visible = false
		print("%8.1f ms  clipboard navigated away from" % _elapsed())
		_census("after close")


## Who is still running, by script.
##
## The direct question, asked directly. A background cost on a hidden screen is
## something still being *processed* or still being *drawn*, and both are
## countable -- so rather than reason about which node it might be, count them
## and print the classes. A leak that survives navigation shows up as a count
## that does not drop when the screen goes.
func _census(when: String) -> void:
	var processing := {}
	var total := 0
	for child in root.get_children():
		total += _count_processing(child, processing)
	var names := processing.keys()
	names.sort()
	print("--- %s: %d nodes processing ---" % [when, total])
	for name in names:
		print("    %-34s %d" % [name, processing[name]])
	## Absolute, not the change feed. `_survey_viewports` prints only what moved,
	## which is right for a running trace and useless at a checkpoint -- a viewport
	## still on UPDATE_ALWAYS after the screen closed has not *changed*, and it is
	## exactly what this census exists to catch.
	var found := {}
	for child in root.get_children():
		_walk_viewports(child, found)
	var paths := found.keys()
	paths.sort()
	for path: String in paths:
		print("    viewport %-64s %s" % [str(path).get_file(), found[path]])


func _count_processing(node: Node, into: Dictionary) -> int:
	var found := 0
	if node.is_processing() or node.is_physics_processing():
		var script_path := "(none)"
		var attached: Variant = node.get_script()
		if attached != null:
			script_path = str((attached as Script).resource_path).get_file()
		var label := "%s / %s" % [node.get_class(), script_path]
		into[label] = int(into.get(label, 0)) + 1
		found += 1
	for child in node.get_children():
		found += _count_processing(child, into)
	return found


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
	_clipboard_screen = screen
	print("%8.1f ms  clipboard built in %.0f ms" % [
		_elapsed(), float(Time.get_ticks_usec() - began) / 1000.0,
	])


func _report() -> void:
	if _clipboard:
		_census("at the end")
		print("--- frame cost by phase ---")
		for phase in ["before", "open", "after"]:
			var count := int(_phase_frames[phase])
			print("    %-6s %4d frames, %6.1f ms each" % [
				phase, count,
				float(_phase_ms[phase]) / maxf(float(count), 1.0),
			])
	print("--- %d frames in %.1f s ---" % [_frames, _elapsed() / 1000.0])
	print("slow frames: %d, worst %.0f ms, %.0f ms of stall in total" % [
		_slow.size(), _worst, _total_stall_ms,
	])
	if _slow.is_empty():
		print("settled: immediately")
	else:
		print("settled after %.1f s" % (_last_slow_at / 1000.0))
