class_name UICreasedEdge
extends Control

## A panel edge that was **folded and cut**, not drawn and not printed.
##
## The other three media all put a *line* around a surface. The journal stitches
## one, the default page draws one with a nib, the clipboard prints one. Each
## time, something was added to the sheet.
##
## A folder has no line around it at all. What reads as its edge is the sheet's
## own geometry: one side is a **crease**, where the card was folded and the fold
## catches light along its shoulder and holds shadow in its valley, and the other
## three are **cut**, where you are seeing the thickness of the stock end-on.
## Nothing here is a mark. If you handed somebody a folder and asked them to
## point at the border, they would have nothing to point at.
##
## That is what makes this a fourth medium rather than `MEDIUM_FORM` with a
## different colour, and `UIPrintedRule`'s own header explains why that
## distinction has to be made in the substrate and not in the border: the first
## clipboard failed *exactly* by being the journal with a different edge.
##
## ## The hand is a pencil
##
## Each medium allows one instrument and forbids the others, which is how a
## hover affordance stays inside the object's own vocabulary:
##
## | medium | what a hand may do to it |
## |---|---|
## | `sewn` | nothing -- you do not annotate cloth |
## | `drawn` | a highlighter, swept over the word |
## | `form` | marker, red pen, highlighter, over machine-set type |
## | `board` | four markers, and a wipe |
## | `card` | **pencil** |
##
## A folder is annotated in pencil because its contents change and pencil comes
## off. So hovering here draws a pencil line under the control -- graphite, which
## is grey and slightly cold rather than brown-black like ink, and which does not
## lay down evenly because the stock has tooth. It is the same *event* as the
## highlighter sweep on paper and it is a different instrument, which is the
## whole intent.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## Which side was folded. The rest are cut.
##
## Left by default: a folder stands in a drawer with its spine toward you-left
## and opens away, so that is the side the fold is on for the object this medium
## was built for. Exported because a folder laid flat on a desk folds along its
## bottom and the scouting screen may yet want both.
enum Fold { LEFT, BOTTOM, TOP, RIGHT, NONE }

@export var fold: Fold = Fold.LEFT:
	set(value):
		fold = value
		queue_redraw()

## Whether a hand may write on this one. Set by the style system, the same way
## `UIInkOutline.hover_highlight` is, so surfaces stay unmarked and controls take
## the pencil.
@export var pencil_hover: bool = false:
	set(value):
		pencil_hover = value
		_bind_hover()
		queue_redraw()

## How thick the stock is, in pixels. Card is thick enough to see and thin enough
## that this is the only number that says so -- past about three it stops reading
## as a sheet and starts reading as a slab.
const STOCK_THICKNESS: float = 2.0
## The cut edge: the stock's own colour, in shadow, along the three open sides.
const CUT_ALPHA: float = 0.20

## The crease is two lines and they are not the same line.
##
## A fold has a valley that holds shadow and a shoulder beside it that is
## slightly proud and catches light, and drawing only the dark half is the
## difference between a fold and a smudge. They sit `CREASE_SPREAD` apart, which
## is the width of the radius the card takes when it bends rather than a
## decorative gap.
const CREASE_SPREAD: float = 2.4
const CREASE_VALLEY_ALPHA: float = 0.30
const CREASE_SHOULDER_ALPHA: float = 0.26
const CREASE_INSET: float = 3.0

## Graphite. Cooler and lighter than any of the inks this interface uses -- a
## pencil is a grey mineral and every other mark on the desk is a dye.
const GRAPHITE_LIGHT := Color(0.30, 0.31, 0.34)
const GRAPHITE_DARK := Color(0.70, 0.72, 0.76)
const PENCIL_ALPHA: float = 0.62
const PENCIL_WIDTH: float = 1.7
const PENCIL_INSET: float = 5.0
## How far the line overshoots the word at each end. A pencil stroke starts
## before and stops after, because a hand is moving when the tip lands.
const PENCIL_OVERSHOOT: float = 3.0
## Segments per line, and how far the tip wanders off true. Small: a ruled
## underline is not what this is, and neither is a scribble.
const PENCIL_SEGMENTS: int = 14
const PENCIL_WANDER: float = 0.7
## The tooth of the stock, as the share of a segment's alpha that survives where
## the graphite skipped. Card is not smooth, so a pencil line on it is not solid.
const PENCIL_TOOTH: float = 0.45

## How long the line takes to be drawn, and to go. Slower on than the
## highlighter's sweep, because a pencil is dragged and a highlighter is swiped.
const PENCIL_DRAW_SECONDS: float = 0.22
const PENCIL_LIFT_SECONDS: float = 0.12

## Seeded from the parent's name, so one control's line is the same imperfect
## line every time and two side by side are never identical.
var pencil_seed: int = 0

var _stroke: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Walked past by the style pass, like every other edge component. Without it
	## the pass would try to classify this as a control and give it a variation.
	set_meta("ui_style_exempt", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parent := get_parent() as Control
	if parent != null:
		parent.resized.connect(queue_redraw)
	resized.connect(queue_redraw)
	set_process(false)
	_bind_hover()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


## The parent is watched rather than this node, for `UIInkOutline`'s reason: this
## is `MOUSE_FILTER_IGNORE` and has to be, or it would swallow the clicks meant
## for the control underneath it.
func _bind_hover() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	if pencil_hover:
		if not parent.mouse_entered.is_connected(_on_hover):
			parent.mouse_entered.connect(_on_hover)
			parent.mouse_exited.connect(_on_unhover)
		return
	if parent.mouse_entered.is_connected(_on_hover):
		parent.mouse_entered.disconnect(_on_hover)
		parent.mouse_exited.disconnect(_on_unhover)
	_stroke = 0.0
	_target = 0.0
	set_process(false)


func _on_hover() -> void:
	## Restarted from nothing, not resumed. A pointer coming back to a control it
	## just left gets the line drawn again -- the same rule the highlighter keeps,
	## because a half-drawn line fading back in reads as a rendering glitch.
	_stroke = 0.0
	_target = 1.0
	set_process(true)


func _on_unhover() -> void:
	_target = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var seconds := PENCIL_DRAW_SECONDS if _target > _stroke else PENCIL_LIFT_SECONDS
	_stroke = move_toward(_stroke, _target, delta / maxf(seconds, 0.001))
	queue_redraw()
	if is_equal_approx(_stroke, _target):
		set_process(false)


func _draw() -> void:
	if size.x < 6.0 or size.y < 6.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	## The cut and the crease are both the stock in shadow, so both are mixed from
	## the page's own stroke colour rather than from a colour of their own. An edge
	## that carried its own hue would be a line again.
	var shadow := UIPalette.color(&"stroke", light_mode)
	_draw_cut(shadow)
	_draw_crease(shadow, light_mode)
	if pencil_hover and _stroke > 0.001:
		_draw_pencil(light_mode)


## The three open sides: the thickness of the sheet, seen end-on.
##
## Drawn as short inward bands rather than as a frame, and never on the folded
## side -- a fold has no cut edge, which is the one asymmetry that makes a viewer
## read the shape as a folded sheet instead of a rectangle.
func _draw_cut(shadow: Color) -> void:
	var ink := Color(shadow, CUT_ALPHA)
	for side in [Fold.LEFT, Fold.RIGHT, Fold.TOP, Fold.BOTTOM]:
		if side == fold:
			continue
		draw_rect(_edge_band(side), ink, true)


func _edge_band(side: Fold) -> Rect2:
	match side:
		Fold.LEFT:
			return Rect2(0.0, 0.0, STOCK_THICKNESS, size.y)
		Fold.RIGHT:
			return Rect2(size.x - STOCK_THICKNESS, 0.0, STOCK_THICKNESS, size.y)
		Fold.TOP:
			return Rect2(0.0, 0.0, size.x, STOCK_THICKNESS)
		_:
			return Rect2(0.0, size.y - STOCK_THICKNESS, size.x, STOCK_THICKNESS)


## The fold: a valley and the shoulder beside it.
##
## The shoulder is drawn in the *surface* colour rather than in shadow, because
## it is the one part of a folder that is turned toward the light. Two lines of
## the same colour would be a double rule, which is what a form prints and what
## this medium exists not to be.
func _draw_crease(shadow: Color, light_mode: bool) -> void:
	if fold == Fold.NONE:
		return
	var valley := Color(shadow, CREASE_VALLEY_ALPHA)
	var lit := Color(UIPalette.color(&"surface_raised", light_mode), CREASE_SHOULDER_ALPHA)
	var horizontal := fold == Fold.TOP or fold == Fold.BOTTOM
	var at := CREASE_INSET
	if fold == Fold.RIGHT:
		at = size.x - CREASE_INSET
	elif fold == Fold.BOTTOM:
		at = size.y - CREASE_INSET
	## The shoulder is always on the *inside* of the fold, which is the side the
	## panel's own contents are on.
	var toward := 1.0 if fold == Fold.LEFT or fold == Fold.TOP else -1.0
	if horizontal:
		draw_line(Vector2(1.0, at), Vector2(size.x - 1.0, at), valley, 1.4)
		var y := at + toward * CREASE_SPREAD
		draw_line(Vector2(1.0, y), Vector2(size.x - 1.0, y), lit, 1.0)
		return
	draw_line(Vector2(at, 1.0), Vector2(at, size.y - 1.0), valley, 1.4)
	var x := at + toward * CREASE_SPREAD
	draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0), lit, 1.0)


## The pencil, under the word, drawn left to right as the pointer rests.
func _draw_pencil(light_mode: bool) -> void:
	var graphite := GRAPHITE_LIGHT if light_mode else GRAPHITE_DARK
	var baseline := size.y - PENCIL_INSET
	var from := -PENCIL_OVERSHOOT
	var to := (size.x + PENCIL_OVERSHOOT - from) * _stroke + from
	if to - from < 1.0:
		return
	var wobble := pencil_seed
	for index in range(PENCIL_SEGMENTS):
		var a := from + (to - from) * float(index) / float(PENCIL_SEGMENTS)
		var b := from + (to - from) * float(index + 1) / float(PENCIL_SEGMENTS)
		if b - a < 0.2:
			continue
		## One deterministic draw per segment, advanced by a large odd multiplier
		## so consecutive segments are uncorrelated without needing a second seed.
		wobble = (wobble * 1103515245 + 12345) & 0x7FFFFFFF
		var drift := (float(wobble % 1000) / 1000.0 - 0.5) * 2.0 * PENCIL_WANDER
		var next := (wobble * 1103515245 + 12345) & 0x7FFFFFFF
		## Tooth: some of the stroke skipped where the tooth of the card stood
		## proud of the tip. Never all the way to nothing, or the line breaks in
		## half and reads as a dash.
		var tooth := lerpf(PENCIL_TOOTH, 1.0, float(next % 1000) / 1000.0)
		draw_line(
			Vector2(a, baseline + drift),
			Vector2(b, baseline + drift),
			Color(graphite, PENCIL_ALPHA * tooth),
			PENCIL_WIDTH
		)
