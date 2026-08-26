class_name DeskScreen
extends Control

## Transparent interaction layer over the canonical 3D office Desk camera.
##
## The room is rendered by CanonicalOfficeShell. This screen owns only the
## manager-facing interaction contract: hit regions, tooltips and navigation
## signals. It deliberately paints no second desk and no room geometry.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal opened(what: String)

## Normalized screen regions for the current canonical Desk camera. These are
## intentionally generous: the visible low-poly silhouette supplies precision,
## while the hit target supplies usability. If a camera changes, update this
## table rather than authoring another desk layout.
const REGIONS := [
	{"key": "calendar", "rect": Rect2(0.615, 0.00, 0.225, 0.31), "tip": "Calendar"},
	{"key": "encyclopedia", "rect": Rect2(0.585, 0.34, 0.185, 0.36), "tip": "The encyclopedia"},
	{"key": "phone", "rect": Rect2(0.645, 0.57, 0.180, 0.23), "tip": "The telephone"},
	{"key": "machine", "rect": Rect2(0.815, 0.70, 0.185, 0.26), "tip": "The answering machine"},
	{"key": "journal", "rect": Rect2(0.105, 0.64, 0.285, 0.34), "tip": "The journal"},
	{"key": "training", "rect": Rect2(0.395, 0.65, 0.205, 0.33), "tip": "The training clipboard"},
	{"key": "kitchen", "rect": Rect2(0.565, 0.82, 0.155, 0.18), "tip": "The meal plan"},
	{"key": "housing", "rect": Rect2(0.000, 0.70, 0.190, 0.20), "tip": "The housing folder"},
	{"key": "scouting", "rect": Rect2(0.000, 0.84, 0.150, 0.16), "tip": "The scouting board"},
	{"key": "settings", "rect": Rect2(0.900, 0.84, 0.100, 0.16), "tip": "Settings"},
]

var _career_manager: Node = null
var _game_manager: Node = null
var _surface: _DeskInteractionSurface = null


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface = _DeskInteractionSurface.new()
	_surface.name = "DeskInteractionSurface"
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.opened.connect(func(key: String) -> void: opened.emit(key))
	add_child(_surface)


func refresh() -> void:
	if _surface == null:
		return
	_surface.readings = _read_the_desk()
	_surface.queue_redraw()


func _read_the_desk() -> Dictionary:
	var out := {}
	var career = _career_manager.career if _career_manager != null else null
	if career == null:
		return out
	var unread := 0
	if "inbox" in career:
		for entry in Array(career.inbox):
			if not bool(Dictionary(entry).get("read", false)):
				unread += 1
	out["journal"] = "The journal — week %d%s" % [
		int(career.absolute_week), "" if unread == 0 else ", %d unread" % unread,
	]
	var marks: Dictionary = career.scouting_marks if "scouting_marks" in career else {}
	var pinned := 0
	if _game_manager != null:
		pinned = Array(_game_manager.players).size()
	if "scouted_players" in career and not Array(career.scouted_players).is_empty():
		pinned = Array(career.scouted_players).size()
	out["scouting"] = "The scouting board — %d pinned up, %d undecided" % [
		pinned, maxi(pinned - marks.size(), 0)
	]
	var team = _game_manager.team if _game_manager != null else null
	if team != null:
		if "housing_structure" in team:
			out["housing"] = "The housing folder — %s" % str(team.housing_structure)
		out["kitchen"] = "The meal plan — %s" % str(team.food_block)
	out["calendar"] = "Calendar"
	return out


class _DeskInteractionSurface extends Control:
	signal opened(what: String)

	var readings: Dictionary = {}
	var _hovered := ""

	func _ready() -> void:
		set_meta("ui_style_exempt", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var key := _region_at((event as InputEventMouseMotion).position)
			if key == _hovered:
				return
			_hovered = key
			tooltip_text = _tip_for(key)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not key.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var key := _region_at((event as InputEventMouseButton).position)
			if not key.is_empty():
				opened.emit(key)
				accept_event()

	func _region_at(point: Vector2) -> String:
		if size.x <= 0.0 or size.y <= 0.0:
			return ""
		var normalized := Vector2(point.x / size.x, point.y / size.y)
		for entry in REGIONS:
			if (entry["rect"] as Rect2).has_point(normalized):
				return str(entry["key"])
		return ""

	func _tip_for(key: String) -> String:
		if key.is_empty():
			return ""
		for entry in REGIONS:
			if str(entry["key"]) == key:
				return str(readings.get(key, entry["tip"]))
		return ""

	func _draw() -> void:
		if _hovered.is_empty():
			return
		var light := UIPalette.control_is_light(self)
		var accent := UIPalette.color(&"accent", light)
		for entry in REGIONS:
			if str(entry["key"]) != _hovered:
				continue
			var normalized: Rect2 = entry["rect"]
			var rect := Rect2(
				Vector2(normalized.position.x * size.x, normalized.position.y * size.y),
				Vector2(normalized.size.x * size.x, normalized.size.y * size.y)
			)
			# A restrained glassy lift, not a label or permanent UI chrome.
			draw_rect(rect, Color(accent, 0.055), true)
			draw_rect(rect, Color(accent, 0.58), false, 2.0)
			break

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hovered = ""
			tooltip_text = ""
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()
