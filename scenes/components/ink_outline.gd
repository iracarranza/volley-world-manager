class_name UIInkOutline
extends Control

## A panel edge drawn as a pen line rather than a border width.
##
## `StyleBoxFlat` draws a rectangle of constant thickness with mathematically
## exact corners, which is the single most machine-made thing on the screen. A
## pen does none of that: it wanders off the straight by a fraction of a
## millimetre, it thins where the hand moves fastest along a run, and it pools
## where the hand slows and turns.
##
## So this draws the edge itself, as a chain of short segments whose offset and
## width both vary. It sits over the panel it belongs to and paints nothing else,
## which keeps it composable with the halftone -- one says what the surface is
## made of, the other says how its edge was drawn.
##
## **Deterministic, seeded per panel.** A wobble that redraws differently every
## frame is a shimmer, and a wobble shared by every panel is a texture rather
## than a hand. The seed comes from the panel's identity, so a given card always
## has the same imperfect edge and two cards side by side never have the same
## one.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## How long each drawn segment is, in pixels.
##
## Short enough that the line reads as continuously varying and long enough that
## a full card is not hundreds of draw calls. At 14 a dashboard card's edge is
## about fifty segments.
const SEGMENT_LENGTH: float = 6.0

## How far the line may stray from true, in pixels.
##
## Small on purpose, and smaller than it first shipped. At 1.15 the wobble was
## the loudest thing about the line; a drawn edge is mostly straight, and what
## says "hand" is the *variation in the ink*, not the deviation of the path.
const WANDER_PIXELS: float = 0.40

## Pen width along a run, and what it becomes at a corner.
##
## Thicker at corners because that is where a hand slows and the ink pools, which
## is the detail that sells a drawn line more than the wander does.
## The nib, at its widest and at its narrowest.
##
## A broad pen is not a round one with jitter. Its width depends on the
## *direction of travel* relative to the angle the nib is held at: fully across
## the nib is the full width of the edge, along it is almost nothing. That is
## the entire reason calligraphy reads as calligraphy, and it is structural
## rather than noise -- the same stroke drawn twice comes out the same.
##
## Thicker than the line it replaces, and it has to be: at 1.6 px a width
## *ratio* has nowhere to show. `NIB_ANGLE_DEGREES` near the horizontal is what
## makes a rounded rectangle interesting -- the top and bottom runs travel
## nearly along the nib and come out light, the sides travel across it and come
## out heavy, and the corners sweep between the two.
const STROKE_WIDTH: float = 5.4
const NIB_ANGLE_DEGREES: float = 22.0
## What is left when travelling straight along the nib. Not zero: a nib run
## exactly along its own edge still leaves a hairline, and a border that
## genuinely vanishes on its top run reads as a bug.
const NIB_MIN_RATIO: float = 0.38
const CORNER_WIDTH: float = 6.6

## How much of the run either side of a corner is affected by the pooling, as a
## fraction of the shortest side.
const CORNER_SHARE: float = 0.14

## Inset from the panel's own rect, so the line sits on the edge rather than half
## outside it.
const EDGE_INSET: float = 1.0

## The feathering pass: how far past the true edge it reaches, and how faint.
##
## `draw_polygon` does not antialias, so the ribbon needs its own soft edge. One
## wider pass at low alpha is enough at this stroke weight and costs one extra
## quad per segment.
const FEATHER_PIXELS: float = 0.7
const FEATHER_ALPHA: float = 0.32

## How much ink the ball can fail to lay down, at worst.
##
## A ballpoint does not deposit an even line: the ball picks up ink in bursts, so
## a stroke runs solid, thins over a stretch where the bearing is dry, and comes
## back. That starvation is what a real pen line looks like up close, and it is a
## different thing from the path wandering -- one is where the line goes, the
## other is how much of it arrives.
##
## 0.62 leaves the driest stretch faint but never absent. A line that genuinely
## breaks reads as a rendering gap rather than as ink.
const COVERAGE_DEPTH: float = 0.62

## How many segments a dry stretch lasts. A pen starves over a run and re-inks;
## per-segment noise would be a dotted line, which is a different instrument.
const COVERAGE_RUN: int = 5

## How much thinner the stroke goes where it is starved. A dry ball lays down a
## narrower line as well as a fainter one.
const COVERAGE_WIDTH_FLOOR: float = 0.72

## The two ways this edge can be drawn.
##
## `INK` is a continuous broad-nib stroke. `STITCH` is a running stitch: discrete
## lens-shaped marks with gaps between them, which is what the old chain of
## segments accidentally resembled once its per-joint beading fell on a regular
## fourteen-pixel beat. One is a pen, the other is thread, and the halftone
## underneath reads differently against each -- ink on printed stock, or a
## sampler worked on it.
enum Stroke { INK, STITCH }

## What the interface uses. One line to switch the whole page.
const DEFAULT_STROKE: Stroke = Stroke.STITCH

## How long each visible mark is, and how much cloth shows between two of them.
##
## The pair is only a *request*: the spacing is rescaled so a whole number of
## stitches fits the perimeter exactly, because a sampler is planned to come out
## even and a border that closes with a half-stitch looks like a mistake rather
## than like handwork.
const STITCH_LENGTH: float = 9.0
const STITCH_GAP: float = 4.5

## How many quads make up one mark. Enough for the taper to read as a curve
## rather than as a chamfer.
const STITCH_SEGMENTS: int = 5

## What the mark tapers to at each end, as a share of its middle.
##
## A stitch is thread pulled taut and pushed through cloth at both ends, so it
## is fullest mid-span and disappears into the fabric at the ends. Drawn as a
## rectangle it reads as a dash, which is a dotted border and carries a
## conventional meaning -- disabled, placeholder -- that this is not.
const STITCH_END_RATIO: float = 0.22

## How far alternate stitches sit off the true line, in pixels. Hand sewing
## does not track a ruled edge; consecutive marks sit a hair either side of it.
const STITCH_ALTERNATE_OFFSET: float = 0.55

## The gauge of the thread.
##
## Constant, and deliberately not the nib width. Floss has one thickness
## wherever it goes -- it is not held at an angle and it does not pool at a
## turn. Drawn through `_stroke_width` the marks inherited the nib's
## direction dependence, so the vertical runs came out nearly as wide as they
## were long and read as a row of beads rather than as stitches.
const STITCH_WIDTH: float = 2.6

## How a cut edge differs from a drawn one.
##
## Scissors do not wander -- they travel in short straight facets and leave the
## occasional nick where the blade was reopened. So a sewn panel's outline holds
## its offset for a few steps and then steps to a new one, instead of drifting
## smoothly the way a pen does. That faceting is most of what reads as "cut out
## and stitched on" rather than "drawn around".
const CUT_FACET_STEPS: int = 4
const CUT_DEPTH_PIXELS: float = 1.15
## How often the blade leaves a deeper nick, and how much deeper.
const CUT_NICK_CHANCE: float = 0.16
const CUT_NICK_PIXELS: float = 2.3

## Loose threads, where the stitching has worked its way out of the weave.
## Fraying is flavour, not structure. At seven per panel the strands were a
## feature of the design rather than a thing you notice on second look, and a
## patch that is coming apart at seven points is a patch about to fall off.
const FRAY_COUNT: int = 3
const FRAY_LENGTH: float = 5.5
const FRAY_WIDTH: float = 1.1
## Faint, for the same reason. These sit under the threshold where the eye
## counts them.
const FRAY_ALPHA: float = 0.34

## How far inside the cloth the stitching runs.
##
## A seam is sewn *in from* the edge -- there has to be material outside it or
## there is nothing for the thread to hold. Running the stitches along the true
## boundary made the card stop exactly where its sewing did, which reads as a
## drawn border that happens to be dashed rather than as cloth with a seam in
## it.
const SEAM_INSET: float = 5.0

## The perforated silhouette: how far the tabs stand out from the edge, how wide
## each one is, and how far apart their centres run.
##
## A stamp's edge, or the wire stubs left in a cut-up cross-stitch template --
## the little remnants of where a sheet was separated. Drawn *outward* in the
## card's own colour rather than bitten inward in the page's, because the page
## under a card carries the halftone and a backdrop doodle, and painting over
## either would leave a visible flat patch where the perforation should be.
## Shorter than they started. At 3.4 px the stubs stood far enough off the edge
## to be counted, which makes them a scalloped border -- a decorative edge
## treatment, which is the opposite of a remnant. Cut back, they register as
## roughness along the boundary and only resolve into wire when looked at.
const PERFORATION_DEPTH: float = 2.2
const PERFORATION_WIDTH: float = 4.2
const PERFORATION_PITCH: float = 9.0
const PERFORATION_STUB_WIDTH: float = 1.4
## Fainter than the seam. These are remnants, not part of the sewing.
const PERFORATION_ALPHA: float = 0.42

## A highlighter is a wide chisel drawn once across a word.
##
## Not an outline at all -- it is a band of translucent colour *behind* the text,
## and everything that says "highlighter" rather than "coloured rectangle" is at
## its edges. The tip is a flat chisel, so the ends of the stroke are angled
## rather than square. The hand does not stop exactly on the word, so the band
## overshoots at one end and falls short at the other. And the ink is laid down
## in one pass, so it is denser where the tip pressed and thinner where it
## lifted.
## Translucent, and by a lot. At 0.85 the band was a fill: it covered the page
## completely, took the tone of the paper out from under the word, and made
## every control read as a primary action. A highlighter puts a wash over
## something you can still see -- the halftone, the paper, the tone of the ink
## underneath all survive it, and that survival is the whole effect.
const HIGHLIGHT_ALPHA: float = 0.30
## How far past the box the stroke runs at each end, in pixels. Signed per end
## and seeded, so no two buttons are covered the same way.
const HIGHLIGHT_OVERSHOOT: float = 6.5
## The chisel angle, as a horizontal shear of the two ends.
const HIGHLIGHT_SHEAR: float = 4.5
## How much the band's top and bottom edges wander, in pixels.
const HIGHLIGHT_EDGE_WAVE: float = 1.4
## How far in from the top and bottom of the box the band sits. A highlighter
## covers the word, not the whole line.
const HIGHLIGHT_INSET: float = 2.0

## The other three ways a mark misses.
##
## Only the two ends varied, which meant every control on the page was covered
## by a band of the same height, in the same place, at the same angle -- the
## overshoot was the one degree of freedom and it read as a template with a
## random number in it. What actually differs between two swipes of a
## highlighter is where the band sat relative to the word (`DRIFT`), whether the
## hand ran level or downhill across it (`TILT`), and how the tip happened to be
## held that time (`SHEAR_SPREAD`, as a multiplier on the chisel angle). All
## three are drawn per control from its own seed, so a given button is always
## marked the same way and no two are marked alike.
const HIGHLIGHT_DRIFT: float = 3.2
const HIGHLIGHT_TILT: float = 3.0
const HIGHLIGHT_SHEAR_SPREAD: float = 1.1

## How often the stroke is laid down right to left instead.
##
## A right-handed hand going back over a line does not always start at the same
## end, and the direction of a sweep is the most legible thing about it. Under a
## half, so left-to-right still reads as the norm and the others as the
## exception rather than as a coin toss.
const HIGHLIGHT_REVERSE_CHANCE: float = 0.30

## How long the swipe takes, in seconds. Short: this is a pointer landing on a
## control, not a transition. Long enough that the direction is legible, because
## a mark that appears all at once is a colour change rather than a stroke.
##
## Paired with a width, because a fixed duration is a fixed *duration* and not a
## fixed speed: at 0.16 s flat, a 60 px chip and a 320 px row were marked in the
## same time, so the hand went five times faster across the long one. The eye
## reads that as two different gestures. Instead the time is scaled by the
## control's width against this reference -- one hand speed everywhere -- and
## then compressed, because a stroke five times as long taking five times as
## long to arrive is a hover affordance that has stopped being responsive.
const HIGHLIGHT_SWEEP_SECONDS: float = 0.16
const HIGHLIGHT_SWEEP_REFERENCE_WIDTH: float = 150.0
## How much of the width difference the duration actually takes on. At 1.0 the
## speed is genuinely constant and long buttons feel slow; at 0 it is back to a
## fixed duration. Below half, so a longer button is marked in *slightly* more
## time and therefore visibly faster -- which is what a hand does when it has
## further to go and the same amount of patience.
const HIGHLIGHT_SWEEP_LENGTH_SHARE: float = 0.42
## Never quicker than this, whatever the arithmetic says, or the mark on a small
## chip stops being a stroke and becomes a state change.
const HIGHLIGHT_SWEEP_FLOOR: float = 0.09

## The width past which a control stops being highlighted at all.
##
## Scaling the duration fixed the *speed* problem and left the real one, which is
## that a highlighter marks a word or a phrase. Nobody drags a highlighter across
## a whole ruled line -- and the widest controls here are whole lines: a scouting
## row runs the width of the card. At 1100px the sweep took 0.36s, which is far
## too long for a hover affordance, and no amount of curve tuning makes a
## full-line wash the right instrument.
##
## So above this width the instrument changes rather than the timing. A pen
## underline is what a hand actually does to a whole line, it arrives in one
## quick pass whatever the width, and it does not read as a highlighted button.
const HIGHLIGHT_MAX_WIDTH: float = 360.0

## How long an underline takes, whatever it is under.
##
## Fixed rather than width-scaled, and that is not the mistake the sweep made: a
## highlighter is a chisel dragged at a hand's pace, so its duration has to
## follow its length, while an underline is a flick from the wrist that arrives
## at about the same speed under a short phrase or a long one.
const UNDERLINE_SECONDS: float = 0.13
## Where the rule sits, as a share of the control's height.
##
## Not an inset from the bottom, which is what the first cut used: at three
## pixels up from the edge the line landed exactly on the control's own drawn
## outline and was invisible against it. A control's label is centred, so the
## rule wants to be just under the text -- about seven tenths down -- which on a
## 46px button leaves it clear of both the type above and the border below.
const UNDERLINE_BASELINE: float = 0.70
## Never closer than this to the bottom edge, so a short control cannot push the
## rule back onto its own border.
const UNDERLINE_EDGE_CLEARANCE: float = 6.0
const UNDERLINE_WIDTH: float = 2.0
## How far the pen runs past each end of the control.
const UNDERLINE_OVERSHOOT: float = 5.0


## Which panel this is, for the wander. Assigned by whoever creates the outline;
## identical seeds draw identical edges, which is the point.
@export var ink_seed: int = 0

## Corner radius to follow, so the pen turns where the stylebox turns.
@export var corner_radius: float = 10.0

## Which of the two treatments this outline draws. Per-instance so a preview can
## put both on screen at once.
@export var stroke_style: Stroke = DEFAULT_STROKE:
	set(value):
		stroke_style = value
		if is_inside_tree():
			queue_redraw()

## Whether pointing at this control marks it.
##
## The highlighter is not a *state* of the button, it is something that happens
## to it: hovering is the act of going over the word. So the band is absent at
## rest -- the control is just written -- and sweeps on under the pointer.
##
## Which also answers what the mark is for. A permanent wash on every control is
## decoration; one that arrives when you point at something is the hover
## affordance doing its job in the page's own vocabulary, instead of the instant
## colour swap it replaces.
@export var hover_highlight: bool = false:
	set(value):
		hover_highlight = value
		if is_inside_tree():
			_sync_draw_order()
			_bind_hover()
			queue_redraw()

## How much of the sweep has been laid down, 0 to 1, and where it is heading.
var highlight_sweep: float = 0.0
var _sweep_target: float = 0.0


func _ready() -> void:
	## Purely decorative: it must never eat a click meant for the card it is
	## drawn over, and it must never be restyled by the pass that created it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	## `set_anchors_and_offsets_preset`, not `set_anchors_preset`.
	##
	## The latter takes `keep_offsets = false` to mean "recompute the offsets so
	## the control keeps the rect it already has" -- it changes which edges the
	## control is anchored to and deliberately leaves it exactly where it was.
	## Read as "snap to full rect" it looks right and does nothing, which is what
	## happened: under a `PanelContainer` the outline was fitted by the container
	## and drew correctly, and under every `Button` it kept its content-derived
	## rect of 163x0 and returned at the size guard without painting a pixel. Six
	## of the seven inked surfaces on the dashboard were blank.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## Draw order follows the width, and the width arrives with the first layout
	## pass -- so it has to be re-decided on resize, not settled here.
	resized.connect(_on_resized)
	_sync_draw_order()
	_bind_hover()


func _on_resized() -> void:
	_sync_draw_order()
	queue_redraw()


## Watch the control this outline belongs to, so the mark follows the pointer.
##
## The outline itself cannot be asked -- it is `MOUSE_FILTER_IGNORE`, which it
## has to be or it would eat the clicks meant for the button underneath it. So
## it listens to its parent instead.
func _bind_hover() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	if hover_highlight:
		if not parent.mouse_entered.is_connected(_on_parent_hover):
			parent.mouse_entered.connect(_on_parent_hover)
			parent.mouse_exited.connect(_on_parent_unhover)
		return
	if parent.mouse_entered.is_connected(_on_parent_hover):
		parent.mouse_entered.disconnect(_on_parent_hover)
		parent.mouse_exited.disconnect(_on_parent_unhover)
	highlight_sweep = 0.0
	set_process(false)


func _on_parent_hover() -> void:
	_sweep_target = 1.0
	set_process(true)


func _on_parent_unhover() -> void:
	_sweep_target = 0.0
	set_process(true)


## Whether this control is long enough that a highlighter is the wrong tool.
func _is_underlined() -> bool:
	return size.x > HIGHLIGHT_MAX_WIDTH


## How long this particular control takes to be gone over.
func _sweep_seconds() -> float:
	if _is_underlined():
		return UNDERLINE_SECONDS
	var stretch := lerpf(
		1.0,
		maxf(size.x, 1.0) / HIGHLIGHT_SWEEP_REFERENCE_WIDTH,
		HIGHLIGHT_SWEEP_LENGTH_SHARE
	)
	return maxf(HIGHLIGHT_SWEEP_SECONDS * stretch, HIGHLIGHT_SWEEP_FLOOR)


func _process(delta: float) -> void:
	var step := delta / maxf(_sweep_seconds(), 0.001)
	highlight_sweep = move_toward(highlight_sweep, _sweep_target, step)
	queue_redraw()
	if is_equal_approx(highlight_sweep, _sweep_target):
		set_process(false)


## A highlighter goes *under* the word.
##
## A child `CanvasItem` normally draws after its parent, which is right for an
## outline at the perimeter and completely wrong for a band that covers the
## control -- it would paint over the label it is supposed to be marking.
## `show_behind_parent` puts it before the parent's own drawing instead, so the
## order becomes band, then stylebox, then text.
## Which side of the parent this node draws on, and it depends on the instrument.
##
## A highlighter belongs behind: band, then stylebox, then text, so the wash sits
## under the word the way a real one does. An underline does not -- it is a pen
## mark on the paper, and behind a filled stylebox a two-pixel line is simply
## swamped. Drawn in front it reads, and it still sits below the label because it
## is placed below the label rather than because of draw order.
##
## Width is only known once the control has been laid out, so this is re-run on
## resize rather than settled in `_ready`.
func _sync_draw_order() -> void:
	show_behind_parent = hover_highlight
	_sync_underline_layer()


## The rule that draws in front, while the rest of this node draws behind.
##
## One `CanvasItem` gets one side of its parent, and this node needs both: the
## perimeter ink belongs behind the stylebox with the highlighter, and the rule
## belongs in front of it. Behind, a two-pixel line is swamped -- the highlighter
## survives back there only because it is a wash across the whole control and the
## eye reads the tint shift, which a line does not get.
##
## So the rule is a sibling laid on the same parent, added after this node and
## therefore drawn after it. Same shape as the paper window's slip-and-window
## pair, for the same reason.
func _sync_underline_layer() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var wanted := hover_highlight and _is_underlined()
	var existing := parent.get_node_or_null("InkUnderline") as UIInkOutline.UnderlineLayer
	if not wanted:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		existing.outline = self
		existing.queue_redraw()
		return
	var layer := UnderlineLayer.new()
	layer.name = "InkUnderline"
	layer.outline = self
	parent.add_child(layer)
	parent.move_child(layer, parent.get_child_count() - 1)


## A bare surface whose only job is to be on the other side of the parent.
##
## It holds no state of its own -- the geometry, the seed and the sweep all live
## on the outline it belongs to, and this simply asks that node to paint onto it.
class UnderlineLayer extends Control:
	var outline: UIInkOutline = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("ui_style_exempt", true)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if outline != null and is_instance_valid(outline):
			outline.paint_underline(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var ink := UIPalette.color(&"stroke_strong", light_mode)
	var points := _outline_points()
	## The path closes by repeating its first point. A ribbon walks the ring
	## cyclically, so that duplicate would draw one zero-length quad at the seam.
	if points.size() > 1 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	if points.size() < 3:
		return
	var count := points.size()
	var shortest := minf(size.x, size.y)
	## Everything the ribbon needs, resolved once per point on the centreline.
	##
	## Per *point*, not per segment, and that is the whole of the rewrite. The
	## edge was drawn as a chain of independent antialiased `draw_line` calls,
	## which put three separate discontinuities at every joint: two overlapping
	## antialiased quads compositing into a darker blob, a width sampled fresh
	## for each segment, and an alpha sampled fresh as well. Measured on a
	## straight run, the stroke swelled from 2 to 4 pixels with its strongest
	## periodicity at exactly `SEGMENT_LENGTH` -- a regular bead every 14 px,
	## which over a halftone reads as cross-stitch rather than as ink.
	##
	## Resolving at the points and letting adjacent quads *share* their edge
	## vertices removes all three at once: nothing overlaps, and width and alpha
	## become continuous along the stroke instead of stepping at each seam.
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	normals.resize(count)
	widths.resize(count)
	alphas.resize(count)
	for index in range(count):
		var previous: Vector2 = points[(index - 1 + count) % count]
		var following: Vector2 = points[(index + 1) % count]
		var tangent := following - previous
		tangent = tangent.normalized() if tangent.length_squared() > 0.000001 \
			else Vector2.RIGHT
		normals[index] = tangent.orthogonal()
		var coverage := _coverage(index)
		widths[index] = _stroke_width(points[index], shortest, tangent) \
			* lerpf(COVERAGE_WIDTH_FLOOR, 1.0, coverage)
		alphas[index] = ink.a * coverage
	## The mark goes down first, under everything else this node draws.
	if hover_highlight and highlight_sweep > 0.001:
		_draw_highlight(highlight_sweep)
	if stroke_style == Stroke.STITCH:
		## Silhouette first, so the seam sits on top of the cloth it is holding.
		_draw_perforation()
		_draw_stitches(points, ink, shortest)
		_draw_fraying(points, ink)
		return
	## Two passes. `draw_polygon` has no antialiasing of its own, so a bare
	## ribbon has hard edges; a wider, fainter one underneath feathers them.
	_draw_ribbon(points, normals, widths, alphas, ink, FEATHER_PIXELS, FEATHER_ALPHA, true)
	_draw_ribbon(points, normals, widths, alphas, ink, 0.0, 1.0, true)


## One closed ribbon, as quads that share their edges with their neighbours.
##
## `widen` grows the half-width for the feathering pass; `alpha_scale` fades it.
func _draw_ribbon(
	points: PackedVector2Array,
	normals: PackedVector2Array,
	widths: PackedFloat32Array,
	alphas: PackedFloat32Array,
	ink: Color,
	widen: float,
	alpha_scale: float,
	closed: bool,
) -> void:
	var count := points.size()
	## A ring wraps; a single stitch is an open run and must not join its last
	## point back to its first.
	var last := count if closed else count - 1
	for index in range(last):
		var next_index := (index + 1) % count
		var here := widths[index] * 0.5 + widen
		var there := widths[next_index] * 0.5 + widen
		## Wound consistently so every quad faces the same way: out along one
		## edge, across, and back along the other.
		var quad := PackedVector2Array([
			points[index] + normals[index] * here,
			points[next_index] + normals[next_index] * there,
			points[next_index] - normals[next_index] * there,
			points[index] - normals[index] * here,
		])
		var near := Color(ink, alphas[index] * alpha_scale)
		var far := Color(ink, alphas[next_index] * alpha_scale)
		draw_polygon(quad, PackedColorArray([near, far, far, near]))


## One swipe of a chisel-tip highlighter across the control.
##
## The colour comes from the parent's own stylebox rather than from a constant
## here, so the theme stays the single place that decides what a primary action
## is coloured. The stylebox itself is transparent for these tiers -- this band
## *is* the fill, not a decoration over one.
func _draw_highlight(sweep: float) -> void:
	## Underlined controls paint nothing here -- their mark is on the layer in
	## front of the parent, which repaints itself off the same sweep.
	if _is_underlined():
		return
	var band := Color(_highlighter_ink(), HIGHLIGHT_ALPHA)
	## Where the band sat relative to the word this time, and whether the hand
	## ran level across it. Both drawn from the control's own seed.
	var drift := (_unit(53) - 0.5) * HIGHLIGHT_DRIFT
	var squeeze := (_unit(73) - 0.5) * HIGHLIGHT_DRIFT * 0.6
	var top := HIGHLIGHT_INSET + drift - squeeze
	var bottom := size.y - HIGHLIGHT_INSET + drift + squeeze
	var tilt := (_unit(97) - 0.5) * HIGHLIGHT_TILT
	## Where the hand started and stopped. Each end draws its own overshoot, so
	## one usually runs past the word and the other falls short of it.
	var behind := -HIGHLIGHT_OVERSHOOT * (_unit(11) * 2.2 - 0.7)
	var beyond := size.x + HIGHLIGHT_OVERSHOOT * (_unit(29) * 2.2 - 0.7)
	## Which end the swipe began at. Reversed, the tip enters from the right and
	## the band grows leftward -- same geometry, opposite travel.
	var reversed := _unit(131) < HIGHLIGHT_REVERSE_CHANCE
	var anchor := beyond if reversed else behind
	var far := behind if reversed else beyond
	## As far as the tip has travelled. The stroke is laid down, not faded in.
	var tip := lerpf(anchor, far, clampf(sweep, 0.0, 1.0))
	## The chisel. Both ends lean the same way, because the tip is held at one
	## angle for the whole stroke -- but not at the same angle on every control.
	var shear := HIGHLIGHT_SHEAR * (0.45 + _unit(157) * HIGHLIGHT_SHEAR_SPREAD)
	if reversed:
		shear = -shear
	var steps := maxi(int(size.x / 9.0), 4)
	## The band, and the denser leading edge inside it. A chisel lays down more
	## ink where it first touches down and drags less as it goes, so a second,
	## narrower pass along the top is what stops it reading as a flat rectangle.
	## Both are the same run of the tip, so they share one builder -- the lead
	## simply stops a third of the way down instead of at the bottom.
	draw_colored_polygon(
		_highlight_band(anchor, tip, shear, top, bottom, tilt, steps, 601, 1409),
		band
	)
	draw_colored_polygon(
		_highlight_band(
			anchor, tip, shear, top, lerpf(top, bottom, 0.34), tilt, steps,
			601, 2803, 0.4
		),
		Color(band, HIGHLIGHT_ALPHA * 0.28)
	)


## A rule drawn under a whole line, for controls a highlighter would be wrong on.
##
## Always left to right. The 30% chance of a reversed stroke is right for a
## highlighter -- a hand going back over a word does not always start at the same
## end -- and wrong here, because underlining is a reading gesture that follows
## the text, and a long row is exactly where a backwards stroke is most visible.
##
## The line lifts slightly at its far end rather than stopping square: a pen
## leaving the paper thins out, and the last few pixels of a flick are the part
## that says a hand did it.
func paint_underline(surface: CanvasItem) -> void:
	var travelled := clampf(highlight_sweep, 0.0, 1.0)
	if travelled <= 0.001:
		return
	var ink := Color(_highlighter_ink(), HIGHLIGHT_ALPHA * 2.4)
	var start := -UNDERLINE_OVERSHOOT
	var finish := size.x + UNDERLINE_OVERSHOOT
	var tip := lerpf(start, finish, travelled)
	## Where the rule sits, and how much it runs downhill -- both from the
	## control's own seed, so one row is not a copy of the row above it.
	var baseline := minf(
		size.y * UNDERLINE_BASELINE, size.y - UNDERLINE_EDGE_CLEARANCE
	) + (_unit(211) - 0.5) * 2.0
	var fall := (_unit(223) - 0.5) * 3.0

	var steps := maxi(int((tip - start) / 12.0), 2)
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var along := float(index) / float(steps)
		var x := lerpf(start, tip, along)
		var y := baseline + fall * along + _wander(index * 7 + 311)
		points.append(Vector2(x, y))
	if points.size() < 2:
		return
	surface.draw_polyline(points, ink, UNDERLINE_WIDTH, true)
	## The lift. Only once the stroke is most of the way across, because a pen
	## that thins from the moment it lands is a pen that never pressed down.
	if travelled > 0.72:
		var tail := points[points.size() - 1]
		var before := points[points.size() - 2]
		var direction := (tail - before).normalized()
		surface.draw_line(
			tail, tail + direction * 4.0,
			Color(ink, ink.a * 0.45), UNDERLINE_WIDTH * 0.6, true
		)


## One pass of the tip, as a closed strip: along the upper edge and back along
## the lower one, both wandering.
##
## `tilt` runs the whole band downhill or up across its travel, which is the
## difference between a mark somebody made and a rectangle somebody placed.
func _highlight_band(
	from: float,
	to: float,
	shear: float,
	top: float,
	bottom: float,
	tilt: float,
	steps: int,
	top_salt: int,
	bottom_salt: int,
	bottom_shear_share: float = -1.0,
) -> PackedVector2Array:
	var lower_shear := -shear if bottom_shear_share < 0.0 \
		else shear * bottom_shear_share
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var along := float(index) / float(steps)
		points.append(Vector2(
			lerpf(from + shear, to + shear, along),
			top + tilt * (along - 0.5)
				+ (_unit(index + top_salt) - 0.5) * HIGHLIGHT_EDGE_WAVE
		))
	for index in range(steps + 1):
		var along := 1.0 - float(index) / float(steps)
		points.append(Vector2(
			lerpf(from + lower_shear, to + lower_shear, along),
			bottom + tilt * (along - 0.5)
				+ (_unit(index + bottom_salt) - 0.5) * HIGHLIGHT_EDGE_WAVE
		))
	return points


## What this control gets marked in.
##
## The same ink the nib is using. A highlighter that contrasts with the line it
## covers is two marks arguing; one that matches is the same hand going back
## over its own writing, which is what a marked word actually looks like. It is
## also where the idea came from -- the nib's varying weight was what read as
## highlighter in the first place, so the wash belongs in its colour.
func _highlighter_ink() -> Color:
	return UIPalette.color(&"stroke_strong", UIPalette.control_is_light(self))


## What colour the surface underneath would have painted itself.
##
## Read from the parent's stylebox for the same reason the corner radii are:
## there should be one place that decides what a tier looks like, and a second
## copy of the palette here would be free to drift from it.
func _resolved_fill() -> Color:
	var parent := get_parent() as Control
	if parent != null:
		var variation := parent.theme_type_variation
		for style_name: StringName in [&"normal", &"panel"]:
			if not parent.has_theme_stylebox(style_name, variation):
				continue
			var box := parent.get_theme_stylebox(style_name, variation) as StyleBoxFlat
			if box != null:
				return box.bg_color
	return UIPalette.color(&"accent", UIPalette.control_is_light(self))


## Work the edge as a running stitch.
##
## Marks are laid along *arc length* rather than per path point, so their size
## and spacing are the same on a long side and a tight corner -- thread does not
## get shorter because the cloth turns. What the corners do instead is show
## their construction: a stitch is straight, so a rounded corner comes out as a
## visible fan of short chords rather than as a curve. That is how a real
## sampler handles a curve, and it is the detail that separates this from a
## dashed border.
func _draw_stitches(points: PackedVector2Array, ink: Color, shortest: float) -> void:
	var count := points.size()
	var cumulative := PackedFloat32Array()
	cumulative.resize(count + 1)
	cumulative[0] = 0.0
	for index in range(count):
		var here: Vector2 = points[index]
		var there: Vector2 = points[(index + 1) % count]
		cumulative[index + 1] = cumulative[index] + here.distance_to(there)
	var perimeter := cumulative[count]
	if perimeter < STITCH_LENGTH * 2.0:
		return
	## Rescale the pitch so a whole number of stitches closes the loop exactly.
	## A border that comes back round and overlaps its own first mark by a third
	## reads as a mistake; a sampler is counted out before it is sewn.
	var wanted := STITCH_LENGTH + STITCH_GAP
	var stitches := maxi(int(round(perimeter / wanted)), 3)
	var pitch := perimeter / float(stitches)
	var mark := pitch * STITCH_LENGTH / wanted
	for stitch in range(stitches):
		var start_distance := float(stitch) * pitch
		## Alternating either side of the true line, and a little shorter or
		## longer, so no two consecutive marks are identical.
		var side := 1.0 if stitch % 2 == 0 else -1.0
		var offset := side * STITCH_ALTERNATE_OFFSET \
			* (0.6 + _unit(stitch + 8123) * 0.8)
		var length := mark * (0.85 + _unit(stitch + 2711) * 0.3)
		_draw_one_stitch(
			points, cumulative, perimeter, start_distance, length, offset,
			ink, shortest, stitch
		)


## One mark: a short ribbon whose width swells at mid-span and tapers into the
## cloth at both ends.
func _draw_one_stitch(
	points: PackedVector2Array,
	cumulative: PackedFloat32Array,
	perimeter: float,
	start_distance: float,
	length: float,
	offset: float,
	ink: Color,
	shortest: float,
	stitch: int,
) -> void:
	var stitch_points := PackedVector2Array()
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	var coverage := _coverage(stitch)
	for step in range(STITCH_SEGMENTS + 1):
		var along := float(step) / float(STITCH_SEGMENTS)
		var distance := fposmod(start_distance + along * length, perimeter)
		var here := _point_at(points, cumulative, perimeter, distance)
		var ahead := _point_at(
			points, cumulative, perimeter, fposmod(distance + 0.75, perimeter)
		)
		var tangent := ahead - here
		tangent = tangent.normalized() if tangent.length_squared() > 0.000001 \
			else Vector2.RIGHT
		var normal := tangent.orthogonal()
		stitch_points.append(here + normal * offset)
		normals.append(normal)
		## The lens. `sin` over the mark rather than a triangle, so the taper
		## reads as thread rounding into the cloth rather than as a sharpened
		## pencil.
		var lens := lerpf(STITCH_END_RATIO, 1.0, sin(along * PI))
		widths.append(STITCH_WIDTH * lens)
		alphas.append(ink.a * coverage)
	_draw_ribbon(
		stitch_points, normals, widths, alphas, ink,
		FEATHER_PIXELS, FEATHER_ALPHA, false
	)
	_draw_ribbon(stitch_points, normals, widths, alphas, ink, 0.0, 1.0, false)


## The cut silhouette: tabs left where the patch was separated from its sheet.
##
## Regularly spaced, because a perforation is punched on a pitch -- this is the
## one place on the panel where evenness is correct rather than a tell. What
## varies is which tabs survived: some were torn away cleanly and some kept a
## stub, so a share of them are drawn short or skipped entirely.
##
## Drawn as *stubs* rather than as paper tabs, which is both closer to the
## reference and the only thing that reads. A tab in the card's own colour is
## invisible here -- card and page are within a few percent of each other in the
## light theme, so a silhouette with no line in it has no contrast to work with.
## And a cut cross-stitch template does not leave paper behind: it leaves short
## lengths of the wire that held it, which are line-like. So these are stubs in
## the thread's colour, standing off the edge at the perforation pitch.
func _draw_perforation() -> void:
	var ink := UIPalette.color(&"stroke_strong", UIPalette.control_is_light(self))
	var rect := Rect2(
		Vector2(EDGE_INSET, EDGE_INSET),
		size - Vector2(EDGE_INSET, EDGE_INSET) * 2.0
	)
	## Each side walked separately. The corners are left alone: a stamp's corner
	## is where the two perforations meet and neither one runs through it.
	var margin := PERFORATION_PITCH
	_perforate_run(
		Vector2(rect.position.x + margin, rect.position.y),
		Vector2(rect.end.x - margin, rect.position.y), Vector2.UP, ink, 0
	)
	_perforate_run(
		Vector2(rect.end.x, rect.position.y + margin),
		Vector2(rect.end.x, rect.end.y - margin), Vector2.RIGHT, ink, 97
	)
	_perforate_run(
		Vector2(rect.end.x - margin, rect.end.y),
		Vector2(rect.position.x + margin, rect.end.y), Vector2.DOWN, ink, 211
	)
	_perforate_run(
		Vector2(rect.position.x, rect.end.y - margin),
		Vector2(rect.position.x, rect.position.y + margin), Vector2.LEFT, ink, 349
	)


## One side's worth of tabs.
func _perforate_run(
	from: Vector2, to: Vector2, outward: Vector2, ink: Color, salt: int
) -> void:
	var span := from.distance_to(to)
	if span < PERFORATION_PITCH * 2.0:
		return
	var count := maxi(int(span / PERFORATION_PITCH), 1)
	var along := (to - from) / float(count)
	var across := Vector2(-outward.y, outward.x) * (PERFORATION_WIDTH * 0.5)
	for index in range(1, count):
		var roll := _unit(salt + index * 13)
		## A third of the tabs tore away flush. Their absence is what makes the
		## rest read as remnants rather than as a decorative scallop.
		if roll < 0.34:
			continue
		var centre := from + along * float(index)
		## Length varies with what survived the cut; direction leans a little,
		## because a snipped wire does not stay perpendicular.
		var depth := outward * PERFORATION_DEPTH * (0.5 + roll * 0.9)
		var lean := across.normalized() * (roll - 0.5) * PERFORATION_WIDTH * 0.4
		draw_line(
			centre, centre + depth + lean,
			Color(ink, ink.a * PERFORATION_ALPHA), PERFORATION_STUB_WIDTH, true
		)


## Loose threads, worked out of the weave at a few points around the edge.
##
## Drawn *outward* only, and short. A patch frays at its cut edge because the
## weave has nothing holding it there any more, so the strands stand off the
## boundary rather than lying across the panel. Two or three per point, splayed,
## because a single strand reads as a stray line rather than as fraying.
func _draw_fraying(points: PackedVector2Array, ink: Color) -> void:
	var count := points.size()
	for index in range(FRAY_COUNT):
		## Spread around the ring, then jittered, so the frays are not evenly
		## spaced -- cloth does not give way on a schedule.
		var position := int(
			(float(index) / float(FRAY_COUNT) + _unit(index + 6151) * 0.09)
			* float(count)
		) % count
		var here: Vector2 = points[position]
		var ahead: Vector2 = points[(position + 1) % count]
		var tangent := ahead - here
		if tangent.length_squared() < 0.000001:
			continue
		tangent = tangent.normalized()
		## Outward is the side away from the panel, which for a clockwise ring is
		## the *negative* normal.
		var outward := -tangent.orthogonal()
		var strands := 2 + int(_unit(index + 7717) * 2.0)
		for strand in range(strands):
			var seed_value := index * 31 + strand
			var splay := (_unit(seed_value + 1223) - 0.5) * 1.3
			var length := FRAY_LENGTH * (0.45 + _unit(seed_value + 4457) * 0.75)
			var direction := (outward + tangent * splay).normalized()
			## Curled rather than straight: a loose thread does not stand to
			## attention. The mid-point is pushed off the line so the strand
			## reads as slack.
			var tip := here + direction * length
			var bow := tangent * (splay * length * 0.35)
			var middle := here.lerp(tip, 0.55) + bow
			draw_polyline(
				PackedVector2Array([here, middle, tip]),
				Color(ink, ink.a * FRAY_ALPHA), FRAY_WIDTH, true
			)


## Where a given distance along the closed path falls, in local coordinates.
func _point_at(
	points: PackedVector2Array,
	cumulative: PackedFloat32Array,
	perimeter: float,
	distance: float,
) -> Vector2:
	var count := points.size()
	var target := clampf(distance, 0.0, perimeter)
	## Linear scan rather than a binary search: a panel edge is a couple of
	## hundred points and this runs once per redraw, not per frame.
	for index in range(count):
		if target <= cumulative[index + 1]:
			var span := cumulative[index + 1] - cumulative[index]
			var share := 0.0 if span < 0.0001 else (target - cumulative[index]) / span
			return Vector2(points[index]).lerp(
				Vector2(points[(index + 1) % count]), share
			)
	return points[0]


## The path the pen takes, already wandered.
##
## Built as one closed chain rather than four independent sides, so the corners
## join instead of meeting -- four separately jittered edges leave visible gaps
## exactly where a real line is heaviest.
func _outline_points() -> PackedVector2Array:
	## A drawn line sits on the edge; a seam sits in from it.
	var inset := EDGE_INSET + (SEAM_INSET if stroke_style == Stroke.STITCH else 0.0)
	var rect := Rect2(
		Vector2(inset, inset), size - Vector2(inset, inset) * 2.0
	)
	## Four radii, not one. The panel styleboxes deliberately round each corner
	## differently -- 9/20/12/16 on a card -- which is most of what stops them
	## reading as machine-cut rectangles, and a pen tracing one radius around all
	## four undoes exactly that.
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	var radii := _resolved_radii()
	var top_left := clampf(radii.x, 0.0, limit)
	var top_right := clampf(radii.y, 0.0, limit)
	var bottom_right := clampf(radii.z, 0.0, limit)
	var bottom_left := clampf(radii.w, 0.0, limit)
	## The ring in draw order, clockwise from the top: each side's straight run,
	## then the arc that turns onto the next side. A side's ends are set by the
	## two corners it runs between, so the runs shorten and lengthen with them.
	var side_starts := [
		rect.position + Vector2(top_left, 0.0),
		rect.position + Vector2(rect.size.x, top_right),
		rect.position + Vector2(rect.size.x - bottom_right, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - bottom_left),
	]
	var side_ends := [
		rect.position + Vector2(rect.size.x - top_right, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y - bottom_right),
		rect.position + Vector2(bottom_left, rect.size.y),
		rect.position + Vector2(0.0, top_left),
	]
	var arc_radii := [top_right, bottom_right, bottom_left, top_left]
	var arc_centres := [
		rect.position + Vector2(rect.size.x - top_right, top_right),
		rect.position
			+ Vector2(rect.size.x - bottom_right, rect.size.y - bottom_right),
		rect.position + Vector2(bottom_left, rect.size.y - bottom_left),
		rect.position + Vector2(top_left, top_left),
	]
	var outward := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var path := PackedVector2Array()
	var step := 0
	for side in range(4):
		var from: Vector2 = side_starts[side]
		var to: Vector2 = side_ends[side]
		var divisions := maxi(int(from.distance_to(to) / SEGMENT_LENGTH), 1)
		for division in range(divisions):
			step += 1
			path.append(
				from.lerp(to, float(division) / float(divisions))
					+ outward[side] * _wander(step)
			)
		var radius: float = arc_radii[side]
		if radius <= 0.5:
			continue
		## The turn onto the next side, walked around rather than cut across.
		##
		## This was a single straight segment between the two corner points --
		## a 45-degree chamfer. The stylebox behind it is rounded, so the panel's
		## own corner sat *outside* the ink and the one place the eye looks for
		## the hand was the one place the line was provably machine-made.
		var start_angle := -PI * 0.5 + float(side) * PI * 0.5
		var arc_steps := maxi(int(radius * PI * 0.5 / SEGMENT_LENGTH) + 1, 4)
		for division in range(arc_steps):
			var angle := start_angle \
				+ PI * 0.5 * float(division) / float(arc_steps)
			step += 1
			## Wander applied along the radius, so the pen strays off the curve
			## the same way it strays off a straight -- perpendicular to travel.
			path.append(
				arc_centres[side]
					+ Vector2(cos(angle), sin(angle)) * (radius + _wander(step))
			)
	if path.size() > 0:
		path.append(path[0])
	return path


## What radii the surface underneath actually uses, clockwise from the top left.
##
## Read from the parent's own stylebox rather than carried as constants here:
## the two themes are free to round their panels differently, and a pen that
## turns at a radius the panel does not use traces an edge that is not there.
## `corner_radius` stays as the fallback for a parent with no flat stylebox.
func _resolved_radii() -> Vector4:
	var parent := get_parent() as Control
	if parent != null:
		var variation := parent.theme_type_variation
		for style_name: StringName in [&"panel", &"normal"]:
			if not parent.has_theme_stylebox(style_name, variation):
				continue
			var box := parent.get_theme_stylebox(style_name, variation) as StyleBoxFlat
			if box != null:
				return Vector4(
					float(box.corner_radius_top_left),
					float(box.corner_radius_top_right),
					float(box.corner_radius_bottom_right),
					float(box.corner_radius_bottom_left),
				)
	return Vector4(corner_radius, corner_radius, corner_radius, corner_radius)


## How far off true the pen is at this point along the chain.
##
## Two hashed values at different rates summed, so the line drifts on a long
## wavelength and jitters on a short one -- a single frequency reads as a
## regular ripple, which is a spring rather than a hand.
func _wander(step: int) -> float:
	if stroke_style == Stroke.STITCH:
		return _cut_offset(step)
	var slow := _unit(step / 3 + 1) - 0.5
	var fast := _unit(step + 977) - 0.5
	return (slow * 1.4 + fast * 0.6) * WANDER_PIXELS


## Where a *cut* edge sits, as opposed to a drawn one.
##
## Held flat across a facet and then stepped, because that is what a blade does.
## Interpolating between facets would put the drift back and lose the whole
## point; the discontinuity is the shape of the cut.
func _cut_offset(step: int) -> float:
	var facet := step / CUT_FACET_STEPS
	var offset := (_unit(facet + 5171) - 0.5) * 2.0 * CUT_DEPTH_PIXELS
	if _unit(facet + 9277) < CUT_NICK_CHANCE:
		## A nick goes inward only. A blade that slipped takes cloth away; it
		## cannot add any.
		offset -= _unit(facet + 3391) * CUT_NICK_PIXELS
	return offset


## How much ink reached the paper on this segment.
##
## Cubed, so most of the stroke is fully inked and only occasionally does the
## ball run dry -- a linear draw would leave the whole line permanently patchy,
## which reads as a bad texture rather than as a pen. The slow term holds a dry
## stretch across several segments the way a real bearing does; the fast term is
## the grain within it.
func _coverage(index: int) -> float:
	var starve := _unit(index / COVERAGE_RUN + 313)
	var grain := _unit(index + 4409)
	var dry := pow(starve, 3.0) * 0.82 + pow(grain, 5.0) * 0.18
	return clampf(1.0 - COVERAGE_DEPTH * dry, 0.0, 1.0)


## Thicker where the hand slows: at the corners, and never in the middle of a
## straight run.
func _stroke_width(point: Vector2, shortest: float, tangent: Vector2) -> float:
	## The nib first: how much of its edge this direction of travel presents.
	##
	## `sin` of the angle between travel and the nib, so travelling across the
	## nib is 1 and along it is 0. Absolute, because a nib does not care which
	## way along its edge you go.
	var nib := deg_to_rad(NIB_ANGLE_DEGREES)
	var presented := absf(sin(tangent.angle() - nib))
	var base := STROKE_WIDTH * lerpf(NIB_MIN_RATIO, 1.0, presented)
	var corner_base := CORNER_WIDTH * lerpf(NIB_MIN_RATIO, 1.0, presented)
	var band := maxf(shortest * CORNER_SHARE, 6.0)
	var to_edge := minf(
		minf(point.x, size.x - point.x),
		minf(point.y, size.y - point.y)
	)
	var along := minf(
		maxf(point.x, size.x - point.x),
		maxf(point.y, size.y - point.y)
	)
	## Distance to the nearest corner, cheaply: a point is near one when it is
	## near two edges at once.
	var corner_proximity := 1.0 - clampf(
		(along - (maxf(size.x, size.y) - band)) / maxf(band, 1.0), 0.0, 1.0
	)
	if to_edge > band:
		corner_proximity = 0.0
	return lerpf(base, corner_base, corner_proximity)


## A stable 0-1 from this outline's seed and a step along its path.
##
## Hand-mixed rather than `randf()`: the edge has to be the same every frame or
## it shimmers, and the same across runs or a screenshot is not reproducible.
func _unit(step: int) -> float:
	var accumulated := (ink_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0
