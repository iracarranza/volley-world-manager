class_name UICorkBoard
extends Control

## The clipboard itself: a cork board with a metal clamp holding paper to it.
##
## The card every page sits on used to be another sheet -- paper on paper, which
## is a stack rather than an object. A clipboard is the thing that makes a loose
## page into something you carry to a session and write on standing up, and it is
## the only object on the desk that *holds* rather than contains. So the card
## becomes the board and the page becomes what is clipped to it, with the board
## showing round all four edges the way it does when the paper is smaller than
## the backing.
##
## Cork is a hard material to draw and an easy one to overdo. What reads as cork
## is not brown -- it is **granularity at two scales**: a fine speckle of pressed
## grains, and a much sparser scatter of the larger dark flecks where a whole
## piece of bark went in. A flat brown rectangle with noise on it reads as
## corduroy; the second scale is what fixes it.
##
## Drawn behind the card rather than replacing it, so the page keeps whatever the
## style pass gave it and the board is a separate object underneath.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## How far the board shows past the page it holds.
##
## Wider than it was. At 9 x 11 the cork was a bevel round the page rather than a
## board the page was lying on -- the object reads from how much of it you can
## see, and a clipboard is mostly board with a smaller sheet clamped to it.
const BOARD_MARGIN: Vector2 = Vector2(21.0, 21.0)
## And how far the clamp hangs down over the top of the page.
const CLAMP_HEIGHT: float = 26.0
const CLAMP_WIDTH_SHARE: float = 0.26
const CLAMP_CORNER: float = 4.0

## The two scales of grain. `FINE` is the pressed-granule texture; `FLECK` is the
## sparse dark bark. Counts are per 10,000 px² so a resize does not change how
## coarse the material looks -- which it did when they were flat counts, and a
## maximised window turned the cork to suede.
## Raised for the open board.
##
## These were set against the clipboard, where the cork is a 21px margin round a
## page -- and a margin reads as a material off almost nothing, because your eye
## has the page beside it for comparison. The scouting board is nearly a
## thousand times the area with nothing to compare against, and at the old
## density it rendered as flat brown paper: about one granule per two hundred
## square pixels, which at arm's length is not a texture, it is dust.
const FINE_PER_AREA: float = 3.4
const FLECK_PER_AREA: float = 0.38

## Cork, and what cork becomes at night.
##
## Light brown sits well on Molten's green and cream. Mikasa cannot take the same
## value -- a mid-brown against a near-black page is the brightest thing on the
## screen and the board stops being furniture and starts being the subject. So
## the dark theme keeps the *hue* and drops the value hard: the same cork, in a
## room with the lights off, which is what every other surface in Mikasa is
## doing. Its grain also inverts -- flecks read lighter than the ground rather
## than darker -- because in the dark what you can see of a texture is where it
## catches what light there is.
const CORK_LIGHT := Color(0.70, 0.54, 0.36)
const CORK_DARK := Color(0.33, 0.24, 0.16)

var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	## Behind the card it belongs to. A child draws after its parent, which for a
	## backing would mean painting out the page.
	show_behind_parent = true
	_seed = int(String(name).hash() & 0x7FFFFFFF)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


## Whether this cork is holding a sheet or *is* the surface.
##
## The clipboard is a board with one page clamped to it; the scouting board is a
## wall with a dozen things pinned to it. Both are cork and the same component
## draws both, so the two marks that belong only to the clipboard -- the steel
## clamp, and the shadow the single page drops onto the board -- are switched off
## here rather than being a second component that would drift.
##
## `UIPinnedSlip`'s header carries the full table of what separates the two
## objects; this flag is the drawing half of it.
@export var clamped: bool = true:
	set(value):
		clamped = value
		queue_redraw()


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var cork := CORK_LIGHT if light_mode else CORK_DARK
	var board := Rect2(-BOARD_MARGIN, size + BOARD_MARGIN * 2.0)

	## The board, its edge, and the shadow it casts onto the page behind it.
	draw_rect(board.grow(2.0), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(board, cork)
	_draw_grain(board, cork, light_mode)
	draw_rect(board, Color(cork.darkened(0.34), 0.85), false, 1.6)

	if not clamped:
		return
	## And the shadow the page casts onto the cork, which is what says the paper
	## is lying on the board rather than printed on it. Only when there *is* one
	## page: on the open board every scrap drops its own shadow and one the size
	## of the whole surface would be a grey rectangle over the cork.
	draw_rect(
		Rect2(Vector2(2.0, 3.0), size), Color(0.0, 0.0, 0.0, 0.16)
	)
	_draw_clamp(light_mode)


func _draw_grain(board: Rect2, cork: Color, light_mode: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var area := board.size.x * board.size.y / 10000.0
	## In the dark the grain catches light instead of absorbing it.
	var fine := cork.darkened(0.16) if light_mode else cork.lightened(0.22)
	var fleck := cork.darkened(0.42) if light_mode else cork.lightened(0.40)
	for index in range(int(area * FINE_PER_AREA)):
		var at := board.position + Vector2(
			rng.randf() * board.size.x, rng.randf() * board.size.y
		)
		draw_rect(
			Rect2(at, Vector2(rng.randf_range(1.0, 2.6), rng.randf_range(1.0, 2.0))),
			Color(fine, rng.randf_range(0.18, 0.42))
		)
	for index in range(int(area * FLECK_PER_AREA)):
		var at := board.position + Vector2(
			rng.randf() * board.size.x, rng.randf() * board.size.y
		)
		## Irregular quads rather than rectangles: a piece of bark has no
		## right angles, and a field of tiny axis-aligned boxes reads as pixels.
		var scale := rng.randf_range(2.4, 6.0)
		var points := PackedVector2Array()
		for corner in range(4):
			var angle := TAU * float(corner) / 4.0 + rng.randf_range(-0.5, 0.5)
			points.append(
				at + Vector2(cos(angle), sin(angle)) * scale * rng.randf_range(0.6, 1.3)
			)
		draw_colored_polygon(points, Color(fleck, rng.randf_range(0.24, 0.52)))


## The clamp: a spring clip centred on the top edge, holding the page down.
##
## Drawn as three things because that is what one is -- a body, the bright lip
## where it bends over the paper, and the two arms you press. Without the lip it
## is a grey rectangle; the lip is the whole of what makes it metal.
func _draw_clamp(light_mode: bool) -> void:
	var width := size.x * CLAMP_WIDTH_SHARE
	var left := (size.x - width) * 0.5
	## Sat on the board rather than off the top of it. At -BOARD_MARGIN - 4 the
	## clip hung past the edge of the screen and read as a nub.
	var top := -BOARD_MARGIN.y + 2.0
	var body := Rect2(left, top, width, CLAMP_HEIGHT)
	var metal := Color(0.74, 0.75, 0.78) if light_mode else Color(0.42, 0.45, 0.50)

	draw_rect(body.grow(1.5), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(body, metal)
	## Brushed, along the length. Steel is directional and a flat fill is plastic.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 77
	for index in range(int(width * 0.5)):
		var x := left + rng.randf() * width
		draw_line(
			Vector2(x, body.position.y + 2.0), Vector2(x, body.end.y - 2.0),
			Color(metal.lightened(0.30), rng.randf_range(0.05, 0.16)), 1.0
		)
	## The lip, where it folds over the paper: the brightest line on the object.
	draw_rect(
		Rect2(left, body.end.y - 5.0, width, 5.0), metal.darkened(0.22)
	)
	draw_line(
		Vector2(left, body.end.y - 5.0), Vector2(left + width, body.end.y - 5.0),
		metal.lightened(0.55), 1.6
	)
	## The two arms, standing up off the back.
	for share in [0.22, 0.78]:
		var arm := Rect2(left + width * share - 7.0, top - 5.0, 14.0, 7.0)
		draw_rect(arm, metal.darkened(0.14))
		draw_line(
			arm.position, arm.position + Vector2(arm.size.x, 0.0),
			metal.lightened(0.40), 1.2
		)
	draw_rect(body, Color(metal.darkened(0.45), 0.75), false, 1.2)
