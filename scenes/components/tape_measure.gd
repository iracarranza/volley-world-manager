class_name UITapeMeasure
extends Control

## The section menu, as a tape measure rolling out of its case.
##
## Every other surface on this page is sewn, printed or written -- things that
## are made once and then sit still. The section drawer is the one element that
## has to *move*, and a stitched panel that expands is a contradiction: cloth
## does not extend. So it stops being cloth.
##
## A tape measure earns the job on three counts. It is rigid and it still rolls
## out, which is exactly the behaviour needed. It belongs in the same drawer as
## the thread and the scissors, so it does not arrive from a different world.
## And it comes with its own affordance already attached: the hook on the end is
## what you pull, so the expansion indicator is a real part of the object rather
## than a chevron borrowed from a dropdown.
##
## Drawn rather than assembled from a texture, because the tape's length changes
## every time it opens and a stretched bitmap would smear its own graduations.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The three pieces of one object.
##
## `CASE` is the housing the menu button *is*; `BAND` is the steel rule that
## comes out of it; `TANG` is the hook on the end, which the closed strip shows
## on its own as the expansion indicator. One script for all three because they
## share a palette and a slot geometry, and two files that have to be kept
## looking like the same tool is exactly how they stop being it.
enum Piece { BAND, TANG, CASE }

## The steel rule's colour, warm and slightly grubby. Not taken from the palette:
## a tape measure is a *tool that happens to be on the desk*, not part of the
## page's own scheme, and matching it to the theme would make it read as another
## panel.
const TAPE_LIGHT := Color("e8c14a")
const TAPE_DARK := Color("b8912e")

## How often a graduation falls, in pixels, and how tall each kind stands as a
## share of the tape's height.
const MINOR_PITCH: float = 7.0
const MAJOR_EVERY: int = 5
const MINOR_HEIGHT: float = 0.20
const MAJOR_HEIGHT: float = 0.38

## The hook: the folded metal tang riveted to the end of the tape.
##
## Set *in* from the tape's edges rather than standing proud of them. A tang
## that overhangs is a flag on a stick; a real one is a plate riveted to the
## band, narrower than it, with its corners rounded off so it does not catch --
## and it is the rounding that makes it read as a piece of pressed metal rather
## than as a grey rectangle marking the end.
const HOOK_WIDTH: float = 8.0
const HOOK_INSET: float = 2.5
const HOOK_RADIUS: float = 2.4
const HOOK_COLOR := Color("9aa0a8")

## How far the leading edge is drawn back from the clip, so the hook sits *at*
## the end of the revealed tape rather than half outside it.
const HOOK_MARGIN: float = 1.0

## The case.
##
## A tape measure's body is a fat rounded shell at the reel end and squares off
## towards the nose, because the nose is a machined slot and the shell is
## moulded around a spring. Drawing one radius all the way round makes a
## lozenge; the difference between the two ends is what says which end the tape
## comes out of before it has come out.
const CASE_REEL_RADIUS: float = 10.0
const CASE_NOSE_RADIUS: float = 3.0

## The rubberised base along the bottom, as a share of the case's height.
const CASE_BASE_SHARE: float = 0.26

## The reel hub, as a share of the case's height and of its width.
## Far enough left that the label sits between the reel and the nose rather
## than across the hub: the case is wide because it holds a word, and the two
## parts of it that are machinery both live at the ends.
const CASE_HUB_RADIUS_SHARE: float = 0.30
const CASE_HUB_CENTRE_SHARE: float = 0.16

## The nose: how far in from the right edge the slot's mouth sits, and how thick
## the chrome lip above and below it is.
const CASE_NOSE_INSET: float = 3.0
const CASE_LIP_THICKNESS: float = 2.0
## How far back along the shell the lip is pressed. Longer than the slot is deep
## so a few pixels of it stay visible once the band is through -- the lip is the
## part that says "an opening", and an opening you can only see when it is empty
## is a hole.
const CASE_LIP_REACH: float = 13.0
const CASE_SLOT_COLOR := Color("3a3327")

## How much the shell lifts when the pointer is on it.
##
## The case is the one control on the page that does not take the highlighter --
## nobody goes over a steel tool with a marker -- so it needs its own answer to
## "this is pressable", and a moulded shell catching a little more light is the
## one that belongs to the object.
const CASE_HOVER_LIFT: float = 0.10


## Which piece this node draws.
@export var piece: Piece = Piece.BAND:
	set(value):
		piece = value
		if is_inside_tree():
			queue_redraw()

## How tall the slot in the nose is, in pixels. Set by whoever lays out the
## drawer, so the mouth and the band that comes through it are the same size --
## a tape wider than its own slot is the one mistake that cannot be explained.
var slot_height: float = 20.0:
	set(value):
		slot_height = value
		if is_inside_tree():
			queue_redraw()

## Where the whole denominations fall, in local x. Set by whoever lays out the
## drawer; empty falls back to an even pitch.
var major_marks: PackedFloat32Array = PackedFloat32Array()

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	resized.connect(queue_redraw)
	var parent := get_parent() as Control
	if parent == null:
		return
	if piece == Piece.BAND:
		## The tape is sized to its full extension and revealed by the clip, so
		## it is the *parent's* width that says how much is out. Redrawn as that
		## changes, which is what lets the hook travel with the leading edge.
		parent.resized.connect(queue_redraw)
	if piece == Piece.CASE:
		## The shell is drawn under the button's own label, so it has to be the
		## thing that answers the pointer -- the button paints no box of its own.
		show_behind_parent = true
		parent.mouse_entered.connect(_set_hovered.bind(true))
		parent.mouse_exited.connect(_set_hovered.bind(false))


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()


func _draw() -> void:
	match piece:
		Piece.TANG:
			_draw_hook(size.x - HOOK_WIDTH * 0.5, size.y)
		Piece.CASE:
			_draw_case()
		Piece.BAND:
			_draw_band()


func _draw_band() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var revealed := _revealed_width()
	if revealed < 2.0:
		return
	var band := Rect2(Vector2.ZERO, Vector2(revealed, size.y))
	draw_rect(band, TAPE_LIGHT)
	## The curl. A tape is not flat -- it is a shallow trough, which is what
	## keeps it rigid when extended, and the shading along its lower edge is how
	## anyone recognises one.
	draw_rect(
		Rect2(Vector2(0.0, size.y * 0.72), Vector2(revealed, size.y * 0.28)),
		Color(TAPE_DARK, 0.45)
	)
	draw_line(
		Vector2(0.0, 0.5), Vector2(revealed, 0.5), Color(TAPE_DARK, 0.7), 1.0
	)
	## The mouth it came through, cast onto the first few pixels of the band.
	## The drawer is drawn over the case rather than behind it, so without this
	## the tape ends flush at the housing's edge and the join reads as two
	## objects abutting instead of one passing through the other.
	var mouth := minf(5.0, revealed)
	for step in range(int(mouth)):
		## Graded rather than a block: a shadow cast into a slot is deepest at
		## the mouth and gone a few pixels out. Drawn flat it was a dark bar, and
		## a dark bar across the band is a seam between two objects -- which is
		## the exact reading this exists to prevent.
		draw_rect(
			Rect2(Vector2(float(step), 0.0), Vector2(1.0, size.y)),
			Color(CASE_SLOT_COLOR, 0.30 * (1.0 - float(step) / mouth))
		)
	_draw_graduations(revealed)
	_draw_hook(revealed - HOOK_MARGIN - HOOK_WIDTH * 0.5, size.y)


## The housing: a moulded shell with a reel in it and a slot at the nose.
##
## This is what the navigation button is, rather than something the navigation
## button is decorated with. The button paints no stylebox and carries no drawn
## edge -- a nib outline round a steel tool is the page's handwriting claiming
## to have made an object it did not make -- so everything below the label is
## this drawing, and pressing it is pressing the case.
func _draw_case() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var lift := CASE_HOVER_LIFT if _hovered else 0.0
	var shell := TAPE_LIGHT.lightened(lift)
	var trim := TAPE_DARK.lightened(lift * 0.5)
	var body := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(
		_shell_outline(body, CASE_REEL_RADIUS, CASE_NOSE_RADIUS), shell
	)
	## The rubberised base. Clipped to the shell by being built from the same
	## outline, so it follows the reel end's curve instead of squaring off
	## inside it.
	var base := Rect2(
		Vector2(0.0, size.y * (1.0 - CASE_BASE_SHARE)),
		Vector2(size.x, size.y * CASE_BASE_SHARE)
	)
	draw_colored_polygon(
		_shell_outline(
			base, CASE_REEL_RADIUS * CASE_BASE_SHARE, CASE_NOSE_RADIUS * 0.5
		),
		Color(trim, 0.55)
	)
	## The reel, seen through the shell: a hub and the coil wound on it.
	var hub := Vector2(size.x * CASE_HUB_CENTRE_SHARE, size.y * 0.46)
	var hub_radius := size.y * CASE_HUB_RADIUS_SHARE
	draw_arc(hub, hub_radius, 0.0, TAU, 40, Color(trim, 0.40), 1.4, true)
	draw_arc(hub, hub_radius * 0.42, 0.0, TAU, 24, Color(trim, 0.55), 1.4, true)
	## The nose. A slot the height of the band, with a chrome lip pressed in
	## above and below it -- which is the part that says a thing comes out here.
	var slot := clampf(slot_height, 4.0, size.y - 6.0)
	var mouth_x := size.x - CASE_NOSE_INSET
	var slot_top := (size.y - slot) * 0.5
	draw_rect(
		Rect2(
			Vector2(mouth_x - 4.0, slot_top), Vector2(4.0, slot)
		),
		Color(CASE_SLOT_COLOR, 0.85)
	)
	for edge in [slot_top - CASE_LIP_THICKNESS, slot_top + slot]:
		draw_rect(
			Rect2(
				Vector2(mouth_x - CASE_LIP_REACH, edge),
				Vector2(CASE_LIP_REACH, CASE_LIP_THICKNESS)
			),
			Color(HOOK_COLOR, 0.9)
		)
	## The shell's own edge, so it reads as a moulded part rather than a swatch.
	draw_polyline(
		_shell_outline(body, CASE_REEL_RADIUS, CASE_NOSE_RADIUS),
		Color(TAPE_DARK.darkened(0.35), 0.55), 1.2, true
	)


## The shell's silhouette: fat at the reel end, square at the nose.
func _shell_outline(
	rect: Rect2, reel_radius: float, nose_radius: float
) -> PackedVector2Array:
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	var reel := clampf(reel_radius, 0.0, limit)
	var nose := clampf(nose_radius, 0.0, limit)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - nose, rect.position.y + nose), -PI * 0.5, nose],
		[Vector2(rect.end.x - nose, rect.end.y - nose), 0.0, nose],
		[Vector2(rect.position.x + reel, rect.end.y - reel), PI * 0.5, reel],
		[Vector2(rect.position.x + reel, rect.position.y + reel), PI, reel],
	]
	for corner in corners:
		var centre: Vector2 = corner[0]
		var start: float = corner[1]
		var radius: float = corner[2]
		for step in range(7):
			var angle := start + PI * 0.5 * float(step) / 6.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Ticks up from the lower edge, minor and major.
##
## Measured from the *case* end rather than from the leading edge, so a
## graduation stays put on the tape as it extends instead of sliding along it.
## A tape whose markings move when you pull it is a barber's pole.
##
## Where the majors fall is handed in by the drawer rather than derived from a
## pitch. The section buttons sit on the tape, and a rule whose whole
## denominations land at arbitrary points between them looks like two unrelated
## things sharing a strip; landing them on the button edges makes the buttons
## look measured out along the tape, which is what a scale is for.
func _draw_graduations(revealed: float) -> void:
	var ink := Color(TAPE_DARK, 0.85)
	var majors := major_marks if not major_marks.is_empty() \
		else _even_majors(revealed)
	var previous := 0.0
	for major_x in majors:
		if major_x > revealed - HOOK_WIDTH:
			break
		_draw_tick(major_x, MAJOR_HEIGHT, ink)
		## Minors subdivide whatever gap the layout left, so they stay evenly
		## spaced within each denomination even when the buttons are not equal.
		var gap := major_x - previous
		if gap > MINOR_PITCH * 1.5:
			var divisions := maxi(int(round(gap / MINOR_PITCH)), 2)
			for step in range(1, divisions):
				_draw_tick(
					previous + gap * float(step) / float(divisions),
					MINOR_HEIGHT, ink
				)
		previous = major_x


## Where the majors would fall with nothing to align to.
func _even_majors(revealed: float) -> PackedFloat32Array:
	var marks := PackedFloat32Array()
	var x := MINOR_PITCH * float(MAJOR_EVERY)
	while x < revealed:
		marks.append(x)
		x += MINOR_PITCH * float(MAJOR_EVERY)
	return marks


func _draw_tick(x: float, share: float, ink: Color) -> void:
	var height := size.y * share
	draw_line(Vector2(x, size.y - height), Vector2(x, size.y - 1.0), ink, 1.0)


## The tang on the end. An L of folded steel: a plate across the tape and a lip
## turned up at the tip, which is the part you hook over an edge.
func _draw_hook(centre_x: float, height: float) -> void:
	var top := HOOK_INSET
	var bottom := maxf(height - HOOK_INSET, top + HOOK_RADIUS * 2.0)
	var plate := Rect2(
		Vector2(centre_x - HOOK_WIDTH * 0.5, top),
		Vector2(HOOK_WIDTH, bottom - top)
	)
	_draw_rounded(plate, HOOK_RADIUS, HOOK_COLOR)
	## The turned lip, caught by the light down one side, and the shadow of the
	## fold down the other. Rounded with the plate so the highlight follows its
	## edge instead of squaring off inside it.
	_draw_rounded(
		Rect2(plate.position, Vector2(HOOK_WIDTH * 0.40, plate.size.y)),
		HOOK_RADIUS, Color(HOOK_COLOR.lightened(0.42), 0.95)
	)
	draw_line(
		Vector2(plate.end.x - 1.0, plate.position.y + HOOK_RADIUS),
		Vector2(plate.end.x - 1.0, plate.end.y - HOOK_RADIUS),
		Color(HOOK_COLOR.darkened(0.45), 0.75), 1.0
	)


## A rounded rectangle, as a polygon.
##
## `draw_rect` has no corner radius and a `StyleBoxFlat` would need a resource
## per colour, so the tang builds its own -- four quarter-arcs and the straight
## runs between them.
func _draw_rounded(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for corner in corners:
		var centre: Vector2 = corner[0]
		var start: float = corner[1]
		for step in range(5):
			var angle := start + PI * 0.5 * float(step) / 4.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)


## How much tape is currently out, in pixels.
##
## The clip above decides: this control is always its full extended length and
## the parent's width is the window onto it. Falls back to its own width so the
## thing still draws if it is ever used without a clipper.
func _revealed_width() -> float:
	var parent := get_parent() as Control
	if parent == null:
		return size.x
	return clampf(parent.size.x, 0.0, size.x)
