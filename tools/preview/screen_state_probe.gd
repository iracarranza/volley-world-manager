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
## Add it to `scenes/application.tscn` as a child of the root and run the project.
## It touches nothing -- it only reads.

const REPORT_SECONDS: float = 1.0

var _elapsed: float = 0.0
var _root: Control


func _ready() -> void:
	_root = get_parent() as Control


func _process(delta: float) -> void:
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
	print("[screens] %s" % ", ".join(shown))
	var hovered := get_viewport().gui_get_hovered_control()
	print("[mouse]   at %s over %s" % [
		get_viewport().get_mouse_position(),
		"nothing" if hovered == null else hovered.name,
	])
