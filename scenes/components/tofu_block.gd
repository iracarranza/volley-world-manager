class_name TofuBlock
extends Control

## The nutrition block, as a block.
##
## It has been a name in a list and a line of flavour text, which is a strange
## thing for the object the whole screen is about. A manager picks a block, spends
## paste on it and feeds it to twelve people; it should be a thing sitting on the
## bench, and what is on it should be visible without being described.
##
## ## The projection is the worksheet's, not a camera's
##
## Three-quarter view by **axonometric projection**: one linear map from block
## space to the screen, no perspective divide, no camera. The floor plan and the
## training worksheet are drawn the same way and for the same reasons -- a
## parallel projection can be inverted in closed form, which is what makes a
## mouse position a place on the block rather than a raycast, and its texture
## mapping is affine, which is what makes `draw_polygon` correct rather than
## approximately correct on the top face.
##
##     screen(u, v) = origin + ((u - v) * half_width, (u + v) * half_depth)
##
## `u` runs to the right-back edge and `v` to the left-back edge, both in `[0, 1]`
## across the top face. The two visible sides hang straight down from the front
## two edges, because a slab has no vanishing point.
##
## ## The paint is a texture, and it has to be
##
## The canvas is 16,384 cells. Drawn as that many little projected quads it is
## that many draw calls a frame while somebody is dragging a nozzle across it.
## Uploaded to an `ImageTexture` once per change and drawn as one textured quad,
## it is one. The affine mapping above is what makes the second one exact -- with
## a perspective camera the same shortcut would swim.

const Larder := preload("res://scripts/data/region_larder.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

signal pressed_at(cell: Vector2)
signal dragged_to(cell: Vector2)
signal released

## How squat the block is drawn.
##
## `DEPTH_RATIO` is the vertical squash of the top face: 0.5 is a true isometric
## diamond and reads as a floor tile, so this sits under it and the block reads as
## something seen from a standing cook's height rather than from directly above.
const DEPTH_RATIO: float = 0.42
## How thick the slab is, as a share of the top face's half-width.
##
## It was 0.30 and rendered as a packing crate: at that ratio the two visible
## sides are as tall as the top face is deep, and a shape whose faces are all the
## same size is a box whatever colour it is painted. A block of tofu is a slab.
const THICKNESS_RATIO: float = 0.19
## Room left around the block so the corner nicks and the cursor ring are not
## clipped by the control's own rect.
const MARGIN: float = 10.0

## The two visible sides, relative to the top.
##
## A curd block is one material all the way through, so the sides are the top's
## own colour darkened rather than colours of their own -- which is also what
## keeps the paint reading as something laid *on* the block rather than as the
## block being made of it.
const LEFT_FACE_SHADE: float = 0.72
const RIGHT_FACE_SHADE: float = 0.86

## The bare block, before anything is spread on it. Warm off-white in both themes
## and only slightly cooler in Mikasa: tofu does not change colour in a dim room,
## and a block that took the theme's slate would read as stone.
const CURD_LIGHT := Color("f3ead4")
const CURD_DARK := Color("d9d0bb")

## The nicks knocked off the top corners, as a share of the half-width. A block
## cut from a larger one with a wire has soft corners, and this is the cheapest
## mark that says it was cut rather than moulded.
const NICK: float = 0.045

## Whether a nozzle can be dragged across this one. False for the block sitting on
## the kitchen's stage, which is a readout, and true inside the painter.
@export var interactive: bool = false:
	set(value):
		interactive = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value \
			else Control.MOUSE_FILTER_IGNORE

## The nozzle's radius in cells, drawn as a ring under the pointer so a cook can
## see how wide the stroke will be *before* spending the paste.
@export var nozzle_cells: float = 9.0

var _paint: PastePaint = null
var _texture: ImageTexture = null
var _hover_cell := Vector2(-1.0, -1.0)
var _dragging: bool = false


func _ready() -> void:
	set_meta("ui_style_exempt", true)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive \
		else Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_paint(paint: PastePaint) -> void:
	_paint = paint
	refresh_paint()


## Rebuild the top face's texture from the cells.
##
## Called by whoever changed the canvas rather than polled, because a stroke is
## dozens of cells and a poll would re-upload the whole face every frame whether
## or not anything moved.
##
## The image itself comes from `PastePaint`, which keeps it in step cell by cell.
## This used to build one here by walking all 16,384 cells, which is a quarter of
## a second of GDScript per frame of a held drag.
func refresh_paint() -> void:
	if _paint == null:
		_texture = null
		queue_redraw()
		return
	var image := _paint.image()
	if _texture != null and _texture.get_size() == Vector2(image.get_size()):
		## Updated in place rather than replaced. `ImageTexture.update` re-uploads
		## into the existing GPU texture; `create_from_image` allocates a new one
		## every stroke and leaves the old to be collected.
		_texture.update(image)
	else:
		_texture = ImageTexture.create_from_image(image)
	## Filtered, not nearest.
	##
	## The canvas is 128 cells across and the block is drawn several hundred pixels
	## wide, so an unfiltered texture magnifies each cell into a visible square and
	## a round nozzle comes out scalloped. Filtering feathers the edge instead --
	## which is also what spread paste does, so the softening is not a concession.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


## ## Block space and back
##
## `_half_width` and `_half_depth` are derived from whichever of the two the
## control's rect runs out of first, so the block fills its box in either
## proportion without ever being drawn off the edge.
func _half_width() -> float:
	var by_width := (size.x - MARGIN * 2.0) * 0.5
	var by_height := (size.y - MARGIN * 2.0) \
		/ (2.0 * DEPTH_RATIO + THICKNESS_RATIO)
	return maxf(minf(by_width, by_height), 1.0)


func _origin() -> Vector2:
	var half := _half_width()
	var block_height := half * (2.0 * DEPTH_RATIO + THICKNESS_RATIO)
	return Vector2(size.x * 0.5, (size.y - block_height) * 0.5 + MARGIN * 0.5)


func project(u: float, v: float) -> Vector2:
	var half := _half_width()
	return _origin() + Vector2(
		(u - v) * half, (u + v) * half * DEPTH_RATIO
	)


## The closed-form inverse, which is the reason for the projection.
##
## Returns cell coordinates in `[0, CANVAS)`, or `(-1, -1)` for a point that is
## not on the top face. Off-face is reported rather than clamped: clamping would
## smear paint along whichever edge the pointer wandered past, which looks exactly
## like a bug in the brush.
func cell_at_point(local: Vector2) -> Vector2:
	var half := _half_width()
	var offset := local - _origin()
	var across := offset.x / half
	var down := offset.y / (half * DEPTH_RATIO)
	var u := (across + down) * 0.5
	var v := (down - across) * 0.5
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(u * float(PastePaint.CANVAS), v * float(PastePaint.CANVAS))


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			var cell := cell_at_point(button.position)
			if cell.x >= 0.0:
				_dragging = true
				pressed_at.emit(cell)
			accept_event()
			return
		_dragging = false
		released.emit()
		accept_event()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = cell_at_point(motion.position)
		queue_redraw()
		if _dragging and _hover_cell.x >= 0.0:
			dragged_to.emit(_hover_cell)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = Vector2(-1.0, -1.0)
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return
	var light := UIPalette.control_is_light(self)
	var curd := CURD_LIGHT if light else CURD_DARK
	var half := _half_width()
	var drop := Vector2(0.0, half * THICKNESS_RATIO)

	var back := project(0.0, 0.0)
	var right := project(1.0, 0.0)
	var front := project(1.0, 1.0)
	var left := project(0.0, 1.0)

	## **The sides hang from the nicked outline, not from the sharp corners.**
	##
	## They used to run `left -> front -> right`, which is where the corners would
	## be if they had not been knocked off. The top is cut back from all three, so
	## at the front corner the two faces met at a point the top no longer reaches
	## and the background showed through a triangular notch -- which reads as a
	## polygon winding bug rather than as a cut corner.
	##
	## Taking the top edge of each face straight off `_nicked_top` closes it by
	## construction: whatever shape the top is, the sides start exactly where it
	## ends.
	var top := PackedVector2Array(_nicked_top(back, right, front, left, half))
	## Indices into that outline. The visible silhouette runs from just before the
	## right corner, through the front, to just after the left one; the two faces
	## split at the middle of the front corner's own cut.
	var right_in := top[1]
	var right_out := top[2]
	var front_in := top[3]
	var front_out := top[4]
	var left_in := top[5]
	var left_out := top[6]
	var front_mid := (front_in + front_out) * 0.5

	draw_colored_polygon(
		PackedVector2Array([
			right_in, right_out, front_in, front_mid,
			front_mid + drop, front_in + drop, right_out + drop, right_in + drop,
		]),
		Color(curd * RIGHT_FACE_SHADE, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			front_mid, front_out, left_in, left_out,
			left_out + drop, left_in + drop, front_out + drop, front_mid + drop,
		]),
		Color(curd * LEFT_FACE_SHADE, 1.0)
	)

	## The top after the sides, so it draws over the seam where they meet it --
	## otherwise the darker face bleeds a pixel onto the paint along the front.
	draw_colored_polygon(top, curd)
	_draw_paint(back, right, front, left)

	## The cut edges, in the curd's own shadow rather than the page's ink. A block
	## of tofu has no drawn outline; what you see at its edge is the same material
	## turning away from the light.
	var edge := Color(curd * 0.55, 0.85)
	draw_polyline(top + PackedVector2Array([top[0]]), edge, 1.4)
	for corner in [right_in, left_out]:
		draw_line(corner, corner + drop, edge, 1.4)
	draw_polyline(
		PackedVector2Array([
			right_in + drop, right_out + drop, front_in + drop,
			front_out + drop, left_in + drop, left_out + drop,
		]),
		edge, 1.4
	)

	if interactive and _hover_cell.x >= 0.0:
		_draw_nozzle_ring(edge)


## The top face with its corners knocked off.
func _nicked_top(
	back: Vector2, right: Vector2, front: Vector2, left: Vector2, half: float
) -> Array:
	var nick := half * NICK
	var points: Array = []
	for pair in [[back, right], [right, front], [front, left], [left, back]]:
		var from: Vector2 = pair[0]
		var to: Vector2 = pair[1]
		var along := (to - from).normalized() * nick
		points.append(from + along)
		points.append(to - along)
	return points


## The paint, as one textured quad over the top face.
##
## UVs are the face's own corners in `[0, 1]`, which is exactly block space -- so
## the texture's `x` runs along `u` and its `y` along `v`, and a cell painted at
## `(3, 40)` lands where the nozzle was.
func _draw_paint(back: Vector2, right: Vector2, front: Vector2, left: Vector2) -> void:
	if _texture == null:
		return
	draw_polygon(
		PackedVector2Array([back, right, front, left]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		]),
		_texture
	)


## The nozzle's footprint, projected.
##
## Drawn as the projected circle rather than a screen-space one, because a circle
## on a tilted face is an ellipse and a round cursor would promise a round blob
## the stroke does not make.
func _draw_nozzle_ring(ink: Color) -> void:
	var steps := 24
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var angle := TAU * float(index) / float(steps)
		var cell := _hover_cell + Vector2(cos(angle), sin(angle)) * nozzle_cells
		points.append(project(
			cell.x / float(PastePaint.CANVAS), cell.y / float(PastePaint.CANVAS)
		))
	draw_polyline(points, Color(ink, 0.75), 1.6)
