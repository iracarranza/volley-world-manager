class_name UIWorksheet
extends Control

## The workspace: a panel of graph paper on the clipboard, worked in pencil.
##
## Was a whiteboard, and that was the wrong object. **A whiteboard does not get
## clipped to a clipboard** -- the two are alternatives, not a stack, and the
## picture was of one lying on the other. What a coach actually clips down and
## carries is a sheet of squared paper with the court worked out on it in pencil,
## which is also why the squares are useful: the grid is a coordinate system you
## can count along, so "half a square further off the net" is a thing you can
## say and mean.
##
## Pencil rather than marker, and they behave differently in ways that matter
## more than colour:
##
## 1. **Graphite is not opaque and not uniform.** A pencil line is dense where
##    the tooth of the paper caught it and pale where it skipped, so a stroke is
##    broken along its length rather than solid. That break is the whole tell.
## 2. **The side of the tip is a different instrument from the point.** A point
##    draws a line; laid over, the same pencil shades a broad soft band with a
##    hard edge on one side and a feathered one on the other. Fills are shaded
##    that way here rather than hatched, because that is what a hand does when it
##    wants an area rather than a line.
## 3. **It can be erased, not wiped.** Changing the phase or the view lifts the
##    old working with an eraser and leaves the smudge a real eraser leaves, and
##    the grid *survives underneath* -- because the grid is printed and the
##    working is not, which is the same print-versus-hand split the whole
##    clipboard runs on.
##
## Deterministic and seeded, for the same reason the pen and the marker are: a
## wobble redrawn differently every frame is a shimmer, and a wobble shared by
## every stroke is a texture rather than a hand.

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const VoliStickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

## The sticker border, and the shadow that proves it has thickness.
##
## Constant weight is the point. Every other line on this sheet varies with the
## hand -- the tooth, the pressure drift, the wander -- and this one does not,
## because a die cut does not. That single difference is what separates a sticker
## lying *on* the paper from a drawing worked *into* it, and it is why the bodies
## can be bold while the court behind them stays quiet.
## The court, in the units it is actually built in.
##
## Every view drew its own geometry from shares of the panel, so the net was
## whatever fraction of the height that view's author picked -- 0.66 of the panel
## in the along-net view against roughly a third in three quarter, for the same
## 2.43 m of net. Two drawings of one object that disagree about its size are two
## objects.
##
## One scale per view instead, in pixels per metre, fitted to whatever the panel
## has. Then a net is 2.43 m in both because it is 2.43 m, and the check is
## arithmetic rather than eyesight.
const NET_HEIGHT_M: float = 2.43
const COURT_HALF_M: float = 9.0
const COURT_WIDTH_M: float = 9.0
## Headroom above the tape for a blocker's hands, and a margin so nothing touches
## the edge of the sheet.
const HEADROOM_M: float = 1.25
const MARGIN_SHARE: float = 0.08

const STICKER_BORDER: float = 3.4
const STICKER_SHADOW_OFFSET := Vector2(3.0, 4.0)
const STICKER_SHADOW_ALPHA: float = 0.26

signal phase_changed(phase: String)
signal view_changed(view: String)
signal zone_priority_changed(zone_index: int, priority: int)

## The phases a coach explains one at a time, in the order a rally travels them.
##
## Three, not four. Serve receive was its own page and should not have been: it
## is floor work -- the same six volis in the same plan view deciding where to
## stand -- and it had exactly one cell in the view matrix, which was the tell.
## Serving is the same argument pointed the other way: where you aim a serve is
## an attacking decision, not a phase of its own.
##
## Both survive as **overlays** on the phase that owns them, which is what they
## always were. That also empties two thirds of the matrix's holes, so the
## greying and the auto-switch have less to do.
const PHASES: Array[String] = ["Attack", "Block", "Floor"]

## The overlay each phase can carry, and whether it is on. An overlay is a second
## layer of marks on the same drawing rather than a different drawing -- the
## court does not change when you switch to serve targeting, only what is marked
## on it.
const OVERLAYS := {
	"Attack": "Serve target",
	"Floor": "Serve receive",
}

## And the ways of looking at the court. These are a **second, independent axis**
## rather than four more phases: what you can adjust is the intersection of what
## you are planning and where you are standing to look at it.
##
## Each view can only answer the questions its geometry actually contains, which
## is not a limitation to work around but the reason to have more than one:
##
## - **Top down** is a floor-shape view. Positions, lanes, funnels, coverage --
##   anything whose answer is an (x, y) on the court.
## - **Along the net** is an elevation, sighted down the tape. Heights and
##   distances *from* the net: set tightness, how far off the setter releases,
##   how tight a defender plays for the block follow.
## - **Three quarter** is neither, and that is its job. It is the only view where
##   depth and lateral position are both legible at once, so it is what you look
##   at to read a plan the other two authored rather than to author one.
const VIEW_TOP_DOWN: String = "Top down"
const VIEW_THREE_QUARTER: String = "Three quarter"
const VIEW_ALONG_NET: String = "Along the net"
const VIEWS: Array[String] = [VIEW_TOP_DOWN, VIEW_THREE_QUARTER, VIEW_ALONG_NET]

## Which phase can be adjusted from which view, and what the adjustment is.
##
## An empty cell is a **design gap, not a state to handle**. The greying and the
## auto-switch below exist because this table currently has holes in it; every
## hole filled is one fewer piece of interface behaviour that has to explain
## itself to the player. Written out rather than inferred so the holes are
## countable -- see `docs/design/TACTICS_AND_TRAINING.md` §0.10.
const ADJUSTMENTS := {
	VIEW_TOP_DOWN: {
		"Attack": "Lane priority",
		"Block": "Which way the block funnels",
		"Floor": "Where each defender stands",
	},
	VIEW_THREE_QUARTER: {
		"Block": "Who takes the seam, and how wide the wall sits",
	},
	VIEW_ALONG_NET: {
		"Attack": "Set tightness, and how far off the net the setter releases",
		"Floor": "How tight the back row plays for the block follow",
	},
}

## The point. Narrow -- a pencil is a fraction of a marker's width, and most of
## why the board read as a board rather than as paper was that every line on it
## was seven pixels wide.
##
## `MARKER_ANGLE_DEGREES` survives as the angle the tip is worn to: a pencil
## sharpened and then used develops a flat, and a stroke along that flat is wider
## than one across it. Weaker than a chisel marker's ratio, because a worn point
## is only slightly directional.
const MARKER_WIDTH: float = 2.6
const MARKER_MIN_RATIO: float = 0.62
const MARKER_ANGLE_DEGREES: float = 31.0
## Graphite is never solid. Kept low so crossings still darken -- two pencil
## lines over each other genuinely are darker -- but low enough that a single
## line reads as grey rather than as ink.
const MARKER_ALPHA: float = 0.62
## How far a hand strays over a run, and how long each drawn segment is. Shorter
## segments than the marker had, because the tooth is sampled per segment.
const MARKER_WANDER: float = 1.05
const MARKER_SEGMENT: float = 6.0

## The tooth of the paper.
##
## A pencil skips. `TOOTH_SKIP` is how much of a stroke's density is modulated by
## the grain, and `TOOTH_PITCH` is how quickly that grain varies along the run --
## fast enough to break the line, slow enough that it is not noise.
const TOOTH_SKIP: float = 0.42
const TOOTH_PITCH: float = 0.9

## Shading with the side of the tip.
##
## `SHADE_WIDTH` is in pixels and not a share of whatever is being filled, which
## is the mistake the first pass made: scaled to the bar it produced 40px slabs,
## and the side of a pencil is about a centimetre wide no matter how big the box
## is. Passes overlap at roughly two-thirds of their width, which is what turns
## separate strokes into a tone.
const SHADE_WIDTH: float = 9.0
const SHADE_STEP: float = 6.0
const SHADE_ALPHA: float = 0.26

## What a wipe leaves behind. Low, and lower than it first read: at 0.085 with
## the alpha bug above in play the previous heading was still legible under the
## new one and the board said "BLOCK RECEIVE".
const GHOST_ALPHA: float = 0.055

## The red pencil. A coach's second instrument, and on paper it is a pencil
## rather than a pen -- the same tooth, the same erasability, so it belongs to
## the sheet in a way a ballpoint would not. Softer and browner than the marker
## red it replaces, which was mixed to sit on white plastic.
const MARKER_RED := Color(0.70, 0.28, 0.24)

## Graph paper.
##
## The squares are printed, so they follow the *form's* rules and not the
## pencil's: fixed pitch in screen pixels, dead straight, and a heavier line every
## fifth square the way squared paper actually comes. They survive an erase,
## because print does.
const GRAPH_PITCH: float = 13.0
const GRAPH_MAJOR_EVERY: int = 5
const GRAPH_ALPHA: float = 0.20
const GRAPH_MAJOR_ALPHA: float = 0.34
const GRAPH_INK_LIGHT := Color(0.42, 0.55, 0.62)
const GRAPH_INK_DARK := Color(0.46, 0.58, 0.68)

## The zone-priority bars. Four zones, each 0 to 3, scrolled to change.
const ZONE_COUNT: int = 4
const ZONE_MAX_PRIORITY: int = 3
const ZONE_LABELS: Array[String] = ["Line", "Seam", "Cross", "Tip"]

var phase: String = "Block"
var view: String = VIEW_THREE_QUARTER
## Whether the current phase's overlay is showing. One flag, not one per phase:
## only one phase is on the board at a time, and an overlay belongs to what is
## being looked at rather than being remembered per page.
var overlay_on: bool = false
## Where volis have been dropped, in unit court space, keyed by tray slot.
var placements: Dictionary = {}
var zone_priorities: Array[int] = [3, 2, 1, 2]
var light_mode: bool = true

## The layout being wiped away, and how far the squeegee has got. Nothing is
## drawn from these except the ghost; the board does not animate two live
## layouts at once, because a coach does not either.
var _ghost_phase: String = ""
var _wipe: float = 1.0
var _wipe_tween: Tween = null
var _hovered_zone: int = -1
var _seed: int = 0
var _stickers: UIVoliSticker = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## The board paints itself from the palette, so it has to be told which
	## theme is up. `UIStyleSystem.apply` walks the tree on every switch but only
	## restyles nodes it recognises, and a hand-painted exempt node is not one --
	## so the board reads the theme off its own ancestry instead, the same way
	## `UIBackdrop` does, and refreshes when the tree tells it to.
	theme_changed.connect(_sync_theme)
	_sync_theme()
	## Painted by hand end to end. The style pass would give the board a drawn
	## paper edge and a halftone wash, which is the wrong material -- a board is
	## smooth, and its edge is a tray rather than a torn sheet.
	set_meta("ui_style_exempt", true)
	custom_minimum_size = Vector2(420.0, 300.0)
	_seed = int(String(name).hash() & 0x7FFFFFFF)
	resized.connect(queue_redraw)
	## The bake needs frames, so it cannot happen inside `_draw`. Ask for the
	## poses now and redraw when each lands; until then the figures simply are not
	## there, which is honest -- a half-traced body would be worse than none.
	_stickers = VoliStickerScript.new()
	_stickers.name = "VoliStickers"
	add_child(_stickers)
	_stickers.sticker_ready.connect(_on_sticker_ready)
	_request_stickers()


## Re-emitted so a screen can populate a tray from the same bake queue rather
## than standing up a second one.
signal sticker_baked(key: String)


func _on_sticker_ready(key: String) -> void:
	sticker_baked.emit(key)
	queue_redraw()


func stickers() -> UIVoliSticker:
	return _stickers


## The poses the sheet draws, asked for once.
##
## Two blockers rather than one sticker used twice: they are different volis, and
## the whole reason to trace the rig is that a 201 cm middle and a 186 cm wing
## come out as visibly different people. The profiles are placeholders until the
## sheet is reading a real lineup.
## Where the camera stands for each view, so a body is seen from where the
## drawing is seen from. A sticker baked head-on and dropped into a plan view is
## a figure standing up out of the floor.
const BAKE_ANGLES := {
	VIEW_TOP_DOWN: Vector2(0.0, -62.0),
	VIEW_THREE_QUARTER: Vector2(-14.0, -8.0),
	VIEW_ALONG_NET: Vector2(-78.0, -4.0),
}

## How high the baked blockers are jumping, shared by the bake and the placement
## so the two cannot drift.
const BLOCK_ELEVATION: float = 0.85

const BLOCKER_PROFILES := [
	{
		"key": "tall", "height_cm": 201.0, "wingspan_cm": 209.0,
		"stride_length_m": 0.93, "body_type": "Vegi", "dominant_hand": "Right",
		"standing_reach_meters": 2.62, "jumping_reach_meters": 3.42,
	},
	{
		"key": "wing", "height_cm": 186.0, "wingspan_cm": 190.0,
		"stride_length_m": 0.84, "body_type": "Cani", "dominant_hand": "Left",
		"standing_reach_meters": 2.44, "jumping_reach_meters": 3.24,
	},
]


func _sticker_key(who: String, for_view: String) -> String:
	return "%s_%s" % [who, for_view.replace(" ", "_")]


## Every pose the sheet can show, from every angle it can be looked at.
##
## Baked up front rather than on the view change: six bakes at roughly ten
## milliseconds each is a blink at startup, and doing it lazily would put that
## blink in the middle of a view toggle, which is where it would be felt.
func _request_stickers() -> void:
	for for_view in VIEWS:
		var angles: Vector2 = BAKE_ANGLES.get(for_view, Vector2.ZERO)
		for profile in BLOCKER_PROFILES:
			var built: Dictionary = (profile as Dictionary).duplicate()
			_stickers.request(
				_sticker_key(str(built["key"]), for_view),
				RallyEventModel.EventType.BLOCK, BLOCK_ELEVATION, 0.0,
				built, angles.x, angles.y
			)


## Lay a baked sticker down: shadow, shaded body, then the cut border.
## `feet` is where the body touches the floor, not where its middle is.
##
## Anchoring by the centre meant the figure's contact point moved whenever the
## pose or the crop changed, so a blocker floated a good forty pixels above the
## shadow drawn at their own feet. Anchoring by the bottom of the box makes the
## two agree by construction rather than by a constant somebody tuned.
func _draw_sticker(key: String, feet: Vector2, height: float) -> bool:
	if _stickers == null:
		return false
	var built: UIVoliSticker.Sticker = _stickers.sticker(key)
	if built == null or built.contours.is_empty():
		return false
	var box := Vector2(height * built.aspect, height)
	var origin := feet - Vector2(box.x * 0.5, box.y)

	## 1. The shadow. Without it a sticker is a shape with a thick outline; with
	## it the shape is above the paper.
	for contour in built.contours:
		var shadowed := PackedVector2Array()
		for point in (contour as PackedVector2Array):
			shadowed.append(origin + point * box + STICKER_SHADOW_OFFSET)
		if shadowed.size() >= 3:
			draw_colored_polygon(shadowed, Color(0.0, 0.0, 0.0, STICKER_SHADOW_ALPHA))

	## 2. The body, carrying the mesh's own light and shade.
	if built.texture != null:
		draw_texture_rect(built.texture, Rect2(origin, box), false)

	## 3. The cut edge, at constant weight, hugging its own outline.
	for contour in built.contours:
		var edge := PackedVector2Array()
		for point in (contour as PackedVector2Array):
			edge.append(origin + point * box)
		if edge.size() >= 3:
			draw_polyline(edge, _ink(), STICKER_BORDER, true)
			draw_line(edge[edge.size() - 1], edge[0], _ink(), STICKER_BORDER, true)
	return true


func set_light_mode(value: bool) -> void:
	light_mode = value
	queue_redraw()


func _sync_theme() -> void:
	light_mode = UIPalette.control_is_light(self)
	queue_redraw()


## Choose a phase: squeegee what is there, then draw the new one.
func set_phase(value: String) -> void:
	if value == phase or not value in PHASES:
		return
	_ghost_phase = phase
	phase = value
	phase_changed.emit(phase)
	_start_wipe()


func _start_wipe() -> void:
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()
	_wipe = 0.0
	_wipe_tween = create_tween()
	_wipe_tween.tween_method(_set_wipe, 0.0, 1.0, 0.34)
	_wipe_tween.set_ease(Tween.EASE_OUT)
	_wipe_tween.set_trans(Tween.TRANS_CUBIC)


## Change where the court is being looked at. Wipes and redraws, exactly like a
## phase change -- a coach rubbing out a plan view and drawing the same thing from
## the end of the net is doing one action, not two.
func set_view(value: String) -> void:
	if value == view or not value in VIEWS:
		return
	_ghost_phase = phase
	view = value
	view_changed.emit(view)
	_start_wipe()


## What this view can say about this phase, or an empty string if it cannot.
static func adjustment_for(for_view: String, for_phase: String) -> String:
	var by_phase: Dictionary = ADJUSTMENTS.get(for_view, {})
	return str(by_phase.get(for_phase, ""))


## The first phase this view has anything to say about, in rally order.
static func first_phase_for(for_view: String) -> String:
	for candidate in PHASES:
		if not adjustment_for(for_view, candidate).is_empty():
			return candidate
	return ""


## The overlay this phase owns, or an empty string.
static func overlay_for(for_phase: String) -> String:
	return str(OVERLAYS.get(for_phase, ""))


func set_overlay(enabled: bool) -> void:
	if overlay_on == enabled:
		return
	overlay_on = enabled
	queue_redraw()


## Put a voli on the court at a unit position.
func place_voli(slot: int, at: Vector2) -> void:
	placements[slot] = at
	queue_redraw()


func _set_wipe(value: float) -> void:
	_wipe = value
	queue_redraw()


## Scrolling over a bar changes that zone's priority.
##
## The control the planner had for this was an `OptionButton` reading "P2 ·
## Seam", which is the value written out as text -- three clicks and a menu to
## change a number whose whole meaning is how it compares to the other three.
## Four bars answer that at a glance, and a wheel changes one without leaving it.
func _gui_input(event: InputEvent) -> void:
	if phase != "Block":
		return
	if event is InputEventMouseMotion:
		var was := _hovered_zone
		_hovered_zone = _zone_at((event as InputEventMouseMotion).position)
		if was != _hovered_zone:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	var index := _zone_at(button.position)
	if index < 0:
		return
	var step := 0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 1
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -1
	if step == 0:
		return
	zone_priorities[index] = clampi(
		zone_priorities[index] + step, 0, ZONE_MAX_PRIORITY
	)
	zone_priority_changed.emit(index, zone_priorities[index])
	accept_event()
	queue_redraw()


func _exit_tree() -> void:
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	## Read at draw time rather than trusted from a signal.
	##
	## `theme_changed` is connected and does fire, but the first draft trusted it
	## alone and the board rendered dark inside Molten -- one lookup that was
	## stale by a frame, on the one node whose entire surface is a colour. A
	## theme colour lookup per redraw is nothing next to a few hundred strokes,
	## and it cannot be out of date.
	light_mode = UIPalette.control_is_light(self)
	draw_rect(Rect2(Vector2.ZERO, size), _board_color())
	_draw_graph()

	## The previous working, still faintly there. An eraser lifts graphite; it
	## does not remove it, and what is left is exactly this.
	if not _ghost_phase.is_empty():
		_draw_phase(_ghost_phase, GHOST_ALPHA * (2.0 - _wipe))

	_draw_phase(phase, 1.0, _wipe)
	if _wipe < 1.0:
		_draw_eraser(_wipe)


## The printed squares.
##
## Fixed pitch in screen pixels rather than as a fraction of the panel, for the
## same reason the form's grid is: a press does not rescale its grid to fit the
## sheet, and two panels sharing one grid is most of what makes it read as
## printed. Every fifth line is heavier, which is what squared paper does and
## what makes it countable -- the whole reason to work a court out on it.
func _draw_graph() -> void:
	var ink := GRAPH_INK_LIGHT if light_mode else GRAPH_INK_DARK
	var index := 1
	var x := GRAPH_PITCH
	while x < size.x:
		var major := index % GRAPH_MAJOR_EVERY == 0
		draw_line(
			Vector2(x, 0.0), Vector2(x, size.y),
			Color(ink, GRAPH_MAJOR_ALPHA if major else GRAPH_ALPHA), 1.0
		)
		x += GRAPH_PITCH
		index += 1
	index = 1
	var y := GRAPH_PITCH
	while y < size.y:
		var major := index % GRAPH_MAJOR_EVERY == 0
		draw_line(
			Vector2(0.0, y), Vector2(size.x, y),
			Color(ink, GRAPH_MAJOR_ALPHA if major else GRAPH_ALPHA), 1.0
		)
		y += GRAPH_PITCH
		index += 1


## The eraser, travelling left to right, lifting the working as it goes.
##
## A squeegee had a bright leading edge because it is wet. An eraser is dry and
## does the opposite: it leaves a band of *smudge* behind it, graphite pushed
## rather than removed, which fades over the following second.
func _draw_eraser(progress: float) -> void:
	var x := size.x * progress
	var rubber := Color(0.94, 0.86, 0.78) if light_mode else Color(0.52, 0.46, 0.42)
	var smudge := Color(_ink(), 0.10)
	draw_rect(Rect2(x - 34.0, 0.0, 34.0, size.y), smudge)
	draw_rect(Rect2(x - 13.0, size.y * 0.32, 13.0, size.y * 0.30), rubber)
	draw_rect(
		Rect2(x - 13.0, size.y * 0.32, 13.0, size.y * 0.30),
		Color(rubber.darkened(0.30), 0.7), false, 1.0
	)


func _draw_phase(which: String, alpha: float, reveal: float = 1.0) -> void:
	match view:
		VIEW_TOP_DOWN:
			_draw_top_down(which, alpha, reveal)
		VIEW_ALONG_NET:
			_draw_along_net(which, alpha, reveal)
		_:
			_draw_three_quarter(which, alpha, reveal)


func _draw_three_quarter(which: String, alpha: float, reveal: float) -> void:
	## Three quarter draws the wall whatever the phase, because that is the only
	## thing this angle is better at than the other two. A phase with nothing to
	## adjust from here still gets the picture -- the view is for reading.
	_draw_block_phase(alpha, reveal)
	if which != "Block":
		_marker_text(
			"%s — nothing to set from here" % which.to_upper(),
			Vector2(size.x * 0.06, size.y * 0.95), 13,
			_ink(), alpha * 0.6, reveal
		)


## Sighted straight down the tape from the antenna: the net is a line, and what
## the view is *for* is everything measured perpendicular to it.
func _draw_along_net(which: String, alpha: float, reveal: float) -> void:
	var ink := _ink()
	var board_bottom := size.y - 13.0

	## Sighting down the tape: what runs across the sheet is the **depth of both
	## courts** -- nine metres either side of the net -- and what runs up it is
	## height. One scale for both, so the net is 2.43 m of an eighteen-metre span
	## and not two thirds of the panel, which is what it was.
	##
	## That was the disproportion: this view sized the net off `size.y` and the
	## three-quarter view sized it off its own share, so the same net came out
	## roughly twice as tall here.
	## Six metres either side rather than the full nine.
	##
	## A crop, not a distortion -- the scale is still one number for both axes, so
	## the net is still 2.43 m. But nothing this view exists to measure lives
	## beyond six metres: set tightness is under a metre off the tape, a setter
	## releases inside three, and the deepest defender this view has an opinion
	## about is at six. Fitting eighteen metres in put all of that in the middle
	## third of the sheet and left the net a hundred pixels tall in a panel three
	## times that.
	const ALONG_NET_REACH_M: float = 6.0
	var scale := _metres(
		Vector2(ALONG_NET_REACH_M * 2.0, NET_HEIGHT_M + HEADROOM_M)
	)
	var floor_y := board_bottom - size.y * 0.08
	var net_x := size.x * 0.5
	var tape_top := floor_y - NET_HEIGHT_M * scale

	_marker_text(which.to_upper(), Vector2(size.x * 0.05, size.y * 0.13), 24, ink, alpha, reveal)

	## Not quite square on.
	##
	## At a true 90 degrees the net is one line and the far half of the court does
	## not exist -- geometrically honest and useless, because the reason to sight
	## down the tape is to measure distances *from* it and a viewer with no far
	## side has nothing to measure them against. A couple of degrees opens the net
	## into a narrow band and brings the far court into frame, at almost no cost to
	## the near-side distances this view exists to show.
	## Lifted off the floor plane, not just off square.
	##
	## Two degrees of yaw opened the net into a band but left the eye level with
	## the floor, so the near and far halves of the court lay on the same line and
	## only one of them could be drawn. Raising the viewpoint separates them: the
	## far sideline rises away from the near one, and the strip between the two
	## *is* the court, which is what makes a defender's depth something you can
	## point at rather than infer.
	##
	## `rise` is how far a metre of depth away from the viewer lifts on the page.
	## Small: this view still measures heights against the net, and a steep lift
	## would foreshorten exactly the axis it exists to show.
	## The offset a metre of depth away from the viewer gets on the page, as one
	## vector: sideways and up. Both together read as a court receding; the lift
	## alone reads as a court standing on its edge, which is what 0.16 gave --
	## nine metres of it lifted the far sideline a hundred pixels and took the net
	## with it, so a 2.43 m net drew twice its own height.
	var yaw := NET_HEIGHT_M * scale * 0.30
	var rise := 0.055

	## The court as a band between two sidelines rather than as one rule. The near
	## line is where the viewer stands; the far one is nine metres across the
	## court and lifted by the raised viewpoint.
	var far_lift := COURT_WIDTH_M * scale * rise
	var near_left := Vector2(size.x * 0.05, floor_y)
	var near_right := Vector2(size.x * 0.95, floor_y)
	var far_left := near_left + Vector2(yaw, -far_lift)
	var far_right := near_right + Vector2(yaw, -far_lift)
	_marker_line(near_left, near_right, ink, alpha, reveal, 3, MARKER_WIDTH * 1.2)
	_marker_line(far_left, far_right, Color(ink, 0.52), alpha, reveal, 9, MARKER_WIDTH * 0.8)
	## The two ends, closing the band into a floor.
	_marker_line(near_left, far_left, Color(ink, 0.34), alpha, reveal, 17, MARKER_WIDTH * 0.5)
	_marker_line(near_right, far_right, Color(ink, 0.34), alpha, reveal, 19, MARKER_WIDTH * 0.5)
	## The attack lines three metres either side, drawn right across the band so
	## they read as lines on a floor rather than as ticks on a rule.
	for side: float in [-1.0, 1.0]:
		var at: float = net_x + side * 3.0 * scale
		_marker_line(
			Vector2(at, floor_y), Vector2(at + yaw, floor_y - far_lift),
			Color(ink, 0.44), alpha, reveal, 5 + int(side * 3.0), MARKER_WIDTH * 0.55
		)
	## Metre marks along the floor, which is what turns a line into a ruler -- and
	## this view is a ruler before it is anything else.
	for metre in range(-6, 7):
		if metre == 0:
			continue
		var tick := net_x + float(metre) * scale
		_marker_line(
			Vector2(tick, floor_y), Vector2(tick, floor_y + (7.0 if metre % 3 == 0 else 4.0)),
			Color(ink, 0.40 if metre % 3 == 0 else 0.24), alpha, reveal,
			200 + metre, MARKER_WIDTH * 0.35
		)
	_marker_text(
		"near", Vector2(size.x * 0.06, floor_y - 6.0), 11, Color(ink, 0.55), alpha, reveal
	)
	_marker_text(
		"far", Vector2(size.x * 0.06 + yaw, floor_y - far_lift - 6.0), 11,
		Color(ink, 0.45), alpha, reveal
	)

	## The net as a narrow band: near tape, far tape, mesh between.
	var near_top := Vector2(net_x, tape_top)
	var near_foot := Vector2(net_x, floor_y)
	## The net crosses the whole band, so its far foot sits on the far sideline.
	var far_top := near_top + Vector2(yaw, -far_lift)
	var far_foot := near_foot + Vector2(yaw, -far_lift)
	_marker_line(near_top, near_foot, ink, alpha, reveal, 11, MARKER_WIDTH * 1.5)
	_marker_line(far_top, far_foot, Color(ink, 0.58), alpha, reveal, 13, MARKER_WIDTH * 0.9)
	_marker_line(near_top, far_top, ink, alpha, reveal, 15, MARKER_WIDTH * 1.2)
	for step in range(1, 8):
		var down := float(step) / 8.0
		_marker_line(
			near_top.lerp(near_foot, down), far_top.lerp(far_foot, down),
			Color(ink, 0.22), alpha, reveal, 60 + step, MARKER_WIDTH * 0.40
		)
	## The padded post beyond the far tape, hatched like the three-quarter one so
	## the two views agree about what a post is made of.
	_hatch(
		Rect2(Vector2(net_x + yaw - 4.0, floor_y - NET_HEIGHT_M * scale * 0.62),
			Vector2(8.0, NET_HEIGHT_M * scale * 0.62)),
		Color(ink, 0.30), alpha, reveal, 91
	)
	_marker_text(
		"2.43", Vector2(net_x + yaw + 9.0, tape_top + 4.0), 12,
		Color(ink, 0.7), alpha, reveal
	)

	match which:
		"Attack":
			## Set tightness is a horizontal distance from the tape, and the
			## setter's release is another -- both are exactly what this view
			## measures and neither is visible from above.
			var release := net_x - size.x * 0.16
			var apex := Vector2(release + size.x * 0.05, tape_top - size.y * 0.10)
			_marker_line(
				Vector2(release, floor_y), Vector2(release, floor_y - size.y * 0.18),
				ink, alpha, reveal, 11, MARKER_WIDTH * 0.7
			)
			_marker_text("S", Vector2(release - 5.0, floor_y - size.y * 0.20), 15, ink, alpha, reveal)
			var arc := PackedVector2Array()
			for step in range(17):
				var t := float(step) / 16.0
				var point := Vector2(release, floor_y - size.y * 0.20).lerp(
					Vector2(net_x - size.x * 0.03, tape_top + size.y * 0.03), t
				)
				point.y -= sin(t * PI) * size.y * 0.16
				arc.append(point)
			_marker_stroke(arc, MARKER_RED, alpha, reveal, 13, MARKER_WIDTH * 0.8, false)
			_draw_measure(
				Vector2(net_x, tape_top - 18.0), Vector2(release, tape_top - 18.0),
				"release", ink, alpha, reveal, 17
			)
			_draw_measure(
				Vector2(net_x, apex.y), Vector2(net_x - size.x * 0.05, apex.y),
				"tightness", MARKER_RED, alpha, reveal, 19
			)
		"Floor":
			## How tight the back row plays: a distance from the net, which is the
			## same axis and the reason both live on this view.
			for entry in [[0.20, "follow"], [0.34, "deep"]]:
				var share: float = entry[0]
				var label: String = entry[1]
				var at := net_x + size.x * share
				_marker_circle(Vector2(at, floor_y - 14.0), 11.0, ink, alpha, reveal, 31 + int(share * 100.0))
				_draw_measure(
					Vector2(net_x, floor_y + 16.0), Vector2(at, floor_y + 16.0),
					label, MARKER_RED if share < 0.3 else ink, alpha, reveal,
					41 + int(share * 100.0)
				)
		_:
			_marker_text(
				"%s — nothing to set from here" % which.to_upper(),
				Vector2(size.x * 0.06, size.y * 0.95), 13, ink, alpha * 0.6, reveal
			)


## The floor under a three-quarter net: the centre line beneath the tape, the
## attack line three metres back, and the near sideline. Enough to stand on.
func _draw_floor_three_quarter(
	origin: Vector2, span: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	var scale := span.y / NET_HEIGHT_M
	## Depth is drawn through the same axonometric map the net uses, so the floor
	## and the net cannot disagree about where the far side is.
	for entry in [[0.0, 0.62, 131], [3.0 / COURT_HALF_M * 1.9, 0.34, 137]]:
		var depth: float = entry[0]
		var weight: float = entry[1]
		var salt: int = entry[2]
		_marker_line(
			_net_point(origin, span, -0.04, 0.0, depth),
			_net_point(origin, span, 1.04, 0.0, depth),
			Color(ink, weight), alpha, reveal, salt, MARKER_WIDTH * 0.7
		)
	for u in [-0.04, 1.04]:
		_marker_line(
			_net_point(origin, span, u, 0.0, 0.0),
			_net_point(origin, span, u, 0.0, 3.0 / COURT_HALF_M * 1.9),
			Color(ink, 0.34), alpha, reveal, 141 + int(u * 10.0), MARKER_WIDTH * 0.5
		)


## Serve target, or serve receive, marked over whatever court is already drawn.
##
## Both are the same gesture from opposite ends -- an arrow into a zone you want
## the ball in, or a shape over the zone you are covering -- so they share a
## routine and differ in direction and colour.
func _draw_serve_overlay(
	court: Rect2, which: String, ink: Color, alpha: float, reveal: float
) -> void:
	if which == "Attack":
		var from := court.position + Vector2(court.size.x * 0.5, court.size.y * 1.06)
		for target in [Vector2(0.16, 0.22), Vector2(0.84, 0.26)]:
			_marker_arrow(
				from, court.position + court.size * target,
				MARKER_RED, alpha * 0.9, reveal, 301 + int(target.x * 90.0)
			)
		_marker_text(
			"serve target", from + Vector2(-30.0, 16.0), 12, MARKER_RED, alpha, reveal
		)
		return
	## Serve receive: the three-passer seam, shaded rather than arrowed, because
	## what is being declared is an area of responsibility and not a direction.
	for share in [0.24, 0.52, 0.80]:
		_marker_ellipse(
			court.position + court.size * Vector2(share, 0.70),
			Vector2(court.size.x * 0.15, court.size.y * 0.14),
			Color(ink, 0.5), alpha, reveal, 321 + int(share * 100.0)
		)
	_hatch(
		Rect2(court.position + court.size * Vector2(0.32, 0.56),
			court.size * Vector2(0.20, 0.30)),
		Color(MARKER_RED, 0.30), alpha, reveal, 341
	)
	_marker_text(
		"seam", court.position + court.size * Vector2(0.34, 0.52), 12,
		MARKER_RED, alpha, reveal
	)


## Cross-hatching: two crossing sets of strokes. One direction is texture; two
## are shadow, and the difference is the whole reason to bother.
func _hatch(
	area: Rect2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	if area.size.x < 3.0 or area.size.y < 3.0:
		return
	var pitch := 5.5
	var steps := int((area.size.x + area.size.y) / pitch)
	for step in range(steps):
		var offset := float(step) * pitch
		var a := Vector2(area.position.x + offset, area.position.y)
		var b := a + Vector2(-area.size.y, area.size.y)
		_marker_line(
			a.clamp(area.position, area.end), b.clamp(area.position, area.end),
			color, alpha, reveal, salt + step, MARKER_WIDTH * 0.32
		)
	for step in range(0, steps, 2):
		var offset := float(step) * pitch
		var a := Vector2(area.position.x + offset - area.size.y, area.position.y)
		var b := a + Vector2(area.size.y, area.size.y)
		_marker_line(
			a.clamp(area.position, area.end), b.clamp(area.position, area.end),
			Color(color, color.a * 0.7), alpha, reveal, salt + 500 + step,
			MARKER_WIDTH * 0.30
		)


## A dimension line: a rule between two points with ticks at each end and the
## quantity written over it. Printed forms use these and so do coaches, and it is
## the one place on the board where a straight line is honest.
func _draw_measure(
	from: Vector2, to: Vector2, label: String, color: Color,
	alpha: float, reveal: float, salt: int
) -> void:
	_marker_line(from, to, color, alpha * 0.8, reveal, salt, MARKER_WIDTH * 0.30)
	for at in [from, to]:
		_marker_line(
			at + Vector2(0.0, -5.0), at + Vector2(0.0, 5.0),
			color, alpha * 0.8, reveal, salt + 1, MARKER_WIDTH * 0.30
		)
	_marker_text(
		label, from.lerp(to, 0.5) + Vector2(-16.0, -8.0), 12, color, alpha, reveal
	)


## Straight down on the floor. Positions, lanes and coverage -- everything whose
## answer is a place rather than a height.
func _draw_top_down(which: String, alpha: float, reveal: float) -> void:
	var ink := _ink()
	var board_bottom := size.y - 13.0
	_marker_text(which.to_upper(), Vector2(size.x * 0.05, size.y * 0.13), 24, ink, alpha, reveal)

	## One half court, net along the top.
	var court := Rect2(
		size.x * 0.10, size.y * 0.22, size.x * 0.52, board_bottom - size.y * 0.34
	)
	_marker_line(
		court.position, court.position + Vector2(court.size.x, 0.0),
		ink, alpha, reveal, 5, MARKER_WIDTH * 1.1
	)
	_marker_rect(court, ink, alpha, reveal, 9)
	## The three-metre line, which is the only other line on a half court and the
	## one every one of these phases is measured against.
	var attack_line := court.position.y + court.size.y * 0.34
	_marker_line(
		Vector2(court.position.x, attack_line),
		Vector2(court.end.x, attack_line),
		Color(ink, 0.55), alpha, reveal, 13, MARKER_WIDTH * 0.5
	)

	match which:
		"Serve Receive":
			for spot in [Vector2(0.20, 0.72), Vector2(0.50, 0.84), Vector2(0.80, 0.70)]:
				_marker_circle(
					court.position + court.size * spot, 12.0, ink, alpha, reveal,
					51 + int(spot.x * 90.0)
				)
			_marker_ellipse(
				court.position + court.size * Vector2(0.35, 0.78),
				Vector2(50.0, 34.0), MARKER_RED, alpha * 0.9, reveal, 63
			)
			_marker_text("seam", court.position + court.size * Vector2(0.28, 0.60), 13, MARKER_RED, alpha, reveal)
		"Attack":
			var setter := court.position + court.size * Vector2(0.62, 0.20)
			_marker_circle(setter, 11.0, ink, alpha, reveal, 71)
			for target in [Vector2(0.10, 0.10), Vector2(0.40, 0.06), Vector2(0.88, 0.12)]:
				_marker_arrow(
					setter, court.position + court.size * target,
					MARKER_RED, alpha, reveal, 81 + int(target.x * 90.0)
				)
			_marker_text("lanes", court.position + court.size * Vector2(0.42, 0.30), 13, MARKER_RED, alpha, reveal)
		"Block":
			for share in [0.34, 0.52]:
				_marker_circle(
					court.position + Vector2(court.size.x * share, 12.0),
					11.0, ink, alpha, reveal, 101 + int(share * 100.0)
				)
			_marker_arrow(
				court.position + court.size * Vector2(0.44, 0.12),
				court.position + court.size * Vector2(0.20, 0.52),
				MARKER_RED, alpha, reveal, 113
			)
			_marker_text("funnel", court.position + court.size * Vector2(0.24, 0.58), 13, MARKER_RED, alpha, reveal)
		_:
			for spot in [Vector2(0.16, 0.30), Vector2(0.84, 0.32), Vector2(0.20, 0.82),
					Vector2(0.50, 0.92), Vector2(0.80, 0.80)]:
				_marker_circle(
					court.position + court.size * spot, 10.0, ink, alpha, reveal,
					121 + int(spot.x * 80.0 + spot.y * 17.0)
				)
			_marker_text("cover", court.position + court.size * Vector2(0.44, 0.50), 13, MARKER_RED, alpha, reveal)

	## The overlay, on the same court rather than on a different one.
	if overlay_on:
		_draw_serve_overlay(court, which, ink, alpha, reveal)

	## Anything dragged out of the tray, standing where it was dropped.
	for raw_slot in placements:
		var at: Vector2 = placements[raw_slot]
		var spot := Vector2(at.x * size.x, at.y * size.y)
		_marker_ellipse(
			spot, Vector2(13.0, 6.0), Color(ink, 0.42), alpha, reveal,
			401 + int(raw_slot) * 7
		)
		if not _draw_sticker(
			_sticker_key("tall" if int(raw_slot) % 2 == 0 else "wing", view),
			spot, size.y * 0.30
		):
			_marker_circle(spot - Vector2(0.0, 16.0), 9.0, ink, alpha, reveal, 411 + int(raw_slot))

	if adjustment_for(view, which).is_empty():
		_marker_text(
			"%s — nothing to set from here" % which.to_upper(),
			Vector2(size.x * 0.06, size.y * 0.95), 13, ink, alpha * 0.6, reveal
		)
	else:
		_draw_zone_bars(
			Rect2(size.x * 0.68, size.y * 0.40, size.x * 0.27, board_bottom - size.y * 0.54),
			alpha, reveal
		)


## The block phase, drawn the way an illustrator draws blockers at a net: a
## three-quarter view from slightly above, which is roughly the broadcast angle
## lifted a little.
##
## Was a flat elevation, straight on. That is the honest engineering view and it
## is the wrong one here -- straight on, two blockers at different depths sit at
## exactly the same height on the page, so the one thing the picture exists to
## show (who is where along the net, and how the seam between them opens) is the
## one thing it flattens. A slight rotation and a slight lift give the net a
## receding edge, and the moment the net recedes the blockers have positions
## along it.
##
## Projection is deliberately not a camera. `_net_point` is an axonometric map --
## along the net, up, and across it -- with no perspective divide, because a
## marker drawing does not have a focal length and a vanishing point would make
## the board look rendered rather than drawn.
## Screen y grows downward, which is the trap: written as `+ u * skew` the right
## antenna sank instead of rising and the net read as a fence falling over. The
## right-hand end of a net seen from the left and slightly above is *further
## away*, so it sits higher on the page and a little shorter.
const NET_SKEW: float = 0.13
## Where the far side of the net lands relative to the near side: up, and back to
## the left. No perspective divide -- a marker drawing has no focal length, and a
## vanishing point would make the board look rendered rather than drawn.
const NET_DEPTH := Vector2(-30.0, -22.0)


## u runs along the net (0 left antenna, 1 right), v is height (0 floor, 1 tape
## top), w is depth across the net (0 near side, 1 far).
## Pixels per metre for a view, fitted to the panel.
##
## `world` is the extent the view has to hold, in metres: how wide across, how
## tall up. The smaller of the two fits wins, so nothing is cropped and the two
## axes stay at the same scale -- an anisotropic fit would make the net the right
## height and the wrong width, which is the defect this exists to stop.
func _metres(world: Vector2) -> float:
	var usable := size * (1.0 - MARGIN_SHARE * 2.0) - Vector2(0.0, 13.0)
	return minf(usable.x / maxf(world.x, 0.001), usable.y / maxf(world.y, 0.001))


func _net_point(origin: Vector2, span: Vector2, u: float, v: float, w: float) -> Vector2:
	return origin + Vector2(
		u * span.x + w * NET_DEPTH.x,
		-v * span.y - u * span.x * NET_SKEW + w * NET_DEPTH.y
	)


func _draw_block_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	var board_bottom := size.y - 13.0
	## Sized in metres rather than in shares of the panel: 9 m of net across and
	## 2.43 m of it up, at one scale, with headroom above the tape for hands.
	var scale := _metres(Vector2(COURT_WIDTH_M * 1.55, NET_HEIGHT_M + HEADROOM_M))
	var span := Vector2(COURT_WIDTH_M * scale, NET_HEIGHT_M * scale)
	var origin := Vector2(size.x * 0.09, board_bottom - size.y * 0.07)

	_marker_text("BLOCK", Vector2(size.x * 0.06, size.y * 0.15), 26, ink, alpha, reveal)

	## The floor first, because everything else stands on it and because the
	## shadows the stickers cast need somewhere to fall. A court drawn with no
	## floor gives a blocker nothing to be above.
	_draw_floor_three_quarter(origin, span, ink, alpha, reveal)

	## The two tapes, top and bottom, and the band between them.
	var tape_top_left := _net_point(origin, span, 0.0, 1.0, 0.0)
	var tape_top_right := _net_point(origin, span, 1.0, 1.0, 0.0)
	var tape_low_left := _net_point(origin, span, 0.0, 0.46, 0.0)
	var tape_low_right := _net_point(origin, span, 1.0, 0.46, 0.0)

	## A net tape is a folded band with a cable through it, so it draws as **two**
	## lines a few millimetres apart with the cable's sag between them -- not as
	## one heavy stroke. That doubling is most of what turns a diagram of a net
	## into a drawing of one.
	var tape_depth := span.y * 0.045
	_marker_line(tape_top_left, tape_top_right, ink, alpha, reveal, 11, MARKER_WIDTH * 1.5)
	_marker_line(
		tape_top_left + Vector2(0.0, tape_depth),
		tape_top_right + Vector2(0.0, tape_depth),
		ink, alpha, reveal, 12, MARKER_WIDTH * 1.1
	)
	## The cable sags between the posts. Straight, a net reads as a fence.
	var sag := PackedVector2Array()
	for step in range(13):
		var t := float(step) / 12.0
		var point := tape_top_left.lerp(tape_top_right, t)
		point.y += sin(t * PI) * span.y * 0.035 + tape_depth * 0.5
		sag.append(point)
	_marker_stroke(sag, Color(ink, 0.55), alpha, reveal, 15, MARKER_WIDTH * 0.5, false)
	_marker_line(tape_low_left, tape_low_right, ink, alpha, reveal, 23, MARKER_WIDTH * 1.2)

	## The mesh, hung from the sagging cable rather than from a straight line, so
	## the squares stretch at the posts and slacken in the middle the way they do.
	var columns := 15
	for index in range(columns + 1):
		var u := float(index) / float(columns)
		var head := tape_top_left.lerp(tape_top_right, u)
		head.y += sin(u * PI) * span.y * 0.035 + tape_depth
		_marker_line(
			head, _net_point(origin, span, u, 0.46, 0.0),
			Color(ink, 0.40), alpha, reveal, 40 + index, MARKER_WIDTH * 0.55
		)
	for index in range(1, 4):
		var v := lerpf(0.46, 0.97, float(index) / 4.0)
		_marker_line(
			_net_point(origin, span, 0.0, v, 0.0),
			_net_point(origin, span, 1.0, v, 0.0),
			Color(ink, 0.34), alpha, reveal, 60 + index, MARKER_WIDTH * 0.50
		)

	## The posts. A net without them is hanging from nothing, and they are also
	## the only vertical reference in a drawing whose every other line is skewed.
	for entry in [[0.0, 71], [1.0, 79]]:
		var u: float = entry[0]
		var salt: int = entry[1]
		var foot := _net_point(origin, span, u, 0.0, 0.10)
		var crown := _net_point(origin, span, u, 1.16, 0.10)
		_marker_line(foot, crown, ink, alpha, reveal, salt, MARKER_WIDTH * 1.3)
		## The padded sleeve over the bottom two-thirds: two rules across the post
		## and a hatched face, which is how a sleeve reads at this size.
		var sleeve_top := foot.lerp(crown, 0.62)
		_marker_line(
			foot + Vector2(-7.0, 0.0), foot + Vector2(7.0, 0.0),
			ink, alpha, reveal, salt + 1, MARKER_WIDTH * 0.7
		)
		_marker_line(
			sleeve_top + Vector2(-6.0, 0.0), sleeve_top + Vector2(6.0, 0.0),
			ink, alpha, reveal, salt + 2, MARKER_WIDTH * 0.7
		)
		_hatch(
			Rect2(foot + Vector2(-6.0, 0.0), Vector2(12.0, sleeve_top.y - foot.y)),
			Color(ink, 0.30), alpha, reveal, salt + 3
		)
		## And the guy line back to the floor, which is the detail that says the
		## post is under tension rather than planted.
		_marker_line(
			crown, foot + Vector2(-26.0 if u < 0.5 else 26.0, 6.0),
			Color(ink, 0.34), alpha, reveal, salt + 5, MARKER_WIDTH * 0.35
		)

	## The antennae, in red, standing dead vertical -- the only strictly vertical
	## lines in the drawing, which is exactly how they read on a court.
	for entry in [[0.0, 91], [1.0, 97]]:
		var u: float = entry[0]
		var salt: int = entry[1]
		_marker_line(
			_net_point(origin, span, u, 1.34, 0.0),
			_net_point(origin, span, u, 0.40, 0.0),
			MARKER_RED, alpha, reveal, salt, MARKER_WIDTH * 1.4
		)
		## Banded, the way an antenna is.
		for band in range(1, 5):
			var v := lerpf(0.40, 1.34, float(band) / 5.0)
			_marker_line(
				_net_point(origin, span, u, v, 0.0) + Vector2(-3.0, 0.0),
				_net_point(origin, span, u, v, 0.0) + Vector2(3.0, 0.0),
				Color(MARKER_RED, 0.5), alpha, reveal, salt + band, MARKER_WIDTH * 0.8
			)

	## Cross-hatched shade under the tape, where the net's own shadow falls on the
	## mesh. Two crossing sets rather than one, because a single direction reads as
	## texture and two read as shadow.
	## Lighter than the mesh it falls on, or it stops being shade and becomes
	## another layer of net.
	_hatch(
		Rect2(tape_top_left + Vector2(0.0, tape_depth), Vector2(span.x, span.y * 0.14)),
		Color(ink, 0.10), alpha, reveal, 121
	)

	## The blockers, as stickers rather than as drawn figures.
	##
	## They fall back to the drawn arch while the bake is still running -- a few
	## frames at startup -- because a body that pops in is better than a hole, and
	## the fallback is the same figure the sheet used before.
	var blockers := [
		[0.30, "tall"], [0.52, "wing"],
	]
	for index in range(blockers.size()):
		var u: float = blockers[index][0]
		var key: String = _sticker_key(str(blockers[index][1]), view)
		var salt := 90 + index * 29
		var head := _net_point(origin, span, u, 1.15, 0.55)
		var radius := 15.0
		## Scaled off the net rather than off the panel: a blocker is about a
		## third again the height of the tape from the floor, and pinning the
		## sticker to the drawing is what keeps the two in proportion when the
		## sheet resizes.
		## In metres, off the net rather than off the panel: a blocker at full
		## extension reaches about 3.4 m, so against a 2.43 m net they stand about
		## a net and a half tall. Tying it to `span.y` -- which *is* 2.43 m of
		## pixels -- keeps the two in proportion at every panel size.
		var sticker_height := span.y * (3.40 / NET_HEIGHT_M) * 0.80
		## The shadow the body casts on the floor, drawn *into* the drawing rather
		## than under the sticker: a pencil ellipse at the voli's feet, hatched, in
		## the same hand as the court. The sticker's own drop shadow says it is a
		## sticker; this one says the voli is standing somewhere.
		var feet := _net_point(origin, span, u, 0.0, 0.55)
		_marker_ellipse(
			feet, Vector2(span.y * 0.20, span.y * 0.070),
			Color(ink, 0.42), alpha, reveal, salt + 71
		)
		_hatch(
			Rect2(feet - Vector2(span.y * 0.17, span.y * 0.05),
				Vector2(span.y * 0.34, span.y * 0.10)),
			Color(ink, 0.22), alpha, reveal, salt + 83
		)
		## Raised off their own shadow by the jump the pose already contains.
		##
		## Anchoring at the feet put a blocker at full extension flat on the floor,
		## which is a contradiction the shadow made obvious: the ellipse says "this
		## voli is standing here" and a block says they are not. `set_pose` lifts
		## the body by `elevation * 0.82` metres, so the drawing lifts by the same
		## number of metres through the same scale, and the gap between body and
		## shadow *is* the jump rather than a constant that looked about right.
		var lift := BLOCK_ELEVATION * 0.82 * (span.y / NET_HEIGHT_M)
		var placed := _draw_sticker(key, feet - Vector2(0.0, lift), sticker_height)
		if not placed:
			var arch := PackedVector2Array()
			for step in range(17):
				var t := float(step) / 16.0
				var angle := lerpf(PI * 0.92, PI * 0.08, t)
				arch.append(
					head + Vector2(cos(angle), -sin(angle))
						* Vector2(radius * 1.85, radius * 1.55)
				)
			_marker_stroke(arch, ink, alpha, reveal, salt + 5, MARKER_WIDTH * 1.4, false)
			_marker_circle(head, radius, ink, alpha, reveal, salt)
			_marker_line(
				head + Vector2(0.0, radius * 0.9),
				_net_point(origin, span, u, 0.62, 0.55),
				ink, alpha, reveal, salt + 3, MARKER_WIDTH * 1.4
			)
		_marker_text(
			"%d" % (index + 1), head + Vector2(-6.0, -radius * 1.9),
			16, MARKER_RED, alpha, reveal
		)

	## The seam between them, circled the way somebody circles the thing they
	## want you to look at.
	var seam_u: float = (float(blockers[0][0]) + float(blockers[1][0])) * 0.5
	var seam := _net_point(origin, span, seam_u, 1.17, 0.48)
	_marker_ellipse(seam, Vector2(44.0, 38.0), MARKER_RED, alpha * 0.9, reveal, 137)

	_draw_zone_bars(
		Rect2(size.x * 0.68, size.y * 0.40, size.x * 0.27, board_bottom - size.y * 0.54),
		alpha, reveal
	)


## The priority bars. Black for the level, red for the one being pointed at, and
## a hand-ruled baseline under all four.
func _draw_zone_bars(area: Rect2, alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"PRIORITY", area.position + Vector2(0.0, -8.0), 15, ink, alpha, reveal
	)
	var slot := area.size.x / float(ZONE_COUNT)
	var bar_width := slot * 0.66
	var baseline := area.position.y + area.size.y
	for index in range(ZONE_COUNT):
		var centre := area.position.x + slot * (float(index) + 0.5)
		var level := zone_priorities[index]
		var height := area.size.y * (float(level) / float(ZONE_MAX_PRIORITY))
		var color := MARKER_RED if index == _hovered_zone else ink
		## Filled by hatching rather than by a solid rectangle. A marker fills a
		## shape by going back and forth across it, and the overlaps at the turns
		## are visible -- which is exactly what the translucent ink gives for free.
		## Shaded with the **side** of the tip, not hatched with the point.
		##
		## Hatching was the marker's answer -- a chisel fills a box by going back
		## and forth and the turns show. A pencil laid over does something else
		## entirely: a few broad diagonal passes, each soft, overlapping into a
		## tone. Diagonal because a hand shading a tall box moves across it rather
		## than along it, and the diagonal is what stops the fill reading as more
		## rungs on a ladder.
		var passes := maxi(int(height / SHADE_STEP), 1)
		for step in range(passes):
			var y := baseline - float(step) * SHADE_STEP - SHADE_WIDTH * 0.4
			if y < baseline - height:
				break
			## Each pass leans, because a hand shading a box moves across it at an
			## angle rather than straight along. The lean is what stops the fill
			## reading as more rungs on a ladder.
			_marker_stroke(
				PackedVector2Array([
					Vector2(centre - bar_width * 0.5, y + 3.0),
					Vector2(centre + bar_width * 0.5, y - 3.0),
				]),
				Color(color, SHADE_ALPHA), alpha, reveal,
				200 + index * 17 + step, SHADE_WIDTH, false
			)
		## The outline of the box it was filled into, drawn after, so it reads as
		## the shape rather than as the edge of the hatching.
		if level > 0:
			_marker_rect(
				Rect2(
					centre - bar_width * 0.5, baseline - height,
					bar_width, height
				), color, alpha * 0.85, reveal, 300 + index
			)
		_marker_text(
			ZONE_LABELS[index], Vector2(centre - bar_width * 0.5, baseline + 15.0),
			12, color, alpha, reveal
		)
	_marker_line(
		Vector2(area.position.x - 6.0, baseline),
		Vector2(area.position.x + area.size.x + 6.0, baseline),
		ink, alpha, reveal, 399, 13
	)


func _draw_receive_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"SERVE RECEIVE", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	## A half court in plan, because reception is a floor-shape problem.
	var court := Rect2(size.x * 0.10, size.y * 0.24, size.x * 0.46, size.y * 0.54)
	_marker_rect(court, ink, alpha, reveal, 11)
	_marker_line(
		court.position + Vector2(0.0, court.size.y * 0.34),
		court.position + Vector2(court.size.x, court.size.y * 0.34),
		Color(ink, 0.55), alpha * 0.7, reveal, 27
	)
	for spot in [Vector2(0.22, 0.68), Vector2(0.50, 0.80), Vector2(0.78, 0.66)]:
		_marker_circle(
			court.position + court.size * spot, 10.0, ink, alpha, reveal,
			41 + int(spot.x * 100.0)
		)
	_marker_text(
		"seam", court.position + court.size * Vector2(0.30, 0.44), 13,
		MARKER_RED, alpha, reveal
	)
	_marker_ellipse(
		court.position + court.size * Vector2(0.36, 0.72), Vector2(56.0, 30.0),
		MARKER_RED, alpha * 0.9, reveal, 63
	)


func _draw_attack_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"ATTACK", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	var net_y := size.y * 0.34
	_marker_line(
		Vector2(size.x * 0.08, net_y), Vector2(size.x * 0.72, net_y), ink, alpha, reveal, 7, 11
	)
	var setter := Vector2(size.x * 0.44, size.y * 0.52)
	_marker_circle(setter, 11.0, ink, alpha, reveal, 19)
	_marker_text("S", setter + Vector2(-5.0, 5.0), 14, ink, alpha, reveal)
	for target in [Vector2(size.x * 0.15, size.y * 0.42), Vector2(size.x * 0.66, size.y * 0.44)]:
		_marker_arrow(setter, target, MARKER_RED, alpha, reveal, 31 + int(target.x))


func _draw_floor_phase(alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"FLOOR", Vector2(size.x * 0.08, size.y * 0.16), 26, ink, alpha, reveal
	)
	var court := Rect2(size.x * 0.10, size.y * 0.26, size.x * 0.52, size.y * 0.50)
	_marker_rect(court, ink, alpha, reveal, 5)
	for spot in [Vector2(0.18, 0.26), Vector2(0.50, 0.20), Vector2(0.82, 0.28),
			Vector2(0.22, 0.76), Vector2(0.78, 0.74)]:
		_marker_circle(
			court.position + court.size * spot, 9.0, ink, alpha, reveal,
			51 + int(spot.x * 90.0 + spot.y * 13.0)
		)
	_marker_text(
		"cover", court.position + court.size * Vector2(0.42, 0.52), 13,
		MARKER_RED, alpha, reveal
	)


# --------------------------------------------------------------------------
# The marker itself
# --------------------------------------------------------------------------

## One stroke, chisel-tipped and translucent.
##
## `reveal` is how much of the board the squeegee has uncovered; a stroke past
## that point has not been drawn yet, and one that straddles it is drawn as far
## as the squeegee has got. That is what makes the new layout appear *behind* the
## wipe rather than all at once when it finishes.
func _marker_line(
	from: Vector2, to: Vector2, color: Color, alpha: float,
	reveal: float, salt: int, width: float = MARKER_WIDTH
) -> void:
	_marker_stroke(
		_wandering_path(from, to, salt), color, alpha, reveal, salt, width, false
	)


## A run the hand did not lift for.
##
## The first draft drew every stroke as a chain of short `draw_line` calls with
## an independent offset per segment. Two things came out of that and both were
## wrong. The joins between segments overlap, and since the ink is translucent
## *every join darkened* -- so a plain straight line was a row of dark ticks, and
## the overlap that is supposed to mean "two strokes crossed here" meant nothing
## because it was everywhere. And an independent offset per segment is white
## noise, which reads as a shaky hand rather than a fast one.
##
## So a stroke is now one polygon: a ribbon built along a centreline, filled in a
## single `draw_colored_polygon`. It cannot overlap itself, so a crossing is the
## only thing that darkens. The centreline wanders on two slow sine components
## rather than per-point noise, which bends the run instead of shaking it, and
## the width drifts slowly along it on a third -- the hand leaning in and easing
## off over a run it never lifted from.
func _wandering_path(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var path := PackedVector2Array()
	var length := from.distance_to(to)
	if length < 0.001:
		return path
	var normal := (to - from).orthogonal().normalized()
	var steps := clampi(int(length / MARKER_SEGMENT), 3, 48)
	## Two components, seeded: one long bow across the whole run and one shorter
	## correction. A hand drawing a straight line produces exactly this -- it
	## leaves true, notices, and comes back.
	var phase_a := _unit(salt * 31 + 3) * TAU
	var phase_b := _unit(salt * 31 + 9) * TAU
	var amplitude := MARKER_WANDER * (0.55 + _unit(salt * 31 + 17) * 0.75)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var bow := sin(phase_a + t * PI) * 0.75 + sin(phase_b + t * TAU * 1.7) * 0.25
		## Both ends settle onto true: a hand starts and finishes where it meant
		## to even when the middle of the run drifts.
		path.append(from.lerp(to, t) + normal * bow * amplitude * sin(t * PI))
	return path


## Fill a centreline as one continuous chisel-tipped ribbon.
##
## Emitted as a quad per segment rather than as one polygon down the whole run.
## The single-polygon form works for an open stroke and silently fails for a
## closed one: left-side-forward plus right-side-backward round a circle is a
## *ring*, which is not a simple polygon, and Godot's triangulator drops it --
## which is why a blocker's head vanished while their arms drew fine.
##
## Adjacent quads share an edge exactly, so the run still does not darken against
## itself; where a path genuinely crosses its own tail, the two quads there do
## overlap and it darkens, which is the lap that says a circle was thrown round
## something in a hurry.
func _marker_stroke(
	path: PackedVector2Array, color: Color, alpha: float, reveal: float,
	salt: int, width: float, _closed: bool
) -> void:
	if alpha <= 0.001 or path.size() < 2:
		return
	var limit := size.x * reveal
	var visible := PackedVector2Array()
	for point in path:
		if point.x > limit:
			break
		visible.append(point)
	if visible.size() < 2:
		return

	## One antialiased polyline per stroke.
	##
	## Strokes were quads -- one `draw_colored_polygon` per segment -- to stop the
	## joins double-drawing and darkening, which they did when each segment was
	## its own `draw_line`. That worked and cost the thing nobody wanted to lose:
	## `draw_colored_polygon` has no antialiasing at all, so every line on the
	## sheet was a hard-edged staircase. At two and a half pixels wide that is
	## most of what the eye sees.
	##
	## `draw_polyline` is one primitive rather than N, so it does not double-draw
	## at its own joins *and* it antialiases. What it cannot do is vary width
	## along its length -- so the width is resolved once per stroke, from the
	## chisel angle against the stroke's own dominant direction. At a pencil's
	## width that variation was never visible along a single run anyway; what
	## reads is the difference *between* strokes, and that survives.
	var heading := visible[visible.size() - 1] - visible[0]
	if heading.length_squared() < 0.000001:
		heading = Vector2.RIGHT
	var pressure := 1.0 + sin(_unit(salt * 47 + 5) * TAU) * 0.14
	var drawn := maxf(_tip_width(heading, width) * pressure, 0.6)
	## The tooth, per stroke rather than per segment. Graphite catches unevenly,
	## and with the width now constant this is the only channel left that says so.
	var grain := lerpf(1.0 - TOOTH_SKIP * 0.5, 1.0, _unit(salt * 31 + 17))
	draw_polyline(
		visible, Color(color, color.a * MARKER_ALPHA * alpha * grain), drawn, true
	)


## A stable 0-1 from the board's seed and a salt. Hand-mixed rather than an rng
## object, because these are read a few thousand times a frame.
func _unit(step: int) -> float:
	var accumulated := (_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0


## The chisel: full width across the tip, `MARKER_MIN_RATIO` of it along.
func _tip_width(direction: Vector2, width: float) -> float:
	if direction.length_squared() < 0.0001:
		return width
	var tip := Vector2.RIGHT.rotated(deg_to_rad(MARKER_ANGLE_DEGREES))
	var across := absf(direction.normalized().cross(tip))
	return width * lerpf(MARKER_MIN_RATIO, 1.0, across)


func _marker_rect(
	rect: Rect2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0.0)
	var c := rect.position + rect.size
	var d := rect.position + Vector2(0.0, rect.size.y)
	## Overshot corners. A hand drawing a box does not stop exactly on the
	## corner, and the little crossings at four corners are most of what says
	## somebody drew this quickly.
	_marker_line(a + Vector2(-3.0, 0.0), b + Vector2(4.0, 0.0), color, alpha, reveal, salt)
	_marker_line(b + Vector2(0.0, -3.0), c + Vector2(0.0, 4.0), color, alpha, reveal, salt + 1)
	_marker_line(c + Vector2(3.0, 0.0), d + Vector2(-4.0, 0.0), color, alpha, reveal, salt + 2)
	_marker_line(d + Vector2(0.0, 3.0), a + Vector2(0.0, -4.0), color, alpha, reveal, salt + 3)


func _marker_circle(
	centre: Vector2, radius: float, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_ellipse(centre, Vector2(radius, radius), color, alpha, reveal, salt)


## One lap of the pen, drawn as a single ribbon.
##
## Was a run of separate chords, which meant fifteen overlapping joins round
## every circle and a ring of dark ticks. The overshoot past its own start is
## kept -- that lap over the beginning is the entire tell of a circle thrown
## round something quickly -- but now it is the one place the shape crosses
## itself, so it is the one place that darkens.
func _marker_ellipse(
	centre: Vector2, radii: Vector2, color: Color, alpha: float,
	reveal: float, salt: int
) -> void:
	var segments := 40
	var start := _unit(salt * 13 + 1) * TAU
	var sweep := TAU + 0.25 + _unit(salt * 13 + 7) * 0.30
	## A hand-thrown circle is never round and never axis-aligned.
	var tilt := (_unit(salt * 13 + 21) - 0.5) * 0.5
	var squash := 0.92 + _unit(salt * 13 + 33) * 0.16
	var path := PackedVector2Array()
	for index in range(segments + 1):
		var angle := start + sweep * float(index) / float(segments)
		var local := Vector2(cos(angle), sin(angle) * squash) * radii
		path.append(centre + local.rotated(tilt))
	_marker_stroke(
		path, color, alpha, reveal, salt, MARKER_WIDTH * 1.4, true
	)


func _marker_arrow(
	from: Vector2, to: Vector2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_line(from, to, color, alpha, reveal, salt)
	var back := (from - to).normalized()
	for turn in [0.45, -0.45]:
		_marker_line(
			to, to + back.rotated(turn) * 17.0, color, alpha, reveal,
			salt + int(turn * 100.0), MARKER_WIDTH * 0.85
		)


## Marker writing. The heading face is already a fat rounded display -- which is
## what a chisel tip produces -- so the board writes in it rather than in the
## body face, and tilts it a degree or two off true.
func _marker_text(
	text: String, at: Vector2, font_size: int, color: Color,
	alpha: float, reveal: float
) -> void:
	if alpha <= 0.001 or at.x > size.x * reveal:
		return
	var font := _marker_font()
	if font == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(text.hash() & 0xFFFF)
	draw_set_transform(at, rng.randf_range(-0.028, 0.028))
	## Writing takes a boost over stroke work, because a letterform at marker
	## alpha loses its counters and turns to mush -- but only when it is *live*.
	## Boosting a ghost too left the previous phase's heading legible under the
	## new one, so the board read "BLOCK RECEIVE".
	var written := MARKER_ALPHA * alpha
	if alpha > 0.5:
		written = clampf(written + 0.18, 0.0, 1.0)
	draw_string(
		font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, Color(color, color.a * written)
	)
	draw_set_transform(Vector2.ZERO, 0.0)


func _marker_font() -> Font:
	## `DisplayHeading` is the Cherry Bomb face -- fat, rounded, no thin strokes
	## anywhere, which is what a chisel tip physically cannot produce either. It
	## was chosen as a display face and happens to be the closest thing in the
	## project to marker writing, so the board borrows it rather than shipping a
	## font for one screen.
	var theme_font := get_theme_font(&"font", &"DisplayHeading")
	if theme_font != null:
		return theme_font
	return get_theme_default_font()


func _board_color() -> Color:
	## Graph paper is a *sheet on the sheet*, so it must not be the same colour as
	## the form it lies on -- two surfaces the same colour are one surface. Squared
	## paper is faintly cooler and very slightly greener than plain stock, which is
	## the whole difference and is enough. In Mikasa the same sheet under a desk
	## lamp: still paper, still lighter than the page around it, nowhere near white.
	return Color(0.955, 0.960, 0.950) if light_mode else Color(0.19, 0.21, 0.22)


func _ink() -> Color:
	## Graphite, which is not black -- it is a warm grey with a slight sheen, and
	## drawn at true black a pencil stops being a pencil. On the dark sheet the
	## roles swap, because a grey pencil on a grey page cannot be read; red stays
	## red in both, which is why it carries the emphasis.
	return Color(0.26, 0.25, 0.27) if light_mode else Color(0.82, 0.84, 0.86)


func _zone_at(at: Vector2) -> int:
	var area := Rect2(
		size.x * 0.68, size.y * 0.40, size.x * 0.27, size.y - 13.0 - size.y * 0.54
	)
	if not area.grow(10.0).has_point(at):
		return -1
	var slot := area.size.x / float(ZONE_COUNT)
	return clampi(int((at.x - area.position.x) / slot), 0, ZONE_COUNT - 1)
