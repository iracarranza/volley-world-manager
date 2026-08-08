extends Node

## What the running application is actually showing, printed once a second.
##
## Exists because a screen can be present, laid out, focusable and clickable
## while being invisible, and there is no way to tell that apart from a frozen
## game by looking at it. The two states that do it:
##
##   * a screen left at `modulate.a = 0` by a reveal that never finished
##   * the wipe's sheet left across by a tween killed mid-travel
##
## Both are fixed, and both were unreproducible on the machine they were fixed
## on, so this stays: if the symptom comes back the log says which one it is
## rather than leaving it to be guessed at again.
##
## **Install it as an autoload**, which needs no scene editing at all:
## Project > Project Settings > Globals > Autoload, point Path at this file, Add,
## then run the project. Remove it the same way. It touches nothing -- it only
## reads -- and it finds the application itself rather than assuming who its
## parent is, so it works from anywhere in the tree.
##
## Each line also carries a frame counter. **That counter is the whole point.** If
## it keeps climbing while the window looks frozen, the game is alive and the
## renderer is not presenting; if it stops, the main loop is blocked. Those are
## different bugs and they look identical from outside.

const REPORT_SECONDS: float = 1.0

var _elapsed: float = 0.0
var _frames: int = 0
var _root: Control


## The application, wherever it is. As an autoload this node is a sibling of the
## main scene rather than its child, so the parent is `/root` and not the screen
## holder -- which is exactly the assumption that made "attach it" ambiguous.
func _find_application() -> Control:
	for child in get_tree().root.get_children():
		if child == self:
			continue
		var control := child as Control
		if control == null:
			continue
		if control.get_script() != null \
				and str(control.get_script().resource_path).ends_with(
					"application.gd"
				):
			return control
	var main := get_tree().current_scene as Control
	return main


func _process(delta: float) -> void:
	_frames += 1
	if _root == null:
		_root = _find_application()
		if _root == null:
			return
	_elapsed += delta
	if _elapsed < REPORT_SECONDS:
		return
	_elapsed = 0.0
	var shown: Array[String] = []
	for child in _root.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		shown.append("%s a=%.2f pos=%s size=%s filter=%d" % [
			control.name, control.modulate.a, control.position, control.size,
			control.mouse_filter,
		])
	print("[frame %d] %s" % [_frames, ", ".join(shown)])
	var hovered := get_viewport().gui_get_hovered_control()
	print("[mouse]   at %s over %s" % [
		get_viewport().get_mouse_position(),
		"nothing" if hovered == null else hovered.name,
	])
