class_name DeskScreen
extends Control

## The desk, from the chair.
##
## ## This screen is not an interface
##
## Every other page in this game is a *document* -- a journal, a clipboard, a
## board, a folder -- and is drawn the way documents are: abstracted, flattened,
## with a material standing in for an idea. That is right for a page you read and
## wrong for the thing this is.
##
## The desk is where the title screen puts you down. It is the one screen with no
## information on it, because it is not a page: it is **the room**, at the moment
## before work starts, and its job is to make a manager want to pick something up.
## So it is not laid out, it is *staged*, and everything on it is a stylised model
## of the object it actually is rather than a coloured rectangle wearing a label.
##
## Three rules follow, and they are most of the file:
##
## **Nothing is labelled.** A desk with the word "Telephone" written across the
## telephone is a diagram. Names and readings are in the tooltip, which is what
## pointing at a thing on a desk gets you.
##
## **Hover lifts the silhouette rather than tinting a rect.** What highlights is
## the outline of the modelled thing, so the feedback confirms you read the shape.
##
## **It is almost purely visual, and that is the specification.** Anything that
## needs reading has a screen of its own to be read on.
##
## ## The projection, and why the angle is low
##
## Looking down at your own desk from a chair is roughly twenty-five degrees above
## the surface, not seventy. That one number decides everything: at a high angle
## objects are outlines with an edge on them, and at a low one they are *bodies* --
## you see the front of a book rather than the top of it, a telephone has a shape,
## and a lamp has a height rather than a footprint.
##
## Points live in desk space `(u, v, h)`: `u` across in `[0, 1]`, `v` back to
## front in `[0, 1]`, `h` upward in units of about a centimetre.
##
##     x = centre + (u - 0.5) * width * lerp(FAR_NARROWING, 1.0, v)
##     y = far_edge + v * depth - h * RISE
##
## The `u` term narrows with distance, which is the only perspective here and the
## one that matters -- a desk from a chair is a trapezoid, and a rectangle reads as
## a wall. Everything else is parallel, because a closed-form inverse is what lets
## a click be arithmetic instead of a raycast: the same trade `TofuBlock` and
## `FloorPlan` already make.
##
## ## Order
##
## Painter's algorithm on the near edge of each footprint, so what is closer to the
## chair draws last. That is also what `rest` is for: a clipboard lying across the
## journal rests at `2.5`, and it occludes and shadows both the journal and the
## board without anything being told to draw it on top.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## Which object was clicked. The application maps these to screens; the desk does
## not know what a screen is.
signal opened(what: String)

## How far the far edge of the desk narrows, as a share of the near edge.
const FAR_NARROWING: float = 0.80
## Screen pixels per unit of height, and the lever that sets the viewing angle:
## bigger is a lower chair. At 3.9 a five-unit book shows about twenty pixels of
## its own front cover, which is a book you can see is shut.
const RISE: float = 3.9
const WALL_SHARE: float = 0.20
const LIP: float = 12.0

## ## What is on the desk
##
## `foot` is the footprint in desk space -- `x`/`y` are the far-left corner's
## `u`/`v`, `w`/`h` its extent across and back-to-front. `rest` is what it is lying
## on and `height` is how thick it is, both in `RISE`'s units.
const OBJECTS := [
	{
		"key": "encyclopedia", "label": "Encyclopedia",
		"tip": "The encyclopedia", "foot": Rect2(0.035, 0.06, 0.150, 0.20),
		"tilt": -5.0, "rest": 0.0, "height": 8.0,
	},
	{
		"key": "lamp", "label": "", "tip": "",
		"foot": Rect2(0.615, 0.02, 0.085, 0.10),
		"tilt": 0.0, "rest": 0.0, "height": 42.0,
	},
	{
		"key": "phone", "label": "Telephone",
		"tip": "The telephone", "foot": Rect2(0.795, 0.10, 0.145, 0.17),
		"tilt": -4.0, "rest": 0.0, "height": 8.0,
	},
	{
		"key": "journal", "label": "The journal",
		"tip": "The journal", "foot": Rect2(0.430, 0.20, 0.270, 0.31),
		"tilt": -2.0, "rest": 0.0, "height": 5.0,
	},
	{
		"key": "machine", "label": "Answering machine",
		"tip": "The answering machine", "foot": Rect2(0.790, 0.36, 0.155, 0.14),
		"tilt": 3.0, "rest": 0.0, "height": 6.0,
	},
	{
		"key": "scouting", "label": "Scouting board",
		"tip": "The scouting board", "foot": Rect2(0.030, 0.34, 0.245, 0.40),
		"tilt": 2.0, "rest": 0.0, "height": 2.5,
	},
	{
		## Lying across the journal's near edge and the board, which is what
		## `rest` buys: it is above both, occludes both and shadows both, and none
		## of that is drawn -- it follows from one number.
		"key": "training", "label": "Training clipboard",
		"tip": "The clipboard", "foot": Rect2(0.215, 0.30, 0.215, 0.34),
		"tilt": 7.0, "rest": 2.5, "height": 4.0,
	},
	{
		"key": "settings", "label": "", "tip": "Settings",
		"foot": Rect2(0.815, 0.58, 0.075, 0.10),
		"tilt": -8.0, "rest": 0.0, "height": 9.0,
	},
	{
		"key": "housing", "label": "Housing folder",
		"tip": "The housing folder", "foot": Rect2(0.275, 0.52, 0.235, 0.32),
		"tilt": -4.0, "rest": 0.0, "height": 3.0,
	},
	{
		"key": "kitchen", "label": "Meal plan",
		"tip": "The meal plan", "foot": Rect2(0.500, 0.60, 0.190, 0.28),
		"tilt": 8.0, "rest": 0.0, "height": 3.5,
	},
	{
		"key": "mug", "label": "", "tip": "",
		"foot": Rect2(0.700, 0.28, 0.062, 0.075),
		"tilt": 0.0, "rest": 0.0, "height": 11.0,
	},
]

## Things that open nothing. A desk with only useful objects on it is a toolbar;
## what makes a room somebody's is the stuff that is just stuff.
const FURNITURE := ["lamp", "mug"]

## Things that are **not boxes**, and so do not get the shared body.
##
## Almost everything on a desk is a box from a chair, which is why one box does
## for the books, the folder, the pad and the machines. A lamp is not: it is a
## base, an arm and a shade with air between them, and extruding its footprint to
## its full height drew a black column standing off the top of the screen. A mug
## is not either -- it is a cylinder, and its box was a grey cube parked behind it.
##
## Their models draw the whole object instead.
const BODYLESS := ["lamp", "mug"]

## Behind and beside the desk. The trapezoid does not reach the corners of the
## screen -- that is what makes it a desk seen from a chair rather than a
## backdrop -- so the room has to be painted under everything or those corners
## show through to nothing.
const FLOOR_LIGHT := Color(0.29, 0.24, 0.21)
const FLOOR_DARK := Color(0.08, 0.07, 0.07)

## The same wood at two times of day rather than two woods -- a desk does not
## change material at night.
const WOOD_LIGHT := Color(0.47, 0.33, 0.22)
const WOOD_DARK := Color(0.16, 0.12, 0.09)

## The window is the one place a theme means something rather than being a
## preference: Molten is the afternoon and Mikasa is late, so the lamp being lit
## in one *follows from* the light in the other instead of being a second choice.
const SKY_DAY_TOP := Color(0.55, 0.73, 0.85)
const SKY_DAY_LOW := Color(0.88, 0.87, 0.78)
const SKY_NIGHT_TOP := Color(0.04, 0.06, 0.13)
const SKY_NIGHT_LOW := Color(0.10, 0.12, 0.22)
const WALL_LIGHT := Color(0.78, 0.72, 0.62)
const WALL_DARK := Color(0.13, 0.12, 0.14)
const LAMP_WARMTH := Color(1.0, 0.86, 0.60)
const LAMP_REACH: float = 300.0

var _career_manager: Node = null
var _game_manager: Node = null
var _surface: _Surface = null


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface = _Surface.new()
	_surface.name = "DeskSurface"
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.opened.connect(func(key: String) -> void: opened.emit(key))
	add_child(_surface)


func refresh() -> void:
	if _surface == null:
		return
	_surface.readings = _read_the_desk()
	_surface.queue_redraw()


## What each object says when you point at it.
##
## Derived, every line, and where a system does not exist the object gives its
## name and nothing more. A tooltip reading "3 new" when nothing generated three
## of anything is a gauge that lies, and the desk is the last place that should:
## it is the screen a manager trusts without reading.
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
		if "accommodation_structure" in team:
			out["housing"] = "The housing folder — %s" % str(team.accommodation_structure)
		out["kitchen"] = "The meal plan — %s" % str(team.food_block)
	return out


## The desk, its objects and the clicks on them.
##
## One `_draw` rather than a node per object, because these overlap and overlap in
## canvas drawing is call order -- eleven sibling `Control`s would need z-indices
## kept in step with a projection they know nothing about.
class _Surface extends Control:
	signal opened(what: String)

	var readings: Dictionary = {}
	var _hovered: String = ""

	func _ready() -> void:
		set_meta("ui_style_exempt", true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func _desk() -> Rect2:
		var top := size.y * WALL_SHARE
		return Rect2(Vector2(0.0, top), Vector2(size.x, size.y - top - LIP))

	func _to_screen(u: float, v: float, h: float) -> Vector2:
		var desk := _desk()
		var narrow := lerpf(FAR_NARROWING, 1.0, v)
		return Vector2(
			desk.position.x + desk.size.x * 0.5 + (u - 0.5) * desk.size.x * narrow,
			desk.position.y + v * desk.size.y - h * RISE
		)

	## The four corners of a footprint at a height, turned about its own centre.
	##
	## The turn happens in **desk space**, so a rotated object is rotated lying on
	## the desk rather than leaning on the screen. `v` is scaled against `u` before
	## the rotation and back after, or a footprint wider than it is deep comes out
	## sheared instead of turned.
	func _face(entry: Dictionary, h: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			out.append(_at(entry, corner.x, corner.y, h))
		return out

	## A point inside an object's footprint, in screen space.
	##
	## Every model below is built from this rather than from a screen rectangle,
	## which is what keeps a detail *on* the object when the object moves or turns.
	func _at(entry: Dictionary, s: float, t: float, h: float) -> Vector2:
		var foot: Rect2 = entry["foot"]
		var centre := foot.position + foot.size * 0.5
		var turn := deg_to_rad(float(entry["tilt"]))
		var aspect := maxf(foot.size.y, 0.001) / maxf(foot.size.x, 0.001)
		var local := Vector2((s - 0.5) * foot.size.x, (t - 0.5) * foot.size.y / aspect)
		var turned := local.rotated(turn)
		var at := centre + Vector2(turned.x, turned.y * aspect)
		return _to_screen(at.x, at.y, h)

	func _quad(
		entry: Dictionary, s0: float, t0: float, s1: float, t1: float, h: float
	) -> PackedVector2Array:
		return PackedVector2Array([
			_at(entry, s0, t0, h), _at(entry, s1, t0, h),
			_at(entry, s1, t1, h), _at(entry, s0, t1, h),
		])

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var under := _object_at((event as InputEventMouseMotion).position)
			if under == _hovered:
				return
			_hovered = under
			## The only place a name appears on this screen.
			tooltip_text = _tip_for(under)
			queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var hit := _object_at((event as InputEventMouseButton).position)
			if not hit.is_empty():
				opened.emit(hit)
			accept_event()

	func _tip_for(key: String) -> String:
		if key.is_empty():
			return ""
		for entry in OBJECTS:
			if str(entry["key"]) == key:
				return str(readings.get(key, entry["tip"]))
		return ""

	## Hit-tested against the top face, near to far, so the nearest thing under the
	## pointer wins. Furniture is skipped: a lamp that swallowed a click meant for
	## the journal beside it would be a hit box shaped like a joke.
	func _object_at(where: Vector2) -> String:
		var order := _by_depth()
		order.reverse()
		for entry in order:
			var key := str(entry["key"])
			if key in FURNITURE:
				continue
			var top := _face(entry, float(entry["rest"]) + float(entry["height"]))
			if Geometry2D.is_point_in_polygon(where, top):
				return key
		return ""

	## Far to near, on the near edge of the footprint, because that is what decides
	## which of two overlapping things is in front.
	func _by_depth() -> Array:
		var order := OBJECTS.duplicate()
		order.sort_custom(func(a, b) -> bool:
			var one: Rect2 = a["foot"]
			var two: Rect2 = b["foot"]
			return one.position.y + one.size.y < two.position.y + two.size.y
		)
		return order

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hovered = ""
			tooltip_text = ""
			queue_redraw()
		elif what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		if size.x < 300.0 or size.y < 200.0:
			return
		var light := UIPalette.control_is_light(self)
		_draw_room(light)
		for entry in _by_depth():
			_draw_thing(entry, light)

	# ------------------------------------------------------------------ the room

	func _draw_room(light: bool) -> void:
		var desk := _desk()
		draw_rect(Rect2(Vector2.ZERO, size), FLOOR_LIGHT if light else FLOOR_DARK, true)
		draw_rect(
			Rect2(Vector2.ZERO, Vector2(size.x, desk.position.y)),
			WALL_LIGHT if light else WALL_DARK, true
		)
		_draw_window(light, desk.position.y)

		## The desk top as the trapezoid it is, taken from the projection rather
		## than drawn as a rect -- so the surface and the things standing on it
		## cannot disagree about where the far edge went.
		var wood := WOOD_LIGHT if light else WOOD_DARK
		draw_colored_polygon(
			PackedVector2Array([
				_to_screen(0.0, 0.0, 0.0), _to_screen(1.0, 0.0, 0.0),
				_to_screen(1.0, 1.0, 0.0), _to_screen(0.0, 1.0, 0.0),
			]), wood
		)
		_draw_grain(wood)
		if not light:
			_draw_lamplight()
		var near_left := _to_screen(0.0, 1.0, 0.0)
		var near_right := _to_screen(1.0, 1.0, 0.0)
		draw_colored_polygon(
			PackedVector2Array([
				near_left, near_right,
				near_right + Vector2(0.0, LIP), near_left + Vector2(0.0, LIP),
			]), Color(wood.darkened(0.42), 1.0)
		)
		draw_colored_polygon(
			PackedVector2Array([
				_to_screen(0.0, 0.0, 0.0), _to_screen(1.0, 0.0, 0.0),
				_to_screen(1.0, 0.07, 0.0), _to_screen(0.0, 0.07, 0.0),
			]), Color(0.0, 0.0, 0.0, 0.22)
		)

	## Boards running across the desk and narrowing with it. Grain runs one way,
	## which is what stops a plank reading as stone -- and the boards follow the
	## projection, so the perspective is in the surface and not only in what stands
	## on it.
	func _draw_grain(wood: Color) -> void:
		for board in range(10):
			var v := float(board) / 9.0
			draw_line(
				_to_screen(0.0, v, 0.0), _to_screen(1.0, v, 0.0),
				Color(wood.darkened(0.22), 0.5), 1.6
			)
		for streak in range(34):
			var seed_value := ((streak + 5) * 2654435761) & 0x7FFFFFFF
			var v := float(seed_value % 1000) / 1000.0
			var u0 := float((seed_value / 1000) % 1000) / 1000.0
			draw_line(
				_to_screen(u0, v, 0.0), _to_screen(minf(u0 + 0.16, 1.0), v, 0.0),
				Color(wood.lightened(0.10), 0.26), 2.4
			)

	func _draw_window(light: bool, wall_bottom: float) -> void:
		var frame := Rect2(
			Vector2(size.x * 0.08, wall_bottom * 0.14),
			Vector2(size.x * 0.31, wall_bottom * 0.72)
		)
		var top_sky := SKY_DAY_TOP if light else SKY_NIGHT_TOP
		var low_sky := SKY_DAY_LOW if light else SKY_NIGHT_LOW
		for band in range(20):
			var t := float(band) / 20.0
			draw_rect(
				Rect2(
					frame.position + Vector2(0.0, frame.size.y * t),
					Vector2(frame.size.x, frame.size.y / 20.0 + 1.0)
				), top_sky.lerp(low_sky, t), true
			)
		if light:
			var roof := Color(0.42, 0.44, 0.44, 0.5)
			for index in range(5):
				var seed_value := ((index + 2) * 2654435761) & 0x7FFFFFFF
				var w := frame.size.x * (0.12 + float(seed_value % 100) / 900.0)
				var h := frame.size.y * (0.14 + float((seed_value / 100) % 100) / 460.0)
				draw_rect(
					Rect2(
						Vector2(
							frame.position.x + frame.size.x * (0.03 + 0.2 * float(index)),
							frame.position.y + frame.size.y - h
						), Vector2(w, h)
					), roof, true
				)
		else:
			for index in range(30):
				var seed_value := ((index + 3) * 2654435761) & 0x7FFFFFFF
				var at := frame.position + Vector2(
					float(seed_value % 1000) / 1000.0 * frame.size.x,
					float((seed_value / 1000) % 1000) / 1000.0 * frame.size.y
				)
				draw_rect(
					Rect2(at, Vector2(2.0, 2.0)),
					Color(1.0, 0.92, 0.70, 0.24 + float(seed_value % 60) / 150.0), true
				)
		var ink := Color(0.34, 0.31, 0.27) if light else Color(0.05, 0.05, 0.07)
		draw_rect(frame, ink, false, 5.0)
		draw_line(
			Vector2(frame.position.x + frame.size.x * 0.5, frame.position.y),
			Vector2(frame.position.x + frame.size.x * 0.5, frame.position.y + frame.size.y),
			ink, 3.0
		)
		draw_rect(
			Rect2(
				frame.position + Vector2(-7.0, frame.size.y),
				Vector2(frame.size.x + 14.0, 6.0)
			), ink, true
		)

	## The lamp's pool, painted on the wood *before* anything is put on it -- so the
	## light falls on the desk and every object keeps its own colour, which a wash
	## over the top would take away.
	func _draw_lamplight() -> void:
		var lamp := _lamp()
		var foot: Rect2 = lamp["foot"]
		var at := _to_screen(
			foot.position.x + foot.size.x * 0.5,
			foot.position.y + foot.size.y + 0.18, 0.0
		)
		for step in range(12):
			var t := float(step) / 12.0
			draw_circle(
				at, LAMP_REACH * (0.22 + t * 0.9),
				Color(LAMP_WARMTH, 0.085 * (1.0 - t) * (1.0 - t))
			)

	func _lamp() -> Dictionary:
		for entry in OBJECTS:
			if str(entry["key"]) == "lamp":
				return entry
		return OBJECTS[0]

	# --------------------------------------------------------------- the objects

	## One thing: its shadow, its box, and then whatever makes it itself.
	##
	## The box is shared because everything on a desk *is* roughly a box from here.
	## The detail is not, and that is where the model actually lives.
	func _draw_thing(entry: Dictionary, light: bool) -> void:
		var key := str(entry["key"])
		var hovered := key == _hovered
		var lift := 2.6 if hovered else 0.0
		var base := float(entry["rest"]) + lift
		var top_h := base + float(entry["height"])
		var floor_face := _face(entry, base)
		var top_face := _face(entry, top_h)

		_draw_shadow(entry)
		var stock := _stock_of(key, light)
		if key in BODYLESS:
			_draw_model(key, entry, top_h, light)
			if hovered:
				_glow(top_face, light)
			return
		var near_side := _wall(top_face, floor_face, 2, 3)
		## The near wall always, and the side turned toward the chair -- which
		## follows from where the object sits, and is what makes the room read as
		## having one viewpoint rather than eleven.
		var flank := _wall(top_face, floor_face, 1, 2) \
			if _centre_of(top_face).x < size.x * 0.5 \
			else _wall(top_face, floor_face, 3, 0)
		draw_colored_polygon(flank, Color(stock.darkened(0.42), 1.0))
		draw_colored_polygon(near_side, Color(stock.darkened(0.24), 1.0))
		draw_colored_polygon(top_face, stock)
		_draw_model(key, entry, top_h, light)

		if hovered:
			## The silhouette, not a tint: what lights up is the outline of the
			## modelled thing, so the feedback confirms you read the shape rather
			## than announcing that a rectangle was clickable.
			for face in [top_face, near_side, flank]:
				_glow(face, light)

	func _glow(face: PackedVector2Array, light: bool) -> void:
		draw_polyline(
			face + PackedVector2Array([face[0]]),
			UIPalette.color(&"accent", light), 2.2
		)

	static func _wall(
		top: PackedVector2Array, bottom: PackedVector2Array, a: int, b: int
	) -> PackedVector2Array:
		return PackedVector2Array([top[a], top[b], bottom[b], bottom[a]])

	static func _centre_of(face: PackedVector2Array) -> Vector2:
		var sum := Vector2.ZERO
		for point in face:
			sum += point
		return sum / float(face.size())

	## Contact shadow on the wood, lengthening with height, so a thing resting on
	## something else is visibly off the desk.
	func _draw_shadow(entry: Dictionary) -> void:
		var drop := _face(entry, 0.0)
		## A bodyless thing casts from its footprint, not from its full height --
		## a lamp is a base and some air, and a shadow scaled to the top of the
		## shade would be a slab lying across the desk.
		var height := float(entry["rest"]) + float(entry["height"])
		if str(entry["key"]) in BODYLESS:
			height = 6.0
		var offset := Vector2(height * 0.34, height * 0.58)
		for step in range(4):
			var spread := offset + Vector2(float(step), float(step)) * 1.4
			var moved := PackedVector2Array()
			for point in drop:
				moved.append(point + spread)
			draw_colored_polygon(moved, Color(0.0, 0.0, 0.0, 0.13 / float(step + 1)))

	## What each thing is made of, matched to the screen it opens so that picking a
	## thing up and opening it is continuous.
	func _stock_of(key: String, light: bool) -> Color:
		match key:
			"journal":
				return Color("9a5741") if light else Color("47281e")
			"training", "scouting":
				return Color("a87a4c") if light else Color("4d3728")
			"housing":
				return Color("d9bd83") if light else Color("4b3d26")
			"kitchen":
				return Color("e6e0cd") if light else Color("55524a")
			"encyclopedia":
				return Color("6c4a66") if light else Color("382a35")
			"phone", "machine":
				return Color("32363c") if light else Color("22262b")
			"settings":
				return Color("6d7365") if light else Color("3a3f38")
			"lamp":
				return Color("46505b") if light else Color("2b323a")
			"mug":
				return Color("c6d3d0") if light else Color("6d7c7a")
			_:
				return UIPalette.color(&"surface", light)

	## ## The models
	##
	## Everything above is a box. Everything below is what makes each box the thing
	## it is, and it is the point of the screen.
	func _draw_model(key: String, entry: Dictionary, top_h: float, light: bool) -> void:
		match key:
			"journal":
				_model_book(entry, top_h, light, true)
			"encyclopedia":
				_model_book(entry, top_h, light, false)
			"training":
				_model_clipboard(entry, top_h, light)
			"scouting":
				_model_board(entry, top_h, light)
			"housing":
				_model_folder(entry, top_h, light)
			"kitchen":
				_model_pad(entry, top_h, light)
			"phone":
				_model_phone(entry, top_h, light)
			"machine":
				_model_machine(entry, top_h, light)
			"settings":
				_model_sharpener(entry, top_h, light)
			"lamp":
				_model_lamp(entry, top_h, light)
			"mug":
				_model_mug(entry, top_h, light)

	## A shut book: cloth boards, a page block showing on the near side, and the
	## spine wrapping round the left.
	func _model_book(
		entry: Dictionary, top_h: float, light: bool, worn: bool
	) -> void:
		var cloth := _stock_of(str(entry["key"]), light)
		var pages := Color(0.93, 0.90, 0.80) if light else Color(0.70, 0.67, 0.60)
		## The block is *inside* the covers, so it shows as a band on the near face
		## between two heights -- which is what reads as a stack rather than as a
		## stripe painted on the side.
		var block_top := top_h - 0.9
		var block_low := float(entry["rest"]) + 0.9
		var high := _quad(entry, 0.08, 1.0, 1.0, 1.0, block_top)
		var low := _quad(entry, 0.08, 1.0, 1.0, 1.0, block_low)
		draw_colored_polygon(
			PackedVector2Array([high[0], high[1], low[1], low[0]]), pages
		)
		var leaf := Color(pages.darkened(0.26), 0.55)
		for line in range(4):
			var h := lerpf(block_low, block_top, float(line) / 3.0)
			draw_line(_at(entry, 0.08, 1.0, h), _at(entry, 1.0, 1.0, h), leaf, 1.0)
		draw_colored_polygon(
			_quad(entry, 0.0, 0.0, 0.11, 1.0, top_h), Color(cloth.darkened(0.18), 1.0)
		)
		if worn:
			for band in [0.32, 0.70]:
				draw_line(
					_at(entry, 0.0, band, top_h), _at(entry, 0.11, band, top_h),
					Color(cloth.darkened(0.36), 0.8), 2.0
				)
		## A blank plate on the cover. Blank because the desk carries no lettering:
		## what it says is in the tooltip.
		draw_colored_polygon(
			_quad(entry, 0.30, 0.26, 0.82, 0.64, top_h),
			Color(cloth.lightened(0.18), 0.5)
		)

	func _model_clipboard(entry: Dictionary, top_h: float, light: bool) -> void:
		var sheet := Color(0.97, 0.95, 0.88) if light else Color(0.74, 0.73, 0.68)
		draw_colored_polygon(_quad(entry, 0.07, 0.13, 0.93, 0.95, top_h + 0.3), sheet)
		var steel := Color(0.74, 0.76, 0.78) if light else Color(0.50, 0.53, 0.56)
		draw_colored_polygon(_quad(entry, 0.32, 0.01, 0.68, 0.12, top_h + 1.1), steel)
		draw_colored_polygon(
			_quad(entry, 0.34, 0.10, 0.66, 0.15, top_h + 0.7),
			Color(steel.darkened(0.35), 1.0)
		)
		for line in range(5):
			var t := lerpf(0.32, 0.86, float(line) / 4.0)
			draw_line(
				_at(entry, 0.16, t, top_h + 0.3), _at(entry, 0.84, t, top_h + 0.3),
				Color(0.45, 0.50, 0.55, 0.28), 1.0
			)

	## Cork with scraps pinned to it: the board on the desk shows what the board
	## screen is, which is things at angles with a pin each.
	func _model_board(entry: Dictionary, top_h: float, light: bool) -> void:
		var cork := _stock_of("scouting", light)
		for speck in range(80):
			var seed_value := ((speck + 11) * 2654435761) & 0x7FFFFFFF
			draw_circle(
				_at(
					entry, float(seed_value % 1000) / 1000.0,
					float((seed_value / 1000) % 1000) / 1000.0, top_h
				), 1.3, Color(cork.darkened(0.34), 0.42)
			)
		var paper := Color(0.96, 0.94, 0.88) if light else Color(0.72, 0.71, 0.67)
		var slips := [
			[0.09, 0.08, 0.36, 0.32], [0.45, 0.06, 0.74, 0.28],
			[0.13, 0.44, 0.41, 0.68], [0.52, 0.42, 0.85, 0.66],
			[0.27, 0.76, 0.60, 0.96],
		]
		const PINS := [
			Color("c8443a"), Color("d9982f"), Color("3f7d52"),
			Color("35618f"), Color("8a4a86"),
		]
		for index in range(slips.size()):
			var slip: Array = slips[index]
			draw_colored_polygon(
				_quad(entry, slip[0], slip[1], slip[2], slip[3], top_h + 0.2), paper
			)
			draw_circle(
				_at(entry, (slip[0] + slip[2]) * 0.5, slip[1] + 0.04, top_h + 0.6),
				2.5, PINS[index % PINS.size()]
			)

	## Manila with paper poking out of it, which is what a folder in use looks like
	## and a shut one does not.
	func _model_folder(entry: Dictionary, top_h: float, light: bool) -> void:
		var paper := Color(0.97, 0.95, 0.89) if light else Color(0.73, 0.72, 0.67)
		for sheet in [[0.07, -0.05, 0.86, 0.30], [0.17, -0.02, 0.99, 0.22]]:
			draw_colored_polygon(
				_quad(entry, sheet[0], sheet[1], sheet[2], sheet[3], top_h - 0.5), paper
			)
		var manila := _stock_of("housing", light)
		draw_colored_polygon(
			_quad(entry, 0.52, -0.08, 0.87, 0.03, top_h),
			Color(manila.darkened(0.05), 1.0)
		)
		## The fold, as a crease rather than a line: a valley and a lit shoulder,
		## which is `UICreasedEdge`'s claim at desk scale.
		draw_line(
			_at(entry, 0.04, 0.03, top_h), _at(entry, 0.04, 0.98, top_h),
			Color(manila.darkened(0.32), 0.85), 2.0
		)
		draw_line(
			_at(entry, 0.065, 0.03, top_h), _at(entry, 0.065, 0.98, top_h),
			Color(manila.lightened(0.24), 0.55), 1.4
		)

	func _model_pad(entry: Dictionary, top_h: float, light: bool) -> void:
		var sheet := Color(0.98, 0.97, 0.92) if light else Color(0.76, 0.75, 0.70)
		draw_colored_polygon(_quad(entry, 0.03, 0.11, 0.97, 0.99, top_h + 0.2), sheet)
		draw_colored_polygon(
			_quad(entry, 0.03, 0.01, 0.97, 0.11, top_h + 0.2),
			Color(0.84, 0.78, 0.62) if light else Color(0.58, 0.54, 0.44)
		)
		## The curl: the near-right corner lifted off the block, which is the one
		## mark that says these are separate sheets.
		draw_colored_polygon(
			PackedVector2Array([
				_at(entry, 0.76, 0.99, top_h + 0.2),
				_at(entry, 0.97, 0.99, top_h + 0.2),
				_at(entry, 0.97, 0.78, top_h + 1.8),
			]), Color(sheet.darkened(0.12), 1.0)
		)
		for line in range(4):
			var t := lerpf(0.28, 0.82, float(line) / 3.0)
			draw_line(
				_at(entry, 0.10, t, top_h + 0.2), _at(entry, 0.90, t, top_h + 0.2),
				Color(0.45, 0.50, 0.55, 0.20), 1.0
			)

	## A telephone: a dial face on the sloping front, the handset lying across the
	## back a little proud of it, and a cord going off the desk.
	func _model_phone(entry: Dictionary, top_h: float, light: bool) -> void:
		var body := _stock_of("phone", light)
		var dark := Color(body.darkened(0.38), 1.0)
		draw_colored_polygon(
			_quad(entry, 0.10, 0.52, 0.90, 0.94, top_h + 0.2),
			Color(body.lightened(0.12), 1.0)
		)
		for row in range(3):
			for column in range(3):
				draw_circle(
					_at(
						entry, 0.24 + 0.26 * float(column),
						0.60 + 0.12 * float(row), top_h + 0.4
					), 2.0, Color(0.80, 0.80, 0.82, 0.72)
				)
		var rest_h := top_h + 3.6
		draw_colored_polygon(_quad(entry, 0.12, 0.12, 0.88, 0.40, rest_h), dark)
		for cup in [[0.02, 0.02, 0.32, 0.50], [0.68, 0.02, 0.98, 0.50]]:
			draw_colored_polygon(
				_quad(entry, cup[0], cup[1], cup[2], cup[3], rest_h + 1.4), dark
			)
		for loop in range(7):
			var t := float(loop) / 6.0
			draw_circle(
				_at(entry, -0.05 - t * 0.12, 0.60 + t * 0.40, 1.2 + sin(t * PI) * 1.8),
				2.2, Color(dark, 0.8)
			)

	func _model_machine(entry: Dictionary, top_h: float, light: bool) -> void:
		var body := _stock_of("machine", light)
		draw_colored_polygon(
			_quad(entry, 0.08, 0.18, 0.62, 0.86, top_h + 0.2),
			Color(body.lightened(0.07), 1.0)
		)
		for line in range(5):
			var t := lerpf(0.26, 0.78, float(line) / 4.0)
			draw_line(
				_at(entry, 0.12, t, top_h + 0.4), _at(entry, 0.58, t, top_h + 0.4),
				Color(0.0, 0.0, 0.0, 0.32), 1.6
			)
		for button in [0.32, 0.60]:
			draw_circle(
				_at(entry, 0.78, button, top_h + 0.4), 3.0,
				Color(body.lightened(0.26), 1.0)
			)
		## Steady and dead when there is nothing. A desk that flashes before there
		## are any messages is animating a lie.
		draw_circle(_at(entry, 0.78, 0.84, top_h + 0.4), 2.6, Color(0.30, 0.27, 0.26))

	## A rotary sharpener. The crank wheel stands on the side of the body, so it is
	## seen nearly edge-on from a chair -- which is exactly when a toothed disc most
	## reads as a gear, and the camouflage has to work both ways: it must say
	## "settings" at a glance and still be a real object, or the desk acquires an
	## icon from a different design language.
	func _model_sharpener(entry: Dictionary, top_h: float, light: bool) -> void:
		var steel := Color(0.62, 0.63, 0.64) if light else Color(0.42, 0.44, 0.46)
		var centre := _at(entry, 0.92, 0.50, top_h * 0.58)
		var radius := 9.0
		for tooth in range(9):
			var angle := TAU * float(tooth) / 9.0
			draw_circle(centre + Vector2(cos(angle), sin(angle)) * radius, 2.6, steel)
		draw_circle(centre, radius * 0.82, steel)
		draw_circle(centre, radius * 0.24, Color(steel.darkened(0.45), 1.0))
		draw_circle(_at(entry, 0.32, 1.0, top_h * 0.62), 3.4, Color(0.10, 0.10, 0.11))

	## An anglepoise: base, elbow, arm, shade, bulb.
	func _model_lamp(entry: Dictionary, top_h: float, light: bool) -> void:
		var metal := _stock_of("lamp", light)
		var base := _at(entry, 0.5, 0.8, 0.0)
		var elbow := _at(entry, 0.5, 0.7, top_h * 0.62)
		var head := _at(entry, 0.5, 0.25, top_h)
		draw_line(base, elbow, Color(metal.darkened(0.12), 1.0), 5.0)
		draw_line(elbow, head, Color(metal.darkened(0.12), 1.0), 5.0)
		draw_circle(elbow, 4.2, Color(metal.lightened(0.16), 1.0))
		var mouth_left := head + Vector2(-21.0, 27.0)
		var mouth_right := head + Vector2(21.0, 27.0)
		draw_colored_polygon(
			PackedVector2Array([
				head + Vector2(-7.0, -5.0), head + Vector2(7.0, -5.0),
				mouth_right, mouth_left,
			]), metal
		)
		draw_line(mouth_left, mouth_right, Color(metal.darkened(0.32), 1.0), 2.0)
		var bulb := (mouth_left + mouth_right) * 0.5
		draw_circle(bulb, 6.0, Color(0.32, 0.34, 0.36) if light else LAMP_WARMTH)
		if not light:
			for step in range(4):
				draw_circle(
					bulb, 8.0 + float(step) * 7.0,
					Color(LAMP_WARMTH, 0.11 / float(step + 1))
				)

	## A mug, because a desk without one is a photograph of a desk.
	func _model_mug(entry: Dictionary, top_h: float, light: bool) -> void:
		var china := _stock_of("mug", light)
		var rim := _at(entry, 0.5, 0.5, top_h)
		draw_arc(
			rim + Vector2(11.0, 5.0), 7.0, -PI * 0.5, PI * 0.5, 12,
			Color(china.darkened(0.20), 1.0), 3.4
		)
		draw_circle(rim, 12.0, china)
		draw_circle(rim, 9.4, Color(0.30, 0.18, 0.11))
		draw_circle(rim + Vector2(2.0, -1.0), 4.0, Color(0.44, 0.28, 0.18, 0.65))
