class_name DeskScreen
extends Control

## The desk.
##
## `CLAUDE.md` has carried a row reading *"The desk -- the menu | **not built
## yet**"* since the interface was first named, and every screen built since has
## been an object that belongs on it. This is the surface they were always
## supposed to be lying on.
##
## ## It is not a main menu
##
## A main menu is a list of destinations. This is a **place**, and the difference
## is load bearing rather than decorative: a list tells you what you can do, and a
## desk tells you what is *happening*. The journal being open at a page with three
## unread entries in it, the answering machine's light going, a folder that has a
## new sheet in it since yesterday -- none of those are navigation, and all of
## them are things a manager would learn by walking into their own office.
##
## The title screen is the room this desk is in (`TITLE_SCREEN.md`), which is why
## that screen is exempt from the medium rule and this one is not: the room can be
## drawn in any hand, and the desk is a table with specific objects on it.
##
## ## Nothing here is a prop
##
## The rule that keeps the ambient layer honest, and the reason to state it before
## anything moves: **every mark on every object is a function of data that already
## exists, or it is not drawn.**
##
## A journal that looks marked-up because there are unread entries is telling the
## truth. A journal that looks marked-up because it is week twelve is set dressing,
## and set dressing drifts out of step within a fortnight and then lies. Each
## object below takes a `reading` -- a count and a short phrase, both derived -- and
## an object with nothing true to say shows nothing.
##
## ## Why the objects are drawn rather than laid out
##
## A desk is the one screen where the *arrangement* is the content. Things on a
## desk overlap, sit at angles, and are placed by hand; a container that flowed
## them into a grid would produce a menu with pictures on it, which is what this
## is trying not to be. So each object carries its own rect as a share of the
## surface and draws itself, and the layout is a table at the top of the file
## rather than a node tree.

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const InboxEvents := preload("res://scripts/data/inbox_events.gd")

## Which object was clicked. The application maps these to screens; the desk does
## not know what a screen is.
signal opened(what: String)

## Where everything lies, as a share of the desk's surface.
##
## Shares rather than pixels, so the arrangement survives a resize -- and in this
## order, because later entries draw over earlier ones and that overlap *is* the
## arrangement. The journal is the thing you sit in front of, so it is centre and
## nearest; the phone is off to the right where a phone is; the encyclopedia is
## the furthest away because it is the thing you get up for.
##
## `x`, `y`, `w`, `h` are all in `[0, 1]` of the desk rect.
const OBJECTS := [
	{
		"key": "encyclopedia", "label": "Encyclopedia",
		"rect": Rect2(0.030, 0.07, 0.185, 0.27), "tilt": -4.0,
	},
	{
		"key": "scouting", "label": "Scouting board",
		"rect": Rect2(0.045, 0.40, 0.27, 0.45), "tilt": 2.5,
	},
	{
		"key": "training", "label": "Training clipboard",
		"rect": Rect2(0.245, 0.11, 0.235, 0.40), "tilt": 5.0,
	},
	{
		"key": "housing", "label": "Housing folder",
		"rect": Rect2(0.290, 0.50, 0.255, 0.38), "tilt": -3.0,
	},
	{
		"key": "kitchen", "label": "Meal plan",
		"rect": Rect2(0.500, 0.56, 0.215, 0.31), "tilt": 6.0,
	},
	{
		"key": "journal", "label": "The journal",
		"rect": Rect2(0.455, 0.09, 0.29, 0.44), "tilt": -1.5,
	},
	{
		"key": "phone", "label": "Telephone",
		"rect": Rect2(0.775, 0.16, 0.175, 0.28), "tilt": -1.0,
	},
	{
		"key": "machine", "label": "Answering machine",
		"rect": Rect2(0.760, 0.55, 0.195, 0.20), "tilt": 2.0,
	},
]

## The desktop itself. A worn wooden surface in Molten and the same wood with the
## lights off in Mikasa -- the desk does not change material at night, and a desk
## that went slate in the dark theme would be a different piece of furniture.
const WOOD_LIGHT := Color(0.52, 0.38, 0.26)
const WOOD_DARK := Color(0.17, 0.13, 0.10)

## How much of the surface the desk takes, leaving room for the ribbon.
const SURFACE_INSET := Vector2(0.0, 0.0)

var _career_manager: Node = null
var _game_manager: Node = null
var _surface: _Surface = null
var _readings: Dictionary = {}


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface = _Surface.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.name = "DeskSurface"
	_surface.opened.connect(func(key: String) -> void: opened.emit(key))
	add_child(_surface)


func refresh() -> void:
	if _surface == null:
		return
	_readings = _read_the_desk()
	_surface.readings = _readings
	_surface.queue_redraw()


## ## What each object has to say
##
## Every line here is derived from real state. Where a system does not exist yet
## the object says nothing rather than saying a plausible number -- an empty
## journal is honest about the game, and a journal reading "3 new" when nothing
## generated three of anything is the failure this whole file's header is about.
func _read_the_desk() -> Dictionary:
	var out := {}
	var career = _career_manager.career if _career_manager != null else null
	if career == null:
		return out

	## The journal counts unread inbox entries, which is a real field.
	var unread := 0
	if "inbox" in career:
		for entry in Array(career.inbox):
			if not bool(Dictionary(entry).get("read", false)):
				unread += 1
	out["journal"] = {
		"count": unread,
		"note": "week %d" % int(career.absolute_week),
	}

	## Scouting counts what is pinned up and how much of it is undecided, because
	## an undecided card is the thing on that board still asking for attention.
	var marks: Dictionary = career.scouting_marks if "scouting_marks" in career else {}
	var pinned := 0
	if _game_manager != null:
		pinned = Array(_game_manager.players).size()
	if "scouted_players" in career and not Array(career.scouted_players).is_empty():
		pinned = Array(career.scouted_players).size()
	out["scouting"] = {
		"count": maxi(pinned - marks.size(), 0),
		"note": "%d pinned up" % pinned,
	}

	var team = _game_manager.team if _game_manager != null else null
	if team != null:
		out["housing"] = {
			"count": 0,
			"note": str(team.accommodation_structure) \
				if "accommodation_structure" in team else "",
		}
		out["kitchen"] = {"count": 0, "note": str(team.food_block)}
	out["training"] = {"count": 0, "note": ""}
	out["encyclopedia"] = {"count": 0, "note": ""}

	## The machine's light is the count, and it is the only object whose reading is
	## *only* a light: a voicemail you have not heard has no summary, which is the
	## whole reason to listen to it.
	out["machine"] = {"count": 0, "note": "no messages"}
	out["phone"] = {"count": 0, "note": ""}
	return out


## The desk, its objects and the clicks on them, in one node.
##
## One `_draw` rather than a node per object, because the objects overlap and
## overlap in canvas drawing is just call order -- whereas eight sibling `Control`s
## would need z-indices, and eight `Button`s laid out by hand would need their
## rects kept in step with the drawing by a second copy of `OBJECTS`.
class _Surface extends Control:
	signal opened(what: String)

	var readings: Dictionary = {}
	var _hovered: String = ""

	const LABEL_SIZE: int = 13
	const NOTE_SIZE: int = 10
	const CORNER: float = 3.0

	func _ready() -> void:
		set_meta("ui_style_exempt", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var under := _object_at((event as InputEventMouseMotion).position)
			if under != _hovered:
				_hovered = under
				queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var hit := _object_at((event as InputEventMouseButton).position)
			if not hit.is_empty():
				opened.emit(hit)
			accept_event()

	## Hit-tested back to front, so the object drawn nearest is the one you get.
	## The reverse of the draw order, which is the whole reason `OBJECTS` is a
	## list rather than a dictionary.
	func _object_at(where: Vector2) -> String:
		for index in range(OBJECTS.size() - 1, -1, -1):
			var entry: Dictionary = OBJECTS[index]
			## Tested in the object's own frame rather than against its screen
			## rect: everything on this desk is rotated a few degrees, and a
			## hit test against the un-rotated rect is wrong along every edge --
			## by up to nine pixels on the clipboard, which is enough to click a
			## visible corner and open whatever is underneath it.
			var rect := _rect_for(entry)
			var centre := rect.position + rect.size * 0.5
			var local := (where - centre).rotated(-deg_to_rad(float(entry["tilt"])))
			if Rect2(-rect.size * 0.5, rect.size).has_point(local):
				return str(entry["key"])
		return ""

	func _rect_for(entry: Dictionary) -> Rect2:
		var share: Rect2 = entry["rect"]
		return Rect2(
			Vector2(share.position.x * size.x, share.position.y * size.y),
			Vector2(share.size.x * size.x, share.size.y * size.y)
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hovered = ""
			queue_redraw()
		elif what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		if size.x < 200.0 or size.y < 150.0:
			return
		var light := UIPalette.control_is_light(self)
		_draw_desktop(light)
		for entry in OBJECTS:
			_draw_object(entry, light)

	## Wood, and the grain in it.
	##
	## Long horizontal streaks rather than a noise field: what makes a plank read
	## as a plank is that its variation runs *one way*, and a desk textured with
	## isotropic noise reads as stone. Deterministic off the row index so the desk
	## is the same desk every time it is opened.
	func _draw_desktop(light: bool) -> void:
		var wood := WOOD_LIGHT if light else WOOD_DARK
		draw_rect(Rect2(Vector2.ZERO, size), wood, true)
		var rows := int(size.y / 7.0)
		for row in range(rows):
			var seed_value := (row * 2654435761) & 0x7FFFFFFF
			var shade := (float(seed_value % 1000) / 1000.0 - 0.5) * 0.06
			var y := float(row) * 7.0
			draw_rect(
				Rect2(Vector2(0.0, y), Vector2(size.x, 7.0)),
				Color(wood.r + shade, wood.g + shade * 0.8, wood.b + shade * 0.6),
				true
			)
		## A soft vignette, so the middle of the desk is where the lamp is.
		for step in range(6):
			var inset := float(step) * 14.0
			draw_rect(
				Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0),
				Color(0.0, 0.0, 0.0, 0.035), false, 14.0
			)

	## One object: its shadow, its body in its own material, its name, and what it
	## has to say today.
	func _draw_object(entry: Dictionary, light: bool) -> void:
		var rect := _rect_for(entry)
		var key := str(entry["key"])
		## **The tilt.**
		##
		## It was in `OBJECTS` from the first draft and unread, so every object
		## rendered square and the desk came out as a grid of coloured rectangles
		## -- a menu with pictures on it, which is the exact thing this screen was
		## written not to be. Nobody puts anything down straight, and a few degrees
		## is the whole difference between things *placed* on a surface and cells
		## in a table.
		##
		## Applied as a canvas transform rather than per-point, so everything drawn
		## for this object -- body, shadow, face, lettering, tally -- turns together
		## and none of them can be forgotten.
		var centre := rect.position + rect.size * 0.5
		draw_set_transform(centre, deg_to_rad(float(entry["tilt"])), Vector2.ONE)
		_draw_body(entry, key, Rect2(-rect.size * 0.5, rect.size), light)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


	func _draw_body(entry: Dictionary, key: String, rect: Rect2, light: bool) -> void:
		var hovered := key == _hovered
		## Hover lifts rather than tints. Everything on this desk is a physical
		## object, and the physical way to say "this one" is to pick it up an inch
		## -- which is a longer shadow and a small rise, not a colour.
		var rise := 3.0 if hovered else 0.0
		var font := get_theme_default_font()
		var body := Rect2(rect.position - Vector2(0.0, rise), rect.size)
		for step in range(3):
			draw_rect(
				Rect2(
					body.position + Vector2(2.0, 3.0 + rise) + Vector2(float(step), float(step)) * 0.5,
					body.size
				),
				Color(0.0, 0.0, 0.0, (0.22 if hovered else 0.16) / float(step + 1)),
				true
			)
		draw_rect(body, _material_of(key, light), true)
		draw_rect(body, Color(_material_of(key, light).darkened(0.35), 0.8), false, 1.2)
		_draw_face(key, body, light)
		if font == null:
			return
		var ink := _lettering_of(key, light)
		draw_string(
			font, body.position + Vector2(10.0, 22.0), str(entry["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 20.0, LABEL_SIZE, ink
		)
		var reading: Dictionary = readings.get(key, {})
		var note := str(reading.get("note", ""))
		if not note.is_empty():
			draw_string(
				font, body.position + Vector2(10.0, 38.0), note,
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 20.0, NOTE_SIZE,
				Color(ink, 0.7)
			)
		var count := int(reading.get("count", 0))
		if count > 0:
			_draw_tally(body, count, light)

	## What each object is made of, taken from the medium it actually uses so the
	## desk cannot disagree with the screen it opens.
	func _material_of(key: String, light: bool) -> Color:
		match key:
			"journal":
				return Color("d9c9a8") if light else Color("3b3324")
			"training":
				return Color("b07f4f") if light else Color("53392a")
			"scouting":
				return Color("a87f52") if light else Color("4c3826")
			"housing":
				return Color("d8be86") if light else Color("4a3d25")
			"kitchen":
				return Color("e8e2d2") if light else Color("55524a")
			"encyclopedia":
				return Color("7d5a72") if light else Color("3b2b37")
			"phone":
				return Color("2f3236") if light else Color("22262a")
			_:
				return Color("3a3d42") if light else Color("26292d")

	func _lettering_of(key: String, light: bool) -> Color:
		if key in ["phone", "machine", "encyclopedia"]:
			return Color(0.94, 0.93, 0.90)
		return UIPalette.color(&"ink", light) if light \
			else Color(0.90, 0.88, 0.83)

	## The one mark each object carries that is not its name.
	func _draw_face(key: String, body: Rect2, light: bool) -> void:
		match key:
			"training":
				## The clipboard's clamp, which is the mark that says clipboard.
				var clamp := Rect2(
					body.position + Vector2(body.size.x * 0.34, -4.0),
					Vector2(body.size.x * 0.32, 12.0)
				)
				draw_rect(clamp, Color(0.62, 0.64, 0.67), true)
			"housing":
				## A folder's tab, on the top edge, offset like a real cut.
				draw_rect(
					Rect2(
						body.position + Vector2(body.size.x * 0.5, -9.0),
						Vector2(body.size.x * 0.34, 10.0)
					),
					_material_of(key, light), true
				)
			"phone":
				_draw_handset(body)
			"machine":
				_draw_machine(body, light)

	func _draw_handset(body: Rect2) -> void:
		## A handset lying in its cradle, seen from above: two ends and a bar.
		var mid := body.position + Vector2(body.size.x * 0.5, body.size.y * 0.62)
		var span := body.size.x * 0.34
		var ink := Color(0.10, 0.11, 0.13)
		draw_rect(
			Rect2(mid - Vector2(span, 7.0), Vector2(span * 2.0, 14.0)), ink, true
		)
		for side in [-1.0, 1.0]:
			draw_rect(
				Rect2(
					mid + Vector2(side * span - 11.0 * maxf(side, 0.0), -13.0),
					Vector2(11.0, 26.0)
				), ink, true
			)

	func _draw_machine(body: Rect2, _light: bool) -> void:
		## The light. Red and steady when there is nothing, and the *count* is what
		## makes it flash -- but nothing flashes here, because a desk that animates
		## before there are any messages is animating a lie.
		var lamp := body.position + Vector2(body.size.x - 20.0, body.size.y - 16.0)
		var waiting := int(Dictionary(readings.get("machine", {})).get("count", 0)) > 0
		draw_circle(lamp, 5.0, Color("d94f42") if waiting else Color(0.28, 0.26, 0.25))
		draw_circle(
			lamp + Vector2(-1.6, -1.6), 1.8,
			Color(1.0, 1.0, 1.0, 0.45 if waiting else 0.12)
		)

	## How many things are waiting, as marks rather than as a number in a circle.
	##
	## A tally, because that is what somebody keeps on a desk, and because it makes
	## "a few" and "far too many" different *shapes* rather than two-digit numbers
	## you have to read. Capped, and the cap is visible: past nine the fifth group
	## is replaced by a plus, so the mark stops being countable at exactly the point
	## counting stops being the useful operation.
	func _draw_tally(body: Rect2, count: int, light: bool) -> void:
		var ink := UIPalette.color(&"accent", light)
		var at := body.position + Vector2(body.size.x - 16.0, 14.0)
		var shown := mini(count, 9)
		for index in range(shown):
			var x := at.x - float(index % 5) * 5.0
			var y := at.y + float(index / 5) * 11.0
			draw_line(Vector2(x, y), Vector2(x - 2.0, y + 9.0), ink, 2.0)
		if count > 9:
			draw_string(
				get_theme_default_font(), at + Vector2(-34.0, 9.0), "+",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, ink
			)
