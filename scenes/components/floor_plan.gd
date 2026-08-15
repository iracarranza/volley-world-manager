class_name FloorPlan
extends Control

## The building, from any angle you like.
##
## `ACCOMMODATIONS_AND_CARE.md` §10: *"occupancy and equipment compete for the
## same floor."* That is the rule the whole housing system turns on, and it is
## the one thing a column of checkboxes cannot show. Two volis and a rack of
## weights is seven floor in a room that has five, and a manager reading two
## columns of ticks has no way to see it.
##
## ## Why it turns
##
## The first version drew one room flat, from directly above, and it was correct
## and inert -- a bar chart with a wall on the end. What a manager is being asked
## about is *where their squad lives*, and a place you can only see from one
## angle is a diagram of a place rather than the place.
##
## So the same axonometric orbit the training worksheet uses, with one
## difference that matters: the worksheet has three named views because a coach
## is asking three specific questions of a court. Nobody is asking a specific
## question of a dormitory. They are looking at it. So `theta` is **continuous**
## -- drag and it turns -- and the tilt stays put, because a building read from a
## consistent height is a building you can compare week to week.
##
## Projection is axonometric with no perspective divide, for the reason the
## worksheet gives: a drawing has no focal length, and a vanishing point would
## make this look rendered rather than drawn.
##
## ## And why the near walls are missing
##
## Every wall whose outside faces the viewer is dropped. That is the cutaway
## every building-management game uses and it is not decoration -- a room with
## four walls up, seen from above and to one side, shows you a roof. What is
## being looked at is what is *in* the rooms.
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const Accommodation := preload("res://scripts/data/accommodation.gd")

signal room_focused(room_index: int)

## One unit of floor, in world units. A room is `capacity` of them wide and
## `ROOM_DEPTH` deep, so its *width* is still exactly the number the model
## charges and the depth is only there to make it a room.
const ROOM_DEPTH: float = 3.4
## The gap between rooms, which is the corridor nobody walks down.
const ROOM_GAP: float = 1.1
const WALL_HEIGHT: float = 1.5
const WALL_THICKNESS: float = 0.16

## How tall the things in a room stand. A bed is low and wide, a large item is
## the tallest thing in the room, and none of it is to scale with the walls --
## these are heights that let three sizes of object be told apart from above.
const BED_HEIGHT: float = 0.55
const SMALL_HEIGHT: float = 0.75
const LARGE_HEIGHT: float = 1.15
## Objects sit off the wall a little, because a plan where everything is flush
## reads as a bar again.
const OBJECT_INSET: float = 0.22

## Where the camera stands. `theta` swings around the building and is yours to
## drag; `phi` tilts above it and is not, for the reason in the header.
const TILT_DEGREES: float = 34.0
const ROTATE_PER_PIXEL: float = 0.42
const ZOOM_STEP: float = 1.18
const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 4.5
## A drag this short was a click. Without it, focusing a room by clicking it is
## impossible on a trackpad, where nothing is ever perfectly still.
const CLICK_SLOP: float = 4.0

var structure: String = "Bunkhouse"
var occupants: int = 2
var small: Array = []
var large: Array = []
## How many of the building's rooms have anybody in them. The rest are drawn,
## empty, because a Block with four rooms used out of twenty is a different
## picture from a full Farmhouse and the manager is paying for both.
var rooms_used: int = 1

var theta: float = 34.0
var zoom: float = 1.0
## -1 frames the whole building; anything else frames that one room.
var focused_room: int = -1

var _light_mode: bool = false
var _scale: float = 20.0
var _origin: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_travel: float = 0.0
var _drag_from: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(360.0, 300.0)


func set_room(
	structure_name: String, occupant_count: int,
	small_items: Array, large_items: Array, occupied_rooms: int = 1
) -> void:
	structure = structure_name
	occupants = occupant_count
	small = small_items
	large = large_items
	rooms_used = maxi(occupied_rooms, 1)
	## A focus that outlived its building would frame a room that is no longer
	## there -- which is what happens the moment a lease changes from a Block's
	## twenty rooms to a Farmhouse's six.
	if focused_room >= room_count():
		focused_room = -1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_light_mode = UIPalette.control_is_light(self)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


## ## The arithmetic, unchanged
##
## Everything below is the same floor budget the model charges, and it is kept
## here rather than recomputed in the drawing because a load-bearing picture
## that derives its own arithmetic is a second opinion about the floor.
func capacity() -> float:
	return float(Dictionary(Accommodation.STRUCTURES.get(structure, {})).get("floor", 5.0))


## **A privacy screen partitions the room**, and this is where the plan would
## otherwise lie about it. `Accommodation.crowding` gives the screen back one
## occupant's worth of floor, so a room can sit past its own wall and be
## uncrowded -- and a picture drawing a bed outside the wall above a caption
## reading *over by 0.0* is the interface disagreeing with itself.
func partition_relief() -> float:
	return Accommodation.FLOOR_PER_OCCUPANT if small.has("privacy_screen") else 0.0


func effective_capacity() -> float:
	return capacity() + partition_relief()


func used() -> float:
	return Accommodation.floor_used(occupants, small, large)


func room_count() -> int:
	return int(Dictionary(Accommodation.STRUCTURES.get(structure, {})).get("rooms", 9))


## Every block in a room, left to right, as `{floor, label, kind}`.
##
## Built here rather than inside `_draw` so a gate can walk it: the widths this
## returns are the arithmetic `Accommodation.floor_used` does, and if the two
## ever disagree the picture is lying about the model.
func blocks() -> Array:
	var out: Array = []
	for index in range(maxi(occupants, 0)):
		out.append({
			"floor": Accommodation.FLOOR_PER_OCCUPANT,
			"label": "bed", "kind": "occupant",
		})
	for item in large:
		out.append({
			"floor": Accommodation.FLOOR_LARGE_ITEM,
			"label": str(item), "kind": "large",
		})
	for item in small:
		out.append({
			"floor": Accommodation.FLOOR_SMALL_ITEM,
			"label": str(item), "kind": "small",
		})
	return out


## ## The building
##
## Rooms in as square a grid as the count allows, because a corridor of twenty
## rooms in one line is a building nobody can see the end of at any angle.
func _columns() -> int:
	return maxi(int(ceilf(sqrt(float(room_count())))), 1)


## How far apart two rooms sit, and it is **not** how wide a room is.
##
## The first version spaced the grid by whatever was in the room, so one
## overcrowded room made every room in the building that wide -- nine rooms drawn
## at eleven floor each, none of which is eleven floor. A room is the size the
## structure says it is; what does not fit is in the corridor, and the corridor
## widens to hold it.
func _room_width() -> float:
	return effective_capacity()


func _spill() -> float:
	return maxf(used() - effective_capacity(), 0.0)


func _room_span() -> float:
	return _room_width() + maxf(ROOM_GAP, _spill() + ROOM_GAP * 0.5)


func _room_origin(index: int) -> Vector2:
	var columns := _columns()
	return Vector2(
		float(index % columns) * _room_span(),
		float(index / columns) * (ROOM_DEPTH + ROOM_GAP)
	)


## The box the camera has to hold: the whole building, or one room of it.
func _framed_box() -> Array:
	if focused_room >= 0 and focused_room < room_count():
		var at := _room_origin(focused_room)
		return [
			Vector3(at.x - 0.4, at.y - 0.4, 0.0),
			Vector3(
				at.x + _room_width() + _spill() + 0.4,
				at.y + ROOM_DEPTH + 0.4, WALL_HEIGHT
			),
		]
	var columns := _columns()
	var rows := int(ceilf(float(room_count()) / float(columns)))
	return [
		Vector3(-0.4, -0.4, 0.0),
		Vector3(
			float(columns) * _room_span(),
			float(rows) * (ROOM_DEPTH + ROOM_GAP),
			WALL_HEIGHT
		),
	]


func _rotate(world: Vector3) -> Vector3:
	var turn := deg_to_rad(theta)
	return Vector3(
		world.x * cos(turn) - world.y * sin(turn),
		world.x * sin(turn) + world.y * cos(turn),
		world.z
	)


func _project(world: Vector3) -> Vector2:
	var turned := _rotate(world)
	var tilt := deg_to_rad(TILT_DEGREES)
	return _origin + Vector2(
		turned.x * _scale,
		(turned.y * sin(tilt) - turned.z * cos(tilt)) * _scale
	)


## And back: a point on the page to the place on the floor under it, needed
## because a click lands in pixels and has to name a room.
##
## Closed form because the map is linear and z is known, and `sin(phi)` is never
## zero at a fixed 34 degrees of tilt.
func _unproject_floor(at: Vector2) -> Vector2:
	var turn := deg_to_rad(theta)
	var tilt := deg_to_rad(TILT_DEGREES)
	var flat_x := (at.x - _origin.x) / maxf(_scale, 0.001)
	var flat_y := (at.y - _origin.y) / maxf(_scale * sin(tilt), 0.001)
	return Vector2(
		flat_x * cos(turn) + flat_y * sin(turn),
		-flat_x * sin(turn) + flat_y * cos(turn)
	)


## Fit the framed box to the panel, at whatever the zoom is.
func _fit() -> void:
	var box := _framed_box()
	var low: Vector3 = box[0]
	var high: Vector3 = box[1]
	var least := Vector2(INF, INF)
	var most := Vector2(-INF, -INF)
	_scale = 1.0
	_origin = Vector2.ZERO
	for corner_x in [low.x, high.x]:
		for corner_y in [low.y, high.y]:
			for corner_z in [low.z, high.z]:
				var point := _project(Vector3(corner_x, corner_y, corner_z))
				least = least.min(point)
				most = most.max(point)
	var extent := most - least
	var room := size - Vector2(18.0, 18.0)
	_scale = minf(
		room.x / maxf(extent.x, 0.001), room.y / maxf(extent.y, 0.001)
	) * zoom
	## Centre what is framed rather than the origin, so a focused room sits in
	## the middle of the panel instead of wherever it happens to be in the block.
	var middle := (least + most) * 0.5 * _scale
	_origin = size * 0.5 - middle


## ## Drawing
##
## One list of faces, sorted back to front, because rooms overlap each other and
## the objects inside them overlap the walls. Painter's algorithm is enough:
## nothing here interpenetrates, so a per-face depth is never ambiguous.
func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_fit()
	var faces: Array = []
	for index in range(room_count()):
		_gather_room(faces, index)
	faces.sort_custom(func(a, b) -> bool: return float(a["depth"]) < float(b["depth"]))
	for face in faces:
		var points: PackedVector2Array = face["points"]
		draw_colored_polygon(points, face["fill"])
		if bool(face.get("edge", true)):
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, face["ink"], 1.0)


func _gather_room(faces: Array, index: int) -> void:
	var at := _room_origin(index)
	var occupied := index < rooms_used
	var wall := _room_width()
	var pen := UIPalette.color(&"stroke", _light_mode)
	var over_ink := UIPalette.color(&"danger", _light_mode)

	## The floor. An unoccupied room is drawn flatter and quieter: it is real
	## floor the club is paying for and it is not where anybody sleeps.
	_add_quad(faces, [
		Vector3(at.x, at.y, 0.0),
		Vector3(at.x + wall, at.y, 0.0),
		Vector3(at.x + wall, at.y + ROOM_DEPTH, 0.0),
		Vector3(at.x, at.y + ROOM_DEPTH, 0.0),
	], UIPalette.color(
		## Lifted off the page rather than set into it. `surface_inset` put a
		## Mikasa floor at `07101a` against a `08131f` canvas -- a room drawn
		## darker than the room it is standing in, which is a hole.
		&"surface_raised" if occupied else &"canvas_alt", _light_mode
	), pen)

	## The wall the floor rule is about, standing at capacity. Everything past it
	## is outside the room, which is what crowding is: not a penalty that fires,
	## a bed that does not fit.
	_add_wall(faces, at, wall, Vector2(0.0, 1.0), pen)
	_add_wall(faces, at, wall, Vector2(0.0, -1.0), pen)
	_add_wall(faces, at, wall, Vector2(-1.0, 0.0), pen)

	if not occupied:
		return

	var cursor := 0.0
	for block in blocks():
		var width := float(block["floor"])
		## Out the moment any part of it is past the wall. Not its midpoint and
		## not its far edge: half a bed outside is a bed that does not fit, and
		## rounding that in the room's favour is how a picture ends up
		## disagreeing with the number under it.
		var out := cursor + width > wall + 0.01
		## A ladder of lightness against the floor rather than three hues: what
		## the eye is sorting here is *what is in the room*, and the one thing
		## colour is spent on is whether it fits.
		var height := BED_HEIGHT
		var fill := UIPalette.color(&"stroke", _light_mode)
		match str(block["kind"]):
			"large":
				height = LARGE_HEIGHT
				fill = UIPalette.color(&"stroke_strong", _light_mode)
			"small":
				height = SMALL_HEIGHT
				fill = UIPalette.color(&"surface_hover", _light_mode)
		if out:
			fill = over_ink
		_add_box(
			faces,
			Vector3(at.x + cursor + OBJECT_INSET, at.y + OBJECT_INSET, 0.0),
			Vector3(
				at.x + cursor + width - OBJECT_INSET,
				at.y + ROOM_DEPTH - OBJECT_INSET,
				height
			),
			fill, over_ink if out else UIPalette.color(&"stroke_strong", _light_mode)
		)
		cursor += width


## One wall, dropped when its outside faces the viewer.
##
## The cutaway, and the reason it is a rule rather than a fixed pair of walls:
## the building turns, so which two walls are in the way changes continuously.
func _add_wall(
	faces: Array, at: Vector2, wall: float, outward: Vector2, pen: Color
) -> void:
	if _rotate(Vector3(outward.x, outward.y, 0.0)).y > 0.0:
		return
	var low := Vector3(at.x, at.y, 0.0)
	var high := Vector3(at.x + wall, at.y + ROOM_DEPTH, WALL_HEIGHT)
	if outward.y > 0.0:
		low.y = high.y - WALL_THICKNESS
	elif outward.y < 0.0:
		high.y = low.y + WALL_THICKNESS
	elif outward.x < 0.0:
		high.x = low.x + WALL_THICKNESS
	else:
		low.x = high.x - WALL_THICKNESS
	_add_box(
		faces, low, high,
		UIPalette.color(&"surface_raised", _light_mode), pen
	)


func _add_box(
	faces: Array, low: Vector3, high: Vector3, fill: Color, ink: Color
) -> void:
	## Six faces, each shaded by which way it points. Flat shading rather than a
	## light source, because the rest of this interface is drawn and a specular
	## highlight would be the only lit thing on the desk.
	var top := fill
	var side := Color(fill.darkened(0.18), fill.a)
	var end := Color(fill.darkened(0.32), fill.a)
	_add_quad(faces, [
		Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z),
		Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z),
	], top, ink)
	_add_quad(faces, [
		Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z),
		Vector3(high.x, low.y, high.z), Vector3(low.x, low.y, high.z),
	], side, ink)
	_add_quad(faces, [
		Vector3(low.x, high.y, low.z), Vector3(high.x, high.y, low.z),
		Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z),
	], side, ink)
	_add_quad(faces, [
		Vector3(low.x, low.y, low.z), Vector3(low.x, high.y, low.z),
		Vector3(low.x, high.y, high.z), Vector3(low.x, low.y, high.z),
	], end, ink)
	_add_quad(faces, [
		Vector3(high.x, low.y, low.z), Vector3(high.x, high.y, low.z),
		Vector3(high.x, high.y, high.z), Vector3(high.x, low.y, high.z),
	], end, ink)


func _add_quad(faces: Array, corners: Array, fill: Color, ink: Color) -> void:
	var points := PackedVector2Array()
	var depth := 0.0
	for corner in corners:
		points.append(_project(corner))
		## Depth is the rotated y, which is distance away from the viewer in an
		## axonometric map -- and the height matters too, or a tall object's top
		## face sorts behind the floor it is standing on.
		var turned := _rotate(corner)
		depth += turned.y * sin(deg_to_rad(TILT_DEGREES)) - turned.z * cos(deg_to_rad(TILT_DEGREES))
	faces.append({
		"points": points, "fill": fill, "ink": ink,
		"depth": depth / float(corners.size()),
	})


## ## Handling
##
## Drag to turn, wheel to zoom, click a room to go to it, click the floor to
## come back out. No mode, no toolbar: everything a manager can do to this view
## is done to the building itself.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			set_zoom(zoom * ZOOM_STEP)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			set_zoom(zoom / ZOOM_STEP)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_travel = 0.0
				_drag_from = button.position
			else:
				_dragging = false
				if _drag_travel <= CLICK_SLOP:
					_focus_at(button.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_drag_travel += motion.relative.length()
		turn_by(motion.relative.x * ROTATE_PER_PIXEL)
		accept_event()


func turn_by(degrees: float) -> void:
	theta = fposmod(theta + degrees, 360.0)
	queue_redraw()


func set_zoom(value: float) -> void:
	zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()


## Which room is under this point, or -1 for the floor between them.
func room_at(point: Vector2) -> int:
	var floor_point := _unproject_floor(point)
	for index in range(room_count()):
		var at := _room_origin(index)
		if floor_point.x >= at.x and floor_point.x <= at.x + _room_width() + _spill() \
				and floor_point.y >= at.y and floor_point.y <= at.y + ROOM_DEPTH:
			return index
	return -1


func _focus_at(point: Vector2) -> void:
	## Clicking the room you are already in goes back out, which means one
	## gesture does both and there is no button to explain.
	var hit := room_at(point)
	focus_room(-1 if hit == focused_room else hit)


func focus_room(index: int) -> void:
	focused_room = index
	## Zoom is the camera's, not the room's: a manager who zoomed out to see the
	## whole block and then clicked a room wants that room, at the size they had
	## chosen, not at whatever the last room was looked at from.
	queue_redraw()
	room_focused.emit(index)
