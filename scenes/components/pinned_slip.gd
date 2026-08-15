class_name UIPinnedSlip
extends Control

## What holds a thing to a cork board.
##
## Every other medium on this desk answers *what is this surface made of*. The
## board answers a different question, and getting that wrong is the whole risk
## of building it: **a cork board has no surface of its own that anything is
## drawn on.** It is a wall you push things into. What you are looking at is not
## a page with regions on it, it is a dozen separate scraps that came from
## somewhere else, each one held by a pin, each one casting its own small shadow,
## none of them lined up with any other.
##
## So this medium's whole vocabulary is three marks and no border:
##
## - **a pin**, at the top, drawn over the item rather than round it
## - **a shadow**, short and soft, because the item stands a millimetre off the
##   cork and that gap is the only reason the board reads as depth
## - **a tilt**, a degree or two, because nobody pins anything straight
##
## ## Why this is not the clipboard's cork
##
## `UICorkBoard` already exists and is the *training clipboard's backing*: mostly
## hidden, one sheet clamped square to it, a steel clamp at the top. The same
## material doing two jobs is this repository's most repeated failure, so the
## separation is structural rather than tonal and is worth stating as a table:
##
## | | the clipboard | the board |
## |---|---|---|
## | how much cork you see | a margin round one sheet | nearly all of it |
## | what is on it | one page, square, clamped | many scraps, tilted, pinned |
## | the fastener | one steel clamp, at the top | one pin per item |
## | what it is for | writing on, standing up | arranging, and seeing at once |
##
## A reader who cannot tell those apart is looking at a bug.
##
## ## The tilt is seeded, not random
##
## An item that re-tilts every time the screen refreshes is an item that jitters,
## and jitter reads as a rendering fault rather than as a hand. The angle comes
## off the item's own name, so a voli's card sits at the same slightly wrong
## angle every time you open the board, and two cards side by side are never at
## the same one.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## How far off square a pinned thing sits, in degrees.
##
## Two, and it is deliberately small. Real boards are messier and a interface
## that tilts its content five degrees is one where the text is visibly harder to
## read -- the tilt has to say "a hand put this here" without ever being the
## reason somebody has to turn their head.
const MAX_TILT_DEGREES: float = 2.0

## The gap between the scrap and the cork, expressed as its shadow.
##
## Short and soft. A long shadow would put the item an inch off the wall, and the
## thing being drawn is a sheet of paper with a pin through it.
const SHADOW_OFFSET := Vector2(2.5, 3.5)
const SHADOW_ALPHA: float = 0.30
const SHADOW_SPREAD: float = 2.0
const SHADOW_STEPS: int = 3

## The pin. A coloured head, a highlight on it, and the shadow it drops onto the
## paper -- which is what makes it sit *on* the item rather than being a dot
## printed on it.
const PIN_RADIUS: float = 5.0
const PIN_INSET: float = 9.0
const PIN_HIGHLIGHT: float = 0.34

## What pin colours exist. A box of pins is a box of pins: they come in a few
## colours and which one you grabbed means nothing. Assigning meaning to them is
## available and deliberately unused here -- `tack_colour` is exported so a caller
## that *does* have a meaning (a shortlist, a mark) can say so explicitly, rather
## than the board inventing a colour key nobody was told about.
const PIN_COLOURS := [
	Color("c8443a"), Color("d9982f"), Color("3f7d52"),
	Color("35618f"), Color("8a4a86"),
]

## The item's own colour, so the caller can override it. Left transparent to take
## the palette's paper.
@export var tack_colour := Color(0, 0, 0, 0)

## Whether this scrap is a photographic print rather than a written slip.
##
## A print has a white border all the way round -- the unexposed margin of the
## paper it was printed on -- and a slip does not. It is the cheapest mark that
## separates "a picture of somebody" from "a note about them", and both are on
## the board at once.
@export var photographic: bool = false

## Whether this scrap was **cut out of something**.
##
## The board's two kinds of thing are opposites and have to look it: a polaroid is
## a person you are tracking, and a clipping is an event that arrived. So a
## clipping is newsprint -- greyer, cooler, cheaper stock -- and it is *torn*
## along its top and bottom rather than cut square, because nobody uses scissors.
##
## Same component rather than a second one, because both are paper on cork and the
## family is the point; what separates them is the stock and the edge, which is
## the medium rule applied one level down.
@export var newsprint: bool = false

## The seed the tilt and the pin colour come from. Set from the item's name by
## whoever builds it.
@export var slip_seed: int = 0

const PRINT_BORDER: float = 6.0


static func wrap(item: Control, seed_text: String, is_photo: bool = false) -> UIPinnedSlip:
	var slip := UIPinnedSlip.new()
	slip.slip_seed = int(seed_text.hash() & 0x7FFFFFFF)
	slip.photographic = is_photo
	slip.add_child(item)
	## **The pin goes on last, as a child.**
	##
	## A `CanvasItem` draws itself and then its children, so a pin drawn in this
	## node's own `_draw` is underneath whatever it is holding up -- which is the
	## one thing a pin cannot be. The first board rendered with every pin buried
	## behind the photograph it was supposed to be pinning.
	##
	## Same shape as `UIInkOutline` and `UIPrintedRule`: an exempt child the style
	## pass walks straight past, added after the content so it draws after it.
	var pin := _Pin.new()
	pin.name = "Pin"
	pin.slip = slip
	slip.add_child(pin)
	return slip


func _ready() -> void:
	set_meta("ui_style_exempt", true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	## The tilt is applied to the whole slip, contents and all, which is the point
	## -- a pinned card is tilted, not a card with tilted text in it. Pivoting at
	## the centre keeps the item where the layout put it instead of swinging it
	## out of its own box.
	pivot_offset = size * 0.5
	rotation_degrees = tilt_degrees()
	resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func tilt_degrees() -> float:
	return (float(slip_seed % 1000) / 1000.0 - 0.5) * 2.0 * MAX_TILT_DEGREES


func pin_colour() -> Color:
	if tack_colour.a > 0.0:
		return tack_colour
	return PIN_COLOURS[(slip_seed / 7) % PIN_COLOURS.size()]


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var light := UIPalette.control_is_light(self)
	## The scrap itself, drawn here rather than by a stylebox, because a panel
	## behind this would come with the style pass's edge and a pinned note has no
	## edge -- it has a shadow, and the shadow is what separates it from the cork.
	var paper := UIPalette.color(&"surface_raised", light)
	if photographic:
		paper = Color(1.0, 0.99, 0.96) if light else Color(0.92, 0.91, 0.87)
	elif newsprint:
		## Cheap stock: grey, slightly green, and never as bright as a print. Pulp
		## with no clay in it goes grey rather than yellow, which is the one thing
		## that stops newsprint reading as aged paper.
		paper = Color(0.88, 0.87, 0.83) if light else Color(0.72, 0.72, 0.69)
	_draw_shadow()
	if newsprint:
		draw_colored_polygon(_torn_outline(), paper)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), paper, true)
	## No border. A pinned scrap has a shadow and an edge where the paper stops,
	## and drawing a line round it would make it a card in a list again.
	if photographic:
		## The print's own image area, inset by its unexposed margin.
		draw_rect(
			Rect2(
				Vector2(PRINT_BORDER, PRINT_BORDER),
				size - Vector2(PRINT_BORDER, PRINT_BORDER) * 2.0
			),
			Color(UIPalette.color(&"surface_inset", light), 0.55), true
		)


## The ragged top and bottom of something torn out of a page.
##
## Deterministic off the slip's own seed and the step index, so a cutting is the
## same cutting every time the board is opened -- a tear that re-randomises per
## frame is a scrap dissolving.
const TEAR_STEPS: int = 11
const TEAR_DEPTH: float = 3.4


func _torn_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(TEAR_STEPS + 1):
		var t := float(step) / float(TEAR_STEPS)
		points.append(Vector2(size.x * t, _jag(step)))
	for step in range(TEAR_STEPS + 1):
		var t := 1.0 - float(step) / float(TEAR_STEPS)
		points.append(Vector2(size.x * t, size.y - _jag(step + 31)))
	return points


func _jag(step: int) -> float:
	var noise := ((slip_seed + step * 2654435761) >> 8) & 0x3FF
	return float(noise) / 1023.0 * TEAR_DEPTH


## Stacked translucent rects rather than a blur, which canvas drawing has no
## cheap version of. Three steps is enough to lose the hard edge at this size.
func _draw_shadow() -> void:
	for step in range(SHADOW_STEPS):
		var grow := SHADOW_SPREAD * float(step)
		draw_rect(
			Rect2(
				SHADOW_OFFSET - Vector2(grow, grow) * 0.5,
				size + Vector2(grow, grow)
			),
			Color(0.0, 0.0, 0.0, SHADOW_ALPHA / float(SHADOW_STEPS + step)), true
		)


## The pin itself, over everything the slip holds.
class _Pin extends Control:
	var slip: UIPinnedSlip = null

	func _ready() -> void:
		set_meta("ui_style_exempt", true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if slip == null:
			return
		var at := Vector2(size.x * 0.5, PIN_INSET)
		var head := slip.pin_colour()
		draw_circle(at + Vector2(1.0, 1.5), PIN_RADIUS, Color(0.0, 0.0, 0.0, 0.28))
		draw_circle(at, PIN_RADIUS, head)
		## One highlight, up and left, so every pin on the board is lit from the
		## same place. Lit individually they read as stickers.
		draw_circle(
			at + Vector2(-PIN_RADIUS, -PIN_RADIUS) * 0.34,
			PIN_RADIUS * 0.38,
			Color(1.0, 1.0, 1.0, PIN_HIGHLIGHT)
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()
