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

## ## Everything is in centimetres, and there is one angle
##
## The first pass had three scales that never met. The desk was in shares of
## itself, heights were in "units of about a centimetre" against a hand-picked
## pixel rise, and the wall, the window, the lamp and the mug were drawn in raw
## screen pixels with no projection at all -- so the window did not recede, the
## lamp leaned the wrong way, and nothing in the room could be compared to
## anything else. That is why the scale would not read: there was no scale.
##
## So there is one now. The desk is a real size, the room is a real distance
## behind it, every object's footprint and height are in centimetres, and the
## viewing angle is a single number that everything else is derived from:
##
##     px per cm of depth  = desk depth on screen / DESK_DEPTH_CM
##     px per cm of height = px per cm of depth / tan(elevation)
##
## Stating the angle rather than the rise is what makes it checkable. The old
## constants worked out to an elevation of about **64 degrees** while the header
## claimed twenty-five -- nearly overhead, described as if from a chair, and no
## number in the file disagreed with any other because none of them were in the
## same units.
const DESK_WIDTH_CM: float = 140.0
const DESK_DEPTH_CM: float = 70.0
## How far behind the desk the wall is, and how high the window sits on it.
## **The desk is against the wall, and the window is cropped.**
##
## Both follow from the angle rather than being chosen. Once the elevation is
## honest, a centimetre of *height* is worth more screen than a centimetre of
## depth -- so a wall sixty centimetres behind the desk with a window at
## windowsill height projects several hundred pixels above the top of the frame,
## and the first pass at real units simply lost both off the top.
##
## The answer is not to fake the projection back down. It is that this is a shot
## of somebody's desk pushed against a wall: eight centimetres of gap, a low sill,
## and a window whose head runs off the top of the frame the way it does in any
## photograph taken from a chair. What you can see is the bottom of the window,
## which is all you ever see of a window you are sitting under.
const WALL_BEHIND_CM: float = 8.0
const WINDOW_SILL_CM: float = 13.0
const WINDOW_HEIGHT_CM: float = 54.0
const WINDOW_WIDTH_CM: float = 58.0
const WINDOW_LEFT_CM: float = 5.0

## Where the eye is, above the surface. Fifty-two degrees is somebody at a desk
## with their chair pulled in: low enough that a book shows its own front cover
## and a mug is a cylinder, high enough that the surface is still a surface and
## the things on it can be told apart.
const ELEVATION_DEGREES: float = 52.0
## How far the far edge narrows. The only perspective in the projection, and the
## one that matters -- a desk from a chair is a trapezoid and a rectangle reads as
## a wall.
const FAR_NARROWING: float = 0.80
## How much of the frame is above the desk's far edge. Larger than it was,
## because the room needs somewhere to be: at 0.20 the wall was a strip and the
## window had to be painted flat on it to fit at all.
const WALL_SHARE: float = 0.32
const LIP: float = 12.0

## ## What is on the desk
##
## `foot` is the footprint in desk space -- `x`/`y` are the far-left corner's
## `u`/`v`, `w`/`h` its extent across and back-to-front. `rest` is what it is lying
## on and `height` is how thick it is, both in `RISE`'s units.
## ## What is on the desk
##
## `foot` is the footprint **in centimetres** on a 140x70 desk: `x`/`y` are the
## far-left corner, `w`/`h` the extent across and back-to-front. `rest` and
## `height` are centimetres too. Because the footprint is in real units, a mug
## beside a journal comes out the right size without anybody choosing how big a
## mug should look.
const OBJECTS := [
	{
		"key": "encyclopedia", "label": "Encyclopedia", "tip": "The encyclopedia",
		"foot": Rect2(7.0, 3.0, 21.0, 27.0), "tilt": -5.0,
		"rest": 0.0, "height": 6.5,
	},
	{
		"key": "lamp", "label": "", "tip": "",
		## Shorter and to the right of the window, because a lamp at forty
		## centimetres crosses the whole frame at this angle -- which is true of a
		## real lamp and makes for a worse photograph.
		"foot": Rect2(96.0, 2.0, 13.0, 13.0), "tilt": 0.0,
		"rest": 0.0, "height": 30.0,
	},
	{
		"key": "phone", "label": "Telephone", "tip": "The telephone",
		"foot": Rect2(111.0, 6.0, 22.0, 16.0), "tilt": -4.0,
		"rest": 0.0, "height": 7.0,
	},
	{
		"key": "journal", "label": "The journal", "tip": "The journal",
		"foot": Rect2(60.0, 15.0, 38.0, 25.0), "tilt": -2.0,
		"rest": 0.0, "height": 4.5,
	},
	{
		"key": "machine", "label": "Answering machine", "tip": "The answering machine",
		"foot": Rect2(110.0, 27.0, 24.0, 13.0), "tilt": 3.0,
		"rest": 0.0, "height": 5.0,
	},
	{
		"key": "scouting", "label": "Scouting board", "tip": "The scouting board",
		"foot": Rect2(3.0, 25.0, 35.0, 31.0), "tilt": 2.0,
		"rest": 0.0, "height": 1.4,
	},
	{
		## Lying across the journal's near edge and the board, which is what
		## `rest` buys: it is above both, occludes both and shadows both, and none
		## of that is drawn -- it follows from one number.
		"key": "training", "label": "Training clipboard", "tip": "The clipboard",
		"foot": Rect2(28.0, 21.0, 31.0, 27.0), "tilt": 7.0,
		"rest": 1.4, "height": 2.4,
	},
	{
		"key": "settings", "label": "", "tip": "Settings",
		"foot": Rect2(115.0, 45.0, 12.0, 10.0), "tilt": -8.0,
		"rest": 0.0, "height": 7.5,
	},
	{
		"key": "housing", "label": "Housing folder", "tip": "The housing folder",
		"foot": Rect2(37.0, 39.0, 34.0, 25.0), "tilt": -4.0,
		"rest": 0.0, "height": 1.8,
	},
	{
		"key": "kitchen", "label": "Meal plan", "tip": "The meal plan",
		"foot": Rect2(69.0, 45.0, 28.0, 22.0), "tilt": 8.0,
		"rest": 0.0, "height": 2.2,
	},
	{
		"key": "mug", "label": "", "tip": "",
		"foot": Rect2(99.0, 19.0, 9.0, 9.0), "tilt": 0.0,
		"rest": 0.0, "height": 9.5,
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

	## Pixels per centimetre of height, derived from the elevation rather than
	## chosen. The one place the angle turns into a number, so there is nothing to
	## keep in step with it.
	func _rise() -> float:
		var desk := _desk()
		return (desk.size.y / DESK_DEPTH_CM) / tan(deg_to_rad(ELEVATION_DEGREES))

	## Centimetres on the desk to pixels on the screen.
	##
	## `v` is allowed to go **negative**, and that is what puts the room behind the
	## desk in the same projection as the desk: the wall is simply at a large
	## negative depth, so the narrowing extrapolates and the window is narrower
	## than the desk's far edge -- which is what it looks like, and is why the
	## window drawn in flat screen pixels never sat in the room.
	func _to_screen(u_cm: float, v_cm: float, h_cm: float) -> Vector2:
		var desk := _desk()
		var v := v_cm / DESK_DEPTH_CM
		var narrow := lerpf(FAR_NARROWING, 1.0, v)
		return Vector2(
			desk.position.x + desk.size.x * 0.5
				+ (u_cm / DESK_WIDTH_CM - 0.5) * desk.size.x * narrow,
			desk.position.y + v * desk.size.y - h_cm * _rise()
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
	##
	## The rotation is a plain `rotated` now: centimetre space is square, so a
	## turn is a turn. It used to need an aspect correction applied and undone,
	## because the footprint was in shares of a desk that is twice as wide as it is
	## deep -- a unit across and a unit back were different lengths, and rotating in
	## that space shears rather than turns.
	func _at(entry: Dictionary, s: float, t: float, h: float) -> Vector2:
		var foot: Rect2 = entry["foot"]
		var centre := foot.position + foot.size * 0.5
		var local := Vector2((s - 0.5) * foot.size.x, (t - 0.5) * foot.size.y)
		var at := centre + local.rotated(deg_to_rad(float(entry["tilt"])))
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
		_draw_window(light)

		## The desk top as the trapezoid it is, taken from the projection rather
		## than drawn as a rect -- so the surface and the things standing on it
		## cannot disagree about where the far edge went.
		var wood := WOOD_LIGHT if light else WOOD_DARK
		draw_colored_polygon(PackedVector2Array(_desk_corners()), wood)
		_draw_grain(wood)
		if not light:
			_draw_lamplight()
		var near_left := _to_screen(0.0, DESK_DEPTH_CM, 0.0)
		var near_right := _to_screen(DESK_WIDTH_CM, DESK_DEPTH_CM, 0.0)
		draw_colored_polygon(
			PackedVector2Array([
				near_left, near_right,
				near_right + Vector2(0.0, LIP), near_left + Vector2(0.0, LIP),
			]), Color(wood.darkened(0.42), 1.0)
		)
		draw_colored_polygon(
			PackedVector2Array([
				_to_screen(0.0, 0.0, 0.0), _to_screen(DESK_WIDTH_CM, 0.0, 0.0),
				_to_screen(DESK_WIDTH_CM, 5.0, 0.0), _to_screen(0.0, 5.0, 0.0),
			]), Color(0.0, 0.0, 0.0, 0.22)
		)

	func _desk_corners() -> Array:
		return [
			_to_screen(0.0, 0.0, 0.0), _to_screen(DESK_WIDTH_CM, 0.0, 0.0),
			_to_screen(DESK_WIDTH_CM, DESK_DEPTH_CM, 0.0),
			_to_screen(0.0, DESK_DEPTH_CM, 0.0),
		]

	## Boards running across the desk and narrowing with it. Grain runs one way,
	## which is what stops a plank reading as stone -- and the boards follow the
	## projection, so the perspective is in the surface and not only in what stands
	## on it.
	func _draw_grain(wood: Color) -> void:
		## Boards a hand's width across, which is what a desk is made of -- and in
		## centimetres, so the count follows from the size rather than the size
		## being chosen to suit a count.
		var board_cm := 11.0
		var v := board_cm
		while v < DESK_DEPTH_CM:
			draw_line(
				_to_screen(0.0, v, 0.0), _to_screen(DESK_WIDTH_CM, v, 0.0),
				Color(wood.darkened(0.24), 0.5), 1.6
			)
			v += board_cm
		for streak in range(36):
			var seed_value := ((streak + 5) * 2654435761) & 0x7FFFFFFF
			var at_v := float(seed_value % 1000) / 1000.0 * DESK_DEPTH_CM
			var at_u := float((seed_value / 1000) % 1000) / 1000.0 * DESK_WIDTH_CM
			draw_line(
				_to_screen(at_u, at_v, 0.0),
				_to_screen(minf(at_u + 22.0, DESK_WIDTH_CM), at_v, 0.0),
				Color(wood.lightened(0.10), 0.24), 2.4
			)

	## The window, **on the wall plane and in the same projection as everything
	## else**.
	##
	## It was drawn as a screen rectangle on a screen rectangle, which is why it
	## would not sit in the room: the desk receded and the wall did not, so there
	## was no distance between them for the eye to read. Put at a negative depth it
	## narrows past the desk's far edge by the same rule the desk narrows by, and
	## the scale question answers itself -- the window is that far away because it
	## is that far away.
	func _wall_point(u_cm: float, h_cm: float) -> Vector2:
		return _to_screen(u_cm, -WALL_BEHIND_CM, h_cm)

	func _draw_window(light: bool) -> void:
		var left := WINDOW_LEFT_CM
		var right := WINDOW_LEFT_CM + WINDOW_WIDTH_CM
		var sill := WINDOW_SILL_CM
		var head := WINDOW_SILL_CM + WINDOW_HEIGHT_CM
		var top_sky := SKY_DAY_TOP if light else SKY_NIGHT_TOP
		var low_sky := SKY_DAY_LOW if light else SKY_NIGHT_LOW
		for band in range(20):
			var t := float(band) / 20.0
			var upper := lerpf(head, sill, t)
			var lower := lerpf(head, sill, t + 1.0 / 20.0)
			draw_colored_polygon(
				PackedVector2Array([
					_wall_point(left, upper), _wall_point(right, upper),
					_wall_point(right, lower), _wall_point(left, lower),
				]), top_sky.lerp(low_sky, t)
			)
		if light:
			## Rooftops along the bottom of the glass, in centimetres of apparent
			## height, so they sit on the sill rather than at a pixel offset from it.
			var roof := Color(0.42, 0.44, 0.44, 0.5)
			for index in range(5):
				var seed_value := ((index + 2) * 2654435761) & 0x7FFFFFFF
				var w := WINDOW_WIDTH_CM * (0.11 + float(seed_value % 100) / 900.0)
				var tall := WINDOW_HEIGHT_CM * (0.12 + float((seed_value / 100) % 100) / 460.0)
				var at := left + WINDOW_WIDTH_CM * (0.02 + 0.2 * float(index))
				draw_colored_polygon(
					PackedVector2Array([
						_wall_point(at, sill + tall), _wall_point(at + w, sill + tall),
						_wall_point(at + w, sill), _wall_point(at, sill),
					]), roof
				)
		else:
			for index in range(30):
				var seed_value := ((index + 3) * 2654435761) & 0x7FFFFFFF
				var at := _wall_point(
					left + float(seed_value % 1000) / 1000.0 * WINDOW_WIDTH_CM,
					sill + float((seed_value / 1000) % 1000) / 1000.0 * WINDOW_HEIGHT_CM
				)
				draw_rect(
					Rect2(at, Vector2(2.0, 2.0)),
					Color(1.0, 0.92, 0.70, 0.24 + float(seed_value % 60) / 150.0), true
				)
		var ink := Color(0.34, 0.31, 0.27) if light else Color(0.05, 0.05, 0.07)
		var frame := PackedVector2Array([
			_wall_point(left, head), _wall_point(right, head),
			_wall_point(right, sill), _wall_point(left, sill),
		])
		draw_polyline(frame + PackedVector2Array([frame[0]]), ink, 5.0)
		var middle := left + WINDOW_WIDTH_CM * 0.5
		draw_line(_wall_point(middle, head), _wall_point(middle, sill), ink, 3.0)
		## The sill, which projects a little into the room -- so it is the one part
		## of the window with depth, and the thing that says the wall is a wall
		## rather than a picture of one.
		draw_colored_polygon(
			PackedVector2Array([
				_wall_point(left - 4.0, sill), _wall_point(right + 4.0, sill),
				_to_screen(right + 4.0, -WALL_BEHIND_CM + 7.0, sill - 1.0),
				_to_screen(left - 4.0, -WALL_BEHIND_CM + 7.0, sill - 1.0),
			]), Color(ink.lightened(0.18), 1.0)
		)

	## The lamp's pool, painted on the wood *before* anything is put on it -- so the
	## light falls on the desk and every object keeps its own colour, which a wash
	## over the top would take away.
	func _draw_lamplight() -> void:
		var lamp := _lamp()
		var foot: Rect2 = lamp["foot"]
		var at := _to_screen(
			foot.position.x + foot.size.x * 0.5,
			foot.position.y + foot.size.y + 13.0, 0.0
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

	## The silhouette of a solid of revolution, from two rings.
	##
	## Both round things here -- the mug and the lampshade -- were built by hand
	## from "the front half" of one ring and "the back half" of another, and both
	## got it wrong: `_disc` starts at the *right* of the circle and runs through
	## the front, so the half a naive split takes is the back one. The mug came out
	## with its wall behind its rim, which reads exactly as a cup tilted away on a
	## slope, and the shade came out inside out.
	##
	## A convex hull of both rings cannot get it wrong. The outline of a cylinder or
	## a cone *is* the hull of its two ends, whatever the projection does to them,
	## and there is no half to pick.
	func _hull(lower: Array, upper: Array) -> PackedVector2Array:
		var all := PackedVector2Array()
		for point in lower:
			all.append(point)
		for point in upper:
			all.append(point)
		return Geometry2D.convex_hull(all)

	## A circle on the desk at a height, as the projection makes it. Index 0 is the
	## right of the circle, a quarter of the way round is the front.
	func _disc(u_cm: float, v_cm: float, h_cm: float, radius_cm: float) -> Array:
		var points: Array = []
		for step in range(24):
			var angle := TAU * float(step) / 24.0
			points.append(_to_screen(
				u_cm + cos(angle) * radius_cm, v_cm + sin(angle) * radius_cm, h_cm
			))
		return points

	## An anglepoise: a weighted base, an upright, an arm reaching out over the
	## desk, and a shade on the end of it.
	##
	## Drawn in that order, which is the fix as much as the geometry is. The shade
	## used to be a flat wedge with the mouth painted over it *and* the arm drawn
	## first and then covered -- so the lamp read as a dark disc lying on the table
	## with its leg collapsed, which is a thing cheap lamps do and not what this is.
	func _model_lamp(entry: Dictionary, top_h: float, light: bool) -> void:
		var metal := _stock_of("lamp", light)
		var foot: Rect2 = entry["foot"]
		var mid_u := foot.position.x + foot.size.x * 0.5
		var back_v := foot.position.y + foot.size.y * 0.5
		## The base, and the small step up off it.
		draw_colored_polygon(
			PackedVector2Array(_disc(mid_u, back_v, 0.4, 6.5)),
			Color(metal.darkened(0.30), 1.0)
		)
		draw_colored_polygon(
			PackedVector2Array(_disc(mid_u, back_v, 1.6, 4.2)),
			Color(metal.darkened(0.12), 1.0)
		)
		## The upright, straight and clearly vertical, then the arm angling forward
		## over the desk. Two members with a joint, which is what an anglepoise is
		## and what a single line from base to shade cannot be.
		var elbow_h := top_h * 0.72
		var post_foot := _to_screen(mid_u, back_v, 1.6)
		var elbow := _to_screen(mid_u, back_v, elbow_h)
		## Reaching far enough forward that the shade is not sitting on top of its
		## own post. It was fifteen centimetres against a shade ten across, so the
		## upright vanished inside it and only its tip showed -- which is what read
		## as a collapsed leg.
		var reach_v := back_v + 21.0
		var head_h := top_h - 2.0
		var head := _to_screen(mid_u, reach_v, head_h)
		draw_line(post_foot, elbow, Color(metal.lightened(0.06), 1.0), 6.5)
		draw_line(elbow, head, Color(metal.lightened(0.06), 1.0), 6.0)
		draw_circle(elbow, 4.4, Color(metal.lightened(0.22), 1.0))
		draw_circle(head, 3.4, Color(metal.lightened(0.14), 1.0))
		## The shade: a cone hanging under the head, drawn as the hull of its two
		## rings so the silhouette is whatever the projection says it is.
		var mouth_h := head_h - 10.0
		var cap := _disc(mid_u, reach_v, head_h, 3.4)
		var mouth := _disc(mid_u, reach_v, mouth_h, 8.5)
		## **You are above it, so you see the outside of the shade.**
		##
		## The mouth faces the desk. Filling it bright painted the lit *interior*
		## over the whole cone, which is the view from underneath -- so the lamp
		## came out as a glowing blob with a stalk. What a lit lamp looks like from
		## a chair is a dark shade with light escaping under its rim and a pool on
		## the wood, and the pool is already painted.
		draw_colored_polygon(_hull(mouth, cap), metal)
		draw_colored_polygon(PackedVector2Array(cap), Color(metal.lightened(0.12), 1.0))
		if not light:
			## The rim, lit from inside. Only the front of it: the back of the rim
			## is on the far side of the shade and is not visible from here, and
			## lighting the whole ring is how the mouth ends up looking like a
			## floating disc again.
			for index in range(mouth.size() / 4, mouth.size() * 3 / 4):
				draw_line(
					mouth[index], mouth[(index + 1) % mouth.size()],
					Color(1.0, 0.95, 0.80, 0.9), 3.0
				)
			## And the spill just under the rim, which is the light leaving the
			## shade rather than the shade glowing.
			var under := _to_screen(mid_u, reach_v + 3.0, mouth_h - 2.0)
			for step in range(4):
				draw_circle(
					under, 10.0 + float(step) * 9.0,
					Color(LAMP_WARMTH, 0.09 / float(step + 1))
				)

	## A mug: a cylinder with a handle, which is what it is.
	##
	## It was a flat ring of fixed pixel radius seen from directly above, on a desk
	## seen from a chair -- the one object in the room drawn from a different
	## viewpoint -- and then a cylinder whose wall was on the wrong side of it.
	func _model_mug(entry: Dictionary, top_h: float, light: bool) -> void:
		var china := _stock_of("mug", light)
		var foot: Rect2 = entry["foot"]
		var mid_u := foot.position.x + foot.size.x * 0.5
		var mid_v := foot.position.y + foot.size.y * 0.5
		var radius := foot.size.x * 0.5
		## The handle first, so the body draws over where it joins.
		var handle := _to_screen(mid_u + radius, mid_v, top_h * 0.55)
		draw_arc(
			handle, 8.0, -PI * 0.55, PI * 0.55, 14, Color(china.darkened(0.26), 1.0), 3.8
		)
		var rim := _disc(mid_u, mid_v, top_h, radius)
		var base := _disc(mid_u, mid_v, 0.0, radius)
		draw_colored_polygon(_hull(base, rim), Color(china.darkened(0.16), 1.0))
		draw_colored_polygon(PackedVector2Array(rim), china)
		## What is in it, and the last of it, which is not a mechanic.
		draw_colored_polygon(
			PackedVector2Array(_disc(mid_u, mid_v, top_h - 1.2, radius * 0.76)),
			Color(0.30, 0.18, 0.11)
		)
