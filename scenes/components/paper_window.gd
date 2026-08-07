class_name UIPaperWindow
extends Control

## A scrolling region as a slip of paper pushed under the page.
##
## Scrolling is the one interaction on this page with no physical answer yet.
## Everything else was made into an object -- the surfaces are patches, the
## controls are written, the section menu is a tape measure -- and then a
## region would quietly run out of room and hand the reader a grey bar from
## 1995. The bar says "there is more" in the vocabulary of a different program.
##
## Journals solve this with a slip: a strip of paper cut narrower than the page
## and threaded under two slits in it, so it can be pulled up and down inside
## its window. What you see is a rectangle of writing with the page lying over
## its top and bottom edges, and a tab poking back up through a third cut to
## pull it by. That is exactly a scroll region, and it needs no new affordance --
## the *page edge* is the affordance, because a sheet that disappears under
## another sheet is visibly continuing.
##
## So this draws three cuts. Two across the ends of the region, where the slip
## goes under; one down the side, which the tab comes up through. Every one of
## them is cut rather than ruled: a blade travels in short straight facets and
## occasionally leaves a nick, so the line steps instead of running true and its
## shadow steps with it. A clean line here is a printed rule, and a printed rule
## is a border rather than an opening.
##
## The real `ScrollBar` is left in place underneath, stripped to nothing by the
## theme. It still does the dragging, the clicking and the wheel; this only
## draws what the reader sees. Reimplementing scroll input to get a nicer
## grabber would be replacing a working mechanism to change its paint.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

## The slit at each end of the window: how dark the hairline is, how far the
## page's shadow falls into the region, and how much deeper it goes on the side
## that has something behind it.
const SLIT_WIDTH: float = 1.3
const SLIT_ALPHA: float = 0.60
const SHADOW_DEPTH: float = 8.0
const SHADOW_ALPHA: float = 0.34
## What the shadow is worth when nothing is hidden on that side. Not zero: the
## slip is threaded under the page at both ends whether or not it has been
## pulled, so both slits are always there -- one is just not covering anything.
const SHADOW_IDLE_SHARE: float = 0.30

## How a cut differs from a ruled line.
##
## The same model the panel edges use, and for the same reason: scissors do not
## wander, they hold a line for a few millimetres and then step to a new one,
## and every so often the blade is reopened and takes a nick out. That stepping
## is the whole of what reads as "somebody cut this" rather than "something
## drew this", and it has to show in the shadow as well as in the line -- a
## clean shadow under a jagged edge is two different cuts arguing.
const CUT_FACET_PIXELS: float = 7.0
const CUT_DEPTH_PIXELS: float = 1.1
const CUT_NICK_CHANCE: float = 0.14
const CUT_NICK_PIXELS: float = 2.4

## The pull tab.
##
## Long across the cut and short along it, because that is the shape of a thing
## that comes up through a slit and gets pushed along it: the width is what your
## finger has to catch, the height is the thickness of the slot it rides in. The
## first cut of this had it the other way round -- a tall bar in a track -- which
## is a scrollbar grabber wearing paper, not a tab.
const TAB_ACROSS: float = 26.0
const TAB_RADIUS: float = 2.5

## How long the tab is along its slot, and why it is not simply proportional.
##
## A scrollbar grabber's length is the share of the content on screen, and the
## tab should say the same thing: a slip threaded under a long page is a small
## tab in a long slot, and one under a page that nearly fits is almost as long as
## the slot itself. It was a flat 13 px, which said nothing about anything.
##
## Straight proportionality does not survive contact with the real regions.
## Measured across the journal, the clipboard, the folders and the planner with a
## career loaded, the three regions that actually scroll show 0.158, 0.770 and
## 0.891 of their own content on tracks of 449, 449 and 236 px -- so a
## `track * fraction` tab would be 71 px, 346 px and 210 px long against a tab
## 26 px wide. A 346x26 tab is not a tab; it is the bar in a track this shape was
## chosen to avoid, and the comment above says so.
##
## So the fraction is mapped into a band that stays tab-shaped at both ends. The
## ceiling is below `TAB_ACROSS` because the moment a tab is longer along the cut
## than it is across it, it stops reading as something pushed through a slit. The
## floor is what a pointer can still catch. Over the measured range that band
## prints 11.1 px, 18.9 px and 20.6 px -- a visible two-to-one, which is the
## readout the flat constant never gave.
const TAB_ALONG_MIN: float = 9.0
const TAB_ALONG_MAX: float = 21.0

## How far the cut it rides in is set in from the region's far edge, and how far
## short of the two window slits it stops.
const PULL_INSET: float = 15.0
const SLOT_END_MARGIN: float = 7.0

## The fold across the tab, where it turns back on itself after coming through.
const TAB_FOLD_ALPHA: float = 0.40

## The slip is a different sheet, and has to look like one.
##
## Everything else here says "there is paper under the page" -- the cuts, the
## shadow falling into them, the tab coming back through -- and then the region
## itself was exactly the colour of the card it was cut into, which quietly
## contradicts all of it. Two sheets the same colour are one sheet with lines
## drawn on it.
##
## So the slip takes the page's inset tone, mixed back toward the surface it
## lies under. Not `surface_inset` straight: that token is meant for a well
## sunk into the page and at full strength it is a hole, whereas a slip is a
## *sheet* -- something that came from a different pad, not somewhere the page
## stops.
const SLIP_INSET_SHARE: float = 0.55


## Whether this node paints the slip rather than the cuts over it.
##
## One script, two nodes on the same parent, because a `CanvasItem` draws either
## before its parent or after it and this needs both: the slip goes under the
## region's own text, and the cuts and their shadows go over it. A single node
## would have to pick, and picking "behind" puts the page's shadow *under* the
## words it is supposed to be falling across.
@export var backing: bool = false


## Which bars this region has. Resolved once at ready, because the answer comes
## from the parent's class rather than from its state.
var _vertical: ScrollBar = null
var _horizontal: ScrollBar = null
var _tracked: Control = null

## Which sheet of paper this is, for the cuts. Two regions side by side must not
## have been cut identically, and one region must be cut the same way every
## frame or its edges crawl.
var _seed: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("ui_style_exempt", true)
	var parent := get_parent() as Control
	if parent == null:
		return
	_seed = int(String(parent.name).hash() & 0x7FFFFFFF)
	if backing:
		show_behind_parent = true
	## A `Container` lays its children out and would fit this overlay to the
	## content area, then scroll it along with the content -- the window would
	## slide with the paper, which is the one thing a window must not do.
	## `top_level` takes it out of that pass; its rect is then synced by hand
	## from the parent's, below.
	if parent is Container:
		top_level = true
		_tracked = parent
		_sync_rect()
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.resized.connect(_on_parent_resized)
	if parent.has_method("get_v_scroll_bar"):
		_vertical = parent.call("get_v_scroll_bar") as ScrollBar
	if parent.has_method("get_h_scroll_bar"):
		_horizontal = parent.call("get_h_scroll_bar") as ScrollBar
	for bar: ScrollBar in [_vertical, _horizontal]:
		if bar != null:
			bar.value_changed.connect(func(_value: float) -> void: queue_redraw())
			bar.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _on_parent_resized() -> void:
	_sync_rect()
	queue_redraw()


## Keep a `top_level` overlay lying on its parent.
##
## Only the container case needs this, and only on resize: a `top_level` control
## reads its own position as global, so it is set from the parent's global rect
## rather than anchored to it.
func _sync_rect() -> void:
	if _tracked == null:
		return
	position = _tracked.global_position
	size = _tracked.size


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var light_mode := UIPalette.control_is_light(self)
	var ink := UIPalette.color(&"stroke_strong", light_mode)
	if backing:
		if _scrollable(_vertical) or _scrollable(_horizontal):
			_draw_slip(light_mode)
		return
	if _scrollable(_vertical):
		_draw_window(_vertical, true, ink)
		_draw_pull(_vertical, true, ink, light_mode)
	if _scrollable(_horizontal):
		_draw_window(_horizontal, false, ink)
		_draw_pull(_horizontal, false, ink, light_mode)


## The sheet itself, laid in the window before anything is written on it.
##
## Bounded by the cuts rather than by the control's rect, so its own edges are
## the ones the page was opened along -- a slip whose colour stops at a straight
## line half a pixel inside a jagged cut is two edges disagreeing about where the
## paper ends.
func _draw_slip(light_mode: bool) -> void:
	var surface := UIPalette.color(&"surface_raised", light_mode)
	var slip := surface.lerp(
		UIPalette.color(&"surface_inset", light_mode), SLIP_INSET_SHARE
	)
	var top := _cut_path(SLIT_WIDTH * 0.5 + 0.5, true, 1302) \
		if _scrollable(_vertical) else PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(size.x, 0.0)
		])
	var bottom := _cut_path(size.y - SLIT_WIDTH * 0.5 - 0.5, true, 2603) \
		if _scrollable(_vertical) else PackedVector2Array([
			Vector2(0.0, size.y), Vector2(size.x, size.y)
		])
	var sheet := PackedVector2Array(top)
	for index in range(bottom.size() - 1, -1, -1):
		sheet.append(bottom[index])
	draw_colored_polygon(sheet, slip)


## The tab's length along its slot: the share of the content this region shows,
## squeezed into the band that keeps it a tab rather than a bar.
##
## Inverse in the way that matters -- the more there is under the page, the less
## of it is on screen, and the smaller the tab that says so.
func _tab_along(bar: ScrollBar) -> float:
	var span := bar.max_value - bar.min_value
	if span <= 0.0:
		return TAB_ALONG_MAX
	return lerpf(TAB_ALONG_MIN, TAB_ALONG_MAX, clampf(bar.page / span, 0.0, 1.0))


## Whether this bar has anything to say. A region that fits its content is not a
## slip threaded under anything -- it is just writing on the page.
func _scrollable(bar: ScrollBar) -> bool:
	return bar != null and bar.max_value - bar.min_value > bar.page and bar.page > 0.0


## The two slits the slip goes under, and the page lying over them.
##
## A cut is drawn in ink; a shadow is not. The first version of this used the
## ink colour for both, which is right for the slit -- the page's edge is a line
## and the page is drawn in ink -- and exactly backwards for the fall beneath
## it. In the dark theme the ink is *light*, so the shadow of one sheet lying
## over another came out as a glow, and the region looked lit from underneath
## rather than covered. A shadow is the absence of light in either theme.
func _draw_window(bar: ScrollBar, vertical: bool, ink: Color) -> void:
	var span := bar.max_value - bar.min_value - bar.page
	## How much is hidden at each end, as a share of the scrollable distance.
	## The shadow is deeper where there is more behind the page, which turns the
	## decoration into a readout: a slip pushed nearly all the way up has a deep
	## shadow above it and almost none below.
	var before := 0.0 if span <= 0.0 else clampf(
		(bar.value - bar.min_value) / span, 0.0, 1.0
	)
	var across := size.y if vertical else size.x
	var salt := 0
	for entry in [[0.0, before, 1.0], [1.0, 1.0 - before, -1.0]]:
		var edge: float = entry[0]
		var hidden: float = entry[1]
		var inward: float = entry[2]
		salt += 1301
		## Pulled a hair inside the region so neither the line nor its shadow is
		## clipped away at the far edge.
		var at := across * edge + inward * (SLIT_WIDTH * 0.5 + 0.5)
		var path := _cut_path(at, vertical, salt)
		_draw_fall(
			path, vertical, inward,
			SHADOW_DEPTH * lerpf(SHADOW_IDLE_SHARE, 1.0, hidden)
		)
		draw_polyline(path, Color(ink, SLIT_ALPHA), SLIT_WIDTH, true)


## The third cut, running along the region, and the tab that comes up through it.
func _draw_pull(
	bar: ScrollBar, vertical: bool, ink: Color, light_mode: bool
) -> void:
	var track := size.y if vertical else size.x
	var span := bar.max_value - bar.min_value
	if span <= 0.0:
		return
	var at := (size.x if vertical else size.y) - PULL_INSET
	## The slot, cut down the page rather than along it, so it is perpendicular
	## to the two window slits and reads as a separate operation.
	## Stopped short of both window slits. Three cuts meeting at a point would
	## leave the corner of the page held on by nothing, which is a hole rather
	## than a slot -- and the paper knows it even if the reader only feels it.
	var slot := _cut_path(at, not vertical, 7717, SLOT_END_MARGIN)
	_draw_fall(slot, not vertical, 1.0, 3.0)
	_draw_fall(slot, not vertical, -1.0, 3.0)
	draw_polyline(slot, Color(ink, SLIT_ALPHA * 0.85), SLIT_WIDTH, true)
	## Where along the slot the tab has got to. The travel stops short of both
	## ends by half a tab, because a tab cannot leave the cut it is threaded
	## through.
	var reach := maxf(span - bar.page, 0.0001)
	var progress := clampf((bar.value - bar.min_value) / reach, 0.0, 1.0)
	var tab_along := _tab_along(bar)
	var along := lerpf(
		SLOT_END_MARGIN + tab_along * 0.5,
		track - SLOT_END_MARGIN - tab_along * 0.5,
		progress
	)
	var centre := Vector2(at, along) if vertical else Vector2(along, at)
	var half := (
		Vector2(TAB_ACROSS, tab_along) if vertical
		else Vector2(tab_along, TAB_ACROSS)
	) * 0.5
	var rect := Rect2(centre - half, half * 2.0)
	## Standing proud of the page, so it has a shadow of its own -- and needs
	## one. Cut in the same paper as the surface it lies on, it was invisible:
	## the fill matched what was behind it exactly and all that showed was the
	## outline, which is a drawn rectangle rather than a piece of card.
	draw_colored_polygon(
		_rounded(Rect2(rect.position + Vector2(0.0, 1.5), rect.size), TAB_RADIUS),
		Color(0.0, 0.0, 0.0, 0.22)
	)
	var paper := UIPalette.color(&"surface_raised", light_mode)
	paper = paper.darkened(0.09) if light_mode else paper.lightened(0.18)
	draw_colored_polygon(_rounded(rect, TAB_RADIUS), paper)
	draw_polyline(_rounded(rect, TAB_RADIUS), Color(ink, 0.55), 1.0, true)
	## The fold, down the middle of the tab: the crease it was bent along to get
	## it through the slot. It runs the same way the slot does, because it is the
	## line the paper turned on.
	var fold_half := (
		Vector2(TAB_ACROSS * 0.5 - 3.0, 0.0) if vertical
		else Vector2(0.0, TAB_ACROSS * 0.5 - 3.0)
	)
	draw_line(
		centre - fold_half, centre + fold_half,
		Color(ink, TAB_FOLD_ALPHA), 1.0, true
	)


## A blade's path across the region at a given offset.
##
## `vertical` says the cut runs left to right at height `at`; otherwise it runs
## top to bottom at abscissa `at`. Either way the offset is held flat for a
## facet and then stepped, never interpolated -- smoothing the steps out puts
## the drift back and turns the cut into a wobble, which is a hand with a pen
## rather than a hand with scissors.
func _cut_path(
	at: float, vertical: bool, salt: int, margin: float = 0.0
) -> PackedVector2Array:
	var start := margin
	var finish := (size.x if vertical else size.y) - margin
	var facets := maxi(int((finish - start) / CUT_FACET_PIXELS), 2)
	var path := PackedVector2Array()
	for index in range(facets + 1):
		var travel := lerpf(start, finish, float(index) / float(facets))
		## Two samples per facet boundary would round the step off; one per facet,
		## repeated at both of its ends, is what makes the edge stair rather than
		## slope.
		var facet := mini(index, facets - 1)
		var offset := (_unit(salt + facet * 31) - 0.5) * 2.0 * CUT_DEPTH_PIXELS
		if _unit(salt + facet * 31 + 7) < CUT_NICK_CHANCE:
			## A nick only ever takes material away, so it always goes the same
			## way -- into the page, which for both window slits means outward
			## from the region's middle.
			offset -= _unit(salt + facet * 31 + 13) * CUT_NICK_PIXELS
		path.append(
			Vector2(travel, at + offset) if vertical
			else Vector2(at + offset, travel)
		)
	return path


## The shadow the page casts into the region from a cut edge.
##
## Drawn as one quad per facet with the near edge opaque and the far edge clear,
## so the fall follows every step of the cut instead of running straight beneath
## a jagged line. `draw_polygon` takes per-vertex colours, which is what makes
## the gradient free.
func _draw_fall(
	path: PackedVector2Array, vertical: bool, inward: float, depth: float
) -> void:
	if depth <= 0.5 or path.size() < 2:
		return
	var offset := (
		Vector2(0.0, depth * inward) if vertical
		else Vector2(depth * inward, 0.0)
	)
	var near := Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	var far := Color(0.0, 0.0, 0.0, 0.0)
	for index in range(path.size() - 1):
		draw_polygon(
			PackedVector2Array([
				path[index], path[index + 1],
				path[index + 1] + offset, path[index] + offset,
			]),
			PackedColorArray([near, near, far, far])
		)


## A rounded rectangle as a closed ring of points, for filling and for outlining
## with the same geometry -- a fill and a border that disagree about their own
## corners is the tell that they were drawn by two different calls.
func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
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
	points.append(points[0])
	return points


## A stable 0-1 from this region's seed and a step along a cut.
##
## Hand-mixed rather than `randf()`: the edge has to be the same every frame or
## it crawls, and the same across runs or a screenshot is not reproducible.
func _unit(step: int) -> float:
	var accumulated := (_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0
