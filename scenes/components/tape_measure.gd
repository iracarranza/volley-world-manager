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


## Draw only the hook, for the tab that sits on the closed strip.
##
## The collapsed indicator and the extended tape's end are the same piece of
## metal, so they are one drawing routine rather than a control and a glyph that
## have to be kept looking alike.
@export var tab_only: bool = false

## Where the whole denominations fall, in local x. Set by whoever lays out the
## drawer; empty falls back to an even pitch.
var major_marks: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	resized.connect(queue_redraw)
	var parent := get_parent() as Control
	if parent != null and not tab_only:
		## The tape is sized to its full extension and revealed by the clip, so
		## it is the *parent's* width that says how much is out. Redrawn as that
		## changes, which is what lets the hook travel with the leading edge.
		parent.resized.connect(queue_redraw)


func _draw() -> void:
	if tab_only:
		_draw_hook(size.x - HOOK_WIDTH * 0.5, size.y)
		return
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
	_draw_graduations(revealed)
	_draw_hook(revealed - HOOK_MARGIN - HOOK_WIDTH * 0.5, size.y)


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
