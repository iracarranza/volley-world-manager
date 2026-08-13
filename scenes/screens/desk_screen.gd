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
## Where everything lies, how thick it is, and what it is resting on.
##
## ## Seen from the chair
##
## The desk is drawn from where a manager sits: looking down at it, but not from
## directly above. That is one property and it changes everything -- from
## overhead, objects are outlines, and from a chair they have **sides**. You can
## see the block of pages in a shut journal, the moulded body of a telephone, and
## the fact that the clipboard is not lying on the desk at all but bridging
## between the journal and the board.
##
## The projection is oblique rather than perspective: no vanishing point, no
## scaling with distance. `thickness` is how far an object's near face drops on
## screen, and `z` is what it is stacked on. Perspective would be more correct and
## would cost the closed-form hit test that lets a click be a rect check -- the
## same trade `TofuBlock` and `FloorPlan` already make, and for the same reason.
##
## **`z` is a stacking order and a shadow length at once.** Later entries draw
## over earlier ones, and an object's shadow grows and softens with its height, so
## the clipboard reading as *suspended* over two things is one number rather than
## a drawn effect.
##
## `rect` is in shares of the desk surface, which is the room minus the wall.
const OBJECTS := [
	{
		"key": "encyclopedia", "label": "Encyclopedia",
		"rect": Rect2(0.028, 0.05, 0.175, 0.30), "tilt": -4.0,
		"thickness": 13.0, "z": 0.0,
	},
	{
		"key": "scouting", "label": "Scouting board",
		"rect": Rect2(0.042, 0.40, 0.27, 0.47), "tilt": 2.5,
		"thickness": 7.0, "z": 0.0,
	},
	{
		"key": "housing", "label": "Housing folder",
		"rect": Rect2(0.285, 0.50, 0.255, 0.40), "tilt": -3.0,
		"thickness": 5.0, "z": 1.0,
	},
	{
		"key": "journal", "label": "The journal",
		"rect": Rect2(0.450, 0.07, 0.29, 0.46), "tilt": -1.5,
		"thickness": 19.0, "z": 1.0,
	},
	{
		"key": "kitchen", "label": "Meal plan",
		"rect": Rect2(0.495, 0.56, 0.215, 0.32), "tilt": 6.0,
		"thickness": 8.0, "z": 2.0,
	},
	{
		## **Suspended.** It rests on the journal's near edge at one end and the
		## board at the other, so it is above both and its shadow falls on both --
		## which is the whole reason objects have a height rather than an order.
		"key": "training", "label": "Training clipboard",
		"rect": Rect2(0.238, 0.10, 0.235, 0.42), "tilt": 5.0,
		"thickness": 11.0, "z": 3.0,
	},
	{
		"key": "phone", "label": "Telephone",
		"rect": Rect2(0.780, 0.13, 0.170, 0.26), "tilt": -1.0,
		"thickness": 26.0, "z": 0.0,
	},
	{
		"key": "machine", "label": "Answering machine",
		"rect": Rect2(0.766, 0.45, 0.185, 0.17), "tilt": 2.0,
		"thickness": 20.0, "z": 0.0,
	},
	{
		## Settings, as a thing on a desk rather than a cog in a corner.
		##
		## A rotary pencil sharpener: the body is unremarkable stationery and the
		## crank wheel is a toothed disc, which from a chair reads as a gear
		## without ever being one. Nobody has to be told what it opens, and the
		## desk does not acquire an icon from a different design language to say
		## so.
		"key": "settings", "label": "", "rect": Rect2(0.792, 0.70, 0.098, 0.15),
		"tilt": -6.0, "thickness": 15.0, "z": 0.0,
	},
	{
		## Drawn last so its light falls over everything. It is furniture and it
		## opens nothing -- the one object here with no destination, which is why
		## it has no label and why `_object_at` skips it.
		"key": "lamp", "label": "", "rect": Rect2(0.610, 0.03, 0.115, 0.17),
		"tilt": 0.0, "thickness": 34.0, "z": 4.0,
	},
]

## The desktop itself. A worn wooden surface in Molten and the same wood with the
## lights off in Mikasa -- the desk does not change material at night, and a desk
## that went slate in the dark theme would be a different piece of furniture.
const WOOD_LIGHT := Color(0.52, 0.38, 0.26)
const WOOD_DARK := Color(0.17, 0.13, 0.10)

## The wall behind the desk, and the window in it.
##
## Reserved before anything is placed, because the far edge of a desk seen from a
## chair is *not* the top of the screen -- there is a room behind it, and leaving
## that out is what made the first draft read as a texture rather than a place.
const WALL_SHARE: float = 0.17
## The desk's own front lip, which is the near edge you are sitting at.
const LIP: float = 9.0

## What is out of the window, and it is the same window at two times of day.
##
## This is the one place a theme means something rather than being a preference:
## Molten is the afternoon and Mikasa is late, so the light in the room has a
## *source*, and the lamp being on in one and off in the other follows from it
## instead of being a second decision. A dark theme that is merely darker is a
## filter; a dark theme that is night is a room.
const SKY_DAY_TOP := Color(0.60, 0.76, 0.86)
const SKY_DAY_LOW := Color(0.86, 0.88, 0.82)
const SKY_NIGHT_TOP := Color(0.05, 0.07, 0.14)
const SKY_NIGHT_LOW := Color(0.12, 0.14, 0.23)
const WALL_LIGHT := Color(0.80, 0.75, 0.66)
const WALL_DARK := Color(0.15, 0.14, 0.16)

## The lamp's pool on the desk, which only exists at night.
const LAMP_REACH: float = 260.0
const LAMP_WARMTH := Color(1.0, 0.87, 0.62)

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
			## Furniture is not clickable. The lamp is on the desk and opens
			## nothing, and a lamp that swallowed clicks meant for the journal
			## under it would be a hit box shaped like a joke.
			if str(entry["key"]) == "lamp":
				continue
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

	## The desk itself, which is the room minus the wall behind it.
	func _desk_rect() -> Rect2:
		var top := size.y * WALL_SHARE
		return Rect2(Vector2(0.0, top), Vector2(size.x, size.y - top))

	func _rect_for(entry: Dictionary) -> Rect2:
		var desk := _desk_rect()
		var share: Rect2 = entry["rect"]
		return Rect2(
			desk.position + Vector2(share.position.x * desk.size.x, share.position.y * desk.size.y),
			Vector2(share.size.x * desk.size.x, share.size.y * desk.size.y)
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
		_draw_wall(light)
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
		var desk := _desk_rect()
		var wood := WOOD_LIGHT if light else WOOD_DARK
		draw_rect(desk, wood, true)
		var rows := int(desk.size.y / 7.0)
		for row in range(rows):
			var seed_value := (row * 2654435761) & 0x7FFFFFFF
			var shade := (float(seed_value % 1000) / 1000.0 - 0.5) * 0.06
			var y := desk.position.y + float(row) * 7.0
			draw_rect(
				Rect2(Vector2(0.0, y), Vector2(size.x, 7.0)),
				Color(wood.r + shade, wood.g + shade * 0.8, wood.b + shade * 0.6),
				true
			)
		## The front lip: the near edge of the desk, which you can see because you
		## are looking down at it rather than straight on. One band, and it is what
		## makes the surface a *table* rather than a background.
		draw_rect(
			Rect2(Vector2(0.0, size.y - LIP), Vector2(size.x, LIP)),
			Color(wood.darkened(0.34), 1.0), true
		)

		## The lamp's pool, and only at night. In the afternoon the light comes
		## from the window and the lamp is off, so painting a pool would be a
		## second light source with no lamp lit under it.
		if not light:
			var lamp := _rect_for(_lamp_entry())
			var at := lamp.position + Vector2(lamp.size.x * 0.5, lamp.size.y)
			## Painted under the objects, so the lamp lights the desk and the things
			## on it keep their own colour -- a pool drawn over the top would tint
			## every material it reached and undo the whole point of them having
			## one. Stronger than the first pass, which was too faint to see it
			## was there at all.
			for step in range(10):
				var t := float(step) / 10.0
				draw_circle(
					at + Vector2(0.0, LAMP_REACH * 0.40),
					LAMP_REACH * (0.28 + t * 0.82),
					Color(LAMP_WARMTH, 0.075 * (1.0 - t) * (1.0 - t))
				)

	func _lamp_entry() -> Dictionary:
		for entry in OBJECTS:
			if str(entry["key"]) == "lamp":
				return entry
		return OBJECTS[0]

	## The room behind the desk, and the window in it.
	func _draw_wall(light: bool) -> void:
		var wall_rect := Rect2(Vector2.ZERO, Vector2(size.x, size.y * WALL_SHARE))
		draw_rect(wall_rect, WALL_LIGHT if light else WALL_DARK, true)

		var window_rect := Rect2(
			Vector2(size.x * 0.09, wall_rect.size.y * 0.13),
			Vector2(size.x * 0.30, wall_rect.size.y * 0.78)
		)
		var top_sky := SKY_DAY_TOP if light else SKY_NIGHT_TOP
		var low_sky := SKY_DAY_LOW if light else SKY_NIGHT_LOW
		## A vertical gradient in slices, because canvas drawing has no gradient
		## fill and eighteen bands at this height is under a pixel of banding.
		var bands := 18
		for band in range(bands):
			var t := float(band) / float(bands)
			draw_rect(
				Rect2(
					window_rect.position + Vector2(0.0, window_rect.size.y * t),
					Vector2(window_rect.size.x, window_rect.size.y / float(bands) + 1.0)
				),
				top_sky.lerp(low_sky, t), true
			)
		if not light:
			## Lights on the other side of whatever is out there. Deterministic,
			## because a window whose city rearranges itself every frame is a
			## screensaver.
			for index in range(26):
				var seed_value := ((index + 3) * 2654435761) & 0x7FFFFFFF
				var at := window_rect.position + Vector2(
					float(seed_value % 1000) / 1000.0 * window_rect.size.x,
					float((seed_value / 1000) % 1000) / 1000.0 * window_rect.size.y
				)
				draw_rect(
					Rect2(at, Vector2(2.0, 2.0)),
					Color(1.0, 0.92, 0.7, 0.28 + float(seed_value % 60) / 160.0), true
				)
		## The frame and its one glazing bar. A window with no bar is a hole.
		var frame_ink := Color(WALL_LIGHT.darkened(0.45) if light else Color(0.06, 0.06, 0.08))
		draw_rect(window_rect, frame_ink, false, 4.0)
		draw_line(
			Vector2(window_rect.position.x + window_rect.size.x * 0.5, window_rect.position.y),
			Vector2(
				window_rect.position.x + window_rect.size.x * 0.5,
				window_rect.position.y + window_rect.size.y
			), frame_ink, 3.0
		)
		## The sill, which is the one horizontal that says the wall has depth.
		draw_rect(
			Rect2(
				window_rect.position + Vector2(-6.0, window_rect.size.y),
				Vector2(window_rect.size.x + 12.0, 5.0)
			), frame_ink, true
		)
		## And the shadow the wall drops onto the back of the desk.
		draw_rect(
			Rect2(Vector2(0.0, wall_rect.size.y), Vector2(size.x, 14.0)),
			Color(0.0, 0.0, 0.0, 0.22), true
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
		## **The shadow is the height.**
		##
		## An object's shadow drops further and spreads wider the higher it sits,
		## so the clipboard bridging the journal and the board casts a long soft
		## one onto both -- which is what says *suspended* without a single line
		## being drawn to say it. Height is `z` plus the object's own thickness,
		## because a thick thing on the desk is as high as a thin thing on a book.
		var height := float(entry["z"]) * 7.0 + float(entry["thickness"]) * 0.5 + rise
		for step in range(4):
			draw_rect(
				Rect2(
					body.position
						+ Vector2(height * 0.22, height * 0.42)
						+ Vector2(float(step), float(step)) * (1.0 + height * 0.05),
					body.size
				),
				Color(0.0, 0.0, 0.0, (0.24 if hovered else 0.18) / float(step + 1)),
				true
			)
		_draw_sides(key, body, float(entry["thickness"]), light)
		var stock := _stock_of(key, light)
		draw_rect(body, stock, true)
		_draw_grain(key, body, stock)
		## The page inside, showing past the object that holds it. Inset unevenly:
		## paper in a folder does not sit centred, and the offset is what makes the
		## leaf read as *inside* rather than as a second rectangle on top.
		var ground := _ground_of(key, light)
		if ground.a > 0.0:
			draw_rect(_leaf(key, body), ground, true)
		draw_rect(body, Color(stock.darkened(0.35), 0.8), false, 1.2)
		_draw_face(key, body, light)
		if font == null:
			return
		var ink := _lettering_of(key, light)
		if str(entry["label"]).is_empty():
			## Furniture and the sharpener carry no name. A label on a lamp is a
			## caption on a photograph of a lamp.
			return
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

	## ## What each object is made of
	##
	## Two facts per object and they are different facts, which is why there are
	## two tables rather than one:
	##
	## - **`stock`** is what the thing is physically -- the manila of a folder, the
	##   cork of a board, the melamine of a whiteboard. It is the medium.
	## - **`ground`** is the colour of the *page you land on* when you open it.
	##
	## They have to agree or the desk lies about where a click goes: an object
	## that is buff on the desk and blue on the screen is two different objects
	## with one name. So the stock is the material and the ground is drawn as the
	## visible part of the page inside it -- the sheet on the clipboard, the pages
	## in the journal, the leaf sticking out of the folder. Picking one up and
	## opening it is continuous.
	##
	## Both are read off the same palette the screens use, so a theme change moves
	## the desk with them and nothing here has a colour of its own to drift.
	func _stock_of(key: String, light: bool) -> Color:
		match key:
			"journal":
				## Cloth. The journal is the one bound object on the desk.
				return Color("9d5f4a") if light else Color("46281f")
			"training", "scouting":
				## Both cork, and this is the one place on the desk they are
				## allowed to look alike -- because they *are* alike, and what
				## separates them is the clamp and the pins drawn on top.
				return Color("b07f4f") if light else Color("53392a")
			"housing":
				## Manila, from `UIStyleSystem.CARD_STOCK_*` applied to the
				## palette's own surface rather than typed in again.
				return Color("d8be86") if light else Color("4a3d25")
			"kitchen":
				## The pad: tinted office stock, gummed at the top.
				return Color("dcd8c4") if light else Color("4c4a41")
			"encyclopedia":
				return Color("7d5a72") if light else Color("40303c")
			"phone", "machine":
				return Color("2b2e33") if light else Color("1d2126")
			"settings":
				## Unremarkable stationery: the grey-green of a metal desk tidy,
				## which is the point -- it should be the least interesting thing
				## on the desk until you notice the wheel.
				return Color("6f7566") if light else Color("3b4038")
			"lamp":
				return Color("47505a") if light else Color("2c333b")
			_:
				return UIPalette.color(&"surface", light)

	## Where the page sits inside the object, and it is **not** centred.
	##
	## A uniform inset made every object a frame round a rectangle, which is eight
	## objects with one silhouette -- and it hid the materials, because the page
	## covered the part of the stock the grain was drawn on. Each object shows its
	## own material where that material actually shows: a clipboard is board round
	## a sheet with a wide margin at the bottom, a folder is manila down the fold
	## and along the bottom with the leaf sticking out of the top, a journal is a
	## cloth binding at the spine and almost no margin elsewhere.
	func _leaf(key: String, body: Rect2) -> Rect2:
		match key:
			"training":
				## Board all round, and more of it below the clip.
				return Rect2(
					body.position + Vector2(14.0, 20.0),
					body.size - Vector2(28.0, 46.0)
				)
			"housing":
				## The fold is on the left, so the manila shows there and the leaf
				## rides high and to the right, past the top edge of the folder.
				return Rect2(
					body.position + Vector2(22.0, -6.0),
					body.size - Vector2(30.0, 26.0)
				)
			"journal":
				## A bound book: the binding shows down the spine and as a thin
				## edge everywhere else.
				return Rect2(
					body.position + Vector2(18.0, 7.0),
					body.size - Vector2(25.0, 14.0)
				)
			"kitchen":
				## A pad is gummed at the top, so the strip of board shows there
				## and the sheet runs to the other three edges.
				return Rect2(
					body.position + Vector2(5.0, 18.0),
					body.size - Vector2(10.0, 23.0)
				)
			_:
				return Rect2(
					body.position + Vector2(9.0, 13.0),
					body.size - Vector2(18.0, 22.0)
				)

	## The page inside, which is the colour of the screen the object opens into.
	func _ground_of(key: String, light: bool) -> Color:
		match key:
			"scouting":
				## The board has no page: what you see when you open it is more
				## cork. So it returns its own stock, and the object draws no leaf.
				return Color(0, 0, 0, 0)
			"phone", "machine", "settings", "lamp":
				return Color(0, 0, 0, 0)
			"journal", "encyclopedia":
				return UIPalette.color(&"surface_raised", light)
			"housing":
				return Color("efe0bd") if light else Color("6a5836")
			"kitchen":
				return Color("f6f3e8") if light else Color("6d6a60")
			_:
				return UIPalette.color(&"surface", light)

	## Read against **what the label actually sits on**, which is the leaf wherever
	## there is one.
	##
	## It used to be read against the object: the encyclopedia is a dark purple
	## book, so its lettering was pale -- and once the page inside it started
	## showing, the label was pale ink on a cream page and vanished entirely. The
	## thing behind the words is the page, not the cover.
	func _lettering_of(key: String, light: bool) -> Color:
		## **Chosen by the luminance of whatever is behind the word**, not by the
		## theme.
		##
		## It used to assume a page is pale, which is true in Molten and false in
		## Mikasa -- the journal's ground is the journal screen's own surface and
		## that is dark blue at night, so the label came out dark ink on a dark
		## page and vanished. Asking the colour is the only version of this that
		## cannot be wrong when a palette moves.
		var behind := _ground_of(key, light)
		if behind.a <= 0.0:
			behind = _stock_of(key, light)
		var luma := behind.r * 0.299 + behind.g * 0.587 + behind.b * 0.114
		return Color(0.13, 0.12, 0.10) if luma > 0.52 else Color(0.94, 0.93, 0.89)

	## The near and side faces, which are the whole of what "from the chair"
	## means.
	##
	## Only two of the four are ever visible, and which two follows from where the
	## object is: the near face always, and whichever side faces away from the
	## middle of the desk -- because you are sitting at the centre of the near
	## edge, so things on the left show their right side and things on the right
	## show their left. Drawing all four would be an exploded diagram, and drawing
	## only the near one makes everything look like it is against a wall.
	func _draw_sides(key: String, body: Rect2, thickness: float, light: bool) -> void:
		if thickness <= 0.5:
			return
		var stock := _stock_of(key, light)
		var near := Color(stock.darkened(0.30), 1.0)
		var side := Color(stock.darkened(0.44), 1.0)
		var drop := Vector2(0.0, thickness)
		## Which side is turned toward the viewer's eye line.
		var to_the_right := body.position.x + body.size.x * 0.5 < size.x * 0.5
		var x := body.position.x + body.size.x if to_the_right else body.position.x
		var edge := Vector2(x, body.position.y)
		var lean := thickness * (0.16 if to_the_right else -0.16)
		draw_colored_polygon(
			PackedVector2Array([
				edge, edge + Vector2(lean, thickness),
				edge + Vector2(lean, thickness) + Vector2(0.0, body.size.y),
				edge + Vector2(0.0, body.size.y),
			]), side
		)
		draw_colored_polygon(
			PackedVector2Array([
				body.position + Vector2(0.0, body.size.y),
				body.position + Vector2(body.size.x, body.size.y),
				body.position + Vector2(body.size.x, body.size.y) + drop,
				body.position + Vector2(0.0, body.size.y) + drop,
			]), near
		)
		_draw_edge_detail(key, body, thickness, light)

	## What the near face is made of, where that is a different thing from what
	## the top is.
	func _draw_edge_detail(key: String, body: Rect2, thickness: float, light: bool) -> void:
		var near_top := body.position.y + body.size.y
		match key:
			"journal":
				## **The page block.** A shut book seen from a chair is mostly this
				## -- a stack of leaves, cream, with the cloth of the cover above
				## and below it. It is the single mark that says "book" rather than
				## "coloured rectangle", and it is four lines.
				var pages := Color(0.94, 0.91, 0.82) if light else Color(0.74, 0.71, 0.64)
				draw_rect(
					Rect2(
						Vector2(body.position.x + 4.0, near_top + 3.0),
						Vector2(body.size.x - 8.0, thickness - 7.0)
					), pages, true
				)
				var leaf := Color(pages.darkened(0.22), 0.7)
				var y := near_top + 5.0
				while y < near_top + thickness - 4.0:
					draw_line(
						Vector2(body.position.x + 4.0, y),
						Vector2(body.position.x + body.size.x - 4.0, y), leaf, 1.0
					)
					y += 3.0
				## And the spine, down the left, where the cloth wraps round.
				draw_rect(
					Rect2(
						body.position + Vector2(0.0, 0.0),
						Vector2(11.0, body.size.y + thickness)
					), Color(_stock_of(key, light).darkened(0.18), 1.0), true
				)
			"phone":
				## The moulded body: a lighter chamfer along the top of the near
				## face, which is what a plastic case has and a slab does not.
				draw_rect(
					Rect2(Vector2(body.position.x, near_top), Vector2(body.size.x, 3.0)),
					Color(0.42, 0.45, 0.49, 0.85), true
				)
			"machine":
				draw_rect(
					Rect2(Vector2(body.position.x, near_top), Vector2(body.size.x, 3.0)),
					Color(0.42, 0.45, 0.49, 0.85), true
				)

	## The one texture mark that says which material this is.
	##
	## Not the full component -- `UICorkBoard` and `card_fibre.gdshader` draw these
	## properly at screen size and would be wasted on a 200px thumbnail, where what
	## survives is *one* characteristic. Cork is speckled, the journal is screened,
	## manila has fibre in it, and the pad has a printed grid. Anything finer than
	## that is invisible at this size and costs a draw call each.
	func _draw_grain(key: String, body: Rect2, stock: Color) -> void:
		var seed_value := int(key.hash() & 0x7FFFFFFF)
		match key:
			"training", "scouting":
				## Cork: two scales, the coarse one only. The fine granule pitch is
				## under a pixel here.
				for index in range(int(body.get_area() / 900.0)):
					seed_value = (seed_value * 1103515245 + 12345) & 0x7FFFFFFF
					var at := body.position + Vector2(
						float(seed_value % 1000) / 1000.0 * body.size.x,
						float((seed_value / 1000) % 1000) / 1000.0 * body.size.y
					)
					draw_rect(Rect2(at, Vector2(2.0, 2.0)), Color(stock.darkened(0.3), 0.5), true)
			"journal":
				## The halftone, at the only pitch that reads this small.
				var pitch := 4.0
				var y := body.position.y + 2.0
				while y < body.position.y + body.size.y - 2.0:
					var x := body.position.x + 2.0 + (fmod(y, pitch * 2.0) * 0.5)
					while x < body.position.x + body.size.x - 2.0:
						draw_rect(Rect2(Vector2(x, y), Vector2(1.0, 1.0)), Color(stock.darkened(0.25), 0.45), true)
						x += pitch
					y += pitch
			"housing":
				## Fibre: short flecks lying flat, which is the whole of what manila
				## is at any size.
				for index in range(int(body.get_area() / 500.0)):
					seed_value = (seed_value * 1103515245 + 12345) & 0x7FFFFFFF
					var at := body.position + Vector2(
						float(seed_value % 1000) / 1000.0 * body.size.x,
						float((seed_value / 1000) % 1000) / 1000.0 * body.size.y
					)
					draw_rect(Rect2(at, Vector2(2.0, 1.0)), Color(stock.darkened(0.35), 0.35), true)

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
					_stock_of(key, light), true
				)
			"phone":
				_draw_handset(body)
			"machine":
				_draw_machine(body, light)
			"settings":
				_draw_sharpener(body, light)
			"lamp":
				_draw_lamp(body, light)

	## A rotary pencil sharpener, whose crank wheel is a toothed disc.
	##
	## The brief asked for "stationery with a camouflaged gear icon", and the
	## camouflage has to work both ways: it must read as a gear at a glance, so
	## nobody has to be told it is settings, and it must be a real object, so the
	## desk does not acquire an icon from a different design language. A sharpener
	## is the one piece of stationery whose working part is genuinely a wheel with
	## teeth in it.
	func _draw_sharpener(body: Rect2, light: bool) -> void:
		var centre := body.position + body.size * 0.5
		## Smaller and darker than the first pass, which drew a nine-petalled white
		## flower filling the whole body. A sharpener's wheel is a *part* of it,
		## and steel on a dark desk at night is much closer to the body than to
		## white -- it was reading as the brightest object in the room, which for a
		## settings control is exactly backwards.
		var radius := minf(body.size.x, body.size.y) * 0.24
		var steel := Color(0.58, 0.59, 0.60) if light else Color(0.40, 0.42, 0.44)
		var teeth := 9
		for tooth in range(teeth):
			var angle := TAU * float(tooth) / float(teeth)
			var at := centre + Vector2(cos(angle), sin(angle)) * radius
			draw_circle(at, radius * 0.34, steel)
		draw_circle(centre, radius * 0.86, steel)
		draw_circle(centre, radius * 0.30, Color(_stock_of("settings", light).darkened(0.4), 1.0))
		## The shavings drawer, on the near side, so it is a sharpener rather than
		## a cog somebody put on a desk.
		draw_rect(
			Rect2(
				Vector2(body.position.x + body.size.x * 0.18, body.position.y + body.size.y - 7.0),
				Vector2(body.size.x * 0.64, 5.0)
			), Color(steel.darkened(0.3), 0.9), true
		)

	## A desk lamp, seen from a chair: the shade from slightly above, the arm, and
	## the base. Lit or not, which is the theme.
	func _draw_lamp(body: Rect2, light: bool) -> void:
		var shade := Color(0.36, 0.42, 0.46) if light else Color(0.30, 0.33, 0.38)
		var mouth := body.position + Vector2(body.size.x * 0.5, body.size.y * 0.74)
		## The shade, as a wedge opening toward the desk.
		draw_colored_polygon(
			PackedVector2Array([
				body.position + Vector2(body.size.x * 0.34, 0.0),
				body.position + Vector2(body.size.x * 0.66, 0.0),
				mouth + Vector2(body.size.x * 0.44, 0.0),
				mouth - Vector2(body.size.x * 0.44, 0.0),
			]), shade
		)
		## The bulb, which is the only thing on this desk that is a light rather
		## than a thing lit.
		draw_circle(
			mouth, body.size.x * 0.16,
			Color(0.30, 0.32, 0.35) if light else LAMP_WARMTH
		)
		if not light:
			for step in range(3):
				draw_circle(
					mouth, body.size.x * (0.24 + float(step) * 0.16),
					Color(LAMP_WARMTH, 0.13 / float(step + 1))
				)
		draw_line(
			body.position + Vector2(body.size.x * 0.5, body.size.y * 0.72),
			body.position + Vector2(body.size.x * 0.5, body.size.y),
			Color(shade.darkened(0.2), 1.0), 4.0
		)

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
